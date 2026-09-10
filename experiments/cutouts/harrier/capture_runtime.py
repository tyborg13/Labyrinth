"""Task-local capture packaging with real runner validation and fresh input digests."""
from pathlib import Path
import argparse,json,shutil,subprocess,sys
PROJECT=Path(__file__).resolve().parents[3];sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.proof import input_hashes
from cutout_pipeline.cases import digest
p=argparse.ArgumentParser();p.add_argument('kind',choices=['assets','gameplay']);p.add_argument('output',type=Path);args=p.parse_args()
out=args.output.resolve();out.mkdir(parents=True,exist_ok=False)
case=PROJECT/'experiments/cutouts/harrier/v02'
script='tests/harrier_cutout_'+('asset_probe.gd' if args.kind=='assets' else 'gameplay_probe.gd')
def sources():
    result=input_hashes(case);result['probe:'+script]=digest(PROJECT/script);return result
before=sources();(out/'capture_input_sha256.json').write_text(json.dumps(before,indent=2)+'\n')
result=out/'visual_probe_result.json'
command=[sys.executable,'tools/visual_probe_runner.py',script,'--task-id','animate-harrier-cutout','--no-headless','--display-driver','macos','--rendering-method','mobile','--rendering-driver','metal','--timeout','240' if args.kind=='gameplay' else '180','--gui-lease-timeout','1800','--expect-size','1920x1080' if args.kind=='gameplay' else '512x512','--result-manifest',str(result)]
with (out/'capture.log').open('w') as log:subprocess.run(command,cwd=PROJECT,stdout=log,stderr=subprocess.STDOUT,check=True)
assert sources()==before,'Capture inputs changed; keep failure and use fresh output'
r=json.loads(result.read_text());assert r['ok']
source=Path(r['attempts'][-1]['images'][0]['path']).parent
marker='manifest.json' if args.kind=='gameplay' else 'comparison.json'
while not (source/marker).is_file():
    assert source!=source.parent,'Missing native manifest'
    source=source.parent
shutil.copytree(source,out,dirs_exist_ok=True)
print('Accepted',args.kind,'proof at',out)
