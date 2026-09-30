"""
Realistic look: PBR materials from CC0 texture sets, real-scale UVs, and baked sky + bounce light.

Pipeline for a level (see neighborhood.py):
    realism.dress(objects)          flat kit materials -> PBR sets (by material name), box UVs where missing
    realism.split_collision()       every `-col` visual keeps a hidden `-colonly` twin, so the visual can be merged
    baked = realism.join_static()   one mesh for everything that takes baked light, with a second UV set
    realism.bake(baked, out_png)    Cycles: sky (sun clipped out of the HDRI) direct + indirect, plus the sun's
                                    bounce only. The live sun in Godot adds the direct sunlight and shadows.

Units: the lightmap stores light in "Godot sun = 1" units: a white surface facing the sun at noon gets
albedo * 1.0 from the live DirectionalLight (energy 1) and albedo * lightmap from the bake. The PNG stores
sqrt(value / RANGE) so dark values keep precision in 8 bits.
"""

import json
import math
import os

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.normpath(os.path.join(HERE, "..", "art"))
# the sky (and so the sun and the light) for the bakes: SKY=<polyhaven id> overrides it for comparisons
SKY = os.environ.get("SKY", "qwantani_late_afternoon_puresky")      # late afternoon: long shadows, warm light
HDRI = os.path.join(ART, "hdri", SKY + "_2k.hdr")


def set_sky(name):
    """Bake a level under another Poly Haven sky (art/hdri/<name>_2k.hdr; the game loads <name>_1k.hdr)."""
    global SKY, HDRI
    SKY = name
    HDRI = os.path.join(ART, "hdri", name + "_2k.hdr")
RANGE = 2.0
SKY_CLAMP = 30.0          # HDRI radiance above this is the sun disc: left out of the sky bake

# texture set, metres per texture tile, tint (multiplied), metallic, bake?
SETS = {
    "concrete": ("Concrete046", 2.5, (1.0, 1.0, 1.0), 0.0, True),
    "concrete_rough": ("Concrete044D", 2.0, (1.0, 1.0, 1.0), 0.0, True),
    "asphalt": ("Asphalt031", 3.0, (0.8, 0.8, 0.8), 0.0, True),
    "wood": ("Wood094", 1.2, (1.0, 1.0, 1.0), 0.0, True),
    "wood_side": ("Wood094", 1.2, (0.45, 0.42, 0.4), 0.0, True),
    "grass": ("Grass004", 2.5, (1.0, 1.0, 1.0), 0.0, True),
    "grass_far": ("Grass004", 4.0, (0.8, 0.84, 0.74), 0.0, False),     # past the park's edge: lit live, not baked
    "metal": ("Metal032", 0.6, (1.0, 1.0, 1.0), 1.0, False),
    "paint_red": ("PaintedMetal004", 0.8, (1.0, 1.0, 1.0), 0.0, False),
    "galvanized": ("Metal032", 0.5, (0.78, 0.8, 0.82), 1.0, False),
    "court": ("Concrete046", 2.5, (0.26, 0.5, 0.36), 0.0, True),             # a painted green games court
    "side_paint": ("Concrete046", 2.5, (0.27, 0.34, 0.43), 0.0, True),      # painted side sheets: slate over a neutral base
    "steel_plate": ("Concrete044D", 1.0, (0.5, 0.5, 0.52), 0.0, True),       # worn steel at the ramp's foot (baked; Metal032 reads blue)
    "bark": ("Bark012", 1.0, (1.0, 1.0, 1.0), 0.0, False),
    "siding": ("WoodSiding009", 2.0, (0.95, 0.93, 0.88), 0.0, True),
    "siding_blue": ("WoodSiding009", 2.0, (0.55, 0.68, 0.82), 0.0, True),
    "siding_sage": ("WoodSiding009", 2.0, (0.62, 0.72, 0.58), 0.0, True),
    "siding_cream": ("WoodSiding009", 2.0, (0.93, 0.85, 0.68), 0.0, True),
    "siding_grey": ("WoodSiding009", 2.0, (0.6, 0.62, 0.64), 0.0, True),
    "roof": ("RoofingTiles006", 2.5, (1.0, 1.0, 1.0), 0.0, True),
    "roof_dark": ("RoofingTiles006", 2.5, (0.36, 0.36, 0.38), 0.0, True),
    "roof_brown": ("RoofingTiles006", 2.5, (0.6, 0.47, 0.38), 0.0, True),
    "brick": ("Bricks101", 1.5, (1.0, 1.0, 1.0), 0.0, True),
    "paving": ("PavingStones128", 2.0, (1.0, 1.0, 1.0), 0.0, True),
    "dirt": ("Ground037", 3.0, (1.0, 1.0, 1.0), 0.0, True),
}

