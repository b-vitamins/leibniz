# Project Leibniz - Quick Start Implementation Guide

**Version:** 2.0  
**Date:** June 2025
**Purpose:** Your coding companion for Hours 0-48 with OpenAlex integration

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
□ Internet connection (for OpenAlex API)

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
data/works/
data/pdfs/
data/processed/
*.log
.DS_Store
venv/
.pytest_cache/
EOF

# 2. Create project structure in one go
mkdir -p {services/{gateway,query,synthesis,prediction,openalex,pipeline},frontend/src,data/{works,cache,indices},scripts,tests/{unit,integration,performance,e2e},docs}

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
    command: redis-server --save 60 1000 --appendonly yes

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

# 4. Create .env file with OpenAlex config
cat > .env << 'EOF'
OPENAI_API_KEY=sk-YOUR-KEY-HERE
OPENALEX_EMAIL=your-email@example.com  # For polite crawling
REDIS_URL=redis://localhost:6379
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=leibniz123
QDRANT_HOST=localhost
QDRANT_PORT=6333
MEILISEARCH_HOST=http://localhost:7700
MEILISEARCH_KEY=leibniz_dev_key
EOF

echo "⚠️  STOP! Edit .env with your OpenAI API key and email now!"
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

#### 1. OpenAlex Client (NEW - Start Here!)
```python
# services/openalex/client.py
import httpx
import asyncio
from typing import List, Optional
import os
from datetime import datetime

class OpenAlexClient:
    """Client for OpenAlex API with polite crawling"""
    
    def __init__(self):
        self.base_url = "https://api.openalex.org"
        self.email = os.getenv("OPENALEX_EMAIL", "hello@example.com")
        self.rate_limiter = asyncio.Semaphore(10)  # 10 requests/second
        
    async def get_work(self, identifier: str) -> dict:
        """Get Work Object by DOI, OpenAlex ID, or title"""
        async with self.rate_limiter:
            async with httpx.AsyncClient() as client:
                # Try different identifier types
                if identifier.startswith("W"):
                    url = f"{self.base_url}/works/{identifier}"
                elif identifier.startswith("10."):  # DOI
                    url = f"{self.base_url}/works/doi:{identifier}"
                else:  # Try title search
                    url = f"{self.base_url}/works?filter=title.search:{identifier}"
                
                response = await client.get(
                    url,
                    params={"mailto": self.email},
                    timeout=30.0
                )
                
                if response.status_code == 200:
                    data = response.json()
                    if 'results' in data:  # Search result
                        return data['results'][0] if data['results'] else None
                    return data
                return None
    
    async def get_conference_papers(self, venue: str, year: int) -> List[dict]:
        """Fetch all papers from a conference/year"""
        cursor = "*"
        all_papers = []
        
        async with httpx.AsyncClient() as client:
            while cursor:
                async with self.rate_limiter:
                    response = await client.get(
                        f"{self.base_url}/works",
                        params={
                            "filter": f"host_venue.display_name:{venue},publication_year:{year}",
                            "cursor": cursor,
                            "per_page": 200,
                            "mailto": self.email
                        },
                        timeout=30.0
                    )
                    
                    data = response.json()
                    all_papers.extend(data['results'])
                    cursor = data['meta'].get('next_cursor')
                    
                    print(f"Fetched {len(all_papers)} papers from {venue} {year}")
                    
        return all_papers

# Quick test
async def test_openalex():
    client = OpenAlexClient()
    
    # Test fetching a known paper
    work = await client.get_work("10.48550/arXiv.1706.03762")  # Attention is All You Need
    if work:
        print(f"✅ Found: {work['title']}")
        print(f"   ID: {work['id']}")
        print(f"   Citations: {work['cited_by_count']}")
    
    # Test fetching conference papers
    papers = await client.get_conference_papers("NeurIPS", 2023)
    print(f"✅ Found {len(papers)} papers from NeurIPS 2023")

if __name__ == "__main__":
    asyncio.run(test_openalex())
```

