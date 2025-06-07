# Project Leibniz - System Architecture Design Document

**Version:** 1.0  
**Date:** December 2024  
**Status:** Draft  
**Classification:** Internal Development

## 1. Introduction

### 1.1 Purpose
This document provides the technical architecture design for Project Leibniz, translating the requirements from the RA document into concrete technical decisions, component designs, and implementation strategies.

### 1.2 Scope
Covers the complete system architecture for the 48-hour prototype, including all components, interfaces, data flows, and deployment strategies.

### 1.3 Architecture Principles
1. **Speed First:** Every decision optimizes for <200ms response times
2. **Fail Fast:** Graceful degradation over system failure
3. **Cache Everything:** Pre-compute and cache aggressively
4. **Progressive Enhancement:** Show something immediately, enhance progressively
5. **Local First:** Minimize network hops for critical path

## 2. System Architecture Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Client Layer (React)                      │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────────────────┐ │
│  │Query Input  │ │ Graph Canvas │ │ Results/Method Cards     │ │
│  │(Autocomplete)│ │ (D3.js)      │ │ (Progressive Loading)    │ │
│  └─────────────┘ └──────────────┘ └──────────────────────────┘ │
└────────────────────────────┬────────────────────────────────────┘
                             │ WebSocket + REST
┌────────────────────────────▼────────────────────────────────────┐
│                    API Gateway (Node.js/Express)                 │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────────────────┐│
│  │Rate Limiter  │ │ Auth/CORS    │ │ Request Router           ││
│  └──────────────┘ └──────────────┘ └──────────────────────────┘│
└────────────────────────────┬────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                    Application Services Layer                    │
│ ┌───────────────┐ ┌────────────────┐ ┌──────────────────────┐ │
│ │ Query Service │ │Synthesis Service│ │ Prediction Service   │ │
│ │ (FastAPI)     │ │ (FastAPI)      │ │ (FastAPI)            │ │
│ └───────┬───────┘ └────────┬───────┘ └──────────┬───────────┘ │
└─────────┼──────────────────┼────────────────────┼──────────────┘
          │                  │                     │
┌─────────▼──────────────────▼─────────────────────▼──────────────┐
│                      Data Access Layer                           │
│ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐│
│ │   QDrant    │ │   Neo4j     │ │ Meilisearch │ │   Redis    ││
│ │(Embeddings) │ │(Graph Store)│ │(Text Search)│ │  (Cache)   ││
│ └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘│
└──────────────────────────────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────┐
│                   Data Processing Pipeline                       │
│ ┌──────────────┐ ┌──────────────┐ ┌────────────────────────────┐│
│ │GROBID Parser │ │OpenAI Client │ │ Pre-computation Engine     ││
│ └──────────────┘ └──────────────┘ └────────────────────────────┘│
└──────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Responsibilities

| Component | Primary Responsibility | Performance Target |
|-----------|----------------------|-------------------|
| Client Layer | Progressive UI rendering | <50ms interaction feedback |
| API Gateway | Request routing, caching | <10ms overhead |
| Query Service | Semantic search orchestration | <150ms response |
| Synthesis Service | Content generation | <5s for summaries |
| Prediction Service | Autocomplete & suggestions | <50ms predictions |
| Data Access Layer | Optimized data retrieval | <50ms queries |

## 3. Detailed Component Design

### 3.1 Client Layer

#### 3.1.1 Technology Stack
- **Framework:** React 18 with Concurrent Features
- **State Management:** Zustand (lightweight, <8kb)
- **Styling:** Tailwind CSS (no runtime overhead)
- **Graphs:** D3.js with React wrapper
- **Build Tool:** Vite (fastest HMR)

#### 3.1.2 Performance Optimizations
```javascript
// Query Input Component with Optimistic Updates
const QueryInput = () => {
  const [query, setQuery] = useState('');
  const [predictions, setPredictions] = useState([]);
  const debouncedQuery = useDebounce(query, 50); // 50ms debounce
  
  // Optimistic prediction loading
  useEffect(() => {
    if (debouncedQuery) {
      // Show skeleton immediately
      setPredictions(SKELETON_PREDICTIONS);
      // Fetch real predictions
      fetchPredictions(debouncedQuery).then(setPredictions);
    }
  }, [debouncedQuery]);
  
  // Pre-fetch likely next queries
  useEffect(() => {
    predictions.forEach(p => prefetchQuery(p.query));
  }, [predictions]);
};
```

