"""
Level 4, the Warehouse District: an old industrial block in the late afternoon, where the Musician's band plays a
record release show at the Foundry (a converted brick warehouse). Everyday street spots, no skate park:

    the Foundry's dock    a long loading dock (1.2 m) along the venue's front, its edge a ledge, a ramp down at the
                          east end; the tour van parked below it
    the lot               a big parking lot in front: painted bays, wheel stops, a long median curb with lamps
    the stage             a scaffold stage at the lot's east end (its front edge a ledge), speaker stacks, the fans
    the alley             between the Foundry and the next warehouse: a concrete bank up the wall, dumpsters, a side
                          door up three steps with a handrail
    warehouse B           corrugated sheds with their own dock, reached up a long ramp with a handrail
    the street            along the south edge, the same band as the other levels

Blender axes (Z up); Godot sees (x, z, -y). Same pipeline as school.py and campus.py.

Event markers: Event_letter_<L> (V-I-N-Y-L), Event_merch_pickup / _drop, Event_kid_<n> (the fans),
Event_zone_stage (the front of the stage), Start_<name> warp spots, Spawn_Player.
"""

import math
import os

import bpy

import houses
import lib
from lib import box, cyl_between, cyl_z, empty, mat, prism, rail
from neighborhood import marker, paint, root, slab
import park_props as props
from pieces import M, kicker
import realism
import school
import terrain
import trees

SKY = "kloofendal_38d_partly_cloudy_puresky"
LAWN_Z = terrain.LAWN_Z
ROAD_Z = terrain.ROAD_Z

FOUNDRY = (-44.0, 0.0, 10.0, 40.0)        # x0, x1, y0, y1 (the venue)
FOUNDRY_H = 9.0
DOCK = (-38.0, -8.0, 4.0, 10.0)           # the Foundry's dock platform
DOCK_H = 1.2
SHEDS = (10.0, 50.0, 16.0, 44.0)          # warehouse B
B_DOCK = (14.0, 46.0, 11.0, 16.0)
LOT = (-46.0, 52.0, -27.0, 4.0)
STAGE = (40.0, -10.0, 8.0, 4.0)           # x0, x1 (the back), y0, y1 ... see stage()

HARD = [
    (LOT[0], LOT[1], LOT[2], LOT[3]),
    (FOUNDRY[0] - 1.0, FOUNDRY[1] + 1.0, FOUNDRY[2] - 7.0, FOUNDRY[3] + 1.0),
    (SHEDS[0] - 1.0, SHEDS[1] + 1.0, B_DOCK[2] - 1.0, SHEDS[3] + 1.0),
    (0.0, 10.0, 4.0, 44.0),                            # the alley
    (-60.0, 60.0, -60.0, -30.0),                       # the street and beyond
    (-60.0, -46.0, -30.0, 44.0), (52.0, 60.0, -30.0, 44.0),
]
MOUNDS = [(-54.0, 50.0, 8.0, 1.5), (50.0, 54.0, 8.0, 1.2), (0.0, 52.0, 6.0, 1.0)]


# ------------------------------------------------------------------ ground

def ground():
    terrain.configure(HARD, MOUNDS)
    terrain.lawn()
    slab("SidewalkN", "Concrete", "Sidewalk", -60.0, 60.0, -32.5, -30.0, top=0.0, t=-ROAD_Z)
    slab("Road", "Path", "Road", -60.0, 60.0, -40.5, -32.5, top=ROAD_Z, t=0.3)
    slab("SidewalkS", "Concrete", "Sidewalk", -60.0, 60.0, -43.0, -40.5, top=0.0, t=-ROAD_Z)
    slab("FarLot", "Path", "Road", -60.0, 60.0, -60.0, -43.0, top=0.0, t=0.1)
    slab("Lot", "Path", "Road", LOT[0], LOT[1], LOT[2], LOT[3], top=0.0, t=0.1, group="plaza")
    slab("LotApron", "Path", "Road", LOT[0], LOT[1], LOT[2] - 3.0, LOT[2], top=0.0, t=0.1)
    slab("Alley", "Path", "Road", 0.0, 10.0, LOT[3], 44.0, top=0.0, t=0.1, group="plaza")
    slab("DockApron", "Path", "Road", FOUNDRY[0], FOUNDRY[1], LOT[3], FOUNDRY[2], top=0.0, t=0.1, group="plaza")
    slab("BApron", "Path", "Road", 10.0, SHEDS[1] + 2.0, LOT[3], B_DOCK[2], top=0.0, t=0.1, group="plaza")
    slab("Yards", "Path", "Road", -60.0, -46.0, -30.0, 44.0, top=0.0, t=0.1)
    slab("YardsE", "Path", "Road", 52.0, 60.0, -30.0, 44.0, top=0.0, t=0.1)


