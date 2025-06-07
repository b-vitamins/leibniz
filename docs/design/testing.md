# Project Leibniz - Test Plan & API Contracts

**Version:** 2.0  
**Date:** June 2025
**Status:** Revised with OpenAlex Integration

---

# PART 1: TEST PLAN

## 1. Test Strategy Overview

### 1.1 Testing Principles
- **Speed-First Testing:** Tests must not slow down the <200ms target
- **Metadata Validation:** Ensure OpenAlex data integrity throughout
- **Citation Accuracy:** Verify graph relationships match source data
- **Real-World Scenarios:** Test with actual Work Objects and citations
- **Cache-Aware Testing:** Test both cold and warm cache scenarios

### 1.2 Test Levels

| Level       | Focus                           | Tools             | When                   |
|-------------|---------------------------------|-------------------|------------------------|
| Unit        | Individual functions            | pytest, jest      | During development     |
| Integration | Service interactions + OpenAlex | pytest, supertest | After service complete |
| Performance | Latency & throughput            | locust, k6        | Continuous             |
| E2E         | Full user flows with metadata   | Playwright        | Before demo            |

## 2. Critical Path Tests

### 2.1 OpenAlex Integration Test Suite

```python
# tests/integration/test_openalex_integration.py
import pytest
from unittest.mock import patch

class TestOpenAlexIntegration:
    @pytest.mark.integration
    async def test_work_object_fetch(self, openalex_client):
        """Test fetching Work Object by various identifiers"""
        # Test by DOI
        work = await openalex_client.get_work("10.1145/3297280.3297641")
        assert work.id.startswith("https://openalex.org/W")
        assert work.title is not None
        assert work.cited_by_count >= 0
        assert len(work.concepts) > 0
        
        # Test by OpenAlex ID
        work2 = await openalex_client.get_work("W302740479")
        assert work2.id == "https://openalex.org/W302740479"
        
        # Test by title search
        work3 = await openalex_client.search_by_title("Attention Is All You Need")
        assert work3 is not None
        assert "attention" in work3.title.lower()
    
    @pytest.mark.integration
    async def test_batch_fetch_performance(self, openalex_client):
        """Ensure batch fetching stays within rate limits"""
        work_ids = [f"W{i}" for i in range(302740479, 302740579)]  # 100 works
        
        start_time = time.time()
        works = await openalex_client.batch_get_works(work_ids)
        duration = time.time() - start_time
        
        assert len(works) <= 100  # Some might not exist
        assert duration < 15  # Should complete in <15s with rate limiting
        
        # Verify caching worked
        cached_work = await openalex_client.get_work(work_ids[0])
        assert cached_work is not None  # Should be instant from cache
    
    @pytest.mark.integration
    async def test_metadata_completeness(self, sample_works):
        """Verify critical metadata fields are present"""
        for work in sample_works:
            assert work.id is not None
            assert work.title is not None
            assert work.publication_date is not None
            assert isinstance(work.referenced_works, list)
            assert isinstance(work.concepts, list)
            assert all(c.score >= 0 for c in work.concepts)
```

### 2.2 Enhanced Query Performance Tests

```python
# tests/performance/test_query_latency_with_metadata.py
class TestQueryPerformance:
    @pytest.mark.performance
    @pytest.mark.parametrize("query,expected_concepts", [
        ("transformer efficiency", ["Transformer", "Deep Learning"]),
        ("sparse attention mechanisms", ["Attention Mechanism", "Sparse Matrix"]),
        ("vision transformer", ["Computer Vision", "Transformer"])
    ])
    async def test_query_with_concept_expansion(self, api_client, query, expected_concepts):
        """Test query latency with OpenAlex concept expansion"""
        latencies = []
        
        for _ in range(50):
            start = time.perf_counter()
            response = await api_client.post("/api/v1/query", json={
                "query": query,
                "expand_concepts": True
            })
            latency = (time.perf_counter() - start) * 1000
            
            assert response.status_code == 200
            latencies.append(latency)
            
            # Verify concept expansion worked
            data = response.json()
            expanded_concepts = [c['display_name'] for c in data['expanded_concepts']]
            assert any(concept in expanded_concepts for concept in expected_concepts)
        
        p95 = quantiles(latencies, n=100)[94]
        assert p95 < 200, f"P95 latency {p95:.1f}ms exceeds 200ms target"
    
    @pytest.mark.performance
    async def test_citation_enriched_results(self, api_client):
        """Test performance with citation data included"""
        response = await api_client.post("/api/v1/query", json={
            "query": "bert improvements",
            "include_citations": True
        })
        
        assert response.status_code == 200
        data = response.json()
        
        # Verify citation data is present
        for result in data['results'][:5]:
            assert 'cited_by_count' in result
            assert 'citation_context' in result
            assert isinstance(result['citation_context']['cites'], list)
            assert isinstance(result['citation_context']['cited_by'], list)
        
        # Performance should still be good
        assert data['processing_time_ms'] < 200
```

