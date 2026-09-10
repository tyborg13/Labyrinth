"""Native case proof using maintained validation, preview, packing and verifier.

The first 352-sample capture reached 299 poses before the toolkit's computed
100-second timeout. Keep its normal 8-second startup watchdog; this task uses
180 seconds only for the measured native capture/write workload.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

CASE = Path(__file__).resolve().parents[1]
PROJECT = CASE.parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.proof import input_hashes, pack, verify_render
from cutout_pipeline.validation import validate
from cutout_pipeline.cases import digest, write_json

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--task-id',default='animate-veilbound-acolyte-cutout')
args=parser.parse_args()
out=args.output.resolve()
if out.exists():
    raise SystemExit('Choose a fresh proof output directory')
validation=validate(CASE)
if not validation['ok']:
    raise SystemExit(validation)
before=input_hashes(CASE)
with tempfile.TemporaryDirectory(prefix='veilbound-case-capture-') as scratch:
    result_path=Path(scratch)/'native_result.json'
    command=[sys.executable,str(PROJECT/'tools/visual_probe_runner.py'),'tools/cutout_pipeline/preview.gd','--project',str(PROJECT),'--task-id',args.task_id,'--no-headless','--rendering-method','mobile','--rendering-driver','metal','--expect-size','1920x1080','--expect-size','512x512','--timeout','180','--gui-lease-timeout','1800','--result-manifest',str(result_path),'--','--case',str(CASE/'cutout.json')]
    process=subprocess.run(command,cwd=PROJECT,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
    if process.returncode:
        print(process.stdout)
        raise SystemExit(process.returncode)
    result=json.loads(result_path.read_text())
    if not result.get('ok') or input_hashes(CASE)!=before:
        raise SystemExit('Native result rejected or capture inputs changed')
    raw=next(Path(i['path']).parent for i in result['images'] if Path(i['path']).name=='keyboard_focus.png')
    shutil.copytree(raw,out)
    (out/'native_probe.log').write_text(process.stdout)
    for item in result['images']:
        item['path']=str(Path(item['path']).relative_to(raw))
    for attempt in result['attempts']:
        for item in attempt.get('images',[]):
            item['path']=str(Path(item['path']).relative_to(raw))
    write_json(out/'visual_probe_result.json',result)
    write_json(out/'capture_input_sha256.json',before)
    write_json(out/'case_validation.json',validation)
pack(out)
write_json(out/'proof_sha256.json',{str(p.relative_to(out)):digest(p) for p in sorted(out.rglob('*')) if p.is_file() and p.name!='proof_sha256.json'})
print(json.dumps(verify_render(CASE,out),indent=2))
