"""
Park dressing builders (same contract as pieces.py: `fn(root, **kw)`, local +Y forward, origin on the ground).
Registered into park.BUILDERS by dressing.py. Collision only on solid things a skater could bump; flags,
balloons, paint, kites and the like are visual only.
"""

import math
import random

import bmesh  # noqa: F401
import bpy  # noqa: F401
from mathutils import Vector

from lib import (box, col_box, cyl_between, cyl_z, empty, ico, loft_box, mesh_obj, orient_up, prism, quad, uname)
from pieces import M

# --------------------------------------------------------------------------
# small helpers
# --------------------------------------------------------------------------


def rbox(name, size, center, m, rot=(0, 0, 0), parent=None):
    """Box rotated about its own centre."""
    ob = box(name, size, (0, 0, 0), m, parent=parent)
    ob.location = center
    ob.rotation_euler = rot
    return ob


def rcol(name, size, center, rot=(0, 0, 0), parent=None, surface="Wall"):
    ob = col_box(name, size, (0, 0, 0), parent=parent, surface=surface)
    ob.location = center
    ob.rotation_euler = rot
    return ob


def poly(name, pts, m, parent=None, expect=(0, 1, 0)):
    """Flat n-gon (any simple polygon, 3D points) oriented so its normal faces `expect`."""
    ob = mesh_obj(name, pts, [tuple(range(len(pts)))], [m], parent=parent)
    orient_up(ob.data, expect)
    return ob


def bar(parent, p0, p1, r, m, seg=4):
    return cyl_between(uname("Bar"), p0, p1, r, m, seg=seg, smooth=False, caps=False, parent=parent)


# --------------------------------------------------------------------------
# bleachers
# --------------------------------------------------------------------------

TD, RH = 0.85, 0.42          # tread depth, row rise


def bleacher_geom(rows, w):
    D = rows * TD + 0.6
    yf = D / 2 - 0.3
    return D, yf, yf - rows * TD


def bleacher_seats(rows=4, w=8.0, pitch=0.78):
    """Local (x, y, z, row) surface points on the treads where a seated spectator's hips go."""
    D, yf, yb = bleacher_geom(rows, w)
    out = []
    n = max(1, int((w - 0.8) / pitch))
    for k in range(rows):
        y = yf - TD * (k + 0.5) - 0.13
        z = RH * (k + 1)
        for i in range(n):
            out.append((-w / 2 + 0.4 + (i + 0.5) * (w - 0.8) / n, y, z, k))
    return out


def _stair_pts(rows, yf):
    pts = [(yf, 0.0)]
    for k in range(rows):
        pts += [(yf - TD * k, RH * (k + 1)), (yf - TD * (k + 1), RH * (k + 1))]
    pts.append((yf - TD * rows, 0.0))
    return pts


def bleachers(root, rows=4, w=8.0, panel=("Blue", "Orange"), rail="Yellow"):
    """Wood-seat stand rising toward -Y; spectators face +Y. Solid collision block (Wood_)."""
    D, yf, yb = bleacher_geom(rows, w)
    riser_cols = ["Teal", "Purple", "Orange", "Blue", "Pink"]
    for k in range(rows):
        yc = yf - TD * (k + 0.5)
        zt = RH * (k + 1)
        box(uname("Tread"), (w, TD, 0.08), (0, yc, zt - 0.04), M("Wood" if k % 2 == 0 else "WoodB"), parent=root)
        box(uname("Riser"), (w, 0.05, RH), (0, yf - TD * k - 0.02, RH * k + RH / 2), M(riser_cols[k % len(riser_cols)]), parent=root)
    pts = _stair_pts(rows, yf)
    n = len(pts)
    for sx, c in ((1, panel[0]), (-1, panel[1])):
        x0, x1 = (w / 2, w / 2 + 0.12) if sx > 0 else (-w / 2 - 0.12, -w / 2)
        prism(uname("EndPanel"), pts, x0, x1, [M(c)], [0] * n, [False] * n, cap_mat=0, parent=root)
    top = RH * rows
    box(uname("BackPanel"), (w, 0.06, top), (0, yb - 0.02, top / 2), M("MetalDk"), parent=root)
    # guard rails: back run + a sloped run down each side
    xs = (-w / 2 - 0.06, 0.0, w / 2 + 0.06)
    for x in xs:
        box(uname("RailPost"), (0.08, 0.08, 1.0), (x, yb - 0.04, top + 0.5), M("MetalDk"), parent=root)
    for dz in (1.0, 0.5):
        bar(root, (-w / 2 - 0.06, yb - 0.04, top + dz), (w / 2 + 0.06, yb - 0.04, top + dz), 0.045, M(rail))
    for sx in (-1, 1):
        x = sx * (w / 2 + 0.06)
        bar(root, (x, yf - 0.1, RH + 0.95), (x, yb - 0.04, top + 0.95), 0.045, M(rail))
        box(uname("RailPost"), (0.08, 0.08, 0.95), (x, yf - 0.1, RH + 0.475), M("MetalDk"), parent=root)
        box(uname("RailPost"), (0.08, 0.08, 0.95), (x, (yf + yb) / 2, RH * (rows + 1) / 2 + 0.475), M("MetalDk"), parent=root)
    prism(uname("Wood_Bleachers") + "-colonly", pts, -w / 2 - 0.12, w / 2 + 0.12, [M("Collision")], [0] * n, [False] * n, cap_mat=0, parent=root)


