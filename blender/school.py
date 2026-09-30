"""
Level 2, Maple Grove Elementary: a real-scale primary school on a Saturday morning, where the PTA holds a
skate-a-thon to raise money for a new playground. Everyday spots, not a skate park:

    the entrance plaza    steps down from the doors with three handrails, an access ramp with its own rail,
                          planter ledges, benches, the bake sale
    the school sign       a low brick wall by the street, its capstone a ledge
    the covered walkway   a row of columns from the car park to the doors
    the car park          painted bays, wheel stops, a curb island with trees, a speed bump, parked cars
    the loading dock      a 1.1 m dock at the east end of the building, a ramp up at its south end
    the basketball court  the PTA's portable ramps for the day: two quarter pipes, a funbox, a flat bar, a kicker
    behind the school     the old fenced playground the money is for

The street runs along the south (-Y) edge like Neighborhood Park's (same street, same houses across it), the
school faces it. Blender axes (Z up); Godot sees (x, z, -y). Same pipeline as neighborhood.py: realism dresses
the kit, the skated areas bake into a sharp lightmap ("plaza"), everything else into "world"; the sky is a
mid-morning one (realism.set_sky).

Event markers: Event_gate_<n> (the lap route), Event_letter_<L> (D-O-N-A-T-E), Event_cake_pickup / _drop,
Event_kid_1 (the principal), Start_<name> warp spots, Spawn_Player.
"""

import math
import os

import bpy

import houses
import lib
from lib import box, cyl_between, cyl_z, empty, mat, prism, rail
import neighborhood as nb
from neighborhood import marker, paint, root, slab
import park_props as props
from pieces import M, flat_rail, funbox, kicker, ledge, quarter_pipe
import realism
import terrain
import trees

SKY = "qwantani_mid_morning_puresky"
LAWN_Z = terrain.LAWN_Z
ROAD_Z = terrain.ROAD_Z

BUILDING = (-45.0, 25.0, 10.0, 24.0)      # x0, x1, y0, y1
BUILDING_H = 7.4
STEPS_N, STEPS_RISE, STEPS_RUN = 6, 0.19, 0.44
LANDING_H = STEPS_N * STEPS_RISE           # the doors' level, 1.14 m
DOCK_H = 1.1

HARD = [
    (-27.0, 13.0, -13.0, 10.0),            # entrance plaza
    (-34.0, -27.0, 5.0, 10.0),             # walkway slab
    (-12.0, -8.0, -30.0, -13.0),           # path from the street
    (24.0, 28.0, -30.0, -25.0),            # path to the court
    (-46.0, 26.0, 9.0, 25.0),              # the building
    (-59.0, -29.0, -27.0, 5.0),            # car park
    (-53.0, -45.0, -30.0, -27.0),          # driveway
    (25.0, 41.0, 5.0, 25.0),               # loading dock apron
    (11.0, 45.0, -25.0, -3.0),             # basketball court
    (-11.0, 21.0, 27.0, 45.0),             # the old playground
    (-49.0, -45.0, 5.0, 36.0),             # path up the west side
    (-49.0, -11.0, 32.0, 36.0),            # path behind the school
    (-24.5, -13.5, -26.2, -24.8),          # the school sign
    (-60.0, 60.0, -60.0, -30.0),           # the street side
]
for _x in range(-45, 50, 18):              # the houses behind the school
    HARD.append((_x - 7.0, _x + 7.0, 49.0, 61.0))
MOUNDS = [(-20.0, -19.0, 4.5, 0.5), (1.0, -22.0, 5.0, 0.6), (40.0, 38.0, 10.0, 2.0), (-33.0, 45.0, 9.0, 1.6),
          (52.0, 6.0, 6.0, 1.0), (-55.0, 20.0, 5.0, 0.8)]


# ------------------------------------------------------------------ helpers

def text_mesh(name, text, size, loc, rot=(0.0, 0.0, 0.0), m=None, depth=0.02, align="CENTER"):
    """Lettering as a mesh (Blender's built-in font, extruded a little)."""
    cu = bpy.data.curves.new(name, "FONT")
    cu.body = text
    cu.size = size
    cu.extrude = depth
    cu.align_x = align
    cu.align_y = "CENTER"
    tmp = bpy.data.objects.new(name + "_tmp", cu)
    bpy.context.scene.collection.objects.link(tmp)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(tmp.evaluated_get(dg))
    bpy.data.objects.remove(tmp)
    ob = bpy.data.objects.new(lib.uname(name), me)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = rot
    if m is not None:
        me.materials.append(m)
    return ob


