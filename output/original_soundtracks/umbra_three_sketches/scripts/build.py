#!/usr/bin/env python3
"""Three authored auditions. No downloaded scores, samples, or model-audio input.

Run from a Labyrinth worktree with Python 3.12, NumPy and mido installed.
This deliberately does not change the classical-source gate or game assets.
"""
from __future__ import annotations

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

import mido
import numpy as np

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "project.godot").exists())
sys.path.insert(0, str(ROOT / "tools"))
from classical_soundtrack_pipeline.common import (  # noqa: E402
    load_mono_wave, normalize_ogg_serial, sha256, write_json, write_stereo_wave,
)
from classical_soundtrack_pipeline.render import RenderNote, _sampled_note  # noqa: E402

CASE = Path(__file__).resolve().parents[1]
RATE = 32000
BANK = ROOT / "assets/audio/instruments/classical_dark_fantasy_v1"
PATCHES = {
    "lantern_mallet": {"gain": 0.24, "pan": -0.17, "wet": 0.26, "program": 11},
    "reed": {"gain": 0.20, "pan": 0.14, "wet": 0.20, "program": 74},
    "thread_pluck": {"gain": 0.12, "pan": 0.30, "wet": 0.22, "program": 10},
    "bowed_veil": {"gain": 0.085, "pan": -0.20, "wet": 0.28, "program": 48},
    "hollow_bass": {"gain": 0.27, "pan": 0.0, "wet": 0.025, "program": 38},
    "drums": {"gain": 0.25, "pan": 0.0, "wet": 0.055, "program": 0},
}


def pitch(name: str | int) -> int:
    if isinstance(name, int):
        return name
    key = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[name[0]]
    accidental = 1 if "#" in name else -1 if "b" in name else 0
    return 12 * (int(name[-1]) + 1) + key + accidental


def piece(slug, title, bpm, bars, mood, key):
    return {"schema_version": 1, "slug": slug, "title": title, "bpm": bpm,
            "bars": bars, "beats_per_bar": 4, "key": key, "mood": mood,
            "source_kind": "original_authored_symbolic_composition",
            "patches": PATCHES, "notes": [], "harmony": [], "sections": []}


def add(s, instrument, bar, offset, duration, note, velocity=72):
    s["notes"].append({"instrument": instrument, "beat": bar * 4 + offset,
                       "duration": duration, "pitch": pitch(note), "velocity": velocity})


def melody(s, instrument, phrases, velocity=76):
    # Every phrase below is authored; tuples are (beat within bar, length, pitch).
    for bar, notes in enumerate(phrases):
        for i, (offset, duration, note) in enumerate(notes):
            add(s, instrument, bar, offset, duration, note, velocity - (i % 3) * 4)


def bed(s, chords, bass_style="slow"):
    # Each harmonic entry is (label, bass root, inner pair, upper arpeggio notes).
    for bar, (label, root, inner, arp) in enumerate(chords):
        s["harmony"].append({"bar": bar + 1, "chord": label})
        if bar == 0 or chords[bar - 1][:3] != chords[bar][:3]:
            span = 1
            while bar + span < len(chords) and chords[bar + span][:3] == chords[bar][:3]:
                span += 1
            for p in inner:
                add(s, "bowed_veil", bar, 0, span * 4 - 0.12, p, 64)
        if bass_style == "slow":
            add(s, "hollow_bass", bar, 0, 3.6, root, 64)
        elif bass_style == "measured":
            for t, d, interval, v in [(0, 1.25, 0, 76), (1.5, .65, 12, 52), (3, .7, 7, 61)]:
                add(s, "hollow_bass", bar, t, d, pitch(root) + interval, v)
        else:
            pattern = [(0, .72, 0, 85), (1, .36, 0, 67), (1.5, .35, 12, 58),
                       (2.5, .68, 7, 72), (3.5, .35, 0, 63)]
            if 8 <= bar < 12:
                pattern = [(0, 1.65, 0, 75), (2.5, .9, 7, 65)]
            for t, d, interval, v in pattern:
                add(s, "hollow_bass", bar, t, d, pitch(root) + interval, v)


