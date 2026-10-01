#!/usr/bin/env python3
"""Verify the dragon themes/stingers audition: sources, scores, MIDI, audio, loops, tails and distinctness."""
from __future__ import annotations

import argparse
from collections import Counter
import filecmp
import itertools
import json
from pathlib import Path

import numpy as np

import dragon_scores as scores
import dragon_audio as audio
import verify as checks  # umbra_three_sketches helpers (on the path through the Thorns engine chain)

v01 = scores.v01
RANGES = {"violin_1": 55, "violin_2": 55, "viola": 48, "cello": 36}
STINGER_SECONDS = {"07_stinger_level_up": (2.5, 4.0), "08_stinger_rare_reward": (2.0, 3.0),
                   "09_stinger_boss_defeated": (5.0, 7.0)}
THORNS_SCORE = scores.THORNS / "versions/v02/01_thorns_in_the_dark_v02/score.json"
require = checks.require


def lane(s, part):
    return sorted((n for n in s["notes"] if n["instrument"] == part), key=lambda n: (n["beat"], n["pitch"]))


def structure(s):
    end = s["bars"] * 4
    events = []
    for n in s["notes"]:
        require(0 <= n["beat"] < end and n["duration"] > 0 and n["beat"] + n["duration"] <= end + 1e-6, "Note bounds")
        require(0 <= n["pitch"] <= 127 and 1 <= n["velocity"] <= 127, "Invalid MIDI note")
        if n["instrument"] != "drums":
            events += [(round(n["beat"], 6), 1), (round(n["beat"] + n["duration"], 6), -1)]
    active = peak = 0
    for _, delta in sorted(events):
        active += delta
        peak = max(peak, active)
    require(peak <= 6, "More than six simultaneous melodic gates (Thorns family limit)")
    parts = {}
    for part in sorted({n["instrument"] for n in s["notes"]} & set(RANGES)):
        seq = lane(s, part)
        gaps = [round(b["beat"] - a["beat"] - a["duration"], 6) for a, b in zip(seq, seq[1:])]
        require(not gaps or min(gaps) >= 0, f"{part} is not monophonic")
        require(min(n["pitch"] for n in seq) >= RANGES[part], f"{part} below its string range")
        parts[part] = {"notes": len(seq), "gate_coverage": round(sum(n["duration"] for n in seq) / end, 3),
                       "tremolo_notes": sum(n.get("articulation") == "tremolo" for n in seq),
                       "detached_transitions": sum(g > .05 for g in gaps), "touching_transitions": sum(g == 0 for g in gaps)}
    return {"maximum_simultaneous_melodic_gates": peak, "string_lanes": parts,
            "instrument_parts": sorted({n["instrument"] for n in s["notes"]})}


def signature(s, part):
    seq = [n for n in lane(s, part)][:16]
    return tuple(n["pitch"] - seq[0]["pitch"] for n in seq)


def symbolic_key(s):
    import music21
    stream = music21.stream.Stream()
    for n in s["notes"]:
        if n["instrument"] != "drums":
            stream.insert(n["beat"], music21.note.Note(n["pitch"], quarterLength=max(n["duration"], .0625)))
    result = stream.analyze("key.krumhanslschmuckler")
    return {"key": f"{result.tonic.name} {result.mode}", "correlation": round(float(result.correlationCoefficient), 3)}


