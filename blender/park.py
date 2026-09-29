"""
Level 1: Community Park.

A neighbourhood park on flat ground. A big paved ring path circles a fenced skate plaza in the
middle; four spoke paths connect them. Ring features (kickers, manual pads, rails, ledges, benches)
reward skaters who just keep cruising. Beyond a hedge and a road there are houses and trees.

Coordinates: metres, origin at the plaza centre, +X east, +Y north (Blender). Godot flips Y to -Z.
"""

import math
import random

from lib import (box, col_box, cyl_z, empty, loft_box, mesh_obj, quad, revolve, uname)
from pieces import (M, banner, bench, bin_, bush, fence, flat_rail, flower_bed, funbox, hedge, house,
                    kicker, kiosk, ledge, lamp, manual_pad, mini_ramp, picnic, pyramid, quarter_pipe,
                    stair_set, tree)

Z0 = 0.06                 # top of every paved surface
RING_IN, RING_OUT = 33.0, 39.0
RING_MID = (RING_IN + RING_OUT) / 2
PLAZA_X, PLAZA_Y = 20.0, 15.0
SPOKE_W = 4.6
BOUND = 55.0

BUILDERS = dict(
    mini_ramp=mini_ramp, quarter_pipe=quarter_pipe, kicker=kicker, funbox=funbox, pyramid=pyramid,
    manual_pad=manual_pad, ledge=ledge, flat_rail=flat_rail, stair_set=stair_set, bench=bench, tree=tree,
    bush=bush, lamp=lamp, bin=bin_, picnic=picnic, fence=fence, hedge=hedge, banner=banner,
    flower_bed=flower_bed, kiosk=kiosk, house=house,
)


def place(piece, x, y, rot=0.0, z=Z0, **kw):
    root = empty(uname("Piece_" + piece), (x, y, z), math.radians(rot))
    BUILDERS[piece](root, **kw)
    return root


def polar(a_deg, r):
    a = math.radians(a_deg)
    return r * math.cos(a), r * math.sin(a)


# --------------------------------------------------------------------------
# ground, paths, plaza
# --------------------------------------------------------------------------

def ground():
    box("Grass_Ground-col", (320, 320, 1.0), (0, 0, -0.5), M("Grass"))
    # mown stripes
    y = -BOUND - 5
    i = 0
    while y < BOUND + 5:
        if i % 2 == 0:
            quad(uname("Stripe"), (-BOUND - 8, y, 0.006), (BOUND + 8, y, 0.006), (BOUND + 8, y + 5, 0.006),
                 (-BOUND - 8, y + 5, 0.006), M("GrassB"))
        y += 5
        i += 1


def ring():
    profile = [(RING_IN - 0.16, 0.0), (RING_IN, Z0), (RING_OUT, Z0), (RING_OUT + 0.16, 0.0)]
    revolve("Path_Ring-col", profile, 120, [M("Path"), M("Curb")], [1, 0, 1])
    # expansion joints + centre dashes so speed reads
    for k in range(72):
        a = math.radians(k * 5)
        da = 0.07 / RING_MID
        pts = []
        for (r, aa) in ((RING_IN + 0.05, a - da), (RING_OUT - 0.05, a - da), (RING_OUT - 0.05, a + da), (RING_IN + 0.05, a + da)):
            pts.append((r * math.cos(aa), r * math.sin(aa), Z0 + 0.004))
        quad(uname("Joint"), *pts, M("PathB"))
    for k in range(48):
        a0 = math.radians(k * 7.5)
        a1 = math.radians(k * 7.5 + 3.4)
        w = 0.09
        pts = [((RING_MID - w) * math.cos(a0), (RING_MID - w) * math.sin(a0), Z0 + 0.006),
               ((RING_MID + w) * math.cos(a0), (RING_MID + w) * math.sin(a0), Z0 + 0.006),
               ((RING_MID + w) * math.cos(a1), (RING_MID + w) * math.sin(a1), Z0 + 0.006),
               ((RING_MID - w) * math.cos(a1), (RING_MID - w) * math.sin(a1), Z0 + 0.006)]
        quad(uname("Dash"), *pts, M("Line"))


