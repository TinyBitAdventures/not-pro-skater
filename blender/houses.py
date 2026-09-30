"""
Suburban houses for the edges of a level: siding walls on a brick base, a tiled gable roof, trimmed windows
with glossy glass, a front door under a small porch roof, and per house (by seed) a chimney, an attached garage,
a front walk and driveway, a picket fence or a row of shrubs, a mailbox. Real scale (a two-storey house is ~7 m
to the ridge). Built in the house's local space: front faces +Y (toward the street), origin on the ground at the
centre.
"""

import math
import random

from lib import box, cyl_between, cyl_z, mat, prism, quad, uname

_glass = None


def glass():
    """Dark, very smooth glass: reflects the sky in Godot."""
    global _glass
    try:
        if _glass is not None and _glass.name:
            return _glass
    except ReferenceError:            # a previous level's scene was reset (several levels in one Blender run)
        pass
    if True:
        m = mat("Glass", "#1d2630")
        bsdf = m.node_tree.nodes.get("Principled BSDF")
        bsdf.inputs["Roughness"].default_value = 0.06
        _glass = m
    return _glass


def house(root, w=10.0, d=9.0, h=5.6, siding="Siding", seed=0, storeys=2, roof="Roof", garage=False,
          chimney=False, yard=0.0, frontage=None):
    """yard: metres of front yard to the sidewalk (0 = none: no walk, fence or mailbox).
    frontage: "fence", "shrubs" or None along the front of the yard. Returns the door's local x."""
    rnd = random.Random(seed)
    base_h = 0.6
    body = box(uname("House_body"), (w, d, h - base_h), (0, 0, base_h + (h - base_h) / 2), mat(siding, "#dddddd"),
               parent=root)
    box(uname("House_base"), (w + 0.1, d + 0.1, base_h), (0, 0, base_h / 2), mat("Brick", "#aa5544"), parent=root)
    # gable roof along X, 0.4 m overhang
    rise = d * 0.36
    ov = 0.4
    pts = [(-d / 2 - ov, h - 0.05), (d / 2 + ov, h - 0.05), (0.0, h + rise)]
    prism(uname("House_roof"), pts, -w / 2 - ov, w / 2 + ov, [mat(roof, "#664433"), mat(siding, "#dddddd")],
          [0, 0, 0], [False, False, False], cap_mat=1, parent=root)
    trim = mat("Trim", "#f2f2ee")
    if chimney:
        cx = (w / 2 - 1.4) * (1 if rnd.random() < 0.5 else -1)
        box(uname("House_chimney"), (0.9, 0.8, rise + 1.6), (cx, -d * 0.18, h + (rise + 1.6) / 2 - 0.3),
            mat("Brick", "#aa5544"), parent=root)
    # windows: two rows on the front and back, one per storey on the sides
    rows = [base_h + 1.0, base_h + 3.4] if storeys == 2 else [base_h + 1.0]
    cols = max(2, int(w // 2.6))
    door_x = -w / 2 + w * (cols // 2 + 0.5) / cols
    for zi, z in enumerate(rows):
        for i in range(cols):
            x = -w / 2 + w * (i + 0.5) / cols
            if zi == 0 and i == cols // 2:
                _door(root, x, d / 2, base_h, trim)
                continue
            _window(root, x, d / 2, z, 1.2, 1.4, trim, facing=1, shutters=(seed % 3 == 1))
            _window(root, x, -d / 2, z, 1.2, 1.4, trim, facing=-1)
    for z in rows:
        for sy in (-1, 1):
            _window_side(root, sy * w / 2, 0.0, z, 1.1, 1.3, trim)
    garage_x = None
    if garage:
        garage_x = _garage(root, w, d, siding, roof, trim, left=(seed % 2 == 0))
    if yard > 0.0:
        _yard(root, w, d, yard, door_x, garage_x, frontage, trim, rnd)
    return body


def _door(root, x, y, base_h, trim):
    box(uname("House_door"), (1.0, 0.08, 2.1), (x, y + 0.02, base_h + 1.05), mat("Door", "#6b3b2a"), parent=root)
    box(uname("House_doortrim"), (1.25, 0.06, 2.3), (x, y + 0.005, base_h + 1.1), trim, parent=root)
    box(uname("Concrete_step") + "-col", (1.8, 1.2, base_h), (x, y + 0.6, base_h / 2), mat("Concrete", "#bbbbbb"),
        parent=root)
    # porch: a small roof on two posts over the step
    top = base_h + 2.55
    box(uname("House_porchroof"), (2.4, 1.6, 0.12), (x, y + 0.75, top), trim, parent=root)
    for sx in (-1, 1):
        cyl_z(uname("House_porchpost"), (x + sx * 1.05, y + 1.4, base_h), top - base_h, 0.06, trim, seg=8,
              parent=root)


def _window(root, x, y, z, ww, wh, trim, facing=1, shutters=False):
    # the pane is one flat face just proud of the frame: a glass box's thin side faces caught the sky reflection at
    # grazing angles and flickered along every pane edge as the camera moved
    box(uname("House_wtrim"), (ww + 0.2, 0.06, wh + 0.2), (x, y + 0.02 * facing, z + wh / 2), trim, parent=root)
    gy = y + 0.058 * facing
    quad(uname("House_glass"), (x - ww / 2, gy, z), (x + ww / 2, gy, z), (x + ww / 2, gy, z + wh), (x - ww / 2, gy, z + wh),
         glass(), parent=root, expect=(0, facing, 0))
    # (the sill's underside sits 5 mm below the frame's: coplanar, the two flickered from below)
    box(uname("House_sill"), (ww + 0.3, 0.12, 0.06), (x, y + 0.06 * facing, z - 0.075), trim, parent=root)
    if shutters:
        for sx in (-1, 1):
            box(uname("House_shutter"), (0.42, 0.05, wh + 0.1), (x + sx * (ww / 2 + 0.32), y + 0.04 * facing, z + wh / 2),
                mat("Shutter", "#2f3b36"), parent=root)


def _window_side(root, x, y, z, ww, wh, trim, facing=None):
    s = facing if facing is not None else (1 if x > 0 else -1)
    box(uname("House_wtrim"), (0.06, ww + 0.2, wh + 0.2), (x + 0.02 * s, y, z + wh / 2), trim, parent=root)
    gx = x + 0.058 * s
    quad(uname("House_glass"), (gx, y - ww / 2, z), (gx, y + ww / 2, z), (gx, y + ww / 2, z + wh), (gx, y - ww / 2, z + wh),
         glass(), parent=root, expect=(s, 0, 0))


def _garage(root, w, d, siding, roof, trim, left=True):
    """A single garage on one side, its front flush with the house front. Returns its local x."""
    gw, gd, gh = 3.8, 6.5, 3.0
    s = -1 if left else 1
    gx = s * (w / 2 + gw / 2)
    gy = d / 2 - gd / 2
    box(uname("House_garage"), (gw, gd, gh), (gx, gy, gh / 2), mat(siding, "#dddddd"), parent=root)
    rise = 1.1
    pts = [(-gw / 2 - 0.3, gh - 0.05), (gw / 2 + 0.3, gh - 0.05), (0.0, gh + rise)]
    # gable with the ridge running front to back: the prism extrudes along its X, turned a quarter to lie along Y
    r = prism(uname("House_garageroof"), pts, gy - gd / 2 - 0.3, gy + gd / 2 + 0.3,
              [mat(roof, "#664433"), mat(siding, "#dddddd")], [0, 0, 0], [False, False, False], cap_mat=1,
              parent=root, loc=(gx, 0.0, 0.0))
    r.rotation_euler = (0.0, 0.0, math.pi / 2)
    box(uname("House_garagedoor"), (2.8, 0.06, 2.3), (gx, d / 2 + 0.03, 1.15), trim, parent=root)
    for k in range(1, 4):                                           # panel lines
        box(uname("House_garageline"), (2.8, 0.07, 0.03), (gx, d / 2 + 0.035, k * 2.3 / 4), mat("Shutter", "#2f3b36"),
            parent=root)
    return gx


def _yard(root, w, d, yard, door_x, garage_x, frontage, trim, rnd):
    """Front walk and driveway to the sidewalk, and along the front: a picket fence, shrubs or nothing."""
    y0, y1 = d / 2 + 1.2, d / 2 + yard           # from the step to the sidewalk edge
    walk = mat("Driveway", "#bbbbbb")
    box(uname("Concrete_walk") + "-col", (1.2, y1 - y0, 0.06), (door_x, (y0 + y1) / 2, -0.01), walk, parent=root)
    gaps = [(door_x - 0.8, door_x + 0.8)]
    if garage_x is not None:
        yd0 = d / 2
        box(uname("Concrete_drive") + "-col", (3.2, y1 - yd0, 0.06), (garage_x, (yd0 + y1) / 2, -0.01), walk, parent=root)
        gaps.append((garage_x - 1.8, garage_x + 1.8))
    fy = y1 - 0.35
    x0, x1 = -w / 2 - 2.5, w / 2 + 2.5
    if garage_x is not None:
        x0, x1 = min(x0, garage_x - 2.4), max(x1, garage_x + 2.4)
    if frontage == "fence":
        # painted pickets are lit live (not baked): hundreds of slivers would eat the lightmap
        paint = mat("FencePaint", "#ecebe6")
        _picket_fence(root, x0, x1, fy, gaps, paint)
    # mailbox on a post by the walk
    mx = door_x + 1.2
    box(uname("House_mailpost"), (0.08, 0.08, 1.05), (mx, y1 - 0.25, 0.52), mat("Door", "#6b3b2a"), parent=root)
    box(uname("House_mailbox"), (0.22, 0.46, 0.22), (mx, y1 - 0.25, 1.15), mat("Shutter", "#2f3b36"), parent=root)


def _picket_fence(root, x0, x1, y, gaps, trim, h=0.95):
    x = x0
    rails = []
    start = x0
    while x < x1:
        if any(g0 <= x <= g1 for g0, g1 in gaps):
            if x - start > 0.2:
                rails.append((start, x - 0.08))
            while any(g0 <= x <= g1 for g0, g1 in gaps):
                x += 0.05
            start = x
            continue
        box(uname("Fence_picket"), (0.08, 0.025, h), (x, y, h / 2), trim, parent=root)
        x += 0.17
    if x1 - start > 0.2:
        rails.append((start, x1))
    for a, b in rails:
        for z in (0.3, h - 0.2):
            box(uname("Fence_rail"), (b - a, 0.03, 0.06), ((a + b) / 2, y - 0.03, z), trim, parent=root)
