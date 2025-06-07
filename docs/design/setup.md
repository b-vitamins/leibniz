# Project Leibniz - Development Environment Setup Guide

**Version:** 2.0  
**Date:** June 2025
**Status:** Revised with OpenAlex Integration  
**Time to Complete:** 30 minutes

## 1. Quick Start (5 minutes)

### 1.1 One-Command Setup

```bash
# Clone and setup everything
git clone https://github.com/b-vitamins/project-leibniz.git
cd project-leibniz
./scripts/setup.sh  # Runs everything below automatically
```

### 1.2 Manual Setup If Needed

```bash
# 1. Check prerequisites
./scripts/check-prerequisites.sh

# 2. Create environment file with OpenAlex config
cp .env.example .env
# Edit .env with your OpenAI API key and email for OpenAlex

# 3. Start all services
docker-compose up -d

# 4. Verify health
./scripts/health-check.sh

# 5. Test OpenAlex connection
./scripts/test-openalex.sh

# 6. Load sample data with metadata
./scripts/load-sample-data.sh --with-openalex
```

## 2. Prerequisites

### 2.1 Required Software

| Software       | Minimum Version | Check Command              | Install Guide                       |
|----------------|-----------------|----------------------------|-------------------------------------|
| Docker         | 20.10+          | `docker --version`         | https://docs.docker.com/get-docker/ |
| Docker Compose | 2.0+            | `docker-compose --version` | Included with Docker Desktop        |
| Git            | 2.30+           | `git --version`            | https://git-scm.com/downloads       |
| Python         | 3.10+           | `python3 --version`        | https://python.org/downloads        |
| Node.js        | 18+             | `node --version`           | https://nodejs.org                  |
| Make           | 3.81+           | `make --version`           | Usually pre-installed               |

### 2.2 API Requirements

- **OpenAI API Key**: Required for embeddings and synthesis
- **OpenAlex**: No API key needed, but polite crawling requires email
- **Internet Connection**: Required for metadata fetching

### 2.3 Hardware Requirements

- **RAM:** 16GB minimum (32GB recommended)
- **Storage:** 100GB free space (for papers + indexes + metadata)
- **CPU:** 4+ cores (8+ recommended)
- **Network:** Stable internet for API calls

## 3. Automated Setup Scripts

### 3.1 Main Setup Script (Enhanced)

```bash
#!/bin/bash
# scripts/setup.sh

set -euo pipefail

echo "🚀 Project Leibniz Setup Starting..."

# Check prerequisites
./scripts/check-prerequisites.sh || exit 1

# Setup environment
if [ ! -f .env ]; then
    cp .env.example .env
    echo "⚠️  Please edit .env with your API keys and email"
    echo "   - OpenAI API key (required)"
    echo "   - Email for OpenAlex polite crawling (recommended)"
    read -p "Press enter after adding your credentials..."
fi

# Create necessary directories with OpenAlex structure
mkdir -p data/{works,cache,indices,pdfs,processed,embeddings}
mkdir -p logs/{services,frontend,openalex}
mkdir -p scripts/prefetch

# Pull all Docker images in parallel
echo "📦 Pulling Docker images..."
docker-compose pull &

# Install frontend dependencies
echo "📦 Installing frontend dependencies..."
(cd frontend && npm install) &

# Install Python dependencies for scripts
echo "🐍 Installing Python dependencies..."
pip install -r requirements-dev.txt &

wait  # Wait for all parallel tasks

# Start services
echo "🐳 Starting Docker services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy..."
./scripts/wait-for-services.sh

# Run health check
echo "🏥 Running health checks..."
./scripts/health-check.sh

# Test OpenAlex connectivity
echo "🌐 Testing OpenAlex API..."
./scripts/test-openalex.sh

# Initialize Neo4j schema for OpenAlex
echo "📊 Setting up Neo4j schema..."
./scripts/init-neo4j-schema.sh

echo "✅ Setup complete! Run 'make dev' to start developing"
```

### 3.2 OpenAlex Test Script

