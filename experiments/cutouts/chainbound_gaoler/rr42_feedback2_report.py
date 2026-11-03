"""Compact final-round evidence; original native capture remains immutable."""
from collections import Counter
from pathlib import Path
import re
import shutil
from rr42_underlay import CASE,PROJECT
from rr42_retained import FIXTURE,SOURCE_MANIFEST_SHA256
from cutout_pipeline.cases import read_json,write_json,digest

LOGS={
    'import_initial':'rr42-r2-import.log','import':'rr42-r2-import-final.log',
    'calibration':'rr42-r2-calibration-final-report.log','unit':'rr42-r2-unit-cold-final.log',
    'compatibility':'rr42-r2-compatibility.log','godot_full':'rr42-r2-godot-full.log',
    'godot_initial_pass':'rr42-r2-godot-full-before-default-fix.log',
    'godot_concurrent_load':'rr42-r2-godot-concurrent-load.log',
    'transition_suite_timeout':'rr42-r2-transition-suite.log',
    'transition_focused':'rr42-r2-transition-isolated.log',
    'python_full':'rr42-r2-python-full-final.log',
    'python_before_default_fix':'rr42-r2-python-full-before-default-fix.log',
    'raster_regression':'rr42-r2-raster-regression-final.log',
    'historical_motion':'rr42-r2-historical-motion-failure.log',
    'sweep':'rr42-r2-sweep-post-cache-fix.log',
    'native_gates':'rr42-r2-native-post-cache-fix.log','source_gates':'rr42-r2-source-gates.log',
    'native_cache_reuse':'rr42-r2-native-cache-reuse.log',
    'sheets':'rr42-r2-sheets.log','review':'rr42-r2-review.log','registration':'rr42-r2-registration.log'}


def collect():
    case=CASE/'proof/production_case';sweep_path=case/'proof/logs/rr42_sweep.json'
    gates=read_json(case/'proof/native_gates.json');sweep=read_json(sweep_path)
    if gates['sweep_sha256']!=digest(sweep_path):raise ValueError('Native gates do not bind the final sweep')
    calibration=read_json(CASE/'proof/feedback2_calibration.json')
    tucks=read_json(CASE/'proof/feedback2_tucks.json')['texels']
    result=dict(native_pixels=True,retained=True,new_windowed_run=False,
                source_native_manifest_sha256=SOURCE_MANIFEST_SHA256,
                fixture_sha256=digest(FIXTURE/'manifest.json'),calibration=calibration,
                sweep=dict(frames=len(sweep['frames']),findings=len(sweep['errors']),
                           painted_exposure=sweep['all_rounding'],sha256=digest(sweep_path)),
                native_gates=gates,tuck_texels=len(tucks),
                tuck_receipt_sha256=digest(CASE/'proof/feedback2_tucks.json'),
                tuck_counts=dict(Counter(r['tuck'] for r in tucks)),
                motion_changes=[],art_changes=[],unresolved_design_questions=[],
                chosen_defaults=dict(cold_import_timeout_seconds=900,full_godot_timeout_seconds=1800,
                                     invalid_native_rgba=[254,7,199,255],
                                     analysis_mutation_sha256='0'*64,render_mutation_sha256='1'*64,
                                     cache_fixture_model='constructed cache validation only'),logs={})
    output=CASE/'proof/logs/feedback2_final';output.mkdir(parents=True,exist_ok=True)
    for name,filename in LOGS.items():
        source=Path('/private/tmp')/filename
        if not source.exists():raise ValueError('Missing final log: '+str(source))
        target=output/(name+'.log');shutil.copyfile(source,target)
        lines=target.read_text(errors='replace').splitlines()
        markers=('RR42 ','RR10 SHEETS:','RR10 REVIEW:','Ran ','FAILED','FULL SUITE RUNTIME:',
                 'MAIN BODY ASSERTIONS:','TEST REGISTRATION AUDIT:')
        important=[line for line in lines if line in ('OK','TEST RESULT: PASS') or line.startswith(('OK (',*markers))]
        result['logs'][name]=dict(file=str(target.relative_to(CASE)),sha256=digest(target),result_lines=important[-12:])
        if name=='python_full':
            summary=[line for line in lines if re.match(r'^Ran \d+ tests in ',line)]
            if not summary:raise ValueError('Full Python suite has not completed')
            result['python_summary']=summary[-1]
            result['python_failure_headers']=[line for line in lines if re.match(r'^(?:FAIL|ERROR): test_',line)]
            result['python_skipped_tests']=[line for line in lines if re.match(r'^test_.* \.\.\. skipped ',line)]
            result['python_skipped_count']=len(result['python_skipped_tests'])
        if name=='godot_full':
            summary=[line for line in lines if line.startswith('FULL SUITE RUNTIME:')]
            verdict=[line for line in lines if line.startswith('TEST RESULT:')]
            if not summary or not verdict:raise ValueError('Full Godot suite has not completed')
            result['godot_summary']=summary[-1];result['godot_result']=verdict[-1]
    result['known_bootstrap']=read_json(CASE/'proof/feedback2_bootstrap.json')
    result['baseline_failures']=read_json(CASE/'proof/feedback2_baseline_failures.json')
    result['concurrent_godot']=read_json(CASE/'proof/feedback2_concurrent_godot.json')
    for mode,artifact in [('sheets',CASE/'proof/contact_sheets/manifest.json'),
                          ('review',CASE/'proof/chainbound_gaoler_review.json')]:
        record=read_json(artifact)
        if not record['ok']:raise ValueError('Composition did not pass: '+mode)
        result[mode]=dict(manifest=str(artifact.relative_to(PROJECT)),sha256=digest(artifact),frames=record['frames'])
    write_json(CASE/'proof/feedback2_receipts.json',result)
    print('RR42 FEEDBACK2 RECEIPTS: WRITTEN (native_errors=%d; no art or motion changes)'%gates['error_count'])


if __name__=='__main__':collect()
