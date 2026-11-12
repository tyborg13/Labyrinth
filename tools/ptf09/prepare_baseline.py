"""Materialize the brief's unedited release base solely for paired ptf-09 profiling."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE_REF = '7cf181c7e'
OUTPUT = Path('/private/tmp/labyrinth_codex/ptf-09/baseline')


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for name in ('run_scene.gd', 'combat_board_view.gd'):
        source = subprocess.check_output(
            ['git', 'show', f'{BASE_REF}:scripts/{name}'], cwd=ROOT, text=True)
        # Absolute-path loading must not register another CombatBoardView class.
        source = source.replace('class_name CombatBoardView', '')
        (OUTPUT / name).write_text(source)
    base_profile = (ROOT / 'tests/perf/profiled_run_scene.gd').read_text()
    base_profile = base_profile.replace('res://scripts/run_scene.gd', str(OUTPUT / 'run_scene.gd'))
    (OUTPUT / 'runtime_profile.gd').write_text(base_profile)
    profile = (ROOT / 'tools/ptf09/profiled_scene.gd').read_text()
    profile = profile.replace('res://tests/perf/profiled_run_scene.gd', str(OUTPUT / 'runtime_profile.gd'))
    (OUTPUT / 'profiled_scene.gd').write_text(profile)
    (OUTPUT / 'head.txt').write_text(subprocess.check_output(
        ['git', 'rev-parse', BASE_REF], cwd=ROOT, text=True))
    print(f'PTF09 BASELINE: {OUTPUT}')


if __name__ == '__main__':
    main()
