# Project Leibniz - Test Plan & API Contracts

**Version:** 1.0  
**Date:** December 2024  
**Status:** Ready for Implementation

---

# PART 1: TEST PLAN

## 1. Test Strategy Overview

### 1.1 Testing Principles
- **Speed-First Testing:** Tests must not slow down the <200ms target
- **Progressive Coverage:** Start with critical path, expand as time allows
- **Real-World Scenarios:** Test with actual paper data, not just mocks
- **Performance as a Feature:** Latency tests are as important as functional tests

### 1.2 Test Levels

| Level | Focus | Tools | When |
|-------|-------|-------|------|
| Unit | Individual functions | pytest, jest | During development |
| Integration | Service interactions | pytest, supertest | After service complete |
| Performance | Latency & throughput | locust, k6 | Continuous |
| E2E | Full user flows | Playwright | Before demo |

## 2. Critical Path Tests

### 2.1 Query Performance Test Suite

```python
# tests/performance/test_query_latency.py
import pytest
import asyncio
import time
from statistics import mean, stdev, quantiles

class TestQueryPerformance:
    @pytest.mark.performance
    @pytest.mark.parametrize("query", [
        "transformer efficiency",
        "sparse attention mechanisms", 
        "what methods improve BERT performance",
        "contradictions in vision transformer papers"
    ])
    async def test_query_latency_under_200ms(self, api_client, query):
        """Critical: Ensure 95th percentile < 200ms"""
        latencies = []
        
        for _ in range(100):  # 100 requests
            start = time.perf_counter()
            response = await api_client.post("/api/v1/query", json={"query": query})
            latency = (time.perf_counter() - start) * 1000  # ms
            
            assert response.status_code == 200
            latencies.append(latency)
        
        # Calculate percentiles
        p50, p95, p99 = quantiles(latencies, n=100)[49], quantiles(latencies, n=100)[94], quantiles(latencies, n=100)[98]
        
        print(f"\nQuery: '{query}'")
        print(f"P50: {p50:.1f}ms, P95: {p95:.1f}ms, P99: {p99:.1f}ms")
        print(f"Mean: {mean(latencies):.1f}ms, StdDev: {stdev(latencies):.1f}ms")
        
        assert p95 < 200, f"P95 latency {p95:.1f}ms exceeds 200ms target"
        assert p50 < 100, f"P50 latency {p50:.1f}ms should be under 100ms"

    @pytest.mark.performance
    async def test_concurrent_query_performance(self, api_client):
        """Test performance under concurrent load"""
        async def make_query():
            start = time.perf_counter()
            await api_client.post("/api/v1/query", json={"query": "neural networks"})
            return (time.perf_counter() - start) * 1000
        
        # 50 concurrent requests
        latencies = await asyncio.gather(*[make_query() for _ in range(50)])
        p95 = quantiles(latencies, n=100)[94]
        
        assert p95 < 500, f"P95 under load {p95:.1f}ms exceeds 500ms"
```

### 2.2 Search Relevance Tests

```python
# tests/functional/test_search_relevance.py
class TestSearchRelevance:
    @pytest.mark.critical
    def test_vector_search_relevance(self, search_service):
        """Ensure semantic search returns relevant results"""
        test_cases = [
            {
                "query": "improving transformer efficiency",
                "must_contain": ["sparse", "pruning", "distillation", "quantization"],
                "must_not_contain": ["CNN", "RNN", "LSTM"]
            },
            {
                "query": "vision transformer architectures", 
                "must_contain": ["ViT", "DeiT", "Swin", "patch"],
                "must_not_contain": ["NLP", "BERT", "GPT"]
            }
        ]
        
        for test in test_cases:
            results = search_service.search(test["query"], limit=20)
            
            # Check at least one required term appears in top results
            top_10_text = " ".join([r.title + r.abstract for r in results[:10]])
            assert any(term.lower() in top_10_text.lower() for term in test["must_contain"])
            
            # Ensure irrelevant terms don't dominate
            irrelevant_count = sum(1 for term in test["must_not_contain"] 
                                 if term.lower() in top_10_text.lower())
            assert irrelevant_count < 2, "Too many irrelevant results"
```

### 2.3 Intelligence Feature Tests

