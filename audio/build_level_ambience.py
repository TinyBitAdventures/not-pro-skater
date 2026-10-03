"""
District ambiences for the event levels, synthesised with numpy/scipy (no samples, no licences). Same format as the
park ambience (audio/build_ambience.py): 32 s seamless stereo loops, Vorbis q1.

    city_ambience.ogg        downtown: traffic hum and passing cars (Doppler engines, tyre roar), the odd distant horn,
                             a crowd murmur, footsteps walking past, pigeons cooing and one flock taking off
    industrial_ambience.ogg  warehouse district: mains hum, a dust-extractor roar and two compressors chugging, two
                             reversing beepers, metal clanks ringing round the yard, a distant truck, gusty wind
    studio_ambience.ogg      film studio backlot: a diesel generator, distant crew murmur (vowels only, no words),
                             hammering with a slapback off the stage walls, a far-off radio playing a tune, birds

    ~/Code/star-circuit/audio/.venv/bin/python audio/build_level_ambience.py [city|industrial|studio ...]

Seamless by construction: beds are filtered as their steady-state periodic response (FFT over the loop), slow
envelopes have whole cycles per loop, events and the reverb tails wrap round the loop point. Each mix is set to the
park ambience's integrated loudness (-17.2 LUFS, measured with ffmpeg ebur128), then checked again after encoding.
The voice murmur is vowel formants on a buzz with random pitch contours: there are no consonants, so no words.
"""

import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy import signal

SR = 44100
DUR = 32.0
N = int(SR * DUR)
T = np.arange(N) / SR
OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio",
                                    "ambience"))
TARGET_LUFS = -17.2          # park_ambience.ogg, integrated (ffmpeg ebur128)
PEAK_CEIL = 10 ** (-2.0 / 20)


# ---------------------------------------------------------------- periodic helpers (whole loop)

def cfilt(x, kind, fc, order=2):
    """Steady-state periodic filtering over the whole loop (works on (n,) or (2, n))."""
    sos = signal.butter(order, fc, btype=kind, fs=SR, output="sos")
    n = x.shape[-1]
    _, h = signal.sosfreqz(sos, worN=np.fft.rfftfreq(n, 1 / SR), fs=SR)
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * h, n, axis=-1)


def cmodes(x, freqs, qs, gains):
    """Periodic bank of resonances (peak gain = gains, Q given) over the whole loop."""
    n = x.shape[-1]
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-3
    h = np.zeros(len(f), complex)
    for fk, q, g in zip(freqs, qs, gains):
        h += g / (1 + 1j * q * (f / fk - fk / f))
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * h, n, axis=-1)