### 2.3 Citation Network Tests

```python
# tests/functional/test_citation_networks.py
class TestCitationNetworks:
    @pytest.mark.functional
    async def test_citation_path_finding(self, neo4j_client):
        """Test finding paths between papers through citations"""
        # Insert test citation network
        await neo4j_client.run("""
            CREATE (w1:Work {id: 'W1', title: 'Original BERT'}),
                   (w2:Work {id: 'W2', title: 'RoBERTa'}),
                   (w3:Work {id: 'W3', title: 'ALBERT'}),
                   (w4:Work {id: 'W4', title: 'DeBERTa'}),
                   (w1)-[:CITES]->(),
                   (w2)-[:CITES]->(w1),
                   (w3)-[:CITES]->(w1),
                   (w4)-[:CITES]->(w2),
                   (w4)-[:CITES]->(w3)
        """)
        
        # Find path from DeBERTa to BERT
        path = await find_citation_path('W4', 'W1', max_depth=3)
        
        assert path is not None
        assert len(path) >= 2  # At least one intermediate paper
        assert path[0]['id'] == 'W4'
        assert path[-1]['id'] == 'W1'
    
    @pytest.mark.functional
    async def test_common_references_detection(self, citation_analyzer):
        """Test finding papers commonly cited by a set of works"""
        work_ids = ['W302740479', 'W302740480', 'W302740481']
        
        common_refs = await citation_analyzer.find_common_ancestors(work_ids)
        
        assert len(common_refs) > 0
        # Seminal papers should be cited by multiple works
        assert all(ref['citing_count'] >= 2 for ref in common_refs)
        
        # Should be ordered by citation overlap
        assert common_refs[0]['citing_count'] >= common_refs[-1]['citing_count']
```

### 2.4 Work Object Storage Tests

```python
# tests/unit/test_work_storage.py
class TestWorkStorage:
    def test_work_id_file_mapping(self, storage):
        """Test correct file naming convention"""
        work_id = "W302740479"
        
        paths = storage.get_work_paths(work_id)
        
        assert paths['metadata'].name == "work.json"
        assert paths['pdf'].name == "paper.pdf"
        assert paths['tei'].name == "grobid.tei.xml"
        assert paths['embeddings'].name == "embeddings.npy"
        assert str(paths['metadata']).startswith(f"data/works/{work_id}/")
    
    @pytest.mark.asyncio
    async def test_work_object_persistence(self, storage, sample_work):
        """Test saving and loading Work Objects"""
        work_id = sample_work.id.split('/')[-1]
        
        # Save
        await storage.save_work_object(work_id, sample_work)
        
        # Load
        loaded = await storage.load_work_object(work_id)
        
        assert loaded.id == sample_work.id
        assert loaded.title == sample_work.title
        assert len(loaded.concepts) == len(sample_work.concepts)
        assert loaded.cited_by_count == sample_work.cited_by_count
```

## 3. Test Data Generation

### 3.1 OpenAlex-Aware Test Data

