"""
Far backdrop: hazy hills and snowy peaks in a ring at 120-160 m, a skyline of tall buildings behind the far (north-west)
side, a water tower, a radio mast, tall conifers and drifting clouds. NO collision anywhere. Everything hangs off
one `Backdrop` empty so Godot can hide / re-parent / scale it as one unit.
"""

import math
import random

from lib import box, cyl_between, cyl_z, empty, ico, mesh_obj, uname
from pieces import M


def _cone(parent, x, y, h, r, mat, seg=7, z0=-1.0):
    cyl_between(uname("Hill"), (x, y, z0), (x, y, h), r * (1 + (-z0) / max(h, 1)), M(mat), r1=0.03 * r, seg=seg, smooth=False,
                caps=False, parent=parent)


def mountain(parent, x, y, h, r, mat, snow=False, rnd=None):
    rnd = rnd or random.Random(0)
    _cone(parent, x, y, h, r, mat)
    for k in range(2):
        a = rnd.uniform(0, 2 * math.pi)
        d = r * rnd.uniform(0.55, 0.8)
        _cone(parent, x + math.cos(a) * d, y + math.sin(a) * d, h * rnd.uniform(0.45, 0.7), r * rnd.uniform(0.5, 0.7), mat)
    if snow:
        zc = h * 0.68
        R0 = r * (1 + 1 / max(h, 1))
        rc = (R0 + (0.03 * r - R0) * (zc + 1) / (h + 1)) * 1.05 + 0.2      # just outside the cone's own surface
        cyl_between(uname("Snow"), (x, y, zc), (x, y, h + 0.15), rc, M("HillSnow"), r1=0.03 * r + 0.25, seg=7, smooth=False,
                    caps=False, parent=parent)


def mountains(parent):
    rnd = random.Random(101)
    n = 26
    for i in range(n):
        a = math.radians(i * 360 / n + rnd.uniform(-4, 4))
        R = rnd.uniform(122, 160)
        h = rnd.uniform(26, 58)
        r = h * rnd.uniform(1.1, 1.5)
        mat = "HillNear" if R < 136 else ("HillMid" if R < 150 else "HillFar")
        mountain(parent, math.cos(a) * R, math.sin(a) * R, h, r, mat, snow=(h > 42 and rnd.random() < 0.8), rnd=rnd)
    # low rolling foothills just inside the ring
    for i in range(18):
        a = math.radians(i * 20 + rnd.uniform(-6, 6))
        R = rnd.uniform(108, 122)
        _cone(parent, math.cos(a) * R, math.sin(a) * R, rnd.uniform(9, 16), rnd.uniform(16, 24), "HillFar")


def building(parent, x, y, w, d, h, mat, face_deg, rnd):
    root = empty(uname("Bldg"), (x, y, 0), math.radians(face_deg), parent)
    box(uname("BldgBody"), (w, d, h), (0, 0, h / 2), M(mat), parent=root)
    if rnd.random() < 0.5:
        box(uname("BldgTop"), (w * 0.6, d * 0.6, h * 0.08), (0, 0, h + h * 0.04), M("MetalDk"), parent=root)
    if rnd.random() < 0.4:
        cyl_z(uname("Antenna"), (rnd.uniform(-w / 4, w / 4), 0, h), h * 0.18, 0.15, M("MetalDk"), r1=0.05, seg=4, smooth=False,
              parent=root)
    verts, faces = [], []
    cols = max(2, int(w / 2.6))
    rows = max(3, int((h - 3) / 3.6))
    for (face, ww) in (("front", w), ("side", d)):
        cw = ww / cols
        for r in range(rows):
            for c in range(cols):
                if rnd.random() < 0.12:
                    continue
                u0 = -ww / 2 + cw * c + cw * 0.2
                u1 = u0 + cw * 0.6
                z0 = 2.2 + r * 3.6
                z1 = z0 + 2.1
                b = len(verts)
                if face == "front":     # +Y face
                    verts += [(u0, d / 2 + 0.03, z0), (u1, d / 2 + 0.03, z0), (u1, d / 2 + 0.03, z1), (u0, d / 2 + 0.03, z1)]
                else:                   # +X face
                    verts += [(w / 2 + 0.03, u1, z0), (w / 2 + 0.03, u0, z0), (w / 2 + 0.03, u0, z1), (w / 2 + 0.03, u1, z1)]
                faces.append((b, b + 1, b + 2, b + 3))
    if faces:
        mesh_obj(uname("BldgWindows"), verts, faces, [M("Window")], parent=root)


