"""Serial native proof stages; every Blender launch goes through the bridge."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

RUNNER_DEFAULTS={'job_timeout_s':900}
BUILDER=Path(__file__).resolve().parent


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folder',type=Path)
    parser.add_argument('--steps',nargs='+',choices=('proof','exact','capture'),required=True)
    parser.add_argument('--capture-subdir',default='proof/quality_r3')
    args=parser.parse_args()
    folder=args.folder.resolve();capture=folder/args.capture_subdir
    capture.mkdir(parents=True,exist_ok=True)
    spec=folder/'spec_native.json'
    stages={
        'proof':('recipe_proof.py',[spec,capture/'determinism']),
        'exact':('exact_native_replay.py',[capture/'determinism',capture/'determinism/exact_native_replay.json']),
        'capture':('capture_view.py',[spec,capture/'maquette.blend',capture,'both'])}
    original=spec.read_bytes();results=[]
    for stage in args.steps:
        if spec.read_bytes()!=original:raise ValueError('Spec changed during proof')
        script,argv=stages[stage]
        command=[sys.executable,'-B',str(BUILDER/'bridge_client.py'),'--timeout',str(RUNNER_DEFAULTS['job_timeout_s']),str(BUILDER/script),'--',*map(str,argv)]
        log=capture/(stage+'_bridge.log')
        with log.open('w') as stream:result=subprocess.run(command,stdout=stream,stderr=subprocess.STDOUT)
        results.append({'stage':stage,'command':command,'exit':result.returncode,'log':str(log)})
        (capture/'runner_results.json').write_text(json.dumps(results,indent=2)+'\n')
        print('ROUND3_STAGE: '+folder.name+'/'+stage+'; exit='+str(result.returncode),flush=True)
        if result.returncode:return result.returncode
    return 0


if __name__=='__main__':raise SystemExit(main())
