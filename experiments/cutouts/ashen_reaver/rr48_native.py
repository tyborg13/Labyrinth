"""Native gates with complete grids and approved in-hand seam classification."""
import argparse
from pathlib import Path
from rr48_build import CASE
from rr48_native_baseline import capture_errors,compare,HeldBaseline
from humanoid_cutout.gates import native_errors
from humanoid_cutout.canvas import for_case
from cutout_pipeline.cases import read_json,write_json,digest


def evaluate(case,capture,baseline=None):
    surface=None
    if (case/'feedback3_policy.json').exists():
        from rr48_feedback3_native import NativeDirectorPolicy
        surface=NativeDirectorPolicy
    with for_case(case):errors=native_errors(case,capture,surface_policy_factory=surface)
    from rr48_feedback_gates import native_floor_errors
    floor=native_floor_errors(case,capture);errors+=floor['errors']
    active=baseline.classify(errors) if baseline else errors
    if baseline and not baseline.comparison['ok']:
        active.append('in-hand native grid differs from approved held baseline: '+str(baseline.comparison['differing_pixels'])+' pixels')
    report={'ok':not active,'errors':active,'baseline_findings':baseline.findings if baseline else [],'painted_floor':floor,'native_pixels':True,'native_manifest_sha256':digest(capture/'frames.json')}
    if baseline:report['held_comparison']=baseline.comparison
    write_json(case/'proof/native_gates.json',report)
    print(f'RR48 NATIVE GATES: {"FAIL" if active else "PASS"} ({len(active)} errors; {len(report["baseline_findings"])} approved baseline findings)')
    for finding in report['baseline_findings']:print('RR57 BASELINE:',finding['finding'],'(0 differing pixels)')
    for error in active[:30]:print(error)
    return active


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--native',type=Path,required=True);p.add_argument('--baseline',type=Path);p.add_argument('--sheets',type=Path);p.add_argument('--drops',type=Path);a=p.parse_args()
    motion=read_json(a.case/'compiled_motion.json');errors=capture_errors(a.native,motion)
    if a.baseline:errors+=capture_errors(a.baseline,motion)
    if errors:
        write_json(a.case/'proof/native_gates.json',{'ok':False,'errors':errors,'stage':'capture preflight','native_pixels':False})
        print('RR48 NATIVE GATES: FAIL (capture preflight)')
        for error in errors:print(error)
        return 1
    baseline=None
    if a.baseline:
        try:baseline=HeldBaseline(compare(a.baseline,a.native,motion))
        except (OSError,ValueError) as error:print('RR48 NATIVE GATES: FAIL\n'+str(error));return 1
    if a.sheets:
        from humanoid_cutout.proof import compose
        record=compose(a.case,a.native,a.sheets,'sheets',diagnostic=True,native_gate=lambda case,capture:evaluate(case,capture,baseline))
        if a.drops:
            from rr48_weapon_proof import drops
            drops(a.native,a.drops)
        return int(not record['ok'])
    return int(bool(evaluate(a.case,a.native,baseline)))

if __name__=='__main__':raise SystemExit(main())
