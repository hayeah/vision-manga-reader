from pathlib import Path

import cv2
import numpy as np

from manga_panel_segmenter.models import BoundingBox, PageSegmentation, Panel, Point
from manga_panel_segmenter.render import OverlayStyle, PanelRenderer


def test_page_segmentation_from_json_file(tmp_path: Path) -> None:
    payload = {
        "image_path": "page.jpg",
        "image_width": 100,
        "image_height": 200,
        "model_repo": "repo/model",
        "model_filename": "best.pt",
        "panels": [
            {
                "panel_id": 1,
                "reading_order": 2,
                "score": 0.8,
                "area_px": 1000,
                "class_id": 2,
                "class_name": "frame",
                "bbox": {"left": 10, "top": 20, "right": 40, "bottom": 80},
                "polygon": [{"x": 10, "y": 20}, {"x": 40, "y": 20}, {"x": 40, "y": 80}],
            }
        ],
    }
    json_path = tmp_path / "panels.json"
    json_path.write_text(__import__("json").dumps(payload))

    page = PageSegmentation.from_json_file(json_path)

    assert page.image_width == 100
    assert page.panels[0].class_name == "frame"
    assert page.panels[0].bbox.bottom == 80
    assert page.panels[0].polygon[2].x == 40


def test_panel_renderer_writes_overlay(tmp_path: Path) -> None:
    image_path = tmp_path / "page.png"
    image = np.full((120, 120, 3), 255, dtype=np.uint8)
    cv2.imwrite(str(image_path), image)

    page = PageSegmentation(
        image_path=str(image_path),
        image_width=120,
        image_height=120,
        model_repo="repo/model",
        model_filename="best.pt",
        panels=[
            Panel(
                panel_id=1,
                reading_order=1,
                score=0.9,
                area_px=6400,
                class_id=2,
                class_name="frame",
                bbox=BoundingBox(left=20, top=20, right=100, bottom=100),
                polygon=[
                    Point(x=20, y=20),
                    Point(x=100, y=20),
                    Point(x=100, y=100),
                    Point(x=20, y=100),
                ],
            )
        ],
    )

    output_path = tmp_path / "overlay.png"
    renderer = PanelRenderer(style=OverlayStyle(show_labels=False, show_bbox=True))

    renderer.write_overlay(image_path=image_path, page=page, output_path=output_path)

    rendered = cv2.imread(str(output_path), cv2.IMREAD_COLOR)
    assert rendered is not None
    assert rendered.shape == image.shape
    assert not np.array_equal(rendered, image)
