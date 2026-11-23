#!/usr/bin/env python3
"""Check the MRG-17 export filters and approved asset inventories."""

import argparse
from collections import defaultdict
import fnmatch
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from mrg15.pck_check import filters

BASE = "86d9f6ad1"
CANDIDATE = ("9c3652e1a", "a753ba8a5", "2b2656f17", "253d5122f")
PLAYTEST = "844bd3936"
PIN_PATH = "tests/approved_asset_pins.json"
DENSITY_PATH = "spec/assets/board_pixel_density/registry.json"
RESOURCE_PATH = re.compile(r'res://((?:assets|data|scripts|scenes)/[\w./-]+\.[\w]+)')


def git(*args):
    return subprocess.check_output(["git", *args], cwd=GIT_ROOT)


GIT_ROOT = Path(subprocess.check_output(
    ["git", "rev-parse", "--show-toplevel"], cwd=ROOT, text=True).strip())


def paths(ref):
    return set(git("ls-tree", "-r", "--name-only", ref).decode().splitlines())


def source(ref, path):
    return git("show", f"{ref}:{path}").decode()


def check_exports(tips):
    presets = filters((ROOT / "export_presets.cfg").read_text())
    sources = [filters(source(ref, "export_presets.cfg")) for ref in (BASE, *tips)]
    assert len(presets) == 6 and all(presets.keys() == config.keys() for config in sources)
    required = set()
    for tip in tips:
        base = git("merge-base", BASE, tip).decode().strip()
        scopes = ("assets", "data", "scripts", "scenes", "project.godot")
        required.update(git("diff", "--name-only", "--diff-filter=A", base, tip, "--", *scopes)
                        .decode().splitlines())
        for line in git("diff", "-U0", base, tip, "--", *scopes).decode().splitlines():
            if line.startswith("+") and not line.startswith("+++"):
                required.update(RESOURCE_PATH.findall(line))
    # Resource UIDs are editor metadata. Production filters name the resources.
    required = {path for path in required if not path.endswith(".uid")}
    for name, patterns in presets.items():
        missing_patterns = set.union(*(config[name] for config in sources)) - patterns
        missing_resources = {path for path in required if not any(fnmatch.fnmatchcase(path, pattern)
                                                                  for pattern in patterns)}
        assert not (missing_patterns or missing_resources), (name, missing_patterns, missing_resources)
        print(f"MRG-17 EXPORT FILTER {name}: PASS ({len(patterns)} patterns)")
    print("MRG-17 EXPLICIT RUNTIME RESOURCES: " + ", ".join(sorted(required)))


def check_assets(tips):
    pins = json.loads((ROOT / PIN_PATH).read_text())["files"]
    expected = defaultdict(set)
    provenance = set()
    density = json.loads((ROOT / DENSITY_PATH).read_text())
    for ref in (BASE, *tips):
        for path, digest in json.loads(source(ref, PIN_PATH))["files"].items():
            expected[path].add(digest)
        for path in paths(ref):
            if path.endswith("PROVENANCE.md"):
                approved = {line for line in source(ref, path).splitlines() if line}
                merged = set((ROOT / path).read_text().splitlines())
                assert approved <= merged, (ref, path, approved - merged)
                provenance.add(path)
        for key, value in json.loads(source(ref, DENSITY_PATH)).items():
            merged = density[key]
            assert value.items() <= merged.items() if isinstance(value, dict) else value == merged, (ref, key)
    assert pins.keys() == expected.keys(), (expected.keys() - pins.keys(), pins.keys() - expected.keys())
    clashes = 0
    for path, versions in expected.items():
        digest = pins[path]
        assert digest in versions, (path, digest, versions)
        if len(versions) > 1:
            data = (ROOT / path).read_bytes()
            actual = hashlib.sha1(f"blob {len(data)}\0".encode() + data).hexdigest()
            assert digest == actual, (path, digest, actual)
            print(f"PIN {path}: {digest} matches the merged file")
            clashes += 1
    print(f"MRG-17 PIN UNION: PASS ({len(pins)} pins, {clashes} hash clashes)")
    print(f"MRG-17 PROVENANCE AND DENSITY: PASS ({len(provenance)} provenance files and 1 registry)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("edition", choices=("a", "b"))
    args = parser.parse_args()
    tips = (*CANDIDATE, PLAYTEST) if args.edition == "b" else CANDIDATE
    check_exports(tips)
    check_assets(tips)


if __name__ == "__main__":
    main()
