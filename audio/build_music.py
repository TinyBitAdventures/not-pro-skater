"""
Skate Park background music: a bright 112 BPM loop (C major, four-chord pop-punk feel) built from
synthesised drums, bass, guitar-ish plucks and a square lead. Placeholder-quality but licence-free.

    ~/Code/star-circuit/audio/.venv/bin/python audio/build_music.py
"""

import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from build_sfx import SR, ad, band, highpass, lowpass, noise, note, saw, square, sweep, sine  # noqa: E402

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio", "music"))
os.makedirs(OUT, exist_ok=True)

BPM = 112
STEP = 60.0 / BPM / 4          # one sixteenth
BARS = 16
N = int(SR * STEP * 16 * BARS)
RNG = np.random.default_rng(11)


def place(buf, x, step, gain=1.0):
    i = int(SR * STEP * step)
    j = min(len(buf), i + len(x))
    if i < len(buf):
        buf[i:j] += x[:j - i] * gain


def kick():
    n = int(SR * 0.3)
    body = sweep(135, 44, 0.3) * ad(n, 0.001, 0.09)
    click = highpass(noise(0.3), 2500) * ad(n, 0.0003, 0.004) * 0.3
    return body + click


def snare():
    n = int(SR * 0.25)
    nz = band(noise(0.25), 1500, 9000) * ad(n, 0.001, 0.07)
    tone = sine(190, 0.25) * ad(n, 0.001, 0.05) * 0.6
    return nz * 0.9 + tone


def hat(open_=False):
    d = 0.16 if open_ else 0.05
    n = int(SR * d)
    return highpass(noise(d), 7000) * ad(n, 0.0005, 0.09 if open_ else 0.018) * 0.5


def pluck(midi, dur=0.22):
    n = int(SR * dur)
    f = note(midi)
    x = square(f, dur, 0.3) + square(f * 1.004, dur, 0.4) * 0.8
    return lowpass(x, 3600) * ad(n, 0.002, 0.11) * 0.5


def bass(midi, dur=0.26):
    n = int(SR * dur)
    f = note(midi)
    x = saw(f, dur) * 0.6 + sine(f, dur) * 0.9
    return lowpass(x, 700) * ad(n, 0.004, 0.15)


def lead(midi, dur=0.3):
    n = int(SR * dur)
    f = note(midi)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.clip(t / 0.12, 0, 1)
    ph = 2 * np.pi * np.cumsum(f * vib) / SR
    x = np.where(np.sin(ph) > 0.5, 1.0, -1.0) * 0.5 + np.sin(ph) * 0.5
    return x * ad(n, 0.004, 0.2) * np.clip((dur - t) / 0.03, 0, 1)


# chord roots (midi) per bar, then pentatonic pools for the lead
PROG = [48, 45, 41, 43, 48, 45, 41, 43, 41, 43, 40, 45, 41, 43, 48, 48]
MINOR = {45, 40}
POOL = {48: [72, 74, 76, 79, 81], 45: [69, 72, 74, 76, 79], 41: [72, 74, 77, 79, 81], 43: [71, 74, 76, 79, 83], 40: [71, 74, 76, 79, 83]}


def build():
    drums = np.zeros(N)
    music = np.zeros(N)
    lead_buf = np.zeros(N)
    for bar in range(BARS):
        b0 = bar * 16
        root = PROG[bar]
        third = root + (3 if root in MINOR else 4)
        fifth = root + 7
        # drums
        for s in (0, 6, 8, 11) if bar % 4 != 3 else (0, 6, 8, 10, 11, 14):
            place(drums, kick(), b0 + s, 1.0)
        for s in (4, 12):
            place(drums, snare(), b0 + s, 0.9)
        if bar % 4 == 3:
            for s in (13, 14, 15):
                place(drums, snare(), b0 + s, 0.45)
        for s in range(0, 16, 2):
            place(drums, hat(open_=(s == 14 and bar % 2 == 1)), b0 + s, 0.55 if s % 4 else 0.7)
        # bass: eighth notes with octave hops
        for k in range(8):
            m = root - 12 + (12 if k in (3, 6) else 0)
            place(music, bass(m), b0 + k * 2, 0.9)
        # chord plucks on the offbeats
        for s in (2, 6, 10, 14):
            for m in (root + 12, third + 12, fifth + 12):
                place(music, pluck(m), b0 + s, 0.32)
        # lead: a hooky figure that varies every bar
        pool = POOL[root]
        rhythm = [(0, 3), (3, 2), (6, 2), (8, 4), (12, 2)] if bar % 2 == 0 else [(0, 2), (2, 2), (4, 3), (8, 3), (12, 4)]
        for k, (s, l) in enumerate(rhythm):
            if bar >= 12 or bar % 4 != 3 or k < 3:
                m = pool[(k * 2 + bar) % len(pool)] if bar >= 4 else pool[(k + bar) % 3]
                place(lead_buf, lead(m, dur=l * STEP * 0.95), b0 + s, 0.4 if bar < 4 else 0.5)
    # a little echo on the lead
    d = int(SR * STEP * 3)
    echo = np.zeros(N)
    echo[d:] += lead_buf[:-d] * 0.35
    echo[2 * d:] += lead_buf[:-2 * d] * 0.15
    out = drums * 0.9 + music * 0.7 + lead_buf * 0.55 + echo * 0.5
    # wrap the tail so the loop point is clean
    out = np.tanh(out * 0.9)
    out = out / np.max(np.abs(out)) * 0.8
    return out


if __name__ == "__main__":
    import wave
    x = build()
    wav = os.path.join(OUT, "park.wav")
    with wave.open(wav, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())
    ogg = os.path.join(OUT, "park.ogg")
    subprocess.run(["oggenc", "-q", "4", "-o", ogg, wav], check=True, capture_output=True)
    os.remove(wav)
    rms = 20 * np.log10(np.sqrt(np.mean(x ** 2)))
    print(f"  park.ogg  {len(x) / SR:.1f}s  rms {rms:.1f} dBFS")
