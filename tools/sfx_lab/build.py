"""Render owner-approved variants to game-ready Vorbis, with complete provenance."""
from __future__ import annotations

import argparse
from pathlib import Path
import shutil
import sys
import tempfile

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.sfx_lab.common import (LabError, TakeLibrary, cli, db, decode, design_value,
    encode, fade_in, fade_out, finite, front_pair, load_design, loudness, normalize, read_json,
    safe_component, safe_path, sha256, write_json, OUTPUT_RATE, SCHEMA_VERSION,
    SHORT_SECONDS, FADE_IN_MS, FADE_IN_CURVE, PITCH_MODE)
import numpy as np
from scipy import signal


CATEGORY_TARGETS = {"impact": -16, "body": -18, "vocal": -20, "ui": -26,
                    "card": -24, "ambience": -30, "spell": -18, "movement": -28,
                    "status": -22, "pickup": -22, "stinger": -16}
PEAK_TARGETS = {"impact": -3, "ui": -12}
LOOP_CROSSFADE_SECONDS = 0.5
ENCODE_MEASURE_ATTEMPTS = 16
LOUDNESS_TOLERANCE_LU = 0.5
ENCODE_CORRECTION_TOLERANCE = 0.05
NON_AMBIENCE_LOOP = True


def choose_channels(data: np.ndarray, category: str, design: dict) -> tuple[np.ndarray, dict]:
    data, parameters = front_pair(data)
    channels = data.shape[1]
    if channels == 1:
        return data, {**parameters, "channels": 1, "stereo_side_ratio": 0}
    mid = np.mean(data, axis=1, keepdims=True)
    side = (data[:, :1] - data[:, 1:]) / 2
    mid_rms = float(np.sqrt(np.mean(mid ** 2)))
    side_rms = float(np.sqrt(np.mean(side ** 2)))
    # Pure anti-phase has zero mid and nonzero side: always retain stereo.
    # Store null for the unbounded ratio to keep the manifest valid JSON.
    side_ratio = side_rms / mid_rms if mid_rms else (None if side_rms else 0)
    parameters.update({"stereo_side_ratio": side_ratio, "mid_rms": mid_rms, "side_rms": side_rms})
    if category in {"ambience", "stinger"}:
        return data, {**parameters, "channels": 2}
    threshold = finite(design_value(design, "stereo_side_ratio"), "stereo_side_ratio")
    result = data if side_ratio is None or side_ratio >= threshold else mid
    return result, {**parameters, "channels": result.shape[1], "stereo_side_ratio_threshold": threshold}


def crossfade_loop(data: np.ndarray, rate: int, design: dict) -> np.ndarray:
    count = round(LOOP_CROSSFADE_SECONDS * rate)
    if len(data) <= 2 * count:
        raise LabError("A 0.5 s loop crossfade requires more than 1 s of audio")
    design_value(design, "loop_crossfade_curve")
    theta = np.linspace(0, np.pi / 2, count)[:, None]
    join = data[-count:] * np.cos(theta) + data[:count] * np.sin(theta)
    # Join the middle to the blended tail/head. The wrap follows consecutive
    # original samples, instead of fading the entire recording into silence.
    return np.concatenate((data[count:-count], join))


