# Project Leibniz - Development Environment Setup Guide

**Version:** 1.0  
**Date:** June 2025
**Status:** Ready for Use  
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

# 2. Create environment file
cp .env.example .env
# Edit .env with your OpenAI API key

# 3. Start all services
docker-compose up -d

# 4. Verify health
./scripts/health-check.sh

# 5. Load sample data (optional for testing)
./scripts/load-sample-data.sh
```

## 2. Prerequisites

### 2.1 Required Software

| Software | Minimum Version | Check Command | Install Guide |
|----------|----------------|---------------|---------------|
| Docker | 20.10+ | `docker --version` | https://docs.docker.com/get-docker/ |
| Docker Compose | 2.0+ | `docker-compose --version` | Included with Docker Desktop |
| Git | 2.30+ | `git --version` | https://git-scm.com/downloads |
| Python | 3.10+ | `python3 --version` | https://python.org/downloads |
| Node.js | 18+ | `node --version` | https://nodejs.org |
| Make | 3.81+ | `make --version` | Usually pre-installed |

Run `scripts/verify-docker.sh` to confirm Docker is ready:

```bash
./scripts/verify-docker.sh
```

### 2.2 Hardware Requirements

- **RAM:** 16GB minimum (32GB recommended)
- **Storage:** 100GB free space (for papers + indexes)
- **CPU:** 4+ cores (8+ recommended)
- **Network:** Stable internet for API calls

## 3. Automated Setup Scripts

### 3.1 Main Setup Script

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
    echo "⚠️  Please edit .env with your API keys"
    read -p "Press enter after adding your OpenAI API key..."
fi

# Create necessary directories
mkdir -p data/{pdfs,processed,embeddings,cache}
mkdir -p logs/{services,frontend}

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

echo "✅ Setup complete! Run 'make dev' to start developing"
```

### 3.2 Prerequisites Check Script

```bash
#!/bin/bash
# scripts/check-prerequisites.sh

ERRORS=0

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed"
        ERRORS=$((ERRORS + 1))
    else
        VERSION=$($2)
        echo "✅ $1: $VERSION"
    fi
}

echo "Checking prerequisites..."

check_command "docker" "docker --version"
check_command "docker-compose" "docker-compose --version"
check_command "git" "git --version"
check_command "python3" "python3 --version"
check_command "node" "node --version"
check_command "npm" "npm --version"

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo "❌ Docker daemon is not running"
    ERRORS=$((ERRORS + 1))
fi

# Check available memory
AVAILABLE_MEMORY=$(free -g | awk '/^Mem:/{print $7}')
if [ "$AVAILABLE_MEMORY" -lt 8 ]; then
    echo "⚠️  Low memory available: ${AVAILABLE_MEMORY}GB (16GB recommended)"
fi

if [ $ERRORS -gt 0 ]; then
    echo "❌ Prerequisites check failed with $ERRORS errors"
    exit 1
else
    echo "✅ All prerequisites satisfied"
fi
```

### 3.3 Health Check Script

```bash
#!/bin/bash
# scripts/health-check.sh

echo "🏥 Running health checks..."

# Color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
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

# Check service logs for errors
echo -e "\n📋 Checking logs for errors..."
if docker-compose logs --tail=50 | grep -i error > /dev/null; then
    echo -e "${RED}⚠️  Found errors in logs (see docker-compose logs)${NC}"
else
    echo -e "${GREEN}✅ No errors in recent logs${NC}"
fi
```

## 4. Environment Configuration

### 4.1 Environment Variables

```bash
# .env.example

# API Keys
OPENAI_API_KEY=sk-...
OPENAI_MODEL=gpt-4-turbo-preview

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
```

### 4.2 Docker Compose Configuration

```yaml
# docker-compose.yml
version: '3.8'

x-common-variables: &common-variables
  REDIS_URL: ${REDIS_URL}
  LOG_LEVEL: ${LOG_LEVEL}

services:
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
    volumes:
      - redis_data:/data
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
    volumes:
      - neo4j_data:/data
      - ./neo4j/plugins:/plugins
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
    volumes:
      - ./services/query:/app
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

## 5. Development Workflows

### 5.1 Makefile Commands

```makefile
# Makefile
.PHONY: help dev stop clean test benchmark

help:
	@echo "Project Leibniz Development Commands"
	@echo "  make dev        - Start all services in development mode"
	@echo "  make stop       - Stop all services"
	@echo "  make clean      - Clean all data and rebuild"
	@echo "  make test       - Run all tests"
	@echo "  make benchmark  - Run performance benchmarks"
	@echo "  make logs       - Tail all service logs"

dev:
	docker-compose up -d
	@echo "Services starting... Access at:"
	@echo "  Frontend:     http://localhost:5173"
	@echo "  API Gateway:  http://localhost:3000"
	@echo "  Neo4j:        http://localhost:7474"
	@echo "  QDrant:       http://localhost:6333/dashboard"

