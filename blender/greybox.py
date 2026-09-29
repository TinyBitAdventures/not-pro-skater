"""
Greybox test level: every kind of obstacle the skater has to feel right on, laid out in lanes.

Plain surfaces (Godot draws them with a world-space 1 m / 5 m grid), real scale, nothing decorative.
Each lane has a `Start_<name>` empty facing +Y (the ride direction) that the feel tests and the
number keys in the greybox scene warp to.

Row 1 (features from y = 0, starts near y = -12), left to right:
    seam      2 m slab tiles laid end to end (separate collision bodies = internal-edge seams)
    flat      open flat for coasting and momentum
    curb      a 0.12 m curb, then a 0.40 m step further on
    miniqp    2.0 m quarter pipe
    qp        3.0 m quarter pipe
    vert      3.3 m near-vertical wall (88 deg at the lip) with coping
    mini      mini ramp (two facing 1.75 m quarters)
    rail      flat rail, 0.6 m
    kink      kinked rail (flat, down, flat) drawn as one polyline
    curve     curved rail (a quarter circle, radius 8 m)
    ledge     hubba-height ledge, 0.45 m
    stairs    8-stair set with handrails, fed by a bank
Row 2 (y ~ 40): funbox, hip, kicker.
"""

import math

from lib import box, empty, rail, mat, cyl_between, cyl_z
from pieces import funbox, hip, kicker, ledge, mini_ramp, quarter_pipe, stair_set, flat_rail
import lib

X0, X1 = -60.0, 104.0      # slab extent (Blender x)
Y0, Y1 = -30.0, 62.0       # slab extent (Blender y)
SEAM_X = -50.0
SEAM_W = 4.0
TILE = 2.0
SLAB_T = 0.4


def G(name, hexc="#9a9a9a"):
    return mat(name, hexc)


def slab(name, x0, x1, y0, y1, surface="Concrete"):
    return box(f"{surface}_{name}-col", (x1 - x0, y1 - y0, SLAB_T), ((x0 + x1) / 2, (y0 + y1) / 2, -SLAB_T / 2),
               G("Grey"))


def start(name, x, y, rot_deg=0.0):
    empty(f"Start_{name}", (x, y, 0.02), math.radians(rot_deg), None, size=0.6)


def root(name, x, y, rot_deg=0.0):
    return empty(lib.uname(name), (x, y, 0.0), math.radians(rot_deg), None)


def build():
    # ground: two big slabs with the seam lane between them, tiled
    slab("GroundW", X0, SEAM_X - SEAM_W / 2, Y0, Y1)
    slab("GroundE", SEAM_X + SEAM_W / 2, X1, Y0, Y1)
    y = Y0
    k = 0
    while y < Y1 - 0.01:
        slab(f"Seam{k:02d}", SEAM_X - SEAM_W / 2, SEAM_X + SEAM_W / 2, y, y + TILE)
        y += TILE
        k += 1
    start("seam", SEAM_X, -26.0)
    start("flat", -40.0, -26.0)
    empty("Spawn_Player", (-40.0, -26.0, 0.02), 0.0, None)

    # curb lane: a 0.12 m curb to roll up, a 0.40 m step that should stop you
    box("Concrete_Curb-col", (4.0, 6.0, 0.12), (-30.0, 3.0, 0.06), G("GreyDark", "#7c7c7c"))
    box("Wall_Step-col", (4.0, 4.0, 0.40), (-30.0, 16.0, 0.20), G("GreyDark", "#7c7c7c"))
    start("curb", -30.0, -12.0)

    # quarter pipes and vert
    quarter_pipe(root("MiniQP", -18.0, 8.0), W=6.0, R=2.4, H=2.0, D=2.0, rails=False, decals=False)
    start("miniqp", -18.0, -10.0)
    quarter_pipe(root("QP", -6.0, 8.0), W=6.0, R=3.2, H=3.0, D=2.0, rails=False, decals=False)
    start("qp", -6.0, -10.0)
    quarter_pipe(root("Vert", 8.0, 8.0), W=8.0, R=3.4, H=3.3, D=2.4, rails=False, decals=False)
    start("vert", 8.0, -12.0)

    # mini ramp: start on its flat bottom
    mini_ramp(root("Mini", 24.0, 10.0), W=7.0, R=2.7, H=1.75, F=5.0, D=1.8)
    start("mini", 24.0, 8.4)

    # flat rail, approached straight on (and from 1.1 m to the side for the magnet test)
    flat_rail(root("FlatRail", 38.0, 8.0), L=8.0, h=0.6)
    start("rail", 38.0, -6.0)
    start("rail_side", 39.1, -6.0)

    # kinked rail: flat at 0.9, down to 0.4, flat again (one polyline, so the grind rides the kinks)
    kx = 50.0
    kpts = [(kx, 2.0, 0.9), (kx, 6.0, 0.9), (kx, 10.0, 0.45), (kx, 14.0, 0.45)]
    for a, b in zip(kpts, kpts[1:]):
        cyl_between(lib.uname("KinkRail"), a, b, 0.05, G("Metal", "#b9c3d0"), seg=8)
    for p in kpts:
        cyl_z(lib.uname("KinkPost"), (p[0], p[1], 0.0), p[2], 0.04, G("GreyDark", "#7c7c7c"), seg=6)
    rail(None, "kink_01", [(p[0], p[1], p[2] + 0.07) for p in kpts], kind="rail")
    start("kink", kx, -8.0)

    # curved rail: a quarter circle from (62, 4) bending right to (70, 12), 0.55 m high
    cx, cy, r, h = 70.0, 4.0, 8.0, 0.55
    arc = [(cx - r * math.cos(t), cy + r * math.sin(t), h) for t in [i * (math.pi / 2) / 12 for i in range(13)]]
    for a, b in zip(arc, arc[1:]):
        cyl_between(lib.uname("CurveRail"), a, b, 0.05, G("Metal", "#b9c3d0"), seg=8)
    for p in arc[::3]:
        cyl_z(lib.uname("CurvePost"), (p[0], p[1], 0.0), h, 0.04, G("GreyDark", "#7c7c7c"), seg=6)
    rail(None, "curve_01", [(p[0], p[1], h + 0.07) for p in arc], kind="rail", smooth=True, resolution=8)
    start("curve", 62.0, -8.0)

    # ledge (grind lines on both top edges)
    ledge(root("Ledge", 78.0, 8.0), L=8.0, W=0.7, h=0.45)
    start("ledge", 77.2, -6.0)

    # stair set with handrails, fed by a bank; top of the stairs at y = 6
    stair_set(root("Stairs", 90.0, 6.0), n=8)
    start("stairs", 90.0, -12.0)

    # row 2
    funbox(root("Funbox", 0.0, 42.0))
    start("funbox", 0.0, 28.0)
    hip(root("Hip", 24.0, 42.0))
    start("hip", 24.0, 30.0)
    kicker(root("Kicker", 40.0, 40.0), W=3.0, R=5.0, H=0.9)
    start("kicker", 40.0, 28.0)
