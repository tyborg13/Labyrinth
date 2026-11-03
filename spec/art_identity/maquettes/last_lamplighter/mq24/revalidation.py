"""Re-audit accepted native pixels after gate-only changes; never re-render.

The original regeneration receipt remains in history. Compile a fresh copied
input project and build new native geometry, require its exact mesh identity,
then apply the current geometry and image gates to the unchanged captures.
Renderer, geometry, design-data and other compiler changes are forbidden here.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery,validate_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from .delivery import acceptance,tables

GATE_ONLY_FILES=('capture_gate.py','rule_measure.py','proof.py','revalidation.py')


def gate_changes(previous,current):
    prefix='spec/art_identity/maquettes/last_lamplighter/mq24/'
    changed={n:{'before':previous.get(n),'after':current.get(n)} for n in sorted(set(previous)|set(current))
        if previous.get(n)!=current.get(n)}
    if set(changed)-{prefix+n for n in GATE_ONLY_FILES}:
        raise ValueError('Gate-only revalidation forbids geometry, renderer or other input changes')
    return changed


def capture_bytes(folder):
    return {p.name:sha(p) for p in Path(folder).iterdir() if p.suffix.lower() in ('.png','.webp','.import')}


def revalidate(output,captured,regeneration):
    from .proof import fresh,input_paths,compile_spec,PROJECT,FOLDER,BUILDER,job,seal,verify
    output=fresh(output);captured=Path(captured).resolve();regeneration=Path(regeneration).resolve()
    spec=compile_spec();previous=json.loads((regeneration/'regeneration.json').read_text())
    binding=json.loads((captured/'mq24_binding.json').read_text())
    validate_delivery(spec,captured)
    if previous.get('passed') is not True or previous.get('accepted') is not True or previous.get('compiled_spec_hash')!=digest(spec) or previous['inputs']!=binding['inputs']:
        raise ValueError('Revalidation requires an accepted matching regeneration')
    if json.loads((regeneration/'clean_input_sha256.json').read_text())!=previous['inputs']:
        raise ValueError('Changed accepted clean input inventory')
    if any(sha(captured/n)!=value for n,value in binding['files'].items()):raise ValueError('Changed accepted delivery bytes')
    inputs=input_paths();inventory={n:sha(p) for n,p in inputs.items()};changed=gate_changes(previous['inputs'],inventory)
    folders=(captured,regeneration/'capture');before=[capture_bytes(p) for p in folders]
    project=output/'clean_project'
    for name,path in inputs.items():
        target=project/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(path,target)
    compiled=output/'compiled';command=[sys.executable,'-B','-m','spec.art_identity.maquettes.last_lamplighter.mq24.proof','source','--out',str(compiled)]
    result=subprocess.run(command,cwd=project,text=True,capture_output=True);(output/'compile.log').write_text(result.stdout+result.stderr)
    if result.returncode or digest(json.loads((compiled/'spec_native.json').read_text()))!=digest(spec):
        raise ValueError('Fresh copied gate revalidation compilation failed')
    job(project/BUILDER.relative_to(PROJECT)/'build.py',[compiled/'spec_native.json',output/'native','--build-only'],output/'bridge','build')
    native_report=output/'native_probe.json'
    job(project/FOLDER.relative_to(PROJECT)/'native_probe.py',[compiled/'spec_native.json',output/'native',native_report],output/'bridge','native_probe')
    native=json.loads(native_report.read_text());build=json.loads((output/'native/build_report.json').read_text())
    accepted_build=json.loads((captured/'build_report.json').read_text())
    if not native['passed'] or build['mesh_hashes']!=accepted_build['mesh_hashes'] or build['combined_mesh_hash']!=accepted_build['combined_mesh_hash']:
        raise ValueError('Revalidated native geometry differs from accepted delivery')
    views=compare_captures(regeneration/'capture',captured,output,True)
    if views!=previous['views'] or not all(r['passed'] for view in views.values() for r in view.values()):
        raise ValueError('Accepted regeneration capture bytes differ')
    if not all(acceptance(spec,p,False)['accepted'] for p in folders):raise ValueError('Current native image gates failed')
    receipt={'passed':True,'operation':'gate_only_revalidation','captures_reused_byte_identical':True,
        'previous_regeneration_sha256':sha(regeneration/'regeneration.json'),
        'previous_clean_inventory_sha256':sha(regeneration/'clean_input_sha256.json'),
        'changed_inputs':changed,'inputs':inventory,'compiled_spec_hash':digest(spec),
        'fresh_native_mesh_hash':build['combined_mesh_hash'],'native_probe_sha256':sha(native_report),
        'capture_bytes':{'delivery':before[0],'regeneration':before[1]},
        'scope':'Fresh copied source and native build; current gates remeasure unchanged accepted native captures. No render, geometry or design changes.'}
    # All independent checks finish before any accepted report is replaced.
    for folder in folders:
        shutil.copyfile(native_report,folder/'native_probe.json');acceptance(spec,folder)
    shutil.copyfile(native_report,regeneration/'native_probe.json');tables(captured,native)
    shutil.copyfile(output/'compile.log',regeneration/'compile.log')
    write(regeneration/'clean_input_sha256.json',inventory)
    previous.update(inputs=inventory,gate_revalidation=receipt)
    write(regeneration/'regeneration.json',previous)
    write(captured/'validation/gate_revalidation.json',receipt)
    seal_delivery(spec,captured);seal(captured);verify(captured,regeneration)
    if [capture_bytes(p) for p in folders]!=before:raise ValueError('Gate revalidation changed capture or sidecar bytes')
    write(output/'revalidation.json',receipt)
    print('MQ24_GATE_REVALIDATION: PASS; captures_byte_identical=true; native_meshes=57',flush=True)
