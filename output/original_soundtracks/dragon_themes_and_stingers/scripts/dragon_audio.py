"""Decoded-audio measurements shared by the dragon builder and verifier (numpy + FFmpeg only)."""
from __future__ import annotations

import math
import re
import subprocess

import numpy as np

RATE = 32000
PITCH_CLASSES = ["C", "C#", "D", "Eb", "E", "F", "F#", "G", "Ab", "A", "Bb", "B"]
ALIASES = {"Db": "C#", "D#": "Eb", "E#": "F", "Fb": "E", "Gb": "F#", "G#": "Ab", "A#": "Bb", "Cb": "B", "B#": "C"}
# Krumhansl-Kessler key profiles.
MAJOR = np.array([6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88])
MINOR = np.array([6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17])


def pitch_class(label):
    root = label[:2] if len(label) > 1 and label[1] in "#b" else label[:1]
    return PITCH_CLASSES.index(ALIASES.get(root, root))


def decode(path):
    out = subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(path), "-f", "f32le",
                          "-acodec", "pcm_f32le", "-ac", "2", "-ar", str(RATE), "-"],
                         check=True, capture_output=True).stdout
    return np.frombuffer(out, dtype="<f4").reshape(-1, 2).astype(np.float64)


def db(value):
    return 20 * math.log10(max(float(value), 1e-12))


def ebur128(path):
    """Integrated/momentary/short-term loudness plus true and sample peak (FFmpeg ebur128)."""
    run = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-nostats", "-v", "verbose", "-i", str(path),
                          "-filter_complex", "ebur128=peak=true+sample:framelog=verbose", "-f", "null", "-"],
                         capture_output=True, text=True, check=True)
    text = run.stderr
    value = r"(-?inf|-?\d+(?:\.\d+)?)"
    frames = re.findall(rf"M:\s*{value}\s+S:\s*{value}", text)
    summary = text[text.rfind("Summary:"):]
    number = lambda pattern: float(re.search(pattern, summary, re.S).group(1))  # noqa: E731
    return {"integrated_lufs": number(rf"I:\s*{value} LUFS"),
            "momentary_max_lufs": max(float(m) for m, _ in frames),
            # Short-term loudness needs a full 3 s window; shorter files report None.
            "short_term_max_lufs": max([float(s) for _, s in frames if float(s) > -70] or [None],
                                       key=lambda x: -999 if x is None else x),
            "true_peak_dbtp": number(rf"True peak:\s*Peak:\s*{value}"),
            "sample_peak_dbfs": number(rf"Sample peak:\s*Peak:\s*{value}")}


def _band_edges():
    return np.geomspace(60, 9000, 25)


def section_starts(score):
    """Seconds at which the authored sections (after the first) begin."""
    starts = [int(re.match(r"(\d+)", text).group(1)) for text in score["sections"]]
    return [(bar - 1) * 240 / score["bpm"] for bar in starts if bar > 1]


