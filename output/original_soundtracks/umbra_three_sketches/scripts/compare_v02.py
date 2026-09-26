#!/usr/bin/env python3
"""Check the requested musical revision against v01 and describe audio differences.

Gate-gap and spectrum measurements are evidence of specific changes, not taste scores.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess

import numpy as np

import build_v02 as revision


def lead_notes(score, instrument):
    return sorted((n for n in score["notes"] if n["instrument"] == instrument), key=lambda n: n["beat"])


def phrase_metrics(score, instrument):
    notes = lead_notes(score, instrument)
    gaps = [max(0, b["beat"] - a["beat"] - a["duration"]) * 60 / score["bpm"]
            for a, b in zip(notes, notes[1:])]
    return {"note_count": len(notes), "mean_internal_gate_gap_seconds": float(np.mean(gaps)),
            "maximum_internal_gate_gap_seconds": max(gaps),
            "gaps_at_least_quarter_second": sum(g >= .25 - 1e-6 for g in gaps),
            "note_gate_coverage_fraction": sum(n["duration"] for n in notes) / (score["bars"] * 4),
            "median_midi_pitch": float(np.median([n["pitch"] for n in notes]))}


def spectral_metrics(path):
    raw = subprocess.check_output(["ffmpeg", "-v", "error", "-xerror", "-i", str(path),
                                   "-f", "f32le", "-ac", "1", "-ar", "32000", "-"])
    pcm = np.frombuffer(raw, dtype="<f4")
    size = 8192
    windows = pcm[:len(pcm) // size * size].reshape(-1, size) * np.hanning(size)
    power = np.sum(np.abs(np.fft.rfft(windows, axis=1)) ** 2, axis=0)
    hz = np.fft.rfftfreq(size, 1 / 32000)
    return {"power_weighted_centroid_hz": float(np.sum(power * hz) / np.sum(power)),
            "power_fraction_above_1500_hz": float(np.sum(power[hz >= 1500]) / np.sum(power))}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()
    baseline = revision.CASE / "versions/v01"
    report = {"status": "passed", "scope": "specific revision checks, not subjective listening judgment", "tracks": {}}
    generated = [revision.lanterns(), revision.turning_key(), revision.pursuit()]
    for expected in generated:
        expected["notes"].sort(key=lambda n: (n["beat"], n["instrument"], n["pitch"]))
        slug = expected["slug"]
        before = json.loads((baseline / slug / "score.json").read_text())
        after = json.loads((args.directory / slug / "score.json").read_text())
        if expected != after:
            raise ValueError(f"Authored v02 score does not match delivery: {slug}")
        if slug.startswith("01"):
            old_part = new_part = "lantern_mallet"
            if lead_notes(before, old_part) != lead_notes(after, new_part):
                raise ValueError("Lanterns Below mallet melody was altered")
            if before["patches"][old_part] != after["patches"][new_part]:
                raise ValueError("Lanterns Below mallet patch was altered")
            if any(n["instrument"] == "drums" for n in after["notes"]):
                raise ValueError("Lanterns Below gained percussion")
        else:
            old_part = "reed"
            new_part = "shadow_viol" if slug.startswith("02") else "grave_lead"
            old, new = lead_notes(before, old_part), lead_notes(after, new_part)
            if slug.startswith("02"):
                if [n["pitch"] - 12 for n in old] != [n["pitch"] for n in new]:
                    raise ValueError("Turning Key melodic sequence did not survive transposition")
            else:
                for lo, hi in [(0, 32), (64, 96)]:
                    a = [n["pitch"] - 12 for n in old if lo <= n["beat"] < hi]
                    b = [n["pitch"] for n in new if lo <= n["beat"] < hi]
                    if a != b:
                        raise ValueError("Ashen Pursuit lost its opening/return melodic identity")
                if after["bpm"] != 100 or any(n["pitch"] in [38, 42] for n in after["notes"] if n["instrument"] == "drums"):
                    raise ValueError("Combat tempo/percussion revision missing")
            previous, current = phrase_metrics(before, old_part), phrase_metrics(after, new_part)
            if current["mean_internal_gate_gap_seconds"] > previous["mean_internal_gate_gap_seconds"] * .20:
                raise ValueError("Lead gaps were not materially reduced")
            if current["maximum_internal_gate_gap_seconds"] > .31:
                raise ValueError("An unintended extended lead rest remains")
            if current["note_gate_coverage_fraction"] < .90:
                raise ValueError("Connected lead does not span the phrases")
        report["tracks"][after["title"]] = {
            "v01_lead": phrase_metrics(before, old_part), "v02_lead": phrase_metrics(after, new_part),
            "v01_mix_spectrum": spectral_metrics(baseline / slug / "preview.flac"),
            "v02_mix_spectrum": spectral_metrics(args.directory / slug / "preview.flac")}
        x = report["tracks"][after["title"]]
        print(f"PASS {after['title']}: mean gate gap {x['v01_lead']['mean_internal_gate_gap_seconds']:.3f}s -> "
              f"{x['v02_lead']['mean_internal_gate_gap_seconds']:.3f}s; mix power centroid "
              f"{x['v01_mix_spectrum']['power_weighted_centroid_hz']:.1f} -> {x['v02_mix_spectrum']['power_weighted_centroid_hz']:.1f} Hz")
    if args.report:
        revision.v01.write_json(args.report, report)


if __name__ == "__main__":
    main()
