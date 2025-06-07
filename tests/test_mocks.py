import pytest

from leibniz.services.mocks.factory import get_qdrant_client, get_redis_client


@pytest.mark.asyncio
async def test_redis_mock() -> None:
    """Test Redis mock functionality."""
    redis = get_redis_client()

    await redis.setex("test_key", 3600, "test_value")
    value = await redis.get("test_key")
    assert value == "test_value"

    await redis.setex("expire_key", 0, "value")
    value = await redis.get("expire_key")
    assert value is None


@pytest.mark.asyncio
async def test_qdrant_mock() -> None:
    """Test QDrant mock search."""
    qdrant = get_qdrant_client()

    results = await qdrant.search(
        collection_name="papers",
        query_vector=[0.1] * 1536,
        limit=5,
    )

    assert len(results) <= 5
    assert all(hasattr(r, "score") for r in results)
    assert all(hasattr(r, "payload") for r in results)
