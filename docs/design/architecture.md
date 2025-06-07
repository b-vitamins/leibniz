# Project Leibniz - System Architecture Design Document

**Version:** 2.0  
**Date:** June 2025
**Status:** Revised with OpenAlex Integration  
**Classification:** Internal Development

## 1. Introduction

### 1.1 Purpose
This document provides the technical architecture design for Project Leibniz, translating the requirements from the RA document into concrete technical decisions, component designs, and implementation strategies, with OpenAlex as the foundational metadata layer.

### 1.2 Scope
Covers the complete system architecture for the 48-hour prototype, including all components, interfaces, data flows, and deployment strategies, with OpenAlex Work Objects as the primary data model.

### 1.3 Architecture Principles
1. **Speed First:** Every decision optimizes for <200ms response times
2. **Metadata-Driven:** OpenAlex provides authoritative paper metadata
3. **Cache Everything:** Pre-compute and cache aggressively, especially API responses
4. **Progressive Enhancement:** Show something immediately, enhance progressively
5. **Unified Identity:** OpenAlex Work IDs as single source of truth

## 2. System Architecture Overview

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Client Layer (React)                         │
│  ┌─────────────────┐  ┌──────────────┐  ┌───────────────────────┐   │
│  │  Query Input    │  │ Graph Canvas │  │ Results/Method Cards  │   │
│  │ (Autocomplete)  │  │   (D3.js)    │  │ (Progressive Loading) │   │
│  └─────────────────┘  └──────────────┘  └───────────────────────┘   │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │ WebSocket + REST
┌─────────────────────────────────┴───────────────────────────────────┐
│                     API Gateway (Node.js/Express)                   │
│  ┌───────────────┐  ┌──────────────┐  ┌────────────────────────┐    │
│  │ Rate Limiter  │  │  Auth/CORS   │  │   Request Router       │    │
│  └───────────────┘  └──────────────┘  └────────────────────────┘    │
└─────────────────────────────────┬───────────────────────────────────┘
                                  │
┌─────────────────────────────────┴──────────────────────────────────┐
│                    Application Services Layer                      │
│ ┌─────────────────┐ ┌──────────────────┐ ┌────────────────────┐    │
│ │  Query Service  │ │ Synthesis Service│ │ Prediction Service │    │
│ │   (FastAPI)     │ │    (FastAPI)     │ │    (FastAPI)       │    │
│ └────────┬────────┘ └────────┬─────────┘ └──────────┬─────────┘    │
└──────────┼───────────────────┼──────────────────────┼──────────────┘
           │                   │                      │
┌──────────┴───────────────────┴──────────────────────┴──────────────┐
│                      Data Access Layer                             │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐  │
│ │    QDrant    │ │    Neo4j     │ │ Meilisearch  │ │   Redis    │  │
│ │ (Embeddings) │ │(Graph Store) │ │(Text Search) │ │  (Cache)   │  │
│ └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘  │
└─────────────────────────────────┬──────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────┐
│                   Data Processing Pipeline                          │
│ ┌──────────────┐ ┌──────────────┐ ┌──────────────┐ ┌────────────┐   │
│ │   OpenAlex   │ │GROBID Parser │ │OpenAI Client │ │Pre-compute │   │
│ │ API Client   │ │              │ │              │ │   Engine   │   │
│ └──────────────┘ └──────────────┘ └──────────────┘ └────────────┘   │
└─────────────────────────────────────────────────────────────────────┘
                                  │
┌─────────────────────────────────┴───────────────────────────────────┐
│                        Data Storage Layer                           │
│ ┌────────────────────────────────────────────────────────────────┐  │
│ │  File System: W[ID].json | W[ID].pdf | W[ID].tei.xml           │  │
│ └────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Responsibilities

