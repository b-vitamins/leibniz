# Project Leibniz - Requirements Analysis Document

**Version:** 2.0  
**Date:** June 2025
**Status:** Revised with OpenAlex Integration  
**Classification:** Internal Development

## 1. Executive Summary

Project Leibniz is a speed-optimized research literature intelligence system designed to reduce the time between research ideation and comprehensive understanding from hours to seconds. The system combines OpenAlex metadata enrichment, vector search, knowledge graphs, and predictive AI to deliver "research at the speed of thought."

### 1.1 Vision Statement
Enable researchers to explore, understand, and synthesize ML literature as fast as they can think, transforming literature review from a multi-hour task to a sub-second experience.

### 1.2 Project Scope
Weekend prototype covering ICLR, ICML, and NeurIPS papers from 2020-2024 (~5,000 papers), demonstrating 10-50x speed improvements in common research tasks. Papers are identified and enriched using OpenAlex Work Object IDs as the primary identifier system.

## 2. Stakeholder Analysis

| Stakeholder        | Role          | Key Needs                                                                                            |
|--------------------|---------------|------------------------------------------------------------------------------------------------------|
| ML Researchers     | Primary Users | Fast literature discovery, gap identification, contradiction detection, citation network exploration |
| Research Engineers | Power Users   | Code extraction, method comparison, implementation details, reproducibility information              |
| Project Developer  | Builder       | Clear requirements, feasible weekend scope, reliable metadata sources                                |
| Research Community | Beneficiaries | Increased research velocity, fewer duplicate efforts, better citation tracking                       |

## 3. Functional Requirements

### 3.1 Core Capabilities

#### FR-001: Natural Language Query Interface
- **Priority:** P0 (Essential)
- **Description:** Accept conversational queries about ML research
- **Acceptance Criteria:**
  - Supports free-form questions like "What if we combined X with Y?"
  - Provides query autocomplete within 50ms
  - Handles incomplete/partial queries gracefully
  - Leverages OpenAlex concepts and topics for query expansion

#### FR-002: Instant Paper Discovery
- **Priority:** P0 (Essential)
- **Description:** Retrieve relevant papers in <200ms
- **Acceptance Criteria:**
  - Semantic search across 5,000 papers using enriched metadata
  - Returns ranked results with snippets
  - Highlights query matches in results
  - Shows OpenAlex citation count and impact metrics

#### FR-003: OpenAlex Metadata Integration
- **Priority:** P0 (Essential)
- **Description:** Enrich all papers with OpenAlex Work Object metadata
- **Acceptance Criteria:**
  - Fetch and store Work Objects for all papers
  - Use OpenAlex IDs (e.g., W302740479) as primary identifiers
  - Extract citation networks from referenced_works and related_works
  - Leverage concepts, topics, and keywords for enhanced search
  - Track publication venues, authors with ORCID, and institutions

#### FR-004: Citation Network Analysis
- **Priority:** P0 (Essential)
- **Description:** Build and traverse citation graphs using OpenAlex data
- **Acceptance Criteria:**
  - Construct forward and backward citation networks
  - Identify seminal papers and citation patterns
  - Track citation velocity and impact over time
  - Show citation context when available

#### FR-005: Contradiction Detection
- **Priority:** P0 (Essential)
- **Description:** Automatically identify conflicting claims between papers
- **Acceptance Criteria:**
  - Identifies contradictory statements using both text and metadata
  - Shows evidence from both papers
  - Suggests potential reasons for disagreement
  - Considers publication dates and citation relationships

#### FR-006: Research Gap Analysis
- **Priority:** P0 (Essential)
- **Description:** Identify unexplored method/dataset combinations
- **Acceptance Criteria:**
  - Analyzes method-dataset matrix enriched with OpenAlex topics
  - Ranks gaps by potential impact and feasibility
  - Provides "why unexplored" hypothesis
  - Suggests related unexplored concepts from OpenAlex

#### FR-007: Enhanced Embedding Generation
- **Priority:** P0 (Essential)
- **Description:** Create superior embeddings using combined metadata
- **Acceptance Criteria:**
  - Combines GROBID-extracted text with OpenAlex metadata
  - Includes title, abstract, concepts, and topics in embeddings
  - Weights sections based on relevance
  - Achieves better semantic similarity than text-only embeddings

#### FR-008: Method Genealogy Tracking
- **Priority:** P1 (Important)
- **Description:** Trace evolution of methods across papers using citations
- **Acceptance Criteria:**
  - Shows method inheritance tree with citation paths
  - Identifies original vs derived work using citation data
  - Tracks performance improvements across generations
  - Links to author networks and institution patterns

#### FR-009: Speed Review Generation
- **Priority:** P1 (Important)
- **Description:** Auto-generate related work sections with proper citations
- **Acceptance Criteria:**
  - Produces 200-word summaries with OpenAlex citation formatting
  - Includes proper citations with DOIs
  - Groups papers by concepts and topics
  - Completes in <10 seconds

