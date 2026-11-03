"""Director-run bridge proof, clean regeneration and non-destructive curation.

Every Blender command is delegated through the existing 110s job / 120s
response bridge. No timeout retries; completed failures require a real fix.
"""
import argparse
import lzma
import json
from pathlib import Path
import shutil
import subprocess
import sys
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from ..bridge import job
from ..capture_workflow import capture as bounded_capture
from .recipe import FOLDER,BASE,PROJECT,compile_spec
from .measure import observe
from .acceptance import inspect,validate_acceptance,review_sheet,PROOF_DEFAULTS
from .regeneration import input_paths,validate as validate_regeneration

BUILDER=BASE.parent/'blender'


def source(output,draft=False):
    spec=compile_spec(require_resolved=not draft);output=Path(output);output.mkdir(parents=True,exist_ok=True)
    report=observe(spec,{p['id']:p['vertices'] for p in spec['pieces']},spec['joints'],{p['id']:p['faces'] for p in spec['pieces']})
    report.update(spec_hash=digest(spec),geometry_scope='source_arrays_not_opened_native')
    write(output/'spec_native.json',spec);write(output/'source_checks.json',report)
    print('MQ20_SOURCE_GEOMETRY: '+('PASS' if report['passed'] else 'FAIL')+'; rows='+str(len(report['pose_values']))+
        '; clearance_over_H='+str(report['clearance']['minimum_over_H'])+'; unresolved='+str(report['design_pending']),flush=True)
    return spec,report


def build_capture(spec_path,output,builder=BUILDER,base=BASE):
    output=Path(output);job(builder/'build.py',[spec_path,output/'native','--build-only'],output/'bridge','build')
    job(base/'mq20/native_probe.py',[spec_path,output/'native',output/'native_probe.json'],output/'bridge','native_probe')
    captured=bounded_capture(spec_path,output,base/'mq20/capture.py')
    shutil.copyfile(output/'native_probe.json',captured/'native_probe.json')
    print('MQ20_CAPTURE_MERGE: PASS; views=2; solos='+str(2*len(json.loads(Path(spec_path).read_text())['labels'])),flush=True)
    return captured


def fresh(output):
    output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('Proof requires a fresh empty output directory')
    output.mkdir(parents=True,exist_ok=True);return output


def prove(output):
    output=fresh(output);spec,checks=source(output)
    if not checks['passed']:raise ValueError('Source geometry failed; no Blender job submitted')
    captured=build_capture(output/'spec_native.json',output)
    acceptance=inspect(captured,spec)
    if not acceptance['passed']:raise ValueError('mq-20 capture acceptance failed')
    job(BUILDER/'recipe_proof.py',[output/'spec_native.json',output/'determinism'],output/'bridge','cold_replay')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',captured/'exact_native_replay.json'],output/'bridge','exact_replay')
    shutil.copyfile(output/'determinism/recipe_proof.json',captured/'recipe_proof.json')
    compact_capture(spec,captured);inspect(captured,spec);review_sheet(captured);seal_delivery(spec,captured)
    print('MQ20_NATIVE_PROOF: PASS',flush=True);return captured


def stage(capture):
    capture=Path(capture);spec=compile_spec();validate_acceptance(capture,spec);validate_delivery(spec,capture)
    destination=FOLDER/'delivery'
    if destination.exists():raise ValueError('Refusing to overwrite existing delivery; retain it first')
    destination.mkdir()
    for p in capture.iterdir():
        if p.is_file() and '.blend' not in p.suffixes:shutil.copyfile(p,destination/p.name)
    # The complete compiled mesh is retained losslessly. Its uncompressed
    # arrays alone exceed 5 MB; XZ leaves room for the actual native images
    # within the existing 6 MB curated unit budget.
    (FOLDER/'measurements.json.xz').write_bytes(lzma.compress(json.dumps(spec,separators=(',',':'),allow_nan=False).encode(),preset=6))
    from ..report_packing import compact_reports
    compact_reports(destination,FOLDER/'proof/raw_reports')
    inspect(destination,spec);seal_delivery(spec,destination)
    write(destination/'provenance.json',{'spec_hash':digest(spec),'native_image_sha256':json.loads((destination/'capture_manifest.json').read_text())['images']})
    print('MQ20_STAGE: PASS',flush=True)


