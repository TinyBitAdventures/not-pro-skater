"""
Level 6, the Big Moon Studios backlot: an afternoon between takes, the Actor's home turf. Standing sets and the lot:

    the western street    a dirt street between false-front buildings (saloon, bank, general store), a raised
                          boardwalk in front of them (its edges ledges), hitching rails to grind, barrels, a trough
    the New York street   brownstone fronts with stoops (railed steps up to the doors), a paved street between
    the stunt ramp        a big quarter pipe set piece at the north end of the main road
    the green screen      a curved cyclorama wall, rideable like a quarter pipe
    the dolly tracks      two long, low steel tracks laid in front of the New York street (grindable)
    the lot               actors' trailers, craft services, the director's chair and a camera crane

Main Avenue runs along the south edge behind the studio's fence (the same street band as the other levels).
Blender axes (Z up); Godot sees (x, z, -y).

Event markers: Event_letter_<L> (A-C-T-I-O-N), Event_mark_<n> (hit your marks), Event_script_pickup / _drop,
Event_kid_<n> (the director and crew), Start_<name>, Spawn_Player.
"""

import math
import os

import bpy

import houses
import lib
from lib import box, cyl_between, cyl_z, empty, mat, prism, rail
from neighborhood import marker, paint, root, slab
import park_props as props
from pieces import M, quarter_pipe
import realism
import school
import terrain
import trees

SKY = "qwantani_late_afternoon_puresky"
ROAD_Z = terrain.ROAD_Z
WEST_X = -30.0                               # the western street's centre line
NY_X = 30.0                                  # the New York street's centre line
BOARD_H = 0.45                               # the boardwalk

HARD = [(-62.0, 62.0, -62.0, 62.0)]
MOUNDS = []


def ground():
    terrain.configure(HARD, MOUNDS)
    terrain.lawn()
    slab("AveSidewalkN", "Concrete", "Sidewalk", -62.0, 62.0, -32.5, -30.0, top=0.0, t=-ROAD_Z)
    slab("AveRoad", "Path", "Road", -62.0, 62.0, -40.5, -32.5, top=ROAD_Z, t=0.3)
    slab("AveSidewalkS", "Concrete", "Sidewalk", -62.0, 62.0, -43.0, -40.5, top=0.0, t=-ROAD_Z)
    # (to 60 m, where the far ground takes over: out to 62 the two grasses overlapped and flickered; the edge warps you
    # back at 60 m anyway)
    slab("FarVerge", "Grass", "Grass", -60.0, 60.0, -60.0, -43.0, top=terrain.LAWN_Z)
    # the lot is poured concrete (light, like a studio's stage aprons); the western street hard-packed dirt that
    # rides like the lot (a Grass surface would grow tufts and drag)
    slab("Lot", "Concrete", "Sidewalk", -62.0, 62.0, -30.0, 62.0, top=0.0, t=0.1, group="plaza")
    slab("WestDirt", "Path", "PackedDirt", WEST_X - 5.0, WEST_X + 5.0, -22.0, 22.0, top=0.012, t=0.05, group="plaza")
    # the studio fence along the avenue, a gate and the arch over it
    galv = M("Galv")
    for (a, b) in ((-62.0, -5.0), (5.0, 62.0)):
        box(lib.uname("Wall_StudioFence") + "-col", (b - a, 0.25, 2.4), ((a + b) / 2, -29.6, 1.2), mat("Stucco", "#d8cdb8"))
    for x in (-5.0, 5.0):
        box(lib.uname("Wall_GatePost") + "-col", (1.0, 1.0, 5.4), (x, -29.6, 2.7), mat("Stucco", "#d8cdb8"))
    box(lib.uname("GateArch"), (11.0, 0.8, 1.2), (0.0, -29.6, 5.9), mat("Stucco", "#d8cdb8"))
    school.text_mesh("Gate_name", "BIG MOON STUDIOS", 0.62, (0.0, -30.06, 5.9), school.FACING_SOUTH,
                     mat("SignNavy", "#22304a"), depth=0.03)