| Component          | Primary Responsibility            | Performance Target         |
|--------------------|-----------------------------------|----------------------------|
| Client Layer       | Progressive UI rendering          | <50ms interaction feedback |
| API Gateway        | Request routing, caching          | <10ms overhead             |
| Query Service      | Semantic search orchestration     | <150ms response            |
| Synthesis Service  | Content generation with citations | <5s for summaries          |
| Prediction Service | Autocomplete & suggestions        | <50ms predictions          |
| Data Access Layer  | Optimized data retrieval          | <50ms queries              |
| OpenAlex Client    | Metadata enrichment               | <100ms cached, <500ms API  |
| Data Storage       | Unified Work Object storage       | <10ms file access          |

## 3. Detailed Component Design

### 3.1 Data Storage Layer (Foundation)

#### 3.1.1 File Organization Strategy
```python
# Unified naming convention using OpenAlex Work IDs
data/
├── works/           # All work-related files
│   ├── W302740479/
│   │   ├── work.json        # OpenAlex Work Object
│   │   ├── paper.pdf        # Original PDF
│   │   ├── grobid.tei.xml   # GROBID extraction
│   │   ├── embeddings.npy   # Pre-computed embeddings
│   │   └── metadata.json    # Combined metadata cache
│   └── W.../
├── indices/         # Pre-built indices
│   ├── concepts.json
│   ├── authors.json
│   └── venues.json
└── cache/          # API response cache
```

#### 3.1.2 Work Object Schema
```python
@dataclass
class WorkObject:
    """OpenAlex Work Object with local enhancements"""
    # OpenAlex fields
    id: str  # "https://openalex.org/W302740479"
    doi: str
    title: str
    publication_date: datetime
    open_access: OpenAccessInfo
    cited_by_count: int
    referenced_works: List[str]  # Other Work IDs
    related_works: List[str]
    concepts: List[Concept]
    authors: List[Author]
    venue: Venue
    
    # Local fields
    local_path: Path  # Path to W[ID]/ directory
    has_pdf: bool
    has_tei: bool
    has_embeddings: bool
    processing_status: str
```

### 3.2 OpenAlex Integration Service

#### 3.2.1 API Client with Caching
```python
class OpenAlexClient:
    def __init__(self):
        self.base_url = "https://api.openalex.org"
        self.rate_limiter = RateLimiter(max_calls=10, period=1.0)
        self.cache = RedisCache(ttl=86400)  # 24h cache
        
    async def get_work(self, identifier: str) -> WorkObject:
        # Check cache first
        cache_key = f"oa:work:{identifier}"
        if cached := await self.cache.get(cache_key):
            return WorkObject.from_json(cached)
        
        # Resolve identifier (DOI, title, or Work ID)
        work_id = await self._resolve_identifier(identifier)
        
        # Fetch from API with rate limiting
        async with self.rate_limiter:
            response = await self.http.get(f"{self.base_url}/works/{work_id}")
        
        work = WorkObject.from_api_response(response)
        await self.cache.set(cache_key, work.to_json())
        
        return work
    
    async def batch_get_works(self, identifiers: List[str]) -> List[WorkObject]:
        """Efficient batch fetching with cursor pagination"""
        # Use OpenAlex filter API for batch operations
        filter_query = "|".join(identifiers)
        cursor = "*"
        works = []
        
        while cursor:
            async with self.rate_limiter:
                response = await self.http.get(
                    f"{self.base_url}/works",
                    params={
                        "filter": f"ids.openalex:{filter_query}",
                        "cursor": cursor,
                        "per-page": 200
                    }
                )
            
            works.extend(response["results"])
            cursor = response.get("meta", {}).get("next_cursor")
        
        return [WorkObject.from_api_response(w) for w in works]
```

### 3.3 Data Pipeline