```python
# tests/functional/test_contradiction_detection.py
class TestContradictionDetection:
    def test_finds_known_contradictions(self, neo4j_client):
        """Test contradiction detection on known cases"""
        # Insert test papers with contradictory claims
        neo4j_client.run("""
            CREATE (p1:Paper {id: 'test1', title: 'BERT-base achieves 92.1 F1 on SQuAD'})
            CREATE (p2:Paper {id: 'test2', title: 'BERT-base limited to 89.3 F1 on SQuAD'})
            CREATE (p1)-[:CLAIMS]->(c1:Claim {metric: 'F1', dataset: 'SQuAD', value: 92.1})
            CREATE (p2)-[:CLAIMS]->(c2:Claim {metric: 'F1', dataset: 'SQuAD', value: 89.3})
        """)
        
        contradictions = find_contradictions()
        
        assert len(contradictions) >= 1
        assert any(c.involves_papers(['test1', 'test2']) for c in contradictions)
        assert abs(contradictions[0].delta) > 2.0  # Significant difference

    def test_gap_analysis_accuracy(self, gap_analyzer):
        """Test research gap identification"""
        gaps = gap_analyzer.find_unexplored_combinations()
        
        # Verify gaps are actually unexplored
        for gap in gaps[:10]:  # Check top 10
            papers = search_papers(f"{gap.method} {gap.dataset}")
            assert len(papers) == 0, f"Gap {gap} is not actually unexplored"
```

## 3. Test Data Generation

### 3.1 Synthetic Test Data

```python
# scripts/generate_test_data.py
import json
import random
from faker import Faker
import numpy as np

fake = Faker()

class TestDataGenerator:
    def __init__(self):
        self.methods = ["BERT", "GPT", "ViT", "ResNet", "Transformer", "CLIP"]
        self.datasets = ["ImageNet", "COCO", "SQuAD", "GLUE", "WikiText"]
        self.metrics = ["accuracy", "F1", "perplexity", "mAP", "BLEU"]
        
    def generate_paper(self, paper_id: int) -> dict:
        method = random.choice(self.methods)
        dataset = random.choice(self.datasets)
        
        return {
            "id": f"test_paper_{paper_id}",
            "title": f"{method} Improvements on {dataset}: {fake.catch_phrase()}",
            "abstract": self._generate_abstract(method, dataset),
            "year": random.randint(2020, 2024),
            "venue": random.choice(["ICLR", "NeurIPS", "ICML"]),
            "authors": [fake.name() for _ in range(random.randint(2, 6))],
            "embedding": np.random.randn(1536).tolist(),  # Fake embedding
            "claims": self._generate_claims(method, dataset)
        }
    
    def _generate_abstract(self, method: str, dataset: str) -> str:
        templates = [
            f"We propose improvements to {method} that achieve state-of-the-art results on {dataset}. "
            f"Our approach combines {fake.word()} attention with {fake.word()} regularization. "
            f"Experiments show {random.randint(2, 10)}% improvement over baselines.",
            
            f"This paper introduces {fake.word()}-{method}, a novel variant achieving "
            f"{random.uniform(85, 99):.1f}% accuracy on {dataset}. "
            f"Key innovations include {fake.word()} pooling and {fake.word()} normalization."
        ]
        return random.choice(templates)
    
    def _generate_claims(self, method: str, dataset: str) -> list:
        metric = random.choice(self.metrics)
        value = random.uniform(70, 99)
        
        return [{
            "metric": metric,
            "dataset": dataset,
            "method": method,
            "value": value
        }]
    
    def generate_dataset(self, n_papers: int = 1000) -> list:
        return [self.generate_paper(i) for i in range(n_papers)]

# Generate test data
if __name__ == "__main__":
    generator = TestDataGenerator()
    papers = generator.generate_dataset(1000)
    
    with open("data/test_papers.json", "w") as f:
        json.dump(papers, f, indent=2)
```

## 4. Continuous Testing

### 4.1 Performance Monitoring

```python
# tests/monitoring/continuous_performance.py
import time
import requests
from prometheus_client import Histogram, Counter, Gauge

# Metrics
query_duration = Histogram('test_query_duration_seconds', 'Query duration in tests')
query_errors = Counter('test_query_errors_total', 'Total query errors in tests')
active_connections = Gauge('test_active_connections', 'Active WebSocket connections')

class ContinuousMonitor:
    def __init__(self, api_url: str):
        self.api_url = api_url
        
    @query_duration.time()
    def test_query(self, query: str):
        try:
            response = requests.post(
                f"{self.api_url}/api/v1/query",
                json={"query": query},
                timeout=1.0  # 1 second timeout
            )
            response.raise_for_status()
            return response.json()
        except Exception as e:
            query_errors.inc()
            raise
    
    def run_continuous_tests(self, interval: int = 10):
        """Run tests every N seconds"""
        test_queries = [
            "transformer efficiency",
            "contradictions in BERT papers",
            "vision transformer improvements",
            "sparse attention mechanisms"
        ]
        
        while True:
            for query in test_queries:
                try:
                    result = self.test_query(query)
                    print(f"✅ Query '{query}' returned {len(result['papers'])} papers")
                except Exception as e:
                    print(f"❌ Query '{query}' failed: {e}")
            
            time.sleep(interval)
```

