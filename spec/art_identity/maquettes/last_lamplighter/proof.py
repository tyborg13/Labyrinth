"""mq-18 native proof, clean regeneration and curated hash-bound handoff.

Every Blender invocation is a serial director bridge job, with a default
120-second response deadline. This module never launches an engine directly.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from .preserve import discard as discard_evidence
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from .recipe import FOLDER,PROJECT,compile_spec,NUMERICAL_DEFAULTS
from .bridge import job,EXECUTION_DEFAULTS
from .diagnostic import seal as diagnostic_seal,verify as diagnostic_verify,native_contract
from .acceptance import inspect,review_sheet,validate_acceptance,PROOF_DEFAULTS
from .regeneration_validation import materialize_inputs,validate_regeneration

BUILDER=FOLDER.parent/'blender'


def build_capture(spec_path,output,builder=BUILDER):
    output=Path(output).resolve();spec_path=Path(spec_path).resolve()
    job(builder/'build.py',[spec_path,output/'native','--build-only'],output/'bridge','build')
    from .capture_workflow import capture
    script=FOLDER/'capture.py' if builder==BUILDER else builder.parent/'last_lamplighter/capture.py'
    probe=FOLDER/'native_probe.py' if builder==BUILDER else builder.parent/'last_lamplighter/native_probe.py'
    job(probe,[spec_path,output/'native',output/'native_probe.json'],output/'bridge','native_probe')
    result=capture(spec_path,output,script)
    shutil.copyfile(output/'native_probe.json',result/'native_probe.json')
    return result


def prove(output):
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    spec=compile_spec();spec_path=output/'spec_native.json';write(spec_path,spec)
    write(FOLDER/'measurements.json',spec)
    capture=build_capture(spec_path,output)
    return finish_proof(output,capture,spec_path)


def finish_proof(output,capture,spec_path):
    output=Path(output);capture=Path(capture);spec=json.loads(Path(spec_path).read_text())
    acceptance=inspect(capture,spec)
    if not native_contract(spec,json.loads((capture/'native_probe.json').read_text())):raise ValueError('Unexpected native failure')
    job(BUILDER/'recipe_proof.py',[spec_path,output/'determinism'],output/'bridge','cold_replay')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',capture/'exact_native_replay.json'],output/'bridge','exact_replay')
    shutil.copyfile(output/'determinism/recipe_proof.json',capture/'recipe_proof.json')
    review_sheet(capture);diagnostic_seal(spec,capture)
    print('MQ18_NATIVE_PROOF: PASS; acceptance=PASS',flush=True)
    return capture


def stage_delivery(capture):
    capture=Path(capture);spec=json.loads((FOLDER/'measurements.json').read_text())
    validate_acceptance(capture,spec,require_pass=True);compact_capture(spec,capture)
    inspect(capture,spec);review_sheet(capture);diagnostic_seal(spec,capture)
    output=FOLDER/'delivery';output.mkdir(exist_ok=True)
    if (output/'diagnostic_binding.json').exists():
        discard_evidence(FOLDER,[output/'diagnostic_binding.json'],FOLDER/'discarded_proof_sha256.json')
    for path in capture.iterdir():
        if path.is_file() and '.blend' not in path.suffixes:shutil.copyfile(path,output/path.name)
    # Native clay bytes are copied unchanged and all acceptance gates seal.
    manifest=json.loads((capture/'capture_manifest.json').read_text())
    write(output/'provenance.json',{'spec_hash':digest(spec),'recipe_sha256':sha(FOLDER/'measurements.json'),
        'native_image_sha256':{n:sha(capture/n) for n in manifest['images']},
        'acceptance_passed':True,'status':'director_feedback_1'})
    from .report_packing import compact_reports
    if (output/'report_packing.json').exists():
        discard_evidence(FOLDER,[output/'report_packing.json'],FOLDER/'discarded_proof_sha256.json')
    compact_reports(output,FOLDER/'proof/raw_reports')
    inspect(output,spec);review_sheet(output);diagnostic_seal(spec,output)
    logs=output/'validation/bridge';logs.mkdir(parents=True,exist_ok=True)
    for path in (capture.parent/'bridge').glob('*'):shutil.copyfile(path,logs/path.name)
    print('MQ18_STAGE: PASS; acceptance=PASS',flush=True)


def regenerate(output):
    output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('Regeneration requires a fresh empty destination')
    project=output/'clean_project';root=project/'spec/art_identity/maquettes';root.mkdir(parents=True)
    inputs=materialize_inputs(project)
    figure=root/FOLDER.name
    write(output/'clean_input_sha256.json',inputs)
    process=subprocess.run([sys.executable,'-B','-m','spec.art_identity.maquettes.last_lamplighter.recipe'],cwd=project,text=True,capture_output=True)
    (output/'compile.log').write_text(process.stdout+process.stderr)
    if process.returncode:raise ValueError('Fresh copied compiler failed')
    spec_path=figure/'measurements.json';spec=json.loads(spec_path.read_text())
    if digest(spec)!=digest(compile_spec()):raise ValueError('Fresh compiler differs')
    capture=build_capture(spec_path,output,root/'blender')
    compared=compare_captures(capture,FOLDER/'delivery',output,True)
    for filename in ('recipe_proof.json','exact_native_replay.json'):shutil.copyfile(FOLDER/'delivery'/filename,capture/filename)
    acceptance=inspect(capture,spec);review_sheet(capture);binding=diagnostic_seal(spec,capture)
    result={'passed':all(r['passed'] for view in compared.values() for r in view.values()),'acceptance_passed':acceptance['passed'],
        'views':compared,'cache_reused':False,'saved_model_reused':False,'compiled_spec_hash':digest(spec),
        'native_reports':binding,'input_inventory_sha256':sha(output/'clean_input_sha256.json')}
    write(output/'regeneration.json',result)
    if not result['passed']:raise ValueError('Clean regeneration differs; retain diagnostics')
    validate_regeneration(spec,FOLDER/'delivery',receipt_dir=output)
    retain_regeneration(output)
    print('MQ18_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false',flush=True)
    return result


def retain_regeneration(output):
    """Retain only receipts/logs, never the clean inputs or saved native model."""
    output=Path(output);destination=FOLDER/'delivery/validation/regeneration'
    result=json.loads((output/'regeneration.json').read_text())
    if not result['passed']:raise ValueError('Cannot retain a failed regeneration')
    destination.mkdir(parents=True,exist_ok=True)
    discard_evidence(FOLDER,[p for p in destination.rglob('*') if p.is_file()],FOLDER/'discarded_proof_sha256.json')
    for name in ('regeneration.json','clean_input_sha256.json','compile.log'):
        shutil.copyfile(output/name,destination/name)
    (destination/'bridge').mkdir(exist_ok=True)
    for path in (output/'bridge').glob('*'):
        shutil.copyfile(path,destination/'bridge'/path.name)


def preservation():
    # No builder changes are made. Still bind every foreign source and its
    # compiled recipe to HEAD to detect accidental edits, including assets.
    names=subprocess.check_output(['git','ls-files','spec/art_identity/maquettes','assets/units/last_lamplighter.png',
        'assets/units/guardians/last_lamplighter'],cwd=PROJECT,text=True).splitlines()
    import hashlib
    inventory={};compiled=[]
    names=[n for n in names if not ('/last_lamplighter/' in n and n.startswith('spec/'))]
    batch=subprocess.run(['git','cat-file','--batch'],cwd=PROJECT,
        input=''.join('HEAD:'+n+'\n' for n in names).encode(),capture_output=True,check=True).stdout
    position=0
    for name in names:
        end=batch.index(b'\n',position);size=int(batch[position:end].split()[-1]);position=end+1
        before=hashlib.sha256(batch[position:position+size]).hexdigest();position+=size+1
        after=sha(PROJECT/name);inventory[name]={'sha256':after,'passed':before==after}
        if Path(name).name=='measurements.json':
            value=json.loads((PROJECT/name).read_text())
            if 'id' in value and ('surfaces' in value or value.get('version')==2 or value.get('native_solids')):
                compiled.append({'path':name,'compiled_sha256':digest(compile_recipe(value))})
    report={'passed':all(r['passed'] for r in inventory.values()),'files':inventory,'compiled_foreign_specs':compiled,
        'builder_changed':False,'regeneration_scope':'Only Last Lamplighter: shared builder bytes and every existing figure remain unchanged.'}
    from .preserve import save as save_preservation
    save_preservation(FOLDER,report)
    if not report['passed']:raise ValueError('Foreign source preservation failed')
    print('MQ18_PRESERVATION: PASS; files='+str(len(inventory))+'; compiled_specs='+str(len(compiled)),flush=True)


def verify_inventory():
    names={str(p.relative_to(FOLDER)) for p in FOLDER.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    listed={line for line in (FOLDER/'COMMIT_MANIFEST.txt').read_text().splitlines() if line and not line.startswith('#')}
    if names!=listed:raise ValueError('Curated inventory differs: '+str(sorted(names^listed)))
    if any('.blend' in Path(n).suffixes or 'cache' in Path(n).parts or 'proof' in Path(n).parts for n in names):
        raise ValueError('Uncurated build/cache/proof file retained')
    size=sum((FOLDER/n).stat().st_size for n in names)
    if size>PROOF_DEFAULTS['budget_bytes']:raise ValueError('Delivery exceeds 6 MB: '+str(size))
    from .preserve import load_discard
    load_discard(FOLDER/'discarded_proof_sha256.json')
    print('MQ18_COMMIT_CURATION: PASS; bytes='+str(size)+'; files='+str(len(names)),flush=True)
    return size


def verify_delivery():
    spec=json.loads((FOLDER/'measurements.json').read_text());delivery=FOLDER/'delivery'
    if spec!=compile_spec():raise ValueError('Canonical native spec differs from source recipe')
    diagnostic_verify(spec,delivery);validate_acceptance(delivery,spec,require_pass=True)
    sheet=json.loads((delivery/'contact_sheet.json').read_text())
    if sha(delivery/'contact_sheet.webp')!=sheet['sheet_sha256']:raise ValueError('Stale contact sheet')
    for ref in sheet['inputs']:
        path=(delivery if ref['capture_relative'] else PROJECT)/ref['path']
        if sha(path)!=ref['sha256']:raise ValueError('Stale review source')
    provenance=json.loads((delivery/'provenance.json').read_text())
    for view in ('front','rear'):
        name=view+'_clay.png'
        if sha(delivery/name)!=provenance['native_image_sha256'][name]:raise ValueError('Clay bytes changed')
    print('MQ18_HASH_BOUND_DELIVERY: PASS',flush=True)


def verify():
    verify_delivery()
    spec=json.loads((FOLDER/'measurements.json').read_text())
    validate_regeneration(spec,FOLDER/'delivery')
    print('MQ18_CLEAN_REGENERATION_VERIFIED: PASS',flush=True)


def curate():
    verify_delivery()
    state=json.loads((FOLDER/'delivery/validation/regeneration/regeneration.json').read_text())
    if state.get('status')=='bridge_response_timeout':
        if (state['compiled_spec_hash']!=digest(compile_spec()) or state['response_timeout_s']!=120 or state.get('director_result',{}).get('exit')!=-1 or
            sha(FOLDER/'delivery/validation/regeneration/bridge_timeout_result.json')!=state['bridge_result_sha256']):
            raise ValueError('Invalid blocked regeneration receipt')
        print('MQ18_REGENERATION: BLOCKED; bridge response deadline; no retry',flush=True)
    else:verify()
    # Copy only the small, useful results before hashing/removing all build
    # sources, duplicate renders, native models and clean project copies.
    from .preserve import compact_auxiliary
    compact_auxiliary(FOLDER)
    paths=[p for p in (FOLDER/'proof').rglob('*') if p.is_file()]
    discard_evidence(FOLDER,paths,FOLDER/'discarded_proof_sha256.json')
    for path in sorted((FOLDER/'proof').rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if path.is_dir() and not any(path.iterdir()):path.rmdir()
    if (FOLDER/'proof').exists() and not any((FOLDER/'proof').iterdir()):(FOLDER/'proof').rmdir()
    names={str(p.relative_to(FOLDER)) for p in FOLDER.rglob('*') if p.is_file() and '__pycache__' not in p.parts}
    names.add('COMMIT_MANIFEST.txt')
    (FOLDER/'COMMIT_MANIFEST.txt').write_text('# mq-18 curated uncommitted figure inventory; 6,000,000-byte budget.\n'+'\n'.join(sorted(names))+'\n')
    verify_inventory()


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation',choices=('prove','stage','regenerate','preservation','curate','verify'))
    parser.add_argument('--out',type=Path);parser.add_argument('--capture',type=Path)
    args=parser.parse_args()
    if args.operation in ('prove','regenerate') and args.out is None:parser.error('--out is required')
    if args.operation=='prove':prove(args.out)
    elif args.operation=='regenerate':regenerate(args.out)
    elif args.operation=='stage':
        if args.capture is None:parser.error('--capture is required')
        stage_delivery(args.capture)
    elif args.operation=='preservation':preservation()
    elif args.operation=='curate':curate()
    else:verify();verify_inventory()


if __name__=='__main__':main()
