"""
Park dressing: crowd, plaza paint, gates, mural, street + cars, pond, playground, extras, backdrop.
`build(place)` is called at the end of park.build(). Everything is deterministic (seeded).

Placement is verified as it happens: `put()` builds the piece, takes its XY convex-hull footprint (fp.py) and rejects
it (deleting it again) if it touches the ring, a spoke, the plaza or any existing / previously placed piece. Trees and
bushes may be cleared out of zones flagged `clear=True` (the log lists how many).
"""

import math
import random

import bpy
from mathutils import Vector

import backdrop
import fp
import props
from lib import empty, mesh_obj, orient_up, uname
from pieces import M

Z0 = 0.06
PLAZA_X, PLAZA_Y = 20.0, 18.0
BOUND = 55.0
VEG = ("tree", "bush")
BACKDROP_IN_LEVEL = False      # the far backdrop is its own glb (build target "backdrop"): see build.py

BUILDERS = dict(
    bleachers=props.bleachers, bunting=props.bunting, balloons=props.balloons, mural_wall=props.mural_wall, pond=props.pond,
    swing_set=props.swing_set, slide=props.slide, sandbox=props.sandbox, seesaw=props.seesaw, climber=props.climber,
    play_pad=props.play_pad, street_lamp=props.street_lamp, hydrant=props.hydrant, mailbox=props.mailbox, bus_stop=props.bus_stop,
    car=props.car, sandwich_board=props.sandwich_board, bike_rack=props.bike_rack, bike=props.bike, hoop=props.hoop,
    umbrella=props.umbrella, picnic_blanket=props.picnic_blanket, food_cart=props.food_cart, kite=props.kite,
    flower_patch=props.flower_patch,
)

_place = None
OCC = []
LOG = {}
CNT = {}


def log(key, n=1):
    LOG[key] = LOG.get(key, 0) + n


def note(msg):
    LOG.setdefault("_notes", []).append(msg)


# --------------------------------------------------------------------------
# bookkeeping
# --------------------------------------------------------------------------

def remove_piece(root):
    for ob in fp.descendants(root):
        bpy.data.objects.remove(ob, do_unlink=True)
    bpy.data.objects.remove(root, do_unlink=True)


def drop(o, why="cleared"):
    if o in OCC:
        OCC.remove(o)
    log(f"removed_{o['kind']}")
    remove_piece(o["root"])


def put(piece, x, y, rot=0.0, z=0.0, clear=False, allow=(), air=False, flat=False, margin=0.3, **kw):
    """Place a piece and verify its footprint. Returns the root or None if it was rejected."""
    root = _place(piece, x, y, rot, z=z, **kw)
    root["dressing"] = 1
    root["air"] = 1 if air else 0
    root["flat"] = 1 if flat else 0
    hull = fp.piece_hull(root)
    if not (air or flat):
        bad = [w for w in fp.hits_paths(hull, 0.5) if w not in allow]
        conflicts = [o for o in OCC if fp.overlaps(hull, o["hull"], margin)]
        hard = [o for o in conflicts if o["kind"] not in VEG]
        soft = [o for o in conflicts if o["kind"] in VEG]
        if bad or hard or (soft and not clear):
            log(f"skipped_{piece}")
            note(f"skipped {piece} at ({x:.1f},{y:.1f}): paths={bad} hits={[o['root'].name for o in hard + soft][:3]}")
            remove_piece(root)
            return None
        for o in soft:
            drop(o)
    log(f"placed_{piece}")
    if not (air or flat):
        OCC.append(dict(root=root, kind=piece, hull=hull, new=True))
    return root


def try_put(piece, cands, **kw):
    for (x, y, r) in cands:
        root = put(piece, x, y, r, **kw)
        if root is not None:
            return root
    return None


def clear_rect(x0, y0, x1, y1):
    rect = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    for o in list(OCC):
        if o["kind"] in VEG and fp.overlaps(o["hull"], rect, 0.3):
            drop(o)


def point_ok(x, y, pad=0.5):
    for o in OCC:
        if o["kind"] in ("fence", "hedge") or o["kind"] in VEG:
            continue
        if fp.inside(o["hull"], x, y, pad):
            return False
    if fp.hits_paths([(x, y)] * 3, 0.0):
        return False
    return True


def marker(kind, x, y, z, rot, variant=None, size=0.25):
    CNT[kind] = CNT.get(kind, 0) + 1
    n = CNT[kind]
    name = f"{kind}_{variant}_{n}" if variant is not None else f"{kind}_{n}"
    return empty(name, (x, y, z), rot, size=size)


def face_rot(dx, dy):
    """rot_z that makes local +Y point along (dx, dy)."""
    return math.atan2(-dx, dy)


def world(root, p):
    return root.matrix_world @ Vector(p)


def load_occupancy():
    bpy.context.view_layer.update()
    for p in fp.pieces():
        OCC.append(dict(root=p, kind=fp.piece_kind(p), hull=fp.piece_hull(p, update=False), new=False))


