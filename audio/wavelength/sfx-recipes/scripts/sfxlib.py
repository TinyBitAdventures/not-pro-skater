"""Slice, trim, fold to mono, normalise, measure. numpy/scipy only (plus ffmpeg for decode and the loop crossfade)."""
import json, os, struct, subprocess, tempfile
import numpy as np
from scipy import signal
from scipy.io import wavfile
from specs import SR

RNG = np.random.default_rng(1234)


def load_mix(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "f32le", "-ac", "2", "-ar", str(SR), "-"],
                         capture_output=True).stdout
    return np.frombuffer(raw, dtype="<f4").reshape(-1, 2).astype(np.float64)


def db(v):
    return 20 * np.log10(max(float(v), 1e-12))


def kfilters(fs):
    G, Q, fc = 3.999843853973347, 0.7071752369554196, 1681.974450955533
    K = np.tan(np.pi * fc / fs); Vh = 10 ** (G / 20); Vb = Vh ** 0.4996667741545416
    a0 = 1 + K / Q + K * K
    b1 = [(Vh + Vb * K / Q + K * K) / a0, 2 * (K * K - Vh) / a0, (Vh - Vb * K / Q + K * K) / a0]
    a1 = [1, 2 * (K * K - 1) / a0, (1 - K / Q + K * K) / a0]
    fc2, Q2 = 38.13547087602444, 0.5003270373238773
    K = np.tan(np.pi * fc2 / fs); a0 = 1 + K / Q2 + K * K
    return (np.array(b1), np.array(a1)), (np.array([1.0, -2.0, 1.0]), np.array([1, 2 * (K * K - 1) / a0, (1 - K / Q2 + K * K) / a0]))

# self-check against the report's 48 kHz coefficients
_k48 = kfilters(48000)
assert np.allclose(_k48[0][0], [1.53512485958697, -2.69169618940638, 1.19839281085285], atol=1e-6)
assert np.allclose(_k48[1][1], [1.0, -1.99004745483398, 0.99007225036621], atol=1e-6)
K1, K2 = kfilters(SR)


def kw(x):
    return signal.lfilter(*K2, signal.lfilter(*K1, x))


def lufs_of_ms(ms):
    return -0.691 + 10 * np.log10(max(ms, 1e-14))


def sliding_lufs_max(x, win_s):
    k = kw(x); w = int(round(win_s * SR))
    if len(k) < w:
        k = np.concatenate([k, np.zeros(w - len(k))])
    c = np.concatenate([[0.0], np.cumsum(k ** 2)])
    return lufs_of_ms(((c[w:] - c[:-w]) / w).max())


def clip_lufs(x):
    return lufs_of_ms(float((kw(x) ** 2).mean()))


def frames_peak(x, hop_s=0.0025):
    hop = int(hop_s * SR); n = len(x) // hop
    return np.abs(x[: n * hop]).reshape(n, hop).max(axis=1), hop


def centroid(x):
    n = 1 << 17
    sp = np.abs(np.fft.rfft(x * np.hanning(len(x)), n)); fr = np.fft.rfftfreq(n, 1 / SR)
    return float((sp * fr).sum() / max(sp.sum(), 1e-12))


def centroid_pw(x):
    n = 1 << 17
    p = np.abs(np.fft.rfft(x * np.hanning(len(x)), n)) ** 2; fr = np.fft.rfftfreq(n, 1 / SR)
    return float((p * fr).sum() / max(p.sum(), 1e-20))


BANDS = [(0, 150), (150, 600), (600, 2500), (2500, 8000), (8000, 22050)]


def band_shares(x):
    n = 1 << 17
    p = np.abs(np.fft.rfft(x * np.hanning(len(x)), n)) ** 2; fr = np.fft.rfftfreq(n, 1 / SR)
    tot = max(p.sum(), 1e-20)
    return [round(float(100 * p[(fr >= lo) & (fr < hi)].sum() / tot), 1) for lo, hi in BANDS]


