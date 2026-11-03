"""mq-17 native proof, clean regeneration and curated hash-bound handoff.

Every Blender invocation is a serial director bridge job, with an absolute
120-second response deadline. This module never launches an engine directly.
"""
import argparse
import hashlib
import re
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import write,sha,stage,discard_evidence
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery,seal_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from .recipe import FOLDER,PROJECT,compile_spec,NUMERICAL_DEFAULTS
from .bridge import job,EXECUTION_DEFAULTS
from .acceptance import inspect,review_sheet,validate_acceptance,PROOF_DEFAULTS
from .regeneration_checks import materialize_inputs,current_inputs,validate_regeneration,approved_artifacts,seal_artifacts
from .proof_inventory import load_preservation,compact_preservation

BUILDER=FOLDER.parent/'blender'
PRESERVATION_RANGE={'baseline':'b5e181e0a^',
                    'sealed_revision':'ec03a241c458c899bc68a36b6983b20abe17ca53'}


def curated_names(folder):
    """mq-17 owns the parent figure, never a later numbered unit's subtree."""
    folder=Path(folder)
    return {p.relative_to(folder).as_posix() for p in folder.rglob('*')
            if p.is_file() and '__pycache__' not in p.parts
            and not re.fullmatch(r'mq\d+',p.relative_to(folder).parts[0])}


def verify_preservation(folder,project,baseline=None,end=None):
    """Compare the complete receipt to sealed Git objects, then guard its range.

    Later legitimate edits do not invalidate historical evidence. A changed
    foreign file *inside this unit's range* still fails even if its receipt was
    resealed to that edit. Git is read-only throughout this operation.
    """
    preserved=load_preservation(folder)
    baseline=baseline or PRESERVATION_RANGE['baseline']
    end=end or PRESERVATION_RANGE['sealed_revision']
    names=sorted(preserved['files'])
    batch=subprocess.run(['git','cat-file','--batch'],cwd=project,
        input=''.join(end+':'+n+'\n' for n in names).encode(),capture_output=True,check=True).stdout
    position=0
    for name in names:
        stop=batch.index(b'\n',position);header=batch[position:stop].split();position=stop+1
        if len(header)!=3 or header[1]!=b'blob':raise ValueError('Missing sealed foreign source: '+name)
        size=int(header[2]);raw=batch[position:position+size];position+=size+1
        if hashlib.sha256(raw).hexdigest()!=preserved['files'][name]['sha256']:
            raise ValueError('Sealed foreign source bytes changed: '+name)
    changed=subprocess.check_output(['git','diff','--no-renames','--name-only','-z',baseline,end,'--'],cwd=project)
    changed=set(changed.decode().split('\0'))
    prefix='spec/art_identity/maquettes/'
    forbidden=(changed&set(names))|{name for name in changed if name.startswith(prefix)
        and not name.startswith(prefix+'storm_cantor/')}
    if forbidden:raise ValueError('Foreign source changed inside mq-17 unit range: '+str(sorted(forbidden)))
    return preserved



def build_capture(spec_path,output,builder=BUILDER):
    output=Path(output).resolve();spec_path=Path(spec_path).resolve()
    job(builder/'build.py',[spec_path,output/'native','--build-only'],output/'bridge','build')
    from .capture_workflow import capture
    script=FOLDER/'capture.py' if builder==BUILDER else builder.parent/'storm_cantor/capture.py'
    return capture(spec_path,output,script)


def prove(output):
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    spec=compile_spec();spec_path=output/'spec_native.json';write(spec_path,spec)
    write(FOLDER/'measurements.json',spec)
    capture=build_capture(spec_path,output)
    job(FOLDER/'native_probe.py',[spec_path,output/'native',capture/'native_probe.json'],output/'bridge','native_probe')
    return finish_proof(output,capture,spec_path)


def finish_proof(output,capture,spec_path):
    output=Path(output);capture=Path(capture);spec=json.loads(Path(spec_path).read_text())
    if not inspect(capture,spec)['passed']:raise ValueError('mq-17 native acceptance failed')
    job(BUILDER/'recipe_proof.py',[spec_path,output/'determinism'],output/'bridge','cold_replay')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',capture/'exact_native_replay.json'],output/'bridge','exact_replay')
    shutil.copyfile(output/'determinism/recipe_proof.json',capture/'recipe_proof.json')
    review_sheet(capture);seal_delivery(spec,capture);validate_delivery(spec,capture)
    print('MQ17_NATIVE_DELIVERY: PASS',flush=True)
    return capture