stop:
	docker-compose down

clean:
	docker-compose down -v
	rm -rf data/processed/*
	rm -rf data/embeddings/*
	rm -rf logs/*

test:
	./scripts/run-tests.sh

benchmark:
	python scripts/benchmark.py

logs:
	docker-compose logs -f
```

### 5.2 Development Commands

```bash
# Start development environment
make dev

# Watch logs for a specific service
docker-compose logs -f query-service

# Enter a service container
docker-compose exec query-service bash

# Run a specific test
pytest services/query/tests/test_vector_search.py -v

# Check performance
python scripts/benchmark.py --endpoint /api/v1/query --iterations 100

# Rebuild a specific service
docker-compose build query-service
docker-compose up -d query-service

# Load sample data for testing
./scripts/load-sample-data.sh --papers 100
```

## 6. IDE Configuration

### 6.1 VS Code Settings

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
  }
}
```

### 6.2 Debug Configurations

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
      "name": "Frontend",
      "type": "chrome",
      "request": "launch",
      "url": "http://localhost:5173",
      "webRoot": "${workspaceFolder}/frontend/src"
    },
    {
      "name": "Debug Tests",
      "type": "python",
      "request": "launch",
      "module": "pytest",
      "args": ["-v", "-s"],
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

## 7. Troubleshooting

### 7.1 Common Issues

| Issue | Solution |
|-------|----------|
| Port already in use | `lsof -i :PORT` then `kill -9 PID` |
| Docker out of space | `docker system prune -a` |
| Slow performance | Increase Docker memory in preferences |
| GROBID timeout | Reduce batch size in config |
| Neo4j won't start | Check memory settings, clear volume |
| Frontend hot reload not working | Check volume mounts, restart service |

### 7.2 Performance Profiling

```bash
# Profile Python service
python -m cProfile -o profile.stats services/query/main.py

# Analyze profile
python -m pstats profile.stats

# Profile Node.js service
node --prof services/gateway/index.js
node --prof-process isolate-*.log > profile.txt

# Monitor Docker resource usage
docker stats

# Check query performance
curl -w "@curl-format.txt" -o /dev/null -s "http://localhost:3000/api/v1/query"
```

### 7.3 Log Files

```bash
# All logs are in ./logs/

# View specific service logs
tail -f logs/services/query-service.log

# Search for errors across all logs
grep -r ERROR logs/

# View structured logs with jq
tail -f logs/services/api-gateway.log | jq '.'
```

## 8. First Query Walkthrough

### 8.1 Verify Everything Works

```bash
# 1. Check all services are healthy
./scripts/health-check.sh

# 2. Load sample data (if not already done)
./scripts/load-sample-data.sh --papers 100

# 3. Test vector search
curl -X POST http://localhost:3000/api/v1/query \
  -H "Content-Type: application/json" \
  -d '{"query": "transformer efficiency"}'

# 4. Open frontend
open http://localhost:5173

# 5. Try a search in the UI
# Type: "sparse attention transformers"
# You should see results in <200ms
```

### 8.2 Monitor Performance

```bash
# Terminal 1: Watch query latencies
watch -n 1 'tail -n 20 logs/metrics/query-latency.log'

# Terminal 2: Monitor service health
watch -n 5 './scripts/health-check.sh'

# Terminal 3: Track resource usage
docker stats
```

## 9. Data Loading

### 9.1 Quick Sample Data

```bash
# Load 100 sample papers for testing
./scripts/load-sample-data.sh --papers 100

# This creates synthetic papers with:
# - Realistic titles and abstracts
# - Valid embeddings
# - Graph relationships
# - Search indices
```

### 9.2 Full Dataset Loading

```bash
# Download real papers (runs in background)
nohup ./scripts/download-papers.sh &

# Process through GROBID (parallelized)
./scripts/process-papers.sh --workers 8

# Generate embeddings
./scripts/generate-embeddings.sh --batch-size 100

# Build graph
./scripts/build-graph.sh

# Create search indices
./scripts/build-indices.sh
```

## 10. Quick Reference Card

```bash
# === MOST COMMON COMMANDS ===

# Start everything
make dev

# Stop everything  
make stop

# View logs
docker-compose logs -f [service-name]

# Test a query
curl localhost:3000/api/v1/query -d '{"query":"your search"}'

# Check health
./scripts/health-check.sh

# Benchmark performance
python scripts/benchmark.py

# === SERVICE URLS ===
Frontend:        http://localhost:5173
API:            http://localhost:3000
Neo4j Browser:  http://localhost:7474
QDrant UI:      http://localhost:6333/dashboard
Meilisearch:    http://localhost:7700

# === USEFUL ALIASES ===
alias pl-logs='docker-compose logs -f'
alias pl-restart='docker-compose restart'
alias pl-status='./scripts/health-check.sh'
```

---

**Setup Time:** 30 minutes  
**Next Step:** Start coding with `make dev`!