"""Panel segmentation command."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Optional

import typer
from hayeah import logger

from manga_panel_segmenter.model_presets import resolve_profile
from manga_panel_segmenter.segmenter import MangaPanelSegmenter, ModelSpec

from .workspace import Workspace

log = logger.new("manga")

app = typer.Typer(help="Panel segmentation")


@app.callback(invoke_without_command=True)
def panel(
    page: str = typer.Argument(..., help="Page number or filename"),
    page2: Optional[str] = typer.Argument(None, help="Second page for spread"),
    force: bool = typer.Option(False, "--force", help="Re-run even if cached"),
    bbox: bool = typer.Option(False, "--bbox", help="Use rectangular bbox crops instead of polygon"),
    output_overlay: bool = typer.Option(
        False, "--output-overlay", help="Generate overlay image for debugging"
    ),
    preset: str = typer.Option("deepghs-frame", "--preset", help="Model preset"),
    volume_dir: Optional[Path] = typer.Option(None, "--dir", help="Volume directory (default: cwd)"),
) -> None:
    """Segment a page into panels."""
    vol = volume_dir or Path.cwd()
    ws = Workspace(vol, page, page2)
    ws.ensure()

    panel_dir = ws.work_dir / "panel"
    info_path = panel_dir / "info.json"

    if info_path.exists() and not force:
        log.info("cached", info=str(info_path))
        typer.echo(f"Panel data already exists: {info_path}")
        typer.echo("Use --force to re-run segmentation.")
        return

    panel_dir.mkdir(exist_ok=True)

    profile = resolve_profile(
        preset=preset,
        model_repo=None,
        model_filename=None,
        confidence=None,
        iou=None,
        class_id=None,
        class_name=None,
    )
    segmenter = MangaPanelSegmenter(
        model=ModelSpec(repo_id=profile.model_repo, filename=profile.model_filename),
        confidence=profile.confidence,
        iou=profile.iou,
        class_name=profile.class_name,
    )

    image_path = ws.source_image_path()
    log.info("segmenting", image=str(image_path), preset=preset)
    page_seg = segmenter.segment_image(image_path=image_path)

    # Write panel/info.json
    info_path.write_text(page_seg.to_json(indent=2) + "\n")
    log.info("wrote_info", path=str(info_path), panels=len(page_seg.panels))

    # Crop panels
    masked = not bbox
    segmenter.write_crops(
        image_path=image_path,
        page=page_seg,
        output_dir=panel_dir,
        masked=masked,
    )
    # Rename from panel-001.png to 1.png
    for p in page_seg.panels:
        old_name = panel_dir / f"panel-{p.reading_order:03d}.png"
        new_name = panel_dir / f"{p.reading_order}.png"
        if old_name.exists():
            old_name.rename(new_name)
    log.info("wrote_crops", count=len(page_seg.panels), masked=masked)

    # Overlay
    if output_overlay:
        overlay_path = panel_dir / "overlay.jpg"
        segmenter.write_overlay(
            image_path=image_path, page=page_seg, output_path=overlay_path
        )
        log.info("wrote_overlay", path=str(overlay_path))

    # Summary
    typer.echo(f"Segmented {len(page_seg.panels)} panels → {panel_dir}")
    for p in page_seg.panels:
        w, h = p.bbox.width, p.bbox.height
        typer.echo(f"  {p.reading_order}: {w}x{h} (score={p.score:.2f})")
