#!/usr/bin/env python3
"""Recolour RGBA paint deterministically; replay rr-01 provenance without new art.

The Lab conversion is the production gate's pixel-identical implementation of
spec/art_identity/prototype/match_palette.py. Nonzero-alpha paint is transformed;
alpha and all four bytes of fully transparent pixels are retained.
"""
from __future__ import annotations

import argparse
import io
import json
import math
import re
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

import art_identity_gate as gate
import process_board_density as density

ROOT = Path(__file__).resolve().parents[1]
CRAWLER_L_SCALE = 0.76
CRAWLER_AB_SCALE = 0.85
CRAWLER_REASON = "legacy audit 2026-10-13: palette"
CRAWLER_METRICS_NOTE = "Adoption metrics are pre-recolour by design."
CRAWLER_DIRECT_PATHS = (
    "assets/placeholders/units/crawler_anime_trial.png",
    "assets/placeholders/units/crawler_anime_trial_idle.png",
    "assets/art/portraits/tunnel_crawler.png",
)
# Proof-only output location; no runtime consumer reads these baseline copies.
PROOF_BEFORE_DIR = "output/rr-01/before"


def read_rgba(path: Path) -> Image.Image:
    with Image.open(path) as image:
        if image.mode != "RGBA":
            raise ValueError(f"refusing non-RGBA image: {path} ({image.mode})")
        return image.copy()


def recolour(image: Image.Image, l_scale: float, ab_scale: float) -> Image.Image:
    if image.mode != "RGBA":
        raise ValueError(f"refusing non-RGBA image ({image.mode})")
    for name, value in (("l_scale", l_scale), ("ab_scale", ab_scale)):
        if not math.isfinite(value) or value < 0:
            raise ValueError(f"{name} must be finite and nonnegative")
    pixels = np.asarray(image).copy()
    painted = pixels[..., 3] > 0
    # Apple's accelerated matmul can leave spurious overflow/divide flags even
    # for bounded RGB. Validate the actual arrays rather than trusting those
    # flags; a real non-finite conversion always refuses the batch before writes.
    with np.errstate(over="ignore", divide="ignore", invalid="ignore"):
        lab = gate.to_lab(pixels[painted, :3].astype(float))
        lab[:, 0] *= l_scale
        lab[:, 1:] *= ab_scale
        if not np.isfinite(lab).all():
            raise ValueError("non-finite scaled Lab colour")
        rgb = gate.from_lab(lab)
    if not np.isfinite(rgb).all():
        raise ValueError("non-finite converted RGB colour")
    pixels[painted, :3] = np.clip(np.rint(rgb), 0, 255).astype(np.uint8)
    return Image.fromarray(pixels)


def palette(image: Image.Image) -> dict:
    pixels = np.asarray(image)
    # Same value/chroma definition and alpha threshold as the identity audit.
    rgb = pixels[pixels[..., 3] > 128, :3].astype(float) / 255.0
    if not len(rgb):
        return {"value": None, "chroma": None}
    return {"value": float((rgb * np.array([0.299, 0.587, 0.114])).sum(-1).mean()),
            "chroma": float((rgb.max(-1) - rgb.min(-1)).mean())}


def protected_crawler_path(path: Path) -> bool:
    resolved = path.resolve()
    return (resolved in {(ROOT / p).resolve() for p in CRAWLER_DIRECT_PATHS}
            or resolved.is_relative_to((density.SOURCES / "assets/units/crawler_cutout").resolve()))


