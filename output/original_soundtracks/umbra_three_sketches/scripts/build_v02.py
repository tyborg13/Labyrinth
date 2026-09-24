#!/usr/bin/env python3
"""Second auditions: connected phrasing, darker strings, gentle Lanterns revision.

The v01 builder and all v01 source/artifacts stay byte-for-byte unchanged.
"""
from __future__ import annotations

import argparse
from collections import Counter
import copy
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile

import mido
import numpy as np

import build as v01

CASE, ROOT, RATE, BANK = v01.CASE, v01.ROOT, v01.RATE, v01.BANK


def revised(source):
    s = copy.deepcopy(source)
    s["version"] = "v02"
    s["based_on"] = f"versions/v01/{s['slug']}/score.json"
    s["patches"] = copy.deepcopy(v01.PATCHES)
    return s


def connected_lead(s, instrument, break_after_bars, breath=.35):
    """Touch successive notes; leave authored breaths only at phrase boundaries."""
    notes = sorted((n for n in s["notes"] if n["instrument"] == instrument), key=lambda n: n["beat"])
    end = s["bars"] * 4
    for i, n in enumerate(notes):
        next_start = notes[i + 1]["beat"] if i + 1 < len(notes) else end
        bar = int(n["beat"] // 4)
        last_in_bar = i + 1 == len(notes) or int(notes[i + 1]["beat"] // 4) != bar
        stop = next_start
        if last_in_bar and bar + 1 in break_after_bars:
            stop = min(next_start - breath, (bar + 1) * 4 - breath)
        n["duration"] = round(stop - n["beat"], 6)
        if n["duration"] <= 0:
            raise ValueError("Phrase breath would remove a note")


def lanterns():
    s = revised(v01.lanterns())
    s["mood"] = "Quiet exploration; preserved mallet melody with more connected low replies."
    s["patches"]["thread_pluck"]["gain"] *= .90
    s["patches"]["bowed_veil"]["gain"] *= 1.06
    s["patches"]["reed"].update({"wet": .24, "lowpass_hz": 1550})
    # Leave every mallet pitch, onset, gate, velocity, and synthesis setting intact.
    for n in s["notes"]:
        if n["instrument"] == "reed" and n["beat"] == 25:
            n["duration"] = 2.0
        elif n["instrument"] == "reed" and n["beat"] == 27:
            n["duration"] = 1.0
        elif n["instrument"] == "reed" and n["beat"] == 28:
            n["duration"] = 2.9
        elif n["instrument"] == "reed" and n["beat"] == 62.5:
            n["duration"] = 1.35
    v01.add(s, "reed", 7, 3.0, 1.0, "A3", 43)
    s["revision"] = ["Original mallet melody and instrument preserved exactly.",
                     "Connected low reply through bars 7-8; one quiet A3 answer at the phrase end.",
                     "Pluck softened 10%; pad raised 6%; low reed tail warmed."]
    return s


def turning_key():
    s = revised(v01.turning_key())
    s["mood"] = "Tense chamber-like planning; a connected tenor viol and quiet answering voice."
    s["patches"].pop("reed")
    s["patches"].pop("lantern_mallet")
    s["patches"]["shadow_viol"] = {"gain": .255, "pan": .07, "wet": .24, "program": 41,
        "bank_id": "hollow_viola", "legato": True, "lowpass_hz": 1250,
        "attack_seconds": .095, "release_seconds": .20, "vibrato_cents": 3.1}
    s["patches"]["answer_viol"] = {"gain": .090, "pan": -.28, "wet": .28, "program": 41,
        "bank_id": "hollow_viola", "legato": True, "lowpass_hz": 1100,
        "attack_seconds": .13, "release_seconds": .28, "vibrato_cents": 2.0}
    s["patches"]["thread_pluck"].update({"gain": .078, "wet": .24, "lowpass_hz": 1150})
    s["patches"]["bowed_veil"].update({"gain": .075, "lowpass_hz": 1700})
    s["patches"]["hollow_bass"]["gain"] = .235
    s["patches"]["drums"].update({"gain": .20, "lowpass_hz": 1300})
    for n in s["notes"]:
        if n["instrument"] == "reed":
            n["instrument"] = "shadow_viol"
            n["pitch"] -= 12
            bar, offset = divmod(n["beat"], 4)
            if int(bar) in [0, 4, 8, 12] and offset == .5:
                n["beat"] -= .5
            if offset == 1.75:
                n["beat"] -= .25
        elif n["instrument"] == "thread_pluck":
            n["pitch"] -= 12
    connected_lead(s, "shadow_viol", {4, 8, 12, 16}, .40)
    # Sparse responses occupy phrase endings; they are not unison melody doubling.
    for bar, notes in {3: [(2.25, 1.0, "E4"), (3.25, .70, "D4")],
                       7: [(2.50, 1.40, "B3")],
                       11: [(2.25, 1.65, "B3")],
                       15: [(2.50, 1.30, "A3")]}.items():
        for t, d, p in notes:
            v01.add(s, "answer_viol", bar, t, d, p, 54)
    s["revision"] = ["Original melodic pitch sequence retained one octave lower, on a bowed tenor viol.",
                     "Continuous bow within four-bar phrases; 0.4-beat breaths at their endings.",
                     "Quieter, lower pluck; sparse upper-viol answers connect the phrase endings."]
    return s


def pursuit():
    s = revised(v01.pursuit())
    s["bpm"] = 100
    s["mood"] = "Dark chamber pursuit; a low bowed lead, deliberate war drums, and a minor middle."
    # Reuse the harmony skeleton while replacing its brighter middle and the bouncy rhythm.
    s["notes"] = [n for n in s["notes"] if n["instrument"] == "bowed_veil" and not 32 <= n["beat"] < 48]
    s["patches"].pop("reed")
    s["patches"].pop("lantern_mallet")
    s["patches"]["grave_lead"] = {"gain": .285, "pan": .06, "wet": .25, "program": 42,
        "bank_id": "grave_cello", "legato": True, "lowpass_hz": 1150,
        "attack_seconds": .085, "release_seconds": .19, "vibrato_cents": 3.6}
    s["patches"]["answer_viol"] = {"gain": .090, "pan": -.30, "wet": .29, "program": 41,
        "bank_id": "hollow_viola", "legato": True, "lowpass_hz": 1150,
        "attack_seconds": .12, "release_seconds": .25, "vibrato_cents": 2.2}
    s["patches"]["thread_pluck"].update({"gain": .060, "wet": .24, "lowpass_hz": 950})
    s["patches"]["bowed_veil"].update({"gain": .070, "lowpass_hz": 1500})
    s["patches"]["hollow_bass"]["gain"] = .245
    s["patches"]["drums"].update({"gain": .26, "wet": .11, "lowpass_hz": 1100})
    for bar, label in [(8, "Gm(add9)"), (9, "Gm(add9)"), (10, "Ebmaj7"), (11, "Ebmaj7")]:
        s["harmony"][bar]["chord"] = label
    for bar, inner in [(8, ["Bb3", "D4"]), (10, ["G3", "D4"])]:
        for p in inner:
            v01.add(s, "bowed_veil", bar, 0, 7.88, p, 57)
    # The first eight and final eight bars retain the original melodic identity.
    phrases = [
        [(0, "D3"), (1, "A3"), (1.5, "F3"), (3, "E3"), (3.5, "D3")],
        [(0, "F3"), (1.5, "A3"), (2.5, "G3")],
        [(0, "F3"), (1, "D4"), (1.5, "A3"), (3, "G3"), (3.5, "F3")],
        [(0, "D3"), (2, "F3"), (3, "A3")],
        [(0, "G3"), (1, "D4"), (1.5, "Bb3"), (3, "A3"), (3.5, "G3")],
        [(0, "F3"), (1.5, "D3"), (2.5, "G3")],
        [(0, "E3"), (1, "A3"), (1.5, "G3"), (3, "E3"), (3.5, "C#3")],
        [(0, "E3"), (2, "G3"), (3, "A3")],
        [(0, "D4"), (2, "Bb3")], [(0, "A3"), (2, "G3")],
        [(0, "G3"), (2, "F3")], [(0, "Eb3"), (2, "D3")],
        [(0, "G3"), (1.5, "A3"), (2.5, "Bb3")],
        [(0, "A3"), (1.5, "F3"), (2.5, "D3")],
        [(0, "E3"), (1, "G3"), (1.5, "A3"), (3, "C#4"), (3.5, "B3")],
        [(0, "A3"), (2, "G3"), (3, "E3")],
        [(0, "D3"), (1, "A3"), (1.5, "F3"), (3, "E3"), (3.5, "D3")],
        [(0, "F3"), (1.5, "A3"), (2.5, "D4")],
        [(0, "F3"), (1, "D4"), (1.5, "A3"), (3, "G3"), (3.5, "F3")],
        [(0, "D3"), (2, "F3"), (3, "A3")],
        [(0, "G3"), (1.5, "Bb3"), (2.5, "A3")],
        [(0, "F3"), (1.5, "E3"), (2.5, "D3")],
        [(0, "E3"), (1, "A3"), (1.5, "G3"), (3, "E3"), (3.5, "C#3")],
        [(0, "E3"), (1.5, "C#3"), (2.5, "A2")],
    ]
    for bar, notes in enumerate(phrases):
        for i, (t, p) in enumerate(notes):
            velocity = (68 if 8 <= bar < 12 else 80) - i % 3 * 3
            v01.add(s, "grave_lead", bar, t, .1, p, velocity)
    connected_lead(s, "grave_lead", {2, 4, 6, 8, 12, 16, 18, 20, 22, 24}, .25)
    roots = ["D2", "D2", "Bb1", "Bb1", "G1", "G1", "A1", "A1", "G1", "G1", "Eb2", "Eb2",
             "G1", "Bb1", "A1", "A1", "D2", "D2", "Bb1", "Bb1", "G1", "Bb1", "A1", "A1"]
    # Low lute-like fragments replace the high, chiming arpeggio and bell punctuation.
    arps = {"D2": ["D3", "A3", "F3"], "Bb1": ["D3", "F3", "A3"],
            "G1": ["D3", "G3", "Bb3"], "A1": ["E3", "A3", "G3"],
            "Eb2": ["Eb3", "Bb3", "G3"]}
    for bar, root in enumerate(roots):
        quiet = 8 <= bar < 12
        for t, d, interval, vel in ([(0, 3.7, 0, 65)] if quiet else
                                  [(0, 1.4, 0, 80), (1.5, .38, 0, 55), (2, 1.72, 7, 68)]):
            v01.add(s, "hollow_bass", bar, t, d, v01.pitch(root) + interval, vel)
        for i, t in enumerate([0, 2.5] if quiet else [0, 2.0, 3.0]):
            v01.add(s, "thread_pluck", bar, t, .38, arps[root][i], 43 if quiet else 51)
        for t in ([0] if quiet else [0, 2]):
            v01.add(s, "drums", bar, t, .32, 36, 52 if quiet else 73)
        if not quiet:
            v01.add(s, "drums", bar, 3.0 if bar % 2 else 1.5, .26, 41, 47)
        if bar in [7, 15, 23]:
            v01.add(s, "drums", bar, 3.5, .24, 41, 52)
    for bar, notes in {3: [(2.75, 1.0, "D4")], 7: [(2.75, 1.0, "C#4")],
                       11: [(2.50, 1.4, "Bb3")], 15: [(2.75, 1.0, "C#4")],
                       19: [(2.75, 1.0, "D4")], 23: [(2.75, 1.0, "C#4")]}.items():
        for t, d, p in notes:
            v01.add(s, "answer_viol", bar, t, d, p, 51)
    s["sections"] = ["1-8: low bowed pursuit", "9-12: G-minor/E-flat suspended breath",
                     "13-16: rebuild", "17-24: connected return and dominant turnaround"]
    s["revision"] = ["Tenor cello lead replaces the high reed, with continuous bow through each phrase.",
                     "100 BPM; bass octave hops and bright ticks/backbeat removed in favor of low drum/tom weight.",
                     "G minor and borrowed E-flat replace the major-key middle; sparse viol answers mark returns."]
    return s


def midi(s, path):
    result = mido.MidiFile(type=1, ticks_per_beat=480)
    end = s["bars"] * 4 * 480
    meta = mido.MidiTrack([mido.MetaMessage("track_name", name=s["title"]),
        mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(s["bpm"])),
        mido.MetaMessage("time_signature", numerator=4, denominator=4),
        mido.MetaMessage("end_of_track", time=end)])
    result.tracks.append(meta)
    for channel_index, instrument in enumerate(sorted({n["instrument"] for n in s["notes"]})):
        channel = 9 if instrument == "drums" else channel_index
        track = mido.MidiTrack([mido.MetaMessage("track_name", name=instrument),
            mido.Message("program_change", channel=channel, program=s["patches"][instrument]["program"])])
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
        result.tracks.append(track)
    result.save(path)


def legato_phrase(notes, bpm, patch, sample, wave):
    """One continuous sample cursor and bow envelope across every connected phrase.

    Crucially, a new note changes pitch/pressure without restarting the sample's
    baked-in attack. Velocity ramps at note changes do not close the bow envelope.
    """
    beat = 60 / bpm
    start = notes[0]["beat"]
    hold = (notes[-1]["beat"] + notes[-1]["duration"] - start) * beat
    release = patch["release_seconds"]
    size = round((hold + release) * RATE)
    frequencies = np.empty(size)
    pressures = np.empty(size)
    for i, n in enumerate(notes):
        a = round((n["beat"] - start) * beat * RATE)
        b = round((notes[i + 1]["beat"] - start) * beat * RATE) if i + 1 < len(notes) else size
        frequencies[a:b] = 440 * 2 ** ((n["pitch"] - 69) / 12)
        pressures[a:b] = (n["velocity"] / 88) ** 1.35
        if i:
            # Very short transitions prevent abrupt sample-rate changes, not audible slides.
            transition = min(b - a, round(.012 * RATE))
            frequencies[a:a + transition] = np.linspace(frequencies[a - 1], frequencies[a], transition)
            smooth = min(b - a, round(.065 * RATE))
            pressures[a:a + smooth] = np.linspace(pressures[a - 1], pressures[a], smooth)
    t = np.arange(size) / RATE
    vibrato = 2 ** (patch["vibrato_cents"] * np.minimum(t / .4, 1) * np.sin(2 * np.pi * 4.6 * t) / 1200)
    steps = sample["sample_rate"] / RATE * frequencies / sample["stored_effective_frequency_hz"] * vibrato
    lo, hi = sample["loop_start_sample"], sample["loop_end_sample_exclusive"]
    positions = lo + np.mod(np.cumsum(steps) - steps[0], hi - lo)
    i0 = np.floor(positions).astype(int)
    i1 = lo + (i0 + 1 - lo) % (hi - lo)
    fraction = positions - i0
    signal = wave[i0] * (1 - fraction) + wave[i1] * fraction
    phrase_swell = .90 + .10 * np.sin(np.pi * np.minimum(t / hold, 1))
    return signal * pressures * phrase_swell * v01.envelope(t, hold, patch["attack_seconds"], release)


def circular_lowpass(stem, cutoff):
    # Zero-phase periodic response avoids a new filter startup transient at the seam.
    f = np.fft.rfftfreq(len(stem), 1 / RATE)
    response = 1 / np.sqrt(1 + (f / cutoff) ** 8)
    return np.fft.irfft(np.fft.rfft(stem, axis=0) * response[:, None], n=len(stem), axis=0)


def make_stem(s, name, samples, waves):
    frames = round(s["bars"] * 240 / s["bpm"] * RATE)
    stem = np.zeros((frames, 2))
    notes = sorted((n for n in s["notes"] if n["instrument"] == name), key=lambda n: n["beat"])
    patch = s["patches"][name]
    if patch.get("legato"):
        groups = []
        for n in notes:
            if not groups or n["beat"] > groups[-1][-1]["beat"] + groups[-1][-1]["duration"] + 1e-5:
                groups.append([])
            groups[-1].append(n)
        sample_id = patch["bank_id"]
        for group in groups:
            voice = legato_phrase(group, s["bpm"], patch, samples[sample_id], waves[sample_id])
            v01.circular_add(stem, voice * patch["gain"], round(group[0]["beat"] * 60 / s["bpm"] * RATE), patch["pan"])
    else:
        for n in notes:
            voice = v01.synth(n, s["bpm"], samples["hollow_viola"], waves["hollow_viola"])
            v01.circular_add(stem, voice * patch["gain"], round(n["beat"] * 60 / s["bpm"] * RATE), patch["pan"])
    if patch.get("lowpass_hz"):
        stem = circular_lowpass(stem, patch["lowpass_hz"])
    return stem


def render(s, destination, samples, waves):
    frames = round(s["bars"] * 240 / s["bpm"] * RATE)
    mix = np.zeros((frames, 2))
    levels = {}
    for name in sorted({n["instrument"] for n in s["notes"]}):
        stem = make_stem(s, name, samples, waves)
        levels[name] = float(np.sqrt(np.mean(stem ** 2)))
        mix += v01.circular_dark_echo(stem, s["patches"][name]["wet"], 60 / s["bpm"])
    with tempfile.TemporaryDirectory(prefix="umbra-v02-render-") as td:
        path = Path(td) / "render.wav"
        mix *= .75 / max(np.max(np.abs(mix)), 1e-9)
        v01.write_stereo_wave(path, mix, RATE)
        measured = v01.loudness(path)
        gain = min(10 ** ((-20 - float(measured["input_i"])) / 20), 10 ** (-4 / 20) / np.max(np.abs(mix)))
        mix *= gain
        v01.write_stereo_wave(path, mix, RATE)
        for suffix, codec in [("flac", ["-c:a", "flac", "-compression_level", "8"]),
                              ("ogg", ["-c:a", "vorbis", "-strict", "experimental", "-q:a", "5"]),
                              ("mp3", ["-c:a", "libmp3lame", "-b:a", "192k"])]:
            subprocess.run(["ffmpeg", "-v", "error", "-nostdin", "-i", str(path),
                            "-map_metadata", "-1", *codec, str(destination / f"preview.{suffix}")], check=True)
        serial = int(hashlib.sha256((s["slug"] + "v02").encode()).hexdigest()[:8], 16)
        v01.normalize_ogg_serial(destination / "preview.ogg", serial)
    return {"version": "v02", "sample_rate": RATE, "frames": frames, "duration_seconds": frames / RATE,
            "target_lufs": -20, "sample_peak_dbfs": float(20 * np.log10(np.max(np.abs(mix)))),
            "master_gain": float(gain), "pre_master_stem_rms": levels,
            "loop_method": "periodic phrase/release overlap-add, circular tone filters and echo; exact bar length",
            "lead_articulation": ("continuous sample position and bow envelope within connected note groups"
                                  if any(p.get("legato") for p in s["patches"].values())
                                  else "original mallet articulation; longer connected low replies"),
            "note_counts": dict(Counter(n["instrument"] for n in s["notes"]))}


def load_bank():
    manifest = json.loads((BANK / "bank_manifest.json").read_text())
    samples, waves = {}, {}
    for name in ["hollow_viola", "grave_cello"]:
        sample = next(x for x in manifest["samples"] if x["bank_id"] == name)
        path = BANK / sample["path"]
        if v01.sha256(path) != sample["sha256"]:
            raise ValueError(f"Canonical bank sample drift: {path}")
        samples[name] = sample
        waves[name], _ = v01.load_mono_wave(path)
    return samples, waves


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--output-dir", type=Path, default=CASE / "versions/v02")
    args = ap.parse_args()
    output = args.output_dir.resolve()
    if output.exists():
        raise SystemExit(f"Refusing to replace an audition directory: {output}. Use a new version/directory.")
    samples, waves = load_bank()
    source_paths = [Path(__file__), CASE / "scripts/build.py", CASE / "scripts/verify.py",
                    CASE / "scripts/compare_v02.py", CASE / "V02_NOTES.md", CASE / "PROVENANCE.md",
                    CASE / "requirements.txt", BANK / "bank_manifest.json",
                    *(BANK / s["path"] for s in samples.values()),
                    ROOT / "tools/classical_soundtrack_pipeline/common.py",
                    ROOT / "tools/classical_soundtrack_pipeline/render.py",
                    ROOT / "tools/classical_soundtrack_pipeline/verify.py"]
    source_paths.extend(sorted((CASE / "versions/v01").glob("*/score.json")))
    sources = {str(p.relative_to(ROOT)): v01.sha256(p) for p in source_paths}
    output.mkdir(parents=True)
    v01.write_json(output / "SOURCES.json", {"source_kind": "original_authored_symbolic_composition",
        "version": "v02", "approval_status": "awaiting_user_audition", "inputs_sha256": sources,
        "python_version": sys.version.split()[0], "numpy_version": np.__version__,
        "mido_version": str(mido.version_info),
        "ffmpeg_version": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0]})
    for s in [lanterns(), turning_key(), pursuit()]:
        folder = output / s["slug"]
        folder.mkdir()
        s["notes"].sort(key=lambda n: (n["beat"], n["instrument"], n["pitch"]))
        v01.write_json(folder / "score.json", s)
        midi(s, folder / "arrangement.mid")
        report = render(s, folder, samples, waves)
        report["artifacts_sha256"] = {p.name: v01.sha256(p) for p in sorted(folder.iterdir())}
        v01.write_json(folder / "render.json", report)
        print(f"{s['title']} v02: {report['duration_seconds']:.2f}s rendered", flush=True)
    print(output, flush=True)


if __name__ == "__main__":
    main()
