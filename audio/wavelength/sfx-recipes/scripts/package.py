"""Build levels.json, measurements.json, CREDITS.md, the reel and the deliver folder from out/final + out/measure.json."""
import json, os, shutil, subprocess, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from specs import *
from sfxlib import *

M = json.load(open(os.path.join(WORK, "out", "measure.json")))
FINAL = os.path.join(WORK, "out", "final")
D = DELIVER
os.makedirs(os.path.join(D, "alt", "builtin-only"), exist_ok=True)

# ---- perceived level intent, dB relative to the anchor (ollie/land), what the mix should feel like
INTENT = {
    "ollie": 0, "land": 0, "land_hard": 3, "crack": -9, "flip": -2, "grab": -3, "manual": -10, "bail": 2,
    "grind_start": -1, "trick": -2, "bank": 1, "bank_big": 3, "combo_lost": -1, "pickup": 0, "skate_done": 3,
    "go": 0, "time_up": 2, "ui_ok": -3,
    "roll_loop": -12, "roll_grass_loop": -14, "roll_wood_loop": -12, "grind_loop": -8,
}
NOTES = {
    "ollie": "anchor (defined 0 dB)", "land": "anchor (defined 0 dB); measures louder than ollie, see anchor.measured_offsets_db",
    "land_hard": "rare, big: +3 over an equal-loudness land",
    "crack": "fires about 2.5x/s at speed: keep it a texture (-9 perceived); positive gain_db only compensates its peaky, low-energy waveform. Play with pitch_scale 0.94-1.06 and +-2 dB random per hit (game side)",
    "flip": "-2: airy whoosh, sits under the landing", "grab": "-3: soft cloth slap",
    "manual": "very subtle blip (report: 10-15 dB down); dense waveform so gain_db is strongly negative",
    "bail": "+2: the failure state should cut through", "grind_start": "-1: metal tick that starts the grind loop",
    "trick": "-2: fires on every trick", "bank": "+1: reward", "bank_big": "+3: biggest reward stinger",
    "combo_lost": "-1: soft negative", "pickup": "0: S-K-A-T-E letter; pitch_scale 2^(n/12) with n=0,2,4,7,9 for the five letters",
    "skate_done": "+3: fanfare", "go": "0: round start", "time_up": "+2: buzzer", "ui_ok": "-3: menu click",
    "roll_loop": "bed under everything (-12 perceived); drive pitch_scale from speed", "roll_grass_loop": "bed, softer than concrete",
    "roll_wood_loop": "bed, hollow ramp", "grind_loop": "bed while grinding (-8 perceived), plays over grind_start",
}
LICENCE = {n: "OPEN" for n in ORDER}

A = (M["ollie"]["lufs_m400"] + M["land"]["lufs_m400"]) / 2
sounds = {}
for n in ORDER:
    m = M[n]
    eq = A - m["lufs_m400"]
    gain = 0.0 if n in ("ollie", "land") else round(2 * (eq + INTENT[n])) / 2
    sounds[n] = dict(
        gain_db=gain, loop=(n in LOOPS), duration_s=m["duration_s"], licence=LICENCE[n],
        peak_dbfs=m["peak_dbfs"], lufs_m400=m["lufs_m400"], lufs_clip=m["lufs_clip"], rms_dbfs=m["rms_dbfs"],
        equal_loudness_gain_db=round(eq, 1), perceived_rel_anchor_db=INTENT[n] if n not in ("ollie", "land") else round(m["lufs_m400"] - A, 1),
        peak_after_gain_dbfs=round(m["peak_dbfs"] + gain, 1), note=NOTES[n])
mx = max(v["gain_db"] for v in sounds.values())
for v in sounds.values():
    v["gain_db_no_boost"] = round(v["gain_db"] - mx, 1)