FACING_SOUTH = (math.pi / 2, 0.0, 0.0)     # a text mesh's face turned toward -Y (the street)


# ------------------------------------------------------------------ ground

def ground():
    terrain.configure(HARD, MOUNDS)
    terrain.lawn()
    slab("SidewalkN", "Concrete", "Sidewalk", -60.0, 60.0, -32.5, -30.0, top=0.0, t=-ROAD_Z)
    slab("Road", "Path", "Road", -60.0, 60.0, -40.5, -32.5, top=ROAD_Z, t=0.3)
    slab("SidewalkS", "Concrete", "Sidewalk", -60.0, 60.0, -43.0, -40.5, top=0.0, t=-ROAD_Z)
    slab("FrontYards", "Grass", "Grass", -60.0, 60.0, -60.0, -43.0, top=LAWN_Z)
    slab("Plaza", "Plaza", "Plaza", -27.0, 13.0, -13.0, 10.0, top=0.0, t=0.1, group="plaza")
    slab("Walkway", "Plaza", "Plaza", -34.0, -27.0, 5.0, 10.0, top=0.0, t=0.1, group="plaza")
    slab("PathIn", "Path", "Path", -12.0, -8.0, -30.0, -13.0, top=-0.01, t=0.08)
    slab("PathCourt", "Path", "Path", 24.0, 28.0, -30.0, -25.0, top=-0.01, t=0.08)
    slab("PathWest", "Path", "Path", -49.0, -45.0, 5.0, 36.0, top=-0.01, t=0.08)
    slab("PathBack", "Path", "Path", -49.0, -11.0, 32.0, 36.0, top=-0.01, t=0.08)
    slab("CarPark", "Path", "Road", -59.0, -29.0, -27.0, 5.0, top=0.0, t=0.1, group="plaza")
    slab("Driveway", "Path", "Road", -53.0, -45.0, -30.0, -27.0, top=-0.01, t=0.1)
    slab("Apron", "Path", "Road", 25.0, 41.0, 5.0, 25.0, top=0.0, t=0.1, group="plaza")
    slab("Court", "Path", "Court", 11.0, 45.0, -25.0, -3.0, top=0.0, t=0.1, group="plaza")
    slab("Playground", "Grass", "Dirt", -10.0, 20.0, 28.0, 44.0, top=0.0, t=0.1)


# ------------------------------------------------------------------ the building