```python
# scripts/generate_test_data_openalex.py
import json
import random
from datetime import datetime, timedelta
from faker import Faker

fake = Faker()

class OpenAlexTestDataGenerator:
    def __init__(self):
        self.concepts = [
            {"id": "C154945302", "display_name": "Artificial Neural Networks"},
            {"id": "C2524010", "display_name": "Natural Language Processing"},
            {"id": "C126255220", "display_name": "Computer Vision"},
            {"id": "C119599485", "display_name": "Transformer"},
            {"id": "C165906935", "display_name": "Deep Learning"},
        ]
        self.venues = [
            {"id": "V172146120", "display_name": "NeurIPS", "type": "conference"},
            {"id": "V1983995261", "display_name": "ICML", "type": "conference"},
            {"id": "V2752708", "display_name": "ICLR", "type": "conference"},
        ]
        
    def generate_work_object(self, work_id: int) -> dict:
        """Generate realistic OpenAlex Work Object"""
        publication_date = fake.date_between(
            start_date=datetime(2020, 1, 1),
            end_date=datetime(2024, 12, 31)
        )
        
        # Generate realistic citation counts based on age
        age_days = (datetime.now() - publication_date).days
        base_citations = int(age_days / 30)  # ~1 citation per month
        cited_by_count = max(0, base_citations + random.randint(-5, 50))
        
        # Generate referenced works (older papers)
        num_refs = random.randint(20, 60)
        referenced_works = [
            f"https://openalex.org/W{random.randint(1000000, work_id-1)}"
            for _ in range(num_refs)
        ]
        
        # Assign concepts with scores
        selected_concepts = random.sample(self.concepts, k=random.randint(3, 5))
        concepts_with_scores = [
            {**concept, "score": round(random.uniform(0.5, 0.99), 2)}
            for concept in selected_concepts
        ]
        
        return {
            "id": f"https://openalex.org/W{work_id}",
            "doi": f"https://doi.org/10.1234/test.{work_id}",
            "title": self._generate_realistic_title(),
            "display_name": self._generate_realistic_title(),
            "publication_date": publication_date.isoformat(),
            "publication_year": publication_date.year,
            "cited_by_count": cited_by_count,
            "referenced_works": referenced_works,
            "related_works": random.sample(referenced_works, k=min(5, len(referenced_works))),
            "abstract": self._generate_abstract(),
            "authorships": self._generate_authorships(),
            "concepts": concepts_with_scores,
            "host_venue": random.choice(self.venues),
            "open_access": {
                "is_oa": random.choice([True, False]),
                "oa_url": f"https://arxiv.org/pdf/{work_id}.pdf" if random.random() > 0.5 else None
            },
            "type": "article",
            "language": "en"
        }
    
    def _generate_realistic_title(self) -> str:
        """Generate paper titles that sound real"""
        templates = [
            "{method} for {task}: A {approach} Approach",
            "Improving {metric} in {domain} with {technique}",
            "{technique}: {property} {method} for {application}",
            "On the {property} of {method} in {domain}",
            "Revisiting {classic} for {modern} {task}"
        ]
        
        substitutions = {
            "method": ["BERT", "Transformer", "Vision Transformer", "GPT", "ResNet"],
            "task": ["Question Answering", "Image Classification", "Language Modeling", "Object Detection"],
            "approach": ["Scalable", "Efficient", "Robust", "Novel", "Unified"],
            "metric": ["Accuracy", "Efficiency", "Robustness", "Generalization"],
            "domain": ["NLP", "Computer Vision", "Multimodal Learning", "Few-Shot Learning"],
            "technique": ["Sparse Attention", "Knowledge Distillation", "Contrastive Learning", "Self-Supervision"],
            "property": ["Efficiency", "Scalability", "Interpretability", "Robustness"],
            "application": ["Large-Scale Training", "Edge Deployment", "Real-Time Inference"],
            "classic": ["Attention Mechanisms", "Convolutional Networks", "Recurrent Models"],
            "modern": ["Large-Scale", "Multilingual", "Multimodal"]
        }
        
        template = random.choice(templates)
        title = template
        for key, values in substitutions.items():
            title = title.replace(f"{{{key}}}", random.choice(values))
        
        return title
    
    def _generate_abstract(self) -> str:
        """Generate realistic abstract"""
        intro = fake.sentence(nb_words=15)
        problem = f"However, {fake.sentence(nb_words=12).lower()}"
        solution = f"In this paper, we propose {fake.sentence(nb_words=10).lower()}"
        results = f"Our experiments show {random.randint(2, 15)}% improvement over baselines."
        
        return f"{intro} {problem} {solution} {results}"
    
    def _generate_authorships(self) -> list:
        """Generate author list with institutions"""
        num_authors = random.randint(2, 6)
        return [
            {
                "author": {
                    "id": f"https://openalex.org/A{random.randint(1000000, 9999999)}",
                    "display_name": fake.name(),
                    "orcid": f"https://orcid.org/0000-000{random.randint(1, 9)}-{random.randint(1000, 9999)}-{random.randint(1000, 9999)}"
                },
                "author_position": position,
                "institutions": [{
                    "id": f"https://openalex.org/I{random.randint(1000000, 9999999)}",
                    "display_name": fake.company() + " University",
                    "ror": f"https://ror.org/{fake.lexify('????????')}",
                    "country_code": fake.country_code()
                }]
            }
            for position in ["first", "middle", "middle", "middle", "last"][:num_authors]
        ]
    
    def generate_citation_network(self, num_papers: int = 100) -> tuple:
        """Generate papers with realistic citation patterns"""
        papers = []
        
        # Generate papers chronologically
        for i in range(num_papers):
            work_id = 302740000 + i
            paper = self.generate_work_object(work_id)
            
            # More recent papers cite older ones
            if i > 0:
                num_citations = min(i, random.randint(10, 30))
                cited_indices = random.sample(range(i), num_citations)
                paper["referenced_works"] = [
                    papers[idx]["id"] for idx in cited_indices
                ]
            
            papers.append(paper)
        
        return papers

# Generate test dataset
if __name__ == "__main__":
    generator = OpenAlexTestDataGenerator()
    papers = generator.generate_citation_network(500)
    
    # Save as JSONL for efficient loading
    with open("data/test_works.jsonl", "w") as f:
        for paper in papers:
            f.write(json.dumps(paper) + "\n")
    
    print(f"Generated {len(papers)} test Work Objects with citation network")
```