# --------------------------------------------------------------------------
# festive stuff: bunting, balloons
# --------------------------------------------------------------------------

FLAG_COLORS = ["Red", "Yellow", "Blue", "Green", "Orange", "Pink", "Purple", "Teal"]


def bunting(root, L=5.4, h=2.3, sag=0.3, colors=None, phase=0):
    """String of small triangular flags along local X from -L/2 to +L/2 at height h (sagging by `sag`)."""
    colors = colors or FLAG_COLORS
    mats = [M(c) for c in colors]
    n = max(3, int(L / 0.6))
    verts, faces, fm = [], [], []

    def zat(t):
        return h - sag * 4 * t * (1 - t)

    for i in range(n):
        t = (i + 0.5) / n
        x = -L / 2 + L * t
        z = zat(t)
        b = len(verts)
        tri = [(x - 0.17, 0, z), (x + 0.17, 0, z), (x, 0, z - 0.42)]
        verts += tri + tri                  # second copy = the back side (own vertices keep the mesh valid)
        faces += [(b, b + 1, b + 2), (b + 5, b + 4, b + 3)]
        fm += [(i + phase) % len(mats)] * 2
    mesh_obj(uname("BuntingFlags"), verts, faces, mats, face_mats=fm, parent=root)
    seg = 8
    for k in range(seg):
        t0, t1 = k / seg, (k + 1) / seg
        cyl_between(uname("BuntingString"), (-L / 2 + L * t0, 0, zat(t0)), (-L / 2 + L * t1, 0, zat(t1)), 0.02, M("Ink"),
                    seg=3, smooth=False, caps=False, parent=root)


def balloons(root, n=6, seed=0, zmax=3.4):
    rnd = random.Random(seed)
    cyl_z(uname("BalloonWeight"), (0, 0, 0), 0.14, 0.13, M("Ink"), r1=0.1, seg=6, smooth=False, parent=root)
    cols = list(FLAG_COLORS)
    rnd.shuffle(cols)
    for i in range(n):
        a = 2 * math.pi * i / n + rnd.uniform(-0.3, 0.3)
        d = rnd.uniform(0.15, 0.45)
        top = (math.cos(a) * d, math.sin(a) * d, zmax - rnd.uniform(0, 0.9))
        bar(root, (0, 0, 0.12), (top[0], top[1], top[2] - 0.3), 0.012, M("White"), seg=3)
        ico(uname("Balloon"), (top[0], top[1], top[2]), 0.29, M(cols[i % len(cols)]), sub=1, squash=(0.9, 0.9, 1.15), parent=root,
            smooth=True)


# --------------------------------------------------------------------------
# mural / graffiti wall
# --------------------------------------------------------------------------

def _star(cx, cz, R, r, k=5, rot=math.pi / 2):
    pts = []
    for i in range(2 * k):
        a = rot + math.pi * i / k
        rr = R if i % 2 == 0 else r
        pts.append((cx + rr * math.cos(a), cz + rr * math.sin(a)))
    return pts


