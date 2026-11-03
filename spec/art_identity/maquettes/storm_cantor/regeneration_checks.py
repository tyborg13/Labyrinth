"""Read-only validation of clean inputs, execution results and delivered pixels.

The inventory is derived independently of the receipt. A self-consistent empty
inventory, summary PASS, or hashes copied from a previous run cannot certify
current sources. Canonical hashes allow Blender's volatile PNG stamps; raw
hashes stay bound to the retained fresh capture manifest.
"""
import json
from pathlib import Path
import tempfile

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,canonical_png,write
from spec.art_identity.maquettes.blender.delivery_validation import REPORTS
from .recipe import FOLDER,PROJECT
from .layout_checks import validate_preserved

# mq-17's signed unit end; mq-16 later changed the shared render module.
UNIT_HEAD = 'ec03a241c458c899bc68a36b6983b20abe17ca53'
INPUT_INVENTORY = 'spec/art_identity/maquettes/storm_cantor/delivery/validation/regeneration/clean_input_sha256.json'
# The clean compiler/native entry points never execute these orchestration and
# receipt validators. Retain their original receipt bytes; native inputs stay live.
VALIDATION_MODULES = {'regeneration_checks.py', 'proof.py'}


def source_paths():
    from tools.maquette_input_history import input_paths
    return list(input_paths(FOLDER, UNIT_HEAD, INPUT_INVENTORY).values())


def current_inputs():
    from tools.maquette_input_history import input_hashes
    return input_hashes(FOLDER, UNIT_HEAD, INPUT_INVENTORY, VALIDATION_MODULES)


def materialize_inputs(project):
    from tools.maquette_input_history import materialize_inputs as materialize
    return materialize(project, FOLDER, UNIT_HEAD, INPUT_INVENTORY, VALIDATION_MODULES)


def approved_artifacts(spec,delivery):
    validate_preserved(spec)
    approved=json.loads((FOLDER/'feedback3_delivery_sha256.json').read_text())
    images={p.name:sha(p) for p in sorted(Path(delivery).iterdir()) if p.suffix in ('.png','.webp')}
    if approved['compiled_spec_hash']!=digest(spec) or approved['image_sha256']!=images:
        raise ValueError('Current volume delivery spec or image bytes changed')


def seal_artifacts(spec,delivery):
    """Explicit staging, never an implicit approval or verification side effect."""
    validate_preserved(spec)
    write(FOLDER/'feedback3_delivery_sha256.json',{'compiled_spec_hash':digest(spec),
        'image_sha256':{p.name:sha(p) for p in sorted(Path(delivery).iterdir()) if p.suffix in ('.png','.webp')},
        'scope':'Native delivery from director feedback 3 volume targets. Historical feedback 2 approval remains unchanged.'})


def valid_sha(value):
    return (isinstance(value,str) and len(value)==64 and value!='0'*64 and
            all(c in '0123456789abcdef' for c in value))


def validate_regeneration(spec,delivery):
    delivery=Path(delivery);folder=delivery/'validation/regeneration'
    result=json.loads((folder/'regeneration.json').read_text())
    inventory_path=folder/'clean_input_sha256.json'
    inventory=json.loads(inventory_path.read_text())
    if not inventory or inventory!=current_inputs() or result.get('input_inventory_sha256')!=sha(inventory_path):
        raise ValueError('Missing, stale or incomplete clean input inventory')
    if (result.get('schema')!=2 or result.get('passed') is not True or
        result.get('comparison_required') is not True or result.get('cache_reused') is not False or
        result.get('saved_model_reused') is not False or type(result.get('compile_returncode')) is not int or
        result['compile_returncode']!=0 or result.get('native_geometry_unchanged') is not True or
        result.get('compiled_spec_hash')!=digest(spec)):
        raise ValueError('Missing or failed clean regeneration execution/results')
    jobs=result.get('bridge_jobs',{})
    from .capture_workflow import CAPTURE_DEFAULTS
    expected_jobs={'build','fresh_native_probe'}|{view+'_preview' for view in ('front','rear')}
    expected_jobs|={view+'_solo_'+str(start) for view in ('front','rear')
                    for start in range(0,len(spec['labels']),CAPTURE_DEFAULTS['solo_batch_size'])}
    if set(jobs)!=expected_jobs:
        raise ValueError('Missing fresh native bridge results')
    for name in jobs:
        receipt=json.loads((folder/'bridge'/name).with_suffix('.json').read_text())
        if (jobs[name]!=sha((folder/'bridge'/name).with_suffix('.json')) or
            type(receipt.get('exit')) is not int or receipt['exit']!=0 or
            receipt.get('timeout_s')!=110 or receipt.get('response_timeout_s')!=120):
            raise ValueError('Failed/stale regeneration bridge receipt: '+name)
    manifest_path=folder/'regenerated_capture_manifest.json'
    manifest=json.loads(manifest_path.read_text())
    if result.get('capture_manifest_sha256')!=sha(manifest_path) or manifest.get('spec_hash')!=digest(spec):
        raise ValueError('Missing or stale regenerated capture manifest')
    views=result.get('views',{})
    if set(views)!={'front','rear'}:raise ValueError('Incomplete regeneration views')
    with tempfile.TemporaryDirectory(prefix='mq17_verify_png_') as temporary:
        for view in ('front','rear'):
            if set(views[view])!={'clay','parts'}:raise ValueError('Incomplete regeneration outputs')
            for kind in ('clay','parts'):
                name=view+'_'+kind+'.png';item=views[view][kind]
                hashes=('sha256','expected_sha256','native_file_sha256','delivery_file_sha256')
                if item.get('passed') is not True or any(not valid_sha(item.get(k)) for k in hashes):
                    raise ValueError('Failed or invalid regenerated output: '+name)
                canonical=Path(temporary)/name;canonical_png(delivery/name,canonical,mask=kind=='parts')
                if (item['sha256']!=sha(canonical) or item['expected_sha256']!=sha(canonical) or
                    item['delivery_file_sha256']!=sha(delivery/name) or
                    item['native_file_sha256']!=manifest.get('images',{}).get(name,{}).get('sha256')):
                    raise ValueError('Regeneration hashes are not bound to delivered pixels: '+name)
    binding=result.get('native_reports',{})
    build=json.loads((delivery/'build_report.json').read_text())
    required=set(REPORTS)|set(spec['delivery_reports'])|{'capture_manifest.json'}
    reports=binding.get('report_sha256',{})
    if (binding.get('spec_hash')!=digest(spec) or binding.get('cold_mesh_hash')!=build['combined_mesh_hash'] or
        binding.get('exact_native_replay_sha256')!=sha(delivery/'exact_native_replay.json') or
        set(reports)!=required or any(not valid_sha(v) for v in reports.values()) or
        reports['capture_manifest.json']!=sha(manifest_path) or reports['native_probe.json']!=sha(delivery/'native_probe.json')):
        raise ValueError('Failed, incomplete or stale regenerated native results')
    return result