def pink(r, n=N):
    f = np.fft.rfft(r.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    f[1:] /= np.sqrt(fr[1:])
    f[0] = 0
    x = np.fft.irfft(f, n)
    return x / x.std()


def brown(r, n=N):
    f = np.fft.rfft(r.standard_normal(n))
    fr = np.fft.rfftfreq(n, 1 / SR)
    f[1:] /= np.maximum(fr[1:], 8.0)
    f[0] = 0
    x = np.fft.irfft(f, n)
    return x / x.std()


def unit(x):
    return x / (x.std() + 1e-12)


def slow_env(rate_hz, lo, hi, seed):
    """A slow random envelope that loops: a few sine partials with whole-number cycles per loop (as in the park)."""
    r = np.random.default_rng(seed)
    e = np.zeros(N)
    for k in range(1, 5):
        cycles = max(1, int(round(rate_hz * DUR * k)))
        e += r.uniform(0.4, 1.0) / k * np.sin(2 * np.pi * cycles * T / DUR + r.uniform(0, 2 * np.pi))
    e = (e - e.min()) / (e.max() - e.min())
    return lo + (hi - lo) * e


def rough(fc, depth, seed):
    r = np.random.default_rng(seed)
    e = cfilt(np.abs(r.standard_normal(N)), "lowpass", fc)
    e -= e.mean()
    return 1 + depth * e / (np.abs(e).max() + 1e-12)


def bed(seed, kind, fc, order=2, color="pink"):
    """Decorrelated stereo noise bed."""
    r = np.random.default_rng(seed)
    gen = pink if color == "pink" else (brown if color == "brown" else (lambda rr: rr.standard_normal(N)))
    return np.stack([unit(cfilt(gen(r), kind, fc, order)) for _ in range(2)])


def place(bus, sig, t0, pan=0.5, gain=1.0):
    """Add a mono event into a stereo bus at t0 seconds, wrapping round the loop. pan 0 = left, 1 = right (equal
    power); pan may be an array the length of sig (a moving source)."""
    sig = sig[:N]
    s = int(round(t0 * SR)) % N
    idx = (np.arange(len(sig)) + s) % N
    p = np.clip(pan, 0, 1)
    bus[0, idx] += sig * gain * np.cos(p * np.pi / 2)
    bus[1, idx] += sig * gain * np.sin(p * np.pi / 2)


def addwrap(buf, sig, t0):
    s = int(round(t0 * SR)) % N
    idx = (np.arange(len(sig[:N])) + s) % N
    buf[idx] += sig[:N]


def sfilt(x, kind, fc, order=2):
    """Plain (one-shot) filtering for short events."""
    return signal.sosfilt(signal.butter(order, fc, btype=kind, fs=SR, output="sos"), x)


def make_ir(rt60, length_s, seed, predelay=0.012, lp=5000.0, hp=180.0, early=()):
    """Stereo reverb impulse response: decorrelated decaying noise that darkens as it decays, plus discrete early
    reflections (ms, gain, pan). Energy-normalised per channel."""
    r = np.random.default_rng(seed)
    n = int(length_s * SR)
    t = np.arange(n) / SR
    ir = np.zeros((2, n))
    for ch in range(2):
        tail = r.standard_normal(n) * np.exp(-6.91 * t / rt60)
        dark = sfilt(tail, "lowpass", lp * 0.35, 1)
        w = np.clip(t / (0.6 * rt60), 0, 1)
        tail = sfilt(tail * (1 - w) + dark * w, "lowpass", lp, 1)
        tail = sfilt(tail, "highpass", hp, 2)
        tail[: int(predelay * SR)] = 0
        ir[ch] = tail / np.sqrt((tail ** 2).sum())
    for ms, g, pan in early:
        i = int(ms * SR / 1000)
        ir[0, i] += g * np.cos(pan * np.pi / 2)
        ir[1, i] += g * np.sin(pan * np.pi / 2)
    return ir


def reverb(st, ir, wet, dry=1.0):
    """Circular convolution (the tail wraps round the loop point, so the loop stays seamless)."""
    out = np.zeros_like(st)
    for ch in range(2):
        out[ch] = np.fft.irfft(np.fft.rfft(st[ch]) * np.fft.rfft(ir[ch], N), N)
    return st * dry + out * wet


def rms_db(x):
    return 20 * np.log10(np.sqrt((x ** 2).mean()) + 1e-12)


# ---------------------------------------------------------------- sources

VOWELS = [(730, 1090, 2440), (270, 2290, 3010), (530, 1840, 2480), (660, 1720, 2410), (570, 840, 2410),
          (440, 1020, 2240), (300, 870, 2240), (640, 1190, 2390), (490, 1350, 1690), (400, 1900, 2550)]


def syllable(r, f0a, f0b, dur, form, breath=0.04):
    """One voiced vowel: a buzz gliding f0a -> f0b through three formants, soft on and off. No consonants."""
    n = int(dur * SR) + int(0.04 * SR)
    t = np.arange(n) / SR
    f0 = (f0a + (f0b - f0a) * np.clip(t / dur, 0, 1)) * (1 + 0.012 * np.sin(2 * np.pi * r.uniform(4, 6) * t))
    ph = np.cumsum(f0) / SR
    src = sfilt(2 * (ph % 1.0) - 1, "lowpass", 1100, 1) + breath * r.standard_normal(n)
    y = np.zeros(n)
    for F, bw, g in zip(form, (90, 120, 170), (1.0, 0.45, 0.22)):
        y += g * sfilt(src, "bandpass", [F - bw / 2, F + bw / 2], 1)
    env = np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 0.8
    return y * env


def voice(r, f0, female, pause_mean, calls=0):
    """One talker over the whole loop: phrases of syllables with falling pitch, pauses between. Returns mono."""
    out = np.zeros(N)
    fm = 1.16 if female else 1.0
    t = r.uniform(0, DUR)
    end = t + DUR
    while t < end:
        phrase = r.uniform(0.8, 3.2)
        tt = t
        loud = r.uniform(0.6, 1.0)
        while tt < t + phrase:
            d = r.uniform(0.09, 0.26)
            fr = (tt - t) / phrase
            fa = f0 * (1.12 - 0.24 * fr) * r.uniform(0.93, 1.09)
            v = VOWELS[r.integers(len(VOWELS))]
            form = [F * fm * r.uniform(0.95, 1.05) for F in v]
            addwrap(out, syllable(r, fa, fa * r.uniform(0.92, 1.05), d, form) * loud * r.uniform(0.55, 1.0), tt)
            tt += d + r.uniform(0.0, 0.06)
        t += phrase + r.exponential(pause_mean)
    for _ in range(calls):          # a raised voice calling across the lot: one long open vowel, pitch falling
        tc = r.uniform(0, DUR)
        d = r.uniform(0.45, 0.7)
        form = [F * fm for F in (r.choice([(730, 1090, 2440), (570, 840, 2410), (640, 1190, 2390)]))]
        s = syllable(r, f0 * 1.6, f0 * 1.15, d, form, breath=0.06)
        addwrap(out, s * 1.3, tc)
    return out


def chirp(f0, f1, dur, harm=0.15):
    n = int(SR * dur)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return (np.sin(ph) + harm * np.sin(2 * ph)) * np.sin(np.pi * np.clip(t / dur, 0, 1)) ** 1.5


def bird_call(kind, r):
    if kind == "trill":
        f = r.uniform(3500, 5200)
        notes = [chirp(f * 1.08, f * 0.92, 0.035) for _ in range(r.integers(6, 12))]
        gap = int(SR * r.uniform(0.018, 0.03))
        return np.concatenate([np.concatenate([nt, np.zeros(gap)]) for nt in notes])
    if kind == "whistle":
        parts = []
        f = r.uniform(2400, 3400)
        for _ in range(r.integers(2, 4)):
            f2 = f * r.uniform(0.75, 1.3)
            parts += [chirp(f, f2, r.uniform(0.12, 0.28), harm=0.05), np.zeros(int(SR * 0.04))]
            f = f2
        return np.concatenate(parts)
    parts = []
    for _ in range(r.integers(2, 5)):
        f = r.uniform(3000, 4500)
        parts += [chirp(f, f * r.uniform(1.3, 1.7), r.uniform(0.05, 0.09)), np.zeros(int(SR * r.uniform(0.06, 0.14)))]
    return np.concatenate(parts)


def birds(seed, kinds, gap, level):
    r = np.random.default_rng(seed)
    out = np.zeros((2, N))
    for kind in kinds:
        pan = r.uniform(0.15, 0.85)
        lv = r.uniform(0.6, 1.0) * level
        t = r.uniform(0.0, gap[0])
        while t < DUR:
            place(out, bird_call(kind, r), t, pan, lv)
            t += r.uniform(*gap)
    return out


def modal_hit(r, freqs, taus, amps, dur, exc_ms=2.0, exc_lp=4000.0, click=0.3):
    """A struck object: a short noise burst through decaying sinusoidal modes (with a little random detune)."""
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for f, tau, a in zip(freqs, taus, amps):
        f *= r.uniform(0.985, 1.015)
        y += a * np.sin(2 * np.pi * f * t + r.uniform(0, 2 * np.pi)) * np.exp(-t / tau)
    m = int(exc_ms / 1000 * SR)
    burst = np.zeros(n)
    burst[:m] = r.standard_normal(m) * np.hanning(2 * m)[m:]
    burst = sfilt(burst, "lowpass", exc_lp, 2)
    y = y * np.clip(t / 0.0006, 0, 1) + click * burst / (np.abs(burst).max() + 1e-12)
    return y


def passing_vehicle(r, tc, speed, lateral, direction, f_engine, harmonics, tyre_level, engine_level, span=8.0,
                    engine_lp=900.0):
    """A vehicle driving past: engine harmonics with Doppler, tyre roar that brightens as it nears, equal-power pan
    following its bearing. Returns (stereo event, start time)."""
    n = int(2 * span * SR)
    t = np.arange(n) / SR - span
    c = 343.0
    p = speed * t * direction                    # along the road; listener at 0
    rr = np.sqrt(p ** 2 + lateral ** 2)
    radial = speed * (speed * t) / rr            # d|r|/dt
    dop = c / (c + radial)
    near = lateral / rr                          # 1 at the closest point
    f = f_engine * dop * (1 + 0.04 * np.sin(2 * np.pi * 0.31 * t + r.uniform(0, 6.28)))
    ph = 2 * np.pi * np.cumsum(f) / SR
    eng = sum((1.0 / k ** 0.8) * r.uniform(0.5, 1.0) * np.sin(k * ph + r.uniform(0, 6.28)) for k in range(1, harmonics))
    eng = sfilt(eng, "lowpass", engine_lp, 2) * (1 + 0.06 * unit(sfilt(r.standard_normal(n), "lowpass", 12, 1)))   # load wobble
    roar = sfilt(r.standard_normal(n), "bandpass", [220, 1500], 2)
    hiss = sfilt(r.standard_normal(n), "bandpass", [1500, 5000], 2)
    mono = (unit(eng) * engine_level * near ** 1.1 + unit(roar) * tyre_level * near ** 1.3
            + unit(hiss) * tyre_level * 0.5 * near ** 2.2)
    win = np.ones(n)
    k = int(0.5 * SR)
    win[:k] = np.linspace(0, 1, k) ** 2
    win[-k:] = np.linspace(1, 0, k) ** 2
    mono *= win
    pan = 0.5 + 0.42 * p / rr
    st = np.stack([mono * np.cos(pan * np.pi / 2), mono * np.sin(pan * np.pi / 2)])
    return st, tc - span


def place_st(bus, st, t0, gain=1.0):
    s = int(round(t0 * SR)) % N
    idx = (np.arange(st.shape[1]) + s) % N
    bus[:, idx] += st * gain


# ---------------------------------------------------------------- city

def city():
    layers = {}
    # traffic hum: a block or two of steady traffic, brown rumble + low-mid drone, slow swells
    hum = bed(101, "lowpass", 260, 2, "brown") * 1.0 + bed(102, "bandpass", [180, 900], 2) * 0.35
    hum += bed(104, "bandpass", [1500, 6000], 2) * 0.06                     # far-off tyre hiss off the walls
    hum = cfilt(hum, "highpass", 30, 2) * slow_env(0.06, 0.7, 1.0, 103)
    layers["traffic hum"] = (hum, -24.5)
    # cars passing (tc, speed m/s, lateral m, direction, engine Hz, harmonics, tyre, engine)
    r = np.random.default_rng(110)
    cars = np.zeros((2, N))
    for tc, v, lat, d, fe, h, ty, en in [(2.8, 13, 11, 1, 38, 14, 1.0, 0.7), (9.3, 11, 22, -1, 33, 14, 0.9, 0.6),
                                         (13.9, 8, 9, 1, 21, 18, 1.0, 1.0), (20.6, 15, 14, -1, 44, 12, 1.0, 0.6),
                                         (26.2, 12, 26, 1, 36, 14, 0.8, 0.6), (30.4, 10, 18, -1, 30, 14, 0.9, 0.7)]:
        st, t0 = passing_vehicle(r, tc, v, lat, d, fe, h, ty, en)
        place_st(cars, st, t0, gain=r.uniform(0.8, 1.0))
    layers["passing cars"] = (cars, -26.5)
    # the odd distant horn: a dual-tone car horn, double beep at 7 s (left), one longer honk at 23.5 s (right)
    horns = np.zeros((2, N))
    for t0, pan, beeps, lvl in [(7.1, 0.22, [(0.0, 0.16), (0.24, 0.38)], 1.0), (23.5, 0.8, [(0.0, 0.55)], 0.7)]:
        for off, d in beeps:
            n = int((d + 0.05) * SR)
            t = np.arange(n) / SR
            x = sum((1.0 / k) * (np.sin(2 * np.pi * 415 * k * t) + 0.9 * np.sin(2 * np.pi * 523 * k * t))
                    for k in range(1, 12))
            x = sfilt(sfilt(x, "bandpass", [350, 2600], 2), "lowpass", 1800, 2)
            x *= np.clip(t / 0.012, 0, 1) * np.clip((d - t) / 0.03 + 1, 0, 1)
            place(horns, x, t0 + off, pan, lvl)
    layers["horns"] = (horns, -38.5)
    # crowd murmur: 18 talkers, near and far, low-passed and diffused
    r = np.random.default_rng(120)
    crowd = np.zeros((2, N))
    for i in range(18):
        female = i % 2 == 1
        f0 = r.uniform(175, 235) if female else r.uniform(95, 140)
        place(crowd, voice(r, f0, female, r.uniform(1.0, 3.0)), 0.0, r.uniform(0.1, 0.9), r.uniform(0.3, 1.0))
    crowd = cfilt(cfilt(crowd, "lowpass", 2800, 2), "highpass", 120, 2) * slow_env(0.05, 0.75, 1.0, 121)
    layers["crowd murmur"] = (crowd, -27.0)
    # footsteps: walkers passing (centre time, pass length, pan from, pan to, step s, kind)
    r = np.random.default_rng(130)
    steps = np.zeros((2, N))
    for tc, span, p0, p1, sp, kind in [(4.5, 7.0, 0.15, 0.75, 0.54, "shoe"), (12.5, 6.0, 0.85, 0.35, 0.36, "heel"),
                                       (19.0, 8.0, 0.3, 0.9, 0.58, "sneaker"), (27.5, 7.0, 0.7, 0.2, 0.5, "shoe")]:
        t = tc - span / 2
        while t < tc + span / 2:
            fr = (t - (tc - span / 2)) / span
            g = np.exp(-((fr - 0.5) / 0.22) ** 2) * r.uniform(0.75, 1.0)
            n = int(0.12 * SR)
            tt = np.arange(n) / SR
            if kind == "sneaker":
                x = unit(sfilt(r.standard_normal(n), "bandpass", [300, 2200], 2)) * np.exp(-tt / 0.02) * 0.6
            else:
                bright = [1800, 6000] if kind == "heel" else [1200, 4500]
                x = (unit(sfilt(r.standard_normal(n), "bandpass", bright, 2)) * np.exp(-tt / 0.005)
                     + unit(sfilt(r.standard_normal(n), "bandpass", [140, 450], 2)) * np.exp(-tt / 0.014) * 0.6)
                toe = np.zeros(n)
                k = int(0.055 * SR)
                toe[k:] = unit(sfilt(r.standard_normal(n - k), "bandpass", [900, 3500], 2)) * np.exp(-tt[: n - k] / 0.004) * 0.35
                x += toe
            place(steps, x * np.clip(tt / 0.0005, 0, 1), t, p0 + (p1 - p0) * fr, g)
            t += sp * r.uniform(0.95, 1.05)
    layers["footsteps"] = (steps, -40.0)
    # pigeons: cooing on a ledge now and then; one little flock clatters off at ~18 s
    r = np.random.default_rng(140)
    pig = np.zeros((2, N))
    for pan in (0.25, 0.55, 0.8):
        t = r.uniform(0, 5)
        while t < DUR:
            f = r.uniform(430, 520)
            parts = []
            for seg, d, flut in [("oo", 0.22, 0.0), ("rroo", r.uniform(0.5, 0.75), 0.6), ("oo", 0.28, 0.0)]:
                n = int(d * SR)
                tt = np.arange(n) / SR
                cont = f * (1 + 0.12 * np.sin(np.pi * tt / d)) * (0.92 if seg == "oo" else 1.0)
                ph = 2 * np.pi * np.cumsum(cont) / SR
                x = np.sin(ph) + 0.3 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) + 0.03 * r.standard_normal(n)
                x *= (1 - flut * 0.5 * (1 + np.sin(2 * np.pi * r.uniform(26, 34) * tt))) * np.sin(np.pi * tt / d) ** 0.9
                parts += [x, np.zeros(int(SR * 0.07))]
            place(pig, sfilt(np.concatenate(parts), "lowpass", 2000, 2), t, pan, r.uniform(0.6, 1.0))
            t += r.uniform(4.0, 9.0)
    for b in range(4):                       # wing claps, ~10/s, fading as they go
        pan0 = r.uniform(0.35, 0.65)
        t0 = 18.0 + r.uniform(0, 0.25)
        rate = r.uniform(8.5, 11.0)
        for k in range(14):
            n = int(0.03 * SR)
            tt = np.arange(n) / SR
            x = unit(sfilt(r.standard_normal(n), "bandpass", [350, 3500], 2)) * np.exp(-tt / 0.008)
            place(pig, x, t0 + k / rate, pan0 + (k / 14) * (0.4 if b % 2 else -0.4), np.exp(-k / 6) * 1.6)
    layers["pigeons"] = (pig, -29.0)
    # street canyon: slap echoes off the buildings + a short diffuse tail
    ir = make_ir(1.1, 2.0, 150, predelay=0.02, lp=4500, early=[(37, 0.30, 0.2), (61, 0.22, 0.8), (97, 0.15, 0.35),
                                                                (143, 0.10, 0.7)])
    sends = {"traffic hum": 0.2, "passing cars": 0.35, "horns": 0.9, "crowd murmur": 0.5, "footsteps": 0.45,
             "pigeons": 0.35}
    return layers, ir, sends