```bash
#!/bin/bash
# scripts/test-openalex.sh

echo "🌐 Testing OpenAlex API connectivity..."

# Test with a known paper (Attention Is All You Need)
python3 << 'EOF'
import httpx
import json
import os

email = os.getenv("OPENALEX_EMAIL", "test@example.com")
test_doi = "10.48550/arXiv.1706.03762"

print(f"Using email: {email}")
print(f"Testing with DOI: {test_doi}")

try:
    response = httpx.get(
        f"https://api.openalex.org/works/doi:{test_doi}",
        params={"mailto": email},
        timeout=10.0
    )
    
    if response.status_code == 200:
        work = response.json()
        print(f"✅ OpenAlex API working!")
        print(f"   Found: {work['title']}")
        print(f"   Citations: {work['cited_by_count']}")
        print(f"   Work ID: {work['id'].split('/')[-1]}")
    else:
        print(f"❌ OpenAlex returned status {response.status_code}")
        
except Exception as e:
    print(f"❌ OpenAlex test failed: {e}")
    print("   Check your internet connection")
EOF
```

### 3.3 Enhanced Health Check Script

```bash
#!/bin/bash
# scripts/health-check.sh

echo "🏥 Running health checks..."

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

check_service() {
    SERVICE=$1
    PORT=$2
    ENDPOINT=${3:-/}
    
    if curl -f -s "http://localhost:$PORT$ENDPOINT" > /dev/null; then
        echo -e "${GREEN}✅ $SERVICE is healthy${NC}"
        return 0
    else
        echo -e "${RED}❌ $SERVICE is not responding${NC}"
        return 1
    fi
}

# Check each service
check_service "Redis" 6379 || true
check_service "Neo4j" 7474 || true
check_service "QDrant" 6333 "/collections" || true
check_service "Meilisearch" 7700 "/health" || true
check_service "GROBID" 8070 "/api/version" || true
check_service "API Gateway" 3000 "/health" || true
check_service "Query Service" 8001 "/health" || true
check_service "Frontend" 5173 || true

# Check OpenAlex metadata cache
echo -e "\n📊 Checking metadata cache..."
CACHED_WORKS=$(redis-cli --raw KEYS "oa:work:*" | wc -l)
if [ "$CACHED_WORKS" -gt 0 ]; then
    echo -e "${GREEN}✅ OpenAlex cache has $CACHED_WORKS work objects${NC}"
else
    echo -e "${YELLOW}⚠️  OpenAlex cache is empty (run data loading)${NC}"
fi

# Check Neo4j for Work nodes
echo -e "\n🗂️  Checking graph database..."
WORK_COUNT=$(echo "MATCH (w:Work) RETURN COUNT(w) as count" | cypher-shell -u neo4j -p leibniz123 --format plain 2>/dev/null | grep -o '[0-9]\+' || echo "0")
if [ "$WORK_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✅ Neo4j has $WORK_COUNT Work nodes${NC}"
else
    echo -e "${YELLOW}⚠️  Neo4j has no Work nodes yet${NC}"
fi

# Check service logs for errors
echo -e "\n📋 Checking logs for errors..."
if docker-compose logs --tail=50 | grep -i error > /dev/null; then
    echo -e "${RED}⚠️  Found errors in logs (see docker-compose logs)${NC}"
else
    echo -e "${GREEN}✅ No errors in recent logs${NC}"
fi
```

## 4. Environment Configuration

### 4.1 Environment Variables (Enhanced)

```bash
# .env.example

# API Keys
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4-turbo-preview

# OpenAlex Configuration
OPENALEX_EMAIL=your-email@example.com  # For polite crawling
OPENALEX_RATE_LIMIT=10  # Requests per second
OPENALEX_CACHE_TTL=86400  # 24 hours

# Service URLs (for local development)
REDIS_URL=redis://localhost:6379
NEO4J_URI=bolt://localhost:7687
NEO4J_USER=neo4j
NEO4J_PASSWORD=leibniz123
QDRANT_HOST=localhost
QDRANT_PORT=6333
MEILISEARCH_HOST=http://localhost:7700
MEILISEARCH_KEY=leibniz_dev_key

# Performance Settings
QUERY_TIMEOUT_MS=200
CACHE_TTL_SECONDS=3600
MAX_WORKERS=8
BATCH_SIZE=100

# Development Settings
DEBUG=true
LOG_LEVEL=info
HOT_RELOAD=true

# Data Paths
DATA_DIR=./data
WORKS_DIR=./data/works
CACHE_DIR=./data/cache
INDEX_DIR=./data/indices
```

