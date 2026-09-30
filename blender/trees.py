"""
Light, believable park trees: a tapered, slightly bent trunk with a few branches (oak bark, CC0 Bark012) and a
crown of alpha-cut leaf cards. The cards use a leaf-cluster texture composited from CC0 Leaf001 and carry
normals that point out from the crown's centre, so the foliage shades like one soft mass instead of flat planes.
About 1-2k triangles a tree, so a park can have dozens and still run in a browser.
"""

import math
import os
import random

import bpy
from mathutils import Vector

import realism
from lib import link

GEN = os.path.join(realism.ART, "generated")
CLUSTER = os.path.join(GEN, "leaf_cluster.png")
_mats = {}


def make_leaf_cluster(size=512, leaves=90, seed=7):
    """Composite many scaled, rotated, tinted copies of Leaf001 into one RGBA card texture."""
    import numpy as np
    if os.path.exists(CLUSTER):
        return CLUSTER
    os.makedirs(GEN, exist_ok=True)
    base = os.path.join(realism.ART, "textures", "Leaf001", "Leaf001_1K-JPG")
    col = bpy.data.images.load(base + "_Color.jpg")
    opa = bpy.data.images.load(base + "_Opacity.jpg")
    w, h = col.size
    c = np.empty(w * h * 4, dtype=np.float32)
    o = np.empty(w * h * 4, dtype=np.float32)
    col.pixels.foreach_get(c)
    opa.pixels.foreach_get(o)
    c = c.reshape(h, w, 4)
    a = o.reshape(h, w, 4)[:, :, 0]
    out = np.zeros((size, size, 4), dtype=np.float32)
    rnd = random.Random(seed)
    ys, xs = np.mgrid[0:size, 0:size]
    for _ in range(leaves):
        # leaf centre inside a rough circle, bigger leaves near the middle
        r = rnd.random() ** 0.7 * size * 0.38
        t = rnd.random() * math.tau
        cx, cy = size / 2 + math.cos(t) * r, size / 2 + math.sin(t) * r
        s = rnd.uniform(0.11, 0.2) * size / w           # leaf size relative to the source image
        ang = rnd.random() * math.tau
        tint = np.array([rnd.uniform(0.75, 1.05), rnd.uniform(0.85, 1.1), rnd.uniform(0.7, 0.95)], dtype=np.float32)
        half = int(w * s * 0.75) + 2
        x0, x1 = max(0, int(cx) - half), min(size, int(cx) + half)
        y0, y1 = max(0, int(cy) - half), min(size, int(cy) + half)
        if x1 <= x0 or y1 <= y0:
            continue
        px = xs[y0:y1, x0:x1] - cx
        py = ys[y0:y1, x0:x1] - cy
        ca, sa = math.cos(ang), math.sin(ang)
        u = (ca * px + sa * py) / s + w / 2
        v = (-sa * px + ca * py) / s + h / 2
        inside = (u >= 0) & (u < w) & (v >= 0) & (v < h)
        ui = np.clip(u.astype(np.int32), 0, w - 1)
        vi = np.clip(v.astype(np.int32), 0, h - 1)
        la = np.where(inside, a[vi, ui], 0.0)
        lc = c[vi, ui, :3] * tint
        region = out[y0:y1, x0:x1]
        region[:, :, :3] = region[:, :, :3] * (1 - la[..., None]) + lc * la[..., None]
        region[:, :, 3] = np.maximum(region[:, :, 3], la)
    img = bpy.data.images.new("LeafCluster", size, size, alpha=True)
    img.pixels.foreach_set(out.ravel())
    img.filepath_raw = CLUSTER
    img.file_format = "PNG"
    img.save()
    return CLUSTER


def _leaf_material():
    if "leaf" in _mats:
        return _mats["leaf"]
    m = bpy.data.materials.new("TreeLeaves")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = bpy.data.images.load(make_leaf_cluster(), check_existing=True)
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
    bsdf.inputs["Roughness"].default_value = 0.7
    if hasattr(m, "blend_method"):
        m.blend_method = "CLIP"
    m.use_backface_culling = False
    m["bake"] = False
    _mats["leaf"] = m
    return m


def _bark_material():
    if "bark" not in _mats:
        _mats["bark"] = realism.material("bark")
    return _mats["bark"]


