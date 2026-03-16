from __future__ import annotations

from dataclasses import dataclass, field
from typing import Sequence

from .models import BoundingBox


@dataclass(slots=True)
class PanelRow:
    panel_indexes: list[int] = field(default_factory=list)
    top: int = 0
    bottom: int = 0

    @property
    def height(self) -> int:
        return max(1, self.bottom - self.top)

    @property
    def center_y(self) -> float:
        return (self.top + self.bottom) / 2

    def add(self, panel_index: int, bbox: BoundingBox) -> None:
        if not self.panel_indexes:
            self.top = bbox.top
            self.bottom = bbox.bottom
        else:
            self.top = min(self.top, bbox.top)
            self.bottom = max(self.bottom, bbox.bottom)
        self.panel_indexes.append(panel_index)

    def overlaps(self, bbox: BoundingBox, threshold: float) -> bool:
        vertical_overlap = max(0, min(self.bottom, bbox.bottom) - max(self.top, bbox.top))
        overlap_ratio = vertical_overlap / max(1, min(self.height, bbox.height))
        top_distance = abs(self.top - bbox.top)
        top_threshold = max(24.0, min(self.height, bbox.height) * 0.45)
        return overlap_ratio >= threshold and top_distance <= top_threshold


class MangaReadingOrder:
    """Approximate manga reading order: top-to-bottom, right-to-left per row."""

    def __init__(self, row_overlap_threshold: float = 0.35):
        self.row_overlap_threshold = row_overlap_threshold

    def sort_indexes(self, boxes: Sequence[BoundingBox]) -> list[int]:
        if not boxes:
            return []

        rows: list[PanelRow] = []
        for panel_index in sorted(range(len(boxes)), key=lambda index: boxes[index].top):
            bbox = boxes[panel_index]
            row = self._matching_row(rows, bbox)
            if row is None:
                row = PanelRow()
                rows.append(row)
            row.add(panel_index, bbox)

        rows.sort(key=lambda row: row.top)

        ordered: list[int] = []
        for row in rows:
            ordered.extend(
                sorted(
                    row.panel_indexes,
                    key=lambda panel_index: (boxes[panel_index].right, boxes[panel_index].top),
                    reverse=True,
                )
            )
        return ordered

    def _matching_row(self, rows: Sequence[PanelRow], bbox: BoundingBox) -> PanelRow | None:
        for row in rows:
            if row.overlaps(bbox, self.row_overlap_threshold):
                return row
        return None
