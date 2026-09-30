"""
Shared Blender helpers for the Skate Park asset builders.

Conventions
- Blender +Z is up. glTF export converts to Godot's Y-up, so Blender +Y becomes Godot -Z.
- Everything is flat-shaded low-poly with plain colour materials; Godot swaps every material
  for a toon shader at load time, so only the material NAME and base colour matter.
- Collision is named in the mesh's object name: `Foo-col` = visible + trimesh collision,
  `Foo-colonly` = invisible collision. Godot's glTF importer builds the StaticBody3D for us.
  The part of the name before the first underscore is the surface type the skater feels:
  Grass_, Path_, Concrete_, Wood_, Metal_, Wall_.
- Grind lines are Blender curves called `Rail_<id>` (custom property `kind`: rail / ledge / coping / curb),
  drawn ~0.07 m above the grindable edge. export() samples them into `<level>.rails.json` next to the glb
  (glTF cannot carry curves) and leaves them out of the glb.
"""

import math
import os

import bmesh
import bpy
from mathutils import Vector

_mats = {}
_counters = {}


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    _counters.clear()


def uname(base):
    """Unique, dot-free object name."""
    _counters[base] = _counters.get(base, 0) + 1
    return f"{base}_{_counters[base]:02d}"


def hexc(h):
    """sRGB hex -> linear rgb tuple."""
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def mat(name, hex_color):
    """Cached flat-colour material. Godot re-skins it, so keep names meaningful."""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    col = (*hexc(hex_color), 1.0)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = 1.0
    bsdf.inputs["Metallic"].default_value = 0.0
    m.diffuse_color = col
    _mats[name] = m
    return m


# --------------------------------------------------------------------------
# objects
# --------------------------------------------------------------------------

def link(ob, parent=None):
    bpy.context.scene.collection.objects.link(ob)
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, loc=(0, 0, 0), rot_z=0.0, parent=None, size=0.3):
    ob = bpy.data.objects.new(name, None)
    ob.empty_display_type = "PLAIN_AXES"
    ob.empty_display_size = size
    ob.location = loc
    ob.rotation_euler = (0, 0, rot_z)
    return link(ob, parent)


