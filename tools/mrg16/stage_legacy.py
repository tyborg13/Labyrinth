#!/usr/bin/env python3
"""Supply the retired FX dependencies to the pinned candidate 4 comparators."""

import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "mrg15"))
import stage_proof

BASELINES = {
    "gfix34": "90d5574ff",
    "fx20": "f21b6ff47",
    "fx23": "8f38fb277",
    "fx29": "5adb3d0d1",
}
RETIRED_BOARD_DEPS = (
    "scripts/bile_bloomer_cutout/bloom_fx.gd",
    "scripts/enemy_mechanics/death_burst_view.gd",
    "scripts/cinder_ooze_cutout/action_fx.gd",
    "scripts/vaeloryx_cutout/wind_feedback.gd",
    "scripts/board_surface_presentation.gd",
    "scripts/chain_attack_fx.gd",
    "scripts/enemy_mechanics/burst_fx.gd",
    "scripts/dragon_shadow_fx.gd",
    "scripts/veilbound_acolyte_cutout/fx.gd",
    "scripts/chain_attack_feedback.gd",
)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proof", choices=BASELINES)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    directory = args.directory.resolve()
    target = directory / "before" if args.proof == "fx23" else directory
    source = "res://" + target.relative_to(stage_proof.ROOT).as_posix()

    if args.proof == "fx23":
        sys.path.insert(0, str(stage_proof.ROOT / "tools/fx23"))
        from stage import observe, stage

        board = target / "combat_board_view.gd"
        board.write_text(observe(board.read_text()))
        # All three observed painter functions are gone from candidate 5.
        stage(directory / "after", base=False, instrument=False)

    for relative in RETIRED_BOARD_DEPS:
        path = Path(relative)
        original = f'"res://{relative}"'
        local = f'"{source}/{path.name}"'
        for script in target.glob("*.gd"):
            text = script.read_text()
            if original not in text:
                continue
            (target / path.name).write_bytes(stage_proof.source(BASELINES[args.proof], relative))
            script.write_text(text.replace(original, local))


if __name__ == "__main__":
    main()
