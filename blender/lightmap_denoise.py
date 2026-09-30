"""
Clean the noise out of a baked lightmap, in plain numpy (it runs inside Blender's bake step and standalone).

A 128-sample Cycles bake of sky light leaves speckle, and in shade (where only the sky term shows) it reads as
purple and green blotches on the walls. Sky light changes colour only slowly across a surface, so the colour is
smoothed hard (chroma) and the brightness only lightly (luma), keeping contact shadows and edges. Blurring is
masked: texels outside the UV islands (black) don't bleed in.

    python3 blender/lightmap_denoise.py game/assets/levels/*.lightmap.*.png      (needs numpy + PIL)
"""

import numpy as np

LUMA_SIGMA = 1.6      # texels
CHROMA_SIGMA = 10.0


def _kernel(sigma):
    r = max(1, int(round(sigma * 2.5)))
    x = np.arange(-r, r + 1, dtype=np.float32)
    k = np.exp(-(x * x) / (2.0 * sigma * sigma))
    return k / k.sum(), r


def _blur(a, sigma):
    """Separable gaussian blur of a 2D or 3D (h, w, c) array, edges clamped."""
    k, r = _kernel(sigma)
    out = a.astype(np.float32)
    for axis in (0, 1):
        pad = [(0, 0)] * out.ndim
        pad[axis] = (r, r)
        p = np.pad(out, pad, mode="edge")
        acc = np.zeros_like(out)
        n = out.shape[axis]
        for i, w in enumerate(k):
            sl = [slice(None)] * out.ndim
            sl[axis] = slice(i, i + n)
            acc += w * p[tuple(sl)]
        out = acc
    return out


def _masked_blur(a, mask, sigma):
    m = mask.astype(np.float32)
    num = _blur(a * (m[..., None] if a.ndim == 3 else m), sigma)
    den = _blur(m, sigma)
    den = np.maximum(den, 1e-4)
    return num / (den[..., None] if a.ndim == 3 else den)


def denoise(rgb):
    """rgb: float array (h, w, 3), the lightmap's stored values (0..1). Returns the cleaned array."""
    rgb = np.asarray(rgb, dtype=np.float32)
    mask = rgb.max(axis=2) > (1.0 / 255.0)
    luma = rgb @ np.array([0.299, 0.587, 0.114], dtype=np.float32)
    chroma = rgb - luma[..., None]                  # what's left is the colour
    luma_s = _masked_blur(luma, mask, LUMA_SIGMA)
    chroma_s = _masked_blur(chroma, mask, CHROMA_SIGMA)
    out = np.clip(luma_s[..., None] + chroma_s, 0.0, 1.0)
    out[~mask] = rgb[~mask]
    return out


if __name__ == "__main__":
    import sys
    from PIL import Image
    for path in sys.argv[1:]:
        im = Image.open(path).convert("RGB")
        a = np.asarray(im, dtype=np.float32) / 255.0
        b = denoise(a)
        Image.fromarray(np.round(b * 255.0).astype(np.uint8)).save(path)
        print("denoised", path, im.size)
