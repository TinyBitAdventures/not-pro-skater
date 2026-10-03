"""
Set the game's version everywhere it's written: game/project.godot (config/version: the daily update check compares
it with GitHub's latest release tag) and game/export_presets.cfg (the macOS bundle's version and short_version, the
Windows exe's file and product version).

    python3 tools/set_version.py 0.3.0
    python3 tools/set_version.py            (prints what each file says now)
"""

import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
PROJECT = os.path.join(ROOT, "game", "project.godot")
PRESETS = os.path.join(ROOT, "game", "export_presets.cfg")
PRESET_KEYS = ("application/version", "application/short_version", "application/file_version",
               "application/product_version")


def current():
    out = {}
    with open(PROJECT) as f:
        m = re.search(r'^config/version="([^"]*)"', f.read(), re.M)
        out["project.godot config/version"] = m.group(1) if m else None
    with open(PRESETS) as f:
        presets = f.read()
    for key in PRESET_KEYS:
        found = re.findall(r'^%s="([^"]*)"' % re.escape(key), presets, re.M)
        if found:
            out["export_presets " + key] = found
    return out


def set_version(v):
    if not re.fullmatch(r"\d+\.\d+\.\d+", v):
        sys.exit("version must look like 0.3.0")
    with open(PROJECT) as f:
        s = f.read()
    s, n = re.subn(r'^config/version="[^"]*"', 'config/version="%s"' % v, s, flags=re.M)
    if n != 1:
        sys.exit("project.godot: no config/version line")
    with open(PROJECT, "w") as f:
        f.write(s)
    with open(PRESETS) as f:
        s = f.read()
    # Windows: file and product version, added next to the product name if the preset doesn't have them yet
    for key in ("application/file_version", "application/product_version"):
        if not re.search(r"^%s=" % re.escape(key), s, re.M):
            s = re.sub(r'^(application/product_name="[^"]*")$', r'\1\n%s=""' % key, s, count=1, flags=re.M)
    for key in PRESET_KEYS:
        s = re.sub(r'^%s="[^"]*"' % re.escape(key), '%s="%s"' % (key, v), s, flags=re.M)
    with open(PRESETS, "w") as f:
        f.write(s)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        set_version(sys.argv[1].lstrip("v"))
    for k, val in current().items():
        print(f"{k}: {val}")