def band_split(x, lo, hi):
    if lo <= 0:
        sos = signal.butter(4, hi, "lowpass", fs=SR, output="sos")
    elif hi >= SR / 2 - 1:
        sos = signal.butter(4, lo, "highpass", fs=SR, output="sos")
    else:
        sos = signal.butter(4, [lo, hi], "bandpass", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def stereo_checks(L, R):
    ms = lambda v: float((v ** 2).mean())
    mono = 0.5 * (L + R)
    corr = float(np.corrcoef(L, R)[0, 1]) if L.std() > 1e-12 and R.std() > 1e-12 else 1.0
    lr = db(np.sqrt(ms(L) + 1e-20)) - db(np.sqrt(ms(R) + 1e-20))
    st_k = float((kw(L) ** 2).mean() + (kw(R) ** 2).mean())
    fold_k = 2 * float((kw(mono) ** 2).mean())
    fold_delta = 10 * np.log10(max(fold_k, 1e-20) / max(st_k, 1e-20))
    worst = 0.0; worst_band = None
    tot = ms(L) + ms(R)
    for lo, hi in BANDS:
        bl, br = band_split(L, lo, hi), band_split(R, lo, hi)
        e = ms(bl) + ms(br)
        if e / max(tot, 1e-20) < 0.05:
            continue
        d = 10 * np.log10(max(2 * ms(0.5 * (bl + br)), 1e-20) / e)
        if d < worst:
            worst, worst_band = d, f"{lo}-{hi} Hz"
    flag = None
    if corr < 0.0 or fold_delta < -3.0 or worst < -3.5:
        flag = "PHASE PROBLEM"
    elif corr < 0.5 or fold_delta < -1.5:
        flag = "wide/decorrelated (moderate mono loss)"
    return dict(lr_corr=round(corr, 3), lr_diff_db=round(float(lr), 2), mono_fold_loss_db=round(float(fold_delta), 2),
                worst_band_fold_db=round(float(worst), 2), worst_band=worst_band, mono_flag=flag)


def true_peak_db(x):
    return db(np.abs(signal.resample_poly(x, 4, 1)).max())


def to_int16(x, rng=RNG):
    d = rng.uniform(-0.5, 0.5, len(x)) + rng.uniform(-0.5, 0.5, len(x))
    return np.clip(np.round(x * 32767 + d), -32768, 32767).astype("<i2")


def write_wav(path, i16, loop=False):
    data = i16.astype("<i2").tobytes()
    fmt = struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16)
    body = b"fmt " + struct.pack("<I", 16) + fmt + b"data" + struct.pack("<I", len(data)) + data
    if loop:
        n = len(i16)
        smpl = struct.pack("<9I", 0, 0, int(round(1e9 / SR)), 60, 0, 0, 0, 1, 0) + struct.pack("<6I", 0, 0, 0, n - 1, 0, 0)
        body += b"smpl" + struct.pack("<I", len(smpl)) + smpl
    with open(path, "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", 4 + len(body)) + b"WAVE" + body)


def read_wav16(path):
    sr, x = wavfile.read(path)
    assert sr == SR and x.dtype == np.int16 and x.ndim == 1, (sr, x.dtype, x.shape)
    return x.astype(np.float64) / 32767


def fade_out(w, n, kind="qsin"):
    n = min(n, len(w))
    if n > 0:
        w[-n:] *= np.cos(0.5 * np.pi * np.linspace(0, 1, n))
    return w


def aw_shares(x):
    n = 1 << 17
    sp = np.fft.rfft(x * np.hanning(len(x)), n); fr = np.fft.rfftfreq(n, 1 / SR)
    f2 = np.maximum(fr, 1.0) ** 2
    ra = (12194 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194 ** 2))
    p = np.abs(sp) ** 2 * ra ** 2
    t = max(p.sum(), 1e-30)
    return round(float(100 * p[fr < 150].sum() / t), 1), round(float(100 * p[fr >= 2500].sum() / t), 1), round(float(100 * p[fr >= 8000].sum() / t), 1)


def measure_final(x, stereo_info, extra, xf=None):
    xf = x if xf is None else xf
    """x: final float mono (from int16). Measurements of the deliverable itself."""
    pk = np.abs(x).max()
    fr, hop = frames_peak(x)
    above = np.nonzero(fr > 10 ** (-60 / 20))[0]
    first = int(above[0]) if len(above) else 0
    last = int(above[-1]) if len(above) else 0
    idx = np.nonzero(np.abs(x) > 10 ** (-60 / 20))[0]
    rms = float(np.sqrt((x ** 2).mean()))
    m = dict(
        frames=len(x), duration_s=round(len(x) / SR, 4),
        peak_dbfs=round(db(pk), 2), true_peak_dbtp=round(float(true_peak_db(x)), 2),
        rms_dbfs=round(db(rms), 2), crest_db=round(db(pk) - db(rms), 2),
        lead_ms=round(1000 * float(idx[0]) / SR, 2) if len(idx) else None,
        tail_below_60dbfs_ms=round(1000 * (len(x) - (idx[-1] + 1)) / SR, 2) if len(idx) else None,
        onset_to_last_above_60dbfs_ms=round(1000 * float(idx[-1] - idx[0]) / SR, 1) if len(idx) else None,
        last_sample=float(x[-1]), dc_offset=round(float(x.mean()), 6),
        centroid_hz=round(centroid(xf), 0), centroid_first300ms_hz=round(centroid(xf[: int(0.3 * SR)]), 0),
        centroid_power_weighted_hz=round(centroid_pw(xf), 0),
        band_pct=dict(zip(["<150", "150-600", "0.6-2.5k", "2.5-8k", ">8k"], band_shares(xf))),
        a_weighted_pct=dict(zip(["<150", ">2.5k", ">8k"], aw_shares(xf))),
        lufs_clip=round(clip_lufs(x), 2), lufs_m400=round(sliding_lufs_max(x, 0.4), 2),
        lufs_s3=round(sliding_lufs_max(x, 3.0), 2),
    )
    m.update(stereo_info); m.update(extra)
    return m


