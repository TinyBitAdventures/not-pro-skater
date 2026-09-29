"""
A small rubber-duck style duck for the pond. Origin on the water plane, forward +Y.

  Duck          root
    Body        hull, wing, tail (sits a little under the waterline so it floats)
    Head        pivot at the neck: head, beak, eyes (Godot can bob / turn it)
Materials: DuckBody (yellow), DuckWing (darker yellow), Orange (beak), Eye.
"""

from lib import box, empty, ico, loft_box, mat

DK = {"DuckBody": "#ffe25a", "DuckWing": "#f2c235", "Orange": "#ff8a3d", "Eye": "#1b2033"}


def M(n):
    return mat(n, DK[n])


def build_duck(root=None):
    root = root or empty("Duck")
    body = empty("Body", (0, 0, 0), 0, root)
    ico("DuckHull", (0, -0.02, 0.09), 0.2, M("DuckBody"), sub=1, squash=(0.95, 1.35, 0.8), parent=body, smooth=True)
    ico("DuckTail", (0, -0.29, 0.19), 0.09, M("DuckBody"), sub=0, squash=(0.6, 1.0, 1.2), parent=body)
    for sx in (-1, 1):
        ico(f"DuckWing{'L' if sx < 0 else 'R'}", (sx * 0.17, -0.04, 0.14), 0.11, M("DuckWing"), sub=0, squash=(0.35, 1.5, 0.9),
            parent=body)
    head = empty("Head", (0, 0.16, 0.24), 0, root)
    ico("DuckHead", (0, 0.03, 0.14), 0.13, M("DuckBody"), sub=1, parent=head, smooth=True)
    loft_box("DuckBeak", (0.11, 0.02), (0.06, 0.02), 0.06, 0.1, M("Orange"), center=(0, 0.17), parent=head)
    box("DuckBeakB", (0.1, 0.1, 0.035), (0, 0.19, 0.115), M("Orange"), parent=head)
    for sx in (-1, 1):
        ico(f"DuckEye{'L' if sx < 0 else 'R'}", (sx * 0.075, 0.11, 0.18), 0.03, M("Eye"), sub=0, parent=head)
    return root
