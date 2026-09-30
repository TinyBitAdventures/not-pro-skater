"""
Level 1, Neighborhood Park: a real-scale suburban park with a concrete skate plaza, a paved picnic area where
the birthday party happens, lawn, paths, a street with sidewalks and curbs, and houses across the road.

Blender axes (Z up); Godot sees (x, z, -y). The street runs along the south (-Y) edge; the plaza sits west of
centre, the party area east of it. Everything uses the realistic look (realism.py): the plaza and party area
bake into their own sharper lightmap ("plaza"), the rest into "world".

Event markers (read by the Godot event system):
    Event_cake_pickup / Event_cake_drop     the cake's table at the street and the party table
    Event_kid_<n>                            where the kids stand (they want to see a trick)
    Event_letter_<L>                         the P-A-R-T-Y balloons (some only reachable in the air)
    Start_<name>                             warp spots
"""

import math

import lib
from lib import box, empty, mat, rail
from pieces import bank, flat_rail, ledge, manual_pad, mini_ramp, quarter_pipe, stair_set
import houses
import park_props as props
import realism
import terrain
import trees

LAWN_Z = -0.04
ROAD_Z = -0.12


def slab(name, surface, matname, x0, x1, y0, y1, top=0.0, t=0.5, group="world"):
    ob = box(f"{surface}_{name}-col", (x1 - x0, y1 - y0, t), ((x0 + x1) / 2, (y0 + y1) / 2, top - t / 2),
             mat(matname, "#888888"))
    ob["bake_group"] = group
    return ob


def root(name, x, y, rot_deg=0.0, group="plaza"):
    r = empty(lib.uname(name), (x, y, 0.0), math.radians(rot_deg), None)
    r["bake_group"] = group
    return r


def marker(name, x, y, z=0.02, rot_deg=0.0):
    empty(name, (x, y, z), math.radians(rot_deg), None, size=0.5)


def ground():
    # the lawn rolls a little (terrain.py) and flattens to meet everything built; hard surfaces sit on top
    terrain.lawn()
    # street: sidewalk, curb drop, road, sidewalk. Raised slabs are only as thick as their step down (plus a
    # little): a buried side face bakes black and bleeds into the visible strip as a dark line along the curb.
    slab("SidewalkN", "Concrete", "Sidewalk", -60.0, 60.0, -32.5, -30.0, top=0.0, t=-ROAD_Z)   # down to the road exactly
    slab("Road", "Path", "Road", -60.0, 60.0, -40.5, -32.5, top=ROAD_Z, t=0.3)
    slab("SidewalkS", "Concrete", "Sidewalk", -60.0, 60.0, -43.0, -40.5, top=0.0, t=-ROAD_Z)
    slab("FrontYards", "Grass", "Grass", -60.0, 60.0, -60.0, -43.0, top=LAWN_Z)
    # the skate plaza, the path in from the street and the one across to the party
    slab("Plaza", "Plaza", "Plaza", -34.0, 6.0, -24.0, 10.0, top=0.0, t=0.1, group="plaza")
    slab("PathIn", "Path", "Path", -16.0, -12.0, -30.0, -24.0, top=-0.01, t=0.08)
    slab("PathEast", "Path", "Path", 6.0, 16.0, -4.0, 0.0, top=-0.01, t=0.08)
    slab("PathNorth", "Path", "Path", -16.0, -12.0, 10.0, 45.0, top=-0.01, t=0.08)
    # the picnic area: paving stones
    slab("Picnic", "Plaza", "Paving", 16.0, 34.0, -12.0, 8.0, top=0.0, t=0.1, group="plaza")


