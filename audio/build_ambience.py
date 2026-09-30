"""
Park ambience, synthesised with numpy/scipy (no samples, no licences): gusting wind, leaves rustling in the gusts,
a low hum of distant traffic with one car passing, and birds (a few kinds of call) around the stereo field.

    ~/Code/star-circuit/audio/.venv/bin/python audio/build_ambience.py

Writes game/assets/audio/ambience/park_ambience.ogg: a seamless 32 s stereo loop (Vorbis q1, small for the web).
"""

import os
import subprocess
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
DUR = 32.0
N = int(SR * DUR)
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio",
                                    "ambience"))
RNG = np.random.default_rng(11)


def sos_filter(x, kind, fc, order=2):
    sos = signal.butter(order, fc, btype=kind, fs=SR, output="sos")
    # run the filter over the loop twice and keep the second pass: the state wraps, so the loop point is seamless
    y = signal.sosfilt(sos, np.concatenate([x, x]))
    return y[len(x):]


def smooth_env(rate_hz, lo, hi, seed):
    """A slow random envelope that loops: a few sine partials with whole-number cycles per loop."""
    r = np.random.default_rng(seed)
    t = np.arange(N) / SR
    e = np.zeros(N)
    for k in range(1, 5):
        cycles = max(1, int(round(rate_hz * DUR * k)))
        e += r.uniform(0.4, 1.0) / k * np.sin(2 * np.pi * cycles * t / DUR + r.uniform(0, 2 * np.pi))
    e = (e - e.min()) / (e.max() - e.min())
    return lo + (hi - lo) * e


def pink(n):
    """Pink-ish noise (Voss-McCartney-free: filter white noise by 1/sqrt(f))."""
    w = RNG.standard_normal(n)
    f = np.fft.rfft(w)
    freqs = np.fft.rfftfreq(n, 1 / SR)
    f[1:] /= np.sqrt(freqs[1:])
    f[0] = 0
    x = np.fft.irfft(f, n)
    return x / np.abs(x).max()


def wind():
    gust = smooth_env(0.07, 0.25, 1.0, 1)
    out = []
    for ch in range(2):
        x = sos_filter(pink(N), "lowpass", 700.0)
        x = sos_filter(x, "highpass", 60.0)
        out.append(x / np.abs(x).max() * gust * 0.5)
    return np.stack(out), gust


def leaves(gust):
    out = []
    for ch in range(2):
        x = RNG.standard_normal(N)
        x = sos_filter(x, "bandpass", [2200.0, 7000.0])
        flutter = sos_filter(np.abs(RNG.standard_normal(N)), "lowpass", 18.0)      # leaf-by-leaf flicker
        flutter = flutter / flutter.max()
        out.append(x / np.abs(x).max() * (gust ** 2.2) * (0.4 + 0.6 * flutter) * 0.22)
    return np.stack(out)


def traffic():
    t = np.arange(N) / SR
    hum = []
    for ch in range(2):
        x = sos_filter(np.cumsum(RNG.standard_normal(N)) * 0.02, "lowpass", 220.0)   # brown-ish rumble
        x = sos_filter(x, "highpass", 35.0)
        hum.append(x / np.abs(x).max() * 0.12)
    hum = np.stack(hum)
    # one car passes left to right around 12-19 s: filtered noise swelling in and out, panning across
    car = sos_filter(RNG.standard_normal(N), "bandpass", [120.0, 1400.0])
    car /= np.abs(car).max()
    c = 15.5
    env = np.exp(-((t - c) / 2.2) ** 2)
    pan = np.clip((t - (c - 3.5)) / 7.0, 0.0, 1.0)
    hum[0] += car * env * np.cos(pan * np.pi / 2) * 0.35
    hum[1] += car * env * np.sin(pan * np.pi / 2) * 0.35
    return hum


def chirp(f0, f1, dur, harm=0.15):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    x = np.sin(ph) + harm * np.sin(2 * ph)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5
    return x * env


def bird_call(kind, r):
    if kind == "trill":            # a fast run of short identical notes
        f = r.uniform(3500, 5200)
        notes = [chirp(f * 1.08, f * 0.92, 0.035) for _ in range(r.integers(6, 12))]
        gap = int(SR * r.uniform(0.018, 0.03))
        return np.concatenate([np.concatenate([nt, np.zeros(gap)]) for nt in notes])
    if kind == "whistle":          # two or three slurred tones
        parts = []
        f = r.uniform(2400, 3400)
        for _ in range(r.integers(2, 4)):
            f2 = f * r.uniform(0.75, 1.3)
            parts.append(chirp(f, f2, r.uniform(0.12, 0.28), harm=0.05))
            parts.append(np.zeros(int(SR * 0.04)))
            f = f2
        return np.concatenate(parts)
    # "tweet": a few quick up-sweeps
    parts = []
    for _ in range(r.integers(2, 5)):
        f = r.uniform(3000, 4500)
        parts.append(chirp(f, f * r.uniform(1.3, 1.7), r.uniform(0.05, 0.09)))
        parts.append(np.zeros(int(SR * r.uniform(0.06, 0.14))))
    return np.concatenate(parts)


def birds():
    r = np.random.default_rng(5)
    out = np.zeros((2, N))
    # a few birds, each with its own call, pitch and place, calling every few seconds
    for b in range(5):
        kind = ["trill", "whistle", "tweet", "tweet", "whistle"][b]
        pan = r.uniform(0.1, 0.9)
        level = r.uniform(0.12, 0.3)
        t = r.uniform(0.0, 4.0)
        while t < DUR:
            call = bird_call(kind, r) * level
            s = int(t * SR)
            idx = (np.arange(len(call)) + s) % N           # wrap round the loop point
            out[0, idx] += call * np.cos(pan * np.pi / 2)
            out[1, idx] += call * np.sin(pan * np.pi / 2)
            t += r.uniform(3.0, 7.5)
    # a little outdoor space: a short, bright, decaying noise tail
    tail_n = int(SR * 0.35)
    tail = RNG.standard_normal(tail_n) * np.exp(-np.arange(tail_n) / (SR * 0.07))
    tail = sos_filter(tail, "highpass", 1500.0)
    tail /= np.abs(tail).sum() * 0.35
    for ch in range(2):
        wet = np.real(np.fft.ifft(np.fft.fft(out[ch]) * np.fft.fft(tail, N)))     # circular: loops cleanly
        out[ch] = out[ch] * 0.8 + wet * 0.35
    return out


def main():
    w, gust = wind()
    mix = w * 0.9 + leaves(gust) + traffic() + birds()
    mix = sos_filter(mix[0], "highpass", 30.0), sos_filter(mix[1], "highpass", 30.0)
    mix = np.stack(mix)
    mix /= np.abs(mix).max()
    mix *= 0.7
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "amb.wav")
        pcm = (np.clip(mix.T, -1, 1) * 32767).astype(np.int16)
        with wave.open(wav, "wb") as f:
            f.setnchannels(2)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes(pcm.tobytes())
        out = os.path.join(OUT, "park_ambience.ogg")
        subprocess.run(["oggenc", "-q", "1", "--quiet", "-t", "Park ambience", "-a", "Not Pro Skaters",
                        "-o", out, wav], check=True)
    print("[ambience] wrote", out, os.path.getsize(out), "bytes")


if __name__ == "__main__":
    main()
