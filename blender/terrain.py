"""
Ground with some shape, and a world past the park's edge.

lawn(): the park lawn as a gently rolling mesh (a few low mounds and soft undulation) that flattens smoothly
wherever it meets something built (plaza, paths, picnic paving, sidewalk, houses), so every kit piece still sits
on level ground. lawn_z(x, y) gives its height for placing trees, shrubs, props and markers.

backdrop(): everything past the playable square (x -60..60, y -60..60): the street carrying on to the horizon,
terrain rising into low hills, and a few hundred distant trees. It is lit live (not baked) and ends up as one
object, "Far", so it costs a handful of draw calls; the fog turns it hazy with distance.

Blender axes (Z up); Godot sees (x, z, -y).
"""

import math
import random

import bpy

import lib
from lib import mat

LAWN_Z = -0.04
ROAD_Z = -0.12
EDGE = 60.0                           # the playable square: x -EDGE..EDGE, y -EDGE..EDGE

# built things the lawn must meet flat: (x0, x1, y0, y1)
HARD = [
    (-34.0, 6.0, -24.0, 10.0),        # plaza
    (-16.0, -12.0, -30.0, -24.0),     # path in from the street
    (6.0, 16.0, -4.0, 0.0),           # path across to the party
    (-16.0, -12.0, 10.0, 45.0),       # path north
    (16.0, 34.0, -12.0, 8.0),         # picnic paving
    (-60.0, 60.0, -60.0, -30.0),      # the street side (sidewalks, road, front yards)
]
for _x in range(-45, 50, 18):         # the houses behind the park
    HARD.append((_x - 7.0, _x + 7.0, 49.0, 61.0))

# low mounds: (x, y, radius, height)
MOUNDS = [(-46.0, 27.0, 9.0, 1.9), (40.0, 33.0, 11.0, 2.5), (-50.0, -8.0, 6.5, 1.2), (49.0, 8.0, 7.0, 1.3),
          (8.0, 30.0, 6.0, 0.9)]


def configure(hard, mounds):
    """Another level's layout: the rectangles the lawn meets flat, and its mounds. (Defaults: Neighborhood Park.)"""
    HARD[:] = list(hard)
    MOUNDS[:] = list(mounds)


def _rect_dist(x, y, r):
    dx = max(r[0] - x, 0.0, x - r[1])
    dy = max(r[2] - y, 0.0, y - r[3])
    return math.hypot(dx, dy)