def regenerate(output):
    output=fresh(output);project=output/'clean_project';inputs=input_paths()
    for name,path in inputs.items():
        target=project/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
    write(output/'clean_input_sha256.json',{n:sha(p) for n,p in inputs.items()})
    clean=project/FOLDER.relative_to(PROJECT);spec_path=clean/'measurements.json'
    command=[sys.executable,'-B','-m','spec.art_identity.maquettes.last_lamplighter.mq20.recipe','--out',str(spec_path)]
    result=subprocess.run(command,cwd=project,text=True,capture_output=True);(output/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode:raise ValueError('Copied mq-20 compiler failed')
    spec=json.loads(spec_path.read_text())
    if digest(spec)!=digest(compile_spec()):raise ValueError('Copied mq-20 recipe differs')
    captured=build_capture(spec_path,output,project/BUILDER.relative_to(PROJECT),clean.parent)
    acceptance=inspect(captured,spec);compared=compare_captures(captured,FOLDER/'delivery',output,True)
    report={'passed':all(r['passed'] for v in compared.values() for r in v.values()),'acceptance_passed':acceptance['passed'],
        'cache_reused':False,'saved_model_reused':False,'compiled_spec_hash':digest(spec),'views':compared,'input_inventory_sha256':sha(output/'clean_input_sha256.json')}
    write(output/'regeneration.json',report);validate_regeneration(spec,FOLDER/'delivery',output)
    destination=FOLDER/'delivery/validation/regeneration'
    if destination.exists():raise ValueError('Refusing to overwrite retained regeneration')
    destination.mkdir(parents=True)
    for name in ('regeneration.json','clean_input_sha256.json','compile.log'):shutil.copyfile(output/name,destination/name)
    shutil.copytree(output/'bridge',destination/'bridge')
    print('MQ20_CLEAN_REGENERATION: PASS; clays=2/2; part_maps=2/2; cache_reused=false',flush=True)


def verify():
    spec=compile_spec();delivery=FOLDER/'delivery'
    if json.loads(lzma.decompress((FOLDER/'measurements.json.xz').read_bytes()))!=spec:raise ValueError('Stale mq-20 specification')
    validate_acceptance(delivery,spec);validate_delivery(spec,delivery);validate_regeneration(spec,delivery)
    sheet=json.loads((delivery/'contact_sheet.json').read_text())
    if sha(delivery/'contact_sheet.webp')!=sheet['sheet_sha256']:raise ValueError('Stale contact sheet')
    for r in sheet['inputs']:
        if sha((delivery if r['capture_relative'] else PROJECT)/r['path'])!=r['sha256']:raise ValueError('Stale contact sheet input')
    print('MQ20_HASH_BOUND_DELIVERY: PASS',flush=True)


def curate():
    verify()
    # Build intermediates stay in proof/, outside the reviewable inventory.
    # Never delete the mq-18 baseline or the design owner's prompt files.
    files=[p for p in FOLDER.rglob('*') if p.is_file() and not {'proof','__pycache__'}&set(p.relative_to(FOLDER).parts)]
    if any('.blend' in p.suffixes or 'cache' in p.parts for p in files):raise ValueError('Native/cache artifact in delivery')
    total=sum(p.stat().st_size for p in files)
    if total>PROOF_DEFAULTS['budget_bytes']:raise ValueError('mq-20 delivery exceeds 6,000,000 bytes: '+str(total))
    names=[str(p.relative_to(BASE)) for p in files]
    names += ['prompt_front.md','prompt_rear.md','mq20/COMMIT_MANIFEST.txt']
    (FOLDER/'COMMIT_MANIFEST.txt').write_text('# mq-20 paths relative to last_lamplighter; protected mq-18 prompts retained.\n'+'\n'.join(sorted(set(names)))+'\n')
    print('MQ20_COMMIT_CURATION: PASS; bytes='+str(total),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('operation',choices=('source','prove','stage','regenerate','verify','curate'))
    parser.add_argument('--out',type=Path);parser.add_argument('--capture',type=Path);parser.add_argument('--draft',action='store_true');args=parser.parse_args()
    if args.draft and args.operation!='source':parser.error('--draft is source-only')
    if args.operation in ('source','prove','regenerate') and args.out is None:parser.error('--out is required')
    if args.operation=='source':
        _,checks=source(args.out,args.draft);return 0 if checks['passed'] else 1
    if args.operation=='prove':prove(args.out)
    elif args.operation=='regenerate':regenerate(args.out)
    elif args.operation=='stage':
        if args.capture is None:parser.error('--capture is required')
        stage(args.capture)
    elif args.operation=='curate':curate()
    else:verify()
    return 0


if __name__=='__main__':raise SystemExit(main())
