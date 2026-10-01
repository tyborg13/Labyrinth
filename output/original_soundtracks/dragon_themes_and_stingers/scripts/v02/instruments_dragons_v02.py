"""Procedural instruments added in v02: formant choir, brass section, taiko, timpani and a tolling bell.

Pure mathematical synthesis (additive wavetables, modal resonators) with deterministically
seeded noise and vibrato. No recordings, samples, SoundFonts or generated audio are used.
Every function returns a stereo float array starting at the note onset.
"""
from __future__ import annotations

import hashlib
import math

import numpy as np

RATE = 32000
TABLE = 4096
VOWELS = {  # formant centres (Hz), bandwidths (Hz), relative gains
    "ah": ([730, 1090, 2440, 3400], [110, 120, 170, 220], [1.0, .55, .26, .12]),
    "oh": ([570, 840, 2410, 3300], [100, 110, 170, 220], [1.0, .42, .16, .07]),
    "oo": ([320, 800, 2240, 3200], [80, 100, 160, 200], [1.0, .28, .08, .04]),
    "ah_high": ([850, 1220, 2810, 3800], [120, 130, 190, 240], [1.0, .62, .30, .14]),
}


def seed(*parts):
    return int(hashlib.sha256(repr(parts).encode()).hexdigest()[:8], 16)


def hz(pitch):
    return 440 * 2 ** ((pitch - 69) / 12)


def pan_gains(pan):
    return math.cos((pan + 1) * np.pi / 4), math.sin((pan + 1) * np.pi / 4)


def smooth_noise(rng, length, points_per_second, scale):
    count = max(2, int(length / RATE * points_per_second) + 2)
    return np.interp(np.arange(length), np.linspace(0, length, count), rng.normal(0, scale, count))


def band_noise(rng, length, low, high):
    """Seeded noise band-limited with smooth spectral edges."""
    freqs = np.fft.rfftfreq(length, 1 / RATE)
    mask = 1 / (1 + (low / np.maximum(freqs, 1)) ** 4) / (1 + (freqs / high) ** 4)
    noise = np.fft.irfft(np.fft.rfft(rng.normal(size=length)) * mask, n=length)
    return noise / max(np.sqrt(np.mean(noise ** 2)), 1e-9)


def onset(t, seconds=.0015):
    """A raised-cosine strike ramp: a fast physical attack instead of a one-sample step."""
    return np.sin(np.minimum(t / seconds, 1) * np.pi / 2) ** 2


def gate(t, hold, attack, release):
    rise = np.sin(np.minimum(t / max(attack, 1e-4), 1) * np.pi / 2) ** 2
    fall = np.cos(np.clip((t - hold) / release, 0, 1) * np.pi / 2) ** 2
    return rise * fall


def wavetable(amplitudes, phases):
    theta = np.arange(TABLE) / TABLE * 2 * np.pi
    harmonics = np.arange(1, len(amplitudes) + 1)
    table = (amplitudes[:, None] * np.sin(harmonics[:, None] * theta[None, :] + phases[:, None])).sum(axis=0)
    return table / max(np.max(np.abs(table)), 1e-9)


def read_table(table, cycles):
    position = (cycles % 1.0) * TABLE
    i0 = np.floor(position).astype(int)
    frac = position - i0
    return table[i0] * (1 - frac) + table[(i0 + 1) % TABLE] * frac


def formant_gain(freqs, vowel, scale=1.0):
    centres, widths, gains = VOWELS[vowel]
    total = np.full_like(freqs, .015, dtype=float)
    for f, b, g in zip(centres, widths, gains):
        total += g / np.sqrt(1 + ((freqs - f * scale) / (b / 2)) ** 2)
    return total