def stage_delivery(capture):
    capture=Path(capture);spec=json.loads((FOLDER/'measurements.json').read_text())
    validate_acceptance(capture,spec);compact_capture(spec,capture)
    inspect(capture,spec);seal_delivery(spec,capture);stage(FOLDER,capture)
    for name in ('per_part_coverage.csv','pose_table.md','proportion_table.md','contact_sheet.webp','contact_sheet.json'):
        shutil.copyfile(capture/name,FOLDER/'delivery'/name)
    inspect(FOLDER/'delivery',spec);review_sheet(FOLDER/'delivery');seal_delivery(spec,FOLDER/'delivery')
    seal_artifacts(spec,FOLDER/'delivery')
    logs=FOLDER/'delivery/validation/bridge';logs.mkdir(parents=True,exist_ok=True)
    for path in (capture.parent/'bridge').glob('*'):
        shutil.copyfile(path,logs/path.name)
    print('MQ17_STAGE: PASS',flush=True)


def regenerate(output):
    output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('Regeneration requires a fresh empty destination')
    approved_artifacts(compile_spec(),FOLDER/'delivery')
    project=output/'clean_project';root=project/'spec/art_identity/maquettes'
    inputs=materialize_inputs(project)
    figure=root/FOLDER.name
    write(output/'clean_input_sha256.json',inputs)
    process=subprocess.run([sys.executable,'-B','-m','spec.art_identity.maquettes.storm_cantor.recipe'],cwd=project,text=True,capture_output=True)
    (output/'compile.log').write_text(process.stdout+process.stderr)
    if process.returncode:raise ValueError('Fresh copied compiler failed')
    spec_path=figure/'measurements.json';spec=json.loads(spec_path.read_text())
    if digest(spec)!=digest(compile_spec()):raise ValueError('Fresh compiler differs')
    capture=build_capture(spec_path,output,root/'blender')
    job(figure/'native_probe.py',[spec_path,output/'native',capture/'native_probe.json'],output/'bridge','fresh_native_probe')
    compared=compare_captures(capture,FOLDER/'delivery',output,True)
    for filename in ('recipe_proof.json','exact_native_replay.json'):shutil.copyfile(FOLDER/'delivery'/filename,capture/filename)
    acceptance=inspect(capture,spec);seal_delivery(spec,capture);binding=validate_delivery(spec,capture)
    shutil.copyfile(capture/'capture_manifest.json',output/'regenerated_capture_manifest.json')
    result={'schema':2,'passed':acceptance['passed'] and all(r['passed'] for view in compared.values() for r in view.values()),
        'views':compared,'cache_reused':False,'saved_model_reused':False,'compiled_spec_hash':digest(spec),
        'comparison_required':True,'compile_returncode':process.returncode,
        'native_geometry_unchanged':json.loads((capture/'capture_checks.json').read_text())['geometry_unchanged'],
        'native_reports':binding,'input_inventory_sha256':sha(output/'clean_input_sha256.json'),
        'capture_manifest_sha256':sha(output/'regenerated_capture_manifest.json'),
        'bridge_jobs':{p.stem:sha(p) for p in sorted((output/'bridge').glob('*.json'))}}
    write(output/'regeneration.json',result)
    if not result['passed']:raise ValueError('Clean regeneration differs; retain diagnostics')
    if inputs!=current_inputs():raise ValueError('Sources changed during clean regeneration')
    # Only proof reports change. The director's paint-over depends on the exact
    # existing PNG/WebP bytes, so never stage a regenerated image here.
    shutil.copyfile(capture/'native_probe.json',FOLDER/'delivery/native_probe.json')
    inspect(FOLDER/'delivery',spec);seal_delivery(spec,FOLDER/'delivery')
    approved_artifacts(spec,FOLDER/'delivery')
    retain_regeneration(output)
    validate_regeneration(spec,FOLDER/'delivery')
    print('MQ17_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false',flush=True)
    return result


