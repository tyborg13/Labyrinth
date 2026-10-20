"""Actual resolver/playback progression, contacts, cues and outcome gates."""
import argparse
from pathlib import Path
from case import CASE, read_json, write_json
from humanoid_cutout.production_gates import production_errors

EPSILON = 0.000001  # Existing serialized contact phase tolerance.
ATTACK_CLIPS = ('bolt', 'mirror')


def feedback_cues(row):
    # Existing melee preparation owns its swing cue before the pose starts;
    # an embedded approach also owns footsteps. Impact/cast cues belong at
    # contact. Preserve these established cue families without retiming them.
    return [c for c in row['sfx_cues'] if not c['cue'].startswith(('step.', 'swing.'))]


def errors(report):
    data = read_json(CASE/'compiled_motion.json')
    result = production_errors(CASE, report, data)
    for clip in ('bolt', 'mirror', 'block'):
        rows = [r for r in report['frames'] if r['stage'] == clip]
        contact = data['clips'][clip]['contact']
        before = [r for r in rows if r['snapshot']['phase'] < contact - EPSILON]
        at = [r for r in rows if abs(r['snapshot']['phase'] - contact) < EPSILON]
        if not before or not at: result.append(clip + ': missing before/contact evidence')
        if any(r['effect'] for r in before): result.append(clip + ': VFX before contact')
        if clip in ATTACK_CLIPS:
            if any(not r['effect'] for r in at): result.append(clip + ': missing VFX at contact')
            for row in before:
                if feedback_cues(row): result.append(clip + ': feedback cue before contact')
            if not any(feedback_cues(row) for row in at): result.append(clip + ': missing existing cue at contact')
            if before and len({r['player_hp'] for r in before}) != 1: result.append(clip + ': outcome changed before contact')
        if clip == 'block' and before and at and max(r['enemy_block'] for r in at) <= min(r['enemy_block'] for r in before):
            result.append('block: guard outcome missing at contact')
    return sorted(set(result))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', required=True, type=Path)
    args = parser.parse_args()
    report = read_json(args.input)
    failures = errors(report)
    write_json(args.input.parent/'verification.json', {'ok': not failures, 'errors': failures,
        'native_pixels': report['native_pixels'], 'frames': len(report['frames'])})
    print('RR20 PRODUCTION %s: %s (%d frames; %d errors)' % ('NATIVE' if report['native_pixels'] else 'LOGIC', 'PASS' if not failures else 'FAIL', len(report['frames']), len(failures)))
    for error in failures: print(error)
    return int(bool(failures))


if __name__ == '__main__': raise SystemExit(main())
