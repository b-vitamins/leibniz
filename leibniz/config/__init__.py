"""Configuration management with security separation."""

import os
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings


class ServiceDefaults:
    """Default service configurations - PUBLIC information only."""

    # Default ports (public knowledge)
    REDIS_PORT = 6379
    NEO4J_BOLT_PORT = 7687
    NEO4J_HTTP_PORT = 7474
    QDRANT_HTTP_PORT = 6333
    QDRANT_GRPC_PORT = 6334
    MEILISEARCH_PORT = 7700
    GROBID_PORT = 8070

    # Performance defaults (public knowledge)
    QUERY_TIMEOUT_MS = 200
    CACHE_TTL_SECONDS = 3600
    MAX_WORKERS = 8
    BATCH_SIZE = 100


class XDGPaths:
    """XDG Base Directory specification paths."""

    def __init__(self, app_name: str = "leibniz"):
        self.app_name = app_name

        # Standard XDG paths
        self.config_home = Path(
            os.environ.get("XDG_CONFIG_HOME", "~/.config")
        ).expanduser()
        self.data_home = Path(
            os.environ.get("XDG_DATA_HOME", "~/.local/share")
        ).expanduser()
        self.cache_home = Path(
            os.environ.get("XDG_CACHE_HOME", "~/.cache")
        ).expanduser()
        self.state_home = Path(
            os.environ.get("XDG_STATE_HOME", "~/.local/state")
        ).expanduser()

        # App-specific paths
        self.config_dir = self.config_home / app_name
        self.data_dir = self.data_home / app_name
        self.cache_dir = self.cache_home / app_name
        self.state_dir = self.state_home / app_name

        # Sub-directories
        self.pdfs_dir = self.data_dir / "pdfs"
        self.processed_dir = self.data_dir / "processed"
        self.embeddings_dir = self.data_dir / "embeddings"
        self.logs_dir = self.state_dir / "logs"
        self.metrics_dir = self.state_dir / "metrics"

    def ensure_directories(self) -> None:
        """Create all required directories."""
        dirs = [
            self.config_dir,
            self.data_dir,
            self.cache_dir,
            self.state_dir,
            self.pdfs_dir,
            self.processed_dir,
            self.embeddings_dir,
            self.logs_dir,
            self.metrics_dir,
        ]
        for path in dirs:
            path.mkdir(parents=True, exist_ok=True)


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # API Keys - loaded from environment only
    openai_api_key: str = Field(default="", alias="LEIBNIZ_OPENAI_API_KEY")

    # Service configurations - loaded from environment
    redis_url: str = Field(default="redis://localhost:6379", alias="LEIBNIZ_REDIS_URL")
    neo4j_uri: str = Field(default="bolt://localhost:7687", alias="LEIBNIZ_NEO4J_URI")
    neo4j_user: str = Field(default="neo4j", alias="LEIBNIZ_NEO4J_USER")
    neo4j_password: str = Field(default="", alias="LEIBNIZ_NEO4J_PASSWORD")
    qdrant_host: str = Field(default="localhost", alias="LEIBNIZ_QDRANT_HOST")
    qdrant_port: int = Field(default=6333, alias="LEIBNIZ_QDRANT_PORT")
    meilisearch_host: str = Field(
        default="http://localhost:7700", alias="LEIBNIZ_MEILISEARCH_HOST"
    )
    meilisearch_key: str = Field(default="", alias="LEIBNIZ_MEILISEARCH_KEY")
    grobid_host: str = Field(
        default="http://localhost:8070", alias="LEIBNIZ_GROBID_HOST"
    )

    # Performance settings
    query_timeout_ms: int = Field(default=200, alias="LEIBNIZ_QUERY_TIMEOUT_MS")
    cache_ttl_seconds: int = Field(default=3600, alias="LEIBNIZ_CACHE_TTL_SECONDS")
    max_workers: int = Field(default=8, alias="LEIBNIZ_MAX_WORKERS")
    batch_size: int = Field(default=100, alias="LEIBNIZ_BATCH_SIZE")

    # Development settings
    debug: bool = Field(default=False, alias="LEIBNIZ_DEBUG")
    log_level: str = Field(default="INFO", alias="LEIBNIZ_LOG_LEVEL")

    class Config:
        """Pydantic configuration."""

        env_file = ".env"
        case_sensitive = False


# Create singleton instances
paths = XDGPaths()
defaults = ServiceDefaults()


class _SettingsCache:
    """Cache for settings instance to avoid global variable."""

    def __init__(self) -> None:
        self._settings: Settings | None = None

    def get(self) -> Settings:
        """Get cached settings or create new instance."""
        if self._settings is None:
            self._settings = Settings()
        return self._settings

    def reset(self) -> None:
        """Reset cached settings (useful for testing)."""
        self._settings = None


# Use a class to avoid global variable
_cache = _SettingsCache()


def get_settings() -> Settings:
    """Get settings instance, creating if needed."""
    return _cache.get()


# Export public interface
__all__ = [
    "ServiceDefaults",
    "Settings",
    "XDGPaths",
    "defaults",
    "get_settings",
    "paths",
]