# ---------------------------------------------------------------- industrial

def industrial():
    layers = {}
    r = np.random.default_rng(200)
    # mains hum and a big dust extractor, a few buildings away
    hum = np.zeros(N)
    for k, a in zip(range(1, 9), [0.2, 1.0, 0.5, 0.6, 0.25, 0.35, 0.15, 0.15]):
        hum += a * np.sin(2 * np.pi * 60 * k * T + r.uniform(0, 6.28)) * slow_env(0.04 * k, 0.75, 1.0, 210 + k)
    hum = np.stack([hum, hum])
    fan = (cmodes(bed(201, "lowpass", 900, 2), [112, 224, 336, 448], [6, 8, 8, 8], [1.0, 0.6, 0.4, 0.3])
           + cfilt(bed(202, "bandpass", [150, 1400], 2), "highpass", 100, 2) * 0.7)
    whine = np.sin(2 * np.pi * np.cumsum(1480 * (1 + 0.002 * np.sin(2 * np.pi * 5 * T / DUR))) / SR)   # a motor, far off
    chug = np.zeros((2, N))
    for cyc, f_lo, pan, a in [(128, 70, 0.7, 1.0), (86, 110, 0.3, 0.7)]:      # two compressors, 4 Hz and 2.69 Hz
        ph = (cyc * T / DUR) % 1.0
        pulse = np.exp(-ph * (DUR / cyc) / 0.05)
        src = unit(cfilt(np.random.default_rng(220 + cyc).standard_normal(N), "bandpass", [f_lo, f_lo * 4], 2)) * pulse
        place(chug, src, 0.0, pan, a)
    mach = (unit(hum) * 0.5 + unit(fan) * 0.8 + unit(chug) * 0.5) * slow_env(0.05, 0.8, 1.0, 203)
    mach = cfilt(cfilt(mach, "lowpass", 1400, 2), "highpass", 45, 2)
    place(mach, whine * 0.03, 0.0, 0.6)
    layers["machinery"] = (mach, -24.0)
    # reversing beepers: a forklift close-ish (left) and a truck further off (right)
    beeps = np.zeros((2, N))
    for t0, count, period, f, pan, lvl, lp in [(3.6, 6, 1.0, 1050, 0.3, 1.0, 3500), (19.4, 5, 0.92, 1230, 0.74, 0.75, 2600)]:
        for k in range(count):
            n = int(0.5 * period * SR)
            tt = np.arange(n) / SR
            x = np.sin(2 * np.pi * f * tt) + 0.25 * np.sin(2 * np.pi * 3 * f * tt) + 0.1 * np.sin(2 * np.pi * 5 * f * tt)
            x *= np.clip(tt / 0.004, 0, 1) * np.clip((n / SR - tt) / 0.008, 0, 1)
            place(beeps, sfilt(x, "lowpass", lp, 2), t0 + k * period, pan, lvl * (1 - 0.06 * (k % 2)))
    layers["reversing beeps"] = (beeps, -42.0)
    # metal: a steel plate dropped (and bouncing), a chain rattling, a container door, a pipe knocked
    r = np.random.default_rng(230)
    clank = np.zeros((2, N))
    plate = [1, 1.6, 2.13, 2.66, 3.24, 3.96, 4.5, 5.2, 6.1]
    for t0, f1, pan, lvl, taus, dur in [(7.3, 180, 0.66, 1.0, 1.1, 2.5), (7.48, 180, 0.66, 0.35, 0.7, 1.5),
                                        (25.1, 74, 0.82, 0.9, 1.4, 3.0), (30.2, 520, 0.38, 0.5, 0.5, 1.2)]:
        fs = [f1 * k for k in plate]
        ts = [taus / (1 + 0.35 * i) for i in range(len(plate))]
        am = [r.uniform(0.4, 1.0) / (1 + 0.15 * i) for i in range(len(plate))]
        place(clank, modal_hit(r, fs, ts, am, dur, exc_lp=3500), t0, pan, lvl)
    for k in range(7):
        f1 = r.uniform(900, 1500)
        fs = [f1 * q for q in (1, 2.7, 4.1, 5.9)]
        place(clank, modal_hit(r, fs, [0.25, 0.15, 0.1, 0.07], [1, 0.6, 0.4, 0.25], 0.6, exc_ms=1.0, exc_lp=6000),
              13.8 + k * r.uniform(0.05, 0.11), 0.3, r.uniform(0.25, 0.5))
    clank = cfilt(clank, "lowpass", 5000, 2)
    layers["metal clanks"] = (clank, -33.0)
    # a truck going by on the far side of the yard
    st, t0 = passing_vehicle(r, 15.5, 9, 55, 1, 24, 18, 0.7, 1.0, span=10.0, engine_lp=600)
    truck = np.zeros((2, N))
    place_st(truck, st, t0)
    layers["distant truck"] = (cfilt(truck, "lowpass", 1800, 2), -30.5)
    # gusty wind through the yard, whistling a little at the strongest gusts, a loose sheet rattling
    gust = slow_env(0.08, 0.3, 1.0, 240)
    wind = cfilt(cfilt(bed(241, "lowpass", 650, 2), "highpass", 50, 2), "lowpass", 2000, 1) * gust
    wh = cmodes(bed(242, "lowpass", 4000, 1), [780, 1172], [45, 50], [1.0, 0.6])
    hiss = cfilt(bed(244, "bandpass", [900, 5000], 1), "lowpass", 6000, 2) * gust ** 2
    wind = unit(wind) + unit(wh) * 0.12 * gust ** 3 + unit(hiss) * 0.25
    rat = np.zeros(N)
    rr = np.random.default_rng(243)
    p = rr.random(N) < (gust ** 4) * 18 / SR
    rat[p] = rr.uniform(0.3, 1.0, p.sum())
    rat = cmodes(rat, [310, 540, 870], [12, 12, 10], [1.0, 0.7, 0.4])
    place(wind, rat / (np.abs(rat).max() + 1e-9) * 0.5, 0.0, 0.62)
    layers["wind"] = (wind, -24.5)
    ir = make_ir(2.2, 3.0, 250, predelay=0.04, lp=4000, early=[(120, 0.35, 0.3), (185, 0.28, 0.75), (310, 0.2, 0.45),
                                                                 (470, 0.12, 0.6)])
    sends = {"machinery": 0.3, "reversing beeps": 0.9, "metal clanks": 0.9, "distant truck": 0.4, "wind": 0.0}
    return layers, ir, sends


