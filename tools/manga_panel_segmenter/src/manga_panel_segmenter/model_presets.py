from __future__ import annotations

from dataclasses import dataclass

from .segmenter import DEFAULT_MODEL_FILENAME, DEFAULT_MODEL_REPO


@dataclass(slots=True)
class InferenceProfile:
    name: str
    description: str
    model_repo: str
    model_filename: str
    confidence: float
    iou: float
    class_id: int | None = None
    class_name: str | None = None


PRESET_PROFILES: dict[str, InferenceProfile] = {
    "blindmaster-seg": InferenceProfile(
        name="blindmaster-seg",
        description="YOLOv8 segmentation model trained for manga frame masks.",
        model_repo=DEFAULT_MODEL_REPO,
        model_filename=DEFAULT_MODEL_FILENAME,
        confidence=0.5,
        iou=0.5,
    ),
    "deepghs-frame": InferenceProfile(
        name="deepghs-frame",
        description="Manga109 YOLO detector filtered to the 'frame' class.",
        model_repo="deepghs/manga109_yolo",
        model_filename="v2023.12.07_s_yv11/model.pt",
        confidence=0.383,
        iou=0.5,
        class_name="frame",
    ),
    "mosesb-comic": InferenceProfile(
        name="mosesb-comic",
        description="YOLOv12 comic panel detector trained on a custom comic dataset.",
        model_repo="mosesb/best-comic-panel-detection",
        model_filename="best.pt",
        confidence=0.5,
        iou=0.5,
    ),
}


def available_presets_text() -> str:
    lines = ["Available presets:"]
    for preset in PRESET_PROFILES.values():
        lines.append(f"- {preset.name}: {preset.description}")
    return "\n".join(lines)


def preset_names() -> list[str]:
    return list(PRESET_PROFILES.keys())


def resolve_profile(
    preset: str | None,
    model_repo: str | None,
    model_filename: str | None,
    confidence: float | None,
    iou: float | None,
    class_id: int | None,
    class_name: str | None,
) -> InferenceProfile:
    if preset is None:
        return InferenceProfile(
            name="custom",
            description="Custom model arguments.",
            model_repo=model_repo or DEFAULT_MODEL_REPO,
            model_filename=model_filename or DEFAULT_MODEL_FILENAME,
            confidence=0.25 if confidence is None else confidence,
            iou=0.5 if iou is None else iou,
            class_id=class_id,
            class_name=class_name,
        )

    if preset not in PRESET_PROFILES:
        available = ", ".join(preset_names())
        raise ValueError(f"Unknown preset {preset!r}. Available presets: {available}")

    base = PRESET_PROFILES[preset]
    return InferenceProfile(
        name=base.name,
        description=base.description,
        model_repo=model_repo or base.model_repo,
        model_filename=model_filename or base.model_filename,
        confidence=base.confidence if confidence is None else confidence,
        iou=base.iou if iou is None else iou,
        class_id=base.class_id if class_id is None else class_id,
        class_name=base.class_name if class_name is None else class_name,
    )
