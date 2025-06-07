.PHONY: help install init check test lint format clean

help:
	@echo "Leibniz Development Commands"
	@echo "  make init      - Initialize local directories and check setup"
	@echo "  make check     - Check configuration and services"
	@echo "  make test      - Run test suite"
	@echo "  make lint      - Run linters"
	@echo "  make format    - Format code with black"
	@echo "  make clean     - Clean cache and temporary files"

init:
	python -m leibniz.cli init

check:
	./scripts/check-services.sh
	python -m leibniz.cli check

test:
	pytest -v

lint:
	ruff leibniz tests
	mypy leibniz

format:
	black leibniz tests

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	rm -rf .pytest_cache .mypy_cache .ruff_cache
	rm -rf logs/*.log