# --------------------------------------------------------------------------
# 1. trees: more varieties
# --------------------------------------------------------------------------

def convert_trees():
    rnd = random.Random(31)
    varieties = [2, 3, 4, 5, 2, 5, 3, 4]
    n = 0
    for o in list(OCC):
        if o["kind"] != "tree" or rnd.random() > 0.5:
            continue
        r = o["root"]
        x, y = r.location.x, r.location.y
        v = rnd.choice(varieties)
        seed = rnd.randint(0, 999)
        s = rnd.uniform(0.9, 1.2)
        OCC.remove(o)
        remove_piece(r)
        nr = _place("tree", x, y, rnd.uniform(0, 360), z=0.0, variety=v, seed=seed, s=s)
        nr["dressing"] = 1
        nr["converted"] = 1
        OCC.append(dict(root=nr, kind="tree", hull=fp.piece_hull(nr), new=False))
        n += 1
    log("converted_trees", n)


# --------------------------------------------------------------------------
# 2. crowd
# --------------------------------------------------------------------------

def seat_people(stand, rows, w, rnd, fill=0.72, stand_frac=0.14):
    rz = stand.rotation_euler.z
    for (x, y, z, k) in props.bleacher_seats(rows, w):
        if rnd.random() > fill:
            continue
        p = world(stand, (x + rnd.uniform(-0.08, 0.08), y, z))
        v = rnd.randint(0, 3)
        if k >= 1 and rnd.random() < stand_frac:
            marker("Spectator", p.x, p.y, p.z, rz + rnd.uniform(-0.2, 0.2), v)
        else:
            marker("SpectatorSit", p.x, p.y, p.z, rz + rnd.uniform(-0.12, 0.12), v)


def crowd():
    rnd = random.Random(5)
    D, yf, yb = props.bleacher_geom(4, 8.0)
    A = put("bleachers", -21.3 - yf, 9.6, -90, clear=True, rows=4, w=8.0, panel=("Blue", "Orange"))
    D2, yf2, yb2 = props.bleacher_geom(3, 5.4)
    B = put("bleachers", -21.3 - yf2, -9.4, -90, clear=True, rows=3, w=5.4, panel=("Purple", "Teal"), rail="Orange")
    if A:
        seat_people(A, 4, 8.0, rnd)
    if B:
        seat_people(B, 3, 5.4, rnd, fill=0.8)
    # standing spectators along the outside of the plaza fence, facing the action
    for side in range(4):
        t = -19.0
        while t < 19.0:
            t += rnd.uniform(1.3, 2.4)
            if abs(t) < 3.7 or (side >= 2 and abs(t) > 17.2):
                continue
            x, y = ((t, 19.35), (t, -19.35), (21.35, t), (-21.35, t))[side]
            if side < 2 and abs(t) > 19.2:
                continue
            if rnd.random() < 0.5 or not point_ok(x, y):
                continue
            marker("Spectator", x, y, Z0, face_rot(-x * 0.5, -y * 0.5) + rnd.uniform(-0.35, 0.35), rnd.randint(0, 3))
    # a few sit on the ring benches (facing the way the bench faces)
    benches = [o for o in OCC if o["kind"] == "bench" and math.hypot(o["root"].location.x, o["root"].location.y) > 38]
    rnd.shuffle(benches)
    for o in benches[:6]:
        b = o["root"]
        for sx in rnd.sample((-0.45, 0.45), rnd.choice((1, 2))):
            p = world(b, (sx, 0.0, 0.54))
            marker("SpectatorSit", p.x, p.y, p.z, b.rotation_euler.z + rnd.uniform(-0.1, 0.1), rnd.randint(0, 3))
    # a person sitting on a ramp deck, legs over the lip (as in the reference art)
    decks = []
    for o in OCC:
        if o["kind"] == "mini_ramp":
            decks += [(o["root"], (-1.0, 2.5 + 2.53 + 0.4, 1.75), math.pi), (o["root"], (1.0, -2.5 - 2.53 - 0.4, 1.75), 0.0)]
        if o["kind"] == "quarter_pipe":
            R, H, W = (3.4, 2.6, 7.0) if o["root"].location.x < -8 else (2.4, 1.4, 5.0)
            yt = R * math.sin(math.acos(1 - H / R))
            decks.append((o["root"], (-W * 0.15, yt + 0.4, H), math.pi))
    for (r, p, rr) in decks:
        w = world(r, p)
        marker("SpectatorSit", w.x, w.y, w.z, r.rotation_euler.z + rr, rnd.randint(0, 3))
    # shop customers
    kiosk = [o for o in OCC if o["kind"] == "kiosk"]
    if kiosk:
        k = kiosk[0]["root"]
        for sx in (-1.6, 0.4, 2.2):
            p = world(k, (sx, 4.6 + rnd.uniform(0, 0.6), 0))
            marker("Spectator", p.x, p.y, 0.06, k.rotation_euler.z + math.pi + rnd.uniform(-0.4, 0.4), rnd.randint(0, 3))
    # perches for the birds: lamp heads, fence rails, stand rails
    lamps = [o["root"] for o in OCC if o["kind"] == "lamp"]
    rnd.shuffle(lamps)
    for l in lamps[:6]:
        p = world(l, (0.85, 0, 4.25))
        marker("Bird", p.x, p.y, p.z, rnd.uniform(0, 6.28))
    for (x, y) in ((-12, 20.3), (5, -20.2), (21.3, -6), (-21.3, 16), (12, 20.3), (-4, -20.2)):
        marker("Bird", x, y, Z0 + 1.75, rnd.uniform(0, 6.28))