# ---------------------------------------------------------------- studio backlot

def radio_tune(seed):
    """A small band tune at 120 bpm, 16 bars = 32 s exactly (I-vi-IV-V twice), as heard from a cheap radio."""
    r = np.random.default_rng(seed)
    beat = 0.5
    midi = lambda m: 440.0 * 2 ** ((m - 69) / 12)
    chords = [(48, [60, 64, 67]), (45, [57, 60, 64]), (41, [57, 60, 65]), (43, [55, 59, 62])] * 2
    pent = [72, 74, 76, 79, 81, 84]
    out = np.zeros(N)

    def note(f, dur, odd=True, a=0.008, d=0.9):
        n = int((dur + 0.06) * SR)
        t = np.arange(n) / SR
        ks = range(1, 10, 2) if odd else range(1, 6)
        x = sum((1.0 / k ** (1.0 if odd else 2.0)) * np.sin(2 * np.pi * f * k * t * (1 + 0.003 * np.sin(2 * np.pi * 5 * t)))
                for k in ks if f * k < 4000)
        env = np.clip(t / a, 0, 1) * np.exp(-t / d) * np.clip((dur + 0.06 - t) / 0.06, 0, 1)
        return x * env

    i = int(r.integers(len(pent)))
    for c, (root, tri) in enumerate(chords):
        t0 = c * 8 * beat
        for b in range(8):
            if b % 2 == 0:
                addwrap(out, note(midi(root - 12 + (7 if b % 4 == 2 else 0)), beat * 0.9, odd=False, d=0.4) * 0.8,
                        t0 + b * beat)
            else:
                for m in tri:
                    addwrap(out, note(midi(m), beat * 0.35, odd=True, a=0.004, d=0.12) * 0.22, t0 + b * beat)
                n = int(0.1 * SR)
                addwrap(out, unit(sfilt(r.standard_normal(n), "bandpass", [1800, 5000], 2)) * np.exp(-np.arange(n) / (SR * 0.03)) * 0.12,
                        t0 + b * beat)
        tb = 0.0
        while tb < 8:
            d = r.choice([0.5, 1.0, 1.0, 1.5, 2.0])
            i = int(np.clip(i + r.integers(-2, 3), 0, len(pent) - 1))
            if r.random() > 0.15:
                addwrap(out, note(midi(pent[i]), min(d, 8 - tb) * beat * 0.92, a=0.01, d=0.6) * 0.5, t0 + tb * beat)
            tb += d
    return out