#### 3.1.3 WebSocket Protocol
```typescript
interface WSMessage {
  type: 'query' | 'result' | 'update' | 'prediction';
  id: string;
  timestamp: number;
  payload: any;
}

// Binary protocol for graph updates (50% size reduction)
const encodeGraphUpdate = (nodes: Node[], edges: Edge[]): ArrayBuffer => {
  // Custom binary encoding for maximum efficiency
};
```

### 3.2 API Gateway

#### 3.2.1 Architecture
```yaml
# docker-compose.yml excerpt
api-gateway:
  image: node:18-alpine
  environment:
    - REDIS_URL=redis://cache:6379
    - RATE_LIMIT=1000/min
  deploy:
    replicas: 2
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
    interval: 5s
```

#### 3.2.2 Caching Strategy
```javascript
// Multi-layer caching
const cacheMiddleware = async (req, res, next) => {
  const cacheKey = generateCacheKey(req);
  
  // L1: In-memory cache (10ms)
  const memoryCache = memoryLRU.get(cacheKey);
  if (memoryCache) return res.json(memoryCache);
  
  // L2: Redis cache (30ms)
  const redisCache = await redis.get(cacheKey);
  if (redisCache) {
    memoryLRU.set(cacheKey, redisCache);
    return res.json(redisCache);
  }
  
  // L3: Compute and cache
  res.on('finish', () => {
    const data = res.locals.data;
    memoryLRU.set(cacheKey, data);
    redis.setex(cacheKey, 3600, data); // 1hr TTL
  });
  
  next();
};
```

### 3.3 Query Service

#### 3.3.1 Query Processing Pipeline
```python
# FastAPI service
class QueryService:
    def __init__(self):
        self.qdrant = QdrantClient(host="localhost", port=6333)
        self.neo4j = Neo4jClient(uri="bolt://localhost:7687")
        self.meilisearch = MeiliClient("http://localhost:7700")
        
    async def process_query(self, query: str) -> QueryResult:
        # Parallel execution of all search strategies
        vector_task = asyncio.create_task(self._vector_search(query))
        graph_task = asyncio.create_task(self._graph_search(query))
        keyword_task = asyncio.create_task(self._keyword_search(query))
        
        # Wait max 150ms for results
        done, pending = await asyncio.wait(
            [vector_task, graph_task, keyword_task],
            timeout=0.15,
            return_when=asyncio.ALL_COMPLETED
        )
        
        # Cancel slow operations
        for task in pending:
            task.cancel()
            
        # Merge results with weights
        return self._merge_results(done)
```

#### 3.3.2 Vector Search Optimization
```python
# Pre-computed embeddings with quantization
class OptimizedVectorSearch:
    def __init__(self):
        # Use product quantization for 10x memory reduction
        self.index_params = {
            "metric": "cosine",
            "index_type": "IVF_PQ",
            "params": {
                "nlist": 1024,
                "m": 16,
                "nbits": 8
            }
        }
        
    async def search(self, embedding: List[float], limit: int = 10):
        # Search with optimized parameters
        results = await self.qdrant.search(
            collection_name="papers",
            query_vector=embedding,
            limit=limit,
            search_params={"nprobe": 10}  # Speed/accuracy tradeoff
        )
        return results
```

### 3.4 Graph Database Design

#### 3.4.1 Neo4j Schema
```cypher
// Optimized node structure
CREATE CONSTRAINT paper_id ON (p:Paper) ASSERT p.id IS UNIQUE;
CREATE INDEX paper_year ON :Paper(year);
CREATE INDEX method_name ON :Method(name);

// Materialized paths for common queries
CREATE (p1:Paper)-[:CITES]->(p2:Paper)
CREATE (p1:Paper)-[:CONTRADICTS {claim: $claim}]->(p2:Paper)
CREATE (p:Paper)-[:INTRODUCES]->(m:Method)
CREATE (m1:Method)-[:EXTENDS]->(m2:Method)

// Pre-computed graph algorithms
CALL gds.pageRank.write('paper-graph', {
  writeProperty: 'influence_score'
});
```

#### 3.4.2 Query Optimization
```cypher
// Optimized contradiction detection
MATCH (p1:Paper)-[c:CONTRADICTS]->(p2:Paper)
WHERE p1.year >= 2020
WITH p1, p2, c
LIMIT 100  // Prevent runaway queries
RETURN p1.title, p2.title, c.claim
ORDER BY p1.influence_score DESC
```

