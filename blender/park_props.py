"""
CC0 props from Poly Haven (fetched by tools/fetch_assets.py into art/models/<id>/): each model is imported
once, merged into one mesh and kept as a library object; place() makes copies that share its mesh (the glb
stores it once). Props are lit live in Godot (not baked), but they are in the scene during the bake, so the
ground under them gets their soft shadow. Each placed prop gets a hidden box collider from its bounds.
"""

import math
import os

import bpy
from mathutils import Vector

import lib
import realism

MODELS = os.path.join(realism.ART, "models")
_lib = {}

# some assets hold variants side by side: keep only the parts whose names contain one of these
PARTS = {"fire_hydrant": ("fire_hydrant_aged",), "football": ("football_inflated",)}
# kits laid out piece by piece: drop the parts that are not this prop. The street seating kit is one bench with a
# back plus a spare backless seat (no leg at its far end) and four curved connector seats floating beside it.
EXCLUDE = {"modular_street_seating": ("seat_bench", "suspended_support_02", "connector_")}
# heavy scans: collapse to about this many triangles (they are small on screen)
DECIMATE = {"fire_hydrant": 4000, "garden_gnome": 3000, "modular_street_seating": 9000, "covered_car": 6000}


def _import(model_id):
    if model_id in _lib:
        return _lib[model_id]
    path = os.path.join(MODELS, model_id, f"{model_id}_1k.gltf")
    before = set(o.name for o in bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.context.scene.objects if o.name not in before]
    new_names = [o.name for o in new]
    meshes = [o for o in new if o.type == "MESH"]
    if model_id in PARTS:
        meshes = [o for o in meshes if any(k in o.name for k in PARTS[model_id])]
    if model_id in EXCLUDE:
        meshes = [o for o in meshes if not any(k in o.name for k in EXCLUDE[model_id])]
    bpy.ops.object.select_all(action="DESELECT")
    for o in meshes:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    if len(meshes) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    for nm in new_names:
        o = bpy.data.objects.get(nm)
        if o is not None and o != ob:
            bpy.data.objects.remove(o)
    ob.name = f"Lib_{model_id}"
    if model_id in DECIMATE:
        tris = sum(len(p.vertices) - 2 for p in ob.data.polygons)
        ratio = DECIMATE[model_id] / max(tris, 1)
        if ratio < 1.0:
            mod = ob.modifiers.new("Decimate", "DECIMATE")
            mod.ratio = ratio
            bpy.context.view_layer.objects.active = ob
            bpy.ops.object.modifier_apply(modifier=mod.name)
    # the part filter left the other variant's objects in the scene: they go with the rest of the import
    for m in ob.data.materials:
        if m is not None:
            m["bake"] = False
    # the library copy sits far away and is removed before export (its mesh lives on in the copies)
    ob.location = (0, 0, -500)
    ob["library"] = True
    _lib[model_id] = ob
    return ob


def bounds(model_id):
    ob = _import(model_id)
    xs = [v.co.x for v in ob.data.vertices]
    ys = [v.co.y for v in ob.data.vertices]
    zs = [v.co.z for v in ob.data.vertices]
    return Vector((min(xs), min(ys), min(zs))), Vector((max(xs), max(ys), max(zs)))


def place(model_id, x, y, rot_deg=0.0, z=0.0, scale=1.0, collide=True, surface="Wall", name=None):
    src = _import(model_id)
    ob = bpy.data.objects.new(name or lib.uname(f"Prop_{model_id}"), src.data)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = (x, y, z)
    ob.rotation_euler = (0, 0, math.radians(rot_deg))
    ob.scale = (scale, scale, scale)
    if collide:
        lo, hi = bounds(model_id)
        size = (hi - lo) * scale
        centre = (lo + hi) * 0.5 * scale
        c = lib.box(f"{surface}_{ob.name}-colonly", (size.x, size.y, size.z), (centre.x, centre.y, centre.z),
                    lib.mat("Collision", "#ff00ff"))
        c.parent = ob
    return ob


def remove_library():
    for ob in list(bpy.context.scene.objects):
        if ob.get("library"):
            bpy.data.objects.remove(ob)
