"""Rebuild sync heads from lossless parent recipes and durable per-path constraints."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import platform
import subprocess
import tempfile

import numpy as np
import scipy
import soundfile as sf

from tools.sfx_lab.build import process
from tools.sfx_lab.common import LabError, TakeLibrary, decode, encode, fade_in, read_json, sha256
from tools.sfx_lab.sync_metrics import RULES, envelope, envelope_times, peak_levels, short_loudness
from tools.sfx_lab.sync_duration import bind_duration_constraints, trim_tail

MAX_ENCODER_PASSES = 12
MAX_HEAD_CANDIDATES = 64
GAIN_MARGIN_DB = 0.08


def rules_digest() -> str:
    return hashlib.sha256(json.dumps(RULES, sort_keys=True).encode()).hexdigest()


def toolchain() -> dict:
    return {"python": platform.python_version(), "numpy": np.__version__, "scipy": scipy.__version__,
            "soundfile": sf.__version__, "libsndfile": sf.__libsndfile_version__,
            "ffmpeg": subprocess.check_output(["ffmpeg", "-version"], text=True).splitlines()[0],
            "encoder": "libsndfile Vorbis q6; Ogg serial=0 with page CRC repair; original granules"}


def builder_digest(root: Path) -> str:
    paths = ["sync.py", "sync_align.py", "sync_metrics.py", "sync_duration.py", "build.py", "common.py"]
    return hashlib.sha256(b"".join((root / "tools/sfx_lab" / path).read_bytes() for path in paths)).hexdigest()


def quiet_cut(samples: np.ndarray, rate: int, latest: int, peak_index: int) -> tuple[int, float]:
    """Walk backwards to a quiet sample, measuring both channels before fading.

    The cut is instantaneous max-channel amplitude relative to the selected
    RMS peak. Runtime PCM skips use their separate minimum-pre-peak/fade rule.
    """
    rms = envelope(samples, rate)
    threshold = rms[peak_index] * 10 ** (-RULES["cut_below_peak_db"] / 20)
    amplitude = np.max(np.abs(samples), axis=1)
    legal = np.flatnonzero(amplitude[:max(0, latest) + 1] <= threshold)
    if not len(legal): raise LabError("No quiet pre-peak sample exists")
    removed = int(legal[-1])
    below = float(20 * np.log10(max(1e-15, amplitude[removed]) / rms[peak_index]))
    return removed, below


def measures(path: Path) -> dict:
    from tools.sfx_lab.sync import leading_ms
    audio, rate = decode(path)
    return {**envelope_times(audio, rate), **peak_levels(audio),
            "leading_ms": leading_ms(audio, rate), "short_loudness_lufs": short_loudness(path),
            "sample_rate": rate, "duration_seconds": len(audio) / rate}


def write_provenance(path: Path, document: dict) -> None:
    def compact(value):
        if isinstance(value, float): return round(value, 6)
        if isinstance(value, list): return [compact(item) for item in value]
        if isinstance(value, dict): return {key: compact(item) for key, item in value.items()}
        return value
    used = {row.get("build") for row in document["outputs"]}
    document["builds"] = {key: value for key, value in document["builds"].items() if key in used}
    dump = lambda value: json.dumps(compact(value), sort_keys=True, ensure_ascii=False, separators=(",", ":"))
    lines = ["{"] + ["  " + json.dumps(key) + ":" + dump(value) + "," for key, value in sorted(document.items()) if key != "outputs"]
    lines += ['  "outputs":[', ",\n".join("    " + dump(row) for row in document["outputs"]), "  ]", "}"]
    path.write_text("\n".join(lines) + "\n")


def rebuild_aligned(root: Path, manifest: Path, features: Path, provenance: Path, sources: Path | None = None) -> dict:
    from tools.sfx_lab.sync import leading_ms, variant_from_provenance
    prior = read_json(provenance)
    if prior.get("schema_version") != 3:
        raise LabError("Expected compact version 3 provenance with per-path constraints")
    if sha256(manifest) != prior["parent_manifest_sha256"]:
        raise LabError("Parent recipe manifest changed")
    original = {row["path"]: row for row in read_json(manifest)["outputs"]}
    bind_duration_constraints(prior, read_json(root / "data/sfx_cues.json")["cues"])
    current_rules, current_builder, versions = rules_digest(), builder_digest(root), toolchain()
    build = {"rules_sha256": current_rules, "builder_sha256": current_builder, "toolchain": versions}
    build_id = hashlib.sha256(json.dumps(build, sort_keys=True).encode()).hexdigest()
    prior.setdefault("builds", {})[build_id] = build
    def constraints_digest(row: dict) -> str:
        return hashlib.sha256(json.dumps(row["constraints"], sort_keys=True).encode()).hexdigest()
    # No source-catalogue scan or writes on an already verified rebuild.
    pending = [row for row in prior["outputs"] if row.get("build") != build_id or
               row.get("constraints_sha256") != constraints_digest(row) or
               not (root / "assets/audio/sfx/cues" / row["path"]).exists() or
               sha256(root / "assets/audio/sfx/cues" / row["path"]) != row["output_sha256"]]
    if not pending:
        print(f"SFX04 BUILD RESULT: PASS (0 rebuilt; {len(prior['outputs'])} verified hashes)")
        return prior
    (root / "output/sfx").mkdir(parents=True, exist_ok=True)
    library = TakeLibrary(features, sources)
    for row in pending:
        parent = original[row["path"]]
        if parent["output_sha256"] != row["parent_output_sha256"] or parent["source_sha256"] != row["source_sha256"]:
            raise LabError("Parent recipe/source hash changed: " + row["path"])
        variant = variant_from_provenance(parent)
        samples, rate, parameters = process(library, library.get(variant), variant, parent["category"], parent["loop"], {})
        for key, value in parameters.items():
            if parent["processing"].get(key) != value:
                raise LabError(f"Original recipe changed: {row['path']} / {key}")
        samples *= 10 ** (float(parent["processing"]["encoder_gain_correction_db"]) / 20)
        source_metrics = envelope_times(samples, rate)
        peak_index = round(source_metrics["peak_ms"] * rate / 1000)
        bound = row["constraints"]
        minimum = min(max(float(bound["min_peak_ms"]), RULES["minimum_pre_peak_ms"]), source_metrics["peak_ms"])
        latest = max(0, int(np.floor((source_metrics["peak_ms"] - minimum) * rate / 1000)))
        needed_ms = max(0.0, source_metrics["perceived_onset_ms"] - bound["max_onset_ms"],
                        leading_ms(samples, rate) - RULES["leading_limit_ms"],
                        source_metrics["peak_ms"] - bound["max_peak_ms"] if bound["max_peak_ms"] is not None else 0.0)
        requested = min(latest, max(row["previous_removed_samples"], int(np.ceil(needed_ms * rate / 1000))))
        removed, cut_db = quiet_cut(samples, rate, requested, peak_index)
        rms = envelope(samples, rate)
        quiet = np.flatnonzero(np.max(np.abs(samples[:latest + 1]), axis=1) <=
                               rms[peak_index] * 10 ** (-RULES["cut_below_peak_db"] / 20))
        earliest = max(0, int(np.ceil((source_metrics["peak_ms"] - bound["max_peak_ms"]) * rate / 1000))) if bound["max_peak_ms"] is not None else 0
        nearby = quiet[quiet >= earliest]
        candidates = list(dict.fromkeys([removed] + ([int(nearby[-1])] if len(nearby) else []) +
            ([int(nearby[index]) for index in np.linspace(len(nearby) - 1, 0, min(MAX_HEAD_CANDIDATES, len(nearby))).astype(int)] if len(nearby) else [])))
        if "head_removed_samples" in bound:
            candidates = [int(bound["head_removed_samples"])]
        # Codec quantization can change which near-equal local peak reaches the
        # 2 dB threshold. Search only source-safe quiet cuts, never later peaks.
        path = root / "assets/audio/sfx/cues" / row["path"]
        best = None
        with tempfile.TemporaryDirectory(prefix="sfx-sync-", dir=root / "output/sfx") as temporary:
            rebuilt = Path(temporary) / path.name
            best_path = Path(temporary) / "best.ogg"
            for candidate in candidates:
                removed = candidate
                gain = 0.0
                for attempt in range(MAX_ENCODER_PASSES):
                    trimmed = fade_in(samples[removed:].copy(), rate, RULES["fade_ms"]) if removed else samples.copy()
                    trimmed = trim_tail(trimmed, rate, bound.get("max_duration_seconds"))
                    encode(rebuilt, trimmed * 10 ** (gain / 20), rate, "ogg")
                    actual = measures(rebuilt)
                    desired_gain = bound["reference_loudness_lufs"] - actual["short_loudness_lufs"]
                    allowed_gain = min(bound["peak_cap_dbfs"] - actual["peak_dbfs"],
                                       RULES["true_peak_ceiling_dbtp"] - actual["true_peak_dbtp"])
                    if allowed_gain >= 0 and (RULES["loudness_delta_lu"][0] <= -desired_gain <= RULES["loudness_delta_lu"][1] or 0 <= allowed_gain <= 0.1 < desired_gain):
                        break
                    # Once a cap was hit, only attenuate. Vorbis's quantized
                    # scalefactors otherwise oscillate around the cap.
                    if allowed_gain < 0:
                        gain += allowed_gain - GAIN_MARGIN_DB
                    else:
                        gain += min(desired_gain, allowed_gain - GAIN_MARGIN_DB)
                else:
                    continue
                score = max(0, minimum - actual["peak_ms"]) if removed else 0
                score += max(0, actual["peak_ms"] - bound["max_peak_ms"]) if bound["max_peak_ms"] is not None else 0
                score += max(0, actual["perceived_onset_ms"] - bound["max_onset_ms"])
                score += max(0, actual["leading_ms"] - RULES["leading_limit_ms"])
                if best is None or score < best[0]:
                    cut_db = float(20 * np.log10(max(1e-15, np.max(np.abs(samples[removed]))) / rms[peak_index]))
                    best = (score, removed, gain, actual, cut_db)
                    best_path.write_bytes(rebuilt.read_bytes())
                if score == 0: break
            if best is None: raise LabError("Encoded peak cap did not converge: " + row["path"])
            _, removed, gain, actual, cut_db = best
            rebuilt.write_bytes(best_path.read_bytes())
            actual["loudness_delta_lu"] = actual["short_loudness_lufs"] - bound["reference_loudness_lufs"]
            violations = []
            if actual["peak_dbfs"] > bound["peak_cap_dbfs"] or actual["true_peak_dbtp"] > RULES["true_peak_ceiling_dbtp"]:
                raise LabError("Peak cap not met: " + row["path"])
            cap = bound.get("max_duration_seconds")
            if cap is not None and actual["duration_seconds"] > cap:
                raise LabError("One-shot duration cap not met: " + row["path"])
            if actual["perceived_onset_ms"] > bound["max_onset_ms"]: violations.append("perceived onset exceeds cap")
            if bound["max_peak_ms"] is not None and actual["peak_ms"] > bound["max_peak_ms"]: violations.append("quiet cut retains a late peak")
            if actual["leading_ms"] > RULES["leading_limit_ms"]: violations.append("leading silence exceeds cap")
            if not RULES["loudness_delta_lu"][0] <= actual["loudness_delta_lu"] <= RULES["loudness_delta_lu"][1]: violations.append("capped loudness outside allowed window")
            if "tail_trim" in row:
                if violations:
                    raise LabError("Tail trim violates preserved constraints: " + row["path"] + "; " + "; ".join(violations))
                row["tail_trim"].update({"after_duration_seconds": actual["duration_seconds"],
                    "fade_out_ms": RULES["duration"]["tail_fade_ms"],
                    "fade_out_frames": round(rate * RULES["duration"]["tail_fade_ms"] / 1000),
                    "fade_curve": RULES["duration"]["tail_fade_curve"],
                    "kept_frames": round(actual["duration_seconds"] * rate),
                    "removed_frames": len(samples) - removed - round(actual["duration_seconds"] * rate)})
            row.update({"output_sha256": sha256(rebuilt), "removed_samples": removed, "sample_rate": rate,
                        "source_peak_ms": source_metrics["peak_ms"], "cut_relative_db": cut_db,
                        "fade_ms": RULES["fade_ms"], "gain_db": gain, "after": actual,
                        "build": build_id, "constraints_sha256": constraints_digest(row),
                        "constraint_exceptions": violations})
            for obsolete in ["rules_sha256", "builder_sha256", "toolchain"]: row.pop(obsolete, None)
            rebuilt.replace(path)
        # Every completed asset is restartable; interrupted work never adopts
        # unrecognized bytes as provenance. Original constraints remain intact.
        write_provenance(provenance, prior)
        print(f"SFX04 REBUILD {row['path']}: cut {row['previous_removed_samples']} -> {removed}; "
              f"peak {actual['peak_ms']:.3f} ms; loudness {actual['loudness_delta_lu']:+.3f} LU; "
              f"sample {actual['peak_dbfs']:.3f} dBFS / true {actual['true_peak_dbtp']:.3f} dBTP" +
              ("; " + "; ".join(violations) if violations else ""), flush=True)
    print(f"SFX04 BUILD RESULT: PASS ({len(pending)} rebuilt; peak caps verified; inspect constraint exceptions)")
    return prior