#### 3.3.1 Ingestion Coordinator
```python
class IngestionPipeline:
    def __init__(self):
        self.openalex = OpenAlexClient()
        self.grobid = GROBIDClient()
        self.storage = WorkStorage()
        
    async def ingest_paper(self, identifier: str, pdf_path: Optional[Path] = None):
        # Step 1: Fetch OpenAlex metadata
        work = await self.openalex.get_work(identifier)
        work_id = work.id.split("/")[-1]  # Extract W123456789
        
        # Step 2: Create storage structure
        work_dir = self.storage.create_work_directory(work_id)
        
        # Step 3: Save Work Object
        await self.storage.save_work_object(work_id, work)
        
        # Step 4: Download or copy PDF
        if pdf_path:
            await self.storage.store_pdf(work_id, pdf_path)
        elif work.open_access.oa_url:
            await self.storage.download_pdf(work_id, work.open_access.oa_url)
        
        # Step 5: Process with GROBID
        if await self.storage.has_pdf(work_id):
            tei_xml = await self.grobid.process_pdf(
                self.storage.get_pdf_path(work_id)
            )
            await self.storage.save_tei(work_id, tei_xml)
        
        # Step 6: Generate enhanced embeddings
        embeddings = await self._generate_enhanced_embeddings(work_id)
        await self.storage.save_embeddings(work_id, embeddings)
        
        # Step 7: Update graph databases
        await self._update_databases(work_id)
    
    async def _generate_enhanced_embeddings(self, work_id: str):
        """Combine OpenAlex metadata with GROBID text for better embeddings"""
        work = await self.storage.load_work_object(work_id)
        
        # Build rich text representation
        text_parts = [
            f"Title: {work.title}",
            f"Abstract: {work.abstract}",
            f"Concepts: {', '.join(c.display_name for c in work.concepts[:5])}",
            f"Venue: {work.venue.display_name if work.venue else 'Unknown'}",
            f"Year: {work.publication_date.year}",
        ]
        
        # Add GROBID extracted sections if available
        if tei := await self.storage.load_tei(work_id):
            sections = self._extract_sections_from_tei(tei)
            text_parts.extend([
                f"Introduction: {sections.get('introduction', '')[:500]}",
                f"Methods: {sections.get('methods', '')[:500]}",
                f"Conclusion: {sections.get('conclusion', '')[:300]}",
            ])
        
        # Generate embeddings with section weights
        combined_text = "\n\n".join(text_parts)
        embeddings = await self.openai.embeddings.create(
            input=combined_text,
            model="text-embedding-3-large"
        )
        
        return embeddings
```

### 3.4 Citation-Aware Query Service

#### 3.4.1 Query Processing
```python
class QueryService:
    def __init__(self):
        self.qdrant = QdrantClient(host="localhost", port=6333)
        self.neo4j = Neo4jClient(uri="bolt://localhost:7687")
        self.meilisearch = MeiliClient("http://localhost:7700")
        self.openalex = OpenAlexClient()
        
    async def process_query(self, query: str) -> QueryResult:
        # Expand query with OpenAlex concepts
        concepts = await self._extract_concepts(query)
        expanded_query = self._expand_query_with_concepts(query, concepts)
        
        # Parallel execution of all search strategies
        vector_task = asyncio.create_task(
            self._vector_search(expanded_query)
        )
        graph_task = asyncio.create_task(
            self._graph_search(query, concepts)
        )
        keyword_task = asyncio.create_task(
            self._keyword_search(expanded_query)
        )
        citation_task = asyncio.create_task(
            self._citation_search(query)
        )
        
        # Wait max 150ms for results
        done, pending = await asyncio.wait(
            [vector_task, graph_task, keyword_task, citation_task],
            timeout=0.15,
            return_when=asyncio.ALL_COMPLETED
        )
        
        # Cancel slow operations
        for task in pending:
            task.cancel()
            
        # Merge results with citation-aware ranking
        results = self._merge_with_citation_boost(done)
        
        # Enrich with fresh metadata if needed
        results = await self._enrich_results(results)
        
        return results
    
    async def _citation_search(self, query: str):
        """Search based on citation patterns"""
        # Find seminal papers (high cited_by_count)
        cypher = """
        MATCH (w:Work)
        WHERE w.title CONTAINS $query OR w.abstract CONTAINS $query
        RETURN w
        ORDER BY w.cited_by_count DESC
        LIMIT 10
        """
        
        seminal_papers = await self.neo4j.run(cypher, query=query)
        
        # Find papers that cite multiple seminal papers
        if seminal_papers:
            work_ids = [p['w']['id'] for p in seminal_papers[:3]]
            cypher = """
            MATCH (w:Work)-[:CITES]->(s:Work)
            WHERE s.id IN $work_ids
            WITH w, COUNT(DISTINCT s) as citation_overlap
            WHERE citation_overlap >= 2
            RETURN w
            ORDER BY citation_overlap DESC, w.cited_by_count DESC
            LIMIT 20
            """
            citing_papers = await self.neo4j.run(cypher, work_ids=work_ids)
            
            return seminal_papers + citing_papers
        
        return []
```

