"""Redis mock for testing without Redis server."""

import asyncio
from datetime import UTC, datetime, timedelta
from typing import Any


class RedisMock:
    """In-memory Redis mock with TTL support."""

    def __init__(self) -> None:
        self._store: dict[str, tuple[str, datetime | None]] = {}
        self._lock = asyncio.Lock()

    async def get(self, key: str) -> str | None:
        """Get value by key."""
        async with self._lock:
            if key in self._store:
                value, expiry = self._store[key]
                if expiry and datetime.now(UTC) > expiry:
                    del self._store[key]
                    return None
                return value
            return None

    async def setex(self, key: str, ttl: int, value: str) -> bool:
        """Set value with TTL in seconds."""
        async with self._lock:
            expiry = datetime.now(UTC) + timedelta(seconds=ttl)
            self._store[key] = (value, expiry)
            return True

    async def delete(self, key: str) -> int:
        """Delete key."""
        async with self._lock:
            if key in self._store:
                del self._store[key]
                return 1
            return 0

    async def ping(self) -> bool:
        """Health check."""
        return True

    def pipeline(self) -> "RedisMock":
        """Return a pipeline mock."""
        return self  # Simplified - just return self

    async def execute(self) -> list[Any]:
        """Execute pipeline (no-op for mock)."""
        return []
