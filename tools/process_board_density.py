#!/usr/bin/env python3
"""Adopt, derive, verify and report the board's source-preserving density treatment."""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import math
import shutil
import struct
import sys
from pathlib import Path

from PIL import Image

from pixel_density import classify_alpha, frame_rects, metrics, process, scale_axes, strength

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "spec/assets/board_pixel_density"
REGISTRY = ASSETS / "registry.json"
SOURCES = ASSETS / "sources"
MANIFEST = ASSETS / "outputs.json"
REPORT = ASSETS / "report.md"
CALIBRATION_FIELDS = ("calibration_source", "calibration_note", "calibration_baseline")
PRE_RECOLOUR_CALIBRATION = "pre-recolour source, 2026-10-07"
# Verification-only float tolerance, matching the existing seven-place tests.
CALIBRATION_METRIC_TOLERANCE = 1e-7


def repo_path(path: str) -> Path:
    candidate = ROOT / path
    if Path(path).is_absolute() or ".." in Path(path).parts or not candidate.resolve().is_relative_to(ROOT):
        raise ValueError(f"expected a repo-relative path: {path}")
    return candidate


def load_registry() -> dict:
    registry = json.loads(REGISTRY.read_text())
    ids, paths = set(), set()
    for entry in registry["entries"]:
        if entry["id"] in ids:
            raise ValueError(f"duplicate id: {entry['id']}")
        ids.add(entry["id"])
        for path in entry["paths"]:
            repo_path(path)
            if path in paths:
                raise ValueError(f"duplicate registered path: {path}")
            paths.add(path)
    for entry in registry["entries"]:
        alpha_source_entry(entry, registry)
        recorded_calibration(entry)
    return registry


def recorded_calibration(entry: dict) -> dict | None:
    """Only the director-approved crawler exception may use historical paint.

    Palette treatment changes RGB-distance orphan metrics, not the October 7
    density decision. Bind its original measurement fixtures to decoded digests;
    the commit is provenance text, not a dependency on historical Git objects.
    """
    if not any(field in entry for field in CALIBRATION_FIELDS):
        if entry.get("id") == "crawler" and entry.get("kind") == "rig":
            raise ValueError("crawler calibration fixtures and annotation are required")
        return None
    if entry["id"] != "crawler" or entry.get("kind") != "rig":
        raise ValueError("pre-recolour calibration is reserved for the rr-01 crawler")
    if entry.get("calibration_source") != PRE_RECOLOUR_CALIBRATION:
        raise ValueError("crawler calibration_source must name the pre-recolour source")
    note = entry.get("calibration_note")
    if not isinstance(note, str) or not note.strip():
        raise ValueError("crawler calibration_note must record the director decision")
    baseline = entry.get("calibration_baseline")
    if not isinstance(baseline, dict) or set(baseline) != {"commit", "paths", "pixel_sha256"}:
        raise ValueError("crawler calibration requires fixture paths and measurement digests")
    commit, digests = baseline["commit"], baseline["pixel_sha256"]
    if not isinstance(commit, str) or len(commit) != 40 or any(c not in "0123456789abcdef" for c in commit):
        raise ValueError("crawler calibration baseline must be a full Git commit")
    facings = entry.get("facings")
    if not isinstance(facings, dict) or not facings:
        raise ValueError("crawler calibration requires its facing measurements")
    measurements = {settings["measurement_path"] for settings in facings.values()}
    if not isinstance(digests, dict) or set(digests) != measurements:
        raise ValueError("crawler calibration digests must cover exactly its measurement paths")
    paths = baseline["paths"]
    if not isinstance(paths, dict) or set(paths) != measurements:
        raise ValueError("crawler calibration fixtures must cover exactly its measurement paths")
    for path, digest in digests.items():
        repo_path(path)
        if not isinstance(paths[path], str):
            raise ValueError("invalid crawler calibration fixture path: " + path)
        repo_path(paths[path])
        if not isinstance(digest, str) or len(digest) != 64 or any(c not in "0123456789abcdef" for c in digest):
            raise ValueError("invalid crawler calibration pixel digest: " + path)
    return baseline


