# Contributor Guide - Project Leibniz

## Project Overview
Project Leibniz delivers "research at the speed of thought" - a <200ms semantic search system for ML literature. Every line of code must serve this goal.

## Codex Environment Setup

In Codex environment, external services (Redis, Neo4j, etc.) won't be available. Use these patterns:

```python
# GOOD: Graceful fallback for missing services
import os
from unittest.mock import MagicMock

def get_redis_client():
    """Get Redis client with fallback for testing."""
    if os.getenv("CODEX_ENVIRONMENT") or not is_redis_available():
        # Return mock for testing without Redis
        mock = MagicMock()
        mock.get = lambda k: None
        mock.setex = lambda k, ttl, v: True
        return mock
    
    return redis.Redis(host="localhost", port=6379)

def is_redis_available():
    """Check if Redis is running."""
    try:
        client = redis.Redis(host="localhost", port=6379)
        client.ping()
        return True
    except:
        return False

# Use environment variable to detect Codex
IS_CODEX = os.getenv("CODEX_ENVIRONMENT", "").lower() == "true"
```

## Quick Setup
```bash
# Check prerequisites
./scripts/check-services.sh

# Initialize environment
cp .env.example .env
# Edit .env with your OpenAI API key

# Start all services
docker-compose up -d

# Initialize Leibniz
python -m leibniz.cli init
python -m leibniz.cli check
```

## Development Workflow

### Pre-commit Checks
Always run these before committing:
```bash
# Auto-fix code style
ruff check . --fix
ruff format .

# Type checking
mypy leibniz

# Run performance tests
pytest tests/performance/ -v

# If all pass, commit
git add -A && git commit -m "..."
```

## Coding Conventions

### Performance First
Every function must consider the <200ms target. When in doubt, measure.

```python
# GOOD: Performance tracked from the start
import time
from functools import wraps

def track_performance(func):
    @wraps(func)
    async def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = await func(*args, **kwargs)
        duration = (time.perf_counter() - start) * 1000
        if duration > 150:  # Warning threshold
            logger.warning(f"{func.__name__} took {duration:.1f}ms")
        return result
    return wrapper

@track_performance
async def search_papers(query: str) -> list[Paper]:
    # Implementation
    pass

# BAD: No performance consideration
async def search_papers(query: str) -> list[Paper]:
    # Just hoping it's fast
    pass
```

### Modern Python (3.11+) & FastAPI Patterns

```python
# GOOD: Type hints everywhere, async by default
from typing import Optional, Annotated
from fastapi import FastAPI, Query, Depends
from pydantic import BaseModel, Field

class QueryRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=500)
    limit: int = Field(20, ge=1, le=100)
    filters: Optional[QueryFilters] = None

async def get_redis_client() -> Redis:
    """Dependency injection for Redis client."""
    return redis_pool.get_client()

@app.post("/api/v1/query", response_model=QueryResponse)
async def search_papers(
    request: QueryRequest,
    redis: Annotated[Redis, Depends(get_redis_client)]
) -> QueryResponse:
    # Check cache first - CRITICAL for <200ms
    cache_key = f"query:{hash(request.query)}"
    if cached := await redis.get(cache_key):
        return QueryResponse.parse_raw(cached)
    
    # Parallel search
    results = await parallel_search(request.query)
    
    # Cache for next time
    await redis.setex(cache_key, 3600, results.json())
    return results

# BAD: Synchronous, no caching, no types
@app.post("/api/v1/query")
def search_papers(request):
    results = database.search(request["query"])
    return {"results": results}
```

### Parallel by Default

```python
# GOOD: All operations parallelized
async def parallel_search(query: str) -> SearchResults:
    """Execute all search strategies in parallel."""
    # Create tasks
    tasks = [
        search_vector(query),
        search_graph(query),
        search_keyword(query),
    ]
    
    # Execute with timeout
    results = []
    done, pending = await asyncio.wait(
        tasks,
        timeout=0.15,  # 150ms max
        return_when=asyncio.ALL_COMPLETED
    )
    
    # Cancel slow operations
    for task in pending:
        task.cancel()
        logger.warning(f"Cancelled slow task: {task.get_name()}")
    
    # Gather results
    for task in done:
        try:
            results.append(await task)
        except Exception as e:
            logger.error(f"Task failed: {e}")
    
    return merge_results(results)

# BAD: Sequential operations
async def search_all(query: str) -> SearchResults:
    vector_results = await search_vector(query)
    graph_results = await search_graph(query)
    keyword_results = await search_keyword(query)
    return merge_results([vector_results, graph_results, keyword_results])
```

