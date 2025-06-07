"""Meilisearch mock for text search."""

from typing import Any


class MeilisearchMock:
    """Mock Meilisearch client."""

    def __init__(self, _url: str, _api_key: str | None = None) -> None:
        self.indexes = {
            "papers": MeilisearchIndexMock(),
        }

    def index(self, name: str) -> "MeilisearchIndexMock":
        """Get mock index."""
        return self.indexes.get(name, MeilisearchIndexMock())


class MeilisearchIndexMock:
    """Mock Meilisearch index."""

    def __init__(self) -> None:
        self.documents = [
            {
                "id": "test_p_1",
                "title": "Efficient Transformers via Sparse Attention",
                "abstract": "We propose sparse attention mechanisms that reduce computational complexity from O(n²) to O(n log n) while maintaining performance.",
                "year": 2023,
                "venue": "NeurIPS",
            },
            {
                "id": "test_p_2",
                "title": "Quantization Methods for Transformer Models",
                "abstract": "This paper explores quantization techniques to compress transformer models to 8-bit and 4-bit representations.",
                "year": 2023,
                "venue": "ICLR",
            },
        ]

    async def search(
        self, query: str, limit: int = 20, **_kwargs: Any
    ) -> dict[str, Any]:
        """Mock keyword search."""
        query_lower = query.lower()
        hits: list[dict[str, Any]] = []

        for doc in self.documents:
            score = 0
            text = f"{doc['title']} {doc['abstract']}".lower()

            for word in query_lower.split():
                score += text.count(word)

            if score > 0:
                hits.append({**doc, "_score": score})

        hits.sort(key=lambda x: x["_score"], reverse=True)

        return {
            "hits": hits[:limit],
            "processingTimeMs": 15,
            "query": query,
            "limit": limit,
        }

    def add_documents(self, documents: list[dict[str, Any]], **_kwargs: Any) -> None:
        """Mock document addition."""
        self.documents.extend(documents)

    def update_settings(self, settings: dict[str, Any]) -> None:
        """Mock settings update."""