## 5. Test Execution Plan

### 5.1 During Development (Hours 0-40)

```bash
# Run unit tests on save
watchmedo shell-command \
    --patterns="*.py" \
    --recursive \
    --command='pytest ${watch_src_path} -v'

# Run performance tests every hour
while true; do
    pytest tests/performance -v --benchmark
    sleep 3600
done
```

### 5.2 Pre-Demo Testing (Hours 40-44)

```bash
#!/bin/bash
# scripts/pre-demo-tests.sh

echo "🧪 Running pre-demo test suite..."

# 1. Functional tests
pytest tests/functional -v || exit 1

# 2. Performance benchmarks
python scripts/benchmark.py --full || exit 1

# 3. Load testing
locust -f tests/load/locustfile.py \
    --headless \
    --users 50 \
    --spawn-rate 5 \
    --run-time 60s

# 4. E2E tests
pytest tests/e2e -v || exit 1

# 5. Demo scenario validation
python scripts/validate_demo_scenarios.py || exit 1

echo "✅ All tests passed! Ready for demo"
```

---

# PART 2: API CONTRACTS

## 1. OpenAPI Specification

```yaml
openapi: 3.0.0
info:
  title: Project Leibniz API
  version: 1.0.0
  description: Research at the speed of thought

servers:
  - url: http://localhost:3000/api/v1
    description: Development server

paths:
  /query:
    post:
      summary: Execute semantic search query
      operationId: searchPapers
      tags: [Search]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/QueryRequest'
      responses:
        '200':
          description: Search results
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/QueryResponse'
        '400':
          $ref: '#/components/responses/BadRequest'
        '500':
          $ref: '#/components/responses/ServerError'

  /synthesis:
    post:
      summary: Generate research synthesis
      operationId: generateSynthesis
      tags: [Intelligence]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/SynthesisRequest'
      responses:
        '200':
          description: Generated synthesis
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/SynthesisResponse'

  /contradictions:
    get:
      summary: Find contradicting papers
      operationId: findContradictions
      tags: [Intelligence]
      parameters:
        - name: topic
          in: query
          schema:
            type: string
          description: Filter by topic
        - name: min_delta
          in: query
          schema:
            type: number
          description: Minimum difference threshold
      responses:
        '200':
          description: List of contradictions
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ContradictionsResponse'

  /gaps:
    get:
      summary: Identify research gaps
      operationId: findGaps
      tags: [Intelligence]
      parameters:
        - name: domain
          in: query
          schema:
            type: string
            enum: [vision, nlp, multimodal, general]
      responses:
        '200':
          description: Research opportunities
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/GapsResponse'

  /health:
    get:
      summary: Health check
      operationId: healthCheck
      tags: [System]
      responses:
        '200':
          description: Service healthy
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/HealthResponse'

components:
  schemas:
    QueryRequest:
      type: object
      required: [query]
      properties:
        query:
          type: string
          minLength: 1
          maxLength: 500
          example: "transformer efficiency improvements"
        filters:
          $ref: '#/components/schemas/SearchFilters'
        limit:
          type: integer
          minimum: 1
          maximum: 100
          default: 20
        include_graph:
          type: boolean
          default: false
          description: Include graph neighborhood
        include_contradictions:
          type: boolean
          default: true

    QueryResponse:
      type: object
      required: [query_id, papers, processing_time_ms]
      properties:
        query_id:
          type: string
          format: uuid
        papers:
          type: array
          items:
            $ref: '#/components/schemas/Paper'
        suggestions:
          type: array
          items:
            type: string
          description: Related query suggestions
        contradictions:
          type: array
          items:
            $ref: '#/components/schemas/Contradiction'
        graph:
          $ref: '#/components/schemas/GraphData'
        processing_time_ms:
          type: number
          example: 145.3

    Paper:
      type: object
      required: [id, title, abstract, year, venue, relevance_score]
      properties:
        id:
          type: string
        title:
          type: string
        abstract:
          type: string
        year:
          type: integer
        venue:
          type: string
        authors:
          type: array
          items:
            type: string
        relevance_score:
          type: number
          minimum: 0
          maximum: 1
        snippet:
          type: string
          description: Highlighted matching text
        methods:
          type: array
          items:
            type: string
        claims:
          type: array
          items:
            $ref: '#/components/schemas/Claim'

    Claim:
      type: object
      properties:
        metric:
          type: string
          example: "accuracy"
        dataset:
          type: string
          example: "ImageNet"
        value:
          type: number
          example: 92.3
        context:
          type: string

    SearchFilters:
      type: object
      properties:
        year_range:
          type: array
          items:
            type: integer
          minItems: 2
          maxItems: 2
          example: [2020, 2024]
        venues:
          type: array
          items:
            type: string
            enum: [ICLR, NeurIPS, ICML, CVPR, ACL, EMNLP]
        authors:
          type: array
          items:
            type: string

    SynthesisRequest:
      type: object
      required: [paper_ids, synthesis_type]
      properties:
        paper_ids:
          type: array
          items:
            type: string
          minItems: 1
          maxItems: 50
        synthesis_type:
          type: string
          enum: [related_work, summary, comparison, timeline]
        max_words:
          type: integer
          minimum: 50
          maximum: 1000
          default: 250
        style:
          type: string
          enum: [academic, blog, bullet_points]
          default: academic

    SynthesisResponse:
      type: object
      required: [synthesis_id, content, citations]
      properties:
        synthesis_id:
          type: string
          format: uuid
        content:
          type: string
          description: Generated text with inline citations
        citations:
          type: array
          items:
            $ref: '#/components/schemas/Citation'
        word_count:
          type: integer
        generation_time_ms:
          type: number

    Citation:
      type: object
      properties:
        text:
          type: string
          description: Text being cited
        paper_ids:
          type: array
          items:
            type: string
        location:
          type: object
          properties:
            start:
              type: integer
            end:
              type: integer

    Contradiction:
      type: object
      properties:
        paper1:
          $ref: '#/components/schemas/Paper'
        paper2:
          $ref: '#/components/schemas/Paper'
        claim:
          type: string
          description: What they disagree about
        delta:
          type: number
          description: Magnitude of disagreement
        explanation:
          type: string

    GapsResponse:
      type: object
      properties:
        gaps:
          type: array
          items:
            $ref: '#/components/schemas/ResearchGap'
        total_found:
          type: integer

    ResearchGap:
      type: object
      properties:
        method:
          type: string
        dataset:
          type: string
        related_papers:
          type: array
          items:
            type: string
        potential_impact:
          type: string
          enum: [low, medium, high]
        reasoning:
          type: string

    HealthResponse:
      type: object
      properties:
        status:
          type: string
          enum: [healthy, degraded, unhealthy]
        services:
          type: object
          additionalProperties:
            type: object
            properties:
              status:
                type: string
              latency_ms:
                type: number
        version:
          type: string

    GraphData:
      type: object
      properties:
        nodes:
          type: array
          items:
            type: object
            properties:
              id:
                type: string
              type:
                type: string
                enum: [paper, method, dataset, author]
              label:
                type: string
              properties:
                type: object
        edges:
          type: array
          items:
            type: object
            properties:
              source:
                type: string
              target:
                type: string
              type:
                type: string
                enum: [cites, extends, uses, contradicts]
              weight:
                type: number

  responses:
    BadRequest:
      description: Invalid request
      content:
        application/json:
          schema:
            type: object
            properties:
              error:
                type: string
              details:
                type: object

    ServerError:
      description: Internal server error
      content:
        application/json:
          schema:
            type: object
            properties:
              error:
                type: string
              request_id:
                type: string
```