def lanterns():
    s = piece("01_lanterns_below", "Lanterns Below", 72, 16,
              "Quiet exploration; soft mallet questions answered by a low reed.", "D minor")
    D = ("Dm(add9)", "D2", ["F3", "A3"], ["D4", "A4", "E5", "F4"])
    B = ("Bbmaj7", "Bb1", ["F3", "A3"], ["D4", "F4", "A4", "Bb4"])
    F = ("Fmaj7", "F2", ["E3", "A3"], ["C4", "E4", "A4", "F4"])
    C = ("C(add9)", "C2", ["E3", "G3"], ["D4", "G4", "E4", "C4"])
    G = ("Gm9", "G2", ["F3", "Bb3"], ["D4", "A4", "F4", "G4"])
    DF = ("Dm/F", "F2", ["D3", "A3"], ["F4", "A4", "E5", "D4"])
    AS = ("A7sus4", "A1", ["D3", "G3"], ["E4", "A4", "D5", "G4"])
    A = ("A7", "A1", ["C#3", "G3"], ["E4", "A4", "C#5", "G4"])
    chords = [D, D, B, B, F, F, C, C, G, G, DF, DF, B, B, AS, A]
    bed(s, chords)
    phrases = [
        [(0.5, .8, "D5"), (1.75, .55, "A4"), (2.5, 1.1, "F5")],
        [(0, 1.2, "E5"), (1.75, 1.1, "D5")],
        [(0.5, .65, "A4"), (1.5, .65, "D5"), (2.5, 1.0, "F5")],
        [(0, 1.6, "E5"), (2, 1.4, "D5")],
        [(0, .7, "C5"), (1, .6, "A4"), (2, 1.3, "G4")],
        [(0.5, 1.2, "A4"), (2.25, 1.0, "C5")],
        [(0, 1.1, "G4"), (1.5, .6, "E4"), (2.5, 1.0, "D4")],
        [(0.5, 2.0, "E4")],
        [(0.5, .8, "D5"), (1.75, .55, "A4"), (2.5, 1.1, "Bb4")],
        [(0, 1.2, "A4"), (1.75, 1.1, "G4")],
        [(0.5, .65, "A4"), (1.5, .65, "C5"), (2.5, 1.0, "F5")],
        [(0, 1.4, "E5"), (2.0, 1.25, "D5")],
        [(0.5, .65, "F5"), (1.5, .65, "E5"), (2.5, 1.0, "D5")],
        [(0.0, 1.6, "A4"), (2.0, .9, "F4")],
        [(0.5, 1.0, "G4"), (2.0, 1.0, "E4")],
        [(0.0, 1.5, "C#5"), (2.0, .7, "E5")],
    ]
    melody(s, "lantern_mallet", phrases, 78)
    for bar, chord in enumerate(chords):
        for i, t in enumerate([0, 1.5, 3]):
            add(s, "thread_pluck", bar, t, .34, chord[3][(bar + i) % 4], 44 + i * 3)
    for bar, notes in {3: [(2.5, 1.25, "A3")], 6: [(1, 1.5, "G3"), (3, .8, "E4")],
                       7: [(0, 2.5, "D4")], 11: [(2, 1.6, "A3")],
                       13: [(1, 2, "D4")], 15: [(2.5, 1.0, "A3")]}.items():
        for t, d, p in notes:
            add(s, "reed", bar, t, d, p, 50)
    s["sections"] = ["1-4: lantern motif", "5-8: lower-register reply",
                     "9-12: minor-subdominant variation", "13-16: return and suspended turnaround"]
    return s


