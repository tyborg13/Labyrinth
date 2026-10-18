"""Explicit, serial, fail-closed native-solid delivery through the owner bridge.

An unanswered/refused job stops the entire workflow. No fit, curation or replay
pass is manufactured when native evidence is absent. Existing figures can be
regenerated separately with the unchanged regenerate_delivery entry point.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys

from .bridge_client import run_job
from .compile_recipe import compile_recipe, PROJECT
from .contract import digest
from .curate_delivery import stage, curate, write
from .delivery_validation import seal_delivery, validate_delivery
from .solid_review import review

WORKFLOW_DEFAULTS = {'job_timeout_s': 900, 'review_owner_index': 1}


def native_job(folder, name, script, values):
    folder=Path(folder)
    output=folder/'proof/bridge'
    output.mkdir(parents=True,exist_ok=True)
    result=run_job(Path(__file__).with_name(script),[str(v) for v in values],
                   timeout_s=WORKFLOW_DEFAULTS['job_timeout_s'])
    write(output/(name+'.json'),{k:v for k,v in result.items() if k!='stdout'})
    (output/(name+'.log')).write_text(result['stdout'])
    print('SOLID_WORKFLOW: '+folder.name+'/'+name+'; exit='+str(result['exit']),flush=True)
    if result['exit'] or result.get('refused'):
        raise ValueError('Native stage failed; inspect '+str(output/(name+'.log')))


def build_and_prove(folder):
    folder=Path(folder)
    recipe=json.loads((folder/'measurements.json').read_text())
    spec=compile_recipe(recipe)
    spec_path=folder/'spec_native.json'
    write(spec_path,spec)
    capture=folder/'proof/native'
    if capture.exists() and any(capture.iterdir()):
        raise ValueError('Use an empty native proof directory; retain/hash previous evidence first')
    native_job(folder,'capture','build.py',[spec_path,capture])
    proof=capture/'determinism'
    native_job(folder,'cold_replay','recipe_proof.py',[spec_path,proof])
    native_job(folder,'exact_replay','exact_native_replay.py',[proof,proof/'exact_native_replay.json'])
    job=folder/'proof/native_validation_job.json'
    write(job,[{'spec':str(spec_path),'build':str(capture)}])
    native_job(folder,'material_mutation','native_delivery_checks.py',[job,folder/'proof/native_validation.json'])
    from .compact_capture import compact_capture
    compact_capture(spec,capture)
    seal_delivery(spec,capture)
    validate_delivery(spec,capture)
    stage(folder,capture)
    validate_delivery(spec,folder/'delivery')
    validation=folder/'delivery/validation'
    validation.mkdir(exist_ok=True)
    shutil.copyfile(folder/'proof/native_validation.json',validation/'native_validation.json')
    shutil.copytree(folder/'proof/bridge',validation/'bridge',dirs_exist_ok=True)
    return spec


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders',nargs='+',type=Path)
    parser.add_argument('--curate',action='store_true',help='Hash and discard generated blends/caches/proof after all gates pass')
    args=parser.parse_args()
    folders=[p.resolve() for p in args.folders]
    root=PROJECT/'spec/art_identity/maquettes'
    if len(set(folders))!=len(folders) or any(p.parent!=root for p in folders):
        raise ValueError('Explicit distinct figure folders must belong to this worktree')
    for folder in folders:build_and_prove(folder)
    review_owner=folders[min(WORKFLOW_DEFAULTS['review_owner_index'],len(folders)-1)]
    passed=review(folders,review_owner/'delivery/review')
    if not passed:
        raise ValueError('Native fit or coverage failed; retained for implementation correction')
    # The fresh input-only regeneration is deliberately after source staging.
    # It compares both clay and part-map PNGs and independently validates the
    # new native reports against the cold build before discarding any build.
    from . import regenerate_delivery
    for folder in folders:
        output=folder/'proof/regeneration'
        with _arguments(['regenerate_delivery',str(folder),'--out',str(output),'--verify','--discard-build']):
            code=regenerate_delivery.main()
        if code:raise ValueError('Fresh regeneration differs: '+folder.name)
        validation=folder/'delivery/validation/regeneration'
        shutil.copytree(output,validation,dirs_exist_ok=True)
    if args.curate:
        for folder in folders:curate(folder)
    print('SOLID_NATIVE_DELIVERY: PASS; figures='+str(len(folders)))
    return 0


class _arguments:
    def __init__(self,values):self.values=values
    def __enter__(self):self.previous=sys.argv;sys.argv=self.values
    def __exit__(self,*_):sys.argv=self.previous


if __name__=='__main__':
    try:raise SystemExit(main())
    except (ValueError,TimeoutError,OSError) as error:
        print('SOLID_WORKFLOW_ERROR: '+str(error),file=sys.stderr)
        raise SystemExit(2)
