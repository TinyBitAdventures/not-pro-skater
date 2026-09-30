"""
Level 5, Downtown: a few city blocks on a weekday morning, the Vlogger's home turf ("Rush Hour"). Market Street is
closed to cars for the morning market, and the city is full of spots:

    Market Street         the closed street north-south, market stalls on the road, curbs both sides (grindable)
    the café              on the west side, tables out on the sidewalk: the coffee order comes from here
    the civic plaza       raised 1.5 m on the north-east corner: a ramp up with a handrail, wide stairs down to
                          Second Street with the big rail and a hubba, its street edge a ledge, the office tower's
                          lobby (the coffee goes there)
    the bank to wall      a sloped plinth along the south-east block's wall
    the corner            a mini plaza with planter ledges and benches where the camera is set up (film the intro)
    the subway entrance   a glass kiosk on the north-west sidewalk

Main Avenue runs along the south edge (the same street band as the other levels), Second Street crosses Market
Street at y 18..26. Blender axes (Z up); Godot sees (x, z, -y).

Event markers: Event_letter_<L> (V-I-R-A-L), Event_check_<n> (the one-take run), Event_coffee_pickup / _drop,
Event_zone_camera (film the intro), Start_<name>, Spawn_Player.
"""

import math
import os

import bpy

import houses
import lib
from lib import box, cyl_between, cyl_z, empty, mat, prism, rail
from neighborhood import marker, paint, root, slab
import park_props as props
from pieces import M, bank
import realism
import school
import terrain
import trees

SKY = "qwantani_mid_morning_puresky"
ROAD_Z = terrain.ROAD_Z
CURB = 0.15                                 # the sidewalks stand this high over the road
PLAZA = (12.0, 40.0, 30.0, 50.0)            # the raised civic plaza (x0, x1, y0, y1)
PLAZA_H = 1.5
STAIRS_N, STAIRS_RISE, STAIRS_RUN = 8, 0.1875, 0.42
TOWER = (40.0, 58.0, 30.0, 60.0)

HARD = [(-62.0, 62.0, -62.0, 62.0)]         # the whole level is paved
MOUNDS = []


# ------------------------------------------------------------------ ground

def ground():
    terrain.configure(HARD, MOUNDS)
    terrain.lawn()
    # Main Avenue along the south edge
    slab("AveSidewalkN", "Concrete", "Sidewalk", -62.0, 62.0, -32.5, -30.0, top=CURB, t=0.3)
    slab("AveRoad", "Path", "Road", -62.0, 62.0, -40.5, -32.5, top=0.0, t=0.3)
    slab("AveSidewalkS", "Concrete", "Sidewalk", -62.0, 62.0, -43.0, -40.5, top=CURB, t=0.3)
    slab("FarBlocks", "Concrete", "Sidewalk", -62.0, 62.0, -62.0, -43.0, top=CURB, t=0.3)
    # Market Street (north-south), Second Street (east-west)
    slab("MarketRoad", "Path", "Road", -8.0, 8.0, -30.0, 62.0, top=0.0, t=0.3, group="plaza")
    slab("SecondRoad", "Path", "Road", -62.0, 62.0, 19.0, 25.0, top=0.0, t=0.3, group="plaza")
    # the blocks' sidewalks and yards (raised a curb above the roads)
    for (x0, x1, y0, y1) in ((-62.0, -8.0, -30.0, 19.0), (8.0, 62.0, -30.0, 19.0), (-62.0, -8.0, 25.0, 62.0),
                             (8.0, 62.0, 25.0, 62.0)):
        slab(lib.uname("Block"), "Concrete", "Sidewalk", x0, x1, y0, y1, top=CURB, t=0.3, group="plaza")
    # curbs: the sidewalk edges along Market Street are grindable
    for name, x, (y0, y1) in (("curb_w_s", -8.0, (-29.5, 18.5)), ("curb_e_s", 8.0, (-29.5, 18.5)),
                              ("curb_w_n", -8.0, (25.5, 61.0)), ("curb_e_n", 8.0, (25.5, 61.0))):
        rail(None, name, [(x + (0.06 if x > 0 else -0.06), y0, CURB + 0.07), (x + (0.06 if x > 0 else -0.06), y1, CURB + 0.07)],
             kind="curb")
    # lane lines and crosswalks
    white = paint("LineWhite", "#e6e3da")
    for y in (-28.5, 16.8, 27.2, 60.0):
        for k in range(8):
            box(lib.uname("Crosswalk"), (1.2, 2.4, 0.008), (-7.0 + k * 2.0, y, 0.004), white)
    for y in range(-24, 16, 6):
        box(lib.uname("LaneDash"), (0.12, 2.6, 0.008), (0.0, y, 0.004), paint("LineYellow", "#d9ac3a"))