def retain_regeneration(output):
    """Retain only receipts/logs, never the clean inputs or saved native model."""
    output=Path(output);destination=FOLDER/'delivery/validation/regeneration'
    result=json.loads((output/'regeneration.json').read_text())
    if not result['passed']:raise ValueError('Cannot retain a failed regeneration')
    destination.mkdir(parents=True,exist_ok=True)
    for name in ('regeneration.json','clean_input_sha256.json','compile.log','regenerated_capture_manifest.json'):
        shutil.copyfile(output/name,destination/name)
    (destination/'bridge').mkdir(exist_ok=True)
    for path in (output/'bridge').glob('*'):
        shutil.copyfile(path,destination/'bridge'/path.name)


def preservation():
    # No builder changes are made. Still bind every foreign source and its
    # compiled recipe to HEAD to detect accidental edits, including assets.
    names=subprocess.check_output(['git','ls-files','spec/art_identity/maquettes','assets/units/storm_cantor.png',
        'assets/units/guardians/storm_cantor'],cwd=PROJECT,text=True).splitlines()
    import hashlib
    inventory={};compiled=[]
    names=[n for n in names if not ('/storm_cantor/' in n and n.startswith('spec/'))]
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
        'builder_changed':False,'regeneration_scope':'Only Storm Cantor: shared builder bytes and every existing figure remain unchanged.'}
    write(FOLDER/'preservation.json',report)
    if not report['passed']:raise ValueError('Foreign source preservation failed')
    compact_preservation(FOLDER)
    print('MQ17_PRESERVATION: PASS; files='+str(len(inventory))+'; compiled_specs='+str(len(compiled)),flush=True)


def verify_inventory():
    names=curated_names(FOLDER)
    listed={line for line in (FOLDER/'COMMIT_MANIFEST.txt').read_text().splitlines() if line and not line.startswith('#')}
    if names!=listed:raise ValueError('Curated inventory differs: '+str(sorted(names^listed)))
    if any('.blend' in Path(n).suffixes or 'cache' in Path(n).parts or 'proof' in Path(n).parts for n in names):
        raise ValueError('Uncurated build/cache/proof file retained')
    size=sum((FOLDER/n).stat().st_size for n in names)
    if size>PROOF_DEFAULTS['budget_bytes']:raise ValueError('Delivery exceeds 6 MB: '+str(size))
    print('MQ17_COMMIT_CURATION: PASS; bytes='+str(size)+'; files='+str(len(names)),flush=True)
    return size


def verify():
    spec=json.loads((FOLDER/'measurements.json').read_text());delivery=FOLDER/'delivery'
    if spec!=compile_spec():raise ValueError('Canonical native spec differs from source recipe')
    validate_delivery(spec,delivery);validate_acceptance(delivery,spec)
    sheet=json.loads((delivery/'contact_sheet.json').read_text())
    if sha(delivery/'contact_sheet.webp')!=sheet['sheet_sha256']:raise ValueError('Stale contact sheet')
    for ref in sheet['inputs']:
        path=(delivery if ref['capture_relative'] else PROJECT)/ref['path']
        if sha(path)!=ref['sha256']:raise ValueError('Stale review source')
    provenance=json.loads((delivery/'provenance.json').read_text())
    for view in ('front','rear'):
        name=view+'_clay.png'
        if sha(delivery/name)!=provenance['native_image_sha256'][name]:raise ValueError('Clay bytes changed')
    approved_artifacts(spec,delivery)
    validate_regeneration(spec,delivery)
    verify_preservation(FOLDER,PROJECT)
    print('MQ17_HASH_BOUND_DELIVERY: PASS',flush=True)


def curate():
    verify()
    # Copy only the small, useful results before hashing/removing all build
    # sources, duplicate renders, native models and clean project copies.
    paths=[p for p in (FOLDER/'proof').rglob('*') if p.is_file()]
    discard_evidence(FOLDER,paths,FOLDER/'discarded_proof_sha256.json')
    for path in sorted((FOLDER/'proof').rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if path.is_dir() and not any(path.iterdir()):path.rmdir()
    if (FOLDER/'proof').exists() and not any((FOLDER/'proof').iterdir()):(FOLDER/'proof').rmdir()
    names=curated_names(FOLDER)
    names.add('COMMIT_MANIFEST.txt')
    (FOLDER/'COMMIT_MANIFEST.txt').write_text('# mq-17 curated uncommitted figure inventory; 6,000,000-byte budget.\n'+'\n'.join(sorted(names))+'\n')
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
