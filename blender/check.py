"""
Proof script for the dressing pass:  blender --background --factory-startup --python blender/check.py
Builds the park, then checks every NEW solid piece (dressing.py) against the ring, the four spokes, the plaza, every
existing piece (skate obstacles, trees, benches...) and each other, checks the paint decals against the plaza
obstacles and the spectator markers against every footprint, and prints triangle counts.
"""
import collections
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bpy  # noqa: E402

import dressing  # noqa: E402
import fp  # noqa: E402
import lib  # noqa: E402
import park  # noqa: E402


def main():
    lib.reset_scene()
    park.build()
    bpy.context.view_layer.update()
    allp = fp.pieces()
    new, old, air, flat, conv = [], [], [], [], []
    for p in allp:
        if p.get("converted"):
            conv.append(p)
        elif p.get("dressing"):
            (air if p.get("air") else flat if p.get("flat") else new).append(p)
        else:
            old.append(p)
    hulls = {p.name: fp.piece_hull(p, update=False) for p in allp}
    print(f"[check] pieces: old {len(old)}, new solid {len(new)}, aerial/decor {len(air)}, flat {len(flat)}, converted trees {len(conv)}")
    bad = []
    # 1) new vs paths (ring / spokes / plaza)
    allow = {"bunting": ("spoke", "plaza")}
    for p in new:
        why = fp.hits_paths(hulls[p.name], 0.5)
        if why:
            bad.append(f"PATH {p.name} touches {why}")
    # 2) new vs old (obstacles, trees, benches, fences, houses ...)
    kinds = collections.Counter()
    for p in new:
        for q in old:
            if fp.overlaps(hulls[p.name], hulls[q.name], 0.0):
                bad.append(f"OVERLAP {p.name} x {q.name}")
    # 3) new vs new
    for i, p in enumerate(new):
        for q in new[i + 1:]:
            if fp.overlaps(hulls[p.name], hulls[q.name], 0.0):
                bad.append(f"OVERLAP-NEW {p.name} x {q.name}")
    # 4) converted trees vs new pieces (they replaced old trees in place)
    for p in new:
        for q in conv:
            if fp.overlaps(hulls[p.name], hulls[q.name], 0.0):
                bad.append(f"OVERLAP {p.name} x converted {q.name}")
    # 5) paint decals vs plaza obstacles
    obs = []
    for q in old + new:
        k = fp.piece_kind(q)
        if k in ("fence", "banner", "tree", "bush"):
            continue
        x0, y0, x1, y1 = fp.bbox(hulls[q.name])
        if abs((x0 + x1) / 2) < 20 and abs((y0 + y1) / 2) < 18:
            obs.append((q.name, (x0, y0, x1, y1)))
    n_decal = n_bad_decal = 0
    for ob in bpy.data.objects:
        if ob.name.startswith("PaintDecals"):
            for pg in ob.data.polygons:
                n_decal += 1
                c = pg.center
                hit = [n for n, (x0, y0, x1, y1) in obs if x0 - 0.05 <= c.x <= x1 + 0.05 and y0 - 0.05 <= c.y <= y1 + 0.05]
                if hit:
                    n_bad_decal += 1
                    bad.append(f"DECAL centre ({c.x:.1f},{c.y:.1f}) inside {hit[0]}")
    # 6) spectator markers vs every footprint (seat markers sit on their stand by design)
    n_mark = n_mark_bad = 0
    for ob in bpy.data.objects:
        if ob.name.startswith("Spectator_"):
            n_mark += 1
            x, y = ob.location.x, ob.location.y
            for q in allp:
                if fp.piece_kind(q) in ("hedge", "fence"):
                    continue
                if ob.location.z > 0.2 and fp.piece_kind(q) in ("bleachers",):
                    continue
                if fp.inside(hulls[q.name], x, y, 0.0):
                    n_mark_bad += 1
                    bad.append(f"MARKER {ob.name} inside {q.name}")
            if fp.hits_paths([(x, y)] * 3, 0.0):
                n_mark_bad += 1
                bad.append(f"MARKER {ob.name} on {fp.hits_paths([(x, y)] * 3, 0.0)}")
    # 7) car routes vs parked cars (every route point + 5 samples per segment must be > 1.2 m from any car footprint)
    cars = [hulls[p.name] for p in new if fp.piece_kind(p) == "car"]
    rt = collections.defaultdict(list)
    for ob in bpy.data.objects:
        if ob.name.startswith("CarRoute_"):
            rt[ob.name.split("_")[1]].append((int(ob.name.split("_")[2]), ob.location.x, ob.location.y))
    nsamp = 0
    for k, pts in rt.items():
        pts.sort()
        for i in range(len(pts)):
            a, b = pts[i], pts[(i + 1) % len(pts)]
            for t in range(6):
                x, y = a[1] + (b[1] - a[1]) * t / 6, a[2] + (b[2] - a[2]) * t / 6
                nsamp += 1
                for h in cars:
                    if fp.inside(h, x, y, 1.2):
                        bad.append(f"ROUTE {k} sample ({x:.1f},{y:.1f}) within 1.2 m of a parked car")
    print(f"[check] car routes: {dict((k, len(v)) for k, v in rt.items())} points, {nsamp} samples checked against {len(cars)} parked cars")
    print(f"[check] paint decals {n_decal}, inside obstacles {n_bad_decal}; standing spectators {n_mark}, bad {n_mark_bad}")
    print(f"[check] VIOLATIONS: {len(bad)}")
    for b in bad[:60]:
        print("   ", b)
    # triangle counts
    per = collections.defaultdict(list)
    for p in new + air + flat:
        per[fp.piece_kind(p)].append(fp.tri_count(p, True))
    print("[check] tris per new piece kind (count, min, max):")
    for k, v in sorted(per.items()):
        print(f"    {k:16s} n={len(v):3d} min={min(v):5d} max={max(v):5d}")
    tot = sum(fp.tri_count(o) for o in bpy.data.objects if o.parent is None)
    paint = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.data.objects if o.name.startswith("PaintDecals"))
    print(f"[check] level tris total {tot} (baseline 41498); paint tris {paint}; objects {len(bpy.data.objects)} (baseline 2947)")
    import backdrop
    import car
    import duck
    import spectator
    for label, fn in (("spectator.glb", spectator.build_person), ("duck.glb", duck.build_duck),
                      ("car_hatch.glb", lambda: car.build_car("hatch")), ("car_van.glb", lambda: car.build_car("van")),
                      ("car_pickup.glb", lambda: car.build_car("pickup")), ("backdrop.glb", backdrop.build)):
        lib.reset_scene()
        r = fn()
        print(f"[check] model {label}: {fp.tri_count(r)} tris")
    lib.reset_scene()
    park.build()
    bpy.context.view_layer.update()
    ring_ok = all(fp.hits_paths(hulls[p.name], 0.0) == [] for p in new)
    print("[check] every new solid piece clear of ring/spokes/plaza:", ring_ok)
    for m in dressing.LOG.get("_notes", []):
        if "skipped" in m and "tree" not in m:
            print("   note:", m)


main()