def seam_profile(frames, boundaries_seconds=(), rms_window=.1, spectrum_window=.25):
    """Compare the loop boundary (end -> start) with every internal adjacent-window transition
    and with the piece's own section boundaries."""
    mono = frames.mean(axis=1)

    def rms_blocks(n):
        count = len(mono) // n
        blocks = [mono[i * n:(i + 1) * n] for i in range(count)]
        return blocks, mono[-n:]

    n = round(rms_window * RATE)
    blocks, tail = rms_blocks(n)
    level = np.array([db(np.sqrt(np.mean(b ** 2))) for b in blocks])
    internal = np.abs(np.diff(level))
    seam_rms = abs(db(np.sqrt(np.mean(tail ** 2))) - level[0])
    m = round(spectrum_window * RATE)
    sblocks, stail = rms_blocks(m)
    edges, freqs = _band_edges(), np.fft.rfftfreq(m, 1 / RATE)
    window = np.hanning(m)

    def bands(block):
        power = np.abs(np.fft.rfft(block * window)) ** 2
        return np.array([10 * math.log10(max(power[(freqs >= a) & (freqs < b)].sum(), 1e-12))
                         for a, b in zip(edges, edges[1:])])
    spectra = [bands(b) for b in sblocks]
    spectral_internal = np.array([np.mean(np.abs(a - b)) for a, b in zip(spectra, spectra[1:])])
    seam_spectral = float(np.mean(np.abs(bands(stail) - spectra[0])))
    edge_rms, edge_band = [], []
    for seconds in boundaries_seconds:
        b = round(seconds * RATE)
        edge_rms.append(abs(db(np.sqrt(np.mean(mono[b - n:b] ** 2))) - db(np.sqrt(np.mean(mono[b:b + n] ** 2)))))
        edge_band.append(float(np.mean(np.abs(bands(mono[b - m:b]) - bands(mono[b:b + m])))))
    rms_limit = max([float(np.percentile(internal, 99))] + edge_rms) + .5
    band_limit = max([float(np.percentile(spectral_internal, 99))] + edge_band) + .5
    return {"within_internal_range": bool(seam_rms <= rms_limit and seam_spectral <= band_limit),
            "rms_limit_db": rms_limit, "band_limit_db": band_limit,
            "section_boundary_rms_step_db": edge_rms, "section_boundary_band_distance_db": edge_band,"rms_window_seconds": rms_window, "seam_rms_step_db": float(seam_rms),
            "internal_rms_step_db_p50": float(np.percentile(internal, 50)),
            "internal_rms_step_db_p95": float(np.percentile(internal, 95)),
            "internal_rms_step_db_p99": float(np.percentile(internal, 99)),
            "seam_rms_step_percentile": float((internal < seam_rms).mean() * 100),
            "spectrum_window_seconds": spectrum_window, "seam_band_distance_db": seam_spectral,
            "internal_band_distance_db_p50": float(np.percentile(spectral_internal, 50)),
            "internal_band_distance_db_p95": float(np.percentile(spectral_internal, 95)),
            "internal_band_distance_db_p99": float(np.percentile(spectral_internal, 99)),
            "seam_band_distance_percentile": float((spectral_internal < seam_spectral).mean() * 100)}


def section_loudness(path, score):
    """K-weighted integrated loudness (LUFS) of every authored section span, via FFmpeg ebur128."""
    per_bar = 240 / score["bpm"]
    result = []
    for text in score["sections"]:
        first, last = (int(x) for x in re.match(r"(\d+)-(\d+)", text).groups())
        run = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-nostats", "-i", str(path), "-af",
                              f"atrim=start={(first - 1) * per_bar}:end={last * per_bar},ebur128", "-f", "null", "-"],
                             capture_output=True, text=True, check=True)
        summary = run.stderr[run.stderr.rfind("Summary:"):]
        value = float(re.search(r"I:\s*(-?\d+(?:\.\d+)?) LUFS", summary).group(1))
        result.append({"bars": f"{first}-{last}", "integrated_lufs": value})
    return result


def stinger_shape(frames):
    mono = np.abs(frames).max(axis=1)
    threshold = 10 ** (-40 / 20)
    onset = int(np.argmax(mono > threshold)) if (mono > threshold).any() else len(mono)
    tail = frames[-round(.05 * RATE):]
    last = frames[-round(.01 * RATE):]
    windows = [frames[len(frames) - (k + 1) * round(.1 * RATE):len(frames) - k * round(.1 * RATE)]
               for k in range(6)][::-1]
    decay = [db(np.sqrt(np.mean(w ** 2))) for w in windows]
    return {"duration_seconds": len(frames) / RATE, "onset_seconds": onset / RATE,
            "final_50ms_rms_dbfs": db(np.sqrt(np.mean(tail ** 2))), "final_10ms_peak_dbfs": db(np.max(np.abs(last))),
            "last_600ms_rms_dbfs_per_100ms": decay,
            "last_600ms_monotonic_decay": bool(all(b <= a + .5 for a, b in zip(decay, decay[1:])))}


