"""Read-only verification of mq-19's sealed delivery and current geometry guards.

The archived production inputs are historical evidence. Current validation code
may improve without resealing/regenerating the director's approved pixels.
"""
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import numpy as np
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,canonical_png
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from tools.unit_preservation import read_bytes
from ..recipe import PROJECT
from .recipe import FOLDER,compile_spec
from .delivery import inspect,DELIVERY_DEFAULTS
from .checks import observe

SEALED_REVISION='8eb6d3ef3'
DIRECTOR_NAMES=('prompt_front.md','prompt_rear.md')


def inventory():
    return {p.relative_to(FOLDER).as_posix() for p in FOLDER.rglob('*')
            if p.is_file() and '__pycache__' not in p.parts}


def verify_inventory():
    listed={n for n in (FOLDER/'COMMIT_MANIFEST.txt').read_text().splitlines() if n and not n.startswith('#')}
    names=inventory()
    if names!=listed:raise ValueError('mq-19 curated inventory differs: '+str(sorted(names^listed)))
    if any('.blend' in Path(n).suffixes or 'cache' in Path(n).parts or 'proof' in Path(n).parts for n in names):
        raise ValueError('mq-19 retained uncurated model/cache/proof')
    director=json.loads((FOLDER/'director_files.json').read_text())
    expected={name:hashlib.sha256(read_bytes(PROJECT,SEALED_REVISION,(FOLDER/name).relative_to(PROJECT).as_posix())).hexdigest() for name in DIRECTOR_NAMES}
    if director.get('revision')!=SEALED_REVISION or director.get('files')!=expected:
        raise ValueError('Protected director inventory differs')
    if any(sha(FOLDER/name)!=value for name,value in expected.items()):raise ValueError('Protected director prompt changed')
    print('MQ19_COMMIT_CURATION: PASS; files='+str(len(names))+'; protected_director_files=2',flush=True)


def verify_bundle(bundle):
    names={p.relative_to(bundle).as_posix() for p in bundle.rglob('*') if p.is_file()}
    listed={n for n in (bundle/'COMMIT_MANIFEST.txt').read_text().splitlines() if n and not n.startswith('#')}
    if names!=listed:raise ValueError('mq-19 delivery inventory differs')
    hashes=json.loads((bundle/'bundle_sha256.json').read_text())
    if names!=set(hashes)|{'bundle_sha256.json','COMMIT_MANIFEST.txt'}:
        raise ValueError('mq-19 incomplete delivery hash inventory')
    for name in ('bundle_sha256.json','COMMIT_MANIFEST.txt'):
        relative=(bundle/name).relative_to(PROJECT).as_posix()
        if (bundle/name).read_bytes()!=read_bytes(PROJECT,SEALED_REVISION,relative):
            raise ValueError('mq-19 delivery seal changed: '+name)
    if any(sha(bundle/n)!=value for n,value in hashes.items()):raise ValueError('mq-19 delivery bytes changed')
    size=sum((bundle/n).stat().st_size for n in names)
    if size>DELIVERY_DEFAULTS['budget_bytes']:raise ValueError('mq-19 delivery exceeds 6 MB')
    for name,value in json.loads((bundle/'mq17_baseline.json').read_text()).items():
        if sha(PROJECT/name)!=value:raise ValueError('mq-19 baseline source changed')
    print('MQ19_CURATED_BUNDLE: PASS; bytes='+str(size)+'; files='+str(len(names)),flush=True)


def verify_archive(bundle,spec):
    expected=json.loads((bundle/'clean_input_sha256.json').read_text())
    with tempfile.TemporaryDirectory(prefix='mq19_verify_archive_') as temporary:
        project=Path(temporary).resolve();recipe=None
        with tarfile.open(fileobj=io.BytesIO((bundle/'source_inputs.tar.xz').read_bytes()),mode='r:xz') as archive:
            for member in archive.getmembers():
                if not member.isfile():raise ValueError('Non-file in source archive')
                raw=archive.extractfile(member).read()
                if member.name=='GENERATED_DESIGN.json':recipe=json.loads(raw);continue
                if member.name not in expected or not (project/member.name).resolve().is_relative_to(project):
                    raise ValueError('Unexpected archived input: '+member.name)
                target=project/member.name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        generated=(FOLDER/'design.json').relative_to(PROJECT).as_posix()
        command='python3 -B -m spec.art_identity.maquettes.storm_cantor.mq19.generate_design'
        if recipe!={'path':generated,'sha256':expected[generated],'command':command}:
            raise ValueError('Archived design recipe differs')
        process=subprocess.run([sys.executable,'-B','-m','spec.art_identity.maquettes.storm_cantor.mq19.generate_design'],cwd=project,text=True,capture_output=True)
        if process.returncode:raise ValueError('Archived design generation failed: '+process.stderr)
        actual={p.relative_to(project).as_posix():sha(p) for p in project.rglob('*') if p.is_file()}
        if actual!=expected:raise ValueError('Archived input hashes differ')
        output=project/'reproduced_spec.json'
        process=subprocess.run([sys.executable,'-B','-m','spec.art_identity.maquettes.storm_cantor.mq19.recipe','--out',str(output)],cwd=project,text=True,capture_output=True)
        if process.returncode or json.loads(output.read_text())!=spec:
            raise ValueError('Archived compilation differs: '+process.stderr)
    print('MQ19_ARCHIVE_REPRODUCTION: PASS; inputs='+str(len(expected))+'; exact_spec=true',flush=True)


