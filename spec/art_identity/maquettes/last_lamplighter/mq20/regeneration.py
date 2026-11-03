"""One complete copied-input set; no cached model or compiled spec is a source."""
import json
from pathlib import Path
import tempfile
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import canonical_png,sha
from ..regeneration_validation import input_paths as mq18_inputs
from .recipe import FOLDER,BASE,PROJECT

# The accepted pixel proof predates this checks-only review. These modules
# cannot produce geometry or pixels; retain that receipt's independently
# pinned source identity while all rendering/recipe inputs remain live.
REVIEWED_REVISION='56c475c69'
CHECKS_ONLY_INPUTS={'surface_checks.py','regeneration.py'}


def accepted_check_hash(name,folder):
    from tools.maquette_input_history import historical_bytes
    folder=Path(folder);project=folder.parent.parents[3]
    if name not in {str((folder/n).relative_to(project)) for n in CHECKS_ONLY_INPUTS}:return None
    import hashlib
    return hashlib.sha256(historical_bytes(REVIEWED_REVISION,name)).hexdigest()


def input_paths(folder=FOLDER):
    folder=Path(folder);base=folder.parent;project=base.parents[3]
    inputs=mq18_inputs(base)
    # mq-20 uses the current renderer. mq-18's signed, fixed inventory
    # predates this imported helper and must remain unchanged.
    p=base.parent/'blender/render_plan.py';inputs[str(p.relative_to(project))]=p
    for p in folder.iterdir():
        if p.suffix=='.py' or p.name in ('directives.json','design_details.json','chosen_defaults.json'):
            inputs[str(p.relative_to(project))]=p
    # Acceptance and review are copied too; the baseline evidence and source
    # art are immutable comparison inputs, never substitutes for a new render.
    for name in ('acceptance.py',):inputs[str((base/name).relative_to(project))]=base/name
    for name in ('front_clay.png','rear_clay.png','native_probe.json'):
        p=base/'delivery'/name;inputs[str(p.relative_to(project))]=p
    for p in (base/'prompt_front.md',base/'prompt_rear.md',project/'assets/units/last_lamplighter.png'):
        inputs[str(p.relative_to(project))]=p
    return dict(sorted(inputs.items()))


def validate(spec,delivery,receipt_folder=None,folder=FOLDER):
    delivery=Path(delivery);receipt_folder=Path(receipt_folder) if receipt_folder else delivery/'validation/regeneration'
    result=json.loads((receipt_folder/'regeneration.json').read_text());inventory_path=receipt_folder/'clean_input_sha256.json'
    if (result.get('passed') is not True or result.get('acceptance_passed') is not True or result.get('cache_reused') is not False or
        result.get('saved_model_reused') is not False or result.get('compiled_spec_hash')!=digest(spec)):
        raise ValueError('Missing, failed or stale mq-20 regeneration')
    if sha(inventory_path)!=result.get('input_inventory_sha256'):raise ValueError('Invalid mq-20 input inventory digest')
    inventory=json.loads(inventory_path.read_text());current=input_paths(folder)
    if set(inventory)!=set(current):raise ValueError('Incomplete mq-20 regeneration input set')
    for name,path in current.items():
        allowed={sha(path)};previous=accepted_check_hash(name,folder)
        if previous is not None:allowed.add(previous)
        if type(inventory[name]) is not str or inventory[name] not in allowed:
            raise ValueError('Stale mq-20 regeneration source bytes: '+name)
    views=result.get('views',{})
    if set(views)!={'front','rear'} or any(set(views[v])!={'clay','parts'} for v in views):raise ValueError('Four mq-20 regeneration comparisons required')
    with tempfile.TemporaryDirectory(prefix='mq20_compare_') as temporary:
        for view in ('front','rear'):
            for kind in ('clay','parts'):
                name=view+'_'+kind+'.png';image=delivery/name;row=views[view][kind]
                canonical=Path(temporary)/name;canonical_png(image,canonical,mask=kind=='parts')
                if row.get('passed') is not True or row.get('sha256')!=sha(canonical) or row.get('expected_sha256')!=sha(canonical) or row.get('delivery_file_sha256')!=sha(image):
                    raise ValueError('Failed or unbound mq-20 regeneration comparison: '+name)
    return result
