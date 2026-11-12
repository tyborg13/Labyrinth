"""Certify separate production Section I and real-depth dragon inspection saves."""
from datetime import datetime, timezone
from pathlib import Path
import json
import shlex
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-08')
SNARE_PROOF_SEED = 83
SNARE_PROOF_ARGS = ["--snare-biome", "fire", "--snare-tier", "2", "--snare-case", "first_turn"]
HOME_ROOT = '/private/tmp/labyrinth-godot-home'


def certify(case, args, scenario):
    run_id = f'rd-08-{case}-v2'
    prefix = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rd-08',
              '--run-id', run_id, '--stream', '--', 'godot', '--headless', '--path', '.']
    generate = prefix + ['--script', 'tools/rd08/fixture_generator.gd', '--',
                         '--scenario', scenario, *args, '--summary', f'rd-08 real-game {case}']
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
    manifest = dict(schema_version=2, project=str(ROOT), task_id='rd-08', run_id=run_id,
                    scenario=scenario, verified=True, generated_at_utc=datetime.now(timezone.utc).isoformat(),
                    generator_command=shlex.join(generate), verifier_command=shlex.join(verify),
                    fixture_args=['--scenario', scenario, *args],
                    verification=dict(godot='godot', godot_home_root=HOME_ROOT,
                                      runner='tools/godot_task_runner.py', script='tools/inspection_fixture_verify.gd'))
    (OUTPUT / f'{case}.json').write_text(json.dumps(manifest, indent=2) + '\n')


def prepare_snare():
    output = OUTPUT / 'feedback2'
    output.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, 'tools/inspection_fixture.py', '--task-id', 'rd-08',
               '--run-id', 'rd-08-sealbinder', '--manifest', str(output / 'snare.json'),
               '--scenario', 'snare', '--seed', str(SNARE_PROOF_SEED), *SNARE_PROOF_ARGS,
               '--summary', 'rd-08 Sealbinder countdown tooltip proof']
    subprocess.run(command, cwd=ROOT, check=True)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    certify('overlap', [], 'combat')
    cases = json.loads((OUTPUT / 'cases.json').read_text())
    for boss in ['zekarion', 'vyraketh']:
        certify(boss, ['--seed', str(cases['seed']), '--dragon-id', boss,
                       '--dragon-depth', str(cases[boss + '_depth'])], 'dragon')
    prepare_snare()
    print(f'RD08 REAL-GAME FIXTURES: PASS (Section I + two real-depth boss arenas + Snare); {OUTPUT}')


if __name__ == '__main__':
    main()