### 4.2 Docker Compose Configuration (Enhanced)

```yaml
# docker-compose.yml
version: '3.8'

x-common-variables: &common-variables
  REDIS_URL: ${REDIS_URL}
  LOG_LEVEL: ${LOG_LEVEL}
  OPENALEX_EMAIL: ${OPENALEX_EMAIL}

services:
  # Enhanced Redis with persistence
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes:
      - redis_data:/data
      - ./redis.conf:/usr/local/etc/redis/redis.conf
    command: redis-server /usr/local/etc/redis/redis.conf
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5

  neo4j:
    image: neo4j:5-community
    ports: ["7474:7474", "7687:7687"]
    environment:
      - NEO4J_AUTH=${NEO4J_USER}/${NEO4J_PASSWORD}
      - NEO4J_dbms_memory_heap_initial__size=2G
      - NEO4J_dbms_memory_heap_max__size=4G
      - NEO4J_dbms_memory_pagecache_size=2G
      - NEO4J_PLUGINS=["graph-data-science"]
    volumes:
      - neo4j_data:/data
      - ./neo4j/plugins:/plugins
      - ./neo4j/import:/import
    healthcheck:
      test: ["CMD", "cypher-shell", "-u", "neo4j", "-p", "${NEO4J_PASSWORD}", "RETURN 1"]
      interval: 10s
      timeout: 5s
      retries: 5

  qdrant:
    image: qdrant/qdrant:latest
    ports: ["6333:6333", "6334:6334"]
    volumes:
      - qdrant_data:/qdrant/storage
    environment:
      - QDRANT__SERVICE__HTTP_PORT=6333
      - QDRANT__SERVICE__GRPC_PORT=6334
      - QDRANT__LOG_LEVEL=INFO
      - QDRANT__STORAGE__OPTIMIZERS__MEMMAP_THRESHOLD_KB=50000

  meilisearch:
    image: getmeili/meilisearch:v1.5
    ports: ["7700:7700"]
    environment:
      - MEILI_MASTER_KEY=${MEILISEARCH_KEY}
      - MEILI_ENV=development
    volumes:
      - meilisearch_data:/meili_data

  grobid:
    image: lfoppiano/grobid:0.7.3
    ports: ["8070:8070"]
    environment:
      - GROBID_SERVICE_OPTS=-Xmx4g
    volumes:
      - ./grobid/config:/opt/grobid/grobid-home/config

  # Data pipeline service (new)
  data-pipeline:
    build: ./services/pipeline
    environment:
      <<: *common-variables
      OPENALEX_RATE_LIMIT: ${OPENALEX_RATE_LIMIT}
    depends_on:
      - redis
      - neo4j
    volumes:
      - ./data/works:/data/works
      - ./logs/openalex:/logs
    profiles: ["pipeline"]

  # Application services
  api-gateway:
    build: ./services/gateway
    ports: ["3000:3000"]
    environment:
      <<: *common-variables
      PORT: 3000
    depends_on:
      - redis
      - query-service
    volumes:
      - ./services/gateway:/app
      - /app/node_modules
    command: npm run dev

  query-service:
    build: ./services/query
    ports: ["8001:8001"]
    environment:
      <<: *common-variables
      OPENAI_API_KEY: ${OPENAI_API_KEY}
    depends_on:
      - qdrant
      - neo4j
      - meilisearch
      - redis
    volumes:
      - ./services/query:/app
      - ./data/works:/data/works:ro
    command: uvicorn main:app --reload --host 0.0.0.0 --port 8001

  frontend:
    build: ./frontend
    ports: ["5173:5173"]
    environment:
      - VITE_API_URL=http://localhost:3000
    volumes:
      - ./frontend:/app
      - /app/node_modules
    command: npm run dev

volumes:
  redis_data:
  neo4j_data:
  qdrant_data:
  meilisearch_data:
```

### 4.3 Redis Configuration

