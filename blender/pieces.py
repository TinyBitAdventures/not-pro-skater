"""
Modular skate-park kit: ramps, banks, boxes, ledges, rails and stairs.

Every builder takes a `root` empty and builds in the piece's local space:
  local +Y is the piece's main axis (the direction a skater rides into a ramp),
  local +X is its width, local +Z is up, origin on the ground at the piece centre.
Level scripts place the roots (see neighborhood.py, greybox.py), so pieces can be reused and rotated freely.
"""

import math
import random

from mathutils import Vector

from lib import (box, col_box, cyl_between, cyl_z, empty, grind_line, loft_box, mat, mesh_obj, orient_up, prism, quad,
                 uname)

PALETTE = {
    "Galv": "#9ea4a8", "Steel": "#8a8f94", "SidePaint": "#3c4a55", "Timber": "#6e5a44",
    "Wood": "#eaa964", "WoodB": "#d99552", "Navy": "#39415f", "Metal": "#bcc7d8", "MetalDk": "#7d8aa0",
    "Concrete": "#c9d0db", "Plaza": "#b7c2d4", "ConcreteDk": "#9ba7b8", "Path": "#8a97aa", "Grass": "#6fc84c",
    "Orange": "#ff8a3d", "Blue": "#3d9bff", "Green": "#3fc66d", "Purple": "#8a5cf0", "Red": "#ff5a5a",
    "Yellow": "#ffd23f", "Teal": "#1fc2b0", "Pink": "#ff7eb6", "Road": "#59637a", "Collision": "#ff00ff",
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
    """Deck railing from p0 to p1 (x, y) standing on height z: galvanized pipe (48 mm top rail, 42 mm mid rail and
    posts), like the rails bolted round a real mini ramp deck. `colors` is kept for old callers and unused."""
    a, b = Vector((*p0, 0)), Vector((*p1, 0))
    L = (b - a).length
    n = max(1, int(round(L / post_every)))
    galv = M("Galv")
    for i in range(n + 1):
        p = a.lerp(b, i / n)
        cyl_z(uname("RailPost"), (p.x, p.y, z), h, 0.021, galv, seg=10, parent=root)
        cyl_z(uname("RailFoot"), (p.x, p.y, z), 0.012, 0.055, galv, seg=10, parent=root)     # base flange
    cyl_between(uname("RailBar"), (a.x, a.y, z + h), (b.x, b.y, z + h), 0.024, galv, seg=12, parent=root)
    cyl_between(uname("RailBar"), (a.x, a.y, z + h * 0.52), (b.x, b.y, z + h * 0.52), 0.021, galv, seg=12, parent=root)
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
    if H > 0.9:
        ramp_details(root, W, R, H, D, yt)
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


def ramp_details(root, W, R, H, D, yt):
    """What makes a quarter pipe read as built: a steel plate at the foot where the wheels meet the ground,
    painted plywood side sheets set just proud of the side walls with a dark timber edge along the profile,
    and the deck's front fascia under the coping."""
    steel = M("Steel")
    side = M("SidePaint")
    edge = M("Timber")
    # the foot plate: 30 cm of steel over the first bit of transition (8 mm proud: at 4 mm its depth tied with the
    # ramp's at a distance and the two flickered)
    n = 6
    pts = []
    for i in range(n + 1):
        y = 0.3 * i / n
        pts.append((y, profile_z(R, H, y) + 0.008))
    for i in range(n):
        (y0, z0), (y1, z1) = pts[i], pts[i + 1]
        quad(uname("Metal_FootPlate"), (-W / 2 + 0.02, y0, z0), (W / 2 - 0.02, y0, z0), (W / 2 - 0.02, y1, z1),
             (-W / 2 + 0.02, y1, z1), steel, parent=root)
    # side sheets and a timber strip following the curve on both ends
    prof = [(y, profile_z(R, H, y)) for y in [yt * i / 16 for i in range(17)]] + [(yt + D, H)]
    for sx in (-1, 1):
        x = sx * (W / 2 + 0.006)
        outline = [(0.0, 0.0)] + prof + [(yt + D, 0.0)]
        verts = [(x, y, z) for (y, z) in outline]
        face = list(range(len(verts)))
        if sx < 0:
            face.reverse()
        sheet = mesh_obj(uname("SideSheet"), verts, [tuple(face)], [side], parent=root)
        orient_up(sheet.data, expect=(sx, 0, 0))            # facing out from the ramp
        for (y0, z0), (y1, z1) in zip(prof, prof[1:]):
            box_strip(root, x + sx * 0.004, (y0, z0), (y1, z1), edge)
    # deck fascia: a timber board under the coping across the ramp's width
    box(uname("Fascia"), (W, 0.03, 0.16), (0, yt + 0.02, H - 0.1), edge, parent=root)


def box_strip(root, x, a, b, m, w=0.05, t=0.012):
    """A thin strip on a side wall from profile point a to b (y, z), 5 cm wide."""
    import math as _m
    (y0, z0), (y1, z1) = a, b
    L = _m.hypot(y1 - y0, z1 - z0)
    if L < 1e-4:
        return
    # built at the origin, then placed: lib.box bakes its centre into the vertices, so rotating it in place
    # would swing it round the ramp's origin
    ob = box(uname("Timber_Edge"), (t, L + 0.01, w), (0.0, 0.0, -w * 0.5), m, parent=root)
    ob.location = (x, (y0 + y1) / 2, (z0 + z1) / 2)
    ob.rotation_euler = (_m.atan2(z1 - z0, y1 - y0), 0.0, 0.0)


def kicker(root, W=2.8, R=5.0, H=0.75):
    quarter_pipe(root, W=W, R=R, H=H, D=0.0, coping=False, rails=False, decals=False)


def hip(root, W=2.6, R=5.0, H=0.55):
    """Two kickers back to back (crest at local y=0): rideable in both directions on the ring."""
    yt = R * math.sin(math.acos(1 - H / R))
    kicker(empty(uname("Hip"), (0, -yt, 0), 0.0, root), W=W, R=R, H=H)
    kicker(empty(uname("Hip"), (0, yt, 0), math.pi, root), W=W, R=R, H=H)


def mini_ramp(root, W=7.0, R=2.7, H=1.75, F=5.0, D=1.8, seed=3, decals=True):
    """Two facing quarter pipes with a flat between them; the flat is the plaza slab."""
    yt = R * math.sin(math.acos(1 - H / R))
    left = empty(uname("Half"), (0, -F / 2, 0), math.pi, root)
    right = empty(uname("Half"), (0, F / 2, 0), 0.0, root)
    quarter_pipe(left, W=W, R=R, H=H, D=D, seed=seed, decals=decals)
    quarter_pipe(right, W=W, R=R, H=H, D=D, seed=seed + 1, decals=decals)
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


def stair_set(root, n=6, rise=0.19, run=0.44, W=2.6):
    """Kicker-fed platform with a stair set down the far side and a rail on each side.
    Local origin = top of the stairs; skaters ride toward +Y."""
    Ht = n * rise
    stair_rail(root, n=n, rise=rise, run=run, W=W)
    bank(empty(uname("Feed"), (0, -1.6 - 3.4, 0), 0.0, root), W=W, L=3.4, H=Ht)
