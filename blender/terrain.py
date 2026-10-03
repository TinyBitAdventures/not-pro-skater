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
from lib import mat, prism

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

_FLAT = [25.0]                        # how far past the edge the far terrain stays level (backdrop's flat_to)


def _far_rise(x, y):
    """Terrain outside the square: level at the edge, low hills from about 60 m out."""
    d = max(abs(x) - EDGE, abs(y) - EDGE, 0.0)
    if d <= 0.0:
        return 0.0
    a = math.atan2(y, x)
    hills = 9.0 + 7.0 * math.sin(3.0 * a + 0.8) + 5.0 * math.sin(7.0 * a + 2.3) + 3.0 * math.sin(13.0 * a)
    if d < _FLAT[0]:
        return 0.0 if _FLAT[0] > 25.0 else _smooth(d / 25.0) * 0.6 * math.sin(0.05 * x + 1.1) * math.sin(0.06 * y + 0.3)
    swell = 0.6 * math.sin(0.05 * x + 1.1) * math.sin(0.06 * y + 0.3)
    return _smooth((d - _FLAT[0]) / 170.0) * max(hills, 2.0) + _smooth((d - _FLAT[0] + 25.0) / 25.0) * swell


def _in_street_band(y, margin=0.0):
    return -43.0 - margin <= y <= -30.0 + margin


def backdrop(extent=420.0, step=12.0, tree_fn=None, road_top=ROAD_Z, walk_top=0.0, ground=None, far_trees=True, hills=True,
             flat_to=25.0, near_ground=None, street_from=EDGE):
    """The world past the square: rolling far terrain, the street carrying on both ways, clumps of trees.
    road_top / walk_top: the level's own road and sidewalk heights, so the street continues without a step.
    ground: (material name, colour) for the far ground (a city's is paved); far_trees=False for no meadow trees.
    flat_to: the ground stays level this far past the edge (room for industrial()); near_ground: (material name,
    colour) for that level band (yards), with the far trees and hills only beyond it. street_from: where the level's
    own street ends (Downtown and the Backlot run theirs out to 62 m: from 60, the two overlapped and flickered)."""
    _FLAT[0] = flat_to
    far_grass = mat(*ground) if ground else mat("FarGrass", "#6a8a44")
    near = mat(*near_ground) if near_ground else far_grass
    # terrain: a grid outside the square only (the park's own ground covers the inside)
    n = int(2 * extent / step)
    verts, faces, face_mats = [], [], []
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
            d = max(abs(xa + step / 2) - EDGE, abs(ya + step / 2) - EDGE)
            face_mats.append(1 if d < flat_to - step else 0)
    lib.mesh_obj("Far_Terrain", verts, faces, [far_grass, near], face_mats=face_mats, smooth=[True] * len(faces))
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
            lib.quad(lib.uname("Far_Verge"), (lo, y0, LAWN_Z), (hi, y0, LAWN_Z), (hi, y1, LAWN_Z), (lo, y1, LAWN_Z),
                     near if near_ground else far_grass)
    # the street carries on both ways: road, sidewalks
    road = mat("FarRoad", "#4c4f55")
    walk = mat("FarWalk", "#b9b6ae")
    for sx in (-1, 1):
        xa, xb = sx * street_from, sx * extent
        lo, hi = min(xa, xb), max(xa, xb)
        lib.box("Far_Road", (hi - lo, 8.0, 0.1), ((lo + hi) / 2, -36.5, road_top - 0.05), road)
        for y0, y1 in ((-32.5, -30.0), (-43.0, -40.5)):
            lib.box("Far_Walk", (hi - lo, y1 - y0, walk_top - road_top), ((lo + hi) / 2, (y0 + y1) / 2, (walk_top + road_top) / 2),
                    walk)
    if far_trees:
        _far_trees(extent, tree_fn, near=max(22.0, flat_to + 10.0))


