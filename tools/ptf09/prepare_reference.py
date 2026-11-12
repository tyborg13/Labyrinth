"""Read-only release-script and legacy-capture timing evidence for ptf-09."""
from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-09/feedback2')
RELEASE = 'c9121c833'
LEGACY_FRAMES = range(46, 56)
FRAME_DIR = Path('/private/tmp/labyrinth_codex/ptf-09/captures')


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in ('run_scene.gd', 'combat_board_view.gd'):
        source = subprocess.check_output(['git', 'show', f'{RELEASE}:scripts/{name}'], cwd=ROOT, text=True)
        (OUTPUT / ('release_' + name)).write_text(source.replace('class_name CombatBoardView', ''))
    frames = [FRAME_DIR / f'sweep_{frame:03d}.png' for frame in LEGACY_FRAMES]
    times = [p.stat().st_mtime_ns / 1000 for p in frames]
    data = {'release': RELEASE, 'source_images': [str(p) for p in frames],
            'saved_wall_usec': times, 'intended_fps': 30,
            'delta_usec': [round(b-a) for a, b in zip(times, times[1:])]}
    (OUTPUT / 'legacy_sampling.json').write_text(json.dumps(data, indent=2) + '\n')
    print('PTF09 LEGACY SAMPLING: ' + json.dumps(data['delta_usec']))
    print('PTF09 RELEASE REFERENCE: ' + RELEASE + '; production RunScene/CombatBoard scripts; no ptf-09 overlay')


if __name__ == '__main__':
    main()
