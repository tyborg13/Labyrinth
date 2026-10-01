#!/usr/bin/env python3
"""Verify versions/v02 (Noctyrax takes A/B + dark stingers) and, optionally, that v01 rebuilds byte-identically."""
from __future__ import annotations

import argparse
from collections import Counter
import filecmp
import json
from pathlib import Path
import sys

import numpy as np

HERE = Path(__file__).resolve().parent
SHARED = HERE.parent
sys.path.insert(0, str(SHARED))
import scores_dragons_v02 as scores  # noqa: E402
import dragon_audio as audio  # noqa: E402
import verify as checks  # noqa: E402  (umbra_three_sketches helpers, on the path through the engine chain)

v1, v01 = scores.v1, scores.v01
CASE = SHARED.parent
V01 = CASE / "versions/v01"
RANGES = {"violin_1": 55, "violin_2": 55, "viola": 48, "cello": 36, "contrabass": 23}
LOOP_SECONDS = (75, 100)
STINGER_SECONDS = {"07_stinger_level_up": (2.5, 4.0), "08_stinger_rare_reward": (2.0, 3.5),
                   "09_stinger_boss_defeated": (5.0, 7.0)}
OTHER_THEMES = v1.THEMES[:5]
THORNS_SCORE = v1.THORNS / "versions/v02/01_thorns_in_the_dark_v02/score.json"
require = checks.require


def lane(s, part):
    return sorted((n for n in s["notes"] if n["instrument"] == part), key=lambda n: (n["beat"], n["pitch"]))


def structure(s):
    end = s["bars"] * 4
    events = []
    for n in s["notes"]:
        require(0 <= n["beat"] < end and n["duration"] > 0 and n["beat"] + n["duration"] <= end + 1e-6, "Note bounds")
        require(0 <= n["pitch"] <= 127 and 1 <= n["velocity"] <= 127, "Invalid MIDI note")
        if n["instrument"] not in scores.PERCUSSION:
            events += [(round(n["beat"], 6), 1), (round(n["beat"] + n["duration"], 6), -1)]
    active = peak = 0
    for _, delta in sorted(events):
        active += delta
        peak = max(peak, active)
    require(peak <= 16, "More than sixteen simultaneous melodic gates (final-boss ensemble limit)")
    parts = {}
    for part in sorted({n["instrument"] for n in s["notes"]} & set(RANGES)):
        seq = lane(s, part)
        gaps = [round(b["beat"] - a["beat"] - a["duration"], 6) for a, b in zip(seq, seq[1:])]
        require(not gaps or min(gaps) >= 0, f"{part} is not monophonic")
        require(min(n["pitch"] for n in seq) >= RANGES[part], f"{part} below its range")
        parts[part] = {"notes": len(seq), "gate_coverage": round(sum(n["duration"] for n in seq) / end, 3)}
    return {"maximum_simultaneous_melodic_gates": peak, "string_lanes": parts,
            "instrument_parts": sorted({n["instrument"] for n in s["notes"]}),
            "lowest_pitch": min(n["pitch"] for n in s["notes"] if n["instrument"] not in scores.PERCUSSION)}


def signature(s, part):
    seq = lane(s, part)[:16]
    return tuple(n["pitch"] - seq[0]["pitch"] for n in seq)


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
            require(LOOP_SECONDS[0] <= expected <= LOOP_SECONDS[1], "Final-boss loop outside 75-100 seconds")
            require(not checks._long_silences(path, .5), "Unexpected silence")
            entry.update(checks.loudness(path))
            require(-21 <= entry["integrated_lufs"] <= -19, "Loop loudness outside -20 +/- 1 LUFS")
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
            if suffix != "mp3":
                require(low <= shape["duration_seconds"] <= high, "Stinger length outside its brief")
                require(shape["onset_seconds"] <= .01, "Stinger does not start promptly")
                require(shape["final_50ms_rms_dbfs"] < -60 and shape["final_10ms_peak_dbfs"] < -60, "Stinger tail is cut")
                require(shape["last_600ms_monotonic_decay"], "Stinger tail does not decay naturally")
        out[suffix] = entry
    return out