# --------------------------------------------------------------------------
# 3. plaza paint (flat quads, batched per material)
# --------------------------------------------------------------------------

class Paint:
    def __init__(self):
        self.d = {}
        self.count = 0

    def add(self, mat, pts, z):
        self.d.setdefault(mat, []).append([(x, y, z) for (x, y) in pts])
        self.count += 1

    def flush(self):
        for mat, polys in self.d.items():
            verts, faces = [], []
            for p in polys:
                b = len(verts)
                verts += p
                faces.append(tuple(range(b, b + len(p))))
            ob = mesh_obj(uname("PaintDecals_" + mat.split("_")[1]), verts, faces, [M(mat)])
            orient_up(ob.data)
            for pg in ob.data.polygons:      # every face up (orient_up only checks the first)
                if pg.normal.z < 0:
                    pg.flip()
            ob.data.update()


FONT = {
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
}


def rect(cx, cy, w, h, rot=0.0):
    c, s = math.cos(rot), math.sin(rot)
    return [(cx + c * x - s * y, cy + s * x + c * y) for x, y in ((-w / 2, -h / 2), (w / 2, -h / 2), (w / 2, h / 2), (-w / 2, h / 2))]


def plaza_paint():
    P = Paint()
    L1, L2 = Z0 + 0.006, Z0 + 0.012
    obs = []
    for o in OCC:
        if o["kind"] in ("fence", "banner") or o["kind"] in VEG:
            continue
        x0, y0, x1, y1 = fp.bbox(o["hull"])
        if abs((x0 + x1) / 2) < PLAZA_X and abs((y0 + y1) / 2) < PLAZA_Y:
            obs.append((o, (x0, y0, x1, y1)))

    def blocked(pts, skip=None, pad=0.35):
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        for o, (x0, y0, x1, y1) in obs:
            if o is skip:
                continue
            for (x, y) in list(pts) + [(cx, cy)]:
                if x0 - pad <= x <= x1 + pad and y0 - pad <= y <= y1 + pad:
                    return True
        return False

    def add(mat, pts, z, skip=None):
        if not blocked(pts, skip):
            P.add(mat, pts, z)

    def arc_ring(cx, cy, r0, r1, n, mat, z, cols=None, a0=0.0, a1=2 * math.pi):
        for i in range(n):
            t0 = a0 + (a1 - a0) * i / n
            t1 = a0 + (a1 - a0) * (i + 1) / n
            pts = [(cx + r0 * math.cos(t0), cy + r0 * math.sin(t0)), (cx + r1 * math.cos(t0), cy + r1 * math.sin(t0)),
                   (cx + r1 * math.cos(t1), cy + r1 * math.sin(t1)), (cx + r0 * math.cos(t1), cy + r0 * math.sin(t1))]
            add(cols[i % len(cols)] if cols else mat, pts, z)

    # --- central ring + starburst
    cx, cy = -0.6, 0.8
    arc_ring(cx, cy, 2.55, 3.15, 40, None, L1, cols=["Paint_Red"])
    arc_ring(cx, cy, 2.0, 2.2, 32, None, L2, cols=["Paint_Yellow", "Paint_White"])
    for i in range(16):
        t0, t1 = 2 * math.pi * i / 16, 2 * math.pi * (i + 1) / 16
        tm = (t0 + t1) / 2
        rr = 1.75 if i % 2 == 0 else 1.2
        add(["Paint_Blue", "Paint_Teal"][i % 2], [(cx, cy), (cx + rr * math.cos(t0), cy + rr * math.sin(t0)),
                                                  (cx + rr * math.cos(t1), cy + rr * math.sin(t1))], L1)
    for i in range(8):
        t0 = 2 * math.pi * i / 8 + math.pi / 8
        add("Paint_White", [(cx, cy), (cx + 0.9 * math.cos(t0 - 0.16), cy + 0.9 * math.sin(t0 - 0.16)),
                            (cx + 0.9 * math.cos(t0 + 0.16), cy + 0.9 * math.sin(t0 + 0.16))], L2)
    # --- giant SKATE (block letters) with a dark drop shadow
    cell, x0, y0 = 0.42, -2.6, 12.2
    for li, ch in enumerate("SKATE"):
        lx = x0 + li * (5 * cell + 0.5)
        col = ["Paint_Red", "Paint_Yellow", "Paint_Teal", "Paint_Orange", "Paint_Pink"][li]
        for r, row in enumerate(FONT[ch]):
            c = 0
            while c < 5:
                if row[c] == "#":
                    c2 = c
                    while c2 + 1 < 5 and row[c2 + 1] == "#":
                        c2 += 1
                    w = (c2 - c + 1) * cell
                    ccx = lx + c * cell + w / 2
                    ccy = y0 + (6 - r) * cell + cell / 2
                    add("Paint_Ink", rect(ccx + 0.1, ccy - 0.1, w, cell), L1)
                    add(col, rect(ccx, ccy, w - 0.02, cell - 0.02), L2)
                    c = c2 + 1
                else:
                    c += 1
    # --- checker strips along the north and south edges
    for ys in (17.1, -17.1):
        for j, xx in enumerate(range(-38, 38)):
            x = xx * 0.5 + 0.25
            for row in range(2):
                y = ys + (row - 0.5) * 0.5
                m = "Paint_Ink" if (j + row) % 2 == 0 else "Paint_White"
                add(m, rect(x, y, 0.5, 0.5), L1)
    # --- coloured block borders along the east / west edges
    for sx in (-1, 1):
        for k in range(-20, 21):
            y = k * 0.8
            add(["Paint_Pink", "Paint_Teal", "Paint_Yellow", "Paint_Purple"][k % 4], rect(sx * 19.6, y, 0.6, 0.6), L1)
    # --- dashed outlines around the big obstacles
    for o, (x0_, y0_, x1_, y1_) in obs:
        if o["kind"] not in ("mini_ramp", "quarter_pipe", "funbox", "pyramid", "stair_set", "hip"):
            continue
        pad = 0.7
        xa, ya, xb, yb = x0_ - pad, y0_ - pad, x1_ + pad, y1_ + pad
        for (ax, ay, bx, by) in ((xa, ya, xb, ya), (xb, ya, xb, yb), (xb, yb, xa, yb), (xa, yb, xa, ya)):
            Ln = math.hypot(bx - ax, by - ay)
            ux, uy = (bx - ax) / Ln, (by - ay) / Ln
            t = 0.0
            while t + 0.8 <= Ln:
                mx, my = ax + ux * (t + 0.4), ay + uy * (t + 0.4)
                ang = math.atan2(uy, ux)
                add("Paint_Yellow", rect(mx, my, 0.8, 0.16, ang), L1, skip=o)
                t += 1.4
    # --- chevrons: south lane (east) and into each gate (Paint_Yellow, on the spoke paths)

    def chevron(cx_, cy_, heading, sc, mat, z, skip_blocked=True):
        a = heading - math.pi / 2
        c, s = math.cos(a), math.sin(a)

        def T(pts):
            return [(cx_ + (c * x - s * y) * sc, cy_ + (s * x + c * y) * sc) for x, y in pts]
        for arm in ([(-1.2, -0.5), (-1.2, 0.0), (0.0, 1.0), (0.0, 0.5)], [(0.0, 0.5), (0.0, 1.0), (1.2, 0.0), (1.2, -0.5)]):
            if skip_blocked:
                add(mat, T(arm), z)
            else:
                P.add(mat, T(arm), z)

    for x in (-5.5, -3.0, -0.5, 2.0, 4.5, 7.0, 9.5, 12.0):
        chevron(x, -15.2, 0.0, 1.0, "Paint_Teal", L1)
    for (gx, gy, hd) in ((0, 1, -math.pi / 2), (0, -1, math.pi / 2), (1, 0, math.pi), (-1, 0, 0.0)):
        for k, dist in enumerate((23.4, 25.0, 26.6)):
            chevron(gx * dist, gy * dist, hd, 0.95, "Paint_Yellow", L1, skip_blocked=False)
        for k, c in enumerate(("Paint_Red", "Paint_Yellow", "Paint_Blue")):
            d = 19.4 + 0.5 * k if gx == 0 else 21.4 + 0.5 * k
            if gx == 0:
                P.add(c, rect(0, gy * d, 4.2, 0.34), L1)
            else:
                P.add(c, rect(gx * d, 0, 0.34, 4.2), L1)
    P.flush()
    log("paint_polys", P.count)


