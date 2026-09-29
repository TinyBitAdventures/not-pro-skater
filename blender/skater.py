"""
The skater: a chunky, chibi-proportioned rider on a board.

Rig (Empties are the joints; Godot poses them procedurally, see skater_visual.gd):
  Skater
    Board            wheels on the ground plane, deck along +Y (travel direction)
    Body             hips, origin 0.62 up. Chest faces +X (regular stance: left foot forward)
      Torso  Head  ArmL/ArmR (+ ForeL/ForeR)  LegL/LegR (+ ShinL/ShinR, each with its shoe)
Material names are re-tinted per character in Godot: Skin, Shirt, ShirtB, Pants, Shoe, Sole, Helmet,
HelmetB, Pad, Hair, Eye, Cheek, Deck, Grip, Truck, Wheel.
"""

import math

from lib import (box, cyl_between, cyl_z, dome, empty, ico, loft_box, mat, prism)

SK = {
    "Skin": "#f2b48c", "Shirt": "#ff7a3d", "ShirtB": "#fff1d6", "Pants": "#3b4a78", "Shoe": "#f4f7fb",
    "Sole": "#20263a", "Helmet": "#3d9bff", "HelmetB": "#ffd23f", "Pad": "#2a3050", "Hair": "#5a3a24",
    "Eye": "#1b2033", "Cheek": "#ff8f8f", "Deck": "#ff5a5a", "Grip": "#2b3148", "Truck": "#bcc7d8",
    "Wheel": "#fff1d6",
}


def M(n):
    return mat(n, SK[n])


def build_skater():
    root = empty("Skater")

    # ---------------- board ----------------
    board = empty("Board", (0, 0, 0), 0, root)
    prof = [(-0.44, 0.16), (-0.36, 0.115), (0.36, 0.115), (0.44, 0.16), (0.44, 0.19), (0.36, 0.145), (-0.36, 0.145),
            (-0.44, 0.19)]
    prism("DeckMesh", prof, -0.125, 0.125, [M("Deck"), M("Grip")], [0, 0, 0, 0, 1, 1, 1, 0], [False] * 8, cap_mat=0,
          parent=board)
    for sy in (-1, 1):
        y = sy * 0.26
        box(f"Truck{'F' if sy > 0 else 'B'}", (0.17, 0.07, 0.035), (0, y, 0.098), M("Truck"), parent=board)
        for sx in (-1, 1):
            cyl_between(f"Wheel{sx}{sy}", (sx * 0.135 - 0.03, y, 0.057), (sx * 0.135 + 0.03, y, 0.057), 0.057, M("Wheel"),
                        seg=10, parent=board)

    # ---------------- body ----------------
    body = empty("Body", (0, 0, 0.62), 0, root)
    torso = empty("Torso", (0, 0, 0), 0, body)
    loft_box("TorsoMesh", (0.22, 0.28), (0.26, 0.4), 0.0, 0.42, M("Shirt"), parent=torso)
    loft_box("TorsoBand", (0.245, 0.335), (0.255, 0.36), 0.2, 0.28, M("ShirtB"), parent=torso)
    loft_box("Hips", (0.23, 0.30), (0.22, 0.28), -0.08, 0.02, M("Pants"), parent=torso)

    # head (faces +Y, the direction of travel)
    head = empty("Head", (0, 0, 0.44), 0, body)
    ico("HeadMesh", (0, 0, 0.24), 0.27, M("Skin"), sub=2, parent=head, smooth=True)
    for sx in (-1, 1):
        ico(f"Eye{sx}", (sx * 0.1, 0.235, 0.26), 0.05, M("Eye"), sub=1, squash=(0.8, 0.6, 1.25), parent=head, smooth=True)
        ico(f"Cheek{sx}", (sx * 0.17, 0.2, 0.19), 0.04, M("Cheek"), sub=1, squash=(1, 0.5, 0.8), parent=head, smooth=True)
        ico(f"Ear{sx}", (sx * 0.265, 0.0, 0.22), 0.06, M("Skin"), sub=1, squash=(0.6, 0.9, 1.0), parent=head, smooth=True)
    dome("HelmetMesh", (0, -0.015, 0.29), 0.32, 0.03, M("Helmet"), sub=2, squash=(1.0, 1.02, 0.92), parent=head)
    box("HelmetStripe", (0.09, 0.6, 0.03), (0, -0.015, 0.575), M("HelmetB"), parent=head)
    ico("Ponytail", (0, -0.36, 0.3), 0.11, M("Hair"), sub=1, squash=(0.8, 1.0, 1.4), parent=head, smooth=True)

    # arms (shoulders at +-Y since the chest faces +X)
    for side, sy in (("L", 1), ("R", -1)):
        arm = empty(f"Arm{side}", (0, sy * 0.22, 0.36), 0, body)
        cyl_between(f"Sleeve{side}", (0, 0, 0), (0, 0, -0.22), 0.062, M("Shirt"), r1=0.055, seg=8, parent=arm)
        ico(f"Shoulder{side}", (0, 0, 0), 0.07, M("Shirt"), sub=1, parent=arm, smooth=True)
        fore = empty(f"Fore{side}", (0, 0, -0.22), 0, arm)
        cyl_between(f"Forearm{side}", (0, 0, 0), (0, 0, -0.2), 0.05, M("Skin"), r1=0.045, seg=8, parent=fore)
        box(f"ElbowPad{side}", (0.11, 0.11, 0.09), (0, 0, -0.01), M("Pad"), parent=fore)
        ico(f"Hand{side}", (0, 0, -0.23), 0.065, M("Skin"), sub=1, parent=fore, smooth=True)

    # legs (hips slightly apart along Y); shoes point along +X across the board
    for side, sy in (("L", 1), ("R", -1)):
        leg = empty(f"Leg{side}", (0, sy * 0.1, -0.02), 0, body)
        cyl_between(f"Thigh{side}", (0, 0, 0), (0, 0, -0.3), 0.085, M("Pants"), r1=0.075, seg=8, parent=leg)
        shin = empty(f"Shin{side}", (0, 0, -0.3), 0, leg)
        cyl_between(f"Calf{side}", (0, 0, 0), (0, 0, -0.27), 0.07, M("Pants"), r1=0.062, seg=8, parent=shin)
        box(f"KneePad{side}", (0.16, 0.14, 0.11), (0.03, 0, 0.0), M("Pad"), parent=shin)
        box(f"Shoe{side}", (0.3, 0.12, 0.1), (0.05, 0, -0.32), M("Shoe"), parent=shin)
        box(f"Sole{side}", (0.31, 0.125, 0.03), (0.05, 0, -0.365), M("Sole"), parent=shin)
    return root