def studio():
    layers = {}
    # diesel generator behind a trailer: 4-cylinder at 1800 rpm (60 Hz firing), uneven cylinders, enclosure modes
    r = np.random.default_rng(300)
    f = 60.0 * (1 + 0.004 * np.sin(2 * np.pi * 3 * T / DUR))       # wobbles but keeps 1920 whole cycles per loop
    ph = np.cumsum(f) / SR
    ph -= ph[0]
    ph *= 1920.0 / (ph[-1] + f[-1] / SR)
    cyl = np.array([1.0, 0.82, 0.93, 0.78])[np.floor(ph).astype(int) % 4]
    pulse = np.exp(-(ph % 1.0) / 60.0 / 0.0035) * cyl
    body = cmodes(pulse - pulse.mean(), [60, 120, 190, 310], [4, 6, 8, 8], [1.0, 0.7, 0.45, 0.3])
    clat = unit(cfilt(r.standard_normal(N), "bandpass", [700, 2400], 2)) * cfilt(pulse, "lowpass", 300, 1)
    exh = unit(cfilt(r.standard_normal(N), "lowpass", 250, 2)) * (0.6 + 0.4 * pulse / pulse.max())
    gen = unit(body) * 1.0 + unit(clat) * 0.25 + unit(exh) * 0.45
    gen = cfilt(gen, "lowpass", 1400, 2)
    g = np.zeros((2, N))
    place(g, gen, 0.0, 0.44)
    g += bed(301, "lowpass", 400) * 0.08
    layers["generator"] = (g, -26.0)
    # crew murmur far across the lot: a handful of talkers, sporadic, and a couple of calls
    r = np.random.default_rng(310)
    crew = np.zeros((2, N))
    for i in range(7):
        female = i in (1, 4, 6)
        f0 = r.uniform(180, 230) if female else r.uniform(95, 135)
        place(crew, voice(r, f0, female, r.uniform(2.5, 5.0), calls=1 if i in (0, 4) else 0), 0.0,
              r.uniform(0.25, 0.85), r.uniform(0.5, 1.0))
    crew = cfilt(cfilt(crew, "lowpass", 1700, 2), "highpass", 150, 2)
    layers["crew murmur"] = (crew, -34.0)
    # hammering: three runs of nail strikes, the last blows of a run duller as the nail goes home
    r = np.random.default_rng(320)
    ham = np.zeros((2, N))
    for t0, count, gap, pan, lvl in [(5.4, 5, 0.42, 0.7, 1.0), (17.1, 7, 0.36, 0.22, 0.6), (26.0, 4, 0.5, 0.58, 0.85)]:
        for k in range(count):
            home = k / max(1, count - 1)
            ping = [f * (1 - 0.18 * home) for f in (2900, 4700, 6900)]
            thunk = [190, 340, 560, 900]
            x = (modal_hit(r, ping, [0.05, 0.03, 0.018], [1.0 - 0.5 * home, 0.6, 0.35], 0.4, exc_ms=0.6, exc_lp=8000, click=0.6)
                 + modal_hit(r, thunk, [0.05, 0.035, 0.025, 0.015], [1.0, 0.8, 0.5, 0.3], 0.4, exc_ms=2.0, exc_lp=2000,
                             click=0.2) * (0.8 + 0.6 * home))
            place(ham, sfilt(x, "lowpass", 4200, 2), t0 + k * gap * r.uniform(0.95, 1.06), pan, lvl * r.uniform(0.85, 1.0))
    layers["hammering"] = (ham, -43.0)
    # a radio somewhere on the lot: tinny band, carried in and out on the breeze
    rad = radio_tune(330)
    rad = cfilt(cfilt(rad, "highpass", 380, 2), "lowpass", 3000, 2)
    rad = np.tanh(2.2 * rad / np.abs(rad).max())
    rad += 0.03 * unit(cfilt(np.random.default_rng(331).standard_normal(N), "bandpass", [1000, 5000], 2))
    rad = cfilt(rad, "lowpass", 2300, 2) * slow_env(0.06, 0.25, 1.0, 332)
    radio = np.zeros((2, N))
    place(radio, rad, 0.0, 0.66)
    layers["radio"] = (radio, -36.0)
    layers["birds"] = (birds(340, ["whistle", "tweet", "trill"], (5.0, 11.0), 0.25), -41.0)
    breeze = cfilt(bed(350, "lowpass", 600, 2), "highpass", 50, 2) * slow_env(0.07, 0.4, 1.0, 351)
    breeze += bed(352, "lowpass", 160, 2, "brown") * 0.5                      # the city beyond the walls
    breeze += bed(353, "bandpass", [1800, 6500], 1) * 0.12 * slow_env(0.07, 0.4, 1.0, 351) ** 2   # air in the trees
    layers["breeze + far traffic"] = (breeze, -30.0)
    ir = make_ir(1.4, 2.5, 360, predelay=0.03, lp=4500, early=[(150, 0.42, 0.35), (210, 0.3, 0.7), (330, 0.16, 0.5)])
    sends = {"generator": 0.25, "crew murmur": 0.7, "hammering": 0.75, "radio": 0.8, "birds": 0.35,
             "breeze + far traffic": 0.0}
    return layers, ir, sends


