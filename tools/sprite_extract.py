#!/usr/bin/env python3
"""
Sprite Extractor — detects sprites on a tile grid and outputs:
  1. A composite preview image (sprites blown up and labeled) for visual review
  2. A draft JSON in the entities format used by Lexaway

Usage:
    python sprite_extract.py <spritesheet.png> [options]

Options:
    --tile-size N       Tile size in pixels (default: 16)
    --scale N           Preview scale factor (default: 6)
    --output-dir DIR    Where to write output (default: same dir as input)
    --padding N         Padding between preview sprites in pixels (default: 16)
"""

import argparse
import json
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("Pillow is required: pip install Pillow", file=sys.stderr)
    sys.exit(1)


def find_non_empty_tiles(img, tile_size):
    """Return set of (col, row) tiles that contain at least one non-transparent pixel."""
    width, height = img.size
    cols = width // tile_size
    rows = height // tile_size
    occupied = set()

    pixels = img.load()
    for row in range(rows):
        for col in range(cols):
            x0 = col * tile_size
            y0 = row * tile_size
            for y in range(y0, min(y0 + tile_size, height)):
                for x in range(x0, min(x0 + tile_size, width)):
                    pixel = pixels[x, y]
                    if len(pixel) >= 4 and pixel[3] > 0:
                        occupied.add((col, row))
                        break
                else:
                    continue
                break

    return occupied


def find_connected_sprites(occupied_tiles):
    """Group adjacent occupied tiles into sprites using flood fill."""
    remaining = set(occupied_tiles)
    sprites = []

    while remaining:
        seed = min(remaining)  # deterministic: top-left first
        group = set()
        stack = [seed]
        while stack:
            tile = stack.pop()
            if tile in remaining:
                remaining.discard(tile)
                group.add(tile)
                col, row = tile
                for dc, dr in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    neighbor = (col + dc, row + dr)
                    if neighbor in remaining:
                        stack.append(neighbor)
        sprites.append(group)

    return sprites


def split_sparse_components(groups, density_threshold=0.5):
    """Split connected components along low-density tile columns and rows.

    Sprite sheets sometimes have labels or annotations that bridge otherwise
    separate sprites. This finds columns/rows within each component's bounding
    box where fewer than `density_threshold` fraction of tiles are occupied,
    and splits along those gaps.
    """
    result = []
    for group in groups:
        split = _try_split(group, density_threshold)
        result.extend(split)
    return result


def _try_split(tiles, threshold):
    """Recursively split a tile group along sparse columns, then sparse rows."""
    if len(tiles) <= 1:
        return [tiles]

    min_col, min_row, max_col, max_row = sprite_bounds(tiles)
    w = max_col - min_col + 1
    h = max_row - min_row + 1

    if w >= 3:  # need at least 3 cols to have an interior split
        for col in range(min_col + 1, max_col):
            col_count = sum(1 for (c, r) in tiles if c == col)
            if col_count / h < threshold:
                left = {(c, r) for (c, r) in tiles if c < col}
                right = {(c, r) for (c, r) in tiles if c > col}
                # Tiles in the split column go to whichever side they're closer to
                # (or get dropped — they're sparse noise like text)
                pieces = []
                if left:
                    pieces.extend(_try_split(left, threshold))
                if right:
                    pieces.extend(_try_split(right, threshold))
                if pieces:
                    return pieces

    if h >= 3:
        for row in range(min_row + 1, max_row):
            row_count = sum(1 for (c, r) in tiles if r == row)
            if row_count / w < threshold:
                top = {(c, r) for (c, r) in tiles if r < row}
                bottom = {(c, r) for (c, r) in tiles if r > row}
                pieces = []
                if top:
                    pieces.extend(_try_split(top, threshold))
                if bottom:
                    pieces.extend(_try_split(bottom, threshold))
                if pieces:
                    return pieces

    return [tiles]