# ------------------------------------------------------------------ the western street

def western():
    """False fronts either side of the dirt street, a boardwalk in front of them, hitching rails, barrels."""
    wood = M("Timber")
    names = [("SALOON", "#8a3b2c"), ("BANK", "#4d5f3b"), ("GENERAL STORE", "#6c4b2e"), ("SHERIFF", "#3b4a5c")]
    for side in (-1, 1):
        fx = WEST_X + side * 9.0                                  # the facades' faces
        for k, (label, colour) in enumerate(names[:2] if side < 0 else names[2:]):
            y0 = -18.0 + k * 18.0
            y1 = y0 + 14.0
            h = 6.5 if k == 0 else 5.2
            paint_ = mat(f"WestPaint{side}{k}", colour)
            box(f"Wall_WestFront{side}{k}-col", (0.4, y1 - y0, h), (fx + side * 0.2, (y0 + y1) / 2, h / 2), paint_)
            # a stepped parapet over the false front, trim boards at the top and the corners
            yc = (y0 + y1) / 2
            box(lib.uname("WestParapet"), (0.4, (y1 - y0) * 0.55, 0.7), (fx + side * 0.2, yc, h + 0.35), paint_)
            box(lib.uname("WestParapet"), (0.4, (y1 - y0) * 0.25, 0.5), (fx + side * 0.2, yc, h + 0.95), paint_)
            trim_ = mat("WestTrim", "#e8dcc0")
            for (yy, zz, ww, hh) in ((yc, h - 0.12, y1 - y0, 0.24), (yc, h + 0.62, (y1 - y0) * 0.55, 0.16),
                                     (yc, h + 1.12, (y1 - y0) * 0.25, 0.16)):
                box(lib.uname("WestCornice"), (0.12, ww + 0.1, hh), (fx - side * 0.04, yy, zz), trim_)
            for yy in (y0 + 0.08, y1 - 0.08):
                box(lib.uname("WestCorner"), (0.1, 0.16, h), (fx - side * 0.03, yy, h / 2), trim_)
            # the porch roof over the boardwalk: planks sloping out from the front on brackets (no posts: the
            # boardwalk's edge is a ledge to grind); solid, for big airs
            pr = box(f"Wood_WestPorch{side}{k}-col", (2.3, y1 - y0 - 0.4, 0.1), (0.0, 0.0, 0.0), M("Timber"))
            pr.location = (fx - side * 1.15, yc, 3.02)
            pr.rotation_euler = (0.0, -side * math.radians(6.0), 0.0)        # the outer edge lower
            for yy in (y0 + 1.0, yc, y1 - 1.0):
                cyl_between(lib.uname("PorchBracket"), (fx - side * 0.05, yy, 2.2), (fx - side * 1.3, yy, 2.95), 0.05,
                            M("Timber"), seg=6)
            # the bracing behind the false front (it's a set: nothing behind it)
            for yy in (y0 + 1.0, (y0 + y1) / 2, y1 - 1.0):
                cyl_between(lib.uname("Brace"), (fx + side * 0.4, yy, h - 0.6), (fx + side * 3.4, yy, 0.0), 0.08, wood, seg=6)
            # behind the set the braces stand in rows: one solid block there rather than a thicket to ride through
            lib.col_box(lib.uname("SetBack"), (3.0, y1 - y0, h), (fx + side * 1.9, (y0 + y1) / 2, h / 2))
            school.text_mesh(f"WestSign{side}{k}", label, 0.7, (fx - side * 0.06, (y0 + y1) / 2, h - 1.2),
                             (math.pi / 2, 0.0, -side * math.pi / 2), mat("SignCream", "#efe4c8"), depth=0.03)
            r = empty(lib.uname("WestWindows"), (0, 0, 0), 0.0, None)
            for yy in (y0 + 3.0, y1 - 3.0):                         # upstairs windows, above the porch roof
                houses._window_side(r, fx, yy, 3.5 if h > 6 else 3.3, 1.4, 1.5, mat("WestTrim", "#e8dcc0"), facing=-side)
            box(lib.uname("WestDoor"), (0.08, 1.8, 2.4), (fx - side * 0.04, (y0 + y1) / 2, BOARD_H + 1.2),
                mat("WestDoor", "#3a2a1c"))
            # the boardwalk in front, its street edge a ledge, a hitching rail along the dirt
            bx = fx - side * 1.6
            box(f"Wood_Boardwalk{side}{k}-col", (3.2, y1 - y0, BOARD_H), (bx, (y0 + y1) / 2, BOARD_H / 2), M("WoodB"))
            ex = fx - side * 3.2
            rail(None, f"boardwalk_{'w' if side < 0 else 'e'}{k}", [(ex + side * 0.06, y0 + 0.2, BOARD_H + 0.07),
                                                                   (ex + side * 0.06, y1 - 0.2, BOARD_H + 0.07)], kind="ledge")
            hx = ex - side * 1.2
            for yy in (y0 + 3.0, y1 - 3.0):
                cyl_z(lib.uname("HitchPost"), (hx, yy, 0.0), 0.95, 0.07, wood, seg=8)
                lib.col_box(lib.uname("HitchPost"), (0.16, 0.16, 0.95), (hx, yy, 0.475), surface="Wood")
            cyl_between(lib.uname("HitchRail"), (hx, y0 + 2.8, 0.9), (hx, y1 - 2.8, 0.9), 0.05, wood, seg=8)
            c = lib.col_box(lib.uname("HitchRail"), (0.14, y1 - y0 - 5.6, 0.14), (hx, (y0 + y1) / 2, 0.9), surface="Wood")
            rail(None, f"hitching_rail_{'w' if side < 0 else 'e'}{k}", [(hx, y0 + 3.2, 0.97), (hx, y1 - 3.2, 0.97)],
                 kind="rail")
    # barrels and a water trough in the street
    for (x, y) in ((WEST_X - 3.2, 14.5), (WEST_X - 3.8, 15.2), (WEST_X + 3.4, -15.5)):
        cyl_z(lib.uname("Wood_Barrel") + "-col", (x, y, 0.0), 0.95, 0.32, M("Timber"), r1=0.3, seg=12)
    box("Wood_Trough-col", (0.8, 2.4, 0.6), (WEST_X + 3.0, 6.0, 0.3), M("Timber"))


