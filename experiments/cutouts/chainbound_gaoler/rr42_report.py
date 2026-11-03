"""Compact, hash-bound handoff receipts; full diagnostics remain local."""
from collections import Counter
from pathlib import Path
import argparse
import shutil
from rr42_underlay import CASE, PROJECT
from rr42_density import PROOF_CASE
from cutout_pipeline.cases import read_json,write_json,digest

LOGS={'focused':'/private/tmp/rr42-focused.log','reference_focused':'/private/tmp/rr42-reference-focused.log',
      'python_full':'/private/tmp/rr42-python-full-final.log','godot_full':'/private/tmp/rr42-godot-full-final.log',
      'registration':'/private/tmp/rr42-registration.log','runtime':'/private/tmp/rr42-runtime.log',
      'canvas':'/private/tmp/rr42-canvas.log','density':'/private/tmp/rr42-density-check.log',
      'shadow':'/private/tmp/rr42-shadow.log','rest':'/private/tmp/rr42-rest.log',
      'enemy_no_action_retry':'/private/tmp/rr42-enemy-no-action.log',
      'art_identity':'/private/tmp/rr42-art-identity.log','sidecars':'/private/tmp/rr42-sidecars.log','all_gates':'/private/tmp/rr42-all-gates.log',
      'exposure_witness':'/private/tmp/rr42-exposure-witness.log',
      'density_focused_final':'/private/tmp/rr42-density-focused-final.log'}


def collect():
    path=PROOF_CASE/'proof/logs/rr42_sweep.json';sweep=read_json(path)
    counts=Counter((r['view'],r['clip'],','.join(r['kinds'])) for r in sweep['frames'])
    summary={'native_pixels':False,'sweep_sha256':digest(path),'frames':len(sweep['frames']),
             'findings':len(sweep['errors']),'per_clip':[{'view':v,'clip':c,'kinds':k,'frames':n} for (v,c,k),n in sorted(counts.items())],
             'motion_clamps':[],'acceptance':'STOP: death floor still tears; source/native gates are not waived',
             'floor_candidates':{},'logs':{}}
    holes=[]
    seen=set()
    for row in sweep['frames']:
        if row['view']!='rear' or not row['metrics'].get('uncovered_missing_pixels'):continue
        if row['clip'] in seen:continue
        seen.add(row['clip'])
        holes.append({k:row[k] for k in ('view','clip','frame','metrics','source_space','crop')})
    write_json(CASE/'proof/rear_holes.json',{'native_pixels':False,'diagnostic_case':str(PROOF_CASE.relative_to(PROJECT)),'holes':holes,'rule':'report only; no rear paint synthesized'})
    for name in ('press_hip-rest','death_relaxed','death_all-rest'):
        root=CASE/'proof/limits'/name;report=root/'proof/logs/rr42_sweep.json'
        result=read_json(report)
        summary['floor_candidates'][name]={'case':str(root.relative_to(PROJECT)),'frames':len(result['frames']),'findings':len(result['errors']),
            'scales':read_json(root/'channel_scales.json'),'report_sha256':digest(report),
            'first_front_failure':next(({k:r[k] for k in ('frame','metrics','source_space','crop')} for r in result['frames'] if r['view']=='front' and r['kinds']),None)}
    output=CASE/'proof/logs/final';output.mkdir(parents=True,exist_ok=True)
    for name,source in LOGS.items():
        source=Path(source)
        if not source.exists():continue
        target=output/(name+'.log');shutil.copyfile(source,target)
        text=target.read_text(errors='replace').splitlines()
        important=[line for line in text if any(word in line for word in ('Ran ','FAILED','\nOK','CHECK-OK','REGISTRATION AUDIT:','CALIBRATION:','PASS (','TEST RESULT','TESTS PASSED','TESTS FAILED','PROGRAM SUITE RESULT')) or line=='OK']
        summary['logs'][name]={'file':str(target.relative_to(CASE)),'sha256':digest(target),'result_lines':important[-16:]}
    write_json(CASE/'proof/rr42_receipts.json',summary)
    print('RR42 HANDOFF RECEIPTS: WRITTEN (native_pixels=False; acceptance blocked)')


if __name__=='__main__': collect()
