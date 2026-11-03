"""Owner-run bridge proof. No direct Blender invocation or window-server use."""
import argparse
import lzma
import io
import tarfile
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from ..bridge import job
from .capture_workflow import capture
from ..regeneration_checks import source_paths as baseline_sources
from ..recipe import PROJECT,FOLDER as BASE
from .recipe import FOLDER,compile_spec,pose_spec
from .checks import observe
from .delivery import inspect,review_sheet,rear_cloak_crop,front_far_crop,DELIVERY_DEFAULTS

BUILDER = BASE.parent/'blender'
ARCHIVE_DEFAULTS = {'xz_preset':9,'mtime':0,'file_mode':0o644}


def input_inventory():
    paths = set(baseline_sources())|{BUILDER/'render_plan.py'}|set(FOLDER.glob('*.py'))|{FOLDER/'design.json',FOLDER/'cloak_acceptance.json',BASE/'delivery/native_probe.json'}
    return {str(p.relative_to(PROJECT)):sha(p) for p in sorted(paths)}


def fresh(output):
    output = Path(output).resolve()
    if output.exists() and any(output.iterdir()): raise ValueError('Proof requires a fresh empty output directory')
    output.mkdir(parents=True,exist_ok=True)
    return output


def build_capture(spec_path,output,local=FOLDER):
    job(local/'native.py',['build',spec_path,output/'native','--build-only'],output/'bridge','build')
    job(local/'native.py',['audit',spec_path,output/'native',output/'native/mq19_native.json'],output/'bridge','native_audit')
    result = capture(spec_path,output,local)
    shutil.copyfile(output/'native/mq19_native.json',result/'mq19_native.json')
    return result


def prove(output):
    # Resolve before creating/submitting any bridge job. The deadline remains
    # 120 seconds including queue time; exceptions terminate this command.
    spec = compile_spec(); inventory = input_inventory()
    portable = observe(spec,{p['id']+'_render':p['vertices'] for p in spec['pieces']},spec['joints'],
        spec['mq19']['bone_forward'],{p['id']+'_render':p['faces'] for p in spec['pieces']})
    if not portable['passed']:
        raise ValueError('mq-19 portable acceptance failed: '+str([k for k,v in portable['checks'].items() if not v]))
    output = fresh(output)
    path = output/'spec_native.json'; write(path,spec)
    result = build_capture(path,output)
    if not inspect(spec,result)['passed']: raise ValueError('mq-19 native acceptance failed')
    job(FOLDER/'native.py',['determinism',path,output/'determinism'],output/'bridge','determinism')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',result/'exact_native_replay.json'],output/'bridge','exact_replay')
    shutil.copyfile(output/'determinism/recipe_proof.json',result/'recipe_proof.json')
    if inventory!=input_inventory(): raise ValueError('Sources changed during proof')
    write(output/'input_sha256.json',inventory); review_sheet(result); rear_cloak_crop(result);front_far_crop(result)
    compact_capture(spec,result); inspect(spec,result); seal_delivery(spec,result); validate_delivery(spec,result)
    print('MQ19_NATIVE_DELIVERY: PASS; '+str(result))


def regenerate(reference,output):
    spec = compile_spec(); reference = Path(reference).resolve()
    validate_delivery(spec,reference)
    inventory = input_inventory(); output = Path(output).resolve()
    if not output.is_relative_to(BASE.parent.resolve()):
        raise ValueError('Clean bridge scripts must stay under the worktree maquette root; use mq19/proof/<run>')
    output = fresh(output); project = output/'clean_project'
    for name in inventory:
        target = project/name; target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(PROJECT/name,target)
    copied = {str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()}
    if copied!=inventory: raise ValueError('Clean input copy differs')
    local = project/FOLDER.relative_to(PROJECT); path = output/'spec_native.json'
    command = [sys.executable,'-B','-m','spec.art_identity.maquettes.storm_cantor.mq19.recipe','--out',str(path)]
    process = subprocess.run(command,cwd=project,text=True,capture_output=True)
    (output/'compile.log').write_text(process.stdout+process.stderr)
    if process.returncode: raise ValueError('Clean copied compiler failed')
    if json.loads(path.read_text())!=spec: raise ValueError('Clean compiler differs')
    result = build_capture(path,output,local)
    # A new native build and empty local cache supply the comparison. No
    # .blend, generated spec, proof output or cloth cache was copied as input.
    compared = compare_captures(result,reference,output,True)
    receipt = {'passed':all(v['passed'] for r in compared.values() for v in r.values()),
        'spec_hash':digest(spec),'input_sha256':inventory,'views':compared,
        'cache_reused':False,'saved_model_reused':False,'compile_returncode':process.returncode,
        'native_probe_sha256':sha(result/'mq19_native.json'),
        'native_manifest_sha256':sha(result/'capture_manifest.json')}
    write(output/'regeneration.json',receipt)
    if not receipt['passed']: raise ValueError('Fresh mq-19 regeneration differs')
    if inventory!=input_inventory(): raise ValueError('Source inventory changed during regeneration')
    print('MQ19_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false')


