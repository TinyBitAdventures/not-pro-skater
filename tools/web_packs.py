#!/usr/bin/env python3
"""Web builds ship the first levels in the main package (index.pck) and every later level as its own resource pack
(levels/<level>.pck next to index.html), fetched the first time someone plays there (Game.go -> _fetch_pack). That
keeps the first download under the 80 MB budget however many levels the game has.

This writes game/export_presets.cfg: the "Web" preset leaves every pack's files out, and one "Web pack <level>"
preset per pack holds that level, the textures only it uses, its event's characters and items, and its sky. Other
presets (desktop builds) are kept as they are. Run it after adding a level, then export (readme, Web build):

    python3 tools/web_packs.py
    cd game && godot --headless --export-release "Web" ../build/web/index.html
    for l in <pack levels>; do godot --headless --export-pack "Web pack $l" ../build/web/levels/$l.pck; done
"""

import glob
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GAME = os.path.join(ROOT, "game")
CFG = os.path.join(GAME, "export_presets.cfg")

BASE_LEVELS = ["neighborhood", "school"]          # in index.pck: the title and the first two events
PACKS = {                                         # level -> the event's own characters, items, sky and music
    "campus": {"characters": ["coworker_ana", "coworker_raj", "coworker_june"], "models": ["pizza"],
               "sky": "kloofendal_48d_partly_cloudy_puresky_1k.hdr", "music": "launchday"},
    "warehouse": {"characters": ["fan_zoe", "fan_mo", "fan_ike"], "models": ["merch"],
                  "sky": "kloofendal_38d_partly_cloudy_puresky_1k.hdr", "music": "recordrelease"},
    "downtown": {"characters": [], "models": ["coffee"], "sky": "qwantani_mid_morning_puresky_1k.hdr",
                 "music": "rushhour"},
    "backlot": {"characters": ["director_lou", "crew_rita", "crew_ray"], "models": ["script"],
                "sky": "qwantani_late_afternoon_puresky_1k.hdr", "music": "betweentakes"},
}
BASE_MUSIC = ["title", "cruise", "hype"]          # in index.pck: the menus, Birthday and the Skate-a-thon
BASE_SKIES = ["qwantani_late_afternoon_puresky_1k.hdr", "qwantani_mid_morning_puresky_1k.hdr"]


def images(level):
    with open(os.path.join(GAME, "assets", "levels", level + ".gltf")) as f:
        g = json.load(f)
    return {os.path.basename(im["uri"]) for im in g.get("images", []) if "uri" in im}


def rel(path):
    return os.path.relpath(path, GAME).replace(os.sep, "/")


def pack_files(level, spec, base_images):
    # imported resources only (the .gltf and the lightmaps): the glTF's .bin is just an import source, and the
    # .json sidecars come in through the preset's include_filter
    files = [rel(p) for p in sorted(glob.glob(os.path.join(GAME, "assets", "levels", level + ".*")))
             if os.path.exists(p + ".import")]
    files += ["assets/textures/" + i for i in sorted(images(level) - base_images)]
    for c in spec.get("characters", []):
        files.append(f"assets/characters/{c}.glb")
    for m in spec.get("models", []):
        files.append(f"assets/models/{m}.glb")
    if spec.get("sky") and spec["sky"] not in BASE_SKIES:
        files.append("assets/sky/" + spec["sky"])
    if spec.get("music"):
        files.append(f"assets/audio/music/{spec['music']}.ogg")
    return files


def pack_globs(level, spec, base_images):
    """What the main package leaves out for this pack (the extracted character textures too)."""
    g = [f"assets/levels/{level}.*"]
    g += ["assets/textures/" + i for i in sorted(images(level) - base_images)]
    for c in spec.get("characters", []):
        g += [f"assets/characters/{c}.glb", f"assets/characters/{c}_*"]
    for m in spec.get("models", []):
        g += [f"assets/models/{m}.glb", f"assets/models/{m}_*"]
    if spec.get("sky") and spec["sky"] not in BASE_SKIES:
        g.append("assets/sky/" + spec["sky"])
    if spec.get("music"):
        g.append(f"assets/audio/music/{spec['music']}.ogg")
    return g


def split_presets(text):
    """[(index, head block, options block)] from export_presets.cfg."""
    out = []
    for m in re.finditer(r"\[preset\.(\d+)\]\n(.*?)(?=\n\[preset\.\1\.options\])\n\[preset\.\1\.options\]\n(.*?)(?=\n\[preset\.\d+\]|\Z)",
                         text, re.S):
        out.append((int(m.group(1)), m.group(2).strip("\n"), m.group(3).strip("\n")))
    return out


def set_key(block, key, value):
    line = f"{key}={value}"
    if re.search(rf"^{re.escape(key)}=.*$", block, re.M):
        return re.sub(rf"^{re.escape(key)}=.*$", lambda _m: line, block, count=1, flags=re.M)
    return block + "\n" + line


def main():
    with open(CFG) as f:
        presets = split_presets(f.read())
    base_images = set()
    for lv in BASE_LEVELS:
        base_images |= images(lv)
    web = next(p for p in presets if re.search(r'^name="Web"$', p[1], re.M))
    kept = [p for p in presets if not re.search(r'^name="Web pack ', p[1], re.M) and p is not web]
    excludes = ["scenes/dev_*", "scripts/dev/*", "assets/brand/icon_1024.png"]   # the desktop app icon (1.4 MB)
    packs = []
    for level, spec in PACKS.items():
        excludes += pack_globs(level, spec, base_images)
        files = pack_files(level, spec, base_images)
        head = "\n".join([
            f'name="Web pack {level}"', 'platform="Web"', "runnable=false", "advanced_options=false",
            "dedicated_server=false", 'custom_features=""', 'export_filter="resources"',
            "export_files=PackedStringArray(" + ", ".join(f'"res://{p}"' for p in files) + ")",
            f'include_filter="assets/levels/{level}.*.json"',
            # the level's scripts, shaders and shared textures are already in index.pck
            'exclude_filter="scripts/*, shaders/*, scenes/*, assets/audio/sfx/*, assets/audio/ambience/*, '
            'assets/audio/jingles/*, ' + ", ".join(f"assets/audio/music/{m}.ogg" for m in BASE_MUSIC) + ', assets/fonts/*, assets/brand/*, '
            + ", ".join(sorted("assets/textures/" + i for i in base_images)) + '"',
            f'export_path="../build/web/levels/{level}.pck"', "patches=PackedStringArray()",
            'encryption_include_filters=""', 'encryption_exclude_filters=""', "seed=0", "encrypt_pck=false",
            "encrypt_directory=false", "script_export_mode=2",
        ])
        packs.append((head, web[2]))
        print(f"pack {level}: {len(files)} files")
    web_head = set_key(web[1], "exclude_filter", '"' + ", ".join(excludes) + '"')
    ordered = [(web_head, web[2])] + [(h, o) for (_i, h, o) in kept] + packs
    out = []
    for i, (h, o) in enumerate(ordered):
        out.append(f"[preset.{i}]\n\n{h}\n\n[preset.{i}.options]\n\n{o}\n")
    with open(CFG, "w") as f:
        f.write("\n".join(out))
    print(f"wrote {len(ordered)} presets")


if __name__ == "__main__":
    main()