def process(library: TakeLibrary, row: dict, variant: dict, category: str,
            loop: bool, design: dict) -> tuple[np.ndarray, int, dict]:
    if category not in CATEGORY_TARGETS:
        raise LabError(f"Unknown category: {category}")
    design_value(design, "pitch_mode")
    data, rate, parameters = library.excerpt(row, variant)
    data, channel_parameters = choose_channels(data, category, design)
    parameters.update(channel_parameters)
    cutoff = variant.get("lowpass_hz")
    if cutoff is not None:
        cutoff = finite(cutoff, "lowpass_hz")
        if not 0 < cutoff < rate / 2:
            raise LabError("lowpass_hz must be between zero and Nyquist")
        order = design_value(design, "lowpass_order")
        filter_kind = design_value(design, "lowpass_filter")
        # Periodic filtering avoids a filter startup transient at the loop seam.
        sos = signal.butter(order, cutoff, fs=rate, output="sos")
        if loop:
            filtered = signal.sosfilt(sos, np.tile(data, (3, 1)), axis=0)
            data = filtered[len(data):2 * len(data)]
        else:
            data = signal.sosfilt(sos, data, axis=0)
        parameters["lowpass_order"] = order
        parameters["lowpass_filter"] = filter_kind
    parameters["lowpass_hz"] = cutoff
    milliseconds = finite(variant.get("fade_out_ms", 30), "fade_out_ms")
    if milliseconds < 0:
        raise LabError("fade_out_ms must be nonnegative")
    data = fade_in(data, rate)
    parameters.update({"fade_in_ms": FADE_IN_MS, "fade_in_curve": FADE_IN_CURVE,
                       "fade_in_stage": "before_loop_crossfade" if loop else "before_normalization"})
    if loop:
        if category != "ambience" and not NON_AMBIENCE_LOOP:
            raise LabError("Loops outside ambience are disabled")
        data = crossfade_loop(data, rate, design)
        parameters.update({"loop_crossfade_seconds": LOOP_CROSSFADE_SECONDS,
                           "loop_crossfade_curve": design_value(design, "loop_crossfade_curve"),
                           "fade_out_ms": 0})
    else:
        data = fade_out(data, rate, milliseconds, design)
        parameters.update({"fade_out_ms": milliseconds,
                           "fade_curve": design_value(design, "fade_curve") if milliseconds else None})
    peak_target = PEAK_TARGETS.get(category)
    if len(data) / rate < SHORT_SECONDS:
        if category == "ambience":
            raise LabError("Ambience must be at least 0.4 s for integrated LUFS")
        targets = design_value(design, "short_peak_targets")
        peak_target = finite(targets[category], "short_peak_targets")
    data, normalization = normalize(data, rate, CATEGORY_TARGETS[category], peak_target,
                                    variant.get("gain_db", 0))
    parameters.update(normalization)
    parameters["pitch_mode"] = PITCH_MODE
    return data, rate, parameters


def encode_verified(path: Path, data: np.ndarray, rate: int, parameters: dict,
                    codec: str) -> dict:
    """Correct codec level drift; measure the actual deliverable, never a WAV proxy."""
    path = safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    target = (db(float(np.max(np.abs(data)))) if parameters["normalization"] == "short_peak_dbfs"
              else loudness(data, rate)[0])
    cumulative, lower_gain, upper_gain = 0.0, None, None
    cap = parameters["peak_target_dbfs"]
    best = None
    with tempfile.TemporaryDirectory(dir=path.parent) as temporary:
        encoded = Path(temporary) / ("candidate." + codec)
        selected = Path(temporary) / ("selected." + codec)
        for attempt in range(ENCODE_MEASURE_ATTEMPTS):
            encode(encoded, data * 10 ** (cumulative / 20), rate, codec)
            decoded, decoded_rate = decode(encoded)
            level, method = loudness(decoded, decoded_rate)
            peak = db(float(np.max(np.abs(decoded))))
            actual = peak if parameters["normalization"] == "short_peak_dbfs" else level
            if actual is None or peak is None:
                raise LabError(f"Encoder produced silent output: {path}")
            error = abs(actual - target)
            meets_cap = cap is None or peak <= cap + ENCODE_CORRECTION_TOLERANCE
            # Keep the closest valid encoding. Vorbis quantizer decisions can
            # make direct gain corrections oscillate on very short sounds.
            if meets_cap and peak <= 0 and (best is None or error < best[0]):
                best = (error, level, method, peak, len(decoded) / decoded_rate, cumulative)
                shutil.copyfile(encoded, selected)
            correction = target - actual
            if cap is not None:
                correction = min(correction, cap - peak)
            if abs(correction) <= ENCODE_CORRECTION_TOLERANCE and meets_cap and peak <= 0:
                break
            if correction > 0:
                lower_gain = cumulative
            else:
                upper_gain = cumulative
            cumulative = ((lower_gain + upper_gain) / 2
                          if lower_gain is not None and upper_gain is not None
                          else cumulative + correction)
        if best is None:
            raise LabError(f"Encoded output clips or exceeds peak cap: {path}")
        error, level, method, peak, duration, cumulative = best
        # Only a normalization cap can waive the encoded loudness tolerance.
        if error > LOUDNESS_TOLERANCE_LU and not parameters["peak_cap_applied"]:
            raise LabError(f"Encoded loudness outside tolerance: {path}")
        selected.replace(path)
    return {"output_lufs": level, "output_loudness_method": method,
            "output_peak_dbfs": peak, "output_duration": duration,
            "encoder_gain_correction_db": cumulative,
            "loudness_target_limited_by_peak_cap": parameters["peak_cap_applied"],
            "codec": "libvorbis" if codec == "ogg" else "libmp3lame",
            "encoder_backend": "libsndfile" if codec == "ogg" else "ffmpeg",
            "muxer": "ffmpeg",
            "quality": 6 if codec == "ogg" else 4, "sample_rate": OUTPUT_RATE,
            "encoder_threads": 2, "bitexact": True,
            "ogg_serial_offset": 0 if codec == "ogg" else None}