### 3.5 Synthesis Service

#### 3.5.1 OpenAI Integration
```python
class SynthesisService:
    def __init__(self):
        self.openai = OpenAI()
        self.token_limit = 4000
        
    async def generate_summary(self, papers: List[Paper]) -> str:
        # Intelligent chunking to fit context window
        context = self._build_context(papers)
        
        # Streaming response for progressive display
        stream = await self.openai.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": SYNTHESIS_PROMPT},
                {"role": "user", "content": context}
            ],
            stream=True,
            temperature=0.3,  # More deterministic
            max_tokens=500
        )
        
        # Stream tokens to client via WebSocket
        async for chunk in stream:
            yield chunk.choices[0].delta.content
```

### 3.6 Pre-computation Engine

#### 3.6.1 Nightly Processing Pipeline
```python
class PreComputationEngine:
    async def run_nightly(self):
        # Parallel processing tasks
        tasks = [
            self._compute_contradiction_matrix(),
            self._compute_method_combinations(),
            self._compute_influence_scores(),
            self._compute_common_queries(),
            self._update_embeddings_cache()
        ]
        
        await asyncio.gather(*tasks)
        
    async def _compute_contradiction_matrix(self):
        # Find all paper pairs with opposing claims
        query = """
        MATCH (p1:Paper), (p2:Paper)
        WHERE p1.id < p2.id
        AND EXISTS {
            MATCH (p1)-[:CLAIMS]->(c1:Claim),
                  (p2)-[:CLAIMS]->(c2:Claim)
            WHERE c1.metric = c2.metric
            AND c1.dataset = c2.dataset
            AND abs(c1.value - c2.value) > c1.value * 0.2
        }
        CREATE (p1)-[:CONTRADICTS]->(p2)
        """
        await self.neo4j.run(query)
```

## 4. Data Flow Architecture

### 4.1 Query Processing Flow
```
User Input
    ↓
[Client] Debounce & Validate
    ↓
[Gateway] Check Cache → HIT → Return
    ↓ MISS
[Query Service] Parse Intent
    ↓
[Parallel Execution]
    ├→ [QDrant] Vector Search (50ms)
    ├→ [Neo4j] Graph Traversal (100ms)
    └→ [Meilisearch] Keyword Match (30ms)
    ↓
[Merge & Rank] Weight-based fusion
    ↓
[Cache] Store result
    ↓
[Client] Progressive render
```

### 4.2 Data Ingestion Pipeline
```
PDF Files
    ↓
[GROBID] Parse → Structured JSON
    ↓
[Splitter] Chunk into sections
    ↓
[Parallel Processing]
    ├→ [OpenAI] Generate embeddings
    ├→ [NER] Extract entities
    └→ [Analyzer] Detect claims/methods
    ↓
[Parallel Storage]
    ├→ [QDrant] Store embeddings
    ├→ [Neo4j] Build graph
    └→ [Meilisearch] Index text
```

## 5. API Specifications

### 5.1 REST Endpoints

#### 5.1.1 Query Endpoint
```yaml
POST /api/v1/query
Content-Type: application/json

Request:
{
  "query": "transformer efficiency improvements",
  "filters": {
    "year_range": [2020, 2024],
    "venues": ["ICLR", "NeurIPS", "ICML"]
  },
  "limit": 20,
  "include_contradictions": true
}

Response (streaming):
{
  "query_id": "q_1234567890",
  "results": [
    {
      "paper_id": "p_123",
      "title": "Sparse Transformers...",
      "relevance_score": 0.95,
      "snippet": "We propose...",
      "contradictions": []
    }
  ],
  "suggestions": ["sparse attention", "quantization"],
  "processing_time_ms": 145
}
```

#### 5.1.2 Synthesis Endpoint
```yaml
POST /api/v1/synthesize
Content-Type: application/json

Request:
{
  "paper_ids": ["p_123", "p_456", "p_789"],
  "synthesis_type": "related_work",
  "max_words": 250
}

Response:
{
  "synthesis_id": "s_1234567890",
  "content": "Recent work in transformer efficiency...",
  "citations": [
    {"text": "sparse attention", "paper_ids": ["p_123"]},
    {"text": "quantization methods", "paper_ids": ["p_456", "p_789"]}
  ],
  "generation_time_ms": 3200
}
```