def turning_key():
    s = piece("02_the_turning_key", "The Turning Key", 80, 16,
              "Tense planning; a lopsided plucked figure and restrained reed melody.", "E minor")
    E = ("Em(add9)", "E2", ["G3", "B3"], ["E4", "B4", "F#4", "G4"])
    C = ("Cmaj7(#11)", "C2", ["E3", "B3"], ["E4", "B4", "F#4", "G4"])
    A = ("Am9", "A1", ["G3", "C4"], ["E4", "B4", "C5", "A4"])
    BS = ("B7sus4", "B1", ["A3", "E4"], ["F#4", "B4", "E5", "A4"])
    B = ("B7", "B1", ["A3", "D#4"], ["F#4", "B4", "D#5", "A4"])
    G = ("Gmaj7", "G2", ["F#3", "B3"], ["D4", "B4", "F#4", "G4"])
    chords = [E, E, C, C, A, A, BS, B, E, E, G, G, C, A, BS, B]
    bed(s, chords, "measured")
    phrases = [
        [(0.5, .8, "E4"), (1.75, .55, "G4"), (2.5, .85, "F#4")],
        [(0.0, 1.2, "B4"), (1.75, .55, "A4"), (2.5, .8, "G4")],
        [(0.5, 1.0, "E4"), (2, .65, "F#4"), (3, .65, "G4")],
        [(0, 1.25, "B4"), (2, 1.2, "G4")],
        [(0.5, .7, "A4"), (1.5, .7, "G4"), (2.5, 1.0, "E4")],
        [(0.5, .75, "D4"), (1.5, 1.3, "E4")],
        [(0, 1.2, "F#4"), (1.75, .6, "E4"), (2.5, 1.0, "A4")],
        [(0.5, 1.1, "F#4"), (2, 1.0, "D#4")],
        [(0.5, .8, "E4"), (1.75, .55, "G4"), (2.5, .85, "B4")],
        [(0, 1.2, "D5"), (1.75, .55, "B4"), (2.5, .85, "A4")],
        [(0.5, .9, "B4"), (2, .65, "A4"), (3, .65, "G4")],
        [(0, 1.25, "F#4"), (2, 1.25, "D4")],
        [(0.5, 1.0, "E4"), (2, .65, "G4"), (3, .65, "B4")],
        [(0, 1.2, "A4"), (1.75, .55, "G4"), (2.5, .8, "E4")],
        [(0.5, 1.2, "F#4"), (2.25, 1.0, "E4")],
        [(0.0, 1.5, "D#4"), (2.0, .75, "F#4")],
    ]
    melody(s, "reed", phrases, 76)
    for bar, chord in enumerate(chords):
        times = [0, .5, 1.5, 2, 3] if bar % 4 != 3 else [0, 1.5, 3]
        for i, t in enumerate(times):
            add(s, "thread_pluck", bar, t, .28, chord[3][[0, 1, 2, 1, 3][i]], 63 if i == 0 else 50)
        if bar % 2 == 0:
            add(s, "drums", bar, 0, .2, 36, 44)
        for t in [1.5, 3.5]:
            add(s, "drums", bar, t, .1, 42, 39)
        if bar in [3, 7, 11, 15]:
            add(s, "drums", bar, 3.0, .2, 41, 46)
    s["sections"] = ["1-4: question over E pedal colors", "5-8: A minor and B dominant",
                     "9-12: higher response", "13-16: compressed harmonic return"]
    return s


