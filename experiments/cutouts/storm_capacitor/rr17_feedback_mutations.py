"""Remove one feedback guard at a time; its regression must reject the mutant.

Run serially, with no other rr17 proof process. Every source is restored byte
for byte in finally; protected director files and Git metadata are untouched.
"""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
OUTPUT = ROOT / 'experiments/cutouts/storm_capacitor/mq5/proof/logs/mutations'
MUTATION_TIMEOUT_SECONDS = 180


def run(name, target, replacement, tests):
    original = None
    path = ROOT / target if target else None
    try:
        if path:
            original = path.read_bytes()
            source = original.decode()
            before, after = replacement
            if source.count(before) != 1: raise AssertionError('Mutation target is ambiguous: ' + name)
            path.write_text(source.replace(before, after))
        command = [sys.executable, '-m', 'unittest', *tests, '-q'] if path else [sys.executable, '-c', tests]
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=MUTATION_TIMEOUT_SECONDS)
        log = process.stdout + process.stderr
        (OUTPUT / (name + '.log')).write_text(log)
        caught = process.returncode != 0 and 'FAIL:' in log and 'SCRIPT ERROR:' not in log and 'setUpClass' not in log
        print(name + ': ' + ('CAUGHT' if caught else 'SURVIVED/INVALID'), flush=True)
        return {'mutation': name, 'caught': caught, 'exit': process.returncode, 'log': str((OUTPUT / (name + '.log')).relative_to(ROOT))}
    finally:
        if path and original is not None: path.write_bytes(original)


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rows = []
    rows.append(run('own_death_clock_removed', 'scripts/maquette_cutout_runtime/death_sequence.gd',
        ('if own.is_empty(): return', 'if true: return'),
        ['tests.test_rr17_feedback.FeedbackTests.test_all_six_paired_deaths_retain_every_base_frame_and_last_frame_time']))
    rows.append(run('crossed_hop_cues_removed', 'assets/units/storm_capacitor_cutout/actions.gd',
        ('while int(clock["cued_hops"]) < count:', 'while false:'),
        ['tests.test_rr17_feedback.FeedbackTests.test_four_hop_cues_normal_reduced_and_skipped_recovery']))
    rows.append(run('production_sampling_guard_removed', 'experiments/cutouts/storm_capacitor/rr17_gates.py',
        ('def production_motion_errors(report):', 'def production_motion_errors(report):\n    return []'),
        ['tests.test_rr17_production.ProductionTests.test_reversed_production_only_death_lean_is_caught_from_fresh_rigs']))
    rows.append(run('production_bindings_guard_removed', 'experiments/cutouts/storm_capacitor/rr17_production.py',
        ("if report.get('inputs') != bindings:", "if False:"),
        ['tests.test_rr17_production.ProductionTests.test_production_bindings_are_required']))
    rows.append(run('production_signed_motion_guard_removed', 'experiments/cutouts/storm_capacitor/rr17_production.py',
        ('if observed is None or not np.allclose(unpack(observed), bone[space], atol=TOLERANCE, rtol=0):', 'if False:'),
        ['tests.test_rr17_production.ProductionTests.test_reversed_production_only_death_lean_is_caught_from_fresh_rigs']))
    rows.append(run('explicit_shadow_baseline_removed', 'experiments/cutouts/storm_capacitor/rr17_shadow_check.gd',
        ('load(args[args.find("--baseline") + 1])', 'load("res://assets/generated/unit_shadow_cache.res")'),
        ['tests.test_rr17_feedback.FeedbackTests.test_shadow_baseline_is_explicit_and_portable']))
    rows.append(run('sidecar_guard_removed', None, None,
        'import unittest; from tests import test_godot_sidecars as s; '
        's.assert_sidecars_versioned = lambda *a, **k: None; '
        'r = unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(s.GodotSidecarGuardTests)); '
        'raise SystemExit(not r.wasSuccessful())'))
    (OUTPUT / 'table.json').write_text(json.dumps(rows, indent=2) + '\n')
    print('RR17 FEEDBACK MUTATIONS: %s (%d/%d caught)' % ('PASS' if all(r['caught'] for r in rows) else 'FAIL', sum(r['caught'] for r in rows), len(rows)))
    return 0 if all(r['caught'] for r in rows) else 1


if __name__ == '__main__':
    raise SystemExit(main())
