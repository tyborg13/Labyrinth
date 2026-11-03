"""Bind a clean regeneration to its complete current inputs and delivered pixels."""
import gzip
import hashlib
import json
from pathlib import Path
import tempfile

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import canonical_png,sha
from .recipe import FOLDER

# mq-18's signed unit end: inventory membership cannot grow with other units.
UNIT_HEAD = 'c97ff4e62db05359d692e61b7acfec7477025e66'
INPUT_INVENTORY = 'spec/art_identity/maquettes/last_lamplighter/delivery/validation/regeneration/clean_input_sha256.json.gz'


def input_paths(source=FOLDER):
    from tools.maquette_input_history import input_paths as declared_paths
    return declared_paths(source, UNIT_HEAD, INPUT_INVENTORY)


def current_inputs(source=FOLDER):
    from tools.maquette_input_history import input_hashes
    return input_hashes(source, UNIT_HEAD, INPUT_INVENTORY, {'regeneration_validation.py'})


def materialize_inputs(project):
    from tools.maquette_input_history import materialize_inputs as materialize
    return materialize(project, FOLDER, UNIT_HEAD, INPUT_INVENTORY, {'regeneration_validation.py'})


def validate_regeneration(spec,delivery,source=FOLDER,receipt_dir=None):
    delivery=Path(delivery);folder=Path(receipt_dir) if receipt_dir else delivery/'validation/regeneration'
    report=json.loads((folder/'regeneration.json').read_text())
    if (report.get('passed') is not True or report.get('acceptance_passed') is not True or
        report.get('cache_reused') is not False or report.get('saved_model_reused') is not False or
        report.get('compiled_spec_hash')!=digest(spec)):
        raise ValueError('Fresh regeneration incomplete or uses a stale specification')
    inventory=folder/'clean_input_sha256.json'
    raw=inventory.read_bytes() if inventory.is_file() else gzip.decompress(inventory.with_suffix('.json.gz').read_bytes())
    if hashlib.sha256(raw).hexdigest()!=report.get('input_inventory_sha256'):
        raise ValueError('Invalid regeneration input-inventory digest')
    recorded=json.loads(raw);current=input_paths(source)
    if type(recorded) is not dict or set(recorded)!=set(current):
        raise ValueError('Regeneration input inventory is incomplete or contains unexpected paths')
    expected=current_inputs(source)
    stale=[name for name,path in current.items() if not path.is_file() or recorded[name]!=expected[name]]
    if stale:raise ValueError('Stale regeneration source bytes: '+', '.join(stale))
    views=report.get('views',{})
    if type(views) is not dict or set(views)!={'front','rear'}:
        raise ValueError('Regeneration requires both image comparison views')
    with tempfile.TemporaryDirectory(prefix='mq18_regeneration_verify_') as temporary:
        for view in ('front','rear'):
            if type(views[view]) is not dict or set(views[view])!={'clay','parts'}:
                raise ValueError('Regeneration requires all four image comparisons')
            for kind in ('clay','parts'):
                row=views[view][kind];name=view+'_'+kind+'.png';image=delivery/name
                if type(row) is not dict or row.get('passed') is not True:
                    raise ValueError('Failed regeneration image comparison: '+name)
                target=Path(temporary)/name;canonical_png(image,target,mask=kind=='parts')
                if (row.get('sha256')!=sha(target) or row.get('expected_sha256')!=sha(target) or
                    row.get('delivery_file_sha256')!=sha(image)):
                    raise ValueError('Regeneration comparison is not bound to delivered image: '+name)
    return report
