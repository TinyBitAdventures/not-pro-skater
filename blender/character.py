"""
Characters for Not Pro Skaters, built with MPFB (MakeHuman for Blender) from CC0 MakeHuman assets.

Grounded stylized: real proportions and PBR clothing, nudged toward a slightly bigger head and hands.
Each archetype is a recipe (body settings, stylizing targets, skin, hair, clothes); build() makes the human,
rigs it with MPFB's game-engine skeleton, bakes helpers and hidden body parts away and exports a skinned glb.

Needs the MPFB extension enabled in Blender's user preferences, so this runs WITHOUT --factory-startup:
    blender --background --python blender/character.py -- dev
Asset packs (CC0) live in MPFB's user data dir; see ART_CREDITS.md.
"""

import importlib
import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "game", "assets", "characters"))
MPFB = "bl_ext.blender_org.mpfb"

# Every archetype is inspired by a KIND of real skater who is not a pro (see docs/REBUILD_PLAN.md): original
# characters, not likenesses. Assets are named by MPFB folder (skins/<skin>, hair/<hair>, clothes/<name>, ...).
STYLIZE = {"head-scale-vert-incr": 0.35, "head-scale-horiz-incr": 0.3, "head-scale-depth-incr": 0.25,
           "l-hand-scale-incr": 0.35, "r-hand-scale-incr": 0.35}
TEXTURE_MAX = 1024        # the web build cannot afford MakeHuman's 2K / 4K maps
ARCHETYPES = {
    "dev": {
        "title": "The Dev",
        "macro": {"gender": 1.0, "age": 0.56, "muscle": 0.45, "weight": 0.45, "proportions": 0.6,
                  "height": 0.5, "cupsize": 0.5, "firmness": 0.5,
                  "race": {"asian": 0.1, "caucasian": 0.8, "african": 0.1}},
        "stylize": STYLIZE,
        "skin": "young_caucasian_male",
        "eyes": "brown",
        "eyebrows": "eyebrow001",
        "eyelashes": "eyelashes01",
        "hair": "short02",
        "clothes": ["male_casualsuit02", "shoes06"],
    },
    "musician": {
        "title": "The Musician",
        "macro": {"gender": 1.0, "age": 0.5, "muscle": 0.55, "weight": 0.5, "proportions": 0.6,
                  "height": 0.55, "cupsize": 0.5, "firmness": 0.5,
                  "race": {"asian": 0.0, "caucasian": 0.1, "african": 0.9}},
        "stylize": STYLIZE,
        "skin": "young_african_male",
        "eyes": "brown",
        "eyebrows": "eyebrow002",
        "eyelashes": "eyelashes02",
        "hair": "short04",
        "clothes": ["male_casualsuit05", "shoes05", "fedora_cocked"],
    },
    "vlogger": {
        "title": "The Vlogger",
        "macro": {"gender": 0.0, "age": 0.5, "muscle": 0.5, "weight": 0.42, "proportions": 0.6,
                  "height": 0.5, "cupsize": 0.45, "firmness": 0.6,
                  "race": {"asian": 0.8, "caucasian": 0.2, "african": 0.0}},
        "stylize": STYLIZE,
        "skin": "young_asian_female",
        "eyes": "brown",
        "eyebrows": "eyebrow009",
        "eyelashes": "eyelashes03",
        "hair": "ponytail01",
        "clothes": ["female_casualsuit01", "shoes05"],
    },
    "dad": {
        "title": "The Dad",
        "macro": {"gender": 1.0, "age": 0.72, "muscle": 0.45, "weight": 0.62, "proportions": 0.55,
                  "height": 0.55, "cupsize": 0.5, "firmness": 0.5,
                  "race": {"asian": 0.05, "caucasian": 0.9, "african": 0.05}},
        "stylize": STYLIZE,
        "skin": "middleage_caucasian_male",
        "eyes": "blue",
        "eyebrows": "eyebrow003",
        "eyelashes": "eyelashes01",
        "hair": "short03",
        "clothes": ["namuhekam_male_polo_shirt", "cortu_cargo_pants", "shoes02"],
    },
    # the birthday party's kids (they watch your tricks; not playable)
    "kid_maya": {
        "title": "Maya", "npc": True,
        "macro": {"gender": 0.0, "age": 0.16, "muscle": 0.5, "weight": 0.45, "proportions": 0.5,
                  "height": 0.5, "cupsize": 0.0, "firmness": 0.5,
                  "race": {"asian": 0.2, "caucasian": 0.3, "african": 0.5}},
        "stylize": {"head-scale-vert-incr": 0.15, "head-scale-horiz-incr": 0.15},
        "skin": "young_african_female", "eyes": "brown", "eyebrows": "eyebrow010", "eyelashes": "eyelashes02",
        "hair": "bob01", "clothes": ["female_casualsuit02", "shoes05"],
    },
    "kid_leo": {
        "title": "Leo", "npc": True,
        "macro": {"gender": 1.0, "age": 0.15, "muscle": 0.5, "weight": 0.5, "proportions": 0.5,
                  "height": 0.5, "cupsize": 0.5, "firmness": 0.5,
                  "race": {"asian": 0.1, "caucasian": 0.8, "african": 0.1}},
        "stylize": {"head-scale-vert-incr": 0.15, "head-scale-horiz-incr": 0.15},
        "skin": "young_caucasian_male", "eyes": "blue", "eyebrows": "eyebrow001", "eyelashes": "eyelashes01",
        "hair": "short01", "clothes": ["male_casualsuit04", "shoes06"],
    },
    "kid_sam": {
        "title": "Sam", "npc": True,
        "macro": {"gender": 1.0, "age": 0.17, "muscle": 0.5, "weight": 0.55, "proportions": 0.5,
                  "height": 0.55, "cupsize": 0.5, "firmness": 0.5,
                  "race": {"asian": 0.8, "caucasian": 0.2, "african": 0.0}},
        "stylize": {"head-scale-vert-incr": 0.15, "head-scale-horiz-incr": 0.15},
        "skin": "young_asian_male", "eyes": "brown", "eyebrows": "eyebrow002", "eyelashes": "eyelashes01",
        "hair": "short04", "clothes": ["male_casualsuit06", "shoes05"],
    },
    "actor": {
        "title": "The Actor",
        "macro": {"gender": 1.0, "age": 0.62, "muscle": 0.4, "weight": 0.66, "proportions": 0.5,
                  "height": 0.4, "cupsize": 0.5, "firmness": 0.5,
                  "race": {"asian": 0.05, "caucasian": 0.85, "african": 0.1}},
        "stylize": STYLIZE,
        "skin": "young_caucasian_male2",
        "eyes": "brown",
        "eyebrows": "eyebrow004",
        "eyelashes": "eyelashes01",
        "hair": "culturalibre_hair_02",
        "clothes": ["male_casualsuit03", "shoes03"],
    },
}