### Connection Pooling

```python
# GOOD: Connection pools initialized once
class DatabasePools:
    """Singleton for all database connections."""
    
    def __init__(self):
        self.redis = None
        self.qdrant = None
        self.neo4j = None
        
    async def initialize(self):
        """Initialize all connection pools."""
        self.redis = Redis(
            connection_pool=ConnectionPool(
                host="localhost",
                port=6379,
                max_connections=50,
                decode_responses=True
            )
        )
        
        self.qdrant = QdrantClient(
            host="localhost",
            port=6333,
            limits=HttpLimits(max_connections=20)
        )
        
        self.neo4j = AsyncGraphDatabase.driver(
            "bolt://localhost:7687",
            auth=("neo4j", "password"),
            max_connection_pool_size=50
        )

# Global instance
db_pools = DatabasePools()

@app.on_event("startup")
async def startup():
    await db_pools.initialize()

# BAD: Creating connections per request
async def search_vector(query: str):
    client = QdrantClient("localhost", 6333)  # New connection each time!
    results = await client.search(...)
    return results
```

### Error Handling with Performance

```python
# GOOD: Graceful degradation
async def search_with_fallback(query: str) -> SearchResults:
    """Search with automatic fallback to maintain <200ms."""
    try:
        # Try vector search first (fastest)
        return await asyncio.wait_for(
            search_vector(query),
            timeout=0.1  # 100ms timeout
        )
    except asyncio.TimeoutError:
        logger.warning("Vector search timeout, trying cache")
        
        # Try cache
        if cached := await get_cached_results(query):
            return cached
            
        # Last resort: keyword search (fastest alternative)
        return await search_keyword(query)

# BAD: Let it fail
async def search(query: str) -> SearchResults:
    return await search_vector(query)  # If this fails, whole request fails
```

### Caching Patterns

```python
# GOOD: Multi-level caching
from functools import lru_cache
import hashlib

class CacheManager:
    def __init__(self):
        self.memory_cache = {}  # L1: In-memory
        self.redis = None       # L2: Redis
        
    async def get(self, key: str) -> Optional[Any]:
        # L1: Memory cache (0ms)
        if key in self.memory_cache:
            return self.memory_cache[key]
            
        # L2: Redis cache (1-5ms)
        if self.redis and (value := await self.redis.get(key)):
            self.memory_cache[key] = value  # Promote to L1
            return json.loads(value)
            
        return None
    
    async def set(self, key: str, value: Any, ttl: int = 3600):
        # Set in both levels
        self.memory_cache[key] = value
        if self.redis:
            await self.redis.setex(key, ttl, json.dumps(value))

@lru_cache(maxsize=1000)
def compute_embedding_cache_key(text: str) -> str:
    """Cache key computation (expensive)."""
    return hashlib.sha256(text.encode()).hexdigest()

# BAD: No caching strategy
async def get_embeddings(text: str) -> list[float]:
    return await openai_client.embeddings.create(input=text)
```

### Testing for Performance