def _tube(verts, faces, uvs, fmat, path, radii, sides=8, mat=0):
    """A tapered tube along `path` (list of Vectors) with per-point radii. UVs wrap once around, 1 m up."""
    base = len(verts)
    along = 0.0
    for i, p in enumerate(path):
        d = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
        u = d.cross(ref).normalized()
        v = d.cross(u).normalized()
        if i > 0:
            along += (path[i] - path[i - 1]).length
        for k in range(sides + 1):
            a = math.tau * k / sides
            verts.append(p + (u * math.cos(a) + v * math.sin(a)) * radii[i])
    ring = sides + 1
    for i in range(len(path) - 1):
        for k in range(sides):
            a = base + i * ring + k
            faces.append((a, a + 1, a + ring + 1, a + ring))
            fmat.append(mat)
            ua, ub = k / sides, (k + 1) / sides
            va = sum((path[j + 1] - path[j]).length for j in range(i))
            vb = va + (path[i + 1] - path[i]).length
            uvs.append([(ua * 1.2, va), (ub * 1.2, va), (ub * 1.2, vb), (ua * 1.2, vb)])


def tree(name, loc, height=7.0, crown=3.2, seed=0, cards=110, parent=None):
    rnd = random.Random(seed)
    verts, faces, uvs, fmat = [], [], [], []
    normals = {}                                  # vertex index -> custom normal (leaf cards)
    lean = Vector((rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), 0.0))
    crown_base = height * rnd.uniform(0.38, 0.48)
    trunk = [Vector((0, 0, 0)) + lean * (t * t) + Vector((0, 0, crown_base * 1.15 * t)) for t in (0.0, 0.35, 0.7, 1.0)]
    r0 = 0.12 + height * 0.02
    _tube(verts, faces, uvs, fmat, trunk, [r0 * 1.25, r0, r0 * 0.85, r0 * 0.7])
    top = trunk[-1]
    centre = Vector((lean.x, lean.y, height - crown * 0.85))
    for b in range(rnd.randint(4, 6)):
        ang = math.tau * (b / 5.0 + rnd.uniform(-0.08, 0.08))
        out = Vector((math.cos(ang), math.sin(ang), rnd.uniform(0.6, 1.1))).normalized()
        start = trunk[2].lerp(top, rnd.uniform(0.2, 0.9))
        mid = start + out * crown * 0.45 + Vector((0, 0, 0.3))
        end = mid + (out + Vector((0, 0, 0.4))).normalized() * crown * 0.4
        _tube(verts, faces, uvs, fmat, [start, mid, end], [r0 * 0.5, r0 * 0.3, r0 * 0.12], sides=6)
    # leaf cards through an ellipsoid crown
    rx, rz = crown, crown * 0.8
    for i in range(cards):
        while True:
            p = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1)))
            if p.length <= 1.0:
                break
        p = centre + Vector((p.x * rx, p.y * rx, p.z * rz))
        n = Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.4, 1))).normalized()
        ref = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
        u = n.cross(ref).normalized()
        v = n.cross(u).normalized()
        s = rnd.uniform(0.75, 1.15) * (crown / 3.2) ** 0.5
        base = len(verts)
        for (a, b2) in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
            q = p + (u * a + v * b2) * s * 0.6
            verts.append(q)
            normals[len(verts) - 1] = (q - centre).normalized()
        faces.append((base, base + 1, base + 2, base + 3))
        fmat.append(1)
        uvs.append([(0, 0), (1, 0), (1, 1), (0, 1)])
    from lib import mesh_obj
    ob = mesh_obj(name, verts, faces, [_bark_material(), _leaf_material()], face_mats=fmat,
                  smooth=[True] * len(faces), parent=parent, loc=loc, uvs=uvs)
    me = ob.data
    # soft, crown-shaped shading for the leaves; the bark keeps its own smooth normals
    me.update()
    loop_normals = []
    for poly in me.polygons:
        for li in poly.loop_indices:
            vi = me.loops[li].vertex_index
            loop_normals.append(tuple(normals[vi]) if vi in normals else tuple(me.vertices[vi].normal))
    try:
        me.normals_split_custom_set(loop_normals)
    except Exception:
        pass
    return ob
