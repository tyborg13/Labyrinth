"""Check owner proof ordering and creature isolation with inert command stubs."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from types import ModuleType
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
SCRIPT = PROJECT / 'experiments/cutouts/shale_bloomer/rr05/proof_for_design_owner.sh'
COMMAND_STUB_TIMEOUT_SECONDS = 10


class OwnerProofTests(unittest.TestCase):
    def test_adoption_heredoc_reads_layouts_and_calls_density(self):
        # Execute the real heredoc, rather than replacing python3 wholesale.
        # read_json deliberately retains its Path-only public contract.
        sys.path.insert(0, str(PROJECT / 'tools'))
        from cutout_pipeline.cases import read_json
        block = SCRIPT.read_text().split("<<'PY'\n", 1)[1].split('\nPY\n', 1)[0]
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            base = root / 'assets/units/lightning_wisp_cutout'
            base.mkdir(parents=True)
            for view in ('front', 'rear'):
                (base / (view + '.json')).write_text(json.dumps({'parts': [{'file': view + '/eye.png'}]}))
            registry_path = root / 'registry.json'
            (base / 'features.json').write_text(json.dumps({'features': [{'name': 'eye', 'views': {
                'front': {'mask': 'features/front_eye.png'}, 'rear': {'mask': 'features/empty.png'}}}]}))
            registry = {'entries': [{'dir': 'assets/units/lightning_wisp_cutout', 'paths': ['existing.png']}], 'excluded_paths': {}}
            density = ModuleType('process_board_density')
            density.REGISTRY = registry_path
            density.load_registry = lambda: registry
            calls = []
            density.main = lambda: calls.append(sys.argv.copy()) or 0
            previous = Path.cwd()
            try:
                os.chdir(root)
                with patch.dict(sys.modules, process_board_density=density), patch.object(sys, 'argv', ['-', 'lightning_wisp']):
                    with self.assertRaises(SystemExit) as stopped:
                        exec(compile(block, str(SCRIPT) + ':adoption', 'exec'), {})
                self.assertEqual(stopped.exception.code, 0)
            finally:
                os.chdir(previous)
            expected = ['assets/units/lightning_wisp_cutout/front/eye.png',
                        'assets/units/lightning_wisp_cutout/rear/eye.png']
            self.assertEqual(calls, [['process_board_density.py', '--force-adopt', '--adopt', *expected]])
            self.assertEqual(read_json(registry_path)['entries'][0]['paths'], [*expected, 'existing.png'])
            exclusions = read_json(registry_path)['excluded_paths']
            self.assertEqual(set(exclusions), {'assets/units/lightning_wisp_cutout/features/front_eye.png',
                                               'assets/units/lightning_wisp_cutout/features/empty.png'})
            self.assertTrue(all(v['category'] == 'never_drawn' and v['reason'] for v in exclusions.values()))
            self.assertFalse(any('features/' in path for path in calls[0]))

    def commands(self, *arguments):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stub = root / 'python3'
            stub.write_text(f'#!{sys.executable}\n' + '''import json, os, sys
with open(os.environ['RR05_STUB_LOG'], 'a') as stream:
    stream.write(json.dumps(sys.argv[1:]) + '\\n')
if sys.argv[1:2] == ['-']:
    sys.stdin.read()
''')
            stub.chmod(0o755)
            log = root / 'commands.jsonl'
            environment = dict(os.environ, PATH=str(root) + os.pathsep + os.environ['PATH'], RR05_STUB_LOG=str(log))
            result = subprocess.run(['bash', str(SCRIPT), *arguments], cwd=PROJECT,
                                    env=environment, text=True, capture_output=True, timeout=COMMAND_STUB_TIMEOUT_SECONDS)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_default_stage_order(self):
        result, calls = self.commands()
        self.assertEqual(result.returncode, 0, result.stderr)
        derive = [i for i, c in enumerate(calls) if c[:2] == ['tools/maquette_cutout_polish.py', 'derive']]
        review = [i for i, c in enumerate(calls) if c[0] == 'tools/maquette_cutout_review.py']
        promote = [i for i, c in enumerate(calls) if c[:2] == ['tools/maquette_cutout_build.py', 'promote']]
        adopt = [i for i, c in enumerate(calls) if c[0] == '-']
        rebake = [i for i, c in enumerate(calls) if 'tools/rebake_cutout_rests.gd' in c]
        self.assertEqual([len(derive), len(review), len(promote), len(adopt), len(rebake)], [2, 2, 2, 1, 2])
        self.assertLess(max(derive), min(review))
        self.assertLess(max(review), min(promote))
        self.assertLess(max(promote), adopt[0])
        self.assertLess(adopt[0], min(rebake))
        self.assertEqual(calls[adopt[0]], ['-', 'shale_bloomer', 'lightning_wisp'])
        self.assertFalse(any('inspection_fixture.py' in arg for c in calls for arg in c))

    def test_resume_wisp_only_in_either_argument_order(self):
        for arguments in (('--from-native', '--creature', 'lightning_wisp'),
                          ('--creature', 'lightning_wisp', '--from-native')):
            result, calls = self.commands(*arguments)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(any('derive' in c for c in calls))
            self.assertFalse(any('shale' in arg or 'bile_bloomer' in arg for c in calls for arg in c))
            reviews = [c for c in calls if c[0] == 'tools/maquette_cutout_review.py']
            self.assertEqual(len(reviews), 1)
            self.assertIn('output/rr-05/lightning_wisp_review.mp4', reviews[0])
            self.assertIn(['-', 'lightning_wisp'], calls)
            self.assertEqual(sum('tools/rebake_cutout_rests.gd' in c for c in calls), 1)
            self.assertEqual(sum('tests/maquette_cutout/production_capture.gd' in c for c in calls), 1)
            self.assertFalse(any('inspection_fixture.py' in arg for c in calls for arg in c))

    def test_invalid_filter_stops_before_tools(self):
        for arguments in (('--creature',), ('--creature', 'shrike'), ('--unknown',)):
            result, calls = self.commands(*arguments)
            self.assertEqual(result.returncode, 2)
            self.assertEqual(calls, [])

    def test_resume_adoption_only(self):
        for creature in ('lightning_wisp', 'shale_bloomer'):
            result, calls = self.commands('--from-adopt', '--creature', creature)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(any('derive' in c or 'promote' in c or c[0] == 'tools/maquette_cutout_review.py' for c in calls))
            self.assertFalse(any('pixel_samples.gd' in arg for c in calls for arg in c))
            self.assertIn(['-', creature], calls)
            other = 'shale' if creature == 'lightning_wisp' else 'wisp'
            self.assertFalse(any(other in arg for c in calls for arg in c))
            self.assertEqual(sum('tools/rebake_cutout_rests.gd' in c for c in calls), 1)


if __name__ == '__main__':
    unittest.main()
