#!/usr/bin/env python3
"""Verify delivered audition bytes, independent MIDI readback, and decoded audio."""
from __future__ import annotations

import argparse
from collections import Counter
import json
import math
from pathlib import Path
import subprocess
import sys

import mido
import numpy as np

ROOT = next(p for p in Path(__file__).resolve().parents if (p / "project.godot").exists())
sys.path.insert(0, str(ROOT / "tools"))
from classical_soundtrack_pipeline.common import sha256, write_json  # noqa: E402
from classical_soundtrack_pipeline.verify import (  # noqa: E402
    _decoded_metrics, _long_silences, _probe, _strict_decode, _validate_loop_seam,
)


def require(condition, detail):
    if not condition:
        raise ValueError(detail)


def check_midi(path, score):
    midi = mido.MidiFile(path)
    expected_ticks = score["bars"] * 4 * midi.ticks_per_beat
    actual = []
    for track in midi.tracks:
        name = next((x.name for x in track if x.type == "track_name"), "")
        active = {}
        tick = 0
        for message in track:
            tick += message.time
            if message.type == "note_on" and message.velocity:
                key = (message.channel, message.note)
                require(key not in active, f"Overlapping same-pitch MIDI note in {name}")
                active[key] = (tick, message.velocity)
            elif message.type == "note_off" or (message.type == "note_on" and message.velocity == 0):
                key = (message.channel, message.note)
                require(key in active, f"Unmatched MIDI note-off in {name}")
                start, velocity = active.pop(key)
                actual.append((name, start, tick - start, message.note, velocity))
        require(not active, f"Hanging notes in {name}")
        require(tick == expected_ticks, f"Wrong MIDI track length in {name}")
    expected = [(n["instrument"], round(n["beat"] * midi.ticks_per_beat),
                 round((n["beat"] + n["duration"]) * midi.ticks_per_beat) - round(n["beat"] * midi.ticks_per_beat),
                 n["pitch"], n["velocity"]) for n in score["notes"]]
    require(Counter(actual) == Counter(expected), "MIDI notes do not match the editable score")
    require(abs(midi.length - score["bars"] * 240 / score["bpm"]) < .001, "MIDI tempo mismatch")
    return {"notes": len(actual), "tracks": len(midi.tracks) - 1, "duration_seconds": midi.length,
            "score_event_readback": "exact", "hanging_or_overlapping_same_pitch_notes": 0}


def loudness(path):
    run = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-i", str(path),
                          "-af", "loudnorm=I=-20:TP=-3:LRA=11:print_format=json",
                          "-f", "null", "-"], capture_output=True, text=True, check=True)
    values = json.JSONDecoder().raw_decode(run.stderr[run.stderr.rfind("{"):])[0]
    return {"integrated_lufs": float(values["input_i"]), "true_peak_dbtp": float(values["input_tp"]),
            "loudness_range_lu": float(values["input_lra"])}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()
    directory = args.directory.resolve()
    sources = json.loads((directory / "SOURCES.json").read_text())
    for relative, expected in sources["inputs_sha256"].items():
        require(sha256(ROOT / relative) == expected, f"Source drift: {relative}")
    folders = sorted(p for p in directory.iterdir() if p.is_dir())
    require([p.name for p in folders] == ["01_lanterns_below", "02_the_turning_key", "03_ashen_pursuit"],
            "Expected exactly the three named auditions")
    report = {"status": "passed", "source_hashes_checked": len(sources["inputs_sha256"]),
              "listening_review": "Not performed by this verifier; user taste audition is pending.",
              "tracks": {}}
    for folder in folders:
        score = json.loads((folder / "score.json").read_text())
        render = json.loads((folder / "render.json").read_text())
        require(set(render["artifacts_sha256"]) == {"score.json", "arrangement.mid", "preview.ogg", "preview.flac", "preview.mp3"},
                f"Incomplete artifact inventory: {folder.name}")
        for name, expected in render["artifacts_sha256"].items():
            require(sha256(folder / name) == expected, f"Artifact drift: {folder.name}/{name}")
        midi = check_midi(folder / "arrangement.mid", score)
        expected_seconds = score["bars"] * 240 / score["bpm"]
        require(45 <= expected_seconds <= 60, "Audition is not 45-60 seconds")
        counts = Counter(n["instrument"] for n in score["notes"])
        require(dict(counts) == render["note_counts"], "Render note counts do not match the score")
        audio = {}
        for suffix in ["flac", "ogg", "mp3"]:
            path = folder / f"preview.{suffix}"
            _strict_decode(path)
            probe = _probe(path)
            require(len(probe["streams"]) == 1, "Expected one audio stream")
            require(probe["streams"][0]["channels"] == 2, "Audio is not stereo")
            require(int(probe["streams"][0]["sample_rate"]) == 32000, "Wrong sample rate")
            metrics = _decoded_metrics(path, 32000)
            require(abs(metrics["duration_seconds"] - expected_seconds) < .005, "Decoded duration mismatch")
            require(metrics["peak_dbfs"] < -1, "Insufficient peak headroom")
            require(not _long_silences(path, .5), "Unexpected long silence")
            if suffix != "mp3":
                _validate_loop_seam(metrics, 1.5, str(path))
            metrics.update(loudness(path))
            require(-21 <= metrics["integrated_lufs"] <= -19, "Loudness outside comparison range")
            require(metrics["true_peak_dbtp"] < -1, "Insufficient true-peak headroom")
            audio[suffix] = metrics
        report["tracks"][score["title"]] = {"midi": midi, "audio": audio}
        print(f"PASS {score['title']}: {expected_seconds:.2f}s; {audio['flac']['integrated_lufs']:.2f} LUFS; "
              f"Ogg seam {max(audio['ogg']['seam_to_p99_9_ratio']):.3f}", flush=True)
    if args.report:
        write_json(args.report, report)
    print("All three auditions passed source, score, MIDI, decode, loudness, headroom, silence and loop checks.")


if __name__ == "__main__":
    main()