def choir(note, bpm, patch):
    """A section of 'voices' singers: formant-shaped glottal harmonics, seeded vibrato, drift and breath."""
    hold = note["duration"] * 60 / bpm
    release, attack = patch.get("release_seconds", .6), patch.get("attack_seconds", .3)
    vowel = note.get("vowel", patch.get("vowel", "ah"))
    rng = np.random.default_rng(seed("choir", note["pitch"], note["beat"], note["velocity"], vowel, patch["voices"]))
    length = round((hold + release + .05) * RATE)
    t = np.arange(length) / RATE
    f0 = hz(note["pitch"])
    loud = note["velocity"] / 127
    harmonics = np.arange(1, max(2, int(min(5200, 15000) / f0)) + 1)
    out = np.zeros((length, 2))
    spread = patch.get("spread", .5)
    for voice in range(patch["voices"]):
        scale = rng.normal(1, .03)
        tilt = 1.45 - .55 * loud
        amps = harmonics ** -tilt * formant_gain(harmonics * f0, vowel, scale)
        table = wavetable(amps, rng.uniform(0, 2 * np.pi, len(harmonics)))
        cents = (rng.normal(0, patch.get("detune_cents", 7))
                 + patch.get("vibrato_cents", 18) * rng.uniform(.7, 1.2) * np.minimum(t / .45, 1)
                 * np.sin(2 * np.pi * rng.uniform(4.6, 5.8) * t + rng.uniform(0, 2 * np.pi))
                 + smooth_noise(rng, length, 4, 3.5))
        wave = read_table(table, np.cumsum(f0 * 2 ** (cents / 1200)) / RATE)
        shimmer = 1 + .07 * np.sin(2 * np.pi * rng.uniform(.4, 1.6) * t + rng.uniform(0, 6.3))
        delay = round(rng.uniform(0, .04) * RATE)
        env = gate(np.maximum(t - delay / RATE, 0), hold, attack * rng.uniform(.8, 1.25), release)
        left, right = pan_gains(patch.get("pan", 0) + spread * (voice / max(patch["voices"] - 1, 1) - .5))
        signal = wave * env * shimmer
        out[:, 0] += signal * left
        out[:, 1] += signal * right
    breath = rng.normal(size=length)
    freqs = np.fft.rfftfreq(length, 1 / RATE)
    breath = np.fft.irfft(np.fft.rfft(breath) * formant_gain(freqs, vowel) * (freqs > 300), n=length)
    breath *= patch.get("breath", .025) / max(np.sqrt(np.mean(breath ** 2)), 1e-9) * gate(t, hold, attack * .6, release)
    out += breath[:, None] * .7
    return out / patch["voices"] * loud ** 1.25


def brass(note, bpm, patch):
    """Low brass section: dynamic brightness (soft->blazing wavetables), onset scoop, gentle saturation."""
    hold = note["duration"] * 60 / bpm
    release, attack = patch.get("release_seconds", .3), patch.get("attack_seconds", .07)
    rng = np.random.default_rng(seed("brass", note["pitch"], note["beat"], note["velocity"], note.get("shape")))
    length = round((hold + release + .03) * RATE)
    t = np.arange(length) / RATE
    f0 = hz(note["pitch"])
    harmonics = np.arange(1, max(2, int(9000 / f0)) + 1)
    bell = 1 + 1.1 * np.exp(-((harmonics * f0 - 1150) / 650) ** 2)
    phases = rng.uniform(0, .4, len(harmonics))
    tables = [wavetable(harmonics ** -1.0 * np.exp(-harmonics * f0 / cutoff) * bell, phases)
              for cutoff in (380, 950, 2600)]
    shape = note.get("shape", "sustain")
    x = np.clip(t / max(hold, 1e-3), 0, 1)
    if shape == "swell":
        level = .22 + .78 * x ** 1.6
    elif shape == "sfz":
        level = np.where(t < .35, 1 - .6 * np.sin(np.minimum(t / .35, 1) * np.pi / 2), .4 + .5 * x ** 1.3)
    elif shape == "fade":
        level = 1 - .7 * x
    else:
        level = np.full(length, .8)
    level = np.clip(level, 0, 1)
    out = np.zeros((length, 2))
    for voice in range(patch.get("voices", 3)):
        scoop = -28 * np.exp(-t / .05)
        cents = rng.normal(0, 5) + scoop + 4 * np.minimum(t / .8, 1) * np.sin(2 * np.pi * 5.1 * t + voice)
        cycles = np.cumsum(f0 * 2 ** (cents / 1200)) / RATE
        position = level * 2
        lo = np.minimum(position.astype(int), 1)
        frac = position - lo
        waves = [read_table(table, cycles) for table in tables]
        wave = np.where(lo == 0, waves[0] * (1 - frac) + waves[1] * frac, waves[1] * (1 - frac) + waves[2] * frac)
        drive = 1 + 1.6 * level
        wave = np.tanh(wave * drive) / np.tanh(drive)
        left, right = pan_gains(patch.get("pan", 0) + .35 * (voice - 1))
        out[:, 0] += wave * left
        out[:, 1] += wave * right
    env = gate(t, hold, attack, release) * level ** 1.5
    blat = rng.normal(size=length) * np.exp(-t / .02) * .05 * onset(t, .004)
    out = out * env[:, None] + blat[:, None]
    return out / patch.get("voices", 3) * (note["velocity"] / 110) ** 1.3