```conf
# redis.conf
# Persistence settings for metadata caching
save 900 1
save 300 10
save 60 10000

# Append only file
appendonly yes
appendfsync everysec

# Memory policy - LRU for cache behavior
maxmemory 4gb
maxmemory-policy allkeys-lru

# Enable keyspace notifications
notify-keyspace-events KEA

# Performance tuning
tcp-backlog 511
timeout 0
tcp-keepalive 300
```

## 5. Development Workflows

### 5.1 Makefile Commands (Enhanced)

```makefile
# Makefile
.PHONY: help dev stop clean test benchmark ingest-data

help:
	@echo "Project Leibniz Development Commands"
	@echo "  make dev           - Start all services in development mode"
	@echo "  make stop          - Stop all services"
	@echo "  make clean         - Clean all data and rebuild"
	@echo "  make test          - Run all tests"
	@echo "  make benchmark     - Run performance benchmarks"
	@echo "  make logs          - Tail all service logs"
	@echo "  make ingest-data   - Ingest sample papers with OpenAlex"
	@echo "  make cache-status  - Show cache statistics"

dev:
	docker-compose up -d
	@echo "Services starting... Access at:"
	@echo "  Frontend:     http://localhost:5173"
	@echo "  API Gateway:  http://localhost:3000"
	@echo "  Neo4j:        http://localhost:7474"
	@echo "  QDrant:       http://localhost:6333/dashboard"
	@echo ""
	@echo "Run 'make ingest-data' to load sample papers"

stop:
	docker-compose down

clean:
	docker-compose down -v
	rm -rf data/works/*
	rm -rf data/processed/*
	rm -rf data/embeddings/*
	rm -rf logs/*

test:
	./scripts/run-tests.sh

benchmark:
	python scripts/benchmark.py

logs:
	docker-compose logs -f

ingest-data:
	@echo "📚 Ingesting sample papers with OpenAlex metadata..."
	python scripts/ingest_sample_data.py

cache-status:
	@echo "📊 Cache Statistics:"
	@echo "OpenAlex Works:"
	@redis-cli --raw KEYS "oa:work:*" | wc -l
	@echo "Query Results:"
	@redis-cli --raw KEYS "qr:*" | wc -l
	@echo "Concepts:"
	@redis-cli --raw KEYS "concepts:*" | wc -l
```

### 5.2 Development Commands

```bash
# Start development environment
make dev

# Watch logs for a specific service
docker-compose logs -f query-service

# Monitor OpenAlex ingestion
tail -f logs/openalex/ingestion.log

# Enter a service container
docker-compose exec query-service bash

# Run OpenAlex batch ingestion
docker-compose run --rm data-pipeline python ingest_conference.py --venue NeurIPS --year 2023

# Check Neo4j for citation patterns
echo "MATCH (w1:Work)-[:CITES]->(w2:Work) RETURN w1.title, w2.title LIMIT 10" | cypher-shell -u neo4j -p leibniz123

# Monitor cache hit rates
redis-cli --stat

# Load specific paper by DOI
python scripts/ingest_paper.py --doi "10.1145/3297280.3297641"

# Pre-fetch popular papers
python scripts/prefetch_popular.py --limit 100
```

## 6. Neo4j Schema Initialization

### 6.1 Schema Setup Script

