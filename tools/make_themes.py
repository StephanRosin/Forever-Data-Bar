#!/usr/bin/env python3
"""Writes the theme textures the addon ships (Media/Themes/*.tga).
Needs Pillow and numpy.

Per theme (Themes.lua; the same as Forever Unit Frames'):
* <Name>Back.tga, 128 x 128, tiles seamlessly: the frame's backdrop.
* <Name>Bar.tga, 256 x 32: the bar texture. Kept light (white to grey):
  the client multiplies it with the bar colour.
Ornaments, 32 x 32, drawn for the top-left corner (the addon mirrors them):
* Rivet.tga (wood), Bracket.tga (tech), Rune.tga (runestone, white:
  tinted), Seal.tga (parchment).

Run from the repository root:  python3 tools/make_themes.py
The output is deterministic; re-running it must not change the files.
"""
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join("Media", "Themes")
TILE = 128
BAR_W, BAR_H = 256, 32
ORN = 32


def save(img, name):
    img.save(os.path.join(OUT, name))


def tiled_blur(arr, radius):
    """Blurs a 2-D array as if it repeated in both directions (stays tileable)."""
    h, w = arr.shape
    big = np.tile(arr, (3, 3))
    img = Image.fromarray(np.clip(big * 255, 0, 255).astype(np.uint8))
    img = img.filter(ImageFilter.GaussianBlur(radius))
    out = np.asarray(img, dtype=np.float64)[h:2 * h, w:2 * w] / 255
    return out


def noise(rng, radius, size=TILE):
    n = tiled_blur(rng.random((size, size)), radius)
    return (n - n.min()) / max(n.max() - n.min(), 1e-9)


def rgba(r, g, b, a=None):
    if a is None:
        a = np.ones_like(r)
    stack = np.stack([r, g, b, a], axis=-1)
    return Image.fromarray(np.clip(stack * 255, 0, 255).astype(np.uint8), "RGBA")


def mix(c1, c2, t):
    return [c1[i] + (c2[i] - c1[i]) * t for i in range(3)]


# Backdrops ------------------------------------------------------------------

def wood(rng):
    y, x = np.mgrid[0:TILE, 0:TILE] / TILE
    warp = noise(rng, 12)
    grain = np.sin((y + warp * 0.06) * 2 * np.pi * 7) * 0.5 + 0.5
    # Streaks along the board: one random value per row, barely blurred.
    rows = np.repeat(rng.random(TILE)[:, None], TILE, axis=1)
    fine = tiled_blur(rows * 0.7 + rng.random((TILE, TILE)) * 0.3, 0.8)
    t = grain * 0.45 + fine * 0.4 + noise(rng, 6) * 0.15
    c = mix((0.36, 0.21, 0.10), (0.62, 0.40, 0.21), t)
    return rgba(*c)


def tech(rng):
    y, x = np.mgrid[0:TILE, 0:TILE]
    base = 0.04 + noise(rng, 20) * 0.03
    line = ((x % 32 == 0) | (y % 32 == 0)).astype(float)
    r = base * 0.6 + line * 0.06
    g = base * 1.4 + line * 0.20
    b = base * 2.0 + line * 0.22
    return rgba(r, g, b)


def parchment(rng):
    t = noise(rng, 14) * 0.6 + noise(rng, 2) * 0.25 + noise(rng, 0.8) * 0.15
    spots = np.clip(noise(rng, 5) - 0.75, 0, 1) * 1.5
    c = mix((0.80, 0.69, 0.48), (0.95, 0.89, 0.74), t - spots)
    return rgba(*c)


def stone(rng):
    t = noise(rng, 8) * 0.45 + noise(rng, 1.0) * 0.4 + noise(rng, 3) * 0.15
    speck = (rng.random((TILE, TILE)) > 0.985) * 0.25
    c = mix((0.25, 0.25, 0.27), (0.46, 0.46, 0.49), t + speck)
    return rgba(*c)


GLASS = [(0.12, 0.23, 0.36), (0.35, 0.10, 0.16), (0.17, 0.29, 0.20), (0.29, 0.16, 0.37), (0.45, 0.30, 0.10)]


