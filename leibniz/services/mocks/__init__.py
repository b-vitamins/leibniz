"""Mock services for development without external dependencies."""

import os

# Environment detection
IS_CODEX = os.getenv("CODEX_ENVIRONMENT", "").lower() == "true"
USE_MOCKS = IS_CODEX or os.getenv("LEIBNIZ_USE_MOCKS", "").lower() == "true"

__all__ = ["IS_CODEX", "USE_MOCKS"]
