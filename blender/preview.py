"""
Workbench preview renders from the game's camera angle (orthographic, 35.264 degrees down, viewer at +X,-Y
looking toward Blender NW), sky-blue background.

    blender --background --factory-startup --python blender/preview.py -- OUT_DIR name [name ...]
Names: any key of PREVIEWS (see dressing.PREVIEWS, plus the character/car/duck models below) or `overview`.
"""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402
from mathutils import Vector  # noqa: E402

import lib  # noqa: E402

SKY = (0.56, 0.83, 1.0)


def world_bounds(objs=None):
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for ob in (objs or bpy.data.objects):
        if ob.type != "MESH":
            continue
        for c in ob.bound_box:
            w = ob.matrix_world @ Vector(c)
            lo = Vector((min(lo.x, w.x), min(lo.y, w.y), min(lo.z, w.z)))
            hi = Vector((max(hi.x, w.x), max(hi.y, w.y), max(hi.z, w.z)))
    return lo, hi


def render(path, center, scale, size=(900, 700), pitch=35.264, yaw=45.0):
    sc = bpy.context.scene
    for ob in bpy.data.objects:                       # collision proxies are invisible in the game
        if "colonly" in ob.name:
            ob.hide_render = True
    sc.render.engine = "BLENDER_WORKBENCH"
    sc.render.resolution_x, sc.render.resolution_y = size
    sc.render.resolution_percentage = 100
    sc.render.filepath = path
    sc.render.image_settings.file_format = "PNG"
    sc.view_settings.view_transform = "Standard"
    sh = sc.display.shading
    sh.light = "STUDIO"
    sh.color_type = "MATERIAL"
    sh.show_object_outline = True
    sh.object_outline_color = (0.08, 0.1, 0.18)
    sh.show_specular_highlight = False
    sc.display.render_aa = "8"
    w = bpy.data.worlds.new("Sky")
    w.color = SKY
    sc.world = w
    cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    cam.data.clip_start = 1.0
    cam.data.clip_end = 2000.0
    bpy.context.scene.collection.objects.link(cam)
    cam.rotation_euler = (math.radians(90 - pitch), 0, math.radians(yaw))
    look = Vector((-math.sin(math.radians(yaw)) * math.cos(math.radians(pitch)),
                   math.cos(math.radians(yaw)) * math.cos(math.radians(pitch)), -math.sin(math.radians(pitch))))
    cam.location = Vector(center) - look * 400
    sc.camera = cam
    bpy.ops.render.render(write_still=True)
    print(f"[preview] {path}")


def shoot(path, ground=None, pad=1.25, min_scale=3.0, size=(900, 700), objs=None):
    """Frame everything in the scene (or `objs`), optionally add a flat ground disc, and render."""
    import pieces
    lo, hi = world_bounds(objs)
    c = (lo + hi) / 2
    if ground:
        gx, gy = ground if isinstance(ground, tuple) else (max(hi.x - lo.x, 3) + 3, max(hi.y - lo.y, 3) + 3)
        lib.box("PreviewGround", (gx, gy, 0.1), (c.x, c.y, -0.05), pieces.M("Grass"))
    dx, dy, dz = hi.x - lo.x, hi.y - lo.y, hi.z - lo.z
    wneed = (dx + dy) * 0.7071
    hneed = (dx + dy) * 0.7071 * 0.5774 + dz * 0.8192
    scale = max(min_scale, wneed * pad, hneed * pad * size[0] / size[1])
    render(path, (c.x, c.y, (lo.z + hi.z) / 2), scale, size)


if __name__ == "__main__":
    import dressing
    args = sys.argv[sys.argv.index("--") + 1:]
    out, names = args[0], args[1:]
    os.makedirs(out, exist_ok=True)
    for n in names:
        lib.reset_scene()
        dressing.preview(n)
        # some previews position their own camera framing; default framing otherwise
        opts = dict(dressing.PREVIEW_OPTS.get(n, {}))
        if "scale" in opts:
            render(os.path.join(out, n + ".png"), opts["center"], opts["scale"])
        else:
            opts.setdefault("ground", n not in ("spectator", "duck") and not n.startswith("car_") and True)
            shoot(os.path.join(out, n + ".png"), **opts)