## 2. WebSocket Protocol

```typescript
// WebSocket Events Specification
// ws://localhost:3000/ws

// Client → Server Events
interface ClientEvents {
  // Subscribe to query updates
  subscribe: {
    event: 'subscribe';
    data: {
      query_id: string;
      include_partial: boolean;
    };
  };

  // Live query (streaming results)
  live_query: {
    event: 'live_query';
    data: {
      query: string;
      filters?: SearchFilters;
    };
  };

  // Request graph exploration
  explore_graph: {
    event: 'explore_graph';
    data: {
      node_id: string;
      depth: number;
      types: ('cites' | 'extends' | 'contradicts')[];
    };
  };
}

// Server → Client Events  
interface ServerEvents {
  // Partial query result
  partial_result: {
    event: 'partial_result';
    data: {
      query_id: string;
      papers: Paper[];
      is_final: boolean;
      timestamp: number;
    };
  };

  // Graph update
  graph_update: {
    event: 'graph_update';
    data: {
      added_nodes: GraphNode[];
      added_edges: GraphEdge[];
      removed_nodes: string[];
      removed_edges: string[];
    };
  };

  // Suggestion update
  suggestions: {
    event: 'suggestions';
    data: {
      query_id: string;
      suggestions: string[];
    };
  };

  // Error event
  error: {
    event: 'error';
    data: {
      code: string;
      message: string;
      details?: any;
    };
  };
}

// Connection protocol
const ws = new WebSocket('ws://localhost:3000/ws');

ws.on('open', () => {
  // Send heartbeat every 30s
  setInterval(() => {
    ws.send(JSON.stringify({ event: 'ping' }));
  }, 30000);
});

ws.on('message', (data) => {
  const event = JSON.parse(data);
  
  switch (event.event) {
    case 'partial_result':
      updateResults(event.data);
      break;
    case 'graph_update':
      updateGraph(event.data);
      break;
    // ... handle other events
  }
});
```

