.PHONY: help install init check verify-docker test lint format clean \
	docker-up docker-down docker-logs docker-status docker-clean

help:
	@echo "Leibniz Development Commands"
	@echo "  make init      - Initialize local directories and check setup"
	@echo "  make check     - Check configuration and services"
	@echo "  make verify-docker - Verify Docker installation"
	@echo "  make test      - Run test suite"
	@echo "  make lint      - Run linters"
	@echo "  make format    - Format code with black"
	@echo "  make clean     - Clean cache and temporary files"

init:
	python -m leibniz.cli init

check:
	./scripts/check-services.sh
	python -m leibniz.cli check

verify-docker:
	./scripts/verify-docker.sh

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

docker-up:
	docker-compose up -d
	@echo "Waiting for services to be healthy..."
	@sleep 5
	@docker-compose ps

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f

docker-status:
	@docker-compose ps
	@echo "\nService Health:"
	@docker-compose ps | grep -E "(healthy|unhealthy|starting)" || echo "All services starting..."

docker-clean:
	docker-compose down -v
	@echo "\u26A0\uFE0F  All data volumes removed!"