#### 2. Enhanced Query Service with OpenAlex
```python
# services/query/main.py
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import time
import asyncio
from typing import List, Optional
import numpy as np
import sys
sys.path.append('..')
from openalex.client import OpenAlexClient

app = FastAPI(title="Leibniz Query Service")

# Initialize clients
from qdrant_client import QdrantClient
from neo4j import AsyncGraphDatabase
import redis
import httpx

qdrant = QdrantClient(host="localhost", port=6333)
redis_client = redis.Redis(host='localhost', port=6379, decode_responses=True)
neo4j_driver = AsyncGraphDatabase.driver("bolt://localhost:7687", auth=("neo4j", "leibniz123"))
openalex = OpenAlexClient()

# Enhanced models with OpenAlex fields
class QueryRequest(BaseModel):
    query: str
    limit: int = 20
    expand_concepts: bool = True
    include_citations: bool = True
    filters: Optional[dict] = None

class Paper(BaseModel):
    work_id: str  # OpenAlex Work ID
    title: str
    abstract: str
    doi: Optional[str]
    venue: Optional[dict]
    publication_year: int
    cited_by_count: int
    concepts: List[dict]
    open_access: dict
    relevance_score: float

class QueryResponse(BaseModel):
    query_id: str
    papers: List[Paper]
    expanded_concepts: List[dict] = []
    processing_time_ms: float
    suggestions: List[str] = []

@app.post("/api/v1/query", response_model=QueryResponse)
async def search_papers(request: QueryRequest):
    start_time = time.perf_counter()
    
    # Check cache first
    cache_key = f"query:{hash(request.query)}"
    cached = redis_client.get(cache_key)
    if cached:
        return QueryResponse.parse_raw(cached)
    
    # Extract concepts from query (mock for now)
    concepts = []
    if request.expand_concepts:
        # In real implementation, this would use OpenAlex concept search
        concepts = [
            {"id": "C119599485", "display_name": "Transformer", "score": 0.9},
            {"id": "C165906935", "display_name": "Deep Learning", "score": 0.8}
        ]
    
    # For now, return enriched mock data
    papers = [
        Paper(
            work_id="W302740479",
            title="Efficient Transformers: A Survey",
            abstract="This survey covers recent advances in making transformers more efficient...",
            doi="10.1145/3530811",
            venue={"display_name": "ACM Computing Surveys", "type": "journal"},
            publication_year=2022,
            cited_by_count=342,
            concepts=[
                {"display_name": "Transformer", "score": 0.98},
                {"display_name": "Computational Efficiency", "score": 0.87}
            ],
            open_access={"is_oa": True, "oa_url": "https://arxiv.org/pdf/2009.06732.pdf"},
            relevance_score=0.95
        )
    ]
    
    processing_time = (time.perf_counter() - start_time) * 1000
    
    response = QueryResponse(
        query_id=f"q_{int(time.time())}",
        papers=papers,
        expanded_concepts=concepts,
        processing_time_ms=processing_time,
        suggestions=["sparse transformers", "efficient attention", "model compression"]
    )
    
    # Cache for next time
    redis_client.setex(cache_key, 3600, response.json())
    
    return response

@app.get("/health")
async def health():
    return {"status": "healthy", "service": "query", "features": ["openalex", "citations"]}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8001)
```