def check_audio(s, folder, render):
    out = {}
    for suffix in ["flac", "ogg", "mp3"]:
        path = folder / f"preview.{suffix}"
        checks._strict_decode(path)
        streams = checks._probe(path)["streams"]
        require(len(streams) == 1 and streams[0]["channels"] == 2 and int(streams[0]["sample_rate"]) == 32000,
                "Wrong audio format (expected 32 kHz stereo)")
        if suffix == "ogg":
            require(streams[0]["codec_name"] == "vorbis", "Ogg is not Vorbis")
        metrics = checks._decoded_metrics(path, 32000)
        frames = audio.decode(path)
        loud = audio.ebur128(path)
        entry = {"duration_seconds": metrics["duration_seconds"], **loud}
        require(loud["sample_peak_dbfs"] <= -1 and loud["true_peak_dbtp"] < -1, "Insufficient peak headroom")
        if s["kind"] == "loop_theme":
            expected = s["bars"] * 240 / s["bpm"]
            require(abs(metrics["duration_seconds"] - expected) < .005, "Loop duration drift")
            require(48 <= expected <= 64, "Theme loop outside 48-64 seconds")
            require(not checks._long_silences(path, .5), "Unexpected silence")
            entry.update(checks.loudness(path))
            require(-21 <= entry["integrated_lufs"] <= -19, "Theme loudness outside -20 +/- 1 LUFS")
            if suffix != "mp3":
                checks._validate_loop_seam(metrics, 1.5, str(path))
                entry["sample_seam_to_p99_9_ratio"] = metrics["seam_to_p99_9_ratio"]
                entry["seam_profile"] = audio.seam_profile(frames, audio.section_starts(s))
                require(entry["seam_profile"]["within_internal_range"],
                        "Loop seam is more abrupt than any internal transition or section boundary")
        else:
            low, high = STINGER_SECONDS[s["slug"]]
            shape = audio.stinger_shape(frames)
            entry["shape"] = shape
            require(abs(loud["integrated_lufs"] - render["target_integrated_lufs"]) <= .6 or
                    render["limited_by"] == "peak ceiling", "Stinger loudness off target")
            if suffix != "mp3":  # MP3 adds encoder padding; its decoded duration is reported only
                require(low <= shape["duration_seconds"] <= high, "Stinger length outside its brief")
                require(shape["onset_seconds"] <= .01, "Stinger does not start promptly")
                require(shape["final_50ms_rms_dbfs"] < -60 and shape["final_10ms_peak_dbfs"] < -60, "Stinger tail is cut")
                require(shape["last_600ms_monotonic_decay"], "Stinger tail does not decay naturally")
        out[suffix] = entry
    return out


def listening_analysis(s, folder):
    frames = audio.decode(folder / "preview.flac")
    centres, vectors = audio.chroma(frames)
    profile = vectors.sum(axis=0) / vectors.sum()
    result = {"audio_key_estimate": audio.estimate_key(profile), "symbolic_key_estimate": symbolic_key(s),
              "chroma_profile": profile.round(4).tolist()}
    if s["kind"] == "loop_theme":
        result.update({"onset_tempo_estimate_bpm": round(audio.onset_tempo(frames), 1),
                       "harmony_from_audio": audio.harmony_match(frames, s),
                       "section_loudness": audio.section_loudness(folder / "preview.flac", s)})
    return result


