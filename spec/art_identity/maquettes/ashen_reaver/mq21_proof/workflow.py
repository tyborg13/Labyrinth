"""Owner-only bridge proof and clean regeneration for mq-21; no engine fallback."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import gzip
from spec.art_identity.maquettes.blender.contract import digest,todos
from spec.art_identity.maquettes.blender.curate_delivery import write,sha,canonical_png
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from ..source_measurements import FOLDER,PROJECT
from .mq21_recipe import compile_spec,read_design
from .mq21_checks import observe
from .mq21_acceptance import inspect,validate_acceptance
from .mq21_sheet import review_sheet
from ..source_inventory import required_sources
from ..bridge import job
from ..capture_workflow import capture
from ..proof import replay

BUILDER=FOLDER.parent/'blender'
DELIVERY=FOLDER/'mq21_delivery'
PROOF_DEFAULTS={'budget_bytes':6000000,'source_timeout_seconds':120}
DIRECTOR_FILES={
    'mq21_prompt_front.md':'d208a7f0e9a14452838224bf413f48e3f9e7553aecbf4fd84b9335d57596eeb9',
    'mq21_prompt_rear.md':'c078f728c9aae205da63c4b318219b78b97f56875b5ffe8bdfd66289e8642f81'}


def verify_director_files():
    record=json.loads((FOLDER/'mq21_director_files.json').read_text())
    if record.get('schema')!=1 or record.get('files')!=DIRECTOR_FILES:
        raise ValueError('Protected director inventory differs')
    if any(sha(FOLDER/name)!=value for name,value in DIRECTOR_FILES.items()):
        raise ValueError('Protected director prompt changed')
    print('MQ21_PROTECTED_DIRECTOR_FILES: PASS; files=2')


def inventory(project=PROJECT):
    paths=required_sources(project);figure=Path(project)/FOLDER.relative_to(PROJECT)
    for path in (figure/'mq21_proof').rglob('*.py'):
        paths[str(path.relative_to(project))]=path
    for name in ('mq21_pose.json','mq21_design.json','mq21_contract.json','mq21_historical_delivery.json','prompt_front.md','prompt_rear.md','prompt_rear_edit_1.md'):
        path=figure/name;paths[str(path.relative_to(project))]=path
    import hashlib
    result={name:sha(path) if path is not None else hashlib.sha256(b'').hexdigest() for name,path in sorted(paths.items())}
    # Validation-only improvements retain the sealed production input hashes.
    # Every admitted live verifier is separately pinned; all other inputs bind
    # their current bytes, including compiler, renderer, assets and design.
    from .mq21_sources import validation_source_hashes
    result.update(validation_source_hashes(project))
    return result


def copy_sources(destination,project=PROJECT):
    destination=Path(destination);project=Path(project)
    for name in inventory(project):
        target=destination/name;target.parent.mkdir(parents=True,exist_ok=True)
        source=project/name
        if source.is_file():shutil.copyfile(source,target)
        else:target.write_bytes(b'')
    relative=FOLDER.relative_to(PROJECT)/'mq21_validation_sources.json'
    shutil.copyfile(project/relative,destination/relative)
    return inventory(destination)


def native_proof(spec,output,figure=FOLDER):
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    path=output/'spec_native.json';write(path,spec)
    job(figure.parent/'blender/build.py',[path,output/'native','--build-only'],output/'bridge','build')
    dest=capture(path,output,figure/'capture.py')
    audit(spec,output,figure)
    return dest


def audit(spec,output,figure=FOLDER):
    output=Path(output).resolve()
    if figure==FOLDER:
        from ..recipe import compile_spec as compile_baseline
        reference=compile_baseline()
    else:reference=json.loads((output/'clean_project/source_reference.json').read_text())
    if digest(reference)!=spec['mq21']['baseline_spec_hash']:raise ValueError('Compiler source reference differs')
    write(output/'source_reference.json',reference)
    job(figure/'mq21_proof/mq21_native_probe.py',[output/'spec_native.json',output/'native',output/'capture/native_probe.json',output/'source_reference.json'],output/'bridge','native_probe')


def prove(output):
    spec=compile_spec();checks=observe(spec)
    if not checks['passed']:raise ValueError('mq-21 geometry fails before renderer: '+str([k for k,v in checks['checks'].items() if not v]))
    output=Path(output).resolve()
    if (output/'capture/capture_manifest.json').is_file():
        if json.loads((output/'spec_native.json').read_text())!=spec:raise ValueError('Cannot resume captures for a different compiled spec')
        read_manifest(output/'capture',digest(spec),('full',))
        audit(spec,output);dest=output/'capture'
    else:dest=native_proof(spec,output)
    replay(output)
    acceptance=inspect(spec,dest)
    if not acceptance['passed']:raise ValueError('mq-21 capture acceptance failed: '+str(acceptance['checks']))
    review_sheet(spec,dest);seal_delivery(spec,dest);validate_delivery(spec,dest)
    write(dest/'mq21_input_sha256.json',inventory())
    print('MQ21_NATIVE_PROOF: PASS')
    return dest


def stage(source):
    spec=compile_spec();source=Path(source);validate_acceptance(spec,source);validate_delivery(spec,source)
    if json.loads((source/'mq21_input_sha256.json').read_text())!=inventory():raise ValueError('Proof source changed before staging')
    from spec.art_identity.maquettes.blender.compact_capture import compact_capture
    compact_capture(spec,source);inspect(spec,source);seal_delivery(spec,source)
    manifest=read_manifest(source,digest(spec),('full',))
    names=set(manifest['images'])|{p.name for p in source.glob('*.json')}|{'mq21_contact_sheet.webp','mq21_proportion_table.md','front_sword_hand_3x.png','rear_sword_hand_3x.png'}
    # Replace only the verified generated delivery after the new capture passes.
    if DELIVERY.exists() and any(DELIVERY.iterdir()):retire_previous_delivery()
    DELIVERY.mkdir(exist_ok=True)
    for name in sorted(names):shutil.copyfile(source/name,DELIVERY/name)
    shutil.copytree(source.parent/'bridge',DELIVERY/'validation/native_bridge')
    from .mq21_mutations import report as mutation_report
    write(DELIVERY/'validation/mutations.json',mutation_report())
    review_sheet(spec,DELIVERY);seal_delivery(spec,DELIVERY);validate_delivery(spec,DELIVERY)
    print('MQ21_DELIVERY_STAGE: PASS')


def archive_files(paths):
    from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence
    ledger=FOLDER/'mq21_discarded_proof_sha256.json';packed=ledger.with_suffix('.json.gz')
    if not ledger.exists() and packed.exists():
        raw=gzip.decompress(packed.read_bytes());json.loads(raw)
        ledger.write_bytes(raw)
    discard_evidence(FOLDER,paths,ledger)


def retire_previous_delivery():
    receipt=json.loads((DELIVERY/'mq21_receipt.json').read_text())
    files={str(p.relative_to(DELIVERY)):sha(p) for p in DELIVERY.rglob('*') if p.is_file() and p.name!='mq21_receipt.json'}
    build=json.loads((DELIVERY/'build_report.json').read_text())
    if receipt.get('files')!=files or receipt.get('spec_hash')!=build.get('spec_hash'):
        raise ValueError('Previous delivery differs from its verified receipt; preserve it')
    archive_files([p for p in DELIVERY.rglob('*') if p.is_file()])
    for path in sorted(DELIVERY.rglob('*'),key=lambda p:len(p.parts),reverse=True):
        if path.is_dir():path.rmdir()
    DELIVERY.rmdir()


def regenerate(output):
    output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('Regeneration requires a fresh empty directory')
    project=output/'clean_project';expected=inventory()
    if copy_sources(project)!=expected:raise ValueError('Clean source copy differs')
    code=('from pathlib import Path\n'
          'from spec.art_identity.maquettes.ashen_reaver.mq21_proof.mq21_recipe import compile_spec,FOLDER\n'
          'from spec.art_identity.maquettes.blender.curate_delivery import write\n'
          'from spec.art_identity.maquettes.ashen_reaver.recipe import compile_spec as baseline\n'
          'assert FOLDER.is_relative_to(Path.cwd()), "Compiler escaped clean sources"\n'
          'write(Path("spec_native.json"),compile_spec())\n'
          'write(Path("source_reference.json"),baseline())\n')
    run=subprocess.run([sys.executable,'-B','-c',code],cwd=project,text=True,capture_output=True,timeout=PROOF_DEFAULTS['source_timeout_seconds'])
    (output/'source_compile.log').write_text(run.stdout+run.stderr)
    if run.returncode:raise ValueError('Clean source compilation failed')
    spec=json.loads((project/'spec_native.json').read_text())
    if spec!=compile_spec():raise ValueError('Clean recipe differs from canonical recipe')
    figure=project/FOLDER.relative_to(PROJECT);dest=native_proof(spec,output,figure)
    for name in ('recipe_proof.json','exact_native_replay.json'):shutil.copyfile(DELIVERY/name,dest/name)
    acceptance=inspect(spec,dest);compared=compare_captures(dest,DELIVERY,output,True)
    from ..validation import compare_blade_masks
    compare_blade_masks(dest,DELIVERY,compared)
    result={'passed':acceptance['passed'] and all(row['passed'] for view in compared.values() for row in view.values()),
        'spec_hash':digest(spec),'views':compared,'source_recompiled':True,'saved_model_reused':False,'cache_reused':False,
        'input_sha256':expected,'native_mesh_hash':json.loads((dest/'native_probe.json').read_text())['native_mesh_hash']}
    write(output/'mq21_regeneration.json',result)
    if not result['passed']:raise ValueError('mq-21 clean regeneration differs')
    write(DELIVERY/'mq21_regeneration.json',result)
    validation=DELIVERY/'validation';validation.mkdir(exist_ok=True)
    for source,name in ((output/'source_compile.log','fresh_source_compile.log'),
                        (dest/'native_probe.json','fresh_native_probe.json'),
                        (dest/'capture_manifest.json','fresh_capture_manifest.json')):
        shutil.copyfile(source,validation/name)
    shutil.copytree(output/'bridge',validation/'fresh_bridge',dirs_exist_ok=True)
    print('MQ21_CLEAN_REGENERATION: PASS; source_recompiled=true; clays=2/2; part_maps=2/2; blade_area_masks=2/2')


def seal():
    spec=compile_spec();validate_acceptance(spec,DELIVERY);validate_delivery(spec,DELIVERY)
    fresh=json.loads((DELIVERY/'mq21_regeneration.json').read_text())
    if not fresh['passed'] or fresh['input_sha256']!=inventory():raise ValueError('Fresh source proof absent or stale')
    files={str(p.relative_to(DELIVERY)):sha(p) for p in DELIVERY.rglob('*') if p.is_file() and p.name!='mq21_receipt.json'}
    write(DELIVERY/'mq21_receipt.json',{'spec_hash':digest(spec),'files':files})
    verify(require_inventory=False)
    # Copied clean scripts must remain inside the bridge's maquette root.
    # Retain their hashes before removing these generated proof intermediates.
    proof=FOLDER/'proof';generated=[p for p in proof.rglob('*') if p.is_file()]
    if generated:
        archive_files(generated)
        for path in sorted(proof.rglob('*'),key=lambda p:len(p.parts),reverse=True):
            if path.is_dir() and not any(path.iterdir()):path.rmdir()
        if not any(proof.iterdir()):proof.rmdir()
    ledger=FOLDER/'mq21_discarded_proof_sha256.json'
    if ledger.exists():
        raw=ledger.read_bytes();packed=gzip.compress(raw,compresslevel=9,mtime=0)
        if gzip.decompress(packed)!=raw:raise ValueError('Archive packing changed proof records')
        ledger.with_suffix('.json.gz').write_bytes(packed);ledger.unlink()
    manifest=FOLDER/'mq21_COMMIT_MANIFEST.txt';names=sorted({str(p.relative_to(FOLDER)) for p in FOLDER.rglob('*') if p.is_file() and not p.is_relative_to(FOLDER/'proof')}|{manifest.name})
    manifest.write_text('# mq-21 source/delivery inventory; mq-16 COMMIT_MANIFEST.txt remains historical.\n'+'\n'.join(names)+'\n')
    verify();print('MQ21_CURATED_DELIVERY: PASS')


def verify(require_inventory=True):
    verify_director_files()
    from .mq21_sources import verify as verify_rebinding
    verify_rebinding()
    from .mq21_mq16_regeneration import verify as verify_mq16
    verify_mq16()
    from .mq21_mutations import report as mutation_report
    if json.loads((DELIVERY/'validation/mutations.json').read_text())!=mutation_report():
        raise ValueError('Stale semantic mutation proof')
    spec=compile_spec();validate_acceptance(spec,DELIVERY);validate_delivery(spec,DELIVERY)
    fresh=json.loads((DELIVERY/'mq21_regeneration.json').read_text());native=json.loads((DELIVERY/'native_probe.json').read_text())
    if (fresh.get('passed') is not True or fresh.get('spec_hash')!=digest(spec) or fresh.get('input_sha256')!=inventory()
            or fresh.get('source_recompiled') is not True or fresh.get('saved_model_reused') is not False or fresh.get('cache_reused') is not False
            or fresh.get('native_mesh_hash')!=native['native_mesh_hash']):raise ValueError('Invalid fresh source/native regeneration')
    verify_fresh_pixels(fresh,DELIVERY)
    fresh_native=json.loads((DELIVERY/'validation/fresh_native_probe.json').read_text())
    if fresh_native.get('passed') is not True or fresh_native.get('native_mesh_hash')!=native['native_mesh_hash'] or fresh_native.get('spec_hash')!=digest(spec):
        raise ValueError('Fresh opened native geometry differs')
    capture=json.loads((DELIVERY/'validation/fresh_capture_manifest.json').read_text())
    if capture.get('spec_hash')!=digest(spec):raise ValueError('Stale fresh capture')
    for view,passes in fresh['views'].items():
        for kind,row in passes.items():
            if row['native_file_sha256']!=capture['images'][view+'_'+kind+'.png']['sha256']:raise ValueError('Fresh capture binding differs')
    for folder in ('native_bridge','fresh_bridge'):
        receipts=list((DELIVERY/'validation'/folder).glob('*.json'))
        if not receipts:raise ValueError('Missing bridge receipts')
        for path in receipts:
            row=json.loads(path.read_text())
            if row.get('exit')!=0 or row.get('timeout_s')!=110 or row.get('response_timeout_s')!=120:raise ValueError('Failed or unbounded bridge receipt')
    from .mq21_sheet import verify_sheet
    verify_sheet(DELIVERY)
    receipt=json.loads((DELIVERY/'mq21_receipt.json').read_text())
    files={str(p.relative_to(DELIVERY)):sha(p) for p in DELIVERY.rglob('*') if p.is_file() and p.name!='mq21_receipt.json'}
    if receipt!={'spec_hash':digest(spec),'files':files}:raise ValueError('Stale mq-21 delivery receipt')
    if require_inventory:
        verify_inventory()
        print('MQ21_NATIVE_DELIVERY: PASS')


def verify_inventory():
    paths=[p for p in FOLDER.rglob('*') if p.is_file()]
    names={str(p.relative_to(FOLDER)) for p in paths}
    listed={line.strip() for line in (FOLDER/'mq21_COMMIT_MANIFEST.txt').read_text().splitlines() if line.strip() and not line.startswith('#')}
    # mq-16's full immutable historical proof is retained for its regression
    # suite. The active mq-21 budget includes all root source/data, the new
    # delivery and both mq-16 clay references used in the current sheet.
    # measurements.json is the retained mq-16 compiled snapshot, never an
    # mq-21 authoring input (both revisions recompile from protected sources).
    historical={FOLDER/'measurements.json',FOLDER/'discarded_proof_sha256.json'}
    active=[p for p in paths if p not in historical and
            (not p.is_relative_to(FOLDER/'delivery') or p.name in ('front_clay.png','rear_clay.png'))]
    size=sum(p.stat().st_size for p in active)
    if names!=listed or size>PROOF_DEFAULTS['budget_bytes'] or any(p.suffix in ('.blend','.blend1','.pyc') or '__pycache__' in p.parts or p.is_relative_to(FOLDER/'proof') for p in paths):
        raise ValueError('Uncurated, incomplete or oversized mq-21 inventory')
    result={'active_revision_bytes':size,'historical_and_current_bytes':sum(p.stat().st_size for p in paths),'files':len(paths)}
    print('MQ21_CURATED_INVENTORY: PASS; '+str(result))
    return result


def verify_fresh_pixels(fresh,delivery):
    delivery=Path(delivery)
    if set(fresh.get('views',{}))!={'front','rear'}:raise ValueError('Missing fresh views')
    with tempfile.TemporaryDirectory(prefix='mq21_verify_pixels_') as tmp:
        for view,passes in fresh['views'].items():
            if set(passes)!={'clay','parts','blade_area'}:raise ValueError('Missing fresh passes')
            for kind,row in passes.items():
                name=view+'_'+kind+'.png';target=Path(tmp)/name
                canonical_png(delivery/name,target,mask=kind!='clay')
                if (row.get('passed') is not True or row['sha256']!=row['expected_sha256']
                        or sha(target)!=row['sha256'] or row['delivery_file_sha256']!=sha(delivery/name)):
                    raise ValueError('Stale fresh pixels: '+name)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=('source','mutations','prove','stage','regenerate','regenerate-mq16','rebind-sources','seal','verify'))
    parser.add_argument('--out',type=Path);parser.add_argument('--capture',type=Path);args=parser.parse_args()
    if args.action=='source':
        p,d=read_design();missing=todos(p,'pose')+todos(d,'forms')
        if missing:raise ValueError('Unresolved mq-21 design: '+'; '.join(missing))
        spec=compile_spec();result=observe(spec)
        if not result['passed']:raise ValueError('Geometry gates failed: '+str([k for k,v in result['checks'].items() if not v]))
        result.update(spec_hash=digest(spec),director_design_sha256=sha(FOLDER/'mq21_design.json'),blade_solve=spec['mq21']['blade_solve'])
        if args.out:write(args.out,result)
        print('MQ21_SOURCE_GEOMETRY: PASS; pieces='+str(len(spec['pieces'])))
    elif args.action=='prove':prove(args.out)
    elif args.action=='rebind-sources':
        from .mq21_sources import rebind
        rebind()
    elif args.action=='mutations':
        from .mq21_mutations import report
        result=report()
        if args.out:write(args.out,result)
        print('MQ23_MUTATIONS: PASS; caught='+str(result['caught'])+'; survived='+str(result['survived']))
    elif args.action=='stage':stage(args.capture)
    elif args.action=='regenerate':regenerate(args.out)
    elif args.action=='regenerate-mq16':
        from .mq21_mq16_regeneration import regenerate as regenerate_mq16
        regenerate_mq16(args.out)
    elif args.action=='seal':seal()
    else:verify()


if __name__=='__main__':
    try:main()
    except (ValueError,OSError,KeyError,TimeoutError) as error:
        print('MQ21_PROOF_ERROR: '+str(error));raise SystemExit(2)