# ------------------------------------------------------------------ buildings

def foundry():
    """The venue: a two-storey brick warehouse with big steel-framed windows, a roll-up door onto the dock, a marquee
    over the door and a fire escape."""
    x0, x1, y0, y1 = FOUNDRY
    w, d = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    brick = mat("Brick", "#9c4e3d")
    trim = mat("SteelFrame", "#2b2f33")
    box("Wall_Foundry-col", (w, d, FOUNDRY_H), (cx, cy, FOUNDRY_H / 2), brick)
    box(lib.uname("Foundry_parapet"), (w + 0.3, d + 0.3, 0.45), (cx, cy, FOUNDRY_H + 0.2), mat("StoneDk", "#6e6a64"))
    box(lib.uname("Foundry_roof"), (w - 0.4, d - 0.4, 0.06), (cx, cy, FOUNDRY_H + 0.04), mat("Stone", "#7a7a78"))
    r = empty(lib.uname("FoundryWindows"), (0, 0, 0), 0.0, None)
    n = int(w // 4.4)
    for i in range(n):
        x = x0 + w * (i + 0.5) / n
        houses._window(r, x, y0, 5.2, 3.2, 2.6, trim, facing=-1)       # upper row all along
        if not (DOCK[0] - 1.0 < x < DOCK[1] + 1.0):
            houses._window(r, x, y0, 1.6, 3.2, 2.4, trim, facing=-1)
        houses._window(r, x, y1, 3.5, 3.2, 2.6, trim, facing=1)
    for yy in (y0 + 6.0, cy, y1 - 6.0):
        for z in (1.6, 5.2):
            houses._window_side(r, x0, yy, z, 3.2, 2.4, trim)
            houses._window_side(r, x1, yy, z, 3.2, 2.4, trim)
    # roll-up doors onto the dock, the marquee over the main door (west end, at street level)
    for x in (-30.0, -18.0):
        box(lib.uname("Foundry_rolldoor"), (3.6, 0.08, 3.4), (x, y0 - 0.04, DOCK_H + 1.7), mat("Galv", "#9ea4a8"))
    box(lib.uname("Foundry_door"), (2.2, 0.08, 2.6), (-41.0, y0 - 0.04, 1.3), mat("DoorRed", "#7c2b25"))
    box(lib.uname("Marquee"), (6.0, 1.8, 0.9), (-41.0, y0 - 0.9, 3.4), mat("MarqueeBlack", "#15171a"))
    school.text_mesh("Marquee_text", "THE FOUNDRY", 0.42, (-41.0, y0 - 1.84, 3.55), school.FACING_SOUTH,
                     mat("MarqueeLights", "#f4d27a"), depth=0.02)
    school.text_mesh("Marquee_sub", "RECORD RELEASE TONIGHT", 0.17, (-41.0, y0 - 1.84, 3.15), school.FACING_SOUTH,
                     mat("SignWhite", "#f2f0ea"), depth=0.01)
    # the fire escape on the east wall (decoration: landings and stairs up the brick)
    steel = M("Steel")
    for k, z in enumerate((3.4, 6.6)):
        box(lib.uname("FireEscape_landing"), (1.2, 4.0, 0.08), (x1 + 0.6, 30.0, z), steel)
        cyl_between(lib.uname("FireEscape_rail"), (x1 + 1.2, 28.0, z + 0.9), (x1 + 1.2, 32.0, z + 0.9), 0.02, steel, seg=6)
        cyl_between(lib.uname("FireEscape_stair"), (x1 + 0.6, 28.0 if k == 0 else 32.0, z),
                    (x1 + 0.6, 32.0 if k == 0 else 28.0, z + 3.2), 0.05, steel, seg=6)


def foundry_dock():
    """The long loading dock along the Foundry's front: its south edge is a ledge (steel angle), a ramp down at the
    east end, bumpers on its face."""
    x0, x1, y0, y1 = DOCK
    conc = mat("Concrete", "#b5b3ad")
    box("Concrete_FoundryDock-col", (x1 - x0, y1 - y0, DOCK_H), ((x0 + x1) / 2, (y0 + y1) / 2, DOCK_H / 2), conc)
    L = 7.0
    # profile (along the ramp, up) extruded across it, turned +90 degrees: high end at the dock (x1), down eastward
    ramp = prism("Concrete_FoundryDockSlope-col", [(0.0, 0.0), (L, DOCK_H), (L, 0.0)], y0, y1, [conc] * 3,
                 [0, 0, 0], [False] * 3, cap_mat=0)
    ramp.rotation_euler = (0.0, 0.0, math.pi / 2)
    ramp.location = (x1 + L, 0.0, 0.0)
    cyl_between(lib.uname("DockEdge"), (x0 + 0.1, y0 + 0.04, DOCK_H + 0.01), (x1 - 0.1, y0 + 0.04, DOCK_H + 0.01), 0.04,
                M("Galv"), seg=6, smooth=False)
    rail(None, "dock_ledge", [(x0 + 0.3, y0 + 0.05, DOCK_H + 0.07), (x1 - 0.3, y0 + 0.05, DOCK_H + 0.07)], kind="ledge")
    rubber = mat("Rubber", "#1e1e1e")
    for x in range(int(x0) + 3, int(x1), 5):
        box(lib.uname("DockBumper"), (0.5, 0.14, 0.45), (x, y0 - 0.07, DOCK_H - 0.35), rubber)
    props.place("plastic_crate_02", x0 + 2.0, y1 - 1.0, 10.0, z=DOCK_H, surface="Wall")
    props.place("plastic_crate_02", x0 + 2.1, y1 - 1.0, -8.0, z=DOCK_H + 0.28, collide=False)


def tour_van():
    """The band's van, parked below the dock with its back doors open: the merch comes out of here."""
    tx, ty = -24.0, 1.3
    van = empty(lib.uname("TourVan"), (tx, ty, 0.0), 0.0, None)
    van["bake_group"] = "world"
    paint_ = mat("VanWhite", "#e9e6df")
    box(lib.uname("Wall_VanBody") + "-col", (5.2, 2.0, 2.0), (0.0, 0.0, 1.3), paint_, parent=van)
    box(lib.uname("Wall_VanNose") + "-col", (1.0, 1.9, 1.2), (3.05, 0.0, 0.95), paint_, parent=van)
    box(lib.uname("VanWindshield"), (0.05, 1.7, 0.7), (2.6, 0.0, 1.85), houses.glass(), parent=van)
    for (x, y) in ((-1.8, -0.9), (-1.8, 0.9), (2.2, -0.9), (2.2, 0.9)):
        cyl_between(lib.uname("VanWheel"), (x, y - 0.12, 0.38), (x, y + 0.12, 0.38), 0.38, mat("Rubber", "#1e1e1e"),
                    seg=16, parent=van)
    box(lib.uname("VanStripe"), (5.2, 2.02, 0.25), (0.0, 0.0, 1.55), mat("VanStripe", "#c8452e"), parent=van)
    for s in (-1, 1):                                            # back doors, swung open
        box(lib.uname("VanDoor"), (0.06, 0.9, 1.7), (-2.65, s * 1.4, 1.2), paint_, parent=van)
    box(lib.uname("VanCargo"), (0.02, 1.8, 1.6), (-2.58, 0.0, 1.25), mat("VanDark", "#1a1c1e"), parent=van)


def sheds():
    """Warehouse B: corrugated sheds with their own dock, a long ramp up to it with a handrail."""
    x0, x1, y0, y1 = SHEDS
    w, d = x1 - x0, y1 - y0
    siding = mat("SidingGrey", "#8f9396")
    box("Wall_Sheds-col", (w, d, 7.0), ((x0 + x1) / 2, (y0 + y1) / 2, 3.5), siding)
    for k in range(4):                                           # saw-tooth roof
        xs = x0 + w * k / 4
        prism(lib.uname("ShedRoof"), [(y0, 7.0), (y1, 7.0), (y1, 9.2)], xs, xs + w / 4, [mat("RoofDark", "#3a3c3e")] * 3,
              [0, 0, 0], [False] * 3, cap_mat=0)
    for x in (18.0, 30.0, 42.0):
        box(lib.uname("Shed_rolldoor"), (4.0, 0.08, 3.6), (x, y0 - 0.04, DOCK_H + 1.8), mat("Galv", "#9ea4a8"))
    # graffiti panels down the alley wall (colour blocks)
    colours = ["#d9453a", "#f2b632", "#2f8fd8", "#3fbf73", "#a34fd1", "#f07b2f"]
    for k in range(6):
        box(lib.uname("Graffiti"), (0.02, 3.2, 2.2), (x0 - 0.02, y0 + 3.0 + k * 3.8, 1.6 + (k % 2) * 0.6),
            mat(f"Graffiti{k}", colours[k]))
    # the dock along the south face, and the ramp up to it from the lot
    bx0, bx1, by0, by1 = B_DOCK
    conc = mat("Concrete", "#b5b3ad")
    box("Concrete_ShedDock-col", (bx1 - bx0, by1 - by0, DOCK_H), ((bx0 + bx1) / 2, (by0 + by1) / 2, DOCK_H / 2), conc)
    cyl_between(lib.uname("DockEdge"), (bx0 + 0.1, by0 + 0.04, DOCK_H + 0.01), (bx1 - 0.1, by0 + 0.04, DOCK_H + 0.01), 0.04,
                M("Galv"), seg=6, smooth=False)
    rail(None, "shed_ledge", [(bx0 + 0.3, by0 + 0.05, DOCK_H + 0.07), (bx1 - 0.3, by0 + 0.05, DOCK_H + 0.07)], kind="ledge")
    L = 12.0                                   # the ramp: up eastward onto the dock's west end, a handrail on its south side
    ramp = prism("Concrete_ShedRamp-col", [(0.0, 0.0), (L, DOCK_H), (L, 0.0)], -by1, -by0, [conc] * 3,
                 [0, 0, 0], [False] * 3, cap_mat=0)
    ramp.rotation_euler = (0.0, 0.0, -math.pi / 2)
    ramp.location = (bx0 - L, 0.0, 0.0)
    galv = M("Galv")
    ry = by0 + 0.25
    xa, xb = bx0 - L + 0.8, bx0 - 0.2
    p0 = (xa, ry, DOCK_H * (xa - (bx0 - L)) / L + 0.95)
    p1 = (xb, ry, DOCK_H * (xb - (bx0 - L)) / L + 0.95)
    cyl_between(lib.uname("ShedRampRail"), p0, p1, 0.026, galv, seg=12)
    for k in range(6):
        t = k / 5
        x = xa + (xb - xa) * t
        base = DOCK_H * (x - (bx0 - L)) / L
        cyl_z(lib.uname("RailPost"), (x, ry, base), p0[2] + (p1[2] - p0[2]) * t - base, 0.022, galv, seg=10)
    c = lib.col_box(lib.uname("ShedRampRail"), (math.hypot(p1[0] - p0[0], p1[2] - p0[2]), 0.08, 0.08), (0, 0, 0),
                    surface="Metal")
    c.location = ((p0[0] + p1[0]) / 2, ry, (p0[2] + p1[2]) / 2)
    c.rotation_euler = (0.0, -math.atan2(p1[2] - p0[2], p1[0] - p0[0]), 0.0)
    rail(None, "ramp_rail", [(p0[0] + 0.1, ry, p0[2] + 0.06), (p1[0] - 0.1, ry, p1[2] + 0.06)], kind="rail")


def alley():
    """Between the Foundry and the sheds: a concrete bank up the sheds' wall, dumpsters, and a side door of the
    Foundry up three steps with a handrail."""
    conc = mat("Concrete", "#b5b3ad")
    prism("Concrete_AlleyBank-col", [(0.0, 0.0), (0.0, 1.5), (2.2, 0.0)], 20.0, 32.0, [conc] * 3, [0, 0, 0],
          [False] * 3, cap_mat=0)
    bnk = bpy.data.objects["Concrete_AlleyBank-col"]
    bnk.rotation_euler = (0.0, 0.0, math.pi / 2)                 # the profile's y runs west from the sheds' wall
    bnk.location = (SHEDS[0], 0.0, 0.0)
    for (x, y, rot) in ((2.2, 36.0, 0.0), (7.2, 14.0, 90.0)):
        dump = empty(lib.uname("Dumpster"), (x, y, 0.0), math.radians(rot), None)
        box(lib.uname("Wall_Dumpster") + "-col", (1.9, 1.3, 1.3), (0.0, 0.0, 0.65), mat("DumpsterGreen", "#2f4a36"),
            parent=dump)
        box(lib.uname("DumpsterLid"), (1.95, 1.35, 0.06), (0.0, 0.0, 1.33), mat("Rubber", "#1e1e1e"), parent=dump)
    # the Foundry's side door: a landing and three steps down into the alley, a handrail beside them
    n, rise, run = 3, 0.18, 0.4
    Ht = n * rise
    box("Concrete_SideLanding-col", (1.6, 2.6, Ht), (FOUNDRY[1] + 0.8, 24.0, Ht / 2), conc)
    stp = empty(lib.uname("SideSteps"), (FOUNDRY[1] + 1.6, 24.0, 0.0), -math.pi / 2, None)   # riding local +Y = east
    stp["bake_group"] = "plaza"
    pts = [(-0.3, 0.0), (-0.3, Ht), (0.0, Ht)]
    em = [0, 0]
    for k in range(1, n + 1):
        z = Ht - k * rise
        pts.append(((k - 1) * run, z))
        em.append(0)
        if k < n:
            pts.append((k * run, z))
            em.append(0)
    em.append(0)
    prism(lib.uname("Concrete_SideSteps"), pts, -1.3, 1.3, [conc], em, [False] * len(pts), cap_mat=0, parent=stp)
    prism(lib.uname("Concrete_SideSlope") + "-colonly", [(-0.3, 0.0), (-0.3, Ht), (0.0, Ht), (n * run, 0.0)], -1.3, 1.3,
          [M("Collision")], [0, 0, 0, 0], cap_mat=0, parent=stp)
    galv = M("Galv")
    x = 1.15
    slope = rise / run
    y0, y1 = -0.4, (n - 1) * run + 0.3
    z0, z1 = Ht + 0.85 - y0 * slope, Ht + 0.85 - y1 * slope
    cyl_between(lib.uname("SideRail"), (x, y0, z0), (x, y1, z1), 0.024, galv, seg=12, parent=stp)
    for (y, z) in ((y0, z0), (y1, z1)):
        base = Ht if y <= 0 else Ht - min(n, int(y / run) + 1) * rise
        cyl_z(lib.uname("RailPost"), (x, y, base), z - base, 0.021, galv, seg=10, parent=stp)
    c = lib.col_box(lib.uname("SideRail"), (0.08, math.hypot(y1 - y0, z1 - z0), 0.08), (0, 0, 0), parent=stp, surface="Metal")
    c.location = (x, (y0 + y1) / 2, (z0 + z1) / 2)
    c.rotation_euler = (math.atan2(z1 - z0, y1 - y0), 0, 0)
    rail(stp, "alley_rail", [(x, y0 + 0.05, z0 + 0.06), (x, y1 - 0.05, z1 + 0.06)], kind="rail")
    box(lib.uname("SideDoor"), (0.08, 1.1, 2.2), (FOUNDRY[1] + 0.04, 24.0, Ht + 1.1), mat("DoorRed", "#7c2b25"))


# ------------------------------------------------------------------ the lot and the stage

def lot():
    white = paint("LineWhite", "#e6e3da")
    conc = mat("Concrete", "#b5b3ad")
    z = 0.004
    stops = 0
    for (ys, ye, stop_y) in ((-26.0, -21.0, -25.3), (-6.0, -1.0, -1.7)):
        x = -44.0
        while x <= 20.0:
            box(lib.uname("BayLine"), (0.1, ye - ys, 0.008), (x, (ys + ye) / 2, z), white)
            if x + 2.6 <= 21.0 and not (-30.0 < x < -16.0 and stop_y > -5.0):
                box(lib.uname("Concrete_WheelStop") + "-col", (1.8, 0.2, 0.12), (x + 1.3, stop_y, 0.06), conc)
                if stops % 3 == 0:
                    rail(None, f"wheelstop_{stops}", [(x + 0.5, stop_y, 0.19), (x + 2.1, stop_y, 0.19)], kind="curb")
                stops += 1
            x += 2.6
    # the median down the lot: a raised curb (both edges grindable) with lamps
    box("Concrete_Median-col", (46.0, 2.2, 0.16), (-12.0, -13.5, 0.08), conc)
    for yy, tag in ((-14.6, "s"), (-12.4, "n")):
        rail(None, f"median_curb_{tag}", [(-34.6, yy, 0.23), (10.6, yy, 0.23)], kind="curb")
    for x in (-30.0, -12.0, 6.0):
        props.place("street_lamp_02", x, -13.5, 90.0, z=0.16, surface="Metal")
    # cars: a few in the bays (none by the spawn, where one would fill the camera)
    for x, y, rot in ((-39.2, -23.5, 180.0), (-28.8, -23.5, 180.0), (7.8, -3.5, 0.0),
                      (13.0, -3.5, 0.0), (-36.6, -3.5, 0.0)):
        props.place("covered_car", x, y, rot, surface="Wall")


def stage():
    """A scaffold stage at the lot's east end facing west: a 1.1 m deck (its front edge a ledge), truss towers and a
    top beam, speaker stacks, stairs at the back; the merch table beside it."""
    sx0, sx1, sy0, sy1 = 38.0, 48.0, -10.0, 2.0
    sh = 1.1
    deck = mat("StageDeck", "#2a2522")
    box("Wood_Stage-col", (sx1 - sx0, sy1 - sy0, sh), ((sx0 + sx1) / 2, (sy0 + sy1) / 2, sh / 2), deck)
    box(lib.uname("StageSkirt"), (0.04, sy1 - sy0, sh - 0.05), (sx0 - 0.02, (sy0 + sy1) / 2, sh / 2), mat("Skirt", "#111214"))
    cyl_between(lib.uname("StageEdge"), (sx0 + 0.03, sy0 + 0.1, sh), (sx0 + 0.03, sy1 - 0.1, sh), 0.04, M("Steel"), seg=6,
                smooth=False)
    rail(None, "stage_edge", [(sx0 + 0.05, sy0 + 0.3, sh + 0.07), (sx0 + 0.05, sy1 - 0.3, sh + 0.07)], kind="ledge")
    steel = M("Steel")
    for (x, y) in ((sx0 + 0.4, sy0 + 0.4), (sx0 + 0.4, sy1 - 0.4), (sx1 - 0.4, sy0 + 0.4), (sx1 - 0.4, sy1 - 0.4)):
        for dx in (-0.2, 0.2):
            for dy in (-0.2, 0.2):
                cyl_z(lib.uname("Truss"), (x + dx, y + dy, sh), 5.5, 0.03, steel, seg=6)
    for y in (sy0 + 0.4, sy1 - 0.4):
        cyl_between(lib.uname("TrussTop"), (sx0 + 0.4, y, sh + 5.4), (sx1 - 0.4, y, sh + 5.4), 0.06, steel, seg=8)
    cyl_between(lib.uname("TrussTop"), (sx0 + 0.4, sy0 + 0.4, sh + 5.4), (sx0 + 0.4, sy1 - 0.4, sh + 5.4), 0.06, steel, seg=8)
    box(lib.uname("StageBanner"), (0.05, 8.0, 1.2), (sx0 + 0.35, (sy0 + sy1) / 2, sh + 4.6), mat("BannerBlack", "#15171a"))
    school.text_mesh("StageBanner_text", "RECORD RELEASE", 0.55, (sx0 + 0.29, (sy0 + sy1) / 2, sh + 4.6),
                     (math.pi / 2, 0.0, -math.pi / 2), mat("MarqueeLights", "#f4d27a"), depth=0.02)
    for y in (sy0 + 1.0, sy1 - 1.0):
        box(lib.uname("Wall_SpeakerStack") + "-col", (1.0, 1.2, 2.4), (sx0 - 0.9, y, 1.2), mat("Rubber", "#1e1e1e"))
    for y in ((sy0 + sy1) / 2 - 2.0, (sy0 + sy1) / 2 + 2.0):
        box(lib.uname("Amp"), (0.7, 1.0, 0.8), (sx1 - 2.0, y, sh + 0.4), mat("Rubber", "#1e1e1e"))
    box(lib.uname("DrumRiser"), (2.4, 2.4, 0.4), (sx1 - 2.6, (sy0 + sy1) / 2, sh + 0.2), deck)
    # stairs up the back (decoration: nobody rides round the back)
    for k in range(5):
        box(lib.uname("StageStair"), (0.3, 1.2, 0.22 * (k + 1)), (sx1 + 1.5 - k * 0.3, sy1 - 1.0, 0.11 * (k + 1)), steel)
    props.place("round_wooden_table_02", 30.0, 6.0, 0.0, surface="Wood")          # the merch table
    kicker(root("StageKicker", 34.8, -4.0, -90.0), W=2.2, R=4.0, H=0.8)            # up onto the stage's front edge


def furniture():
    for x in range(-50, 51, 20):
        props.place("street_lamp_02", float(x), -32.1, 0.0, surface="Metal")
    props.place("fire_hydrant", -8.0, -32.1, 90.0, surface="Metal")
    props.place("utility_box_01", 24.0, -29.4, 0.0, surface="Metal")
    for x, y in ((-46.5, 2.0), (1.0, 3.0), (52.5, -20.0), (-2.0, 40.0)):
        props.place("metal_trash_can", x, y, 0.0, surface="Metal")
    for x, y, rot in ((-6.0, 3.2, 0.0), (26.0, 10.0, 90.0)):
        props.place("trashbag", x, y, rot, collide=False)
    for k in range(4):
        props.place("plastic_crate_02", 9.0, 28.0 + k * 0.5, 20.0 * k, z=0.28 * (k % 2), collide=k % 2 == 0,
                    surface="Wall")


def plant_trees():
    spots = [(-54.0, 20.0), (-54.0, 6.0), (56.0, 10.0), (56.0, 30.0), (-20.0, 48.0), (26.0, 50.0), (-50.0, -20.0),
             (56.0, -18.0)]
    for x in range(-54, 55, 16):                              # a few street trees along the sidewalk
        spots.append((float(x) + 4.0, -28.4))
    for i, (x, y) in enumerate(spots):
        h = 6.0 + (i * 37 % 5) * 0.7
        trees.tree(lib.uname("Tree"), (x, y, terrain.lawn_z(x, y)), height=h, crown=2.4 + (i * 13 % 4) * 0.35, seed=120 + i)


def markers():
    marker("Spawn_Player", -2.0, -22.0, 0.02, 0.0)
    marker("Start_lot", -2.0, -22.0, 0.02, 0.0)
    marker("Start_dock", -36.0, 7.0, DOCK_H + 0.02, -90.0)
    marker("Start_stage", 22.0, -4.0, 0.02, -90.0)
    marker("Start_alley", 5.0, 42.0, 0.02, 180.0)
    marker("Start_ramp", 0.0, 9.0, 0.02, -90.0)
    marker("Start_median", -40.0, -13.5, 0.2, -90.0)
    # the fans, in front of the stage (a character at rot 0 faces south; rot -90 faces west... they face the stage: east)
    for i, (x, y, rot) in enumerate(((31.5, -7.0, 95.0), (33.0, -3.5, 80.0), (31.0, 0.5, 100.0))):
        marker(f"Event_kid_{i + 1}", x, y, 0.02, rot)
    # the merch: out of the back of the van -> the merch table beside the stage
    lo, hi = props.bounds("round_wooden_table_02")
    marker("Event_merch_pickup", -24.0 - 2.9, 1.3, 1.05)
    marker("Event_merch_drop", 30.0, 6.0, hi.z + 0.02)
    marker("Event_zone_stage", 31.0, -4.0, 0.02)
    # V-I-N-Y-L: off the Foundry's dock, over the median, the alley bank, up the sheds' ramp, over the stage edge
    for letter, (x, y, z) in zip("VINYL", ((-22.0, 3.2, 2.4), (-12.0, -13.5, 1.8), (8.6, 26.0, 2.6), (8.0, 11.5, 2.4),
                                          (36.6, -4.0, 2.1))):
        marker(f"Event_letter_{letter}", x, y, z)


def write_look(out):
    import json
    # this sky's HDRI is bright (sky_energy ~1.24 against ~0.4-0.7 elsewhere): a low sky_display keeps the haze and the
    # sky from washing the lot out
    look = {"joints": {}, "bake_energy": 1.4, "exposure": 0.9, "sky_display": 1.4}
    with open(os.path.splitext(out)[0] + ".look.json", "w") as f:
        json.dump(look, f, indent=1)


def build(out, bake=True, samples=128):
    realism.set_sky(SKY)
    ground()
    foundry()
    foundry_dock()
    tour_van()
    sheds()
    alley()
    lot()
    stage()
    furniture()
    plant_trees()
    markers()
    tree_fn = lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed)
    terrain.backdrop(tree_fn=lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed,
                                                                         cards=60, litter=0))
    terrain.edge_trees(tree_fn)
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