### 3.5 Graph Database Design with Citations

#### 3.5.1 Neo4j Schema with OpenAlex
```cypher
// Node types with OpenAlex data
CREATE CONSTRAINT work_id ON (w:Work) ASSERT w.id IS UNIQUE;
CREATE CONSTRAINT author_orcid ON (a:Author) ASSERT a.orcid IS UNIQUE;
CREATE CONSTRAINT concept_id ON (c:Concept) ASSERT c.id IS UNIQUE;
CREATE CONSTRAINT venue_id ON (v:Venue) ASSERT v.id IS UNIQUE;
CREATE CONSTRAINT institution_ror ON (i:Institution) ASSERT i.ror IS UNIQUE;

// Indexes for performance
CREATE INDEX work_title ON :Work(title);
CREATE INDEX work_year ON :Work(publication_year);
CREATE INDEX work_citations ON :Work(cited_by_count);
CREATE INDEX concept_name ON :Concept(display_name);

// Relationships from OpenAlex
CREATE (w1:Work)-[:CITES]->(w2:Work)  // From referenced_works
CREATE (w1:Work)-[:RELATED_TO]->(w2:Work)  // From related_works
CREATE (w:Work)-[:HAS_CONCEPT {score: 0.8}]->(c:Concept)
CREATE (w:Work)-[:AUTHORED_BY {position: 1}]->(a:Author)
CREATE (w:Work)-[:PUBLISHED_IN]->(v:Venue)
CREATE (a:Author)-[:AFFILIATED_WITH]->(i:Institution)

// Derived relationships
CREATE (w:Work)-[:CONTRADICTS {claim: $claim}]->(w2:Work)
CREATE (m1:Method)-[:EXTENDS]->(m2:Method)
CREATE (w:Work)-[:INTRODUCES]->(m:Method)
```

#### 3.5.2 Citation Network Queries
```python
class CitationAnalyzer:
    async def find_citation_paths(self, from_work: str, to_work: str, max_depth: int = 3):
        """Find how papers are connected through citations"""
        cypher = """
        MATCH path = shortestPath(
            (w1:Work {id: $from_work})-[:CITES*..{max_depth}]->(w2:Work {id: $to_work})
        )
        RETURN path, 
               [n in nodes(path) | n.title] as titles,
               length(path) as hops
        """
        return await self.neo4j.run(cypher, 
                                   from_work=from_work, 
                                   to_work=to_work,
                                   max_depth=max_depth)
    
    async def find_common_ancestors(self, work_ids: List[str]):
        """Find papers cited by multiple works (common foundations)"""
        cypher = """
        MATCH (w:Work)-[:CITES]->(ancestor:Work)
        WHERE w.id IN $work_ids
        WITH ancestor, COUNT(DISTINCT w) as citing_count, COLLECT(w.title) as citing_papers
        WHERE citing_count >= 2
        RETURN ancestor, citing_count, citing_papers
        ORDER BY citing_count DESC, ancestor.cited_by_count DESC
        """
        return await self.neo4j.run(cypher, work_ids=work_ids)
```

### 3.6 Synthesis Service with Proper Citations

