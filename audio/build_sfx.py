"""
Not Pro Skater placeholder sound effects, synthesised with numpy/scipy. No samples, no licences.

    ~/Code/star-circuit/audio/.venv/bin/python audio/build_sfx.py [name ...]

Writes 44.1 kHz mono 16-bit WAVs to game/assets/audio/sfx. Names ending in _loop are seamless.
"""

import os
import sys
import wave

import numpy as np
from scipy import signal

SR = 44100
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio", "sfx"))
os.makedirs(OUT, exist_ok=True)
RNG = np.random.default_rng(7)


def tt(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return RNG.standard_normal(int(SR * dur))


def band(x, lo, hi, order=2):
    sos = signal.butter(order, [lo, hi], btype="bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def lowpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="lowpass", fs=SR, output="sos"), x)


def highpass(x, fc, order=2):
    return signal.sosfilt(signal.butter(order, fc, btype="highpass", fs=SR, output="sos"), x)


def ad(n, attack, decay):
    """Attack then exponential decay envelope over n samples."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-t / max(decay, 1e-4))
    return a * d


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * tt(dur) + phase)


def sweep(f0, f1, dur, shape="exp"):
    t = tt(dur)
    if shape == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def saw(freq, dur):
    t = tt(dur)
    return 2 * ((freq * t) % 1.0) - 1


def square(freq, dur, duty=0.5):
    t = tt(dur)
    return np.where(((freq * t) % 1.0) < duty, 1.0, -1.0)


def pad(x, n):
    out = np.zeros(n)
    out[:min(n, len(x))] = x[:n]
    return out


def mix(*parts, n=None):
    n = n or max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out += pad(p, n)
    return out


def loopify(x, fade=0.08):
    """Crossfade the tail into the head so the clip repeats without a click."""
    f = int(SR * fade)
    body = x[:-f].copy()
    tail = x[-f:]
    ramp = np.linspace(0, 1, f)
    body[:f] = body[:f] * ramp + tail * (1 - ramp)
    return body


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {name}.wav  {len(x) / SR:.2f}s")


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


# ---------------------------------------------------------------- sounds

def roll_loop():
    """Urethane on concrete: low rumble plus a hiss, with a slow wheel-wobble."""
    n = 2.0
    x = noise(n + 0.1)
    rumble = lowpass(band(x, 90, 420, 2), 500) * 1.6
    hiss = band(noise(n + 0.1), 1400, 4200, 2) * 0.35
    wob = 1 + 0.22 * np.sin(2 * np.pi * 5.0 * tt(n + 0.1)) + 0.1 * np.sin(2 * np.pi * 11.0 * tt(n + 0.1))
    return loopify((rumble + hiss) * wob)


def roll_grass_loop():
    n = 2.0
    x = lowpass(noise(n + 0.1), 700) * 1.2 + band(noise(n + 0.1), 300, 1200) * 0.5
    return loopify(x * (1 + 0.3 * np.sin(2 * np.pi * 3.0 * tt(n + 0.1))))


def roll_wood_loop():
    """Hollow, resonant rumble for ramps."""
    n = 2.0
    x = noise(n + 0.1)
    body = band(x, 140, 500, 2) * 1.4
    knock = band(noise(n + 0.1), 900, 2400, 2) * 0.28
    res = 0.5 * sine(190, n + 0.1) * (0.5 + 0.5 * np.sin(2 * np.pi * 2.0 * tt(n + 0.1)))
    return loopify((body + knock) * (1 + 0.18 * np.sin(2 * np.pi * 6.0 * tt(n + 0.1))) + res * 0.15)


def grind_loop():
    """Metal scrape: detuned saws through a band, dirty with noise."""
    n = 1.6
    t = tt(n + 0.1)
    wob = 1 + 0.03 * np.sin(2 * np.pi * 7 * t)
    s = sum(saw(f * wob[0], n + 0.1) * a for f, a in ((310, 1.0), (467, 0.7), (623, 0.5), (911, 0.35)))
    scrape = band(s + noise(n + 0.1) * 1.4, 700, 5200, 2)
    return loopify(scrape * (1 + 0.25 * np.sin(2 * np.pi * 9 * t)))


def ollie():
    n = int(SR * 0.3)
    thump = sweep(190, 70, 0.3) * ad(n, 0.001, 0.05)
    click = highpass(noise(0.3), 1800) * ad(n, 0.0005, 0.012) * 0.8
    rattle = band(noise(0.3), 700, 3600) * ad(n, 0.02, 0.07) * 0.5
    return mix(thump, click, rattle, n=n)


def land():
    n = int(SR * 0.35)
    thud = sweep(120, 45, 0.35) * ad(n, 0.001, 0.09)
    slap = band(noise(0.35), 300, 2600) * ad(n, 0.001, 0.05) * 0.9
    rattle = band(noise(0.35), 1200, 5000) * ad(n, 0.03, 0.09) * 0.35
    return mix(thud, slap, rattle, n=n)


def land_hard():
    return land() * 1.0 + np.pad(lowpass(noise(0.45), 200) * ad(int(SR * 0.45), 0.001, 0.12), (0, 0))[:int(SR * 0.35)] * 0.6


def crack():
    """A wheel crossing a pavement joint: tick, then a small thunk."""
    n = int(SR * 0.12)
    tick = highpass(noise(0.12), 2200) * ad(n, 0.0004, 0.006)
    thunk = sweep(140, 80, 0.12) * ad(n, 0.001, 0.03) * 0.8
    return mix(tick, thunk, n=n)


def flip():
    n = int(SR * 0.32)
    t = tt(0.32)
    sweepn = band(noise(0.32), 500, 3500, 2) * np.sin(np.pi * t / 0.32) ** 1.5
    tick = highpass(noise(0.32), 2600) * ad(n, 0.0005, 0.01) * 0.5
    return mix(sweepn, tick, n=n)


def grab():
    n = int(SR * 0.2)
    return band(noise(0.2), 900, 3200, 2) * np.sin(np.pi * tt(0.2) / 0.2) ** 2 * 0.8


def trick():
    """Little rising blip when a trick is completed."""
    parts = []
    for i, m in enumerate((72, 79)):
        d = 0.09
        e = ad(int(SR * d), 0.002, 0.05)
        parts.append(np.pad(square(note(m), d, 0.35) * e, (int(SR * 0.07 * i), 0)))
    return mix(*parts) * 0.9


def bail():
    n = int(SR * 1.0)
    t = tt(1.0)
    hit = sweep(150, 40, 1.0) * ad(n, 0.001, 0.12)
    scrape = band(noise(1.0), 200, 2400) * ad(n, 0.005, 0.28) * (1 + 0.5 * np.sin(2 * np.pi * 14 * t))
    bounce = np.zeros(n)
    for k, (tm, a) in enumerate(((0.0, 1.0), (0.22, 0.6), (0.4, 0.4), (0.52, 0.25))):
        i = int(SR * tm)
        b = sweep(110, 50, 0.16) * ad(int(SR * 0.16), 0.001, 0.045) * a
        bounce[i:i + len(b)] += b[:n - i]
    clatter = highpass(noise(1.0), 1500) * ad(n, 0.01, 0.16) * 0.4
    return mix(hit, scrape * 0.7, bounce, clatter, n=n)


def bank():
    """Combo banked: bright rising arpeggio with a shimmer."""
    parts = []
    for i, m in enumerate((72, 76, 79, 84)):
        d = 0.28
        e = ad(int(SR * d), 0.003, 0.11)
        v = (square(note(m), d, 0.25) * 0.5 + sine(note(m) * 2, d) * 0.4) * e
        parts.append(np.pad(v, (int(SR * 0.075 * i), 0)))
    return mix(*parts)


def bank_big():
    seq = (72, 76, 79, 84, 88, 91)
    parts = []
    for i, m in enumerate(seq):
        d = 0.34
        e = ad(int(SR * d), 0.003, 0.13)
        v = (square(note(m), d, 0.25) * 0.45 + sine(note(m) * 2, d) * 0.4 + sine(note(m) * 3, d) * 0.15) * e
        parts.append(np.pad(v, (int(SR * 0.07 * i), 0)))
    return mix(*parts)


def combo_lost():
    parts = []
    for i, m in enumerate((67, 62)):
        d = 0.26
        e = ad(int(SR * d), 0.004, 0.13)
        parts.append(np.pad(saw(note(m), d) * 0.5 * e, (int(SR * 0.16 * i), 0)))
    return lowpass(mix(*parts), 1600)


def pickup():
    n = int(SR * 0.4)
    a = sine(note(84), 0.4) * ad(n, 0.002, 0.14)
    b = sine(note(91), 0.4) * ad(n, 0.002, 0.14)
    b = np.pad(b, (int(SR * 0.08), 0))[:n]
    return mix(a, b * 0.9, sine(note(96), 0.4) * ad(n, 0.002, 0.08) * 0.3, n=n)


def skate_done():
    seq = (72, 76, 79, 84, 79, 84, 88)
    parts = []
    for i, m in enumerate(seq):
        d = 0.3
        e = ad(int(SR * d), 0.003, 0.14)
        parts.append(np.pad((square(note(m), d, 0.25) * 0.5 + sine(note(m), d) * 0.5) * e, (int(SR * 0.09 * i), 0)))
    return mix(*parts)


def go():
    n = int(SR * 0.3)
    return mix(square(note(79), 0.3, 0.3) * ad(n, 0.002, 0.12), sine(note(91), 0.3) * ad(n, 0.002, 0.1) * 0.5, n=n)


def time_up():
    n = int(SR * 0.9)
    t = tt(0.9)
    horn = (saw(196, 0.9) + saw(196 * 1.5, 0.9) * 0.6 + saw(196 * 2.01, 0.9) * 0.4)
    horn = lowpass(horn, 2200) * np.clip(t / 0.03, 0, 1) * np.clip((0.9 - t) / 0.15, 0, 1)
    return horn


def ui_ok():
    n = int(SR * 0.12)
    return mix(square(note(84), 0.12, 0.3) * ad(n, 0.001, 0.05), n=n)


def manual():
    n = int(SR * 0.16)
    return band(noise(0.16), 400, 1800) * ad(n, 0.004, 0.05) * 0.7 + sweep(240, 180, 0.16) * ad(n, 0.002, 0.04) * 0.4


SOUNDS = {k: v for k, v in globals().items() if callable(v) and k in (
    "roll_loop", "roll_grass_loop", "roll_wood_loop", "grind_loop", "ollie", "land", "land_hard", "crack", "flip",
    "grab", "trick", "bail", "bank", "bank_big", "combo_lost", "pickup", "skate_done", "go", "time_up", "ui_ok", "manual")}


if __name__ == "__main__":
    want = sys.argv[1:] or list(SOUNDS)
    for name in want:
        save(name, SOUNDS[name]())
