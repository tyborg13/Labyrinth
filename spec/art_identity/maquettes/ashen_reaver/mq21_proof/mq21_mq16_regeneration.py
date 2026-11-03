"""Successor mq-16 proof; the historical delivery is strictly read-only."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from ..source_measurements import FOLDER,PROJECT
from ..recipe import compile_spec
from ..capture_workflow import capture
from ..bridge import job


def verify_history():
    record=json.loads((FOLDER/'mq21_historical_delivery.json').read_text())
    actual={str(p.relative_to(FOLDER/'delivery')):sha(p) for p in (FOLDER/'delivery').rglob('*') if p.is_file()}
    if actual!=record['files']:raise ValueError('Historical mq-16 delivery bytes changed')
    return actual


def regenerate(output):
    from .workflow import inventory,copy_sources,PROOF_DEFAULTS,verify_fresh_pixels
    from ..acceptance import inspect
    from ..validation import compare_blade_masks
    verify_history();output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('mq-16 regeneration needs a fresh empty output')
    project=output/'clean_project';inputs=inventory()
    if copy_sources(project)!=inputs:raise ValueError('mq-16 clean input copy differs')
    code=('from pathlib import Path\n'
          'from spec.art_identity.maquettes.ashen_reaver.recipe import compile_spec,FOLDER\n'
          'from spec.art_identity.maquettes.blender.curate_delivery import write\n'
          'assert FOLDER.is_relative_to(Path.cwd()), "Compiler escaped clean checkout"\n'
          'write(Path("spec_native.json"),compile_spec())\n')
    run=subprocess.run([sys.executable,'-B','-c',code],cwd=project,text=True,capture_output=True,
                       timeout=PROOF_DEFAULTS['source_timeout_seconds'])
    (output/'source_compile.log').write_text(run.stdout+run.stderr)
    if run.returncode:raise ValueError('mq-16 clean compilation failed')
    spec=compile_spec();path=project/'spec_native.json'
    if json.loads(path.read_text())!=spec:raise ValueError('mq-16 clean source geometry differs')
    figure=project/FOLDER.relative_to(PROJECT)
    job(figure.parent/'blender/build.py',[path,output/'native','--build-only'],output/'bridge','build')
    dest=capture(path,output,figure/'capture.py')
    job(figure/'native_probe.py',[path,output/'native',dest/'native_probe.json'],output/'bridge','native_probe')
    for name in ('recipe_proof.json','exact_native_replay.json'):shutil.copyfile(FOLDER/'delivery'/name,dest/name)
    acceptance=inspect(spec,dest);compared=compare_captures(dest,FOLDER/'delivery',output,True)
    compare_blade_masks(dest,FOLDER/'delivery',compared)
    native=json.loads((dest/'native_probe.json').read_text())
    result={'passed':acceptance['passed'] and all(row['passed'] for passes in compared.values() for row in passes.values()),
        'spec_hash':digest(spec),'views':compared,'input_sha256':inputs,'source_recompiled':True,
        'cache_reused':False,'saved_model_reused':False,'native_mesh_hash':native['native_mesh_hash']}
    if not result['passed']:raise ValueError('mq-16 clean regeneration differs')
    verify_fresh_pixels(result,FOLDER/'delivery')
    target=FOLDER/'mq21_delivery/validation/mq16';target.mkdir(parents=True,exist_ok=True)
    write(target/'regeneration.json',result)
    for source,name in ((output/'source_compile.log','source_compile.log'),(dest/'native_probe.json','native_probe.json'),
                        (dest/'capture_manifest.json','capture_manifest.json')):shutil.copyfile(source,target/name)
    shutil.copytree(output/'bridge',target/'bridge',dirs_exist_ok=True)
    verify_history();verify()
    print('MQ16_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; blade_area_masks=2/2; cache_reused=false; historical_delivery_unchanged=true')
    return result


def verify():
    from .workflow import inventory,verify_fresh_pixels
    verify_history();target=FOLDER/'mq21_delivery/validation/mq16';spec=compile_spec()
    result=json.loads((target/'regeneration.json').read_text())
    if (result.get('passed') is not True or result.get('spec_hash')!=digest(spec) or result.get('input_sha256')!=inventory()
            or result.get('source_recompiled') is not True or result.get('cache_reused') is not False
            or result.get('saved_model_reused') is not False):raise ValueError('Stale mq-16 successor regeneration')
    verify_fresh_pixels(result,FOLDER/'delivery')
    native=json.loads((target/'native_probe.json').read_text());build=json.loads((FOLDER/'delivery/build_report.json').read_text())
    if (native.get('passed') is not True or native.get('spec_hash')!=digest(spec)
            or native.get('native_mesh_hash')!=build['combined_mesh_hash']
            or result.get('native_mesh_hash')!=native['native_mesh_hash']):raise ValueError('mq-16 successor native geometry differs')
    manifest=json.loads((target/'capture_manifest.json').read_text())
    if manifest.get('spec_hash')!=digest(spec):raise ValueError('Stale mq-16 successor capture')
    for view,passes in result['views'].items():
        for kind,row in passes.items():
            if row['native_file_sha256']!=manifest['images'][view+'_'+kind+'.png']['sha256']:
                raise ValueError('mq-16 successor capture binding differs')
    receipts=list((target/'bridge').glob('*.json'))
    if not receipts:raise ValueError('Missing mq-16 successor bridge receipts')
    for path in receipts:
        row=json.loads(path.read_text())
        if row.get('exit')!=0 or row.get('timeout_s')!=110 or row.get('response_timeout_s')!=120:
            raise ValueError('Failed or unbounded mq-16 successor bridge receipt')
    print('MQ16_SUCCESSOR_REGENERATION: PASS; historical_files='+str(len(verify_history())))
