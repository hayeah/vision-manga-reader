"""manga — creative CLI for manga pages."""

from __future__ import annotations

from pathlib import Path

from dotenv import load_dotenv

import typer

from .color_cmd import app as color_app
from .panel_cmd import app as panel_app

ENV_SECRET = Path.home() / ".env.secret"

app = typer.Typer(help="Manga creative tools — panel segmentation and colorization.")
app.add_typer(panel_app, name="panel")
app.add_typer(color_app, name="color")


@app.callback()
def main() -> None:
    """Manga creative tools."""
    if ENV_SECRET.exists():
        load_dotenv(ENV_SECRET)


def run() -> None:
    app()


if __name__ == "__main__":
    run()
