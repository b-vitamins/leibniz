# Project Leibniz - Quick Start Implementation Guide

**Version:** 1.0  
**Date:** June 2025
**Purpose:** Your coding companion for Hours 0-48

---

## 🚀 HOUR 0-3: SETUP SPRINT

### Pre-Flight Checklist (10 minutes)
```bash
# 1. Check you have everything
□ Terminal open
□ VS Code/IDE ready  
□ Coffee/Red Bull supply
□ OpenAI API key ready
□ 100GB free disk space
□ This guide open in a browser

# 2. Create workspace
mkdir -p ~/weekend-sprint/project-leibniz
cd ~/weekend-sprint/project-leibniz

# 3. Start a timer (seriously!)
echo "Sprint started at: $(date)" > SPRINT_LOG.md
```

### The Golden Path Setup (20 minutes)
```bash
# 1. Initialize repository
git init
cat > .gitignore << 'EOF'
.env
*.pyc
__pycache__/
node_modules/
data/pdfs/
data/processed/
*.log
.DS_Store
venv/
.pytest_cache/
EOF

# 2. Create project structure in one go
mkdir -p {services/{gateway,query,synthesis,prediction},frontend/src,data/{pdfs,processed,embeddings},scripts,tests/{unit,integration,performance,e2e},docs}

# 3. Copy this master docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # Data stores - start these first!
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes: ["redis_data:/data"]
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s

  neo4j:
    image: neo4j:5-community  
    ports: ["7474:7474", "7687:7687"]
    environment:
      - NEO4J_AUTH=neo4j/leibniz123
      - NEO4J_dbms_memory_heap_max__size=4G
    volumes: ["neo4j_data:/data"]

  qdrant:
    image: qdrant/qdrant:latest
    ports: ["6333:6333"]
    volumes: ["qdrant_data:/qdrant/storage"]

  meilisearch:
    image: getmeili/meilisearch:v1.5
    ports: ["7700:7700"]
    environment:
      - MEILI_MASTER_KEY=leibniz_dev_key
    volumes: ["meilisearch_data:/meili_data"]

  grobid:
    image: lfoppiano/grobid:0.7.3
    ports: ["8070:8070"]

volumes:
  redis_data:
  neo4j_data:
  qdrant_data:
  meilisearch_data:
EOF

# 4. Create .env file
cat > .env << 'EOF'
OPENAI_API_KEY=sk-YOUR-KEY-HERE
REDIS_URL=redis://localhost:6379
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=leibniz123
QDRANT_HOST=localhost
QDRANT_PORT=6333
MEILISEARCH_HOST=http://localhost:7700
MEILISEARCH_KEY=leibniz_dev_key
EOF

echo "⚠️  STOP! Edit .env with your OpenAI API key now!"
read -p "Press enter when done..."

# 5. Start infrastructure
docker-compose up -d

# 6. Quick health check
sleep 10
curl -s localhost:6379 && echo "✅ Redis OK" || echo "❌ Redis FAIL"
curl -s localhost:7474 && echo "✅ Neo4j OK" || echo "❌ Neo4j FAIL"  
curl -s localhost:6333 && echo "✅ QDrant OK" || echo "❌ QDrant FAIL"
curl -s localhost:7700 && echo "✅ Meilisearch OK" || echo "❌ Meilisearch FAIL"
```

### Critical First Hour Saves (Complete these NOW!)