#### 3.6.1 OpenAlex-Aware Synthesis
```python
class SynthesisService:
    def __init__(self):
        self.openai = OpenAI()
        self.storage = WorkStorage()
        
    async def generate_synthesis(self, work_ids: List[str], synthesis_type: str) -> str:
        # Load full Work Objects with metadata
        works = await asyncio.gather(*[
            self.storage.load_work_object(wid) for wid in work_ids
        ])
        
        # Build context with proper citations
        context = self._build_context_with_citations(works)
        
        # Generate synthesis with citation instructions
        prompt = self._get_synthesis_prompt(synthesis_type, context)
        
        response = await self.openai.chat.completions.create(
            model="gpt-4-turbo",
            messages=[
                {"role": "system", "content": SYNTHESIS_SYSTEM_PROMPT},
                {"role": "user", "content": prompt}
            ],
            temperature=0.3,
            max_tokens=1000
        )
        
        # Post-process to ensure proper citation formatting
        synthesis = response.choices[0].message.content
        return self._format_citations(synthesis, works)
    
    def _build_context_with_citations(self, works: List[WorkObject]) -> str:
        context_parts = []
        
        for i, work in enumerate(works):
            # Create citation key [AuthorYear] or [FirstAuthorEtAl Year]
            if len(work.authors) == 1:
                citation_key = f"[{work.authors[0].family_name} {work.publication_year}]"
            elif len(work.authors) == 2:
                citation_key = f"[{work.authors[0].family_name} & {work.authors[1].family_name} {work.publication_year}]"
            else:
                citation_key = f"[{work.authors[0].family_name} et al. {work.publication_year}]"
            
            context_parts.append(f"""
Paper {i+1} {citation_key}:
Title: {work.title}
Venue: {work.venue.display_name if work.venue else 'Preprint'}
Abstract: {work.abstract}
Key Concepts: {', '.join(c.display_name for c in work.concepts[:5])}
Citations: {work.cited_by_count} citations as of {datetime.now().strftime('%Y-%m')}
DOI: {work.doi}
""")
        
        return "\n---\n".join(context_parts)
```

### 3.7 Pre-computation Engine with OpenAlex

#### 3.7.1 Pre-computation Pipeline
```python
class PreComputationEngine:
    async def run_initial_setup(self):
        """One-time setup with OpenAlex data"""
        tasks = [
            self._fetch_all_conference_papers(),
            self._build_concept_index(),
            self._compute_author_networks(),
            self._identify_seminal_papers(),
            self._cache_common_queries()
        ]
        
        await asyncio.gather(*tasks)
    
    async def _fetch_all_conference_papers(self):
        """Fetch all papers from target conferences"""
        venues = ["ICLR", "ICML", "NeurIPS"]
        years = range(2020, 2025)
        
        for venue in venues:
            for year in years:
                filter_query = f"venue.display_name:{venue},publication_year:{year}"
                
                cursor = "*"
                while cursor:
                    works = await self.openalex.search_works(
                        filter=filter_query,
                        cursor=cursor,
                        per_page=200
                    )
                    
                    # Process each work
                    for work in works['results']:
                        await self.ingest_paper(work['id'])
                    
                    cursor = works['meta'].get('next_cursor')
    
    async def _build_concept_index(self):
        """Build inverted index of concepts to papers"""
        concept_index = defaultdict(list)
        
        all_works = await self.storage.list_all_works()
        for work_id in all_works:
            work = await self.storage.load_work_object(work_id)
            for concept in work.concepts:
                concept_index[concept.id].append({
                    'work_id': work_id,
                    'score': concept.score,
                    'title': work.title
                })
        
        # Save index for fast concept-based search
        await self.storage.save_index('concepts', concept_index)
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
[Query Service] Parse Intent & Extract Concepts
    ↓
[Concept Expansion] Use OpenAlex concepts
    ↓
[Parallel Execution]
    ├→ [QDrant] Vector Search with metadata (50ms)
    ├→ [Neo4j] Citation-aware Graph Search (80ms)
    ├→ [Meilisearch] Keyword Match (30ms)
    └→ [Redis] Check pre-computed results (5ms)
    ↓
[Merge & Rank] Citation-boosted fusion
    ↓
[Enrich] Add fresh OpenAlex metadata if needed
    ↓
[Cache] Store result with TTL
    ↓
[Client] Progressive render with metadata
```