# --------------------------------------------------------------------------
# 4. gates: bunting, balloons; mural wall
# --------------------------------------------------------------------------

def gates_and_mural():
    gap = 2.3 + 0.4
    fx, fy = PLAZA_X + 0.25, PLAZA_Y + 0.25
    put("bunting", 0, fy, 0, z=Z0, air=True, L=2 * gap, h=2.26, sag=0.28, phase=0)
    put("bunting", 0, -fy, 0, z=Z0, air=True, L=2 * gap, h=2.26, sag=0.28, phase=3)
    put("bunting", fx, 0, 90, z=Z0, air=True, L=2 * gap, h=2.26, sag=0.28, phase=1)
    put("bunting", -fx, 0, 90, z=Z0, air=True, L=2 * gap, h=2.26, sag=0.28, phase=5)
    seed = 0
    for (x, y) in ((3.7, fy + 0.6), (-3.7, fy + 0.6), (3.7, -fy - 0.6), (-3.7, -fy - 0.6), (fx + 0.6, 3.7), (fx + 0.6, -3.7),
                   (-fx - 0.6, 3.7), (-fx - 0.6, -3.7)):
        seed += 1
        put("balloons", x, y, 0, z=Z0, air=True, n=6, seed=seed)
    put("mural_wall", -11.6, 22.6, 180, clear=True, L=15.0, h=2.2, seed=2)
    put("mural_wall", 11.6, 22.6, 180, clear=True, L=15.0, h=2.2, seed=7)


