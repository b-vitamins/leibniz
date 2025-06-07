"""Global pytest configuration and fixtures."""

import os

import pytest

# Force mocks in test environment
os.environ["LEIBNIZ_USE_MOCKS"] = "true"

from leibniz.services.mocks.factory import (
    get_meilisearch_client,
    get_neo4j_driver,
    get_openai_client,
    get_qdrant_client,
    get_redis_client,
)


@pytest.fixture
async def redis_mock():
    """Provide Redis mock."""
    return get_redis_client()


@pytest.fixture
async def neo4j_mock():
    """Provide Neo4j mock."""
    driver = get_neo4j_driver()
    yield driver
    await driver.close()


@pytest.fixture
async def qdrant_mock():
    """Provide QDrant mock."""
    return get_qdrant_client()


@pytest.fixture
async def meilisearch_mock():
    """Provide Meilisearch mock."""
    return get_meilisearch_client()


@pytest.fixture
async def openai_mock():
    """Provide OpenAI mock."""
    return get_openai_client()


@pytest.fixture
def anyio_backend() -> str:
    """Use asyncio for async tests."""
    return "asyncio"