## 3. Example API Calls

### 3.1 Basic Query

```bash
# Simple search
curl -X POST http://localhost:3000/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "transformer efficiency improvements",
    "limit": 10
  }'

# Response (< 200ms)
{
  "query_id": "550e8400-e29b-41d4-a716-446655440000",
  "papers": [
    {
      "id": "paper_2023_0142",
      "title": "Sparse Transformers: 10x Efficiency with Minimal Loss",
      "abstract": "We propose a sparse attention mechanism that...",
      "year": 2023,
      "venue": "NeurIPS",
      "relevance_score": 0.94,
      "snippet": "...sparse attention mechanism that achieves <em>10x efficiency</em>..."
    }
  ],
  "suggestions": ["sparse attention", "pruning transformers", "quantization"],
  "processing_time_ms": 127.4
}
```

### 3.2 Find Contradictions

```bash
curl http://localhost:3000/api/v1/contradictions?topic=bert+performance

# Response
{
  "contradictions": [
    {
      "paper1": {
        "id": "p_123",
        "title": "BERT Achieves 92.1 F1 on SQuAD",
        "claim": { "metric": "F1", "value": 92.1 }
      },
      "paper2": {
        "id": "p_456", 
        "title": "Revisiting BERT: Maximum 89.3 F1 on SQuAD",
        "claim": { "metric": "F1", "value": 89.3 }
      },
      "delta": 2.8,
      "explanation": "Different evaluation protocols: paper1 uses dev set, paper2 uses test set"
    }
  ]
}
```

### 3.3 Generate Synthesis

```bash
curl -X POST http://localhost:3000/api/v1/synthesis \
  -H "Content-Type: application/json" \
  -d '{
    "paper_ids": ["p_123", "p_456", "p_789"],
    "synthesis_type": "related_work",
    "max_words": 200
  }'

# Response (streaming possible)
{
  "synthesis_id": "syn_987654321",
  "content": "Recent advances in transformer efficiency have focused on three main approaches. Sparse attention mechanisms [1,2] reduce computational complexity from O(n²) to O(n log n) while maintaining performance. Quantization methods [2] compress model weights to 8-bit or even 4-bit representations. Knowledge distillation [3] transfers capabilities from large models to smaller ones, achieving 90% of teacher performance with 10x fewer parameters.",
  "citations": [
    {"text": "Sparse attention mechanisms", "paper_ids": ["p_123", "p_456"]},
    {"text": "Quantization methods", "paper_ids": ["p_456"]},
    {"text": "Knowledge distillation", "paper_ids": ["p_789"]}
  ],
  "word_count": 72,
  "generation_time_ms": 1842
}
```

## 4. Error Responses

```json
// 400 Bad Request
{
  "error": "Invalid query",
  "details": {
    "field": "query",
    "reason": "Query cannot be empty"
  }
}

// 429 Rate Limited
{
  "error": "Rate limit exceeded",
  "details": {
    "limit": 100,
    "window": "1h",
    "retry_after": 1234
  }
}

// 500 Internal Error
{
  "error": "Internal server error",
  "request_id": "req_abc123",
  "message": "Please try again later"
}
```

---

**Test Coverage Target:** 80% for critical paths  
**API Compliance:** OpenAPI 3.0 validated  
**Next Step:** Begin implementation!