## 4. API Contract Tests

### 4.1 OpenAlex-Enhanced Endpoints

```python
# tests/contract/test_api_contracts.py
import pytest
from jsonschema import validate

class TestAPIContracts:
    @pytest.mark.contract
    async def test_query_endpoint_with_metadata(self, api_client):
        """Test query endpoint returns OpenAlex metadata"""
        response = await api_client.post("/api/v1/query", json={
            "query": "transformer",
            "expand_concepts": True,
            "include_citations": True
        })
        
        assert response.status_code == 200
        data = response.json()
        
        # Validate response schema
        query_response_schema = {
            "type": "object",
            "required": ["query_id", "results", "expanded_concepts", "processing_time_ms"],
            "properties": {
                "query_id": {"type": "string"},
                "expanded_concepts": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": ["id", "display_name", "score"],
                        "properties": {
                            "id": {"type": "string", "pattern": "^C\\d+$"},
                            "display_name": {"type": "string"},
                            "score": {"type": "number", "minimum": 0, "maximum": 1}
                        }
                    }
                },
                "results": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "required": ["work_id", "title", "venue", "cited_by_count"],
                        "properties": {
                            "work_id": {"type": "string", "pattern": "^W\\d+$"},
                            "cited_by_count": {"type": "integer", "minimum": 0},
                            "concepts": {"type": "array"},
                            "open_access": {
                                "type": "object",
                                "required": ["is_oa"],
                                "properties": {
                                    "is_oa": {"type": "boolean"},
                                    "oa_url": {"type": ["string", "null"]}
                                }
                            }
                        }
                    }
                }
            }
        }
        
        validate(instance=data, schema=query_response_schema)
    
    @pytest.mark.contract
    async def test_work_endpoint(self, api_client):
        """Test work detail endpoint"""
        work_id = "W302740479"
        response = await api_client.get(f"/api/v1/works/{work_id}")
        
        assert response.status_code == 200
        data = response.json()
        
        assert data["work"]["id"] == work_id
        assert "openalex_url" in data["work"]
        assert "citation_analysis" in data
        assert "local_resources" in data["work"]
```

## 5. Performance Benchmarks

### 5.1 Load Testing with Metadata