def calibration_sample(entry: dict, settings: dict) -> Image.Image:
    baseline = recorded_calibration(entry)
    path = settings["measurement_path"]
    if baseline is None:
        return sample(SOURCES / path, entry["frames"])
    fixture = repo_path(baseline["paths"][path])
    if not fixture.is_file():
        raise ValueError("crawler calibration fixture missing: " + str(fixture))
    with Image.open(fixture) as original:
        if pixel_digest(original) != baseline["pixel_sha256"].get(path):
            raise ValueError("crawler calibration baseline pixel digest changed: " + path)
        image = original.convert("RGBA")
    x, y, w, h = frame_rects(image.size, entry["frames"])[0]
    return image.crop((x, y, x + w, y + h))


def calibration_errors(entries: list[dict]) -> list[str]:
    errors = []
    for entry in entries:
        try:
            if recorded_calibration(entry) is None:
                continue
            for facing, settings in entry["facings"].items():
                share = metrics(calibration_sample(entry, settings))["orphan_share"]
                t = strength(share)
                grid = round(t / entry["r"], 2)
                mode = "regrid" if grid >= 1.2 else "clean"
                if (not math.isclose(share, settings["orphan_share"], abs_tol=CALIBRATION_METRIC_TOLERANCE)
                        or not math.isclose(t, settings["t"], abs_tol=CALIBRATION_METRIC_TOLERANCE)
                        or settings["grid"] != grid or settings["mode"] != mode):
                    errors.append("calibration mismatch: %s/%s: recorded values do not derive from the bound pre-recolour source" %
                                  (entry["id"], facing))
        except (OSError, ValueError, KeyError, TypeError) as exc:
            errors.append("calibration invalid: %s: %s" % (entry["id"], exc))
    return errors


def alpha_source_entry(entry: dict, registry: dict) -> dict:
    """Resolve the static/measurement owner, rejecting broken family links."""
    entries = {e["id"]: e for e in registry["entries"]}
    source, seen = entry, {entry["id"]}
    while "alpha_class_from" in source:
        name = source["alpha_class_from"]
        if not isinstance(name, str) or name not in entries:
            raise ValueError(f"unknown alpha_class_from for {source['id']}: {name}")
        if name in seen:
            raise ValueError(f"cyclic alpha_class_from for {entry['id']}: {name}")
        seen.add(name)
        source = entries[name]
    return source


def alpha_settings(entry: dict, registry: dict | None = None) -> dict:
    source = alpha_source_entry(entry, registry if registry is not None else load_registry())
    measurement = sample(SOURCES / source["measurement_path"], source["frames"])
    return {**classify_alpha(measurement), "alpha_class_from": source["id"],
            "alpha_measurement_path": source["measurement_path"],
            "alpha_source_pixel_sha256": pixel_digest(measurement)}


def source_paths(registry: dict, entries: list[dict]) -> list[str]:
    # Native rest references must survive the later GPU rebake so reports and
    # grid calibration always refer to the untouched assembly.
    paths = {registry["hero_reference"]}
    for entry in entries:
        paths.update(entry["paths"])
        for settings in entry.get("facings", {"": entry}).values():
            paths.add(settings["measurement_path"])
        for rests in entry.get("rest_paths", {}).values():
            paths.update(rests)
        if "alpha_class_from" in entry:
            paths.add(alpha_source_entry(entry, registry)["measurement_path"])
    return sorted(paths)


def adopt(paths: list[str], force: bool) -> None:
    # Validate the whole adoption before copying anything. Accidentally adopting
    # treated production files must never replace an existing painted baseline.
    for path in paths:
        if not repo_path(path).is_file():
            raise ValueError(f"missing production file: {path}")
        if (SOURCES / path).exists() and not force:
            raise ValueError(f"source already exists: {path}; use --force-adopt for a deliberate repaint")
    for path in paths:
        target = SOURCES / path
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(repo_path(path), target)
    print(f"ADOPTED {len(paths)} source file(s)")


def png_bytes(image: Image.Image) -> bytes:
    buffer = io.BytesIO()
    image.save(buffer, format="PNG")
    return buffer.getvalue()


def pixel_digest(image: Image.Image) -> str:
    """Hash decoded RGBA, independent of PNG encoder, metadata or compression."""
    rgba = image.convert("RGBA")
    return hashlib.sha256(b"RGBA\0" + struct.pack(">II", *rgba.size) + rgba.tobytes()).hexdigest()


