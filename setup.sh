#!/usr/bin/env bash
# setup.sh - Initialize Project Leibniz with clear public/private separation
# This script creates ONLY public files that are safe to commit to the repository

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
header() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Check if we're in the right directory
check_project_root() {
    if [ ! -f "pyproject.toml" ]; then
        error "Please run this script from the project root (where pyproject.toml exists)"
    fi
}

# Create public repository structure
create_public_structure() {
    header "Creating PUBLIC repository structure"
    
    info "Creating Python package structure..."
    mkdir -p leibniz/{api,core,services,ingestion,intelligence,cli,config}
    mkdir -p tests/{unit,integration,performance,e2e}
    mkdir -p scripts
    mkdir -p docs
    
    # Create __init__.py files
    touch leibniz/__init__.py
    for dir in api core services ingestion intelligence cli config; do
        touch leibniz/$dir/__init__.py
    done
    
    touch tests/__init__.py
    for dir in unit integration performance e2e; do
        touch tests/$dir/__init__.py
    done
    
    # Create logs directory with .gitkeep
    mkdir -p logs
    touch logs/.gitkeep
    
    info "Public directories created"
}

# Create comprehensive .gitignore
create_gitignore() {
    header "Creating .gitignore to protect sensitive files"
    
    cat > .gitignore << 'EOF'
# SECURITY: Never commit these files
.env
.env.*
!.env.example
config/local.py
config/secrets.py
*_local.py
*_private.py
*_secrets.py

# API keys and credentials
*.key
*.pem
*.cert
*.crt
credentials/
secrets/
private/

# Local configuration
local_config/
instance/
.secrets/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST
.pytest_cache/
.coverage
.mypy_cache/
.ruff_cache/
htmlcov/
.tox/
.hypothesis/

# Virtual environments
venv/
env/
ENV/
env.bak/
venv.bak/

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.project
.pydevproject
.settings/

# Logs (keep structure, ignore content)
*.log
logs/*
!logs/.gitkeep

# Local data (never commit)
data/
*.db
*.sqlite
*.sqlite3
*.pickle
*.pkl
*.h5
*.hdf5
*.parquet
*.arrow

# Model files
*.pth
*.onnx
*.pb
*.tflite
models/

# Cache
.cache/
*.cache
__pycache__/

# OS
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Docker
docker-compose.override.yml
.docker/

# Temporary
tmp/
temp/
*.tmp
*.bak
*.swp
*.orig

# Jupyter
.ipynb_checkpoints/
*.ipynb

# Coverage reports
coverage.xml
*.cover
.coverage.*

# Documentation builds
docs/_build/
docs/_static/
docs/_templates/
EOF
    
    info ".gitignore created"
}

# Create public environment template
create_env_template() {
    header "Creating PUBLIC environment template"
    
    cat > .env.example << 'EOF'
# Leibniz Configuration Template
# 
# INSTRUCTIONS:
# 1. Copy this file to .env
# 2. Fill in your actual values
# 3. NEVER commit .env to the repository!
#
# The .env file is gitignored for your security

# API Keys (required)
LEIBNIZ_OPENAI_API_KEY=sk-your-openai-api-key-here

# Service Configuration
# Adjust these if your services run on non-default ports
LEIBNIZ_REDIS_URL=redis://localhost:6379
LEIBNIZ_NEO4J_URI=bolt://localhost:7687
LEIBNIZ_NEO4J_USER=neo4j
LEIBNIZ_NEO4J_PASSWORD=your-neo4j-password-here
LEIBNIZ_QDRANT_HOST=localhost
LEIBNIZ_QDRANT_PORT=6333
LEIBNIZ_MEILISEARCH_HOST=http://localhost:7700
LEIBNIZ_MEILISEARCH_KEY=your-meilisearch-master-key-here
LEIBNIZ_GROBID_HOST=http://localhost:8070

# Performance settings (safe defaults)
LEIBNIZ_QUERY_TIMEOUT_MS=200
LEIBNIZ_CACHE_TTL_SECONDS=3600
LEIBNIZ_MAX_WORKERS=8
LEIBNIZ_BATCH_SIZE=100

# Development settings
LEIBNIZ_DEBUG=false
LEIBNIZ_LOG_LEVEL=INFO

# Data paths (using XDG defaults)
# Override these if you want data stored elsewhere
# LEIBNIZ_DATA_HOME=~/.local/share/leibniz
# LEIBNIZ_CACHE_HOME=~/.cache/leibniz
# LEIBNIZ_CONFIG_HOME=~/.config/leibniz
# LEIBNIZ_STATE_HOME=~/.local/state/leibniz
EOF
    
    info ".env.example created"
}

# Create public Python configuration
create_python_config() {
    header "Creating PUBLIC Python configuration"
    
    # Main package init
    cat > leibniz/__init__.py << 'EOF'
"""Research intelligence system for ML literature."""
__version__ = "0.1.0"
EOF
    
    # Config module - NO SECRETS
    cat > leibniz/config/__init__.py << 'EOF'
"""Configuration management with security separation."""
import os
from pathlib import Path
from typing import Optional, Dict, Any
from pydantic_settings import BaseSettings
from pydantic import Field

class ServiceDefaults:
    """Default service configurations - PUBLIC information only."""
    
    # Default ports (public knowledge)
    REDIS_PORT = 6379
    NEO4J_BOLT_PORT = 7687
    NEO4J_HTTP_PORT = 7474
    QDRANT_HTTP_PORT = 6333
    QDRANT_GRPC_PORT = 6334
    MEILISEARCH_PORT = 7700
    GROBID_PORT = 8070
    
    # Performance defaults (public knowledge)
    QUERY_TIMEOUT_MS = 200
    CACHE_TTL_SECONDS = 3600
    MAX_WORKERS = 8
    BATCH_SIZE = 100

class XDGPaths:
    """XDG Base Directory specification paths."""
    
    def __init__(self, app_name: str = "leibniz"):
        self.app_name = app_name
        
        # Standard XDG paths
        self.config_home = Path(os.environ.get('XDG_CONFIG_HOME', '~/.config')).expanduser()
        self.data_home = Path(os.environ.get('XDG_DATA_HOME', '~/.local/share')).expanduser()
        self.cache_home = Path(os.environ.get('XDG_CACHE_HOME', '~/.cache')).expanduser()
        self.state_home = Path(os.environ.get('XDG_STATE_HOME', '~/.local/state')).expanduser()
        
        # App-specific paths
        self.config_dir = self.config_home / app_name
        self.data_dir = self.data_home / app_name
        self.cache_dir = self.cache_home / app_name
        self.state_dir = self.state_home / app_name
        
        # Sub-directories
        self.pdfs_dir = self.data_dir / "pdfs"
        self.processed_dir = self.data_dir / "processed"
        self.embeddings_dir = self.data_dir / "embeddings"
        self.logs_dir = self.state_dir / "logs"
        self.metrics_dir = self.state_dir / "metrics"
        
    def ensure_directories(self):
        """Create all required directories."""
        dirs = [
            self.config_dir, self.data_dir, self.cache_dir, self.state_dir,
            self.pdfs_dir, self.processed_dir, self.embeddings_dir,
            self.logs_dir, self.metrics_dir
        ]
        for path in dirs:
            path.mkdir(parents=True, exist_ok=True)

class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # API Keys - loaded from environment only
    openai_api_key: str = Field(default="", env="LEIBNIZ_OPENAI_API_KEY")
    
    # Service configurations - loaded from environment
    redis_url: str = Field(default="redis://localhost:6379", env="LEIBNIZ_REDIS_URL")
    neo4j_uri: str = Field(default="bolt://localhost:7687", env="LEIBNIZ_NEO4J_URI")
    neo4j_user: str = Field(default="neo4j", env="LEIBNIZ_NEO4J_USER")
    neo4j_password: str = Field(default="", env="LEIBNIZ_NEO4J_PASSWORD")
    qdrant_host: str = Field(default="localhost", env="LEIBNIZ_QDRANT_HOST")
    qdrant_port: int = Field(default=6333, env="LEIBNIZ_QDRANT_PORT")
    meilisearch_host: str = Field(default="http://localhost:7700", env="LEIBNIZ_MEILISEARCH_HOST")
    meilisearch_key: str = Field(default="", env="LEIBNIZ_MEILISEARCH_KEY")
    grobid_host: str = Field(default="http://localhost:8070", env="LEIBNIZ_GROBID_HOST")
    
    # Performance settings
    query_timeout_ms: int = Field(default=200, env="LEIBNIZ_QUERY_TIMEOUT_MS")
    cache_ttl_seconds: int = Field(default=3600, env="LEIBNIZ_CACHE_TTL_SECONDS")
    max_workers: int = Field(default=8, env="LEIBNIZ_MAX_WORKERS")
    batch_size: int = Field(default=100, env="LEIBNIZ_BATCH_SIZE")
    
    # Development settings
    debug: bool = Field(default=False, env="LEIBNIZ_DEBUG")
    log_level: str = Field(default="INFO", env="LEIBNIZ_LOG_LEVEL")
    
    class Config:
        env_file = ".env"
        env_prefix = "LEIBNIZ_"
        case_sensitive = False

# Create singleton instances
paths = XDGPaths()
defaults = ServiceDefaults()

# Settings will be initialized when needed, loading from environment
# This allows the module to be imported without requiring .env to exist
_settings: Optional[Settings] = None

def get_settings() -> Settings:
    """Get settings instance, creating if needed."""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings

# Export public interface
__all__ = ['paths', 'defaults', 'get_settings', 'XDGPaths', 'ServiceDefaults', 'Settings']
EOF
    
    info "Public Python configuration created"
}

# Create CLI module
create_cli_module() {
    header "Creating CLI module"
    
    cat > leibniz/cli/__init__.py << 'EOF'
"""Command-line interface for Leibniz."""
import typer
from rich.console import Console
from rich.table import Table
from pathlib import Path
import sys

app = typer.Typer(
    name="leibniz",
    help="Research intelligence system for ML literature",
    add_completion=True,
)
console = Console()

@app.command()
def info():
    """Show configuration and paths information."""
    from ..config import paths, get_settings, defaults
    
    table = Table(title="Leibniz Configuration")
    table.add_column("Setting", style="cyan")
    table.add_column("Value", style="green")
    
    # XDG Paths
    table.add_row("Config Directory", str(paths.config_dir))
    table.add_row("Data Directory", str(paths.data_dir))
    table.add_row("Cache Directory", str(paths.cache_dir))
    table.add_row("State Directory", str(paths.state_dir))
    
    # Service Status
    table.add_row("", "")  # Separator
    try:
        settings = get_settings()
        table.add_row("Redis URL", settings.redis_url)
        table.add_row("Neo4j URI", settings.neo4j_uri)
        table.add_row("QDrant Host", f"{settings.qdrant_host}:{settings.qdrant_port}")
        table.add_row("Query Timeout", f"{settings.query_timeout_ms}ms")
    except Exception as e:
        table.add_row("Settings", f"[red]Error: {e}[/red]")
        table.add_row("", "[yellow]Run 'leibniz check' for diagnostics[/yellow]")
    
    console.print(table)

@app.command()
def init():
    """Initialize Leibniz data directories and check configuration."""
    from ..config import paths
    
    console.print("[bold blue]Initializing Leibniz...[/bold blue]")
    
    # Create directories
    paths.ensure_directories()
    console.print("[green]✓[/green] Created XDG directories")
    
    # Check for .env file
    if not Path(".env").exists():
        console.print("[yellow]⚠[/yellow]  No .env file found")
        console.print("   Run: cp .env.example .env")
        console.print("   Then edit .env with your credentials")
    else:
        console.print("[green]✓[/green] Found .env file")
    
    console.print("\nDirectories created:")
    console.print(f"  Config: {paths.config_dir}")
    console.print(f"  Data:   {paths.data_dir}")
    console.print(f"  Cache:  {paths.cache_dir}")
    console.print(f"  State:  {paths.state_dir}")

@app.command()
def check():
    """Check configuration and service connectivity."""
    from ..config import get_settings
    import socket
    
    console.print("[bold]Checking Leibniz configuration...[/bold]\n")
    
    # Check .env file
    if not Path(".env").exists():
        console.print("[red]✗[/red] No .env file found")
        console.print("  Create one with: cp .env.example .env")
        return
    
    # Try to load settings
    try:
        settings = get_settings()
        console.print("[green]✓[/green] Settings loaded successfully")
    except Exception as e:
        console.print(f"[red]✗[/red] Failed to load settings: {e}")
        return
    
    # Check for required API key
    if not settings.openai_api_key or settings.openai_api_key.startswith("sk-your"):
        console.print("[red]✗[/red] OpenAI API key not configured")
    else:
        console.print("[green]✓[/green] OpenAI API key configured")
    
    # Check service connectivity
    console.print("\n[bold]Checking services...[/bold]")
    
    services = [
        ("Redis", "localhost", 6379),
        ("Neo4j Bolt", "localhost", 7687),
        ("Neo4j HTTP", "localhost", 7474),
        ("QDrant", settings.qdrant_host, settings.qdrant_port),
        ("Meilisearch", "localhost", 7700),
        ("GROBID", "localhost", 8070),
    ]
    
    for name, host, port in services:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        try:
            result = sock.connect_ex((host, port))
            if result == 0:
                console.print(f"[green]✓[/green] {name} is accessible on port {port}")
            else:
                console.print(f"[red]✗[/red] {name} is not accessible on port {port}")
        except Exception as e:
            console.print(f"[red]✗[/red] {name} check failed: {e}")
        finally:
            sock.close()

if __name__ == "__main__":
    app()
EOF
    
    info "CLI module created"
}

# Create Guix manifest
create_guix_manifest() {
    header "Creating Guix manifest"
    
    cat > manifest.scm << 'EOF'
;; GNU Guix development manifest for Project Leibniz
;; This file is PUBLIC - contains only package specifications

(specifications->manifest
 '(;; System tools
   "python"
   "git"
   "make"
   "curl"
   "jq"
   "netcat-openbsd"  ; for port checking
   
   ;; Python packages from myguix channel
   "python-neo4j"
   "python-qdrant-client"
   "python-meilisearch"
   
   ;; Standard Python packages
   "python-fastapi"
   "python-uvicorn"
   "python-redis"
   "python-httpx"
   "python-pydantic"
   "python-numpy"
   "python-rich"
   "python-typer"
   "python-openai"
   
   ;; Development tools
   "python-pytest"
   "python-pytest-asyncio"
   "python-black"
   "python-mypy"
   "python-ruff"))
EOF
    
    info "manifest.scm created"
}

# Create public helper scripts
create_public_scripts() {
    header "Creating PUBLIC helper scripts"
    
    # Service check script
    cat > scripts/check-services.sh << 'EOF'
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
EOF
    chmod +x scripts/check-services.sh
    
    # Git hooks installer
    cat > scripts/install-git-hooks.sh << 'EOF'
#!/usr/bin/env bash
# Install git hooks to prevent accidental secret commits

set -euo pipefail

echo "Installing git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Pre-commit hook
cat > .git/hooks/pre-commit << 'HOOK'
#!/usr/bin/env bash
# Pre-commit hook to prevent committing secrets

set -euo pipefail

# Check for .env file
if git diff --cached --name-only | grep -qE "^\.env$"; then
    echo "❌ ERROR: Attempting to commit .env file!"
    echo "   Remove it with: git reset HEAD .env"
    exit 1
fi

# Check for local config files
if git diff --cached --name-only | grep -qE "(config/local/|_local\.py|_private\.py|_secrets\.py)"; then
    echo "❌ ERROR: Attempting to commit local/private config files!"
    echo "   These files should never be committed."
    exit 1
fi

# Check for common secret patterns in staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep -E "\.(py|yml|yaml|json|env|conf|cfg|ini)$" || true)

if [ ! -z "$STAGED_FILES" ]; then
    # Look for obvious secrets
    PATTERN="(api[_-]?key|apikey|password|passwd|secret|token|auth|credential|private[_-]?key)"
    FOUND=$(echo "$STAGED_FILES" | xargs grep -iE "$PATTERN" 2>/dev/null | grep -vE "(example|template|test|dummy|fake|mock)" || true)
    
    if [ ! -z "$FOUND" ]; then
        echo "⚠️  WARNING: Possible secrets detected in staged files!"
        echo "$FOUND" | head -10
        echo
        read -p "Are you sure these are safe to commit? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

echo "✓ Pre-commit checks passed"
HOOK

chmod +x .git/hooks/pre-commit

echo "✓ Git hooks installed successfully"
echo "  The pre-commit hook will prevent accidental commits of:"
echo "  - .env files"
echo "  - Files matching *_local.py, *_private.py, *_secrets.py"
echo "  - Files containing obvious secret patterns"
EOF
    chmod +x scripts/install-git-hooks.sh
    
    info "Public scripts created"
}

# Create setup-local script
create_local_setup_script() {
    header "Creating setup-local.sh script"
    
    cat > setup-local.sh << 'EOF'
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
EOF
    
    chmod +x setup-local.sh
    info "setup-local.sh created"
}

# Create documentation
create_documentation() {
    header "Creating documentation"
    
    # Security guidelines
    cat > docs/SECURITY.md << 'EOF'
# Security Guidelines

## Overview

This project follows security best practices to prevent accidental exposure of secrets.

## Never Commit

The following files/patterns are gitignored and must NEVER be committed:

- `.env` - Contains actual API keys and passwords
- `config/local/*` - Local configuration files
- `*_local.py`, `*_private.py`, `*_secrets.py` - Local Python modules
- Any file containing passwords, API keys, or credentials

## Environment Variables

All sensitive configuration is loaded from environment variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `LEIBNIZ_OPENAI_API_KEY` | OpenAI API key | `sk-...` |
| `LEIBNIZ_NEO4J_PASSWORD` | Neo4j database password | Strong password |
| `LEIBNIZ_MEILISEARCH_KEY` | Meilisearch master key | Random string |

## Local Setup Process

1. Copy `.env.example` to `.env`
2. Fill in your actual credentials in `.env`
3. Run `./setup-local.sh` for additional local configuration
4. Verify protection: `git status` should not show any secret files

## Git Hooks

Install pre-commit hooks to prevent accidental secret commits:

```bash
./scripts/install-git-hooks.sh
```

## Before Every Commit

1. Run `git status` to review staged files
2. Ensure no `.env` or `config/local/` files are staged
3. Check that no credentials appear in staged files
4. The pre-commit hook will provide additional safety

## If You Accidentally Commit Secrets

1. Immediately rotate the exposed credentials
2. Remove the secret from git history (see GitHub docs on removing sensitive data)
3. Force push the cleaned history
4. Notify team members if in a shared repository
EOF
    
    # Main README
    cat > README.md << 'EOF'
# Leibniz

Research intelligence system for ML literature.

## Features

- Sub-200ms semantic search across research papers
- Multi-source search fusion (vector, graph, keyword)
- Automatic contradiction detection
- Research gap identification
- XDG-compliant local data storage

## Prerequisites

- Python 3.10+
- Running instances of:
  - Redis (port 6379)
  - Neo4j (ports 7474, 7687)
  - QDrant (ports 6333, 6334)
  - Meilisearch (port 7700)
  - GROBID (port 8070)

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd leibniz

# 2. Run the setup script
./setup.sh

# 3. Create local configuration
./setup-local.sh

# 4. Edit .env with your credentials
$EDITOR .env

# 5. Install dependencies (Guix)
guix shell -m manifest.scm

# 6. Initialize Leibniz
python -m leibniz.cli init

# 7. Check everything is working
python -m leibniz.cli check
```

## Project Structure

```
leibniz/
├── leibniz/          # Main package
│   ├── api/         # REST API endpoints
│   ├── core/        # Core models and utilities
│   ├── services/    # Service integrations
│   ├── cli/         # Command-line interface
│   └── config/      # Configuration (no secrets)
├── tests/           # Test suites
├── scripts/         # Helper scripts
├── docs/           # Documentation
└── manifest.scm    # Guix package manifest
```

## Security

**Important**: This project separates public code from private configuration.

- See `docs/SECURITY.md` for security guidelines
- Never commit `.env` or files containing secrets
- Install git hooks: `./scripts/install-git-hooks.sh`

## Development

```bash
# Run tests
pytest

# Format code
black leibniz tests

# Type checking
mypy leibniz

# Start development server
python -m leibniz.api.server
```

## Configuration

Configuration is loaded from environment variables. See `.env.example` for all available options.

Data is stored according to XDG Base Directory specification:
- Config: `~/.config/leibniz/`
- Data: `~/.local/share/leibniz/`
- Cache: `~/.cache/leibniz/`
- Logs: `~/.local/state/leibniz/`

## License

MIT
EOF
    
    info "Documentation created"
}

# Create Makefile
create_makefile() {
    header "Creating Makefile"
    
    cat > Makefile << 'EOF'
.PHONY: help install init check test lint format clean

help:
	@echo "Leibniz Development Commands"
	@echo "  make init      - Initialize local directories and check setup"
	@echo "  make check     - Check configuration and services"
	@echo "  make test      - Run test suite"
	@echo "  make lint      - Run linters"
	@echo "  make format    - Format code with black"
	@echo "  make clean     - Clean cache and temporary files"

init:
	python -m leibniz.cli init

check:
	./scripts/check-services.sh
	python -m leibniz.cli check

test:
	pytest -v

lint:
	ruff leibniz tests
	mypy leibniz

format:
	black leibniz tests

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .mypy_cache .ruff_cache
	rm -rf logs/*.log
EOF
    
    info "Makefile created"
}

# Create initial tracking files
create_tracking_files() {
    header "Creating tracking files"
    
    cat > SPRINT_LOG.md << EOF
# Sprint Log

## $(date +"%Y-%m-%d %H:%M") - Project Initialized
- Repository structure created
- Security separation implemented
- Public configuration templates created
- Git hooks available for installation

## Next Steps
- Run ./setup-local.sh to create local configuration
- Edit .env with actual credentials
- Install git hooks with ./scripts/install-git-hooks.sh
EOF
    
    cat > PERFORMANCE_LOG.md << 'EOF'
# Performance Tracking

## Target Metrics
- P95 Query Latency: <200ms
- P50 Query Latency: <100ms
- Search Result Relevance: >90%

## Benchmarks
*To be populated after implementation*
EOF
    
    info "Tracking files created"
}

# Main setup function
main() {
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                  Project Leibniz Setup                       ║
║                                                              ║
║  This script creates PUBLIC files safe for the repository    ║
║  Private configuration will be created by setup-local.sh     ║
╚══════════════════════════════════════════════════════════════╝
EOF
    
    check_project_root
    
    # Create all public components
    create_public_structure
    create_gitignore
    create_env_template
    create_python_config
    create_cli_module
    create_guix_manifest
    create_public_scripts
    create_local_setup_script
    create_documentation
    create_makefile
    create_tracking_files
    
    # Summary
    echo
    header "Setup Complete!"
    
    cat << EOF

PUBLIC files created (safe to commit):
  ✓ Python package structure
  ✓ .gitignore (protects secrets)
  ✓ .env.example (template only)
  ✓ manifest.scm (Guix packages)
  ✓ Configuration modules (no secrets)
  ✓ Helper scripts
  ✓ Documentation

PRIVATE files (never commit):
  ⚠ .env (create with setup-local.sh)
  ⚠ config/local/* (create with setup-local.sh)

Next steps:
  1. Run: ./setup-local.sh
  2. Edit .env with your credentials
  3. Install git hooks: ./scripts/install-git-hooks.sh
  4. Enter Guix environment: guix shell -m manifest.scm
  5. Initialize: python -m leibniz.cli init
  6. Verify: python -m leibniz.cli check

Remember: Always run 'git status' before committing!
EOF
}

# Run main function
main "$@"