```python
# tests/load/test_concurrent_with_openalex.py
from locust import HttpUser, task, between

class LebnizUser(HttpUser):
    wait_time = between(0.1, 0.5)
    
    def on_start(self):
        """Pre-fetch some work IDs for testing"""
        self.work_ids = [f"W30274{i:04d}" for i in range(1000, 2000)]
        self.test_queries = [
            "transformer efficiency",
            "bert improvements", 
            "vision transformer applications",
            "attention mechanisms",
            "neural architecture search"
        ]
    
    @task(3)
    def search_with_concepts(self):
        """Search with concept expansion"""
        query = random.choice(self.test_queries)
        with self.client.post("/api/v1/query", 
                              json={
                                  "query": query,
                                  "expand_concepts": True,
                                  "limit": 20
                              },
                              catch_response=True) as response:
            if response.elapsed.total_seconds() > 0.2:
                response.failure(f"Query took {response.elapsed.total_seconds():.3f}s")
            elif "results" not in response.json():
                response.failure("No results in response")
    
    @task(1)
    def get_work_details(self):
        """Fetch work details with citations"""
        work_id = random.choice(self.work_ids)
        with self.client.get(f"/api/v1/works/{work_id}",
                             catch_response=True) as response:
            if response.status_code != 200:
                response.failure(f"Got status {response.status_code}")
    
    @task(2)
    def citation_search(self):
        """Search based on citations"""
        with self.client.post("/api/v1/citations/common",
                              json={"work_ids": random.sample(self.work_ids, 3)},
                              catch_response=True) as response:
            if response.elapsed.total_seconds() > 0.3:
                response.failure("Citation search too slow")
```

## 6. Integration Test Scenarios

### 6.1 End-to-End Metadata Flow

```python
# tests/e2e/test_metadata_flow.py
class TestMetadataFlow:
    @pytest.mark.e2e
    async def test_complete_ingestion_flow(self, services):
        """Test complete flow from paper discovery to searchable"""
        # Step 1: Discover paper by DOI
        doi = "10.1145/3297280.3297641"
        work = await services.openalex.get_work(f"doi:{doi}")
        work_id = work.id.split('/')[-1]
        
        # Step 2: Trigger ingestion
        await services.pipeline.ingest_paper(work_id)
        
        # Step 3: Verify storage
        assert await services.storage.has_work(work_id)
        stored_work = await services.storage.load_work_object(work_id)
        assert stored_work.title == work.title
        
        # Step 4: Verify in vector store
        vector_results = await services.qdrant.search(
            collection_name="papers",
            query_filter={"work_id": work_id}
        )
        assert len(vector_results) > 0
        
        # Step 5: Verify in graph
        graph_result = await services.neo4j.run(
            "MATCH (w:Work {id: $id}) RETURN w",
            id=work_id
        )
        assert graph_result is not None
        
        # Step 6: Search and find
        search_results = await services.query.search(work.title[:20])
        assert any(r.work_id == work_id for r in search_results)
```

## 7. Cache Testing

### 7.1 Cache Effectiveness Tests

```python
# tests/performance/test_cache_effectiveness.py
class TestCacheEffectiveness:
    @pytest.mark.performance
    async def test_openalex_cache_hit_rate(self, api_client, redis_client):
        """Verify OpenAlex metadata caching works"""
        work_id = "W302740479"
        
        # Clear cache
        await redis_client.delete(f"oa:work:{work_id}")
        
        # First request - cache miss
        start = time.time()
        response1 = await api_client.get(f"/api/v1/works/{work_id}")
        cold_time = time.time() - start
        
        # Second request - cache hit
        start = time.time()
        response2 = await api_client.get(f"/api/v1/works/{work_id}")
        warm_time = time.time() - start
        
        assert response1.json() == response2.json()
        assert warm_time < cold_time * 0.1  # 10x faster from cache
        
        # Verify cache was used
        cached = await redis_client.get(f"oa:work:{work_id}")
        assert cached is not None
```

---

# PART 2: API CONTRACTS

## 1. OpenAPI Specification with OpenAlex