def skate_features():
    mini_ramp(root("Mini", -24.0, 2.0, 90.0), W=8.0, R=2.7, H=1.6, F=5.0, D=1.8, decals=False)
    ledge(root("LedgeHigh", -10.0, 4.0, 90.0), L=6.0, W=0.7, h=0.45)
    ledge(root("LedgeLow", -10.0, -2.5, 90.0), L=6.0, W=0.7, h=0.3)
    manual_pad(root("Manual", -2.0, -8.0), L=5.0, W=1.6, H=0.2)
    flat_rail(root("FlatRail", -20.0, -11.0, 90.0), L=6.0, h=0.5, color="Red")
    stair_set(root("Stairs", 0.0, 3.0, 180.0), n=4)
    quarter_pipe(root("QP", 2.0, -16.0, 180.0), W=6.0, R=2.8, H=1.8, D=1.5, rails=True, decals=False)
    bank(root("Bank", -28.0, -18.0, 0.0), W=4.0, L=3.0, H=0.8)


def party():
    for x, y in ((21.0, -6.0), (27.0, -6.0), (21.0, 0.5)):
        props.place("wooden_picnic_table", x, y, 90.0, surface="Wood")
    props.place("round_wooden_table_02", 28.0, 1.5, 0.0, surface="Wood")
    lo, hi = props.bounds("round_wooden_table_02")      # the cake itself is a runtime item (the event moves it)
    lo2, hi2 = props.bounds("wooden_picnic_table")
    props.place("boombox", 21.0, -6.3, 20.0, z=hi2.z, collide=False)
    props.place("plastic_crate_02", 22.6, -7.4, 15.0, collide=False)                 # drinks for the party
    props.place("standing_chalkboard_01", 15.2, -4.9, 70.0, surface="Wood")           # at the path into the party
    props.place("football", 12.5, -9.5, 0.0, z=terrain.lawn_rise(12.5, -9.5) + terrain.LAWN_Z, collide=False)
    props.place("american_football", 36.8, 9.4, 40.0, z=terrain.lawn_rise(36.8, 9.4) + terrain.LAWN_Z, collide=False)
    # the party bench: a bench along the path with its seat edge as a grindable line
    bz = terrain.lawn_rise(13.0, 2.2)
    b = props.place("painted_wooden_bench", 13.0, 2.2, 0.0, z=bz, surface="Wood", name="Prop_party_bench")
    blo, bhi = props.bounds("painted_wooden_bench")
    rail(None, "party_bench", [(13.0 + blo.x + 0.1, 2.2 + blo.y + 0.05, bz + bhi.z * 0.62 + 0.07),
                               (13.0 + bhi.x - 0.1, 2.2 + blo.y + 0.05, bz + bhi.z * 0.62 + 0.07)], kind="ledge")
    # the cake starts on a table at the street (the bakery drop-off)
    props.place("round_wooden_table_02", -9.0, -31.2, 0.0, surface="Wood")
    marker("Event_cake_pickup", -9.0, -31.2, hi.z + 0.02)
    marker("Event_cake_drop", 28.0, 1.5, hi.z + 0.02)
    # lamps with bunting strung between them
    for x in (17.0, 33.0):
        props.place("street_lamp_02", x, 7.0, 180.0, surface="Metal")
    bunting((17.0, 7.0, 3.6), (33.0, 7.0, 3.6), sag=0.9)


def bunting(a, b, sag=0.8, flags=26):
    colors = [("Flag_Red", "#d9443b"), ("Flag_Yellow", "#f1c232"), ("Flag_Blue", "#3d7bd9"),
              ("Flag_Green", "#44a35a"), ("Flag_White", "#f2f2f2")]
    ax, ay, az = a
    bx, by, bz = b
    pts = []
    for i in range(flags + 1):
        t = i / flags
        pts.append((ax + (bx - ax) * t, ay + (by - ay) * t, az + (bz - az) * t - sag * 4 * t * (1 - t)))
    for i in range(flags):
        p0, p1 = pts[i], pts[i + 1]
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2 - 0.32)
        cname, chex = colors[i % len(colors)]
        lib.mesh_obj(lib.uname("Flag"), [p0, p1, mid], [(0, 1, 2)], [mat(cname, chex)])
    for i in range(flags):
        lib.cyl_between(lib.uname("FlagString"), pts[i], pts[i + 1], 0.006, mat("String", "#eeeeee"), seg=4, caps=False)


