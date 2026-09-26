#!/usr/bin/env python3
"""Verify new combat auditions and report their deliberately mixed articulation."""
from __future__ import annotations

import argparse
from collections import Counter
import json
from pathlib import Path

import compose
import verify as checks


def musical_metrics(s):
    lead = sorted((n for n in s["notes"] if n["instrument"] == s["lead_instrument"]), key=lambda n: n["beat"])
    gaps = [round(b["beat"] - a["beat"] - a["duration"], 6) for a, b in zip(lead, lead[1:])]
    checks.require(min(gaps) >= 0, "Monophonic lead notes overlap")
    checks.require(any(g > .05 for g in gaps) and any(g == 0 for g in gaps), "Lead lacks the intended mix of detached/connected gestures")
    short, held = sum(n["duration"] < .7 for n in lead), sum(n["duration"] >= 1.5 for n in lead)
    checks.require(short > 0 and held > 0, "Lead lacks varied short and held notes")
    parts = {n["instrument"] for n in s["notes"]}
    checks.require(4 <= len(parts) <= 6 and "drums" in parts, "Expected compact combat ensemble with percussion")
    for n in s["notes"]:
        checks.require(0 <= n["beat"] < s["bars"] * 4 and n["duration"] > 0, "Invalid note time")
        checks.require(n["beat"] + n["duration"] <= s["bars"] * 4 + 1e-6, "Note exceeds loop bounds")
        checks.require(0 <= n["pitch"] <= 127 and 1 <= n["velocity"] <= 127, "Invalid MIDI note/velocity")
    melodic_events = []
    for n in s["notes"]:
        if n["instrument"] != "drums":
            melodic_events.extend([(n["beat"], 1), (n["beat"] + n["duration"], -1)])
    voices = peak = 0
    for _, delta in sorted(melodic_events):
        voices += delta
        peak = max(peak, voices)
    checks.require(peak <= 6, "More than six simultaneous melodic gates")
    return {"lead_notes": len(lead), "detached_transitions": sum(g > .05 for g in gaps),
            "touching_transitions": sum(g == 0 for g in gaps), "short_notes_under_0_7_beats": short,
            "held_notes_at_least_1_5_beats": held,
            "maximum_internal_lead_gap_seconds": max(gaps) * 60 / s["bpm"],
            "lead_gate_coverage_fraction": sum(n["duration"] for n in lead) / (s["bars"] * 4),
            "parts": len(parts), "maximum_simultaneous_melodic_gates": peak}


def interval_signature(s):
    lead = sorted((n for n in s["notes"] if n["instrument"] == s["lead_instrument"]), key=lambda n: n["beat"])
    return tuple(n["pitch"] - lead[0]["pitch"] for n in lead[:16])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("directory", type=Path)
    ap.add_argument("--report", type=Path)
    args = ap.parse_args()
    directory = args.directory.resolve()
    manifest = json.loads((directory / "SOURCES.json").read_text())
    for path, expected in manifest["inputs_sha256"].items():
        checks.require(compose.v01.sha256(compose.ROOT / path) == expected, f"Source drift: {path}")
    folders = sorted(p for p in directory.iterdir() if p.is_dir())
    checks.require([p.name for p in folders] == compose.SLUGS, "Expected exactly the three new combat auditions")
    expected_scores = {s["slug"]: s for s in compose.compositions()}
    signatures = [interval_signature(s) for s in expected_scores.values()]
    checks.require(len(set(signatures)) == 3, "New tracks share the same opening melodic sequence")
    prior = compose.engine.pursuit()
    prior["lead_instrument"] = "grave_lead"
    checks.require(all(sig != interval_signature(prior) for sig in signatures), "An opening duplicates Ashen Pursuit")
    report = {"status": "passed", "source_hashes_checked": len(manifest["inputs_sha256"]),
              "listening_review": "User audition pending; technical and score checks do not establish aesthetic quality.",
              "tracks": {}}
    for folder in folders:
        s = json.loads((folder / "score.json").read_text())
        checks.require(s == expected_scores[folder.name], "Expanded score differs from authored composition")
        render = json.loads((folder / "render.json").read_text())
        checks.require(set(render["artifacts_sha256"]) == {"score.json", "arrangement.mid", "preview.ogg", "preview.flac", "preview.mp3"}, "Incomplete artifact inventory")
        for name, expected in render["artifacts_sha256"].items():
            checks.require(compose.v01.sha256(folder / name) == expected, f"Artifact drift: {folder.name}/{name}")
        checks.require(render["note_counts"] == dict(Counter(n["instrument"] for n in s["notes"])), "Render note count mismatch")
        midi = checks.check_midi(folder / "arrangement.mid", s)
        music = musical_metrics(s)
        duration = s["bars"] * 240 / s["bpm"]
        checks.require(45 <= duration <= 60, "Duration outside audition target")
        audio = {}
        for suffix in ["flac", "ogg", "mp3"]:
            path = folder / f"preview.{suffix}"
            checks._strict_decode(path)
            probe = checks._probe(path)
            checks.require(len(probe["streams"]) == 1, "Expected one audio stream")
            stream = probe["streams"][0]
            checks.require(stream["channels"] == 2 and int(stream["sample_rate"]) == 32000, "Wrong audio channel/sample rate")
            metrics = checks._decoded_metrics(path, 32000)
            checks.require(abs(metrics["duration_seconds"] - duration) < .005, "Decoded duration mismatch")
            checks.require(metrics["peak_dbfs"] < -1, "Insufficient sample peak headroom")
            checks.require(not checks._long_silences(path, .5), "Unexpected long silence")
            if suffix != "mp3":
                checks._validate_loop_seam(metrics, 1.5, str(path))
            metrics.update(checks.loudness(path))
            checks.require(-21 <= metrics["integrated_lufs"] <= -19, "Loudness outside matched audition range")
            checks.require(metrics["true_peak_dbtp"] < -1, "Insufficient true peak headroom")
            audio[suffix] = metrics
        report["tracks"][s["title"]] = {"midi": midi, "musical_structure": music, "audio": audio}
        print(f"PASS {s['title']}: {duration:.2f}s, {audio['flac']['integrated_lufs']:.2f} LUFS, "
              f"{music['detached_transitions']} detached / {music['touching_transitions']} joined lead transitions", flush=True)
    if args.report:
        compose.v01.write_json(args.report, report)
    print("Three distinct combat auditions passed score, MIDI, source, audio and loop checks.")


if __name__ == "__main__":
    main()
