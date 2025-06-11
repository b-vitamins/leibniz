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

## Prerequisites Verification

Check your Docker installation before running the setup scripts:

```bash
make verify-docker
# or
./scripts/verify-docker.sh
```

This script verifies:
- Docker version (20.10+ recommended)
- Docker daemon status
- Docker Compose availability
- Available disk space (100GB recommended)

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd leibniz

# 2. Setup development environment
./setup-dev.sh

# 3. Run the setup script
./setup.sh

# 4. Create local configuration
./setup-local.sh

# 5. Edit .env with your credentials
$EDITOR .env

# 6. Install dependencies (Guix)
guix shell -m manifest.scm

# 7. Initialize Leibniz
python -m leibniz.cli init

# 8. Check everything is working
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

GPL-3.0
