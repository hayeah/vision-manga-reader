"""Master prompts for colorization. Edit these to adjust output quality."""

# Used when a text model (gpt-5, etc.) revises the prompt before image generation.
# Keep simple — the model expands it into detailed instructions.
COLORIZE_PAGE = "Can you colorize this page?"
COLORIZE_PANEL = "Can you colorize this panel?"

# Used when calling the image model directly (--model none).
COLORIZE_PAGE_DIRECT = """\
Colorize this black-and-white manga page, preserving every line, hatch, and texture.
Keep all speech balloons and text untouched.\
"""

COLORIZE_PANEL_DIRECT = """\
Colorize this black-and-white manga panel, preserving every line, hatch, and texture.
Keep all speech balloons and text untouched.\
"""