```yaml
openapi: 3.0.0
info:
  title: Project Leibniz API
  version: 2.0.0
  description: Research at the speed of thought with OpenAlex enrichment

servers:
  - url: http://localhost:3000/api/v1
    description: Development server

paths:
  /query:
    post:
      summary: Execute semantic search with metadata enrichment
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
          description: Search results with OpenAlex metadata
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/QueryResponse'

  /works/{work_id}:
    get:
      summary: Get work details with full OpenAlex metadata
      operationId: getWork
      tags: [Works]
      parameters:
        - name: work_id
          in: path
          required: true
          schema:
            type: string
            pattern: '^W\d+$'
            example: W302740479
      responses:
        '200':
          description: Work object with citations
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/WorkResponse'

  /citations/paths:
    post:
      summary: Find citation paths between works
      operationId: findCitationPaths
      tags: [Citations]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CitationPathRequest'
      responses:
        '200':
          description: Citation paths found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CitationPathResponse'

  /citations/common:
    post:
      summary: Find commonly cited works
      operationId: findCommonCitations
      tags: [Citations]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              $ref: '#/components/schemas/CommonCitationsRequest'
      responses:
        '200':
          description: Common citations found
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CommonCitationsResponse'

  /concepts/expand:
    post:
      summary: Expand query with OpenAlex concepts
      operationId: expandConcepts
      tags: [Concepts]
      requestBody:
        required: true
        content:
          application/json:
            schema:
              type: object
              required: [query]
              properties:
                query:
                  type: string
      responses:
        '200':
          description: Expanded concepts
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/ConceptExpansionResponse'

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
        expand_concepts:
          type: boolean
          default: true
          description: Use OpenAlex concepts for query expansion
        include_citations:
          type: boolean
          default: true
          description: Include citation context in results
        limit:
          type: integer
          minimum: 1
          maximum: 100
          default: 20

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
          example: ["NeurIPS", "ICML", "ICLR"]
        concepts:
          type: array
          items:
            type: string
          description: OpenAlex concept IDs or names
        min_citations:
          type: integer
          minimum: 0
          description: Minimum cited_by_count
        open_access:
          type: boolean
          description: Filter to open access papers only

    QueryResponse:
      type: object
      required: [query_id, results, processing_time_ms]
      properties:
        query_id:
          type: string
          format: uuid
        expanded_concepts:
          type: array
          items:
            $ref: '#/components/schemas/Concept'
          description: OpenAlex concepts used for expansion
        results:
          type: array
          items:
            $ref: '#/components/schemas/EnrichedPaper'
        citation_network:
          $ref: '#/components/schemas/CitationNetwork'
        processing_time_ms:
          type: number

    EnrichedPaper:
      type: object
      required: [work_id, title, doi, publication_year, venue, cited_by_count]
      properties:
        work_id:
          type: string
          pattern: '^W\d+$'
          example: W302740479
        openalex_url:
          type: string
          format: uri
          example: https://openalex.org/W302740479
        title:
          type: string
        doi:
          type: string
          example: "10.1145/3297280.3297641"
        abstract:
          type: string
        publication_year:
          type: integer
        publication_date:
          type: string
          format: date
        venue:
          $ref: '#/components/schemas/Venue'
        authors:
          type: array
          items:
            $ref: '#/components/schemas/Author'
        concepts:
          type: array
          items:
            $ref: '#/components/schemas/Concept'
        cited_by_count:
          type: integer
        citation_context:
          type: object
          properties:
            cites:
              type: array
              items:
                type: string
              description: Work IDs this paper cites
            cited_by:
              type: array
              items:
                type: string
              description: Work IDs that cite this paper
        open_access:
          type: object
          properties:
            is_oa:
              type: boolean
            oa_url:
              type: string
              format: uri
              nullable: true
        relevance_score:
          type: number
          minimum: 0
          maximum: 1

    WorkResponse:
      type: object
      properties:
        work:
          $ref: '#/components/schemas/WorkObject'
        citation_analysis:
          type: object
          properties:
            influential_citations:
              type: array
              items:
                $ref: '#/components/schemas/Citation'
            citation_velocity:
              type: object
              properties:
                last_30_days:
                  type: integer
                last_90_days:
                  type: integer
                trend:
                  type: string
                  enum: [increasing, stable, decreasing]
            h_index:
              type: integer
              description: h-index of papers citing this work

    WorkObject:
      type: object
      required: [id, title, publication_date]
      properties:
        id:
          type: string
          example: W302740479
        openalex_url:
          type: string
          format: uri
        doi:
          type: string
        title:
          type: string
        abstract:
          type: string
        publication_date:
          type: string
          format: date
        publication_year:
          type: integer
        type:
          type: string
          example: article
        cited_by_count:
          type: integer
        referenced_works:
          type: array
          items:
            type: string
          description: OpenAlex Work IDs cited by this paper
        related_works:
          type: array
          items:
            type: string
          description: Similar works suggested by OpenAlex
        authorships:
          type: array
          items:
            $ref: '#/components/schemas/Authorship'
        concepts:
          type: array
          items:
            $ref: '#/components/schemas/Concept'
        host_venue:
          $ref: '#/components/schemas/Venue'
        open_access:
          $ref: '#/components/schemas/OpenAccess'
        local_resources:
          type: object
          properties:
            pdf_available:
              type: boolean
            tei_available:
              type: boolean
            embeddings_computed:
              type: boolean

    Concept:
      type: object
      required: [id, display_name]
      properties:
        id:
          type: string
          pattern: '^C\d+$'
          example: C154945302
        display_name:
          type: string
          example: "Artificial Neural Networks"
        level:
          type: integer
          minimum: 0
          maximum: 5
        score:
          type: number
          minimum: 0
          maximum: 1

    Author:
      type: object
      properties:
        id:
          type: string
          pattern: '^A\d+$'
        display_name:
          type: string
        orcid:
          type: string
          format: uri
          nullable: true

    Authorship:
      type: object
      properties:
        author_position:
          type: string
          enum: [first, middle, last]
        author:
          $ref: '#/components/schemas/Author'
        institutions:
          type: array
          items:
            $ref: '#/components/schemas/Institution'

    Institution:
      type: object
      properties:
        id:
          type: string
          pattern: '^I\d+$'
        display_name:
          type: string
        ror:
          type: string
          format: uri
        country_code:
          type: string
          pattern: '^[A-Z]{2}$'

    Venue:
      type: object
      properties:
        id:
          type: string
          pattern: '^V\d+$'
        display_name:
          type: string
          example: NeurIPS
        issn_l:
          type: string
          nullable: true
        publisher:
          type: string
          nullable: true
        type:
          type: string
          enum: [journal, conference, repository, ebook_platform]

    Citation:
      type: object
      properties:
        citing_work:
          type: string
        cited_work:
          type: string
        context:
          type: string
          description: Text around the citation
        section:
          type: string
          enum: [introduction, related_work, methods, results, discussion, conclusion]

    CitationNetwork:
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
                enum: [work, author, venue, concept]
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
                enum: [cites, authored_by, published_in, has_concept]
              weight:
                type: number

    CitationPathRequest:
      type: object
      required: [from_work_id, to_work_id]
      properties:
        from_work_id:
          type: string
          pattern: '^W\d+$'
        to_work_id:
          type: string
          pattern: '^W\d+$'
        max_depth:
          type: integer
          minimum: 1
          maximum: 5
          default: 3

    CitationPathResponse:
      type: object
      properties:
        paths:
          type: array
          items:
            type: object
            properties:
              length:
                type: integer
              works:
                type: array
                items:
                  type: object
                  properties:
                    work_id:
                      type: string
                    title:
                      type: string
                    year:
                      type: integer

    CommonCitationsRequest:
      type: object
      required: [work_ids]
      properties:
        work_ids:
          type: array
          items:
            type: string
            pattern: '^W\d+$'
          minItems: 2
          maxItems: 10
        min_citing_count:
          type: integer
          minimum: 2
          default: 2

    CommonCitationsResponse:
      type: object
      properties:
        common_ancestors:
          type: array
          items:
            type: object
            properties:
              work:
                $ref: '#/components/schemas/EnrichedPaper'
              citing_count:
                type: integer
              citing_papers:
                type: array
                items:
                  type: string

    ConceptExpansionResponse:
      type: object
      properties:
        original_query:
          type: string
        expanded_concepts:
          type: array
          items:
            $ref: '#/components/schemas/Concept'
        suggested_queries:
          type: array
          items:
            type: string

    OpenAccess:
      type: object
      properties:
        is_oa:
          type: boolean
        oa_status:
          type: string
          enum: [gold, green, hybrid, bronze, closed]
        oa_url:
          type: string
          format: uri
          nullable: true
        any_repository_has_fulltext:
          type: boolean
```