def sprite_bounds(tiles):
    """Return (min_col, min_row, max_col, max_row) for a set of tiles."""
    cols = [t[0] for t in tiles]
    rows = [t[1] for t in tiles]
    return min(cols), min(rows), max(cols), max(rows)


def extract_sprites(img, tile_size, density_threshold=0.5, min_tiles=1,
                     crop_region=None):
    """Detect sprites and return list of dicts sorted top-left to bottom-right.

    crop_region: optional (col, row, w_tiles, h_tiles) to restrict detection
                 to a sub-region of the sheet. Coordinates in the output are
                 still relative to the full sheet.
    """
    occupied = find_non_empty_tiles(img, tile_size)

    if crop_region:
        cc, cr, cw, ch = crop_region
        occupied = {
            (c, r) for (c, r) in occupied
            if cc <= c < cc + cw and cr <= r < cr + ch
        }

    groups = find_connected_sprites(occupied)
    groups = split_sparse_components(groups, density_threshold)

    groups = [g for g in groups if len(g) >= min_tiles]

    sprites = []
    for i, group in enumerate(groups):
        min_col, min_row, max_col, max_row = sprite_bounds(group)
        w_tiles = max_col - min_col + 1
        h_tiles = max_row - min_row + 1
        sprites.append({
            "name": f"sprite_{i}",
            "col": min_col,
            "row": min_row,
            "widthTiles": w_tiles,
            "heightTiles": h_tiles,
            "src": [min_col * tile_size, min_row * tile_size],
            "size": [w_tiles * tile_size, h_tiles * tile_size],
        })

    # Sort top-to-bottom, then left-to-right, then renumber.
    sprites.sort(key=lambda s: (s["row"], s["col"]))
    for i, s in enumerate(sprites):
        s["name"] = f"sprite_{i}"

    return sprites


def crop_sprite(img, sprite, tile_size):
    """Crop a sprite region from the source image."""
    x = sprite["src"][0]
    y = sprite["src"][1]
    w = sprite["size"][0]
    h = sprite["size"][1]
    return img.crop((x, y, x + w, y + h))


