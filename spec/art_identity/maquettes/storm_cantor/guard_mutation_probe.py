"""Reproduce the six review survivors against their specific regression tests.

Each test passes on unchanged sources first. Mutations run serially in fresh
Python processes and must fail an assertion in the named test (an import error,
stale inventory or unrelated delivery failure does not count). Always restore
the source bytes. This is a focused test probe, not a review or engine run.
"""
import json
import subprocess
import sys

from spec.art_identity.maquettes.blender.curate_delivery import write
from .recipe import FOLDER,PROJECT

MUTATION_TIMEOUT_S=45
CASES=(
    ('pose_measurements_echo_targets','native_checks.py',"'measured':float(measured)","'measured':float(target)",
     'SourceGeometryTests.test_perturbed_pose_measurements_match_independent_calculations'),
    ('disable_tabard_fold_guard','volume_checks.py',"checks['three_vertical_tabard_folds']=crests>=d['tabard_vertical_folds']","checks['three_vertical_tabard_folds']=True",
     'SourceGeometryTests.test_flattened_tabard_folds_and_missing_cloak_tails_fail_specific_guards'),
    ('disable_cloak_tail_guard','volume_checks.py',"checks['three_cloak_tails']=tails==d['cloak_tails']","checks['three_cloak_tails']=True",
     'SourceGeometryTests.test_flattened_tabard_folds_and_missing_cloak_tails_fail_specific_guards'),
    ('disable_fork_shape_guard','native_checks.py',"'fork_tine_order_and_curves':bool(fork['outer'][-1,2]>fork['inner'][-1,2]>fork['centre'][-1,2] and fork['outer'][-1,1]<shaft[-1,1] and fork['inner'][-1,1]>shaft[-1,1])","'fork_tine_order_and_curves':True",
     'SourceGeometryTests.test_fork_tine_order_and_elbow_direction_guards_are_independent'),
    ('disable_far_elbow_forward_guard','native_checks.py',"'far_elbow_not_forward':j['elbow_far'][0]<=j['shoulder_far'][0]+NATIVE_DEFAULTS['endpoint_tolerance_m']","'far_elbow_not_forward':True",
     'SourceGeometryTests.test_fork_tine_order_and_elbow_direction_guards_are_independent'),
    ('accept_wrong_volume_targets','volume_checks.py',"or r.get('target_over_H')!=target","",
     'CuratedDeliveryTests.test_every_volume_target_is_required_independently_of_measurement'),
)


def run(test):
    return subprocess.run([sys.executable,'-B','-m','unittest','tests.test_mq17_maquette.'+test,'-q'],
        cwd=PROJECT,text=True,capture_output=True,timeout=MUTATION_TIMEOUT_S)


def main():
    results=[]
    for name,filename,before,after,test in CASES:
        baseline=run(test)
        if baseline.returncode:raise ValueError('Mutation baseline failed: '+test+'\n'+baseline.stdout+baseline.stderr)
        path=FOLDER/filename;original=path.read_bytes();source=original.decode()
        if source.count(before)!=1:raise ValueError('Mutation anchor changed: '+name)
        try:
            path.write_text(source.replace(before,after));mutant=run(test);output=mutant.stdout+mutant.stderr
            caught=(mutant.returncode!=0 and 'FAIL: '+test.split('.')[-1]+' ' in output and 'ERROR:' not in output)
            results.append({'name':name,'test':test,'baseline_exit':baseline.returncode,
                'mutant_exit':mutant.returncode,'caught_by_named_assertion':caught,
                'result_lines':[s for s in output.splitlines() if s.startswith(('FAIL:','ERROR:','Ran ','FAILED'))]})
        finally:path.write_bytes(original)
        if path.read_bytes()!=original:raise ValueError('Source restore failed: '+filename)
    report={'passed':all(r['caught_by_named_assertion'] for r in results),'cases':results,'source_bytes_restored':True}
    write(FOLDER/'feedback2_guard_mutations.json',report)
    print('MQ17_REVIEW_SURVIVORS: '+('PASS' if report['passed'] else 'FAIL')+'; caught='+str(sum(r['caught_by_named_assertion'] for r in results))+'/6; baseline_passed=6/6; sources_restored=true')
    return 0 if report['passed'] else 1


if __name__=='__main__':raise SystemExit(main())