def settings_for_path(entry: dict, path: str) -> dict:
    if "facings" not in entry:
        return entry
    facing = Path(path).parent.name
    if entry.get("exact_source_partition") and entry["id"] == "storm_capacitor_cutout":
        # One shared painting, also used for the rear; storage is not a view.
        facing = "front"
    if facing not in entry["facings"]:
        raise ValueError(f"no facing settings for {path}")
    return entry["facings"][facing]


def derive(entry: dict, path: str) -> tuple[Image.Image, dict]:
    source = SOURCES / path
    settings = settings_for_path(entry, path)
    alpha = alpha_settings(entry) if settings["mode"] == "resample" else {}
    with Image.open(source) as original:
        if entry.get("exact_source_partition"):
            # rr-17 splits already treated production paint. Reprocessing each
            # crop would change rest identity and the director's glow table.
            if entry["id"] != "storm_capacitor_cutout":
                raise ValueError("exact_source_partition is reserved for rr-17")
            output = original.convert("RGBA")
        else:
            output = process(original, settings["mode"], settings["grid"], entry["frames"],
                             settings.get("scale", 1.0), alpha.get("alpha_class"))
        source_digest = pixel_digest(original)
    record = {"pixel_sha256": pixel_digest(output), "source_pixel_sha256": source_digest,
              "id": entry["id"], "mode": settings["mode"], "grid": settings["grid"]}
    if "facings" in entry:
        record["facing"] = "front" if entry.get("exact_source_partition") else Path(path).parent.name
    if settings["mode"] == "resample":
        record["scale"] = settings["scale"]
        record.update(alpha)
    return output, record


def same_pixels(path: Path, expected: Image.Image) -> bool:
    if not path.is_file():
        return False
    with Image.open(path) as current:
        rgba = current.convert("RGBA")
    return rgba.size == expected.size and rgba.tobytes() == expected.tobytes()


def rest_paths(entry: dict) -> list[str]:
    paths = {path for facing in entry.get("rest_paths", {}).values() for path in facing}
    # Historical assemblies remain shipped but are deliberately not rebaked.
    paths.update(entry.get("preserved_rest_paths", []))
    return sorted(paths)


def parts_digest(entry: dict) -> str:
    """Bind a rebake to the current decoded paint, including its path identities."""
    records = []
    for path in sorted(entry["paths"]):
        with Image.open(repo_path(path)) as image:
            records.append(path + "\0" + pixel_digest(image) + "\n")
    return hashlib.sha256("".join(records).encode("utf-8")).hexdigest()


def paint_errors(entries: list[dict], manifest: dict) -> list[str]:
    stale = []
    for entry in entries:
        for path in entry["paths"]:
            image, record = derive(entry, path)
            if not same_pixels(repo_path(path), image) or manifest.get(path) != record:
                stale.append(path)
    return stale


def rest_errors(entries: list[dict], manifest: dict) -> list[str]:
    stale = []
    for entry in entries:
        paths = rest_paths(entry)
        if not paths:
            continue
        current_parts = parts_digest(entry)
        for path in paths:
            record = manifest.get(path)
            reason = ""
            if not record or record.get("kind") != "rest" or record.get("id") != entry["id"]:
                reason = "no rebake record; run --record-rests after native rebake"
            elif not repo_path(path).is_file():
                reason = "rest image missing"
            else:
                with Image.open(repo_path(path)) as image:
                    if pixel_digest(image) != record.get("pixel_sha256"):
                        reason = "rest pixels changed since recorded rebake"
                if not reason and current_parts != record.get("parts_pixel_sha256"):
                    reason = "rig part pixels changed since recorded rebake"
            if reason:
                stale.append(f"rest rebake needed: {path}: {reason}")
    return stale


def record_rests(entries: list[dict], manifest: dict) -> None:
    stale = paint_errors(entries, manifest)
    if stale:
        raise ValueError("process current paint before --record-rests:\n" + "\n".join(stale))
    # Stage all records before writing, so a missing rest cannot record half a rig.
    records = {}
    for entry in entries:
        paths = rest_paths(entry)
        if not paths:
            continue
        current_parts = parts_digest(entry)
        for path in paths:
            with Image.open(repo_path(path)) as image:
                records[path] = {"kind": "rest", "id": entry["id"],
                                 "pixel_sha256": pixel_digest(image), "parts_pixel_sha256": current_parts}
    manifest.update(records)
    MANIFEST.write_text(json.dumps(dict(sorted(manifest.items())), indent=2) + "\n")
    print(f"RECORDED-RESTS {len(records)} file(s)")