### 5.2 WebSocket Events

```typescript
// Client → Server
interface QueryMessage {
  type: 'query';
  id: string;
  query: string;
  stream: boolean;
}

// Server → Client
interface ResultMessage {
  type: 'partial_result' | 'final_result';
  query_id: string;
  data: {
    papers?: Paper[];
    graph_update?: GraphDelta;
    suggestions?: string[];
  };
  is_final: boolean;
}
```

## 6. Database Schemas

### 6.1 QDrant Collections
```python
# Papers collection
papers_collection = {
    "name": "papers",
    "vector_size": 1536,  # OpenAI embeddings
    "distance": "Cosine",
    "payload_schema": {
        "paper_id": "keyword",
        "title": "text",
        "year": "integer",
        "venue": "keyword",
        "section_type": "keyword"  # abstract, intro, method, etc.
    }
}

# Pre-computed queries collection (for instant autocomplete)
queries_collection = {
    "name": "common_queries",
    "vector_size": 1536,
    "payload_schema": {
        "query_text": "text",
        "frequency": "integer",
        "avg_results": "integer"
    }
}
```

### 6.2 Redis Cache Schema
```python
# Cache key patterns
CACHE_PATTERNS = {
    "query_result": "qr:{query_hash}",
    "paper_detail": "pd:{paper_id}",
    "graph_neighborhood": "gn:{node_id}:{depth}",
    "user_session": "us:{session_id}",
    "prediction": "pr:{query_prefix}"
}

# Cache TTLs (seconds)
CACHE_TTLS = {
    "query_result": 3600,      # 1 hour
    "paper_detail": 86400,     # 24 hours
    "graph_neighborhood": 3600,
    "user_session": 1800,      # 30 minutes
    "prediction": 300          # 5 minutes
}
```

## 7. Performance Engineering

### 7.1 Critical Path Optimization
```
Target: <200ms query response

Breakdown:
- Network latency: 20ms
- API Gateway: 10ms
- Query parsing: 5ms
- Parallel searches: 100ms (max of all)
  - Vector search: 50ms
  - Graph query: 100ms
  - Keyword search: 30ms
- Result merging: 15ms
- Response serialization: 10ms
- Network return: 20ms
- Client rendering: 20ms
------------------------
Total: 200ms
```

### 7.2 Optimization Techniques

#### 7.2.1 Database Optimizations
- QDrant: Product quantization, HNSW index tuning
- Neo4j: Warm cache, query result caching, index hints
- Meilisearch: Typo tolerance off for speed, limited facets
- Redis: Pipelining, connection pooling

#### 7.2.2 Application Optimizations
- Connection pooling (min: 10, max: 100)
- Async/await throughout
- Protobuf for binary data
- HTTP/2 with multiplexing
- Brotli compression

#### 7.2.3 Client Optimizations
- Service Worker for offline caching
- IndexedDB for local paper storage
- Virtual scrolling for large lists
- React.memo for expensive components
- Web Workers for graph layout

## 8. Security Architecture

### 8.1 API Security
```python
# Rate limiting by IP and session
RATE_LIMITS = {
    "global": "1000/hour",
    "per_ip": "100/hour",
    "per_session": "500/hour",
    "synthesis": "10/hour"  # Expensive operation
}

# API key validation for OpenAI proxy
@app.middleware("http")
async def validate_api_key(request: Request, call_next):
    if request.url.path.startswith("/api/v1/synthesis"):
        api_key = request.headers.get("X-API-Key")
        if not is_valid_api_key(api_key):
            return JSONResponse(status_code=401, content={"error": "Invalid API key"})
    return await call_next(request)
```

### 8.2 Data Security
- No PII stored
- Read-only database access
- Parameterized queries only
- Input sanitization
- CORS restricted to localhost (dev)

## 9. Deployment Architecture