```python
# GOOD: Performance is part of the test
import pytest
from statistics import mean, quantiles

@pytest.mark.asyncio
@pytest.mark.performance
async def test_query_latency():
    """Ensure P95 < 200ms requirement is met."""
    async with httpx.AsyncClient() as client:
        latencies = []
        
        # Warm up
        await client.post("/api/v1/query", json={"query": "test"})
        
        # Measure
        for _ in range(100):
            start = time.perf_counter()
            response = await client.post(
                "/api/v1/query",
                json={"query": "transformer efficiency"}
            )
            latency = (time.perf_counter() - start) * 1000
            
            assert response.status_code == 200
            latencies.append(latency)
        
        # Check percentiles
        p50, p95 = quantiles(latencies, n=100)[49], quantiles(latencies, n=100)[94]
        
        assert p95 < 200, f"P95 latency {p95:.1f}ms exceeds 200ms target"
        assert p50 < 100, f"P50 latency {p50:.1f}ms should be under 100ms"
        
        # Log for tracking
        print(f"\nPerformance: P50={p50:.1f}ms, P95={p95:.1f}ms")

# BAD: Only testing functionality
async def test_search():
    response = await client.post("/api/v1/query", json={"query": "test"})
    assert response.status_code == 200  # But how fast was it?
```

## Documentation Standards

### FastAPI Docstrings

```python
@app.post(
    "/api/v1/query",
    response_model=QueryResponse,
    summary="Search research papers",
    description="Semantic search across ML literature with <200ms response time"
)
async def search_papers(
    request: QueryRequest,
    background_tasks: BackgroundTasks,
    redis: Annotated[Redis, Depends(get_redis_client)]
) -> QueryResponse:
    """
    Execute multi-source paper search.
    
    Performs parallel search across:
    - Vector embeddings (QDrant)
    - Knowledge graph (Neo4j) 
    - Full-text index (Meilisearch)
    
    Performance target: <200ms P95 latency
    
    Args:
        request: Search query and filters
        background_tasks: FastAPI background task queue
        redis: Injected Redis client for caching
        
    Returns:
        QueryResponse with papers, suggestions, and timing
        
    Raises:
        HTTPException: If query processing fails
        
    Example:
        >>> response = await search_papers(
        ...     QueryRequest(query="transformer efficiency", limit=10)
        ... )
        >>> assert response.processing_time_ms < 200
    """
```

### Module Documentation

```python
"""
Query service for Project Leibniz.

This module implements the core search functionality with a focus on
achieving <200ms response times through:

- Parallel search execution across multiple backends
- Multi-level caching (memory + Redis)
- Query result pre-computation for common searches
- Aggressive timeout and fallback strategies

Performance Targets
------------------
- P50 latency: <100ms
- P95 latency: <200ms  
- Cache hit rate: >80%

Architecture Notes
-----------------
The service uses a three-tier architecture:
1. API layer (FastAPI) - request validation and routing
2. Search orchestration - parallel execution and merging
3. Storage backends - QDrant, Neo4j, Meilisearch

All database connections use pooling to minimize connection overhead.
Redis caching is mandatory for meeting performance targets.
"""
```

## Testing

### Test Organization
```
tests/
├── unit/           # Fast, isolated tests
├── integration/    # Service integration tests
├── performance/    # Latency and throughput tests
├── e2e/           # End-to-end user flows
└── fixtures/      # Shared test data
```

### Performance Test Requirements

Every new feature MUST include a performance test:

```python
# tests/performance/test_feature.py
@pytest.mark.performance
@pytest.mark.benchmark(
    group="query",
    min_rounds=50,
    max_time=10.0,
    disable_gc=True
)
def test_new_feature_performance(benchmark):
    """Ensure new feature doesn't degrade performance."""
    result = benchmark(run_feature_function)
    
    # Check against baseline
    assert benchmark.stats['mean'] < 0.150  # 150ms mean
    assert benchmark.stats['max'] < 0.200   # 200ms max
```

### Load Testing

```python
# tests/load/test_concurrent.py
@pytest.mark.load
async def test_concurrent_users():
    """Verify performance under load."""
    async def make_request():
        async with httpx.AsyncClient() as client:
            start = time.perf_counter()
            await client.post("/api/v1/query", json={"query": "test"})
            return (time.perf_counter() - start) * 1000
    
    # 50 concurrent requests
    latencies = await asyncio.gather(*[make_request() for _ in range(50)])
    
    p95 = quantiles(latencies, n=100)[94]
    assert p95 < 500, f"P95 under load {p95:.1f}ms exceeds 500ms"
```

## PR Guidelines

### Title Format
`[component] Brief description (<200ms maintained)`

