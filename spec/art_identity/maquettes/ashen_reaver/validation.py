"""Bind clean regeneration, source/bridge receipts and curated review assets."""
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import canonical_png,sha,write
from .source_measurements import FOLDER,PROJECT
from .source_inventory import validate_source_inventory

RELEASE_FILES=('contact_sheet.webp','contact_sheet.json','per_part_coverage.csv','proportion_table.md',
               'provenance.json','capture_packing.json','native_render_manifest.json','native_capture_manifest.json')
MUTATIONS={'constant_torso','material_index_zero','omitted_cloth_context','disabled_cache_integrity'}


def compare_blade_masks(capture,delivery,compared):
    with tempfile.TemporaryDirectory(prefix='mq16_blade_compare_') as tmp:
        for view in ('front','rear'):
            name=view+'_blade_area.png';source=Path(capture)/name;expected=Path(delivery)/name
            actual=Path(tmp)/name;reference=Path(tmp)/('expected_'+name)
            canonical_png(source,actual,mask=True);canonical_png(expected,reference,mask=True)
            compared[view]['blade_area']={'passed':sha(actual)==sha(reference),'sha256':sha(actual),
                'expected_sha256':sha(reference),'native_file_sha256':sha(source),'delivery_file_sha256':sha(expected)}


def retain_native(output):
    validation=FOLDER/'delivery/validation';validation.mkdir(exist_ok=True)
    target=validation/'native_bridge';target.mkdir(exist_ok=True)
    for file in (Path(output)/'bridge').iterdir():
        if file.is_file():shutil.copyfile(file,target/file.name)
    portable=FOLDER/'proof/portable_mutations.json'
    if not portable.is_file():
        subprocess.run([sys.executable,'-B','-m','spec.art_identity.maquettes.blender.mutation_proof','--out',str(portable)],cwd=PROJECT,check=True)
    shutil.copyfile(portable,validation/'portable_mutations.json')


def receipt_files(folder):
    folder=Path(folder)
    paths=[p for p in (folder/'validation').rglob('*') if p.is_file() and p.name!='receipt_manifest.json']
    paths += [folder/name for name in RELEASE_FILES]
    if any(not p.is_file() or not p.resolve().is_relative_to(folder.resolve()) for p in paths):
        raise ValueError('Missing or external release receipt')
    return {str(p.relative_to(folder)):sha(p) for p in sorted(paths)}


def retain_fresh(output):
    output=Path(output);folder=FOLDER/'delivery';validation=folder/'validation';validation.mkdir(exist_ok=True)
    for source,name in [('regeneration.json','fresh_regeneration.json'),('clean_input_sha256.json','fresh_clean_input_sha256.json'),
                        ('source_compile.log','fresh_source_compile.log'),('capture/native_probe.json','fresh_native_probe.json'),
                        ('capture/capture_manifest.json','fresh_capture_manifest.json')]:
        shutil.copyfile(output/source,validation/name)
    target=validation/'fresh_bridge';target.mkdir(exist_ok=True)
    for file in (output/'bridge').iterdir():
        if file.is_file():shutil.copyfile(file,target/file.name)
    write(validation/'receipt_manifest.json',{'schema':1,'files':receipt_files(folder)})


def validate_receipts(spec,folder):
    folder=Path(folder);validation=folder/'validation'
    manifest=json.loads((validation/'receipt_manifest.json').read_text())
    if manifest.get('files')!=receipt_files(folder):raise ValueError('Stale or incomplete release receipt inventory')
    fresh=json.loads((validation/'fresh_regeneration.json').read_text())
    if (fresh.get('passed') is not True or fresh.get('spec_hash')!=digest(spec)
            or fresh.get('cache_reused') is not False or fresh.get('saved_model_reused') is not False
            or fresh.get('source_recompiled') is not True):
        raise ValueError('Missing or failed fresh source regeneration')
    if fresh['input_inventory_sha256']!=sha(validation/'fresh_clean_input_sha256.json'):
        raise ValueError('Fresh input inventory binding differs')
    inputs=json.loads((validation/'fresh_clean_input_sha256.json').read_text())
    if any(Path(name).suffix in ('.blend','.pyc') or Path(name).name=='measurements.json' for name in inputs):
        raise ValueError('Fresh inputs reused generated native geometry/model/cache')
    validate_source_inventory(inputs)
    native=json.loads((validation/'fresh_native_probe.json').read_text())
    build=json.loads((folder/'build_report.json').read_text())
    if native.get('passed') is not True or native.get('native_mesh_hash')!=build['combined_mesh_hash']:
        raise ValueError('Fresh native geometry differs')
    capture=json.loads((validation/'fresh_capture_manifest.json').read_text())
    if capture.get('spec_hash')!=digest(spec):raise ValueError('Stale fresh capture')
    with tempfile.TemporaryDirectory(prefix='mq16_fresh_verify_') as tmp:
        for view in ('front','rear'):
            for kind in ('clay','parts','blade_area'):
                name=view+'_'+kind+'.png';row=fresh['views'][view][kind]
                target=Path(tmp)/name;canonical_png(folder/name,target,mask=kind!='clay')
                if (row.get('passed') is not True or row['sha256']!=row['expected_sha256'] or sha(target)!=row['sha256']
                        or row['delivery_file_sha256']!=sha(folder/name)
                        or row['native_file_sha256']!=capture['images'][name]['sha256']):
                    raise ValueError('Fresh render binding differs: '+name)
    mutations=json.loads((validation/'portable_mutations.json').read_text())
    if set(mutations)!=MUTATIONS or not all(row.get('caught') is True for row in mutations.values()):
        raise ValueError('Missing or surviving portable mutation')
    for path in list((validation/'native_bridge').glob('*.json'))+list((validation/'fresh_bridge').glob('*.json')):
        value=json.loads(path.read_text())
        if value.get('exit')!=0 or value.get('timeout_s')!=110 or value.get('response_timeout_s')!=120:
            raise ValueError('Failed or unbounded bridge receipt: '+str(path))
    packing=json.loads((folder/'capture_packing.json').read_text())
    if packing.get('native_clay_bytes_unchanged') is not True or packing.get('alpha_and_visible_rgba_unchanged') is not True:
        raise ValueError('Packing changed native paint or mask pixels')
    for name,row in packing['images'].items():
        if row['packed_sha256']!=sha(folder/name) or (name.endswith('_clay.png') and row['native_sha256']!=sha(folder/name)):
            raise ValueError('Stale packed/native PNG binding: '+name)
    return {'passed':True,'fresh_clays':2,'fresh_part_maps':2,'fresh_blade_area_masks':2,'portable_mutations_caught':4,
            'receipt_manifest_sha256':sha(validation/'receipt_manifest.json')}
