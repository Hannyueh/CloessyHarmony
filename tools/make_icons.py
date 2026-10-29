"""Generate all PNG assets for the Yunmei HarmonyOS app.

Run: python tools/make_icons.py
Everything is rendered at 4x/8x and downsampled for clean edges.
"""
from __future__ import annotations

import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
APP_MEDIA = os.path.join(ROOT, "AppScope", "resources", "base", "media")
ENTRY_MEDIA = os.path.join(ROOT, "entry", "src", "main", "resources", "base", "media")

MINT = (59, 227, 169)
CYAN = (53, 198, 255)
DEEP = (7, 15, 27)
SURFACE = (14, 27, 43)


def linear_gradient(size: int, c1: tuple[int, int, int], c2: tuple[int, int, int], angle: float) -> Image.Image:
    """Smooth linear gradient with the given angle (degrees, 0 = left->right)."""
    xs = np.linspace(0.0, 1.0, size)[None, :]
    ys = np.linspace(0.0, 1.0, size)[:, None]
    rad = math.radians(angle)
    field = xs * math.cos(rad) + ys * math.sin(rad)
    lo, hi = float(field.min()), float(field.max())
    t = (field - lo) / max(hi - lo, 1e-6)
    arr = np.zeros((size, size, 4), dtype=np.float32)
    for i in range(3):
        arr[:, :, i] = c1[i] + (c2[i] - c1[i]) * t
    arr[:, :, 3] = 255.0
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def radial_glow(size: int, color: tuple[int, int, int], cx: float, cy: float, radius: float, strength: float) -> Image.Image:
    xs = np.linspace(0.0, 1.0, size)[None, :]
    ys = np.linspace(0.0, 1.0, size)[:, None]
    dist = np.sqrt((xs - cx) ** 2 + (ys - cy) ** 2) / max(radius, 1e-6)
    falloff = np.clip(1.0 - dist, 0.0, 1.0) ** 2 * strength
    arr = np.zeros((size, size, 4), dtype=np.float32)
    for i in range(3):
        arr[:, :, i] = color[i]
    arr[:, :, 3] = falloff * 255.0
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def _caps(draw: ImageDraw.ImageDraw, points, radius: float, color) -> None:
    for px, py in points:
        draw.ellipse((px - radius, py - radius, px + radius, py + radius), fill=color)


def draw_lock(draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], color, open_shackle: bool, scale: float = 1.0, width: float | None = None) -> None:
    """Stylized padlock glyph inside box (x0, y0, x1, y1). Solid fill, round caps."""
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    body_w = w * 0.76
    body_h = h * 0.44
    bx0 = x0 + (w - body_w) / 2
    by0 = y1 - body_h
    radius = body_h * 0.30
    draw.rounded_rectangle((bx0, by0, bx0 + body_w, y1), radius=radius, fill=color)

    sw = width if width is not None else w * 0.105
    swi = max(2, int(round(sw)))
    cx = x0 + w / 2
    shackle_r = w * 0.255
    cy = y0 + shackle_r + sw / 2
    # open lock lifts the shackle and shifts it slightly to the right
    scx = cx + (w * 0.055 if open_shackle else 0.0)
    top_y = cy - shackle_r
    bbox = (scx - shackle_r, top_y, scx + shackle_r, cy + shackle_r)
    draw.arc(bbox, start=180, end=360, fill=color, width=swi)

    left_x = scx - shackle_r
    right_x = scx + shackle_r
    # legs
    if open_shackle:
        left_bottom = by0 + body_h * 0.22
        draw.line((left_x, cy, left_x, left_bottom), fill=color, width=swi)
        right_bottom = cy + shackle_r * 0.42
        draw.line((right_x, cy, right_x, right_bottom), fill=color, width=swi)
        _caps(draw, [(left_x, cy), (right_x, cy), (left_x, left_bottom), (right_x, right_bottom)], sw / 2, color)
    else:
        leg_bottom = by0 + body_h * 0.20
        draw.line((left_x, cy, left_x, leg_bottom), fill=color, width=swi)
        draw.line((right_x, cy, right_x, leg_bottom), fill=color, width=swi)
        _caps(draw, [(left_x, cy), (right_x, cy), (left_x, leg_bottom), (right_x, leg_bottom)], sw / 2, color)