# ---------------------------------------------------------------- loudness, mixing, output

def _kfilters():
    fs = SR
    G, Q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    K = np.tan(np.pi * fc / fs)
    Vh = 10 ** (G / 20)
    Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    fc2, Q2 = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * fc2 / fs)
    a0 = 1 + K / Q2 + K * K
    return (b1, a1), ([1.0, -2.0, 1.0], [1, 2 * (K * K - 1) / a0, (1 - K / Q2 + K * K) / a0])


def integrated_lufs(st):
    """BS.1770 integrated loudness (400 ms blocks, 75 % overlap, absolute and relative gates) of a stereo loop."""
    (b1, a1), (b2, a2) = _kfilters()
    f = np.fft.rfftfreq(N, 1 / SR)
    _, h1 = signal.freqz(b1, a1, worN=f, fs=SR)
    _, h2 = signal.freqz(b2, a2, worN=f, fs=SR)
    z = np.fft.irfft(np.fft.rfft(st, axis=-1) * h1 * h2, N, axis=-1)
    blk, hop = int(0.4 * SR), int(0.1 * SR)
    c = np.concatenate([np.zeros((2, 1)), np.cumsum(z ** 2, axis=1)], axis=1)
    starts = np.arange(0, N - blk + 1, hop)
    p = ((c[:, starts + blk] - c[:, starts]) / blk).sum(0)
    l = -0.691 + 10 * np.log10(p + 1e-20)
    p = p[l > -70]
    rel = -0.691 + 10 * np.log10(p.mean()) - 10
    p = p[-0.691 + 10 * np.log10(p) > rel]
    return -0.691 + 10 * np.log10(p.mean())