#### 3. Data Ingestion Pipeline
```python
# services/pipeline/ingest.py
import asyncio
from pathlib import Path
import json
import httpx
from typing import Optional
import sys
sys.path.append('..')
from openalex.client import OpenAlexClient

class IngestionPipeline:
    def __init__(self):
        self.openalex = OpenAlexClient()
        self.data_dir = Path("../../data/works")
        self.data_dir.mkdir(parents=True, exist_ok=True)
        
    async def ingest_paper(self, identifier: str, pdf_path: Optional[Path] = None):
        """Ingest a paper with OpenAlex metadata"""
        # Step 1: Get OpenAlex metadata
        print(f"Fetching metadata for {identifier}")
        work = await self.openalex.get_work(identifier)
        if not work:
            print(f"❌ Could not find {identifier} in OpenAlex")
            return None
            
        # Extract Work ID
        work_id = work['id'].split('/')[-1]  # W302740479
        print(f"✅ Found {work['title']} ({work_id})")
        
        # Step 2: Create directory structure
        work_dir = self.data_dir / work_id
        work_dir.mkdir(exist_ok=True)
        
        # Step 3: Save Work Object
        with open(work_dir / "work.json", "w") as f:
            json.dump(work, f, indent=2)
        
        # Step 4: Download PDF if available and not provided
        if not pdf_path and work.get('open_access', {}).get('oa_url'):
            pdf_url = work['open_access']['oa_url']
            pdf_path = work_dir / "paper.pdf"
            
            print(f"Downloading PDF from {pdf_url}")
            async with httpx.AsyncClient() as client:
                response = await client.get(pdf_url, follow_redirects=True)
                if response.status_code == 200:
                    pdf_path.write_bytes(response.content)
                    print(f"✅ Saved PDF to {pdf_path}")
        
        # Step 5: Copy provided PDF
        elif pdf_path and pdf_path.exists():
            import shutil
            shutil.copy(pdf_path, work_dir / "paper.pdf")
            print(f"✅ Copied PDF to {work_dir}")
        
        return work_id
    
    async def ingest_conference(self, venue: str, year: int, limit: Optional[int] = None):
        """Ingest all papers from a conference"""
        print(f"\n🎯 Ingesting {venue} {year}")
        
        papers = await self.openalex.get_conference_papers(venue, year)
        if limit:
            papers = papers[:limit]
            
        print(f"Processing {len(papers)} papers...")
        
        for i, paper in enumerate(papers):
            work_id = paper['id'].split('/')[-1]
            work_dir = self.data_dir / work_id
            
            if work_dir.exists():
                print(f"[{i+1}/{len(papers)}] Skipping {work_id} (already exists)")
                continue
                
            work_dir.mkdir(exist_ok=True)
            with open(work_dir / "work.json", "w") as f:
                json.dump(paper, f, indent=2)
                
            print(f"[{i+1}/{len(papers)}] Saved {work_id}: {paper['title'][:60]}...")
            
            # Be polite
            await asyncio.sleep(0.1)

# Quick ingestion script
async def quick_start_ingestion():
    pipeline = IngestionPipeline()
    
    # Ingest some famous papers
    famous_papers = [
        "10.48550/arXiv.1706.03762",  # Attention is All You Need
        "10.48550/arXiv.1810.04805",  # BERT
        "10.48550/arXiv.2005.14165",  # GPT-3
    ]
    
    for doi in famous_papers:
        await pipeline.ingest_paper(doi)
    
    # Ingest recent conference papers (limited for quick start)
    await pipeline.ingest_conference("NeurIPS", 2023, limit=50)

if __name__ == "__main__":
    asyncio.run(quick_start_ingestion())
```

## 📊 PERFORMANCE PATTERNS COOKBOOK

### Pattern 1: OpenAlex Metadata Caching
```python
# services/query/caching.py
from functools import wraps
import hashlib
import json

class OpenAlexCache:
    """Two-tier caching for OpenAlex data"""
    
    def __init__(self, redis_client):
        self.redis = redis_client
        self.memory_cache = {}  # L1: In-memory
        
    async def get_work(self, work_id: str) -> dict:
        # L1: Memory cache (0ms)
        if work_id in self.memory_cache:
            return self.memory_cache[work_id]
            
        # L2: Redis cache (1-5ms)
        cache_key = f"oa:work:{work_id}"
        if cached := await self.redis.get(cache_key):
            work = json.loads(cached)
            self.memory_cache[work_id] = work
            return work
            
        return None
    
    async def set_work(self, work_id: str, work_data: dict):
        # Cache in both tiers
        self.memory_cache[work_id] = work_data
        cache_key = f"oa:work:{work_id}"
        await self.redis.setex(cache_key, 86400, json.dumps(work_data))  # 24h TTL
        
    async def get_citations(self, work_id: str) -> list:
        """Get cached citation list"""
        cache_key = f"oa:citations:{work_id}"
        if cached := await self.redis.get(cache_key):
            return json.loads(cached)
        return None
```