# flat kit material name -> set
KIT = {
    "Wood": "wood", "WoodB": "wood", "Navy": "wood_side", "NavyLt": "wood_side",
    "Concrete": "concrete", "Plaza": "concrete", "Curb": "concrete", "ConcreteDk": "concrete_rough",
    "Stone": "concrete_rough", "StoneDk": "concrete_rough", "Wall": "concrete_rough", "Grey": "concrete",
    "GreyDark": "concrete_rough",
    "Path": "asphalt", "PathB": "asphalt", "Road": "asphalt",
    "Grass": "grass", "GrassB": "grass",
    "Metal": "metal", "MetalDk": "metal", "Coping": "metal", "Galv": "galvanized", "Steel": "steel_plate",
    "SidePaint": "side_paint", "Timber": "wood_side", "Court": "court",
    "Red": "paint_red", "Yellow": "paint_red", "Orange": "paint_red", "Blue": "paint_red",
    "Siding": "siding", "SidingBlue": "siding_blue", "SidingSage": "siding_sage", "Roof": "roof", "Brick": "brick",
    "Paving": "paving", "Dirt": "dirt", "Sidewalk": "concrete", "Trim": "concrete", "Door": "wood_side",
    "SidingCream": "siding_cream", "SidingGrey": "siding_grey", "RoofDark": "roof_dark", "RoofBrown": "roof_brown",
    "Pole": "wood_side", "Driveway": "concrete", "FarGrass": "grass_far",
}

_mats = {}


def _mix_sockets(node):
    """(A colour input, B colour input, colour output) of a ShaderNodeMix in RGBA mode."""
    ins = [i for i in node.inputs if i.type == "RGBA"]
    outs = [o for o in node.outputs if o.type == "RGBA"]
    return ins[0], ins[1], outs[0]


def _tex(node_tree, path, non_color=False):
    img = bpy.data.images.load(path, check_existing=True)
    if non_color:
        img.colorspace_settings.name = "Non-Color"
    n = node_tree.nodes.new("ShaderNodeTexImage")
    n.image = img
    return n


def material(set_name):
    """Principled BSDF over one CC0 texture set; exports to glTF as base colour / normal / roughness(+metal)."""
    if set_name in _mats:
        return _mats[set_name]
    asset, _tile, tint, metallic, bake = SETS[set_name]
    folder = os.path.join(ART, "textures", asset)
    base = os.path.join(folder, f"{asset}_1K-JPG")
    m = bpy.data.materials.new(f"PBR_{set_name}")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    col = _tex(nt, base + "_Color.jpg")
    if tint != (1.0, 1.0, 1.0):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        a, b, o = _mix_sockets(mix)
        b.default_value = (*tint, 1.0)
        nt.links.new(col.outputs["Color"], a)
        nt.links.new(o, bsdf.inputs["Base Color"])
    else:
        nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    rough = _tex(nt, base + "_Roughness.jpg", non_color=True)
    nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    nrm = _tex(nt, base + "_NormalGL.jpg", non_color=True)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nrm.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    metal_path = base + "_Metalness.jpg"
    if metallic > 0.0 and os.path.exists(metal_path):
        mt = _tex(nt, metal_path, non_color=True)
        nt.links.new(mt.outputs["Color"], bsdf.inputs["Metallic"])
    else:
        bsdf.inputs["Metallic"].default_value = metallic
    m["bake"] = bake
    m["tile"] = _tile
    _mats[set_name] = m
    return m


def set_for(mat_name):
    base = mat_name.split(".")[0]
    return KIT.get(base)


def box_uv(ob):
    """World-space box projection (metres) for faces of a mesh without UVs. Adjacent pieces tile continuously."""
    me = ob.data
    if me.uv_layers:
        return
    mw = ob.matrix_world
    nm = mw.to_3x3().inverted().transposed()
    layer = me.uv_layers.new(name="UVMap")
    for poly in me.polygons:
        n = (nm @ poly.normal).normalized()
        ax = max(range(3), key=lambda i: abs(n[i]))
        for li in poly.loop_indices:
            w = mw @ me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                uv = (w.y * (1 if n.x > 0 else -1), w.z)
            elif ax == 1:
                uv = (w.x * (-1 if n.y > 0 else 1), w.z)
            else:
                uv = (w.x, w.y * (1 if n.z > 0 else -1))
            layer.data[li].uv = uv


