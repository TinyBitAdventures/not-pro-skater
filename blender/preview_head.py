"""
Try a character's hair (or anything else in its recipe) before committing to it: builds the character with each
candidate and renders the head from the front, the side and behind in Cycles, without touching the game's assets.

    blender --background --python blender/preview_head.py -- actor short04 cortu_short_messy_hair faydaen_hair_1

-> shots/head_<key>_<hair>_{front,side,back}.png (the glb goes to a temp folder). Check each candidate's licence in
its .mhclo first: community MakeHuman assets can be AGPL3; the cast is all CC0.
"""

import math
import os
import sys
import tempfile

import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import character  # noqa: E402

SHOTS = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shots"))


def render_head(key, label):
    rig = bpy.data.objects["Rig"]
    centre = rig.matrix_world @ rig.pose.bones["head"].head + Vector((0.0, 0.0, 0.1))
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 48
    sc.render.resolution_x = sc.render.resolution_y = 420
    sc.world.use_nodes = True
    bg = sc.world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.55, 0.62, 0.72, 1.0)
    bg.inputs[1].default_value = 0.8
    sun = bpy.data.objects.get("PreviewSun")
    if sun is None:
        sun = bpy.data.objects.new("PreviewSun", bpy.data.lights.new("PreviewSun", "SUN"))
        sun.data.energy = 3.5
        sc.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(50), 0.0, math.radians(30))
    cam = bpy.data.objects.get("PreviewCam")
    if cam is None:
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        sc.collection.objects.link(cam)
    cam.data.lens = 85
    sc.camera = cam
    os.makedirs(SHOTS, exist_ok=True)
    for view, ang in (("front", -120.0), ("side", 0.0), ("back", 110.0)):
        a = math.radians(ang)
        cam.location = centre + Vector((math.cos(a) * 1.05, math.sin(a) * 1.05, 0.05))
        cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = os.path.join(SHOTS, f"head_{key}_{label}_{view}.png")
        bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:]
    key, hairs = args[0], args[1:] or [character.ARCHETYPES[args[0]]["hair"]]
    character.OUT = tempfile.mkdtemp(prefix="preview_head_")      # never the game's assets
    for hair in hairs:
        character.ARCHETYPES[key]["hair"] = hair
        character.build(key)
        render_head(key, hair)
        print(f"[preview] {key} {hair}: shots/head_{key}_{hair}_{{front,side,back}}.png")