# ------------------------------------------------------------------ the New York street

def new_york():
    """Brownstone fronts both sides of a paved street, stoops with railings up to the doors."""
    brick = mat("Brownstone", "#7d4c3a")
    trim = mat("Trim", "#e8e4dc")
    for side in (-1, 1):
        fx = NY_X + side * 9.0
        box(f"Wall_NYFront{side}-col", (0.5, 40.0, 11.0), (fx + side * 0.25, 0.0, 5.5), brick)
        for yy in (-14.0, -4.0, 6.0, 15.0):            # clear of the director's table and the green screen's warp spot
            cyl_between(lib.uname("Brace"), (fx + side * 0.5, yy, 9.0), (fx + side * 4.0, yy, 0.0), 0.08, M("Timber"), seg=6)
        lib.col_box(lib.uname("SetBack"), (3.5, 40.0, 9.0), (fx + side * 2.25, 0.0, 4.5))
        r = empty(lib.uname("NYWindows"), (0, 0, 0), 0.0, None)
        stone = mat("Stone", "#bdb8ad")
        for z in (3.2, 6.6):
            for yy in range(-18, 20, 4):
                houses._window_side(r, fx, float(yy), z, 1.3, 2.2, trim, facing=-side)
                box(lib.uname("NYLintel"), (0.14, 1.7, 0.22), (fx - side * 0.07, float(yy), z + 2.42), stone)
        # a deep cornice along the top, and a stone band between the floors
        box(lib.uname("NYCornice"), (0.7, 40.4, 0.45), (fx - side * 0.1, 0.0, 10.8), mat("StoneDk", "#77736c"))
        box(lib.uname("NYCornice"), (0.3, 40.2, 0.2), (fx - side * 0.05, 0.0, 10.45), stone)
        box(lib.uname("NYBand"), (0.12, 40.0, 0.25), (fx - side * 0.06, 0.0, 6.1), stone)
        for k, yy in enumerate((-12.0, 0.0, 12.0)):                # stoops: five steps up to the doors
            # (the landing spans local y -1.2..0: set the origin out from the wall so it stands in front of it)
            st = empty(lib.uname("Stoop"), (fx - side * 1.25, yy, 0.0), (math.pi / 2) if side > 0 else (-math.pi / 2), None)
            st["bake_group"] = "plaza"
            n, rise, run = 5, 0.19, 0.34
            Ht = n * rise
            pts = [(-1.2, 0.0), (-1.2, Ht), (0.0, Ht)]
            for j in range(1, n + 1):
                pts.append(((j - 1) * run, Ht - j * rise))
                if j < n:
                    pts.append((j * run, Ht - j * rise))
            prism(lib.uname("Concrete_Stoop"), pts, -0.9, 0.9, [mat("Stone", "#bdb8ad")], [0] * len(pts), [False] * len(pts),
                  cap_mat=0, parent=st)
            prism(lib.uname("Concrete_StoopSlope") + "-colonly", [(-1.2, 0.0), (-1.2, Ht), (0.0, Ht), (n * run, 0.0)],
                  -0.9, 0.9, [M("Collision")], [0, 0, 0, 0], cap_mat=0, parent=st)
            galv = mat("IronBlack", "#1d1f22")
            slope = rise / run
            for sx, tag in ((-0.85, "a"), (0.85, "b")):
                y0r, y1r = -1.0, (n - 1) * run + 0.2
                z0, z1 = Ht + 0.85 - max(y0r, 0.0) * slope, Ht + 0.85 - y1r * slope
                cyl_between(lib.uname("StoopRail"), (sx, y0r, z0), (sx, y1r, z1), 0.022, galv, seg=10, parent=st)
                for (y, z) in ((y0r, z0), (y1r, z1)):
                    base = Ht if y <= 0 else Ht - min(n, int(y / run) + 1) * rise
                    cyl_z(lib.uname("StoopPost"), (sx, y, base), z - base, 0.02, galv, seg=8, parent=st)
                c = lib.col_box(lib.uname("StoopRail"), (0.08, math.hypot(y1r - y0r, z1 - z0), 0.08), (0, 0, 0), parent=st,
                                surface="Metal")
                c.location = (sx, (y0r + y1r) / 2, (z0 + z1) / 2)
                c.rotation_euler = (math.atan2(z1 - z0, y1r - y0r), 0, 0)
                rail(st, f"stoop_rail_{'w' if side < 0 else 'e'}{k}{tag}", [(sx, y0r + 0.05, z0 + 0.06), (sx, y1r - 0.05, z1 + 0.06)],
                     kind="rail")
            box(lib.uname("NYDoor"), (0.08, 1.1, 2.3), (fx - side * 0.02, yy, Ht + 1.15), mat("DoorGreen", "#2c4a3a"))
    props.place("fire_hydrant", NY_X - 7.5, 3.0, 90.0, surface="Metal")
    for (x, y) in ((NY_X + 7.6, -4.0), (NY_X - 7.6, 16.0)):
        props.place("metal_trash_can", x, y, 0.0, surface="Metal")