def sample(path: Path, frames: dict | None) -> Image.Image:
    with Image.open(path) as original:
        im = original.convert("RGBA")
    x, y, w, h = frame_rects(im.size, frames)[0]
    return im.crop((x, y, x + w, y + h))


def report(registry: dict) -> None:
    lines = ["# Board pixel-density report", "",
             "Native calibration uses each facing's untouched rest or the first prop frame.",
             "Recorded pre-recolour calibration uses its bound historical source; paint metrics use current sources.",
             "Before/after are means over the first frame of each registered paint path.",
             "After derives from sources in memory; native rest/visual proof is separate.",
             "Screen-pixel ratios are relative to the hero on each axis: r_axis/scale_axis = 1.0;",
             "integer frame-size rounding can differ slightly from that ideal ratio.", "",
             "| Entry / facing | r (x) | t | grid | mode | Pixel ratio x old → new | Pixel ratio y old → new | Native orphan / run | Before orphan / run | After orphan / run | Screen run x before → after |",
             "| --- | ---: | ---: | ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: |"]
    hero = metrics(sample(SOURCES / registry["hero_reference"], None))
    label = lambda m: f"{100*m['orphan_share']:.2f}% / {m['run_length']:.3f}"
    lines.append(f"| Hero front (untouched reference) | 1 | — | — | reference | 1.000 → 1.000 | 1.000 → 1.000 | {label(hero)} | {label(hero)} | {label(hero)} | {hero['run_length']:.3f} → {hero['run_length']:.3f} |")
    for entry in registry["entries"]:
        for facing, settings in entry.get("facings", {"": entry}).items():
            alpha = alpha_settings(entry, registry) if settings["mode"] == "resample" else {}
            paths = [p for p in entry["paths"] if not facing or Path(p).parent.name == facing]
            native = metrics(calibration_sample(entry, settings))
            before, after = [], []
            for path in paths:
                im = sample(SOURCES / path, entry["frames"])
                before.append(metrics(im))
                after.append(metrics(process(im, settings["mode"], settings["grid"], None,
                                             settings.get("scale", 1.0), alpha.get("alpha_class"))))
            mean = lambda values: {key: sum(m[key] for m in values) / len(values) for key in hero}
            b, a = mean(before), mean(after)
            rx, ry = scale_axes(entry.get("r_axes", entry["r"]))
            sx, sy = scale_axes(settings.get("scale", 1.0))
            new_rx, new_ry = rx / sx, ry / sy
            name = entry["id"] + (" / " + facing if facing else "")
            lines.append(f"| {name} | {rx:.6f} | {settings['t']:.4f} | {settings['grid']:.2f} | {settings['mode']} | {rx:.3f} → {new_rx:.3f} | {ry:.3f} → {new_ry:.3f} | {label(native)} | {label(b)} | {label(a)} | {b['run_length']*rx:.3f} → {a['run_length']*new_rx:.3f} |")
    lines += ["", "## Fixed rig geometry", "",
              "Rigs retain their 255-pixel logical canvas and never resample. Dragon pixels",
              "still draw larger than the hero; native cleanup preserves their fixed geometry.", "",
              "## Resample alpha families", "",
              "Each entry measures once; linked sheets/parts inherit their static family source.",
              "The translucent fraction counts 64 ≤ alpha < 240 among nonzero source pixels.", "",
              "| Entry | Measurement owner | Alpha class | Translucent fraction | Measurement path |",
              "| --- | --- | --- | ---: | --- |"]
    for entry in registry["entries"]:
        if entry.get("mode") == "resample":
            alpha = alpha_settings(entry, registry)
            lines.append(f"| {entry['id']} | {alpha['alpha_class_from']} | {alpha['alpha_class']} | {alpha['translucent_alpha_fraction']:.6f} | `{alpha['alpha_measurement_path']}` |")
    lines += ["",
              "## Production files per entry", "",
              "A † marks changed decoded pixels or dimensions relative to untouched source paint.", ""]
    for entry in registry["entries"]:
        lines += [f"### {entry['id']}", ""]
        for path in entry["paths"]:
            image, _ = derive(entry, path)
            with Image.open(SOURCES / path) as original:
                im = original.convert("RGBA")
            changed = im.size != image.size or im.tobytes() != image.tobytes()
            lines.append(f"- `{path}`" + (" †" if changed else " (pixels unchanged)"))
        lines.append("")
    REPORT.write_text("\n".join(lines) + "\n")
    print(f"REPORT {REPORT.relative_to(ROOT)}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    action = parser.add_mutually_exclusive_group()
    action.add_argument("--adopt-all", action="store_true")
    action.add_argument("--adopt", nargs="+", metavar="PATH")
    action.add_argument("--check", action="store_true")
    action.add_argument("--write-originals", action="store_true")
    action.add_argument("--record-rests", action="store_true", help="record rests after a successful native rebake")
    parser.add_argument("--force-adopt", action="store_true")
    parser.add_argument("--only", default="", metavar="ID")
    parser.add_argument("--report", action="store_true", help="write the full registry report without processing production")
    args = parser.parse_args()
    registry = load_registry()
    entries = [e for e in registry["entries"] if not args.only or e["id"] == args.only]
    if not entries:
        raise ValueError(f"unknown id: {args.only}")
    if args.force_adopt and not (args.adopt or args.adopt_all):
        raise ValueError("--force-adopt requires --adopt or --adopt-all")
    if args.adopt_all or args.adopt:
        paths = source_paths(registry, entries) if args.adopt_all else args.adopt
        allowed = set(source_paths(registry, registry["entries"]))
        for path in paths:
            repo_path(path)
            if path not in allowed:
                raise ValueError(f"register new board art before --adopt {path}")
        adopt(paths, args.force_adopt)
        return 0
    needed = source_paths(registry, registry["entries"] if args.report else entries)
    missing = [path for path in needed if not (SOURCES / path).is_file()]
    if missing:
        raise ValueError("missing sources; use --adopt <path> (or --adopt-all initially):\n" + "\n".join(missing))
    calibration_failures = calibration_errors(entries)
    if calibration_failures and not args.check:
        raise ValueError("\n".join(calibration_failures))
    if args.write_originals:
        # Restore rest baselines too, after a native rebake, for truthful A/B
        # captures. Default processing + native rebake restores the treated view.
        paths = needed if not args.only else source_paths(registry, entries)
        for path in paths:
            if path == registry["hero_reference"]:
                continue
            shutil.copyfile(SOURCES / path, repo_path(path))
        print(f"WROTE-ORIGINALS {len(paths)-1} file(s)")
        return 0
    if args.report and not args.check:
        report(registry)
        return 0
    manifest = json.loads(MANIFEST.read_text()) if MANIFEST.exists() else {}
    if args.record_rests:
        record_rests(entries, manifest)
        return 0
    expected_paint = {path for entry in registry["entries"] for path in entry["paths"]}
    expected_rests = {path for entry in registry["entries"] for path in rest_paths(entry)}
    if args.check:
        stale = calibration_failures + paint_errors(entries, manifest) + rest_errors(entries, manifest)
        if not args.only:
            stale.extend(f"outputs.json: unregistered {path}" for path in sorted(set(manifest) - expected_paint - expected_rests))
        for path in stale:
            print(path if path.startswith("rest rebake needed:") else f"stale: {path}")
        if not stale:
            print("CHECK-OK")
        if args.report:
            report(registry)
        return 1 if stale else 0
    # Processing must never certify rests. Preserve their last native rebake
    # records so later part edits make --check demand a new rebake.
    outputs = dict(manifest) if args.only else {p: manifest[p] for p in expected_rests if p in manifest}
    for entry in entries:
        for path in entry["paths"]:
            image, record = derive(entry, path)
            repo_path(path).write_bytes(png_bytes(image))
            outputs[path] = record
    MANIFEST.write_text(json.dumps(dict(sorted(outputs.items())), indent=2) + "\n")
    print(f"PROCESSED {sum(len(e['paths']) for e in entries)} file(s)")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (ValueError, OSError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        sys.exit(1)
