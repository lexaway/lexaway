#!/usr/bin/env python3
"""Quick visual compositor for the new claw-machine art.

Renders the new pieces onto the clean exterior so we can eyeball layout
BEFORE wiring any of it into Flutter. All positions are knobs below.
Run:  python3 tools/compose_machine.py
Out:  machine_preview.png  (scaled 6x, nearest-neighbour)
"""
from PIL import Image

SRC = "assets/drive-download-20260529T185859Z-3-001"
OUT = "machine_preview.png"
ZOOM = 6  # upscale factor for the preview only

# ---- knobs (logical pixels, machine is 88x136) ---------------------------
GLASS = dict(left=9, top=18, right=78, floor=76)   # measured from the mask
CX = (GLASS["left"] + GLASS["right"]) / 2          # glass center x = 43.5

POS = {
    # claw assembly (inside the glass)
    "hook_base_scale": 0.5,         # file is 2x; bring to native res
    "spool_cx":   CX,
    "spool_top":  GLASS["top"] + 1,
    "arm_drop":   -10,              # how far arm tops sit below the spool bottom
    "arm_spread": 0,                # gap between the two prongs at center
    "arm_angle":  18,               # degrees each prong splays outward (open look)

    # console controls (panel is y 77..132)
    "joystick_cx": 64, "joystick_cy": 86,
    "button_cx":   22, "button_cy":  88,
    "star_cx":     43, "star_cy":    89,
    "door_cx":     43, "door_cy":    118,
}
# --------------------------------------------------------------------------


def load(name):
    return Image.open(f"{SRC}/{name}").convert("RGBA")


def trim(im):
    bbox = im.getbbox()
    return im.crop(bbox) if bbox else im


def cell(sheet, idx, n):
    """idx-th of n equal-width cells, trimmed."""
    w, h = sheet.size
    cw = w // n
    return trim(sheet.crop((idx * cw, 0, (idx + 1) * cw, h)))


def paste_center(base, sprite, cx, cy):
    base.alpha_composite(sprite, (int(cx - sprite.width / 2),
                                  int(cy - sprite.height / 2)))


def paste_top(base, sprite, cx, top):
    base.alpha_composite(sprite, (int(cx - sprite.width / 2), int(top)))


# canvas: light bg so the transparent glass reads clearly
base = Image.new("RGBA", (88, 136), (40, 44, 60, 255))

exterior = load("Big machine clean 88x136.PNG")
base.alpha_composite(exterior, (0, 0))

# --- claw assembly --- (arms render BEHIND the head, like in-game priority)
hb = load("Hook base 36x52.PNG")
hb = trim(hb)
hb = hb.resize((max(1, int(hb.width * POS["hook_base_scale"])),
                max(1, int(hb.height * POS["hook_base_scale"]))), Image.NEAREST)
spool_bottom = POS["spool_top"] + hb.height

hook_r = trim(load("Hook 16x20.PNG"))        # right prong (art in left half)
hook_l = trim(load("Hook left 16x20.PNG"))   # left prong  (art in right half)
ar = hook_r.rotate(-POS["arm_angle"], expand=True, resample=Image.BICUBIC)
al = hook_l.rotate(POS["arm_angle"], expand=True, resample=Image.BICUBIC)
arm_top = spool_bottom + POS["arm_drop"]
paste_top(base, al, POS["spool_cx"] - POS["arm_spread"] - al.width / 2, arm_top)
paste_top(base, ar, POS["spool_cx"] + POS["arm_spread"] + ar.width / 2, arm_top)

# head/spool on top of the arm tops
paste_top(base, hb, POS["spool_cx"], POS["spool_top"])

# --- console controls ---
joy = cell(load("Joy stick 28x20.PNG"), 1, 3)            # center pose
paste_center(base, joy, POS["joystick_cx"], POS["joystick_cy"])

btn = cell(load("Button 16x8.PNG"), 0, 2)                # unpressed
paste_center(base, btn, POS["button_cx"], POS["button_cy"])

star = trim(load("Star 12x12.PNG"))
paste_center(base, star, POS["star_cx"], POS["star_cy"])

door = cell(load("Untitled 05-23-2026 10-52-59.PNG"), 2, 3)  # closed frame
paste_center(base, door, POS["door_cx"], POS["door_cy"])

# --- export ---
big = base.resize((88 * ZOOM, 136 * ZOOM), Image.NEAREST)
big.save(OUT)
print(f"wrote {OUT} ({big.size[0]}x{big.size[1]}); spool_bottom={spool_bottom:.1f}")
