#!/usr/bin/env python3
"""Provenance-gated classical-to-retro soundtrack workflow."""

from __future__ import annotations

import argparse
import importlib.util
import json
from pathlib import Path
import shutil
import sys

from classical_soundtrack_pipeline.common import PipelineError


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BANK = REPO_ROOT / "assets" / "audio" / "instruments" / "classical_dark_fantasy_v1"


def _json(value: object) -> None:
    print(json.dumps(value, indent=2, sort_keys=True))


def command_doctor(_: argparse.Namespace) -> int:
    checks = {
        "python": {"version": sys.version.split()[0], "ok": sys.version_info >= (3, 12)},
        "mido": importlib.util.find_spec("mido") is not None,
        "numpy": importlib.util.find_spec("numpy") is not None,
        "music21": importlib.util.find_spec("music21") is not None,
        "ffmpeg": shutil.which("ffmpeg"),
        "ffprobe": shutil.which("ffprobe"),
    }
    checks["ok"] = bool(checks["python"]["ok"] and checks["mido"] and checks["numpy"] and checks["music21"] and checks["ffmpeg"] and checks["ffprobe"])
    _json(checks)
    return 0 if checks["ok"] else 1


def command_generate_bank(args: argparse.Namespace) -> int:
    from classical_soundtrack_pipeline.bank import generate_bank

    destination = Path(args.destination).resolve()
    _json(generate_bank(destination))
    return 0


def command_scaffold(args: argparse.Namespace) -> int:
    from classical_soundtrack_pipeline.scaffold import create_scaffold

    destination = create_scaffold(Path(args.root), args.track_id, args.title, args.composer, Path(args.bank_manifest))
    _json({"ok": True, "track_directory": str(destination), "next": str(destination / "LICENSE_SOURCE.md")})
    return 0


def command_render(args: argparse.Namespace) -> int:
    from classical_soundtrack_pipeline.render import render_track

    _json(render_track(Path(args.config), Path(args.output_dir) if args.output_dir else None))
    return 0


def command_verify(args: argparse.Namespace) -> int:
    from classical_soundtrack_pipeline.verify import verify_track

    _json(verify_track(Path(args.config), Path(args.output_dir) if args.output_dir else None, Path(args.report) if args.report else None))
    return 0


def command_promote(args: argparse.Namespace) -> int:
    from classical_soundtrack_pipeline.promote import promote_track

    _json(promote_track(
        Path(args.config),
        Path(args.output_dir) if args.output_dir else None,
        Path(args.asset_path),
    ))
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    doctor = subparsers.add_parser("doctor", help="Check the pinned Python/audio toolchain")
    doctor.set_defaults(func=command_doctor)
    bank = subparsers.add_parser("generate-bank", help="Generate the shared deterministic sample bank")
    bank.add_argument("--destination", default=str(DEFAULT_BANK))
    bank.set_defaults(func=command_generate_bank)
    scaffold = subparsers.add_parser("scaffold", help="Create a non-overwriting, rights-locked track workspace")
    scaffold.add_argument("--track-id", required=True)
    scaffold.add_argument("--title", required=True)
    scaffold.add_argument("--composer", required=True)
    scaffold.add_argument("--root", default=str(REPO_ROOT / "output" / "classical_soundtracks"))
    scaffold.add_argument("--bank-manifest", default=str(DEFAULT_BANK / "bank_manifest.json"))
    scaffold.set_defaults(func=command_scaffold)
    for name, function, help_text in (
        ("render", command_render, "Render MIDI through the procedural bank"),
        ("verify", command_verify, "Verify rights, inputs, MIDI, and audio"),
    ):
        subparser = subparsers.add_parser(name, help=help_text)
        subparser.add_argument("--config", required=True)
        subparser.add_argument("--output-dir")
        if name == "verify":
            subparser.add_argument("--report")
        subparser.set_defaults(func=function)
    promote = subparsers.add_parser("promote", help="Verify and copy an approved Ogg into game assets")
    promote.add_argument("--config", required=True)
    promote.add_argument("--output-dir")
    promote.add_argument("--asset-path", required=True)
    promote.set_defaults(func=command_promote)
    return parser


def main() -> int:
    arguments = build_parser().parse_args()
    if arguments.command != "doctor" and sys.version_info < (3, 12):
        raise PipelineError(f"Python 3.12 or newer is required; found {sys.version.split()[0]}")
    return int(arguments.func(arguments))


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except PipelineError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
