"""Test fixtures and mock data generators."""
# ruff: noqa: S311

import random
from typing import Any

from faker import Faker

fake = Faker()


class TestDataGenerator:
    """Generate realistic test data."""

    def __init__(self) -> None:
        self.methods = [
            "BERT",
            "GPT",
            "ViT",
            "ResNet",
            "Transformer",
            "CLIP",
            "DeiT",
            "Swin",
        ]
        self.datasets = ["ImageNet", "COCO", "SQuAD", "GLUE", "WikiText", "CIFAR-10"]
        self.metrics = ["accuracy", "F1", "perplexity", "mAP", "BLEU", "FID"]
        self.venues = ["ICLR", "NeurIPS", "ICML", "CVPR", "ACL", "EMNLP"]

    def generate_paper(self, paper_id: int) -> dict[str, Any]:
        """Generate a realistic paper."""
        method = random.choice(self.methods)
        dataset = random.choice(self.datasets)

        return {
            "id": f"test_p_{paper_id}",
            "title": f"{method} Improvements on {dataset}: {fake.catch_phrase()}",
            "abstract": self._generate_abstract(method, dataset),
            "year": random.randint(2020, 2024),
            "venue": random.choice(self.venues),
            "authors": [fake.name() for _ in range(random.randint(2, 6))],
            "claims": self._generate_claims(method, dataset),
        }

    def _generate_abstract(self, method: str, dataset: str) -> str:
        """Generate realistic abstract."""
        templates = [
            f"We propose improvements to {method} that achieve state-of-the-art results on {dataset}. "
            f"Our approach combines {fake.word()} attention with {fake.word()} regularization. "
            f"Experiments show {random.randint(2, 10)}% improvement over baselines.",
            f"This paper introduces {fake.word()}-{method}, a novel variant achieving "
            f"{random.uniform(85, 99):.1f}% accuracy on {dataset}. "
            f"Key innovations include {fake.word()} pooling and {fake.word()} normalization.",
        ]
        return random.choice(templates)

    def _generate_claims(self, method: str, dataset: str) -> list[dict[str, Any]]:
        """Generate paper claims."""
        metric = random.choice(self.metrics)
        value = random.uniform(70, 99)

        return [
            {
                "metric": metric,
                "dataset": dataset,
                "method": method,
                "value": value,
            }
        ]

    def generate_dataset(self, n_papers: int = 100) -> list[dict[str, Any]]:
        """Generate full test dataset."""
        return [self.generate_paper(i) for i in range(n_papers)]