levels = {
    "_readme": ("gain_db = the volume_db to set per sound in Godot (relative; ollie and land are the 0 dB anchors). "
                "perceived_rel_anchor_db is how loud the sound should FEEL vs the anchor; gain_db = measured equal-loudness correction "
                "(anchor loudness minus the sound's own loudness, because every file is peak-normalised: one-shots -1 dBFS, loops -3 dBFS) plus that intent. "
                "Positive gains push peaks above 0 dBFS in float: put the SFX bus at sfx_bus_offset_db or use gain_db_no_boost. "
                "Loudness = BS.1770 K-weighted, mono file, ungated; lufs_m400 = loudest 400 ms window (short files zero-padded to 400 ms), the basis of the gains. "
                "Intents are design guesses; NOTHING here was verified by ear."),
    "anchor": {"sounds": ["ollie", "land"], "lufs_m400_mean": round(A, 2),
               "measured_offsets_db": {"ollie": round(M["ollie"]["lufs_m400"] - A, 2), "land": round(M["land"]["lufs_m400"] - A, 2)},
               "note": "both defined as 0 dB per the brief; by measurement land is ~5.9 dB louder than ollie (ollie +2.9 / land -2.9 would equalise them)"},
    "sfx_bus_offset_db": round(-(max(v["peak_after_gain_dbfs"] for v in sounds.values())) , 1),
    "sounds": sounds,
}
levels["hierarchy_loudest_to_quietest_perceived"] = [k for k, v in sorted(sounds.items(), key=lambda kv: -kv[1]["perceived_rel_anchor_db"] if kv[0] not in ("ollie", "land") else 0)]
levels["hierarchy_note"] = "one-shots first by perceived_rel_anchor_db (crack and manual are the quietest events, bank_big and skate_done the loudest); beds sit at -8..-14. gain_db is NOT this order: peaky sounds (crack, grind_start) get positive gain_db only to make up for a low-energy waveform."
alt_gains = {}
for k in M:
    if k.endswith("__alt") or k.startswith("builtin_only__"):
        base = k[:-5] if k.endswith("__alt") else k.replace("builtin_only__", "").split("__")[0]
        alt_gains[("alt/" + k + ".wav") if k.endswith("__alt") else ("alt/builtin-only/" + k.replace("builtin_only__", "") + ".wav")] = dict(
            replaces=base, gain_db=round(2 * (sounds[base]["gain_db"] + M[base]["lufs_m400"] - M[k]["lufs_m400"])) / 2,
            duration_s=M[k]["duration_s"], licence="OPEN", note="loudness-matched to the primary by lufs_m400, for level-fair A/B")
levels["alts"] = alt_gains
levels["loops_note"] = "roll_loop, roll_grass_loop, roll_wood_loop, grind_loop are exactly 88200 frames (2.000 s) and carry a smpl loop chunk (0..N-1): Godot's WAV import with loop_mode 0 (Detect From WAV, as in the current .import files) loops them; otherwise set Loop Mode = Forward."
json.dump(levels, open(os.path.join(D, "levels.json"), "w"), indent=1)

# ---- measurements.json
keep = {n: M[n] for n in ORDER}
alts = {k: M[k] for k in M if k.endswith("__alt") or k.startswith("builtin_only__")}
decisions = [
    "ollie: report pick #1 (Surge Tuned Wood + Simple Click + builtin hat rattle) measured 24.9% of A-weighted energy above 8 kHz (hat ticks, hissy); rattle low-passed at 6 kHz and set +3 dB (fader -1.6 -> +3.0 after LP): 3.7% above 8 kHz, 13.9% above 2.5 kHz.",
    "crack: report pick (tick + thunk) had 0.8% of A-weighted energy above 2.5 kHz (tick inaudible next to the 98 Hz thunk). Tick raised +20 dB and low-passed 6.5 kHz: 30% above 2.5 kHz, 1.5% above 8 kHz. Original render kept as alt/builtin-only/crack__report_original.wav",
    "grind_loop: A (saw stack) has 63.6% of A-weighted energy above 2.5 kHz vs 44.5% for B (noise band-pass + saturation); B chosen for the 'never fatiguing' rule, A is the alt. Low-passing A at 4.5/3.5 kHz only moved it to 58.8/54.4% (tried, not used).",
    "bank: last note lengthened to 0.3 s (report advice) so the file fills 0.5 s.",
    "All jobs rendered at 44.1 kHz natively (job sampleRate 44100), stems none, default 1 s lead-in; slices cut from the float stereo mix, folded to mono (L+R)/2, faded, peak-normalised, TPDF-dithered to 16 bit.",
]
json.dump({"format": "mono 16-bit PCM 44100 Hz", "definitions": {
    "lead_ms": "time from file start to the first sample above -60 dBFS", "tail_below_60dbfs_ms": "time from the last sample above -60 dBFS to the file end",
    "natural_tail_ms": "onset to last 2.5 ms frame above -60 dBFS in the untrimmed render (+ = render-limited lower bound); truncated_by_target = cut with a quarter-sine fade at the report's target length",
    "lr_corr / mono_fold_loss_db": "measured on the stereo render before folding; fold loss = K-weighted loudness of mono (as dual-mono) minus stereo, 0 = no loss, -3 = uncorrelated channels, worse = phase problem",
    "a_weighted_pct": "share of A-weighted spectral energy (<150 Hz, >2.5 kHz, >8 kHz)", "centroid_hz": "magnitude-weighted spectral centroid of the whole clip (float, pre-dither); centroid_power_weighted_hz is energy-weighted",
    "crest_db": "sample peak minus RMS over the whole clip"},
    "decisions": decisions, "sounds": keep, "alt_and_builtin_only": alts}, open(os.path.join(D, "measurements.json"), "w"), indent=1)

