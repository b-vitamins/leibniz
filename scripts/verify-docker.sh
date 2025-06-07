#!/usr/bin/env bash
# Verify Docker installation for Project Leibniz

set -euo pipefail

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🐳 Verifying Docker installation..."

# Check Docker
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo -e "${GREEN}✅ Docker installed: $DOCKER_VERSION${NC}"

    # Check version meets minimum requirement (20.10+)
    DOCKER_VERSION_NUM=$(docker --version | grep -oE '[0-9]+\.[0-9]+' | head -1)
    MAJOR=$(echo $DOCKER_VERSION_NUM | cut -d. -f1)
    MINOR=$(echo $DOCKER_VERSION_NUM | cut -d. -f2)

    if [[ $MAJOR -gt 20 ]] || [[ $MAJOR -eq 20 && $MINOR -ge 10 ]]; then
        echo -e "${GREEN}✅ Docker version meets requirements (20.10+)${NC}"
    else
        echo -e "${YELLOW}⚠️  Docker version $DOCKER_VERSION_NUM is older than recommended 20.10+${NC}"
    fi

    # Check Docker daemon
    if docker info &> /dev/null; then
        echo -e "${GREEN}✅ Docker daemon is running${NC}"
    else
        echo -e "${RED}❌ Docker daemon is not running${NC}"
        echo "   Start it with: sudo systemctl start docker (Linux) or open Docker Desktop (Mac/Windows)"
        exit 1
    fi
else
    echo -e "${RED}❌ Docker is not installed${NC}"
    echo "   Install from: https://docs.docker.com/get-docker/"
    exit 1
fi

echo ""

# Check Docker Compose
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    echo -e "${GREEN}✅ Docker Compose (standalone) installed: $COMPOSE_VERSION${NC}"
elif docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version)
    echo -e "${GREEN}✅ Docker Compose (plugin) installed: $COMPOSE_VERSION${NC}"
else
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    echo "   Install from: https://docs.docker.com/compose/install/"
    exit 1
fi

# Check disk space
AVAILABLE_SPACE=$(df -BG . | awk 'NR==2 {print $4}' | sed 's/G//')
if [[ $AVAILABLE_SPACE -lt 50 ]]; then
    echo -e "${YELLOW}⚠️  Low disk space: ${AVAILABLE_SPACE}GB available (100GB recommended)${NC}"
else
    echo -e "${GREEN}✅ Sufficient disk space: ${AVAILABLE_SPACE}GB available${NC}"
fi

echo ""
echo -e "${GREEN}✅ Docker environment ready for Project Leibniz!${NC}"