def mural_wall(root, L=15.0, h=2.2, seed=0):
    """Low wall of coloured panels, front (painted) side = local +Y. Stars, bolts, block faces, targets, zigzags."""
    rnd = random.Random(seed)
    T = 0.34
    pw = 3.0
    n = max(1, int(round(L / pw)))
    pw = L / n
    bases = ["Purple", "Teal", "Orange", "Blue", "Pink", "Green"]
    shapes = ["star", "bolt", "face", "target", "zigzag", "star", "face"]
    rnd.shuffle(shapes)
    yf = T / 2 + 0.012
    box(uname("Wall_Mural") + "-col", (L, T, h), (0, 0, h / 2), M("Ink"), parent=root)
    for i in range(n):
        cx = -L / 2 + pw * (i + 0.5)
        base = bases[(i + seed) % len(bases)]
        box(uname("MuralPanel"), (pw - 0.06, T + 0.02, h - 0.3), (cx, 0, 0.3 + (h - 0.3) / 2), M(base), parent=root)
        sh = shapes[i % len(shapes)]
        cz = 0.3 + (h - 0.3) / 2
        if sh == "star":
            poly(uname("MuralStar"), [(x + cx, yf, z) for x, z in _star(0, cz, 0.72, 0.3)], M("Yellow"), parent=root)
            poly(uname("MuralStar"), [(x + cx - 0.9, yf, z + 0.32) for x, z in _star(0, 0, 0.26, 0.11)], M("White"), parent=root)
            poly(uname("MuralStar"), [(x + cx + 0.95, yf, z - 0.3) for x, z in _star(0, cz, 0.22, 0.09)], M("White"), parent=root)
        elif sh == "bolt":
            b = [(-0.15, 0.85), (0.4, 0.85), (0.12, 0.2), (0.5, 0.2), (-0.3, -0.85), (-0.05, -0.05), (-0.5, -0.05)]
            poly(uname("MuralBolt"), [(cx + x * 0.85, yf, cz + z * 0.85) for x, z in b], M("Yellow"), parent=root)
            poly(uname("MuralBolt"), [(cx + x * 0.5 + 0.9, yf, cz + z * 0.5 - 0.1) for x, z in b], M("White"), parent=root)
        elif sh == "face":
            box(uname("MuralFace"), (1.3, 0.05, 1.3), (cx, yf, cz), M("Yellow"), parent=root)
            for sx in (-1, 1):
                box(uname("MuralEye"), (0.2, 0.06, 0.28), (cx + sx * 0.3, yf + 0.01, cz + 0.2), M("Ink"), parent=root)
                box(uname("MuralCheek"), (0.2, 0.06, 0.12), (cx + sx * 0.5, yf + 0.01, cz - 0.15), M("Pink"), parent=root)
            box(uname("MuralMouth"), (0.6, 0.06, 0.1), (cx, yf + 0.01, cz - 0.28), M("Ink"), parent=root)
            box(uname("MuralHair"), (1.3, 0.06, 0.22), (cx, yf + 0.01, cz + 0.76), M("Orange"), parent=root)
            box(uname("MuralHair"), (0.5, 0.06, 0.2), (cx + 0.4, yf + 0.01, cz + 0.98), M("Orange"), parent=root)
        elif sh == "target":
            for r, c in ((0.85, "Red"), (0.6, "White"), (0.35, "Blue"), (0.14, "Yellow")):
                zz = {0.85: 0, 0.6: 0.012, 0.35: 0.024, 0.14: 0.036}[r]
                cyl_between(uname("MuralTarget"), (cx, yf + zz, cz), (cx, yf + zz + 0.02, cz), r, M(c), seg=10, smooth=False,
                            parent=root)
        else:  # zigzag stripes
            for k in range(4):
                z0 = cz - 0.75 + k * 0.42
                c = ["White", "Yellow", "Ink", "Pink"][k]
                poly(uname("MuralZig"), [(cx - 1.2, yf, z0), (cx, yf, z0 + 0.28), (cx + 1.2, yf, z0), (cx + 1.2, yf, z0 + 0.2),
                                        (cx, yf, z0 + 0.48), (cx - 1.2, yf, z0 + 0.2)], M(c), parent=root)
    for i in range(n + 1):
        x = -L / 2 + pw * i
        box(uname("MuralPier"), (0.3, T + 0.1, h + 0.05), (x, 0, (h + 0.05) / 2), M("Navy"), parent=root)
    box(uname("MuralCoping"), (L + 0.2, T + 0.14, 0.14), (0, 0, h + 0.07), M("White"), parent=root)
    box(uname("MuralBase"), (L, T + 0.06, 0.3), (0, 0, 0.15), M("Ink"), parent=root)
    col_box(uname("Mural"), (L, 0.5, h + 3.0), (0, 0, (h + 3.0) / 2), parent=root)


# --------------------------------------------------------------------------
# pond
# --------------------------------------------------------------------------

WATER_Z = 0.12
RIM_TOP = 0.32


def pond_outline(r, seed, n=14):
    rnd = random.Random(seed)
    p1, p2, p3 = (rnd.uniform(0, 6.28) for _ in range(3))
    out = []
    for i in range(n):
        a = 2 * math.pi * i / n
        rr = r * (1 + 0.13 * math.sin(2 * a + p1) + 0.09 * math.sin(3 * a + p2) + 0.05 * math.sin(5 * a + p3))
        out.append((rr * math.cos(a), rr * math.sin(a), a))
    return out


