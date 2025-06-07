# Project Leibniz - Requirements Analysis Document

**Version:** 1.0  
**Date:** December 2024  
**Status:** Draft  
**Classification:** Internal Development

## 1. Executive Summary

Project Leibniz is a speed-optimized research literature intelligence system designed to reduce the time between research ideation and comprehensive understanding from hours to seconds. The system combines vector search, knowledge graphs, and predictive AI to deliver "research at the speed of thought."

### 1.1 Vision Statement
Enable researchers to explore, understand, and synthesize ML literature as fast as they can think, transforming literature review from a multi-hour task to a sub-second experience.

### 1.2 Project Scope
Weekend prototype covering ICLR, ICML, and NeurIPS papers from 2020-2024 (~5,000 papers), demonstrating 10-50x speed improvements in common research tasks.

## 2. Stakeholder Analysis

| Stakeholder | Role | Key Needs |
|------------|------|-----------|
| ML Researchers | Primary Users | Fast literature discovery, gap identification, contradiction detection |
| Research Engineers | Power Users | Code extraction, method comparison, implementation details |
| Project Developer | Builder | Clear requirements, feasible weekend scope |
| Research Community | Beneficiaries | Increased research velocity, fewer duplicate efforts |

## 3. Functional Requirements

### 3.1 Core Capabilities

#### FR-001: Natural Language Query Interface
- **Priority:** P0 (Essential)
- **Description:** Accept conversational queries about ML research
- **Acceptance Criteria:**
  - Supports free-form questions like "What if we combined X with Y?"
  - Provides query autocomplete within 50ms
  - Handles incomplete/partial queries gracefully

#### FR-002: Instant Paper Discovery
- **Priority:** P0 (Essential)
- **Description:** Retrieve relevant papers in <200ms
- **Acceptance Criteria:**
  - Semantic search across 5,000 papers
  - Returns ranked results with snippets
  - Highlights query matches in results

#### FR-003: Contradiction Detection
- **Priority:** P0 (Essential)
- **Description:** Automatically identify conflicting claims between papers
- **Acceptance Criteria:**
  - Identifies contradictory statements
  - Shows evidence from both papers
  - Suggests potential reasons for disagreement

#### FR-004: Research Gap Analysis
- **Priority:** P0 (Essential)
- **Description:** Identify unexplored method/dataset combinations
- **Acceptance Criteria:**
  - Analyzes method-dataset matrix
  - Ranks gaps by potential impact
  - Provides "why unexplored" hypothesis

#### FR-005: Method Genealogy Tracking
- **Priority:** P1 (Important)
- **Description:** Trace evolution of methods across papers
- **Acceptance Criteria:**
  - Shows method inheritance tree
  - Identifies original vs derived work
  - Tracks performance improvements

#### FR-006: Speed Review Generation
- **Priority:** P1 (Important)
- **Description:** Auto-generate related work sections
- **Acceptance Criteria:**
  - Produces 200-word summaries
  - Includes proper citations
  - Completes in <10 seconds

#### FR-007: Interactive Knowledge Graph
- **Priority:** P1 (Important)
- **Description:** Visual exploration of paper relationships
- **Acceptance Criteria:**
  - Real-time graph updates
  - Clickable nodes/edges
  - Multiple layout algorithms

#### FR-008: Code/Method Extraction
- **Priority:** P2 (Desirable)
- **Description:** Extract implementation details from papers
- **Acceptance Criteria:**
  - Identifies code blocks/pseudocode
  - Extracts key equations
  - Links to GitHub repos if mentioned

### 3.2 Predictive Features

#### FR-009: Thought Completion
- **Priority:** P1 (Important)
- **Description:** Predict and pre-load likely next queries
- **Acceptance Criteria:**
  - Suggests completions in <50ms
  - Pre-fetches top 3 likely paths
  - Learns from usage patterns

#### FR-010: Research Recipe Generation
- **Priority:** P2 (Desirable)
- **Description:** Suggest novel research directions
- **Acceptance Criteria:**
  - Combines unexplored methods
  - Estimates success probability
  - Provides implementation hints

## 4. Non-Functional Requirements

### 4.1 Performance Requirements

#### NFR-001: Query Response Time
- **Metric:** 95th percentile latency
- **Target:** <200ms for primary queries
- **Measurement:** Client-side timer from query submit to first result

#### NFR-002: Autocomplete Latency
- **Metric:** Time to show suggestions
- **Target:** <50ms
- **Measurement:** Keystroke to suggestion display

#### NFR-003: System Startup Time
- **Metric:** Time to interactive
- **Target:** <3 seconds
- **Measurement:** Page load to first query capability

#### NFR-004: Concurrent Users
- **Metric:** Simultaneous active sessions
- **Target:** 10 users (prototype scope)
- **Measurement:** Load testing with maintained response times

### 4.2 Scalability Requirements

#### NFR-005: Data Volume
- **Metric:** Number of indexed papers
- **Target:** 5,000 papers (weekend scope)
- **Growth:** Architecture supports 50,000+ papers

#### NFR-006: Query Throughput
- **Metric:** Queries per second
- **Target:** 100 QPS
- **Measurement:** Benchmark testing

### 4.3 Usability Requirements

#### NFR-007: Learning Curve
- **Metric:** Time to first successful query
- **Target:** <30 seconds for new users
- **Measurement:** User testing

#### NFR-008: Error Recovery
- **Metric:** Clear error messages
- **Target:** 100% actionable error messages
- **Measurement:** Error message audit

### 4.4 Reliability Requirements

#### NFR-009: System Availability
- **Metric:** Uptime percentage
- **Target:** 95% (demo scope)
- **Measurement:** Monitoring logs