#### FR-010: Interactive Knowledge Graph
- **Priority:** P1 (Important)
- **Description:** Visual exploration of paper relationships and citations
- **Acceptance Criteria:**
  - Real-time graph updates showing citation networks
  - Clickable nodes/edges with metadata popups
  - Multiple layout algorithms (citation-based, topic-based)
  - Filter by OpenAlex concepts, venues, or time periods

### 3.2 Predictive Features

#### FR-011: Thought Completion
- **Priority:** P1 (Important)
- **Description:** Predict and pre-load likely next queries
- **Acceptance Criteria:**
  - Suggests completions based on OpenAlex concepts
  - Pre-fetches top 3 likely paths
  - Learns from usage patterns
  - Leverages topic co-occurrence data

#### FR-012: Research Recipe Generation
- **Priority:** P2 (Desirable)
- **Description:** Suggest novel research directions
- **Acceptance Criteria:**
  - Combines unexplored methods using concept analysis
  - Estimates success probability based on citation patterns
  - Provides implementation hints
  - Suggests collaborators based on author expertise

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-001: Query Response Time
- **Metric:** 95th percentile latency
- **Target:** <200ms for primary queries
- **Measurement:** Client-side timer from query submit to first result

#### NFR-002: Metadata Retrieval Speed
- **Metric:** Time to fetch OpenAlex Work Object
- **Target:** <100ms from cache, <500ms from API
- **Measurement:** API response time monitoring

#### NFR-003: System Startup Time
- **Metric:** Time to interactive with pre-loaded metadata
- **Target:** <3 seconds
- **Measurement:** Page load to first query capability

### 4.2 Data Quality Requirements

#### NFR-004: Metadata Completeness
- **Metric:** Percentage of papers with full OpenAlex metadata
- **Target:** >95% coverage
- **Measurement:** Automated completeness checks

#### NFR-005: Citation Accuracy
- **Metric:** Accuracy of citation relationships
- **Target:** >99% match with OpenAlex data
- **Measurement:** Validation against source data

### 4.3 Scalability Requirements

#### NFR-006: Data Volume
- **Metric:** Number of indexed papers with full metadata
- **Target:** 5,000 papers (weekend scope)
- **Growth:** Architecture supports 50,000+ papers

#### NFR-007: API Rate Limits
- **Metric:** OpenAlex API calls per second
- **Target:** Stay within free tier (10 requests/second)
- **Measurement:** Rate limiter metrics

## 5. System Constraints

### 5.1 Technical Constraints
- **Development Time:** 48 hours
- **Infrastructure:** Local development machine + free-tier cloud services
- **Dependencies:** OpenAlex API, GROBID, Neo4j, QDrant, Meilisearch, OpenAI API
- **Budget:** <$100 for API calls during development

### 5.2 Data Constraints
- **Paper Access:** Only publicly available PDFs with OpenAlex records
- **Metadata:** Limited to OpenAlex available data + GROBID extraction
- **Storage:** ~50GB for papers + indexes + metadata cache

### 5.3 API Constraints
- **OpenAlex:** Free tier rate limits (10 req/s, no auth required)
- **Data Freshness:** OpenAlex updates weekly, cache accordingly

## 6. Use Cases

### UC-001: Rapid Literature Survey with Citation Context
**Actor:** ML Researcher  
**Precondition:** Has research question  
**Flow:**
1. User types natural language query
2. System expands query using OpenAlex concepts
3. System shows instant results with citation counts
4. User explores citation network for key papers
5. System shows related papers based on citations and topics
6. User requests summary generation
7. System produces draft with proper citations

**Postcondition:** User has comprehensive view with citation context in <5 minutes

### UC-002: Research Gap Discovery via Concept Analysis
**Actor:** Research Engineer  
**Precondition:** Looking for novel research direction  
**Flow:**
1. User explores method/dataset/concept combinations
2. System analyzes OpenAlex topic coverage
3. System highlights unexplored areas
4. User investigates specific gap
5. System shows why gap exists using citation data
6. User requests implementation sketch

**Postcondition:** User has actionable research direction backed by data

### UC-003: Citation-Aware Contradiction Resolution
**Actor:** ML Researcher  
**Precondition:** Found conflicting claims  
**Flow:**
1. System auto-highlights contradictions
2. User clicks contradiction indicator
3. System shows both claims with publication context
4. System displays citation relationships between papers
5. System suggests experimental differences
6. User explores resolution paths

**Postcondition:** User understands source of conflict and research evolution

## 7. Data Model Requirements

### 7.1 Core Entities
- **Work:** OpenAlex ID, title, DOI, publication_date, open_access status
- **Paper:** Work_ID (primary key), PDF_path, TEI_XML_path, embeddings
- **Author:** ORCID, name, institutions, h-index, works_count
- **Venue:** ISSN, name, type, publisher, impact_factor
- **Concept:** OpenAlex concept_id, display_name, level, score
- **Citation:** from_work_id, to_work_id, context, section
- **Institution:** ROR ID, name, country, type

### 7.2 File Organization
- **Naming Convention:** 
  - `W[ID].json` - OpenAlex Work Object
  - `W[ID].pdf` - Paper PDF
  - `W[ID].tei.xml` - GROBID extracted XML
  - `W[ID].embeddings.npy` - Pre-computed embeddings