def glass(rng):
    # Voronoi panes on a torus (tileable), dark lead between them.
    pts = rng.random((9, 2)) * TILE
    y, x = np.mgrid[0:TILE, 0:TILE]
    d = []
    for px, py in pts:
        dx = np.abs(x - px)
        dy = np.abs(y - py)
        dx = np.minimum(dx, TILE - dx)
        dy = np.minimum(dy, TILE - dy)
        d.append(np.hypot(dx, dy))
    d = np.stack(d)
    order = np.sort(d, axis=0)
    owner = np.argmin(d, axis=0)
    edge = (order[1] - order[0]) < 2.2
    shade = noise(rng, 6) * 0.25
    out = np.zeros((TILE, TILE, 3))
    for i in range(len(pts)):
        col = np.array(GLASS[i % len(GLASS)])
        mask = owner == i
        out[mask] = col * (0.85 + shade[mask][:, None])
    out[edge] = (0.06, 0.05, 0.04)
    return rgba(out[..., 0], out[..., 1], out[..., 2])


def comic(rng):
    y, x = np.mgrid[0:TILE, 0:TILE]
    cx = (x % 8) - 3.5
    cy = (y % 8) - 3.5
    dot = (np.hypot(cx, cy) < 1.3).astype(float)
    base = np.ones((TILE, TILE))
    r = base * 1.0 - dot * 0.10
    g = base * 0.97 - dot * 0.10
    b = base * 0.90 - dot * 0.10
    return rgba(r, g, b)


def frost(rng):
    t = noise(rng, 16) * 0.7 + noise(rng, 2) * 0.3
    img = rgba(*mix((0.30, 0.50, 0.68), (0.62, 0.80, 0.93), t))
    draw = ImageDraw.Draw(img)
    # Cracks: short jagged lines, wrapped so the tile stays seamless.
    for _ in range(5):
        x, y = rng.random(2) * TILE
        for _ in range(6):
            nx = x + rng.uniform(-14, 14)
            ny = y + rng.uniform(-14, 14)
            for ox in (-TILE, 0, TILE):
                for oy in (-TILE, 0, TILE):
                    draw.line([(x + ox, y + oy), (nx + ox, ny + oy)], fill=(232, 248, 255, 255), width=1)
            x, y = nx, ny
    return img


def pixel(rng):
    y, x = np.mgrid[0:TILE, 0:TILE]
    scan = (y % 4 < 2).astype(float)
    r = 0.05 + scan * 0.03
    g = 0.08 + scan * 0.04
    b = 0.19 + scan * 0.08
    return rgba(r, g, b)


# Bars -----------------------------------------------------------------------

def bar_from(v):
    """A luminance array (BAR_H x BAR_W) as an opaque grey bar."""
    return rgba(v, v, v)


def vertical(profile):
    rows = np.array([profile(i / (BAR_H - 1)) for i in range(BAR_H)])
    return np.repeat(rows[:, None], BAR_W, axis=1)


def wood_bar(rng):
    v = vertical(lambda t: 1.0 - 0.45 * t if t > 0.15 else 0.85 + t)
    return bar_from(v * (0.92 + noise(rng, 1.5, BAR_W)[:BAR_H] * 0.08))


def tech_bar(rng):
    # Clean: a bright top line, a darker foot, faint scan lines.
    def profile(t):
        if t < 0.06:
            return 1.0
        if t > 0.88:
            return 0.62
        return 0.86 - 0.08 * t
    v = vertical(profile)
    v = v * np.where((np.arange(BAR_H) % 2 == 0)[:, None], 1.0, 0.96)
    return bar_from(v)


def parchment_bar(rng):
    # A wash: lighter at the top, a faint even grain.
    n = noise(rng, 6, BAR_W)[:BAR_H]
    v = vertical(lambda t: 0.97 - 0.17 * t) * (0.95 + n * 0.05)
    return bar_from(v)


def stone_bar(rng):
    v = vertical(lambda t: 0.55 + 0.45 * max(0.0, 1 - abs(t - 0.45) * 2) ** 1.5)
    return bar_from(v)


def glass_bar(rng):
    # Smooth glass: a soft diagonal sheen and a light top edge.
    x = np.arange(BAR_W)[None, :]
    y = np.arange(BAR_H)[:, None]
    band = np.clip(1 - np.abs(((x + y * 1.5) % 128) - 40) / 18, 0, 1) * 0.12
    v = vertical(lambda t: 0.95 - 0.2 * t) + band
    return bar_from(np.clip(v, 0, 1))


