#!/usr/bin/env python3
"""Build the hearth's dry foley palette from existing shipped project recordings.

No pitched oscillators, note sequences, external downloads or added reverb.
Filtering, envelopes and overlapping air pulses supply the healing lift.
See assets/audio/sfx/run/EMBER_HEARTH_AUDIO.md for source provenance and timing.
"""
import argparse
import hashlib
import json
import math
import struct
import wave
from pathlib import Path

RATE = 44100
ROOT = Path(__file__).resolve().parents[1]
SFX = ROOT / "assets/audio/sfx"
DURATIONS = {"arrival": 0.68, "focus": 0.12, "select": 0.26,
             "recover": 0.95, "strength": 0.95, "depart": 1.0}
SOURCES = {"paper": "card_draw_deal.wav", "touch": "card_play_take.wav",
           "clasp": "item_equip.wav", "air": "elemental/air_attack.wav",
           "fire": "run/campfire_loop.wav"}
# Five pluses start at progress * 1.30 - index * 0.12 in CombatBoardView.
# Keep the existing 0.90-second effect. Soft pulse attacks bloom after each birth.
HEAL_PULSE_STARTS = tuple(index * 0.90 * 0.12 / 1.30 for index in range(5))


def rms(values):
    return math.sqrt(sum(value * value for value in values) / max(1, len(values)))


def db(value):
    return 20 * math.log10(max(value, 1e-12))


def read_source(path):
    with wave.open(str(path), "rb") as stream:
        if stream.getsampwidth() != 2:
            raise ValueError(f"Expected PCM16 source: {path}")
        channels, rate = stream.getnchannels(), stream.getframerate()
        data = struct.unpack(f"<{stream.getnframes() * channels}h",
                             stream.readframes(stream.getnframes()))
    mono = [sum(data[i:i + channels]) / (32768 * channels)
            for i in range(0, len(data), channels)]
    return mono, rate


def excerpt(source, start, duration, speed=1.0):
    """Linear resampling; all authored rate changes are down-pitches."""
    data, source_rate = source
    result = []
    for index in range(round(duration * RATE)):
        position = (start + index / RATE * speed) * source_rate
        left = int(position)
        amount = position - left
        value = ((1 - amount) * data[left] + amount * data[left + 1]
                 if 0 <= left < len(data) - 1 else 0.0)
        result.append(value)
    return result


def lowpass(data, cutoff, passes=2):
    alpha = 1 - math.exp(-math.tau * cutoff / RATE)
    for _ in range(passes):
        state, output = 0.0, []
        for value in data:
            state += alpha * (value - state)
            output.append(state)
        data = output
    return data


def texture(source, start, duration, low=90, high=2000, speed=1.0):
    data = excerpt(source, start, duration, speed)
    low_band = lowpass(data, low, 1)
    data = lowpass([value - bass for value, bass in zip(data, low_band)], high)
    level = rms(data)
    if level < 1e-8:
        raise ValueError("Source excerpt is silent")
    return [value / level for value in data]


def envelope(data, attack=0.015, release=0.05):
    # Raised-cosine edges have no discontinuity and reach literal zero at both ends.
    last = len(data) - 1
    for index, value in enumerate(data):
        fade_in = min(1.0, index / max(1, attack * RATE))
        fade_out = min(1.0, (last - index) / max(1, release * RATE))
        yield value * (0.5 - 0.5 * math.cos(math.pi * fade_in)) * (0.5 - 0.5 * math.cos(math.pi * fade_out))


def add(destination, layer, start=0.0, gain=1.0):
    offset = round(start * RATE)
    for index, value in enumerate(layer):
        if offset + index >= len(destination):
            break
        destination[offset + index] += value * gain