def pond(root, r=5.0, seed=3, jetty_deg=205.0):
    rnd = random.Random(seed)
    o = pond_outline(r, seed)
    n = len(o)
    verts = [(0, 0, WATER_Z)] + [(x, y, WATER_Z) for x, y, a in o]
    faces = [(0, 1 + i, 1 + (i + 1) % n) for i in range(n)]
    w = mesh_obj("Water_Pond", verts, faces, [M("Water")], parent=root)
    orient_up(w.data)
    # wet bank ring under the rim
    bv = [(x * 1.02, y * 1.02, 0.03) for x, y, a in o] + [(x * 1.2 + 0.0, y * 1.2, 0.03) for x, y, a in o]
    bf = [(i, (i + 1) % n, n + (i + 1) % n, n + i) for i in range(n)]
    bk = mesh_obj(uname("PondBank"), bv, bf, [M("Dirt")], parent=root)
    orient_up(bk.data)
    ja = math.radians(jetty_deg)
    for i in range(n):
        x0, y0, a0 = o[i]
        x1, y1, a1 = o[(i + 1) % n]
        mx, my = (x0 + x1) / 2 * 1.1, (y0 + y1) / 2 * 1.1
        if abs(math.atan2(math.sin(math.atan2(my, mx) - ja), math.cos(math.atan2(my, mx) - ja))) < 0.2:
            continue        # gap for the jetty
        ang = math.atan2(y1 - y0, x1 - x0)
        ln = math.hypot(x1 - x0, y1 - y0) * 1.12
        hz = RIM_TOP - rnd.uniform(0.0, 0.07)
        rbox(uname("RimStone"), (ln, 0.55, hz), (mx, my, hz / 2), M("Stone" if i % 2 else "StoneDk"), (0, 0, ang), parent=root)
        rcol(uname("PondRim"), (ln, 0.6, 0.5), (mx, my, 0.25), (0, 0, ang), parent=root)
    for k in range(5):
        a = rnd.uniform(0, 2 * math.pi)
        d = rnd.uniform(0.3, 0.65) * r
        x, y = math.cos(a) * d, math.sin(a) * d
        rr = rnd.uniform(0.3, 0.42)
        poly(uname("Lily"), [(x + rr * math.cos(t), y + rr * math.sin(t), WATER_Z + 0.012) for t in [i * math.pi / 3 + k for i in range(6)]],
             M("Lily"), parent=root, expect=(0, 0, 1))
        if k % 2 == 0:
            ico(uname("LilyFlower"), (x + 0.08, y + 0.05, WATER_Z + 0.1), 0.1, M("Pink" if k % 4 == 0 else "White"), sub=0, parent=root)
    for a_deg in (30, 95, 320):
        a = math.radians(a_deg)
        bx, by = math.cos(a) * r * 0.92, math.sin(a) * r * 0.92
        for j in range(4):
            x, y = bx + rnd.uniform(-0.35, 0.35), by + rnd.uniform(-0.35, 0.35)
            top = rnd.uniform(1.0, 1.6)
            bar(root, (x, y, 0.05), (x + rnd.uniform(-0.12, 0.12), y + rnd.uniform(-0.12, 0.12), top), 0.03, M("Reed"), seg=3)
            if j % 2 == 0:
                cyl_between(uname("Cattail"), (x, y, top - 0.15), (x, y, top + 0.12), 0.055, M("Cattail"), seg=4, smooth=False,
                            parent=root)
    for k in range(3):
        a = rnd.uniform(0, 2 * math.pi)
        if abs(math.atan2(math.sin(a - ja), math.cos(a - ja))) < 0.5:
            a += 1.0
        rr = rnd.uniform(0.35, 0.6)
        ico(uname("Rock"), (math.cos(a) * r * 1.3, math.sin(a) * r * 1.3, rr * 0.35), rr, M("Stone" if k % 2 else "StoneDk"), sub=0,
            squash=(1, 1, 0.65), parent=root)
    # jetty (walkable deck, Wood collision), local +Y points into the pond
    jr = empty(uname("Jetty"), (math.cos(ja) * (r * 1.12 + 0.75), math.sin(ja) * (r * 1.12 + 0.75), 0), ja + math.pi / 2, root)
    for i in range(6):
        box(uname("JettyPlank"), (1.3, 0.58, 0.07), (0, 0.3 + i * 0.6, 0.4), M("Wood" if i % 2 == 0 else "WoodB"), parent=jr)
    for sx in (-1, 1):
        for y in (0.3, 3.4):
            box(uname("JettyPost"), (0.14, 0.14, 0.75), (sx * 0.62, y, 0.375), M("Trunk"), parent=jr)
    col_box(uname("Jetty"), (1.3, 3.7, 0.45), (0, 1.85, 0.22), parent=jr, surface="Wood")


# --------------------------------------------------------------------------
# playground
# --------------------------------------------------------------------------

def swing_set(root, n=3, first_swing=1):
    """A-frame with n swings. Empties `Swing_<k>` sit on the top bar (rotate about local X to swing along +-Y)."""
    W = n * 1.15 + 0.7
    H = 2.75
    for sx in (-1, 1):
        x = sx * W / 2
        for sy in (-1, 1):
            cyl_between(uname("SwingLeg"), (x, sy * 0.95, 0), (x, 0, H), 0.075, M("Red"), seg=6, smooth=False, parent=root)
        rcol(uname("SwingFrame"), (0.3, 2.0, H), (x, 0, H / 2), parent=root, surface="Metal")
    cyl_between(uname("SwingBar"), (-W / 2 - 0.15, 0, H), (W / 2 + 0.15, 0, H), 0.08, M("Blue"), seg=6, smooth=False, parent=root)
    cols = ["Yellow", "Green", "Orange", "Pink"]
    for i in range(n):
        x = -W / 2 + 0.35 + 0.35 + i * (W - 1.4) / max(1, n - 1) if n > 1 else 0
        piv = empty(f"Swing_{first_swing + i}", (x, 0, H - 0.08), 0, root, size=0.2)
        for sx in (-1, 1):
            bar(piv, (sx * 0.22, 0, 0), (sx * 0.22, 0, -2.0), 0.015, M("MetalDk"), seg=3)
        box(uname("SwingSeat"), (0.5, 0.22, 0.06), (0, 0, -2.03), M(cols[i % len(cols)]), parent=piv)


