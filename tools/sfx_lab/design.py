"""Render director-authored layer recipes into deterministic, indexed sources."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys
import tempfile

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.sfx_lab.common import (LabError, OUTPUT_RATE, SourceRoots, TakeLibrary,
    cli, db, derive_licence, fade_in, fade_out, finite, front_pair, read_json,
    resample_audio, safe_component, safe_path, sha256, write_json, write_text)
import numpy as np
import soundfile as sf
from scipy import signal


# Defaults supplied by the sfx-02 recipe contract; never inferred from a cue.
LAYER_DEFAULTS = {"trim": [0.0, None], "pitch": 1.0, "reverse": False,
                  "gain_db": 0.0, "offset_ms": 0, "highpass_hz": None,
                  "lowpass_hz": None, "fade_in_ms": 3, "fade_out_ms": 30}
MASTER_DEFAULTS = {"highpass_hz": None, "lowpass_hz": None,
                   "peak_dbfs": -1.0, "fade_out_ms": 30}
FILTER_ORDER = 2
DESIGNED_LICENSE_TEXT = (
    "Each designed file is a derivative of approved sources and carries the most "
    "restrictive licence of its layers. The JSON sidecar is authoritative per file.\n"
    "Any Sonniss GDC layer: Sonniss GDC Bundle licence. Otherwise: CC0-1.0.\n"
)


def filters(data: np.ndarray, settings: dict) -> np.ndarray:
    for name, kind in (("highpass_hz", "highpass"), ("lowpass_hz", "lowpass")):
        cutoff = settings.get(name)
        if cutoff is not None:
            cutoff = finite(cutoff, name)
            if not 0 < cutoff < OUTPUT_RATE / 2:
                raise LabError(f"{name} must be between zero and Nyquist")
            sos = signal.butter(FILTER_ORDER, cutoff, btype=kind,
                                fs=OUTPUT_RATE, output="sos")
            data = signal.sosfilt(sos, data, axis=0)
    return data


def render_layer(library: TakeLibrary, recipe: dict) -> tuple[np.ndarray, int, dict]:
    if not isinstance(recipe, dict):
        raise LabError("Each layer must be an object")
    settings = {**LAYER_DEFAULTS, **recipe}
    row = library.get(settings)
    # Decode/resample the full take first, then trim at 48 kHz before tape pitch.
    data, rate, _ = library.excerpt(row, {})
    trim = settings["trim"]
    if not isinstance(trim, list) or len(trim) != 2:
        raise LabError("trim must be [start, end] relative to the take")
    start = finite(trim[0], "trim")
    end = len(data) / rate if trim[1] is None else finite(trim[1], "trim")
    if not 0 <= start < end <= len(data) / rate:
        raise LabError(f"trim is outside take: {trim}")
    data = data[round(start * rate):round(end * rate)]
    if not len(data):
        raise LabError("trim must contain at least one sample")
    pitch = finite(settings["pitch"], "pitch")
    if pitch <= 0:
        raise LabError("pitch must be positive")
    data = resample_audio(data, rate, OUTPUT_RATE, pitch)
    data, _ = front_pair(data)
    if not isinstance(settings["reverse"], bool):
        raise LabError("reverse must be boolean")
    if settings["reverse"]:
        data = data[::-1].copy()
    data = filters(data, settings)
    data = fade_in(data, OUTPUT_RATE, settings["fade_in_ms"])
    data = fade_out(data, OUTPUT_RATE, settings["fade_out_ms"])
    gain = finite(settings["gain_db"], "gain_db")
    with np.errstate(over="ignore", invalid="ignore"):
        data = data * np.power(10.0, gain / 20)
    if not np.isfinite(data).all():
        raise LabError("Layer gain produces non-finite audio")
    offset = finite(settings["offset_ms"], "offset_ms")
    if offset < 0:
        raise LabError("offset_ms must be nonnegative")
    provenance = {key: row[key] for key in ("source_path", "source_sha256", "take_id",
                                           "start_seconds", "end_seconds", "licence_id")}
    return data, round(offset * 48), provenance


def render_entry(library: TakeLibrary, recipe: dict) -> tuple[np.ndarray, dict]:
    if not isinstance(recipe, dict) or not isinstance(recipe.get("layers"), list) or not recipe["layers"]:
        raise LabError("A recipe requires a nonempty layers list")
    layers = [render_layer(library, layer) for layer in recipe["layers"]]
    natural_length = max(offset + len(data) for data, offset, _ in layers)
    length = (round(finite(recipe["length_s"], "length_s") * OUTPUT_RATE)
              if "length_s" in recipe else natural_length)
    if length <= 0:
        raise LabError("length_s must contain at least one sample")
    channels = max(data.shape[1] for data, _, _ in layers)
    data = np.zeros((max(length, natural_length), channels), dtype=np.float64)
    for layer, offset, _ in layers:
        # NumPy broadcasts a mono column to both channels of a stereo mix.
        data[offset:offset + len(layer)] += layer
    master = recipe.get("master", {})
    if not isinstance(master, dict):
        raise LabError("master must be an object")
    master = {**MASTER_DEFAULTS, **master}
    data = filters(data, master)
    peak = float(np.max(np.abs(data)))
    if not np.isfinite(data).all() or not peak:
        raise LabError("Cannot normalize a silent or non-finite mix")
    target = finite(master["peak_dbfs"], "peak_dbfs")
    if target > 0:
        raise LabError("peak_dbfs must be at most zero (never clip)")
    data = data * (10 ** (target / 20) / peak)
    data = fade_out(data, OUTPUT_RATE, master["fade_out_ms"])
    data = data[:length]
    if not np.any(data):
        raise LabError("Recipe produces silent audio after fade/truncation")
    provenance = [layer[2] for layer in layers]
    return data, {"recipe": recipe, "layers": provenance,
                  "licence_id": derive_licence(provenance)}


def write_wav(path: Path, data: np.ndarray) -> np.ndarray:
    path = safe_path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, suffix=".wav") as temporary:
        sf.write(temporary.name, data, OUTPUT_RATE, format="WAV", subtype="PCM_24")
        encoded, _ = sf.read(temporary.name, dtype="float64", always_2d=True)
        if not np.any(encoded):
            raise LabError("Recipe is silent at 24-bit PCM precision")
        Path(temporary.name).replace(path)
    return encoded


def output_path(root: Path, relative: str) -> Path:
    path = safe_path(root / relative)
    if not path.is_relative_to(root):
        raise LabError(f"Output escapes design output root: {relative}")
    return path


def design(recipes: Path, features: Path, out_root: Path,
           only: list[str] | None = None, on_render=None) -> list[dict]:
    entries = read_json(recipes)
    if not isinstance(entries, dict):
        raise LabError("Recipes must be an object keyed by cue id")
    library = TakeLibrary(features)
    out_root = safe_path(out_root)
    roots = library.sources.roots if isinstance(library.sources, SourceRoots) else [library.sources]
    if any(out_root.is_relative_to(root) or root.is_relative_to(out_root) for root in roots):
        raise LabError("Output root must be separate from read-only source roots")
    if only and any(cue not in entries for cue in only):
        raise LabError("--only contains an unknown cue id")
    jobs = []
    for cue, candidates in entries.items():
        safe_component(cue)
        if only and cue not in only:
            continue
        if not isinstance(candidates, dict):
            raise LabError(f"{cue} must contain label-keyed recipes")
        for label, entry in candidates.items():
            if label not in {"A", "B", "C", "D"}:
                raise LabError("Recipe labels must be A, B, C or D")
            relative = f"designed/{cue}/{label}"
            jobs.append((cue, label, entry, output_path(out_root, relative + ".wav"),
                         output_path(out_root, relative + ".json")))
    licence_path = output_path(out_root, "designed/LICENSE.txt")
    results = []
    for cue, label, entry, path, sidecar_path in jobs:
        data, sidecar = render_entry(library, entry)
        encoded = write_wav(path, data)
        write_json(sidecar_path, sidecar)
        if not results:
            write_text(licence_path, DESIGNED_LICENSE_TEXT)
        # Report measured PCM output, including the mandated post-peak master fade.
        result = {"cue": cue, "label": label, "duration": len(encoded) / OUTPUT_RATE,
                  "peak_dbfs": db(float(np.max(np.abs(encoded)))),
                  "licence_id": sidecar["licence_id"], "sha256": sha256(path)}
        results.append(result)
        if on_render is not None:
            on_render(result)
    return results


def report(row: dict) -> None:
    print(f"{row['cue']}\t{row['label']}\t{row['duration']:.6f}s\t"
          f"{row['peak_dbfs']:.3f} dBFS\t{row['licence_id']}\t{row['sha256']}", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--recipes", type=Path, required=True)
    parser.add_argument("--features", type=Path, required=True)
    parser.add_argument("--out-root", type=Path, required=True)
    parser.add_argument("--only", nargs="+", action="extend")
    args = parser.parse_args()
    design(args.recipes, args.features, args.out_root, args.only, report)


if __name__ == "__main__":
    cli(main)
