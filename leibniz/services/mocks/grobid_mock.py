"""GROBID mock for PDF parsing."""

from typing import Any


class GrobidMock:
    """Mock GROBID client."""

    def __init__(self, base_url: str = "http://localhost:8070") -> None:
        self.base_url = base_url

    async def process_pdf(self, _pdf_path: str) -> dict[str, Any]:
        """Mock PDF processing."""
        return {
            "title": "Mock Paper Title from GROBID",
            "abstract": "This is a mock abstract extracted by GROBID.",
            "authors": [
                {"name": "John Doe", "affiliation": "Mock University"},
                {"name": "Jane Smith", "affiliation": "Research Lab"},
            ],
            "sections": [
                {
                    "title": "Introduction",
                    "text": "This paper introduces novel approaches to...",
                },
                {"title": "Methods", "text": "We propose the following methodology..."},
            ],
            "references": [
                {
                    "title": "Referenced Paper 1",
                    "authors": ["Author A", "Author B"],
                    "year": "2022",
                }
            ],
        }