def slide(root):
    """Tower with a ladder on the -Y side and a slide running out toward +Y."""
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(uname("SlidePost"), (0.1, 0.1, 1.9), (sx * 0.6, sy * 0.6, 0.95), M("MetalDk"), parent=root)
    box(uname("SlideDeck"), (1.4, 1.4, 0.08), (0, 0, 1.6), M("Yellow"), parent=root)
    loft_box(uname("SlideRoof"), (1.9, 1.9), (0.3, 0.3), 1.9, 2.5, M("Red"), parent=root)
    for sx in (-1, 1):
        box(uname("SlideRail"), (0.06, 1.4, 0.4), (sx * 0.7, 0, 1.85), M("Blue"), parent=root)
    box(uname("SlideRail"), (1.4, 0.06, 0.4), (0, -0.7, 1.85), M("Blue"), parent=root)
    for k in range(5):
        box(uname("Rung"), (0.55, 0.05, 0.05), (0, -0.98 + k * 0.03, 0.3 + k * 0.32), M("Metal"), parent=root)
    for sx in (-1, 1):
        rbox(uname("LadderSide"), (0.06, 0.05, 1.75), (sx * 0.3, -0.98, 0.9), M("MetalDk"), parent=root)
    y0, z0, y1, z1 = 0.7, 1.6, 3.5, 0.28
    L = math.hypot(y1 - y0, z1 - z0)
    ang = math.atan2(z1 - z0, y1 - y0)
    mid = ((y0 + y1) / 2, (z0 + z1) / 2)
    rbox(uname("SlideChute"), (0.72, L, 0.06), (0, mid[0], mid[1]), M("Blue"), (ang, 0, 0), parent=root)
    for sx in (-1, 1):
        rbox(uname("SlideWall"), (0.06, L, 0.2), (sx * 0.39, mid[0], mid[1] + 0.09), M("Yellow"), (ang, 0, 0), parent=root)
    rcol(uname("SlideTower"), (1.6, 1.6, 2.0), (0, 0, 1.0), parent=root, surface="Metal")
    rcol(uname("SlideChute"), (0.8, L, 0.16), (0, mid[0], mid[1]), (ang, 0, 0), parent=root, surface="Metal")


def sandbox(root, s=2.6):
    for sg in (-1, 1):
        box(uname("SandBoard"), (s, 0.14, 0.32), (0, sg * (s / 2 - 0.07), 0.16), M("Wood"), parent=root)
        box(uname("SandBoard"), (0.14, s - 0.28, 0.32), (sg * (s / 2 - 0.07), 0, 0.16), M("WoodB"), parent=root)
    box(uname("SandFill"), (s - 0.28, s - 0.28, 0.04), (0, 0, 0.26), M("Sand"), parent=root)
    cyl_z(uname("Bucket"), (0.55, 0.45, 0.28), 0.26, 0.15, M("Red"), r1=0.11, seg=8, smooth=False, parent=root)
    box(uname("Shovel"), (0.05, 0.5, 0.03), (-0.5, 0.3, 0.34), M("Blue"), parent=root)
    box(uname("Shovel"), (0.16, 0.14, 0.03), (-0.5, 0.58, 0.34), M("Blue"), parent=root)
    loft_box(uname("Sandcastle"), (0.55, 0.55), (0.42, 0.42), 0.28, 0.5, M("Cream"), center=(-0.3, -0.35), parent=root)
    loft_box(uname("Sandcastle"), (0.3, 0.3), (0.2, 0.2), 0.5, 0.66, M("Cream"), center=(-0.3, -0.35), parent=root)
    col_box(uname("Sandbox"), (s, s, 0.34), (0, 0, 0.17), parent=root, surface="Wood")


def seesaw(root):
    prism(uname("SeesawBase"), [(-0.32, 0), (0.32, 0), (0, 0.6)], -0.14, 0.14, [M("Metal")], [0, 0, 0], [False] * 3, cap_mat=0,
          parent=root)
    tilt = math.radians(-10)
    plank = empty(uname("SeesawTilt"), (0, 0, 0.62), 0, root)
    plank.rotation_euler = (tilt, 0, 0)
    box(uname("SeesawPlank"), (0.42, 3.2, 0.09), (0, 0, 0), M("Yellow"), parent=plank)
    for sg in (-1, 1):
        box(uname("SeesawHandle"), (0.5, 0.06, 0.05), (0, sg * 1.15, 0.2), M("Red"), parent=plank)
        box(uname("SeesawHandlePost"), (0.05, 0.05, 0.2), (0, sg * 1.15, 0.1), M("Red"), parent=plank)
    # the low end (+Y for a negative tilt) rests on a tyre
    cyl_z(uname("SeesawTyre"), (0, 1.55 * math.cos(tilt), 0), 0.34, 0.17, M("Ink"), seg=6, smooth=False, parent=root)
    rcol(uname("SeesawBase"), (0.4, 0.7, 0.65), (0, 0, 0.32), parent=root, surface="Metal")
    rcol(uname("SeesawPlank"), (0.5, 3.2, 0.2), (0, 0, 0.62), (tilt, 0, 0), parent=root, surface="Wood")


