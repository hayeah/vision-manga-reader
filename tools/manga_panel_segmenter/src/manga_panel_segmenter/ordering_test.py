from manga_panel_segmenter.models import BoundingBox
from manga_panel_segmenter.ordering import MangaReadingOrder


def test_manga_reading_order_sorts_top_to_bottom_then_right_to_left() -> None:
    boxes = [
        BoundingBox(left=40, top=40, right=140, bottom=240),
        BoundingBox(left=180, top=30, right=290, bottom=250),
        BoundingBox(left=30, top=280, right=150, bottom=520),
        BoundingBox(left=190, top=300, right=310, bottom=500),
    ]

    indexes = MangaReadingOrder().sort_indexes(boxes)

    assert indexes == [1, 0, 3, 2]


def test_manga_reading_order_keeps_stacked_panels_in_separate_rows() -> None:
    boxes = [
        BoundingBox(left=180, top=40, right=320, bottom=240),
        BoundingBox(left=190, top=280, right=330, bottom=520),
        BoundingBox(left=20, top=40, right=150, bottom=520),
    ]

    indexes = MangaReadingOrder().sort_indexes(boxes)

    assert indexes == [0, 2, 1]