### 9.1 Development Environment
```yaml
# docker-compose.yml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes:
      - redis_data:/data
      
  neo4j:
    image: neo4j:5-community
    ports: ["7474:7474", "7687:7687"]
    environment:
      - NEO4J_AUTH=neo4j/leibniz123
      - NEO4J_dbms_memory_heap_max__size=4G
    volumes:
      - neo4j_data:/data
      
  qdrant:
    image: qdrant/qdrant
    ports: ["6333:6333"]
    volumes:
      - qdrant_data:/qdrant/storage
      
  meilisearch:
    image: getmeili/meilisearch:v1.5
    ports: ["7700:7700"]
    environment:
      - MEILI_MASTER_KEY=leibniz_dev_key
    volumes:
      - meilisearch_data:/meili_data
      
  grobid:
    image: lfoppiano/grobid:0.7.3
    ports: ["8070:8070"]
    
  api-gateway:
    build: ./gateway
    ports: ["3000:3000"]
    depends_on:
      - redis
      - query-service
      
  query-service:
    build: ./services/query
    ports: ["8001:8001"]
    depends_on:
      - qdrant
      - neo4j
      - meilisearch
      
  frontend:
    build: ./frontend
    ports: ["5173:5173"]
    environment:
      - VITE_API_URL=http://localhost:3000

volumes:
  redis_data:
  neo4j_data:
  qdrant_data:
  meilisearch_data:
```

### 9.2 Production Considerations
- Kubernetes deployment ready
- Horizontal scaling for API services
- Read replicas for databases
- CDN for static assets
- Monitoring with Prometheus/Grafana

## 10. Development Tools

### 10.1 Code Quality
```json
// .eslintrc.json
{
  "extends": ["react-app", "plugin:react-hooks/recommended"],
  "rules": {
    "no-console": "warn",
    "prefer-const": "error"
  }
}

// pyrightconfig.json
{
  "typeCheckingMode": "strict",
  "reportUnusedVariable": "error",
  "reportUnusedImport": "error"
}
```

### 10.2 Testing Strategy
```python
# Performance test example
@pytest.mark.asyncio
async def test_query_performance():
    service = QueryService()
    
    start = time.time()
    result = await service.process_query("transformer efficiency")
    duration = time.time() - start
    
    assert duration < 0.2  # 200ms requirement
    assert len(result.papers) > 0
```

## 11. Monitoring and Observability

### 11.1 Metrics Collection
```python
# Prometheus metrics
query_histogram = Histogram(
    'query_duration_seconds',
    'Query processing time',
    buckets=[0.05, 0.1, 0.2, 0.5, 1.0]
)

cache_hit_counter = Counter(
    'cache_hits_total',
    'Number of cache hits',
    ['cache_level']  # L1, L2, L3
)
```

### 11.2 Logging Strategy
```python
# Structured logging
import structlog

logger = structlog.get_logger()

@query_histogram.time()
async def process_query(query: str):
    logger.info("query_received", query=query, timestamp=time.time())
    # ... processing ...
    logger.info("query_completed", query=query, duration_ms=duration)
```

## 12. Error Handling

### 12.1 Graceful Degradation
```python
async def process_query_with_fallback(query: str):
    try:
        # Try vector search first
        return await vector_search(query)
    except QdrantException:
        logger.warning("Vector search failed, falling back to keyword search")
        try:
            return await keyword_search(query)
        except MeilisearchException:
            logger.error("All search methods failed")
            return get_cached_popular_papers()
```

### 12.2 User-Friendly Errors
```typescript
const ERROR_MESSAGES = {
  TIMEOUT: "Taking longer than usual. Here's what we found so far...",
  NO_RESULTS: "No papers found. Try broadening your search.",
  SERVICE_ERROR: "Some features are temporarily slow. Basic search still works!"
};
```

## 13. Testing Architecture

### 13.1 Test Data Generation
```python
# Generate realistic test corpus
class TestDataGenerator:
    def generate_papers(self, count: int = 1000):
        papers = []
        for i in range(count):
            paper = {
                "id": f"test_p_{i}",
                "title": self.generate_title(),
                "abstract": self.generate_abstract(),
                "year": random.randint(2020, 2024),
                "venue": random.choice(["ICLR", "NeurIPS", "ICML"])
            }
            papers.append(paper)
        return papers
```

### 13.2 Load Testing
```python
# Locust configuration
class QuickstartUser(HttpUser):
    wait_time = between(0.1, 0.5)  # Aggressive load
    
    @task(3)
    def search_query(self):
        query = random.choice(COMMON_QUERIES)
        with self.client.post("/api/v1/query", 
                              json={"query": query},
                              catch_response=True) as response:
            if response.elapsed.total_seconds() > 0.2:
                response.failure("Query took >200ms")
```

## 14. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | Project Team | Initial architecture design |

---

**Document Status:** Ready for Review  
**Next Step:** Implementation Planning & Task Breakdown