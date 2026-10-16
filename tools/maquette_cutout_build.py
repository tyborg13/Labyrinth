#!/usr/bin/env python3
"""Build rr-04 from approved paint and cached maquette exports; no art generation."""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
from unittest.mock import patch
import numpy as np
from PIL import Image
import maquette_cutout as builder
from cutout_pipeline.cases import read_json, write_json, digest, baseline
from maquette_motion.compiler import compile_creature

PROJECT = Path(__file__).resolve().parents[1]
SOURCE = PROJECT / 'spec/peer_benchmark/staged/rr-04/motion_tracks.json'
CREATURES = ('shale_bloomer', 'lightning_wisp')
VERSIONS = {'shale_bloomer': 'mq3', 'lightning_wisp': 'mq4'}
RENDER_SIZE = 1024
ORIGINAL_REGISTRATION = builder.registration

def case_for(creature): return PROJECT / 'experiments/cutouts' / creature / VERSIONS[creature]

def registration(raw, record):
    # Replay steps may bind decoded pixels rather than PNG bytes. The builder's
    # registration depends only on the replayed alpha and exact approved sizing.
    expected = record.get("raw_sha256", record.get("raw_steps", [{}])[0].get("inputs", {}).get("raw", {}).get("sha256"))
    if expected != digest(raw): raise builder.CutoutError("Raw source differs from approved record")
    adapted = dict(record, raw_sha256=digest(raw))
    actual = ORIGINAL_REGISTRATION(raw, adapted)
    ratio = actual.trace['raw_size'][0] / RENDER_SIZE
    return builder.Registration([s * ratio for s in actual.scale], actual.offset,
        dict(actual.trace, render_size=RENDER_SIZE, render_to_raw_scale=ratio))

def bind_layout(spec, view, transform, projected_joints, recipe):
    bones = {n: {'position': transform.point(builder.projected(spec, item['position_3d'], view)), 'parent': item['parent']}
             for n,item in recipe['joints'].items()}
    return bones, recipe['parts']

def material_for(creature, part):
    # Material identities are taken from the approved painting prompt: one
    # braided-root material, shale petals and a distinct amber heart. Wisp's
    # lightning is painted onto its cloud, so those labels share one bone/paint.
    if creature == 'lightning_wisp': return 'storm-cloud vapour with painted lightning veins' if part != 'tail' else 'storm-cloud vapour tail'
    if part == 'core': return 'amber crystal heart'
    if part.startswith('petal_'): return 'shale daisy petals'
    return 'dark brown braided roots'

def build(creature, renders, front_raw, rear_raw):
    root = case_for(creature)
    spec_path = PROJECT / 'spec/art_identity/maquettes' / creature / 'spec.json'
    spec = read_json(spec_path)
    compiled = compile_creature(SOURCE, creature, spec)
    data = read_json(SOURCE)[creature]
    recipe = {'character_id': creature, 'joints': {n: {'position_3d': p, 'parent': compiled['parents'][n]} for n,p in compiled['joints_3d'].items()},
              'parts': compiled['parts'], 'motion': 'motion.gd', 'rigid_bones': [], 'contact_feet': [],
              'clips': {n: {'frames': max(6, round(c['seconds'] * 60)), 'duration': c['seconds'], 'loop': c.get('loop', False)} for n,c in data['clips'].items()},
              'design_placeholders': {}, 'materials': {n: material_for(creature, n) for n in spec['labels']},
              'copy_files': [], 'proof_defaults': {'native_fps': 60, 'render_size': RENDER_SIZE}}
    # Art palette categories are retained from the supplied maquette parts;
    # only the exact same part is a donor. No invented material or paint.
    recipe_file = PROJECT / 'experiments/cutouts' / creature / 'rig_recipe.json'
    write_json(recipe_file, recipe)
    jobs = data['art']
    args = argparse.Namespace(spec=spec_path, case=root, front_job=PROJECT/jobs['front'], rear_job=PROJECT/jobs['rear'],
        front_raw=front_raw, rear_raw=rear_raw, renders=renders, rig_recipe=recipe_file,
        view_transforms=None, palette=None, color_config=None, blender=builder.BLENDER,
        task_id='rr-04', resume_scaffold=False, allow_incomplete_renders=False)
    with patch.object(builder, 'registration', registration), patch.object(builder, 'bind_layout', bind_layout):
        report = builder.build(args)
    (root/'director_motion.json').write_bytes(SOURCE.read_bytes())
    write_json(root/'compiled_motion.json', compiled)
    (root/'motion.gd').write_text('extends "res://scripts/maquette_cutout_runtime/motion.gd"\n')
    for view in ('front','rear'):
        layout_path = root/f'layouts/{view}.json'
        layout = read_json(layout_path)
        layout['motion_data'] = 'res://' + str(root.relative_to(PROJECT)/'compiled_motion.json')
        write_json(layout_path, layout)
    config = read_json(root/'cutout.json')
    config['sources'] = sorted(set(config['sources']) | {'director_motion.json', 'compiled_motion.json', 'motion.gd'})
    write_json(root/'cutout.json', config)
    baseline(root)
    return report