```bash
#!/bin/bash
# scripts/init-neo4j-schema.sh

echo "📊 Initializing Neo4j schema for OpenAlex..."

cypher-shell -u neo4j -p leibniz123 << 'EOF'
// Create constraints for data integrity
CREATE CONSTRAINT work_id IF NOT EXISTS FOR (w:Work) REQUIRE w.id IS UNIQUE;
CREATE CONSTRAINT author_id IF NOT EXISTS FOR (a:Author) REQUIRE a.id IS UNIQUE;
CREATE CONSTRAINT venue_id IF NOT EXISTS FOR (v:Venue) REQUIRE v.id IS UNIQUE;
CREATE CONSTRAINT concept_id IF NOT EXISTS FOR (c:Concept) REQUIRE c.id IS UNIQUE;
CREATE CONSTRAINT institution_id IF NOT EXISTS FOR (i:Institution) REQUIRE i.id IS UNIQUE;

// Create indexes for performance
CREATE INDEX work_title IF NOT EXISTS FOR (w:Work) ON (w.title);
CREATE INDEX work_year IF NOT EXISTS FOR (w:Work) ON (w.year);
CREATE INDEX work_citations IF NOT EXISTS FOR (w:Work) ON (w.cited_by_count);
CREATE INDEX author_name IF NOT EXISTS FOR (a:Author) ON (a.display_name);
CREATE INDEX venue_name IF NOT EXISTS FOR (v:Venue) ON (v.display_name);
CREATE INDEX concept_name IF NOT EXISTS FOR (c:Concept) ON (c.display_name);

// Create full-text search indexes
CREATE FULLTEXT INDEX work_search IF NOT EXISTS FOR (w:Work) ON EACH [w.title, w.abstract];
CREATE FULLTEXT INDEX author_search IF NOT EXISTS FOR (a:Author) ON EACH [a.display_name];

RETURN "Schema initialized successfully" as message;
EOF

echo "✅ Neo4j schema ready for OpenAlex data"
```

## 7. Data Loading Scripts

### 7.1 Sample Data Ingestion

```python
#!/usr/bin/env python3
# scripts/ingest_sample_data.py

import asyncio
import sys
sys.path.append('.')
from services.openalex.client import OpenAlexClient
from services.pipeline.ingest import IngestionPipeline

async def ingest_sample_data():
    """Load sample papers for development"""
    
    pipeline = IngestionPipeline()
    
    # Key papers for testing
    sample_papers = [
        # Foundational papers
        ("10.48550/arXiv.1706.03762", "Attention Is All You Need"),
        ("10.48550/arXiv.1810.04805", "BERT: Pre-training of Deep Bidirectional Transformers"),
        ("10.48550/arXiv.2005.14165", "Language Models are Few-Shot Learners (GPT-3)"),
        
        # Vision papers
        ("10.48550/arXiv.2010.11929", "An Image is Worth 16x16 Words: Vision Transformer"),
        ("10.48550/arXiv.2103.14030", "Swin Transformer"),
        
        # Efficiency papers
        ("10.48550/arXiv.2009.06732", "Efficient Transformers: A Survey"),
        ("10.48550/arXiv.2205.07686", "FlashAttention"),
        
        # Recent papers
        ("10.48550/arXiv.2302.13971", "LLaMA: Open and Efficient Foundation Language Models"),
        ("10.48550/arXiv.2307.09288", "Llama 2: Open Foundation and Fine-Tuned Chat Models"),
    ]
    
    print("📚 Ingesting sample papers...\n")
    
    for doi, title in sample_papers:
        print(f"→ {title}")
        try:
            work_id = await pipeline.ingest_paper(doi)
            if work_id:
                print(f"  ✅ Ingested as {work_id}")
            else:
                print(f"  ❌ Failed to ingest")
        except Exception as e:
            print(f"  ❌ Error: {e}")
        
        # Be polite to OpenAlex
        await asyncio.sleep(0.5)
    
    # Also get some recent conference papers
    print("\n📚 Fetching recent conference papers...")
    
    for venue in ["NeurIPS", "ICML", "ICLR"]:
        print(f"\n→ {venue} 2023 (top 20 by citations)")
        try:
            await pipeline.ingest_conference(venue, 2023, limit=20)
            print(f"  ✅ Ingested top papers from {venue} 2023")
        except Exception as e:
            print(f"  ❌ Error: {e}")
    
    print("\n✨ Sample data ingestion complete!")
    print("   Run 'make cache-status' to see what was loaded")

if __name__ == "__main__":
    asyncio.run(ingest_sample_data())
```

### 7.2 Popular Papers Pre-fetch

