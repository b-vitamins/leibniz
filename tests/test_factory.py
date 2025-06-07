"""Tests for the mock factory."""

import os


def test_factory_uses_mocks_in_test_environment() -> None:
    """Verify mocks are used in test environment."""
    assert os.getenv("LEIBNIZ_USE_MOCKS") == "true"

    from leibniz.services.mocks.factory import USE_MOCKS

    assert USE_MOCKS is True


def test_factory_returns_mocks() -> None:
    """Test that factory returns mock instances."""
    from leibniz.services.mocks.factory import (
        get_grobid_client,
        get_meilisearch_client,
        get_neo4j_driver,
        get_openai_client,
        get_qdrant_client,
        get_redis_client,
    )
    from leibniz.services.mocks.grobid_mock import GrobidMock
    from leibniz.services.mocks.meilisearch_mock import MeilisearchMock
    from leibniz.services.mocks.neo4j_mock import Neo4jDriverMock
    from leibniz.services.mocks.openai_mock import OpenAIMock
    from leibniz.services.mocks.qdrant_mock import QdrantMock
    from leibniz.services.mocks.redis_mock import RedisMock

    assert isinstance(get_redis_client(), RedisMock)
    assert isinstance(get_neo4j_driver(), Neo4jDriverMock)
    assert isinstance(get_qdrant_client(), QdrantMock)
    assert isinstance(get_meilisearch_client(), MeilisearchMock)
    assert isinstance(get_openai_client(), OpenAIMock)
    assert isinstance(get_grobid_client(), GrobidMock)


def test_factory_with_kwargs() -> None:
    """Test that factory passes kwargs correctly."""
    from leibniz.services.mocks.factory import (
        get_meilisearch_client,
        get_qdrant_client,
        get_redis_client,
    )

    redis = get_redis_client(host="localhost", port=6379)
    assert redis is not None

    qdrant = get_qdrant_client(host="localhost", port=6333)
    assert qdrant is not None

    meili = get_meilisearch_client(url="http://localhost:7700", api_key="test")
    assert meili is not None
