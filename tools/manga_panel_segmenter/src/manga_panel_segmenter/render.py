from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence

import cv2
import numpy as np

from .models import PageSegmentation, Panel, Point


@dataclass(slots=True)
class OverlayStyle:
    fill_alpha: float = 0.25
    stroke_thickness: int = 3
    bbox_thickness: int = 2
    font_scale: float = 0.8
    font_thickness: int = 2
    show_labels: bool = True
    show_bbox: bool = True


class PanelRenderer:
    def __init__(self, style: OverlayStyle | None = None):
        self.style = style or OverlayStyle()

    def write_overlay(self, image_path: Path, page: PageSegmentation, output_path: Path) -> None:
        image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image is None:
            raise FileNotFoundError(image_path)

        overlay = self.overlay_image(image=image, page=page)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        cv2.imwrite(str(output_path), overlay)

    def overlay_image(
        self,
        image: np.ndarray[Any, Any],
        page: PageSegmentation,
    ) -> np.ndarray[Any, Any]:
        fill_layer = image.copy()
        line_layer = image.copy()
        for panel in page.panels:
            polygon = self._polygon_array(panel.polygon)
            color = self._panel_color(panel.reading_order)
            cv2.fillPoly(fill_layer, [polygon], color)
            cv2.polylines(
                line_layer,
                [polygon],
                isClosed=True,
                color=color,
                thickness=self.style.stroke_thickness,
            )
            if self.style.show_bbox:
                cv2.rectangle(
                    line_layer,
                    (panel.bbox.left, panel.bbox.top),
                    (panel.bbox.right, panel.bbox.bottom),
                    color,
                    self.style.bbox_thickness,
                )
            if self.style.show_labels:
                cv2.putText(
                    line_layer,
                    str(panel.reading_order),
                    (panel.bbox.left + 8, max(24, panel.bbox.top + 28)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    self.style.font_scale,
                    color,
                    self.style.font_thickness,
                    cv2.LINE_AA,
                )

        return cv2.addWeighted(
            fill_layer,
            self.style.fill_alpha,
            line_layer,
            1.0 - self.style.fill_alpha,
            0,
        )

    def write_crops(
        self,
        image_path: Path,
        page: PageSegmentation,
        output_dir: Path,
        masked: bool,
    ) -> None:
        image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image is None:
            raise FileNotFoundError(image_path)

        output_dir.mkdir(parents=True, exist_ok=True)
        for panel in page.panels:
            crop = self._crop_panel(image=image, panel=panel, masked=masked)
            output_path = output_dir / f"panel-{panel.reading_order:03d}.png"
            cv2.imwrite(str(output_path), crop)

    def _crop_panel(
        self,
        image: np.ndarray[Any, Any],
        panel: Panel,
        masked: bool,
    ) -> np.ndarray[Any, Any]:
        left, top, right, bottom = (
            panel.bbox.left,
            panel.bbox.top,
            panel.bbox.right,
            panel.bbox.bottom,
        )
        if not masked:
            return image[top:bottom, left:right]

        mask = np.zeros(image.shape[:2], dtype=np.uint8)
        cv2.fillPoly(mask, [self._polygon_array(panel.polygon)], 255)

        crop_bgr = image[top:bottom, left:right]
        crop_mask = mask[top:bottom, left:right]
        alpha = crop_mask[:, :, None]
        return np.dstack([crop_bgr, alpha])

    def _polygon_array(self, polygon: Sequence[Point]) -> np.ndarray[Any, Any]:
        return np.array([[point.x, point.y] for point in polygon], dtype=np.int32)

    def _panel_color(self, reading_order: int) -> tuple[int, int, int]:
        palette = [
            (250, 140, 64),
            (90, 185, 255),
            (106, 186, 112),
            (245, 210, 70),
            (210, 90, 170),
            (92, 220, 220),
        ]
        return palette[(reading_order - 1) % len(palette)]
