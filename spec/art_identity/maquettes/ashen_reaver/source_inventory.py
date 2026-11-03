"""One required-source contract for clean copying and current-byte validation."""
import hashlib
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.curate_delivery import sha
from .source_measurements import PROJECT

FIGURE='spec/art_identity/maquettes/ashen_reaver'
MAQUETTES='spec/art_identity/maquettes'
FIGURE_DATA=('authoring.json','director_pose.json','director_feedback2.json',
             'feedback1_preservation.json','source_measurements.json','source_caliper_record.json')
BUILDER_ENTRY_POINTS=('build.py','render.py','render_plan.py','recipe_proof.py','exact_native_replay.py')
PACKAGE_STUBS=('spec/__init__.py','spec/art_identity/__init__.py')
PROOF_VERSIONS={
    'mq16_sealed':{'revision':'07d541d9fa47bcf32ca1aca86ccabaed7fe5c968',
                   'sha256':'6a5f676d521dcaf24e03f1c8206d96b328ff2d437b5f9398c5f3d35cbcf683d3'},
    'mq23_inventory_scoping':{'revision':'0241c7dc08792971702d86902f1e97d2ba21db5e',
                            'sha256':'8b26f19f4599b777ca92d72919f254555fc9ed69386a194484aadf9bdc75ff1a'}}
SEALED_INVENTORY_SHA256='18945c02a2a4655e9d3e2056ccce78ba36c0914bfc90908048ed2a8d53afed6e'
VALIDATOR_PINS='mq21_validation_sources.json'


def required_sources(project=PROJECT):
    project=Path(project).resolve();figure=project/FIGURE;builder=project/MAQUETTES/'blender'
    files=set((project/MAQUETTES).glob('*.py')) | set(figure.glob('*.py'))
    files.update(p for p in builder.rglob('*') if p.is_file() and p.suffix!='.pyc' and '__pycache__' not in p.parts)
    files.update(builder/name for name in BUILDER_ENTRY_POINTS)
    files.update(figure/name for name in FIGURE_DATA)
    files.add(project/MAQUETTES/'frostglass_lancer/spec_r3.json')
    source=json.loads((figure/'source_measurements.json').read_text())
    files.update(project/name for name in source['input_sha256'])
    result={}
    for file in sorted(files):
        if not file.is_file() or not file.resolve().is_relative_to(project):
            raise ValueError('Required regeneration source is missing or external: '+str(file))
        result[str(file.relative_to(project))]=file
    # Namespace packages in the checkout use empty init files in the isolated
    # project. An existing init file is copied and bound to its actual bytes.
    for name in PACKAGE_STUBS:
        file=project/name
        result[name]=file if file.is_file() else None
    return result


def source_inventory(project=PROJECT):
    empty=hashlib.sha256(b'').hexdigest()
    current={name:sha(file) if file is not None else empty
            for name,file in sorted(required_sources(project).items())}
    # These two files validate historical evidence; they do not produce its
    # geometry or pixels. Keep every production source binding unchanged.
    # The portable record pins this validator's exact live bytes separately.
    record=json.loads((Path(project)/FIGURE/VALIDATOR_PINS).read_text())
    proof=FIGURE+'/proof.py';inventory=FIGURE+'/source_inventory.py'
    sealed=PROOF_VERSIONS['mq16_sealed']['sha256']
    if (record.get('proof_versions')!=PROOF_VERSIONS
            or current[proof] not in {row['sha256'] for row in PROOF_VERSIONS.values()}
            or record.get('sealed_sha256',{}).get('proof.py')!=sealed
            or record.get('sealed_sha256',{}).get('source_inventory.py')!=SEALED_INVENTORY_SHA256
            or current[inventory]!=record.get('current_sha256',{}).get('source_inventory.py')):
        raise ValueError('Fresh source inventory differs from current source: unapproved proof.py/source_inventory.py verifier bytes')
    current[proof]=sealed;current[inventory]=SEALED_INVENTORY_SHA256
    return current


def copy_required_sources(destination,project=PROJECT):
    destination=Path(destination)
    for name,file in required_sources(project).items():
        target=destination/name;target.parent.mkdir(parents=True,exist_ok=True)
        if file is None:target.write_bytes(b'')
        else:shutil.copyfile(file,target)
    pins=Path(project)/FIGURE/VALIDATOR_PINS
    if not pins.resolve().is_relative_to(Path(project).resolve()):
        raise ValueError('External validation pin record')
    shutil.copyfile(pins,destination/FIGURE/VALIDATOR_PINS)
    return source_inventory(destination)


def validate_source_inventory(saved,project=PROJECT):
    current=source_inventory(project)
    if saved!=current:
        missing=sorted(current.keys()-saved.keys());extra=sorted(saved.keys()-current.keys())
        changed=sorted(name for name in current.keys() & saved.keys() if current[name]!=saved[name])
        raise ValueError('Fresh source inventory differs from current source: '+
                         str({'missing':missing,'extra':extra,'changed':changed}))
    return current
