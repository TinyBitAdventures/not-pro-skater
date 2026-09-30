"""Spec table for the Not Pro Skater SFX set. Recipes come from the research folder (read-only)."""
import os
HOME = os.path.expanduser("~")
RES = os.path.join(HOME, "Documents/wavelength-songs/skate-park/research/recipes")
WORK = os.path.join(HOME, "Documents/wavelength-songs/skate-park-sfx")
DELIVER = os.path.join(HOME, "Documents/wavelength-songs/skate-park/deliver/sfx")
SR = 44100

# name: (recipe stem, target length s, end-fade ms)   (trim/fade values from the report, section 1-3)
ONESHOTS = {
    "ollie":        ("ollie__ollie_Br3",       0.30, 50),
    "land":         ("land__land_Br",          0.35, 80),
    "land_hard":    ("land_hard__landhard_Br", 0.50, 120),
    "crack":        ("crack__crack_G5",        0.10, 20),
    "flip":         ("flip__flip_E",           0.30, 60),
    "grab":         ("grab__grab_B",           0.20, 50),
    "manual":       ("manual__manual_D",       0.15, 40),
    "bail":         ("bail__bail_Ar2",         1.05, 300),
    "grind_start":  ("grind_start__gstart_A",  0.20, 50),
    "trick":        ("trick__trick_A",         0.16, 30),
    "bank":         ("bank__bank_A",           0.50, 150),
    "bank_big":     ("bank_big__bankbig_E",    0.90, 250),
    "combo_lost":   ("combo_lost__lost_A",     0.40, 100),
    "pickup":       ("pickup__pickup_A",       0.35, 100),
    "skate_done":   ("skate_done__done_Er",    1.15, 250),
    "go":           ("go__go_A",               0.30, 80),
    "time_up":      ("time_up__timeup_B",      0.90, 150),
    "ui_ok":        ("ui_ok__uiok_A",          0.12, 30),
}
LOOPS = {
    "roll_loop":       "roll_loop__roll_Br",
    "roll_grass_loop": "roll_grass_loop__grass_Ar",
    "roll_wood_loop":  "roll_wood_loop__wood_Ar",
    "grind_loop":      "grind_loop__grind_B",
}
ORDER = list(ONESHOTS) + list(LOOPS)

# extra candidates rendered for loop selection and alternates: key -> (kind, recipe stem, target s, fade ms)
EXTRA = {
    "roll_Ar":  ("loop", "roll_loop__roll_Ar"),
    "grass_B":  ("loop", "roll_grass_loop__grass_B"),
    "wood_B":   ("loop", "roll_wood_loop__wood_B"),
    "grind_B":  ("loop", "grind_loop__grind_B"),
    "grind_E":  ("loop", "grind_loop__grind_E"),
}

# per-recipe edits applied to a copy of the recipe job (never to the research folder)
def edit_bank_A(job):
    # report: natural end 380 ms, 120 ms short of the 0.5 s target: lengthen the last note
    notes = job["tracks"][0]["notes"]
    notes.sort(key=lambda n: n.get("beat", n.get("time", 0)))
    notes[-1]["dur"] = 0.30
EDITS = {"bank__bank_A": edit_bank_A}


# variants: new stem -> (base recipe stem, edit function).  Made after measuring the first pass (see CREDITS/measurements)
def ollie_hat_soft(job):
    t = job["tracks"][2]
    assert t["plugin"] == "builtin:drums"
    t["fx"][0]["bands"].append({"type": "lowpass", "freq": 6000})
    t["gain"] = -5.6

def crack_tick(tick_db, thunk_db):
    def f(job):
        assert job["tracks"][0]["name"] == "tick" and job["tracks"][1]["name"] == "thunk"
        job["tracks"][0]["gain"] = tick_db
        job["tracks"][1]["gain"] = thunk_db
    return f

VARIANTS = {
    "ollie__ollie_Br2": ("ollie__ollie_Br", ollie_hat_soft),
    "crack__crack_G2": ("crack__crack_G", crack_tick(12.0, -3.0)),
    "crack__crack_G3": ("crack__crack_G", crack_tick(8.0, -6.0)),
}
NEWSTEMS = ["ollie__ollie_Br2", "ollie__ollie_E", "ollie__ollie_C", "crack__crack_G2", "crack__crack_G3", "crack__crack_F",
            "grab__grab_H", "bail__bail_Br", "land__land_Cr", "land__land_A", "land_hard__landhard_A", "manual__manual_E",
            "grind_start__gstart_G"]


def ollie_hat_mid(job):
    t = job["tracks"][2]
    assert t["plugin"] == "builtin:drums"
    t["fx"][0]["bands"].append({"type": "lowpass", "freq": 6000})
    t["gain"] = 3.0

