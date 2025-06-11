#!/usr/bin/env bash
set -euo pipefail

# setup-dev.sh - Prepare Leibniz development environment
# This script installs system packages, Python dependencies, docker images
# and git hooks so that development can continue offline after it finishes.
# It may be executed multiple times safely.

# Detect OS package manager
if command -v apt-get >/dev/null 2>&1; then
    PM_INSTALL="apt-get install -y"
    PM_UPDATE="apt-get update"
else
    echo "Unsupported package manager. Install dependencies manually." >&2
    exit 1
fi

REQUIRED_APT_PACKAGES=(python3-venv python3-pip docker.io docker-compose)

install_packages() {
    echo "Updating package lists..."
    sudo $PM_UPDATE
    echo "Installing required packages..."
    sudo $PM_INSTALL ${REQUIRED_APT_PACKAGES[*]}
}

create_venv() {
    if [ ! -d .venv ]; then
        echo "Creating virtual environment..."
        python3 -m venv .venv
    else
        echo "Virtual environment already exists"
    fi
    # shellcheck disable=SC1091
    source .venv/bin/activate
    python -m pip install --upgrade pip
    pip install -r requirements-dev.txt
}

pull_docker_images() {
    echo "Pulling docker images (for offline use)..."
    images=(
        redis:7-alpine
        neo4j:5-community
        qdrant/qdrant:latest
        getmeili/meilisearch:v1.5
        lfoppiano/grobid:0.7.3
    )
    for img in "${images[@]}"; do
        docker pull "$img"
    done
}

install_git_hooks() {
    echo "Installing git hooks..."
    bash scripts/install-git-hooks.sh
}

run_tests() {
    echo "Running basic tests..."
    export LEIBNIZ_USE_MOCKS=true
    export CODEX_ENVIRONMENT=true
    # shellcheck disable=SC1091
    source .venv/bin/activate
    pytest -q
}

main() {
    install_packages
    create_venv
    pull_docker_images
    install_git_hooks
    run_tests
    echo "\nDevelopment environment setup complete. Docker images and Python\npackages are now available for offline use. Activate the venv with:\n  source .venv/bin/activate"
}

main "$@"