def furniture():
    for x, y in ((6.5, 10.5), (-34.5, 10.5), (-34.5, -24.5), (6.5, -24.5)):
        props.place("street_lamp_02", x, y, 45.0, surface="Metal")
    for x in range(-50, 51, 20):
        props.place("street_lamp_02", float(x), -30.6, 0.0, surface="Metal")
    rise = terrain.lawn_rise
    props.place("metal_trash_can", 11.5, 1.2, 0.0, z=rise(11.5, 1.2), surface="Metal")
    props.place("metal_trash_can", -17.5, -26.0, 0.0, z=rise(-17.5, -26.0), surface="Metal")
    for x, y in ((-35.5, 0.0), (7.5, -10.0), (-20.0, 11.5)):
        props.place("planter_box_01", x, y, 0.0, z=rise(x, y), surface="Wall")
    shrubs = [(-40.0, -28.0), (-30.0, -28.5), (20.0, -28.0), (35.0, -28.5), (40.0, 12.0), (-40.0, 14.0), (36.0, -14.0),
              (12.0, -16.0),
              # clumps around the plaza's edges and along the paths: soft green edges instead of lawn meeting slab
              (-36.5, -8.0), (-36.2, -5.5), (-36.8, 4.5), (-27.0, 12.2), (-24.5, 12.6), (-5.0, 12.4), (2.5, 12.0),
              (8.2, -18.0), (8.6, -21.0), (-10.0, -27.0), (-18.2, 16.0), (-9.8, 22.0), (-18.3, 30.0), (-9.7, 38.0),
              (35.8, 5.0), (36.0, -6.0), (18.0, 10.5), (26.0, 10.2)]
    for i, (x, y) in enumerate(shrubs):
        props.place("shrub_03", x, y, i * 47.0, z=rise(x, y), scale=0.7 + (i * 31 % 7) * 0.08, collide=False)
    props.place("tree_stump_01", 38.0, 2.0, 0.0, z=rise(38.0, 2.0), surface="Wood")
    # benches along the plaza's edges, facing in
    props.place("modular_street_seating", -29.0, -24.9, 0.0, z=0.0, surface="Wood")
    props.place("modular_street_seating", -2.0, 10.9, 180.0, z=0.0, surface="Wood")
    props.place("modular_street_seating", -35.0, -12.0, 90.0, z=rise(-35.0, -12.0), surface="Wood")
    # rubbish bags next to the bins
    props.place("trashbag", 12.1, 0.5, 30.0, z=rise(12.1, 0.5), collide=False)
    props.place("trashbag", -16.9, -26.6, 110.0, z=rise(-16.9, -26.6), collide=False)


def street_life():
    """Things along the street: a fire hydrant on the park sidewalk, utility boxes by the poles, and a couple of
    cars under covers parked along the far curb."""
    props.place("fire_hydrant", -21.0, -31.0, 90.0, surface="Metal")
    props.place("fire_hydrant", 27.0, -41.9, -90.0, surface="Metal")
    props.place("utility_box_01", -28.4, -41.9, 180.0, surface="Metal")
    props.place("utility_box_01", 29.6, -41.9, 180.0, surface="Metal")
    props.place("utility_box_01", 5.2, -30.6, 0.0, surface="Metal")
    for x, rot in ((-26.0, 90.0), (44.0, 92.0)):
        props.place("covered_car", x, -39.2, rot, z=ROAD_Z, surface="Wall")
    # the neighbours' kids leave things lying around
    props.place("garden_gnome", -52.8, -45.0, 160.0, z=terrain.LAWN_Z, collide=False)
    props.place("garden_gnome", 14.2, -45.3, 200.0, z=terrain.LAWN_Z, collide=False)