def _scale_uvs(ob, tile_of_slot):
    """Metres -> texture tiles, per material slot."""
    me = ob.data
    layer = me.uv_layers[0]
    for poly in me.polygons:
        t = tile_of_slot.get(poly.material_index, 1.0)
        for li in poly.loop_indices:
            u, v = layer.data[li].uv
            layer.data[li].uv = (u / t, v / t)


def dress(objects):
    """Swap kit colours for PBR sets and give every mesh tile-scaled UVs. Unmapped materials are left alone."""
    for ob in objects:
        if ob.type != "MESH" or ob.name.endswith("-colonly"):
            continue
        me = ob.data
        box_uv(ob)
        tiles = {}
        for i, slot in enumerate(me.materials):
            if slot is None:
                continue
            sname = set_for(slot.name)
            if sname is None:
                continue
            me.materials[i] = material(sname)
            tiles[i] = SETS[sname][1]
        _scale_uvs(ob, tiles)


def split_collision():
    """A `Foo-col` object is visible + collision. Give it an invisible `Foo-colonly` twin and rename the visual,
    so visuals can be merged for the bake without losing per-piece collision (and surface names)."""
    for ob in list(bpy.context.scene.objects):
        if ob.type == "MESH" and ob.name.endswith("-col"):
            twin = ob.copy()
            twin.data = ob.data.copy()
            twin.name = ob.name[:-4] + "-colonly"
            bpy.context.scene.collection.objects.link(twin)
            twin.matrix_world = ob.matrix_world.copy()
            ob.name = "Vis_" + ob.name[:-4]


def group_of(ob):
    """Bake group: the nearest `bake_group` custom property up the parent chain (default "world")."""
    o = ob
    while o is not None:
        if "bake_group" in o:
            return o["bake_group"]
        o = o.parent
    return "world"


def join_static(name="Baked", group=None):
    """Merge every visible mesh whose materials all take baked light into one object with a lightmap UV set.
    With `group`, only objects in that bake group (group_of) are merged: each group gets its own lightmap."""
    bakeable = []
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH" or ob.name.endswith("-colonly") or not ob.data.materials or ob.get("library") \
                or ob.name.startswith("Baked"):
            continue
        if group is not None and group_of(ob) != group:
            continue
        if all(m is not None and m.get("bake", False) for m in ob.data.materials):
            bakeable.append(ob)
    if not bakeable:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for ob in bakeable:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = bakeable[0]
    for ob in bakeable:                                # joining needs the parents' transforms applied
        mw = ob.matrix_world.copy()
        ob.parent = None
        ob.matrix_world = mw
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    bpy.ops.object.join()
    baked = bpy.context.view_layer.objects.active
    baked.name = name
    # the joined mesh keeps the first object's mesh name: a "-col" there makes Godot build a second collider
    # out of the whole baked mesh (it did: the lawn's), so name it after the object
    baked.data.name = name
    me = baked.data
    # undersides resting on or below the ground are never seen: drop them so they take no lightmap space
    bm = bmesh.new()
    bm.from_mesh(me)
    hidden = [f for f in bm.faces if f.normal.z < -0.95 and f.calc_center_median().z < 0.05]
    bmesh.ops.delete(bm, geom=hidden, context="FACES")
    bm.to_mesh(me)
    bm.free()
    lm = me.uv_layers.new(name="Lightmap")
    me.uv_layers.active = lm
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.0, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    me.uv_layers.active = me.uv_layers[0]
    me.uv_layers[0].active_render = True
    return baked


