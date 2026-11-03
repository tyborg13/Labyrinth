"""Override CLI integration, paired statistics, provenance and report reconstruction."""
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import encounter_bot
import skybolt_measurement as skybolt
CLI_TIMEOUT_SECONDS = 180
SUBPROCESS_TIMEOUT_SECONDS = 200
# The reviewed report remains frozen while later fixes improve future tooling.
# Check its recorded tool bytes against the exact measurement handoff commit.
MEASUREMENT_TOOL_SNAPSHOT = '2285dad8dedec2c3c047b6f57c2d0199ecfdf6dd'


class SkyboltMeasurementTests(unittest.TestCase):
    def row(self, seed, won, hp, section=0):
        return {'seed': seed, 'section_index': section, 'coord': {'x': section, 'y': 1},
                'won': won, 'hp_lost': hp}

    def test_frozen_policy_and_literal_arms(self):
        self.assertEqual(len(skybolt.ARMS), 9)
        self.assertEqual(len(skybolt.GROUPS), 7)
        self.assertEqual(skybolt.RUNS, 150)
        self.assertEqual(skybolt.FIRST_SEED, 1)
        self.assertEqual(skybolt.ARMS['V1']['fields'], {'action_fields': {'shock_all_hits': False}})
        self.assertEqual(skybolt.ARMS['V2']['fields'], {'burn': True})
        self.assertEqual(skybolt.ARMS['V3']['fields'], {'action_fields': {'range': 5, 'ignore_los': None}})
        self.assertEqual(skybolt.ARMS['V4']['fields'], {'time': 9})
        self.assertEqual(skybolt.ARMS['V5']['fields'], {'burn': True, 'action_fields': {'shock_all_hits': False}})

    def test_pairing_and_signs(self):
        base = [self.row(1, False, 10), self.row(2, True, 5)]
        arm = [self.row(1, True, 2), self.row(2, True, 5)]
        result = skybolt.paired_delta(base, arm)
        self.assertEqual(result['win_rate']['mean'], .5)
        self.assertEqual(result['hp_lost']['mean'], -4)
        self.assertEqual(result['win_rate']['ci95'], [0, 1])
        self.assertEqual(result['hp_lost']['ci95'], [-8, 0])
        self.assertEqual(result, skybolt.paired_delta(base, arm))
        with self.assertRaisesRegex(ValueError, 'identical ordered'):
            skybolt.paired_delta(base, arm[::-1])
        with self.assertRaises(ValueError): skybolt.paired_delta([], [])

    def test_correlated_sections_are_bootstrapped_together(self):
        base = [self.row(1, False, 10, 0), self.row(1, False, 10, 1)]
        arm = [self.row(1, True, 2, 0), self.row(1, False, 10, 1)]
        result = skybolt.paired_delta(base, arm)
        self.assertEqual(result['seed_clusters'], 1)
        self.assertEqual(result['win_rate']['ci95'], [.5, .5])
        self.assertEqual(result['hp_lost']['ci95'], [-4, -4])

    def test_usage_includes_zero_cast_fights(self):
        counts = {'casts': {'skybolt': 2}, 'skybolt_hits': 3, 'skybolt_kills': 1,
                  'skybolt_cancelled_attacks': 1, 'skybolt_hits_beyond_5': 1,
                  'skybolt_hits_without_los': 1, 'skybolt_casts_beyond_5': 1,
                  'skybolt_casts_without_los': 1}
        zero = {key: {} if key == 'casts' else 0 for key in counts}
        result = skybolt.usage([{'card_usage': counts}, {'card_usage': zero}])
        self.assertEqual(result['casts_per_fight'], 1)
        self.assertEqual(result['hits_per_cast'], 1.5)
        self.assertEqual(result['cancelled_attacks_per_cast'], .5)
        self.assertEqual(result['kills_per_fight'], .5)

    def test_cli_named_card_override_resume_and_policy_unchanged(self):
        before_policy = skybolt.sha(ROOT / 'tools/encounter_bot.gd')
        before_cards = skybolt.sha(ROOT / 'data/cards.json')
        historical = encounter_bot.read_report(ROOT / 'spec/peer_benchmark/encounter_redesign/measurements/revision7/bot-t2-standard.json.gz')
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'report.json'
            arguments = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--task-id', 'meas-03',
                         '--timeout', str(CLI_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', str(ROOT),
                         '--script', 'tools/encounter_measurement_bot.gd', '--', '--revision', '7',
                         '--tier', '2', '--cohort', 'standard', '--runs', '1', '--add-card', 'skybolt',
                         '--card-overrides', '{"burn":true}', '--output', str(output)]
            first = subprocess.run(arguments, cwd=ROOT, text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            report = json.loads(output.read_text())
            for tier in ('1', '2', '3'):
                self.assertEqual(report['decks'][tier], historical['decks'][tier] + ['skybolt'])
            for key in ('common_rewards', 'rare_rewards'):
                self.assertEqual(report['decks'][key], historical['decks'][key])
            self.assertEqual(report['defaults'], historical['defaults'])
            self.assertEqual(report['deck_override'], {'card': 'skybolt', 'fields': {'burn': True}})
            self.assertEqual(len(report['results']), 1)
            self.assertIn('card_usage', report['results'][0])
            resumed = subprocess.run(arguments + ['--resume-report', str(output)], cwd=ROOT,
                                     text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertEqual(resumed.returncode, 0, resumed.stdout + resumed.stderr)
            self.assertEqual(json.loads(output.read_text()), report)
            old_origin = json.loads(json.dumps(report))
            self.assertGreater(old_origin['results'][0]['card_usage']['casts'].get('skybolt', 0), 0)
            old_origin['results'][0]['card_usage'].pop('origin_metric')
            old_origin_path = Path(temporary) / 'old-origin.json'
            old_origin_path.write_text(json.dumps(old_origin))
            refreshed = subprocess.run(arguments + ['--resume-report', str(old_origin_path), '--refresh-skybolt-metrics'],
                                       cwd=ROOT, text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertEqual(refreshed.returncode, 0, refreshed.stdout + refreshed.stderr)
            self.assertIn('ENCOUNTER METRIC REFRESH: PASS (1 records; 1 fights replayed)', refreshed.stdout)
            self.assertEqual(json.loads(output.read_text()), report)
            wrong_outcome = json.loads(json.dumps(old_origin))
            wrong_outcome['results'][0]['hp_lost'] += 1
            wrong_outcome_path = Path(temporary) / 'wrong-outcome.json'
            wrong_outcome_path.write_text(json.dumps(wrong_outcome))
            rejected_outcome = subprocess.run(arguments + ['--resume-report', str(wrong_outcome_path), '--refresh-skybolt-metrics'],
                                              cwd=ROOT, text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertNotEqual(rejected_outcome.returncode, 0)
            self.assertIn('Metric refresh changed a combat result', rejected_outcome.stdout + rejected_outcome.stderr)
            self.assertEqual(json.loads(output.read_text()), report)
            wrong_hits = json.loads(json.dumps(old_origin))
            wrong_hits['results'][0]['card_usage']['skybolt_hits'] += 1
            wrong_hits_path = Path(temporary) / 'wrong-hits.json'
            wrong_hits_path.write_text(json.dumps(wrong_hits))
            before_output = output.read_bytes()
            before_wrong_hits = wrong_hits_path.read_bytes()
            rejected_hits = subprocess.run(arguments + ['--resume-report', str(wrong_hits_path), '--refresh-skybolt-metrics'],
                                           cwd=ROOT, text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertNotEqual(rejected_hits.returncode, 0)
            self.assertIn('Metric refresh changed a non-geometric counter', rejected_hits.stdout + rejected_hits.stderr)
            self.assertEqual(output.read_bytes(), before_output)
            self.assertEqual(wrong_hits_path.read_bytes(), before_wrong_hits)
            mismatched_arguments = arguments.copy()
            mismatched_arguments[mismatched_arguments.index('--card-overrides') + 1] = '{"time":9}'
            rejected_overrides = subprocess.run(mismatched_arguments + ['--resume-report', str(output)], cwd=ROOT,
                                                text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertNotEqual(rejected_overrides.returncode, 0)
            self.assertIn('Resume requires identical card overrides', rejected_overrides.stdout + rejected_overrides.stderr)
            self.assertEqual(output.read_bytes(), before_output)
            # A pre-adapter checkpoint cannot silently masquerade as V1.
            stale = json.loads(output.read_text())
            stale['deck_override']['fields'] = {'action_fields': {'shock_all_hits': False}}
            stale_path = Path(temporary) / 'pre-adapter.json'
            stale_path.write_text(json.dumps(stale))
            primary_arguments = arguments.copy()
            primary_arguments[primary_arguments.index('--card-overrides') + 1] = json.dumps(stale['deck_override']['fields'])
            rejected = subprocess.run(primary_arguments + ['--resume-report', str(stale_path)], cwd=ROOT,
                                      text=True, capture_output=True, timeout=SUBPROCESS_TIMEOUT_SECONDS)
            self.assertNotEqual(rejected.returncode, 0)
            self.assertIn('Primary-only Shock requires adapter-aware checkpoints', rejected.stdout + rejected.stderr)
            self.assertEqual(json.loads(output.read_text()), report)
        self.assertEqual(skybolt.sha(ROOT / 'tools/encounter_bot.gd'), before_policy)
        self.assertEqual(skybolt.sha(ROOT / 'data/cards.json'), before_cards)

    def test_report_is_complete_paired_and_recomputable(self):
        path = skybolt.OUTPUT / 'summary.json'
        metadata = json.loads(path.read_text())
        self.assertIn('groups', metadata, 'full measurement must finish before handoff')
        self.assertEqual(metadata['policy_sha256'], skybolt.POLICY_SHA256)
        self.assertEqual(metadata['arms'], skybolt.ARMS)
        self.assertEqual(metadata['runs_per_arm'], 150)
        self.assertEqual(metadata['first_seed'], 1)
        regenerated = skybolt.build_report(skybolt.OUTPUT, {k: v for k, v in metadata.items() if k != 'groups'})
        self.assertEqual(regenerated, metadata)
        self.assertEqual(skybolt.render(regenerated), (skybolt.OUTPUT / 'report.md').read_text())
        self.assertEqual(len(regenerated['groups']), 63)
        for tier, cohort in skybolt.GROUPS:
            records = {}
            baseline = encounter_bot.read_report(skybolt.OUTPUT / 'data' / f't{tier}-{cohort}-none.json.gz')
            frozen = ROOT / 'spec/peer_benchmark/encounter_redesign/measurements/revision7'
            if cohort == 'boss':
                original_rows = [r for boss in encounter_bot.BOSS_IDS
                                 for r in encounter_bot.read_report(frozen / f'bot-t3-boss-{boss}.json.gz')['results']]
                original_rows.sort(key=skybolt.identity)
            else:
                original_rows = encounter_bot.read_report(frozen / f'bot-t{tier}-{cohort}.json.gz')['results']
            clean_baseline = [{k: v for k, v in r.items() if k != 'card_usage'} for r in baseline['results']]
            self.assertEqual(clean_baseline, original_rows[:150], 'none reproduces frozen policy-v2 outcomes exactly')
            for arm, addition in skybolt.ARMS.items():
                raw = encounter_bot.read_report(skybolt.OUTPUT / 'data' / f't{tier}-{cohort}-{arm}.json.gz')
                rows = raw['results']
                records[arm] = rows
                self.assertEqual(len(rows), 150)
                for t in ('1', '2', '3'):
                    expected = baseline['decks'][t] + ([addition['card']] if addition else [])
                    self.assertEqual(raw['decks'][t], expected)
                self.assertEqual(raw['defaults'], baseline['defaults'])
                self.assertEqual([skybolt.identity(r) for r in rows], [skybolt.identity(r) for r in baseline['results']])
                for before, row in zip(baseline['results'], rows):
                    for key in ('revision', 'cohort', 'tier', 'biome', 'objective', 'travel_dir', 'encounter_id'):
                        self.assertEqual(row[key], before[key])
                    u = row['card_usage']
                    casts = u['casts'].get('skybolt', 0)
                    if addition.get('card') == 'skybolt':
                        self.assertEqual(u['origin_metric'], 'caster_v1')
                    if arm in ('V1', 'V5'):
                        self.assertTrue(row['primary_only_shock_adapter'])
                    if arm in ('V2', 'V5'):
                        self.assertLessEqual(casts, 1, 'the single Exhaust copy cannot be replayed')
                    for key in ('skybolt_casts_beyond_5', 'skybolt_casts_without_los'):
                        self.assertLessEqual(u[key], casts)
                    for key in ('skybolt_hits_beyond_5', 'skybolt_hits_without_los'):
                        self.assertLessEqual(u[key], u['skybolt_hits'])


if __name__ == '__main__':
    unittest.main()