### 4.2 Paper Ingestion Pipeline
```
Paper Discovery (DOI/Title/PDF)
    ↓
[OpenAlex] Resolve to Work ID
    ↓
[Storage] Create W[ID]/ directory structure
    ↓
[OpenAlex] Fetch complete Work Object → W[ID].json
    ↓
[Download] Get PDF (if available) → W[ID].pdf
    ↓
[GROBID] Parse PDF → W[ID].tei.xml
    ↓
[Combine] Merge metadata + text
    ↓
[Generate] Enhanced embeddings → W[ID].embeddings.npy
    ↓
[Index] Update all databases
    ├→ [QDrant] Store embeddings with metadata
    ├→ [Neo4j] Build citation graph
    └→ [Meilisearch] Index text with concepts
```

## 5. API Specifications

### 5.1 REST Endpoints with OpenAlex Integration

#### 5.1.1 Query Endpoint
```yaml
POST /api/v1/query
Content-Type: application/json

Request:
{
  "query": "transformer efficiency improvements",
  "filters": {
    "year_range": [2020, 2024],
    "venues": ["ICLR", "NeurIPS", "ICML"],
    "concepts": ["Machine Learning", "Deep Learning"],
    "min_citations": 10,
    "open_access": true
  },
  "expand_concepts": true,
  "include_citations": true,
  "limit": 20
}

Response:
{
  "query_id": "q_1234567890",
  "expanded_concepts": [
    {"id": "C154945302", "display_name": "Transformer Networks", "score": 0.92},
    {"id": "C2776214958", "display_name": "Model Efficiency", "score": 0.87}
  ],
  "results": [
    {
      "work_id": "W302740479",
      "title": "Sparse Transformers: Efficient Attention Mechanisms",
      "doi": "10.1145/3297280.3297641",
      "venue": {
        "id": "V172146120",
        "display_name": "NeurIPS",
        "type": "conference"
      },
      "publication_year": 2023,
      "cited_by_count": 145,
      "authors": [
        {
          "id": "A2064505764",
          "display_name": "Jane Smith",
          "orcid": "0000-0002-1234-5678"
        }
      ],
      "concepts": [
        {"display_name": "Sparse Matrix", "score": 0.89},
        {"display_name": "Attention Mechanism", "score": 0.92}
      ],
      "relevance_score": 0.95,
      "citation_context": {
        "cites": ["W2964268362", "W2962775029"],
        "cited_by": ["W3127698451", "W3198237645"]
      },
      "open_access": {
        "is_oa": true,
        "oa_url": "https://arxiv.org/pdf/2301.12345.pdf"
      }
    }
  ],
  "citation_network": {
    "nodes": [...],
    "edges": [...]
  },
  "processing_time_ms": 142
}
```

#### 5.1.2 Work Object Endpoint
```yaml
GET /api/v1/works/{work_id}

Response:
{
  "work": {
    "id": "W302740479",
    "openalex_url": "https://openalex.org/W302740479",
    "title": "...",
    "abstract": "...",
    "full_metadata": {...},  # Complete OpenAlex Work Object
    "local_resources": {
      "pdf_available": true,
      "tei_available": true,
      "embeddings_computed": true
    }
  },
  "citation_analysis": {
    "influential_citations": [...],
    "citation_velocity": {...},
    "common_citing_works": [...]
  }
}
```

## 6. Database Schemas