def _svc(name, cls):
    return getattr(importlib.import_module(f"{MPFB}.services.{name}"), cls)


def _enable_mpfb():
    if MPFB not in bpy.context.preferences.addons:
        bpy.ops.preferences.addon_enable(module=MPFB)


def _asset(kind, name, ext):
    """The .mhclo / .mhmat inside an MPFB asset folder, e.g. _asset("clothes", "shoes06", "mhclo")."""
    folder = _data(f"{kind}/{name}")
    for f in sorted(os.listdir(folder)):
        if f.endswith("." + ext):
            return os.path.join(folder, f)
    raise FileNotFoundError(f"{kind}/{name}/*.{ext}")


def _data(rel):
    ls = _svc("locationservice", "LocationService")
    for root in (ls.get_user_data(), ls.get_mpfb_data()):
        p = os.path.join(root, rel)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(rel)


def build(key):
    _enable_mpfb()
    hs = _svc("humanservice", "HumanService")
    ts = _svc("targetservice", "TargetService")
    es = _svc("exportservice", "ExportService")
    spec = ARCHETYPES[key]

    bpy.ops.wm.read_homefile(use_empty=True)
    basemesh = hs.create_human(macro_detail_dict=spec["macro"])
    for target, weight in spec.get("stylize", {}).items():
        path = ts.target_full_path(target)
        if path:
            ts.load_target(basemesh, path, weight=weight)
    # eyes, hair and clothes fit to the mesh's base shape: bake the body shape first or they sit on the
    # unshaped head (the eyes ended up on the forehead)
    ts.bake_targets(basemesh)
    hs.set_character_skin(_asset("skins", spec["skin"], "mhmat"), basemesh, skin_type="GAMEENGINE")
    hs.add_builtin_rig(basemesh, "game_engine")
    eyes = hs.add_mhclo_asset(_data("eyes/low-poly/low-poly.mhclo"), basemesh, asset_type="Eyes",
                              subdiv_levels=0, material_type="MAKESKIN")
    eye_mat = _data(f"eyes/materials/{spec['eyes']}.mhmat")
    try:
        _svc("materialservice", "MaterialService").create_and_assign_material_slots(eyes, eye_mat)
    except Exception:
        pass
    for kind, folder, name in (("Eyebrows", "eyebrows", spec["eyebrows"]), ("Eyelashes", "eyelashes", spec["eyelashes"]),
                               ("Hair", "hair", spec["hair"])):
        hs.add_mhclo_asset(_asset(folder, name, "mhclo"), basemesh, asset_type=kind, subdiv_levels=0, material_type="MAKESKIN")
    for name in spec["clothes"]:
        hs.add_mhclo_asset(_asset("clothes", name, "mhclo"), basemesh, asset_type="Clothes", subdiv_levels=0,
                           material_type="MAKESKIN")

    # bake shape keys and the "hidden under clothes" masks into real geometry, drop helper geometry
    es.bake_modifiers_remove_helpers(basemesh, bake_masks=True, bake_subdiv=False, remove_helpers=True)
    rig = basemesh.parent
    _fix_materials(rig)
    _shrink_textures(rig, npc=spec.get("npc", False))
    rig.name = "Rig"
    basemesh.name = "Body"
    _report(rig)
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, f"{key}.glb")
    bpy.ops.object.select_all(action="DESELECT")
    for ob in [rig] + list(rig.children_recursive):
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=False,
                              export_skins=True, export_morph=False, export_animations=False, export_yup=True,
                              export_image_format="AUTO", export_texcoords=True, export_normals=True)
    print(f"[character] exported {out}")


