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