def softclip(x, thresh):
    a = np.abs(x)
    over = a > thresh
    y = x.copy()
    y[over] = np.sign(x[over]) * (thresh + (1 - thresh) * np.tanh((a[over] - thresh) / (1 - thresh)))
    return y


def ffmpeg_lufs(path):
    p = subprocess.run(["ffmpeg", "-nostats", "-i", path, "-af", "ebur128", "-f", "null", "-"],
                       capture_output=True, text=True)
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", p.stderr)[-1])


def build(name, title, fn):
    layers, ir, sends = fn()
    mix = np.zeros((2, N))
    for k, (st, lvl) in layers.items():
        st = st / (np.sqrt((st ** 2).mean()) + 1e-12) * 10 ** (lvl / 20)      # each layer to its RMS (dBFS)
        st = reverb(st, ir, sends.get(k, 0.0) * 0.6, dry=1.0)
        mix += st
        print(f"   {k:22s} rms {rms_db(st):6.1f} dBFS  peak {20 * np.log10(np.abs(st).max()):6.1f} dBFS")
    mix = cfilt(mix, "highpass", 30, 2)
    gain_db = 0.0
    for _ in range(4):                                         # loudness to the park's, peaks soft-limited under -2 dBFS
        mix *= 10 ** ((TARGET_LUFS - integrated_lufs(mix)) / 20)
        if np.abs(mix).max() > PEAK_CEIL:
            mix = softclip(mix / PEAK_CEIL, 0.75) * PEAK_CEIL
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, name + ".ogg")
    for attempt in range(3):                                   # Vorbis shifts loudness a hair: measure, correct, re-encode
        with tempfile.TemporaryDirectory() as d:
            wav = os.path.join(d, "amb.wav")
            pcm = (np.clip(mix.T * 10 ** (gain_db / 20), -1, 1) * 32767).astype(np.int16)
            with wave.open(wav, "wb") as f:
                f.setnchannels(2)
                f.setsampwidth(2)
                f.setframerate(SR)
                f.writeframes(pcm.tobytes())
            subprocess.run(["oggenc", "-q", "1", "--quiet", "-t", title, "-a", "Not Pro Skater", "-o", out, wav], check=True)
        got = ffmpeg_lufs(out)
        if abs(got - TARGET_LUFS) <= 0.1:
            break
        gain_db += TARGET_LUFS - got
    print(f"[ambience] wrote {out} {os.path.getsize(out)} bytes, {got:.1f} LUFS (ebur128)")


AMBIENCES = {
    "city": ("city_ambience", "City ambience", city),
    "industrial": ("industrial_ambience", "Industrial ambience", industrial),
    "studio": ("studio_ambience", "Studio backlot ambience", studio),
}


def main():
    for key in sys.argv[1:] or list(AMBIENCES):
        name, title, fn = AMBIENCES[key]
        print(f"[ambience] {name}")
        build(name, title, fn)


if __name__ == "__main__":
    main()
