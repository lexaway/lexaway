"""Compose marketing-ready App Store screenshots from raw captures.

Reads tools/screenshot_config.yaml for screen captions and style,
then overlays a bottom scrim + caption text on each raw PNG.

Supports per-language captions. Raw screenshots are expected at:
  screenshots/raw/{lang}/{device}/01_packs.png
Output goes to:
  screenshots/final/{lang}/{device}/01_packs.png
"""

import argparse
import os
from pathlib import Path

import yaml
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
RAW_DIR = PROJECT_DIR / "screenshots" / "raw"
FINAL_DIR = PROJECT_DIR / "screenshots" / "final"
CONFIG_PATH = SCRIPT_DIR / "screenshot_config.yaml"


def load_config():
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)


def make_scrim_dithered(
    width: int,
    height: int,
    color: tuple,
    max_opacity: float,
    pixel_size: int = 12,
) -> Image.Image:
    """Create a dithered pixel-art scrim using an 8x8 Bayer ordered dithering matrix.

    Each chunky block (pixel_size x pixel_size) is either fully opaque or fully
    transparent, with density increasing toward the bottom — retro game fade style.
    """
    # 8x8 Bayer threshold matrix (normalized to 0..1)
    bayer8 = [
        [ 0, 48, 12, 60,  3, 51, 15, 63],
        [32, 16, 44, 28, 35, 19, 47, 31],
        [ 8, 56,  4, 52, 11, 59,  7, 55],
        [40, 24, 36, 20, 43, 27, 39, 23],
        [ 2, 50, 14, 62,  1, 49, 13, 61],
        [34, 18, 46, 30, 33, 17, 45, 29],
        [10, 58,  6, 54,  9, 57,  5, 53],
        [42, 26, 38, 22, 41, 25, 37, 21],
    ]
    # Normalize to 0..1
    bayer = [[v / 64.0 for v in row] for row in bayer8]

    fill = (*color, int(255 * max_opacity))
    clear = (0, 0, 0, 0)

    # Work at chunky-pixel resolution, then scale up
    cols = (width + pixel_size - 1) // pixel_size
    rows = (height + pixel_size - 1) // pixel_size

    small = Image.new("RGBA", (cols, rows), (0, 0, 0, 0))
    for r in range(rows):
        # t: 0 at top of scrim, 1 at bottom
        t = r / rows
        # Quadratic density curve — sparse at top, dense at bottom
        density = t ** 1.5 * max_opacity
        for c in range(cols):
            threshold = bayer[r % 8][c % 8]
            if density > threshold:
                small.putpixel((c, r), fill)
            else:
                small.putpixel((c, r), clear)

    # Scale up with nearest-neighbor to keep crispy pixels
    return small.resize((width, height), Image.NEAREST)


def hex_to_rgb(hex_color: str) -> tuple:
    h = hex_color.lstrip("#")
    return tuple(int(h[i : i + 2], 16) for i in (0, 2, 4))


def _word_wrap(draw: ImageDraw.ImageDraw, text: str, font, max_width: int) -> str:
    """Break text into lines that fit within max_width pixels."""
    words = text.split()
    lines = []
    current = ""
    for word in words:
        test = f"{current} {word}".strip()
        bbox = draw.textbbox((0, 0), test, font=font)
        if bbox[2] - bbox[0] <= max_width:
            current = test
        else:
            if current:
                lines.append(current)
            current = word
    if current:
        lines.append(current)
    return "\n".join(lines)