### Pattern 2: Citation-Aware Search
```python
# services/query/citation_search.py
async def citation_boosted_search(query: str, openalex_cache: OpenAlexCache) -> list:
    """Search with citation count boosting"""
    
    # Get initial results from vector search
    vector_results = await search_vectors(query)
    
    # Enrich with citation data
    enriched_results = []
    for result in vector_results:
        work_id = result['work_id']
        
        # Get cached metadata
        work = await openalex_cache.get_work(work_id)
        if work:
            # Boost score based on citations
            citation_boost = min(work['cited_by_count'] / 1000, 0.2)  # Max 0.2 boost
            result['relevance_score'] += citation_boost
            result['cited_by_count'] = work['cited_by_count']
            result['venue'] = work.get('host_venue', {})
            result['concepts'] = work.get('concepts', [])[:5]
            
        enriched_results.append(result)
    
    # Re-sort by boosted score
    enriched_results.sort(key=lambda x: x['relevance_score'], reverse=True)
    
    return enriched_results
```

### Pattern 3: Smart Pre-fetching
```python
# services/pipeline/prefetch.py
async def prefetch_conference_papers():
    """Pre-fetch and cache popular conference papers"""
    
    conferences = [
        ("NeurIPS", 2023),
        ("ICML", 2023),
        ("ICLR", 2023),
        ("NeurIPS", 2022),
    ]
    
    pipeline = IngestionPipeline()
    
    for venue, year in conferences:
        print(f"\nPre-fetching {venue} {year}")
        
        # Get papers sorted by citations
        papers = await pipeline.openalex.get_conference_papers(venue, year)
        papers.sort(key=lambda x: x.get('cited_by_count', 0), reverse=True)
        
        # Cache top 100 most cited
        for paper in papers[:100]:
            work_id = paper['id'].split('/')[-1]
            
            # Save to disk
            work_dir = Path(f"data/works/{work_id}")
            work_dir.mkdir(parents=True, exist_ok=True)
            
            with open(work_dir / "work.json", "w") as f:
                json.dump(paper, f, indent=2)
            
            # Also cache in Redis
            await redis_client.setex(
                f"oa:work:{work_id}",
                86400 * 7,  # 1 week TTL
                json.dumps(paper)
            )
            
        print(f"✅ Cached top 100 papers from {venue} {year}")
```

## 🚨 CRITICAL PATH OPTIMIZATIONS

### Hour 4-8: OpenAlex Integration Sprint

```python
# scripts/batch_ingest.py
"""Batch ingest papers for demo"""
import asyncio
from services.pipeline.ingest import IngestionPipeline

async def ingest_for_demo():
    pipeline = IngestionPipeline()
    
    # Key papers for demo scenarios
    demo_papers = {
        # Transformer papers
        "10.48550/arXiv.1706.03762": "Attention Is All You Need",
        "10.48550/arXiv.2005.14165": "GPT-3",
        "10.48550/arXiv.1810.04805": "BERT",
        "10.48550/arXiv.2010.11929": "ViT",
        
        # Efficiency papers
        "10.48550/arXiv.2009.06732": "Efficient Transformers Survey",
        "10.48550/arXiv.1911.02150": "Sparse Transformers",
        "10.48550/arXiv.2205.07686": "FlashAttention",
        
        # Papers with known contradictions
        "10.48550/arXiv.1907.11692": "RoBERTa",  # Claims different BERT performance
        "10.48550/arXiv.1909.11942": "ALBERT",   # Different efficiency claims
    }
    
    print("📚 Ingesting key papers for demo...")
    for doi, title in demo_papers.items():
        print(f"\n→ {title}")
        work_id = await pipeline.ingest_paper(doi)
        if work_id:
            print(f"  ✅ Saved as {work_id}")
    
    # Get some recent papers from each conference
    print("\n📚 Ingesting recent conference papers...")
    for venue in ["NeurIPS", "ICML", "ICLR"]:
        await pipeline.ingest_conference(venue, 2023, limit=30)
    
    print("\n✨ Demo dataset ready!")

if __name__ == "__main__":
    asyncio.run(ingest_for_demo())
```