def skyline(parent):
    rnd = random.Random(202)
    mats = ["BldgA", "BldgB", "BldgC", "BldgD"]
    n = 18
    for i in range(n):
        a = math.radians(95 + i * (110 / (n - 1)) + rnd.uniform(-2, 2))     # the far, north-west half
        R = rnd.uniform(98, 118)
        w, d = rnd.uniform(9, 15), rnd.uniform(9, 14)
        h = rnd.uniform(24, 62) if 120 < math.degrees(a) < 170 else rnd.uniform(18, 40)
        x, y = math.cos(a) * R, math.sin(a) * R
        building(parent, x, y, w, d, h, mats[i % 4], math.degrees(a) + 90 - 180 + 180, rnd)


def water_tower(parent, x, y):
    r = empty(uname("WaterTower"), (x, y, 0), 0, parent)
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl_between(uname("TowerLeg"), (sx * 3.2, sy * 3.2, 0), (sx * 2.4, sy * 2.4, 20), 0.35, M("MetalDk"), seg=4, smooth=False,
                        parent=r)
    cyl_z(uname("Tank"), (0, 0, 20), 8, 4.5, M("BldgA"), seg=10, smooth=False, parent=r)
    cyl_between(uname("TankRoof"), (0, 0, 28), (0, 0, 32), 4.9, M("Roof"), r1=0.2, seg=10, smooth=False, parent=r)
    box(uname("TankBand"), (9.2, 0.3, 1.0), (0, 0, 24), M("Red"), parent=r)


def radio_mast(parent, x, y, h=70):
    r = empty(uname("RadioMast"), (x, y, 0), 0, parent)
    cyl_between(uname("Mast"), (0, 0, 0), (0, 0, h), 0.9, M("MetalDk"), r1=0.25, seg=4, smooth=False, parent=r)
    for k in range(1, 6):
        z = h * k / 6.5
        w = 6.0 * (1 - z / h) + 0.8
        box(uname("MastArm"), (w, 0.3, 0.3), (0, 0, z), M("Red" if k % 2 else "White"), parent=r)
    ico(uname("MastLamp"), (0, 0, h + 0.4), 0.7, M("Lamp"), sub=0, parent=r)


def conifer(parent, x, y, s):
    r = empty(uname("BgTree"), (x, y, 0), 0, parent)
    cyl_z(uname("BgTrunk"), (0, 0, 0), 2.5 * s, 0.3 * s, M("Trunk"), seg=5, smooth=False, parent=r)
    for i, (z, rad, hh) in enumerate(((1.5, 2.8, 4.0), (3.9, 2.2, 3.6), (6.0, 1.5, 3.4))):
        cyl_between(uname("BgPine"), (0, 0, z * s), (0, 0, (z + hh) * s), rad * s, M("Pine" if i % 2 == 0 else "PineB"), r1=0.03,
                    seg=6, smooth=False, caps=False, parent=r)


def cloud(idx, x, y, z, s, parent):
    c = empty(f"Cloud_{idx}", (x, y, z), 0, parent, size=3)
    for (dx, dz, r) in ((0, 0, 1.0), (1.3, -0.15, 0.8), (-1.3, -0.2, 0.75), (0.4, 0.5, 0.7)):
        ico(uname("CloudPuff"), (dx * s, 0, dz * s), r * s, M("Cloud"), sub=1, squash=(1.3, 1.0, 0.7), parent=c)
    return c


def build():
    root = empty("Backdrop")
    mountains(root)
    skyline(root)
    water_tower(root, -88, 74)
    radio_mast(root, 92, 104)
    radio_mast(root, -104, -60, h=50)
    rnd = random.Random(303)
    for i in range(14):
        a = math.radians(rnd.uniform(0, 360))
        R = rnd.uniform(96, 112)
        conifer(root, math.cos(a) * R, math.sin(a) * R, rnd.uniform(2.6, 4.2))
    for i in range(7):
        a = math.radians(i * 51 + 20)
        R = rnd.uniform(70, 120)
        cloud(i + 1, math.cos(a) * R, math.sin(a) * R, rnd.uniform(48, 80), rnd.uniform(5, 9), root)
    return root
