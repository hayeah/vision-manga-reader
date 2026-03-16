from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any, Sequence

import cv2
import numpy as np
from huggingface_hub import hf_hub_download
from ultralytics import YOLO  # pyright: ignore[reportPrivateImportUsage]

from .models import BoundingBox, PageSegmentation, Panel, Point
from .ordering import MangaReadingOrder
from .render import PanelRenderer

DEFAULT_MODEL_REPO = "TheBlindMaster/yolov8n-manga-frame-seg"
DEFAULT_MODEL_FILENAME = "best.pt"


@dataclass(slots=True)
class ModelSpec:
    repo_id: str = DEFAULT_MODEL_REPO
    filename: str = DEFAULT_MODEL_FILENAME


class MangaPanelSegmenter:
    def __init__(
        self,
        model: ModelSpec,
        confidence: float = 0.25,
        iou: float = 0.5,
        device: str | None = None,
        class_id: int | None = None,
        class_name: str | None = None,
    ):
        self.model = model
        self.confidence = confidence
        self.iou = iou
        self.device = device
        self.class_id = class_id
        self.class_name = class_name
        self.ordering = MangaReadingOrder()
        self.renderer = PanelRenderer()
        self._predictor = YOLO(self.model_path)

    @property
    def model_path(self) -> str:
        return hf_hub_download(repo_id=self.model.repo_id, filename=self.model.filename)

    def segment_image(self, image_path: Path, max_panels: int = 64) -> PageSegmentation:
        image = cv2.imread(str(image_path), cv2.IMREAD_COLOR)
        if image is None:
            raise FileNotFoundError(image_path)

        height, width = image.shape[:2]
        classes = self._classes_filter()
        result = self._predictor.predict(
            source=image,
            conf=self.confidence,
            iou=self.iou,
            device=self.device,
            classes=classes,
            max_det=max_panels,
            verbose=False,
        )[0]

        panels = self._extract_panels(result, width=width, height=height)
        return PageSegmentation.create(
            image_path=image_path,
            image_width=width,
            image_height=height,
            model_repo=self.model.repo_id,
            model_filename=self.model.filename,
            panels=panels,
        )

    def write_overlay(self, image_path: Path, page: PageSegmentation, output_path: Path) -> None:
        self.renderer.write_overlay(image_path=image_path, page=page, output_path=output_path)

    def write_crops(
        self, image_path: Path, page: PageSegmentation, output_dir: Path, masked: bool
    ) -> None:
        self.renderer.write_crops(
            image_path=image_path,
            page=page,
            output_dir=output_dir,
            masked=masked,
        )

    def _extract_panels(self, result: Any, width: int, height: int) -> list[Panel]:
        boxes = result.boxes
        if boxes is None or len(boxes) == 0:
            return []

        xyxy = boxes.xyxy.cpu().numpy()
        scores = boxes.conf.cpu().numpy()
        class_ids = boxes.cls.cpu().numpy().astype(int)
        polygons = self._result_polygons(result, xyxy)
        bboxes = [self._bbox_from_xyxy(coords, width=width, height=height) for coords in xyxy]
        ordered_indexes = self.ordering.sort_indexes(bboxes)

        panels_by_detection: dict[int, Panel] = {}
        for detection_index, (bbox, score, polygon, class_id) in enumerate(
            zip(bboxes, scores, polygons, class_ids, strict=True)
        ):
            area_px = int(abs(cv2.contourArea(self._polygon_array(polygon).astype(np.float32))))
            panels_by_detection[detection_index] = Panel(
                panel_id=detection_index,
                reading_order=0,
                score=round(float(score), 4),
                area_px=area_px,
                class_id=int(class_id),
                class_name=self._class_name(int(class_id)),
                bbox=bbox,
                polygon=polygon,
            )

        ordered_panels: list[Panel] = []
        for reading_order, detection_index in enumerate(ordered_indexes, start=1):
            panel = panels_by_detection[detection_index]
            panel.reading_order = reading_order
            ordered_panels.append(panel)
        return ordered_panels

    def _result_polygons(self, result: Any, xyxy: np.ndarray[Any, Any]) -> list[list[Point]]:
        if result.masks is None:
            return [self._bbox_polygon(self._bbox_from_xyxy(coords)) for coords in xyxy]
        return [self._normalize_polygon(points) for points in result.masks.xy]

    def _bbox_from_xyxy(
        self,
        coords: Sequence[float],
        width: int | None = None,
        height: int | None = None,
    ) -> BoundingBox:
        left, top, right, bottom = [int(round(value)) for value in coords]
        if width is not None:
            left = min(max(0, left), width - 1)
            right = min(max(left + 1, right), width)
        if height is not None:
            top = min(max(0, top), height - 1)
            bottom = min(max(top + 1, bottom), height)
        return BoundingBox(left=left, top=top, right=right, bottom=bottom)

    def _bbox_polygon(self, bbox: BoundingBox) -> list[Point]:
        return [
            Point(x=bbox.left, y=bbox.top),
            Point(x=bbox.right, y=bbox.top),
            Point(x=bbox.right, y=bbox.bottom),
            Point(x=bbox.left, y=bbox.bottom),
        ]

    def _normalize_polygon(self, polygon: np.ndarray[Any, Any]) -> list[Point]:
        points = [Point(x=int(round(x)), y=int(round(y))) for x, y in polygon]
        if len(points) < 3:
            left = min(point.x for point in points)
            right = max(point.x for point in points)
            top = min(point.y for point in points)
            bottom = max(point.y for point in points)
            return self._bbox_polygon(BoundingBox(left=left, top=top, right=right, bottom=bottom))
        return points

    def _polygon_array(self, polygon: Sequence[Point]) -> np.ndarray[Any, Any]:
        return np.array([[point.x, point.y] for point in polygon], dtype=np.int32)

    def _classes_filter(self) -> list[int] | None:
        if self.class_id is not None:
            return [self.class_id]
        if self.class_name is not None:
            return [self._class_id_by_name(self.class_name)]
        return None

    def _class_id_by_name(self, class_name: str) -> int:
        names = self._predictor.names
        for class_id, candidate_name in names.items():
            if str(candidate_name).lower() == class_name.lower():
                return int(class_id)
        available = ", ".join(str(name) for _, name in sorted(names.items()))
        raise ValueError(f"Unknown class name {class_name!r}. Available classes: {available}")

    def _class_name(self, class_id: int) -> str | None:
        name = self._predictor.names.get(class_id)
        return None if name is None else str(name)
