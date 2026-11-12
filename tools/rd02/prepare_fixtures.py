"""Certified real combat saves; all coordinates and seed are proof-only defaults."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-02')
FIXTURE_SEED = 7262026
CASES = {
    'standard': ['--scenario', 'combat', '--room-coord', '1,0', '--player-position', '2:4',
                 '--enemy-types', 'crawler,harrier,warden,cinder_ooze', '--enemy-positions', '1:2,5:2,6:4,2:6'],
    'zekarion_arena': ['--scenario', 'dragon', '--dragon-id', 'zekarion', '--dragon-depth', '4', '--dragon-case', 'encounter', '--player-position', '3:3'],
    'vyraketh_arena': ['--scenario', 'dragon', '--dragon-id', 'vyraketh', '--dragon-depth', '4', '--dragon-case', 'encounter', '--player-position', '3:3'],
    'walk': ['--scenario', 'dragon', '--dragon-id', 'zekarion', '--dragon-depth', '4',
             '--dragon-case', 'encounter', '--player-position', '3:4'],
    'eight': ['--scenario', 'combat', '--room-coord', '1,0', '--player-position', '2:4',
              '--enemy-types', 'zekarion,lightning_wisp,crawler,crawler,crawler,crawler,crawler',
              '--enemy-positions', '3:5,4:4,6:1,7:1,7:2,6:7,7:4', '--terrain', 'wooden_crate@1:7',
              '--item-drops', 'crimson_draught@2:7,nail_bomb@7:7'],
    'zekarion': ['--scenario', 'combat', '--room-coord', '1,0', '--player-position', '2:4',
                 '--enemy-types', 'zekarion,lightning_wisp', '--enemy-positions', '3:5,4:4',
                 '--terrain', 'wooden_crate@3:4'],
    'hero': ['--scenario', 'combat', '--room-coord', '1,0', '--player-position', '3:3',
             '--enemy-types', 'warden', '--enemy-positions', '3:4'],
    'vyraketh': ['--scenario', 'combat', '--room-coord', '1,0', '--player-position', '2:4',
                 '--enemy-types', 'vyraketh', '--enemy-positions', '3:4',
                 '--trap-elements', 'fire', '--trap-positions', '3:3'],
    'warband': ['--scenario', 'warband', '--warband-biome', 'air', '--warband-tier', '2',
                '--warband-case', 'encounter'],
    'six': ['--scenario', 'combat', '--room-coord', '1,0', '--player-position', '2:4',
            '--enemy-types', 'zekarion,lightning_wisp,lightning_wisp,lightning_wisp',
            '--enemy-positions', '3:5,3:3,2:3,4:4', '--terrain', 'wooden_crate@3:4',
            '--item-drops', 'crimson_draught@1:3,nail_bomb@4:5',
            '--equipment-drop', 'training_sword', '--equipment-drop-position', '4:6'],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=CASES, action='append')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in args.case or CASES:
        command = [sys.executable, 'tools/inspection_fixture.py', '--task-id', 'rd-02',
                   '--run-id', 'rd-02-' + name, '--manifest', str(OUTPUT / (name + '.json')),
                   '--seed', str(FIXTURE_SEED), '--umbra-stage', 'clear',
                   '--summary', 'rd-02 ' + name + ' silhouette proof', *CASES[name]]
        print(' '.join(command), flush=True)
        if not args.dry_run:
            code = subprocess.run(command, cwd=ROOT).returncode
            if code:
                return code
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
