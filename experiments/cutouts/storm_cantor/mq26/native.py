"""Director native gate and strict CPU-superset calibration (on demand)."""
import argparse
from pathlib import Path
from build import CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import native_errors,bindings
from humanoid_cutout.canvas import for_case
from surface_policy import NativePolicy
from cloth_rags import RagComponentPolicy
p=argparse.ArgumentParser();p.add_argument('--case',type=Path,default=CASE);p.add_argument('--native',type=Path,required=True);a=p.parse_args()
# Changed cuts/poses cannot be judged against a stale surface inventory. Fail
# with a verdict before missing/renamed layers can raise StopIteration.
manifest=read_json(a.native/'frames.json')
if manifest.get('inputs')!=bindings(a.case):
    errors=['Stale native capture: rerun density, rest and native for the current cut/motion inputs']
    write_json(a.case/'proof/native_gates.json',{'ok':False,'errors':errors,'native_pixels':True,'stale':True})
    print('RR56 NATIVE GATES: STALE (1 errors; capture rejected before pixel evaluation)')
    raise SystemExit(1)
space=[];holes=[]
with for_case(a.case):errors=native_errors(a.case,a.native,hole_details=holes,space_details=space,surface_policy_factory=NativePolicy,release_policy_factory=RagComponentPolicy)
# CPU must catch at least every native rejected pocket. Missing/stale CPU data fails.
path=a.case/'proof/cpu_sweep.json';cpu=read_json(path) if path.exists() else {};misses=[]
fresh=cpu.get('inputs')==bindings(a.case) and cpu.get('samples_sha256')==digest(a.case/'proof/raster_samples.json')
if not fresh:errors.append('CPU superset: stale input bindings or sampled poses')
index={(r['view'],r['clip'],r['frame']):r for r in cpu.get('diagnostics',[])}
from cpu_native_superset import pocket_report
pockets=pocket_report(cpu,holes);misses=pockets['missing']
if not index:errors.append('CPU superset: missing sweep diagnostics')
if misses:errors.append(f'CPU superset: {len(misses)} missed native pockets')
outline_misses=[]
for view in ('front','rear'):
    for n in read_json(a.case/f'proof/native_outline_{view}.json'):
        if not n['rejected_pixels']:continue
        candidates=index.get((n['view'],n['clip'],n['frame']),{}).get('outline',[])
        b=n['bbox']
        if not any(c['part']==n['part'] and c['pixels']>=n['rejected_pixels'] and c['bbox'][0]<=b[0] and c['bbox'][1]<=b[1] and c['bbox'][2]>=b[2] and c['bbox'][3]>=b[3] for c in candidates):outline_misses.append(n)
if outline_misses:errors.append(f'CPU superset: {len(outline_misses)} missed native outline records')
from cpu_native_superset import report as component_superset
components=component_superset(a.case,a.native,manifest,cpu,space,errors)
if not components['ok']:errors.append(f'CPU superset: {len(components["missing"])} missed native component/release locations')
write_json(a.case/'proof/native_gates.json',{'ok':not errors,'errors':errors,'native_pixels':True,'inputs':manifest['inputs'],'native_manifest_sha256':digest(a.native/'frames.json'),'cpu_superset':{'ok':fresh and bool(index) and not misses and not outline_misses and components['ok'],'components':components,'pocket_sizes':pockets['pixel_count_differences'],'fresh':fresh,'misses':misses,'outline_misses':outline_misses},'native_holes':holes,'native_spaces':space})
print(f'RR56 NATIVE GATES: {"FAIL" if errors else "PASS"} ({len(errors)} errors)')
for e in errors[:20]:print(e)
raise SystemExit(int(bool(errors)))