## 2. Example API Calls with OpenAlex

### 2.1 Query with Concept Expansion

```bash
# Search with OpenAlex concept expansion
curl -X POST http://localhost:3000/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{
    "query": "efficient transformers",
    "expand_concepts": true,
    "filters": {
      "min_citations": 50,
      "open_access": true
    }
  }'

# Response
{
  "query_id": "550e8400-e29b-41d4-a716-446655440000",
  "expanded_concepts": [
    {
      "id": "C119599485",
      "display_name": "Transformer",
      "score": 0.95
    },
    {
      "id": "C2776214958", 
      "display_name": "Computational Efficiency",
      "score": 0.87
    }
  ],
  "results": [
    {
      "work_id": "W302740479",
      "openalex_url": "https://openalex.org/W302740479",
      "title": "Efficient Transformers: A Survey",
      "doi": "10.1145/3530811",
      "publication_year": 2022,
      "venue": {
        "id": "V49218635",
        "display_name": "ACM Computing Surveys",
        "type": "journal"
      },
      "cited_by_count": 342,
      "authors": [
        {
          "id": "A2064505764",
          "display_name": "Yi Tay",
          "orcid": "https://orcid.org/0000-0001-5432-1234"
        }
      ],
      "concepts": [
        {
          "id": "C119599485",
          "display_name": "Transformer",
          "score": 0.98
        }
      ],
      "open_access": {
        "is_oa": true,
        "oa_url": "https://arxiv.org/pdf/2009.06732.pdf"
      },
      "relevance_score": 0.96
    }
  ],
  "processing_time_ms": 156.4
}
```

