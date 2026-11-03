"""Rebind path-only authoring changes to byte-identical accepted native proof.

This performs a fresh isolated source compilation. It retains the accepted
native captures explicitly; it never claims another renderer build occurred.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,write
from ..source_measurements import FOLDER,PROJECT
from ..recipe import compile_spec as baseline
from .mq21_recipe import compile_spec

REBINDING_METADATA={
    'mq21_input_sha256.json','mq21_regeneration.json','mq21_receipt.json',
    'validation/fresh_source_compile.log','validation/mq16/regeneration.json',
    'validation/mq16/source_compile.log','validation/source_rebinding.json'}
SEALED_VALIDATION_REVISION='eb6e164dde5fe5799b7cc92cb59e592d423f39fc'
SEALED_VALIDATION_SOURCES={
    'proof.py':'6a5f676d521dcaf24e03f1c8206d96b328ff2d437b5f9398c5f3d35cbcf683d3',
    'source_inventory.py':'18945c02a2a4655e9d3e2056ccce78ba36c0914bfc90908048ed2a8d53afed6e',
    'mq21_proof/mq21_mq16_regeneration.py':'7322098eece950bdb910350cecbf396aee9fb567e2eebe31165d6f831cef74a7',
    'mq21_proof/workflow.py':'32a8cef8f152d567c8247a5b2acda4a8b38cfa079da12b5bb598cd6b762d5561',
    'mq21_proof/mq21_sources.py':'91d1bf923d16f3d49da3d066821c8382b6745ceb22b6223457204dcff1d5a05c'}


def validation_source_hashes(project=PROJECT):
    """Bind exact live validators independently of historical native inputs.

    The sealed Git hashes are portable, so an isolated verification checkout
    needs neither the author checkout nor its Git metadata. No production
    compiler, renderer, asset or design file is admitted by this exception.
    """
    project=Path(project);relative=FOLDER.relative_to(PROJECT);figure=project/relative
    record=json.loads((figure/'mq21_validation_sources.json').read_text())
    if (record.get('sealed_revision')!=SEALED_VALIDATION_REVISION
            or record.get('sealed_sha256')!=SEALED_VALIDATION_SOURCES
            or set(record.get('current_sha256',{}))!=set(SEALED_VALIDATION_SOURCES)):
        raise ValueError('Invalid sealed validation source inventory')
    if any(sha(figure/name)!=value for name,value in record['current_sha256'].items()):
        raise ValueError('Approved validation source changed')
    # The editable record never widens mq-16's own allowlist of verifier bytes.
    from ..source_inventory import PROOF_VERSIONS
    if record['current_sha256']['proof.py'] not in {row['sha256'] for row in PROOF_VERSIONS.values()}:
        raise ValueError('Approved validation source changed: unapproved proof.py')
    return {str(relative/name):value for name,value in SEALED_VALIDATION_SOURCES.items()}


def preserved_files(delivery):
    return {str(p.relative_to(delivery)):sha(p) for p in sorted(delivery.rglob('*'))
            if p.is_file() and str(p.relative_to(delivery)) not in REBINDING_METADATA}


def validate_transition(previous,current):
    prefix=str(FOLDER.relative_to(PROJECT))+'/'
    restored={prefix+name for name in ('director_pose.json','recipe.py','source_inventory.py')}
    changed={name for name in previous.keys() & current.keys() if previous[name]!=current[name]}
    removed=previous.keys()-current.keys();added=current.keys()-previous.keys()
    def old_module(name):
        relative=name.removeprefix(prefix)
        return name.startswith(prefix) and '/' not in relative and relative.startswith('mq21_') and relative.endswith('.py')
    if (not changed<=restored or not all(old_module(name) or name==prefix+'mq16_pose.json' for name in removed)
            or not all(name.startswith(prefix+'mq21_proof/') and name.endswith('.py') or name==prefix+'mq21_pose.json' for name in added)
            or current.get(prefix+'mq21_pose.json')!=previous.get(prefix+'director_pose.json')
            or current.get(prefix+'director_pose.json')!=previous.get(prefix+'mq16_pose.json')):
        raise ValueError('Source rebinding exceeds the approved mq-16 restoration and mq-21 path isolation')
    pins=json.loads((FOLDER/'mq21_feedback1_restoration.json').read_text())['mq16_baseline_sha256']
    sealed=validation_source_hashes()
    if any(not (PROJECT/name).is_file() or sealed.get(name,sha(PROJECT/name))!=expected for name,expected in pins.items()):
        raise ValueError('mq-16 baseline bytes differ during source rebinding')
    return digest(pins)


def rebind():
    from .workflow import DELIVERY,inventory,copy_sources,PROOF_DEFAULTS
    receipt=json.loads((DELIVERY/'mq21_receipt.json').read_text())
    files={str(p.relative_to(DELIVERY)):sha(p) for p in DELIVERY.rglob('*')
           if p.is_file() and p.name!='mq21_receipt.json'}
    if receipt['files']!=files:raise ValueError('Accepted delivery changed before source rebinding')
    reports={name:json.loads((DELIVERY/name).read_text()) for name in
             ('mq21_regeneration.json','validation/mq16/regeneration.json')}
    specs={'mq21':compile_spec(),'mq16':baseline()}
    for key,name in (('mq21','mq21_regeneration.json'),('mq16','validation/mq16/regeneration.json')):
        if digest(specs[key])!=reports[name]['spec_hash']:
            raise ValueError('Source rebinding would change '+key+' geometry')
    inputs=inventory();previous=reports['mq21_regeneration.json']['input_sha256']
    pins_digest=validate_transition(previous,inputs);preserved=preserved_files(DELIVERY)
    with tempfile.TemporaryDirectory(prefix='mq23_source_rebinding_') as temp:
        project=Path(temp)
        if copy_sources(project)!=inputs:raise ValueError('Rebinding source copy differs')
        code=('from pathlib import Path\n'
              'from spec.art_identity.maquettes.ashen_reaver.mq21_proof.mq21_recipe import compile_spec,FOLDER\n'
              'from spec.art_identity.maquettes.ashen_reaver.recipe import compile_spec as baseline\n'
              'from spec.art_identity.maquettes.blender.curate_delivery import write\n'
              'assert FOLDER.is_relative_to(Path.cwd()), "Compiler escaped isolated source copy"\n'
              'write(Path("source_specs.json"),{"mq21":compile_spec(),"mq16":baseline()})\n')
        run=subprocess.run([sys.executable,'-B','-c',code],cwd=project,text=True,capture_output=True,
                           timeout=PROOF_DEFAULTS['source_timeout_seconds'])
        if run.returncode:raise ValueError('Isolated rebinding compilation failed: '+run.stdout+run.stderr)
        if json.loads((project/'source_specs.json').read_text())!=specs:
            raise ValueError('Isolated rebinding changes compiled geometry')
    compiled={name:digest(spec) for name,spec in specs.items()}
    log=json.dumps({'result':'MQ23_ISOLATED_SOURCE_REBINDING: PASS','compiled_spec_hashes':compiled,
                    'native_evidence':'retained accepted native build/captures; no renderer recapture claimed'},sort_keys=True)+'\n'
    for name in ('validation/fresh_source_compile.log','validation/mq16/source_compile.log'):
        (DELIVERY/name).write_text(log)
    evidence={'schema':1,'source_recompiled':True,'native_evidence_retained':True,
              'compiled_spec_hashes':compiled,'input_inventory_digest':digest(inputs),
              'previous_input_sha256':previous,'mq16_baseline_pins_digest':pins_digest,
              'source_compile_log_sha256':sha(DELIVERY/'validation/fresh_source_compile.log'),
              'preserved_delivery_sha256':preserved}
    path=DELIVERY/'validation/source_rebinding.json';write(path,evidence)
    for name,report in reports.items():
        report['input_sha256']=inputs;report['source_rebinding_sha256']=sha(path);write(DELIVERY/name,report)
    write(DELIVERY/'mq21_input_sha256.json',inputs)
    verify()
    print('MQ23_SOURCE_REBINDING: PASS; isolated_compilers=2/2; preserved_delivery_files='+str(len(preserved)))


def verify():
    from .workflow import DELIVERY,inventory
    path=DELIVERY/'validation/source_rebinding.json'
    if not path.exists():return
    evidence=json.loads(path.read_text())
    pins_digest=validate_transition(evidence['previous_input_sha256'],inventory())
    if (evidence.get('schema')!=1 or evidence.get('source_recompiled') is not True
            or evidence.get('native_evidence_retained') is not True
            or evidence.get('mq16_baseline_pins_digest')!=pins_digest
            or evidence.get('input_inventory_digest')!=digest(inventory())
            or evidence.get('compiled_spec_hashes')!={'mq21':digest(compile_spec()),'mq16':digest(baseline())}
            or evidence.get('preserved_delivery_sha256')!=preserved_files(DELIVERY)):
        raise ValueError('Invalid source-equivalent delivery rebinding')
    for name in ('validation/fresh_source_compile.log','validation/mq16/source_compile.log'):
        if sha(DELIVERY/name)!=evidence['source_compile_log_sha256']:
            raise ValueError('Source rebinding compiler log changed')
    for name in ('mq21_regeneration.json','validation/mq16/regeneration.json'):
        if json.loads((DELIVERY/name).read_text()).get('source_rebinding_sha256')!=sha(path):
            raise ValueError('Source rebinding receipt changed')
