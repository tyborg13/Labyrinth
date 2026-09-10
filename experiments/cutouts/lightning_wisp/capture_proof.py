"""Bind Lightning Wisp native/runtime proof to its actual source closure."""
from pathlib import Path
import hashlib, json, sys
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[2]
sys.path.insert(0,str(REPO/'tools'))
from cutout_pipeline.proof import input_hashes
RUNTIME=ROOT/'runtime_v1'
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def inputs():
 result=input_hashes(ROOT/'v01')
 for folder,extensions in [('tests',{'.gd','.json','.tscn'}),('assets',{'.import'})]:
  result.update({'project:'+str(p.relative_to(REPO)):digest(p) for p in sorted((REPO/folder).rglob('*')) if p.is_file() and p.suffix in extensions})
 for name in ['export_presets.cfg','scripts/lightning_wisp_cutout/straight_alpha.gdshader','tools/godot_task_runner.py','tools/visual_probe_runner.py','tools/inspection_fixture.py','tools/inspection_fixture.gd','tools/inspection_fixture_verify.gd','experiments/cutouts/lightning_wisp/capture_proof.py','experiments/cutouts/lightning_wisp/pack_gameplay.py']:
  p=REPO/name
  if p.exists():result['project:'+name]=digest(p)
 return result
def write(path,obj):path.write_text(json.dumps(obj,indent=2)+'\n')
command=sys.argv[1]
if command=='capture':
 write(RUNTIME/'capture_input_sha256.json',inputs()); print('Captured',len(inputs()),'inputs')
elif command=='verify':
 expected=json.loads((RUNTIME/'capture_input_sha256.json').read_text());actual=inputs();changed=[p for p in expected.keys()|actual.keys() if expected.get(p)!=actual.get(p)]; print(json.dumps({'ok':not changed,'inputs':len(actual),'changed':changed},indent=2));sys.exit(bool(changed))
elif command=='seal':
 expected=json.loads((RUNTIME/'capture_input_sha256.json').read_text());actual=inputs()
 if actual!=expected:raise SystemExit('Inputs changed; capture fresh proof')
 write(RUNTIME/'proof_sha256.json',{str(p.relative_to(RUNTIME)):digest(p) for p in sorted(RUNTIME.rglob('*')) if p.is_file() and p.name!='proof_sha256.json'})
 print('Sealed runtime outputs')