# ------------------------------------------------------------------ set pieces and the lot

def set_pieces():
    # the stunt ramp: a big quarter pipe at the north end of the main road, facing south
    quarter_pipe(root("StuntQP", 0.0, 36.0, 0.0), W=8.0, R=3.2, H=2.6, D=2.0, rails=True, decals=False)
    # the green screen: a curved cyclorama, rideable like a quarter pipe (its top is out of reach)
    qp = root("GreenScreen", 42.0, 36.0, 0.0)
    quarter_pipe(qp, W=14.0, R=4.5, H=4.5, D=1.0, coping=False, rails=False, decals=False, details=False)
    for ob in qp.children_recursive:
        if ob.type == "MESH":
            for i, m in enumerate(ob.data.materials):
                ob.data.materials[i] = mat("GreenScreen", "#3fbf4a")
    box(lib.uname("GreenScreenWall"), (14.0, 0.2, 3.0), (42.0, 40.6, 6.0), mat("GreenScreen", "#3fbf4a"))
    # the dolly tracks: two long low steel tracks on sleepers, grindable
    steel = M("Steel")
    for (y, tag) in ((-24.0, "a"), (-22.8, "b")):
        cyl_between(lib.uname("DollyTrack"), (12.0, y, 0.12), (40.0, y, 0.12), 0.03, steel, seg=8)
        c = lib.col_box(lib.uname("DollyTrack"), (28.0, 0.08, 0.1), (26.0, y, 0.09), surface="Metal")
        rail(None, f"dolly_track_{tag}", [(12.3, y, 0.19), (39.7, y, 0.19)], kind="rail")
    for k in range(15):
        box(lib.uname("Sleeper"), (0.14, 1.8, 0.05), (12.5 + k * 1.95, -23.4, 0.025), M("Timber"))
    dolly = empty(lib.uname("Dolly"), (41.4, -23.4, 0.0), 0.0, None)        # parked past the tracks' end
    box(lib.uname("DollyCart"), (1.2, 1.4, 0.3), (0.0, 0.0, 0.35), mat("Rubber", "#1e1e1e"), parent=dolly)
    cyl_z(lib.uname("DollyPost"), (0.0, 0.0, 0.5), 1.0, 0.07, steel, seg=8, parent=dolly)
    box(lib.uname("DollyCamera"), (0.5, 0.3, 0.35), (0.0, 0.0, 1.65), mat("Rubber", "#1e1e1e"), parent=dolly)
    lib.col_box(lib.uname("Dolly"), (1.2, 1.4, 1.9), (41.4, -23.4, 0.95), surface="Wall")
    # the camera crane (decoration)
    cyl_z(lib.uname("CraneBase"), (8.0, -18.0, 0.0), 0.6, 0.6, mat("Rubber", "#1e1e1e"), seg=16)
    cyl_z(lib.uname("CranePost"), (8.0, -18.0, 0.6), 2.4, 0.12, steel, seg=10)
    cyl_between(lib.uname("CraneArm"), (6.0, -18.0, 3.2), (12.5, -18.0, 4.6), 0.08, steel, seg=10)
    lib.col_box(lib.uname("Crane"), (1.3, 1.3, 3.0), (8.0, -18.0, 1.5), surface="Metal")


