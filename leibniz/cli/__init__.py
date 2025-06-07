"""Command-line interface for Leibniz."""

import socket
from pathlib import Path

import typer
from pydantic import ValidationError
from rich.console import Console
from rich.table import Table

from leibniz.config import get_settings, paths

app = typer.Typer(
    name="leibniz",
    help="Research intelligence system for ML literature",
    add_completion=True,
)
console = Console()


@app.command()
def info() -> None:
    """Show configuration and paths information."""
    table = Table(title="Leibniz Configuration")
    table.add_column("Setting", style="cyan")
    table.add_column("Value", style="green")

    # XDG Paths
    table.add_row("Config Directory", str(paths.config_dir))
    table.add_row("Data Directory", str(paths.data_dir))
    table.add_row("Cache Directory", str(paths.cache_dir))
    table.add_row("State Directory", str(paths.state_dir))

    # Service Status
    table.add_row("", "")  # Separator
    try:
        settings = get_settings()
        table.add_row("Redis URL", settings.redis_url)
        table.add_row("Neo4j URI", settings.neo4j_uri)
        table.add_row("QDrant Host", f"{settings.qdrant_host}:{settings.qdrant_port}")
        table.add_row("Query Timeout", f"{settings.query_timeout_ms}ms")
    except (ValidationError, FileNotFoundError) as e:
        table.add_row("Settings", f"[red]Error: {e}[/red]")
        table.add_row("", "[yellow]Run 'leibniz check' for diagnostics[/yellow]")

    console.print(table)


@app.command()
def init() -> None:
    """Initialize Leibniz data directories and check configuration."""
    console.print("[bold blue]Initializing Leibniz...[/bold blue]")

    # Create directories
    paths.ensure_directories()
    console.print("[green]✓[/green] Created XDG directories")

    # Check for .env file
    if not Path(".env").exists():
        console.print("[yellow]⚠[/yellow]  No .env file found")
        console.print("   Run: cp .env.example .env")
        console.print("   Then edit .env with your credentials")
    else:
        console.print("[green]✓[/green] Found .env file")

    console.print("\nDirectories created:")
    console.print(f"  Config: {paths.config_dir}")
    console.print(f"  Data:   {paths.data_dir}")
    console.print(f"  Cache:  {paths.cache_dir}")
    console.print(f"  State:  {paths.state_dir}")


@app.command()
def check() -> None:
    """Check configuration and service connectivity."""
    console.print("[bold]Checking Leibniz configuration...[/bold]\n")

    # Check .env file
    if not Path(".env").exists():
        console.print("[red]✗[/red] No .env file found")
        console.print("  Create one with: cp .env.example .env")
        return

    # Try to load settings
    try:
        settings = get_settings()
        console.print("[green]✓[/green] Settings loaded successfully")
    except (ValidationError, FileNotFoundError) as e:
        console.print(f"[red]✗[/red] Failed to load settings: {e}")
        return

    # Check for required API key
    if (
        not settings.openai_api_key
        or "your-openai-api-key-here" in settings.openai_api_key
    ):
        console.print("[red]✗[/red] OpenAI API key not configured")
    else:
        console.print("[green]✓[/green] OpenAI API key configured")

    # Check service connectivity
    console.print("\n[bold]Checking services...[/bold]")

    services = [
        ("Redis", "localhost", 6379),
        ("Neo4j Bolt", "localhost", 7687),
        ("Neo4j HTTP", "localhost", 7474),
        ("QDrant", settings.qdrant_host, settings.qdrant_port),
        ("Meilisearch", "localhost", 7700),
        ("GROBID", "localhost", 8070),
    ]

    for name, host, port in services:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(1)
        try:
            result = sock.connect_ex((host, port))
            if result == 0:
                console.print(f"[green]✓[/green] {name} is accessible on port {port}")
            else:
                console.print(f"[red]✗[/red] {name} is not accessible on port {port}")
        except (TimeoutError, socket.gaierror) as e:
            console.print(f"[red]✗[/red] {name} check failed: {e}")
        finally:
            sock.close()


if __name__ == "__main__":
    app()