def finish_oneshot(stereo, target_s, fade_ms):
    L, R = stereo[:, 0], stereo[:, 1]
    mono = 0.5 * (L + R)
    pk_all = np.abs(mono).max()
    on = int(np.nonzero(np.abs(mono) > pk_all * 10 ** (-70 / 20))[0][0])   # first audible sample (-70 dB re raw peak)
    n_t = int(round(target_s * SR))
    # onset at -60 dBFS of the final level: refine after choosing the window
    w0 = mono[on: on + n_t + int(0.2 * SR)]
    pk_w = np.abs(w0[:n_t]).max()
    thr = pk_w * 10 ** (-59 / 20)                                   # -60 dBFS once the peak sits at -1 dBFS
    idx = np.nonzero(np.abs(mono) > thr)[0]
    onset = int(idx[0])
    start = max(0, onset - int(round(0.0015 * SR)))
    raw_seg = mono[start:]
    fr, hop = frames_peak(raw_seg)
    ab = np.nonzero(fr > thr)[0]
    nat_end = int((ab[-1] + 1) * hop)                               # samples from start to the last frame above -60 dBFS
    render_limited = (len(raw_seg) - nat_end) < 3 * hop
    if nat_end + int(0.010 * SR) < n_t:
        end = nat_end + int(0.010 * SR); fade_n = int(0.010 * SR); truncated = False
    else:
        end = n_t; fade_n = int(round(fade_ms / 1000 * SR)); truncated = True
    end = min(end, len(raw_seg))
    st = stereo[start:start + end]
    w = mono[start:start + end].copy()
    fin = min(int(0.0005 * SR), len(w))
    w[:fin] *= np.sin(0.5 * np.pi * np.linspace(0, 1, fin)) ** 2
    w = fade_out(w, fade_n)
    g = 10 ** (-1.0 / 20) / np.abs(w).max()
    wg = w * g
    ia = np.nonzero(np.abs(wg) > 10 ** (-60 / 20))[0]
    cut = min(len(wg), int(ia[-1]) + 1 + int(round(0.002 * SR)))
    wg = fade_out(wg[:cut].copy(), int(round(0.002 * SR)))
    st = st[:cut]
    xf = wg
    i16 = to_int16(wg)
    info = stereo_checks(st[:, 0], st[:, 1])
    extra = dict(gain_applied_db=round(db(g), 2), natural_tail_ms=round(1000 * (nat_end - (onset - start)) / SR, 0),
                 natural_tail_render_limited=bool(render_limited), truncated_by_target=bool(truncated),
                 target_s=target_s, fade_ms=fade_ms if truncated else 10)
    return i16, xf, info, extra


def loop_join_ffmpeg(stereo_slice):
    """The report's ffmpeg recipe: slice starts 1.0 s after the note start, length 2.15 s; tail folded onto head."""
    with tempfile.TemporaryDirectory() as td:
        a, b = os.path.join(td, "s.wav"), os.path.join(td, "loop.wav")
        wavfile.write(a, SR, stereo_slice.astype(np.float32))
        fg = ("[0:a]atrim=0:0.15,asetpts=N/SR/TB[h];[0:a]atrim=2.0:2.15,asetpts=N/SR/TB[t];"
              "[0:a]atrim=0.15:2.0,asetpts=N/SR/TB[b];[t][h]acrossfade=d=0.15:c1=qsin:c2=qsin[x];[x][b]concat=n=2:v=0:a=1[o]")
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", a, "-filter_complex", fg, "-map", "[o]", "-c:a", "pcm_f32le", b], check=True)
        return load_mix(b)