def _smooth(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def lawn_rise(x, y):
    """Height above LAWN_Z: 0 within 1.5 m of anything built, full shape from 10 m away."""
    d = min(_rect_dist(x, y, r) for r in HARD)
    k = _smooth((d - 1.5) / 8.5)
    if k <= 0.0:
        return 0.0
    base = 0.35 * math.sin(0.13 * x + 0.7) * math.sin(0.11 * y + 2.1) + 0.2 * math.sin(0.27 * x - 0.19 * y + 1.3) \
        + 0.12 * math.sin(0.41 * x + 0.37 * y) + 0.25
    mound = sum(h * math.exp(-((x - mx) ** 2 + (y - my) ** 2) / (r * r)) for (mx, my, r, h) in MOUNDS)
    # level again at the square's edge, where the far terrain starts flat: it stood up to 0.6 m above it there
    # (a step, and cracks you could see the sky through)
    edge = _smooth((EDGE - max(abs(x), abs(y))) / 6.0)
    return (base + mound) * k * edge


def lawn_z(x, y):
    return LAWN_Z + lawn_rise(x, y)


def lawn(step=1.0):
    """The lawn (-60..60, -30..60) as one rolling mesh: visible and collidable ("Grass_" surface)."""
    x0, x1, y0, y1 = -EDGE, EDGE, -30.0, EDGE
    nx, ny = int((x1 - x0) / step), int((y1 - y0) / step)
    verts, faces = [], []
    for j in range(ny + 1):
        for i in range(nx + 1):
            x, y = x0 + i * step, y0 + j * step
            verts.append((x, y, lawn_z(x, y)))
    for j in range(ny):
        for i in range(nx):
            a = j * (nx + 1) + i
            faces.append((a, a + 1, a + nx + 2, a + nx + 1))
    ob = lib.mesh_obj("Grass_Lawn-col", verts, faces, [mat("Grass", "#888888")], smooth=[True] * len(faces))
    ob["bake_group"] = "world"
    return ob


# ------------------------------------------------------------------ past the edge

def _far_rise(x, y):
    """Terrain outside the square: level at the edge, low hills from about 60 m out."""
    d = max(abs(x) - EDGE, abs(y) - EDGE, 0.0)
    if d <= 0.0:
        return 0.0
    a = math.atan2(y, x)
    hills = 9.0 + 7.0 * math.sin(3.0 * a + 0.8) + 5.0 * math.sin(7.0 * a + 2.3) + 3.0 * math.sin(13.0 * a)
    swell = 0.6 * math.sin(0.05 * x + 1.1) * math.sin(0.06 * y + 0.3)
    return _smooth((d - 25.0) / 170.0) * max(hills, 2.0) + _smooth(d / 25.0) * swell


def _in_street_band(y, margin=0.0):
    return -43.0 - margin <= y <= -30.0 + margin


def backdrop(extent=420.0, step=12.0, tree_fn=None, road_top=ROAD_Z, walk_top=0.0, ground=None, far_trees=True, hills=True):
    """The world past the square: rolling far terrain, the street carrying on both ways, clumps of trees.
    road_top / walk_top: the level's own road and sidewalk heights, so the street continues without a step.
    ground: (material name, colour) for the far ground (a city's is paved); far_trees=False for no meadow trees."""
    far_grass = mat(*ground) if ground else mat("FarGrass", "#6a8a44")
    # terrain: a grid outside the square only (the park's own ground covers the inside)
    n = int(2 * extent / step)
    verts, faces = [], []
    index = {}

    def vid(i, j):
        if (i, j) not in index:
            x, y = -extent + i * step, -extent + j * step
            z = LAWN_Z + (_far_rise(x, y) if hills else 0.0)      # a city is flat to the horizon
            if _in_street_band(y, 6.0):
                z = LAWN_Z                                # the rows either side of the street: flat verge
            index[(i, j)] = len(verts)
            verts.append((x, y, z))
        return index[(i, j)]

    for j in range(n):
        for i in range(n):
            xa, ya = -extent + i * step, -extent + j * step
            xb, yb = xa + step, ya + step
            if xa >= -EDGE and xb <= EDGE and ya >= -EDGE and yb <= EDGE:
                continue                                  # inside the park
            if _in_street_band(ya, 6.0) and _in_street_band(yb, 6.0):
                continue                                  # the street's band: road, walks and verges below
            faces.append((vid(i, j), vid(i + 1, j), vid(i + 1, j + 1), vid(i, j + 1)))
    lib.mesh_obj("Far_Terrain", verts, faces, [far_grass], smooth=[True] * len(faces))
    # the terrain grid ran one row down the road's centreline, 8 cm above the road: it buried the far street,
    # its sidewalks poking through as white wedges. The band is flat verge either side of the walks instead
    band_lo, band_hi = None, None
    for j in range(n + 1):
        y = -extent + j * step
        if _in_street_band(y, 6.0):
            band_lo = y if band_lo is None else band_lo
            band_hi = y
    for sx in (-1, 1):
        xa, xb = sx * EDGE, sx * extent
        lo, hi = min(xa, xb), max(xa, xb)
        for y0, y1 in ((band_lo, -43.0), (-30.0, band_hi)):
            lib.quad(lib.uname("Far_Verge"), (lo, y0, LAWN_Z), (hi, y0, LAWN_Z), (hi, y1, LAWN_Z), (lo, y1, LAWN_Z), far_grass)
    # the street carries on both ways: road, sidewalks
    road = mat("FarRoad", "#4c4f55")
    walk = mat("FarWalk", "#b9b6ae")
    for sx in (-1, 1):
        xa, xb = sx * EDGE, sx * extent
        lo, hi = min(xa, xb), max(xa, xb)
        lib.box("Far_Road", (hi - lo, 8.0, 0.1), ((lo + hi) / 2, -36.5, road_top - 0.05), road)
        for y0, y1 in ((-32.5, -30.0), (-43.0, -40.5)):
            lib.box("Far_Walk", (hi - lo, y1 - y0, walk_top - road_top), ((lo + hi) / 2, (y0 + y1) / 2, (walk_top + road_top) / 2),
                    walk)
    if far_trees:
        _far_trees(extent, tree_fn)


def city_blocks(seed=5, inner=68.0, outer=150.0, keep_clear=()):
    """A city past the edge: blocks of offices and flats in rings round the square, low near it and taller
    further out, so every street ends in buildings instead of meadow. Flat live colours (they're far away and must
    stay out of the bake's atlas). keep_clear: (x0, x1, y0, y1) boxes to leave empty (a street's vista, say)."""
    rnd = random.Random(seed)
    colours = [("FarBlockA", "#a39b8f"), ("FarBlockB", "#8c8378"), ("FarBlockC", "#b7b0a5"), ("FarBlockD", "#7d7f84"),
               ("FarBlockE", "#9a6f5d")]
    mats = [mat(n, c) for n, c in colours]
    placed = 0
    for k in range(2000):
        if placed >= 90:
            break
        x = rnd.uniform(-outer, outer)
        y = rnd.uniform(-outer, outer)
        d = max(abs(x), abs(y))
        if d < inner or _in_street_band(y, 8.0):
            continue
        if any(x0 <= x <= x1 and y0 <= y <= y1 for (x0, x1, y0, y1) in keep_clear):
            continue
        w, dp = rnd.uniform(12.0, 26.0), rnd.uniform(12.0, 26.0)
        h = rnd.uniform(8.0, 18.0) + (d - inner) / (outer - inner) * rnd.uniform(10.0, 40.0)
        lib.box(lib.uname("Far_Block"), (w, dp, h), (x, y, h / 2 - 0.2), mats[k % len(mats)])
        placed += 1


def _far_trees(extent, tree_fn=None):
    """Trees in clumps past the edge. With tree_fn (trees.tree), three leaf-card tree variants are built once and
    every other tree is a linked copy (FarTree_*): the glb stores each variant once and Godot draws all copies of
    a variant as one MultiMesh. Without it, simple blobs (a fallback for builds without the leaf texture)."""
    rnd = random.Random(7)
    spots = []
    tries = 0
    while len(spots) < 240 and tries < 8000:
        tries += 1
        x = rnd.uniform(-240.0, 240.0)
        y = rnd.uniform(-240.0, 240.0)
        d = max(abs(x) - EDGE, abs(y) - EDGE)
        if d < 22.0 or _in_street_band(y, 5.0):
            continue                                      # nearer than that, real trees stand (edge_trees)
        # clumps: keep a tree only where a slow pattern says "wood", thinning with distance
        wood = math.sin(0.045 * x + 1.3) * math.sin(0.05 * y + 0.4) + 0.5 * math.sin(0.11 * x - 0.07 * y)
        if wood < 0.1 or rnd.random() > 1.0 - d / 420.0:
            continue
        spots.append((x, y, LAWN_Z + _far_rise(x, y)))
    if tree_fn is None:
        return
    variants = [tree_fn(f"FarTree_v{k}", (0.0, 0.0, 0.0), 8.0 + k * 1.2, 3.0 + k * 0.3, 300 + k) for k in range(3)]
    for i, (x, y, z) in enumerate(spots):
        src = variants[i % len(variants)]
        ob = src if i < len(variants) else bpy.data.objects.new(f"FarTree_{i}", src.data)
        if ob is not src:
            bpy.context.scene.collection.objects.link(ob)
        s = rnd.uniform(0.8, 1.3)
        ob.location = (x, y, z - 0.2)
        ob.rotation_euler = (0.0, 0.0, rnd.uniform(0.0, math.tau))
        ob.scale = (s, s, s * rnd.uniform(0.9, 1.15))


def edge_trees(tree_fn):
    """Real trees (trees.tree) in a loose band just past the edge, where the simple far trees would look like
    what they are. tree_fn(name, base, height, crown, seed)."""
    rnd = random.Random(21)
    placed = 0
    for k in range(400):
        if placed >= 34:
            break
        side = rnd.randrange(4)
        t = rnd.uniform(-EDGE - 15.0, EDGE + 15.0)
        out = rnd.uniform(4.0, 20.0)
        x, y = [(t, EDGE + out), (t, -EDGE - out), (EDGE + out, t), (-EDGE - out, t)][side]
        if _in_street_band(y, 4.0) or (side == 1):
            continue                                      # the south side is the houses' back gardens: skip
        z = LAWN_Z + _far_rise(x, y)
        tree_fn(lib.uname("Far_Tree"), (x, y, z - 0.1), rnd.uniform(6.5, 10.0), rnd.uniform(2.6, 3.6), 100 + k)
        placed += 1


def join_far():
    """Everything past the edge as one object (a few materials: a few draw calls)."""
    obs = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("Far_")]
    if not obs:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    far = bpy.context.view_layer.objects.active
    far.name = "Far"
    far.data.name = "Far"
    return far