### Hour 8-12: Build Citation Network

```python
# scripts/build_citation_graph.py
import asyncio
import json
from pathlib import Path
from neo4j import AsyncGraphDatabase

async def build_citation_graph():
    """Build Neo4j graph from OpenAlex data"""
    
    driver = AsyncGraphDatabase.driver(
        "bolt://localhost:7687", 
        auth=("neo4j", "leibniz123")
    )
    
    # Create constraints
    async with driver.session() as session:
        await session.run(
            "CREATE CONSTRAINT IF NOT EXISTS FOR (w:Work) REQUIRE w.id IS UNIQUE"
        )
        await session.run(
            "CREATE CONSTRAINT IF NOT EXISTS FOR (a:Author) REQUIRE a.id IS UNIQUE"
        )
        await session.run(
            "CREATE CONSTRAINT IF NOT EXISTS FOR (v:Venue) REQUIRE v.id IS UNIQUE"
        )
    
    # Load all work objects
    works_dir = Path("data/works")
    work_count = 0
    
    for work_dir in works_dir.iterdir():
        if not work_dir.is_dir():
            continue
            
        work_file = work_dir / "work.json"
        if not work_file.exists():
            continue
            
        with open(work_file) as f:
            work = json.load(f)
        
        work_id = work['id'].split('/')[-1]
        
        # Create Work node
        async with driver.session() as session:
            await session.run("""
                MERGE (w:Work {id: $work_id})
                SET w.title = $title,
                    w.doi = $doi,
                    w.year = $year,
                    w.cited_by_count = $cited_by_count,
                    w.abstract = $abstract
            """, 
                work_id=work_id,
                title=work['title'],
                doi=work.get('doi', ''),
                year=work['publication_year'],
                cited_by_count=work['cited_by_count'],
                abstract=work.get('abstract', '')[:1000]  # Truncate
            )
            
            # Create Venue
            if venue := work.get('host_venue'):
                if venue.get('id'):
                    venue_id = venue['id'].split('/')[-1]
                    await session.run("""
                        MERGE (v:Venue {id: $venue_id})
                        SET v.display_name = $name,
                            v.type = $type
                        WITH v
                        MATCH (w:Work {id: $work_id})
                        MERGE (w)-[:PUBLISHED_IN]->(v)
                    """,
                        venue_id=venue_id,
                        name=venue['display_name'],
                        type=venue.get('type', 'unknown'),
                        work_id=work_id
                    )
            
            # Create Authors
            for authorship in work.get('authorships', []):
                author = authorship.get('author', {})
                if author.get('id'):
                    author_id = author['id'].split('/')[-1]
                    await session.run("""
                        MERGE (a:Author {id: $author_id})
                        SET a.display_name = $name,
                            a.orcid = $orcid
                        WITH a
                        MATCH (w:Work {id: $work_id})
                        MERGE (w)-[:AUTHORED_BY {position: $position}]->(a)
                    """,
                        author_id=author_id,
                        name=author['display_name'],
                        orcid=author.get('orcid', ''),
                        work_id=work_id,
                        position=authorship.get('author_position', 'unknown')
                    )
            
            # Create Citations
            for ref_work in work.get('referenced_works', []):
                ref_id = ref_work.split('/')[-1]
                await session.run("""
                    MERGE (w1:Work {id: $citing})
                    MERGE (w2:Work {id: $cited})
                    MERGE (w1)-[:CITES]->(w2)
                """,
                    citing=work_id,
                    cited=ref_id
                )
        
        work_count += 1
        if work_count % 10 == 0:
            print(f"Processed {work_count} works...")
    
    print(f"\n✅ Built citation graph with {work_count} works")
    
    # Run some analytics
    async with driver.session() as session:
        result = await session.run("""
            MATCH (w:Work)
            RETURN COUNT(w) as works,
                   COUNT(DISTINCT (w)-[:CITES]->()) as citations,
                   COUNT(DISTINCT (w)-[:AUTHORED_BY]->()) as authorships
        """)
        stats = await result.single()
        print(f"📊 Graph stats:")
        print(f"   Works: {stats['works']}")
        print(f"   Citations: {stats['citations']}")
        print(f"   Authorships: {stats['authorships']}")

if __name__ == "__main__":
    asyncio.run(build_citation_graph())
```