def plaza_and_spokes():
    loft_box("Concrete_Plaza-col", (PLAZA_X * 2 + 0.32, PLAZA_Y * 2 + 0.32), (PLAZA_X * 2, PLAZA_Y * 2), 0.0, Z0,
             M("Plaza"), center=(0, 0))
    ns_len = RING_IN - PLAZA_Y + 1.0
    ew_len = RING_IN - PLAZA_X + 1.0
    for sgn in (-1, 1):
        cy = sgn * (PLAZA_Y - 0.5 + ns_len / 2)
        loft_box(uname("Path_Spoke") + "-col", (SPOKE_W + 0.32, ns_len + 0.32), (SPOKE_W, ns_len), 0.0, Z0, M("Path"), center=(0, cy))
        cx = sgn * (PLAZA_X - 0.5 + ew_len / 2)
        loft_box(uname("Path_Spoke") + "-col", (ew_len + 0.32, SPOKE_W + 0.32), (ew_len, SPOKE_W), 0.0, Z0, M("Path"), center=(cx, 0))


def plaza_fence():
    gap = SPOKE_W / 2 + 0.4
    fx, fy = PLAZA_X + 0.25, PLAZA_Y + 0.25
    # north / south edges run along X
    for sy in (-1, 1):
        seg = fx - gap
        for sx in (-1, 1):
            place("fence", sx * (gap + seg / 2), sy * fy, 90, L=seg)
    # east / west edges run along Y
    for sx in (-1, 1):
        seg = fy - gap
        for sy in (-1, 1):
            place("fence", sx * fx, sy * (gap + seg / 2), 0, L=seg)
    # gate posts with coloured caps
    for (x, y) in ((gap, fy), (-gap, fy), (gap, -fy), (-gap, -fy), (fx, gap), (fx, -gap), (-fx, gap), (-fx, -gap)):
        cyl_z(uname("GatePost"), (x, y, Z0), 2.1, 0.11, M("Navy"), seg=8)
        box(uname("GateCap"), (0.3, 0.3, 0.16), (x, y, Z0 + 2.15), M("Orange"))


# --------------------------------------------------------------------------
# skate plaza layout
# --------------------------------------------------------------------------

def plaza_obstacles():
    # west side: transition zone
    place("mini_ramp", -10.0, 8.0, -90)
    place("quarter_pipe", -13.2, -6.5, 90, W=7.0, R=3.4, H=2.6, D=2.0, seed=11)
    place("quarter_pipe", -3.5, -8.7, 180, W=5.0, R=2.4, H=1.4, D=1.6, seed=12)
    place("ledge", -8.0, -1.5, 90, L=5.5)
    # east side: street course
    place("funbox", 11.5, -5.5, 0)
    place("pyramid", 12.0, 7.5, 0)
    place("stair_set", 5.5, 4.0, 0)
    place("flat_rail", 3.5, -12.2, 90, L=6.5, color="Orange")
    place("flat_rail", 4.0, -2.0, 0, L=5.5, color="Blue")
    place("manual_pad", 1.0, 7.0, 90, L=5.0)
    place("manual_pad", 16.0, 0.8, 0, L=4.5)
    place("kicker", -16.5, 1.5, 0, W=2.8, R=5.0, H=0.7)
    place("ledge", 17.0, 13.3, 90, L=4.5, color="ConcreteDk")
    # banners on the fence line
    place("banner", -9.5, 16.4, -135, text="SKATE JAM", color="Purple")
    place("banner", 9.5, 16.4, -135, text="RIDE ON", color="Blue")
    place("banner", 21.6, 9.0, -135, text="GRIND TIME", color="Orange", w=3.0)
    # a few benches / bins inside the fence
    place("bench", 18.6, -12.5, -135, grindable=True)
    place("bin", 19.0, -9.8, 0)
    place("bench", -18.6, 12.8, -45)
    place("bin", -19.0, 10.0, 0, color="Blue")


# --------------------------------------------------------------------------
# ring features and park dressing
# --------------------------------------------------------------------------

