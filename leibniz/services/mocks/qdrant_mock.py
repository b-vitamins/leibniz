"""QDrant mock for vector search."""

from dataclasses import dataclass
from typing import Any

import numpy as np


@dataclass
class ScoredPoint:
    """Mock scored point result."""

    id: str
    score: float
    payload: dict[str, Any]


class QdrantMock:
    """Mock QDrant client."""

    def __init__(self, _host: str = "localhost", _port: int = 6333) -> None:
        # Pre-computed embeddings for test papers
        self.collections = {
            "papers": {
                "vectors": {
                    "test_p_1": np.random.randn(1536).tolist(),
                    "test_p_2": np.random.randn(1536).tolist(),
                    "test_p_3": np.random.randn(1536).tolist(),
                },
                "payloads": {
                    "test_p_1": {
                        "paper_id": "test_p_1",
                        "title": "Efficient Transformers via Sparse Attention",
                        "abstract": "We propose sparse attention mechanisms...",
                        "year": 2023,
                        "venue": "NeurIPS",
                    },
                    "test_p_2": {
                        "paper_id": "test_p_2",
                        "title": "Quantization Methods for Transformer Models",
                        "abstract": "This paper explores quantization techniques...",
                        "year": 2023,
                        "venue": "ICLR",
                    },
                    "test_p_3": {
                        "paper_id": "test_p_3",
                        "title": "Knowledge Distillation in Large Language Models",
                        "abstract": "We present a novel distillation approach...",
                        "year": 2024,
                        "venue": "ICML",
                    },
                },
            }
        }

    async def search(
        self,
        collection_name: str,
        query_vector: list[float],
        limit: int = 10,
        **_kwargs: Any,
    ) -> list[ScoredPoint]:
        """Mock vector search."""
        if collection_name not in self.collections:
            return []

        _ = query_vector
        collection = self.collections[collection_name]
        results = []

        # Simple mock scoring - just return top papers with fake scores
        for idx, (doc_id, payload) in enumerate(collection["payloads"].items()):
            if idx >= limit:
                break

            # Fake relevance score based on query
            score = 0.95 - (idx * 0.1)
            results.append(
                ScoredPoint(
                    id=doc_id,
                    score=score,
                    payload=payload,
                )
            )

        return results

    def recreate_collection(self, *args: object, **kwargs: object) -> None:
        """Mock collection creation."""

    def upsert(self, *args: object, **kwargs: object) -> None:
        """Mock upsert operation."""