def verify_regeneration(bundle,spec):
    result=json.loads((bundle/'regeneration/regeneration.json').read_text());capture=bundle/'delivery'
    # The clean native manifest/raw images were discarded by mq-19 curation.
    # Their raw hashes remain in the Git-sealed receipt. Recompute all four
    # canonical hashes against the retained delivery; do not substitute the
    # staged manifest (packing deliberately changed its raw image hashes).
    if (result.get('passed') is not True or result.get('cache_reused') is not False or
        result.get('saved_model_reused') is not False or result.get('compile_returncode')!=0 or
        result.get('spec_hash')!=digest(spec) or
        result.get('input_sha256')!=json.loads((bundle/'clean_input_sha256.json').read_text()) or
        result.get('native_probe_sha256')!=sha(capture/'mq19_native.json') or
        not valid_sha(result.get('native_manifest_sha256'))):
        raise ValueError('Stale or failed mq-19 regeneration')
    views=result.get('views',{})
    if set(views)!={'front','rear'}:raise ValueError('Incomplete mq-19 regeneration views')
    with tempfile.TemporaryDirectory(prefix='mq19_verify_pixels_') as temporary:
        for view in ('front','rear'):
            if set(views[view])!={'clay','parts'}:raise ValueError('Incomplete mq-19 regeneration outputs')
            for kind in ('clay','parts'):
                name=view+'_'+kind+'.png';row=views[view][kind];canonical=Path(temporary)/name
                canonical_png(capture/name,canonical,mask=kind=='parts')
                if (row.get('passed') is not True or row.get('sha256')!=sha(canonical) or
                    row.get('expected_sha256')!=sha(canonical) or row.get('delivery_file_sha256')!=sha(capture/name) or
                    not valid_sha(row.get('native_file_sha256'))):
                    raise ValueError('mq-19 regenerated pixels differ: '+name)
    print('MQ19_REGENERATION_BINDING: PASS; clays=2/2; part_maps=2/2',flush=True)


def valid_sha(value):
    return isinstance(value,str) and len(value)==64 and value!='0'*64 and all(c in '0123456789abcdef' for c in value)


def verify():
    bundle=FOLDER/'feedback3_delivery';capture=bundle/'delivery';spec=compile_spec()
    verify_inventory();verify_bundle(bundle);validate_delivery(spec,capture)
    if not inspect(spec,capture,False)['passed']:raise ValueError('mq-19 retained native acceptance failed')
    sheet=json.loads((capture/'contact_sheet.json').read_text())
    if sha(capture/'contact_sheet.webp')!=sheet['sheet_sha256']:raise ValueError('Stale mq-19 contact sheet')
    for item in sheet['inputs']:
        path=capture/item['path'] if Path(item['path']).parent==Path('.') else PROJECT/item['path']
        if sha(path)!=item['sha256']:raise ValueError('Stale mq-19 review source: '+str(path))
    verify_archive(bundle,spec);verify_regeneration(bundle,spec)
    points={p['id']+'_render':np.asarray(p['vertices']) for p in spec['pieces']}
    faces={p['id']+'_render':p['faces'] for p in spec['pieces']}
    report=observe(spec,points,spec['joints'],spec['mq19']['bone_forward'],faces)
    if not report['passed']:raise ValueError('mq-19 current geometry guards failed: '+str(report['cloak']['checks']))
    print('MQ19_LIVE_GEOMETRY_GUARDS: PASS; strips='+str(report['cloak']['strip_count'])+'; cloth_rows='+str(len(report['cloak']['cloth_profiles']['rows'])),flush=True)
    print('MQ19_HASH_BOUND_DELIVERY: PASS',flush=True)
    return report