def compare_builds(first, second):
    names = sorted(str(p.relative_to(first)) for p in first.rglob("*") if p.is_file()
                   and p.name not in {"VERIFICATION.json", "AUDITION.md"})
    other = sorted(str(p.relative_to(second)) for p in second.rglob("*") if p.is_file()
                   and p.name not in {"VERIFICATION.json", "AUDITION.md"})
    require(names == other, "Independent build has a different file inventory")
    different = [n for n in names if not filecmp.cmp(first / n, second / n, shallow=False)]
    require(not different, f"Independent build differs: {different}")
    return {"compared_files": len(names), "byte_identical": True, "other_build": str(second)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--compare", type=Path, help="independent fresh build to byte-compare")
    args = parser.parse_args()
    directory = args.directory.resolve()
    manifest = json.loads((directory / "SOURCES.json").read_text())
    require(manifest["subset"] == "complete", "Development subset build")
    for path, expected in manifest["inputs_sha256"].items():
        require(v01.sha256(scores.ROOT / path) == expected, f"Source drift: {path}")
    for path, expected in manifest["outputs_sha256"].items():
        require(v01.sha256(directory / path) == expected, f"Output drift: {path}")
    folders = sorted(p for p in directory.iterdir() if p.is_dir())
    require([p.name for p in folders] == scores.SLUGS, "Wrong audition inventory")
    expected_scores = {s["slug"]: s for s in scores.compositions()}
    report = {"status": "passed", "source_hashes_checked": len(manifest["inputs_sha256"]),
              "output_hashes_checked": len(manifest["outputs_sha256"]),
              "listening_review": "User audition pending. Numeric and score checks do not establish musical quality.",
              "pieces": {}}
    for folder in folders:
        s = json.loads((folder / "score.json").read_text())
        require(s == expected_scores[folder.name], "Expanded score differs from the authored composition")
        render = json.loads((folder / "render.json").read_text())
        require(set(render["artifacts_sha256"]) == {"score.json", "arrangement.mid", "preview.flac", "preview.ogg",
                                                     "preview.mp3"}, "Incomplete artifact inventory")
        for name, digest in render["artifacts_sha256"].items():
            require(v01.sha256(folder / name) == digest, f"Artifact drift: {folder.name}/{name}")
        require(render["note_counts"] == dict(Counter(n["instrument"] for n in s["notes"])), "Note count drift")
        stems = render["stems"]["post_master_peak_dbfs"]
        require(max(stems.values()) < -6, "A stem is too hot after mastering")
        entry = {"title": s["title"], "kind": s["kind"], "key": s["key"], "bpm": s["bpm"], "bars": s["bars"],
                 "midi": checks.check_midi(folder / "arrangement.mid", s), "structure": structure(s),
                 "stem_post_master_peak_dbfs": stems, "audio": check_audio(s, folder, render),
                 "listening_analysis": listening_analysis(s, folder)}
        if s["kind"] == "loop_theme":
            balance = render["stems"]["lead_above_middle_lu"]
            require(balance is None or -2 <= balance <= 4, "Middle strings buried or overpowering the lead")
            require(entry["listening_analysis"]["harmony_from_audio"]["median_rank"] <= 2,
                    "Rendered harmony does not track the authored chords")
            entry["lead_above_middle_lu"] = balance
            entry["stem_lufs_in_mix"] = render["stems"]["lufs_in_matched_mix"]
        report["pieces"][folder.name] = entry
        flac = entry["audio"]["flac"]
        print(f"PASS {s['title']}: {flac['duration_seconds']:.2f}s, {flac['integrated_lufs']:.2f} LUFS, "
              f"sample peak {flac['sample_peak_dbfs']:.1f} dBFS, true peak {flac['true_peak_dbtp']:.1f} dBTP", flush=True)
    themes = [expected_scores[slug] for slug in scores.THEMES]
    thorns = json.loads(THORNS_SCORE.read_text())
    tempos = [s["bpm"] for s in themes]
    tonics = [audio.pitch_class(s["identity"]["tonic"]) for s in themes]
    require(len(set(tempos)) == 6 and thorns["bpm"] not in tempos, "Themes share a tempo with each other or Thorns")
    require(len(set(tonics)) == 6 and audio.pitch_class("C") not in tonics, "Themes share a tonic with each other or Thorns")
    signatures = {s["slug"]: signature(s, s["lead_instrument"]) for s in themes}
    require(len(set(signatures.values())) == 6 and signature(thorns, "violin_1") not in signatures.values(),
            "An opening melodic sequence repeats another theme or Thorns")
    profiles = {slug: np.array(report["pieces"][slug]["listening_analysis"]["chroma_profile"]) for slug in scores.THEMES}
    correlation = {f"{a} ~ {b}": round(float(np.corrcoef(profiles[a], profiles[b])[0, 1]), 3)
                   for a, b in itertools.combinations(scores.THEMES, 2)}
    noctyrax = report["pieces"][scores.THEMES[5]]["listening_analysis"]["section_loudness"]
    require(max(noctyrax, key=lambda x: x["integrated_lufs"])["bars"] == "17-22" and
            noctyrax[3]["integrated_lufs"] - noctyrax[0]["integrated_lufs"] >= 3, "Noctyrax lacks its build to a climax")
    report["distinctness"] = {"tempos_bpm": dict(zip(scores.THEMES, tempos)), "thorns_bpm": thorns["bpm"],
                              "declared_tonic_pitch_classes": dict(zip(scores.THEMES, tonics)),
                              "opening_lead_interval_signatures": {k: list(v) for k, v in signatures.items()},
                              "thorns_opening_signature": list(signature(thorns, "violin_1")),
                              "pairwise_audio_chroma_correlation": correlation}
    if args.compare:
        report["determinism"] = compare_builds(directory, args.compare.resolve())
        print(f"Independent build byte-identical: {report['determinism']['compared_files']} files", flush=True)
    if args.report:
        v01.write_json(args.report, report)
    print("All nine pieces passed source, score, MIDI, structure, audio, loop/tail and distinctness checks.")


if __name__ == "__main__":
    main()
