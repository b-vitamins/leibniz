#!/usr/bin/env bash
# Check if required services are accessible (PUBLIC script - no secrets)

set -euo pipefail

echo "Checking service availability..."
echo

check_port() {
    SERVICE=$1
    HOST=$2
    PORT=$3

    if command -v nc >/dev/null 2>&1; then
        # Use netcat if available
        if nc -z $HOST $PORT 2>/dev/null; then
            echo "✓ $SERVICE is accessible on $HOST:$PORT"
            return 0
        else
            echo "✗ $SERVICE is not accessible on $HOST:$PORT"
            return 1
        fi
    else
        # Fallback to Python
        if python3 -c "import socket; s=socket.socket(); s.settimeout(1); exit(0 if s.connect_ex(('$HOST', $PORT))==0 else 1)" 2>/dev/null; then
            echo "✓ $SERVICE is accessible on $HOST:$PORT"
            return 0
        else
            echo "✗ $SERVICE is not accessible on $HOST:$PORT"
            return 1
        fi
    fi
}

# Check standard ports (no secrets needed)
ALL_GOOD=true

check_port "Redis" "localhost" 6379 || ALL_GOOD=false
check_port "Neo4j Bolt" "localhost" 7687 || ALL_GOOD=false
check_port "Neo4j HTTP" "localhost" 7474 || ALL_GOOD=false
check_port "QDrant HTTP" "localhost" 6333 || ALL_GOOD=false
check_port "QDrant gRPC" "localhost" 6334 || ALL_GOOD=false
check_port "Meilisearch" "localhost" 7700 || ALL_GOOD=false
check_port "GROBID" "localhost" 8070 || ALL_GOOD=false

echo
if $ALL_GOOD; then
    echo "✓ All services are accessible!"
    exit 0
else
    echo "⚠ Some services are not accessible"
    echo "  If using Guix OCI containers, check: sudo herd status"
    echo "  If using Docker, check: docker ps"
    exit 1
fi
