"""
Cartoon cars: hatchback, van and pickup, about 4.2 m long, origin at the ground centre, forward +Y.

  Car
    WheelFL / WheelFR / WheelBL / WheelBR   pivots at the axle (spin about local X); tyre + hub are children
    body, cabin, glass (Window), lights (Lamp), bumpers (Ink / Metal)
`build_car(variant, root, pivots)`: variant "hatch" | "van" | "pickup". With pivots=False the wheels are plain
meshes (used for the static parked cars baked into the level).
Materials: CarBody (Godot re-tints), Window, Lamp, Ink, Metal, MetalDk, Red, White.
"""

from lib import box, cyl_between, empty, mat, prism, uname
from pieces import PALETTE

CAR = {
    "CarBody": "#ff5a5a", "Window": "#8fd3ff", "Lamp": "#fff3b0", "Ink": "#20263a", "Metal": "#bcc7d8",
    "MetalDk": "#7d8aa0", "Red": "#ff5a5a", "White": "#f4f7fb", "Orange": "#ff8a3d",
}


_body = ["CarBody"]


def M(n):
    if n == "CarBody":
        n = _body[0]
    return mat(n, CAR.get(n) or PALETTE[n])


def _wheels(root, pivots, y_f, y_b, x=0.83, r=0.37, w=0.26):
    for name, sx, y in (("WheelFL", -1, y_f), ("WheelFR", 1, y_f), ("WheelBL", -1, y_b), ("WheelBR", 1, y_b)):
        if pivots:
            piv = empty(name, (sx * x, y, r), 0, root)
            base = (0, 0, 0)
        else:
            piv, base = root, (sx * x, y, r)
        bx, by, bz = base
        cyl_between(uname("Tyre"), (bx - w / 2, by, bz), (bx + w / 2, by, bz), r, M("Ink"), seg=8, smooth=False, parent=piv)
        cyl_between(uname("Hub"), (bx + sx * (w / 2 - 0.02), by, bz), (bx + sx * (w / 2 + 0.03), by, bz), r * 0.55, M("Metal"),
                    seg=6, smooth=False, parent=piv)


def _pillar(root, p0, p1):
    for sx in (-1, 1):
        cyl_between(uname("Pillar"), (sx * 0.8, p0[0], p0[1]), (sx * 0.8, p1[0], p1[1]), 0.045, M("CarBody"), seg=4,
                    smooth=False, caps=False, parent=root)


def _lights(root, y_f=2.12, y_b=-2.12, z_head=0.78, z_tail=0.78, half=0.62):
    for sx in (-1, 1):
        box(uname("Headlight"), (0.3, 0.07, 0.17), (sx * half, y_f, z_head), M("Lamp"), parent=root)
        box(uname("Taillight"), (0.3, 0.07, 0.17), (sx * (half + 0.08), y_b, z_tail), M("Red"), parent=root)
    box(uname("Grille"), (0.8, 0.05, 0.2), (0, y_f + 0.01, z_head - 0.1), M("Ink"), parent=root)
    box(uname("BumperF"), (1.75, 0.16, 0.13), (0, y_f - 0.02, 0.44), M("Ink"), parent=root)
    box(uname("BumperB"), (1.75, 0.16, 0.13), (0, y_b + 0.02, 0.44), M("Ink"), parent=root)
    box(uname("Plate"), (0.42, 0.03, 0.14), (0, y_b - 0.04, 0.6), M("White"), parent=root)


def _mirrors(root, y=0.75, z=1.14):
    for sx in (-1, 1):
        box(uname("Mirror"), (0.14, 0.12, 0.1), (sx * 1.0, y, z), M("Ink"), parent=root)


def hatch(root):
    body = [(-2.0, 0.36), (2.0, 0.36), (2.12, 0.52), (2.12, 0.80), (1.88, 0.98), (-1.9, 0.98), (-2.12, 0.80), (-2.12, 0.52)]
    prism(uname("CarLower"), body, -0.9, 0.9, [M("CarBody")], [0] * 8, [False] * 8, cap_mat=0, parent=root)
    cab = [(-1.3, 0.96), (-0.9, 1.56), (0.5, 1.56), (1.0, 0.96)]
    prism(uname("CarCabin"), cab, -0.8, 0.8, [M("CarBody"), M("Window")], [1, 0, 1, 0], [False] * 4, cap_mat=1, parent=root)
    box(uname("Roof"), (1.72, 1.7, 0.08), (0, -0.2, 1.58), M("CarBody"), parent=root)
    _pillar(root, (1.0, 0.96), (0.5, 1.56))
    _pillar(root, (-1.3, 0.96), (-0.9, 1.56))
    for sx in (-1, 1):
        box(uname("BPillar"), (0.06, 0.1, 0.6), (sx * 0.8, -0.2, 1.27), M("CarBody"), parent=root)
    _lights(root)
    _mirrors(root)
    return dict(y_f=1.3, y_b=-1.3)