def process_files(paths: list[Path], l_scale: float, ab_scale: float, in_place: bool,
                  force_rerecolour: bool = False) -> None:
    if len(set(path.resolve() for path in paths)) != len(paths):
        raise ValueError("duplicate input file (would apply the transform twice)")
    if in_place and not force_rerecolour:
        for path in paths:
            if protected_crawler_path(path):
                raise ValueError("already recoloured crawler path; refusing a second pass without --force-rerecolour: " + str(path))
    # Validate the complete batch before overwriting any file. Process one image
    # at a time afterwards so large idle sheets do not multiply peak memory.
    for path in paths:
        recolour(read_rgba(path), l_scale, ab_scale)
    for path in paths:
        before = read_rgba(path)
        after = recolour(before, l_scale, ab_scale)
        metrics = {"path": str(path), "before": palette(before), "after": palette(after),
                   "written": in_place}
        if in_place:
            after.save(path, format="PNG")
        print(json.dumps(metrics, sort_keys=True, allow_nan=False))


def baseline_commit(ref: str) -> str:
    result = subprocess.run(["git", "rev-parse", "--verify", "--end-of-options", ref + "^{commit}"], cwd=ROOT,
                            check=True, capture_output=True, text=True)
    return result.stdout.strip()


def baseline_bytes(commit: str, path: str) -> bytes:
    gate.repo_path(ROOT, path)
    return subprocess.run(["git", "show", commit + ":" + path], cwd=ROOT,
                          check=True, capture_output=True).stdout


def baseline_image(commit: str, path: str) -> Image.Image:
    with Image.open(io.BytesIO(baseline_bytes(commit, path))) as image:
        if image.mode != "RGBA":
            raise ValueError(f"refusing non-RGBA baseline: {path} ({image.mode})")
        return image.copy()


def crawler_step() -> dict:
    return {"step": "recolour_lab", "l_scale": CRAWLER_L_SCALE,
            "ab_scale": CRAWLER_AB_SCALE, "reason": CRAWLER_REASON}


def crawler_derivation() -> list[dict]:
    return [dict(crawler_step(), target="crawler density sources"),
            {"step": "density_regrid", "grid": 1.73},
            {"step": "native_rest_rebake", "tool": "tools/rebake_cutout_rests.gd"}]


def crawler_portrait_crop() -> Image.Image:
    """Read the director-owned size/focus from the builder, then replay its blit.

    This is a 1:1 crop with transparent padding, not a rescale or another Lab
    pass. The builder remains the authority for source, focus and canvas size.
    """
    code = (ROOT / "tools/build_turn_order_assets.gd").read_text()
    size_match = re.search(r"const PORTRAIT_SIZE\s*:=\s*(\d+)", code)
    row_match = re.search(r'\{\s*"key"\s*:\s*"crawler"[^}]+\}', code)
    if size_match is None or row_match is None:
        raise ValueError("cannot read crawler portrait crop from the builder")
    source_match = re.search(r'"source"\s*:\s*"res://([^"]+)"', row_match[0])
    focus_match = re.search(r'"focus"\s*:\s*Vector2i\(\s*(-?\d+)\s*,\s*(-?\d+)\s*\)', row_match[0])
    if source_match is None or focus_match is None:
        raise ValueError("cannot read crawler portrait source/focus from the builder")
    size = int(size_match[1])
    x, y = int(focus_match[1]) - size // 2, int(focus_match[2]) - size // 2
    return read_rgba(gate.repo_path(ROOT, source_match[1])).crop((x, y, x + size, y + size))