```python
#!/usr/bin/env python3
# scripts/prefetch_popular.py

import asyncio
import argparse
from pathlib import Path

async def prefetch_popular_papers(limit: int = 100):
    """Pre-fetch most cited papers for each conference"""
    
    client = OpenAlexClient()
    
    conferences = [
        ("NeurIPS", [2021, 2022, 2023]),
        ("ICML", [2021, 2022, 2023]),
        ("ICLR", [2021, 2022, 2023]),
    ]
    
    print(f"📚 Pre-fetching top {limit} papers per conference/year...")
    
    for venue, years in conferences:
        for year in years:
            print(f"\n→ {venue} {year}")
            
            # Fetch sorted by citations
            papers = await client.get_conference_papers(venue, year)
            papers.sort(key=lambda x: x.get('cited_by_count', 0), reverse=True)
            
            # Take top N
            for paper in papers[:limit]:
                work_id = paper['id'].split('/')[-1]
                work_dir = Path(f"data/works/{work_id}")
                
                if work_dir.exists():
                    continue
                
                work_dir.mkdir(parents=True, exist_ok=True)
                
                # Save metadata
                with open(work_dir / "work.json", "w") as f:
                    json.dump(paper, f, indent=2)
                
                # Cache in Redis too
                await redis_client.setex(
                    f"oa:work:{work_id}",
                    86400 * 7,  # 1 week
                    json.dumps(paper)
                )
            
            print(f"  ✅ Cached top {min(limit, len(papers))} papers")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--limit", type=int, default=100)
    args = parser.parse_args()
    
    asyncio.run(prefetch_popular_papers(args.limit))
```

## 8. IDE Configuration

### 8.1 VS Code Settings (Enhanced)

```json
// .vscode/settings.json
{
  "python.linting.enabled": true,
  "python.linting.pylintEnabled": true,
  "python.formatting.provider": "black",
  "python.defaultInterpreterPath": "${workspaceFolder}/venv/bin/python",
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.organizeImports": true
  },
  "[python]": {
    "editor.rulers": [88]
  },
  "[javascript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  "[typescript]": {
    "editor.defaultFormatter": "esbenp.prettier-vscode"
  },
  // File associations for OpenAlex data
  "files.associations": {
    "**/data/works/*/work.json": "json",
    "**/data/works/*/grobid.tei.xml": "xml"
  },
  // Exclude data directories from search
  "search.exclude": {
    "**/data/works": true,
    "**/data/cache": true,
    "**/node_modules": true,
    "**/.git": true
  }
}
```

### 8.2 Debug Configurations (Enhanced)

```json
// .vscode/launch.json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Query Service",
      "type": "python",
      "request": "launch",
      "module": "uvicorn",
      "args": ["main:app", "--reload", "--port", "8001"],
      "cwd": "${workspaceFolder}/services/query",
      "envFile": "${workspaceFolder}/.env"
    },
    {
      "name": "OpenAlex Ingestion",
      "type": "python",
      "request": "launch",
      "program": "${workspaceFolder}/scripts/ingest_sample_data.py",
      "cwd": "${workspaceFolder}",
      "envFile": "${workspaceFolder}/.env"
    },
    {
      "name": "Debug Tests",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["-v", "-s", "--no-cov"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

## 9. Troubleshooting

### 9.1 Common Issues

| Issue                  | Solution                                       |
|------------------------|------------------------------------------------|
| OpenAlex rate limiting | Reduce OPENALEX_RATE_LIMIT in .env, add delays |
| Missing Work Objects   | Check internet connection, verify DOI format   |
| Neo4j out of memory    | Increase heap size in docker-compose.yml       |
| Redis cache full       | Increase maxmemory in redis.conf               |
| Slow metadata fetching | Use batch operations, increase workers         |
| GROBID timeout on PDFs | Process smaller batches, increase timeout      |

### 9.2 OpenAlex-Specific Debugging

```bash
# Check OpenAlex request logs
tail -f logs/openalex/requests.log

# Monitor rate limiting
grep "429" logs/openalex/requests.log | tail -20

# Verify Work Object structure
cat data/works/W*/work.json | jq '.id, .title, .cited_by_count' | head -20

# Check citation relationships
echo "MATCH (w:Work)-[:CITES]->() RETURN w.id, COUNT(*) as out_citations ORDER BY out_citations DESC LIMIT 10" | cypher-shell -u neo4j -p leibniz123

# Debug missing metadata
python3 << 'EOF'
import json
from pathlib import Path