# ---- copy audio
for n in ORDER:
    shutil.copy(os.path.join(FINAL, n + ".wav"), os.path.join(D, n + ".wav"))
for k in alts:
    dst = os.path.join(D, "alt", k + ".wav") if k.endswith("__alt") else os.path.join(D, "alt", "builtin-only", k.replace("builtin_only__", "") + ".wav")
    shutil.copy(os.path.join(FINAL, k + ".wav"), dst)

# ---- reel
gap = np.zeros(int(0.4 * SR)); parts = []; cues = []; t = 0.0
for n in ORDER:
    x = read_wav16(os.path.join(FINAL, n + ".wav")) * 10 ** (sounds[n]["gain_db"] / 20)
    if n in LOOPS:
        x = np.concatenate([x, x])
    cues.append((n, round(t, 2), round(len(x) / SR, 2))); parts += [x, gap]; t += (len(x) + len(gap)) / SR
reel = np.concatenate(parts); reel *= 10 ** (-1.0 / 20) / np.abs(reel).max()
tmp = os.path.join(WORK, "out", "reel.wav"); write_wav(tmp, to_int16(reel))
subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", tmp, "-c:a", "libmp3lame", "-b:a", "192k", "-ar", "44100", "-ac", "1", os.path.join(D, "sfx-reel.mp3")], check=True)
os.remove(tmp)
with open(os.path.join(D, "sfx-reel-cues.txt"), "w") as f:
    f.write("Reel order, start time (s), length (s). Gaps 0.4 s. Loops play twice back to back (the join is the loop seam). Levels = gain_db from levels.json.\n")
    for n, s0, ln in cues:
        f.write(f"{s0:7.2f}  {ln:5.2f}  {n}\n")

# ---- recipes + scripts
rd = os.path.join(D, "recipes"); os.makedirs(os.path.join(rd, "jobs"), exist_ok=True); os.makedirs(os.path.join(rd, "scripts"), exist_ok=True)
stems = {M[n]["recipe"] for n in list(ORDER) + list(alts)}
for st in stems:
    shutil.copy(os.path.join(WORK, "jobs", st + ".job.json"), os.path.join(rd, "jobs", st + ".job.json"))
for sc in ("specs.py", "prep_jobs.py", "render_all.py", "sfxlib.py", "finish.py", "package.py"):
    shutil.copy(os.path.join(WORK, "scripts", sc), os.path.join(rd, "scripts", sc))
print("A(anchor) =", round(A, 2), " bus offset", levels["sfx_bus_offset_db"])
for n in ORDER:
    s = sounds[n]; print(f"{n:16s} gain {s['gain_db']:6.1f}  eq {s['equal_loudness_gain_db']:6.1f}  intent {s['perceived_rel_anchor_db']:5.1f}  dur {s['duration_s']:.3f}  peak_after {s['peak_after_gain_dbfs']:5.1f}  m400 {s['lufs_m400']}")