def plant_trees():
    spots = []
    for x in range(-54, 55, 12):                 # street trees along the park's sidewalk
        spots.append((float(x) + 3.0, -28.2))
    spots += [(-44.0, 20.0), (-36.0, 30.0), (-24.0, 40.0), (-4.0, 26.0), (6.0, 38.0), (18.0, 24.0), (30.0, 34.0),
              (42.0, 22.0), (48.0, 40.0), (-50.0, -6.0), (40.0, -4.0), (36.0, 12.0), (12.0, -18.0), (-40.0, 4.0)]
    paths = [(-16.0, -12.0), (6.0, 16.0)]           # keep the path entrances clear
    spots = [(x, y) for (x, y) in spots if not any(x0 - 2.5 < x < x1 + 2.5 and y < -20.0 for (x0, x1) in paths)]
    for i, (x, y) in enumerate(spots):
        h = 6.0 + (i * 37 % 5) * 0.7
        trees.tree(lib.uname("Tree"), (x, y, terrain.lawn_z(x, y)), height=h, crown=2.6 + (i * 13 % 4) * 0.35, seed=i)


def neighbourhood_houses():
    """Seven houses across the street (garages, yards, fences or shrubs, mailboxes) and five behind the park."""
    sidings = ["Siding", "SidingBlue", "SidingCream", "SidingSage", "SidingGrey", "Siding", "SidingBlue"]
    roofs = ["Roof", "RoofDark", "RoofBrown"]
    for i, x in enumerate(range(-51, 52, 17)):
        w, d = 9.5 + (i % 3) * 0.75, 8.5
        r = empty(lib.uname("House"), (float(x), -50.5, 0.0), 0.0, None)
        garage = i % 2 == 0
        frontage = ["fence", "shrubs", None][i % 3]
        houses.house(r, w=w, d=d, h=5.6 if i % 2 == 0 else 3.2, siding=sidings[i % len(sidings)], seed=i,
                     storeys=2 if i % 2 == 0 else 1, roof=roofs[i % 3], garage=garage, chimney=i % 3 != 1,
                     yard=-43.0 - (-50.5 + d / 2), frontage=frontage)
        if frontage == "shrubs":
            for k in range(4):
                sx = x - w / 2 + 0.8 + k * (w - 1.6) / 3
                if abs(sx - x) > 1.2:                    # keep the front walk clear
                    props.place("shrub_03", sx, -43.9, i * 31.0 + k * 77.0, scale=0.8, collide=False)
    for i, x in enumerate(range(-45, 50, 18)):
        r = empty(lib.uname("House"), (float(x), 55.0, 0.0), math.pi, None)
        houses.house(r, w=11.0, d=9.0, h=5.6, siding=sidings[(i + 3) % len(sidings)], seed=20 + i,
                     roof=roofs[(i + 1) % 3], chimney=i % 2 == 0)


def paint(name, hex_color, rough=0.85):
    m = mat(name, hex_color)
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    if bsdf is not None:
        bsdf.inputs["Roughness"].default_value = rough
    return m


def street_details():
    """A dashed centre line, a crosswalk where the park path meets the street, and power poles with sagging
    wires along the far sidewalk."""
    z = ROAD_Z + 0.004
    yellow = paint("LineYellow", "#d9ac3a")
    white = paint("LineWhite", "#e6e3da")
    x = -58.0
    while x < 58.0:
        if not -17.0 < x < -11.0:
            box(lib.uname("Line"), (3.0, 0.12, 0.008), (x + 1.5, -36.5, z), yellow)
        x += 9.0
    for k in range(7):
        box(lib.uname("Crosswalk"), (3.2, 0.5, 0.008), (-14.0, -39.6 + k * 1.05, z), white)
    wire = paint("Wire", "#1b1b1c", 0.6)
    tops = []
    for px in (-58.0, -29.0, 0.0, 29.0, 58.0):
        base = (px, -41.0, 0.0)
        lib.cyl_z(lib.uname("Pole"), base, 8.6, 0.14, mat("Pole", "#6b5a48"), r1=0.11, seg=8)
        box(lib.uname("Pole_arm"), (0.12, 1.9, 0.12), (px, -41.0, 7.9), mat("Pole", "#6b5a48"))
        tops.append([(px, -41.0 + dy, 8.0) for dy in (-0.85, 0.0, 0.85)])
    for a, b in zip(tops, tops[1:]):
        for p0, p1 in zip(a, b):
            pts = []
            for i in range(9):
                t = i / 8
                pts.append((p0[0] + (p1[0] - p0[0]) * t, p0[1], p0[2] - 0.6 * 4 * t * (1 - t)))
            for q0, q1 in zip(pts, pts[1:]):
                lib.cyl_between(lib.uname("Wire"), q0, q1, 0.012, wire, seg=4, caps=False)


