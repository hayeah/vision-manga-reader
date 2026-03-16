from __future__ import annotations

import json
from pathlib import Path

import typer

from .model_presets import PRESET_PROFILES, available_presets_text, resolve_profile
from .segmenter import MangaPanelSegmenter, ModelSpec


def compare_models(
    image_path: Path | None = typer.Argument(None, exists=True, dir_okay=False, readable=True),
    output_dir: Path | None = typer.Option(
        None, "--output-dir", help="Directory for comparison outputs."
    ),
    preset: list[str] = typer.Option(
        [],
        "--preset",
        help="Preset to include. Repeat to limit comparison to a subset.",
    ),
    crop_dir: bool = typer.Option(False, "--crop-dir", help="Write panel crops for each preset."),
    pretty: bool = typer.Option(True, "--pretty/--compact", help="Pretty-print JSON outputs."),
    list_presets: bool = typer.Option(
        False, "--list-presets", help="Show built-in presets and exit."
    ),
) -> None:
    if list_presets:
        typer.echo(available_presets_text())
        return
    if image_path is None:
        raise typer.BadParameter("IMAGE_PATH is required unless --list-presets is used.")
    if output_dir is None:
        raise typer.BadParameter("--output-dir is required unless --list-presets is used.")

    preset_names = preset or list(PRESET_PROFILES.keys())
    output_dir.mkdir(parents=True, exist_ok=True)

    summaries: list[dict[str, object]] = []
    for preset_name in preset_names:
        profile = resolve_profile(
            preset=preset_name,
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
            class_id=profile.class_id,
            class_name=profile.class_name,
        )
        page = segmenter.segment_image(image_path=image_path)

        preset_dir = output_dir / preset_name
        preset_dir.mkdir(parents=True, exist_ok=True)
        overlay_path = preset_dir / "overlay.png"
        json_path = preset_dir / "panels.json"

        segmenter.write_overlay(image_path=image_path, page=page, output_path=overlay_path)
        if crop_dir:
            segmenter.write_crops(
                image_path=image_path,
                page=page,
                output_dir=preset_dir / "crops",
                masked=True,
            )

        payload = page.to_json(indent=2 if pretty else None)
        json_path.write_text(f"{payload}\n")
        summaries.append(
            {
                "preset": preset_name,
                "description": profile.description,
                "model_repo": profile.model_repo,
                "model_filename": profile.model_filename,
                "confidence": profile.confidence,
                "class_name": profile.class_name,
                "panel_count": len(page.panels),
                "overlay_path": str(overlay_path),
                "json_path": str(json_path),
            }
        )

    summary_path = output_dir / "summary.json"
    summary_path.write_text(f"{json.dumps(summaries, indent=2 if pretty else None)}\n")
    typer.echo(summary_path)


def main() -> None:
    typer.run(compare_models)


if __name__ == "__main__":
    main()
