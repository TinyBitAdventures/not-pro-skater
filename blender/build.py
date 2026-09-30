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


# levels built by their own module's build(out, bake, samples), exported as glTF with shared textures
LEVELS = ("school", "campus", "warehouse", "downtown", "backlot")


def build_level(name):
    import importlib
    mod = importlib.import_module(name)
    lib.reset_scene()
    out = os.path.join(GAME, "levels", name + ".gltf")
    mod.build(out, bake=os.environ.get("NOBAKE", "") == "", samples=int(os.environ.get("SAMPLES", "128")))
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
    # Launch Day's pizzas: three boxes from the food truck, a little askew, a red band and a label on each lid
    lib.reset_scene()
    card = lib.mat("Cardboard", "#c29a62")
    band = lib.mat("PizzaRed", "#b3322b")
    ink = lib.mat("PizzaInk", "#f3ede0")
    stack = lib.empty("Pizza", (0, 0, 0), 0.0, None)
    for k, rz in enumerate((0.0, 0.12, -0.08)):
        lid = lib.empty(lib.uname("PizzaBox"), (0, 0, k * 0.055), rz, stack)
        lib.box(lib.uname("PizzaBox_body"), (0.4, 0.4, 0.05), (0, 0, 0.025), card, parent=lid)
        lib.box(lib.uname("PizzaBox_band"), (0.402, 0.09, 0.052), (0, 0.1, 0.025), band, parent=lid)
        lib.box(lib.uname("PizzaBox_label"), (0.14, 0.05, 0.001), (0, -0.08, 0.0505), ink, parent=lid)
    lib.export(os.path.join(GAME, "models", "pizza.glb"))
    # Record Release's merch: a taped-up box of records with the band's label
    lib.reset_scene()
    merch = lib.empty("Merch", (0, 0, 0), 0.0, None)
    box = lib.box
    card = lib.mat("Cardboard", "#b98f58")
    box(lib.uname("Merch_box"), (0.46, 0.34, 0.34), (0, 0, 0.17), card, parent=merch)
    box(lib.uname("Merch_tape"), (0.462, 0.07, 0.342), (0, 0, 0.17), lib.mat("Tape", "#d8c9a0"), parent=merch)
    box(lib.uname("Merch_label"), (0.2, 0.001, 0.12), (0.08, -0.1705, 0.2), lib.mat("MerchLabel", "#15171a"),
        parent=merch)
    box(lib.uname("Merch_disc"), (0.1, 0.0012, 0.1), (0.08, -0.1712, 0.2), lib.mat("MerchGold", "#e9c25a"),
        parent=merch)
    lib.export(os.path.join(GAME, "models", "merch.glb"))
    # Rush Hour's coffee order: a cardboard tray with four cups
    lib.reset_scene()
    tray = lib.empty("Coffee", (0, 0, 0), 0.0, None)
    lib.box(lib.uname("Coffee_tray"), (0.3, 0.3, 0.04), (0, 0, 0.02), lib.mat("Cardboard", "#b98f58"), parent=tray)
    cup = lib.mat("CupWhite", "#efece6")
    lid = lib.mat("CupLid", "#3a2a20")
    sleeve = lib.mat("CupSleeve", "#9c6b3f")
    for (x, y) in ((-0.07, -0.07), (0.07, -0.07), (-0.07, 0.07), (0.07, 0.07)):
        lib.cyl_z(lib.uname("Coffee_cup"), (x, y, 0.02), 0.15, 0.04, cup, r1=0.048, seg=16, parent=tray)
        lib.cyl_z(lib.uname("Coffee_sleeve"), (x, y, 0.07), 0.05, 0.0445, sleeve, r1=0.046, seg=16, parent=tray)
        lib.cyl_z(lib.uname("Coffee_lid"), (x, y, 0.17), 0.02, 0.05, lid, r1=0.045, seg=16, parent=tray)
    lib.export(os.path.join(GAME, "models", "coffee.glb"))
    # Between Takes' script pages: a clipboard with a stack of pages
    lib.reset_scene()
    clip = lib.empty("Script", (0, 0, 0), 0.0, None)
    lib.box(lib.uname("Script_board"), (0.24, 0.33, 0.012), (0, 0, 0.006), lib.mat("Clipboard", "#8a5a36"), parent=clip)
    lib.box(lib.uname("Script_pages"), (0.21, 0.28, 0.02), (0, -0.01, 0.022), lib.mat("Paper", "#f2efe6"), parent=clip)
    lib.box(lib.uname("Script_clip"), (0.1, 0.04, 0.02), (0, 0.15, 0.03), lib.mat("ClipSteel", "#b9bcc0"), parent=clip)
    lib.box(lib.uname("Script_title"), (0.14, 0.03, 0.001), (0, 0.07, 0.0325), lib.mat("Ink", "#1d1f22"), parent=clip)
    lib.export(os.path.join(GAME, "models", "script.glb"))


def build_board():
    import board
    lib.reset_scene()
    board.build()
    lib.export(os.path.join(GAME, "models", "board.glb"))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    targets = args or ["greybox", "board", "items", "neighborhood", *LEVELS]
    if "greybox" in targets:
        build_greybox()
    if "board" in targets:
        build_board()
    for name in LEVELS:
        if name in targets:
            build_level(name)
    if "items" in targets:
        build_items()
    if "neighborhood" in targets:
        build_neighborhood()