def crawler_inputs(commit: str) -> tuple[dict, dict]:
    registry_path = "spec/assets/board_pixel_density/registry.json"
    registry = density.load_registry()
    previous = json.loads(baseline_bytes(commit, registry_path))
    entry = next(e for e in registry["entries"] if e["id"] == "crawler")
    old_entry = next(e for e in previous["entries"] if e["id"] == "crawler")
    treatment = {k: v for k, v in entry.items() if k not in density.CALIBRATION_FIELDS}
    if treatment != old_entry:
        raise ValueError("crawler density settings changed; rr-01 preserves the approved treatment")
    calibration = density.recorded_calibration(entry)
    if calibration is not None and calibration["commit"] != commit:
        raise ValueError("crawler calibration and recolour must bind the same pre-recolour baseline")
    calibration_failures = density.calibration_errors([entry])
    if calibration_failures:
        raise ValueError("\n".join(calibration_failures))
    for path in density.source_paths(registry, [entry]):
        if path == registry["hero_reference"]:
            continue
        source_path = (density.SOURCES / path).relative_to(ROOT).as_posix()
        expected = recolour(baseline_image(commit, source_path), CRAWLER_L_SCALE, CRAWLER_AB_SCALE)
        if not density.same_pixels(ROOT / source_path, expected):
            raise ValueError("source does not replay recolour_lab: " + source_path)
    for path in CRAWLER_DIRECT_PATHS:
        if path == CRAWLER_DIRECT_PATHS[2]:
            if not density.same_pixels(ROOT / path, crawler_portrait_crop()):
                raise ValueError("crawler portrait differs from the builder's current-rest crop")
            continue
        if not (ROOT / path).exists() and path.endswith("_idle.png"):
            if subprocess.run(["git", "cat-file", "-e", commit + ":" + path], cwd=ROOT,
                              capture_output=True).returncode != 0:
                continue
        expected = recolour(baseline_image(commit, path), CRAWLER_L_SCALE, CRAWLER_AB_SCALE)
        if not density.same_pixels(ROOT / path, expected):
            raise ValueError("direct paint does not replay recolour_lab: " + path)
    manifest = json.loads(density.MANIFEST.read_text())
    failures = density.paint_errors([entry], manifest)
    if failures:
        raise ValueError("stale crawler density paint: " + "; ".join(failures))
    return entry, manifest


def crawler_registry(commit: str, paint_only: bool, record: bool) -> None:
    """Verify sources/paint, then bind the native-rest records and legacy gate.

    Alternative to changing the shared gate: this command checks deterministic
    input/part replay, while the native renderer owns rest assembly. Recording
    cannot certify stale rests or silently substitute a new legacy baseline.
    Run the renderer comparison probe after the native rebake as visual proof.
    """
    entry, manifest = crawler_inputs(commit)
    rests = density.rest_paths(entry)
    if not paint_only:
        failures = density.rest_errors([entry], manifest)
        if failures:
            raise ValueError("\n".join(failures))
        for path in rests:
            before = baseline_image(commit, path)
            after = read_rgba(ROOT / path)
            a, b = np.asarray(before), np.asarray(after)
            if a.shape != b.shape or not np.array_equal(a[..., 3], b[..., 3]):
                raise ValueError("native rest alpha changed: " + path)
            if not np.array_equal(a[a[..., 3] == 0], b[a[..., 3] == 0]):
                raise ValueError("native rest transparent pixels changed: " + path)
            if palette(after)["value"] >= palette(before)["value"]:
                raise ValueError("native rest has not been recoloured: " + path)
    registry_path = "spec/art_identity/registry.json"
    registry = json.loads((ROOT / registry_path).read_text())
    old_registry = json.loads(baseline_bytes(commit, registry_path))
    old_entries = {e["path"]: e for e in old_registry["entries"]}
    selected = [e for e in registry["entries"] if e["id"] == "crawler" and e["entry_kind"] == "legacy"
                and (not paint_only or e["path"] not in rests)]
    expected_paths = {CRAWLER_DIRECT_PATHS[0]} | (set() if paint_only else set(rests))
    if {e["path"] for e in selected} != expected_paths:
        raise ValueError("unexpected crawler legacy registry coverage")
    for current in selected:
        path = current["path"]
        previous = old_entries[path]
        old_digest = gate.pixel_digest(baseline_image(commit, path))
        if old_digest != previous["pixel_sha256"] or previous["entry_kind"] != "legacy":
            raise ValueError("previous legacy digest does not bind its baseline source: " + path)
        protected = {k: v for k, v in current.items() if k not in (
            "pixel_sha256", "post_steps", "derivation", "metrics_note", "recolour_baseline")}
        if protected != {k: v for k, v in previous.items() if k != "pixel_sha256"}:
            raise ValueError("legacy adoption fields changed: " + path)
        provenance = {"commit": commit, "pixel_sha256": old_digest}
        digest = gate.pixel_digest(read_rgba(ROOT / path))
        if record:
            current.update(pixel_sha256=digest, recolour_baseline=provenance, metrics_note=CRAWLER_METRICS_NOTE)
            if path in rests:
                current.pop("post_steps", None)
                current["derivation"] = crawler_derivation()
            else:
                current.pop("derivation", None)
                current["post_steps"] = [crawler_step()]
        else:
            if path in rests:
                valid_chain = current.get("derivation") == crawler_derivation() and "post_steps" not in current
            else:
                valid_chain = current.get("post_steps") == [crawler_step()] and "derivation" not in current
            if (not valid_chain or current.get("metrics_note") != CRAWLER_METRICS_NOTE
                    or current.get("recolour_baseline") != provenance or current["pixel_sha256"] != digest):
                raise ValueError("legacy recolour provenance/digest mismatch: " + path)
    if record:
        # Preserve every other enemy and the original adoption metrics byte values.
        gate.write_json(ROOT / registry_path, registry)
    print("CRAWLER RECOLOUR %s: PASS (%s; baseline %s)" %
          ("RECORD" if record else "CHECK", "paint only; native rests unchecked" if paint_only else "paint and native rest records", commit))


