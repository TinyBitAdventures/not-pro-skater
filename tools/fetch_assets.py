#!/usr/bin/env python3
"""
Fetch the CC0 source assets the Blender builders use, into art/ (idempotent: existing files are kept).

    python3 tools/fetch_assets.py            # everything in MANIFEST
    python3 tools/fetch_assets.py --list     # what would be fetched

Textures come from ambientCG (1K JPG sets: Color, NormalGL, Roughness, Metalness, Opacity), models from
Poly Haven (glTF at 1K). Everything here is CC0; ART_CREDITS.md lists what is used where.
"""

import io
import json
import os
import sys
import urllib.request
import zipfile

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
ART = os.path.join(ROOT, "art")
KEEP = ("_Color.jpg", "_NormalGL.jpg", "_Roughness.jpg", "_Metalness.jpg", "_Opacity.jpg")

MANIFEST = {
    "textures": [
        "Concrete046", "Concrete044D", "Asphalt031", "Wood094", "Metal032", "PaintedMetal004", "Grass004",
        "Bark012", "Leaf001", "WoodSiding009", "RoofingTiles006", "Bricks101", "PavingStones128", "Ground037",
    ],
    "models": [
        "wooden_picnic_table", "painted_wooden_bench", "metal_trash_can", "street_lamp_02", "planter_box_01",
        "shrub_03", "potted_plant_04", "carrot_cake", "boombox", "round_wooden_table_02", "tree_stump_01",
    ],
}


def _get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "not-pro-skaters-asset-fetch"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return r.read()


def texture(asset_id):
    folder = os.path.join(ART, "textures", asset_id)
    if os.path.isdir(folder) and any(f.endswith("_Color.jpg") for f in os.listdir(folder)):
        return "have"
    meta = json.loads(_get(f"https://ambientcg.com/api/v2/full_json?id={asset_id}&include=downloadData"))
    found = meta["foundAssets"][0]
    link = next(x["downloadLink"] for x in found["downloadFolders"]["default"]["downloadFiletypeCategories"]["zip"]["downloads"]
                if x["attribute"] == "1K-JPG")
    os.makedirs(folder, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(_get(link))) as z:
        for name in z.namelist():
            if name.endswith(KEEP):
                with open(os.path.join(folder, os.path.basename(name)), "wb") as f:
                    f.write(z.read(name))
    return "fetched"


def model(asset_id):
    folder = os.path.join(ART, "models", asset_id)
    gltf_path = os.path.join(folder, f"{asset_id}_1k.gltf")
    if os.path.exists(gltf_path):
        return "have"
    files = json.loads(_get(f"https://api.polyhaven.com/files/{asset_id}"))
    g = files["gltf"]["1k"]["gltf"]
    os.makedirs(folder, exist_ok=True)
    with open(gltf_path, "wb") as f:
        f.write(_get(g["url"]))
    for rel, info in g.get("include", {}).items():
        out = os.path.join(folder, rel)
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with open(out, "wb") as f:
            f.write(_get(info["url"]))
    return "fetched"


def main():
    if "--list" in sys.argv:
        print(json.dumps(MANIFEST, indent=1))
        return
    for t in MANIFEST["textures"]:
        print(f"texture {t}: {texture(t)}")
    for m in MANIFEST["models"]:
        print(f"model   {m}: {model(m)}")


if __name__ == "__main__":
    main()