def lot():
    # actors' trailers down the west side of the main road, steps at their doors
    for k, y in enumerate((-18.0, -8.0, 2.0)):
        tr = empty(lib.uname("Trailer"), (-10.0, y, 0.0), 0.0, None)
        tr["bake_group"] = "world"
        box(lib.uname("Wall_Trailer") + "-col", (3.0, 8.0, 2.8), (0.0, 0.0, 1.85), mat("TrailerWhite", "#e7e3db"), parent=tr)
        box(lib.uname("TrailerStripe"), (3.02, 8.02, 0.3), (0.0, 0.0, 2.2), mat("TrailerStripe", "#b8732c"), parent=tr)
        for (dx, dy) in ((-1.1, -2.8), (1.1, -2.8), (-1.1, 2.8), (1.1, 2.8)):
            cyl_between(lib.uname("TrailerWheel"), (dx - 0.1, dy, 0.4), (dx + 0.1, dy, 0.4), 0.38, mat("Rubber", "#1e1e1e"),
                        seg=14, parent=tr)
        box(lib.uname("TrailerDoor"), (0.06, 0.9, 1.9), (1.53, 1.5, 1.45), mat("TrailerDoor", "#9c9a96"), parent=tr)
        glass = houses.glass()
        for sx in (-1, 1):                                       # windows down both sides, clear of the door
            for wy in ((-2.4, 3.3) if sx > 0 else (-2.4, 0.6, 3.3)):
                box(lib.uname("TrailerWindow"), (0.03, 1.1, 0.55), (sx * 1.515, wy, 2.68), glass, parent=tr)
        box(lib.uname("TrailerAwning"), (0.9, 1.5, 0.04), (1.95, 1.5, 2.55), mat("TrailerAwning", "#b8732c"), parent=tr)
        box(lib.uname("TrailerAC"), (0.8, 1.0, 0.35), (0.0, -1.5, 3.42), M("Galv"), parent=tr)
        dark = mat("TruckDark", "#1c1f22")
        for sx in (-1, 1):                                       # the hitch: an A-frame tongue on a jack
            cyl_between(lib.uname("TrailerTongue"), (sx * 0.6, -4.0, 0.55), (0.0, -5.3, 0.5), 0.04, dark, seg=6, parent=tr)
        cyl_z(lib.uname("TrailerJack"), (0.0, -5.15, 0.0), 0.55, 0.04, dark, seg=6, parent=tr)
        lib.col_box(lib.uname("TrailerHitch"), (1.2, 1.3, 0.6), (0.0, -4.65, 0.3), parent=tr, surface="Metal")
        box(lib.uname("Wood_TrailerSteps") + "-col", (0.7, 1.0, 0.45), (1.9, 1.5, 0.225), M("Steel"), parent=tr)
        school.text_mesh(f"TrailerStar{k}", ["THE ACTOR", "STUNTS", "MAKEUP"][k], 0.22, (-8.46, y - 1.0, 2.7),
                         (math.pi / 2, 0.0, math.pi / 2), mat("SignNavy", "#22304a"), depth=0.01)
    # craft services: a tent over a table
    for (dx, dy) in ((-2.0, -1.5), (2.0, -1.5), (-2.0, 1.5), (2.0, 1.5)):
        cyl_z(lib.uname("TentPole"), (dx, 18.0 + dy, 0.0), 2.6, 0.035, M("Steel"), seg=6)
        lib.col_box(lib.uname("TentPole"), (0.1, 0.1, 2.6), (dx, 18.0 + dy, 1.3), surface="Metal")
    box(lib.uname("TentRoof"), (4.6, 3.6, 0.06), (0.0, 18.0, 2.62), mat("TentWhite", "#eeeae2"))
    props.place("wooden_picnic_table", 0.0, 18.0, 90.0, surface="Wood")
    # the director's chair (a table beside it takes the script) and the video village
    # a tall canvas director's chair: X-frame legs each side, a seat and a back of canvas, armrests, a footrest
    chair = mat("ChairCanvas", "#1d1f22")
    cw = mat("ChairWood", "#8a6a45")
    cx_, cy_ = 16.0, -18.0
    for sx in (-0.28, 0.28):
        cyl_between(lib.uname("ChairLeg"), (cx_ + sx, cy_ - 0.24, 0.0), (cx_ + sx, cy_ + 0.24, 0.75), 0.022, cw, seg=6)
        cyl_between(lib.uname("ChairLeg"), (cx_ + sx, cy_ + 0.24, 0.0), (cx_ + sx, cy_ - 0.24, 0.75), 0.022, cw, seg=6)
        cyl_between(lib.uname("ChairPost"), (cx_ + sx, cy_ + 0.24, 0.75), (cx_ + sx, cy_ + 0.26, 1.45), 0.02, cw, seg=6)
        cyl_between(lib.uname("ChairArm"), (cx_ + sx, cy_ - 0.24, 1.0), (cx_ + sx, cy_ + 0.26, 1.0), 0.024, cw, seg=6)
        cyl_between(lib.uname("ChairArmPost"), (cx_ + sx, cy_ - 0.22, 0.75), (cx_ + sx, cy_ - 0.22, 1.0), 0.018, cw, seg=6)
    cyl_between(lib.uname("ChairFootrest"), (cx_ - 0.28, cy_ - 0.2, 0.32), (cx_ + 0.28, cy_ - 0.2, 0.32), 0.02, cw, seg=6)
    box(lib.uname("ChairSeat"), (0.54, 0.46, 0.03), (cx_, cy_, 0.77), chair)
    box(lib.uname("DirectorChairBack"), (0.58, 0.04, 0.3), (cx_, cy_ + 0.26, 1.3), chair)
    lib.col_box(lib.uname("DirectorChair"), (0.62, 0.56, 1.45), (cx_, cy_, 0.72), surface="Wall")
    school.text_mesh("DirectorChair_text", "DIRECTOR", 0.09, (cx_, cy_ + 0.285, 1.3), (math.pi / 2, 0.0, math.pi),
                     mat("SignWhite", "#f2f0ea"), depth=0.005)
    props.place("round_wooden_table_02", 17.4, -18.0, 0.0, surface="Wood")
    top = props.bounds("round_wooden_table_02")[1].z             # the monitor stands on the table (it floated above)
    box(lib.uname("MonitorStand"), (0.12, 0.1, 0.16), (17.4, -18.3, top + 0.08), mat("Rubber", "#1e1e1e"))
    box(lib.uname("Monitor"), (0.6, 0.08, 0.4), (17.4, -18.3, top + 0.36), mat("Rubber", "#1e1e1e"))
    # sound stages along the north edge (the lot's backdrop)
    for k, x in enumerate((-40.0, -14.0, 16.0, 44.0)):
        box(lib.uname("Wall_SoundStage") + "-col", (22.0, 16.0, 13.0), (x, 52.0, 6.5), mat("Stucco", "#d8cdb8"))
        prism(lib.uname("StageRoof"), [(44.0, 13.0), (60.0, 13.0), (52.0, 15.5)], x - 11.0, x + 11.0,
              [mat("StoneDk", "#8d8c88")] * 3, [0, 0, 0], [False] * 3, cap_mat=0)    # a stage's roof, not villa tiles
        school.text_mesh(f"StageNum{k}", f"STAGE {k + 4}", 1.2, (x, 43.95, 9.5), school.FACING_SOUTH,
                         mat("SignNavy", "#22304a"), depth=0.04)
        box(lib.uname("StageDoor"), (6.0, 0.1, 6.0), (x, 43.97, 3.0), mat("Galv", "#9ea4a8"))


