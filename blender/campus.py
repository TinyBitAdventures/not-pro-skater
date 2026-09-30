"""
Level 3, Hilltop Tech: a real-scale office campus at midday, the Dev's home turf, on the day the team ships its
app ("Launch Day"). The company picnic is on the lawn; the whole campus is fair game:

    the atrium steps      eight granite steps down from the entrance terrace, a handrail each side and one down
                          the middle, and a sloped hubba ledge beside them
    the plaza             granite pavers, two long planter ledges, a fountain with a grindable rim, a manual pad,
                          benches, a steel sculpture
    the amphitheatre      three curved tiers of seating (each edge a ledge) round a low stage, where the demo is
    the parking deck      a raised deck (1.6 m) with a ramp up from the plaza, a railing down the ramp, a ledge
                          along its open drop
    the company picnic    on the west lawn: a food truck (the pizzas), picnic tables, the team
    the campus sign       a granite monument by Campus Drive, its top a ledge

Campus Drive runs along the south (-Y) edge in the same band as the other levels' streets. Blender axes (Z up);
Godot sees (x, z, -y). Same pipeline as school.py; the sky is a midday one with scattered cloud.

Event markers: Event_letter_<L> (D-E-P-L-O-Y), Event_pizza_pickup / _drop, Event_kid_<n> (the team),
Event_zone_stage (the demo), Start_<name> warp spots, Spawn_Player.
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
from pieces import M, bank
import realism
import school
import terrain
import trees

SKY = "kloofendal_48d_partly_cloudy_puresky"
LAWN_Z = terrain.LAWN_Z
ROAD_Z = terrain.ROAD_Z

BUILDING = (-42.0, 28.0, 24.0, 44.0)      # x0, x1, y0, y1
BUILDING_H = 12.4
STEPS_N, STEPS_RISE, STEPS_RUN = 8, 0.19, 0.44
TERRACE_H = STEPS_N * STEPS_RISE           # 1.52 m
TERRACE = (-20.0, 6.0, 16.0, 24.0)
STEPS_X = (-14.0, 0.0)                     # the steps' width along the terrace front
STEPS_Y0 = TERRACE[2] - STEPS_N * STEPS_RUN   # the foot of the steps (12.48)
PLAZA = (-32.0, 32.0, -14.0, STEPS_Y0)
FOUNTAIN = (14.0, -1.0, 3.4)               # centre x, y, rim radius
STAGE = (38.0, -17.0)                      # the amphitheatre's centre
DECK = (34.0, 54.0, 14.0, 34.0)            # x0, x1, y0, y1
DECK_H = 1.6

HARD = [
    (PLAZA[0], PLAZA[1], PLAZA[2], PLAZA[3]),
    (TERRACE[0] - 0.5, TERRACE[1] + 0.5, STEPS_Y0 - 0.5, TERRACE[3]),
    (BUILDING[0] - 1.0, BUILDING[1] + 1.0, BUILDING[2] - 1.0, BUILDING[3] + 1.0),
    (-9.0, -5.0, -30.0, PLAZA[2]),                     # path from Campus Drive
    (DECK[0] - 15.0, DECK[1] + 1.0, DECK[2] - 1.0, DECK[3] + 1.0),   # the deck and its ramp
    (STAGE[0] - 10.5, STAGE[0] + 10.5, STAGE[1] - 10.5, STAGE[1] + 4.0),  # the amphitheatre
    (-27.0, -13.0, -26.8, -24.2),                      # the campus sign
    (-60.0, 60.0, -60.0, -30.0),                       # Campus Drive and beyond
    (-56.0, -36.0, -24.0, 4.0),                        # the picnic lawn stays level
]
MOUNDS = [(-50.0, 18.0, 7.0, 1.2), (52.0, -2.0, 5.0, 0.8), (-24.0, -22.0, 5.0, 0.5), (18.0, -22.0, 4.0, 0.4),
          (-48.0, 40.0, 9.0, 1.8), (48.0, 44.0, 8.0, 1.5)]


def face_ring(ob, split_r):
    """lib.revolve points every face up / away from the axis. For stepped rings that is wrong on walls that face the
    middle: seating risers facing the stage, a basin's inner wall. Walls (near-horizontal normals) closer to the axis
    than split_r face inward, the rest outward; tops face up."""
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.normal_update()
    for f in bm.faces:
        n = f.normal
        c = f.calc_center_median()
        if abs(n.z) > 0.5:
            if n.z < 0.0:
                f.normal_flip()
            continue
        r = math.hypot(c.x, c.y)
        out = (n.x * c.x + n.y * c.y) > 0.0
        if (r < split_r) == out:
            f.normal_flip()
    bm.to_mesh(ob.data)
    bm.free()
    ob.data.update()


def ring_pts(cx, cy, r, a0, a1, n, z):
    return [(cx + r * math.cos(a0 + (a1 - a0) * k / n), cy + r * math.sin(a0 + (a1 - a0) * k / n), z) for k in range(n + 1)]


# ------------------------------------------------------------------ ground

def ground():
    terrain.configure(HARD, MOUNDS)
    terrain.lawn()
    slab("SidewalkN", "Concrete", "Sidewalk", -60.0, 60.0, -32.5, -30.0, top=0.0, t=-ROAD_Z)
    slab("Road", "Path", "Road", -60.0, 60.0, -40.5, -32.5, top=ROAD_Z, t=0.3)
    slab("SidewalkS", "Concrete", "Sidewalk", -60.0, 60.0, -43.0, -40.5, top=0.0, t=-ROAD_Z)
    slab("FarVerge", "Grass", "Grass", -60.0, 60.0, -60.0, -43.0, top=LAWN_Z)
    slab("Plaza", "Plaza", "Paving", PLAZA[0], PLAZA[1], PLAZA[2], PLAZA[3], top=0.0, t=0.1, group="plaza")
    slab("PathIn", "Path", "Path", -9.0, -5.0, -30.0, PLAZA[2], top=-0.01, t=0.08)
    slab("AmphiFloor", "Plaza", "Paving", STAGE[0] - 6.0, STAGE[0] + 6.0, STAGE[1] - 3.0, STAGE[1] + 4.0, top=0.0,
         t=0.1, group="plaza")
    slab("AmphiPath", "Plaza", "Paving", PLAZA[1], STAGE[0] - 6.0, STAGE[1] + 1.0, STAGE[1] + 4.0, top=0.0, t=0.1,
         group="plaza")
    slab("DeckApron", "Path", "Road", DECK[0] - 15.0, DECK[0], DECK[2] - 1.0, DECK[2] + 5.0, top=0.0, t=0.1)


# ------------------------------------------------------------------ the building

def building():
    x0, x1, y0, y1 = BUILDING
    w, d = x1 - x0, y1 - y0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    panel = mat("Stone", "#c9c7c1")
    mull = mat("Mullion", "#2d3236")
    box("Wall_Office-col", (w, d, BUILDING_H), (cx, cy, BUILDING_H / 2), panel)
    box(lib.uname("Office_parapet"), (w + 0.3, d + 0.3, 0.5), (cx, cy, BUILDING_H + 0.25), mat("StoneDk", "#8d8c88"))
    box(lib.uname("Office_roof"), (w - 0.4, d - 0.4, 0.06), (cx, cy, BUILDING_H + 0.05), mat("Stone", "#999999"))
    for sx in (x0 + 8.0, x1 - 12.0):
        box(lib.uname("Office_hvac"), (4.0, 3.0, 1.6), (sx, cy + 3.0, BUILDING_H + 0.85), M("Galv"))
    # the curtain wall: floor-to-ceiling glass in a dark grid, three storeys, all round
    r = empty(lib.uname("OfficeGlass"), (0, 0, 0), 0.0, None)
    n = int(w // 3.2)
    for z in (2.2, 6.2, 10.2):
        for i in range(n):
            x = x0 + w * (i + 0.5) / n
            if z < 4.0 and -13.0 < x < -1.0:
                continue                                  # the atrium
            houses._window(r, x, y0, z, 2.9, 3.0, mull, facing=-1)
            houses._window(r, x, y1, z, 2.9, 3.0, mull, facing=1)
        for yy in (y0 + 4.0, cy, y1 - 4.0):
            houses._window_side(r, x0, yy, z, 3.0, 3.0, mull)
            houses._window_side(r, x1, yy, z, 3.0, 3.0, mull)
    for z in (4.2, 8.2):                                  # floor bands
        box(lib.uname("Office_band"), (w + 0.1, 0.08, 0.35), (cx, y0 - 0.04, z), mat("StoneDk", "#8d8c88"))
    # the atrium: two storeys of glass behind the terrace, a steel canopy, the company's name
    glass = houses.glass()
    box(lib.uname("Atrium_glass"), (12.0, 0.08, 7.0), (-7.0, y0 - 0.05, TERRACE_H + 3.5), glass)
    for k in range(7):
        box(lib.uname("Atrium_fin"), (0.08, 0.3, 7.0), (-13.0 + k * 2.0, y0 - 0.15, TERRACE_H + 3.5), mull)
    for dx in (-0.8, 0.8):
        box(lib.uname("Atrium_door"), (1.4, 0.06, 2.4), (-7.0 + dx, y0 - 0.16, TERRACE_H + 1.2), glass)   # clear of the atrium glass
    box(lib.uname("Atrium_canopy"), (13.0, 3.2, 0.25), (-7.0, y0 - 1.6, TERRACE_H + 7.4), M("Steel"))
    school.text_mesh("Office_name", "HILLTOP", 1.1, (-7.0, y0 - 0.2, TERRACE_H + 8.6), school.FACING_SOUTH,
                     mat("SignWhite", "#f2f0ea"), depth=0.08)


def terrace():
    """The entrance terrace in front of the atrium, the steps down to the plaza (three named handrails) and a hubba
    ledge beside them sloping with the steps."""
    tx0, tx1, ty0, ty1 = TERRACE
    stone = mat("StoneDk", "#8d8c88")
    box("Plaza_Terrace-col", (tx1 - tx0, ty1 - ty0, TERRACE_H), ((tx0 + tx1) / 2, (ty0 + ty1) / 2, TERRACE_H / 2),
        mat("Paving", "#a09c94"))
    for (a, b) in ((tx0, STEPS_X[0] - 1.2), (STEPS_X[1] + 1.2, tx1)):   # planter walls either side of the steps
        box(lib.uname("Wall_TerraceFront") + "-col", (b - a, ty0 - STEPS_Y0, TERRACE_H),
            ((a + b) / 2, (ty0 + STEPS_Y0) / 2, TERRACE_H / 2), stone)
        for k in range(3):
            props.place("shrub_03", a + (b - a) * (k + 0.5) / 3, (ty0 + STEPS_Y0) / 2, 60.0 * k, z=TERRACE_H,
                        scale=0.7, collide=False)
    # the steps: built riding +Y (down), turned to face the plaza
    W = STEPS_X[1] - STEPS_X[0]
    rt = empty(lib.uname("AtriumSteps"), ((STEPS_X[0] + STEPS_X[1]) / 2, ty0, 0.0), math.pi, None)
    rt["bake_group"] = "plaza"
    n, rise, run = STEPS_N, STEPS_RISE, STEPS_RUN
    Ht = TERRACE_H
    pts = [(-0.4, 0.0), (-0.4, Ht), (0.0, Ht)]
    em = [2, 0]
    for k in range(1, n + 1):
        z = Ht - k * rise
        pts.append(((k - 1) * run, z))
        em.append(1)
        if k < n:
            pts.append((k * run, z))
            em.append(0)
    em.append(2)
    prism(lib.uname("Concrete_AtriumSteps"), pts, -W / 2, W / 2, [mat("Paving", "#a09c94"), mat("StoneDk", "#8d8c88"), mat("StoneDk", "#8d8c88")], em,
          [False] * len(pts), cap_mat=1, parent=rt)
    prism(lib.uname("Concrete_AtriumSlope") + "-colonly", [(-0.4, 0.0), (-0.4, Ht), (0.0, Ht), (n * run, 0.0)],
          -W / 2, W / 2, [M("Collision")], [0, 0, 0, 0], cap_mat=0, parent=rt)
    slope = rise / run
    lrun = (n - 1) * run
    galv = M("Steel")
    for name, x in (("atrium_rail_w", -W / 2 + 0.4), ("atrium_rail_c", 0.0), ("atrium_rail_e", W / 2 - 0.4)):
        y0, y1 = -0.5, lrun + 0.35
        z0 = Ht + 0.9 - y0 * slope
        z1 = Ht + 0.9 - y1 * slope
        cyl_between(lib.uname("HandRail"), (x, y0, z0), (x, y1, z1), 0.026, galv, seg=12, parent=rt)
        for (y, z) in ((y0, z0), (y1, z1), ((y0 + y1) / 2, (z0 + z1) / 2)):
            base = Ht if y <= 0 else Ht - min(n, int(y / run) + 1) * rise
            cyl_z(lib.uname("RailPost"), (x, y, base), z - base, 0.022, galv, seg=10, parent=rt)
        c = lib.col_box(lib.uname("HandRail"), (0.08, math.hypot(y1 - y0, z1 - z0), 0.08), (0, 0, 0), parent=rt,
                        surface="Metal")
        c.location = (x, (y0 + y1) / 2, (z0 + z1) / 2)
        c.rotation_euler = (math.atan2(z1 - z0, y1 - y0), 0, 0)
        rail(rt, name, [(x, y0 + 0.05, z0 + 0.06), (x, y1 - 0.05, z1 + 0.06)], kind="rail")
    # the hubba: a granite block beside the steps (east side, in the gap to the planter wall), its top sloping with
    # the nosings from the terrace edge to a knee-high end on the plaza
    hx0, hx1 = STEPS_X[1] + 0.05, STEPS_X[1] + 1.15
    h_hi, h_lo = Ht + 0.45, 0.5
    L = n * run
    prism("Concrete_Hubba-col", [(ty0, 0.0), (ty0, h_hi), (ty0 - L, h_lo), (ty0 - L, 0.0)], hx0, hx1,
          [mat("StoneDk", "#8d8c88"), mat("Paving", "#a09c94"), mat("StoneDk", "#8d8c88"), mat("StoneDk", "#8d8c88")], [0, 1, 0, 2], [False] * 4, cap_mat=0)
    rail(None, "hubba_e", [(hx0 + 0.06, ty0 - 0.1, h_hi - 0.1 * (h_hi - h_lo) / L + 0.07),
                           (hx0 + 0.06, ty0 - L + 0.1, h_lo + 0.1 * (h_hi - h_lo) / L + 0.07)], kind="ledge")
    rail(None, "hubba_e2", [(hx1 - 0.06, ty0 - 0.1, h_hi - 0.1 * (h_hi - h_lo) / L + 0.07),
                            (hx1 - 0.06, ty0 - L + 0.1, h_lo + 0.1 * (h_hi - h_lo) / L + 0.07)], kind="ledge")
    # the terrace's west side: a planter wall to the gap, the same as the east
    box(lib.uname("Wall_TerraceWestGap") + "-col", (1.15, STEPS_N * STEPS_RUN, TERRACE_H),
        (STEPS_X[0] - 0.6, ty0 - STEPS_N * STEPS_RUN / 2, TERRACE_H / 2), stone)
    for x in (-18.0, -12.0, -2.0, 4.0):                     # potted trees on the terrace
        props.place("potted_plant_04", x, 22.5, 20.0 * x, z=TERRACE_H, scale=1.3, surface="Wall")


# ------------------------------------------------------------------ the plaza

def planter(name, x, y, L, W=1.3, h=0.52):
    """A long granite planter along X, both long edges named ledges (<name>a south, <name>b north)."""
    stone = mat("StoneDk", "#8d8c88")
    box(lib.uname("Concrete_Planter") + "-col", (L, W, h), (x, y, h / 2), stone)
    box(lib.uname("PlanterSoil"), (L - 0.3, W - 0.3, 0.02), (x, y, h + 0.005), mat("Soil", "#3b2c20"))
    for sy, tag in ((-1, "a"), (1, "b")):
        yy = y + sy * (W / 2 - 0.05)
        cyl_between(lib.uname("PlanterEdge"), (x - L / 2, yy, h + 0.005), (x + L / 2, yy, h + 0.005), 0.045, M("Steel"),
                    seg=6, smooth=False)
        rail(None, name + tag, [(x - L / 2 + 0.1, yy, h + 0.07), (x + L / 2 - 0.1, yy, h + 0.07)], kind="ledge")
    for k in range(int(L // 2.2)):
        props.place("shrub_03", x - L / 2 + 1.1 + k * 2.2, y, 37.0 * k, z=h, scale=0.5, collide=False)


def plaza():
    planter("planter_1", -21.0, 5.0, 12.0)
    planter("planter_2", -21.0, -4.0, 12.0)
    # the manual pad: a low granite block with sharp edges (ledges both sides)
    box("Concrete_ManualPad-col", (6.5, 2.2, 0.26), (-4.0, -9.0, 0.13), mat("Paving", "#a09c94"))
    for sy, tag in ((-1, "s"), (1, "n")):
        yy = -9.0 + sy * 1.05
        rail(None, "pad_" + tag, [(-7.15, yy, 0.33), (-0.85, yy, 0.33)], kind="ledge")
    # the fountain: a round basin, its rim a ledge (an arc with a gap where the spout is)
    fx, fy, fr = FOUNTAIN
    rim_h = 0.46
    stone = mat("StoneDk", "#8d8c88")
    rim = lib.revolve(lib.uname("Concrete_FountainRim") + "-col",
                      [(fr - 0.45, 0.28), (fr - 0.45, rim_h), (fr, rim_h), (fr, 0.0)], 48,
                      [stone, mat("Paving", "#a09c94"), stone], [0, 1, 2], loc=(fx, fy, 0.0))
    face_ring(rim, fr - 0.2)
    water = houses.glass()                                  # the reflective window shader reads as water
    # the water is also the pool's floor for the skater (a "Grass" surface: riding in slows you right down)
    lib.revolve("Grass_FountainWater-col", [(0.02, 0.3), (fr - 0.44, 0.3)], 48, [water], [0], loc=(fx, fy, 0.0))
    cyl_z(lib.uname("FountainSpout"), (fx, fy, 0.3), 1.2, 0.35, stone, r1=0.18, seg=16)
    rail(None, "fountain_rim", ring_pts(fx, fy, fr - 0.2, math.radians(-150), math.radians(150), 40, rim_h + 0.07),
         kind="ledge")
    # benches, bins, lamps, a steel sculpture, potted plants along the building
    for x, y, rot in ((6.0, -9.0, 0.0), (22.0, -9.0, 0.0), (-26.0, 0.5, 90.0)):
        props.place("modular_street_seating", x, y, rot, surface="Wood")
    for x, y in ((6.5, 8.0), (-28.0, -12.0), (28.0, -12.0)):          # (clear of the grate tree at 9, 9.5)
        props.place("metal_trash_can", x, y, 0.0, surface="Metal")
    for x, y in ((-30.0, 10.0), (-30.0, -12.0), (30.0, 10.0), (30.0, -12.0), (0.0, -13.0), (-16.0, -13.0), (16.0, -13.0)):
        props.place("street_lamp_02", x, y, 0.0, surface="Metal")
    ring = [(24.0 + 1.6 * math.cos(a * math.tau / 40), 7.0, 1.9 + 1.6 * math.sin(a * math.tau / 40)) for a in range(41)]
    for p0, p1 in zip(ring, ring[1:]):
        cyl_between(lib.uname("Sculpture"), p0, p1, 0.16, M("Steel"), seg=8, caps=False)
    box("Concrete_SculptureBase-col", (1.6, 1.0, 0.35), (24.0, 7.0, 0.175), stone)
    lib.col_box(lib.uname("Sculpture"), (3.4, 0.4, 3.4), (24.0, 7.0, 1.9), surface="Metal")
    # bike racks by the path in: steel hoops
    for k in range(6):
        x = -13.0 + k * 0.9
        pts = [(x, -12.2 + 0.35 * math.cos(a * math.pi / 8), 0.45 + 0.35 * math.sin(a * math.pi / 8)) for a in range(9)]
        cyl_between(lib.uname("BikeRack"), (x, -12.55, 0.0), (x, -12.55, 0.45), 0.03, M("Galv"), seg=8)
        cyl_between(lib.uname("BikeRack"), (x, -11.85, 0.0), (x, -11.85, 0.45), 0.03, M("Galv"), seg=8)
        for p0, p1 in zip(pts, pts[1:]):
            cyl_between(lib.uname("BikeRack"), p0, p1, 0.03, M("Galv"), seg=8, caps=False)
    lib.col_box(lib.uname("BikeRack"), (5.4, 0.9, 0.8), (-10.75, -12.2, 0.4), surface="Metal")


# ------------------------------------------------------------------ the amphitheatre

def amphitheatre():
    """Three curved tiers of seating (the south half of a ring) round a low stage; each tier's front edge is a
    ledge. The stage has a ledge along its front and banks up at both ends."""
    cx, cy = STAGE
    a0, a1 = math.radians(195), math.radians(345)
    stone = mat("StoneDk", "#8d8c88")
    tiers = [(6.0, 0.45), (7.1, 0.9), (8.2, 1.35)]
    profile = [(tiers[0][0], 0.0)]
    for i, (r, z) in enumerate(tiers):
        profile.append((r, z))
        nxt = tiers[i + 1][0] if i + 1 < len(tiers) else 9.8
        profile.append((nxt, z))
    profile.append((9.8, 0.0))
    ems = []
    for i in range(len(profile) - 1):
        (ra, za), (rb, zb) = profile[i], profile[i + 1]
        ems.append(1 if abs(za - zb) < 1e-6 and za > 0 else 0)
    tiers_ob = lib.revolve("Concrete_AmphiTiers-col", profile, 32, [stone, mat("Paving", "#a09c94")], ems,
                           loc=(cx, cy, 0.0), a0=a0, a1=a1)
    face_ring(tiers_ob, 99.0)                              # every riser faces the stage; the back wall too (see below)
    # the back wall (r = 9.8) faces away from the stage: flip it back out
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(tiers_ob.data)
    for f in bm.faces:
        c = f.calc_center_median()
        if abs(f.normal.z) < 0.5 and math.hypot(c.x, c.y) > 9.5:
            f.normal_flip()
    bm.to_mesh(tiers_ob.data)
    bm.free()
    for a, sgn in ((a0, 1), (a1, -1)):                     # the tiers' end walls, facing out of the ring's ends
        verts = [(cx + r * math.cos(a), cy + r * math.sin(a), z) for (r, z) in profile]
        idx = tuple(range(len(verts)))
        # wound so the face points out of the ring's end: the other way round (as it was) both end walls faced in,
        # riders from the lawn passed through them (trimesh colliders are one-sided) and rode round inside
        lib.mesh_obj(lib.uname("Concrete_AmphiEnd") + "-col", verts, [tuple(reversed(idx)) if sgn > 0 else idx], [stone])
    for i, (r, z) in enumerate(tiers):
        rail(None, f"tier_{i + 1}", ring_pts(cx, cy, r + 0.06, a0 + 0.04, a1 - 0.04, 24, z + 0.07), kind="ledge")
    # the stage: 0.55 m, a ledge along its front (north), banks up at the east and west ends
    sw, sd, sh = 7.0, 3.6, 0.55
    box("Wood_Stage-col", (sw, sd, sh), (cx, cy - 0.4, sh / 2), M("Wood"))
    cyl_between(lib.uname("StageEdge"), (cx - sw / 2, cy - 0.4 + sd / 2, sh), (cx + sw / 2, cy - 0.4 + sd / 2, sh), 0.04,
                M("Steel"), seg=6, smooth=False)
    rail(None, "stage_ledge", [(cx - sw / 2 + 0.15, cy - 0.4 + sd / 2 - 0.05, sh + 0.07),
                               (cx + sw / 2 - 0.15, cy - 0.4 + sd / 2 - 0.05, sh + 0.07)], kind="ledge")
    bank(root("StageBankW", cx - sw / 2 - 1.5, cy - 0.4, -90.0), W=sd, L=1.5, H=sh)
    bank(root("StageBankE", cx + sw / 2 + 1.5, cy - 0.4, 90.0), W=sd, L=1.5, H=sh)
    # speakers and a lectern for the demo
    for sx in (-1, 1):
        box(lib.uname("Speaker"), (0.6, 0.5, 1.1), (cx + sx * 3.0, cy - 1.6, sh + 0.55), mat("Rubber", "#1e1e1e"))
        lib.col_box(lib.uname("Speaker"), (0.6, 0.5, 1.1), (cx + sx * 3.0, cy - 1.6, sh + 0.55))
    box(lib.uname("Lectern"), (0.6, 0.45, 1.1), (cx + 1.4, cy - 1.2, sh + 0.55), M("Steel"))
    lib.col_box(lib.uname("Lectern"), (0.6, 0.45, 1.1), (cx + 1.4, cy - 1.2, sh + 0.55), surface="Metal")


# ------------------------------------------------------------------ the parking deck

def parking_deck():
    """A raised deck east of the building (1.6 m, over the garage), a ramp up from the plaza along its south edge with
    a railing, a ledge along its open west drop, cars parked on it."""
    x0, x1, y0, y1 = DECK
    conc = mat("Concrete", "#bbbbbb")
    box("Concrete_Deck-col", (x1 - x0, y1 - y0, DECK_H), ((x0 + x1) / 2, (y0 + y1) / 2, DECK_H / 2), conc)
    for yy in range(int(y0) + 2, int(y1), 3):
        box(lib.uname("DeckLine"), (5.0, 0.1, 0.008), (x1 - 3.5, yy, DECK_H + 0.004), paint("LineWhite", "#e6e3da"))
    # the ramp: up from the plaza side to the deck, riding east along the south edge
    L = 14.0
    # profile (along the ramp, up) extruded across it; turned -90 degrees so it rises east, spanning y0..y0+5
    ramp = prism("Concrete_DeckRamp-col", [(0.0, 0.0), (L, DECK_H), (L, 0.0)], -(y0 + 5.0), -y0, [conc] * 3,
                 [0, 0, 0], [False] * 3, cap_mat=0)
    ramp.rotation_euler = (0.0, 0.0, -math.pi / 2)
    ramp.location = (x0 - L, 0.0, 0.0)
    # railing on the ramp's south side (a long rail down to the plaza), a ledge along the deck's open west edge
    galv = M("Galv")
    p0 = (x0 - L + 0.8, y0 + 0.25, DECK_H * 0.8 / L + 0.95)
    p1 = (x0 - 0.2, y0 + 0.25, DECK_H * (L - 0.2) / L + 0.95)
    cyl_between(lib.uname("RampRail"), p0, p1, 0.026, galv, seg=12)
    for k in range(6):
        t = k / 5
        x = p0[0] + (p1[0] - p0[0]) * t
        cyl_z(lib.uname("RailPost"), (x, y0 + 0.25, DECK_H * (x - (x0 - L)) / L), p0[2] + (p1[2] - p0[2]) * t
              - DECK_H * (x - (x0 - L)) / L, 0.022, galv, seg=10)
    c = lib.col_box(lib.uname("RampRail"), (math.hypot(p1[0] - p0[0], p1[2] - p0[2]), 0.08, 0.08), (0, 0, 0),
                    surface="Metal")
    c.location = ((p0[0] + p1[0]) / 2, y0 + 0.25, (p0[2] + p1[2]) / 2)
    c.rotation_euler = (0.0, -math.atan2(p1[2] - p0[2], p1[0] - p0[0]), 0.0)
    rail(None, "garage_rail", [(p0[0] + 0.1, y0 + 0.25, p0[2] + 0.06), (p1[0] - 0.1, y0 + 0.25, p1[2] + 0.06)],
         kind="rail")
    cyl_between(lib.uname("DeckEdge"), (x0 + 0.04, y0 + 5.2, DECK_H + 0.01), (x0 + 0.04, y1 - 0.2, DECK_H + 0.01), 0.04,
                galv, seg=6, smooth=False)
    rail(None, "deck_ledge", [(x0 + 0.05, y0 + 5.4, DECK_H + 0.07), (x0 + 0.05, y1 - 0.4, DECK_H + 0.07)], kind="ledge")
    # the far edges get a guard rail (no riding off the back of the garage)
    for (a, b) in (((x0, y1), (x1, y1)), ((x1, y0), (x1, y1)), ((x0 + 0.5, y0), (x1, y0))):
        cyl_between(lib.uname("DeckGuard"), (a[0], a[1], DECK_H + 1.0), (b[0], b[1], DECK_H + 1.0), 0.03, galv, seg=8)
        L2 = math.hypot(b[0] - a[0], b[1] - a[1])
        for k in range(int(L2 // 2.5) + 1):
            t = k / max(1, int(L2 // 2.5))
            cyl_z(lib.uname("DeckGuardPost"), (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, DECK_H), 1.0, 0.025,
                  galv, seg=8)
        c = lib.col_box(lib.uname("DeckGuard"), (max(L2, 0.1), 0.12, 1.1), (0, 0, 0), surface="Wall")
        c.location = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, DECK_H + 0.55)
        c.rotation_euler = (0, 0, math.atan2(b[1] - a[1], b[0] - a[0]))
    for x, y, rot in ((49.0, 20.0, 90.0), (49.0, 26.0, 90.0), (49.0, 31.0, 90.0)):
        props.place("covered_car", x, y, rot, z=DECK_H, surface="Wall")
    # the garage under the deck: a dark opening on the plaza side
    box(lib.uname("GarageMouth"), (0.05, 6.0, 1.3), (x0 - 0.01, 24.0, 0.65), mat("Rubber", "#1e1e1e"))


# ------------------------------------------------------------------ the company picnic

def picnic():
    """The launch party on the west lawn: a food truck with the pizzas, picnic tables, a DJ table."""
    tx, ty = -51.0, -8.0                                     # the food truck, serving window facing east
    truck = empty(lib.uname("FoodTruck"), (tx, ty, 0.0), 0.0, None)
    truck["bake_group"] = "world"
    body = mat("TruckTeal", "#2b8a88")
    box(lib.uname("Wall_TruckBody") + "-col", (2.3, 5.6, 2.3), (0.0, 0.0, 1.55), body, parent=truck)
    box(lib.uname("Wall_TruckCab") + "-col", (2.2, 1.6, 1.5), (0.0, -3.4, 1.15), body, parent=truck)
    box(lib.uname("TruckWindshield"), (2.0, 0.05, 0.7), (0.0, -4.21, 1.55), houses.glass(), parent=truck)
    box(lib.uname("TruckRoof"), (2.35, 5.65, 0.08), (0.0, 0.0, 2.72), M("Steel"), parent=truck)
    for (x, y) in ((-1.0, -3.4), (1.0, -3.4), (-1.0, 1.9), (1.0, 1.9)):
        lib.cyl_between(lib.uname("TruckWheel"), (x - 0.12, y, 0.42), (x + 0.12, y, 0.42), 0.42, mat("Rubber", "#1e1e1e"),
                        seg=16, parent=truck)
    box(lib.uname("TruckWindow"), (0.05, 3.0, 1.0), (1.16, 0.2, 1.95), mat("TruckDark", "#1c1f22"), parent=truck)
    box(lib.uname("TruckCounter"), (0.5, 3.2, 0.06), (1.4, 0.2, 1.22), M("Steel"), parent=truck)
    box(lib.uname("TruckAwning"), (1.3, 3.4, 0.05), (1.8, 0.2, 2.6), mat("AwningStripe", "#e8b03a"), parent=truck)
    school.text_mesh("Truck_sign", "HILLTOP PIZZA", 0.32, (tx + 1.18, ty + 0.2, 2.35), (math.pi / 2, 0.0, math.pi / 2),
                     mat("SignWhite", "#f2f0ea"), depth=0.02)
    for x, y, rot in ((-43.0, -2.0, 90.0), (-43.0, -8.0, 90.0), (-43.0, -14.0, 90.0), (-39.0, -20.0, 0.0)):
        props.place("wooden_picnic_table", x, y, rot, surface="Wood")
    props.place("round_wooden_table_02", -38.0, 1.5, 0.0, surface="Wood")
    props.place("boombox", -38.0, 1.5, 200.0, z=props.bounds("round_wooden_table_02")[1].z, collide=False)
    for x, y in ((-47.0, 2.0), (-47.0, -18.0)):
        props.place("metal_trash_can", x, y, 0.0, surface="Metal")
    props.place("plastic_crate_02", tx + 1.6, ty - 2.2, 20.0, surface="Wall")
    props.place("plastic_crate_02", tx + 1.6, ty - 2.2, -10.0, z=props.bounds("plastic_crate_02")[1].z, collide=False)


def campus_sign():
    stone = mat("StoneDk", "#8d8c88")
    sx = -20.0
    box("Concrete_CampusSign-col", (12.0, 0.9, 1.0), (sx, -25.5, 0.5), stone)
    box("Concrete_CampusSignCap-col", (12.2, 1.1, 0.1), (sx, -25.5, 1.05), mat("Paving", "#a09c94"))
    school.text_mesh("CampusSign_name", "HILLTOP", 0.5, (sx, -25.96, 0.62), school.FACING_SOUTH,
                     mat("SignWhite", "#f2f0ea"), depth=0.02)
    school.text_mesh("CampusSign_sub", "CAMPUS", 0.16, (sx, -25.96, 0.27), school.FACING_SOUTH,
                     mat("SignWhite", "#f2f0ea"), depth=0.01)
    rail(None, "sign_ledge", [(sx - 5.9, -25.5, 1.17), (sx + 5.9, -25.5, 1.17)], kind="ledge")


def furniture():
    for x in range(-50, 51, 20):
        props.place("street_lamp_02", float(x), -32.1, 0.0, surface="Metal")
    props.place("fire_hydrant", 4.0, -32.1, 90.0, surface="Metal")
    shrubs = [(-34.0, 10.0), (-34.0, -4.0), (34.0, -4.0), (-12.0, -18.0), (2.0, -18.0), (-30.0, 20.0), (12.0, 18.0),
              (20.0, 20.0), (-46.0, 12.0)]
    for i, (x, y) in enumerate(shrubs):
        props.place("shrub_03", x, y, i * 47.0, z=terrain.lawn_rise(x, y) + LAWN_Z, scale=0.7 + (i * 31 % 7) * 0.08,
                    collide=False)


def plant_trees():
    spots = []
    for x in range(-54, 55, 12):                              # street trees along Campus Drive
        if not -12.0 < x + 3.0 < -2.0:
            spots.append((float(x) + 3.0, -28.2))
    spots += [(-30.0, -20.0), (-22.0, -19.0), (6.0, -21.0), (14.0, -24.0), (-54.0, 12.0), (-54.0, 30.0), (-48.0, 50.0),
              (-20.0, 50.0), (6.0, 50.0), (34.0, 50.0), (58.0, 40.0), (58.0, 10.0), (58.0, -14.0), (-58.0, -18.0),
              (-34.0, -24.0), (22.0, 16.0)]
    for i, (x, y) in enumerate(spots):
        h = 6.5 + (i * 37 % 5) * 0.7
        trees.tree(lib.uname("Tree"), (x, y, terrain.lawn_z(x, y)), height=h, crown=2.6 + (i * 13 % 4) * 0.35, seed=70 + i, collide=True)
    for x, y in ((-16.0, 10.0), (9.0, 9.5), (18.0, 10.0)):     # plaza trees in grates, clear of the steps' landing
        box(lib.uname("TreeGrate"), (1.4, 1.4, 0.012), (x, y, 0.006), M("Steel"))
        trees.tree(lib.uname("Tree"), (x, y, 0.0), height=7.0, crown=2.4, seed=int(x) + 90, collide=True, litter=0)


def markers():
    marker("Spawn_Player", -7.0, -22.0, 0.02, 0.0)
    marker("Start_front", -7.0, -22.0, 0.02, 0.0)
    marker("Start_plaza", -12.0, 0.0, 0.02, -90.0)
    marker("Start_steps", -7.0, 18.5, TERRACE_H + 0.02, 180.0)
    marker("Start_amphi", 29.0, -14.5, 0.02, -90.0)
    marker("Start_deck", 44.0, 24.0, DECK_H + 0.02, 90.0)
    marker("Start_picnic", -45.0, -5.0, 0.02, -90.0)
    marker("Start_fountain", 5.0, -6.0, 0.02, -60.0)
    # the team at the picnic (a character at rot 0 faces south)
    for i, (x, y, rot) in enumerate(((-40.5, -4.5, 100.0), (-38.5, -10.5, 70.0), (-35.0, -16.5, 110.0))):
        marker(f"Event_kid_{i + 1}", x, y, 0.02, rot)
    # the pizzas: on the food truck's counter -> the first picnic table
    lo, hi = props.bounds("wooden_picnic_table")
    marker("Event_pizza_pickup", -51.0 + 1.4, -8.0 + 0.2, 1.27)
    marker("Event_pizza_drop", -43.0, -2.0, hi.z + 0.02)
    marker("Event_zone_stage", STAGE[0], STAGE[1], 0.02)
    # D-E-P-L-O-Y: over the atrium steps, the fountain, the stage, the deck's drop, the hubba, up the ramp
    for letter, (x, y, z) in zip("DEPLOY", ((-7.0, 14.2, 2.6), (FOUNTAIN[0], FOUNTAIN[1], 2.3), (STAGE[0], STAGE[1], 2.0),
                                           (32.8, 27.0, 2.2), (0.6, 13.0, 2.4), (28.0, 16.5, 2.4))):
        marker(f"Event_letter_{letter}", x, y, z)


def write_look(out):
    import json
    look = {"joints": {}, "bake_energy": 1.6, "exposure": 1.0, "sky_display": 2.6}
    with open(os.path.splitext(out)[0] + ".look.json", "w") as f:
        json.dump(look, f, indent=1)


def build(out, bake=True, samples=128):
    realism.set_sky(SKY)
    ground()
    building()
    terrace()
    plaza()
    amphitheatre()
    parking_deck()
    picnic()
    campus_sign()
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
