#!/usr/bin/env bash
# Run CI checks locally before pushing

set -euo pipefail

echo "🔍 Running local CI checks..."

# Set environment for mocks
export LEIBNIZ_USE_MOCKS=true
export CODEX_ENVIRONMENT=true

# Lint checks
echo "📝 Running linters..."
ruff check leibniz tests scripts || { echo "❌ Linting failed"; exit 1; }
ruff format --check leibniz tests || { echo "❌ Format check failed"; exit 1; }

# Type checking
echo "🔍 Running type checks..."
mypy leibniz || { echo "❌ Type checking failed"; exit 1; }

# Tests
echo "🧪 Running tests..."
pytest tests/unit -v || { echo "❌ Unit tests failed"; exit 1; }
pytest tests/test_mocks.py -v || { echo "❌ Mock tests failed"; exit 1; }

# Performance check (if performance tests exist)
if [ -d "tests/performance" ] && [ "$(ls -A tests/performance)" ]; then
    echo "⚡ Running performance tests..."
    pytest tests/performance -v --benchmark-only || { echo "❌ Performance tests failed"; exit 1; }
fi

echo "✅ All CI checks passed!"
