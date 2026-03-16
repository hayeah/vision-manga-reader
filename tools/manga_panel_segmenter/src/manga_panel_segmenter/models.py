from __future__ import annotations

import json
from dataclasses import asdict, dataclass, is_dataclass
from pathlib import Path
from typing import Any


class JsonMixin:
    """Mixin to add JSON serialization to dataclasses."""

    def to_dict(self) -> dict[str, Any]:
        if is_dataclass(self):
            return asdict(self)
        return self.__dict__

    def to_json(self, **json_kwargs: Any) -> str:
        return json.dumps(self.to_dict(), **json_kwargs)


@dataclass(slots=True)
class Point(JsonMixin):
    x: int
    y: int

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Point":
        return cls(x=int(data["x"]), y=int(data["y"]))


@dataclass(slots=True)
class BoundingBox(JsonMixin):
    left: int
    top: int
    right: int
    bottom: int

    @property
    def width(self) -> int:
        return max(0, self.right - self.left)

    @property
    def height(self) -> int:
        return max(0, self.bottom - self.top)

    @property
    def center_y(self) -> float:
        return (self.top + self.bottom) / 2

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "BoundingBox":
        return cls(
            left=int(data["left"]),
            top=int(data["top"]),
            right=int(data["right"]),
            bottom=int(data["bottom"]),
        )


@dataclass(slots=True)
class Panel(JsonMixin):
    panel_id: int
    reading_order: int
    score: float
    area_px: int
    class_id: int | None
    class_name: str | None
    bbox: BoundingBox
    polygon: list[Point]

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "Panel":
        return cls(
            panel_id=int(data["panel_id"]),
            reading_order=int(data["reading_order"]),
            score=float(data["score"]),
            area_px=int(data["area_px"]),
            class_id=None if data.get("class_id") is None else int(data["class_id"]),
            class_name=None if data.get("class_name") is None else str(data["class_name"]),
            bbox=BoundingBox.from_dict(data["bbox"]),
            polygon=[Point.from_dict(point) for point in data["polygon"]],
        )


@dataclass(slots=True)
class PageSegmentation(JsonMixin):
    image_path: str
    image_width: int
    image_height: int
    model_repo: str
    model_filename: str
    panels: list[Panel]

    @classmethod
    def create(
        cls,
        image_path: Path,
        image_width: int,
        image_height: int,
        model_repo: str,
        model_filename: str,
        panels: list[Panel],
    ) -> "PageSegmentation":
        return cls(
            image_path=str(image_path),
            image_width=image_width,
            image_height=image_height,
            model_repo=model_repo,
            model_filename=model_filename,
            panels=panels,
        )

    @classmethod
    def from_dict(cls, data: dict[str, Any]) -> "PageSegmentation":
        return cls(
            image_path=str(data["image_path"]),
            image_width=int(data["image_width"]),
            image_height=int(data["image_height"]),
            model_repo=str(data["model_repo"]),
            model_filename=str(data["model_filename"]),
            panels=[Panel.from_dict(panel) for panel in data["panels"]],
        )

    @classmethod
    def from_json_file(cls, path: Path) -> "PageSegmentation":
        return cls.from_dict(json.loads(path.read_text()))
