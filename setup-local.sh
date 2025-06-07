#!/usr/bin/env bash
# setup-local.sh - Create LOCAL configuration (DO NOT COMMIT THIS FILE)
# This script creates local configuration files containing secrets

set -euo pipefail

echo "=== Setting up LOCAL configuration ==="
echo "⚠️  Files created by this script should NEVER be committed!"
echo

# Create .env from template if it doesn't exist
if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        echo "Creating .env from .env.example..."
        cp .env.example .env
        echo "✓ Created .env"
        echo "  ⚠️  Edit .env with your actual API keys and passwords!"
    else
        echo "❌ No .env.example found!"
        exit 1
    fi
else
    echo "✓ .env already exists"
fi

# Create local config directory
echo
echo "Creating local configuration directory..."
mkdir -p config/local
touch config/local/__init__.py

# Create local secrets template if it doesn't exist
if [ ! -f config/local/secrets.py ]; then
    cat > config/local/secrets.py << 'SECRETS'
"""
LOCAL SECRETS - NEVER COMMIT THIS FILE
This file is gitignored and should contain your actual credentials
"""

# Service credentials (if not using environment variables)
# NEO4J_PASSWORD = "your-actual-neo4j-password"
# MEILISEARCH_KEY = "your-actual-meilisearch-key"

# Additional local-only configuration
# LOCAL_DATA_PATH = "/path/to/your/local/data"
# CUSTOM_MODEL_PATH = "/path/to/your/models"

# Any other secrets or local configuration
SECRETS
    echo "✓ Created config/local/secrets.py template"
fi

echo
echo "✅ Local setup complete!"
echo
echo "Next steps:"
echo "1. Edit .env with your actual credentials:"
echo "   - OpenAI API key"
echo "   - Neo4j password"
echo "   - Meilisearch master key"
echo
echo "2. Optionally edit config/local/secrets.py for additional local config"
echo
echo "3. Verify these files are gitignored:"
echo "   git status --ignored"
echo
echo "Remember: NEVER commit .env or config/local/* files!"