def join_live(cell=30.0, prefix="Live"):
    """Merge every static visual that is lit live (one-off props, trees, house trim and glass, metal rails, bunting)
    into one object per map cell. Godot then draws a map cell as one call per material instead of one per object:
    the park had ~400 such objects. Props placed more than once keep sharing one mesh (copying them into the cells
    would grow the file; Level turns them into MultiMeshes). Collision twins stay separate."""
    cells = {}
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH" or ob.get("library") or ob.hide_render or not ob.data.polygons:
            continue
        if ob.name.endswith("-colonly") or ob.name.startswith(("Baked", prefix, "Far")):
            continue                              # (the world past the edge is joined on its own: terrain.join_far)
        if ob.data.users > 1:                     # repeated props stay shared: Godot draws them as one MultiMesh
            continue
        centre = ob.matrix_world @ (sum((Vector(c) for c in ob.bound_box), Vector()) / 8.0)
        cells.setdefault((math.floor(centre.x / cell), math.floor(centre.y / cell)), []).append(ob)
    joined = set(o for obs in cells.values() for o in obs)
    for ob in bpy.context.scene.objects:          # colliders parented to a prop must not move with the join
        if ob not in joined and ob.parent in joined:
            mw = ob.matrix_world.copy()
            ob.parent = None
            ob.matrix_world = mw
    out = []
    for (cx, cy), obs in sorted(cells.items()):
        for ob in obs:
            mw = ob.matrix_world.copy()
            ob.parent = None
            ob.data = ob.data.copy()               # props share one mesh: joining needs their own copy
            ob.matrix_world = mw
            while len(ob.data.uv_layers) > 1:      # one UV set everywhere, so no merged mesh looks lightmapped
                ob.data.uv_layers.remove(ob.data.uv_layers[-1])
            if ob.data.uv_layers:
                ob.data.uv_layers[0].name = "UVMap"
        host = bpy.data.objects.new(f"{prefix}_{cx}_{cy}", bpy.data.meshes.new(f"{prefix}_{cx}_{cy}"))
        bpy.context.scene.collection.objects.link(host)
        host.location = ((cx + 0.5) * cell, (cy + 0.5) * cell, 0.0)
        bpy.ops.object.select_all(action="DESELECT")
        for ob in obs:
            ob.select_set(True)
        host.select_set(True)
        bpy.context.view_layer.objects.active = host
        bpy.ops.object.join()
        out.append(host)
    return out


def sun_from_hdri(path=None):
    """Direction to the brightest pixel (Blender axes) and the irradiance the sun disc delivers."""
    path = path or HDRI
    import numpy as np
    img = bpy.data.images.load(path, check_existing=True)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    lum = px.reshape(h, w, 4)[:, :, :3].mean(axis=2)          # rows bottom-up (Blender)
    lat = ((np.arange(h) + 0.5) / h - 0.5) * math.pi
    d_omega = ((2 * math.pi / w) * (math.pi / h) * np.cos(lat))[:, None]
    sun_irr = float((np.clip(lum - SKY_CLAMP, 0.0, None) * d_omega).sum())
    up = (lat > 0)[:, None]
    sky_irr = float((np.minimum(lum, SKY_CLAMP) * np.sin(lat)[:, None] * d_omega * up).sum())
    bi = int(lum.argmax())
    x, y = bi % w, bi // w
    u, v = (x + 0.5) / w, (y + 0.5) / h
    lon = (0.5 - u) * 2 * math.pi               # Blender equirect: u = 0.5 - atan2(y, x) / 2pi
    lat = (v - 0.5) * math.pi
    d = Vector((math.cos(lat) * math.cos(lon), math.cos(lat) * math.sin(lon), math.sin(lat)))
    return d.normalized(), sun_irr, sky_irr


def _world(strength, clamp):
    world = bpy.data.worlds.new("Sky") if bpy.context.scene.world is None else bpy.context.scene.world
    bpy.context.scene.world = world
    world.use_nodes = True
    nt = world.node_tree
    nt.nodes.clear()
    env = nt.nodes.new("ShaderNodeTexEnvironment")
    env.image = bpy.data.images.load(HDRI, check_existing=True)
    out = nt.nodes.new("ShaderNodeOutputWorld")
    bg = nt.nodes.new("ShaderNodeBackground")
    bg.inputs["Strength"].default_value = strength
    if clamp:
        mn = nt.nodes.new("ShaderNodeMix")          # min(colour, SKY_CLAMP): cuts the sun disc out
        mn.data_type = "RGBA"
        mn.blend_type = "DARKEN"
        mn.inputs["Factor"].default_value = 1.0
        a, b, o = _mix_sockets(mn)
        b.default_value = (SKY_CLAMP, SKY_CLAMP, SKY_CLAMP, 1.0)
        nt.links.new(env.outputs["Color"], a)
        nt.links.new(o, bg.inputs["Color"])
    else:
        nt.links.new(env.outputs["Color"], bg.inputs["Color"])
    nt.links.new(bg.outputs["Background"], out.inputs["Surface"])


