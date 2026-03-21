# manga — Manga Creative CLI

Panel segmentation and colorization tool for manga pages.

## Install

```sh
cd tools/manga_creative
uv tool install -e .
```

Requires `imagegen` CLI to be installed for colorization.

## Commands

### `manga panel <page> [page2]`

Segment a page into panels using YOLO-based detection.

```sh
cd /path/to/manga/volume
manga panel 010                    # single page
manga panel 11 12                  # spread (RTL join)
manga panel 010 --output-overlay   # generate debug overlay image
manga panel 010 --bbox             # rectangular crops instead of polygon
manga panel 010 --force            # re-run even if cached
manga panel --dir /path/to/vol 10  # explicit volume dir
```

- Auto-creates work directory `010/` with `info.json`
- Writes `panel/info.json` (segmentation data) and `panel/{N}.png` (polygon crops with transparency)
- Uses `deepghs-frame` model preset by default
- Skips if `panel/info.json` already exists (use `--force` to re-run)
- Page numbers accept `010`, `10`, or `010.jpg`

### `manga color <page> [--panel N]`

Colorize a full page or specific panel.

```sh
manga color 010                          # colorize full page (direct edit, no text model)
manga color 010 --panel 3                # colorize a specific panel
manga color 010 -n 3                     # generate 3 variants
manga color 010 --model gpt-5            # use text model for prompt expansion
manga color 010 --prompt "watercolor"    # custom prompt
manga color 010 --quality low            # faster/cheaper
```

- Default: `--model none` with `--image-model gpt-image-1.5` via Images edit API
- Set `--model gpt-5` to use Responses API (text model expands prompt, costs more)
- Outputs to `{page}/color/{timestamp}.webp` (or `panel/{N}/color/{timestamp}.webp`)
- JSON response sidecar saved alongside each variant

## Directory Convention

```
volume/
  010.jpg                          # source page
  010/
    info.json                      # { "pages": ["010.jpg"] }
    panel/
      info.json                    # segmentation data (bboxes, reading order)
      overlay.jpg                  # debug overlay (if --output-overlay)
      1.png                        # polygon crop, panel 1 (reading order)
      2.png
      1/
        color/
          20260316-201955.webp     # colorized variant
          20260316-201955.json     # API response metadata
    color/
      20260316-200313.webp         # full-page colorized
      20260316-200313.json
```

- Work dir = page number (no extension); for spreads, lower page number
- Two entries in `info.json` `pages` array = spread
- Each tool owns its subdirectory with its own `info.json`
- Variants named by sortable timestamp

## Spreads

Two pages joined horizontally (RTL: first arg = right page):

```sh
manga panel 011 012       # joins 011+012 as spread, stores in 011/
manga color 011 012       # colorize the spread
```

## Prompts

Edit `src/manga_creative/prompts.py` to adjust colorization prompts:

- `COLORIZE_PAGE` / `COLORIZE_PANEL` — simple prompts for text-model path (`--model gpt-5`)
- `COLORIZE_PAGE_DIRECT` / `COLORIZE_PANEL_DIRECT` — detailed prompts for direct edit path (`--model none`)

## Dependencies

- `manga-panel-segmenter` — YOLO panel detection (local package)
- `imagegen` — AI image generation CLI (must be installed separately)
- `hayeah` — structured logging
