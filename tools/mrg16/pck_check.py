#!/usr/bin/env python3
"""Check the approved six-tip export union and optionally mount its pack."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[2]
BASE = "76aac505b"
TIPS = ("35421baad", "3d1440d3b", "3ec14fd87", "35b683909", "b966ccdeb", "a3f0e70d9")
sys.path.insert(0, str(ROOT / "tools"))
from mrg15.pck_check import PROBE, filters, inventory


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT, text=True)


def approved_data_paths():
    paths = set()
    for tip in TIPS:
        base = git("merge-base", BASE, tip).strip()
        paths.update(git("diff", "--name-only", "--diff-filter=AM", base, tip, "--", "data/*.json").splitlines())
        added_source = git("diff", "--unified=0", base, tip, "--", "scripts", "scenes", "project.godot")
        paths.update(re.findall(r"res://(data/[\w./-]+\.json)", "\n".join(
            line for line in added_source.splitlines() if line.startswith("+") and not line.startswith("+++")
        )))
    return paths


def check_filters(required):
    source_filters = [filters(git("show", f"{ref}:export_presets.cfg")) for ref in (BASE, *TIPS)]
    actual = filters((ROOT / "export_presets.cfg").read_text())
    if len(actual) != 6 or any(actual.keys() != source.keys() for source in source_filters):
        raise ValueError("Expected the same six presets in candidate 4, all pins and candidate 5")
    for preset, patterns in actual.items():
        expected = required.union(*(filters[preset] for filters in source_filters))
        if missing := expected - patterns:
            raise ValueError(f"{preset} omits {', '.join(sorted(missing))}")
        print(f"MRG-16 EXPORT FILTER {preset}: PASS ({len(patterns)} patterns)", flush=True)
    print("MRG-16 EXPORT FILTERS: PASS (6/6 presets)", flush=True)


def check_pack(pack, paths):
    expected = inventory()
    for name in paths:
        expected.setdefault("res://" + name, {
            "sha256": hashlib.sha256((ROOT / name).read_bytes()).hexdigest(), "sizes": [],
        })
    with tempfile.TemporaryDirectory(prefix="mrg16-pck-", dir=ROOT / ".godot") as directory:
        project = Path(directory)
        (project / "project.godot").write_text("config_version=5\n")
        probe = project / "probe.gd"
        probe.write_text(PROBE.replace("MRG-14", "MRG-16"))
        manifest = project / "expected.json"
        manifest.write_text(json.dumps(expected))
        return subprocess.run([
            sys.executable, str(ROOT / "tools/godot_task_runner.py"),
            "--task-id", "mrg-16", "--stream", "--project", str(project), "--", "godot",
            "--headless", "--path", str(project), "--script", str(probe), "--",
            str(pack.resolve()), str(manifest),
        ], cwd=ROOT, check=False).returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", nargs="?", type=Path)
    args = parser.parse_args()
    if args.pack and not args.pack.is_file():
        parser.error(f"Pack does not exist: {args.pack}")
    paths = approved_data_paths()
    check_filters(paths)
    return check_pack(args.pack, paths) if args.pack else 0


if __name__ == "__main__":
    raise SystemExit(main())
