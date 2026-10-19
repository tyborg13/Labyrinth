"""Remove each rr-16 guard, require its regression to fail, restore byte-for-byte."""
import json
import os
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[3]
OUTPUT = PROJECT / 'experiments/cutouts/arc_thrall/rr16/mutations.json'
LOG_FOLDER = Path('/private/tmp/labyrinth_codex/rr-16/mutations')
MUTATIONS = (
    ('3: interval reach refinement', 'tools/humanoid_cutout/reach.py',
     '            refine(target, start, end)', '            pass  # MUTATION: remove between-sample guard',
     'tests.test_rr16_review_fixes.ReviewFixTests.test_short_interior_reach_dip_is_bisected_to_true_minimum'),
    ('4: required direction coverage', 'tools/humanoid_cutout/action_direction.py',
     'for clip in required_clips(layout):', 'for clip in ():',
     'tests.test_rr15_action_direction.ActionDirectionTests.test_zero_forward_channels_fail_required_clip_coverage_with_fresh_bones'),
    ('5: exact pocket matching', 'tools/humanoid_cutout/native_exceptions.py',
     '    remaining = set(approved)',
     '    approved = {entry[:4] for entry in approved}  # MUTATION: frame-wide suppression\n    remaining = set(approved)',
     'tests.test_rr16_review_fixes.ReviewFixTests.test_extra_hole_in_each_approved_frame_is_rejected'),
)


def main():
    LOG_FOLDER.mkdir(parents=True, exist_ok=True)
    rows = []
    for number, (name, filename, original, replacement, test) in enumerate(MUTATIONS, 3):
        path = PROJECT / filename
        before = path.read_bytes()
        source = before.decode()
        if source.count(original) != 1:
            raise ValueError('Mutation anchor must match once: ' + filename)
        try:
            path.write_text(source.replace(original, replacement))
            env = dict(os.environ, LABYRINTH_TASK_ID='rr-16', PYTHONDONTWRITEBYTECODE='1')
            result = subprocess.run([sys.executable, '-B', '-m', 'unittest', test], cwd=PROJECT,
                                    env=env, capture_output=True, text=True)
            log = LOG_FOLDER / ('fix%d.log' % number)
            log.write_text(result.stdout + result.stderr)
            # Require an assertion failure, rather than crediting a crash or launch failure.
            caught = result.returncode != 0 and 'FAIL:' in result.stderr and 'ERROR:' not in result.stderr
            rows.append({'guard': name, 'regression': test, 'status': 'CAUGHT' if caught else 'SURVIVED',
                         'exit_code': result.returncode, 'log': str(log)})
        finally:
            path.write_bytes(before)
            if path.read_bytes() != before:
                raise AssertionError('Mutation restoration failed: ' + filename)
        rows[-1]['restored'] = True
        print('RR16 MUTATION %s: %s (restored)' % (name, rows[-1]['status']), flush=True)
    OUTPUT.write_text(json.dumps(rows, indent=2) + '\n')
    return int(any(row['status'] != 'CAUGHT' for row in rows))


if __name__ == '__main__':
    raise SystemExit(main())