def build(approved: Path, out_dir: Path, manifest: Path, features: Path,
          sources: Path | None = None, design: dict | None = None) -> dict:
    design = design or {}
    out_dir, manifest = safe_path(out_dir), safe_path(manifest)
    library = TakeLibrary(features, sources)
    document = read_json(approved)
    if not isinstance(document, dict) or not document:
        raise LabError("approved.json must contain cue objects")
    jobs = []
    # Validate and resolve all picks before writing any cue files.
    for cue_id, cue in sorted(document.items()):
        safe_component(cue_id)
        category = cue["category"]
        if category not in CATEGORY_TARGETS:
            raise LabError(f"Unknown category: {category}")
        loop = cue.get("loop", False)
        if not isinstance(loop, bool) or not cue["variants"]:
            raise LabError("loop must be boolean and variants must be nonempty")
        for number, variant in enumerate(cue["variants"], start=1):
            row = library.get(variant)
            jobs.append((cue_id, category, loop, number, variant, row))
    outputs = []
    for cue_id, category, loop, number, variant, row in jobs:
        relative = f"{cue_id}/{cue_id}_{number:02d}.ogg"
        data, rate, parameters = process(library, row, variant, category, loop, design)
        path = safe_path(out_dir / relative)
        parameters.update(encode_verified(path, data, rate, parameters, "ogg"))
        outputs.append({"cue_id": cue_id, "category": category, "variant": number,
                        "path": relative, "loop": loop, "take_id": row["take_id"],
                        "take_start_seconds": row["start_seconds"], "take_end_seconds": row["end_seconds"],
                        "source_path": row["source_path"], "source_id": row["source_id"],
                        "licence_id": row["licence_id"], "source_sha256": row["source_sha256"],
                        "output_sha256": sha256(path), "processing": parameters,
                        "loop_start_seconds": 0 if loop else None,
                        "loop_end_seconds": len(data) / rate if loop else None})
    result = {"schema_version": SCHEMA_VERSION, "outputs": outputs}
    write_json(manifest, result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--approved", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--features", type=Path, default=Path("features.jsonl"))
    parser.add_argument("--sources", type=Path)
    parser.add_argument("--design-config", type=Path)
    args = parser.parse_args()
    result = build(args.approved, args.out_dir, args.manifest, args.features, args.sources,
                   load_design(args.design_config))
    print(f"BUILD outputs={len(result['outputs'])} manifest={args.manifest}")


if __name__ == "__main__":
    cli(main)