def city_blocks(seed=5, inner=68.0, outer=150.0, keep_clear=()):
    """A city past the edge: blocks of offices and flats in rings round the square, low near it and taller
    further out, so every street ends in buildings instead of meadow. Flat live colours (they're far away and must
    stay out of the bake's atlas). keep_clear: (x0, x1, y0, y1) boxes to leave empty (a street's vista, say)."""
    rnd = random.Random(seed)
    colours = [("FarBlockA", "#a39b8f"), ("FarBlockB", "#8c8378"), ("FarBlockC", "#b7b0a5"), ("FarBlockD", "#7d7f84"),
               ("FarBlockE", "#9a6f5d")]
    mats = [mat(n, c) for n, c in colours]
    win = mat("FarWin", "#2c343c")
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
        z = 3.2
        while z < h - 1.5:                            # a ribbon of windows round every floor (one box each)
            lib.box(lib.uname("Far_BlockBand"), (w + 0.1, dp + 0.1, 1.3), (x, y, z), win)
            z += 3.4
        placed += 1


def industrial(seed=9):
    """An industrial district past the edge (the warehouse level): a corrugated steel fence round the square with
    gaps for the street, and beyond it sheds and warehouses, a container yard, a rail spur with boxcars, chimneys,
    tanks and a water tower. Flat live colours like city_blocks. Pair it with backdrop(flat_to=...) so the ground
    under it is level."""
    rnd = random.Random(seed)
    base = LAWN_Z - 0.2
    taken = []                                        # footprints (x0, x1, y0, y1), kept apart
    # one small palette (each material is a draw call for the whole backdrop)
    pal = {k: mat(n, c) for k, (n, c) in {
        "grey": ("FarShedA", "#9aa0a3"), "blue_grey": ("FarShedB", "#7c878a"), "sand": ("FarShedC", "#aaa293"),
        "brick": ("FarBrick", "#6e3b30"), "roof": ("FarRoof", "#55595c"), "dark": ("FarDark", "#2e2e30"),
        "blue": ("FarBoxB", "#2f5d8a"), "green": ("FarBoxC", "#3b7a4a"), "yellow": ("FarBoxD", "#c98f2b"),
        "white": ("FarTank", "#c9c7c0")}.items()}

    def free(x0, x1, y0, y1, gap=4.0):
        if x0 < EDGE + 3.0 and x1 > -EDGE - 3.0 and y0 < EDGE + 3.0 and y1 > -EDGE - 3.0:
            return False                              # inside the fence
        if y0 < -24.0 and y1 > -49.0 and (x0 < -EDGE or x1 > EDGE):
            return False                              # the street carrying on east and west
        return not any(x0 < b[1] + gap and x1 > b[0] - gap and y0 < b[3] + gap and y1 > b[2] - gap for b in taken)

    # the fence: corrugated sheets 2.4 m high round the square, open where the street runs through. It stands just
    # inside the playable ground with a collider, so it is the level's edge to ride into (it stood 1.5 m past the
    # ground's end, scenery only, and the edge warp put riders back before they ever reached it)
    fence = pal["blue_grey"]
    off = EDGE - 0.4
    runs = [((-off, off), (off, off)), ((off, -off), (-off, -off)),
            ((off, off), (off, -28.5)), ((off, -44.5), (off, -off)),
            ((-off, -off), (-off, -44.5)), ((-off, -28.5), (-off, off))]
    for a, b in runs:
        _corrugated(lib.uname("Far_Fence"), a, b, 2.4, fence)
        lib.col_box(lib.uname("FenceCol"), (max(abs(b[0] - a[0]), 0.3), max(abs(b[1] - a[1]), 0.3), 2.6),
                    ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, LAWN_Z + 1.3))
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        n = max(1, round(length / 2.4))
        ux, uy = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        ix, iy = (-0.12 if a[0] > 0 and a[0] == b[0] else 0.12 if a[0] == b[0] else 0.0,
                  -0.12 if a[1] > 0 and a[1] == b[1] else 0.12 if a[1] == b[1] else 0.0)   # on the inside
        for i in range(n + 1):
            t = length * i / n
            lib.box(lib.uname("Far_FencePost"), (0.1, 0.1, 2.7), (a[0] + ux * t + ix, a[1] + uy * t + iy, base + 1.35),
                    pal["dark"])
        mid = ((a[0] + b[0]) / 2 + ix, (a[1] + b[1]) / 2 + iy)
        rail = (abs(b[0] - a[0]) + 0.1, abs(b[1] - a[1]) + 0.1)
        for z in (0.5, 2.25):
            lib.box(lib.uname("Far_FenceRail"), (max(rail[0], 0.08), max(rail[1], 0.08), 0.08), (mid[0], mid[1], LAWN_Z + z),
                    pal["dark"])

    # the rail spur along the north side: ballast, rails, a few boxcars
    ry = EDGE + 10.0
    lib.box("Far_Ballast", (520.0, 3.4, 0.5), (0.0, ry, base + 0.25), pal["roof"])
    for dy in (-0.72, 0.72):
        lib.box(lib.uname("Far_Rail"), (520.0, 0.08, 0.14), (0.0, ry + dy, base + 0.57), pal["dark"])
    taken.append((-260.0, 260.0, ry - 2.5, ry + 2.5))
    cars = [pal["brick"], pal["blue_grey"], pal["blue"]]
    x = -150.0 + rnd.uniform(-10.0, 10.0)
    for k in range(9):
        if k in (3, 6):
            x += rnd.uniform(30.0, 60.0)             # gaps between strings of cars
        lib.box(lib.uname("Far_Boxcar"), (15.0, 3.0, 3.4), (x, ry, base + 0.5 + 1.0 + 1.7), cars[rnd.randrange(3)])
        lib.box(lib.uname("Far_Bogie"), (12.0, 2.2, 1.0), (x, ry, base + 1.0), pal["dark"])
        x += 16.0

    # the container yard, east past the fence
    boxes = [pal["brick"], pal["blue"], pal["green"], pal["yellow"], pal["grey"], pal["white"]]
    yx0, yy0 = EDGE + 16.0, -12.0
    for row in range(6):
        for col in range(5):
            if rnd.random() < 0.15:
                continue
            cx, cy = yx0 + row * 3.4, yy0 + col * 7.2
            for level in range(rnd.randint(1, 3)):
                lib.box(lib.uname("Far_Container"), (2.44, 6.06, 2.59), (cx, cy, base + 0.2 + 1.295 + level * 2.59),
                        boxes[rnd.randrange(len(boxes))])
    taken.append((yx0 - 2.0, yx0 + 6 * 3.4, yy0 - 4.0, yy0 + 5 * 7.2))
    # a gantry crane over the yard
    crane = pal["yellow"]
    for cx in (yx0 - 2.5, yx0 + 5 * 3.4 + 0.5):
        for cy in (yy0 + 4.0, yy0 + 28.0):
            lib.box(lib.uname("Far_Crane"), (0.8, 0.8, 16.0), (cx, cy, base + 8.0), crane)
        lib.box(lib.uname("Far_Crane"), (0.8, 25.0, 1.2), (cx, yy0 + 16.0, base + 16.0), crane)
    lib.box(lib.uname("Far_Crane"), (5 * 3.4 + 3.8, 1.4, 1.4), (yx0 + 7.0, yy0 + 16.0, base + 16.8), crane)

    # tanks and a water tower
    white = pal["white"]
    tx, ty = -EDGE - 30.0, 24.0
    for k, (dx, dy) in enumerate(((0.0, 0.0), (12.0, 0.0), (0.0, 12.0), (12.0, 12.0))):
        h = 8.0 + (k % 2) * 2.5
        lib.cyl_z(lib.uname("Far_Tank"), (tx + dx, ty + dy, base), h, 5.0, white, seg=20)
        lib.cyl_z(lib.uname("Far_TankTop"), (tx + dx, ty + dy, base + h), 1.0, 5.0, white, r1=1.2, seg=20)
    taken.append((tx - 6.0, tx + 18.0, ty - 6.0, ty + 18.0))
    wx, wy = EDGE + 24.0, EDGE + 26.0
    grey = pal["blue_grey"]
    for dx, dy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        lib.cyl_between(lib.uname("Far_TowerLeg"), (wx + dx * 3.0, wy + dy * 3.0, base), (wx + dx * 1.9, wy + dy * 1.9, base + 16.0),
                        0.18, grey, seg=6)
    lib.cyl_z(lib.uname("Far_TowerTank"), (wx, wy, base + 16.0), 5.0, 3.4, grey, seg=20)
    lib.cyl_z(lib.uname("Far_TowerTop"), (wx, wy, base + 21.0), 1.8, 3.6, grey, r1=0.2, seg=20)
    taken.append((wx - 4.0, wx + 4.0, wy - 4.0, wy + 4.0))

    # chimneys
    brick, dark = pal["brick"], pal["dark"]
    for cx, cy, h in ((-EDGE - 48.0, EDGE + 40.0, 38.0), (EDGE + 70.0, -EDGE - 30.0, 44.0), (-EDGE - 20.0, -EDGE - 60.0, 32.0)):
        lib.cyl_z(lib.uname("Far_Chimney"), (cx, cy, base), h, 1.7, brick, r1=1.2, seg=14)
        lib.cyl_z(lib.uname("Far_ChimneyBand"), (cx, cy, base + h - 2.4), 1.8, 1.35, dark, seg=14)
        taken.append((cx - 3.0, cx + 3.0, cy - 3.0, cy + 3.0))

    # sheds and warehouses: dense near the fence, thinning out; flat, pitched or saw-tooth roofs
    walls = [pal["grey"], pal["blue_grey"], pal["sand"], pal["brick"], pal["sand"], pal["grey"]]
    roof = pal["roof"]
    placed = 0
    for k in range(4000):
        if placed >= 75:
            break
        near_ring = placed < 35
        x = rnd.uniform(-EDGE - (40.0 if near_ring else 120.0), EDGE + (40.0 if near_ring else 120.0))
        y = rnd.uniform(-EDGE - (40.0 if near_ring else 120.0), EDGE + (40.0 if near_ring else 120.0))
        w, dp = rnd.uniform(16.0, 42.0), rnd.uniform(14.0, 30.0)
        if rnd.random() < 0.5:
            w, dp = dp, w
        x0, x1, y0, y1 = x - w / 2, x + w / 2, y - dp / 2, y + dp / 2
        if not free(x0, x1, y0, y1):
            continue
        d = max(abs(x), abs(y)) - EDGE
        h = rnd.uniform(6.0, 11.0) + max(d, 0.0) / 120.0 * rnd.uniform(0.0, 7.0)
        wall = walls[rnd.randrange(len(walls))]
        lib.box(lib.uname("Far_Shed"), (w, dp, h - base), (x, y, (h + base) / 2), wall)
        if d < 50.0:                                  # near ones get a window band all round and doors facing the fence
            zb = h - rnd.uniform(1.8, 2.6)
            for sx, sy, lx, ly in ((0, -1, w, 0), (0, 1, w, 0), (-1, 0, 0, dp), (1, 0, 0, dp)):
                lib.box(lib.uname("Far_ShedWin"), (max(lx * 0.8, 0.1), max(ly * 0.8, 0.1), 1.1),
                        (x + sx * (w / 2 + 0.03), y + sy * (dp / 2 + 0.03), zb), pal["dark"])
            if abs(x) > abs(y):
                fx, fy, run, horiz = x - math.copysign(w / 2 + 0.04, x), y, dp, False
            else:
                fx, fy, run, horiz = x, y - math.copysign(dp / 2 + 0.04, y), w, True
            for t in (-0.25, 0.25) if run > 20.0 else (0.0,):
                c = (fx + t * run, fy) if horiz else (fx, fy + t * run)
                lib.box(lib.uname("Far_ShedDoor"), (4.0 if horiz else 0.1, 0.1 if horiz else 4.0, 4.4), (c[0], c[1], LAWN_Z + 2.2),
                        pal["grey"] if wall is not pal["grey"] else pal["blue_grey"])
        kind = rnd.random()
        along_x = w >= dp
        if kind < 0.35:                               # flat roof with a parapet line
            lib.box(lib.uname("Far_ShedRoof"), (w + 0.3, dp + 0.3, 0.5), (x, y, h + 0.25), roof)
        elif kind < 0.7:                              # a low gable
            _gable(lib.uname("Far_ShedRoof"), x0, x1, y0, y1, h, rnd.uniform(1.5, 3.0), along_x, roof)
        else:                                         # saw-tooth: ridges across the long side
            n = max(3, int((w if along_x else dp) / 8.0))
            for i in range(n):
                if along_x:
                    a, b = x0 + (x1 - x0) * i / n, x0 + (x1 - x0) * (i + 1) / n
                    _gable(lib.uname("Far_ShedRoof"), a, b, y0, y1, h, 2.6, False, roof, saw=True)
                else:
                    a, b = y0 + (y1 - y0) * i / n, y0 + (y1 - y0) * (i + 1) / n
                    _gable(lib.uname("Far_ShedRoof"), x0, x1, a, b, h, 2.6, True, roof, saw=True)
        taken.append((x0, x1, y0, y1))
        placed += 1