def taiko(note, bpm, patch):
    """Large drums: 35 = o-daiko, 43 = mid taiko, 47 = high taiko. Modal membrane, pitch drop, stick and skin noise."""
    rng = np.random.default_rng(seed("taiko", note["pitch"], note["beat"], note["velocity"]))
    f0, tau = {35: (62, .75), 43: (105, .45), 47: (172, .26)}[note["pitch"]]
    tau *= patch.get("decay_scale", 1.0)
    length = round((tau * 5) * RATE)
    t = np.arange(length) / RATE
    loud = note["velocity"] / 127
    body = np.zeros(length)
    for ratio, amp, decay in [(1, 1, 1), (1.59, .7, .6), (2.14, .5, .45), (2.65, .3, .32), (3.16, .2, .24)]:
        glide = f0 * ratio * (1 + .45 * np.exp(-t / .04))
        body += amp * np.sin(2 * np.pi * np.cumsum(glide) / RATE) * np.exp(-t / (tau * decay))
    thud = band_noise(rng, length, f0 * 1.2, f0 * 3.5) * np.exp(-t / .035) * .55
    crack = band_noise(rng, length, 700, 2600) * np.exp(-t / .007) * (.12 + .3 * loud)
    signal = (body * .55 + thud + crack) * loud ** 1.4 * onset(t)
    left, right = pan_gains(patch.get("pan", 0))
    return np.stack([signal * left, signal * right], axis=1)


def timpani(note, bpm, patch):
    """Pitched kettle drum with near-harmonic modes; articulation 'roll' plays seeded single strokes."""
    rng = np.random.default_rng(seed("timpani", note["pitch"], note["beat"], note["velocity"], note.get("articulation")))
    f0 = hz(note["pitch"])
    hold = note["duration"] * 60 / bpm
    ring = patch.get("ring_seconds", 3.2)
    length = round((hold + ring) * RATE)
    t = np.arange(length) / RATE
    strokes = [(0.0, 1.0)]
    if note.get("articulation") == "roll":
        start = note.get("roll_from", .25)
        strokes, at = [], 0.0
        while at < hold:
            strokes.append((at, start + (1 - start) * (at / max(hold, 1e-3)) ** 1.3))
            at += .052 + rng.uniform(-.006, .006)
    signal = np.zeros(length)
    stroke_scale = 1.0 if len(strokes) == 1 else .16
    for at, gain in strokes:
        a = round(at * RATE)
        u = t[:length - a]
        hit = np.zeros(len(u))
        for ratio, amp, decay in [(1, 1, 2.4), (1.5, .45, 1.3), (1.98, .3, .9), (2.44, .18, .6), (2.94, .1, .4)]:
            hit += amp * np.sin(2 * np.pi * f0 * ratio * u * (1 + .01 * np.exp(-u / .04))) * np.exp(-u / decay)
        mallet = np.convolve(rng.normal(size=len(u)), np.ones(12) / 12, mode="same") * np.exp(-u / .007) * .35
        signal[a:] += (hit + mallet) * gain * stroke_scale * onset(u)
    signal *= (note["velocity"] / 127) ** 1.4 * np.cos(np.clip((t - hold - ring + .6) / .6, 0, 1) * np.pi / 2) ** 2
    left, right = pan_gains(patch.get("pan", 0))
    return np.stack([signal * left, signal * right], axis=1)


def toll(note, bpm, patch):
    """A deep tolling bell: hum, prime, minor-third tierce, quint, nominal and upper partials with beating pairs."""
    rng = np.random.default_rng(seed("toll", note["pitch"], note["beat"], note["velocity"]))
    nominal = hz(note["pitch"])
    ring = patch.get("ring_seconds", 6.0)
    length = round(ring * RATE)
    t = np.arange(length) / RATE
    signal = np.zeros(length)
    for ratio, amp, decay in [(.5, 1.0, 1.0), (1.0, .7, .7), (1.19, .6, .5), (1.5, .3, .35), (2.0, .6, .45),
                              (2.52, .25, .25), (3.0, .2, .2), (4.2, .12, .12), (5.4, .08, .08), (6.8, .05, .06)]:
        for weight, split in ((1.0, 0.0), (.3, .22)):
            signal += weight * amp * np.sin(2 * np.pi * (nominal * ratio + split) * t + rng.uniform(0, 6.3)) \
                * np.exp(-t / (ring * decay * .45))
    strike = np.convolve(rng.normal(size=length), np.ones(12) / 12, mode="same") * np.exp(-t / .004) * .35
    signal = (signal / 4 + strike) * (note["velocity"] / 127) ** 1.3 * onset(t)
    signal *= np.cos(np.clip((t - ring + .4) / .4, 0, 1) * np.pi / 2) ** 2
    left, right = pan_gains(patch.get("pan", 0))
    return np.stack([signal * left, signal * right], axis=1)


SYNTHS = {"choir": choir, "brass": brass, "taiko": taiko, "timpani": timpani, "toll": toll}
