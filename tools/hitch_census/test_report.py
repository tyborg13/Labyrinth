"""Unit-local tooling checks; writes only TemporaryDirectory outputs.

Kept in the owned tools directory, outside the product-suite inventory.
Run: python3 -m unittest discover -s tools/hitch_census -p 'test_*.py' -v
"""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import census
import report

FIXTURE = Path(__file__).parent / 'fixtures/report_trace.jsonl'


class ReportTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_fixture(self, name='cold', native=True, **extra):
        directory = self.root / name
        directory.mkdir()
        raw = FIXTURE.read_text().replace('"native":true', f'"native":{str(native).lower()}')
        (directory / 'frames.jsonl').write_text(raw)
        path = directory / 'run.json'
        path.write_text(json.dumps(dict(driver='whole', seed=83, cache=name, profile='normal',
                                        replay='cd /repo && census replay', **extra)))
        return path

    def test_thresholds_clusters_nearest_rank_and_replay(self):
        result = report.generate([self.run_fixture()], self.root / 'report')
        self.assertEqual(len(result['clusters']), 2)
        first = result['clusters'][0]
        self.assertEqual(first['count'], 2)
        # The fixture's ~14 µs observer callbacks are subtracted from game time.
        self.assertAlmostEqual(first['max'], 120, delta=0.05)
        self.assertAlmostEqual(first['p99'], 120, delta=0.05)
        self.assertEqual(first['over_ms'], {'33.3': 2, '50.0': 1, '100.0': 1})
        self.assertEqual(first['first']['decision'], 2)
        self.assertEqual(first['first']['replay'], 'cd /repo && census replay')
        self.assertAlmostEqual(first['severity_ms'], 93.4, delta=0.05)
        slow = (self.root / 'report/slow_frames.jsonl').read_text().splitlines()
        self.assertEqual(len(slow), 3)
        self.assertEqual(json.loads(slow[2])['focused'], False)
        self.assertAlmostEqual(result['situations'][0]['p50'], 40, delta=0.05)
        self.assertAlmostEqual(result['situations'][0]['p99.9'], 120, delta=0.05)

    def test_comparisons_keep_cache_and_qos_separate(self):
        cold = self.run_fixture()
        warm = self.run_fixture('warm')
        result = report.generate([cold, warm], self.root / 'report')
        self.assertEqual(len(result['situations']), 4)
        text = (self.root / 'report/report.md').read_text()
        self.assertIn('Cold normal | Warm normal | Cold background | Warm background', text)

    def test_headless_excluded(self):
        result = report.generate([self.run_fixture(native=False)], self.root / 'report')
        self.assertEqual(result['situations'], [])
        self.assertEqual(len(result['rejected']), 1)

    def test_truncated_tail_allowed_but_corrupt_interior_rejected(self):
        path = self.root / 'trace.jsonl'
        path.write_text(FIXTURE.read_text() + '[6,')
        self.assertEqual(len(list(report.frames(path))), 5)
        path.write_text(FIXTURE.read_text() + 'broken\n[6,')
        with self.assertRaisesRegex(ValueError, 'Corrupt trace'):
            list(report.frames(path))

    def test_invalid_schema_and_row_shape(self):
        path = self.root / 'trace.jsonl'
        path.write_text(FIXTURE.read_text().replace('"schema":1', '"schema":99'))
        with self.assertRaisesRegex(ValueError, 'Unsupported'):
            list(report.frames(path))
        path.write_text(FIXTURE.read_text() + '[6]\n')
        with self.assertRaisesRegex(ValueError, 'column count'):
            list(report.frames(path))

    def test_empty_stats(self):
        self.assertIsNone(report.stats([])['p99'])
        self.assertEqual(report.stats([1])['p99.9'], 1)

    def test_primer_and_calibration_excluded_from_gameplay(self):
        primer = self.run_fixture('cold', primer=True)
        calibration = self.run_fixture('warm')
        metadata = json.loads(calibration.read_text())
        metadata.update(driver='calibration', trace_mode='on')
        calibration.write_text(json.dumps(metadata))
        (calibration.parent / 'receipt.json').write_text(json.dumps({'calibration_intervals_ms': [10, 20, 30]}))
        result = report.generate([primer, calibration], self.root / 'report')
        self.assertEqual(result['clusters'], [])
        self.assertEqual(result['situations'], [])
        self.assertEqual(result['calibration']['warm']['normal:on']['p50'], 20)

    def test_native_command_uses_required_runner_and_no_fixed_fps(self):
        from types import SimpleNamespace
        args = SimpleNamespace(output=self.root, seconds=900, first_boss=True, stop_after=3)
        command = census.command(args, 'whole', 83, 'normal', 'example', self.root / 'run', 'on')
        self.assertIn('tools/godot_task_runner.py', command)
        self.assertIn('--windowed', command)
        self.assertIn('1280x800', command)
        self.assertEqual(command[command.index('--position') + 1], '24,24')
        self.assertNotIn('--headless', command)
        self.assertNotIn('--fixed-fps', command)
        self.assertIn('--first-boss', command)
        self.assertIn('--stop-after=3', command)

    def test_deck_override_is_copy_only_and_preserves_release_canvas(self):
        import configparser
        census.write_window_override(self.root)
        config = configparser.ConfigParser()
        config.read(self.root / 'override.cfg')
        display = config['display']
        self.assertEqual(display['window/size/mode'], '0')
        self.assertEqual(display['window/size/window_width_override'], '1280')
        self.assertEqual(display['window/size/window_height_override'], '800')
        self.assertEqual(display['window/dpi/allow_hidpi'], 'false')
        self.assertEqual(display['window/stretch/mode'], '"canvas_items"')
        self.assertEqual(display['window/stretch/aspect'], '"expand"')
        self.assertEqual(display['window/stretch/scale'], '1.15')
        self.assertNotIn('window/size/viewport_width', display)
        with self.assertRaisesRegex(RuntimeError, 'project copy'):
            census.write_window_override(census.ROOT)

    def test_viewport_persisted_even_when_startup_rejects_run(self):
        from types import SimpleNamespace
        viewport = dict(root_pixel_size=[2560, 1600], root_size=[1280, 800],
                        content_scale=1.15, hidpi_allowed=True, status='rejected')
        args = SimpleNamespace(output=self.root, disk_cap_gb=10, tag='test',
                               seconds=900, first_boss=False, stop_after=0)
        def launch(*args, **kwargs):
            directory = next((self.root / 'runs').iterdir())
            (directory / 'viewport.json').write_text(json.dumps(viewport))
            return SimpleNamespace(returncode=1, poll=lambda: 1)
        with patch.object(census, 'guard'), patch.object(census, 'subprocess') as process:
            process.Popen.side_effect = launch
            with self.assertRaisesRegex(RuntimeError, 'failed run'):
                census.run_one(args, 'whole', 83, 'normal', 'cold', 'test-run')
        metadata = json.loads(next((self.root / 'runs').glob('*/run.json')).read_text())
        self.assertEqual(metadata['viewport'], viewport)
        self.assertEqual(metadata['returncode'], 1)
        self.assertEqual(metadata['env']['LABYRINTH_PROBE_WINDOW'], '1')

    def test_report_prints_observed_viewport_without_receipt(self):
        viewport = dict(pixel_measurement_version=2, root_pixel_size=[1280, 800],
                        root_texture_reported_size=[982, 614], startup_capture_us=1234, root_size=[1280, 800],
                        content_scale=1.15, content_scale_size=[1920, 1080],
                        hidpi_allowed=False, screen_scale=2.0, status='passed', pixel_count_ratio=1.0)
        run = self.run_fixture(viewport=viewport)
        result = report.generate([run], self.root / 'report')
        self.assertEqual(result['runs'][0]['viewport'], viewport)
        text = (self.root / 'report/report.md').read_text()
        self.assertIn('1280x800 / 982x614 / 1280x800', text)
        self.assertIn('1.15 / 1920x1080', text)
        self.assertIn('false / 2.0', text)
        self.assertIn('passed / 1.0 / 1234', text)

    def test_legacy_getter_is_never_labelled_as_backing_pixels(self):
        run = self.run_fixture(viewport=dict(root_pixel_size=[982, 614], root_size=[1280, 800],
                                            pixel_count_ratio=0.58881640625, status='rejected'))
        report.generate([run], self.root / 'report')
        text = (self.root / 'report/report.md').read_text()
        self.assertIn('unmeasured / 982x614 / 1280x800', text)
        self.assertIn('legacy:0.58881640625', text)

    def test_rejected_pixel_load_is_reported_but_excluded_from_frame_statistics(self):
        run = self.run_fixture(viewport=dict(root_pixel_size=[2560, 1600], content_scale=1.15,
                                            status='rejected', failure='pixel count'))
        result = report.generate([run], self.root / 'report')
        self.assertEqual(result['situations'], [])
        self.assertEqual(result['clusters'], [])
        self.assertIn('startup viewport rejected', result['rejected'][0]['reason'])
        self.assertIn('2560x1600', (self.root / 'report/report.md').read_text())

    def test_legacy_viewport_abort_excluded_without_rewriting_evidence(self):
        run = self.run_fixture(returncode=1)
        log = run.parent / 'godot.log'
        log.write_text('ERROR: HITCH TRACE: Deck viewport drift\n')
        original = run.read_bytes()
        result = report.generate([run], self.root / 'report')
        self.assertEqual(result['situations'], [])
        self.assertIn('legacy Deck viewport drift', result['rejected'][0]['reason'])
        self.assertEqual(run.read_bytes(), original)

    def test_schema2_attribution_catalog_and_loading(self):
        run = self.run_fixture()
        (run.parent / 'frames.jsonl').write_text(
            FIXTURE.with_name('report_trace_v2.jsonl').read_text())
        result = report.generate([run], self.root / 'report')
        self.assertEqual(len(result['named_hitch_catalog']), 1)
        row = result['named_hitch_catalog'][0]
        self.assertEqual(row['hitch_id'], 'combat/controller:A')
        self.assertEqual(row['count'], 4)
        self.assertEqual(row['over_ms'], {'50.0': 2, '100.0': 2})
        self.assertEqual(row['max'], 160)
        self.assertEqual(row['p99.9'], 160)
        self.assertEqual(row['raw_interval_ms']['max'], 160)
        self.assertEqual(row['mean_buckets_over50_ms'], dict(
            process=None, physics=None, pre_process=None, draw=None, subviewports=7,
            driver=5, observer=0.0))
        self.assertEqual(row['dominant_bucket'], 'n/a')
        self.assertEqual(row['pipeline_compiles'], 2)
        self.assertEqual(row['instances_added'], 3)
        # Full trace: frame 3 follows the filtered driver-only frame 2,
        # frame 5 follows the fast frame 4 (neither is a slow gameplay frame).
        self.assertEqual(row['mean_video_mem_delta_mb'], (3 + 2 + 5) / 3)
        self.assertEqual(row['worst']['frame'], 5)
        self.assertEqual(row['worst']['replay'], 'cd /repo && census replay')
        self.assertEqual(sum(r['count'] for r in result['loading']), 3)
        self.assertEqual(sum(r['count'] for r in result['situations']), 5)
        driver_situation = next(r for r in result['situations'] if r['screen'] == 'driver_only')
        self.assertEqual(driver_situation['max'], 8)
        self.assertEqual(driver_situation['raw_interval_ms']['max'], 1067)
        slow = [json.loads(line) for line in (self.root / 'report/slow_frames.jsonl').read_text().splitlines()]
        self.assertNotIn(2, [f['frame'] for f in slow])
        self.assertEqual(slow[0]['game_ms'], 130)
        self.assertEqual(slow[0]['video_mem_delta_mb'], 3)
        self.assertNotIn('RENDER_TEXTURE_MEM_USED', (self.root / 'report/report.md').read_text())
        saved = json.loads((self.root / 'report/report.json').read_text())
        self.assertEqual(saved['named_hitch_catalog'][0]['hitch_id'], 'combat/controller:A')

    def test_schema3_signal_buckets_fresh_phases_and_load_proxy(self):
        run = self.run_fixture()
        (run.parent / 'frames.jsonl').write_text(FIXTURE.with_name('report_trace_v3.jsonl').read_text())
        result = report.generate([run], self.root / 'report')
        row = result['named_hitch_catalog'][0]
        self.assertEqual(row['mean_buckets_over50_ms'], dict(process=15, physics=5, pre_process=20, draw=17.5, driver=2.5, subviewports=None, observer=0.0))
        self.assertEqual(row['top_load_paths_over50_us'], [('load:res://fixture.png', 22000)])
        self.assertEqual(row['top_post_draw_input_over50_us'], [('post_draw:fixture:resume', 10000), ('input:dispatch', 2000)])
        self.assertEqual(row['mean_explained_pre_process_over50_ms_estimate'], 6)
        self.assertEqual(row['resource_count_delta_proxy'], dict(net=1, positive=3, samples=2))
        text = (self.root / 'report/report.md').read_text()
        self.assertIn('Explained pre_process', text)
        self.assertIn('rolling-peak monitors: not frame-accurate', text)
        rows = list(report.frames(run.parent / 'frames.jsonl'))
        self.assertEqual(rows[1][1]['phase_times_us'], {})
        self.assertTrue(rows[1][1]['phase_map_was_stale'])
        self.assertEqual(rows[1][1]['resource_count_delta'], 3)
        self.assertIsNone(rows[1][1]['first_physics_frame_us'])

    def test_headless_and_legacy_phase_freshness(self):
        path = self.root / 'phases.jsonl'
        for schema in (1, 2, 3):
            for native in (True, False):
                expected = 8 if native else 7
                header = dict(schema=schema, native=native, columns=['frame', 'phase_frame', 'phase_times_us', 'monitors'])
                path.write_text('\n'.join(json.dumps(r) for r in [header, [8, expected, {'fresh': 1}, {}], [9, expected, {'stale': 100}, {}]]) + '\n')
                rows = [r for _, r in report.frames(path)]
                self.assertEqual(rows[0]['phase_times_us'], {'fresh': 1})
                self.assertEqual(rows[1]['phase_times_us'], {})

    def test_schema1_peaks_are_not_bucket_inputs_and_driver_floor(self):
        from attribution import attribute
        frame = dict(draw_interval_ms=120, cpu_ms=90, physics_ms=5, monitors={})
        buckets = attribute(frame, None)[0]['buckets_ms']
        for key in ('process', 'physics', 'pre_process', 'draw'):
            self.assertIsNone(buckets[key])
        frame['driver_cpu_us'] = {'bot_choose': 200000}
        self.assertEqual(attribute(frame, None)[0]['game_ms'], 0)
        result = report.generate([self.run_fixture()], self.root / 'report')
        row = next(r for r in result['named_hitch_catalog'] if r['hitch_id'] == 'combat/pass')
        self.assertIsNone(row['mean_buckets_over50_ms']['process'])
        self.assertIsNone(row['mean_buckets_over50_ms']['draw'])

    def test_whole_survival_defaults_are_recorded_and_forwarded(self):
        from types import SimpleNamespace
        args = SimpleNamespace(output=self.root, disk_cap_gb=10, tag='test', seconds=1800, first_boss=False, stop_after=0)
        command = census.command(args, 'whole', 84, 'normal', 'example', self.root / 'run', 'on')
        self.assertIn('--starting-health=9999', command)
        self.assertNotIn('--allow-voluntary-ends', command)
        def launch(*unused, **kwargs):
            directory = next((self.root / 'runs').iterdir())
            kwargs['stdout'].write('HITCH CENSUS RESULT: whole outcome=time_limit\n')
            (directory / 'receipt.json').write_text(json.dumps(dict(outcome='time_limit', errors=[])))
            return SimpleNamespace(returncode=0, poll=lambda: 0)
        with patch.object(census, 'guard'), patch.object(census, 'subprocess') as process:
            process.Popen.side_effect = launch
            directory = census.run_one(args, 'whole', 84, 'normal', 'cold', 'example')
        run = json.loads((directory / 'run.json').read_text())
        self.assertEqual(run['whole_settings']['starting_health'], 9999)
        self.assertTrue(run['whole_settings']['no_embrace_abandonment_voluntary_ends'])
        self.assertEqual(run['whole_settings']['time_scale'], 1)
        report.generate([directory / 'run.json'], self.root / 'report')
        self.assertIn('starting_health', (self.root / 'report/report.md').read_text())

    def test_catalog_ids_merge_across_events_and_sort_by_count_then_max(self):
        from attribution import hitch_id
        a = {'context': {'screen': 'combat', 'action': 'controller:Joypad Button 0 (A, Cross)'}}
        b = {'context': {'screen': 'combat', 'action': 'controller:Joypad Button 0 (Bottom Action, Sony Cross, Xbox A, Nintendo B)'}}
        self.assertEqual(hitch_id(a), hitch_id(b))
        result = report.generate([self.run_fixture()], self.root / 'report')
        self.assertEqual([r['hitch_id'] for r in result['named_hitch_catalog']], ['combat/pass', 'map/open'])
        self.assertEqual(result['named_hitch_catalog'][0]['count'], 3)

    def test_result_receipt_accounting_continues_after_abort_and_demo_loss(self):
        from types import SimpleNamespace
        args = SimpleNamespace(output=self.root, disk_cap_gb=10, tag='test',
                               seconds=900, first_boss=False, stop_after=0)
        for code, outcome, errors in ((250, 'time_limit', []), (1, 'demo_incomplete', ['Run ended without full demo clear'])):
            def launch(*unused, **kwargs):
                directory = max((self.root / 'runs').iterdir(), key=lambda p: p.name)
                kwargs['stdout'].write('HITCH CENSUS RESULT: demo outcome=' + outcome + '\n')
                if code == 250:
                    kwargs['stdout'].write('libc++abi: recursive_mutex lock failed\n')
                (directory / 'receipt.json').write_text(json.dumps(dict(
                    outcome=outcome, errors=errors, trace={'native': True})))
                return SimpleNamespace(returncode=code, poll=lambda: code)
            with patch.object(census, 'guard'), patch.object(census, 'subprocess') as process:
                process.Popen.side_effect = launch
                directory = census.run_one(args, 'demo', 7, 'normal', 'cold', 'test-run')
            metadata = json.loads((directory / 'run.json').read_text())
            self.assertTrue(metadata['measured'])
            self.assertEqual(metadata['returncode'], code)
            self.assertEqual(metadata['outcome'], outcome)
            self.assertEqual(metadata['errors'], errors)
            result = report.generate([directory / 'run.json'], self.root / ('report-' + str(code)))
            text = (self.root / ('report-' + str(code)) / 'report.md').read_text()
            self.assertIn(str(code) + ' / ' + outcome, text)
            if errors: self.assertIn(errors[0], text)

    def test_script_errors_override_result_and_missing_receipt_is_unmeasured(self):
        (self.root / 'godot.log').write_text('SCRIPT ERROR: broken\nHITCH CENSUS RESULT: demo\n')
        (self.root / 'receipt.json').write_text('{}')
        result = census.run_accounting(self.root, 250)
        self.assertTrue(result['script_error'])
        self.assertFalse(result['measured'])
        (self.root / 'receipt.json').unlink()
        (self.root / 'godot.log').write_text('HITCH CENSUS RESULT: demo\n')
        self.assertFalse(census.run_accounting(self.root, 0)['measured'])
        (self.root / 'godot.log').write_text('exited early\n')
        self.assertFalse(census.run_accounting(self.root, 0)['result_printed'])

    def test_redraw_thresholds_counts_remainder_and_legacy(self):
        run = self.run_fixture()
        source = FIXTURE.with_name('report_trace_v3.jsonl')
        data = [json.loads(line) for line in source.read_text().splitlines()]
        header, rows = data[0], data[1:]
        header['redraw_version'] = 1
        header['columns'] += ['redraws', 'redraw_ms_estimate', 'redraw_span_ms',
                              'redraw_polygons', 'redraw_frame']
        # First two are >50, last is ordinary; second is also >100.
        rows[1][1] = 120
        for index, row in enumerate(rows):
            row += [{'res://fixture.gd': index + 1, 'builtin:Polygon2D': 1},
                    {'res://fixture.gd': 2.5}, 4.0,
                    {'builtin:Polygon2D': {'vertices': 12, 'internal_polygons': 2}}, row[0]]
        (run.parent / 'frames.jsonl').write_text('\n'.join(json.dumps(r) for r in data) + '\n')
        result = report.generate([run], self.root / 'report')
        over50, over100 = result['redraw']
        self.assertEqual(over50['slow']['frames'], 2)
        self.assertEqual(over50['ordinary']['frames'], 1)
        self.assertEqual(over50['slow']['mean_redraws_per_frame'], 2.5)
        self.assertEqual(over50['ordinary']['mean_redraws_per_frame'], 4)
        self.assertEqual(over50['slow']['frames_with_redraw']['res://fixture.gd'], 2)
        self.assertEqual(over50['slow']['top_by_ms_estimate'], [('res://fixture.gd', 5.0)])
        self.assertEqual(over50['slow']['polygon_totals']['builtin:Polygon2D:vertices'], 24)
        self.assertEqual(over50['slow']['process_minus_outermost_phase_ms_estimate'], 30)
        self.assertEqual(over50['slow']['process_minus_outermost_phase_and_redraw_ms_estimate'], 22)
        self.assertEqual(over50['slow']['resume_phase_frames'], {'post_draw:fixture:resume': 1})
        self.assertEqual(over100['slow']['redraw_totals']['res://fixture.gd'], 2)
        self.assertEqual(result['named_hitch_catalog'][0]['redraw_span_ms'], 4)
        self.assertIn('## Redraw', (self.root / 'report/report.md').read_text())
        self.assertIn('redraw_span_ms', (self.root / 'report/report.md').read_text())
        # A stale redraw map cannot leak into either slow or ordinary totals.
        rows[1][-1] = -1
        (run.parent / 'frames.jsonl').write_text('\n'.join(json.dumps(r) for r in data) + '\n')
        result = report.generate([run], self.root / 'stale-report')
        self.assertEqual(result['redraw'][0]['slow']['frames'], 1)
        legacy = self.run_fixture('legacy')
        result = report.generate([legacy], self.root / 'legacy-report')
        self.assertEqual(result['redraw'], [])
        self.assertIsNone(result['named_hitch_catalog'][0]['redraw_span_ms'])

    def test_disk_guard(self):
        with self.assertRaisesRegex(RuntimeError, 'cap'):
            (self.root / 'payload').write_text('too large')
            census.guard(self.root, 1)


if __name__ == '__main__':
    unittest.main()
