#!/usr/bin/env python3
"""Graffiti for the warehouse alley: bubble-letter pieces and marker tags, drawn from the game's own font (Barlow
Condensed, OFL) into RGBA textures with soft spray edges, overspray, drips and some wear. Writes
art/generated/graffiti_<name>.png (committed; warehouse.py puts them on the sheds' wall as alpha-blended quads).

    ~/Code/star-circuit/audio/.venv/bin/python tools/make_graffiti.py        (needs numpy + PIL)
"""

import math
import os
import random

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FONTS = os.path.join(ROOT, "game", "assets", "fonts")
OUT = os.path.join(ROOT, "art", "generated")
W, H = 1024, 512

# (name, word, fill top, fill bottom, outline, block, cloud, tags)
PIECES = [
    ("loud", "LOUD", "#ffb83a", "#e8541e", "#16121c", "#5a1f2b", "#f2efe6", ["mo", "zk"]),
    ("bass", "BASS", "#6fe0d2", "#2a6fd6", "#101521", "#1b2a5c", "#f7e04a", ["ike"]),
    ("echo", "ECHO", "#f58ad0", "#8a3ad0", "#140f1c", "#3b1650", None, ["zk", "rk"]),
    ("beat", "BEAT", "#c9f25a", "#3aa845", "#0f1a12", "#1d4a2a", "#ffffff", ["mo"]),
]
TAGS = ("tags", ["zk", "mo", "ike", "rk", "vn", "zk", "tb"])