def build_preview(img, sprites, tile_size, scale, padding):
    """Build a composite preview image with labeled, scaled-up sprites."""
    if not sprites:
        return Image.new("RGBA", (100, 100), (0, 0, 0, 0))

    crops = []
    for s in sprites:
        cropped = crop_sprite(img, s, tile_size)
        scaled = cropped.resize(
            (cropped.width * scale, cropped.height * scale),
            Image.NEAREST,
        )
        crops.append(scaled)

    # Lay out in a grid — aim for roughly square
    n = len(crops)
    cols = max(1, int(n ** 0.5))
    if cols * cols < n:
        cols += 1
    rows_needed = (n + cols - 1) // cols

    label_height = 24
    cell_widths = [0] * cols
    cell_heights = [0] * rows_needed

    for i, crop in enumerate(crops):
        c = i % cols
        r = i // cols
        cell_widths[c] = max(cell_widths[c], crop.width)
        cell_heights[r] = max(cell_heights[r], crop.height + label_height)

    total_w = sum(cell_widths) + padding * (cols + 1)
    total_h = sum(cell_heights) + padding * (rows_needed + 1)

    preview = Image.new("RGBA", (total_w, total_h), (40, 40, 40, 255))
    draw = ImageDraw.Draw(preview)

    try:
        font = ImageFont.truetype("/System/Library/Fonts/Menlo.ttc", 14)
    except (OSError, IOError):
        font = ImageFont.load_default()

    y_offset = padding
    for r in range(rows_needed):
        x_offset = padding
        for c in range(cols):
            idx = r * cols + c
            if idx >= n:
                break
            crop = crops[idx]
            sprite = sprites[idx]

            # Draw checkerboard background for transparency
            checker_size = max(4, scale * 2)
            for cy in range(0, crop.height, checker_size):
                for cx in range(0, crop.width, checker_size):
                    is_light = ((cx // checker_size) + (cy // checker_size)) % 2 == 0
                    color = (70, 70, 70, 255) if is_light else (50, 50, 50, 255)
                    draw.rectangle(
                        [x_offset + cx, y_offset + cy,
                         x_offset + min(cx + checker_size, crop.width) - 1,
                         y_offset + min(cy + checker_size, crop.height) - 1],
                        fill=color,
                    )

            preview.paste(crop, (x_offset, y_offset), crop)

            label = f"{sprite['name']} ({sprite['widthTiles']}x{sprite['heightTiles']})"
            draw.text(
                (x_offset, y_offset + crop.height + 4),
                label,
                fill=(200, 200, 200, 255),
                font=font,
            )

            x_offset += cell_widths[c] + padding
        y_offset += cell_heights[r] + padding

    return preview


def build_json(source_name, tile_size, sprites):
    """Build the entity JSON structure."""
    entities = {}
    for s in sprites:
        entities[s["name"]] = {
            "col": s["col"],
            "row": s["row"],
            "widthTiles": s["widthTiles"],
            "heightTiles": s["heightTiles"],
            "src": s["src"],
            "size": s["size"],
        }

    return {
        "source": source_name,
        "tileSize": tile_size,
        "entities": entities,
    }


def main():
    parser = argparse.ArgumentParser(description="Extract sprites from a tile-based sprite sheet")
    parser.add_argument("spritesheet", help="Path to the sprite sheet PNG")
    parser.add_argument("--tile-size", type=int, default=16, help="Tile size in pixels (default: 16)")
    parser.add_argument("--scale", type=int, default=6, help="Preview scale factor (default: 6)")
    parser.add_argument("--output-dir", help="Output directory (default: same as input)")
    parser.add_argument("--padding", type=int, default=16, help="Preview padding (default: 16)")
    parser.add_argument("--density", type=float, default=0.5, help="Split threshold: columns/rows below this density get split (default: 0.5)")
    parser.add_argument("--min-tiles", type=int, default=1, help="Discard sprites smaller than N tiles (default: 1)")
    parser.add_argument("--crop", help="Restrict detection to a tile region: col,row,w,h (e.g. 12,5,3,4)")
    args = parser.parse_args()

    input_path = Path(args.spritesheet)
    if not input_path.exists():
        print(f"File not found: {input_path}", file=sys.stderr)
        sys.exit(1)

    output_dir = Path(args.output_dir) if args.output_dir else input_path.parent
    output_dir.mkdir(parents=True, exist_ok=True)

    stem = input_path.stem

    crop_region = None
    if args.crop:
        parts = [int(x) for x in args.crop.split(",")]
        if len(parts) != 4:
            print("--crop requires exactly 4 values: col,row,w,h", file=sys.stderr)
            sys.exit(1)
        crop_region = tuple(parts)

    img = Image.open(input_path).convert("RGBA")
    print(f"Loaded {input_path.name}: {img.width}x{img.height} ({img.width // args.tile_size}x{img.height // args.tile_size} tiles)")
    if crop_region:
        print(f"Cropping to tile region: col={crop_region[0]} row={crop_region[1]} {crop_region[2]}x{crop_region[3]} tiles")

    sprites = extract_sprites(img, args.tile_size, args.density, args.min_tiles,
                              crop_region)
    print(f"Found {len(sprites)} sprites:")
    for s in sprites:
        print(f"  {s['name']}: col={s['col']} row={s['row']} size={s['widthTiles']}x{s['heightTiles']} tiles")

    # Write preview
    preview = build_preview(img, sprites, args.tile_size, args.scale, args.padding)
    preview_path = output_dir / f"{stem}_preview.png"
    preview.save(preview_path)
    print(f"\nPreview saved: {preview_path}")

    # Write draft JSON
    data = build_json(input_path.name, args.tile_size, sprites)
    json_path = output_dir / f"{stem}_draft.json"
    json_path.write_text(json.dumps(data, indent=2) + "\n")
    print(f"Draft JSON saved: {json_path}")


if __name__ == "__main__":
    main()
