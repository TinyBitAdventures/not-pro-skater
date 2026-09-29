"""
Footprint helpers (XY convex hulls of Piece roots) shared by dressing.py (placement) and check.py (proof).

A footprint is the convex hull of the world-space XY of every mesh vertex under a root (collision proxies
included), so it is conservative for L-shaped pieces and exact for boxes.
"""

import math

import bpy

RING_IN, RING_OUT = 32.8, 39.2      # ring path incl. its sloped curb
SPOKE_HALF = 2.46                   # 4.6 m spoke + curb slope
PLAZA_X, PLAZA_Y = 20.3, 18.3


def descendants(root):
    out, stack = [], list(root.children)
    while stack:
        o = stack.pop()
        out.append(o)
        stack.extend(o.children)
    return out


def hull(pts):
    pts = sorted(set((round(x, 4), round(y, 4)) for x, y in pts))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lo, up = [], []
    for p in pts:
        while len(lo) >= 2 and cross(lo[-2], lo[-1], p) <= 0:
            lo.pop()
        lo.append(p)
    for p in reversed(pts):
        while len(up) >= 2 and cross(up[-2], up[-1], p) <= 0:
            up.pop()
        up.append(p)
    return lo[:-1] + up[:-1]


def world_pts(root, only_names=None, update=True):
    if update:
        bpy.context.view_layer.update()
    pts = []
    for ob in [root] + descendants(root):
        if ob.type != "MESH":
            continue
        if only_names and not any(s in ob.name for s in only_names):
            continue
        mw = ob.matrix_world
        for v in ob.data.vertices:
            w = mw @ v.co
            pts.append((w.x, w.y))
    return pts


def piece_hull(root, only_names=None, update=True):
    return hull(world_pts(root, only_names, update))


def piece_kind(ob):
    return ob.name.rsplit("_", 1)[0][len("Piece_"):]


def pieces():
    return [o for o in bpy.data.objects if o.name.startswith("Piece_") and o.parent is None]


def bbox(poly):
    xs = [p[0] for p in poly]
    ys = [p[1] for p in poly]
    return min(xs), min(ys), max(xs), max(ys)


def _proj(poly, ax):
    d = [p[0] * ax[0] + p[1] * ax[1] for p in poly]
    return min(d), max(d)


def gap(a, b):
    """Smallest separation along any edge normal of two convex polygons (negative = overlap depth).
    For convex polygons max(gap along all edge normals) is the true separating distance lower bound."""
    best = -1e9
    for poly in (a, b):
        n = len(poly)
        for i in range(n):
            x0, y0 = poly[i]
            x1, y1 = poly[(i + 1) % n]
            ax = (y1 - y0, -(x1 - x0))
            L = math.hypot(*ax)
            if L < 1e-9:
                continue
            ax = (ax[0] / L, ax[1] / L)
            a0, a1 = _proj(a, ax)
            b0, b1 = _proj(b, ax)
            g = max(b0 - a1, a0 - b1)
            best = max(best, g)
    return best


def overlaps(a, b, margin=0.0):
    if len(a) < 3 or len(b) < 3:
        return False
    ab, bb = bbox(a), bbox(b)
    if ab[0] > bb[2] + margin or bb[0] > ab[2] + margin or ab[1] > bb[3] + margin or bb[1] > ab[3] + margin:
        return False
    return gap(a, b) < margin


def inside(poly, x, y, pad=0.0):
    n = len(poly)
    if n < 3:
        return False
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if (x1 - x0) * (y - y0) - (y1 - y0) * (x - x0) < -pad * math.hypot(x1 - x0, y1 - y0):
            return False
    return True


def samples(poly, step=0.4):
    x0, y0, x1, y1 = bbox(poly)
    pts = list(poly)
    n = len(poly)
    for i in range(n):
        ax, ay = poly[i]
        bx, by = poly[(i + 1) % n]
        k = max(1, int(math.hypot(bx - ax, by - ay) / step))
        pts += [(ax + (bx - ax) * t / k, ay + (by - ay) * t / k) for t in range(k)]
    x = x0
    while x <= x1:
        y = y0
        while y <= y1:
            if inside(poly, x, y):
                pts.append((x, y))
            y += step
        x += step
    return pts


def hits_paths(poly, margin=0.5):
    """Returns a list of reasons this footprint touches the ring, a spoke or the plaza."""
    why = set()
    for (x, y) in samples(poly):
        r = math.hypot(x, y)
        if RING_IN - margin <= r <= RING_OUT + margin:
            why.add("ring")
        if (abs(x) < SPOKE_HALF + margin and abs(y) < RING_IN + 0.5) or (abs(y) < SPOKE_HALF + margin and abs(x) < RING_IN + 0.5):
            why.add("spoke")
        if abs(x) < PLAZA_X + margin and abs(y) < PLAZA_Y + margin:
            why.add("plaza")
    return sorted(why)


def tri_count(root, visual_only=False):
    n = 0
    for ob in [root] + descendants(root):
        if ob.type == "MESH" and not (visual_only and "colonly" in ob.name):
            n += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    return n
