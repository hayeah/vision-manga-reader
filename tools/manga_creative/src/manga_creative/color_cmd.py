"""Colorization command — uses hayeah.imagegen directly."""

from __future__ import annotations

import json
from datetime import datetime
from pathlib import Path
from typing import Optional

import typer
from hayeah.core import logger
from hayeah.imagegen import ImageResult, output_format_from_path
from hayeah.imagegen.openai import OpenAIProvider

from .prompts import (
    COLORIZE_PAGE,
    COLORIZE_PAGE_DIRECT,
    COLORIZE_PANEL,
    COLORIZE_PANEL_DIRECT,
)
from .workspace import Workspace

log = logger.new("manga")

app = typer.Typer(help="Colorize pages or panels")


@app.callback(invoke_without_command=True)
def color(
    page: str = typer.Argument(..., help="Page number or filename"),
    page2: Optional[str] = typer.Argument(None, help="Second page for spread"),
    panel_num: Optional[int] = typer.Option(None, "--panel", "-p", help="Panel number to colorize"),
    n: int = typer.Option(1, "-n", help="Number of variants to generate"),
    model: str = typer.Option("none", "--model", help="Text model (default: none = direct edit)"),
    image_model: str = typer.Option("gpt-image-1.5", "--image-model", help="Image model"),
    quality: str = typer.Option("low", "--quality", help="Quality: low / medium / high / auto"),
    prompt: Optional[str] = typer.Option(None, "--prompt", help="Custom prompt (overrides default)"),
    extra: Optional[str] = typer.Option(None, "--extra", "-e", help="Extra text appended to prompt"),
    volume_dir: Optional[Path] = typer.Option(None, "--dir", help="Volume directory (default: cwd)"),
) -> None:
    """Colorize a full page/spread or a specific panel."""
    vol = volume_dir or Path.cwd()
    ws = Workspace(vol, page, page2)
    ws.ensure()

    is_direct = model.lower() == "none"
    provider = OpenAIProvider(
        model=None if is_direct else model,
        image_model=image_model,
    )

    if panel_num is not None:
        source = _panel_source(ws, panel_num)
        color_dir = ws.work_dir / "panel" / str(panel_num) / "color"
        default_prompt = COLORIZE_PANEL_DIRECT if is_direct else COLORIZE_PANEL
    else:
        source = ws.source_image_path()
        color_dir = ws.work_dir / "color"
        default_prompt = COLORIZE_PAGE_DIRECT if is_direct else COLORIZE_PAGE

    color_dir.mkdir(parents=True, exist_ok=True)
    final_prompt = prompt or default_prompt
    if extra:
        final_prompt = f"{final_prompt}\n{extra}"
    image_bytes = source.read_bytes()

    for i in range(n):
        ts = _timestamp()
        if n > 1:
            ts = f"{ts}-{i + 1}"
        output = color_dir / f"{ts}.webp"
        fmt = output_format_from_path(output)

        log.info("colorize", output=str(output), model=model, image_model=image_model)

        if is_direct:
            results = provider.edit(
                final_prompt,
                images=[image_bytes],
                size="auto",
                quality=quality,
                output_format=fmt,
                input_fidelity="high",
            )
        else:
            results = provider.generate(
                final_prompt,
                images=[image_bytes],
                size="auto",
                quality=quality,
                output_format=fmt,
            )

        if results:
            result = results[0]
            result.save(output)
            _write_metadata(output, result)
            typer.echo(str(output))


def _panel_source(ws: Workspace, panel_num: int) -> Path:
    panel_file = ws.work_dir / "panel" / f"{panel_num}.png"
    if not panel_file.exists():
        typer.echo(f"Panel {panel_num} not found at {panel_file}")
        typer.echo("Run 'manga panel' first to segment the page.")
        raise typer.Exit(1)
    return panel_file


def _write_metadata(output: Path, result: ImageResult) -> None:
    """Write response metadata as JSON sidecar."""
    json_path = output.with_suffix(".json")
    json_path.write_text(json.dumps(result.metadata, indent=2, default=str) + "\n")
    log.info("wrote_metadata", path=str(json_path))


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")