def event_markers():
    marker("Spawn_Player", -14.0, -27.5, 0.02, 0.0)
    marker("Start_plaza", -14.0, -27.5, 0.02, 0.0)
    marker("Start_mini", -24.0, 2.0, 0.02, 90.0)
    marker("Start_party", 10.0, -2.0, 0.02, -90.0)
    marker("Start_street", -45.0, -36.5, 0.02, -90.0)
    for i, (x, y) in enumerate(((9.0, 4.5), (-6.0, -15.0), (-31.0, 9.0))):
        marker(f"Event_kid_{i + 1}", x, y, max(0.02, terrain.lawn_rise(x, y) + 0.02), 0.0)
    # P-A-R-T-Y balloons: over the mini ramp, the flat rail, the stairs' drop, the quarter pipe, the picnic tables
    for letter, (x, y, z) in zip("PARTY", ((-24.0, 2.0, 3.6), (-20.0, -11.0, 1.9), (0.0, -1.5, 2.2),
                                            (2.0, -17.6, 4.0), (24.0, -3.0, 2.6))):
        marker(f"Event_letter_{letter}", x, y, z)


def write_look(out_glb):
    """Surface dressing Godot applies to the baked concrete (baked_pbr.gdshader): a 2 m saw-cut grid across the
    plaza (its edges sit on the grid) and cross cuts every 1.5 m along the sidewalks. Godot axes (x, -y)."""
    import json
    look = {"joints": {"PBR_concrete": {"grid": [2.0, 2.0], "rect": [-34.0, -10.0, 6.0, 24.0], "along_x": 1.5}},
            # late afternoon (realism.SKY): the low sun's sky is dim, so the baked shade is lifted and exposed up
            "bake_energy": 2.1, "exposure": 1.0}
    with open(out_glb[:-4] + ".look.json", "w") as f:
        json.dump(look, f, indent=1)


def build(out_glb, bake=True, samples=128):
    ground()
    skate_features()
    party()
    furniture()
    neighbourhood_houses()
    street_details()
    street_life()
    plant_trees()
    event_markers()
    tree_fn = lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed)
    terrain.backdrop(tree_fn=lambda name, base, h, crown, seed: trees.tree(name, base, height=h, crown=crown, seed=seed,
                                                                         cards=60, litter=0))
    terrain.edge_trees(tree_fn)
    objs = list(lib.bpy.context.scene.objects)
    realism.dress([o for o in objs if not o.get("library") and not o.name.startswith(("Tree", "Far_Tree", "FarTree"))])
    realism.split_collision()
    plaza = realism.join_static("Baked_plaza", group="plaza")
    world = realism.join_static("Baked_world", group="world")
    if plaza is not None:
        plaza["bake_group"] = "plaza"
    if world is not None:
        world["bake_group"] = "world"
    if bake:
        base = out_glb[:-4]
        realism.bake(plaza, base + ".lightmap.plaza.png", samples=samples)
        realism.bake(world, base + ".lightmap.world.png", size=1024, samples=samples)     # lawn, street, houses: soft light
    props.remove_library()
    realism.join_live()
    terrain.join_far()
    write_look(out_glb)
