"""
Not Pro Skater: pushing, wind and per-surface grind sounds, synthesised with numpy/scipy (no samples, no licences).

    push.wav                 one push stride: the shoe plants, then scuffs back off the asphalt (gritty, ~0.33 s)
    wind_loop.wav            rushing air past the ears, gently gusting (6 s loop; the game fades it in with speed)
    grind_metal_loop.wav     trucks on a steel rail: bright scrape driving a bank of ringing rail modes (3 s loop)
    grind_concrete_loop.wav  sliding a concrete ledge or curb: low, sandpapery grit, hardly any ring (3 s loop)
    grind_wood_loop.wav      sliding wood (a bench, a ramp edge): soft friction through hollow plank resonances (3 s loop)

    ~/Code/star-circuit/audio/.venv/bin/python audio/build_skate_sfx.py [name ...]

Loops are built periodic from the start: every filter is applied as its steady-state periodic response (in the
frequency domain over the whole loop), envelopes have whole cycles per loop and random events wrap, so the wrap is
sample-continuous and no crossfade is needed. The grind loops are RMS-matched to grind_loop.wav (-15.35 dBFS); the
wind peaks at -3 dBFS like the other loops; push peaks at -1 dBFS. 44.1 kHz mono 16-bit with TPDF dither; loops carry
a smpl loop chunk, as the Wavelength set does. Seeded, so a rebuild gives the same files.
"""

import os
import struct
import sys

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio", "sfx"))
GRIND_RMS_DB = -15.35          # rms of grind_loop.wav, the generic grind the surface loops sit beside


# ---------------------------------------------------------------- periodic building blocks

def response(sos, n):
    """Complex response of a filter at the rfft bins of an n-sample loop."""
    _, h = signal.sosfreqz(sos, worN=np.fft.rfftfreq(n, 1 / SR), fs=SR)
    return h


def cfilt(x, kind, fc, order=2):
    """Steady-state periodic filtering: the output is what the filter gives once the loop has played forever."""
    sos = signal.butter(order, fc, btype=kind, fs=SR, output="sos")
    return np.fft.irfft(np.fft.rfft(x) * response(sos, len(x)), len(x))


