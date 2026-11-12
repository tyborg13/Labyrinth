"""Run the requested focused headless proofs; preserve every upstream assertion.

Proof copies change only output destinations. Input fixtures and checks stay
identical, and the original scripts remain untouched. No full suite is run.
"""
from pathlib import Path
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-08')
ADAPTERS = ROOT / 'tools/rd08/unit_proofs'


def adapter(source, changes):
    text = (ROOT / source).read_text()
    for old, new in changes:
        assert old in text, (source, old)
        text = text.replace(old, new)
    destination = ADAPTERS / Path(source).name
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_text(text)
    return destination.relative_to(ROOT).as_posix()


def main():
    # Every proof writes exclusively below rd-08, retaining original certified inputs.
    jobs = []
    jobs.append(('rd02', adapter('tools/rd02/silhouette_proof.gd', [
        ('const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-02"',
         'const OUTPUT: String = "/private/tmp/labyrinth_codex/rd-08/rd02"')]), []))
    jobs.append(('rd03', 'tools/rd03/aim_focus_proof.gd', []))
    for case in ['overlap', 'zekarion', 'vyraketh']:
        jobs.append(('rd04-' + case, 'tools/rd04/threat_isolation_proof.gd', [
            '--case', case, '--fixture-manifest', f'/private/tmp/labyrinth_codex/rd-04/feedback2/{case}.json',
            '--output-dir', str(OUTPUT / ('rd04-' + case))]))
    stale = adapter('tools/rd06/stale_occlusion_check.gd', [
        ('const OUTPUT := "/private/tmp/labyrinth_codex/rd-06"',
         'const OUTPUT := "/private/tmp/labyrinth_codex/rd-08/rd06"'),
        ('Fixture.install_save(OUTPUT.path_join("combat.json"))',
         'Fixture.install_save("/private/tmp/labyrinth_codex/rd-06/combat.json")'),
        ('FileAccess.get_file_as_string(OUTPUT.path_join("briefing.json"))',
         'FileAccess.get_file_as_string("/private/tmp/labyrinth_codex/rd-06/briefing.json")')])
    for phase in ['resume', 'fresh', 'briefing']:
        jobs.append(('rd06-' + phase, stale, ['--phase', phase]))
    jobs.append(('rd07', adapter('tools/rd07/board_ui_proof.gd', [
        ('/private/tmp/labyrinth_codex/rd-07/proof.json', '/private/tmp/labyrinth_codex/rd-08/rd07.json')]), []))
    jobs.append(('rd05-adapter', adapter('tools/rd07/rd05_regression.gd', [
        ('/private/tmp/labyrinth_codex/rd-07/rd05-regression.json', '/private/tmp/labyrinth_codex/rd-08/rd05-regression.json')]), []))
    jobs += [('focused', 'tools/rd08/focused_checks.gd', []),
             ('rail', 'tools/rd04/focused_checks.gd', ['--rail-only']),
             ('tooltips', 'tools/rd07/tooltip_checks.gd', []),
             ('board-tooltips', 'tests/board_tile_tooltip_test.gd', []),
             ('settings', 'tools/rd05/settings_checks.gd', [])]
    for folder in ['rd02', 'rd06']:
        (OUTPUT / folder).mkdir(exist_ok=True)
    results = []
    for name, script, args in jobs:
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rd-08', '--stream',
                   '--', 'godot', '--headless', '--path', '.', '--script', script]
        if args:
            command += ['--', *args]
        with (OUTPUT / (name + '.log')).open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        results.append({'name': name, 'exit_code': result.returncode, 'command': command})
        print(f'RD08 CHECK {name}: exit {result.returncode}; {OUTPUT / (name + ".log")}', flush=True)
        (OUTPUT / 'headless-results.json').write_text(json.dumps(results, indent=2) + '\n')
    return int(any(row['exit_code'] for row in results))


if __name__ == '__main__':
    raise SystemExit(main())