### 2.2 Get Work with Citation Analysis

```bash
curl http://localhost:3000/api/v1/works/W302740479

# Response
{
  "work": {
    "id": "W302740479",
    "openalex_url": "https://openalex.org/W302740479",
    "title": "Efficient Transformers: A Survey",
    "doi": "10.1145/3530811",
    "abstract": "Transformer model architectures have garnered immense interest...",
    "publication_date": "2022-03-14",
    "publication_year": 2022,
    "type": "article",
    "cited_by_count": 342,
    "referenced_works": [
      "W2964268362",  // "Attention Is All You Need"
      "W2962775029",  // "BERT: Pre-training of Deep..."
      // ... 45 more
    ],
    "authorships": [
      {
        "author_position": "first",
        "author": {
          "id": "A2064505764",
          "display_name": "Yi Tay",
          "orcid": "https://orcid.org/0000-0001-5432-1234"
        },
        "institutions": [
          {
            "id": "I1299303238",
            "display_name": "Google Research",
            "ror": "https://ror.org/05qrfxd25",
            "country_code": "US"
          }
        ]
      }
    ],
    "local_resources": {
      "pdf_available": true,
      "tei_available": true,
      "embeddings_computed": true
    }
  },
  "citation_analysis": {
    "influential_citations": [
      {
        "citing_work": "W3127698451",
        "cited_work": "W302740479",
        "context": "Following the taxonomy proposed by Tay et al. (2022), we categorize...",
        "section": "related_work"
      }
    ],
    "citation_velocity": {
      "last_30_days": 28,
      "last_90_days": 89,
      "trend": "increasing"
    },
    "h_index": 12
  }
}
```

### 2.3 Find Citation Paths

```bash
curl -X POST http://localhost:3000/api/v1/citations/paths \
  -H "Content-Type: application/json" \
  -d '{
    "from_work_id": "W3127698451",
    "to_work_id": "W2964268362",
    "max_depth": 3
  }'

# Response
{
  "paths": [
    {
      "length": 2,
      "works": [
        {
          "work_id": "W3127698451",
          "title": "FlashAttention: Fast and Memory-Efficient...",
          "year": 2022
        },
        {
          "work_id": "W302740479",
          "title": "Efficient Transformers: A Survey",
          "year": 2022
        },
        {
          "work_id": "W2964268362",
          "title": "Attention Is All You Need",
          "year": 2017
        }
      ]
    }
  ]
}
```

## 3. WebSocket Protocol with OpenAlex

```typescript
// Enhanced WebSocket events with metadata
interface ServerEvents {
  // Work metadata update
  work_enriched: {
    event: 'work_enriched';
    data: {
      work_id: string;
      metadata: WorkObject;
      timestamp: number;
    };
  };

  // Citation discovery
  citation_found: {
    event: 'citation_found';
    data: {
      citing_work: string;
      cited_work: string;
      context?: string;
      added_at: number;
    };
  };

  // Concept expansion update
  concepts_expanded: {
    event: 'concepts_expanded';
    data: {
      query_id: string;
      concepts: Concept[];
      suggested_queries: string[];
    };
  };
}
```

---

**Test Coverage Target:** 80% for critical paths including OpenAlex integration  
**API Compliance:** OpenAPI 3.0 validated with metadata schemas  
**Next Step:** Begin implementation with OpenAlex client!