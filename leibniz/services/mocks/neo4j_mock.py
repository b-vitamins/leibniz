"""Neo4j mock for graph queries."""

from typing import Any


class Neo4jResult:
    """Mock query result."""

    def __init__(self, records: list[dict[str, Any]]) -> None:
        self._records = records
        self._index = 0

    def __aiter__(self) -> "Neo4jResult":
        """Return asynchronous iterator."""
        return self

    async def __anext__(self) -> dict[str, Any]:
        """Return next record."""
        if self._index >= len(self._records):
            raise StopAsyncIteration
        record = self._records[self._index]
        self._index += 1
        return record


class Neo4jSession:
    """Mock Neo4j session."""

    def __init__(self, mock_data: dict[str, list[dict[str, Any]]]) -> None:
        self.mock_data = mock_data

    async def run(self, query: str, **_params: Any) -> Neo4jResult:
        """Execute mock query."""
        # Simple pattern matching for common queries
        if "MATCH (p:Paper)" in query and "CONTRADICTS" in query:
            return Neo4jResult(self.mock_data.get("contradictions", []))
        if "MATCH (p:Paper)" in query:
            return Neo4jResult(self.mock_data.get("papers", []))
        return Neo4jResult([])

    async def close(self) -> None:
        """Close session."""


class Neo4jDriverMock:
    """Mock Neo4j driver."""

    def __init__(self) -> None:
        # Pre-populated test data
        self.mock_data = {
            "papers": [
                {
                    "p.id": "test_p_1",
                    "p.title": "Efficient Transformers via Sparse Attention",
                    "p.year": 2023,
                    "p.venue": "NeurIPS",
                },
                {
                    "p.id": "test_p_2",
                    "p.title": "BERT Performance on SQuAD: A Critical Analysis",
                    "p.year": 2023,
                    "p.venue": "ICLR",
                },
            ],
            "contradictions": [
                {
                    "p1.id": "test_p_1",
                    "p2.id": "test_p_2",
                    "c.claim": "BERT F1 score on SQuAD",
                    "c.delta": 2.8,
                }
            ],
        }

    def session(self) -> Neo4jSession:
        """Create mock session."""
        return Neo4jSession(self.mock_data)

    async def close(self) -> None:
        """Close driver."""
