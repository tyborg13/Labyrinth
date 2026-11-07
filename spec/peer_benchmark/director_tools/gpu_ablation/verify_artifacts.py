"""Audit prepared commands and observed headless evidence; no test suite/GUI."""
from pathlib import Path
import argparse
import ast
import hashlib
import json
import sys

sys.dont_write_bytecode = True
from proof import ROOT, SOURCE, TOOLS, STATES, COMMON_ARMS, verify_binding, save
from report import validate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--headless-dir', type=Path, default=ROOT / 'headless-v2')
    args = parser.parse_args()
    verify_binding()
    python_files = list(TOOLS.glob('*.py'))
    for path in python_files:
        ast.parse(path.read_text(), filename=str(path))
    sys.path.insert(0, str(SOURCE / 'tools'))
    from visual_probe_runner import load_proof_contract
    for state in STATES:
        contract = load_proof_contract(str(TOOLS / ('proof-' + state + '.json')))
        assert contract['expected_sizes'] == ['1280x800'] and contract['min_images'] == 1
    plan = json.loads((ROOT / 'native_commands.json').read_text())
    absent = []
    for state in STATES:
        arms = [r['arm'] for r in plan['arms'] if r['state'] == state]
        assert arms[0] == 'baseline_a' and arms[-1] == 'baseline_b'
        assert set(COMMON_ARMS) <= set(arms)
        if state.startswith('character_'):
            assert {'paper_doll', 'card_strips', 'skill_tree'} <= set(arms)
    for entry in plan['arms']:
        state, arm, cmd = entry['state'], entry['arm'], entry['command']
        assert cmd[1] == 'tools/visual_probe_runner.py'
        assert cmd[cmd.index('--rendering-driver') + 1] == 'vulkan'
        assert cmd[cmd.index('--rendering-method') + 1] == 'mobile'
        assert cmd[cmd.index('--attempts') + 1] == '1'
        assert '--state=' + state in cmd and '--arm=' + arm in cmd
        d = args.headless_dir / state / arm
        case = json.loads((d / (state + '.json')).read_text())
        index = json.loads((d / 'index.json').read_text())
        assert index['headless'] and not index['gpu_measurements_available'] and not index['errors'], str(d)
        assert case['headless'] and len(case['frames']) == 3, str(d)
        assert all(v['api_gpu_ms'] is None and v['api_cpu_ms'] is None for f in case['frames'] for v in f['viewports'].values()), str(d)
        audit = case['measurement_audit']
        assert audit['main_viewport_found'] and audit['live_viewports'] == audit['measurement_enable_requests'], str(d)
        assert case['viewport_catalog'][case['main_viewport_rid']]['is_main'], str(d)
        for f in case['frames']:
            context = f['submission_context']
            assert context['phase'] == ('action' if state == 'dragon_action' else 'steady'), str(d)
            if state == 'dragon_action': assert context['animation_lock'] and context['enemy_action'], str(d)
        if not arm.startswith('baseline_'):
            if case['notes']['ablation']['target_present']:
                assert case['notes']['ablation']['ever_affected_paths'], str(d)
            else: absent.append(state + '/' + arm)
        # The report must explicitly reject this real headless evidence.
        assert 'headless fixture is not GPU evidence' in validate(case, index, state, arm)
    summary = json.loads((ROOT / 'tables/summary.json').read_text())
    assert summary['status'] == 'pending_native' and not summary['top_five'] and not summary['invalid']
    assert all(r['main_median_ms'] is None and r['delta_median_ms'] is None for r in summary['arms'])
    save(ROOT / 'tool_hashes.json', {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in TOOLS.iterdir() if p.is_file()})
    save(ROOT / 'artifact_audit.json', {'headless_dir': str(args.headless_dir), 'states': len(STATES), 'arms': len(plan['arms']), 'absent_noop_targets': absent, 'python_files': len(python_files), 'native_runs': 0, 'status': 'pass'})
    print('SD-12 ARTIFACT AUDIT: PASS python_files=%d states=%d arms=%d contracts=6 headless_times=null native_rejected=all native_runs=0 fabricated_values=0' % (len(python_files), len(STATES), len(plan['arms'])))
    print('SD-12 ABSENT TARGETS: %s' % (', '.join(absent) if absent else 'none'))


if __name__ == '__main__':
    main()
