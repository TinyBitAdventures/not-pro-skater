"""
Modular skate-park kit and park furniture.

Every builder takes a `root` empty and builds in the piece's local space:
  local +Y is the piece's main axis (the direction a skater rides into a ramp),
  local +X is its width, local +Z is up, origin on the ground at the piece centre.
Level scripts place the roots (see park.py), so pieces can be reused and rotated freely.
"""

import math
import random

from mathutils import Vector

from lib import (box, col_box, cyl_between, cyl_z, empty, grind_line, ico, label, loft_box, mat,
                 mesh_obj, prism, quad, uname)

PALETTE = {
    "Wood": "#eaa964", "WoodB": "#d99552", "Navy": "#39415f", "NavyLt": "#4f5a82",
    "Metal": "#bcc7d8", "MetalDk": "#7d8aa0", "Concrete": "#c9d0db", "Plaza": "#b7c2d4", "ConcreteDk": "#9ba7b8",
    "Path": "#8a97aa", "PathB": "#7c8a9e", "Grass": "#6fc84c", "GrassB": "#62bb42", "Curb": "#e3e8f0",
    "Orange": "#ff8a3d", "Blue": "#3d9bff", "Green": "#3fc66d", "Purple": "#8a5cf0", "Red": "#ff5a5a",
    "Yellow": "#ffd23f", "Teal": "#1fc2b0", "Pink": "#ff7eb6", "White": "#f4f7fb", "Ink": "#20263a",
    "Trunk": "#8b5e3c", "Leaf": "#43b54f", "LeafB": "#63cf5c", "LeafC": "#2f9a4a", "Pine": "#2c8f52",
    "PineB": "#3ea867", "Window": "#8fd3ff", "Lamp": "#fff3b0", "FenceMesh": "#c8d0dc", "Water": "#4fc3f7",
    "Road": "#59637a", "Line": "#f6f1d0", "Dirt": "#a7794f", "Brick": "#d9694f", "Roof": "#b5533c",
    "RoofB": "#4a6fa5", "Cream": "#f3e3bb", "Sky": "#8fd3ff", "Bin": "#3fc66d", "Flower": "#ff7eb6",
    "Collision": "#ff00ff",
}


def M(name):
    return mat(name, PALETTE[name])


# --------------------------------------------------------------------------
# ramp profile shared by quarter pipes, kickers and half pipes
# --------------------------------------------------------------------------

def qp_profile(R, H, D, n=14):
    """
    (y, z) polygon of one transition: curve rises from (0, 0) tangent to the ground up to height H,
    then an optional deck of depth D. Returns pts, edge material ids (0 Wood, 1 WoodB, 2 Navy),
    smooth flags, and the lip's y.
    """
    th = math.acos(1 - H / R)
    yt = R * math.sin(th)
    pts, em, sm = [], [], []
    pts.append((yt + D, 0.0))
    em.append(2)
    sm.append(False)
    if D > 0:
        pts.append((yt + D, H))
        em.append(0)          # deck top
        sm.append(False)
    for k in range(n + 1):
        t = th * (1 - k / n)
        pts.append((R * math.sin(t), R * (1 - math.cos(t))))
        if k < n:
            em.append(k % 2)  # alternating plank tones along the curve
            sm.append(True)
    em.append(2)              # closing bottom edge
    sm.append(False)
    return pts, em, sm, yt, th


def profile_z(R, H, y):
    yt = R * math.sin(math.acos(1 - H / R))
    if y >= yt:
        return H
    return R - math.sqrt(max(R * R - y * y, 0.0))


STICKER_COLORS = ["Orange", "Blue", "Green", "Purple", "Red", "Yellow", "Teal", "Pink"]


def stickers(parent, xs, ys_zs, rnd, sizes=(0.28, 0.42)):
    """Colourful discs / polygons stuck on a side panel. xs = x of the panel face (both sides done)."""
    for (y, z) in ys_zs:
        seg = rnd.choice([3, 4, 5, 6, 8, 12])
        s = rnd.uniform(*sizes)
        m = M(rnd.choice(STICKER_COLORS))
        for sx in xs:
            d = 0.012 if sx > 0 else -0.012
            cyl_between(uname("Sticker"), (sx, y, z), (sx + d, y, z), s, m, seg=seg, smooth=False, parent=parent)


