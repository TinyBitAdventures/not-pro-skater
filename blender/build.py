"""
Skate Park asset builder. Regenerates the level and character glTFs.

    blender --background --factory-startup --python blender/build.py -- [park] [skater]

With no targets it builds everything. Output goes to game/assets/{levels,models}.
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, "..", "game", "assets"))


def build_park():
    import park
    lib.reset_scene()
    park.build()
    lib.export(os.path.join(GAME, "levels", "community_park.glb"))


def build_skater():
    import skater
    lib.reset_scene()
    skater.build_skater()
    lib.export(os.path.join(GAME, "models", "skater.glb"))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    targets = args or ["skater", "park"]
    if "skater" in targets:
        build_skater()
    if "park" in targets:
        build_park()