def crack_tick_lp(tick_db, thunk_db, lp=6500):
    def f(job):
        crack_tick(tick_db, thunk_db)(job)
        job["tracks"][0]["fx"] = [{"type": "eq", "bands": [{"type": "lowpass", "freq": lp}]}]
    return f

VARIANTS.update({
    "ollie__ollie_Br3": ("ollie__ollie_Br", ollie_hat_mid),
    "crack__crack_G4": ("crack__crack_G", crack_tick_lp(16.0, -3.0)),
    "crack__crack_G5": ("crack__crack_G", crack_tick_lp(20.0, -3.0)),
})
NEWSTEMS += ["ollie__ollie_Br3", "crack__crack_G4", "crack__crack_G5", "land__land_B"]

def _syn(name, wave, filt, amp, gain, notes, pitch_env=None):
    s = {"osc": [{"wave": wave}], "filter": filt, "amp": amp}
    if pitch_env:
        s["pitchEnv"] = pitch_env
    return {"name": name, "plugin": "builtin:synth", "preset": "Init", "synth": s, "gain": gain, "notes": notes}

def _n(beat, dur, key=60, vel=1.0):
    return {"beat": beat, "dur": dur, "key": key, "vel": vel}

# builtin-only land (licence-safe fallback for the Surge kick+snare): thud + mid knock + slap + quiet rattle
NEWJOBS = {
    "land__land_B": {
        "_about": "land_B: builtin:synth only. thud (sine, pitch env) + knock (BP 380) + slap (BP 1.5k) + rattle (BP 3.2k ticks); sound starts 1.0 s in",
        "tempo": 60, "tail": 0.6, "stems": "none",
        "tracks": [
            _syn("thud", "sine", {"type": "lowpass", "cutoff": 6000, "keytrack": 0},
                 {"attack": 0.001, "decay": 0.11, "sustain": 0, "release": 0.03, "velocity": 0.3}, 0.0, [_n(0, 0.12, 40)],
                 {"amount": 20, "decay": 0.04}),
            _syn("knock", "noise", {"type": "bandpass", "cutoff": 380, "slope": 12, "resonance": 0.5, "keytrack": 0},
                 {"attack": 0.001, "decay": 0.08, "sustain": 0, "release": 0.03, "velocity": 0.3}, -1.0, [_n(0, 0.1)]),
            _syn("slap", "noise", {"type": "bandpass", "cutoff": 1500, "slope": 12, "resonance": 0.25, "keytrack": 0},
                 {"attack": 0.0007, "decay": 0.035, "sustain": 0, "release": 0.02, "velocity": 0.3}, -9.0, [_n(0, 0.05)]),
            _syn("rattle", "noise", {"type": "bandpass", "cutoff": 3200, "slope": 12, "resonance": 0.3, "keytrack": 0},
                 {"attack": 0.0005, "decay": 0.012, "sustain": 0, "release": 0.01, "velocity": 0.3}, -8.0,
                 [_n(0.10, 0.03, 60, 0.8), _n(0.155, 0.03, 60, 0.55)]),
        ],
    }
}


# alternates (5 least-sure sounds) and extras.  name -> (kind, recipe stem, target s, fade ms)
ALTS = {
    "ollie__alt":     ("one",  "ollie__ollie_C",        0.30, 50),
    "grab__alt":      ("one",  "grab__grab_H",          0.20, 50),
    "bail__alt":      ("one",  "bail__bail_Br",         1.05, 300),
    "land__alt":      ("one",  "land__land_Cr",         0.35, 80),
    "grind_loop__alt": ("loop", "grind_loop__grind_A",  None, None),
}
EXTRAS = {   # licence-safe builtin-only stand-ins for the Surge/Dexed sounds, and the crack original
    "land":        ("one", "land__land_B",          0.35, 80),
    "land_hard":   ("one", "land_hard__landhard_A", 0.50, 120),
    "manual":      ("one", "manual__manual_E",      0.15, 40),
    "grind_start": ("one", "grind_start__gstart_G", 0.20, 50),
    "crack__report_original": ("one", "crack__crack_G", 0.10, 20),
}


def grind_lp(freq):
    def f(job):
        t = job["tracks"][0]
        t["fx"] = t.get("fx", []) + [{"type": "eq", "bands": [{"type": "lowpass", "freq": freq}]}]
    return f

VARIANTS.update({
    "grind_loop__grind_A2": ("grind_loop__grind_A", grind_lp(4500)),
    "grind_loop__grind_A3": ("grind_loop__grind_A", grind_lp(3500)),
})
NEWSTEMS += ["grind_loop__grind_A2", "grind_loop__grind_A3"]
