#!/usr/bin/env python3
"""Reproducible, sample-free Ember Hearth cues: soft struck metal and warm air.

All oscillators/noise are synthesized here; there are no external recordings.
UI playback gain is authored separately in run_sfx_library.gd.
"""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
CUES = {
    "arrival": (0.68, [(0.00, 220.0, 0.8), (0.10, 330.0, 0.55), (0.20, 440.0, 0.4)]),
    "focus": (0.12, [(0.00, 660.0, 0.45)]),
    "select": (0.26, [(0.00, 330.0, 0.75), (0.025, 660.0, 0.35)]),
    "recover": (0.95, [(0.00, 330.0, 0.65), (0.11, 440.0, 0.5), (0.22, 660.0, 0.4)]),
    "strength": (0.95, [(0.00, 220.0, 0.7), (0.09, 440.0, 0.55), (0.18, 880.0, 0.35)]),
    "depart": (1.0, [(0.00, 440.0, 0.6), (0.10, 330.0, 0.55), (0.20, 220.0, 0.65)]),
}


def synthesize(name, duration, notes):
    rng = random.Random(1809)
    samples = []
    air = 0.0
    for index in range(round(duration * RATE)):
        t = index / RATE
        value = 0.0
        for start, hz, level in notes:
            u = t - start
            if u < 0:
                continue
            decay = 0.045 if name == "focus" else 0.19
            envelope = (1 - math.exp(-u / 0.006)) * math.exp(-u / decay)
            partials = (math.sin(math.tau * hz * u)
                        + 0.24 * math.sin(math.tau * hz * 2.01 * u) * math.exp(-u / 0.09)
                        + 0.08 * math.sin(math.tau * hz * 3.97 * u) * math.exp(-u / 0.04))
            value += level * envelope * partials
        air = air * 0.93 + rng.uniform(-1, 1) * 0.07
        value += air * 0.22 * math.sin(math.pi * min(1, t / duration)) ** 2
        # Quiet tails reach exactly zero; no playback timer cuts a waveform.
        fade = min(1.0, max(0.0, (duration - t) / 0.04))
        samples.append(value * fade)
    peak = max(abs(v) for v in samples)
    return [round(v / max(peak, 0.001) * 0.68 * 32767) for v in samples]


def main():
    output = Path(__file__).resolve().parents[1] / "assets/audio/sfx/run"
    for name, (duration, notes) in CUES.items():
        samples = synthesize(name, duration, notes)
        path = output / f"ember_hearth_{name}.wav"
        with wave.open(str(path), "wb") as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(struct.pack(f"<{len(samples)}h", *samples))
        print(f"{path.name}: {duration:.2f}s, peak -3.35 dBFS")


if __name__ == "__main__":
    main()