def source_archive(inventory,procedural_design=False):
    """Lossless deterministic source packing, preserving every original value."""
    raw = io.BytesIO();expected=dict(inventory)
    generated=str((FOLDER/'design.json').relative_to(PROJECT))
    recipe={'path':generated,'sha256':inventory[generated],
        'command':'python3 -B -m spec.art_identity.maquettes.storm_cantor.mq19.generate_design'}
    with tarfile.open(fileobj=raw,mode='w') as archive:
        for name,wanted in sorted(inventory.items()):
            source = PROJECT/name
            if sha(source)!=wanted: raise ValueError('Source changed before packing: '+name)
            if procedural_design and name==generated:continue
            data = source.read_bytes(); info = tarfile.TarInfo(name)
            info.size=len(data);info.mode=ARCHIVE_DEFAULTS['file_mode'];info.mtime=ARCHIVE_DEFAULTS['mtime']
            archive.addfile(info,io.BytesIO(data))
        if procedural_design:
            data=(json.dumps(recipe,sort_keys=True)+'\n').encode();info=tarfile.TarInfo('GENERATED_DESIGN.json')
            info.size=len(data);info.mode=ARCHIVE_DEFAULTS['file_mode'];info.mtime=ARCHIVE_DEFAULTS['mtime']
            archive.addfile(info,io.BytesIO(data))
            import hashlib
            expected.pop(generated);expected['GENERATED_DESIGN.json']=hashlib.sha256(data).hexdigest()
    result = lzma.compress(raw.getvalue(),preset=ARCHIVE_DEFAULTS['xz_preset'])
    import hashlib
    with tarfile.open(fileobj=io.BytesIO(result),mode='r:xz') as archive:
        actual = {m.name:hashlib.sha256(archive.extractfile(m).read()).hexdigest() for m in archive.getmembers()}
    if actual!=expected: raise ValueError('Source packing changed input bytes')
    return result