def promote(creature):
    root = case_for(creature)
    config = read_json(root/'cutout.json')
    if read_json(root/'hidden_fills/index.json').get('pending_design'): raise builder.CutoutError('Unfilled hidden material; production refused')
    destination = PROJECT/'assets/units'/ (creature+'_cutout')
    destination.mkdir(parents=True, exist_ok=True)
    for view, relative in config['layouts'].items():
        layout = read_json(root/relative)
        for part in layout['parts']:
            target = destination/part['file']; target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(root/part['file'], target)
            Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
        target = destination/view/'rest.png'; target.parent.mkdir(parents=True,exist_ok=True)
        # Exact source rest is an offline partition check, NOT native proof.
        shutil.copyfile(root/f'source/{view}/processed.png',target)
        Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
        layout['rest_source'] = f'{view}/rest.png'
        layout['motion_data'] = 'res://' + str((destination/'compiled_motion.json').relative_to(PROJECT))
        write_json(destination/(view+'.json'),layout)
    shutil.copyfile(root/'compiled_motion.json', destination/'compiled_motion.json')
    write_json(destination/'integration.json', {'ready': True, 'case': str(root.relative_to(PROJECT)),
        'director_sha256': digest(SOURCE), 'native_proof': 'pending design-owner windowed proof',
        'rest_identity': builder.rest_identity(root), 'files': {str(p.relative_to(destination)):digest(p) for p in destination.rglob('*') if p.is_file() and p.name!='integration.json'}})
    return {'ok': True, 'production':str(destination)}

def update_rest_identity_ledger(creature):
    # The legacy entries here are derived rest snapshots, not new painting
    # certifications. Art authority is the exact owner-approved job copy.
    from art_identity_gate import pixel_digest, measure
    path = PROJECT/'spec/art_identity/registry.json'
    registry = read_json(path)
    type = 'bile_bloomer' if creature == 'shale_bloomer' else creature
    scale = read_json(PROJECT/'data/enemies.json')[type]['art_scale']
    data = read_json(SOURCE)[creature]
    for view in ('front','rear'):
        rest = 'assets/units/' + creature + '_cutout/' + view + '/rest.png'
        entry = next((e for e in registry['entries'] if e['path']==rest), None)
        if entry is None:
            entry = {'path':rest};registry['entries'].append(entry)
        entry.update(id=type, kind='creature', entry_kind='legacy', anatomy='', boss=False, art_scale=scale,
            size_class='small' if creature=='lightning_wisp' else 'large',
            pixel_sha256=pixel_digest(Image.open(PROJECT/rest)), metrics=measure(PROJECT/rest, scale, 'creature', ''),
            source_path=data['art'][view]+'/processed.png',
            source_pixel_sha256=read_json(PROJECT/data['art'][view]/'processed.json')['pixel_sha256'],
            owner_approval='rr-04 brief: supplied approved maquette painting; this entry binds its derived rest snapshot, not a worker art verdict.')
    write_json(path,registry)

def seal_density(creature):
    import process_board_density as density
    entry = next(e for e in density.load_registry()['entries'] if e.get('unit_type', e['id']) == ('bile_bloomer' if creature=='shale_bloomer' else creature) and e['dir'].endswith(creature+'_cutout'))
    outputs = read_json(density.MANIFEST)
    failures = density.paint_errors([entry],outputs) + density.rest_errors([entry],outputs)
    if failures: raise builder.CutoutError('Native rebake and --record-rests required: ' + str(failures))
    destination = PROJECT/entry['dir'];path=destination/'integration.json';record=read_json(path)
    record['files']={str(p.relative_to(destination)):digest(p) for p in destination.rglob('*') if p.is_file() and p!=path}
    record['density']={'entry':entry['id'],'parts_pixel_sha256':density.parts_digest(entry),'native_rests':{p:outputs[p] for p in density.rest_paths(entry)}}
    record['native_proof']='density native-rest record complete; final captures remain separately bound'
    write_json(path,record)
    update_rest_identity_ledger(creature)
    return {'ok':True,'density_entry':entry['id']}

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('command',choices=['build','promote','compile','seal-density','record-derived-rests'])
    p.add_argument('--creature', choices=CREATURES, required=True)
    p.add_argument('--rig-recipe',type=Path);p.add_argument('--renders',type=Path);p.add_argument('--front-raw',type=Path);p.add_argument('--rear-raw',type=Path)
    a=p.parse_args()
    if a.command=='build': result=build(a.creature,a.renders,a.front_raw,a.rear_raw)
    elif a.command=='promote': result=promote(a.creature)
    elif a.command=='seal-density': result=seal_density(a.creature)
    elif a.command=='record-derived-rests': update_rest_identity_ledger(a.creature); result={'ok':True}
    else:
        root=case_for(a.creature); result=compile_creature(SOURCE,a.creature,read_json(root/'source/spec.json'), read_json(a.rig_recipe) if a.rig_recipe else None);write_json(root/'compiled_motion.json',result)
    print(json.dumps(result,indent=2))
if __name__=='__main__': main()
