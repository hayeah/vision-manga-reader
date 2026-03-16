from manga_panel_segmenter.models import BoundingBox, PageSegmentation, Panel, Point


def test_page_segmentation_to_dict() -> None:
    page = PageSegmentation(
        image_path="page.png",
        image_width=1200,
        image_height=1800,
        model_repo="repo/model",
        model_filename="best.pt",
        panels=[
            Panel(
                panel_id=0,
                reading_order=1,
                score=0.98,
                area_px=1234,
                class_id=2,
                class_name="frame",
                bbox=BoundingBox(left=10, top=20, right=110, bottom=220),
                polygon=[Point(x=10, y=20), Point(x=110, y=20), Point(x=110, y=220)],
            )
        ],
    )

    data = page.to_dict()

    assert data["image_path"] == "page.png"
    assert data["panels"][0]["class_name"] == "frame"
    assert data["panels"][0]["bbox"]["right"] == 110
    assert data["panels"][0]["polygon"][2]["y"] == 220
