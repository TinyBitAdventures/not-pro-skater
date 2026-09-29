"""
Look test: a small, real-scale plaza built from the kit, dressed in CC0 PBR materials with baked sky and
bounce light (realism.py). The proving ground for the realistic look before real levels are built.
"""

import math

import lib
from lib import box, empty, mat
from pieces import bench, flat_rail, ledge, quarter_pipe, stair_set
import realism


def slab(name, surface, matname, x0, x1, y0, y1, top=0.0, t=0.4):
    return box(f"{surface}_{name}-col", (x1 - x0, y1 - y0, t), ((x0 + x1) / 2, (y0 + y1) / 2, top - t / 2),
               mat(matname, "#888888"))


def root(name, x, y, rot_deg=0.0):
    return empty(lib.uname(name), (x, y, 0.0), math.radians(rot_deg), None)


def build(out_glb, bake=True, samples=128):
    slab("Lawn", "Grass", "Grass", -30.0, 30.0, -30.0, 30.0, top=-0.04)
    slab("Plaza", "Plaza", "Plaza", -12.0, 12.0, -9.0, 14.0, top=0.0)
    slab("Path", "Path", "Path", -12.0, 12.0, -13.0, -9.0, top=-0.01)
    box("Wall_Back-col", (26.0, 0.6, 3.2), (0.0, 16.5, 1.6), mat("Wall", "#888888"))
    quarter_pipe(root("QP", 0.0, 6.0), W=7.0, R=3.2, H=2.4, D=2.0, rails=False, decals=False)
    ledge(root("Ledge", -7.0, -1.0, 90.0), L=6.0, W=0.7, h=0.5)
    flat_rail(root("Rail", 6.5, -2.0), L=6.0, h=0.6, color="Red")
    stair_set(root("Stairs", -8.0, 9.0, 180.0), n=5)
    bench(root("Bench", 8.0, 10.5))
    empty("Spawn_Player", (0.0, -6.0, 0.02), 0.0, None)
    empty("Start_plaza", (0.0, -6.0, 0.02), 0.0, None)
    empty("Start_qp", (0.0, -4.0, 0.02), 0.0, None)

    objs = list(lib.bpy.context.scene.objects)
    realism.dress(objs)
    realism.split_collision()
    baked = realism.join_static()
    if bake:
        realism.bake(baked, out_glb.replace(".glb", ".lightmap.png"), samples=samples)
