# Manga Panel Segmenter

CLI tool for segmenting manga/comic panels from a page image.

It defaults to the Hugging Face model `TheBlindMaster/yolov8n-manga-frame-seg`, which exposes a YOLOv8 segmentation checkpoint suitable for panel masks.

## Install

```bash
cd tools/manga_panel_segmenter
uv tool install -e .
```

## Usage

```bash
manga-panel-segment path/to/page.jpg --pretty
```

Use a built-in model preset:

```bash
manga-panel-segment path/to/page.jpg --preset blindmaster-seg --pretty
```

Write an overlay and masked panel crops:

```bash
manga-panel-segment \
  path/to/page.jpg \
  --preset blindmaster-seg \
  --pretty \
  --overlay output/page.overlay.png \
  --crop-dir output/panels \
  --output-json output/page.panels.json
```

Render an overlay later from saved coordinates:

```bash
manga-panel-overlay output/page.panels.json --output output/page.overlay.png
```

Compare built-in models on the same page:

```bash
manga-panel-compare path/to/page.jpg --output-dir output/compare
```

List the built-in presets:

```bash
manga-panel-segment --list-presets
```

## Notes

- The first run downloads the model weights from Hugging Face into the local cache.
- Panel ordering is approximate manga reading order: top-to-bottom, then right-to-left within each row.
- You can swap in another Ultralytics-compatible checkpoint with `--model-repo` and `--model-filename`.
- Built-in presets currently include `blindmaster-seg`, `deepghs-frame`, and `mosesb-comic`.
