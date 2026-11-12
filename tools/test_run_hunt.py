"""Focused hunt CLI/evidence regressions. Writes only TemporaryDirectory fixtures."""
import argparse
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('run_hunt', Path(__file__).with_name('run_hunt.py'))
hunt = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(hunt)


def options(**changes):
    values = dict(seed_timeout=4500.0, script='tools/run_hunt.gd', no_embrace=True,
                  stop_after=0, demo=False, health=9999, seed=21, processes=2, minutes=20)
    values.update(changes)
    return argparse.Namespace(**values)


class HuntTests(unittest.TestCase):
    def test_default_command_remains_exact(self):
        expected = [hunt.sys.executable, 'tools/godot_task_runner.py', '--task-id', 'qa-18',
                    '--timeout', '4500.0', '--stream', '--', 'godot', '--headless', '--path', '.',
                    '--script', 'tools/run_hunt.gd', '--', '--seed', '21', '--output-dir', '/tmp/hunt',
                    '--no-embrace', 'true']
        self.assertEqual(hunt.command_for(21, Path('/tmp/hunt'), options()), expected)

    def test_demo_health_and_replay(self):
        args = options(demo=True, health=0)
        command = hunt.command_for(21, Path('/tmp/hunt'), args)
        self.assertEqual(command[command.index('--task-id') + 1], 'qa-85')
        self.assertEqual(command[-4:], ['--demo', 'true', '--health', '0'])
        replay = hunt.replay_command({'context': {'seed': 21, 'decision': 9}}, args)
        self.assertIn('--demo', replay)
        self.assertIn('--health 0', replay)
        self.assertIn('--stop-after 10', replay)

    def test_hearth_defeat_and_profile_arguments_survive_replay(self):
        args = options(demo=True, defeat_after_hearth=True, profile_runs=3)
        command = hunt.command_for(31, Path('/tmp/hunt'), args)
        self.assertEqual(command[-4:], ['--profile-runs', '3', '--defeat-after-hearth', 'true'])
        replay = hunt.replay_command({'context': {'seed': 31, 'decision': 40}}, args)
        self.assertIn('--defeat-after-hearth', replay)
        self.assertIn('--profile-runs 3', replay)

    def test_demo_environment_is_recorded_and_passed(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp)
            with patch.object(hunt.subprocess, 'run') as run, patch.object(hunt, 'read_evidence', return_value={'findings': []}):
                run.return_value.returncode = 0
                hunt.run_seed(21, output, options(demo=True, health=0))
            self.assertEqual(run.call_args.kwargs['env']['LABYRINTH_DEMO'], '1')
            recorded = json.loads((output / 'seed-000021/command.json').read_text())
            self.assertEqual(recorded['env']['LABYRINTH_DEMO'], '1')

    def test_report_and_findings_keep_demo_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            directory = Path(tmp)
            command = hunt.command_for(21, directory, options(demo=True))
            (directory / 'command.json').write_text(json.dumps({'argv': command}))
            context = {'seed': 21, 'section': 0, 'room_kind': 'boss', 'decision': 20}
            row = dict(outcome='victory', section=0, rooms=10, hearth=True, shown='full',
                       expected='full', resumes=[{'stage': 'end_panel', 'preserved': False}], restart_section=0)
            events = [('room', context), ('finding', {'severity': 'script error', 'error': 'Demo resume lost state at end_panel', 'location': 'test:1', 'context': context}),
                      ('finish', {'context': context, 'outcome': 'victory', 'demo_runs': [row]})]
            (directory / 'godot.log').write_text(''.join(hunt.EVENT_PREFIX + json.dumps({'event': event, 'data': data}) + '\n' for event, data in events))
            evidence = hunt.read_evidence(21, directory, 0)
            report, groups = hunt.render_report([evidence], options(demo=True, health=0), 1, 1)
            self.assertEqual(len(groups), 1)
            self.assertIn('demo mode', report)
            self.assertIn('starting Health normal', report)
            self.assertIn('full / full', report)
            self.assertIn('end_panel', report)
            self.assertIn('--demo', report)

    def test_non_demo_report_is_unchanged(self):
        # Compare against the pre-change implementation with identical inputs.
        import subprocess
        original = subprocess.check_output(['git', 'show', 'HEAD:tools/run_hunt.py'], text=True)
        namespace = {'__file__': str(Path(hunt.__file__)), '__name__': 'baseline'}
        exec(compile(original, 'baseline', 'exec'), namespace)
        run = {'seed': 21, 'rooms': [], 'finish': {'outcome': 'victory'}, 'findings': []}
        self.assertEqual(hunt.render_report([run], options(), 2, 1), namespace['render_report']([run], options(), 2, 1))


if __name__ == '__main__':
    unittest.main()