def climber(root, s=2.4):
    h = s
    cols = ["Red", "Blue", "Yellow"]
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(uname("ClimbPost"), (0.1, 0.1, h), (sx * s / 2, sy * s / 2, h / 2), M("Red"), parent=root)
    for zi, z in enumerate((h, h * 0.55)):
        c = M(cols[(zi + 1) % 3])
        for sg in (-1, 1):
            box(uname("ClimbBeam"), (s + 0.1, 0.08, 0.08), (0, sg * s / 2, z), c, parent=root)
            box(uname("ClimbBeam"), (0.08, s + 0.1, 0.08), (sg * s / 2, 0, z), c, parent=root)
    for x in (-s / 6, s / 6):
        for sg in (-1, 1):
            box(uname("ClimbRung"), (0.06, 0.06, h), (x, sg * s / 2, h / 2), M("Yellow"), parent=root)
    box(uname("ClimbDeck"), (s * 0.55, s * 0.55, 0.08), (0, 0, h * 0.55 + 0.04), M("Green"), parent=root)
    loft_box(uname("ClimbRoof"), (s * 0.7, s * 0.7), (0.2, 0.2), h + 0.04, h + 0.6, M("Orange"), parent=root)
    col_box(uname("Climber"), (s + 0.2, s + 0.2, h + 0.4), (0, 0, (h + 0.4) / 2), parent=root, surface="Metal")


def play_pad(root, w=14.0, d=10.0):
    box(uname("PlayPad"), (w, d, 0.04), (0, 0, 0.02), M("Rubber"), parent=root)
    for sx in (-1, 1):
        box(uname("PadEdge"), (0.14, d + 0.14, 0.09), (sx * (w / 2 + 0.07), 0, 0.045), M("Curb"), parent=root)
    for sy in (-1, 1):
        box(uname("PadEdge"), (w + 0.28, 0.14, 0.09), (0, sy * (d / 2 + 0.07), 0.045), M("Curb"), parent=root)


# --------------------------------------------------------------------------
# street
# --------------------------------------------------------------------------

def street_lamp(root, h=5.4, col=False):
    cyl_z(uname("LampPole"), (0, 0, 0), h, 0.1, M("Navy"), r1=0.06, seg=6, smooth=False, parent=root)
    cyl_z(uname("LampBase"), (0, 0, 0), 0.5, 0.17, M("Navy"), seg=6, smooth=False, parent=root)
    bar(root, (0, 0, h - 0.1), (1.3, 0, h + 0.2), 0.05, M("Navy"), seg=4)
    box(uname("LampHead"), (0.75, 0.32, 0.14), (1.4, 0, h + 0.2), M("Navy"), parent=root)
    box(uname("LampBulb"), (0.6, 0.24, 0.05), (1.4, 0, h + 0.11), M("Lamp"), parent=root)
    if col:
        col_box(uname("Lamp"), (0.3, 0.3, 2.5), (0, 0, 1.25), parent=root)


def hydrant(root):
    cyl_z(uname("Hydrant"), (0, 0, 0), 0.62, 0.17, M("Red"), r1=0.15, seg=8, smooth=False, parent=root)
    ico(uname("HydrantTop"), (0, 0, 0.66), 0.17, M("Red"), sub=1, squash=(1, 1, 0.8), parent=root)
    cyl_between(uname("HydrantNozzle"), (-0.24, 0, 0.4), (0.24, 0, 0.4), 0.07, M("Yellow"), seg=6, smooth=False, parent=root)
    cyl_z(uname("HydrantBase"), (0, 0, 0), 0.08, 0.22, M("MetalDk"), seg=8, smooth=False, parent=root)


def mailbox(root, color="Blue"):
    cyl_z(uname("MailPost"), (0, 0, 0), 1.0, 0.05, M("Ink"), seg=4, smooth=False, parent=root)
    box(uname("MailBox"), (0.36, 0.55, 0.3), (0, 0, 1.15), M(color), parent=root)
    prism(uname("MailTop"), [(-0.27, 0.0), (0.27, 0.0), (0.2, 0.1), (-0.2, 0.1)], -0.18, 0.18, [M(color)], [0] * 4, [False] * 4,
          cap_mat=0, parent=root, loc=(0, 0, 1.3))
    box(uname("MailFlag"), (0.04, 0.16, 0.14), (0.2, 0.15, 1.3), M("Red"), parent=root)


