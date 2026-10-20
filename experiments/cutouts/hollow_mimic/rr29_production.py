"""Reuse rr20 outcome/cue checks against the rr29 promoted case."""
import argparse
from pathlib import Path
from rr29_build import CASE,read_json,write_json
from humanoid_cutout.production_gates import production_errors
from production import feedback_cues,EPSILON,ATTACK_CLIPS


def verify(path):
    report=read_json(path);data=read_json(CASE/'compiled_motion.json')
    errors=production_errors(CASE,report,data)
    for clip in ('bolt','mirror','block'):
        rows=[r for r in report['frames'] if r['stage']==clip]
        contact=data['clips'][clip]['contact']
        before=[r for r in rows if r['snapshot']['phase']<contact-EPSILON]
        at=[r for r in rows if abs(r['snapshot']['phase']-contact)<EPSILON]
        if not before or not at:errors.append(clip+': missing before/contact evidence')
        if any(r['effect'] for r in before):errors.append(clip+': VFX before contact')
        if clip in ATTACK_CLIPS:
            if any(not r['effect'] for r in at):errors.append(clip+': missing contact VFX')
            if any(feedback_cues(r) for r in before):errors.append(clip+': feedback before contact')
            if not any(feedback_cues(r) for r in at):errors.append(clip+': missing contact cue')
            if before and len({r['player_hp'] for r in before})!=1:errors.append(clip+': outcome before contact')
        if clip=='block' and before and at and max(r['enemy_block'] for r in at)<=min(r['enemy_block'] for r in before):errors.append('block: missing guard outcome')
    write_json(path.parent/'verification.json',{'ok':not errors,'errors':sorted(set(errors)),
        'frames':len(report['frames']),'native_pixels':report['native_pixels']})
    print(f'RR29 PRODUCTION {"NATIVE" if report["native_pixels"] else "LOGIC"}: {"PASS" if not errors else "FAIL"} ({len(report["frames"])} frames; {len(set(errors))} errors)')
    for error in sorted(set(errors)):print(error)
    return not errors


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--input',required=True,type=Path);a=p.parse_args()
    raise SystemExit(int(not verify(a.input)))