def draw_keyhole(mask_draw: ImageDraw.ImageDraw, box: tuple[float, float, float, float], scale: float = 1.0) -> None:
    x0, y0, x1, y1 = box
    w = x1 - x0
    h = y1 - y0
    body_h = h * 0.44
    cy = y1 - body_h * 0.52
    r = w * 0.068 * scale
    cx = x0 + w / 2
    mask_draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=255)
    mask_draw.rounded_rectangle((cx - r * 0.38, cy, cx + r * 0.38, cy + body_h * 0.26), radius=r * 0.34, fill=255)


def make_app_icon(size: int = 512) -> Image.Image:
    ss = 4
    s = size * ss
    bg = linear_gradient(s, (10, 22, 38), (17, 48, 61), 135)
    glow = radial_glow(s, MINT, 0.18, 0.12, 0.85, 0.55)
    glow2 = radial_glow(s, CYAN, 0.9, 0.95, 0.7, 0.35)
    bg = Image.alpha_composite(bg, glow)
    bg = Image.alpha_composite(bg, glow2)

    # concentric decorative rings
    ring_layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ring_layer)
    for i, r in enumerate((0.62, 0.74, 0.86)):
        box = (s * (0.5 - r / 2), s * (0.5 - r / 2), s * (0.5 + r / 2), s * (0.5 + r / 2))
        rd.ellipse(box, outline=(255, 255, 255, 14 + i * 4), width=max(1, int(s * 0.0015)))
    bg = Image.alpha_composite(bg, ring_layer)

    glyph = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glyph)
    pad = s * 0.24
    box = (pad, pad * 0.9, s - pad, s - pad * 1.05)
    # gradient glyph: draw lock as mask then paste gradient
    mask = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(mask)
    draw_lock(md, box, 255, True)
    draw_keyhole(md, box, 1.0)
    # keyhole should be transparent -> draw keyhole in inverse
    key_mask = Image.new("L", (s, s), 0)
    kd = ImageDraw.Draw(key_mask)
    draw_keyhole(kd, box, 1.0)
    mask = Image.composite(Image.new("L", (s, s), 0), mask, key_mask)

    grad = linear_gradient(s, MINT, CYAN, 120)
    glyph = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    glyph.paste(grad, (0, 0), mask)

    # soft shadow under glyph
    shadow = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    draw_lock(sd, box, (0, 0, 0, 110), True)
    shadow = shadow.filter(ImageFilter.GaussianBlur(s * 0.02))
    bg = Image.alpha_composite(bg, shadow)
    bg = Image.alpha_composite(bg, glyph)

    out = bg.resize((size, size), Image.LANCZOS)
    out.putalpha(rounded_mask(size, int(size * 0.23)))
    return out


def make_layers(size: int = 1024) -> tuple[Image.Image, Image.Image]:
    ss = 2
    s = size * ss
    bg = linear_gradient(s, (9, 20, 34), (17, 46, 60), 135)
    bg = Image.alpha_composite(bg, radial_glow(s, MINT, 0.2, 0.15, 0.9, 0.5))
    bg = Image.alpha_composite(bg, radial_glow(s, CYAN, 0.85, 0.9, 0.8, 0.3))
    background = bg.resize((size, size), Image.LANCZOS)

    fg = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    box = (s * 0.32, s * 0.30, s * 0.68, s * 0.70)
    mask = Image.new("L", (s, s), 0)
    md = ImageDraw.Draw(mask)
    draw_lock(md, box, 255, True)
    key_mask = Image.new("L", (s, s), 0)
    kd = ImageDraw.Draw(key_mask)
    draw_keyhole(kd, box, 1.0)
    mask = Image.composite(Image.new("L", (s, s), 0), mask, key_mask)
    grad = linear_gradient(s, MINT, CYAN, 120)
    fg.paste(grad, (0, 0), mask)
    foreground = fg.resize((size, size), Image.LANCZOS)
    return background, foreground