def bus_stop(root):
    """Shelter open toward local +Y (the road)."""
    for sx in (-1, 1):
        box(uname("ShelterPost"), (0.12, 0.12, 2.5), (sx * 1.6, -0.6, 1.25), M("Navy"), parent=root)
        box(uname("ShelterPost"), (0.12, 0.12, 2.5), (sx * 1.6, 0.7, 1.25), M("Navy"), parent=root)
        box(uname("ShelterSide"), (0.05, 1.3, 1.6), (sx * 1.6, 0.05, 1.3), M("Window"), parent=root)
    box(uname("ShelterBack"), (3.2, 0.05, 1.7), (0, -0.62, 1.35), M("Window"), parent=root)
    box(uname("ShelterRoof"), (3.7, 1.9, 0.14), (0, 0.05, 2.58), M("Teal"), parent=root)
    box(uname("ShelterBench"), (2.2, 0.4, 0.07), (0, -0.35, 0.5), M("Wood"), parent=root)
    for sx in (-1, 1):
        box(uname("ShelterBenchLeg"), (0.08, 0.36, 0.5), (sx * 0.95, -0.35, 0.25), M("MetalDk"), parent=root)
    cyl_z(uname("BusSignPole"), (2.1, 0.6, 0), 2.7, 0.045, M("MetalDk"), seg=4, smooth=False, parent=root)
    cyl_between(uname("BusSign"), (2.1, 0.6, 2.55), (2.1, 0.66, 2.55), 0.34, M("Blue"), seg=8, smooth=False, parent=root)
    cyl_between(uname("BusSignB"), (2.1, 0.66, 2.55), (2.1, 0.68, 2.55), 0.22, M("White"), seg=8, smooth=False, parent=root)


def car(root, variant="hatch", color="CarBody"):
    from car import build_car
    build_car(variant, root, pivots=False, body=color)


# --------------------------------------------------------------------------
# extras
# --------------------------------------------------------------------------

def sandwich_board(root, color="Orange"):
    """A-frame board, painted face toward local +Y."""
    t = math.radians(13)
    for sg in (-1, 1):
        rbox(uname("BoardLeg"), (0.7, 0.05, 0.95), (0, sg * 0.2, 0.47), M("Wood"), (sg * t, 0, 0), parent=root)
    rbox(uname("BoardFace"), (0.62, 0.03, 0.78), (0, 0.24, 0.49), M(color), (t, 0, 0), parent=root)
    rbox(uname("BoardText"), (0.42, 0.035, 0.1), (0, 0.235, 0.62), M("White"), (t, 0, 0), parent=root)
    rbox(uname("BoardText"), (0.3, 0.035, 0.08), (0, 0.235, 0.43), M("Yellow"), (t, 0, 0), parent=root)
    col_box(uname("Board"), (0.7, 0.55, 0.95), (0, 0, 0.47), parent=root)


def bike(root, color="Red", loc=(0, 0, 0), rot=0.0):
    b = empty(uname("Bike"), loc, rot, root)
    for y in (-0.42, 0.42):
        cyl_between(uname("BikeWheel"), (-0.03, y, 0.3), (0.03, y, 0.3), 0.3, M("Ink"), seg=8, smooth=False, parent=b)
        cyl_between(uname("BikeHub"), (-0.04, y, 0.3), (0.04, y, 0.3), 0.1, M("Metal"), seg=5, smooth=False, parent=b)
    bar(b, (0, -0.42, 0.3), (0, 0.05, 0.62), 0.03, M(color))
    bar(b, (0, 0.05, 0.62), (0, 0.38, 0.32), 0.03, M(color))
    bar(b, (0, 0.38, 0.32), (0, 0.42, 0.3), 0.03, M(color))
    bar(b, (0, 0.28, 0.98), (0, 0.38, 0.32), 0.03, M(color))
    bar(b, (-0.22, 0.28, 1.0), (0.22, 0.28, 1.0), 0.025, M("Ink"))
    box(uname("BikeSeat"), (0.1, 0.24, 0.05), (0, -0.12, 0.7), M("Ink"), parent=b)


def bike_rack(root, n=4):
    L = n * 0.6
    for i in range(n + 1):
        y = -L / 2 + i * 0.6
        bar(root, (0, y, 0), (0, y, 0.7), 0.035, M("MetalDk"), seg=5)
    cyl_between(uname("RackBar"), (0, -L / 2, 0.7), (0, L / 2, 0.7), 0.035, M("MetalDk"), seg=5, smooth=False, parent=root)
    cols = ["Red", "Blue", "Green", "Yellow"]
    for i in range(min(n - 1, 3)):
        y = -L / 2 + 0.3 + i * 0.6 + 0.3
        bike(root, cols[i], (0.22, y, 0), math.radians(90))
    col_box(uname("BikeRack"), (0.9, L, 1.0), (0, 0, 0.5), parent=root)


