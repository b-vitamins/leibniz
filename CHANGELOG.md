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

### Security
- Clear separation of public code and private configuration
- Environment-based secrets management
- Git hooks for preventing secret commits
- Comprehensive .gitignore for sensitive files

## [0.1.0] - TBD

Initial development version. Not yet released.

[Unreleased]: https://github.com/yourusername/leibniz/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/yourusername/leibniz/releases/tag/v0.1.0