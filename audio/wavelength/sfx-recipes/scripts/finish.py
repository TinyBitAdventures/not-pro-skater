"""usage: finish.py name:kind:stem[:target:fade] ...   kind = one|loop.  Writes out/final/<name>.wav and merges out/measure.json"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from specs import *
from sfxlib import *

os.makedirs(os.path.join(WORK, "out", "final"), exist_ok=True)
mp = os.path.join(WORK, "out", "measure.json")
M = json.load(open(mp)) if os.path.exists(mp) else {}
todo = sys.argv[1:]
if "alts" in todo:
    todo = [t for t in todo if t != "alts"] + [f"{n}:{k}:{s}:{t}:{fd}" for n, (k, s, t, fd) in ALTS.items()] + [f"builtin_only__{n}:{k}:{s}:{t}:{fd}" for n, (k, s, t, fd) in EXTRAS.items()]
if todo == ["all"]:
    todo = [f"{n}:one:{s}:{t}:{f}" for n, (s, t, f) in ONESHOTS.items()] + [f"{n}:loop:{s}" for n, s in LOOPS.items()]
for spec in todo:
    p = spec.split(":")
    name, kind, stem = p[0], p[1], p[2]
    st = load_mix(os.path.join(WORK, "raw", stem, "mix.wav"))
    if kind == "one":
        i16, xf, info, extra = finish_oneshot(st, float(p[3]), float(p[4]))
        loop = False
    else:
        i16, xf, info, extra = finish_loop(st)
        loop = True
    path = os.path.join(WORK, "out", "final", name + ".wav")
    write_wav(path, i16, loop=loop)
    x = read_wav16(path)
    m = measure_final(x, info, extra, xf)
    m.update(recipe=stem, kind=kind)
    if loop:
        m["seam"] = seam_test(x)
    M[name] = m
    print(f"{name:22s} {m['duration_s']:6.3f}s pk {m['peak_dbfs']:6.2f} tp {m['true_peak_dbtp']:6.2f} crest {m['crest_db']:5.1f} cent {m['centroid_hz']:6.0f} "
          f"bands {list(m['band_pct'].values())} Awt {list(m['a_weighted_pct'].values())} cpw {m['centroid_power_weighted_hz']:.0f} lead {m['lead_ms']}ms tail<-60 {m['tail_below_60dbfs_ms']}ms nat {m.get('natural_tail_ms')}{'+' if m.get('natural_tail_render_limited') else ''} "
          f"trunc {m.get('truncated_by_target')} corr {m['lr_corr']} fold {m['mono_fold_loss_db']} worstband {m['worst_band_fold_db']} "
          f"M400 {m['lufs_m400']} clip {m['lufs_clip']} {m['mono_flag'] or ''}")
    if loop:
        print("     seam", json.dumps(m["seam"]), "naive", m["naive_cut_wrap_step_over_p99"])
json.dump(M, open(mp, "w"), indent=1)