Examples:
- `[query] Add Redis caching layer (<200ms maintained)`
- `[vector] Optimize QDrant search (150ms → 80ms)`
- `[frontend] Add progressive loading (<50ms first paint)`

### PR Checklist
```markdown
## Performance Impact
- [ ] P95 latency still <200ms
- [ ] Performance test added/updated
- [ ] No new blocking operations
- [ ] Caching strategy documented

## Code Quality
- [ ] Type hints on all functions
- [ ] Async/await used properly
- [ ] Error handling with fallbacks
- [ ] No hardcoded values

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Performance benchmarks pass
- [ ] Load test results attached
```

### Performance Report Template
```markdown
## Performance Metrics

### Before
- P50: 120ms
- P95: 180ms
- P99: 220ms

### After  
- P50: 80ms (-40ms)
- P95: 150ms (-30ms)
- P99: 190ms (-30ms)

### Test Details
- Test: 1000 queries, 50 concurrent users
- Cache hit rate: 85%
- Memory usage: +10MB
```

## Common Patterns

### Fast JSON Serialization
```python
# GOOD: Use orjson for speed
import orjson

def fast_json_response(data: Any) -> Response:
    return Response(
        content=orjson.dumps(data),
        media_type="application/json"
    )

# BAD: Standard json is slower
import json
return json.dumps(data)
```

### Streaming Responses
```python
# GOOD: Stream large responses
async def stream_results():
    async def generate():
        for chunk in await get_large_dataset():
            yield orjson.dumps(chunk) + b"\n"
    
    return StreamingResponse(generate(), media_type="application/x-ndjson")
```

### Background Tasks
```python
# GOOD: Non-critical work in background
@app.post("/api/v1/query")
async def search(request: QueryRequest, background_tasks: BackgroundTasks):
    results = await quick_search(request.query)
    
    # Log analytics in background (don't block response)
    background_tasks.add_task(log_search_analytics, request, results)
    
    return results
```

## Performance Debugging

### Quick Profiling
```python
# Add to any suspicious function
import cProfile
import pstats
from io import StringIO

def profile_this(func):
    def wrapper(*args, **kwargs):
        pr = cProfile.Profile()
        pr.enable()
        result = func(*args, **kwargs)
        pr.disable()
        
        s = StringIO()
        ps = pstats.Stats(pr, stream=s).sort_stats('cumulative')
        ps.print_stats(10)
        logger.debug(f"Profile for {func.__name__}:\n{s.getvalue()}")
        
        return result
    return wrapper
```

### Memory Profiling
```python
# Check for memory leaks
from memory_profiler import profile

@profile
async def potentially_leaky_function():
    # Function will output line-by-line memory usage
    pass
```

## Quick Commands

```bash
# Find slow functions
grep -r "duration > 100" logs/ --include="*.log"

# Check current performance
cat PERFORMANCE_LOG.md | tail -20

# Run just performance tests
pytest tests/performance/ -v --benchmark-only

# Profile specific endpoint
python -m cProfile -o profile.stats services/query/main.py
python -m pstats profile.stats

# Monitor Redis
redis-cli monitor | grep -E "query:|SETEX"

# Check Docker resource usage
docker stats --no-stream
```

## Architecture Principles

1. **Speed is a Feature**: If it's not <200ms, it's broken
2. **Cache Aggressively**: Memory > Redis > Database
3. **Fail Fast**: Timeout early, fallback gracefully
4. **Measure Everything**: You can't optimize what you don't measure
5. **Parallel by Default**: Sequential = slow

## Zero Tolerance

- **Blocking I/O**: Everything must be async
- **Uncached Queries**: Cache or explain why not
- **Missing Timeouts**: Every external call needs a timeout
- **No Performance Tests**: Feature isn't done without perf test
- **Sequential Operations**: Parallelize or justify

## Demo-Driven Development

Every feature should enhance one of these demos:
1. Type "transformer" → see results before finishing typing
2. Show contradiction detection in real-time
3. Display research gaps as user explores
4. Progressive loading that feels instant

Remember: We're competing with thought speed. Make it feel like magic.