def tone(path):
    frames = audio.decode(path)
    mono = frames.mean(axis=1)
    power = np.abs(np.fft.rfft(mono)) ** 2
    freqs = np.fft.rfftfreq(len(mono), 1 / 32000)
    _, vectors = audio.chroma(frames)
    profile = vectors.sum(axis=0) / vectors.sum()
    return {"spectral_centroid_hz": round(float((power * freqs).sum() / power.sum()), 1),
            "energy_below_250_hz_percent": round(float(power[freqs < 250].sum() / power.sum() * 100), 1),
            "energy_above_2_khz_percent": round(float(power[freqs > 2000].sum() / power.sum() * 100), 2),
            "audio_key_estimate": audio.estimate_key(profile)["key"]}


def compare_dirs(first, second, skip=("VERIFICATION.json", "AUDITION.md", ".DS_Store")):
    """Byte-compare two builds. Hand-written reports and OS folder metadata (Finder's .DS_Store) are not build output."""
    names = sorted(str(p.relative_to(first)) for p in first.rglob("*") if p.is_file() and p.name not in skip)
    other = sorted(str(p.relative_to(second)) for p in second.rglob("*") if p.is_file() and p.name not in skip)
    require(names == other, f"Different file inventory: {first} vs {second}")
    different = [n for n in names if not filecmp.cmp(first / n, second / n, shallow=False)]
    require(not different, f"Builds differ: {different}")
    return {"compared_files": len(names), "byte_identical": True, "other_build": str(second)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--compare", type=Path, help="independent fresh v02 build to byte-compare")
    parser.add_argument("--v01-rebuild", type=Path, help="fresh scripts/build.py output to compare with versions/v01")
    args = parser.parse_args()
    directory = args.directory.resolve()
    manifest = json.loads((directory / "SOURCES.json").read_text())
    require(manifest["subset"] == "complete", "Development subset build")
    for path, expected in manifest["inputs_sha256"].items():
        require(v01.sha256(v1.ROOT / path) == expected, f"Source drift: {path}")
    for path, expected in manifest["outputs_sha256"].items():
        require(v01.sha256(directory / path) == expected, f"Output drift: {path}")
    folders = sorted(p for p in directory.iterdir() if p.is_dir())
    require([p.name for p in folders] == scores.SLUGS, "Wrong v02 audition inventory")
    expected_scores = {s["slug"]: s for s in scores.compositions()}
    report = {"status": "passed", "version": "v02", "source_hashes_checked": len(manifest["inputs_sha256"]),
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
                 "tone": tone(folder / "preview.flac")}
        if s["kind"] == "loop_theme":
            frames = audio.decode(folder / "preview.flac")
            sections = audio.section_loudness(folder / "preview.flac", s)
            harmony = audio.harmony_match(frames, s)
            require(harmony["median_rank"] <= 2, "Rendered harmony does not track the authored chords")
            entry.update(section_loudness=sections, harmony_from_audio=harmony,
                         onset_tempo_estimate_bpm=round(audio.onset_tempo(frames), 1),
                         stem_lufs_in_mix=render["stems"]["lufs_in_matched_mix"])
        else:
            parts = set(entry["structure"]["instrument_parts"])
            require(not parts & {"lantern_mallet", "thread_pluck"}, "Stinger still uses the bright v01 bell/pluck voices")
            require(entry["structure"]["lowest_pitch"] <= 40, "Stinger lacks low-register weight")
            entry["tone_v01_same_role"] = tone(V01 / folder.name / "preview.flac")
        report["pieces"][folder.name] = entry
        flac = entry["audio"]["flac"]
        print(f"PASS {s['title']}: {flac['duration_seconds']:.2f}s, {flac['integrated_lufs']:.2f} LUFS, "
              f"sample peak {flac['sample_peak_dbfs']:.1f} dBFS, true peak {flac['true_peak_dbtp']:.1f} dBTP", flush=True)
    # Distinct from the other dragons and Thorns; and bigger than any of them.
    others = {slug: json.loads((V01 / slug / "score.json").read_text()) for slug in OTHER_THEMES}
    thorns = json.loads(THORNS_SCORE.read_text())
    other_tempos = {s["bpm"] for s in others.values()} | {thorns["bpm"]}
    other_tonics = {audio.pitch_class(s["identity"]["tonic"]) for s in others.values()} | {audio.pitch_class("C")}
    other_signatures = {signature(s, s["lead_instrument"]) for s in others.values()} | {signature(thorns, "violin_1")}
    v01_dynamics = {slug: json.loads((V01 / slug / "render.json").read_text())["decoded"]["flac"] for slug in OTHER_THEMES}
    biggest = {k: max(d[k] for d in v01_dynamics.values()) for k in ["loudness_range_lu", "momentary_max_lufs",
                                                                      "short_term_max_lufs"]}
    takes = {}
    for slug in scores.THEMES:
        s = expected_scores[slug]
        flac = report["pieces"][slug]["audio"]["flac"]
        sections = report["pieces"][slug]["section_loudness"]
        tonic = audio.pitch_class(s["identity"]["tonic"])
        require(s["bpm"] not in other_tempos, f"{slug} shares a tempo with another theme or Thorns")
        require(tonic not in other_tonics, f"{slug} shares a tonic with another theme or Thorns")
        require(signature(s, s["lead_instrument"]) not in other_signatures, f"{slug} opening repeats another theme")
        loudest = max(sections, key=lambda x: x["integrated_lufs"])
        require(flac["loudness_range_lu"] >= biggest["loudness_range_lu"] + 2, f"{slug} has no larger dynamic arc")
        require(flac["momentary_max_lufs"] >= biggest["momentary_max_lufs"] + 1.5, f"{slug} climax is not bigger")
        require(loudest["integrated_lufs"] - min(x["integrated_lufs"] for x in sections) >= 3, f"{slug} lacks a real climax")
        takes[slug] = {"bpm": s["bpm"], "tonic_pitch_class": tonic, "opening_signature": list(signature(s, s["lead_instrument"])),
                       "loudness_range_lu": flac["loudness_range_lu"], "momentary_max_lufs": flac["momentary_max_lufs"],
                       "short_term_max_lufs": flac["short_term_max_lufs"], "loudest_section": loudest}
    a, b = (expected_scores[slug] for slug in scores.THEMES)
    require(a["bpm"] != b["bpm"] and a["identity"]["tonic"] != b["identity"]["tonic"], "Takes A and B do not contrast")
    report["final_boss_comparison"] = {"takes": takes, "largest_among_v01_themes_01_05": biggest,
                                       "other_theme_tempos": sorted(other_tempos),
                                       "other_theme_tonic_pitch_classes": sorted(other_tonics)}
    if args.compare:
        report["determinism"] = compare_dirs(directory, args.compare.resolve())
        print(f"Independent v02 build byte-identical: {report['determinism']['compared_files']} files", flush=True)
    if args.v01_rebuild:
        v01_manifest = json.loads((V01 / "SOURCES.json").read_text())
        for path, digest in v01_manifest["inputs_sha256"].items():
            require(v01.sha256(v1.ROOT / path) == digest, f"v01 source changed: {path}")
        for path, digest in v01_manifest["outputs_sha256"].items():
            require(v01.sha256(V01 / path) == digest, f"v01 output changed: {path}")
        report["v01_integrity"] = {"v01_sources_unchanged": len(v01_manifest["inputs_sha256"]),
                                   "v01_outputs_unchanged": len(v01_manifest["outputs_sha256"]),
                                   "fresh_v01_rebuild": compare_dirs(V01, args.v01_rebuild.resolve())}
        print(f"Fresh v01 rebuild byte-identical to versions/v01: "
              f"{report['v01_integrity']['fresh_v01_rebuild']['compared_files']} files", flush=True)
    if args.report:
        v01.write_json(args.report, report)
    print("v02 passed source, score, MIDI, structure, audio, loop/tail, distinctness and final-boss scale checks.")


if __name__ == "__main__":
    main()