def ring_features():
    for a in (100, 280):
        x, y = polar(a, RING_MID - 1.4)
        place("kicker", x, y, a, W=2.6, R=5.0, H=0.55)
    for a in (45, 135, 225, 315):
        x, y = polar(a, RING_MID + 1.2)
        place("manual_pad", x, y, a, L=5.0, W=1.4)
    for a, off, color in ((20, 1.6, "Yellow"), (200, -1.6, "Red"), (330, 1.6, "Blue")):
        x, y = polar(a, RING_MID + off)
        place("flat_rail", x, y, a, L=6.0, color=color)
    for a, off in ((70, -1.7), (250, 1.7)):
        x, y = polar(a, RING_MID + off)
        place("ledge", x, y, a, L=5.0, W=0.6, h=0.5)


def furniture():
    # benches + bins around the outside of the ring, facing in
    for a in range(0, 360, 30):
        x, y = polar(a + 8, RING_OUT + 1.6)
        place("bench", x, y, a + 8 + 90, z=0.0)
        if a % 60 == 0:
            bx, by = polar(a + 12, RING_OUT + 1.2)
            place("bin", bx, by, 0, z=0.0, color="Bin" if a % 120 else "Blue")
    # lamps along the ring's outer edge
    for a in range(0, 360, 15):
        x, y = polar(a, RING_OUT + 0.7)
        place("lamp", x, y, a + 180, z=0.0)
    # picnic area NE and SW
    for (x, y, r) in ((31, 34, 20), (36, 28, -30), (-31, -34, 70)):
        place("picnic", x, y, r, z=0.0)
    # flower beds at the four entrances
    for sgn in (-1, 1):
        place("flower_bed", sgn * 4.8, RING_IN - 2.5, 0, z=0.0, seed=sgn + 2)
        place("flower_bed", sgn * 4.8, -RING_IN + 2.5, 0, z=0.0, seed=sgn + 5)
        place("flower_bed", RING_IN - 2.5, sgn * 4.8, 90, z=0.0, seed=sgn + 8)
        place("flower_bed", -RING_IN + 2.5, sgn * 4.8, 90, z=0.0, seed=sgn + 11)


def planting():
    rnd = random.Random(7)
    # between plaza and ring (skip the spoke corridors)
    for k in range(48):
        a = k * 7.5 + rnd.uniform(-2, 2)
        near_spoke = min(abs(((a + 45) % 90) - 45), 99) < 9
        if near_spoke:
            continue
        r = rnd.uniform(28.0, 30.8)
        x, y = polar(a, r)
        if abs(x) < PLAZA_X + 2.5 and abs(y) < PLAZA_Y + 2.5:
            continue
        place("tree", x, y, rnd.uniform(0, 360), z=0.0, variety=rnd.choice([0, 0, 1]), seed=k, s=rnd.uniform(0.85, 1.15))
    for k in range(70):
        a = rnd.uniform(0, 360)
        r = rnd.uniform(41.5, 52)
        x, y = polar(a, r)
        if abs(x) > BOUND - 2 or abs(y) > BOUND - 2:
            continue
        place("tree", x, y, rnd.uniform(0, 360), z=0.0, variety=rnd.choice([0, 1, 1]), seed=100 + k, s=rnd.uniform(0.9, 1.3))
    for k in range(60):
        a = rnd.uniform(0, 360)
        r = rnd.choice([rnd.uniform(24.5, 31.5), rnd.uniform(40.8, 53)])
        x, y = polar(a, r)
        if r < 31.5 and abs(x) < PLAZA_X + 2 and abs(y) < PLAZA_Y + 2:
            continue
        if abs(x) > BOUND - 1.5 or abs(y) > BOUND - 1.5:
            continue
        place("bush", x, y, 0, z=0.0, s=rnd.uniform(0.8, 1.4), seed=k)