def _corrugated(name, a, b, h, m, pitch=0.5, depth=0.1):
    """A corrugated sheet fence from a to b (x, y), faces toward the square's centre."""
    ax, ay = a
    bx, by = b
    length = math.hypot(bx - ax, by - ay)
    n = max(2, int(length / (pitch / 2)))
    ux, uy = (bx - ax) / length, (by - ay) / length
    nx, ny = -uy, ux                                  # the side normal
    if nx * -(ax + bx) + ny * -(ay + by) < 0.0:      # point it at the centre
        nx, ny = -nx, -ny
    z0, z1 = LAWN_Z - 0.2, LAWN_Z + h
    verts, faces = [], []
    for i in range(n + 1):
        t = length * i / n
        o = depth * (0.5 if i % 2 else -0.5)
        px, py = ax + ux * t + nx * o, ay + uy * t + ny * o
        verts += [(px, py, z0), (px, py, z1)]
    for i in range(n):
        q = (2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1)
        faces.append(q)
    ob = lib.mesh_obj(name, verts, faces, [m])            # flat shaded: the ribs read as light and dark stripes
    me = ob.data
    p = me.polygons[0]
    if p.normal.x * nx + p.normal.y * ny < 0.0:       # wound away from the square: flip
        for poly in me.polygons:
            poly.flip()
        me.update()
    return ob


def _gable(name, x0, x1, y0, y1, z, rise, along_x, m, saw=False):
    """A roof prism on the box (x0..x1, y0..y1) at height z: a gable with its ridge along x (or y), or with saw
    one steep glazed face and one long slope (a saw-tooth bay)."""
    if along_x:
        pts = [(y0, z), (y1, z), (y1 if saw else (y0 + y1) / 2, z + rise)]
        return prism(name, pts, x0, x1, [m] * 3, [0, 0, 0], [False] * 3, cap_mat=0)
    pts = [(x0, z), (x1, z), (x1 if saw else (x0 + x1) / 2, z + rise)]
    ob = prism(name, pts, -y1, -y0, [m] * 3, [0, 0, 0], [False] * 3, cap_mat=0)
    ob.rotation_euler = (0.0, 0.0, -math.pi / 2)
    return ob


def _far_trees(extent, tree_fn=None, near=22.0):
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
        if d < near or _in_street_band(y, 5.0):
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
