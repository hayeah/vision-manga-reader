"""Workspace — resolves page numbers to files, manages work directories."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image

IMAGE_EXTENSIONS = (".jpg", ".jpeg", ".png", ".webp")


class Workspace:
    """Manages the work directory for a page or spread."""

    def __init__(self, volume_dir: Path, page_num: str, page2_num: str | None = None):
        self.volume_dir = volume_dir.resolve()
        self.page_file = _resolve_page(volume_dir, page_num)
        self.page2_file = _resolve_page(volume_dir, page2_num) if page2_num else None
        self.work_dir = volume_dir / self.page_file.stem

    @property
    def is_spread(self) -> bool:
        return self.page2_file is not None

    @property
    def pages(self) -> list[str]:
        names = [self.page_file.name]
        if self.page2_file:
            names.append(self.page2_file.name)
        return names

    @property
    def info_path(self) -> Path:
        return self.work_dir / "info.json"

    def ensure(self) -> None:
        """Create work directory and info.json if needed."""
        self.work_dir.mkdir(exist_ok=True)
        if not self.info_path.exists():
            self.info_path.write_text(json.dumps({"pages": self.pages}, indent=2) + "\n")

    def source_image(self) -> Image.Image:
        """Load the source image (joining pages for spreads)."""
        img = Image.open(self.page_file)
        if self.page2_file is None:
            return img
        img2 = Image.open(self.page2_file)
        return _join_spread(img, img2)

    def source_image_path(self) -> Path:
        """For single pages, return the page file. For spreads, create a temp join."""
        if not self.is_spread:
            return self.page_file
        # For spreads, save a temporary joined image for tools that need a file path
        joined_path = self.work_dir / "_spread_tmp.jpg"
        if not joined_path.exists():
            self.ensure()
            img = self.source_image()
            img.save(str(joined_path), quality=95)
        return joined_path


def _resolve_page(volume_dir: Path, page_num: str) -> Path:
    """Resolve a page number (e.g. '10', '010', '010.jpg') to an actual file."""
    # If it already has an extension and exists, use it directly
    candidate = volume_dir / page_num
    if candidate.suffix and candidate.exists():
        return candidate

    # Strip extension if provided
    stem = Path(page_num).stem

    # Try the stem as-is, then zero-padded variants
    stems_to_try = [stem]
    if stem.isdigit():
        num = int(stem)
        stems_to_try.extend([f"{num:03d}", f"{num:02d}", f"{num:04d}", str(num)])

    seen: set[str] = set()
    for s in stems_to_try:
        if s in seen:
            continue
        seen.add(s)
        for ext in IMAGE_EXTENSIONS:
            candidate = volume_dir / f"{s}{ext}"
            if candidate.exists():
                return candidate

    raise FileNotFoundError(
        f"No image found for page '{page_num}' in {volume_dir}"
    )


def _join_spread(right_page: Image.Image, left_page: Image.Image) -> Image.Image:
    """Join two pages into a spread (RTL: right page on the left side)."""
    # Height-normalize
    target_height = max(right_page.height, left_page.height)

    if right_page.height != target_height:
        scale = target_height / right_page.height
        right_page = right_page.resize(
            (int(right_page.width * scale), target_height), Image.LANCZOS
        )
    if left_page.height != target_height:
        scale = target_height / left_page.height
        left_page = left_page.resize(
            (int(left_page.width * scale), target_height), Image.LANCZOS
        )

    total_width = right_page.width + left_page.width
    spread = Image.new("RGB", (total_width, target_height))
    spread.paste(right_page, (0, 0))
    spread.paste(left_page, (right_page.width, 0))
    return spread