# --------------------------------------------------------------------------
# 5. street: lamps, hydrants, mailboxes, bus stops, cars, routes
# --------------------------------------------------------------------------

ROAD_DIR = (90, 180, -90, 0)      # north, west, south, east: rot that points local +X toward the road
FACE_ROAD = (0, 90, 180, -90)     # rot that points local +Y toward the road
INNER_TRAVEL = (-90, 0, 90, 180)  # clockwise traffic (inner lane), rot per side N, W, S, E
OUTER_TRAVEL = (90, 180, -90, 0)  # counter-clockwise traffic (outer lane)


def side_xy(side, along, dist):
    return ((along, dist), (-dist, along), (along, -dist), (dist, along))[side]


def street():
    rnd = random.Random(44)
    walk = 0.1
    for side in range(4):
        for along in (-50, -30, -10, 10, 30, 50):
            x, y = side_xy(side, along, 58.0)
            put("street_lamp", x, y, ROAD_DIR[side], z=walk)
        for along in (rnd.uniform(-45, -33), rnd.uniform(33, 45)):
            x, y = side_xy(side, along, 58.3)
            put("hydrant", x, y, rnd.uniform(0, 360), z=walk)
        for along in (rnd.uniform(-22, -14), rnd.uniform(16, 24)):
            x, y = side_xy(side, along, 58.3)
            put("mailbox", x, y, FACE_ROAD[side], z=walk, color=rnd.choice(["Blue", "Red", "Green"]))
        x, y = side_xy(side, (-24 if side % 2 == 0 else 24), 57.4)
        put("bus_stop", x, y, FACE_ROAD[side], z=walk)
    cols = ["CarBody", "CarBlue", "CarYellow", "CarTeal", "CarWhite", "CarOrange", "CarGreen", "CarPurple", "CarPink"]
    vars_ = ["hatch", "van", "pickup", "hatch", "hatch"]
    for side in range(4):
        for lane, (dist, rots, count) in enumerate(((60.1, INNER_TRAVEL, 2), (67.9, OUTER_TRAVEL, 1))):
            spots = []
            tries = 0
            while len(spots) < count and tries < 40:
                tries += 1
                a = rnd.uniform(-46, 46)
                if all(abs(a - b) > 9 for b in spots):
                    spots.append(a)
            for a in spots:
                x, y = side_xy(side, a, dist)
                put("car", x, y, rots[side] + rnd.choice([0, 0, 0, 180]) * 0, z=Z0, variant=rnd.choice(vars_), color=rnd.choice(cols))
    routes()