### 6.1 QDrant Collections
```python
# Papers collection with OpenAlex metadata
papers_collection = {
    "name": "papers",
    "vector_size": 3072,  # text-embedding-3-large
    "distance": "Cosine",
    "payload_schema": {
        "work_id": "keyword",  # W302740479
        "title": "text",
        "doi": "keyword",
        "year": "integer",
        "venue_id": "keyword",
        "venue_name": "keyword",
        "concepts": "keyword[]",  # Array of concept IDs
        "author_ids": "keyword[]",
        "cited_by_count": "integer",
        "open_access": "bool",
        "section_type": "keyword"  # abstract, intro, method, etc.
    }
}

# Concept embeddings for query expansion
concepts_collection = {
    "name": "concepts",
    "vector_size": 3072,
    "payload_schema": {
        "concept_id": "keyword",
        "display_name": "text",
        "level": "integer",
        "works_count": "integer"
    }
}
```

### 6.2 Redis Cache Schema with OpenAlex
```python
# Cache patterns
CACHE_PATTERNS = {
    "work_object": "oa:work:{work_id}",  # Full Work Object
    "work_citations": "oa:citations:{work_id}",  # Citation list
    "author_works": "oa:author:{author_id}:works",
    "concept_works": "oa:concept:{concept_id}:works",
    "venue_papers": "oa:venue:{venue_id}:{year}",
    "query_result": "qr:{query_hash}",
    "citation_path": "cp:{from_id}:{to_id}",
    "common_ancestors": "ca:{work_ids_hash}"
}

# Longer TTLs for stable OpenAlex data
CACHE_TTLS = {
    "work_object": 86400,      # 24 hours (metadata stable)
    "work_citations": 43200,   # 12 hours (updates less frequently)
    "query_result": 3600,      # 1 hour
    "citation_path": 86400,    # 24 hours (stable)
}
```

## 7. Performance Engineering

### 7.1 Critical Path Optimization with Caching
```
Target: <200ms query response

Breakdown:
- Network latency: 20ms
- API Gateway: 10ms
- Cache check: 5ms (Redis)
- Concept expansion: 10ms (cached)
- Parallel searches: 80ms (max of all)
  - Vector search: 50ms (with metadata filter)
  - Graph query: 80ms (indexed)
  - Keyword search: 30ms
  - Citation lookup: 20ms (cached)
- Result merging: 15ms
- Response serialization: 10ms
- Network return: 20ms
- Client rendering: 20ms
------------------------
Total: 190ms (10ms buffer)
```

### 7.2 OpenAlex-Specific Optimizations

#### 7.2.1 Batch Processing
```python
# Batch fetch Work Objects to minimize API calls
async def batch_enrich_results(work_ids: List[str]):
    # Check cache for all IDs first
    cached = await redis.mget([f"oa:work:{wid}" for wid in work_ids])
    
    # Find missing IDs
    missing_ids = [wid for wid, cache in zip(work_ids, cached) if not cache]
    
    # Batch fetch missing from OpenAlex (max 200 per request)
    if missing_ids:
        for chunk in chunks(missing_ids, 200):
            works = await openalex.batch_get_works(chunk)
            # Cache results
            for work in works:
                await redis.setex(f"oa:work:{work.id}", 86400, work.to_json())
```

#### 7.2.2 Pre-computation Strategy
```python
# Pre-compute common concept combinations
COMMON_CONCEPTS = [
    ("Machine Learning", "Deep Learning"),
    ("Natural Language Processing", "Transformers"),
    ("Computer Vision", "Neural Networks"),
]

async def precompute_concept_searches():
    for concept_pair in COMMON_CONCEPTS:
        # Find papers with both concepts
        results = await find_papers_with_concepts(concept_pair)
        
        # Cache for instant retrieval
        cache_key = f"concepts:{':'.join(concept_pair)}"
        await redis.setex(cache_key, 86400, results)
```

## 8. Deployment Architecture

