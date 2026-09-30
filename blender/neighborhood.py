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
    # lawn around everything, with holes left for the hard surfaces (separate slabs sit on top)
    slab("Lawn", "Grass", "Grass", -60.0, 60.0, -30.0, 60.0, top=LAWN_Z)
    # street: sidewalk, curb drop, road, sidewalk
    slab("SidewalkN", "Concrete", "Sidewalk", -60.0, 60.0, -32.5, -30.0, top=0.0)
    slab("Road", "Path", "Road", -60.0, 60.0, -40.5, -32.5, top=ROAD_Z)
    slab("SidewalkS", "Concrete", "Sidewalk", -60.0, 60.0, -43.0, -40.5, top=0.0)
    slab("FrontYards", "Grass", "Grass", -60.0, 60.0, -60.0, -43.0, top=LAWN_Z)
    # the skate plaza, the path in from the street and the one across to the party
    slab("Plaza", "Plaza", "Plaza", -34.0, 6.0, -24.0, 10.0, top=0.0, group="plaza")
    slab("PathIn", "Path", "Path", -16.0, -12.0, -30.0, -24.0, top=-0.01)
    slab("PathEast", "Path", "Path", 6.0, 16.0, -4.0, 0.0, top=-0.01)
    slab("PathNorth", "Path", "Path", -16.0, -12.0, 10.0, 45.0, top=-0.01)
    # the picnic area: paving stones
    slab("Picnic", "Plaza", "Paving", 16.0, 34.0, -12.0, 8.0, top=0.0, group="plaza")


def skate_features():
    mini_ramp(root("Mini", -24.0, 2.0, 90.0), W=8.0, R=2.7, H=1.6, F=5.0, D=1.8)
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
    # the party bench: a bench along the path with its seat edge as a grindable line
    b = props.place("painted_wooden_bench", 13.0, 2.2, 0.0, surface="Wood", name="Prop_party_bench")
    blo, bhi = props.bounds("painted_wooden_bench")
    rail(None, "party_bench", [(13.0 + blo.x + 0.1, 2.2 + blo.y + 0.05, bhi.z * 0.62 + 0.07),
                               (13.0 + bhi.x - 0.1, 2.2 + blo.y + 0.05, bhi.z * 0.62 + 0.07)], kind="ledge")
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
    props.place("metal_trash_can", 11.5, 1.2, 0.0, surface="Metal")
    props.place("metal_trash_can", -17.5, -26.0, 0.0, surface="Metal")
    for x, y in ((-35.5, 0.0), (7.5, -10.0), (-20.0, 11.5)):
        props.place("planter_box_01", x, y, 0.0, surface="Wall")
    for i, (x, y) in enumerate(((-40.0, -28.0), (-30.0, -28.5), (20.0, -28.0), (35.0, -28.5), (40.0, 12.0),
                                (-40.0, 14.0), (36.0, -14.0), (12.0, -16.0))):
        props.place("shrub_03", x, y, i * 47.0, collide=False)
    props.place("tree_stump_01", 38.0, 2.0, 0.0, surface="Wood")


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
        trees.tree(lib.uname("Tree"), (x, y, LAWN_Z), height=h, crown=2.6 + (i * 13 % 4) * 0.35, seed=i)


def neighbourhood_houses():
    sidings = ["Siding", "SidingBlue", "SidingSage", "Siding", "SidingSage", "SidingBlue", "Siding", "SidingBlue"]
    for i, x in enumerate(range(-52, 53, 15)):
        r = empty(lib.uname("House"), (float(x), -50.5, 0.0), 0.0, None)
        houses.house(r, w=10.0 + (i % 3), d=8.5, h=5.6 if i % 2 == 0 else 3.2, siding=sidings[i % len(sidings)],
                     seed=i, storeys=2 if i % 2 == 0 else 1)
    for i, x in enumerate(range(-45, 50, 18)):
        r = empty(lib.uname("House"), (float(x), 55.0, 0.0), math.pi, None)
        houses.house(r, w=11.0, d=9.0, h=5.6, siding=sidings[(i + 3) % len(sidings)], seed=20 + i)


def event_markers():
    marker("Spawn_Player", -14.0, -27.5, 0.02, 0.0)
    marker("Start_plaza", -14.0, -27.5, 0.02, 0.0)
    marker("Start_mini", -24.0, 2.0, 0.02, 90.0)
    marker("Start_party", 10.0, -2.0, 0.02, -90.0)
    marker("Start_street", -45.0, -36.5, 0.02, -90.0)
    for i, (x, y) in enumerate(((9.0, 4.5), (-6.0, -15.0), (-31.0, 9.0))):
        marker(f"Event_kid_{i + 1}", x, y, 0.02, 0.0)
    # P-A-R-T-Y balloons: over the mini ramp, the flat rail, the stairs' drop, the quarter pipe, the picnic tables
    for letter, (x, y, z) in zip("PARTY", ((-24.0, 2.0, 3.6), (-20.0, -11.0, 1.9), (0.0, -1.5, 2.2),
                                            (2.0, -17.6, 4.0), (24.0, -3.0, 2.6))):
        marker(f"Event_letter_{letter}", x, y, z)


def build(out_glb, bake=True, samples=128):
    ground()
    skate_features()
    party()
    furniture()
    neighbourhood_houses()
    plant_trees()
    event_markers()
    objs = list(lib.bpy.context.scene.objects)
    realism.dress([o for o in objs if not o.get("library") and not o.name.startswith("Tree")])
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
        realism.bake(world, base + ".lightmap.world.png", samples=samples)
    props.remove_library()