def recalc(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()


def orient_up(me, expect=(0, 0, 1)):
    """Flip every face if the first face's normal points away from `expect`."""
    me.update()
    if not me.polygons:
        return
    if me.polygons[0].normal.dot(Vector(expect)) < 0:
        bm = bmesh.new()
        bm.from_mesh(me)
        bmesh.ops.reverse_faces(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()


def mesh_obj(name, verts, faces, mats, face_mats=None, smooth=None, parent=None, loc=(0, 0, 0),
             closed=False, uvs=None):
    """uvs: optional per-face list of per-corner (u, v) in metres (the realistic look scales them per material)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], [], [tuple(f) for f in faces])
    me.update()
    if uvs is not None:
        layer = me.uv_layers.new(name="UVMap")
        for poly, fuv in zip(me.polygons, uvs):
            for li, uv in zip(poly.loop_indices, fuv):
                layer.data[li].uv = uv
    for m in mats:
        me.materials.append(m)
    if face_mats is not None:
        for p, i in zip(me.polygons, face_mats):
            p.material_index = i
    if smooth is not None:
        for p, s in zip(me.polygons, smooth):
            p.use_smooth = bool(s)
    if closed:
        recalc(me)
    ob = bpy.data.objects.new(name, me)
    ob.location = loc
    return link(ob, parent)


# --------------------------------------------------------------------------
# primitives (all flat shaded unless noted)
# --------------------------------------------------------------------------

def box(name, size, center, m, parent=None):
    sx, sy, sz = size[0] / 2, size[1] / 2, size[2] / 2
    cx, cy, cz = center
    v = [(cx + sx * a, cy + sy * b, cz + sz * c)
         for c in (-1, 1) for b in (-1, 1) for a in (-1, 1)]
    # index = a + 2b + 4c
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return mesh_obj(name, v, f, [m], parent=parent, closed=True)


def loft_box(name, base, top, z0, z1, m, center=(0, 0), parent=None):
    """Frustum with rectangular base (bx, by) at z0 and top (tx, ty) at z1."""
    cx, cy = center
    v = []
    for z, (sx, sy) in ((z0, base), (z1, top)):
        for b in (-1, 1):
            for a in (-1, 1):
                v.append((cx + a * sx / 2, cy + b * sy / 2, z))
    f = [(0, 2, 3, 1), (4, 5, 7, 6), (0, 1, 5, 4), (2, 6, 7, 3), (0, 4, 6, 2), (1, 3, 7, 5)]
    return mesh_obj(name, v, f, [m], parent=parent, closed=True)


def cyl_between(name, p0, p1, r0, m, r1=None, seg=10, smooth=True, caps=True, parent=None):
    """Cylinder / cone frustum between two points. Smooth sides, flat caps."""
    p0, p1 = Vector(p0), Vector(p1)
    r1 = r0 if r1 is None else r1
    axis = (p1 - p0)
    axis.normalize()
    ref = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    u = axis.cross(ref)
    u.normalize()
    w = axis.cross(u)
    verts = []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        d = u * math.cos(a) + w * math.sin(a)
        verts.append(p0 + d * r0)
        verts.append(p1 + d * r1)
    faces, smooth_flags = [], []
    for k in range(seg):
        k2 = (k + 1) % seg
        faces.append((2 * k, 2 * k2, 2 * k2 + 1, 2 * k + 1))
        smooth_flags.append(smooth)
    if caps:
        faces.append(tuple(2 * k for k in range(seg)))
        faces.append(tuple(2 * k + 1 for k in reversed(range(seg))))
        smooth_flags += [False, False]
    ob = mesh_obj(name, verts, faces, [m], smooth=smooth_flags, parent=parent, closed=caps)
    return ob


def cyl_z(name, base, h, r0, m, r1=None, seg=10, smooth=True, parent=None):
    b = Vector(base)
    return cyl_between(name, b, b + Vector((0, 0, h)), r0, m, r1=r1, seg=seg, smooth=smooth, parent=parent)


def ico(name, center, r, m, sub=1, squash=(1, 1, 1), parent=None, smooth=False):
    """Low-poly blob (icosphere), flat shaded."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for v in me.vertices:
        v.co = Vector((v.co.x * squash[0] + center[0], v.co.y * squash[1] + center[1],
                       v.co.z * squash[2] + center[2]))
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    ob = bpy.data.objects.new(name, me)
    return link(ob, parent)


def dome(name, center, r, cut_z, m, sub=2, squash=(1, 1, 1), parent=None):
    """Smooth-shaded sphere with everything below `cut_z` (relative to center) removed: helmets, caps."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=r)
    low = [f for f in bm.faces if f.calc_center_median().z < cut_z]
    bmesh.ops.delete(bm, geom=low, context="FACES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for v in me.vertices:
        v.co = Vector((v.co.x * squash[0] + center[0], v.co.y * squash[1] + center[1],
                       v.co.z * squash[2] + center[2]))
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    return link(ob, parent)


def quad(name, p00, p10, p11, p01, m, parent=None, expect=(0, 0, 1)):
    me_ob = mesh_obj(name, [p00, p10, p11, p01], [(0, 1, 2, 3)], [m], parent=parent)
    orient_up(me_ob.data, expect)
    return me_ob


def prism(name, pts, x0, x1, mats, edge_mat, smooth_edges=None, cap_mat=0, parent=None, loc=(0, 0, 0)):
    """
    Extrude a closed (y, z) profile along X from x0 to x1.
    pts: [(y, z), ...] (any winding; closing edge is implicit)
    edge_mat[i]: material index of the side strip from pts[i] to pts[i+1]
    smooth_edges[i]: shade that strip smooth (curved surfaces)
    """
    n = len(pts)
    area = sum(pts[i][0] * pts[(i + 1) % n][1] - pts[(i + 1) % n][0] * pts[i][1] for i in range(n))
    if area < 0:  # make CCW; new edge k is old edge (n-2-k) mod n, walked backwards
        pts = list(reversed(pts))
        edge_mat = [edge_mat[(n - 2 - k) % n] for k in range(n)]
        if smooth_edges is not None:
            smooth_edges = [smooth_edges[(n - 2 - k) % n] for k in range(n)]
    verts = []
    for (y, z) in pts:
        verts.append((x0, y, z))
        verts.append((x1, y, z))
    # UVs in metres: side strips run u = x along the extrusion, v = distance along the profile, so a ramp's
    # riding surface is one seamless sheet from the flat up over the curve; the caps are planar (y, z).
    along = [0.0]
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        along.append(along[-1] + math.hypot(b[0] - a[0], b[1] - a[1]))
    faces, fmat, fsm, uvs = [], [], [], []
    for i in range(n):
        j = (i + 1) % n
        faces.append((2 * i, 2 * j, 2 * j + 1, 2 * i + 1))
        uvs.append([(x0, along[i]), (x0, along[i + 1]), (x1, along[i + 1]), (x1, along[i])])
        fmat.append(edge_mat[i] if i < len(edge_mat) else 0)
        fsm.append(bool(smooth_edges[i]) if smooth_edges is not None and i < len(smooth_edges) else False)
    faces.append(tuple(2 * i + 1 for i in range(n)))
    uvs.append([(pts[i][0], pts[i][1]) for i in range(n)])
    faces.append(tuple(2 * i for i in reversed(range(n))))
    uvs.append([(-pts[i][0], pts[i][1]) for i in reversed(range(n))])
    fmat += [cap_mat, cap_mat]
    fsm += [False, False]
    ob = mesh_obj(name, verts, faces, mats, face_mats=fmat, smooth=fsm, parent=parent, loc=loc, closed=False, uvs=uvs)
    recalc(ob.data)
    return ob


def revolve(name, profile, segs, mats, edge_mat, parent=None, loc=(0, 0, 0), a0=0.0, a1=2 * math.pi):
    """Revolve an (r, z) profile around Z. Open surface; normals oriented up/out."""
    verts = []
    full = abs((a1 - a0) - 2 * math.pi) < 1e-6
    cols = segs if full else segs + 1
    for k in range(cols):
        a = a0 + (a1 - a0) * k / segs
        for (r, z) in profile:
            verts.append((r * math.cos(a), r * math.sin(a), z))
    np_ = len(profile)
    faces, fmat = [], []
    for k in range(segs):
        k2 = (k + 1) % cols
        for i in range(np_ - 1):
            faces.append((k * np_ + i, k2 * np_ + i, k2 * np_ + i + 1, k * np_ + i + 1))
            fmat.append(edge_mat[i] if i < len(edge_mat) else 0)
    ob = mesh_obj(name, verts, faces, mats, face_mats=fmat, parent=parent, loc=loc)
    orient_up(ob.data)
    return ob


def label(parent, text, loc, size=1.0, rot_z=0.0):
    """Marker empty; Godot turns `Text_<words>` into a Label3D."""
    return empty("Text_" + text.replace(" ", "_") + "_" + uname("t").split("_")[-1], loc, rot_z, parent, size)


# --------------------------------------------------------------------------
# collision + grind helpers
# --------------------------------------------------------------------------

def col_box(name, size, center, parent=None, surface="Wall"):
    """Invisible box collider (`<Surface>_<name>-colonly`)."""
    ob = box(f"{surface}_{name}-colonly", size, center, mat("Collision", "#ff00ff"), parent=parent)
    return ob


def rail_kind(gid):
    head = gid.split("_")[0].lower()
    if head == "coping":
        return "coping"
    if head in ("ledge", "bench", "funbox"):
        return "ledge"
    if head == "curb":
        return "curb"
    return "rail"


def rail(parent, gid, pts, kind=None, smooth=False, resolution=24):
    """Grindable line as a curve object `Rail_<gid>` in the parent's local space.
    smooth=False: a polyline through pts (straight rails, kinks). smooth=True: a Bezier with automatic
    handles through pts (curved rails); `resolution` samples per segment when exported."""
    cu = bpy.data.curves.new(f"Rail_{gid}", "CURVE")
    cu.dimensions = "3D"
    if smooth:
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts) - 1)
        for bp, p in zip(sp.bezier_points, pts):
            bp.co = Vector(p)
            bp.handle_left_type = "AUTO"
            bp.handle_right_type = "AUTO"
        sp.resolution_u = resolution
    else:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for pt, p in zip(sp.points, pts):
            pt.co = (p[0], p[1], p[2], 1.0)
    ob = bpy.data.objects.new(f"Rail_{gid}", cu)
    ob["kind"] = kind or rail_kind(gid)
    return link(ob, parent)


def grind_line(parent, gid, pts):
    """Straight / kinked grind line through pts (see rail())."""
    return rail(parent, gid, pts)


def _rail_points(ob):
    """World-space points along a Rail_ curve, in Godot axes (x, z, -y)."""
    mw = ob.matrix_world
    sp = ob.data.splines[0]
    pts = []
    if sp.type == "BEZIER":
        from mathutils.geometry import interpolate_bezier
        bps = sp.bezier_points
        for i in range(len(bps) - 1):
            a, b = bps[i], bps[i + 1]
            seg = interpolate_bezier(a.co, a.handle_right, b.handle_left, b.co, sp.resolution_u + 1)
            pts.extend(seg if i == 0 else seg[1:])
    else:
        pts = [Vector(p.co[:3]) for p in sp.points]
    out = []
    for p in pts:
        w = mw @ Vector(p)
        out.append([round(w.x, 4), round(w.z, 4), round(-w.y, 4)])
    return out


def write_rails(glb_path):
    """Write every Rail_ curve to <glb>.rails.json. Returns the curve objects (excluded from the glb)."""
    import json
    curves = [ob for ob in bpy.context.scene.objects if ob.type == "CURVE" and ob.name.startswith("Rail_")]
    if not curves:
        return []
    bpy.context.view_layer.update()
    data = {"rails": [{"id": ob.name[len("Rail_"):], "kind": ob.get("kind", "rail"), "points": _rail_points(ob)}
                      for ob in sorted(curves, key=lambda o: o.name)]}
    out = os.path.splitext(glb_path)[0] + ".rails.json"
    with open(out, "w") as f:
        json.dump(data, f, indent=1)
    print(f"[skate-park] exported {out} ({len(curves)} rails)")
    return curves


# --------------------------------------------------------------------------
# export
# --------------------------------------------------------------------------

DETAIL_MAX = 512     # normal / roughness / packed ARM maps
COLOR_MAX = 1024


def shrink_images():
    """The web build cannot afford every map at 1K: detail maps (normal, roughness, packed AO/rough/metal)
    go to 512, colour maps stay at 1K. Only the loaded copies change; the source files are untouched."""
    for img in bpy.data.images:
        if img.size[0] == 0 or img.source not in ("FILE", "GENERATED"):
            continue
        n = img.name.lower()
        detail = any(k in n for k in ("normal", "rough", "_arm", "_nor", "metal", "opacity", "displace"))
        cap = DETAIL_MAX if detail else COLOR_MAX
        w, h = img.size
        if max(w, h) > cap:
            k = cap / max(w, h)
            img.scale(max(1, int(w * k)), max(1, int(h * k)))


def export(path, selection=None, images=False):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    rails = set(write_rails(path))
    if images:
        shrink_images()
    objs = selection if selection is not None else list(bpy.context.scene.objects)
    for ob in objs:
        if ob in rails:
            continue
        ob.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_cameras=False,
        export_lights=False,
        export_image_format="AUTO" if images else "NONE",
    )
    print(f"[skate-park] exported {path}")