def pursuit():
    s = piece("03_ashen_pursuit", "Ashen Pursuit", 108, 24,
              "Restrained combat; syncopated low pulse, short reed calls, and a quieter middle.", "D minor")
    D = ("Dm", "D2", ["F3", "A3"], ["D4", "A4", "F4", "E4"])
    B = ("Bbmaj7", "Bb1", ["F3", "A3"], ["D4", "A4", "F4", "Bb4"])
    G = ("Gm", "G1", ["G3", "Bb3"], ["D4", "Bb4", "G4", "A4"])
    A = ("A7", "A1", ["G3", "C#4"], ["E4", "A4", "C#5", "G4"])
    F = ("Fmaj7", "F2", ["E3", "A3"], ["C4", "A4", "F4", "E4"])
    C = ("C(add9)", "C2", ["E3", "G3"], ["D4", "G4", "E4", "C5"])
    chords = [D, D, B, B, G, G, A, A, F, F, C, C, G, B, A, A, D, D, B, B, G, B, A, A]
    bed(s, chords, "driving")
    phrases = [
        [(0, .65, "D4"), (1, .32, "A4"), (1.5, .65, "F4"), (2.5, .35, "E4"), (3.25, .45, "D4")],
        [(0, .7, "F4"), (1.5, .4, "A4"), (2.25, 1.1, "G4")],
        [(0, .65, "F4"), (1, .32, "D5"), (1.5, .65, "A4"), (2.5, .35, "G4"), (3.25, .45, "F4")],
        [(0, 1.15, "D4"), (2, .6, "F4"), (3, .6, "A4")],
        [(0, .65, "G4"), (1, .32, "D5"), (1.5, .65, "Bb4"), (2.5, .35, "A4"), (3.25, .45, "G4")],
        [(0, .7, "F4"), (1.5, .45, "D4"), (2.5, .8, "G4")],
        [(0, .65, "E4"), (1, .32, "A4"), (1.5, .65, "G4"), (2.5, .35, "E4"), (3.25, .45, "C#4")],
        [(0, 1.15, "E4"), (2, .65, "G4"), (3, .65, "A4")],
        [(0.5, 1.4, "C5"), (2.5, 1.0, "A4")],
        [(0.5, 1.4, "G4"), (2.5, 1.0, "F4")],
        [(0.5, 1.4, "G4"), (2.5, 1.0, "E4")],
        [(0.5, 2.5, "D4")],
        [(0, .7, "G4"), (1.5, .55, "A4"), (2.5, 1.0, "Bb4")],
        [(0, .7, "A4"), (1.5, .55, "F4"), (2.5, 1.0, "D4")],
        [(0, .65, "E4"), (1, .32, "G4"), (1.5, .65, "A4"), (2.5, .35, "C#5"), (3.25, .4, "B4")],
        [(0, 1.2, "A4"), (2.0, .6, "G4"), (3.0, .6, "E4")],
        [(0, .65, "D4"), (1, .32, "A4"), (1.5, .65, "F4"), (2.5, .35, "E4"), (3.25, .45, "D4")],
        [(0, .7, "F4"), (1.5, .4, "A4"), (2.25, 1.1, "D5")],
        [(0, .65, "F4"), (1, .32, "D5"), (1.5, .65, "A4"), (2.5, .35, "G4"), (3.25, .45, "F4")],
        [(0, 1.15, "D4"), (2, .6, "F4"), (3, .6, "A4")],
        [(0, .7, "G4"), (1.5, .55, "Bb4"), (2.5, 1.0, "A4")],
        [(0, .7, "F4"), (1.5, .55, "E4"), (2.5, 1.0, "D4")],
        [(0, .65, "E4"), (1, .32, "A4"), (1.5, .65, "G4"), (2.5, .35, "E4"), (3.25, .45, "C#4")],
        [(0, 1.0, "E4"), (1.5, .65, "C#4"), (2.5, .7, "A3")],
    ]
    melody(s, "reed", phrases, 83)
    for bar, chord in enumerate(chords):
        quiet = 8 <= bar < 12
        times = [0, 2] if quiet else [.5, 1.75, 2.5, 3.5]
        for i, t in enumerate(times):
            add(s, "thread_pluck", bar, t, .25, chord[3][i % 4], 45 if quiet else 57)
        if bar in [1, 3, 5, 9, 11, 13, 17, 19, 21]:
            add(s, "lantern_mallet", bar, 3.25, .4, chord[3][0], 53)
        kicks = [0] if quiet else [0, 2.5]
        for t in kicks:
            add(s, "drums", bar, t, .3, 36, 58 if quiet else 79)
        if not quiet:
            for t in [1, 3]:
                add(s, "drums", bar, t, .2, 38, 55 if t == 1 else 61)
        for i, t in enumerate([.5, 1.5, 2.5, 3.5]):
            add(s, "drums", bar, t, .1, 42, 27 if quiet else (37 if i % 2 else 45))
        if bar in [7, 15, 23]:
            for i, t in enumerate([3, 3.5, 3.75]):
                add(s, "drums", bar, t, .2, 41, 48 + i * 5)
    s["sections"] = ["1-8: bass-led pursuit", "9-12: thinner suspended breath",
                     "13-16: rebuild", "17-24: varied return and dominant turnaround"]
    return s


