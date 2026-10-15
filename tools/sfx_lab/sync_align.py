"""Rebuild approved heads to the measured sfx-04 visual climax and onset caps."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
import tempfile

import numpy as np

from tools.sfx_lab.build import process
from tools.sfx_lab.common import LabError, TakeLibrary, decode, encode, fade_in, loudness, read_json, sha256, write_json
from tools.sfx_lab.sync import leading_ms, variant_from_provenance
from tools.sfx_lab.sync_metrics import (ALIGNMENT_FADE_MS, MIN_PRE_PEAK_MS, PEAK_LATE_LIMIT_MS,
    LOUDNESS_TOLERANCE_LU, envelope_times, onset_cap, short_loudness)

# Encoder correction budget only; never changes the director's timing bounds.
MAX_ENCODER_PASSES = 256
MAX_HEAD_CANDIDATES = 64


def resources(cue: str, cues: dict) -> list[str]:
    entry = cues[cue]
    while entry.get("variants_from"):
        entry = cues[entry["variants_from"]]
    return entry.get("variants") or entry.get("fallback", [])


def constraints(phase: dict, cues: dict) -> dict:
    result = {}
    for event in phase["observations"]:
        if event["result"] != "played":
            continue
        cue = event["cue"]
        entry = cues[cue]
        cap = onset_cap(cue, entry)
        if cap is None:
            continue
        if event["delay_ms"] is None:
            raise LabError(f"Missing trigger measurement: {cue}")
        delay = event["delay_ms"]
        pmin = float(entry.get("pitch_scale", 1)) * (1 - float(entry.get("pitch_jitter", 0)))
        pmax = float(entry.get("pitch_scale", 1)) * (1 + float(entry.get("pitch_jitter", 0)))
        for path in resources(cue, cues):
            bound = result.setdefault(path, {"max_onset_ms": float("inf"), "max_peak_ms": None,
                                            "min_peak_ms": MIN_PRE_PEAK_MS, "cues": set(), "climaxes_ms": set()})
            bound["cues"].add(cue)
            bound["max_onset_ms"] = min(bound["max_onset_ms"], (cap - delay) * pmin)
            if event["climax_applicable"]:
                climax = event["climax_after_trigger_ms"]
                if climax is None:
                    raise LabError(f"Missing climax measurement: {cue} / {event['scenario']}")
                bound["climaxes_ms"].add(climax)
                upper = (climax + PEAK_LATE_LIMIT_MS - delay) * pmin
                bound["max_peak_ms"] = upper if bound["max_peak_ms"] is None else min(bound["max_peak_ms"], upper)
                # The director's lower alignment bound applies when this peak
                # was late and is being trimmed, not to an already early peak.
                if phase["samples"][path]["peak_ms"] > upper:
                    bound["min_peak_ms"] = max(bound["min_peak_ms"], (climax - delay) * pmax)
    for path, bound in result.items():
        bound["cues"] = sorted(bound["cues"])
        bound["climaxes_ms"] = sorted(bound["climaxes_ms"])
        if bound["max_peak_ms"] is not None and bound["max_peak_ms"] < bound["min_peak_ms"]:
            raise LabError(f"incompatible_peak_windows (director decision required): {path}: {bound}")
    return result


def needs_trim(metrics: dict, bound: dict) -> bool:
    return (metrics["perceived_onset_ms"] > bound["max_onset_ms"] or
            (bound["max_peak_ms"] is not None and metrics["peak_ms"] > bound["max_peak_ms"]))


def trim_samples(samples: np.ndarray, rate: int, removed: int) -> np.ndarray:
    peak = envelope_times(samples, rate)["peak_ms"]
    if peak - removed * 1000 / rate < MIN_PRE_PEAK_MS:
        raise LabError("Head trim would retain less than 15 ms of pre-peak build-up")
    return fade_in(samples[removed:].copy(), rate, ALIGNMENT_FADE_MS)


def rebuild_aligned(root: Path, manifest: Path, features: Path, provenance: Path, audit: Path) -> dict:
    document = read_json(audit)
    phase = document["feedback_1_before"]
    phase_sha = hashlib.sha256(json.dumps(phase, sort_keys=True).encode()).hexdigest()
    cues = read_json(root / "data/sfx_cues.json")["cues"]
    bounds = constraints(phase, cues)
    original = read_json(manifest)
    library = TakeLibrary(features)
    prior = read_json(provenance) if provenance.exists() else {"outputs": []}
    outputs = {entry["path"]: entry for entry in prior["outputs"]}
    changed = []
    for entry in original["outputs"]:
        path = root / "assets/audio/sfx/cues" / entry["path"]
        resource = "res://" + path.relative_to(root).as_posix()
        if resource not in bounds:
            continue
        before = phase["samples"][resource]
        bound = bounds[resource]
        if not needs_trim(before, bound):
            continue
        previous = outputs.get(entry["path"], entry)
        alignment = previous["processing"].get("sfx_04_alignment", {})
        if alignment.get("baseline_phase_sha256") == phase_sha and sha256(path) == previous["output_sha256"]:
            continue
        if sha256(path) != before["sha256"] or sha256(path) != previous["output_sha256"]:
            raise LabError(f"Unrecognized pre-feedback audio revision: {path}")
        if alignment:
            raise LabError(f"Refusing to stack an alignment onto a different baseline: {path}")
        variant = variant_from_provenance(entry)
        samples, rate, parameters = process(library, library.get(variant), variant, entry["category"], entry["loop"], {})
        for key, value in parameters.items():
            if entry["processing"].get(key) != value:
                raise LabError(f"Original build parameter changed: {entry['cue_id']} {key}")
        samples *= 10 ** (float(entry["processing"]["encoder_gain_correction_db"]) / 20)
        # Preserve the first sfx-04 pass, including its exact approved lead trim.
        lead_trim = previous["processing"].get("sfx_04")
        if lead_trim:
            samples = fade_in(samples[int(lead_trim["removed_samples"]):].copy(), rate, float(lead_trim["fade_in_ms"]))
        floating = envelope_times(samples, rate)
        minimum_trim_ms = max(0.0, floating["perceived_onset_ms"] - bound["max_onset_ms"],
                              floating["peak_ms"] - bound["max_peak_ms"] if bound["max_peak_ms"] is not None else 0.0)
        removed = int(np.ceil(minimum_trim_ms * rate / 1000))
        maximum_removed = int(np.floor((floating["peak_ms"] - bound["min_peak_ms"]) * rate / 1000))
        if removed > maximum_removed:
            raise LabError(f"Incompatible head trim (director decision required): {path}")
        candidates = iter(np.unique(np.linspace(removed, maximum_removed, MAX_HEAD_CANDIDATES).astype(int)))
        attempted_heads = set()
        target_loudness = before["short_loudness_lufs"]
        restore_gain_db = 0.0
        with tempfile.TemporaryDirectory(prefix="sfx-04-align-", dir=path.parent) as temporary:
            rebuilt = Path(temporary) / path.name
            for attempt in range(MAX_ENCODER_PASSES):
                attempted_heads.add(removed)
                trimmed = trim_samples(samples, rate, removed)
                encode(rebuilt, trimmed * 10 ** (restore_gain_db / 20), rate, "ogg")
                actual, actual_rate = decode(rebuilt)
                metrics = envelope_times(actual, actual_rate)
                measured_loudness = short_loudness(rebuilt)
                if needs_trim(metrics, bound):
                    correction = max(0.0, metrics["perceived_onset_ms"] - bound["max_onset_ms"],
                                     metrics["peak_ms"] - bound["max_peak_ms"] if bound["max_peak_ms"] is not None else 0.0)
                    corrected = removed + max(1, int(np.ceil(correction * rate / 1000)))
                    # Nearly equal peaks in a retained tail can exchange rank
                    # after Vorbis encoding. Search only legal head positions;
                    # never chase a later encoded peak by clipping the original
                    # transient or shortening the tail.
                    if corrected <= maximum_removed and corrected not in attempted_heads:
                        removed = corrected
                    else:
                        removed = next((int(candidate) for candidate in candidates if candidate not in attempted_heads), -1)
                        if removed < 0:
                            raise LabError(f"Encoded peak cannot align without clipping the transient: {path}")
                    restore_gain_db = 0.0
                    continue
                if metrics["peak_ms"] < bound["min_peak_ms"]:
                    removed = next((int(candidate) for candidate in candidates if candidate not in attempted_heads), -1)
                    if removed < 0:
                        raise LabError(f"Encoded peak precedes the climax: {path}: {metrics} / {bound}")
                    restore_gain_db = 0.0
                    continue
                encoded_lead = leading_ms(actual, actual_rate)
                lead_limit = 5.0 if lead_trim else 10.0
                if encoded_lead > lead_limit:
                    corrected = removed + max(1, int(np.ceil((encoded_lead - ALIGNMENT_FADE_MS) * rate / 1000)))
                    if corrected > maximum_removed:
                        raise LabError(f"Head trim cannot preserve both peak and leading-silence bounds: {path}")
                    removed = corrected
                    restore_gain_db = 0.0
                    continue
                if abs(measured_loudness - target_loudness) > LOUDNESS_TOLERANCE_LU:
                    restore_gain_db += target_loudness - measured_loudness
                    continue
                if np.max(np.abs(actual)) >= 1:
                    # Use the permitted ±0.5 LU restoration band to preserve
                    # headroom; do not add a limiter or change the tail/EQ.
                    restore_gain_db += float(20 * np.log10(np.nextafter(1.0, 0.0) / np.max(np.abs(actual))))
                    continue
                break
            else:
                raise LabError(f"Encoded alignment did not converge: {path}")
            output = copy.deepcopy(previous)
            output["parent_output_sha256"] = entry["output_sha256"]
            output["output_sha256"] = sha256(rebuilt)
            output["processing"]["sfx_04_alignment"] = {
                "task": "sfx-04", "rule": "director-feedback-1", "baseline_phase_sha256": phase_sha,
                "prior_output_sha256": before["sha256"], "removed_samples": removed,
                "removed_ms": removed * 1000 / rate, "fade_in_ms": ALIGNMENT_FADE_MS,
                "retained_pre_peak_ms": floating["peak_ms"] - removed * 1000 / rate,
                "fade_in_curve": "linear", "tail_preserved": True, "constraints": bound,
                "before": before, "after": {**metrics, "short_loudness_lufs": measured_loudness,
                                            "leading_ms": leading_ms(actual, actual_rate)},
                "loudness_restore_gain_db": restore_gain_db,
                "short_loudness_delta_lu": measured_loudness - target_loudness,
                "loudness_window_ms": 100.0, "loudness_hop_ms": 25.0,
                "encoder_passes": attempt + 1,
            }
            output["processing"]["output_duration"] = len(actual) / actual_rate
            output["processing"]["output_lufs"], output["processing"]["output_loudness_method"] = loudness(actual, actual_rate)
            output["processing"]["output_peak_dbfs"] = float(20 * np.log10(np.max(np.abs(actual))))
            # Persist provenance with each asset so an interrupted build resumes
            # from verified records rather than silently accepting unknown audio.
            rebuilt.replace(path)
        outputs[entry["path"]] = output
        prior.update({"schema_version": 2, "task": "sfx-04", "parent_manifest": str(manifest.relative_to(root)),
                      "parent_manifest_sha256": sha256(manifest),
                      "note": "Original recipe and cue levels preserved; only head trims, fades and measured loudness restoration gain are added.",
                      "outputs": [outputs[key] for key in sorted(outputs)]})
        write_json(provenance, prior)
        changed.append(entry["path"])
        print(f"SFX04 ALIGN {entry['path']}: onset {before['perceived_onset_ms']:.3f} -> {metrics['perceived_onset_ms']:.3f} ms; "
              f"peak {before['peak_ms']:.3f} -> {metrics['peak_ms']:.3f} ms; loudness delta {measured_loudness - target_loudness:+.3f} LU", flush=True)
    print(f"SFX04 ALIGN RESULT: PASS ({len(changed)} rebuilt; {len(outputs)} provenance records)")
    return prior