def make_palette(sources):
    cues = {name: [0.0] * round(duration * RATE) for name, duration in DURATIONS.items()}
    # Dry, short finger/cloth sounds: no melodic hover or confirmation tone.
    add(cues["focus"], envelope(texture(sources["paper"], 0.015, 0.12,
        low=220, high=1800, speed=0.80), 0.008, 0.060), gain=0.75)
    add(cues["select"], envelope(texture(sources["touch"], 0, 0.26,
        low=110, high=1600, speed=0.82), 0.004, 0.10), gain=1.0)
    add(cues["select"], envelope(texture(sources["paper"], 0.05, 0.20,
        low=180, high=1300, speed=0.76), 0.010, 0.14), 0.018, 0.16)
    # A subdued breath of the actual hearth; the world crackle keeps its own mix.
    add(cues["arrival"], envelope(texture(sources["fire"], 19.3, 0.68,
        low=100, high=1500, speed=0.85), 0.045, 0.37), gain=0.50)
    add(cues["arrival"], envelope(texture(sources["paper"], 0.0, 0.25,
        low=160, high=1600, speed=0.80), 0.015, 0.17), gain=0.23)
    # Recovery is one connected exhalation with a soft ripple following the pluses.
    # Raise bandwidth, not musical pitch. Broad noise has no stable beeping note.
    add(cues["recover"], envelope(texture(sources["air"], 0.58, 0.90,
        low=130, high=1050, speed=0.82), 0.12, 0.52), gain=0.10)
    for index, start in enumerate(HEAL_PULSE_STARTS):
        pulse = texture(sources["air"], 0.47 + index * 0.11, 0.245,
                        low=180, high=1050 + index * 210, speed=0.78)
        add(cues["recover"], envelope(pulse, 0.026, 0.19), start,
            (0.70, 0.78, 0.83, 0.77, 0.62)[index])
    # Strength: a weighted clasp with a restrained body of air/fire, no fanfare.
    add(cues["strength"], envelope(texture(sources["clasp"], 0.075, 0.56,
        low=85, high=1500, speed=0.72), 0.014, 0.25), gain=0.48)
    add(cues["strength"], envelope(texture(sources["air"], 0.38, 0.88,
        low=90, high=1150, speed=0.78), 0.08, 0.52), gain=0.21)
    # Embrace closes with settling cloth and a dying ember wash.
    add(cues["depart"], envelope(texture(sources["paper"], 0, 0.35,
        low=140, high=1100, speed=0.60), 0.02, 0.24), gain=0.30)
    add(cues["depart"], envelope(texture(sources["fire"], 27.8, 0.94,
        low=100, high=1250, speed=0.70), 0.07, 0.67), 0.02, 0.48)
    # Master RMS for textures (not equal peaks, which over-promotes one-off clicks).
    target_rms_db = {"focus": -20, "select": -17, "arrival": -19,
                     "recover": -17, "strength": -18, "depart": -20}
    for name, data in cues.items():
        # Round isolated recorded transients before mastering; a lone ember pop
        # should not force the entire bed down or turn into a brittle UI click.
        knee = 1.15 if name in ("arrival", "strength") else 2.5
        data = lowpass([knee * math.tanh(value / knee) for value in data], 3600)
        data = list(envelope(data, 0.002, 0.035))
        gain = min(10 ** (target_rms_db[name] / 20) / max(rms(data), 1e-8),
                   0.60 / max(max(abs(v) for v in data), 1e-8))
        cues[name] = [round(value * gain * 32767) for value in data]
    return cues


def write_wav(path, samples):
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(struct.pack(f"<{len(samples)}h", *samples))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=SFX / "run")
    parser.add_argument("--report", type=Path, help="Write source hashes and signal checks")
    args = parser.parse_args()
    sources = {name: read_source(SFX / path) for name, path in SOURCES.items()}
    report = {"sample_rate": RATE, "method": "filtered shipped foley, no oscillators",
              "heal_pulse_starts_seconds": HEAL_PULSE_STARTS,
              "sources": {path: hashlib.sha256((SFX / path).read_bytes()).hexdigest()
                          for path in SOURCES.values()}, "cues": {}}
    for name, samples in make_palette(sources).items():
        path = args.output_dir / f"ember_hearth_{name}.wav"
        write_wav(path, samples)
        normalized = [v / 32768 for v in samples]
        facts = {"duration": len(samples) / RATE, "rms_dbfs": round(db(rms(normalized)), 3),
                 "peak_dbfs": round(db(max(abs(v) for v in normalized)), 3),
                 "first_sample": samples[0], "last_sample": samples[-1],
                 "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
        report["cues"][name] = facts
        print(f"{path.name}: {facts['duration']:.2f}s, RMS {facts['rms_dbfs']:.1f}, peak {facts['peak_dbfs']:.1f} dBFS")
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