def van(root):
    body = [(-2.0, 0.36), (2.0, 0.36), (2.12, 0.52), (2.12, 0.86), (1.85, 1.02), (1.25, 1.06), (0.8, 1.98), (-1.95, 2.02),
            (-2.12, 1.88), (-2.12, 0.52)]
    # edge materials: 0 body, 1 windscreen glass (edge from (1.25,1.06) to (0.8,1.98))
    em = [0, 0, 0, 0, 0, 1, 0, 0, 0, 0]
    prism(uname("VanBody"), body, -0.9, 0.9, [M("CarBody"), M("Window")], em, [False] * 10, cap_mat=0, parent=root)
    for sx in (-1, 1):
        box(uname("VanSideGlass"), (0.05, 1.35, 0.5), (sx * 0.91, 0.1, 1.55), M("Window"), parent=root)
        box(uname("VanSideGlass"), (0.05, 0.5, 0.5), (sx * 0.91, -1.45, 1.55), M("Window"), parent=root)
        box(uname("VanStripe"), (0.04, 3.2, 0.1), (sx * 0.91, -0.3, 0.98), M("White"), parent=root)
    box(uname("VanRearGlass"), (1.3, 0.05, 0.5), (0, -2.13, 1.55), M("Window"), parent=root)
    for sx in (-1, 1):
        box(uname("VanRoofRack"), (0.07, 2.6, 0.07), (sx * 0.6, -0.8, 2.07), M("MetalDk"), parent=root)
    for y in (-1.8, -0.4):
        box(uname("VanRoofRack"), (1.3, 0.07, 0.07), (0, y, 2.07), M("MetalDk"), parent=root)
    _lights(root, z_head=0.8, z_tail=0.85)
    _mirrors(root, y=0.95, z=1.32)
    return dict(y_f=1.35, y_b=-1.3)


def pickup(root):
    body = [(-2.0, 0.4), (2.0, 0.4), (2.12, 0.55), (2.12, 0.84), (1.88, 1.0), (0.6, 1.02), (0.6, 0.98), (-0.45, 0.98),
            (-0.45, 0.9), (-2.12, 0.9), (-2.12, 0.55)]
    prism(uname("PickupBody"), body, -0.9, 0.9, [M("CarBody")], [0] * len(body), [False] * len(body), cap_mat=0, parent=root)
    cab = [(-0.55, 0.96), (-0.3, 1.66), (0.25, 1.66), (0.7, 0.96)]
    prism(uname("PickupCab"), cab, -0.8, 0.8, [M("CarBody"), M("Window")], [1, 0, 1, 0], [False] * 4, cap_mat=1, parent=root)
    box(uname("Roof"), (1.72, 0.85, 0.08), (0, -0.02, 1.68), M("CarBody"), parent=root)
    for sx in (-1, 1):
        box(uname("BedWall"), (0.1, 1.68, 0.42), (sx * 0.85, -1.3, 1.12), M("CarBody"), parent=root)
    box(uname("Tailgate"), (1.8, 0.1, 0.42), (0, -2.07, 1.12), M("CarBody"), parent=root)
    box(uname("BedFront"), (1.8, 0.1, 0.55), (0, -0.5, 1.18), M("CarBody"), parent=root)
    box(uname("BedFloor"), (1.6, 1.6, 0.04), (0, -1.3, 0.93), M("MetalDk"), parent=root)
    _pillar(root, (0.7, 0.96), (0.25, 1.66))
    _lights(root)
    _mirrors(root, y=0.55, z=1.16)
    return dict(y_f=1.35, y_b=-1.35)


VARIANTS = dict(hatch=hatch, van=van, pickup=pickup)


def build_car(variant="hatch", root=None, pivots=True, body="CarBody"):
    """body = material name of the paintwork (CarBody for the model; CarBlue, CarTeal... for parked cars)."""
    _body[0] = body
    root = root or empty("Car")
    ax = VARIANTS[variant](root)
    _wheels(root, pivots, ax["y_f"], ax["y_b"])
    return root
