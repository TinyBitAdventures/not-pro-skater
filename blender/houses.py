"""
Suburban houses for the edges of a level: siding walls on a brick base, a tiled gable roof, trimmed windows
with glossy glass, a front door and a porch step. Real scale (a two-storey house is ~7 m to the ridge).
Built in the house's local space: front faces +Y (toward the street), origin on the ground at the centre.
"""

import math
import random

from lib import box, empty, mat, mesh_obj, prism, uname

_glass = None


def glass():
    """Dark, very smooth glass: reflects the sky in Godot."""
    global _glass
    if _glass is None:
        m = mat("Glass", "#1d2630")
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.06
        _glass = m
    return _glass


def house(root, w=10.0, d=9.0, h=5.6, siding="Siding", seed=0, storeys=2):
    rnd = random.Random(seed)
    base_h = 0.6
    body = box(uname("House_body"), (w, d, h - base_h), (0, 0, base_h + (h - base_h) / 2), mat(siding, "#dddddd"),
               parent=root)
    box(uname("House_base"), (w + 0.1, d + 0.1, base_h), (0, 0, base_h / 2), mat("Brick", "#aa5544"), parent=root)
    # gable roof along X, 0.4 m overhang
    rise = d * 0.36
    ov = 0.4
    pts = [(-d / 2 - ov, h - 0.05), (d / 2 + ov, h - 0.05), (0.0, h + rise)]
    prism(uname("House_roof"), pts, -w / 2 - ov, w / 2 + ov, [mat("Roof", "#664433"), mat(siding, "#dddddd")],
          [0, 0, 0], [False, False, False], cap_mat=1, parent=root)
    # windows: two rows on the front, one on the sides
    trim = mat("Trim", "#f2f2ee")
    rows = [base_h + 1.0, base_h + 3.4] if storeys == 2 else [base_h + 1.0]
    cols = max(2, int(w // 2.6))
    for zi, z in enumerate(rows):
        for i in range(cols):
            x = -w / 2 + w * (i + 0.5) / cols
            if zi == 0 and i == cols // 2:
                # front door instead of a window
                box(uname("House_door"), (1.0, 0.08, 2.1), (x, d / 2 + 0.02, base_h + 1.05), mat("Door", "#6b3b2a"),
                    parent=root)
                box(uname("House_doortrim"), (1.25, 0.06, 2.3), (x, d / 2 + 0.005, base_h + 1.1), trim, parent=root)
                box(uname("Concrete_step") + "-col", (1.8, 1.2, base_h), (x, d / 2 + 0.6, base_h / 2),
                    mat("Concrete", "#bbbbbb"), parent=root)
                continue
            _window(root, x, d / 2, z, 1.2, 1.4, trim, facing=1)
            _window(root, x, -d / 2, z, 1.2, 1.4, trim, facing=-1)
    for z in rows:
        for sy in (-1, 1):
            _window_side(root, sy * w / 2, 0.0, z, 1.1, 1.3, trim)
    return body


def _window(root, x, y, z, ww, wh, trim, facing=1):
    box(uname("House_wtrim"), (ww + 0.2, 0.06, wh + 0.2), (x, y + 0.02 * facing, z + wh / 2), trim, parent=root)
    box(uname("House_glass"), (ww, 0.06, wh), (x, y + 0.05 * facing, z + wh / 2), glass(), parent=root)


def _window_side(root, x, y, z, ww, wh, trim):
    s = 1 if x > 0 else -1
    box(uname("House_wtrim"), (0.06, ww + 0.2, wh + 0.2), (x + 0.02 * s, y, z + wh / 2), trim, parent=root)
    box(uname("House_glass"), (0.06, ww, wh), (x + 0.05 * s, y, z + wh / 2), glass(), parent=root)