def stage(reference,output,regeneration):
    """Create a bounded, explicitly inventoried delivery without deleting mq-17."""
    spec = compile_spec(); reference = Path(reference); regeneration = Path(regeneration)
    validate_delivery(spec,reference)
    if not inspect(spec,reference,False)['passed']: raise ValueError('Failed native acceptance')
    receipt = json.loads((regeneration/'regeneration.json').read_text())
    inventory = input_inventory()
    if (receipt['input_sha256']!=inventory or receipt['spec_hash']!=digest(spec) or
        receipt['passed'] is not True or receipt['cache_reused'] is not False or receipt['saved_model_reused'] is not False):
        raise ValueError('Stale or incomplete regeneration receipt')
    expected = compare_captures(regeneration/'capture',reference,regeneration,True)
    if expected!=receipt['views']: raise ValueError('Regeneration comparison no longer binds current delivery')
    output = Path(output).resolve()
    files = {str(Path('delivery')/p.name):p.read_bytes() for p in reference.iterdir() if p.is_file()}
    # The registered contact sheet already contains both baseline clays at
    # native scale. Bind the unchanged originals instead of duplicating them.
    files['mq17_baseline.json']=(json.dumps({str(p.relative_to(PROJECT)):sha(p)
        for p in (BASE/'delivery/front_clay.png',BASE/'delivery/rear_clay.png')},sort_keys=True)+'\n').encode()
    for name in ('prompt_front_v2.md','prompt_rear.md'): files[name]=(BASE/name).read_bytes()
    files['regeneration/regeneration.json']=(regeneration/'regeneration.json').read_bytes()
    files['source_inputs.tar.xz']=source_archive(inventory,procedural_design=True)
    # Verify the delivered archive itself, independently of the working tree.
    with tempfile.TemporaryDirectory(prefix='mq19_archive_') as temporary:
        project=Path(temporary)
        with tarfile.open(fileobj=io.BytesIO(files['source_inputs.tar.xz']),mode='r:xz') as archive:
            generated_recipe=None
            for member in archive.getmembers():
                if member.name=='GENERATED_DESIGN.json':
                    generated_recipe=json.loads(archive.extractfile(member).read());continue
                if member.name not in inventory or not member.isfile():raise ValueError('Unexpected archived input')
                target=project/member.name;target.parent.mkdir(parents=True,exist_ok=True)
                target.write_bytes(archive.extractfile(member).read())
        generated_name=str((FOLDER/'design.json').relative_to(PROJECT))
        if generated_recipe is None or generated_recipe['path']!=generated_name or generated_recipe['sha256']!=inventory[generated_name]:
            raise ValueError('Missing generated design recipe binding')
        process=subprocess.run([sys.executable,'-B','-m','spec.art_identity.maquettes.storm_cantor.mq19.generate_design'],cwd=project,text=True,capture_output=True)
        if process.returncode:raise ValueError('Archived design generator failed: '+process.stderr)
        copied={str(p.relative_to(project)):sha(p) for p in project.rglob('*') if p.is_file()}
        if copied!=inventory:raise ValueError('Unpacked archive differs')
        generated=project/'reproduced_spec.json'
        command=[sys.executable,'-B','-m','spec.art_identity.maquettes.storm_cantor.mq19.recipe','--out',str(generated)]
        process=subprocess.run(command,cwd=project,text=True,capture_output=True)
        if process.returncode or json.loads(generated.read_text())!=spec:
            raise ValueError('Archived sources do not reproduce exact measurements: '+process.stderr)
    files['measurement_reproduction.json']=(json.dumps({'passed':True,'spec_hash':digest(spec),
        'source_archive':'source_inputs.tar.xz','unpacked_source_sha256_verified':True,
        'independent_archive_compile_equal':True,'generated_design_byte_sha256_verified':True,
        'command':'python3 -B -m spec.art_identity.maquettes.storm_cantor.mq19.recipe --out measurements.json',
        'note':'Generated mesh/spec payload is reproduced exactly from the archived sources; full raw proof remains in the task proof directory.'},sort_keys=True)+'\n').encode()
    files['clean_input_sha256.json']=(json.dumps(inventory,sort_keys=True)+'\n').encode()

    import hashlib
    files['bundle_sha256.json']=(json.dumps({name:hashlib.sha256(data).hexdigest() for name,data in sorted(files.items())},sort_keys=True)+'\n').encode()
    manifest = '# mq-19 curated delivery; lossless xz sources; exact archive compilation; no model/cache; 6,000,000-byte maximum.\n'+'\n'.join(sorted(files))+'\nCOMMIT_MANIFEST.txt\n'
    files['COMMIT_MANIFEST.txt']=manifest.encode()
    size = sum(len(data) for data in files.values())
    if size>DELIVERY_DEFAULTS['budget_bytes']: raise ValueError('Curated bundle exceeds 6 MB: '+str(size))
    output = fresh(output)
    for name,data in files.items():
        target=output/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
    print('MQ19_CURATED_BUNDLE: PASS; bytes='+str(size)+'; '+str(output))


def diagnostic(output):
    spec = pose_spec(); points = {p['id']+'_render':p['vertices'] for p in spec['pieces']}
    report = observe(spec,points,spec['joints'],spec['mq19']['bone_forward'])
    report['evidence'] = 'Compiler diagnostic only. No Blender build or opened-armature proof has run.'
    write(output,report)
    print('MQ19_POSE_DIAGNOSTIC: '+('PASS' if report['passed'] else 'NEEDS_DESIGN')+'; '+str(output))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation',choices=('diagnostic','prove','regenerate','stage','verify'))
    parser.add_argument('--out',type=Path); parser.add_argument('--capture',type=Path)
    parser.add_argument('--regeneration',type=Path)
    args = parser.parse_args()
    if args.operation=='verify':
        from .verification import verify
        verify();return
    if args.out is None:parser.error('--out is required')
    if args.operation in ('regenerate','stage') and args.capture is None: parser.error('--capture is required')
    if args.operation=='stage' and args.regeneration is None: parser.error('--regeneration is required')
    if args.operation=='diagnostic': diagnostic(args.out)
    elif args.operation=='prove': prove(args.out)
    elif args.operation=='regenerate': regenerate(args.capture,args.out)
    else: stage(args.capture,args.out,args.regeneration)


if __name__=='__main__': main()