def hoop(root):
    cyl_z(uname("HoopPole"), (0, 0, 0), 3.1, 0.09, M("Navy"), seg=6, smooth=False, parent=root)
    box(uname("HoopBase"), (0.6, 0.6, 0.18), (0, 0, 0.09), M("Navy"), parent=root)
    bar(root, (0, 0, 3.0), (0, 0.9, 3.05), 0.05, M("Navy"))
    box(uname("Backboard"), (1.6, 0.06, 1.0), (0, 0.95, 3.35), M("White"), parent=root)
    box(uname("BoardSquare"), (0.6, 0.07, 0.4), (0, 0.97, 3.25), M("Red"), parent=root)
    cyl_z(uname("HoopRim"), (0, 1.25, 3.05), 0.04, 0.32, M("Orange"), seg=8, smooth=False, parent=root)
    cyl_z(uname("HoopNet"), (0, 1.25, 2.65), 0.4, 0.2, M("White"), r1=0.3, seg=6, smooth=False, parent=root)
    col_box(uname("Hoop"), (0.7, 0.7, 3.2), (0, 0, 1.6), parent=root)


def umbrella(root, color="Red", h=2.4, r=1.5):
    cyl_z(uname("UmbrellaPole"), (0, 0, 0), h, 0.04, M("Metal"), seg=4, smooth=False, parent=root)
    seg = 8
    for k in range(seg):
        a0, a1 = 2 * math.pi * k / seg, 2 * math.pi * (k + 1) / seg
        pts = [(0, 0, h + 0.4), (math.cos(a0) * r, math.sin(a0) * r, h), (math.cos(a1) * r, math.sin(a1) * r, h)]
        mesh = mesh_obj(uname("UmbrellaPanel"), pts, [(0, 1, 2)], [M(color if k % 2 == 0 else "White")], parent=root)
        orient_up(mesh.data)


def picnic_blanket(root, color="Red"):
    box(uname("BlanketBase"), (2.2, 1.7, 0.03), (0, 0, 0.02), M(color), parent=root)
    for i in range(4):
        box(uname("BlanketStripe"), (2.2, 0.2, 0.035), (0, -0.65 + i * 0.43, 0.022), M("White"), parent=root)
    box(uname("Basket"), (0.4, 0.3, 0.22), (0.3, 0.1, 0.14), M("Trunk"), parent=root)
    umbrella(empty(uname("Umbrella"), (-1.3, -0.9, 0), 0, root), color="Yellow", h=1.9, r=1.3)


def food_cart(root, color="Orange"):
    box(uname("CartBody"), (2.2, 1.2, 0.9), (0, 0, 0.75), M(color), parent=root)
    box(uname("CartTop"), (2.3, 1.3, 0.08), (0, 0, 1.24), M("White"), parent=root)
    box(uname("CartWindow"), (1.6, 0.05, 0.4), (0, 0.63, 0.9), M("Window"), parent=root)
    for sx in (-1, 1):
        cyl_between(uname("CartWheel"), (sx * 0.6 - 0.05, -0.68, 0.3), (sx * 0.6 + 0.05, -0.68, 0.3), 0.3, M("Ink"), seg=8, smooth=False,
                    parent=root)
    bar(root, (1.1, 0, 0.6), (1.6, 0, 0.75), 0.04, M("MetalDk"))
    umbrella(empty(uname("Umbrella"), (0.9, -0.3, 1.28), 0, root), color="Red", h=1.5, r=1.6)
    box(uname("CartSign"), (1.4, 0.06, 0.4), (0, 0.66, 1.5), M("Yellow"), parent=root)
    col_box(uname("Cart"), (2.4, 1.4, 1.3), (0, 0, 0.65), parent=root)


def kite(root, color="Red", color2="Yellow"):
    for s in (1, -1):
        pts = [(0, 0.55, 0), (0.32, 0, 0), (0, -0.55, 0), (-0.32, 0, 0)][::s]
        mesh_obj(uname("Kite"), pts, [(0, 1, 2, 3)], [M(color)], parent=root)
    mesh_obj(uname("KiteStripe"), [(0, 0.55, 0.003), (0.32, 0, 0.003), (0, 0, 0.003)], [(0, 1, 2)], [M(color2)], parent=root)
    mesh_obj(uname("KiteStripe"), [(0, -0.55, 0.003), (-0.32, 0, 0.003), (0, 0, 0.003)], [(0, 1, 2)], [M(color2)], parent=root)
    for k in range(6):
        y = -0.6 - k * 0.32
        x = math.sin(k * 1.2) * 0.12
        c = (color2, color)[k % 2]
        tri = [(x - 0.09, y, 0), (x + 0.09, y, 0), (x, y - 0.12, 0.07)]
        mesh_obj(uname("KiteBow"), tri + tri, [(0, 1, 2), (5, 4, 3)], [M(c)], parent=root)


def flower_patch(root, r=1.6, seed=0):
    rnd = random.Random(seed)
    for k in range(int(r * 9)):
        a = rnd.uniform(0, 2 * math.pi)
        d = r * math.sqrt(rnd.random())
        c = rnd.choice(["Flower", "Yellow", "White", "Orange", "Purple", "Red"])
        x, y = math.cos(a) * d, math.sin(a) * d
        bar(root, (x, y, 0.0), (x, y, 0.25), 0.012, M("Leaf"), seg=3)
        ico(uname("Bloom"), (x, y, 0.29), 0.08, M(c), sub=0, parent=root)
