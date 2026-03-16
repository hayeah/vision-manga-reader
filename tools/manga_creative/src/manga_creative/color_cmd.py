"""Colorization command — calls imagegen openai under the hood."""

from __future__ import annotations

import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional

import typer
from hayeah import logger

from .prompts import COLORIZE_PAGE, COLORIZE_PANEL
from .workspace import Workspace

log = logger.new("manga")

app = typer.Typer(help="Colorize pages or panels")


@app.callback(invoke_without_command=True)
def color(
    page: str = typer.Argument(..., help="Page number or filename"),
    page2: Optional[str] = typer.Argument(None, help="Second page for spread"),
    panel_num: Optional[int] = typer.Option(None, "--panel", "-p", help="Panel number to colorize"),
    n: int = typer.Option(1, "-n", help="Number of variants to generate"),
    model: str = typer.Option("gpt-5", "--model", help="Text model for imagegen"),
    image_model: Optional[str] = typer.Option(None, "--image-model", help="Image model override"),
    quality: str = typer.Option("auto", "--quality", help="Quality: low / medium / high / auto"),
    volume_dir: Optional[Path] = typer.Option(None, "--dir", help="Volume directory (default: cwd)"),
) -> None:
    """Colorize a full page/spread or a specific panel."""
    vol = volume_dir or Path.cwd()
    ws = Workspace(vol, page, page2)
    ws.ensure()

    if panel_num is not None:
        _colorize_panel(ws, panel_num, n=n, model=model, image_model=image_model, quality=quality)
    else:
        _colorize_page(ws, n=n, model=model, image_model=image_model, quality=quality)


def _colorize_page(
    ws: Workspace,
    *,
    n: int,
    model: str,
    image_model: str | None,
    quality: str,
) -> None:
    color_dir = ws.work_dir / "color"
    color_dir.mkdir(exist_ok=True)
    source = ws.source_image_path()
    prompt = COLORIZE_PAGE

    for i in range(n):
        ts = _timestamp()
        if n > 1:
            ts = f"{ts}-{i + 1}"
        output = color_dir / f"{ts}.png"
        _run_imagegen(
            prompt=prompt,
            source=source,
            output=output,
            model=model,
            image_model=image_model,
            quality=quality,
        )
        typer.echo(str(output))


def _colorize_panel(
    ws: Workspace,
    panel_num: int,
    *,
    n: int,
    model: str,
    image_model: str | None,
    quality: str,
) -> None:
    panel_file = ws.work_dir / "panel" / f"{panel_num}.png"
    if not panel_file.exists():
        typer.echo(f"Panel {panel_num} not found at {panel_file}")
        typer.echo("Run 'manga panel' first to segment the page.")
        raise typer.Exit(1)

    color_dir = ws.work_dir / "panel" / str(panel_num) / "color"
    color_dir.mkdir(parents=True, exist_ok=True)
    prompt = COLORIZE_PANEL

    for i in range(n):
        ts = _timestamp()
        if n > 1:
            ts = f"{ts}-{i + 1}"
        output = color_dir / f"{ts}.png"
        _run_imagegen(
            prompt=prompt,
            source=panel_file,
            output=output,
            model=model,
            image_model=image_model,
            quality=quality,
        )
        typer.echo(str(output))


def _run_imagegen(
    *,
    prompt: str,
    source: Path,
    output: Path,
    model: str,
    image_model: str | None,
    quality: str,
) -> None:
    cmd = [
        "imagegen", "openai", "create",
        prompt,
        "-a", str(source),
        "-o", str(output),
        "--model", model,
        "--quality", quality,
    ]
    if image_model:
        cmd.extend(["--image-model", image_model])

    log.info("imagegen", output=str(output), model=model)
    result = subprocess.run(cmd, check=False)
    if result.returncode != 0:
        log.error("imagegen_failed", returncode=result.returncode)
        raise typer.Exit(result.returncode)


def _timestamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")
