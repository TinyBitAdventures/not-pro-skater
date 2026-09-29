"""
The spectator / bystander: the skater's chibi proportions, standing, no board. ONE model; Godot re-tints the
materials per person and poses the joints (arms up to cheer, a hop, legs folded when seated).

Rig (Empties are the joints; forward is +Y, the person faces +Y; feet on the z = 0 plane)
  Person             root, origin between the feet on the ground
    Body             hips, 0.70 up
      Torso          chest / shirt / hips block
      Head           pivot at the neck (0.44 above Body); face, hair, eyes, cheeks
      ArmL / ArmR    shoulder pivots at x = -0.22 / +0.22 (person's left is -X when facing +Y), arm hangs down -Z
        ForeL/ForeR  elbow pivots 0.22 below the shoulder (forearm, hand)
      LegL / LegR    hip pivots at x = -0.10 / +0.10; legs hang down -Z
        ShinL/ShinR  knee pivots 0.30 below the hip (calf, shoe)
Materials (re-tinted by name): Skin, Shirt, ShirtB, Pants, Shoe, Hair, Eye, Cheek.
"""

from lib import box, cyl_between, dome, empty, ico, loft_box, mat

SP = {
    "Skin": "#f2b48c", "Shirt": "#ff7a3d", "ShirtB": "#fff1d6", "Pants": "#3b4a78", "Shoe": "#f4f7fb",
    "Hair": "#5a3a24", "Eye": "#1b2033", "Cheek": "#ff8f8f",
}


def M(n):
    return mat(n, SP[n])


def build_person():
    root = empty("Person")
    body = empty("Body", (0, 0, 0.70), 0, root)
    torso = empty("Torso", (0, 0, 0), 0, body)
    loft_box("TorsoMesh", (0.28, 0.20), (0.40, 0.24), 0.0, 0.42, M("Shirt"), parent=torso)
    loft_box("TorsoBand", (0.335, 0.225), (0.35, 0.23), 0.19, 0.27, M("ShirtB"), parent=torso)
    loft_box("Hips", (0.30, 0.21), (0.29, 0.20), -0.08, 0.02, M("Pants"), parent=torso)

    head = empty("Head", (0, 0, 0.44), 0, body)
    ico("HeadMesh", (0, 0, 0.24), 0.27, M("Skin"), sub=1, squash=(1.0, 0.98, 0.95), parent=head, smooth=True)
    for sx in (-1, 1):
        ico(f"Eye{'L' if sx < 0 else 'R'}", (sx * 0.1, 0.235, 0.26), 0.05, M("Eye"), sub=0, squash=(0.8, 0.6, 1.3), parent=head)
        ico(f"Cheek{'L' if sx < 0 else 'R'}", (sx * 0.17, 0.2, 0.18), 0.04, M("Cheek"), sub=0, squash=(1, 0.5, 0.8), parent=head)
    dome("HairMesh", (0, -0.03, 0.29), 0.31, 0.04, M("Hair"), sub=1, squash=(1.0, 1.02, 0.95), parent=head)
    ico("HairBack", (0, -0.27, 0.24), 0.1, M("Hair"), sub=0, squash=(1.1, 1.0, 1.4), parent=head)

    for side, sx in (("L", -1), ("R", 1)):
        arm = empty(f"Arm{side}", (sx * 0.22, 0, 0.36), 0, body)
        cyl_between(f"Sleeve{side}", (0, 0, 0), (0, 0, -0.22), 0.062, M("Shirt"), r1=0.055, seg=6, parent=arm)
        fore = empty(f"Fore{side}", (0, 0, -0.22), 0, arm)
        cyl_between(f"Forearm{side}", (0, 0, 0), (0, 0, -0.2), 0.05, M("Skin"), r1=0.045, seg=6, parent=fore)
        ico(f"Hand{side}", (0, 0, -0.23), 0.065, M("Skin"), sub=0, parent=fore)

    for side, sx in (("L", -1), ("R", 1)):
        leg = empty(f"Leg{side}", (sx * 0.10, 0, -0.02), 0, body)
        cyl_between(f"Thigh{side}", (0, 0, 0), (0, 0, -0.3), 0.085, M("Pants"), r1=0.075, seg=6, parent=leg)
        shin = empty(f"Shin{side}", (0, 0, -0.3), 0, leg)
        cyl_between(f"Calf{side}", (0, 0, 0), (0, 0, -0.27), 0.07, M("Pants"), r1=0.062, seg=6, parent=shin)
        box(f"Shoe{side}", (0.12, 0.3, 0.1), (0, 0.05, -0.33), M("Shoe"), parent=shin)
    return root
