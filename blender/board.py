"""
A real-sized skateboard: 8.0" x 31.5" popsicle deck with concave-free kicktails, grip tape on top, a printed
bottom, two trucks and four 54 mm urethane wheels. Nose toward +Y (Godot -Z), deck top at DECK_TOP.

    blender --background --factory-startup --python blender/build.py -- board
"""

import math

import bpy

from mathutils import Vector

from lib import box, cyl_between, mat, mesh_obj, empty

L = 0.80          # deck length
W = 0.205         # deck width
T = 0.012         # deck thickness
TRUCK_Y = 0.215   # truck (axle) positions from the centre
WHEEL_R = 0.027
WHEEL_W = 0.034
AXLE_Z = WHEEL_R
DECK_BOTTOM = 0.098
DECK_TOP = DECK_BOTTOM + T
KICK = 0.085      # height the kicktails rise at the very ends


def _deck_z(y):
    """Deck bottom height along its length: flat between the trucks, curving up into the kicktails."""
    a = abs(y)
    flat = TRUCK_Y + 0.02
    if a <= flat:
        return DECK_BOTTOM
    u = (a - flat) / (L / 2 - flat)
    return DECK_BOTTOM + KICK * (u ** 1.6)


def _outline(y):
    """Half width at y: straight sides with round nose and tail."""
    r = W / 2
    a = abs(y)
    end = L / 2 - r
    if a <= end:
        return r
    d = a - end
    return math.sqrt(max(r * r - d * d, 0.0))


def deck(parent):
    rows, cols = 48, 9
    top, bot = [], []
    ys = [-L / 2 + L * i / (rows - 1) for i in range(rows)]
    verts, faces, fmat = [], [], []
    for y in ys:
        hw = max(_outline(y), 0.004)
        z = _deck_z(y)
        for j in range(cols):
            x = -hw + 2 * hw * j / (cols - 1)
            verts.append((x, y, z + T))       # top
    n_top = len(verts)
    for y in ys:
        hw = max(_outline(y), 0.004)
        z = _deck_z(y)
        for j in range(cols):
            x = -hw + 2 * hw * j / (cols - 1)
            verts.append((x, y, z))           # bottom
    uvs = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            a = i * cols + j
            faces.append((a, a + 1, a + cols + 1, a + cols))
            fmat.append(0)
            uvs.append([(verts[k][0] / W + 0.5, verts[k][1] / L + 0.5) for k in (a, a + 1, a + cols + 1, a + cols)])
            b = n_top + a
            faces.append((b, b + cols, b + cols + 1, b + 1))
            fmat.append(1)
            uvs.append([(verts[k][0] / W + 0.5, verts[k][1] / L + 0.5) for k in (b, b + cols, b + cols + 1, b + 1)])
    # side walls (plywood edge)
    ring = [i * cols for i in range(rows)] + [(rows - 1) * cols + j for j in range(1, cols)] + \
           [i * cols + cols - 1 for i in range(rows - 2, -1, -1)] + [j for j in range(cols - 2, 0, -1)]
    for k in range(len(ring)):
        a, b = ring[k], ring[(k + 1) % len(ring)]
        faces.append((a, b, n_top + b, n_top + a))
        fmat.append(2)
        uvs.append([(0, 0), (0.05, 0), (0.05, 0.02), (0, 0.02)])
    grip = mat("Grip", "#1b1b1d")
    art = mat("DeckArt", "#2f7fd8")
    ply = mat("Ply", "#c9a071")
    ob = mesh_obj("Deck", verts, faces, [grip, art, ply], face_mats=fmat, smooth=[True] * len(faces), parent=parent,
                  uvs=uvs)
    for p in ob.data.polygons:
        p.use_smooth = p.material_index != 2
    return ob


def truck(parent, y):
    metal = mat("TruckMetal", "#b8bcc2")
    base_z = DECK_BOTTOM
    box("Baseplate", (0.055, 0.075, 0.012), (0, y, base_z - 0.006), metal, parent=parent)
    box("Kingpin", (0.03, 0.03, 0.04), (0, y, base_z - 0.03), metal, parent=parent)
    cyl_between("Hanger", (-0.07, y, AXLE_Z + 0.012), (0.07, y, AXLE_Z + 0.012), 0.012, metal, seg=10, parent=parent)
    cyl_between("Axle", (-0.105, y, AXLE_Z), (0.105, y, AXLE_Z), 0.004, metal, seg=8, parent=parent)
    urethane = mat("Wheel", "#f1ede2")
    for sx in (-1, 1):
        x0 = sx * 0.072
        x1 = sx * (0.072 + WHEEL_W)
        cyl_between("Wheel", (x0, y, AXLE_Z), (x1, y, AXLE_Z), WHEEL_R, urethane, seg=18, parent=parent)


def build():
    """One mesh with five materials (grip, art, ply, metal, urethane): the board is drawn in every shadow pass,
    so fifteen separate parts cost fifteen draw calls each time."""
    root = empty("BoardParts", (0, 0, 0), 0.0, None)
    deck(root)
    truck(root, TRUCK_Y)
    truck(root, -TRUCK_Y)
    parts = [o for o in bpy.context.scene.objects if o.parent == root]
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.select_set(True)
    deck_ob = next(o for o in parts if o.name.startswith("Deck"))
    bpy.context.view_layer.objects.active = deck_ob
    bpy.ops.object.join()
    deck_ob.name = "Board"
    bpy.data.objects.remove(root)
    return deck_ob