## 🎯 DEMO SCENARIO SCRIPTS

### The "Wow" Moments to Practice

```python
# scripts/demo_scenarios.py
import asyncio
import httpx
import time

DEMO_QUERIES = [
    {
        "name": "Rich Metadata Search",
        "query": {
            "query": "efficient transformers",
            "expand_concepts": True,
            "filters": {"min_citations": 50}
        },
        "highlight": "See the venue badges and citation counts!",
        "expected": ["ACM Computing Surveys", "342 citations", "Open Access"]
    },
    {
        "name": "Citation Network Discovery",
        "query": {
            "query": "attention mechanisms",
            "include_citations": True
        },
        "highlight": "Click to see citation relationships!",
        "expected": ["Attention Is All You Need", "cited by 15,000+ papers"]
    },
    {
        "name": "Concept-Based Search",
        "query": {
            "query": "vision transformer applications medical imaging",
            "expand_concepts": True
        },
        "highlight": "OpenAlex understands domain concepts!",
        "expected": ["Computer Vision", "Medical Imaging", "Transformer"]
    }
]

async def run_demo():
    """Practice your demo flow"""
    print("🎬 DEMO PRACTICE RUN\n")
    
    async with httpx.AsyncClient() as client:
        for scenario in DEMO_QUERIES:
            print(f"\n{'='*60}")
            print(f"Scenario: {scenario['name']}")
            print(f"Highlight: {scenario['highlight']}")
            print(f"Query: {scenario['query']['query']}")
            
            start = time.perf_counter()
            response = await client.post(
                "http://localhost:8001/api/v1/query",
                json=scenario['query'],
                timeout=5.0
            )
            latency = (time.perf_counter() - start) * 1000
            
            if response.status_code == 200:
                data = response.json()
                print(f"✅ Response in {latency:.0f}ms")
                print(f"   Found {len(data['papers'])} papers")
                
                if data.get('expanded_concepts'):
                    print(f"   Concepts: {', '.join(c['display_name'] for c in data['expanded_concepts'][:3])}")
                
                if data['papers']:
                    paper = data['papers'][0]
                    print(f"   Top result: {paper['title']}")
                    print(f"   Citations: {paper['cited_by_count']}")
                    print(f"   Venue: {paper['venue']['display_name']}")
            else:
                print(f"❌ Request failed: {response.status_code}")

if __name__ == "__main__":
    asyncio.run(run_demo())
```

## ⚡ SPEED HACKS