def octave_levels(x):
    n = len(x); p = np.abs(np.fft.rfft(x * np.hanning(n))) ** 2; fr = np.fft.rfftfreq(n, 1 / SR)
    edges = [88, 177, 354, 707, 1414, 2828, 5657, 11314, 20000]
    return np.array([10 * np.log10(p[(fr >= edges[i]) & (fr < edges[i + 1])].sum() + 1e-20) for i in range(len(edges) - 1)])


def seam_test(x):
    """x: one loop (float mono). Play it twice; measure the join at the wrap. Also every other 50 ms boundary as baseline."""
    n = len(x); y = np.concatenate([x, x, x])
    d = np.abs(np.diff(y)); p99 = np.percentile(d, 99)
    step = float(d[n - 1])
    w = int(0.002 * SR)
    hp = signal.sosfilt(signal.butter(4, 3000, "highpass", fs=SR, output="sos"), y)
    hp_seam = np.abs(hp[n - int(0.0015 * SR): n + int(0.0015 * SR)]).max()
    hp_env = np.abs(hp[int(0.05 * SR): n - int(0.05 * SR)])
    hp_ref = np.percentile(hp_env, 99.9)
    seg = int(0.05 * SR)
    rms = lambda v: float(np.sqrt((v ** 2).mean()) + 1e-12)
    last, first = x[-seg:], x[:seg]
    # baseline: adjacent 50 ms windows elsewhere (step of window RMS in dB and octave-band level distance)
    ds, dl = [], []
    for k in range(1, 3 * n // seg - 1):
        a, b = y[(k - 1) * seg: k * seg], y[k * seg: (k + 1) * seg]
        if k * seg % n == 0:
            continue
        ds.append(abs(db(rms(b)) - db(rms(a))))
        dl.append(float(np.abs(octave_levels(a) - octave_levels(b)).mean()))
    z = int(0.15 * SR)
    win = [db(rms(x[i:i + z])) for i in range(z, n - 2 * z, z // 2)]
    zone = db(rms(x[:z])); body = db(rms(x[z:]))
    seam_ds = abs(db(rms(first)) - db(rms(last)))
    seam_dl = float(np.abs(octave_levels(last) - octave_levels(first)).mean())
    return dict(
        wrap_step_over_p99=round(step / p99, 2),
        xfade_zone_150ms_rms_vs_body_db=round(zone - body, 2), body_150ms_window_rms_std_db=round(float(np.std(win)), 2),
        hf_click_ratio_seam_vs_p99_9=round(float(hp_seam / hp_ref), 2),
        last50ms_rms_dbfs=round(db(rms(last)), 2), first50ms_rms_dbfs=round(db(rms(first)), 2),
        seam_rms_step_db=round(seam_ds, 2), baseline_adjacent50ms_rms_step_db_median=round(float(np.median(ds)), 2),
        baseline_adjacent50ms_rms_step_db_p95=round(float(np.percentile(ds, 95)), 2),
        last50ms_centroid_hz=round(centroid(last), 0), first50ms_centroid_hz=round(centroid(first), 0),
        seam_octave_band_dist_db=round(seam_dl, 2), baseline_octave_band_dist_db_median=round(float(np.median(dl)), 2),
        baseline_octave_band_dist_db_p95=round(float(np.percentile(dl, 95)), 2),
    )


def finish_loop(stereo, note_start=1.0, lead_in=1.0, peak_db=-3.0):
    S = int(round((lead_in + note_start) * SR))
    sl = stereo[S: S + int(round(2.15 * SR))]
    assert len(sl) == int(round(2.15 * SR)), len(sl)
    lp = loop_join_ffmpeg(sl)
    assert len(lp) == 2 * SR, len(lp)
    mono = 0.5 * (lp[:, 0] + lp[:, 1])
    naive = 0.5 * (sl[: 2 * SR, 0] + sl[: 2 * SR, 1])
    g = 10 ** (peak_db / 20) / np.abs(mono).max()
    xf = mono * g
    i16 = to_int16(xf)
    info = stereo_checks(lp[:, 0], lp[:, 1])
    nv = naive * (10 ** (peak_db / 20) / np.abs(naive).max())
    d = np.abs(np.diff(np.concatenate([nv, nv]))); naive_ratio = float(d[len(nv) - 1] / np.percentile(d, 99))
    extra = dict(gain_applied_db=round(db(g), 2), naive_cut_wrap_step_over_p99=round(naive_ratio, 2), lfo_phase_note="slice starts 1.0 s after note start (whole-Hz LFOs)")
    return i16, xf, info, extra