def building():
    x0, x1, y0, y1 = BUILDING
    w, d = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    brick = mat("Brick", "#aa5544")
    trim = mat("Trim", "#f2f2ee")
    box("Wall_School-col", (w, d, BUILDING_H), (cx, cy, BUILDING_H / 2), brick)
    box(lib.uname("School_plinth"), (w + 0.12, d + 0.12, 0.6), (cx, cy, 0.3), mat("Concrete", "#bbbbbb"))
    box(lib.uname("School_parapet"), (w + 0.3, d + 0.3, 0.3), (cx, cy, BUILDING_H + 0.15), trim)
    box(lib.uname("School_roof"), (w - 0.4, d - 0.4, 0.06), (cx, cy, BUILDING_H + 0.05), mat("Stone", "#999999"))
    for sx in (x0 + 6.0, x1 - 9.0):                           # rooftop units
        box(lib.uname("School_hvac"), (3.0, 2.2, 1.4), (sx, cy + 2.0, BUILDING_H + 0.75), mat("Galv", "#9ea4a8"))
    r = empty(lib.uname("SchoolWindows"), (0, 0, 0), 0.0, None)
    rows = [2.0, 5.1]
    n = int(w // 3.6)
    for zi, z in enumerate(rows):
        for i in range(n):
            x = x0 + w * (i + 0.5) / n
            if zi == 0 and -17.0 < x < -3.0:
                continue                                      # the entrance
            if zi == 0 and x > 21.0:
                continue                                      # the dock door
            houses._window(r, x, y0, z, 2.6, 1.6, trim, facing=-1)
            houses._window(r, x, y1, z, 2.6, 1.6, trim, facing=1)
    for z in rows:
        for yy in (cy - 3.5, cy + 3.5):
            houses._window_side(r, x0, yy, z, 2.4, 1.6, trim)
    # the entrance: glass double doors, sidelights, a canopy and the school's name
    door_frame = mat("DoorFrame", "#2c3136")
    glass = houses.glass()
    for dx in (-1.25, 1.25):
        box(lib.uname("School_door"), (1.2, 0.06, 2.3), (-10.0 + dx * 0.5, y0 - 0.03, LANDING_H + 1.15), glass)
    box(lib.uname("School_doorframe"), (3.6, 0.05, 2.6), (-10.0, y0 - 0.005, LANDING_H + 1.3), door_frame)
    for sx in (-1, 1):
        box(lib.uname("School_sidelight"), (0.9, 0.06, 2.3), (-10.0 + sx * 1.9, y0 - 0.03, LANDING_H + 1.15), glass)
    box(lib.uname("School_canopy"), (9.0, 2.6, 0.22), (-10.0, y0 - 1.3, LANDING_H + 3.0), trim)
    text_mesh("School_name", "MAPLE GROVE ELEMENTARY", 0.62, (-10.0, y0 - 0.04, LANDING_H + 3.75), FACING_SOUTH,
              mat("SignNavy", "#22304a"), depth=0.04)
    # the dock door at the east end
    box(lib.uname("School_rolldoor"), (0.08, 3.2, 3.0), (x1 + 0.04, 17.5, DOCK_H + 1.5), mat("Galv", "#9ea4a8"))


def steps():
    """The front steps: a landing at the doors' level and six steps down to the plaza, a handrail down each side and
    one down the middle (named rails for the event). Built in local space riding +Y (down the steps), turned to
    face the street."""
    W = 10.0
    D = 5.0                                     # landing depth
    rt = empty(lib.uname("Steps"), (-10.0, 5.0, 0.0), math.pi, None)
    rt["bake_group"] = "plaza"
    n, rise, run = STEPS_N, STEPS_RISE, STEPS_RUN
    Ht = n * rise
    pts = [(-D, 0.0), (-D, Ht), (0.0, Ht)]
    em = [2, 0]
    for k in range(1, n + 1):
        z = Ht - k * rise
        pts.append(((k - 1) * run, z))
        em.append(1)
        if k < n:
            pts.append((k * run, z))
            em.append(0)
    em.append(2)
    prism(lib.uname("Concrete_FrontSteps"), pts, -W / 2, W / 2, [M("Concrete"), M("ConcreteDk"), M("ConcreteDk")], em,
          [False] * len(pts), cap_mat=1, parent=rt)
    prism(lib.uname("Concrete_FrontStepsSlope") + "-colonly", [(-D, 0.0), (-D, Ht), (0.0, Ht), (n * run, 0.0)],
          -W / 2, W / 2, [M("Collision")], [0, 0, 0, 0], cap_mat=0, parent=rt)
    slope = rise / run
    off = 0.9
    lrun = (n - 1) * run
    galv = M("Galv")
    for name, x in (("steps_rail_l", -W / 2 + 0.35), ("steps_rail_c", 0.0), ("steps_rail_r", W / 2 - 0.35)):
        y0, y1 = -0.5, lrun + 0.35
        z0 = Ht + off - y0 * slope                  # parallel to the nosings, carried on over the landing edge
        z1 = Ht + off - y1 * slope
        cyl_between(lib.uname("HandRail"), (x, y0, z0), (x, y1, z1), 0.024, galv, seg=12, parent=rt)
        for (y, z) in ((y0, z0), (y1, z1), ((y0 + y1) / 2, (z0 + z1) / 2)):
            base = Ht if y <= 0 else Ht - min(n, int(y / run) + 1) * rise
            cyl_z(lib.uname("RailPost"), (x, y, base), z - base, 0.021, galv, seg=10, parent=rt)
        c = lib.col_box(lib.uname("HandRail"), (0.08, math.hypot(y1 - y0, z1 - z0), 0.08), (0, 0, 0), parent=rt,
                        surface="Metal")
        c.location = (x, (y0 + y1) / 2, (z0 + z1) / 2)
        c.rotation_euler = (math.atan2(z1 - z0, y1 - y0), 0, 0)
        rail(rt, name, [(x, y0 + 0.05, z0 + 0.06), (x, y1 - 0.05, z1 + 0.06)], kind="rail")


def access_ramp():
    """A long ramp down from the landing along the front of the building, with a handrail on its open side."""
    L = 14.0
    Ht = LANDING_H
    rt = empty(lib.uname("AccessRamp"), (-5.0, 8.0, 0.0), math.pi / 2, None)    # local -Y runs east
    rt["bake_group"] = "plaza"
    prism(lib.uname("Concrete_AccessRamp") + "-col", [(0.0, 0.0), (0.0, Ht), (-L, 0.0)], 0.0, 2.0,
          [M("Concrete"), M("ConcreteDk"), M("ConcreteDk")], [2, 0, 2], [False] * 3, cap_mat=1, parent=rt)
    galv = M("Galv")
    x = 0.08
    p0 = (x, -0.3, Ht * (1 - 0.3 / L) + 0.9)
    p1 = (x, -L + 0.4, Ht * (0.4 / L) + 0.9)
    cyl_between(lib.uname("RampRail"), p0, p1, 0.024, galv, seg=12, parent=rt)
    for k in range(6):
        t = k / 5
        y = p0[1] + (p1[1] - p0[1]) * t
        z_top = p0[2] + (p1[2] - p0[2]) * t
        z_base = Ht * (1 + y / L)
        cyl_z(lib.uname("RailPost"), (x, y, z_base), z_top - z_base, 0.021, galv, seg=10, parent=rt)
    c = lib.col_box(lib.uname("RampRail"), (0.08, math.hypot(p1[1] - p0[1], p1[2] - p0[2]), 0.08), (0, 0, 0),
                    parent=rt, surface="Metal")
    c.location = (x, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
    c.rotation_euler = (math.atan2(p1[2] - p0[2], p1[1] - p0[1]), 0, 0)
    rail(rt, "ramp_rail", [(x, p0[1], p0[2] + 0.06), (x, p1[1], p1[2] + 0.06)], kind="rail")


def walkway():
    """A covered walkway from the car park to the doors: a flat roof on a row of square columns."""
    trim = mat("Trim", "#f2f2ee")
    for x in (-33.0, -30.0, -27.0, -24.0, -21.0, -18.0):
        box(lib.uname("Wall_WalkColumn") + "-col", (0.3, 0.3, 3.3), (x, 5.6, 1.65), trim)
    box(lib.uname("Walk_roof"), (19.0, 4.8, 0.2), (-24.5, 7.6, 3.4), trim)
    box(lib.uname("Walk_fascia"), (19.0, 0.08, 0.35), (-24.5, 5.2, 3.3), mat("SignNavy", "#22304a"))


def loading_dock():
    """A 1.1 m dock at the east end, its open edge a ledge, a ramp up at its south end, bumpers on its face."""
    x0, x1 = BUILDING[1], BUILDING[1] + 4.0
    box("Concrete_Dock-col", (x1 - x0, 11.0, DOCK_H), ((x0 + x1) / 2, 17.5, DOCK_H / 2), mat("Concrete", "#bbbbbb"))
    prism("Concrete_DockRamp-col", [(6.0, 0.0), (12.0, DOCK_H), (12.0, 0.0)], x0, x1,
          [mat("Concrete", "#bbbbbb")] * 3, [0, 0, 0], [False] * 3, cap_mat=0)
    cyl_between(lib.uname("DockEdge"), (x1 - 0.04, 12.1, DOCK_H + 0.01), (x1 - 0.04, 22.9, DOCK_H + 0.01), 0.04,
                M("Galv"), seg=6, smooth=False)
    rail(None, "dock_ledge", [(x1 - 0.05, 12.3, DOCK_H + 0.07), (x1 - 0.05, 22.7, DOCK_H + 0.07)], kind="ledge")
    rubber = mat("Rubber", "#1e1e1e")
    for y in (14.5, 20.5):
        box(lib.uname("DockBumper"), (0.14, 0.5, 0.45), (x1 + 0.07, y, DOCK_H - 0.35), rubber)
    box(lib.uname("Dumpster"), (1.9, 1.3, 1.3), (38.5, 21.0, 0.65), mat("DumpsterGreen", "#2f4a36"))
    props.place("plastic_crate_02", x0 + 1.2, 21.5, 10.0, z=DOCK_H, collide=False)
    props.place("plastic_crate_02", x0 + 1.3, 21.5, -8.0, z=DOCK_H + 0.25, collide=False)


# ------------------------------------------------------------------ the front

def front():
    # planters with shrubs; their edges are ledges
    for name, x in (("PlanterWest", -21.0), ("PlanterEast", 4.0)):
        ledge(root(name, x, -5.0, 0.0), L=6.0, W=1.1, h=0.5)
        for k in range(3):
            props.place("shrub_03", x, -7.0 + k * 2.0, 40.0 * k, z=0.5, scale=0.55, collide=False)
    for x in (-19.0, 1.0):
        props.place("modular_street_seating", x, -12.3, 0.0, z=0.0, surface="Wood")
    # the school sign by the street: brick with a concrete cap (a ledge)
    brick = mat("Brick", "#aa5544")
    box("Wall_SchoolSign-col", (10.0, 0.45, 0.75), (-19.0, -25.5, 0.375), brick)
    box("Concrete_SignCap-col", (10.3, 0.62, 0.12), (-19.0, -25.5, 0.81), mat("Concrete", "#bbbbbb"))
    text_mesh("Sign_name", "MAPLE GROVE ELEMENTARY", 0.3, (-19.0, -25.74, 0.45), FACING_SOUTH,
              mat("SignWhite", "#f2f0ea"), depth=0.015)
    text_mesh("Sign_owls", "HOME OF THE OWLS", 0.16, (-19.0, -25.74, 0.18), FACING_SOUTH, mat("SignWhite", "#f2f0ea"),
              depth=0.01)
    rail(None, "sign_ledge", [(-23.95, -25.78, 0.94), (-14.05, -25.78, 0.94)], kind="ledge")
    # the flagpole
    z = terrain.lawn_z(-24.0, -18.0)
    cyl_z(lib.uname("Flagpole"), (-24.0, -18.0, z), 9.0, 0.06, M("Galv"), r1=0.04, seg=10)
    box(lib.uname("FlagBase"), (0.8, 0.8, 0.3), (-24.0, -18.0, z + 0.1), mat("Concrete", "#bbbbbb"))
    lib.mesh_obj(lib.uname("Flag"), [(-24.0, -18.0, z + 8.9), (-22.5, -18.0, z + 8.7), (-22.5, -18.0, z + 7.9),
                                      (-24.0, -18.0, z + 7.9)], [(0, 1, 2, 3)], [mat("FlagBlue", "#2d5fb0")])
    # shrubs along the building front either side of the plaza, and the bake sale's picnic table
    for x in (-43.0, -40.5, -38.0, 14.5, 17.0, 19.5, 22.0):
        props.place("shrub_03", x, 9.2, x * 13.0, z=0.0, scale=0.75, collide=False)
    props.place("wooden_picnic_table", 8.0, 1.0, 0.0, surface="Wood")
    props.place("metal_trash_can", 11.8, -11.5, 0.0, surface="Metal")
    props.place("metal_trash_can", -25.8, -11.5, 0.0, surface="Metal")


def car_park():
    white = paint("LineWhite", "#e6e3da")
    yellow = paint("LineYellow", "#d9ac3a")
    conc = mat("Concrete", "#bbbbbb")
    z = 0.004
    # bays: north row (nose to the walkway) and south row, 2.6 m wide, wheel stops at the head of each
    stops = 0
    for row, (ys, ye, stop_y) in enumerate(((-1.0, 4.0, 3.3), (-26.0, -21.0, -25.3))):
        x = -58.0
        while x <= -31.0:
            box(lib.uname("BayLine"), (0.1, ye - ys, 0.008), (x, (ys + ye) / 2, z), white)
            if x + 2.6 <= -30.0:
                box(lib.uname("Concrete_WheelStop") + "-col", (1.8, 0.2, 0.12), (x + 1.3, stop_y, 0.06), conc)
                if stops % 2 == 0:
                    rail(None, f"wheelstop_{stops}", [(x + 0.5, stop_y, 0.19), (x + 2.1, stop_y, 0.19)], kind="curb")
                stops += 1
            x += 2.6
    # the island down the middle: a raised curb with grass, trees and two lamps
    box("Concrete_IslandCurb-col", (22.0, 3.0, 0.15), (-44.0, -11.0, 0.075), conc)
    box(lib.uname("IslandGrass"), (21.6, 2.6, 0.02), (-44.0, -11.0, 0.16), mat("Grass", "#888888"))
    for yy in (-12.5, -9.5):
        rail(None, f"island_curb_{'s' if yy < -11 else 'n'}", [(-54.8, yy, 0.22), (-33.2, yy, 0.22)], kind="curb")
    for x in (-50.0, -44.0, -38.0):
        trees.tree(lib.uname("Tree"), (x, -11.0, 0.17), height=6.2, crown=2.4, seed=int(-x))
    for x in (-54.0, -34.0):
        props.place("street_lamp_02", x, -11.0, 90.0, z=0.15, surface="Metal")
    # the speed bump across the south aisle
    bump = empty(lib.uname("Bump"), (0.0, 0.0, 0.0), math.pi / 2, None)   # local x runs along world y
    bump["bake_group"] = "plaza"
    prism("Path_SpeedBump-col", [(38.35, 0.0), (38.0, 0.08), (37.65, 0.0)], -21.0, -12.5, [mat("Road", "#555555")] * 3,
          [0, 0, 0], [False] * 3, cap_mat=0, parent=bump)
    for k in range(4):
        box(lib.uname("BumpStripe"), (0.72, 0.5, 0.01), (-38.0, -20.3 + k * 2.2, 0.085), yellow)
    # parked cars, a table by one of them with the cake for the bake sale
    for x, y, rot in ((-55.4, 1.5, 0.0), (-47.6, 1.5, 0.0), (-39.8, -23.5, 180.0), (-34.6, -23.5, 180.0)):
        props.place("covered_car", x, y, rot, surface="Wall")
    props.place("round_wooden_table_02", -44.2, 1.0, 0.0, surface="Wood")


def court():
    """A basketball court, with the PTA's portable ramps set up on it for the day."""
    line = paint("CourtLine", "#f0efe9")
    z = 0.004
    for (cx, cy, sx, sy) in ((28.0, -24.9, 34.0, 0.1), (28.0, -3.1, 34.0, 0.1), (11.1, -14.0, 0.1, 21.8),
                             (44.9, -14.0, 0.1, 21.8), (28.0, -14.0, 0.1, 21.8)):
        box(lib.uname("CourtLine"), (sx, sy, 0.008), (cx, cy, z), line)
    ring = [(28.0 + 1.8 * math.cos(a * math.tau / 32), -14.0 + 1.8 * math.sin(a * math.tau / 32), z) for a in range(33)]
    for p0, p1 in zip(ring, ring[1:]):
        lib.cyl_between(lib.uname("CourtCircle"), p0, p1, 0.05, line, seg=4, caps=False)
    for x, s in ((10.2, 1.0), (45.8, -1.0)):                  # hoops, outside the ends
        cyl_z(lib.uname("HoopPole"), (x, -14.0, 0.0), 3.3, 0.07, M("Galv"), seg=10)
        box(lib.uname("HoopArm"), (1.2, 0.1, 0.1), (x + s * 0.6, -14.0, 3.25), M("Galv"))
        box(lib.uname("Backboard"), (0.05, 1.8, 1.05), (x + s * 1.2, -14.0, 3.35), mat("Backboard", "#f4f4f2"))
        ring2 = [(x + s * 1.45 + 0.23 * math.cos(a * math.tau / 16), -14.0 + 0.23 * math.sin(a * math.tau / 16), 3.05)
                 for a in range(17)]
        for p0, p1 in zip(ring2, ring2[1:]):
            lib.cyl_between(lib.uname("Rim"), p0, p1, 0.012, mat("RimOrange", "#d4591e"), seg=4, caps=False)
    quarter_pipe(root("QPWest", 16.0, -14.0, 90.0), W=6.0, R=2.4, H=1.5, D=1.2, rails=True, decals=False)
    quarter_pipe(root("QPEast", 40.0, -14.0, -90.0), W=6.0, R=2.4, H=1.5, D=1.2, rails=True, decals=False)
    funbox(root("Funbox", 28.0, -12.0, 90.0), S=4.4, H=0.8)
    flat_rail(root("FlatBar", 28.0, -20.5, 90.0), L=5.0, h=0.42, color="Galv")
    kicker(root("Kicker", 21.0, -5.8, -90.0), W=2.6, R=5.0, H=0.7)


def playground():
    """The old playground behind the school, fenced off: a rusty swing frame, a slide, and a sign about the new one."""
    galv = M("Galv")
    fx0, fx1, fy0, fy1 = -10.0, 20.0, 28.0, 44.0
    gate = (3.0, 6.0)
    runs = [((fx0, fy0), (gate[0], fy0)), ((gate[1], fy0), (fx1, fy0)), ((fx1, fy0), (fx1, fy1)),
            ((fx1, fy1), (fx0, fy1)), ((fx0, fy1), (fx0, fy0))]
    for (ax, ay), (bx, by) in runs:
        L = math.hypot(bx - ax, by - ay)
        n = max(1, int(L / 2.5))
        for k in range(n + 1):
            t = k / n
            cyl_z(lib.uname("FencePost"), (ax + (bx - ax) * t, ay + (by - ay) * t, 0.0), 1.2, 0.025, galv, seg=8)
        for zz in (1.18, 0.6):
            cyl_between(lib.uname("FenceRail"), (ax, ay, zz), (bx, by, zz), 0.02, galv, seg=8, caps=False)
        c = lib.col_box(lib.uname("Fence"), (max(L, 0.1), 0.12, 1.4), (0, 0, 0), surface="Wall")
        c.location = ((ax + bx) / 2, (ay + by) / 2, 0.7)
        c.rotation_euler = (0, 0, math.atan2(by - ay, bx - ax))
    rust = mat("RustRed", "#8a4a36")
    for x in (0.0, 6.0):                                       # the swing frame
        for dy in (-1.1, 1.1):
            cyl_between(lib.uname("SwingLeg"), (x, 38.0 + dy, 0.0), (x, 38.0, 2.4), 0.045, rust, seg=8)
    cyl_between(lib.uname("SwingBar"), (0.0, 38.0, 2.4), (6.0, 38.0, 2.4), 0.05, rust, seg=8)
    for x in (1.8, 4.2):
        for dx in (-0.22, 0.22):
            cyl_between(lib.uname("SwingChain"), (x + dx, 38.0, 2.38), (x + dx, 38.0, 0.55), 0.008, M("Galv"), seg=4)
        box(lib.uname("SwingSeat"), (0.5, 0.2, 0.04), (x, 38.0, 0.54), mat("Rubber", "#1e1e1e"))
    box(lib.uname("Slide_tower"), (1.2, 1.2, 1.6), (14.0, 38.5, 0.8), rust)
    prism(lib.uname("Slide_chute"), [(39.1, 1.6), (39.1, 1.5), (42.5, 0.2), (42.5, 0.3)], 13.6, 14.4,
          [mat("SlideYellow", "#c9a33a")] * 4, [0, 0, 0, 0], [False] * 4, cap_mat=0)
    box(lib.uname("PlaySignPost"), (0.08, 0.08, 1.8), (7.5, 27.6, 0.9), galv)
    box(lib.uname("PlaySign"), (2.4, 0.04, 1.0), (7.5, 27.55, 1.5), mat("SignBoard", "#f4f1e8"))
    text_mesh("PlaySign_text", "OUR NEW PLAYGROUND\nIS COMING!", 0.17, (7.5, 27.52, 1.5), FACING_SOUTH,
              mat("SignNavy", "#22304a"), depth=0.005)


def furniture():
    rise = terrain.lawn_rise
    for x in range(-50, 51, 20):
        props.place("street_lamp_02", float(x), -30.6, 0.0, surface="Metal")
    props.place("fire_hydrant", -30.0, -31.0, 90.0, surface="Metal")
    props.place("utility_box_01", 20.0, -30.6, 0.0, surface="Metal")
    props.place("garden_gnome", -40.0, -45.1, 160.0, z=terrain.LAWN_Z, collide=False)
    shrubs = [(-28.2, -14.0), (-28.4, -8.0), (13.8, -14.0), (13.6, -8.0), (-7.0, -16.0), (-13.0, -16.0),
              (26.0, 3.0), (-46.5, 8.0), (46.0, -20.0), (46.0, -8.0)]
    for i, (x, y) in enumerate(shrubs):
        props.place("shrub_03", x, y, i * 47.0, z=rise(x, y) + LAWN_Z, scale=0.7 + (i * 31 % 7) * 0.08, collide=False)


def plant_trees():
    spots = []
    for x in range(-54, 55, 12):                              # street trees along the school's sidewalk
        if not -14.0 < x + 3.0 < -6.0 and not 22.0 < x + 3.0 < 30.0 and not -55.0 < x + 3.0 < -43.0:
            spots.append((float(x) + 3.0, -28.2))
    spots += [(-5.0, -20.0), (6.0, -17.0), (-26.0, -21.0), (-56.0, 12.0), (-54.0, 28.0), (-38.0, 40.0), (-24.0, 46.0),
              (-6.0, 48.0), (26.0, 46.0), (32.0, 32.0), (48.0, 28.0), (52.0, 16.0), (50.0, -26.0), (-20.0, 28.0),
              (-32.0, 29.0), (44.0, 40.0)]
    for i, (x, y) in enumerate(spots):
        h = 6.0 + (i * 37 % 5) * 0.7
        trees.tree(lib.uname("Tree"), (x, y, terrain.lawn_z(x, y)), height=h, crown=2.6 + (i * 13 % 4) * 0.35, seed=40 + i)


def markers():
    marker("Spawn_Player", -10.0, -24.0, 0.02, 0.0)
    marker("Start_front", -10.0, -24.0, 0.02, 0.0)
    marker("Start_steps", -10.0, 7.5, LANDING_H + 0.02, 180.0)
    marker("Start_carpark", -52.0, -16.0, 0.02, -90.0)
    marker("Start_court", 19.0, -9.0, 0.02, -90.0)
    marker("Start_dock", 27.0, 6.0, 0.02, 0.0)
    marker("Start_playground", 4.5, 30.0, 0.02, 0.0)
    marker("Start_street", -45.0, -36.5, 0.02, -90.0)
    # the principal, by the steps
    marker("Event_kid_1", -17.5, 1.5, 0.02, 200.0)
    # the cake: on the table by a car in the car park -> the bake sale's picnic table on the plaza
    lo, hi = props.bounds("round_wooden_table_02")
    lo2, hi2 = props.bounds("wooden_picnic_table")
    marker("Event_cake_pickup", -44.2, 1.0, hi.z + 0.02)
    marker("Event_cake_drop", 8.0, 1.0, hi2.z + 0.02)
    # the lap route: plaza -> car park -> the street -> the court -> back to the plaza
    for i, (x, y, rot) in enumerate(((-4.0, -6.0, 90.0), (-44.0, -16.0, 180.0), (-20.0, -31.2, -90.0),
                                     (26.0, -27.5, 0.0))):
        marker(f"Event_gate_{i + 1}", x, y, 0.02, rot)
    # D-O-N-A-T-E: the steps' drop, the funbox, the speed bump, over the east quarter pipe, off the dock, behind
    for letter, (x, y, z) in zip("DONATE", ((-10.0, 3.2, 2.1), (28.0, -12.0, 2.0), (-38.0, -16.0, 1.5),
                                           (42.0, -14.0, 3.3), (30.8, 17.5, 2.1), (4.5, 26.5, 1.4))):
        marker(f"Event_letter_{letter}", x, y, z)


def write_look(out):
    import json
    look = {"joints": {"PBR_concrete": {"grid": [2.5, 2.5], "rect": [-27.0, -10.0, 13.0, 13.0], "along_x": 1.5}},
            "bake_energy": 1.6, "exposure": 1.0, "sky_display": 2.2}
    with open(os.path.splitext(out)[0] + ".look.json", "w") as f:
        json.dump(look, f, indent=1)


def build(out, bake=True, samples=128):
    realism.set_sky(SKY)
    ground()
    building()
    steps()
    access_ramp()
    walkway()
    loading_dock()
    front()
    car_park()
    court()
    playground()
    furniture()
    nb.neighbourhood_houses(north=True)
    nb.street_details(crosswalk_x=-10.0)
    plant_trees()
    markers()
    tree_fn = lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed)
    terrain.backdrop(tree_fn=lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed,
                                                                         cards=60, litter=0))
    terrain.edge_trees(tree_fn)
    objs = list(bpy.context.scene.objects)
    realism.dress([o for o in objs if not o.get("library") and not o.name.startswith(("Tree", "Far_Tree", "FarTree"))])
    realism.split_collision()
    plaza = realism.join_static("Baked_plaza", group="plaza")
    world = realism.join_static("Baked_world", group="world")
    if plaza is not None:
        plaza["bake_group"] = "plaza"
    if world is not None:
        world["bake_group"] = "world"
    if bake:
        base = os.path.splitext(out)[0]
        realism.bake(plaza, base + ".lightmap.plaza.png", samples=samples)
        realism.bake(world, base + ".lightmap.world.png", size=1024, samples=samples)
    props.remove_library()
    realism.join_live()
    terrain.join_far()
    write_look(out)
