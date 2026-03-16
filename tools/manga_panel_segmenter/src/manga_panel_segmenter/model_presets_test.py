from manga_panel_segmenter.model_presets import preset_names, resolve_profile


def test_preset_names_include_built_in_models() -> None:
    assert "blindmaster-seg" in preset_names()
    assert "deepghs-frame" in preset_names()
    assert "mosesb-comic" in preset_names()


def test_resolve_profile_uses_preset_defaults() -> None:
    profile = resolve_profile(
        preset="deepghs-frame",
        model_repo=None,
        model_filename=None,
        confidence=None,
        iou=None,
        class_id=None,
        class_name=None,
    )

    assert profile.model_repo == "deepghs/manga109_yolo"
    assert profile.model_filename == "v2023.12.07_s_yv11/model.pt"
    assert profile.class_name == "frame"