works_dir = Path("data/works")
total = 0
missing_abstract = 0
missing_venue = 0

for work_file in works_dir.glob("*/work.json"):
    with open(work_file) as f:
        work = json.load(f)
    total += 1
    if not work.get('abstract'):
        missing_abstract += 1
    if not work.get('host_venue'):
        missing_venue += 1

print(f"Total works: {total}")
print(f"Missing abstracts: {missing_abstract} ({missing_abstract/total*100:.1f}%)")
print(f"Missing venues: {missing_venue} ({missing_venue/total*100:.1f}%)")
EOF
```

### 9.3 Performance Profiling

```bash
# Profile OpenAlex ingestion
python -m cProfile -o profile.stats scripts/ingest_sample_data.py
python -m pstats profile.stats << EOF
sort cumulative
stats 20
EOF

# Monitor API response times
grep "response_time" logs/openalex/requests.log | \
  awk '{sum+=$NF; count++} END {print "Average:", sum/count "ms"}'

# Check cache effectiveness
redis-cli info stats | grep -E "keyspace_hits|keyspace_misses"
```

## 10. Data Verification

### 10.1 Verify Data Completeness

```bash
#!/bin/bash
# scripts/verify-data.sh

echo "🔍 Verifying OpenAlex data completeness..."

# Count Work Objects
WORK_COUNT=$(find data/works -name "work.json" | wc -l)
echo "Work Objects: $WORK_COUNT"

# Count PDFs
PDF_COUNT=$(find data/works -name "paper.pdf" | wc -l)
echo "PDFs: $PDF_COUNT"

# Count TEI XML files
TEI_COUNT=$(find data/works -name "grobid.tei.xml" | wc -l)
echo "TEI files: $TEI_COUNT"

# Check Redis cache
echo -e "\nRedis cache:"
redis-cli --raw KEYS "oa:work:*" | wc -l | xargs echo "  Cached works:"
redis-cli --raw KEYS "oa:citations:*" | wc -l | xargs echo "  Cached citations:"

# Check Neo4j
echo -e "\nNeo4j graph:"
echo "MATCH (w:Work) RETURN COUNT(w)" | cypher-shell -u neo4j -p leibniz123 --format plain | grep -o '[0-9]\+' | xargs echo "  Work nodes:"
echo "MATCH ()-[c:CITES]->() RETURN COUNT(c)" | cypher-shell -u neo4j -p leibniz123 --format plain | grep -o '[0-9]\+' | xargs echo "  Citation edges:"
echo "MATCH (a:Author) RETURN COUNT(a)" | cypher-shell -u neo4j -p leibniz123 --format plain | grep -o '[0-9]\+' | xargs echo "  Author nodes:"
echo "MATCH (v:Venue) RETURN COUNT(v)" | cypher-shell -u neo4j -p leibniz123 --format plain | grep -o '[0-9]\+' | xargs echo "  Venue nodes:"
```

## 11. Quick Reference Card

```bash
# === MOST COMMON COMMANDS ===

# Start everything
make dev

# Load sample data with OpenAlex
make ingest-data

# Check what's loaded
make cache-status

# Stop everything  
make stop

# View logs
docker-compose logs -f [service-name]

# Test a query
curl localhost:3000/api/v1/query -d '{"query":"transformer efficiency"}'

# Check health
./scripts/health-check.sh

# Verify OpenAlex data
./scripts/verify-data.sh

# === SERVICE URLS ===
Frontend:        http://localhost:5173
API:            http://localhost:3000
Neo4j Browser:  http://localhost:7474 (neo4j/leibniz123)
QDrant UI:      http://localhost:6333/dashboard
Meilisearch:    http://localhost:7700

# === USEFUL COMMANDS ===
# Ingest specific paper
python scripts/ingest_paper.py --doi "10.1145/3297280.3297641"

# Query Neo4j
cypher-shell -u neo4j -p leibniz123

# Monitor Redis
redis-cli monitor | grep -E "oa:work:|qr:"

# Check OpenAlex cache
redis-cli --raw KEYS "oa:*" | head -20
```

---

**Setup Time:** 30 minutes including data loading  
**Next Step:** Run `make ingest-data` to populate with real papers!