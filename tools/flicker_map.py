"""Flicker map from dev_flicker.tscn's frames (game/scripts/dev/flicker_probe.gd): per-pixel max deviation from the median across frames, as a heat
overlay on frame 0. Usage: python tools/flicker_map.py shots/probe_0 -> shots/probe_0_map.png"""
import glob
import sys

import numpy as np
from PIL import Image

base = sys.argv[1]
files = sorted(glob.glob(base + "_[0-9][0-9].png"))
stack = np.stack([np.asarray(Image.open(f).convert("RGB"), dtype=np.float32) for f in files])
lum = stack.mean(axis=3)
dev = np.abs(lum - np.median(lum, axis=0)).max(axis=0)
img = stack[0] * 0.45
hot = np.clip((dev - 12.0) / 40.0, 0, 1)
img[..., 0] = img[..., 0] * (1 - hot) + 255 * hot
img[..., 1] *= (1 - hot)
img[..., 2] *= (1 - hot)
Image.fromarray(img.astype(np.uint8)).save(base + "_map.png")
print(base, "hot pixels:", int((dev > 20).sum()))