def prepare_proof(commit: str) -> None:
    paths = ("assets/units/crawler_cutout/front/rest.png", "assets/units/crawler_cutout/rear/rest.png",
             CRAWLER_DIRECT_PATHS[2])
    for path in paths:
        target = ROOT / PROOF_BEFORE_DIR / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(baseline_bytes(commit, path))
    proof = {"baseline_commit": commit, "paths": list(paths), "before_dir": PROOF_BEFORE_DIR,
             "before_pixels": {p: gate.pixel_digest(baseline_image(commit, p)) for p in paths}}
    (ROOT / PROOF_BEFORE_DIR / "manifest.json").write_text(json.dumps(proof, indent=2) + "\n")
    print("CRAWLER RECOLOUR PROOF BASELINES: " + PROOF_BEFORE_DIR)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--l-scale", type=float)
    parser.add_argument("--ab-scale", type=float)
    parser.add_argument("--in-place", action="store_true")
    parser.add_argument("--force-rerecolour", action="store_true", help="explicitly allow another pass on protected crawler paint")
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--check-crawler", action="store_true")
    action.add_argument("--record-crawler", action="store_true")
    action.add_argument("--prepare-proof", action="store_true")
    parser.add_argument("--baseline-ref", help="fixed previous commit; never infer a new adoption baseline")
    parser.add_argument("--paint-only", action="store_true", help="check/register paint without native rest verification")
    parser.add_argument("files", nargs="*", type=Path)
    args = parser.parse_args(argv)
    pipeline = args.check_crawler or args.record_crawler or args.prepare_proof
    if pipeline:
        if (not args.baseline_ref or args.files or args.in_place or args.force_rerecolour
                or args.l_scale is not None or args.ab_scale is not None):
            parser.error("crawler actions require --baseline-ref and do not accept file-transform options")
        if args.prepare_proof and args.paint_only:
            parser.error("--paint-only is for crawler check/record")
        commit = baseline_commit(args.baseline_ref)
        if args.prepare_proof:
            prepare_proof(commit)
        else:
            crawler_registry(commit, args.paint_only, args.record_crawler)
    else:
        if not args.files or args.l_scale is None or args.ab_scale is None:
            parser.error("supply --l-scale, --ab-scale and FILES (dry run unless --in-place)")
        if args.baseline_ref or args.paint_only:
            parser.error("--baseline-ref / --paint-only require a crawler action")
        if args.force_rerecolour and not args.in_place:
            parser.error("--force-rerecolour requires --in-place")
        process_files(args.files, args.l_scale, args.ab_scale, args.in_place, args.force_rerecolour)
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
