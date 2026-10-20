"""Non-vacuous proof inventories and failing-gate evidence collection."""
import copy
import io
import json
from pathlib import Path
import subprocess
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
import capture_director as director
import capture_inventory as inventory
import capture_review
from capture_gate_runner import prepare_case
from humanoid_cutout.capture_equivalence import compare


def write_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value))


class DirectorTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='cap01-director-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.project = self.root / 'project'
        self.proof = self.root / 'proof'
        self.data = {'creature': 'test', 'view_tracks': {'front': {}, 'rear': {}},
                     'clips': {'idle': {'seconds': .1}, 'death': {'seconds': .1}}}
        self.layout = {'idle_groups': {'body': []}, 'parts': [{'name': 'body'}],
                       'proof_rest_holes': [{'name': 'hole'}], 'proof_joint_seams': [{'name': 'seam'}],
                       'features': [{'name': 'feature'}]}
        for name, (creature, number) in inventory.CASES.items():
            case = self.project / 'experiments/cutouts' / creature / number
            data = dict(self.data, creature=creature)
            write_json(case / 'compiled_motion.json', data)
            write_json(case / 'director_motion.json', {creature: {'clips': data['clips']}})
            for view in data['view_tracks']:
                write_json(case / f'layouts/{view}.json', self.layout)
            for relative in (['proof/production_logic.json'] if number == 'rr10' else
                             ['proof/production_logic/logic_frames.json', 'proof/production_logic_rear/logic_frames.json']):
                write_json(case / relative, {'stage_counts': {'idle': 6, 'death': 6}})
            layouts = {view: self.layout for view in data['view_tracks']}
            for kind in ('native', 'idle_native'):
                files, fields = inventory.native_inventory(data, layouts, kind == 'idle_native')
                manifest = self.manifest()
                manifest.update({field: [{'file': p} for p in sorted(paths)] for field, paths in fields.items()})
                self.capture(name + '/' + kind, manifest, files)
            for view in (('front', 'rear') if name == 'mortar' else ('front',)):
                frames = [{'stage': clip, 'file': f'frame_{i:05d}_{clip}.png', 'pixels_sha256': 'texture',
                           'snapshot': {'clip': clip, 'phase': (i % 6) / 5, 'facing': view}}
                          for i, clip in enumerate(['idle'] * 6 + ['death'] * 6)]
                files = {r['file'] for r in frames}
                if name == 'mortar': files.add('prebattle_panel.png')
                self.capture(name + '/production/' + view, dict(self.manifest(), frames=frames), files)
            if name == 'mortar':
                files = {f'{view}_move_{i:02d}.png' for view in data['view_tracks'] for i in range(12)}
                self.capture(name + '/gait_move_native', dict(self.manifest(), frames=[{'file': p} for p in sorted(files)]), files)
            for mode, count in (('idle', 30), ('review', 84)):
                write_json(self.proof / name / (mode + '.json'), {'frames': count})
                (self.proof / name / (mode + '.mp4')).touch()
            sheets = self.proof / name / 'contact_sheets'
            write_json(sheets / 'manifest.json', {'frames': 4})
            for view in data['view_tracks']:
                for clip in data['clips']: (sheets / f'{view}_{clip}_3x.png').touch()
        (self.proof / 'mortar/gait_move_sheet.png').touch()
        write_json(self.proof / 'mortar/gait_move_sheet.json', {'frames': list(range(24))})
        for relative in inventory.report_sets():
            write_json(self.proof / relative, [] if relative.endswith('source_space_pockets.json') else {'ok': False, 'errors': ['canonical tear']})
        for relative in inventory.exit_sets():
            write_json(self.proof / relative, {'exit_code': 1})

    def manifest(self):
        return {'ok': True, 'errors': [], 'native_pixels': True, 'size': [1920, 1080], 'ui_scale': 1, 'frames': []}

    def capture(self, relative, manifest, files):
        folder = self.proof / relative
        write_json(folder / 'frames.json', manifest)
        for filename in files:
            path = folder / filename
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()

    def test_complete_inventory_accepts_failing_canonical_gates(self):
        captures, reports, reels = inventory.validate(self.proof, self.project)
        self.assertEqual(len(captures), 8)
        self.assertEqual(len(reports), 7)
        self.assertEqual(len(reels), 4)

    def test_performance_targets_are_per_run_and_rig_totals_are_reported(self):
        timings = [{'capture': 'seer/production/front', 'seconds': 256, 'GB': .58, 'bytes': 580_000_000},
                   {'capture': 'mortar/production/front', 'seconds': 275, 'GB': .65, 'bytes': 650_000_000},
                   {'capture': 'mortar/production/rear', 'seconds': 278, 'GB': .68, 'bytes': 680_000_000}]
        with patch('sys.stdout', new_callable=io.StringIO) as stdout:
            result = director.write_performance_report(self.proof, 'after', timings)
        self.assertEqual(result, json.loads((self.proof / 'capture_performance.json').read_text()))
        self.assertEqual(result['per_rig_production']['mortar'],
                         {'seconds': 553, 'GB': 1.33, 'runs': 2, 'all_runs_target_met': True})
        self.assertTrue(all(row['target_met'] for row in result['runs']))
        self.assertTrue(result['target']['advisory'])
        self.assertEqual(stdout.getvalue().count('advisory target PASS'), 3)
        self.assertIn('PRODUCTION RIG mortar: 553.000 s, 1.330000 GB (2 runs)', stdout.getvalue())
        self.assertEqual(timings[0].keys(), {'capture', 'seconds', 'GB', 'bytes'})

    def test_after_exits_zero_when_valid_capture_misses_performance_targets(self):
        output = self.root / 'slow-after'
        folder = output.resolve() / 'seer/production/front'
        command = ['production_capture.gd', '--output', str(folder)]
        def capture(command, env):
            write_json(folder / 'frames.json', {'frames': [{}]})
        with patch.object(sys, 'argv', ['capture_director.py', 'after', '--output', str(output)]), \
             patch.object(director, 'command_plan', return_value=[command]), \
             patch.object(director, 'execute', side_effect=capture), \
             patch.object(director.time, 'perf_counter', side_effect=[0, director.PRODUCTION_TARGET_SECONDS + 1]), \
             patch.object(director, 'collect'), patch.object(director, 'validate') as validate, \
             patch.object(director, 'write_validation_report'), patch('sys.stdout', new_callable=io.StringIO) as stdout:
            self.assertEqual(director.main(), 0)
        validate.assert_called_once_with(output, director.PROJECT, decode_reels=True)
        report = json.loads((output / 'capture_performance.json').read_text())
        self.assertFalse(report['runs'][0]['target_met'])
        self.assertIn('advisory target MISS', stdout.getvalue())
        self.assertIn('CAPTURE DIRECTOR AFTER: PASS', stdout.getvalue())

    def test_performance_size_miss_is_advisory_and_printed(self):
        timings = [{'capture': 'seer/production/front', 'seconds': 256,
                    'GB': 1.1, 'bytes': 1_100_000_000}]
        with patch('sys.stdout', new_callable=io.StringIO) as stdout:
            result = director.write_performance_report(self.proof, 'after', timings)
        self.assertFalse(result['runs'][0]['target_met'])
        self.assertIn('256.000 s, 1.100000 GB; advisory target MISS', stdout.getvalue())
        self.assertTrue(result['target']['advisory'])

    def test_empty_and_equally_missing_or_extra_artifacts_fail_with_path(self):
        empty = self.root / 'empty'; empty.mkdir()
        with self.assertRaisesRegex(ValueError, 'Missing artifact: .*frames|Missing artifact: .*native'):
            inventory.validate(empty, self.project)
        targets = ['seer/native/frames.json', 'mortar/native_gates.json', 'seer/review.mp4',
                   'mortar/contact_sheets/front_death_3x.png', 'seer/native/front_rest.png']
        for relative in targets:
            path = self.proof / relative
            original = path.read_bytes(); path.unlink()
            with self.subTest(missing=relative), self.assertRaises((ValueError, FileNotFoundError)) as caught:
                inventory.validate(self.proof, self.project)
            self.assertIn(str(path), str(caught.exception))
            path.write_bytes(original)
        for relative in ('seer/extra.mp4', 'seer/native/unexpected.png', 'mortar/unexpected_gates.json'):
            path = self.proof / relative; path.touch()
            with self.subTest(extra=relative), self.assertRaisesRegex(ValueError, 'Extra artifact: ' + str(path)):
                inventory.validate(self.proof, self.project)
            path.unlink()

    def test_inventory_rejects_frame_count_and_duplicate_mutations(self):
        path = self.proof / 'seer/native/frames.json'
        original = json.loads(path.read_text())
        for mutate in ('missing', 'duplicate', 'extra'):
            value = copy.deepcopy(original)
            if mutate == 'missing': value['frames'].pop()
            elif mutate == 'duplicate': value['frames'].append(value['frames'][0])
            else: value['frames'].append({'file': 'front_idle/pose_9999.png'})
            write_json(path, value)
            with self.subTest(mutation=mutate), self.assertRaises(ValueError):
                inventory.validate(self.proof, self.project)
        write_json(path, original)
        index = self.proof / 'seer/native/native_storage.json'
        files = inventory.native_files(index.parent, original)
        write_json(index, {'files': {p: {'stored_file': p, 'size': [64, 48], 'crop': [0, 0, 64, 48]} for p in files}})
        inventory.validate(self.proof, self.project)
        (index.parent / 'rogue.rgba').touch()
        with self.assertRaisesRegex(ValueError, 'Extra artifact: .*rogue.rgba'):
            inventory.validate(self.proof, self.project)

    def test_production_count_can_vary_without_a_headless_table(self):
        path = self.proof / 'seer/production/front/frames.json'
        manifest = json.loads(path.read_text())
        # Insert another genuine phase and regenerate only this fixture's files.
        rows = manifest['frames']; rows.insert(2, copy.deepcopy(rows[1]))
        rows[2]['snapshot']['phase'] = .3
        for file in path.parent.glob('*.png'): file.unlink()
        for i, row in enumerate(rows):
            row['file'] = f'frame_{i:05d}_{row["stage"]}.png'
            (path.parent / row['file']).touch()
        write_json(path, manifest)
        inventory.validate(self.proof, self.project)

    def test_validate_reuses_before_and_preserves_legacy_folder_reports(self):
        legacy = self.proof / 'mortar/production/front/production_gates.json'
        write_json(legacy, {'ok': False, 'errors': ['rear: missing production walk samples']})
        previous = legacy.read_bytes()
        with patch.object(director, 'PROJECT', self.project), patch.object(director, 'collect') as collect, \
             patch.object(director, 'complete_legacy_gate_exits'), patch.object(inventory, 'video_inventory'):
            report = director.validate_existing(self.proof, self.root / 'validation.json')
        collect.assert_called_once()
        self.assertTrue(report['ok'])
        self.assertEqual(legacy.read_bytes(), previous)
        self.assertEqual(report['production']['seer']['front']['idle']['frames'], 6)

    def test_director_routes_production_to_phase_matching_and_compares_gate_errors(self):
        after = self.root / 'after'; shutil.copytree(self.proof, after)
        calls = []
        def strict_reports(before, after, **kwargs):
            calls.append(kwargs)
            return compare(before, after, reports=kwargs['reports'])
        with patch.object(director, 'PROJECT', self.project), patch.object(inventory, 'video_inventory'), \
             patch.object(director, 'compare', side_effect=strict_reports):
            result = director.compare_complete(self.proof, after, self.root / 'comparison.json')
            self.assertTrue(result['ok'], result['errors'])
            self.assertEqual(set(result['production']), {'seer', 'mortar'})
            self.assertEqual(set(calls[0]['captures']), inventory.capture_sets() - {
                'seer/production/front', 'mortar/production/front', 'mortar/production/rear'})
            path = after / 'seer/production/front/frames.json'
            manifest = json.loads(path.read_text()); manifest['frames'][1]['pixels_sha256'] = 'changed'
            write_json(path, manifest)
            self.assertFalse(director.compare_complete(self.proof, after, self.root / 'pixel_difference.json')['ok'])
            shutil.copyfile(self.proof / 'seer/production/front/frames.json', path)
            write_json(after / 'mortar/production/production_gates.json', {'ok': False, 'errors': ['changed gate error']})
            self.assertFalse(director.compare_complete(self.proof, after, self.root / 'gate_difference.json')['ok'])

    def test_validate_cli_requires_before_and_accepts_optional_output(self):
        result = subprocess.run([sys.executable, 'tools/capture_director.py', 'validate'], cwd=PROJECT,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn('validate needs --before', result.stderr)
        root = self.root / 'empty_before'; root.mkdir()
        result = subprocess.run([sys.executable, 'tools/capture_director.py', 'validate', '--before', str(root)],
                                cwd=PROJECT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertFalse(json.loads((root / 'capture_validation.json').read_text())['ok'])

    def test_failed_gate_process_is_recorded_and_sequence_continues(self):
        commands = [director.gate_command(Path('/case/rr10'), self.proof / 'seer', Path('/samples'), Path('/native'), 'hoarfrost_seer', 'rr10'), ['capture-next']]
        with patch.object(director.subprocess, 'run', side_effect=[subprocess.CompletedProcess(commands[0], 1), subprocess.CompletedProcess(commands[1], 0)]) as run:
            for command in commands: director.execute(command, {})
        self.assertEqual(run.call_count, 2)
        self.assertFalse(run.call_args_list[0].kwargs['check'])
        self.assertTrue(run.call_args_list[1].kwargs['check'])
        self.assertEqual(json.loads((self.proof / 'seer/native_gate_exit.json').read_text()), {'exit_code': 1})
        with patch.object(director.subprocess, 'run', side_effect=subprocess.CalledProcessError(1, ['capture'])):
            with self.assertRaises(subprocess.CalledProcessError): director.execute(['capture'], {})

    def test_decoded_reel_counts_cannot_be_empty_or_short(self):
        path = self.proof / 'seer/review.mp4'
        for frames in (0, 1, 83, 85):
            stream = {'width': 1920, 'height': 1080, 'r_frame_rate': '60/1', 'nb_read_frames': str(frames)}
            with patch.object(inventory.subprocess, 'run', return_value=subprocess.CompletedProcess([], 0, json.dumps({'streams': [stream]}))):
                with self.assertRaisesRegex(ValueError, 'Decoded reel inventory differs: ' + str(path)):
                    inventory.video_inventory(path, 84)

    def test_real_production_gate_failure_records_actual_exit(self):
        case = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
        folder = self.root / 'production_failure'
        write_json(folder / 'frames.json', self.manifest())
        result = director.execute(director.production_gate_command(case, folder, folder), {})
        self.assertEqual(result.returncode, 1)
        self.assertFalse(json.loads((folder / 'production_gates.json').read_text())['ok'])
        self.assertEqual(json.loads((folder / 'production_gate_exit.json').read_text()), {'exit_code': 1})

    def test_gate_exit_and_failures_must_compare_identically(self):
        a, b = self.root / 'a', self.root / 'b'; a.mkdir(); b.mkdir()
        for folder in (a, b):
            write_json(folder / 'native_gates.json', {'ok': False, 'errors': ['31 genuine tears'], 'metrics': {'joint': 3}})
            write_json(folder / 'native_gate_exit.json', {'exit_code': 1})
        reports = ['native_gates.json', 'native_gate_exit.json']
        self.assertTrue(compare(a, b, reports=reports)['ok'])
        write_json(b / 'native_gate_exit.json', {'exit_code': 0})
        self.assertFalse(compare(a, b, reports=reports)['ok'])

    def test_command_plan_never_writes_case_proof_records(self):
        commands = director.command_plan(self.proof, 'before')
        for command in commands:
            if '--output' in command:
                self.assertTrue(Path(command[command.index('--output') + 1]).is_relative_to(self.proof))
            self.assertFalse(any(part.endswith('_records.py') for part in command))
        self.assertEqual(sum('tools/capture_gate_runner.py' in cmd for cmd in commands), 2)
        self.assertEqual(sum('tools/capture_review.py' in cmd for cmd in commands), 6)

    def test_private_case_preserves_source_and_committed_records(self):
        case = self.root / 'case/rr10'
        write_json(case / 'proof/build.json', {'protected': 'build'})
        write_json(case / 'proof/samples.json', {'protected': 'samples'})
        write_json(case / 'layouts/front.json', {'protected': 'paint'})
        samples = self.root / 'isolated_samples.json'; write_json(samples, {'samples': []})
        private = prepare_case(case, self.root / 'gate_output', samples)
        self.assertEqual((private / 'layouts/front.json').read_bytes(), (case / 'layouts/front.json').read_bytes())
        write_json(private / 'proof/samples.json', {'changed': True})
        self.assertEqual(json.loads((case / 'proof/samples.json').read_text()), {'protected': 'samples'})

    def test_real_failed_gate_adapter_and_legacy_recovery_preserve_records(self):
        case = self.project / 'experiments/cutouts/hoarfrost_seer/rr10'
        write_json(case / 'proof/build.json', {'protected': True})
        write_json(case / 'proof/samples.json', {'protected': True})
        write_json(case / 'proof/native_gates.json', {'protected': True})
        target = self.proof / 'seer'
        write_json(target / 'native/source_space_pockets.json', [])
        script = self.root / 'case_gate.py'
        script.write_text("""from pathlib import Path
import json
import sys
CASE = Path('/unused')
def main():
    capture = Path(sys.argv[sys.argv.index('--native') + 1])
    (capture / 'source_space_pockets.json').write_text('[]')
    (CASE / 'proof/native_gates.json').write_text(json.dumps({'ok': False, 'errors': ['canonical tear']}))
    return 1
""")
        original_command = director.gate_command
        def command(*args):
            value = original_command(*args)
            value[value.index('--script') + 1] = str(script)
            return value
        (target / 'native_gate_exit.json').unlink()
        protected = {p: p.read_bytes() for p in (case / 'proof').iterdir()}
        captured = (target / 'native/source_space_pockets.json').read_bytes()
        with patch.object(director, 'gate_command', side_effect=command), patch.object(director, 'read_report', return_value={'samples': []}):
            director.recover_native_exit(self.proof, target, case, 'hoarfrost_seer', 'rr10', {})
        self.assertEqual(json.loads((target / 'native_gate_exit.json').read_text()), {'exit_code': 1})
        for path, data in protected.items(): self.assertEqual(path.read_bytes(), data)
        self.assertEqual((target / 'native/source_space_pockets.json').read_bytes(), captured)

    def test_compare_cli_empty_evidence_writes_named_failure(self):
        a, b = self.root / 'empty_a', self.root / 'empty_b'; a.mkdir(); b.mkdir()
        output = self.root / 'empty-comparison.json'
        result = subprocess.run([sys.executable, 'tools/capture_director.py', 'compare', '--before', str(a),
            '--after', str(b), '--output', str(output)], cwd=PROJECT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn('CAPTURE EQUIVALENCE: FAIL', result.stdout)
        self.assertIn('Missing artifact:', json.loads(output.read_text())['errors'][0])

    def test_director_composition_matches_original_paths_and_sheet_pixels(self):
        from PIL import Image
        from humanoid_cutout import proof as original
        case = self.project / 'experiments/cutouts/hoarfrost_seer/rr10'
        capture = self.proof / 'seer/native'
        manifest = json.loads((capture / 'frames.json').read_text())
        manifest['inputs'] = {'test': 'bindings'}
        manifest['frames'] = []
        for view in ('front', 'rear'):
            for clip in ('idle', 'death'):
                for frame in range(6):
                    filename = f'{view}_{clip}/pose_{frame:04d}.png'
                    image = Image.new('RGBA', (512, 512))
                    image.paste((40, 90, 140, 255), (200 + frame, 180, 210 + frame, 210))
                    image.save(capture / filename)
                    manifest['frames'].append({'file': filename, 'view': view, 'clip': clip, 'frame': frame, 'phase': frame / 5})
        write_json(capture / 'frames.json', manifest)
        with patch('humanoid_cutout.gates.bindings', return_value=manifest['inputs']), patch.object(original, 'native_errors', return_value=[]):
            for mode in ('review', 'idle'):
                with patch.object(original, 'encode') as old_encode, patch.object(capture_review, 'encode') as new_encode:
                    original.compose(case, capture, self.root / ('old_' + mode + '.mp4'), mode)
                    capture_review.compose(case, capture, self.root / ('new_' + mode + '.mp4'), mode, self.proof / 'seer/native_gates.json')
                    self.assertEqual(old_encode.call_args.args[0], new_encode.call_args.args[0])
            old, new = self.root / 'old_sheets', self.root / 'new_sheets'
            original.compose(case, capture, old, 'sheets')
            capture_review.compose(case, capture, new, 'sheets', self.proof / 'seer/native_gates.json')
            for path in old.glob('*.png'):
                self.assertEqual(Image.open(path).tobytes(), Image.open(new / path.name).tobytes())

    def test_director_review_composes_when_gate_failed(self):
        from PIL import Image
        case = self.project / 'experiments/cutouts/hoarfrost_seer/rr10'
        capture = self.proof / 'seer/native'
        manifest = json.loads((capture / 'frames.json').read_text()); manifest['inputs'] = {'test': 'bindings'}
        write_json(capture / 'frames.json', manifest)
        with patch('humanoid_cutout.gates.bindings', return_value=manifest['inputs']), patch.object(capture_review, 'encode') as encode:
            capture_review.compose(case, capture, self.proof / 'seer/review.mp4', 'review', self.proof / 'seer/native_gates.json')
        self.assertEqual(len(encode.call_args.args[0]), 84)
        self.assertFalse(json.loads((self.proof / 'seer/review.json').read_text())['gate_ok'])


if __name__ == '__main__': unittest.main()