#### 1. Query Service Skeleton (Copy-paste starter)
```python
# services/query/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import time
import asyncio
from typing import List, Optional
import numpy as np

app = FastAPI(title="Leibniz Query Service")

# Critical: Connection pooling from the start!
from qdrant_client import QdrantClient
from neo4j import AsyncGraphDatabase
import redis
import httpx

# Initialize clients with connection pools
qdrant = QdrantClient(host="localhost", port=6333)
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
neo4j_driver = AsyncGraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "leibniz123"))

# Request/Response models
class QueryRequest(BaseModel):
    query: str
    limit: int = 20
    filters: Optional[dict] = None

class Paper(BaseModel):
    id: str
    title: str
    abstract: str
    relevance_score: float
    year: int
    venue: str

class QueryResponse(BaseModel):
    query_id: str
    papers: List[Paper]
    processing_time_ms: float
    suggestions: List[str] = []

@app.post("/api/v1/query", response_model=QueryResponse)
async def search_papers(request: QueryRequest):
    start_time = time.perf_counter()
    
    # Check cache first - CRITICAL for <200ms!
    cache_key = f"query:{hash(request.query)}"
    cached = redis_client.get(cache_key)
    if cached:
        return QueryResponse.parse_raw(cached)
    
    # TODO: Implement parallel search
    # For now, return mock data to test the flow
    papers = [
        Paper(
            id="test_1",
            title="Test Paper on Transformers",
            abstract="This is a test abstract about transformer efficiency...",
            relevance_score=0.95,
            year=2023,
            venue="NeurIPS"
        )
    ]
    
    processing_time = (time.perf_counter() - start_time) * 1000
    
    response = QueryResponse(
        query_id=f"q_{int(time.time())}",
        papers=papers,
        processing_time_ms=processing_time,
        suggestions=["transformer", "efficiency", "attention"]
    )
    
    # Cache for next time
    redis_client.setex(cache_key, 3600, response.json())
    
    return response

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "query"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

#### 2. Frontend Skeleton with Instant Search
```typescript
// frontend/src/App.tsx
import React, { useState, useEffect, useCallback } from 'react';
import { debounce } from 'lodash';

interface Paper {
  id: string;
  title: string;
  abstract: string;
  relevance_score: number;
}

