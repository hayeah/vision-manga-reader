from __future__ import annotations

from pathlib import Path

import typer

from .models import PageSegmentation
from .render import OverlayStyle, PanelRenderer


def render_overlay(
    coordinates_json: Path = typer.Argument(..., exists=True, dir_okay=False, readable=True),
    output: Path = typer.Option(..., "--output", help="Write the overlay image here."),
    image_path: Path | None = typer.Option(
        None,
        "--image",
        help="Override the source image. Defaults to image_path stored in the JSON.",
    ),
    fill_alpha: float = typer.Option(0.25, min=0.0, max=1.0, help="Overlay fill opacity."),
    labels: bool = typer.Option(True, "--labels/--no-labels", help="Draw reading-order labels."),
    bbox: bool = typer.Option(True, "--bbox/--no-bbox", help="Draw bounding boxes."),
) -> None:
    page = PageSegmentation.from_json_file(coordinates_json)
    source_image = image_path or Path(page.image_path)
    renderer = PanelRenderer(
        style=OverlayStyle(
            fill_alpha=fill_alpha,
            show_labels=labels,
            show_bbox=bbox,
        )
    )
    renderer.write_overlay(image_path=source_image, page=page, output_path=output)


def main() -> None:
    typer.run(render_overlay)


if __name__ == "__main__":
    main()
