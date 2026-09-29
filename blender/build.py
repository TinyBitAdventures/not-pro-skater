"""
Skate Park asset builder. Regenerates the level and character glTFs.

    blender --background --factory-startup --python blender/build.py -- [park] [greybox] [skater] [spectator] [car] [duck] [backdrop]

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


def build_greybox():
    import greybox
    lib.reset_scene()
    greybox.build()
    lib.export(os.path.join(GAME, "levels", "greybox.glb"))


def build_looktest():
    import looktest
    lib.reset_scene()
    out = os.path.join(GAME, "levels", "looktest.glb")
    looktest.build(out, bake=os.environ.get("NOBAKE", "") == "", samples=int(os.environ.get("SAMPLES", "128")))
    lib.export(out, images=True)


def build_skater():
    import skater
    lib.reset_scene()
    skater.build_skater()
    lib.export(os.path.join(GAME, "models", "skater.glb"))


def build_spectator():
    import spectator
    lib.reset_scene()
    spectator.build_person()
    lib.export(os.path.join(GAME, "models", "spectator.glb"))


def build_car():
    import car
    for variant in ("hatch", "van", "pickup"):
        lib.reset_scene()
        car.build_car(variant)
        lib.export(os.path.join(GAME, "models", f"car_{variant}.glb"))


def build_backdrop():
    import backdrop
    lib.reset_scene()
    backdrop.build()
    lib.export(os.path.join(GAME, "levels", "backdrop.glb"))


def build_duck():
    import duck
    lib.reset_scene()
    duck.build_duck()
    lib.export(os.path.join(GAME, "models", "duck.glb"))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    targets = args or ["skater", "spectator", "car", "duck", "backdrop", "park", "greybox"]
    if "skater" in targets:
        build_skater()
    if "spectator" in targets:
        build_spectator()
    if "car" in targets:
        build_car()
    if "duck" in targets:
        build_duck()
    if "backdrop" in targets:
        build_backdrop()
    if "park" in targets:
        build_park()
    if "greybox" in targets:
        build_greybox()
    if "looktest" in targets:
        build_looktest()