def compose_image(
    raw_path: Path,
    output_path: Path,
    caption: str | None,
    style: dict,
    screen_overrides: dict | None = None,
):
    img = Image.open(raw_path).convert("RGBA")
    width, height = img.size

    if caption is None:
        # No scrim, no text — just copy
        img.save(output_path)
        return

    # Per-screen overrides take priority over global style
    ov = screen_overrides or {}
    scrim_color = hex_to_rgb(style["scrim_color"])
    pixel_size = ov.get("dither_pixel_size", style.get("dither_pixel_size", 12))
    solid_ratio = ov.get("solid_ratio", style.get("solid_ratio", 0.35))
    scrim_height = ov.get("scrim_height", style["scrim_height"])
    scrim_h = int(height * scrim_height)
    solid_h = int(scrim_h * solid_ratio)
    dither_h = scrim_h - solid_h

    # Dithered transition zone above the solid band
    dither = make_scrim_dithered(
        width, dither_h, scrim_color, style["scrim_opacity"], pixel_size,
    )
    img.alpha_composite(dither, (0, height - scrim_h))

    # Solid black band at the bottom
    solid_alpha = int(255 * style["scrim_opacity"])
    solid = Image.new("RGBA", (width, solid_h), (*scrim_color, solid_alpha))
    img.alpha_composite(solid, (0, height - solid_h))

    # Draw caption text
    draw = ImageDraw.Draw(img)
    font_path = SCRIPT_DIR / "fonts" / style["font"]

    # Scale font size relative to image width (base: 1290px)
    scale = width / 1290
    font_size = int(style["caption_size"] * scale)

    try:
        font = ImageFont.truetype(str(font_path), font_size)
    except OSError:
        print(f"  Warning: font not found at {font_path}, using default")
        font = ImageFont.load_default()

    caption_color = hex_to_rgb(style["caption_color"])

    # Word-wrap caption if it's too wide (keep 10% margin on each side)
    max_text_w = int(width * 0.80)
    wrapped = _word_wrap(draw, caption, font, max_text_w)

    # Center text block vertically in the solid band
    line_spacing = int(font_size * 0.4)
    bbox = draw.multiline_textbbox((0, 0), wrapped, font=font, align="center", spacing=line_spacing)
    text_w = bbox[2] - bbox[0]
    text_h = bbox[3] - bbox[1]
    text_x = (width - text_w) // 2
    text_y = height - solid_h + (solid_h - text_h) // 2

    draw.multiline_text(
        (text_x, text_y), wrapped,
        fill=(*caption_color, 255), font=font, align="center", spacing=line_spacing,
    )

    img.save(output_path)


def resolve_caption(caption_field, lang: str) -> str | None:
    """Extract caption string for a given language.

    Supports both the old format (plain string) and the new format (dict keyed by lang).
    """
    if caption_field is None:
        return None
    if isinstance(caption_field, str):
        return caption_field
    if isinstance(caption_field, dict):
        return caption_field.get(lang) or caption_field.get("en")
    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", help="Process a single language only")
    args = parser.parse_args()

    config = load_config()
    style = config["style"]
    languages = [args.lang] if args.lang else config.get("languages", ["en"])

    # Build per-screen lookups
    overrides = {s["filename"]: s.get("style", {}) for s in config["screens"]}

    if not RAW_DIR.exists():
        print(f"No raw screenshots found at {RAW_DIR}")
        return

    for lang in languages:
        lang_raw_dir = RAW_DIR / lang
        if not lang_raw_dir.exists():
            print(f"Skipping {lang} — no raw screenshots at {lang_raw_dir}")
            continue

        # Build caption lookup for this language
        captions = {
            s["filename"]: resolve_caption(s.get("caption"), lang)
            for s in config["screens"]
        }

        for device_dir in sorted(lang_raw_dir.iterdir()):
            if not device_dir.is_dir():
                continue

            output_dir = FINAL_DIR / lang / device_dir.name
            output_dir.mkdir(parents=True, exist_ok=True)

            print(f"--- {lang}/{device_dir.name} ---")
            for png in sorted(device_dir.glob("*.png")):
                stem = png.stem
                caption = captions.get(stem)
                output_path = output_dir / png.name

                label = f'"{caption}"' if caption else "(no scrim)"
                print(f"  {png.name} {label}")

                compose_image(png, output_path, caption, style, overrides.get(stem))

    print("Done! Output in screenshots/final/")


if __name__ == "__main__":
    main()
