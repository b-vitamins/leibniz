# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure following SWEBOK standards
- XDG-compliant directory structure for configuration and data
- Secure configuration management via environment variables
- CLI interface with `info`, `init`, and `check` commands
- Development environment setup with Guix manifest and pip requirements
- Git hooks to prevent accidental commit of secrets
- Comprehensive documentation including security guidelines
- Testing framework with pytest configuration
- Linting and formatting tools (black, ruff, mypy)
- Docker service health check scripts
- Makefile for common development tasks

### Added
- Mock services framework for Codex/offline development (Task 0.0.1)
- RedisMock with TTL support for in-memory caching
- Neo4jDriverMock with pre-populated test graph data
- QdrantMock with vector search simulation
- MeilisearchMock with keyword search functionality
- OpenAIMock for embeddings and synthesis without API calls
- GrobidMock for PDF parsing simulation
- Service factory pattern supporting mock/real service switching
- Test fixtures and data generators for realistic test scenarios
- Environment detection for automatic mock usage in Codex

### Development
- Added LEIBNIZ_USE_MOCKS environment variable for forced mock usage
- Configured pytest to automatically use mocks in test environment
- All mocks support async operations matching real service interfaces

### Security
- Clear separation of public code and private configuration
- Environment-based secrets management
- Git hooks for preventing secret commits
- Comprehensive .gitignore for sensitive files

### Added
- GitHub Actions CI workflow for automated testing and quality checks (Task 0.0.2)
- Multi-job CI pipeline: lint, test, performance, security, build, docs
- Performance benchmark automation with <200ms validation
- Local CI script for pre-push validation (scripts/ci-local.sh)
- PR template with performance impact checklist
- Dependabot configuration for dependency updates
- Codecov integration for test coverage tracking
- Security scanning with Bandit and Trufflehog

### Development
- CI enforces code quality standards (ruff, mypy)
- Automated performance regression detection
- Matrix testing for Python 3.11 and 3.12
- All CI jobs use mock services (no external dependencies)

## [0.1.0] - TBD

Initial development version. Not yet released.

[Unreleased]: https://github.com/b-vitamins/leibniz/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/b-vitamins/leibniz/releases/tag/v0.1.0
