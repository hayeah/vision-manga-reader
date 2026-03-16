from __future__ import annotations

from enum import StrEnum
from pathlib import Path

import typer

from .model_presets import available_presets_text, resolve_profile
from .segmenter import MangaPanelSegmenter, ModelSpec


class CropMode(StrEnum):
    bbox = "bbox"
    masked = "masked"


def segment(
    image_path: Path | None = typer.Argument(None, exists=True, dir_okay=False, readable=True),
    output_json: Path | None = typer.Option(None, "--output-json", help="Write JSON to a file."),
    overlay: Path | None = typer.Option(None, "--overlay", help="Write an overlay image."),
    crop_dir: Path | None = typer.Option(
        None, "--crop-dir", help="Write panel crops into a directory."
    ),
    crop_mode: CropMode = typer.Option(CropMode.masked, "--crop-mode", help="Panel crop style."),
    max_panels: int = typer.Option(64, min=1, help="Maximum number of detections."),
    preset: str | None = typer.Option(None, "--preset", help="Built-in model preset to use."),
    model_repo: str | None = typer.Option(None, "--model-repo", help="Hugging Face repo id."),
    model_filename: str | None = typer.Option(
        None,
        "--model-filename",
        help="Checkpoint filename inside the repo.",
    ),
    device: str | None = typer.Option(
        None, "--device", help="Torch device, for example cpu or mps."
    ),
    class_id: int | None = typer.Option(
        None, "--class-id", help="Filter detections to a specific model class id."
    ),
    class_name: str | None = typer.Option(
        None, "--class-name", help="Filter detections to a specific model class name."
    ),
    list_presets: bool = typer.Option(
        False, "--list-presets", help="Show built-in presets and exit."
    ),
    confidence: float | None = typer.Option(None, min=0.0, max=1.0, help="Confidence threshold."),
    iou: float | None = typer.Option(None, min=0.0, max=1.0, help="NMS IOU threshold."),
    pretty: bool = typer.Option(False, "--pretty", help="Pretty-print JSON."),
    stdout: bool = typer.Option(True, "--stdout/--no-stdout", help="Print JSON to stdout."),
) -> None:
    if list_presets:
        typer.echo(available_presets_text())
        return
    if image_path is None:
        raise typer.BadParameter("IMAGE_PATH is required unless --list-presets is used.")

    profile = resolve_profile(
        preset=preset,
        model_repo=model_repo,
        model_filename=model_filename,
        confidence=confidence,
        iou=iou,
        class_id=class_id,
        class_name=class_name,
    )
    segmenter = MangaPanelSegmenter(
        model=ModelSpec(repo_id=profile.model_repo, filename=profile.model_filename),
        confidence=profile.confidence,
        iou=profile.iou,
        device=device,
        class_id=profile.class_id,
        class_name=profile.class_name,
    )
    page = segmenter.segment_image(image_path=image_path, max_panels=max_panels)

    if overlay is not None:
        segmenter.write_overlay(image_path=image_path, page=page, output_path=overlay)
    if crop_dir is not None:
        segmenter.write_crops(
            image_path=image_path,
            page=page,
            output_dir=crop_dir,
            masked=(crop_mode == CropMode.masked),
        )

    payload = page.to_json(indent=2 if pretty else None)
    if output_json is not None:
        output_json.parent.mkdir(parents=True, exist_ok=True)
        output_json.write_text(f"{payload}\n")
    if stdout or output_json is None:
        typer.echo(payload)


def main() -> None:
    typer.run(segment)


if __name__ == "__main__":
    main()