def chroma(frames, n=8192, hop=4096):
    mono = frames.mean(axis=1)
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    valid = (freqs >= 40) & (freqs <= 2100)
    classes = (np.round(12 * np.log2(freqs[valid] / 440)).astype(int) + 9) % 12
    window = np.hanning(n)
    centres, vectors = [], []
    for start in range(0, len(mono) - n, hop):
        power = np.abs(np.fft.rfft(mono[start:start + n] * window))[valid] ** 2
        vectors.append(np.bincount(classes, weights=power, minlength=12))
        centres.append((start + n / 2) / RATE)
    return np.array(centres), np.array(vectors)


def estimate_key(profile):
    best = None
    for tonic in range(12):
        for mode, template in [("major", MAJOR), ("minor", MINOR)]:
            r = float(np.corrcoef(np.roll(template, tonic), profile)[0, 1])
            if best is None or r > best[0]:
                best = (r, f"{PITCH_CLASSES[tonic]} {mode}", tonic)
    return {"key": best[1], "tonic_pitch_class": best[2], "correlation": best[0]}


def triad_template(label):
    root = pitch_class(label)
    quality = "dim" if label.endswith("dim") else "min" if label.endswith("m") else "maj"
    third = {"maj": 4, "min": 3, "dim": 3}[quality]
    fifth = {"maj": 7, "min": 7, "dim": 6}[quality]
    template = np.zeros(12)
    template[[root, (root + third) % 12, (root + fifth) % 12]] = [1.0, .8, .8]
    return template


def harmony_match(frames, score):
    """Rank each bar's authored triad among all 36 major/minor/diminished triads by audio chroma."""
    centres, vectors = chroma(frames)
    per_bar = 240 / score["bpm"]
    labels = [f"{PITCH_CLASSES[r]}{q}" for r in range(12) for q in ["", "m", "dim"]]
    templates = np.array([triad_template(label) for label in labels])
    ranks = []
    for entry in score["harmony"]:
        bar = entry["bar"] - 1
        first = entry["triads"][0]
        mask = (centres >= bar * per_bar) & (centres < (bar + (.5 if len(entry["triads"]) > 1 else 1)) * per_bar)
        if not mask.any():
            continue
        profile = vectors[mask].sum(axis=0)
        profile = profile / max(profile.sum(), 1e-12)
        scores = templates @ profile
        target = labels.index(f"{PITCH_CLASSES[pitch_class(first)]}"
                              f"{'dim' if first.endswith('dim') else 'm' if first.endswith('m') else ''}")
        ranks.append(int((scores > scores[target]).sum()) + 1)
    ranks = np.array(ranks)
    return {"bars_checked": len(ranks), "authored_triad_rank_1": int((ranks == 1).sum()),
            "authored_triad_in_top_3": int((ranks <= 3).sum()), "median_rank": float(np.median(ranks))}


def onset_tempo(frames, low=50, high=180):
    """Autocorrelation tempo of a spectral-flux onset envelope; reports the best BPM and its multiples."""
    mono = frames.mean(axis=1)
    hop, n = 320, 1024
    window = np.hanning(n)
    spectra = np.array([np.abs(np.fft.rfft(mono[i:i + n] * window)) for i in range(0, len(mono) - n, hop)])
    flux = np.maximum(np.diff(np.log1p(spectra * 100), axis=0), 0).sum(axis=1)
    flux = flux - flux.mean()
    ac = np.correlate(flux, flux, mode="full")[len(flux) - 1:]
    fps = RATE / hop
    lags = np.arange(len(ac))
    bpms = 60 * fps / np.maximum(lags, 1)
    candidates = (bpms >= low) & (bpms <= high)
    best = lags[candidates][np.argmax(ac[candidates])]
    return float(60 * fps / best)
