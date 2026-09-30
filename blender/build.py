"""
Not Pro Skater asset builder: levels, the board and runtime items. Characters are built separately
(blender/character.py, which needs the MPFB extension).

    blender --background --factory-startup --python blender/build.py -- [neighborhood] [greybox] [board] [items]

With no targets it builds everything. Output goes to game/assets/{levels,models}. NOBAKE=1 skips the Cycles
light bake of the neighborhood (keeps the old lightmaps), SAMPLES sets its sample count (default 128).
"""

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import lib  # noqa: E402

GAME = os.path.normpath(os.path.join(HERE, "..", "game", "assets"))


def build_greybox():
    import greybox
    lib.reset_scene()
    greybox.build()
    lib.export(os.path.join(GAME, "levels", "greybox.glb"))


def build_neighborhood():
    import neighborhood
    lib.reset_scene()
    out = os.path.join(GAME, "levels", "neighborhood.gltf")
    neighborhood.build(out, bake=os.environ.get("NOBAKE", "") == "", samples=int(os.environ.get("SAMPLES", "128")))
    lib.export(out, images=True)


def build_school():
    import school
    lib.reset_scene()
    out = os.path.join(GAME, "levels", "school.gltf")
    school.build(out, bake=os.environ.get("NOBAKE", "") == "", samples=int(os.environ.get("SAMPLES", "128")))
    lib.export(out, images=True)


def build_items():
    """Runtime items the events move around (the birthday cake)."""
    import park_props
    lib.reset_scene()
    ob = park_props._import("carrot_cake")
    ob.location = (0, 0, 0)
    ob["library"] = False
    ob.name = "Cake"
    lib.export(os.path.join(GAME, "models", "cake.glb"), images=True)


def build_board():
    import board
    lib.reset_scene()
    board.build()
    lib.export(os.path.join(GAME, "models", "board.glb"))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    targets = args or ["greybox", "board", "items", "neighborhood"]
    if "greybox" in targets:
        build_greybox()
    if "board" in targets:
        build_board()
    if "school" in targets:
        build_school()
    if "items" in targets:
        build_items()
    if "neighborhood" in targets:
        build_neighborhood()