# ------------------------------------------------------------------ buildings

def facade(name, x0, x1, y0, y1, h, material, front_y=None, front_x=None, shop=None, storey=3.4, seed=0, first_floor=0,
           side_x=None):
    """A city building: a box with rows of windows on its street faces, a shopfront at street level (glass, an
    awning, a sign) if `shop` is given as (text, colour). side_x: one more face (x) with windows on every floor,
    for a side that faces open ground."""
    trim = mat("Trim", "#e8e4dc")
    box(f"Wall_{name}-col", (x1 - x0, y1 - y0, h), ((x0 + x1) / 2, (y0 + y1) / 2, CURB + h / 2), material)
    box(lib.uname(name + "_cornice"), (x1 - x0 + 0.3, y1 - y0 + 0.3, 0.4), ((x0 + x1) / 2, (y0 + y1) / 2, CURB + h + 0.2),
        mat("StoneDk", "#77736c"))
    r = empty(lib.uname(name + "Windows"), (0, 0, 0), 0.0, None)
    floors = int((h - 1.0) // storey)
    for f in range(max(first_floor, 1 if shop else 0), floors):
        z = CURB + 1.0 + f * storey
        if front_y is not None:
            w = x1 - x0
            n = max(1, int(w // 3.0))
            for i in range(n):
                houses._window(r, x0 + w * (i + 0.5) / n, front_y, z, 1.6, 2.0, trim, facing=1 if front_y > y0 else -1)
        if front_x is not None:
            d = y1 - y0
            n = max(1, int(d // 3.0))
            for i in range(n):
                houses._window_side(r, front_x, y0 + d * (i + 0.5) / n, z, 1.6, 2.0, trim,
                                    facing=1 if front_x > (x0 + x1) / 2 else -1)
    if side_x is not None:
        d = y1 - y0
        n = max(1, int(d // 3.0))
        for f in range(max(first_floor, 0), max(floors, 1)):
            z = CURB + 1.0 + f * storey
            for i in range(n):
                houses._window_side(r, side_x, y0 + d * (i + 0.5) / n, z, 1.6, 2.0, trim,
                                    facing=1 if side_x > (x0 + x1) / 2 else -1)
    if shop:
        text, colour = shop
        glass = houses.glass()
        awning = mat(f"Awning{seed}", colour)
        if front_x is not None:                                   # a shopfront along a north-south street
            s = 1 if front_x > (x0 + x1) / 2 else -1
            gx = front_x + 0.03 * s
            lib.quad(lib.uname(name + "_shopglass"), (gx, y0 + 1.0, CURB + 0.4), (gx, y1 - 1.0, CURB + 0.4),
                     (gx, y1 - 1.0, CURB + 2.9), (gx, y0 + 1.0, CURB + 2.9), glass, expect=(s, 0, 0))
            box(lib.uname(name + "_awning"), (1.6, y1 - y0 - 1.6, 0.08), (front_x + s * 0.8, (y0 + y1) / 2, CURB + 3.2), awning)
            school.text_mesh(name + "_sign", text, 0.45, (front_x + s * 0.06, (y0 + y1) / 2, CURB + 3.8),
                             (math.pi / 2, 0.0, s * math.pi / 2), mat("SignWhite", "#f2f0ea"), depth=0.02)
        elif front_y is not None:
            s = 1 if front_y > (y0 + y1) / 2 else -1
            gy = front_y + 0.03 * s
            lib.quad(lib.uname(name + "_shopglass"), (x0 + 1.0, gy, CURB + 0.4), (x1 - 1.0, gy, CURB + 0.4),
                     (x1 - 1.0, gy, CURB + 2.9), (x0 + 1.0, gy, CURB + 2.9), glass, expect=(0, s, 0))
            box(lib.uname(name + "_awning"), (x1 - x0 - 1.6, 1.6, 0.08), ((x0 + x1) / 2, front_y + s * 0.8, CURB + 3.2), awning)
            school.text_mesh(name + "_sign", text, 0.45, ((x0 + x1) / 2, front_y + s * 0.06, CURB + 3.8),
                             (math.pi / 2, 0.0, 0.0 if s < 0 else math.pi), mat("SignWhite", "#f2f0ea"), depth=0.02)


def buildings():
    brick = mat("Brick", "#9a5244")
    cream = mat("Stucco", "#d9cdb4")          # plaster and stone for city buildings (clapboard read as giant houses)
    stone = mat("Stone", "#bdb8ad")
    grey = mat("Brownstone", "#8f9396")
    # the south-west block: the café on the corner of Second Street, shops down to the avenue
    facade("Cafe", -24.0, -12.0, 0.0, 16.0, 8.2, brick, front_x=-12.0, shop=("MORNING GLORY CAFE", "#2f6f5a"), seed=1)
    facade("ShopSW", -24.0, -12.0, -26.0, -4.0, 11.0, cream, front_x=-12.0, shop=("BOOKS", "#8a3b33"), seed=2)
    facade("BlockSW", -44.0, -26.0, -26.0, 16.0, 16.0, stone, front_y=16.0, seed=3, side_x=-44.0)
    # the north-west block: tall offices, the subway entrance on the corner
    facade("BlockNW", -40.0, -12.0, 29.0, 60.0, 21.0, grey, front_x=-12.0, front_y=29.0, seed=4)
    # the south-east block: a long building with a plinth (the bank to wall) along Market Street
    facade("BlockSE", 14.0, 44.0, -26.0, 2.0, 13.0, brick, front_x=14.0, front_y=2.0, seed=5, first_floor=1)
    facade("ShopSE", 30.0, 44.0, 2.0, 16.0, 7.0, cream, front_y=16.0, shop=("DELI", "#b8732c"), seed=6, side_x=30.0)
    # the office tower on the civic plaza
    tx0, tx1, ty0, ty1 = TOWER
    box("Wall_Tower-col", (tx1 - tx0, ty1 - ty0, 36.0), ((tx0 + tx1) / 2, (ty0 + ty1) / 2, 18.0), stone)
    r = empty(lib.uname("TowerGlass"), (0, 0, 0), 0.0, None)
    mull = mat("Mullion", "#2d3236")
    for z in range(4, 36, 4):
        for yy in range(int(ty0) + 2, int(ty1) - 1, 3):
            houses._window_side(r, tx0, yy + 0.5, float(z), 2.6, 3.0, mull, facing=-1)
            houses._window_side(r, tx1, yy + 0.5, float(z), 2.6, 3.0, mull, facing=1)
        for xx in range(int(tx0) + 2, int(tx1) - 1, 3):
            houses._window(r, xx + 0.5, ty0, float(z), 2.6, 3.0, mull, facing=-1)
    glass = houses.glass()
    lib.quad(lib.uname("Lobby_glass"), (tx0 - 0.04, 36.0, PLAZA_H + 0.1), (tx0 - 0.04, 46.0, PLAZA_H + 0.1),
             (tx0 - 0.04, 46.0, PLAZA_H + 3.6), (tx0 - 0.04, 36.0, PLAZA_H + 3.6), glass, expect=(-1, 0, 0))
    box(lib.uname("Lobby_canopy"), (3.0, 11.0, 0.25), (tx0 - 1.5, 41.0, PLAZA_H + 4.0), M("Steel"))
    school.text_mesh("Tower_name", "ONE MARKET PLACE", 0.5, (tx0 - 0.12, 41.0, PLAZA_H + 4.8),
                     (math.pi / 2, 0.0, -math.pi / 2), mat("SignWhite", "#f2f0ea"), depth=0.02)
    # the backdrop: towers beyond the blocks (the city goes on). Glass ones banded by stone floor slabs, stone ones
    # with ribbon windows; some stand on a podium, some step back near the top. A band is one box a little bigger
    # than the tower, so it reads on all four faces. Far colours only: they stay live and out of the bake
    f_glass = mat("FarGlass", "#34404a")
    f_stone = mat("FarBlockC", "#b7b0a5")     # the city_blocks palette: shared draw calls
    f_dark = mat("FarBlockD", "#7d7f84")
    f_win = mat("FarWin", "#2c343c")
    for i, (x, y, w, d, h) in enumerate(((-75.0, 10.0, 18, 22, 60), (-80.0, 50.0, 20, 20, 44), (-70.0, -50.0, 16, 16, 38),
                                         (75.0, -10.0, 22, 18, 70), (80.0, 40.0, 18, 22, 52), (72.0, -52.0, 16, 18, 34),
                                         (-20.0, 85.0, 24, 18, 58), (20.0, 88.0, 18, 18, 76), (50.0, 82.0, 16, 16, 40),
                                         (-50.0, 82.0, 20, 16, 48))):
        glassy = i % 3 != 1
        body, band = (f_glass, f_stone) if glassy else (f_stone, f_win)
        z0 = -0.2
        if i % 4 == 0:                                         # a podium with a dark shopfront band
            box(lib.uname("Far_TowerPodium"), (w + 10.0, d + 10.0, 9.0 - z0), (x, y, (9.0 + z0) / 2), f_stone)
            box(lib.uname("Far_TowerPodium"), (w + 10.1, d + 10.1, 3.2), (x, y, 2.2), f_win)
        top = round(h * 0.72) if i % 3 == 2 else h            # the step back
        box(lib.uname("Far_Tower"), (w, d, top - z0), (x, y, (top + z0) / 2), body)
        if top < h:
            box(lib.uname("Far_Tower"), (w * 0.7, d * 0.7, h - top), (x, y, (top + h) / 2), body)
            box(lib.uname("Far_TowerCap"), (w + 0.6, d + 0.6, 0.8), (x, y, top + 0.4), f_dark)
        z = 5.0
        while z < h - 2.0:
            s = 1.0 if z < top else 0.7
            box(lib.uname("Far_TowerBand"), (w * s + 0.12, d * s + 0.12, 0.75 if glassy else 1.7), (x, y, z), band)
            z += 3.6
        box(lib.uname("Far_TowerCap"), ((w * (0.7 if top < h else 1.0)) + 0.6, (d * (0.7 if top < h else 1.0)) + 0.6, 1.2),
            (x, y, h + 0.6), f_dark)


# ------------------------------------------------------------------ the civic plaza

def civic_plaza():
    """Raised 1.5 m: a ramp up its west side from Market Street's sidewalk (handrail), wide stairs down its south side
    to Second Street (the big rail down the middle, a hubba at the east end), its street edge a ledge."""
    x0, x1, y0, y1 = PLAZA
    pav = mat("Paving", "#a09c94")
    stone = mat("StoneDk", "#8d8c88")
    box("Plaza_Civic-col", (x1 - x0, y1 - y0, PLAZA_H), ((x0 + x1) / 2, (y0 + y1) / 2, PLAZA_H / 2), pav)
    # a stone skirt round its sides (the paving on a 1.5 m wall read as pixelated blockwork); the ramp and the
    # stairs cover parts of it
    sk = 0.03
    for (cx_, cy_, w_, d_) in (((x0 + x1) / 2, y0 - sk / 2, x1 - x0 + 2 * sk, sk), ((x0 + x1) / 2, y1 + sk / 2, x1 - x0 + 2 * sk, sk),
                               (x0 - sk / 2, (y0 + y1) / 2, sk, y1 - y0), (x1 + sk / 2, (y0 + y1) / 2, sk, y1 - y0)):
        box(lib.uname("PlazaSkirt"), (w_, d_, PLAZA_H - 0.04), (cx_, cy_, (PLAZA_H - 0.04) / 2), stone)
    # the ramp up along the west side, rising north from the sidewalk
    L = 14.0
    rx0, rx1 = x0 - 3.0, x0                                       # on the sidewalk, against the plaza's west wall
    ry0 = y1 - L
    prism("Concrete_PlazaRamp-col", [(0.0, CURB), (L, PLAZA_H), (L, 0.0), (0.0, 0.0)], rx0, rx1, [stone, pav, stone, stone],
          [1, 0, 0, 0], [False] * 4, cap_mat=0, loc=(0.0, ry0, 0.0))
    galv = M("Galv")
    rx = rx0 + 0.2
    p0 = (rx, ry0 + 0.6, CURB + (PLAZA_H - CURB) * 0.6 / L + 0.95)
    p1 = (rx, y1 - 0.3, CURB + (PLAZA_H - CURB) * (L - 0.3) / L + 0.95)
    cyl_between(lib.uname("PlazaRampRail"), p0, p1, 0.026, galv, seg=12)
    for k in range(6):
        t = k / 5
        y = p0[1] + (p1[1] - p0[1]) * t
        base = CURB + (PLAZA_H - CURB) * (y - ry0) / L
        cyl_z(lib.uname("RailPost"), (rx, y, base), p0[2] + (p1[2] - p0[2]) * t - base, 0.022, galv, seg=10)
    c = lib.col_box(lib.uname("PlazaRampRail"), (0.08, math.hypot(p1[1] - p0[1], p1[2] - p0[2]), 0.08), (0, 0, 0),
                    surface="Metal")
    c.location = (rx, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
    c.rotation_euler = (math.atan2(p1[2] - p0[2], p1[1] - p0[1]), 0, 0)
    rail(None, "plaza_ramp_rail", [(rx, p0[1] + 0.1, p0[2] + 0.06), (rx, p1[1] - 0.1, p1[2] + 0.06)], kind="rail")
    # the street edge of the plaza (west, north of the ramp's foot... the part the ramp doesn't cover) is a ledge
    cyl_between(lib.uname("PlazaEdge"), (x0 + 0.04, y0 + 0.3, PLAZA_H + 0.01), (x0 + 0.04, ry0 - 0.2, PLAZA_H + 0.01), 0.04,
                galv, seg=6, smooth=False)
    rail(None, "plaza_edge", [(x0 + 0.05, y0 + 0.4, PLAZA_H + 0.07), (x0 + 0.05, ry0 - 0.4, PLAZA_H + 0.07)], kind="ledge")
    # the stairs down the south side to Second Street's sidewalk: riding -Y
    W = 14.0
    sx = 24.0
    rt = empty(lib.uname("CivicSteps"), (sx, y0, 0.0), math.pi, None)
    rt["bake_group"] = "plaza"
    n, rise, run = STAIRS_N, STAIRS_RISE, STAIRS_RUN
    Ht = PLAZA_H - CURB
    pts = [(-0.4, 0.0), (-0.4, Ht), (0.0, Ht)]
    em = [2, 0]
    for k in range(1, n + 1):
        z = Ht - k * (Ht / n)
        pts.append(((k - 1) * run, z))
        em.append(1)
        if k < n:
            pts.append((k * run, z))
            em.append(0)
    em.append(2)
    steps = prism(lib.uname("Concrete_CivicSteps"), pts, -W / 2, W / 2, [pav, stone, stone], em, [False] * len(pts),
                  cap_mat=1, parent=rt)
    steps.location = (0.0, 0.0, CURB)
    slope_ob = prism(lib.uname("Concrete_CivicSlope") + "-colonly", [(-0.4, 0.0), (-0.4, Ht), (0.0, Ht), (n * run, 0.0)],
                     -W / 2, W / 2, [M("Collision")], [0, 0, 0, 0], cap_mat=0, parent=rt)
    slope_ob.location = (0.0, 0.0, CURB)
    slope = (Ht / n) / run
    lrun = (n - 1) * run
    for name, x in (("plaza_rail_c", 0.0), ("plaza_rail_side", -W / 2 + 0.4)):
        y0r, y1r = -0.5, lrun + 0.35
        z0 = CURB + Ht + 0.9 - y0r * slope
        z1 = CURB + Ht + 0.9 - y1r * slope
        cyl_between(lib.uname("HandRail"), (x, y0r, z0), (x, y1r, z1), 0.026, galv, seg=12, parent=rt)
        for (y, z) in ((y0r, z0), (y1r, z1), ((y0r + y1r) / 2, (z0 + z1) / 2)):
            base = CURB + (Ht if y <= 0 else Ht - min(n, int(y / run) + 1) * (Ht / n))
            cyl_z(lib.uname("RailPost"), (x, y, base), z - base, 0.022, galv, seg=10, parent=rt)
        c = lib.col_box(lib.uname("HandRail"), (0.08, math.hypot(y1r - y0r, z1 - z0), 0.08), (0, 0, 0), parent=rt,
                        surface="Metal")
        c.location = (x, (y0r + y1r) / 2, (z0 + z1) / 2)
        c.rotation_euler = (math.atan2(z1 - z0, y1r - y0r), 0, 0)
        rail(rt, name, [(x, y0r + 0.05, z0 + 0.06), (x, y1r - 0.05, z1 + 0.06)], kind="rail")
    # the hubba: a granite block at the stairs' east end, sloping with the nosings
    hx0, hx1 = sx + W / 2, sx + W / 2 + 1.1
    L2 = n * run
    h_hi, h_lo = PLAZA_H + 0.45, CURB + 0.5
    prism("Concrete_CivicHubba-col", [(y0, 0.0), (y0, h_hi), (y0 - L2, h_lo), (y0 - L2, 0.0)], hx0, hx1,
          [stone, pav, stone, stone], [0, 1, 0, 2], [False] * 4, cap_mat=0)
    rail(None, "civic_hubba", [(hx0 + 0.06, y0 - 0.1, h_hi - 0.1 * (h_hi - h_lo) / L2 + 0.07),
                               (hx0 + 0.06, y0 - L2 + 0.1, h_lo + 0.1 * (h_hi - h_lo) / L2 + 0.07)], kind="ledge")
    # the walls of the plaza beside the stairs
    for (a, b) in ((x0, sx - W / 2), (hx1, x1)):
        if b - a > 0.1:
            box(lib.uname("Wall_PlazaFront") + "-col", (b - a, L2, PLAZA_H), ((a + b) / 2, y0 - L2 / 2, PLAZA_H / 2), stone)
    # on the plaza: planters, benches, a big steel sculpture, potted trees
    for (x, y) in ((20.0, 44.0), (32.0, 44.0)):
        box(lib.uname("Concrete_PlazaPlanter") + "-col", (6.0, 1.4, 0.5), (x, y, PLAZA_H + 0.25), stone)
        for k in range(2):
            props.place("shrub_03", x - 1.5 + k * 3.0, y, 30.0 * k, z=PLAZA_H + 0.5, scale=0.6, collide=False)
    rail(None, "plaza_planter_a", [(17.1, 43.35, PLAZA_H + 0.57), (22.9, 43.35, PLAZA_H + 0.57)], kind="ledge")
    rail(None, "plaza_planter_b", [(29.1, 43.35, PLAZA_H + 0.57), (34.9, 43.35, PLAZA_H + 0.57)], kind="ledge")
    for x, y, rot in ((33.0, 47.6, 0.0), (36.0, 38.0, 90.0)):       # off the one-take line (checkpoint 4 -> the stairs)
        props.place("modular_street_seating", x, y, rot, z=PLAZA_H, surface="Wood")
    for x, y in ((26.0, 48.6), (38.5, 48.5), (38.5, 31.5)):          # none at the ramp's top, where riders come on
        props.place("potted_plant_04", x, y, 0.0, z=PLAZA_H, scale=1.4, surface="Wall")


# ------------------------------------------------------------------ street spots

def street_spots():
    stone = mat("StoneDk", "#8d8c88")
    # the bank to wall: a sloped granite plinth along the south-east block's west wall
    prism("Concrete_WallBank-col", [(0.0, CURB), (0.0, CURB + 1.4), (2.0, CURB)], -22.0, -4.0, [stone, stone, stone],
          [0, 0, 0], [False] * 3, cap_mat=0)
    bnk = bpy.data.objects["Concrete_WallBank-col"]
    bnk.rotation_euler = (0.0, 0.0, math.pi / 2)                 # the profile's y runs west from the wall (x = 14)
    bnk.location = (14.0, 0.0, 0.0)
    # the corner: a mini plaza with planter ledges and benches, the camera on its tripod (film the intro)
    for (x, y, name) in ((20.0, 8.0, "corner_planter_a"), (20.0, 12.5, "corner_planter_b")):
        box(lib.uname("Concrete_CornerPlanter") + "-col", (7.0, 1.2, 0.5), (x, y, CURB + 0.25), stone)
        rail(None, name, [(x - 3.4, y - 0.55, CURB + 0.57), (x + 3.4, y - 0.55, CURB + 0.57)], kind="ledge")
        for k in range(3):
            props.place("shrub_03", x - 2.4 + k * 2.4, y, 50.0 * k, z=CURB + 0.5, scale=0.5, collide=False)
    props.place("modular_street_seating", 27.0, 10.0, 90.0, z=CURB, surface="Wood")
    cam = empty(lib.uname("Tripod"), (24.5, 5.0, CURB), math.radians(120), None)
    for a in range(3):
        ang = a * math.tau / 3
        cyl_between(lib.uname("TripodLeg"), (0.0, 0.0, 1.3), (0.35 * math.cos(ang), 0.35 * math.sin(ang), 0.0), 0.015,
                    mat("Rubber", "#1e1e1e"), seg=6, parent=cam)
    box(lib.uname("Camera"), (0.28, 0.14, 0.16), (0.0, 0.0, 1.4), mat("Rubber", "#1e1e1e"), parent=cam)
    cyl_between(lib.uname("CameraLens"), (0.0, 0.07, 1.4), (0.0, 0.17, 1.4), 0.05, M("Steel"), seg=10, parent=cam)
    # the subway entrance: a glass kiosk on Second Street's north sidewalk (decoration, a solid obstacle)
    kx, ky = -24.0, 27.0
    box("Wall_Subway-col", (5.0, 3.0, 0.2), (kx, ky, CURB + 2.6), M("Steel"))
    glass = houses.glass()
    for dy in (-1.45, 1.45):
        s_ = 1 if dy > 0 else -1
        lib.quad(lib.uname("Subway_glass"), (kx - 2.4, ky + dy, CURB + 0.2), (kx + 2.4, ky + dy, CURB + 0.2),
                 (kx + 2.4, ky + dy, CURB + 2.5), (kx - 2.4, ky + dy, CURB + 2.5), glass, expect=(0, s_, 0))
    lib.col_box(lib.uname("Subway"), (5.0, 3.0, 2.5), (kx, ky, CURB + 1.25), surface="Wall")
    cyl_z(lib.uname("SubwayPole"), (kx + 3.2, ky - 1.2, CURB), 2.45, 0.05, M("Steel"), seg=8)
    box(lib.uname("SubwaySign"), (0.9, 0.9, 0.9), (kx + 3.2, ky - 1.2, CURB + 2.9), mat("SubwayGreen", "#2f7a4b"))
    school.text_mesh("Subway_sign", "M", 0.6, (kx + 3.2, ky - 1.67, CURB + 2.9), school.FACING_SOUTH,
                     mat("SignWhite", "#f2f0ea"), depth=0.02)


def market():
    """The morning market on Market Street: stalls (a table under an awning) staggered down the road, a food cart."""
    colours = ["#c8452e", "#2f6f8f", "#d9a43a", "#3f8a55", "#8a4a8f"]
    stalls = [(-4.0, -20.0), (4.0, -14.0), (-4.0, -6.0), (4.0, 2.0), (-4.0, 10.0), (4.0, 36.0), (-4.0, 44.0)]
    for i, (x, y) in enumerate(stalls):
        st = empty(lib.uname("Stall"), (x, y, 0.0), 0.0, None)
        st["bake_group"] = "world"
        box(lib.uname("Wood_StallTable") + "-col", (1.4, 2.6, 0.85), (0.0, 0.0, 0.425), mat("StallWood", "#8a6a48"), parent=st)
        for (dx, dy) in ((-0.75, -1.35), (0.75, -1.35), (-0.75, 1.35), (0.75, 1.35)):
            cyl_z(lib.uname("StallPole"), (dx, dy, 0.0), 2.3, 0.025, M("Steel"), seg=6, parent=st)
        box(lib.uname("StallRoof"), (1.8, 3.0, 0.06), (0.0, 0.0, 2.33), mat(f"StallCanvas{i % 5}", colours[i % 5]), parent=st)
        for k in range(3):
            box(lib.uname("StallCrate"), (0.4, 0.5, 0.18), (0.0, -0.8 + k * 0.8, 0.94), mat("StallCrate", "#b58a5a"), parent=st)
    # the food cart by the café
    cart = empty(lib.uname("FoodCart"), (-6.0, 26.8, 0.0), 0.0, None)
    box(lib.uname("Wall_Cart") + "-col", (1.4, 2.4, 1.1), (0.0, 0.0, 0.85), mat("CartSteel", "#c9ccd0"), parent=cart)
    box(lib.uname("CartUmbrella"), (2.4, 2.4, 0.05), (0.0, 0.0, 2.4), mat("CartYellow", "#e5b83a"), parent=cart)
    cyl_z(lib.uname("CartPole"), (0.0, 0.0, 1.4), 1.0, 0.025, M("Steel"), seg=6, parent=cart)


def cafe_tables():
    for k, y in enumerate((2.0, 6.0, 10.0)):
        props.place("round_wooden_table_02", -10.2, y, 0.0, z=CURB, surface="Wood")
    # the take-away counter under the café's window: solid down to the sidewalk (it was a plank in mid-air)
    box(lib.uname("Wood_CafeCounter") + "-col", (0.5, 2.2, 1.04), (-11.75, 13.0, CURB + 0.52), mat("StallWood", "#8a6a48"))
    props.place("round_wooden_table_02", TOWER[0] - 1.4, 41.0, 0.0, z=PLAZA_H, surface="Wood")   # the lobby desk
    props.place("standing_chalkboard_01", -9.6, 13.4, 110.0, z=CURB, surface="Wood")


def furniture():
    for x in range(-50, 51, 20):
        props.place("street_lamp_02", float(x), -30.6, 0.0, z=CURB, surface="Metal")
    for y in (-18.0, -2.0, 36.0, 52.0):
        props.place("street_lamp_02", -9.2, y, 90.0, z=CURB, surface="Metal")
        props.place("street_lamp_02", 9.2, y + 4.0, -90.0, z=CURB, surface="Metal")
    props.place("fire_hydrant", -9.0, -10.0, 0.0, z=CURB, surface="Metal")
    props.place("utility_box_01", 10.0, -24.0, 90.0, z=CURB, surface="Metal")
    for x, y in ((-9.0, 17.0), (9.4, 17.4), (-9.4, 27.0), (11.0, 28.0)):
        props.place("metal_trash_can", x, y, 0.0, z=CURB, surface="Metal")
    props.place("trashbag", -9.8, -24.0, 30.0, z=CURB, collide=False)


def plant_trees():
    spots = [(-10.0, -14.0), (10.0, -18.0), (10.0, -6.0), (-10.0, 38.0), (10.0, 58.0), (-10.0, 58.0), (-30.0, 27.0),
             (46.0, 27.0), (-50.0, 27.0), (54.0, -34.0)]          # Second Street's on its north sidewalk (road 19..25)
    for i, (x, y) in enumerate(spots):
        box(lib.uname("TreeGrate"), (1.2, 1.2, 0.012), (x, y, CURB + 0.006), M("Steel"))
        trees.tree(lib.uname("Tree"), (x, y, CURB), height=6.5 + (i * 37 % 4) * 0.6, crown=2.2 + (i * 13 % 3) * 0.3,
                   seed=160 + i, collide=True, litter=0)      # in grates on the sidewalk: no leaves on the paving


def markers():
    marker("Spawn_Player", 0.0, -24.0, 0.02, 0.0)
    marker("Start_market", 0.0, -24.0, 0.02, 0.0)
    marker("Start_cafe", -10.0, -2.0, CURB + 0.02, 0.0)
    marker("Start_plaza", 20.0, 40.0, PLAZA_H + 0.02, -90.0)
    marker("Start_ramp", 10.5, 32.0, CURB + 0.02, 0.0)
    marker("Start_corner", 16.0, 4.0, CURB + 0.02, -90.0)
    marker("Start_second", -30.0, 22.0, 0.02, -90.0)
    # the one-take run: down Market Street, across the intersection, up onto the plaza, down its stairs, to the end
    # (the START gate is ahead of the spawn, between the first stalls: roll through it to start the take)
    for i, (x, y) in enumerate(((0.0, -17.0), (0.0, -2.0), (0.0, 21.5), (26.0, 40.0), (24.0, 22.0), (0.0, 54.0))):
        z = PLAZA_H + 0.02 if i == 3 else 0.02
        marker(f"Event_check_{i + 1}", x, y, z, 0.0 if i != 3 else 90.0)
    # the coffee: from the café's window -> the tower's lobby door on the plaza
    lo, hi = props.bounds("round_wooden_table_02")
    marker("Event_coffee_pickup", -11.75, 13.0, CURB + 1.05)
    marker("Event_coffee_drop", TOWER[0] - 1.4, 41.0, PLAZA_H + hi.z + 0.02)
    marker("Event_zone_camera", 21.0, 8.0, CURB + 0.02)
    # V-I-R-A-L: over the café tables, up the plaza ramp, over the stairs, the bank to wall, a market stall
    for letter, (x, y, z) in zip("VIRAL", ((-8.8, 4.0, 1.9), (10.5, 44.0, 3.2), (24.0, 27.5, 2.8), (13.2, -12.0, 2.7),
                                          (0.0, 31.0, 2.0))):
        marker(f"Event_letter_{letter}", x, y, z)


def write_look(out):
    import json
    look = {"joints": {"PBR_concrete": {"grid": [2.0, 2.0], "rect": [-62.0, -30.0, 62.0, 62.0], "along_x": 1.5}},
            "bake_energy": 2.8, "exposure": 1.0, "sky_display": 3.6,   # tall blocks shade the streets: lift the bake
            "shade_floor": 0.2}                                     # and never let a canyon floor go black
    with open(os.path.splitext(out)[0] + ".look.json", "w") as f:
        json.dump(look, f, indent=1)


def build(out, bake=True, samples=128):
    realism.set_sky(SKY)
    ground()
    buildings()
    civic_plaza()
    street_spots()
    market()
    cafe_tables()
    furniture()
    plant_trees()
    markers()
    # the city goes on: paved to the horizon, blocks all round (the streets used to end in a grassy meadow)
    terrain.backdrop(road_top=0.0, walk_top=CURB, ground=("FarCity", "#9c988f"), far_trees=False, hills=False)
    terrain.city_blocks(seed=11)
    objs = list(bpy.context.scene.objects)
    realism.dress([o for o in objs if not o.get("library") and not o.name.startswith(("Tree", "Far_Tree", "FarTree"))])
    realism.split_collision()
    plaza_ob = realism.join_static("Baked_plaza", group="plaza")
    world = realism.join_static("Baked_world", group="world")
    if plaza_ob is not None:
        plaza_ob["bake_group"] = "plaza"
    if world is not None:
        world["bake_group"] = "world"
    if bake:
        base = os.path.splitext(out)[0]
        realism.bake(plaza_ob, base + ".lightmap.plaza.png", samples=samples)
        realism.bake(world, base + ".lightmap.world.png", size=1024, samples=samples)
    props.remove_library()
    realism.join_live()
    terrain.join_far()
    write_look(out)