def _bake_pass(ob, img, pass_filter, samples):
    sc = bpy.context.scene
    sc.cycles.samples = samples
    for m in ob.data.materials:
        nt = m.node_tree
        for n in nt.nodes:
            if n.type == "TEX_IMAGE" and n.name == "LMTarget":
                nt.nodes.remove(n)
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.name = "LMTarget"
        tn.image = img
        nt.nodes.active = tn
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    ob.data.uv_layers.active = ob.data.uv_layers["Lightmap"]
    bpy.ops.object.bake(type="DIFFUSE", pass_filter=pass_filter, margin=4, use_clear=True, target="IMAGE_TEXTURES")
    ob.data.uv_layers.active = ob.data.uv_layers[0]


def bake(ob, out_png, size=2048, samples=128):
    """Bake sky light (direct + indirect, sun clipped out) plus the sun's bounce only, into a PNG lightmap.
    Writes <out>.json with the sun direction (Godot axes) and energies for the Godot environment."""
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    try:
        prefs.compute_device_type = "METAL"
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
    except Exception:
        sc.cycles.device = "CPU"
    hidden = []
    for o in bpy.context.scene.objects:           # collision twins must not shadow or tint the bake
        if o.name.endswith("-colonly") and not o.hide_render:
            o.hide_render = True
            hidden.append(o)
    sun_dir, sun_irr, sky_irr = sun_from_hdri()
    s = math.pi / max(sun_irr, 1e-3)          # scale: the sun delivers pi W/m2 -> Godot sun energy 1
    print(f"[realism] sun dir {tuple(round(c, 3) for c in sun_dir)} sun irr {sun_irr:.1f} sky irr {sky_irr:.1f} scale {s:.5f}")

    img_a = bpy.data.images.new("LM_sky", size, size, float_buffer=True)
    img_b = bpy.data.images.new("LM_sun", size, size, float_buffer=True)
    # 1: sky only (sun disc clipped), all light
    _world(1.0, clamp=True)
    _bake_pass(ob, img_a, {"DIRECT", "INDIRECT"}, samples)
    # 2: the sun only, bounce light only
    _world(0.0, clamp=True)
    lamp_data = bpy.data.lights.new("Sun", "SUN")
    lamp_data.energy = sun_irr
    lamp_data.angle = math.radians(0.53)
    lamp = bpy.data.objects.new("Sun", lamp_data)
    bpy.context.scene.collection.objects.link(lamp)
    lamp.rotation_euler = (-sun_dir).to_track_quat("-Z", "Y").to_euler()
    _bake_pass(ob, img_b, {"INDIRECT"}, samples)
    bpy.data.objects.remove(lamp)

    import numpy as np
    a = np.empty(size * size * 4, dtype=np.float32)
    b = np.empty(size * size * 4, dtype=np.float32)
    img_a.pixels.foreach_get(a)
    img_b.pixels.foreach_get(b)
    lin = (a + b) * s
    rgb = lin.reshape(-1, 4)[:, :3]
    print(f"[realism] lightmap (Godot units) mean {rgb.mean():.3f} p50 {np.median(rgb):.3f} p99 {np.percentile(rgb, 99):.3f} max {rgb.max():.3f}")
    out = np.sqrt(np.clip(lin / RANGE, 0.0, 1.0))
    out.reshape(-1, 4)[:, 3] = 1.0
    res = bpy.data.images.new("Lightmap", size, size)
    res.pixels.foreach_set(out)
    res.filepath_raw = out_png
    res.file_format = "PNG"
    res.save()
    for m in ob.data.materials:
        n = m.node_tree.nodes.get("LMTarget")
        if n is not None:
            m.node_tree.nodes.remove(n)
    for o in hidden:
        o.hide_render = False
    json_path = os.path.splitext(out_png)[0] + ".json"
    group = None
    if ".lightmap." in os.path.basename(out_png):
        # <level>.lightmap.<group>.png: one JSON for the level lists every group
        stem, group = os.path.basename(out_png)[:-4].split(".lightmap.")
        json_path = os.path.join(os.path.dirname(out_png), stem + ".lightmap.json")
    groups = []
    if group is not None and os.path.exists(json_path):
        with open(json_path) as f:
            groups = json.load(f).get("groups", [])
    if group is not None and group not in groups:
        groups.append(group)
    info = {
        "range": RANGE,
        "groups": groups,
        "sun_dir": [round(sun_dir.x, 4), round(sun_dir.z, 4), round(-sun_dir.y, 4)],   # Godot axes, toward the sun
        "sun_energy": 1.0,
        "sky_energy": round(s, 6),
        "hdri": os.path.basename(HDRI).replace("_2k", "_1k"),
    }
    with open(json_path, "w") as f:
        json.dump(info, f, indent=1)
    print(f"[realism] baked {out_png}")
    return info