def make_glyph(size: int, kind: str, color=(255, 255, 255, 242)) -> Image.Image:
    ss = 8
    s = size * ss
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    pad = s * 0.13
    box = (pad, pad, s - pad, s - pad)

    if kind in ("lock_open", "lock_closed"):
        mask = Image.new("L", (s, s), 0)
        md = ImageDraw.Draw(mask)
        draw_lock(md, box, 255, kind == "lock_open")
        key_mask = Image.new("L", (s, s), 0)
        kd = ImageDraw.Draw(key_mask)
        draw_keyhole(kd, box, 1.0)
        mask = Image.composite(Image.new("L", (s, s), 0), mask, key_mask)
        img.paste(Image.new("RGBA", (s, s), color), (0, 0), mask)
    elif kind == "person":
        r = s * 0.17
        cx, cy = s / 2, s * 0.36
        d.ellipse((cx - r, cy - r, cx + r, cy + r), outline=color, width=int(s * 0.055))
        d.arc((s * 0.24, s * 0.52, s * 0.76, s * 0.92), start=200, end=340, fill=color, width=int(s * 0.055))
    elif kind == "key":
        d.ellipse((s * 0.16, s * 0.34, s * 0.44, s * 0.62), outline=color, width=int(s * 0.055))
        d.line((s * 0.40, s * 0.55, s * 0.80, s * 0.86), fill=color, width=int(s * 0.055))
        d.line((s * 0.64, s * 0.72, s * 0.74, s * 0.60), fill=color, width=int(s * 0.05))
    elif kind == "settings":
        for i, y in enumerate((0.30, 0.50, 0.70)):
            d.line((s * 0.16, s * y, s * 0.84, s * y), fill=color, width=int(s * 0.045))
            kx = s * (0.38 if i == 0 else 0.62 if i == 1 else 0.44)
            r = s * 0.065
            d.ellipse((kx - r, s * y - r, kx + r, s * y + r), fill=color)
    elif kind == "refresh":
        d.arc((s * 0.18, s * 0.18, s * 0.82, s * 0.82), start=40, end=320, fill=color, width=int(s * 0.06))
        d.polygon([(s * 0.80, s * 0.20), (s * 0.88, s * 0.40), (s * 0.67, s * 0.38)], fill=color)
    elif kind == "chevron":
        d.line((s * 0.40, s * 0.24, s * 0.66, s * 0.50), fill=color, width=int(s * 0.07))
        d.line((s * 0.66, s * 0.50, s * 0.40, s * 0.76), fill=color, width=int(s * 0.07))
    elif kind == "close":
        d.line((s * 0.28, s * 0.28, s * 0.72, s * 0.72), fill=color, width=int(s * 0.06))
        d.line((s * 0.72, s * 0.28, s * 0.28, s * 0.72), fill=color, width=int(s * 0.06))
    elif kind == "check":
        d.line((s * 0.22, s * 0.52, s * 0.43, s * 0.72), fill=color, width=int(s * 0.08))
        d.line((s * 0.43, s * 0.72, s * 0.78, s * 0.30), fill=color, width=int(s * 0.08))
    elif kind == "alert":
        d.ellipse((s * 0.16, s * 0.16, s * 0.84, s * 0.84), outline=color, width=int(s * 0.055))
        d.line((s * 0.5, s * 0.30, s * 0.5, s * 0.58), fill=color, width=int(s * 0.07))
        d.ellipse((s * 0.455, s * 0.66, s * 0.545, s * 0.75), fill=color)
    elif kind == "logout":
        d.arc((s * 0.18, s * 0.20, s * 0.62, s * 0.80), start=90, end=270, fill=color, width=int(s * 0.055))
        d.line((s * 0.40, s * 0.22, s * 0.78, s * 0.22), fill=color, width=int(s * 0.055))
        d.line((s * 0.40, s * 0.78, s * 0.78, s * 0.78), fill=color, width=int(s * 0.055))
        d.line((s * 0.52, s * 0.50, s * 0.86, s * 0.50), fill=color, width=int(s * 0.055))
        d.polygon([(s * 0.78, s * 0.40), (s * 0.90, s * 0.50), (s * 0.78, s * 0.60)], fill=color)
    elif kind == "bluetooth":
        d.line((s * 0.50, s * 0.14, s * 0.72, s * 0.34), fill=color, width=int(s * 0.055))
        d.line((s * 0.72, s * 0.34, s * 0.30, s * 0.68), fill=color, width=int(s * 0.055))
        d.line((s * 0.50, s * 0.86, s * 0.72, s * 0.66), fill=color, width=int(s * 0.055))
        d.line((s * 0.72, s * 0.66, s * 0.30, s * 0.32), fill=color, width=int(s * 0.055))
        d.line((s * 0.50, s * 0.14, s * 0.50, s * 0.86), fill=color, width=int(s * 0.055))
    elif kind == "building":
        d.rounded_rectangle((s * 0.22, s * 0.20, s * 0.78, s * 0.82), radius=s * 0.06, outline=color, width=int(s * 0.05))
        for yy in (0.36, 0.50, 0.64):
            d.line((s * 0.34, s * yy, s * 0.66, s * yy), fill=color, width=int(s * 0.04))
    elif kind == "door":
        d.rounded_rectangle((s * 0.28, s * 0.16, s * 0.72, s * 0.84), radius=s * 0.05, outline=color, width=int(s * 0.055))
        d.ellipse((s * 0.60, s * 0.47, s * 0.66, s * 0.53), fill=color)
    elif kind == "spark":
        d.ellipse((s * 0.30, s * 0.30, s * 0.70, s * 0.70), fill=color)
    else:
        raise ValueError(kind)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    os.makedirs(APP_MEDIA, exist_ok=True)
    os.makedirs(ENTRY_MEDIA, exist_ok=True)

    app_icon = make_app_icon(512)
    app_icon.save(os.path.join(APP_MEDIA, "app_icon.png"))
    background, foreground = make_layers(1024)
    background.save(os.path.join(APP_MEDIA, "background.png"))
    foreground.save(os.path.join(APP_MEDIA, "foreground.png"))
    # start window icon
    app_icon.resize((288, 288), Image.LANCZOS).save(os.path.join(ENTRY_MEDIA, "startIcon.png"))

    glyphs = {
        "ic_lock_open": "lock_open",
        "ic_lock_closed": "lock_closed",
        "ic_person": "person",
        "ic_key": "key",
        "ic_settings": "settings",
        "ic_refresh": "refresh",
        "ic_chevron": "chevron",
        "ic_close": "close",
        "ic_check": "check",
        "ic_alert": "alert",
        "ic_logout": "logout",
        "ic_bluetooth": "bluetooth",
        "ic_building": "building",
        "ic_door": "door",
    }
    for name, kind in glyphs.items():
        make_glyph(96, kind).save(os.path.join(ENTRY_MEDIA, name + ".png"))
    # mint accent variants used on the card / unlock button
    for name, kind in (("ic_lock_open_mint", "lock_open"), ("ic_lock_closed_mint", "lock_closed")):
        make_glyph(96, kind, (59, 227, 169, 255)).save(os.path.join(ENTRY_MEDIA, name + ".png"))
    # deep navy glyph used inside light accent circles
    make_glyph(96, "lock_open", (8, 20, 32, 255)).save(os.path.join(ENTRY_MEDIA, "ic_lock_open_deep.png"))
    make_glyph(96, "door", (8, 20, 32, 255)).save(os.path.join(ENTRY_MEDIA, "ic_door_deep.png"))

    # Light-theme variants: ink for primary UI, gray for inactive tabs,
    # emerald for the active tab and accent states.
    ink = (16, 24, 40, 255)
    gray = (102, 112, 133, 255)
    emerald = (14, 164, 122, 255)
    for name, kind in glyphs.items():
        make_glyph(96, kind, ink).save(os.path.join(ENTRY_MEDIA, name + "_ink.png"))
        make_glyph(96, kind, gray).save(os.path.join(ENTRY_MEDIA, name + "_gray.png"))
    for name, kind in (("ic_lock_open", "lock_open"), ("ic_person", "person"),
                       ("ic_settings", "settings"), ("ic_door", "door"),
                       ("ic_refresh", "refresh"), ("ic_check", "check")):
        make_glyph(96, kind, emerald).save(os.path.join(ENTRY_MEDIA, name + "_emerald.png"))

    print("icons written")


if __name__ == "__main__":
    main()
