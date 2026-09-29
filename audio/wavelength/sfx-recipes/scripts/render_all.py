"""Render jobs one after another (a single wavelength process at a time). usage: render_all.py stem [stem ...] | all  [--force]"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(__file__))
from specs import *
from prep_jobs import needed
WL = os.path.join(HOME, "Documents/wavelength/build/wavelength")
args = [a for a in sys.argv[1:] if not a.startswith("--")]
force = "--force" in sys.argv
stems = list(needed()) if args == ["all"] else args
for stem in stems:
    out = os.path.join(WORK, "raw", stem)
    if os.path.exists(os.path.join(out, "mix.wav")) and not force:
        print(stem, "exists, skip"); continue
    t0 = time.time()
    p = subprocess.run([WL, "render", os.path.join(WORK, "jobs", stem + ".job.json"), "--out", out,
                        "--stems", "none", "--no-png", "--jobs", "1", "--json"], capture_output=True, text=True, timeout=240)
    try:
        r = json.loads(p.stdout)
    except Exception:
        r = {"ok": False, "raw": p.stdout[-400:], "err": p.stderr[-400:]}
    m = r.get("mix", {})
    print(f"{stem}: ok={r.get('ok')} {time.time()-t0:.1f}s warnings={r.get('warnings')} failed={r.get('failedTracks')} dur={m.get('duration')} sr={r.get('sampleRate')} defaults={r.get('defaultsApplied')}")
    if not r.get("ok"):
        print(r)