def boundary_and_town():
    # hedge all the way round
    for i in range(-5, 6):
        c = i * 10.0
        place("hedge", c, BOUND, 90, z=0.0, L=10.0)
        place("hedge", c, -BOUND, 90, z=0.0, L=10.0)
        place("hedge", BOUND, c, 0, z=0.0, L=10.0)
        place("hedge", -BOUND, c, 0, z=0.0, L=10.0)
    for (sx, sy, w, h) in ((0, 1, 130, 12), (0, -1, 130, 12)):
        col_box(uname("Boundary"), (w, 6, 12), (0, sy * (BOUND + 3.0), 6))
    for (sx, sy) in ((1, 0), (-1, 0)):
        col_box(uname("Boundary"), (6, 130, 12), (sx * (BOUND + 3.0), 0, 6))
    # sidewalk + road ring
    for (cx, cy, sx, sy) in ((0, 1, 150, 1), (0, -1, 150, 1), (1, 0, 1, 150), (-1, 0, 1, 150)):
        px, py = cx * (BOUND + 2.0), cy * (BOUND + 2.0)
        box(uname("Sidewalk"), (sx if sx > 1 else 4.0, sy if sy > 1 else 4.0, 0.1), (px, py, 0.05), M("Curb"))
        rx, ry = cx * (BOUND + 9.0), cy * (BOUND + 9.0)
        box(uname("Road"), (sx if sx > 1 else 10.0, sy if sy > 1 else 10.0, 0.06), (rx, ry, 0.03), M("Road"))
    for k in range(-7, 8):
        for (cx, cy) in ((0, 1), (0, -1)):
            quad(uname("RoadLine"), (k * 9 - 2, cy * (BOUND + 9.0) - 0.12, 0.07), (k * 9 + 2, cy * (BOUND + 9.0) - 0.12, 0.07),
                 (k * 9 + 2, cy * (BOUND + 9.0) + 0.12, 0.07), (k * 9 - 2, cy * (BOUND + 9.0) + 0.12, 0.07), M("Line"))
        for (cx, cy) in ((1, 0), (-1, 0)):
            quad(uname("RoadLine"), (cx * (BOUND + 9.0) - 0.12, k * 9 - 2, 0.07), (cx * (BOUND + 9.0) + 0.12, k * 9 - 2, 0.07),
                 (cx * (BOUND + 9.0) + 0.12, k * 9 + 2, 0.07), (cx * (BOUND + 9.0) - 0.12, k * 9 + 2, 0.07), M("Line"))
    # houses in rows beyond the road
    rnd = random.Random(21)
    walls = ["Cream", "White", "Pink", "Yellow", "Window", "Orange"]
    roofs = ["Roof", "RoofB", "Brick", "Navy"]
    for side in range(4):
        rot0 = (180, 90, 0, -90)[side]
        for i in range(-6, 7):
            c = i * 15.0 + rnd.uniform(-2, 2)
            d = BOUND + 24.0 + rnd.uniform(0, 4)
            if side == 0:
                x, y = c, d
            elif side == 1:
                x, y = -d, c
            elif side == 2:
                x, y = c, -d
            else:
                x, y = d, c
            place("house", x, y, rot0, z=0.0, w=rnd.uniform(8, 11), d=rnd.uniform(7, 9), h=rnd.uniform(4.5, 6.5),
                  wall=rnd.choice(walls), roof=rnd.choice(roofs), seed=side * 20 + i)
            if rnd.random() < 0.6:
                tx, ty = (x + rnd.uniform(-6, 6), y + rnd.uniform(-6, 6))
                place("tree", tx, ty, 0, z=0.0, variety=rnd.choice([0, 1]), seed=side * 30 + i, s=rnd.uniform(0.9, 1.3))


def landmarks():
    # the skate shop, north-west of the ring, facing the park
    place("kiosk", -30.0, 44.0, -135, z=0.0, w=8.0, d=5.5, h=3.6)
    box(uname("Path_ShopApron"), (10.5, 8.0, 0.06), (-25.4, 39.4, 0.03), M("Path")).rotation_euler = (0, 0, math.radians(45))
    # spawn + pickups
    sx, sy = polar(-90, RING_MID)
    empty("Spawn_Player", (sx, sy, Z0), math.radians(-90))
    for i, ch in enumerate("SKATE"):
        a = -60 + i * 72
        x, y = polar(a, RING_MID - 0.3)
        empty(f"Pickup_{ch}_{i}", (x, y, Z0 + 0.9))
    empty("Pickup_Plaza_0", (12.0, -1.0, Z0 + 1.4))


def build():
    ground()
    ring()
    plaza_and_spokes()
    plaza_fence()
    plaza_obstacles()
    ring_features()
    furniture()
    planting()
    boundary_and_town()
    landmarks()