def _hex(c):
    c = c.lstrip("#")
    return np.array([int(c[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32) / 255.0


def _blur(m, r):
    return np.asarray(Image.fromarray((np.clip(m, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(r)),
                      dtype=np.float32) / 255.0


def _grow(m, r, edge=0.18):
    """Round dilation: blur, then keep anything the blur reached."""
    return (_blur(m, r) > edge).astype(np.float32)


def _shrink(m, r):
    return 1.0 - _grow(1.0 - m, r)


def _shift(m, dx, dy):
    out = np.zeros_like(m)
    h, w = m.shape
    xs, xd = (slice(0, w - dx), slice(dx, w)) if dx >= 0 else (slice(-dx, w), slice(0, w + dx))
    ys, yd = (slice(0, h - dy), slice(dy, h)) if dy >= 0 else (slice(-dy, h), slice(0, h + dy))
    out[yd, xd] = m[ys, xs]
    return out


def _letters(word, rnd, height=250):
    """The word as a mask: each letter stretched wide, tilted and bounced, overlapping its neighbour."""
    font = ImageFont.truetype(os.path.join(FONTS, "BarlowCondensed-ExtraBold.ttf"), int(height * 1.25))
    canvas = Image.new("L", (W, H), 0)
    glyphs = []
    for ch in word:
        g = Image.new("L", (height * 2, height * 2), 0)
        ImageDraw.Draw(g).text((height * 0.3, 0), ch, font=font, fill=255)
        g = g.crop(g.getbbox())
        g = g.resize((int(g.width * rnd.uniform(1.35, 1.6)), int(g.height * rnd.uniform(0.95, 1.08))), Image.BICUBIC)
        g = g.rotate(rnd.uniform(-10.0, 10.0), expand=True, resample=Image.BICUBIC)
        glyphs.append(g)
    total = sum(g.width for g in glyphs) * 0.9 + glyphs[-1].width * 0.1
    x = (W - total) / 2
    for g in glyphs:
        y = (H - g.height) / 2 + rnd.uniform(-0.09, 0.09) * height - 20
        canvas.paste(255, (int(x), int(y)), g)
        x += g.width * 0.9
    return np.asarray(canvas, dtype=np.float32) / 255.0


def _layer(rgba, mask, colour, alpha=1.0):
    """Paint `colour` (hex, or an (h, w, 3) array) through `mask` over rgba (straight alpha)."""
    c = colour if isinstance(colour, np.ndarray) else np.broadcast_to(_hex(colour), rgba[..., :3].shape)
    a = np.clip(mask, 0, 1)[..., None] * alpha
    out_a = a + rgba[..., 3:4] * (1 - a)
    rgb = (c * a + rgba[..., :3] * rgba[..., 3:4] * (1 - a)) / np.maximum(out_a, 1e-5)
    rgba[..., :3] = rgb
    rgba[..., 3:4] = out_a


def _spray(mask, rnd, soft=1.6, dust=0.05):
    """A sprayed edge: soft, with a scatter of paint dots just outside it."""
    m = _blur(mask, soft)
    halo = np.clip(_blur(mask, 7.0) - m, 0, 1)
    dots = np.random.default_rng(rnd.randrange(1 << 30)).random(mask.shape) < dust
    return np.clip(m + halo * dots * 1.5, 0, 1)


def _drips(fill, rnd, n=5):
    """Runs of paint down from the fill's lower edge."""
    h, w = fill.shape
    img = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(img)
    cols = np.where(fill.max(axis=0) > 0.5)[0]
    for _ in range(n):
        x = int(rnd.choice(cols))
        ys = np.where(fill[:, x] > 0.5)[0]
        y0 = int(ys.max()) - 4
        length = rnd.uniform(25, 90)
        wd = rnd.uniform(4, 8)
        d.rounded_rectangle([x - wd / 2, y0, x + wd / 2, y0 + length], radius=wd / 2, fill=255)
        d.ellipse([x - wd * 0.8, y0 + length - wd * 0.8, x + wd * 0.8, y0 + length + wd * 0.8], fill=255)
    return np.asarray(img, dtype=np.float32) / 255.0


def _tag(rgba, text, rnd, x, y, size, colour):
    """A marker tag: thin letters, slanted and jittered, with a flourish underline."""
    font = ImageFont.truetype(os.path.join(FONTS, "BarlowCondensed-Bold.ttf"), size)
    img = Image.new("L", (W, H), 0)
    d = ImageDraw.Draw(img)
    cx = x
    for ch in text:
        g = Image.new("L", (size * 2, size * 2), 0)
        ImageDraw.Draw(g).text((size * 0.3, 0), ch, font=font, fill=255)
        g = g.crop(g.getbbox() or (0, 0, 1, 1))
        g = g.transform(g.size, Image.AFFINE, (1, 0.35, -0.35 * g.height * 0.5, 0, 1, 0), resample=Image.BICUBIC)
        g = g.rotate(rnd.uniform(-8, 8), expand=True, resample=Image.BICUBIC)
        img.paste(255, (int(cx), int(y + rnd.uniform(-0.12, 0.12) * size)), g)
        cx += g.width * 0.72
    by = y + size * 1.0
    d.line([(x - size * 0.1, by + size * 0.1), (cx + size * 0.2, by - size * 0.15)], fill=255, width=max(2, size // 14))
    m = np.asarray(img, dtype=np.float32) / 255.0
    _layer(rgba, _blur(m, 0.8), colour, 0.92)


def piece(name, word, top, bottom, outline, block, cloud, tags, seed):
    rnd = random.Random(seed)
    rgba = np.zeros((H, W, 4), dtype=np.float32)
    letters = _letters(word, rnd)
    fill = _grow(letters, 4.5)                         # fat, rounded letters (more and the counters close)
    line = _grow(fill, 6.0)                            # the outline round them
    shade = np.zeros_like(line)                        # a 3D block down and to the right
    for k in range(1, 15):
        shade = np.maximum(shade, _shift(line, k, k))
    back = _grow(np.maximum(line, shade), 22.0, edge=0.08) if cloud else None
    if back is not None:                               # a sprayed cloud behind the letters
        _layer(rgba, _spray(back, rnd, soft=4.0, dust=0.08), cloud, 0.9)
    _layer(rgba, _spray(shade, rnd), block)
    _layer(rgba, _spray(line, rnd, soft=1.2), outline)
    ys = np.linspace(0.0, 1.0, H)[:, None, None]
    grad = _hex(top)[None, None, :] * (1 - ys) + _hex(bottom)[None, None, :] * ys
    grad = np.broadcast_to(grad, (H, W, 3)).copy()
    _layer(rgba, _blur(fill, 1.0), grad)
    # a second tone across the middle, sprayed in a wavy band
    xs = np.arange(W)[None, :]
    band = (np.abs(np.arange(H)[:, None] - (H * 0.52 + 18 * np.sin(xs / 55.0 + seed))) < 14).astype(np.float32) * fill
    _layer(rgba, _blur(band, 3.0), "#ffffff", 0.35)
    # highlights: the top-left rim of each letter, and a few shine dots
    rim = np.clip(fill - _shift(fill, 6, 7), 0, 1) * _shrink(fill, 3.0)
    _layer(rgba, _blur(rim, 1.2), "#ffffff", 0.85)
    shine = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shine)
    ys_, xs_ = np.where(_shrink(fill, 14.0) > 0.5)
    for _ in range(6):
        i = rnd.randrange(len(xs_))
        r = rnd.uniform(5, 9)
        sd.ellipse([xs_[i] - r, ys_[i] - r, xs_[i] + r, ys_[i] + r], fill=255)
    _layer(rgba, _blur(np.asarray(shine, dtype=np.float32) / 255.0, 1.0), "#ffffff", 0.9)
    drips = _drips(fill, rnd)
    _layer(rgba, _blur(drips, 1.0), bottom)
    for i, t in enumerate(tags or []):                 # someone tagged over it
        _tag(rgba, t, rnd, W * rnd.uniform(0.1, 0.65), H * (0.72 if i % 2 == 0 else 0.06), rnd.randrange(80, 110),
             ["#111111", "#d8d8d8", "#c0392b"][rnd.randrange(3)])
    return _wear(rgba, rnd)


def tags_panel(names, seed):
    rnd = random.Random(seed)
    rgba = np.zeros((H, W, 4), dtype=np.float32)
    for i, t in enumerate(names):
        x = W * (0.04 + 0.24 * (i % 4)) + rnd.uniform(-20, 20)
        y = H * (0.06 + 0.46 * (i // 4)) + rnd.uniform(-10, 30)
        _tag(rgba, t, rnd, x, y, rnd.randrange(110, 170), ["#111111", "#f0f0f0", "#c0392b", "#2d5fb8"][i % 4])
    return _wear(rgba, rnd)


def _wear(rgba, rnd):
    """Old paint: a little faded and flaked, so the wall shows through here and there."""
    g = np.random.default_rng(rnd.randrange(1 << 30))
    noise = _blur(g.random((H, W)).astype(np.float32), 3.0)
    noise = (noise - noise.min()) / max(noise.max() - noise.min(), 1e-5)
    flake = np.clip((noise - 0.78) * 8.0, 0.0, 1.0)
    rgba[..., 3] *= (1.0 - 0.65 * flake) * 0.94
    rgba[..., :3] = rgba[..., :3] * 0.92 + 0.04          # sun-faded
    img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), "RGBA")
    return img


def main():
    os.makedirs(OUT, exist_ok=True)
    for k, p in enumerate(PIECES):
        img = piece(*p, seed=11 + k * 7)
        img.save(os.path.join(OUT, f"graffiti_{p[0]}.png"))
        print("wrote", f"graffiti_{p[0]}.png")
    tags_panel(TAGS[1], seed=5).save(os.path.join(OUT, "graffiti_tags.png"))
    print("wrote graffiti_tags.png")


if __name__ == "__main__":
    main()