def midi(s, path):
    file = mido.MidiFile(type=1, ticks_per_beat=480)
    end = s["bars"] * 4 * 480
    meta = mido.MidiTrack()
    file.tracks.append(meta)
    meta.extend([mido.MetaMessage("track_name", name=s["title"]),
                 mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(s["bpm"])),
                 mido.MetaMessage("time_signature", numerator=4, denominator=4),
                 mido.MetaMessage("end_of_track", time=end)])
    for index, instrument in enumerate(sorted({n["instrument"] for n in s["notes"]})):
        channel = 9 if instrument == "drums" else index
        track = mido.MidiTrack()
        file.tracks.append(track)
        track.extend([mido.MetaMessage("track_name", name=instrument),
                      mido.Message("program_change", channel=channel, program=PATCHES[instrument]["program"])])
        events = []
        for n in s["notes"]:
            if n["instrument"] == instrument:
                events.extend([(round(n["beat"] * 480), 1, n),
                               (round((n["beat"] + n["duration"]) * 480), 0, n)])
        previous = 0
        for tick, on, n in sorted(events, key=lambda e: (e[0], e[1], e[2]["pitch"])):
            track.append(mido.Message("note_on" if on else "note_off", channel=channel,
                                      note=n["pitch"], velocity=n["velocity"] if on else 0, time=tick - previous))
            previous = tick
        track.append(mido.MetaMessage("end_of_track", time=end - previous))
    file.save(path)


def envelope(t, hold, attack, release):
    env = np.sin(np.minimum(t / attack, 1) * np.pi / 2) ** 2
    env *= np.cos(np.clip((t - hold) / release, 0, 1) * np.pi / 2) ** 2
    return env