def guard_rail(root, p0, p1, z, h, colors, post_every=1.4, col=True, surface="Wall"):
    """Open colourful railing from p0 to p1 (x, y) standing on height z."""
    a, b = Vector((*p0, 0)), Vector((*p1, 0))
    L = (b - a).length
    n = max(1, int(round(L / post_every)))
    for i in range(n + 1):
        p = a.lerp(b, i / n)
        cyl_z(uname("RailPost"), (p.x, p.y, z), h, 0.06, M("MetalDk"), seg=6, smooth=False, parent=root)
    # top bar + mid bar in coloured segments
    segs = max(1, n // 2)
    for i in range(segs):
        c = colors[i % len(colors)]
        s0 = a.lerp(b, i / segs)
        s1 = a.lerp(b, (i + 1) / segs)
        cyl_between(uname("RailBar"), (s0.x, s0.y, z + h), (s1.x, s1.y, z + h), 0.085, M(c), seg=6, smooth=False, parent=root)
        cyl_between(uname("RailBar"), (s0.x, s0.y, z + h * 0.5), (s1.x, s1.y, z + h * 0.5), 0.055, M(c), seg=6, smooth=False, parent=root)
    if col:
        mid = (a + b) / 2
        ang = math.atan2(b.y - a.y, b.x - a.x)
        c = col_box(uname("GuardRail"), (L, 0.14, h + 0.6), (0, 0, z + (h + 0.6) / 2), parent=root, surface=surface)
        c.location = (mid.x, mid.y, 0)
        c.rotation_euler = (0, 0, ang)


# --------------------------------------------------------------------------
# skate obstacles
# --------------------------------------------------------------------------

def quarter_pipe(root, W=6.0, R=3.2, H=2.4, D=2.0, coping=True, rails=True, decals=True, seed=1):
    wood, woodb, navy = M("Wood"), M("WoodB"), M("Navy")
    pts, em, sm, yt, th = qp_profile(R, H, D)
    prism(uname("Wood_QuarterPipe") + "-col", pts, -W / 2, W / 2, [wood, woodb, navy], em, sm, cap_mat=2, parent=root)
    if coping:
        cyl_between(uname("Coping"), (-W / 2, yt, H + 0.02), (W / 2, yt, H + 0.02), 0.075, M("Metal"), seg=8, parent=root)
        grind_line(root, uname("coping"), [(-W / 2 + 0.4, yt, H + 0.1), (W / 2 - 0.4, yt, H + 0.1)])
    if rails and D > 0:
        cols = ["Orange", "Blue", "Green"]
        guard_rail(root, (-W / 2 + 0.05, yt + D - 0.05), (W / 2 - 0.05, yt + D - 0.05), H, 0.95, cols)
        guard_rail(root, (-W / 2 + 0.05, yt + 0.5), (-W / 2 + 0.05, yt + D - 0.05), H, 0.95, cols, col=True)
        guard_rail(root, (W / 2 - 0.05, yt + 0.5), (W / 2 - 0.05, yt + D - 0.05), H, 0.95, cols, col=True)
    if decals:
        rnd = random.Random(seed)
        spots = []
        for _ in range(4):
            y = rnd.uniform(0.6, yt + D - 0.6)
            top = profile_z(R, H, y)
            if top > 0.9:
                spots.append((y, rnd.uniform(0.35, top - 0.35)))
        stickers(root, (-W / 2, W / 2), spots, rnd)


def kicker(root, W=2.8, R=5.0, H=0.75):
    quarter_pipe(root, W=W, R=R, H=H, D=0.0, coping=False, rails=False, decals=False)


def hip(root, W=2.6, R=5.0, H=0.55):
    """Two kickers back to back (crest at local y=0): rideable in both directions on the ring."""
    yt = R * math.sin(math.acos(1 - H / R))
    kicker(empty(uname("Hip"), (0, -yt, 0), 0.0, root), W=W, R=R, H=H)
    kicker(empty(uname("Hip"), (0, yt, 0), math.pi, root), W=W, R=R, H=H)


def mini_ramp(root, W=7.0, R=2.7, H=1.75, F=5.0, D=1.8, seed=3):
    """Two facing quarter pipes with a flat between them; the flat is the plaza slab."""
    yt = R * math.sin(math.acos(1 - H / R))
    left = empty(uname("Half"), (0, -F / 2, 0), math.pi, root)
    right = empty(uname("Half"), (0, F / 2, 0), 0.0, root)
    quarter_pipe(left, W=W, R=R, H=H, D=D, seed=seed)
    quarter_pipe(right, W=W, R=R, H=H, D=D, seed=seed + 1)
    quad(uname("PipeFloor"), (-W / 2, -F / 2, 0.012), (W / 2, -F / 2, 0.012), (W / 2, F / 2, 0.012),
         (-W / 2, F / 2, 0.012), M("WoodB"), parent=root)
    # a little roll-in bump
    return yt


def bank(root, W=4.0, L=3.0, H=0.8):
    pts = [(L, 0.0), (L, H), (0.0, 0.0)]
    prism(uname("Wood_Bank") + "-col", pts, -W / 2, W / 2, [M("Wood"), M("WoodB"), M("Navy")], [2, 0, 2], [False, False, False],
          cap_mat=2, parent=root)


def funbox(root, S=4.4, H=0.9, seed=5):
    """Wooden deck with a kicker at each end, a bank on one side and a grindable edge on the other."""
    wood, navy = M("Wood"), M("Navy")
    h = S / 2
    pts = [(-h, 0.0), (h, 0.0), (h, H), (-h, H)]
    prism(uname("Wood_FunDeck") + "-col", pts, -h, h, [wood, M("WoodB"), navy], [2, 2, 0, 2], [False] * 4, cap_mat=2, parent=root)
    kyt = 5.0 * math.sin(math.acos(1 - H / 5.0))
    kicker(empty(uname("Kick"), (0, h + kyt, 0), math.pi, root), W=3.4, R=5.0, H=H)
    kicker(empty(uname("Kick"), (0, -h - kyt, 0), 0.0, root), W=3.4, R=5.0, H=H)
    bank(empty(uname("Bank"), (h + 2.8, 0, 0), math.pi / 2, root), W=S, L=2.8, H=H)
    # grind edge on the -X side
    cyl_between(uname("Coping"), (-h, -h + 0.1, H + 0.02), (-h, h - 0.1, H + 0.02), 0.075, M("Metal"), seg=8, parent=root)
    grind_line(root, uname("funbox"), [(-h, -h + 0.3, H + 0.1), (-h, h - 0.3, H + 0.1)])
    # little colour blocks on the deck
    rnd = random.Random(seed)
    stickers(root, (-h - 0.0,), [(rnd.uniform(-1.4, 1.4), rnd.uniform(0.3, 0.6)) for _ in range(2)], rnd, sizes=(0.16, 0.24))


def pyramid(root, B=7.5, T=3.4, H=0.75):
    ob = loft_box(uname("Wood_Pyramid") + "-col", (B, B), (T, T), 0.0, H, M("Wood"), parent=root)
    box(uname("PyramidTop"), (T, T, 0.03), (0, 0, H + 0.015), M("WoodB"), parent=root)


def manual_pad(root, L=5.0, W=1.6, H=0.2, color="Concrete"):
    loft_box(uname("Concrete_ManualPad") + "-col", (W + 0.9, L + 0.9), (W, L), 0.0, H, M(color), parent=root)
    box(uname("PadStripe"), (W * 0.5, L * 0.9, 0.02), (0, 0, H + 0.01), M("Yellow"), parent=root)


def ledge(root, L=5.0, W=0.7, h=0.55, color="Concrete"):
    box(uname("Concrete_Ledge") + "-col", (W, L, h), (0, 0, h / 2), M(color), parent=root)
    box(uname("LedgeSide"), (W + 0.02, L + 0.02, 0.12), (0, 0, 0.06), M("ConcreteDk"), parent=root)
    for sx in (-1, 1):
        x = sx * (W / 2 - 0.04)
        cyl_between(uname("LedgeEdge"), (x, -L / 2, h + 0.01), (x, L / 2, h + 0.01), 0.05, M("Metal"), seg=6, smooth=False, parent=root)
        grind_line(root, uname("ledge"), [(x, -L / 2 + 0.1, h + 0.07), (x, L / 2 - 0.1, h + 0.07)])


def flat_rail(root, L=6.0, h=0.72, color="Yellow"):
    cyl_between(uname("Rail"), (0, -L / 2, h), (0, L / 2, h), 0.065, M(color), seg=8, parent=root)
    n = max(2, int(L // 2.2) + 1)
    for i in range(n):
        y = -L / 2 + L * i / (n - 1)
        cyl_z(uname("RailPost"), (0, y, 0), h, 0.05, M("MetalDk"), seg=6, smooth=False, parent=root)
        box(uname("RailFoot"), (0.42, 0.22, 0.04), (0, y, 0.02), M("MetalDk"), parent=root)
    col_box(uname("Rail"), (0.16, L, 0.16), (0, 0, h), parent=root, surface="Metal")
    grind_line(root, uname("rail"), [(0, -L / 2 + 0.05, h + 0.07), (0, L / 2 - 0.05, h + 0.07)])


def stair_rail(root, n=6, rise=0.19, run=0.44, W=2.6, color="Red"):
    """Stair set descending toward +Y with a grindable handrail down each side."""
    Ht = n * rise
    pts = [(-1.6, 0.0), (-1.6, Ht), (0.0, Ht)]
    em = [2, 0]
    for k in range(1, n + 1):
        z = Ht - k * rise
        pts.append(((k - 1) * run, z))
        em.append(1)                      # riser
        if k < n:
            pts.append((k * run, z))
            em.append(0)                  # tread
    em.append(2)                          # closing bottom edge
    # visual steps only: a capsule cannot roll 19 cm risers (audit: speed 9 -> 0.4 m/s, stuck on tread 3)
    prism(uname("Concrete_Stairs"), pts, -W / 2, W / 2, [M("Concrete"), M("ConcreteDk"), M("Navy")], em,
          [False] * len(pts), cap_mat=1, parent=root)
    # collision proxy: platform + a smooth slope through the nosings
    prism(uname("Concrete_StairsSlope") + "-colonly", [(-1.6, 0.0), (-1.6, Ht), (0.0, Ht), (n * run, 0.0)],
          -W / 2, W / 2, [M("Collision")], [0, 0, 0, 0], cap_mat=0, parent=root)
    slope = rise / run
    off = 0.95
    lrun = (n - 1) * run
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.28)
        y0, y1 = -0.4, lrun + 0.4
        z0 = Ht + off - (y0 * slope)
        z1 = Ht + off - (y1 * slope)
        cyl_between(uname("HandRail"), (x, y0, z0), (x, y1, z1), 0.06, M(color), seg=8, parent=root)
        for (y, z) in ((y0, z0), (y1, z1)):
            cyl_z(uname("RailPost"), (x, y, 0), z - 0.05, 0.05, M("MetalDk"), seg=6, smooth=False, parent=root)
        c = col_box(uname("HandRail"), (0.16, math.hypot(y1 - y0, z1 - z0), 0.16), (0, 0, 0), parent=root, surface="Metal")
        c.location = (x, (y0 + y1) / 2, (z0 + z1) / 2)
        c.rotation_euler = (math.atan2(z1 - z0, y1 - y0), 0, 0)
        grind_line(root, uname("stair"), [(x, y0 + 0.05, z0 + 0.07), (x, y1 - 0.05, z1 + 0.07)])


# --------------------------------------------------------------------------
# park furniture
# --------------------------------------------------------------------------

def bench(root, L=1.9, grindable=True):
    box(uname("BenchSeat"), (L, 0.5, 0.08), (0, 0, 0.5), M("Wood"), parent=root)
    box(uname("BenchBack"), (L, 0.08, 0.45), (0, -0.26, 0.82), M("WoodB"), parent=root)
    for sx in (-1, 1):
        box(uname("BenchLeg"), (0.08, 0.5, 0.5), (sx * (L / 2 - 0.15), 0, 0.25), M("MetalDk"), parent=root)
    col_box(uname("Bench"), (L, 0.6, 0.95), (0, -0.05, 0.47), parent=root)
    if grindable:
        cyl_between(uname("BenchEdge"), (-L / 2, 0.25, 0.55), (L / 2, 0.25, 0.55), 0.03, M("Metal"), seg=6, smooth=False, parent=root)
        grind_line(root, uname("bench"), [(-L / 2 + 0.1, 0.25, 0.6), (L / 2 - 0.1, 0.25, 0.6)])


def tree(root, variety=0, seed=0, s=1.0):
    rnd = random.Random(seed)
    if variety == 0:  # round leafy tree
        cyl_z(uname("Trunk"), (0, 0, 0), 1.9 * s, 0.26 * s, M("Trunk"), r1=0.18 * s, seg=7, smooth=False, parent=root)
        cols = ["Leaf", "LeafB", "LeafC"]
        ico(uname("Leaves"), (0, 0, 3.2 * s), 1.7 * s, M("Leaf"), squash=(1, 1, 0.85), parent=root)
        for i in range(4):
            a = rnd.uniform(0, 2 * math.pi) + i * math.pi / 2
            d = 1.05 * s
            ico(uname("Leaves"), (math.cos(a) * d, math.sin(a) * d, (2.75 + rnd.uniform(-0.2, 0.5)) * s),
                (1.0 + rnd.uniform(-0.15, 0.2)) * s, M(cols[i % 3]), squash=(1, 1, 0.85), parent=root)
        ico(uname("Leaves"), (0.2 * s, 0.1 * s, 4.15 * s), 1.05 * s, M("LeafB"), squash=(1, 1, 0.85), parent=root)
    else:          # pine
        cyl_z(uname("Trunk"), (0, 0, 0), 1.3 * s, 0.22 * s, M("Trunk"), seg=6, smooth=False, parent=root)
        for i, (z, r, h) in enumerate(((0.9, 1.7, 1.9), (2.1, 1.35, 1.8), (3.3, 0.95, 1.7))):
            cyl_between(uname("Pine"), (0, 0, z * s), (0, 0, (z + h) * s), r * s, M("Pine" if i % 2 == 0 else "PineB"),
                        r1=0.02, seg=7, smooth=False, parent=root)
    col_box(uname("Tree"), (0.55 * s, 0.55 * s, 3.0), (0, 0, 1.5), parent=root)


def bush(root, s=1.0, seed=0):
    rnd = random.Random(seed)
    ico(uname("Bush"), (0, 0, 0.45 * s), 0.75 * s, M("LeafC"), squash=(1, 1, 0.75), parent=root)
    ico(uname("Bush"), (0.5 * s, 0.2 * s, 0.35 * s), 0.5 * s, M("Leaf"), squash=(1, 1, 0.75), parent=root)
    if rnd.random() < 0.6:
        for _ in range(3):
            ico(uname("Bloom"), (rnd.uniform(-0.5, 0.5) * s, rnd.uniform(-0.5, 0.5) * s, 0.75 * s), 0.09 * s,
                M(rnd.choice(["Flower", "Yellow", "White"])), sub=0, parent=root)


def lamp(root, h=4.2):
    cyl_z(uname("LampPole"), (0, 0, 0), h, 0.09, M("Ink"), r1=0.06, seg=8, parent=root)
    cyl_z(uname("LampBase"), (0, 0, 0), 0.5, 0.16, M("Ink"), seg=8, parent=root)
    box(uname("LampArm"), (0.9, 0.08, 0.08), (0.4, 0, h), M("Ink"), parent=root)
    box(uname("LampHead"), (0.5, 0.3, 0.12), (0.85, 0, h - 0.02), M("Ink"), parent=root)
    box(uname("LampBulb"), (0.4, 0.22, 0.05), (0.85, 0, h - 0.1), M("Lamp"), parent=root)
    col_box(uname("Lamp"), (0.3, 0.3, 2.5), (0, 0, 1.25), parent=root)


def bin_(root, color="Bin"):
    cyl_z(uname("Bin"), (0, 0, 0), 0.85, 0.32, M(color), r1=0.36, seg=8, parent=root)
    cyl_z(uname("BinLid"), (0, 0, 0.85), 0.1, 0.4, M("Ink"), seg=8, parent=root)
    col_box(uname("Bin"), (0.7, 0.7, 0.95), (0, 0, 0.47), parent=root)


def picnic(root):
    box(uname("PicnicTop"), (2.0, 0.85, 0.07), (0, 0, 0.78), M("Wood"), parent=root)
    for sy in (-1, 1):
        box(uname("PicnicSeat"), (2.0, 0.28, 0.06), (0, sy * 0.72, 0.47), M("WoodB"), parent=root)
    for sx in (-1, 1):
        box(uname("PicnicLeg"), (0.08, 1.7, 0.08), (sx * 0.75, 0, 0.42), M("Trunk"), parent=root)
    col_box(uname("Picnic"), (2.0, 1.9, 0.85), (0, 0, 0.42), parent=root)


def fence(root, L=6.0, h=1.7, color="MetalDk", solid=True):
    """Chain-link fence run along local Y, centred. Godot draws FenceMesh as a see-through diamond mesh."""
    n = max(1, int(round(L / 2.5)))
    for i in range(n + 1):
        y = -L / 2 + L * i / n
        cyl_z(uname("FencePost"), (0, y, 0), h, 0.06, M(color), seg=6, smooth=False, parent=root)
    cyl_between(uname("FenceRail"), (0, -L / 2, h), (0, L / 2, h), 0.045, M(color), seg=6, smooth=False, parent=root)
    cyl_between(uname("FenceRail"), (0, -L / 2, 0.06), (0, L / 2, 0.06), 0.04, M(color), seg=6, smooth=False, parent=root)
    m = M("FenceMesh")
    v = [(0, -L / 2, 0.08), (0, L / 2, 0.08), (0, L / 2, h), (0, -L / 2, h)]
    mesh_obj(uname("FenceMesh"), v, [(0, 1, 2, 3)], [m], parent=root)
    if solid:
        # invisible 6 m sky wall: pump-speed launches off the ramps peak at 4.4 m and vault a 2.1 m collider
        col_box(uname("Fence"), (0.2, L, 6.0), (0, 0, 3.0), parent=root)


def hedge(root, L=6.0, h=1.3, w=1.1):
    loft_box(uname("Hedge"), (w, L), (w * 0.75, L * 0.98), 0.0, h, M("LeafC"), parent=root)
    col_box(uname("Hedge"), (w, L, h + 0.5), (0, 0, (h + 0.5) / 2), parent=root)


def banner(root, text, color="Purple", w=3.6, h=1.3, z=1.2):
    """Two posts and a coloured cloth; Godot adds the lettering from the Text_ marker."""
    for sx in (-1, 1):
        cyl_z(uname("BannerPost"), (sx * (w / 2 + 0.1), 0, 0), z + h + 0.3, 0.06, M("Ink"), seg=6, smooth=False, parent=root)
    box(uname("Banner"), (w, 0.06, h), (0, 0, z + h / 2), M(color), parent=root)
    box(uname("BannerTrim"), (w + 0.12, 0.05, 0.1), (0, 0, z + h + 0.04), M("White"), parent=root)
    label(root, text, (0, 0.04, z + h / 2), size=h)
    col_box(uname("Banner"), (w + 0.4, 0.3, z + h + 0.3), (0, 0, (z + h + 0.3) / 2), parent=root)


def flower_bed(root, L=3.0, W=1.2, seed=0):
    rnd = random.Random(seed)
    box(uname("BedBorder"), (W, L, 0.22), (0, 0, 0.11), M("Curb"), parent=root)
    box(uname("BedSoil"), (W - 0.2, L - 0.2, 0.05), (0, 0, 0.24), M("Dirt"), parent=root)
    for _ in range(int(L * 4)):
        c = rnd.choice(["Flower", "Yellow", "White", "Orange", "Purple"])
        ico(uname("Flower"), (rnd.uniform(-W / 2 + 0.2, W / 2 - 0.2), rnd.uniform(-L / 2 + 0.2, L / 2 - 0.2), 0.34),
            0.1, M(c), sub=0, parent=root)
    col_box(uname("Bed"), (W, L, 0.3), (0, 0, 0.15), parent=root)


def kiosk(root, w=7.0, d=5.0, h=3.4, wall="Cream", trim="Teal", name="SKATE SHOP"):
    """The little skate shop by the park entrance. Local +Y is the front."""
    box(uname("Wall_Kiosk") + "-col", (w, d, h), (0, 0, h / 2), M(wall), parent=root)
    loft_box(uname("KioskRoof"), (w + 0.9, d + 0.9), (w * 0.55, d * 0.4), h, h + 0.9, M("Roof"), parent=root)
    box(uname("KioskBase"), (w + 0.1, d + 0.1, 0.35), (0, 0, 0.17), M("ConcreteDk"), parent=root)
    y = d / 2
    box(uname("Awning"), (w - 0.6, 1.0, 0.14), (0, y + 0.5, 2.7), M(trim), parent=root)
    for i in range(4):
        sx = -w / 2 + 0.9 + i * (w - 1.8) / 3
        box(uname("AwningStripe"), (0.5, 1.02, 0.15), (sx, y + 0.5, 2.7), M("White"), parent=root)
    for sx in (-1.9, 1.9):
        box(uname("KioskWindow"), (1.9, 0.06, 1.3), (sx, y + 0.02, 1.55), M("Window"), parent=root)
        box(uname("KioskFrame"), (2.1, 0.05, 1.5), (sx, y + 0.005, 1.55), M("White"), parent=root)
    box(uname("KioskDoor"), (0.9, 0.06, 2.0), (0, y + 0.02, 1.0), M("Orange"), parent=root)
    # board rack on the wall
    for i, c in enumerate(("Pink", "Yellow", "Blue")):
        box(uname("RackDeck"), (0.3, 0.05, 0.95), (-w / 2 + 0.7 + i * 0.42, y + 0.05, 1.5), M(c), parent=root)
    box(uname("Sign"), (w - 1.0, 0.16, 0.9), (0, y + 0.1, h - 0.45), M("Navy"), parent=root)
    label(root, name, (0, y + 0.2, h - 0.45), size=0.7)


def house(root, w=9.0, d=8.0, h=5.0, wall="Cream", roof="Roof", seed=0):
    rnd = random.Random(seed)
    box(uname("House"), (w, d, h), (0, 0, h / 2), M(wall), parent=root)
    loft_box(uname("HouseRoof"), (w + 1.0, d + 1.0), (w * 0.3, d * 0.5), h, h + 2.0, M(roof), parent=root)
    for i in range(3):
        sx = -w / 2 + w * (i + 0.5) / 3
        box(uname("HouseWin"), (1.2, 0.06, 1.2), (sx, d / 2 + 0.02, h * 0.62), M("Window"), parent=root)
    box(uname("HouseDoor"), (1.0, 0.06, 2.0), (rnd.choice([-1, 1]) * 1.2, d / 2 + 0.02, 1.0), M("Blue"), parent=root)
    col_box(uname("House"), (w, d, h + 1), (0, 0, (h + 1) / 2), parent=root)


def stair_set(root, n=6, rise=0.19, run=0.44, W=2.6):
    """Kicker-fed platform with a stair set down the far side and a rail on each side.
    Local origin = top of the stairs; skaters ride toward +Y."""
    Ht = n * rise
    stair_rail(root, n=n, rise=rise, run=run, W=W)
    bank(empty(uname("Feed"), (0, -1.6 - 3.4, 0), 0.0, root), W=W, L=3.4, H=Ht)