### 1. Pre-warm Everything Before Demo
```python
# scripts/prewarm_demo.py
async def prewarm_for_demo():
    """Pre-cache everything for smooth demo"""
    
    print("🔥 Pre-warming caches...")
    
    # 1. Load all Work Objects into Redis
    works_dir = Path("data/works")
    loaded = 0
    
    for work_file in works_dir.glob("*/work.json"):
        with open(work_file) as f:
            work = json.load(f)
        
        work_id = work['id'].split('/')[-1]
        
        # Cache in Redis
        await redis_client.setex(
            f"oa:work:{work_id}",
            86400,
            json.dumps(work)
        )
        
        loaded += 1
    
    print(f"✅ Cached {loaded} Work Objects")
    
    # 2. Pre-run all demo queries
    for scenario in DEMO_QUERIES:
        response = await query_service.search(scenario['query'])
        print(f"✅ Pre-cached: {scenario['name']}")
    
    # 3. Pre-compute common concept expansions
    common_concepts = [
        "transformer", "attention", "efficient", "bert", 
        "vision", "language model", "neural network"
    ]
    
    for concept in common_concepts:
        expanded = await expand_concepts(concept)
        await redis_client.setex(
            f"concepts:{concept}",
            86400,
            json.dumps(expanded)
        )
    
    print("✅ System pre-warmed for demo!")
```

## 🔥 COMMON PITFALLS & FIXES

### Pitfall 1: "OpenAlex rate limiting"
```python
# Fix: Implement exponential backoff
async def get_work_with_retry(identifier: str, max_retries: int = 3):
    for attempt in range(max_retries):
        try:
            return await openalex.get_work(identifier)
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 429:  # Rate limited
                wait_time = 2 ** attempt
                print(f"Rate limited, waiting {wait_time}s...")
                await asyncio.sleep(wait_time)
            else:
                raise
    return None
```

### Pitfall 2: "Missing Work Objects"
```python
# Fix: Graceful handling of missing data
async def enrich_paper(paper_data: dict) -> dict:
    work_id = paper_data.get('work_id')
    
    # Try cache first
    if work := await cache.get_work(work_id):
        paper_data.update({
            'venue': work.get('host_venue', {}),
            'cited_by_count': work.get('cited_by_count', 0),
            'concepts': work.get('concepts', [])
        })
    else:
        # Minimal fallback data
        paper_data.update({
            'venue': {'display_name': 'Unknown'},
            'cited_by_count': 0,
            'concepts': []
        })
    
    return paper_data
```

### Pitfall 3: "Citation graph too slow"
```cypher
-- Fix: Add indexes and limit depth
CREATE INDEX work_year IF NOT EXISTS FOR (w:Work) ON (w.year);
CREATE INDEX work_citations IF NOT EXISTS FOR (w:Work) ON (w.cited_by_count);

-- Limit citation path queries
MATCH path = (w1:Work {id: $from})-[:CITES*..2]->(w2:Work {id: $to})
RETURN path
LIMIT 5  -- Only return first 5 paths
```

## 📱 QUICK MONITORING

```bash
# Terminal 1: Watch OpenAlex requests
tail -f logs/openalex_requests.log | grep -E "status|remaining"

# Terminal 2: Monitor citation graph size
watch -n 5 'echo "MATCH (w:Work) RETURN COUNT(w) as works, COUNT((w)-[:CITES]->()) as citations" | cypher-shell -u neo4j -p leibniz123'

# Terminal 3: Cache hit rates
redis-cli --stat | grep -E "hits|misses"
```

## 🏁 FINAL HOUR CHECKLIST

### Hour 44-48: Demo Polish with OpenAlex
```bash
□ Run full data ingestion for demo papers
□ Build complete citation graph
□ Pre-warm all caches
□ Practice showing metadata richness
□ Screenshot citation network visualization
□ Prepare "if OpenAlex is down" backup plan
□ Record demo showing:
  - Instant metadata display
  - Citation count badges
  - Venue information
  - Open Access indicators
  - Concept expansion
  - Citation network exploration
```

## 💡 THE MOST IMPORTANT REMINDER

**Your new superpower: Rich metadata from Day 1**
1. Every paper has citations, venue, authors from the start
2. Search quality is immediately better with concepts
3. Citation networks make exploration natural
4. No more "empty" search results

**If behind schedule:**
1. Use pre-ingested conference data only
2. Mock some OpenAlex responses if needed
3. Focus on showing rich metadata over quantity
4. Remember: Quality > Quantity for demos

---
