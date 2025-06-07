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