### 8.1 Docker Compose with OpenAlex Cache
```yaml
version: '3.8'

services:
  # Add persistent cache for OpenAlex data
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes:
      - redis_data:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    
  # File storage for Work Objects
  minio:
    image: minio/minio
    ports: ["9000:9000", "9001:9001"]
    volumes:
      - minio_data:/data
    environment:
      - MINIO_ROOT_USER=leibniz
      - MINIO_ROOT_PASSWORD=leibniz123
    command: server /data --console-address ":9001"
    
  # Data pipeline service
  data-pipeline:
    build: ./services/pipeline
    depends_on:
      - redis
      - neo4j
      - qdrant
    environment:
      - OPENALEX_RATE_LIMIT=10
      - BATCH_SIZE=200
    volumes:
      - ./data/works:/data/works

volumes:
  redis_data:
  minio_data:
  works_data:
```

## 9. Monitoring and Observability

### 9.1 OpenAlex-Specific Metrics
```python
# Prometheus metrics for OpenAlex integration
openalex_api_calls = Counter(
    'openalex_api_calls_total',
    'Total OpenAlex API calls',
    ['endpoint', 'status']
)

openalex_cache_hits = Counter(
    'openalex_cache_hits_total',
    'OpenAlex cache hit rate',
    ['object_type']  # work, author, venue, concept
)

metadata_completeness = Gauge(
    'metadata_completeness_ratio',
    'Percentage of papers with complete metadata'
)

citation_network_size = Gauge(
    'citation_network_edges_total',
    'Total edges in citation graph'
)
```

## 10. Error Handling

### 10.1 OpenAlex API Failures
```python
async def get_work_with_fallback(identifier: str):
    try:
        # Try OpenAlex first
        return await openalex.get_work(identifier)
    except OpenAlexAPIError:
        logger.warning(f"OpenAlex API failed for {identifier}")
        
        # Try local cache
        if cached := await local_storage.find_by_title(identifier):
            return cached
            
        # Create minimal Work Object from available data
        return create_minimal_work_object(identifier)
```

## 11. Testing Architecture

### 11.1 OpenAlex Mock Data
```python
# Generate realistic test data with OpenAlex structure
class OpenAlexMockGenerator:
    def generate_work_object(self, work_id: str):
        return {
            "id": f"https://openalex.org/{work_id}",
            "doi": f"https://doi.org/10.1234/{work_id}",
            "title": self.fake.sentence(),
            "publication_date": "2023-01-15",
            "cited_by_count": random.randint(0, 500),
            "referenced_works": [
                f"https://openalex.org/W{random.randint(1000, 9999)}"
                for _ in range(random.randint(10, 50))
            ],
            "concepts": [
                {
                    "id": f"https://openalex.org/C{random.randint(1000, 9999)}",
                    "display_name": random.choice(["Deep Learning", "NLP", "Computer Vision"]),
                    "score": random.uniform(0.5, 1.0)
                }
                for _ in range(random.randint(3, 7))
            ]
        }
```

## 12. Migration Strategy

### 12.1 Existing Data Migration
```python
# Migrate existing papers to OpenAlex-based system
async def migrate_to_openalex():
    existing_papers = await get_all_existing_papers()
    
    for paper in existing_papers:
        # Try to find OpenAlex Work
        if doi := paper.get('doi'):
            work = await openalex.get_work(f"doi:{doi}")
        elif title := paper.get('title'):
            work = await openalex.search_work_by_title(title)
        else:
            logger.warning(f"Cannot migrate paper without DOI or title: {paper}")
            continue
            
        # Create new structure
        work_id = work.id.split("/")[-1]
        await storage.migrate_paper_to_work(paper, work_id)
```

## 13. Version History

| Version | Date     | Author       | Changes                                   |
|---------|----------|--------------|-------------------------------------------|
| 1.0     | Jun 2025 | Project Team | Initial architecture design               |
| 2.0     | Jun 2025 | Project Team | Integrated OpenAlex as foundational layer |

---

**Document Status:** Ready for Review  
**Next Step:** Implementation Planning with OpenAlex Integration