### 7.3 Relationships
- Works → cite → Works (via referenced_works)
- Works → authored_by → Authors
- Works → published_in → Venues
- Works → has_concept → Concepts
- Authors → affiliated_with → Institutions

## 8. Interface Requirements

### 8.1 Query Interface
- Single search box with OpenAlex concept autocomplete
- Natural language processing with concept expansion
- Query history with branching
- Filter by venue, year, open access status

### 8.2 Results Display
- Instant skeleton loading
- Progressive enhancement with metadata
- Citation count and venue impact display
- Highlighted matches
- Expandable citation network view

### 8.3 Visualization
- Interactive citation network graph
- Timeline slider for temporal views
- Contradiction indicators (red edges)
- Gap highlighting (dotted connections)
- Concept clustering view

## 9. Integration Requirements

### 9.1 External Services
- **OpenAlex:** Metadata enrichment (API, no auth needed)
- **GROBID:** PDF parsing (self-hosted)
- **OpenAI:** Embeddings and synthesis (API)

### 9.2 Data Pipeline
1. Paper Discovery → OpenAlex Work lookup
2. Download PDF → Name as W[ID].pdf
3. Fetch Work Object → Save as W[ID].json
4. PDF → GROBID → W[ID].tei.xml
5. Combine metadata + TEI → Enhanced embeddings
6. Build citation graph from referenced_works
7. Index in QDrant (embeddings) + Neo4j (graph) + Meilisearch (text)

## 10. Success Criteria

### 10.1 Quantitative Metrics
| Metric | Baseline | Target | Stretch |
|--------|----------|--------|---------|
| Literature survey time | 6-8 hours | 10 min | 5 min |
| Query response time | N/A | 200ms | 100ms |
| Gap identification | Manual/Lucky | 30 sec | 10 sec |
| Citation network exploration | 30 min | 30 sec | 10 sec |
| Related work generation | 1 hour | 1 min | 30 sec |
| Metadata completeness | 0% | 95% | 99% |

### 10.2 Qualitative Metrics
- User reaction: "This understands papers better than keyword search!"
- Citation network insights: "I found papers I didn't know existed"
- Willingness to use daily: >90%
- Research velocity improvement: Subjectively 10x

## 11. Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| OpenAlex API downtime | Low | High | Cache aggressively, batch fetch |
| Missing OpenAlex records | Medium | Medium | Fallback to DOI/title search |
| GROBID parsing failures | Medium | High | Pre-parse papers, handle failures gracefully |
| Citation data incomplete | Low | Medium | Use multiple citation sources |
| Complex data integration | High | High | Start with OpenAlex early, test pipeline |
| 48-hour time constraint | High | High | Pre-fetch common conference papers |

## 12. Assumptions and Dependencies

### 12.1 Assumptions
- OpenAlex has records for most ML conference papers
- OpenAlex Work IDs are stable identifiers
- Citation networks are mostly complete
- Metadata + text produces better embeddings
- 5,000 papers with metadata fit in memory

### 12.2 Dependencies
- OpenAlex API available and responsive
- Papers have DOIs or identifiable titles
- GROBID service available and stable
- OpenAI API access with sufficient quota
- Local machine has >16GB RAM, SSD

## 13. Development Priorities

### Phase 1 (Hours 0-16): Foundation with OpenAlex
1. OpenAlex integration and Work Object fetching
2. Paper ingestion pipeline with ID mapping
3. Enhanced embedding generation
4. Basic query interface

### Phase 2 (Hours 16-32): Intelligence Layer
1. Citation network construction
2. Contradiction detection with context
3. Gap analysis with concepts
4. Knowledge graph with citations

### Phase 3 (Hours 32-48): Polish & Demo
1. Performance optimization
2. UI polish with metadata display
3. Demo preparation with citation stories

## 14. Acceptance Test Scenarios

### ATS-001: Speed of Thought with Smart Results
**Scenario:** User types "transformer efficiency"  
**Expected:** Results appear before finishing typing, sorted by citations  
**Pass Criteria:** <200ms to first result with metadata

### ATS-002: Citation-Aware Contradiction Discovery
**Scenario:** System shows papers with conflicting claims  
**Expected:** Red edge in graph, citation relationship shown  
**Pass Criteria:** Accurate contradiction with publication context

### ATS-003: Concept-Based Gap Identification
**Scenario:** User explores method/concept combinations  
**Expected:** Unexplored areas highlighted with topic analysis  
**Pass Criteria:** Valid research opportunities with feasibility scores

### ATS-004: Rich Metadata Display
**Scenario:** User views paper details  
**Expected:** Full OpenAlex metadata with citations, concepts, venues  
**Pass Criteria:** 95%+ papers have complete metadata

## 15. Version History

| Version | Date     | Author       | Changes                                  |
|---------|----------|--------------|------------------------------------------|
| 1.0     | Jun 2025 | Project Team | Initial requirements analysis            |
| 2.0     | Jun 2025 | Project Team | Added OpenAlex integration as foundation |

---

**Document Status:** Ready for Review  
**Next Step:** Technical Architecture Design with OpenAlex Integration