CUTOUT = ("eyebrow", "eyelash", "hair", "short", "long", "bob", "ponytail", "afro", "braid")


def _fix_materials(rig):
    """Skin and cloth textures carry alpha that is not meant as transparency (it showed the inside of the head
    and holes in the jeans): make them opaque. Hair, brows and lashes keep a hard alpha cutout."""
    for ob in rig.children_recursive:
        if ob.type != "MESH":
            continue
        cut = any(k in ob.name.lower() for k in CUTOUT)
        for m in ob.data.materials:
            if m is None or not m.use_nodes:
                continue
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            alpha = bsdf.inputs["Alpha"]
            if cut:
                m.blend_method = "CLIP" if hasattr(m, "blend_method") else None
                if hasattr(m, "surface_render_method"):
                    m.surface_render_method = "DITHERED"
                continue
            for link in list(alpha.links):
                m.node_tree.links.remove(link)
            alpha.default_value = 1.0
            if hasattr(m, "blend_method"):
                m.blend_method = "OPAQUE"
            if hasattr(m, "surface_render_method"):
                m.surface_render_method = "DITHERED"


def _shrink_textures(rig, npc=False):
    done = set()
    for ob in rig.children_recursive:
        if ob.type != "MESH":
            continue
        for m in ob.data.materials:
            if m is None or not m.use_nodes:
                continue
            for n in m.node_tree.nodes:
                img = getattr(n, "image", None)
                if img is None or img.name in done:
                    continue
                done.add(img.name)
                w, h = img.size
                # faces need the skin at 1K; clothes, hair, eyes and normal maps read fine at 512 at play distance;
                # bystanders (npc) are 512 throughout
                cap = 512
                if "skin" in img.name.lower() and not npc:
                    cap = TEXTURE_MAX
                if max(w, h) > cap:
                    k = cap / max(w, h)
                    img.scale(max(1, int(w * k)), max(1, int(h * k)))


def _report(rig):
    tris = 0
    for ob in rig.children_recursive:
        if ob.type == "MESH":
            ob.data.calc_loop_triangles()
            tris += len(ob.data.loop_triangles)
            mats = [m.name if m else "-" for m in ob.data.materials]
            print(f"[character]   {ob.name}: {len(ob.data.loop_triangles)} tris, materials {mats}")
    print(f"[character] {len(rig.data.bones)} bones, {tris} triangles")
    print("[character] bones:", ", ".join(b.name for b in rig.data.bones))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    for k in (args or list(ARCHETYPES)):
        build(k)