## 5. System Constraints

### 5.1 Technical Constraints
- **Development Time:** 48 hours
- **Infrastructure:** Local development machine + free-tier cloud services
- **Dependencies:** GROBID, Neo4j, QDrant, Meilisearch, OpenAI API
- **Budget:** <$100 for API calls during development

### 5.2 Data Constraints
- **Paper Access:** Only publicly available PDFs
- **Metadata:** Limited to OpenAlex available data
- **Storage:** ~50GB for papers + indexes

## 6. Use Cases

### UC-001: Rapid Literature Survey
**Actor:** ML Researcher  
**Precondition:** Has research question  
**Flow:**
1. User types natural language query
2. System shows instant results with snippets
3. User clicks to expand interesting papers
4. System shows related papers and contradictions
5. User requests summary generation
6. System produces draft related work section

**Postcondition:** User has comprehensive view in <5 minutes

### UC-002: Research Gap Discovery
**Actor:** Research Engineer  
**Precondition:** Looking for novel research direction  
**Flow:**
1. User explores method combinations
2. System highlights unexplored areas
3. User investigates specific gap
4. System shows why gap exists
5. User requests implementation sketch
6. System provides starter code

**Postcondition:** User has actionable research direction

### UC-003: Contradiction Resolution
**Actor:** ML Researcher  
**Precondition:** Found conflicting claims  
**Flow:**
1. System auto-highlights contradictions
2. User clicks contradiction indicator
3. System shows both claims with context
4. System suggests experimental differences
5. User explores resolution paths

**Postcondition:** User understands source of conflict

## 7. Data Model Requirements

### 7.1 Core Entities
- **Paper:** ID, title, authors, venue, year, abstract, sections
- **Method:** Name, description, paper_id, equations, code
- **Dataset:** Name, domain, size, paper_references
- **Metric:** Name, higher_better, typical_range
- **Result:** Paper_id, method_id, dataset_id, metric_id, value
- **Citation:** From_paper, to_paper, citation_type, context

### 7.2 Relationships
- Papers → cite → Papers
- Papers → introduce → Methods
- Papers → evaluate_on → Datasets
- Methods → extend → Methods
- Papers → report → Results

## 8. Interface Requirements

### 8.1 Query Interface
- Single search box with autocomplete
- Natural language processing
- Query history with branching

### 8.2 Results Display
- Instant skeleton loading
- Progressive enhancement
- Highlighted matches
- Expandable details

### 8.3 Visualization
- Interactive force-directed graph
- Timeline slider for temporal views
- Contradiction indicators (red edges)
- Gap highlighting (dotted connections)

## 9. Integration Requirements

### 9.1 External Services
- **GROBID:** PDF parsing (self-hosted)
- **OpenAlex:** Metadata enrichment (API)
- **OpenAI:** Embeddings and synthesis (API)

### 9.2 Data Pipeline
- PDF → GROBID → Structured JSON
- JSON → Neo4j (relationships)
- JSON → QDrant (embeddings)
- JSON → Meilisearch (keywords)

## 10. Success Criteria

### 10.1 Quantitative Metrics
| Metric | Baseline | Target | Stretch |
|--------|----------|--------|---------|
| Literature survey time | 6-8 hours | 10 min | 5 min |
| Query response time | N/A | 200ms | 100ms |
| Gap identification | Manual/Lucky | 30 sec | 10 sec |
| Related work generation | 1 hour | 1 min | 30 sec |

### 10.2 Qualitative Metrics
- User reaction: "Wow, this is magic!"
- Willingness to use daily: >90%
- Research velocity improvement: Subjectively 10x

## 11. Risk Analysis

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| GROBID parsing failures | Medium | High | Pre-parse papers, handle failures gracefully |
| OpenAI API rate limits | Medium | Medium | Implement caching, batch requests |
| 48-hour time constraint | High | High | Ruthless prioritization, parallel work |
| Performance targets missed | Medium | High | Pre-compute common queries, optimize critical path |
| Neo4j query complexity | Low | Medium | Limit graph traversal depth |

## 12. Assumptions and Dependencies

### 12.1 Assumptions
- Papers are in English
- PDF quality sufficient for GROBID
- OpenAI embeddings capture semantic similarity
- 5,000 papers fit in memory for fast access

### 12.2 Dependencies
- GROBID service available and stable
- OpenAI API access with sufficient quota
- Local machine has >16GB RAM, SSD
- Docker for service orchestration

## 13. Development Priorities

### Phase 1 (Hours 0-16): Core Pipeline
1. Paper ingestion pipeline
2. Vector search implementation
3. Basic query interface

### Phase 2 (Hours 16-32): Intelligence Layer
1. Contradiction detection
2. Gap analysis
3. Knowledge graph

### Phase 3 (Hours 32-48): Polish & Demo
1. Performance optimization
2. UI polish
3. Demo preparation

## 14. Acceptance Test Scenarios

### ATS-001: Speed of Thought
**Scenario:** User types "transformer efficiency"  
**Expected:** Results appear before finishing typing  
**Pass Criteria:** <200ms to first result

### ATS-002: Contradiction Discovery
**Scenario:** System shows papers with conflicting claims  
**Expected:** Red edge in graph, click shows details  
**Pass Criteria:** Accurate contradiction identification

### ATS-003: Gap Identification
**Scenario:** User explores method combinations  
**Expected:** Unexplored areas highlighted  
**Pass Criteria:** Valid research opportunities surfaced

## 15. Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | Dec 2024 | Project Team | Initial requirements analysis |

---

**Document Status:** Ready for Review  
**Next Step:** Technical Architecture Design