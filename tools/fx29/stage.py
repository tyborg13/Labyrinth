"""Load the pinned beam, shot renderer and adapter alongside the current build."""
import argparse
from pathlib import Path
import subprocess

BASE = "5adb3d0d1"
ROOT = Path(__file__).resolve().parents[2]
SOURCES = (
    "scripts/combat_board_view.gd",
    "scripts/shot_fx.gd",
    "scripts/enemy_mechanics/reflect_view.gd",
    "assets/units/glacial_mirror_cutout/actions.gd",
)


def stage(directory: Path) -> None:
    resource_dir = "res://" + directory.relative_to(ROOT).as_posix()
    redirects = {f"res://{path}": f"{resource_dir}/{Path(path).name}" for path in SOURCES}
    for path in SOURCES:
        source = subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT, text=True)
        source = source.replace("class_name CombatBoardView\n", "")
        for original, staged in redirects.items():
            source = source.replace(original, staged)
        (directory / Path(path).name).write_text(source)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    stage(parser.parse_args().directory.resolve())