def comic_bar(rng):
    y, x = np.mgrid[0:BAR_H, 0:BAR_W]
    dot = (np.hypot((x % 6) - 2.5, (y % 6) - 2.5) < 1.2).astype(float)
    v = 1.0 - dot * 0.3
    return bar_from(v)


def frost_bar(rng):
    v = vertical(lambda t: 1.0 if t < 0.12 else (0.95 - 0.35 * t))
    return bar_from(v)


def pixel_bar(rng):
    v = vertical(lambda t: 1.0 if t < 0.25 else (0.55 if t >= 0.75 else 0.8))
    return bar_from(v)


# Ornaments --------------------------------------------------------------------

def rivet():
    size = ORN * 4
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c, r = size * 0.5, size * 0.22
    d.ellipse([c - r - 6, c - r - 6, c + r + 6, c + r + 6], fill=(30, 18, 8, 160))
    for i in range(int(r), 0, -1):
        t = i / r
        col = tuple(int(v) for v in mix((251, 227, 160), (92, 63, 14), t))
        off = (1 - t) * r * 0.35
        d.ellipse([c - i - off, c - i - off, c + i - off, c + i - off], fill=col + (255,))
    return img.resize((ORN, ORN), Image.LANCZOS)


def bracket():
    img = Image.new("RGBA", (ORN, ORN), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, 15, 2], fill=(255, 255, 255, 255))
    d.rectangle([0, 0, 2, 15], fill=(255, 255, 255, 255))
    return img


def rune():
    """A glowing rune (like Othala): white, the addon tints it."""
    size = ORN * 4
    core = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(core)
    w = size // 14
    top, mid, low, foot = size * 0.16, size * 0.42, size * 0.66, size * 0.86
    cx = size / 2
    d.line([(cx, top), (cx + size * 0.2, mid), (cx - size * 0.16, foot)], fill=255, width=w)
    d.line([(cx, top), (cx - size * 0.2, mid), (cx + size * 0.16, foot)], fill=255, width=w)
    glow = core.filter(ImageFilter.GaussianBlur(size / 16))
    a = np.clip(np.asarray(core, float) / 255 + np.asarray(glow, float) / 255 * 1.6, 0, 1)
    ones = np.ones_like(a)
    return rgba(ones, ones, ones, a).resize((ORN, ORN), Image.LANCZOS)


def seal():
    """A red wax seal with an inner ring."""
    size = ORN * 4
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = size / 2
    rng = np.random.default_rng(7)
    pts = []
    for i in range(24):
        ang = i / 24 * 2 * np.pi
        r = size * (0.44 + rng.uniform(-0.03, 0.02))
        pts.append((c + np.cos(ang) * r, c + np.sin(ang) * r))
    d.polygon(pts, fill=(120, 20, 14, 255))
    for i in range(int(size * 0.4), 0, -2):
        t = i / (size * 0.4)
        col = tuple(int(v) for v in mix((216, 87, 75), (130, 26, 18), t))
        off = (1 - t) * size * 0.06
        d.ellipse([c - i - off, c - i - off, c + i - off, c + i - off], fill=col + (255,))
    r = size * 0.26
    d.ellipse([c - r, c - r, c + r, c + r], outline=(246, 190, 175, 170), width=size // 28)
    return img.resize((ORN, ORN), Image.LANCZOS)


THEMES = {
    "Wood": (wood, wood_bar),
    "Tech": (tech, tech_bar),
    "Parchment": (parchment, parchment_bar),
    "Stone": (stone, stone_bar),
    "Glass": (glass, glass_bar),
    "Comic": (comic, comic_bar),
    "Frost": (frost, frost_bar),
    "Pixel": (pixel, pixel_bar),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for i, (name, (back, bar)) in enumerate(THEMES.items()):
        save(back(np.random.default_rng(100 + i)), name + "Back.tga")
        save(bar(np.random.default_rng(200 + i)), name + "Bar.tga")
    save(rivet(), "Rivet.tga")
    save(bracket(), "Bracket.tga")
    save(rune(), "Rune.tga")
    save(seal(), "Seal.tga")


if __name__ == "__main__":
    main()