def furniture():
    for x in range(-50, 51, 20):
        props.place("street_lamp_02", float(x), -32.1, 0.0, surface="Metal")
    for (x, y) in ((-4.0, -26.0), (4.0, -26.0), (-4.0, 24.0), (4.0, 24.0), (20.0, 26.0), (-20.0, 26.0)):
        props.place("street_lamp_02", x, y, 0.0, surface="Metal")
    for (x, y) in ((-6.0, 12.0), (20.0, -26.0)):
        props.place("plastic_crate_02", x, y, 30.0, surface="Wall")
    props.place("standing_chalkboard_01", 2.6, 16.0, 200.0, surface="Wood")


def plant_trees():
    spots = [(-56.0, -20.0), (-56.0, 10.0), (56.0, -20.0), (56.0, 10.0), (-20.0, -26.0), (46.0, -26.0), (-46.0, 30.0),
             (56.0, 30.0)]
    for i, (x, y) in enumerate(spots):
        trees.tree(lib.uname("Tree"), (x, y, 0.0), height=7.0 + (i * 37 % 4) * 0.6, crown=2.6, seed=200 + i, collide=True)


def markers():
    marker("Spawn_Player", 0.0, -24.0, 0.02, 0.0)
    marker("Start_gate", 0.0, -24.0, 0.02, 0.0)
    marker("Start_west", WEST_X, -20.0, 0.02, 0.0)
    marker("Start_ny", NY_X, -14.0, 0.02, 0.0)                  # (at -20 the chase camera sat in the O balloon)
    marker("Start_stunt", 0.0, 27.0, 0.02, 0.0)                 # (at 22 the camera sat in the craft tent)
    marker("Start_green", 44.0, 25.0, 0.02, 0.0)
    marker("Start_dolly", 10.0, -23.4, 0.02, -90.0)
    # the director by the chair, the crew on the two street sets (a character at rot 0 faces south)
    for i, (x, y, rot) in enumerate(((15.2, -19.2, 20.0), (WEST_X + 4.2, -2.0, -90.0), (NY_X - 5.0, 10.0, 90.0))):
        marker(f"Event_kid_{i + 1}", x, y, 0.02, rot)
    # the script pages: on the actor's trailer steps -> the table by the director's chair
    lo, hi = props.bounds("round_wooden_table_02")
    marker("Event_script_pickup", -10.0 + 1.9, -18.0 + 1.5, 0.5)
    marker("Event_script_drop", 17.4, -18.0, hi.z + 0.02)
    # hit your marks: the saloon's door, a New York stoop's foot, in front of the green screen, at craft services
    for i, (x, y) in enumerate(((WEST_X - 4.0, -11.0), (NY_X + 5.2, 0.0), (42.0, 24.0), (0.0, 13.5))):
        marker(f"Event_mark_{i + 1}", x, y, 0.02)
    # A-C-T-I-O-N: over a hitching rail, a stoop, the stunt ramp, the green screen, the dolly tracks, a boardwalk edge
    for letter, (x, y, z) in zip("ACTION", ((WEST_X - 4.6, -8.0, 2.0), (NY_X + 7.0, 12.0, 2.2), (0.0, 38.6, 4.2),
                                           (42.0, 39.3, 3.8), (30.0, -23.4, 1.5), (WEST_X + 5.8, 12.0, 1.9))):
        marker(f"Event_letter_{letter}", x, y, z)


