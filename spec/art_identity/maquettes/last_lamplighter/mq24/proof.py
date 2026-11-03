"""mq-24 source audit, bounded bridge proof and fresh copied-source replay.

No Blender process is launched locally. Each bridge job has the inherited
110s execution / 120s total response deadline, including queue time. A timeout
ends this operation; there are no automatic retries.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from ..bridge import job
from .bounded_capture import capture
from ..mq20.regeneration import input_paths as mq20_inputs
from .recipe import compile_spec,FOLDER
from .oracle import protected
from .measure import observe
from .delivery import acceptance,proof_images,tables

PROJECT=FOLDER.parents[4]
BUILDER=FOLDER.parent.parent/'blender'


def fresh(path):
    path=Path(path).resolve()
    if path.exists() and any(path.iterdir()):raise ValueError('Proof requires a new empty directory')
    path.mkdir(parents=True,exist_ok=True);return path


def source(output,draft=False):
    spec=compile_spec(require_resolved=not draft);output=Path(output);output.mkdir(parents=True,exist_ok=True)
    result=observe({p['id']:p['vertices'] for p in spec['pieces']},{p['id']:p['faces'] for p in spec['pieces']},
        spec['joints'],{p['id']:{k:p[k] for k in ('part','rig_bone')} for p in spec['pieces']},spec['mq24']['design_pending'])
    result.update(spec_hash=digest(spec),geometry_scope='source_arrays_not_native')
    write(output/'spec_native.json',spec);write(output/'source_checks.json',result);tables(output,result)
    print('MQ24_SOURCE_GEOMETRY: '+('PASS' if result['passed'] else 'FAIL')+'; unresolved='+str(result['design_pending']),flush=True)
    return spec,result


def build_capture(spec_path,output,builder=BUILDER,unit=FOLDER,diagnostic=False):
    output=Path(output)
    job(builder/'build.py',[spec_path,output/'native','--build-only'],output/'bridge','build')
    # A diagnostic job can now have a passing ratified 3D baseline. Its
    # mutation verdict remains diagnostic; image acceptance is separate.
    expected_exit=0
    if diagnostic:
        spec=json.loads(Path(spec_path).read_text())
        expected_exit=0 if observe({p['id']:p['vertices'] for p in spec['pieces']},{p['id']:p['faces'] for p in spec['pieces']},
            spec['joints'],{p['id']:{k:p[k] for k in ('part','rig_bone')} for p in spec['pieces']})['passed'] else 1
    job(unit/'native_probe.py',[spec_path,output/'native',output/'native_probe.json']+(['--diagnostic'] if diagnostic else []),output/'bridge','native_probe',expected_exit=expected_exit)
    captured=capture(spec_path,output,unit/'capture.py');shutil.copyfile(output/'native_probe.json',captured/'native_probe.json')
    return captured


def diagnose(output,resume=False):
    """Capture a fully constructed failed candidate, with no acceptance seal.

    This exists to make incompatible director constraints reviewable. It never
    changes a failed geometric verdict or authorizes publication.
    """
    if resume:
        output=Path(output).resolve();spec=json.loads((output/'spec_native.json').read_text());result=json.loads((output/'source_checks.json').read_text())
        if digest(spec)!=digest(compile_spec()):raise ValueError('Cannot resume changed geometry')
        captured=capture(output/'spec_native.json',output,FOLDER/'capture.py');shutil.copyfile(output/'native_probe.json',captured/'native_probe.json')
    else:
        output=fresh(output);spec,result=source(output)
        captured=build_capture(output/'spec_native.json',output,diagnostic=True)
    accepted=acceptance(spec,captured);tables(captured,json.loads((captured/'native_probe.json').read_text()));proof_images(captured)
    write(captured/'diagnostic_status.json',{'accepted':False,'source_passed':result['passed'],'native_acceptance_passed':accepted['passed'],'purpose':'Director inspection of conflicting constraints; not accepted delivery'})
    print('MQ24_DIAGNOSTIC_CAPTURE: COMPLETE; acceptance='+str(accepted['passed']),flush=True)
    return captured


def prove(output):
    output=fresh(output);spec,result=source(output)
    if not result['passed']:raise ValueError('Source gates failed; no Blender job submitted')
    captured=build_capture(output/'spec_native.json',output)
    accepted=acceptance(spec,captured)
    tables(captured,json.loads((captured/'native_probe.json').read_text()));proof_images(captured)
    if not accepted['passed']:
        write(captured/'diagnostic_status.json',{'accepted':False,'source_passed':True,
            'native_acceptance_passed':False,'purpose':'Fresh native evidence of failed image gates; no acceptance seal'})
        raise ValueError('mq-24 capture acceptance failed')
    job(BUILDER/'recipe_proof.py',[output/'spec_native.json',output/'determinism'],output/'bridge','cold_replay')
    job(BUILDER/'exact_native_replay.py',[output/'determinism',captured/'exact_native_replay.json'],output/'bridge','exact_replay')
    shutil.copyfile(output/'determinism/recipe_proof.json',captured/'recipe_proof.json')
    tables(captured,json.loads((captured/'native_probe.json').read_text()));proof_images(captured);seal_delivery(spec,captured)
    seal(captured)
    print('MQ24_NATIVE_PROOF: PASS',flush=True)
    return captured


def input_paths():
    inputs=mq20_inputs()
    # mq-20's historical compiler inventory predates the split bridge and
    # bounded-capture helpers imported by this unit's copied proof entry.
    for p in FOLDER.parent.glob('*.py'):inputs[str(p.relative_to(PROJECT))]=p
    for p in BUILDER.rglob('*.py'):inputs[str(p.relative_to(PROJECT))]=p
    for p in FOLDER.iterdir():
        if p.suffix=='.py' or p.name in ('contract.json','design_details.json','chosen_defaults.json','protected_files.json','round1_preservation.json','director_files.json','prompt_front.md','prompt_rear.md'):
            inputs[str(p.relative_to(PROJECT))]=p
    # Immutable baseline images/data are comparison inputs, never a saved
    # native model or a substitute for freshly built mq-24 geometry.
    for name in json.loads((FOLDER/'protected_files.json').read_text()):inputs[name]=PROJECT/name
    return dict(sorted(inputs.items()))


def seal(captured):
    captured=Path(captured);names=[p.name for p in captured.iterdir() if p.is_file() and p.name!='mq24_binding.json']
    write(captured/'mq24_binding.json',{'inputs':{n:sha(p) for n,p in input_paths().items()},'files':{n:sha(captured/n) for n in sorted(names)}})


def verify(captured,regeneration):
    captured=Path(captured);spec=compile_spec()
    if not protected() or not acceptance(spec,captured,False)['passed']:raise ValueError('mq-24 acceptance failed')
    binding=json.loads((captured/'mq24_binding.json').read_text())
    if binding['inputs']!={n:sha(p) for n,p in input_paths().items()}:raise ValueError('Stale mq-24 source binding')
    if any(sha(captured/n)!=s for n,s in binding['files'].items()):raise ValueError('Stale mq-24 delivery bytes')
    validate_delivery(spec,captured)
    validate_regeneration(spec,captured,regeneration,binding['inputs'])
    print('MQ24_HASH_BOUND_DELIVERY: PASS; regeneration verified',flush=True)


def validate_regeneration(spec,captured,regeneration,inputs):
    regeneration=Path(regeneration);receipt=json.loads((regeneration/'regeneration.json').read_text())
    if (receipt.get('passed') is not True or receipt.get('compiled_spec_hash')!=digest(spec) or receipt.get('inputs')!=inputs or
        receipt.get('cache_reused') is not False or receipt.get('saved_model_reused') is not False):
        raise ValueError('Missing, failed or stale mq-24 regeneration')
    if json.loads((regeneration/'clean_input_sha256.json').read_text())!=inputs:raise ValueError('Stale clean input inventory')
    if not acceptance(spec,regeneration/'capture',False)['passed']:raise ValueError('Regenerated native acceptance failed')
    views=compare_captures(regeneration/'capture',captured,regeneration,True)
    if receipt.get('views')!=views or not all(r['passed'] for v in views.values() for r in v.values()):raise ValueError('Regeneration images differ')


def regenerate(output,reference,diagnostic=False):
    output=fresh(output);project=output/'clean_project';inputs=input_paths()
    for name,path in inputs.items():
        target=project/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
    inventory={n:sha(p) for n,p in inputs.items()};write(output/'clean_input_sha256.json',inventory)
    clean=project/FOLDER.relative_to(PROJECT);compiled=clean/'proof/compiled'
    command=[sys.executable,'-B','-m','spec.art_identity.maquettes.last_lamplighter.mq24.proof','source','--out',str(compiled)]
    result=subprocess.run(command,cwd=project,text=True,capture_output=True);(output/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode and (not diagnostic or not (compiled/'spec_native.json').is_file()):raise ValueError('Fresh copied mq-24 source compilation failed; see compile.log')
    spec_path=compiled/'spec_native.json';spec=json.loads(spec_path.read_text())
    if digest(spec)!=digest(compile_spec()):raise ValueError('Clean mq-24 compiler differs')
    captured=build_capture(spec_path,output,project/BUILDER.relative_to(PROJECT),clean,diagnostic)
    accepted=acceptance(spec,captured);views=compare_captures(captured,reference,output,True)
    image_match=all(r['passed'] for v in views.values() for r in v.values())
    report={'passed':accepted['passed'] and image_match,'accepted':accepted['passed'] and image_match,'images_match':image_match,'diagnostic':diagnostic,'cache_reused':False,
        'saved_model_reused':False,'compiled_spec_hash':digest(spec),'inputs':inventory,'views':views}
    write(output/'regeneration.json',report)
    if diagnostic:
        print('MQ24_DIAGNOSTIC_REGENERATION: '+('MATCH' if image_match else 'DIFFERENT')+'; acceptance='+str(accepted['passed']),flush=True)
        if not image_match:raise ValueError('Diagnostic regeneration pixels differ')
        return
    print('MQ24_CLEAN_REGENERATION: '+('PASS' if report['passed'] else 'FAIL')+'; cache_reused=false; saved_model_reused=false',flush=True)
    if not report['passed']:raise ValueError('Fresh regeneration differs')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation',choices=('source','prove','diagnose','regenerate','verify','stage','revalidate'))
    parser.add_argument('--out',type=Path);parser.add_argument('--capture',type=Path);parser.add_argument('--regeneration',type=Path);parser.add_argument('--draft',action='store_true')
    parser.add_argument('--diagnostic',action='store_true')
    parser.add_argument('--resume',action='store_true')
    args=parser.parse_args()
    if args.draft and args.operation!='source':parser.error('--draft is source-only')
    if args.operation in ('source','prove','diagnose','regenerate','revalidate') and args.out is None:parser.error('--out required')
    if args.operation in ('regenerate','verify','stage','revalidate') and args.capture is None:parser.error('--capture required')
    if args.operation in ('verify','stage','revalidate') and args.regeneration is None:parser.error('--regeneration required')
    if args.operation=='source':return 0 if source(args.out,args.draft)[1]['passed'] else 1
    if args.operation=='diagnose':diagnose(args.out,args.resume);return 0
    if args.operation=='prove':prove(args.out)
    elif args.operation=='regenerate':regenerate(args.out,args.capture,args.diagnostic)
    elif args.operation=='stage':
        from .staging import stage
        stage(args.capture,args.regeneration)
    elif args.operation=='revalidate':
        from .revalidation import revalidate
        revalidate(args.out,args.capture,args.regeneration)
    else:verify(args.capture,args.regeneration)
    return 0


if __name__=='__main__':raise SystemExit(main())