def routes():
    """Two closed loops on the road ring: A clockwise on the inner lane, B counter-clockwise on the outer lane."""
    Rc = 6.0
    for name, c, ccw in (("A", 62.6, False), ("B", 65.4, True)):
        pts = []
        corners = ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270))
        for k, (sx, sy, a0) in enumerate(corners):
            ox, oy = sx * (c - Rc), sy * (c - Rc)
            for j in range(4):
                a = math.radians(a0 + j * 30)
                pts.append((ox + Rc * math.cos(a), oy + Rc * math.sin(a)))
            # straight to the next corner
            nsx, nsy, na0 = corners[(k + 1) % 4]
            p_end = (ox + Rc * math.cos(math.radians(a0 + 90)), oy + Rc * math.sin(math.radians(a0 + 90)))
            p_next = (nsx * (c - Rc) + Rc * math.cos(math.radians(na0)), nsy * (c - Rc) + Rc * math.sin(math.radians(na0)))
            L = math.hypot(p_next[0] - p_end[0], p_next[1] - p_end[1])
            nseg = int(L // 24)
            for i in range(1, nseg + 1):
                t = i / (nseg + 1)
                pts.append((p_end[0] + (p_next[0] - p_end[0]) * t, p_end[1] + (p_next[1] - p_end[1]) * t))
        if not ccw:
            pts = pts[::-1]
        n = len(pts)
        for i, (x, y) in enumerate(pts):
            nx, ny = pts[(i + 1) % n]
            empty(f"CarRoute_{name}_{i:02d}", (x, y, Z0), face_rot(nx - x, ny - y), size=0.5)
        log(f"route_{name}_points", n)


def driveway_trees():
    rnd = random.Random(61)
    houses = [o for o in OCC if o["kind"] == "house"]
    rnd.shuffle(houses)
    k = 0
    for o in houses:
        if k >= 14:
            break
        h = o["root"]
        rz = h.rotation_euler.z
        f = (-math.sin(rz), math.cos(rz))
        lat = (math.cos(rz), math.sin(rz))
        x0, y0, x1, y1 = fp.bbox(o["hull"])
        ext = max(abs(x1 - x0), abs(y1 - y0)) / 2
        for off in (ext + 2.6, -(ext + 2.6)):
            if k >= 14:
                break
            fx = h.location.x + f[0] * (4.2 + rnd.uniform(0, 1.5)) + lat[0] * off
            fy = h.location.y + f[1] * (4.2 + rnd.uniform(0, 1.5)) + lat[1] * off
            if put("tree", fx, fy, rnd.uniform(0, 360), z=0.0, variety=rnd.choice([2, 3, 4, 5, 2, 3]), seed=k, s=rnd.uniform(0.9, 1.15)):
                k += 1
    log("driveway_trees", k)


# --------------------------------------------------------------------------
# 6. pond and 7. playground
# --------------------------------------------------------------------------

def pond_area():
    rnd = random.Random(12)
    cx, cy = -47.0, -19.0
    r = 4.6
    clear_rect(cx - 8, cy - 8, cx + 8, cy + 8)
    p = put("pond", cx, cy, 0, clear=True, r=r, seed=3, jetty_deg=-30.0)
    if not p:
        note("POND REJECTED")
        return
    for i, (ang, d) in enumerate(((110, 0.35), (175, 0.55), (255, 0.3))):
        a = math.radians(ang)
        x, y = cx + math.cos(a) * r * d, cy + math.sin(a) * r * d
        marker("Duck", x, y, props.WATER_Z, rnd.uniform(0, 6.28), None, size=0.3)
    # a bench and a sitter at the pond
    b = put("bench", cx + 7.6, cy + 3.5, 90, z=0.0, clear=True, grindable=False)
    if b:
        p3 = world(b, (0.0, 0.0, 0.54))
        marker("SpectatorSit", p3.x, p3.y, p3.z, b.rotation_euler.z, rnd.randint(0, 3))
    for k in range(2):
        try_put("flower_patch", [(cx + 7.5 + rnd.uniform(-1, 1), cy - 5 - k * 3.0 + rnd.uniform(-1, 1), 0)], z=0.0, r=1.5, seed=k)


def playground():
    cx, cy = 43.0, 42.0
    W, D = 14.0, 10.0
    clear_rect(cx - W / 2 - 1, cy - D / 2 - 1, cx + W / 2 + 1, cy + D / 2 + 1)
    put("play_pad", cx, cy, 0, flat=True, w=W, d=D)
    put("swing_set", cx - 3.4, cy + 2.6, 0, clear=True, n=3, first_swing=1)
    put("slide", cx + 4.6, cy - 1.2, 0, clear=True)
    put("sandbox", cx - 3.8, cy - 2.6, 0, clear=True, s=2.6)
    put("seesaw", cx + 0.6, cy - 3.6, 90, clear=True)
    put("climber", cx + 1.3, cy + 2.3, 0, clear=True, s=2.4)
    b = put("bench", cx, cy - D / 2 - 1.1, 0, z=0.0, clear=True, grindable=False)
    if b:
        rnd = random.Random(3)
        for sx in (-0.45, 0.45):
            p = world(b, (sx, 0, 0.54))
            marker("SpectatorSit", p.x, p.y, p.z, b.rotation_euler.z, rnd.randint(0, 3))
    put("bin", cx + W / 2 + 1.0, cy - D / 2, 0, z=0.0, clear=True)
    put("tree", cx - W / 2 - 2.6, cy + 1.0, 0, z=0.0, clear=True, variety=3, seed=8, s=1.1)
    put("tree", cx + W / 2 + 2.6, cy + 3.5, 0, z=0.0, clear=True, variety=2, seed=9, s=1.1)


# --------------------------------------------------------------------------
# 8. extras
# --------------------------------------------------------------------------

def extras():
    rnd = random.Random(77)
    kiosk = [o for o in OCC if o["kind"] == "kiosk"]
    if kiosk:
        k = kiosk[0]["root"]
        rz = k.rotation_euler.z
        f, lat = (-math.sin(rz), math.cos(rz)), (math.cos(rz), math.sin(rz))
        for (a, b, rr) in ((5.8, -3.6, 25), (5.8, 3.6, -25)):
            put("sandwich_board", k.location.x + f[0] * a + lat[0] * b, k.location.y + f[1] * a + lat[1] * b, math.degrees(rz) + rr,
                z=0.0, clear=True, color=rnd.choice(["Orange", "Pink", "Teal"]))
        put("bike_rack", k.location.x + f[0] * 4.4 + lat[0] * 6.4, k.location.y + f[1] * 4.4 + lat[1] * 6.4, math.degrees(rz), z=0.0,
            clear=True, n=4)
        put("balloons", k.location.x + f[0] * 4.5 + lat[0] * 2.6, k.location.y + f[1] * 4.5 + lat[1] * 2.6, 0, z=0.0, air=True, n=5,
            seed=91)
    # food cart + umbrella on the north-east lawn, basketball hoop out west
    try_put("food_cart", [(24 + dx, 36 + dy, -30) for dx, dy in ((0, 0), (2, 1), (-2, 2), (4, -2))], z=0.0, clear=True, color="Orange")
    try_put("hoop", [(-46, 30, 0), (-45, 40, 0), (-47, 22, 0)], z=0.0, clear=True)
    try_put("hoop", [(46, -26, 180), (47, -34, 180)], z=0.0, clear=True)
    # picnic blankets + umbrellas on the outer lawn
    for i, (ang, r) in enumerate(((20, 46), (75, 47), (160, 44), (250, 46), (300, 46), (335, 45))):
        cands = [(r * math.cos(math.radians(ang + d)), r * math.sin(math.radians(ang + d)), rnd.uniform(0, 360)) for d in (0, 6, -6, 12, -12)]
        try_put("picnic_blanket", cands, z=0.0, clear=False, color=["Red", "Blue", "Orange", "Purple", "Teal", "Pink"][i])
    # flower patches on the free wedges between plaza and ring, and on the outer lawn
    n = 0
    tries = 0
    while n < 14 and tries < 120:
        tries += 1
        a = rnd.uniform(0, 360)
        r = rnd.choice([rnd.uniform(24.5, 31), rnd.uniform(42, 52)])
        x, y = r * math.cos(math.radians(a)), r * math.sin(math.radians(a))
        if abs(x) > 52 or abs(y) > 52:
            continue
        if put("flower_patch", x, y, 0, z=0.0, r=rnd.uniform(1.0, 1.7), seed=n):
            n += 1
    # bikes leaning on the plaza fence (outside), kites over the outer lawn
    for (x, y, r) in ((21.25, -5.6, 0), (-6.0, -19.5, 90)):
        put("bike", x, y, r, z=0.0, color=rnd.choice(["Red", "Blue", "Green"]))
    for i, (x, y, z, c1, c2) in enumerate(((-40, 14, 9.0, "Red", "Yellow"), (14, -46, 11.5, "Blue", "Orange"),
                                            (47, 12, 8.5, "Purple", "Yellow"), (-12, 47, 12.0, "Pink", "Teal"))):
        root = put("kite", x, y, rnd.uniform(0, 360), z=z, air=True, color=c1, color2=c2)
        if root:
            root.rotation_euler.x = math.radians(50)


# --------------------------------------------------------------------------
# merge the many little visual boxes of a piece into one mesh per material (keeps the level glb small)
# --------------------------------------------------------------------------



def merge_visuals(root):
    """Join the visual meshes of a piece root into one object per material. Collision proxies (-col / -colonly),
    Water_*, and anything under a Swing_ pivot stay as they are so Godot's naming conventions still work."""
    inv = root.matrix_world.inverted()
    groups, victims = {}, []
    for ob in fp.descendants(root):
        if ob.type != "MESH" or "-col" in ob.name or ob.name.startswith("Water_"):
            continue
        a, skip = ob.parent, False
        while a is not None and a is not root:
            if a.name.startswith("Swing_"):
                skip = True
                break
            a = a.parent
        if skip:
            continue
        m = inv @ ob.matrix_world
        me = ob.data
        mats = list(me.materials)
        vmaps = {}
        for p in me.polygons:
            mt = mats[p.material_index] if p.material_index < len(mats) else None
            if mt is None:
                continue
            g = groups.setdefault(mt, dict(v=[], f=[], s=[]))
            vm = vmaps.setdefault(mt, {})
            idx = []
            for vi in p.vertices:
                if vi not in vm:
                    vm[vi] = len(g["v"])
                    g["v"].append(tuple(m @ me.vertices[vi].co))
                idx.append(vm[vi])
            g["f"].append(tuple(idx))
            g["s"].append(p.use_smooth)
        victims.append(ob)
    if len(victims) < 3:
        return 0
    for mt, g in groups.items():
        me = bpy.data.meshes.new(mt.name)
        me.from_pydata(g["v"], [], g["f"])
        me.update()
        me.materials.append(mt)
        for p, sm in zip(me.polygons, g["s"]):
            p.use_smooth = sm
        ob = bpy.data.objects.new(uname("Merged_" + mt.name), me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = root
    for ob in victims:
        bpy.data.objects.remove(ob, do_unlink=True)
    return len(victims)


def merge_all():
    bpy.context.view_layer.update()
    n = 0
    for p in fp.pieces():
        n += merge_visuals(p)
    log("merged_objects", n)


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def build(place):
    global _place
    import park
    park.BUILDERS.update(BUILDERS)
    _place = place
    OCC.clear()
    LOG.clear()
    CNT.clear()
    load_occupancy()
    convert_trees()
    crowd()
    plaza_paint()
    gates_and_mural()
    street()
    driveway_trees()
    pond_area()
    playground()
    extras()
    if BACKDROP_IN_LEVEL:
        backdrop.build()
    merge_all()
    print("[dressing]", {k: v for k, v in sorted(LOG.items()) if not k.startswith("_")})
    print("[dressing] markers", dict(CNT))
    for m in LOG.get("_notes", []):
        print("[dressing] note:", m)


# --------------------------------------------------------------------------
# previews (blender/preview.py)
# --------------------------------------------------------------------------

PREVIEWS = {
    "bleachers": ("bleachers", dict(rows=4, w=8.0), -90),
    "bleachers_small": ("bleachers", dict(rows=3, w=5.4, panel=("Purple", "Teal"), rail="Orange"), -90),
    "mural_wall": ("mural_wall", dict(L=15.0, seed=2), -70),
    "bunting": ("bunting", dict(L=5.4), -70),
    "balloons": ("balloons", dict(n=6, seed=2), -70),
    "pond": ("pond", dict(r=4.6, seed=3, jetty_deg=-30.0), 0),
    "swing_set": ("swing_set", dict(), -70),
    "slide": ("slide", dict(), -70),
    "sandbox": ("sandbox", dict(), -70),
    "seesaw": ("seesaw", dict(), -70),
    "climber": ("climber", dict(), -70),
    "street_lamp": ("street_lamp", dict(), -70),
    "hydrant": ("hydrant", dict(), -70),
    "mailbox": ("mailbox", dict(), -70),
    "bus_stop": ("bus_stop", dict(), -70),
    "sandwich_board": ("sandwich_board", dict(), -70),
    "bike_rack": ("bike_rack", dict(), -70),
    "hoop": ("hoop", dict(), -70),
    "picnic_blanket": ("picnic_blanket", dict(), -70),
    "food_cart": ("food_cart", dict(), -70),
    "kite": ("kite", dict(), -70),
    "flower_patch": ("flower_patch", dict(), -70),
    "house_a": ("house", dict(seed=3, chimney=True, garage=True, porch=True, frames=True, shutters=True, picket=True), -70),
    "house_b": ("house", dict(seed=8, wall="Pink", roof="RoofB"), -70),
    "trees": ("tree", dict(), 0),
}
VIEWS = dict(overview=(0, 0, 0, 150), plaza=(0, 0, 0, 58), stands=(-22, 0, 1.5, 26), playground=(43, 42, 1, 24),
             pondview=(-47, -19, 0, 22), north=(0, 22, 1, 44), street=(30, 62, 0, 44), houses=(60, -70, 2, 40),
             backdrop=(0, 0, 20, 330))
PREVIEW_OPTS = {k: dict(center=(v[0], v[1], v[2]), scale=v[3]) for k, v in VIEWS.items()}


def _stand_in_people():
    """Preview only: drop a posed stand-in person on every Spectator marker (Godot does the real thing)."""
    from spectator import build_person
    for ob in [o for o in bpy.data.objects if o.name.startswith("Spectator")]:
        seated = ob.name.startswith("SpectatorSit")
        p = build_person()
        p.parent = ob
        p.location = (0, 0, -0.58 + 0.06) if seated else (0, 0, 0)
        if seated:
            body = [c for c in p.children if c.name.startswith("Body")][0]
            for leg in [c for c in body.children if c.name.startswith("Leg")]:
                leg.rotation_euler.x = math.radians(90)
                for shin in leg.children:
                    if shin.name.startswith("Shin"):
                        shin.rotation_euler.x = math.radians(-90)
    # rename clash-safe: Blender suffixes .001 on duplicates, which is fine for a preview


def preview(name):
    """Scene for one preview render (see preview.py)."""
    from car import build_car
    from duck import build_duck
    from spectator import build_person
    import park
    if name == "spectator":
        build_person().rotation_euler.z = math.radians(-135)
    elif name == "duck":
        build_duck().rotation_euler.z = math.radians(-135)
    elif name.startswith("car_"):
        build_car(name[4:]).rotation_euler.z = math.radians(-125)
    elif name in VIEWS:
        park.build()
        if name == "backdrop":
            backdrop.build()
        _stand_in_people()
    elif name in PREVIEWS:
        park.BUILDERS.update(BUILDERS)
        piece, kw, rot = PREVIEWS[name]
        if name == "trees":
            for i, v in enumerate((0, 1, 2, 3, 4, 5)):
                root = empty(uname("Piece_tree"), (i * 5.0, 0, 0), 0)
                park.BUILDERS["tree"](root, variety=v, seed=i)
            return
        root = empty(uname("Piece_" + piece), (0, 0, 0), math.radians(rot))
        park.BUILDERS[piece](root, **kw)
        if name.startswith("bleachers"):
            rnd = random.Random(5)
            CNT.clear()
            bpy.context.view_layer.update()
            seat_people(root, kw["rows"], kw["w"], rnd)
            _stand_in_people()
    else:
        raise KeyError(name)