def write_look(out):
    import json
    look = {"joints": {}, "bake_energy": 2.0, "exposure": 1.0}
    with open(os.path.splitext(out)[0] + ".look.json", "w") as f:
        json.dump(look, f, indent=1)


def build(out, bake=True, samples=128):
    realism.set_sky(SKY)
    ground()
    western()
    new_york()
    set_pieces()
    lot()
    furniture()
    plant_trees()
    markers()
    tree_fn = lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed)
    terrain.backdrop(tree_fn=lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed,
                                                                         cards=60, litter=0),
                     street_from=62.0)                  # (the avenue runs out to 62 m here)
    terrain.edge_trees(tree_fn)
    # the studio's wall round the other three sides (the lot ran straight into the meadow)
    stucco = mat("StudioWall", "#d8cdb8")
    for (cx, cy, w, d) in ((-62.4, 16.0, 0.4, 92.0), (62.4, 16.0, 0.4, 92.0), (0.0, 62.4, 125.2, 0.4)):
        box(lib.uname("Wall_StudioWall") + "-col", (w, d, 3.6), (cx, cy, 1.8), stucco)
    for x in range(-60, 61, 12):                      # pilasters along the north wall
        box(lib.uname("StudioPier"), (0.8, 0.7, 3.9), (float(x), 62.3, 1.95), stucco)
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
