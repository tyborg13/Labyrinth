"""Certify separate production Section I and real-depth dragon inspection saves."""
from datetime import datetime, timezone
from pathlib import Path
import json
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-04/feedback2')
HOME_ROOT = '/private/tmp/labyrinth-godot-home'


def certify(case, args, scenario):
    run_id = f'rd-04-{case}-v2'
    prefix = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rd-04',
              '--run-id', run_id, '--stream', '--', 'godot', '--headless', '--path', '.']
    generate = prefix + ['--script', 'tools/rd04/fixture_generator.gd', '--',
                         '--scenario', scenario, *args, '--summary', f'rd-04 real-game {case}']
    verify = prefix + ['--script', 'tools/inspection_fixture_verify.gd']
    for name, command in [('generate', generate), ('verify', verify)]:
        result = subprocess.run(command, cwd=ROOT, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True)
        (OUTPUT / f'{case}-{name}.log').write_text(result.stdout)
        print(result.stdout, end='', flush=True)
        if result.returncode:
            raise SystemExit(result.returncode)
        if name == 'verify' and 'INSPECTION_FIXTURE_VERIFIED ' not in result.stdout:
            raise SystemExit('Missing stock inspection-fixture verification result')
    manifest = dict(schema_version=2, project=str(ROOT), task_id='rd-04', run_id=run_id,
                    scenario=scenario, verified=True, generated_at_utc=datetime.now(timezone.utc).isoformat(),
                    generator_command=shlex.join(generate), verifier_command=shlex.join(verify),
                    fixture_args=['--scenario', scenario, *args],
                    verification=dict(godot='godot', godot_home_root=HOME_ROOT,
                                      runner='tools/godot_task_runner.py', script='tools/inspection_fixture_verify.gd'))
    (OUTPUT / f'{case}.json').write_text(json.dumps(manifest, indent=2) + '\n')


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    certify('overlap', [], 'combat')
    cases = json.loads((OUTPUT / 'cases.json').read_text())
    for boss in ['zekarion', 'vyraketh']:
        certify(boss, ['--seed', str(cases['seed']), '--dragon-id', boss,
                       '--dragon-depth', str(cases[boss + '_depth'])], 'dragon')
    print(f'RD04 REAL-GAME FIXTURES: PASS (Section I + two real-depth boss arenas); {OUTPUT}')


if __name__ == '__main__':
    main()