def modes(x, freqs, taus, levels):
    """A bank of resonant modes (2nd-order band-passes, Q = pi f tau) driven by x, periodic steady state.
    levels set each mode's share of the output power for white-noise drive (gain scaled by sqrt(tau))."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-3
    h = np.zeros(len(f), complex)
    for fk, tk, lk in zip(freqs, taus, levels):
        q = np.pi * fk * tk
        h += lk * np.sqrt(tk / 0.01) / (1 + 1j * q * (f / fk - fk / f))
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def wobble(n, parts, seed):
    """1 + sum of sines with whole cycles per loop: parts = [(cycles, depth), ...]."""
    r = np.random.default_rng(seed)
    t = np.arange(n) / n
    e = np.ones(n)
    for cyc, depth in parts:
        e += depth * np.sin(2 * np.pi * cyc * t + r.uniform(0, 2 * np.pi))
    return e


def rough(n, fc, depth, seed):
    """Random roughness envelope around 1 (low-passed rectified noise, periodic)."""
    r = np.random.default_rng(seed)
    e = cfilt(np.abs(r.standard_normal(n)), "lowpass", fc)
    e = (e - e.mean()) / (np.abs(e - e.mean()).max() + 1e-12)
    return 1 + depth * e


def impulses(n, rate, seed, alpha=2.2, cap=4.0):
    """Poisson clicks, heavy-tailed (Pareto, capped) amplitudes and random sign; positions wrap, so the train is
    periodic. The cap keeps any one click from standing out as a pop."""
    r = np.random.default_rng(seed)
    k = r.poisson(rate * n / SR)
    x = np.zeros(n)
    pos = r.integers(0, n, k)
    np.add.at(x, pos, np.minimum(r.pareto(alpha, k) + 1, cap) * r.choice([-1.0, 1.0], k))
    return x


def pink(n, seed):
    r = np.random.default_rng(seed)
    f = np.fft.rfft(r.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    f[1:] /= np.sqrt(fr[1:])
    f[0] = 0
    x = np.fft.irfft(f, n)
    return x / x.std()


def unit(x):
    return x / (x.std() + 1e-12)


def softclip(x, thresh):
    """Odd soft knee above thresh (linear below), never exceeding 1."""
    a = np.abs(x)
    over = a > thresh
    y = x.copy()
    y[over] = np.sign(x[over]) * (thresh + (1 - thresh) * np.tanh((a[over] - thresh) / (1 - thresh)))
    return y


def match_rms(x, rms_db, peak_ceiling_db=-1.0):
    """Scale to an RMS, soft-limiting peaks under the ceiling (a few rounds, as the limiter takes a little RMS)."""
    target = 10 ** (rms_db / 20)
    ceil = 10 ** (peak_ceiling_db / 20)
    y = x
    for _ in range(6):
        y = y * target / np.sqrt((y ** 2).mean())
        if np.abs(y).max() > ceil:
            y = softclip(y / ceil, 0.6) * ceil
    return y


# ---------------------------------------------------------------- the sounds

def push():
    """Shoe plants (a dull sole thump and a scuff tick), then drags back off the asphalt: dense grit over a rubbery
    shhh, brightening as the foot speeds up, gone by the time the foot lifts (~0.33 s)."""
    dur = 0.33
    n = int(SR * dur)
    t = np.arange(n) / SR
    r = np.random.default_rng(41)
    # the stride: the sole presses in over ~50 ms, drags, and lifts off by ~0.3 s
    env = (np.clip(t / 0.05, 0, 1) ** 1.2) * np.exp(-np.clip(t - 0.05, 0, None) / 0.09)
    env *= 0.5 * (1 + np.cos(np.pi * np.clip((t - 0.20) / 0.12, 0, 1)))       # lift-off
    speed = np.clip(t / 0.10, 0, 1) * np.exp(-np.clip(t - 0.10, 0, None) / 0.15)
    rgh = rough(n, 60.0, 0.45, 3)

    def bp(x, lo, hi, order=2):
        return signal.sosfilt(signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos"), x)

    # grit: the sole skipping over the aggregate; denser and brighter as the foot speeds up
    rate = 900 + 3300 * speed
    grit = np.zeros(n)
    p = r.random(n) < rate / SR
    grit[p] = np.minimum(r.pareto(2.2, p.sum()) + 1, 4.0) * r.choice([-1.0, 1.0], p.sum())
    grit_lo = unit(bp(grit, 600, 2600))
    grit_hi = unit(bp(grit, 2200, 6000))
    grit = grit_lo * (0.9 - 0.4 * speed) + grit_hi * (0.25 + 0.45 * speed)
    # rubber on stone: a broader, softer shhh under the grit
    fric = unit(bp(r.standard_normal(n), 300, 2200)) * 0.7 + unit(bp(r.standard_normal(n), 1800, 5000)) * 0.25 * speed
    scrape = (grit * 0.85 + fric * 0.4) * env * rgh
    # plant: a dull sole thump and a short scuff tick at contact
    thump = np.sin(2 * np.pi * 110 * t - 2 * np.pi * 35 * t ** 2 / 0.05) * np.exp(-t / 0.02) * np.clip(t / 0.003, 0, 1)
    tick = unit(bp(r.standard_normal(n), 1200, 5000)) * np.exp(-t / 0.005) * np.clip(t / 0.0007, 0, 1)
    x = scrape + thump * 0.8 + tick * 0.5
    x = signal.sosfilt(signal.butter(2, 70, btype="highpass", fs=SR, output="sos"), x)
    x = signal.sosfilt(signal.butter(2, 8000, btype="lowpass", fs=SR, output="sos"), x)
    fi = int(0.0005 * SR)
    x[:fi] *= np.sin(0.5 * np.pi * np.linspace(0, 1, fi)) ** 2
    fo = int(0.02 * SR)
    x[-fo:] *= np.cos(0.5 * np.pi * np.linspace(0, 1, fo))
    x /= np.abs(x).max()
    x = softclip(x / 10 ** (-2 / 20), 0.8) * 10 ** (-2 / 20)        # shave the odd grit spike
    return x / np.abs(x).max() * 10 ** (-1.0 / 20), False


def wind_loop():
    """Air past the ears: buffeting low end, a whoosh that brightens in each gust, a thin top hiss."""
    n = int(SR * 6.0)
    gust = wobble(n, [(1, 0.22), (2, 0.12), (3, 0.07), (5, 0.04)], 7)
    gust = (gust - gust.min()) / (gust.max() - gust.min())
    gust = 0.55 + 0.45 * gust                                    # 0.55 .. 1: always blowing, gently gusting
    bands = [  # (lo, hi, level, brightening exponent, flutter rate Hz, flutter depth)
        (35, 150, 0.60, 0.8, 7.0, 0.55),       # ear buffeting
        (150, 400, 0.62, 1.0, 5.0, 0.30),
        (400, 1000, 0.55, 1.3, 3.0, 0.20),     # the whoosh
        (1000, 2500, 0.36, 1.8, 2.0, 0.15),
        (2500, 6000, 0.17, 2.4, 1.5, 0.10),    # hiss, mostly in the gusts
        (6000, 12000, 0.06, 2.8, 1.0, 0.10),
    ]
    x = np.zeros(n)
    for i, (lo, hi, lvl, ex, fr, dp) in enumerate(bands):
        b = unit(cfilt(pink(n, 80 + i), "bandpass", [lo, hi], 1))   # independent noise per band, gentle skirts
        x += b * lvl * gust ** ex * rough(n, fr, dp, 20 + i)
    x = cfilt(x, "highpass", 28.0, 2)
    return x / np.abs(x).max() * 10 ** (-3.0 / 20), True


def grind_metal_loop():
    """Aluminium hanger on a steel rail: stick-slip friction rings the rail's bending modes and a few hanger modes;
    a bright scrape sits on top, chattering at 11 Hz like grind_loop."""
    n = int(SR * 3.0)
    r = np.random.default_rng(31)
    chatter = wobble(n, [(33, 0.25), (66, 0.08)], 32)            # 11 Hz truck chatter (whole cycles per 3 s)
    slow = wobble(n, [(1, 0.10), (2, 0.07), (5, 0.05)], 33)
    ex = (r.standard_normal(n) * 0.7 + unit(impulses(n, 1200, 34, 2.0)) * 0.7) * chatter * slow * rough(n, 45, 0.35, 35)
    # free-free beam ratios for the rail (f1 = 470 Hz) + tube/hanger modes; long rings, brightest 1.3-4.2 kHz
    f = [470, 1295, 2540, 4199, 6272, 8760, 1712, 3318, 3361, 5530]
    tau = [0.55, 0.50, 0.45, 0.35, 0.25, 0.18, 0.40, 0.60, 0.60, 0.20]
    lvl = [0.45, 0.90, 1.00, 0.70, 0.30, 0.12, 0.65, 0.75, 0.55, 0.20]
    # each mode is driven a little differently over the loop so the ring shimmers instead of droning
    ring = np.zeros(n)
    for k in range(len(f)):
        drive = ex * wobble(n, [(2 + k % 3, 0.35), (7 + k, 0.15)], 40 + k)
        ring += modes(drive, [f[k]], [tau[k]], [lvl[k]])
    scrape = cfilt(cfilt(ex, "highpass", 2000, 4), "lowpass", 7000, 2)
    body = cfilt(ex, "bandpass", [700, 2200], 2)
    x = unit(ring) * 1.0 + unit(scrape) * 0.5 + unit(body) * 0.22
    x = cfilt(x, "lowpass", 9000, 2)
    x = np.tanh(1.3 * x / np.abs(x).max()) * np.abs(x).max()
    x = cfilt(x, "highpass", 180, 2)
    return match_rms(x, GRIND_RMS_DB), True


def grind_concrete_loop():
    """Waxed concrete ledge: dense sandpaper grit, a dull friction roar and a low board rumble; barely any ring."""
    n = int(SR * 3.0)
    r = np.random.default_rng(51)
    surf = rough(n, 18, 0.45, 52) * wobble(n, [(1, 0.10), (3, 0.06), (7, 0.05)], 53)   # patches of the ledge
    chatter = wobble(n, [(21, 0.12)], 54)                                                  # 7 Hz, gentle
    grit = cfilt(impulses(n, 2600, 55, 1.8), "bandpass", [380, 3000], 2)
    grit_hi = cfilt(impulses(n, 900, 56, 1.6), "bandpass", [2500, 6000], 2)
    roar = cfilt(pink(n, 57), "bandpass", [140, 1900], 2)
    rumble = cfilt(r.standard_normal(n), "lowpass", 220, 2)
    ring = modes(r.standard_normal(n), [1180, 2650], [0.025, 0.02], [1.0, 0.6])          # the trucks, just a hint
    x = (unit(grit) * 0.85 + unit(grit_hi) * 0.12 + unit(roar) * 0.65 + unit(rumble) * 0.35 * rough(n, 9, 0.5, 58)
         + unit(ring) * 0.10) * surf * chatter
    x = np.tanh(1.1 * x / np.abs(x).max()) * np.abs(x).max()
    x = cfilt(x, "highpass", 60, 2)
    return match_rms(x, GRIND_RMS_DB), True


def grind_wood_loop():
    """Sliding a wooden edge: soft, low-passed friction and a buzz of grain bumps, both ringing the hollow body
    (plank and box modes 150 Hz-1.5 kHz, short decays), with two soft knocks where boards meet."""
    n = int(SR * 3.0)
    r = np.random.default_rng(61)
    fric = cfilt(cfilt(r.standard_normal(n), "lowpass", 1600, 2), "highpass", 90, 2)
    # grain: a jittered ~26 Hz train of soft bumps (78 per loop, so it wraps cleanly)
    grain = np.zeros(n)
    k = 78
    pos = ((np.arange(k) + r.uniform(-0.3, 0.3, k)) * n / k).astype(int) % n
    grain[pos] = r.uniform(0.5, 1.0, k)
    grain = cfilt(grain, "lowpass", 700, 2)
    knocks = np.zeros(n)
    for at, a in ((0.83, 1.0), (2.21, 0.75)):
        knocks[int(at * SR)] = a
    knocks = cfilt(knocks, "lowpass", 1200, 2)
    slow = wobble(n, [(1, 0.10), (2, 0.08), (4, 0.05)], 62) * rough(n, 12, 0.3, 63)
    drive = (unit(fric) * 0.8 + unit(grain) * 0.6) * slow
    f = [150, 232, 395, 610, 940, 1450]
    q = [24, 24, 20, 18, 16, 14]
    tau = [qk / (np.pi * fk) for qk, fk in zip(q, f)]
    lvl = [0.8, 1.0, 0.9, 0.7, 0.5, 0.35]
    body = modes(drive, f, tau, lvl)
    knock = modes(unit(knocks) * 1.0, f, tau, lvl)
    x = unit(body) * 0.9 + unit(fric * slow) * 0.35 + knock / (np.abs(knock).max() + 1e-12) * unit(body).std() * 2.2
    x = cfilt(x, "lowpass", 3500, 2)
    x = cfilt(x, "highpass", 70, 2)
    return match_rms(x, GRIND_RMS_DB), True


SOUNDS = {
    "push": push,
    "wind_loop": wind_loop,
    "grind_metal_loop": grind_metal_loop,
    "grind_concrete_loop": grind_concrete_loop,
    "grind_wood_loop": grind_wood_loop,
}


# ---------------------------------------------------------------- output

def write_wav(path, x, loop):
    r = np.random.default_rng(1234)
    d = r.uniform(-0.5, 0.5, len(x)) + r.uniform(-0.5, 0.5, len(x))          # TPDF dither
    i16 = np.clip(np.round(x * 32767 + d), -32768, 32767).astype("<i2")
    data = i16.tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    body = b"fmt " + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(data)) + data
    if loop:
        n = len(i16)
        smpl = struct.pack("<9I", 0, 0, int(round(1e9 / SR)), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        body += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WAVE" + body)
    return i16.astype(np.float64) / 32767


def main():
    names = sys.argv[1:] or list(SOUNDS)
    os.makedirs(OUT, exist_ok=True)
    for name in names:
        x, loop = SOUNDS[name]()
        y = write_wav(os.path.join(OUT, name + ".wav"), x, loop)
        db = lambda v: 20 * np.log10(max(float(v), 1e-12))
        msg = f"[sfx] {name:20s} {len(y) / SR:5.2f}s peak {db(np.abs(y).max()):6.2f} dBFS rms {db(np.sqrt((y ** 2).mean())):6.2f} dBFS"
        if loop:
            d = np.abs(np.diff(np.concatenate([y, y])))
            msg += f"  wrap step {d[len(y) - 1] / np.percentile(d, 99):.2f} x p99"
        print(msg)


if __name__ == "__main__":
    main()