def synth(n, bpm, bank_sample, bank_wave):
    hold = n["duration"] * 60 / bpm
    instrument = n["instrument"]
    f = 440 * 2 ** ((n["pitch"] - 69) / 12)
    release = {"lantern_mallet": .55, "thread_pluck": .16, "reed": .16,
               "bowed_veil": .6, "hollow_bass": .13, "drums": .25}[instrument]
    t = np.arange(round((hold + release) * RATE)) / RATE
    phase = 2 * np.pi * f * t
    if instrument == "lantern_mallet":
        signal = (np.sin(phase + .8 * np.exp(-t * 11) * np.sin(phase * 3)) * np.exp(-t * 2.3)
                  + .19 * np.sin(phase * 2.005) * np.exp(-t * 5)
                  + .06 * np.sin(phase * 4.01) * np.exp(-t * 13))
        signal *= envelope(t, hold, .006, release)
    elif instrument == "thread_pluck":
        signal = np.zeros_like(t)
        for h in range(1, 9):
            signal += np.sin(phase * h) * (.68 / h ** 1.5) * np.exp(-t * (4 + h * 1.5))
        signal *= envelope(t, hold, .004, release)
    elif instrument == "reed":
        # Vibrato blooms after the attack; no random pitch or timing jitter.
        vib = 2 ** (5 * np.minimum(t / .25, 1) * np.sin(t * 2 * np.pi * 4.8) / 1200)
        ph = np.cumsum(2 * np.pi * f * vib / RATE)
        signal = (.80 * np.sin(ph) + .15 * np.sin(2 * ph) + .075 * np.sin(3 * ph)
                  + .025 * np.sin(5 * ph))
        signal *= envelope(t, hold, .025, release) * (.86 + .14 * np.exp(-t * 6))
    elif instrument == "hollow_bass":
        signal = (.84 * np.sin(phase) + .15 * np.sin(phase * 2) * np.exp(-t * 4)
                  + .07 * np.sin(phase * 3) * np.exp(-t * 6))
        signal *= envelope(t, hold, .008, release) * (.70 + .30 * np.exp(-t * 4))
    elif instrument == "bowed_veil":
        settings = {"release_seconds": release, "vibrato_cents": 2.5, "vibrato_hz": 4.1,
                    "render_gain": 1, "attack_seconds": .25}
        return _sampled_note(RenderNote(0, hold, n["pitch"], n["velocity"]),
                             settings, bank_sample, bank_wave, RATE)
    else:
        seed = n["pitch"] * 65537 + round(n["beat"] * 960) + n["velocity"]
        noise = np.random.default_rng(seed).uniform(-1, 1, len(t))
        smooth = np.convolve(noise, np.ones(7) / 7, mode="same")
        if n["pitch"] == 36:
            # Integrated decaying frequency, avoiding a discontinuous pitch sweep.
            ph = 2 * np.pi * (48 * t + 85 * .026 * (1 - np.exp(-t / .026)))
            signal = np.sin(ph) * np.exp(-t * 13) + .10 * smooth * np.exp(-t * 95)
        elif n["pitch"] == 38:
            signal = .38 * smooth * np.exp(-t * 26) + .18 * np.sin(2 * np.pi * 174 * t) * np.exp(-t * 30)
        elif n["pitch"] == 41:
            ph = 2 * np.pi * (100 * t + 45 * .035 * (1 - np.exp(-t / .035)))
            signal = .65 * np.sin(ph) * np.exp(-t * 19) + .12 * smooth * np.exp(-t * 50)
        else:
            signal = .17 * (noise - smooth) * np.exp(-t * 90)
        signal *= envelope(t, hold, .002, release)
    return signal * (n["velocity"] / 88) ** 1.35


def circular_add(mix, signal, start, pan):
    # Wrap complete note releases to the loop head; never cut a release or shorten a bar.
    gains = [math.cos((pan + 1) * np.pi / 4), math.sin((pan + 1) * np.pi / 4)]
    cursor = 0
    while cursor < len(signal):
        dest = (start + cursor) % len(mix)
        count = min(len(signal) - cursor, len(mix) - dest)
        mix[dest:dest + count] += signal[cursor:cursor + count, None] * gains
        cursor += count


def circular_dark_echo(stem, wet, beat_seconds):
    # Circular filtering and delay preserve the exact musical loop length.
    dark = sum(np.roll(stem, i, axis=0) for i in range(7)) / 7
    out = stem.copy()
    for seconds, gain in [(0.037, .22), (.071, .15), (beat_seconds * .75, .55),
                          (beat_seconds * 1.5, .25), (beat_seconds * 2.25, .10)]:
        out += np.roll(dark[:, ::-1], round(seconds * RATE), axis=0) * wet * gain
    return out


def loudness(path):
    run = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-i", str(path),
                          "-af", "loudnorm=I=-20:TP=-3:LRA=11:print_format=json",
                          "-f", "null", "-"], capture_output=True, text=True, check=True)
    return json.JSONDecoder().raw_decode(run.stderr[run.stderr.rfind("{"):])[0]