function App() {
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<Paper[]>([]);
  const [loading, setLoading] = useState(false);
  const [latency, setLatency] = useState<number>(0);

  // Debounced search - critical for feel
  const debouncedSearch = useCallback(
    debounce(async (searchQuery: string) => {
      if (!searchQuery.trim()) return;
      
      setLoading(true);
      const start = performance.now();
      
      try {
        const response = await fetch('http://localhost:3000/api/v1/query', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ query: searchQuery })
        });
        
        const data = await response.json();
        setResults(data.papers);
        setLatency(performance.now() - start);
      } catch (error) {
        console.error('Search failed:', error);
      } finally {
        setLoading(false);
      }
    }, 150), // 150ms debounce
    []
  );

  useEffect(() => {
    debouncedSearch(query);
  }, [query, debouncedSearch]);

  return (
    <div className="min-h-screen bg-gray-50 p-8">
      <div className="max-w-4xl mx-auto">
        <h1 className="text-4xl font-bold mb-8">
          Project Leibniz - Research at the Speed of Thought
        </h1>
        
        {/* Search Box */}
        <div className="relative mb-8">
          <input
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="What are you thinking about?"
            className="w-full px-4 py-3 text-lg border rounded-lg focus:outline-none focus:ring-2"
            autoFocus
          />
          {loading && (
            <div className="absolute right-4 top-4">
              <div className="animate-spin h-5 w-5 border-2 border-blue-500 rounded-full border-t-transparent" />
            </div>
          )}
        </div>

        {/* Latency display */}
        {latency > 0 && (
          <div className={`text-sm mb-4 ${latency < 200 ? 'text-green-600' : 'text-red-600'}`}>
            Response time: {latency.toFixed(0)}ms
          </div>
        )}

        {/* Results */}
        <div className="space-y-4">
          {results.map(paper => (
            <div key={paper.id} className="bg-white p-6 rounded-lg shadow-sm">
              <h3 className="font-semibold text-lg mb-2">{paper.title}</h3>
              <p className="text-gray-600 text-sm">{paper.abstract}</p>
              <div className="mt-2 text-xs text-gray-500">
                Relevance: {(paper.relevance_score * 100).toFixed(0)}%
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

export default App;
```

#### 3. Performance Test from the Start
```python
# tests/performance/test_baseline.py
import pytest
import asyncio
import httpx
import time
from statistics import mean, quantiles

@pytest.mark.asyncio
async def test_query_latency_baseline():
    """Run this IMMEDIATELY to set your baseline"""
    async with httpx.AsyncClient() as client:
        latencies = []
        
        # Warm up
        await client.post("http://localhost:8001/api/v1/query", 
                         json={"query": "test"})
        
        # Measure
        for _ in range(50):
            start = time.perf_counter()
            response = await client.post(
                "http://localhost:8001/api/v1/query",
                json={"query": "transformer efficiency"}
            )
            latency = (time.perf_counter() - start) * 1000
            
            assert response.status_code == 200
            latencies.append(latency)
        
        p50, p95 = quantiles(latencies, n=100)[49], quantiles(latencies, n=100)[94]
        
        print(f"\n🎯 BASELINE METRICS:")
        print(f"P50: {p50:.1f}ms")
        print(f"P95: {p95:.1f}ms") 
        print(f"Mean: {mean(latencies):.1f}ms")
        
        # Write to file for tracking
        with open("PERFORMANCE_LOG.md", "a") as f:
            f.write(f"\n## Hour 1 Baseline\n")
            f.write(f"- P50: {p50:.1f}ms\n")
            f.write(f"- P95: {p95:.1f}ms\n")
        
        # Set your target
        assert p95 < 500, f"Baseline P95 {p95:.1f}ms is too slow!"
```

## 📊 PERFORMANCE PATTERNS COOKBOOK

### Pattern 1: Cache Everything (Implement in Hour 4-6)
```python
# services/query/caching.py
from functools import wraps
import hashlib
import json

def cached(ttl_seconds=3600):
    """Decorator for Redis caching"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Create cache key from function name and args
            cache_key = f"{func.__name__}:{hashlib.md5(str(args).encode()).hexdigest()}"
            
            # Try cache first
            cached_result = redis_client.get(cache_key)
            if cached_result:
                return json.loads(cached_result)
            
            # Compute if not cached
            result = await func(*args, **kwargs)
            
            # Store in cache
            redis_client.setex(cache_key, ttl_seconds, json.dumps(result))
            
            return result
        return wrapper
    return decorator

# Usage:
@cached(ttl_seconds=3600)
async def get_embeddings(text: str) -> List[float]:
    # Expensive operation - perfect for caching
    return await openai_client.embeddings.create(input=text)
```

### Pattern 2: Parallel Everything (Implement in Hour 8-10)
```python
# services/query/parallel_search.py
async def parallel_search(query: str) -> Dict:
    """Execute all search strategies in parallel"""
    # Create all tasks
    tasks = {
        'vector': search_vector(query),
        'graph': search_graph(query),
        'keyword': search_keyword(query),
        'cache': check_cache(query)
    }
    
    # Wait for all with timeout
    results = {}
    done, pending = await asyncio.wait(
        tasks.values(),
        timeout=0.15,  # 150ms max wait
        return_when=asyncio.ALL_COMPLETED
    )
    
    # Cancel slow tasks
    for task in pending:
        task.cancel()
    
    # Collect results
    for name, task in tasks.items():
        if task in done:
            try:
                results[name] = await task
            except:
                results[name] = []
    
    return results
```

### Pattern 3: Progressive Loading (Implement in Hour 12-14)
```typescript
// frontend/src/hooks/useProgressiveSearch.ts
export function useProgressiveSearch() {
  const [results, setResults] = useState<Paper[]>([]);
  const [isComplete, setIsComplete] = useState(false);
  
  const search = useCallback(async (query: string) => {
    // Reset state
    setResults([]);
    setIsComplete(false);
    
    // Establish WebSocket for streaming
    const ws = new WebSocket('ws://localhost:3000/ws');
    
    ws.onmessage = (event) => {
      const data = JSON.parse(event.data);
      
      if (data.event === 'partial_result') {
        // Append new results as they arrive
        setResults(prev => [...prev, ...data.papers]);
        
        if (data.is_final) {
          setIsComplete(true);
          ws.close();
        }
      }
    };
    
    // Send query
    ws.onopen = () => {
      ws.send(JSON.stringify({
        event: 'live_query',
        data: { query }
      }));
    };
    
    return () => ws.close();
  }, []);
  
  return { results, isComplete, search };
}
```

## 🚨 CRITICAL PATH OPTIMIZATIONS

### Hour 16-20: The Performance Sprint

```python
# THE MOST IMPORTANT OPTIMIZATION - Pre-computed Embeddings
# scripts/precompute_embeddings.py

async def precompute_common_queries():
    """Run this BEFORE demo!"""
    common_queries = [
        "transformer efficiency",
        "vision transformer improvements", 
        "bert optimization",
        "attention mechanisms",
        "sparse transformers",
        # Add 50+ common queries
    ]
    
    for query in common_queries:
        # Generate embedding
        embedding = await get_embedding(query)
        
        # Pre-compute search results
        results = await search_papers(embedding)
        
        # Cache everything
        cache_key = f"precomputed:{query}"
        redis_client.setex(cache_key, 86400, json.dumps({
            'embedding': embedding,
            'results': results,
            'timestamp': time.time()
        }))
        
    print(f"✅ Pre-computed {len(common_queries)} queries")
```

### Hour 24-28: The Intelligence Sprint

```python
# services/query/contradictions.py
# FAST contradiction detection using pre-computed index

class ContradictionDetector:
    def __init__(self):
        # Pre-build contradiction index on startup
        self.contradiction_index = {}
        
    async def build_index(self):
        """Run this ONCE at startup"""
        query = """
        MATCH (p1:Paper)-[:CLAIMS]->(c1:Claim),
              (p2:Paper)-[:CLAIMS]->(c2:Claim)
        WHERE c1.metric = c2.metric 
          AND c1.dataset = c2.dataset
          AND abs(c1.value - c2.value) > 0.1 * c1.value
        RETURN p1.id, p2.id, c1, c2
        LIMIT 1000
        """
        
        async with neo4j_driver.session() as session:
            results = await session.run(query)
            
            async for record in results:
                key = f"{record['c1']['metric']}:{record['c1']['dataset']}"
                if key not in self.contradiction_index:
                    self.contradiction_index[key] = []
                
                self.contradiction_index[key].append({
                    'paper1': record['p1.id'],
                    'paper2': record['p2.id'],
                    'delta': abs(record['c1']['value'] - record['c2']['value'])
                })
    
    def find_contradictions(self, topic: str) -> List[Dict]:
        """INSTANT contradiction lookup"""
        # This is now O(1) instead of a graph query!
        return self.contradiction_index.get(topic, [])
```

## 🎯 DEMO SCENARIO SCRIPTS

### The "Wow" Moments to Practice

```python
# scripts/demo_scenarios.py

DEMO_QUERIES = [
    {
        "query": "what methods improve transformer efficiency",
        "highlight": "Watch the <200ms response time!",
        "expected": ["sparse attention", "quantization", "distillation"]
    },
    {
        "query": "contradictions in bert squad performance", 
        "highlight": "Instant contradiction detection!",
        "expected": ["92.1 vs 89.3 F1 score discrepancy"]
    },
    {
        "query": "unexplored combinations vision transformers",
        "highlight": "AI-powered research gap analysis!",
        "expected": ["ViT + neural architecture search", "DeiT + few-shot learning"]
    }
]

async def run_demo():
    """Practice your demo flow"""
    print("🎬 DEMO PRACTICE RUN\n")
    
    for scenario in DEMO_QUERIES:
        print(f"Query: '{scenario['query']}'")
        print(f"Highlight: {scenario['highlight']}")
        
        start = time.perf_counter()
        response = await search(scenario['query'])
        latency = (time.perf_counter() - start) * 1000
        
        print(f"✅ Response in {latency:.0f}ms")
        print(f"Found: {len(response['papers'])} papers\n")
        
        # Verify expected results
        for expected in scenario['expected']:
            assert any(expected in str(response) for expected in scenario['expected'])
```

## ⚡ SPEED HACKS

### 1. The "Fake It Till You Make It" Pattern
```python
# For demo purposes - pre-warm everything!
async def prewarm_demo():
    """Run 5 minutes before demo"""
    # Load all data into memory
    await load_papers_to_memory()
    
    # Pre-run all demo queries
    for query in DEMO_QUERIES:
        await search(query['query'])
    
    # Force garbage collection
    import gc
    gc.collect()
    
    print("✅ System pre-warmed for demo")
```

### 2. The "Perception of Speed" Tricks
```typescript
// Show something IMMEDIATELY
const SearchResults = () => {
  const [query, setQuery] = useState('');
  const [skeleton, setSkeleton] = useState(false);
  
  const handleSearch = (q: string) => {
    setQuery(q);
    // Show skeleton INSTANTLY (0ms)
    setSkeleton(true);
    
    // Then fetch real results
    fetchResults(q).then(results => {
      setSkeleton(false);
      setResults(results);
    });
  };
  
  return skeleton ? <SkeletonLoader /> : <Results />;
};
```

## 🔥 COMMON PITFALLS & FIXES

### Pitfall 1: "Docker is eating all my RAM"
```bash
# Fix: Limit container memory
docker update --memory="2g" --memory-swap="2g" project-leibniz_neo4j_1
```

### Pitfall 2: "OpenAI rate limits killing me"
```python
# Fix: Aggressive caching + batching
EMBEDDING_CACHE = {}  # In-memory cache

async def get_embedding_cached(text: str):
    if text in EMBEDDING_CACHE:
        return EMBEDDING_CACHE[text]
    
    # Batch multiple requests
    if len(PENDING_EMBEDDINGS) < 10:
        PENDING_EMBEDDINGS.append(text)
        await asyncio.sleep(0.1)  # Wait for more
    
    # Process batch
    embeddings = await openai.embeddings.create(
        input=PENDING_EMBEDDINGS,
        model="text-embedding-ada-002"
    )
    
    # Cache all
    for text, emb in zip(PENDING_EMBEDDINGS, embeddings):
        EMBEDDING_CACHE[text] = emb
```

### Pitfall 3: "Neo4j queries are slow"
```cypher
// Fix: Add indexes IMMEDIATELY
CREATE INDEX paper_year IF NOT EXISTS FOR (p:Paper) ON (p.year);
CREATE INDEX paper_venue IF NOT EXISTS FOR (p:Paper) ON (p.venue);
CREATE INDEX claim_metric IF NOT EXISTS FOR (c:Claim) ON (c.metric);

// Use query hints
MATCH (p:Paper)
USING INDEX p:Paper(year)
WHERE p.year >= 2020
RETURN p LIMIT 100
```

## 📱 QUICK MONITORING

```bash
# Terminal 1: Watch everything
watch -n 1 'docker stats --no-stream'

# Terminal 2: Track latencies
tail -f logs/performance.log | grep "P95"

# Terminal 3: Error watch
tail -f logs/*.log | grep -E "ERROR|FAIL|Exception"
```

## 🏁 FINAL HOUR CHECKLIST

### Hour 44-48: Demo Polish
```bash
□ Run full test suite one last time
□ Clear all caches and re-warm
□ Practice demo flow 3 times
□ Record backup video
□ Prepare "if things go wrong" plan
□ Screenshot best performance metrics
□ Git commit everything
□ Deploy to public URL
□ Share with the world!
```

## 💡 THE MOST IMPORTANT REMINDER

**If you're behind schedule:**
1. Skip features, not performance
2. Fake the demo data if needed
3. Focus on the "wow" of <200ms search
4. Polish what works, hide what doesn't
5. Remember: A fast, simple demo > slow, complex one

---

**Your mantra for the weekend:**  
"Make it work, make it fast, make it amazing!"

**Emergency contact:** Keep this guide open. Everything you need is here.

**Go build something incredible! 🚀**