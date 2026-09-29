import json, os, sys, glob
sys.path.insert(0, os.path.dirname(__file__))
from specs import *

def needed():
    s = {}
    for n, (stem, tgt, fade) in ONESHOTS.items():
        s[stem] = tgt
    for n, stem in LOOPS.items():
        s[stem] = 2.15
    for k, v in EXTRA.items():
        s[v[1]] = 2.15
    for st in NEWSTEMS:
        s[st] = 1.2
    return s

def prep(stem, target, sr=SR, tail_min=0.5):
    base = VARIANTS[stem][0] if stem in VARIANTS else stem
    job = json.loads(json.dumps(NEWJOBS[stem])) if stem in NEWJOBS else json.load(open(os.path.join(RES, base + ".job.json")))
    if stem in VARIANTS:
        VARIANTS[stem][1](job)
    job["sampleRate"] = sr
    job["stems"] = "none"
    job.pop("picture", None)
    if stem in EDITS:
        EDITS[stem](job)
    last = 0.0
    for t in job["tracks"]:
        for n in t.get("notes", []):
            if "beat" in n:
                last = max(last, n["beat"] + n.get("dur", 0))  # tempo 60: beat == second
            else:
                last = max(last, n.get("time", 0) + n.get("length", 0))
    need = last + 0 if False else max(0.0, target + 0.35 - last)
    job["tail"] = round(max(job.get("tail", 0.6), need, tail_min), 3)
    return job

if __name__ == "__main__":
    for stem, tgt in needed().items():
        job = prep(stem, tgt)
        assert job.get("tempo") == 60, (stem, job.get("tempo"))
        json.dump(job, open(os.path.join(WORK, "jobs", stem + ".job.json"), "w"), indent=1)
        print(stem, "tail", job["tail"], "tracks", [(t["plugin"], t.get("preset")) for t in job["tracks"]])
    j = json.load(open(os.path.join(WORK, "jobs", "bank__bank_A.job.json")))
    print(json.dumps(j["tracks"][0].get("notes"), indent=None))
