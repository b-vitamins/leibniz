"""OpenAI API mock for embeddings and synthesis."""

import asyncio
from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Any

import numpy as np


@dataclass
class EmbeddingData:
    """Embedding data item."""

    embedding: list[float]
    index: int


@dataclass
class EmbeddingResponse:
    """Response from embeddings endpoint."""

    data: list[EmbeddingData]
    model: str
    usage: dict[str, int]


@dataclass
class ChatCompletionChunk:
    """Streaming chat chunk."""

    choices: list[dict[str, Any]]


class OpenAIMock:
    """Mock OpenAI client."""

    def __init__(self) -> None:
        self.embeddings = EmbeddingsMock()
        self.chat = ChatMock()


class EmbeddingsMock:
    """Mock embeddings endpoint."""

    async def create(
        self, text_input: str | list[str], model: str = "text-embedding-ada-002"
    ) -> EmbeddingResponse:
        """Generate mock embeddings."""
        if isinstance(text_input, str):
            text_input = [text_input]

        data = []
        for idx, text in enumerate(text_input):
            np.random.seed(hash(text) % 2**32)
            embedding = np.random.randn(1536).tolist()
            data.append(EmbeddingData(embedding=embedding, index=idx))

        return EmbeddingResponse(
            data=data,
            model=model,
            usage={
                "prompt_tokens": len(text_input) * 10,
                "total_tokens": len(text_input) * 10,
            },
        )


class ChatMock:
    """Mock chat completions."""

    class Completions:
        """Mock chat completions endpoints."""

        async def create(
            self, messages: list[dict[str, Any]], stream: bool = False, **_kwargs: Any
        ) -> object:
            """Generate mock completions."""
            if stream:
                return ChatStreamMock(messages)

            return {
                "choices": [
                    {
                        "message": {
                            "content": "This is a mock synthesis of the provided papers. The research shows convergent findings on transformer efficiency improvements through sparse attention, quantization, and knowledge distillation techniques.",
                            "role": "assistant",
                        }
                    }
                ],
                "usage": {"total_tokens": 150},
            }

    def __init__(self) -> None:
        self.completions = self.Completions()


class ChatStreamMock:
    """Mock streaming chat response."""

    def __init__(self, _messages: list[dict[str, Any]]) -> None:
        self.chunks = [
            "This is a mock synthesis. ",
            "Research shows improvements in ",
            "transformer efficiency through ",
            "sparse attention and quantization.",
        ]

    async def __aiter__(self) -> AsyncIterator[ChatCompletionChunk]:
        """Stream mock chunks."""
        for chunk_text in self.chunks:
            await asyncio.sleep(0.05)
            yield ChatCompletionChunk(choices=[{"delta": {"content": chunk_text}}])
