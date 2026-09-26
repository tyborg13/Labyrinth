"""Deterministic bowed-string synthesis; no recordings or external sample input."""
import hashlib
import numpy as np

RATE = 16000


def phrase(notes, bpm, patch):
    start = notes[0]['beat']
    hold = (notes[-1]['beat'] + notes[-1]['duration'] - start) * 60 / bpm
    release = patch['release_seconds']
    length = round((hold + release) * RATE)
    t = np.arange(length) / RATE
    freq, pressure = np.empty(length), np.empty(length)
    bow = np.ones(length)
    seed = int(hashlib.sha256(repr((notes, patch['voice'])).encode()).hexdigest()[:8], 16)
    rng = np.random.default_rng(seed)
    for i, note in enumerate(notes):
        a = round((note['beat'] - start) * 60 / bpm * RATE)
        b = round((notes[i + 1]['beat'] - start) * 60 / bpm * RATE) if i + 1 < len(notes) else length
        freq[a:b] = 440 * 2 ** ((note['pitch'] - 69) / 12)
        pressure[a:b] = (note['velocity'] / 80) ** 1.15
        if i:
            glide = min(b - a, round(.009 * RATE))
            freq[a:a + glide] = np.linspace(freq[a - 1], freq[a], glide)
            ramp = min(b - a, round(.045 * RATE))
            pressure[a:a + ramp] = np.linspace(pressure[a - 1], pressure[a], ramp)
            # Small bow-pressure dip articulates a pitch change without closing the phrase.
            span = min(b - a, round(.07 * RATE))
            bow[a:a + span] -= .09 * np.sin(np.linspace(0, np.pi, span))
    drift_points = rng.normal(0, .65, max(2, int(t[-1] * 8) + 2))
    drift = np.interp(t, np.linspace(0, t[-1], len(drift_points)), drift_points)
    vibrato = patch['vibrato_cents'] * np.minimum(t / .32, 1) * np.sin(
        2 * np.pi * patch['vibrato_hz'] * t + .14 * np.sin(2 * np.pi * .7 * t))
    freq *= 2 ** ((vibrato + drift) / 1200)
    phase = np.cumsum(freq) * 2 * np.pi / RATE
    signal = np.zeros(length)
    viola = patch['voice'] == 'viola'
    # Harmonic bow excitation through broad body/bridge resonances. Even partials
    # are retained so this is neither a square wave nor a hollow reed spectrum.
    for harmonic in range(1, 29):
        hz = freq * harmonic
        body = (.34 + 1.00 * np.exp(-.5 * ((hz - (410 if viola else 520)) / 240) ** 2)
                + .55 * np.exp(-.5 * ((hz - 1300) / 430) ** 2)
                + .72 * np.exp(-.5 * ((hz - (2250 if viola else 2750)) / 650) ** 2))
        cutoff = np.clip((6800 - hz) / 1000, 0, 1)
        color = 1 + .045 * np.sin(2 * np.pi * (1.1 + harmonic * .031) * t + harmonic)
        signal += np.sin(phase * harmonic + .12 * np.sin(harmonic)) * body * cutoff * color / harmonic ** 1.05
    signal *= .19
    noise = rng.normal(size=length)
    bins = np.fft.rfftfreq(length, 1 / RATE)
    response = (1 - np.exp(-(bins / 1300) ** 4)) / np.sqrt(1 + (bins / 4300) ** 8)
    noise = np.fft.irfft(np.fft.rfft(noise) * response, n=length)
    noise /= max(np.sqrt(np.mean(noise ** 2)), 1e-9)
    signal += noise * patch['bow_noise'] * (1 + 1.2 * np.exp(-t / .065))
    envelope = np.minimum(t / patch['attack_seconds'], 1) * np.clip((hold + release - t) / release, 0, 1) ** 1.5
    swell = .94 + .06 * np.sin(np.pi * np.minimum(t / max(hold, .001), 1))
    signal *= pressure * bow * envelope * swell
    # Low-rate, 12-bit source texture, reconstructed at the project's 32 kHz rate.
    signal = np.round(signal * 2047) / 2047
    return np.interp(np.arange(length * 2) / 2, np.arange(length), signal)
