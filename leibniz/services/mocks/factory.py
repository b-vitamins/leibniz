"""Factory for creating mock or real service clients."""
# ruff: noqa: ANN401

import os
from typing import Any

from .grobid_mock import GrobidMock
from .meilisearch_mock import MeilisearchMock
from .neo4j_mock import Neo4jDriverMock
from .openai_mock import OpenAIMock
from .qdrant_mock import QdrantMock
from .redis_mock import RedisMock

# Check if we should use mocks
USE_MOCKS = (
    os.getenv("CODEX_ENVIRONMENT", "").lower() == "true"
    or os.getenv("LEIBNIZ_USE_MOCKS", "").lower() == "true"
)


def get_redis_client(**kwargs: Any) -> Any:
    """Get Redis client (mock or real)."""
    if USE_MOCKS:
        return RedisMock()
    try:
        import redis

        return redis.Redis(**kwargs)
    except Exception:  # noqa: BLE001
        return RedisMock()


def get_neo4j_driver(**kwargs: Any) -> Any:
    """Get Neo4j driver (mock or real)."""
    if USE_MOCKS:
        return Neo4jDriverMock()
    try:
        from neo4j import AsyncGraphDatabase

        return AsyncGraphDatabase.driver(**kwargs)
    except Exception:  # noqa: BLE001
        return Neo4jDriverMock()


def get_qdrant_client(**kwargs: Any) -> Any:
    """Get QDrant client (mock or real)."""
    if USE_MOCKS:
        return QdrantMock()
    try:
        from qdrant_client import QdrantClient

        return QdrantClient(**kwargs)
    except Exception:  # noqa: BLE001
        return QdrantMock()


def get_meilisearch_client(**kwargs: Any) -> Any:
    """Get Meilisearch client (mock or real)."""
    if USE_MOCKS:
        return MeilisearchMock()
    try:
        import meilisearch

        return meilisearch.Client(**kwargs)
    except Exception:  # noqa: BLE001
        return MeilisearchMock()


def get_openai_client(**kwargs: Any) -> Any:
    """Get OpenAI client (mock or real)."""
    if USE_MOCKS:
        return OpenAIMock()
    try:
        from openai import AsyncOpenAI

        return AsyncOpenAI(**kwargs)
    except Exception:  # noqa: BLE001
        return OpenAIMock()


def get_grobid_client(**kwargs: Any) -> Any:
    """Get GROBID client (mock or real)."""
    if USE_MOCKS:
        return GrobidMock(**kwargs)

    return GrobidMock(**kwargs)
