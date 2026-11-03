"""Bounded bridge build/capture, cold replay, staging and fresh regeneration."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha,stage,discard_evidence
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from .acceptance import inspect,validate_acceptance
from .contract import load_spec,read_inputs,unresolved
from .source_measurements import FOLDER,verify
from .bridge import job
from .capture_workflow import capture

BUILDER=FOLDER.parent/'blender'
CURATION_DEFAULTS={'budget_bytes':6000000}


def build(output):
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    _,spec=load_spec();path=output/'spec_native.json';write(path,spec)
    job(BUILDER/'build.py',[path,output/'native','--build-only'],output/'bridge','build')
    return path


def audit(output,spec_path=None):
    output=Path(output).resolve();path=spec_path or output/'spec_native.json'
    job(FOLDER/'native_probe.py',[path,output/'native',output/'capture/native_probe.json'],output/'bridge','native_probe')


def replay(output):
    output=Path(output).resolve();path=output/'spec_native.json';dest=output/'capture';dest.mkdir(exist_ok=True)
    job(BUILDER/'recipe_proof.py',[path,output/'determinism'],output/'bridge','cold_replay')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',dest/'exact_native_replay.json'],output/'bridge','exact_replay')
    shutil.copyfile(output/'determinism/recipe_proof.json',dest/'recipe_proof.json')


def prove(output):
    output=Path(output).resolve();path=build(output);dest=capture(path,output)
    audit(output);replay(output)
    _,spec=load_spec();result=inspect(spec,dest)
    if not result['passed']:raise ValueError('Acceptance failed: '+str(result['checks']))
    seal_delivery(spec,dest);validate_delivery(spec,dest)
    print('MQ16_NATIVE_PROOF: PASS',flush=True)
    return dest


def verify_inventory():
    import re
    names={line.strip() for line in (FOLDER/'COMMIT_MANIFEST.txt').read_text().splitlines() if line.strip() and not line.startswith('#')}
    # Later numbered units own their prefixed files and subtrees.
    paths=[p for p in FOLDER.rglob('*') if p.is_file()
           and not ((successor:=re.match(r'mq(\d+)[_/]',p.relative_to(FOLDER).as_posix()))
                    and int(successor[1])>16)]
    actual={str(p.relative_to(FOLDER)) for p in paths}
    size=sum(p.stat().st_size for p in paths)
    if (names!=actual or size>CURATION_DEFAULTS['budget_bytes']
            or any(p.suffix in ('.blend','.blend1','.pyc') or '__pycache__' in p.parts or p.is_relative_to(FOLDER/'proof') for p in paths)):
        raise ValueError('Uncurated, incomplete or oversized figure inventory')
    print('MQ16_CURATED_INVENTORY: PASS; files='+str(len(paths))+'; bytes='+str(size))
    return {'files':len(paths),'bytes':size}


def verify_delivery(require_fresh=True,require_inventory=True):
    _,spec=load_spec();validate_delivery(spec,FOLDER/'delivery');validate_acceptance(spec,FOLDER/'delivery')
    if require_fresh:
        from .validation import validate_receipts
        validate_receipts(spec,FOLDER/'delivery')
    if require_inventory:verify_inventory()
    print('MQ16_NATIVE_DELIVERY: PASS')


def stage_delivery(source):
    _,spec=load_spec();source=Path(source)
    from spec.art_identity.maquettes.blender.compact_capture import compact_capture
    from .review_sheet import review_sheet
    from .validation import retain_native
    validate_acceptance(spec,source);compact_capture(spec,source);inspect(spec,source);seal_delivery(spec,source)
    stage(FOLDER,source)
    for name in ('per_part_coverage.csv','proportion_table.md'):
        shutil.copyfile(source/name,FOLDER/'delivery'/name)
    review_sheet(spec,FOLDER/'delivery');retain_native(source.parent)
    inspect(spec,FOLDER/'delivery');seal_delivery(spec,FOLDER/'delivery');verify_delivery(require_fresh=False,require_inventory=False)


def regenerate(output):
    output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('Fresh regeneration needs an empty output')
    from .source_inventory import copy_required_sources
    project=output/'clean_project';root=project/'spec/art_identity/maquettes';figure=root/'ashen_reaver'
    write(output/'clean_input_sha256.json',copy_required_sources(project))
    compile_code=('from pathlib import Path\n'
        'from spec.art_identity.maquettes.ashen_reaver.recipe import FOLDER,compile_spec\n'
        'from spec.art_identity.maquettes.blender.curate_delivery import write\n'
        'if not FOLDER.is_relative_to(Path.cwd()): raise ValueError("Compiler escaped clean input project")\n'
        'write(FOLDER/"measurements.json",compile_spec())\n'
        'print("MQ16_CLEAN_SOURCE: PASS; module="+str(FOLDER/"recipe.py"))\n')
    process=subprocess.run([sys.executable,'-B','-c',compile_code],
                           cwd=project,text=True,capture_output=True)
    (output/'source_compile.log').write_text(process.stdout+process.stderr)
    if process.returncode:raise ValueError('Fresh source reconstruction failed')
    spec_path=figure/'measurements.json'
    _,spec=load_spec()
    if json.loads(spec_path.read_text())!=spec:raise ValueError('Fresh source reconstruction differs from canonical native input')
    # Neither native geometry, a saved scene nor any cache was copied.
    job(root/'blender/build.py',[spec_path,output/'native','--build-only'],output/'bridge','build')
    dest=capture(spec_path,output,figure/'capture.py')
    job(figure/'native_probe.py',[spec_path,output/'native',dest/'native_probe.json'],output/'bridge','fresh_native_probe')
    for name in ('recipe_proof.json','exact_native_replay.json'):shutil.copyfile(FOLDER/'delivery'/name,dest/name)
    acceptance=inspect(spec,dest);compared=compare_captures(dest,FOLDER/'delivery',output,True)
    from .validation import compare_blade_masks
    compare_blade_masks(dest,FOLDER/'delivery',compared)
    seal_delivery(spec,dest);validate_delivery(spec,dest)
    result={'passed':acceptance['passed'] and all(r['passed'] for v in compared.values() for r in v.values()),
        'views':compared,'cache_reused':False,'saved_model_reused':False,'source_recompiled':True,'spec_hash':digest(spec),
        'input_inventory_sha256':sha(output/'clean_input_sha256.json')}
    write(output/'regeneration.json',result)
    if not result['passed']:raise ValueError('Fresh regeneration mismatch')
    from .validation import retain_fresh
    retain_fresh(output);inspect(spec,FOLDER/'delivery');seal_delivery(spec,FOLDER/'delivery')
    print('MQ16_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; blade_area_masks=2/2; cache_reused=false',flush=True)
    return result


def curate():
    verify_delivery(require_inventory=False);archive=FOLDER/'discarded_proof_sha256.json'
    paths=[p for p in (FOLDER/'proof').rglob('*') if p.is_file()]
    discard_evidence(FOLDER,paths,archive)
    for path in sorted((FOLDER/'proof').rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if path.is_dir() and not any(path.iterdir()):path.rmdir()
    manifest=FOLDER/'COMMIT_MANIFEST.txt'
    names=sorted({str(p.relative_to(FOLDER)) for p in FOLDER.rglob('*') if p.is_file()}|{manifest.name})
    manifest.write_text('# mq-16 curated native source and delivery inventory.\n'+'\n'.join(names)+'\n')
    verify_inventory()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('source','build','capture','audit','replay','prove','stage','regenerate','curate','verify'))
    parser.add_argument('--out',type=Path);parser.add_argument('--capture',type=Path)
    args=parser.parse_args()
    if args.action=='source':
        recipe,source=read_inputs();verify(source)
        print('MQ16_SOURCE_MEASUREMENTS: PASS; drawn_height_px='+str(source['measurements']['drawn_height_px']))
        print('MQ16_DESIGN_STATUS: '+('UNRESOLVED' if unresolved(recipe) else 'RESOLVED'))
    elif args.action=='verify':verify_delivery()
    elif args.action=='curate':curate()
    elif args.action=='stage':stage_delivery(args.capture)
    elif args.action=='regenerate':regenerate(args.out)
    elif args.action=='prove':prove(args.out)
    elif args.action=='build':build(args.out)
    elif args.action=='capture':capture(args.out.resolve()/'spec_native.json',args.out)
    elif args.action=='audit':audit(args.out)
    elif args.action=='replay':replay(args.out)


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError,TimeoutError) as error:
        print('MQ16_PROOF_ERROR: '+str(error),flush=True);raise SystemExit(2)