def render(s, destination, bank_sample, bank_wave):
    frames = round(s["bars"] * 4 * 60 / s["bpm"] * RATE)
    mix = np.zeros((frames, 2))
    stem_levels = {}
    for name in sorted({n["instrument"] for n in s["notes"]}):
        stem = np.zeros_like(mix)
        patch = PATCHES[name]
        for n in s["notes"]:
            if n["instrument"] == name:
                voice = synth(n, s["bpm"], bank_sample, bank_wave) * patch["gain"]
                circular_add(stem, voice, round(n["beat"] * 60 / s["bpm"] * RATE), patch["pan"])
        stem_levels[name] = float(np.sqrt(np.mean(stem ** 2)))
        mix += circular_dark_echo(stem, patch["wet"], 60 / s["bpm"])
    with tempfile.TemporaryDirectory(prefix="umbra-original-render-") as td:
        wave = Path(td) / "render.wav"
        # Prevent clipping in the measurement WAV, then use a single linear gain.
        mix *= .75 / max(np.max(np.abs(mix)), 1e-9)
        write_stereo_wave(wave, mix, RATE)
        measured = loudness(wave)
        desired = 10 ** ((-20 - float(measured["input_i"])) / 20)
        ceiling = 10 ** (-4 / 20) / np.max(np.abs(mix))
        applied_gain = min(desired, ceiling)
        mix *= applied_gain
        write_stereo_wave(wave, mix, RATE)
        for suffix, codec in [("flac", ["-c:a", "flac", "-compression_level", "8"]),
                              ("ogg", ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]),
                              ("mp3", ["-c:a", "libmp3lame", "-b:a", "192k"] )]:
            subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(wave),
                            "-map_metadata", "-1", *codec, str(destination / f"preview.{suffix}")], check=True)
        serial = int(hashlib.sha256(s["slug"].encode()).hexdigest()[:8], 16)
        normalize_ogg_serial(destination / "preview.ogg", serial)
    return {"sample_rate": RATE, "frames": frames, "duration_seconds": frames / RATE,
            "target_lufs": -20, "sample_peak_dbfs": float(20 * np.log10(np.max(np.abs(mix)))),
            "master_gain": float(applied_gain), "pre_master_stem_rms": stem_levels,
            "loop_method": "periodic note-release overlap-add and circular dark echo; no time shortening",
            "note_counts": dict(Counter(n["instrument"] for n in s["notes"]))}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output-dir", type=Path, default=CASE / "versions/v01")
    args = ap.parse_args()
    output = args.output_dir.resolve()
    if output.exists():
        raise SystemExit(f"Refusing to replace an audition directory: {output}. Use a new version/directory.")
    manifest = json.loads((BANK / "bank_manifest.json").read_text())
    sample = next(x for x in manifest["samples"] if x["bank_id"] == "hollow_viola")
    sample_path = BANK / sample["path"]
    if sha256(sample_path) != sample["sha256"]:
        raise SystemExit("Canonical viola sample hash mismatch")
    wave, _ = load_mono_wave(sample_path)
    output.mkdir(parents=True)
    source_paths = [Path(__file__), CASE / "scripts/verify.py", CASE / "README.md", CASE / "PROVENANCE.md",
                    CASE / "requirements.txt", BANK / "bank_manifest.json", sample_path,
                    ROOT / "tools/classical_soundtrack_pipeline/common.py",
                    ROOT / "tools/classical_soundtrack_pipeline/render.py"]
    sources = {str(p.relative_to(ROOT)): sha256(p) for p in source_paths}
    write_json(output / "SOURCES.json", {"source_kind": "original_authored_symbolic_composition",
               "approval_status": "awaiting_user_audition", "inputs_sha256": sources,
               "python_version": sys.version.split()[0], "numpy_version": np.__version__,
               "mido_version": str(mido.version_info),
               "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]})
    for s in [lanterns(), turning_key(), pursuit()]:
        folder = output / s["slug"]
        folder.mkdir()
        s["notes"].sort(key=lambda n: (n["beat"], n["instrument"], n["pitch"]))
        write_json(folder / "score.json", s)
        midi(s, folder / "arrangement.mid")
        report = render(s, folder, sample, wave)
        report["artifacts_sha256"] = {p.name: sha256(p) for p in sorted(folder.iterdir())}
        write_json(folder / "render.json", report)
        print(f"{s['title']}: {report['duration_seconds']:.2f}s rendered", flush=True)
    print(output, flush=True)


if __name__ == "__main__":
    main()
