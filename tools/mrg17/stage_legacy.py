"""Restore retired dependencies inside the four historical proof stages."""

import argparse
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from mrg16 import stage_legacy

DEPENDENCIES = ("scripts/enemy_mechanics/kindle_view.gd", "scripts/combat_hud_forecast.gd",
                "scripts/combat_pacing.gd")


def redirect(directory, revision):
    location = "res://" + directory.relative_to(ROOT).as_posix()
    for dependency in DEPENDENCIES:
        name = Path(dependency).name
        original = f'"res://{dependency}"'
        target = f'"{location}/{name}"'
        for script in directory.glob("*.gd"):
            text = script.read_text()
            if original not in text:
                continue
            source = stage_legacy.stage_proof.source(revision, dependency).decode()
            (directory / name).write_text(re.sub(r"(?m)^class_name \w+\n", "", source))
            script.write_text(text.replace(original, target))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proof", choices=stage_legacy.BASELINES)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    subprocess.run([sys.executable, ROOT / "tools/mrg15/stage_proof.py", args.proof, args.directory], check=True)
    subprocess.run([sys.executable, ROOT / "tools/mrg16/stage_legacy.py", args.proof, args.directory], check=True)
    before = args.directory / "before" if args.proof == "fx23" else args.directory
    redirect(before.resolve(), stage_legacy.BASELINES[args.proof])


if __name__ == "__main__":
    main()
