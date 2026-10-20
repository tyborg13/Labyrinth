"""rr-29: replay mq11 cuts with rr20 rules and recompute rr28 texel donors."""
from copy import deepcopy
from pathlib import Path
import shutil
import sys
from case import ROOT, ASSETS, VIEWS, read_json, write_json, digest
from build import build_view
from rr29_source import prepare as prepare_mq11
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.gait_continuations import nearest_donors, errors as continuation_errors
from humanoid_cutout.promotion import promote
from PIL import Image

CASE = Path(__file__).parent / 'rr29'
DIRECTOR = ROOT / 'spec/peer_benchmark/staged/rr-29/motion_tracks.json'
BASE = Path(__file__).parent / 'rr20'


def build():
    CASE.mkdir(exist_ok=True)
    anatomy = read_json(BASE/'anatomy.json')
    anatomy['integration']['binding_folders'].append('tests/rr29')
    anatomy['integration']['binding_files'].append('draw_order.gd')
    anatomy['integration']['owner_approval'] = 'mq11 director paintings; rr29 native acceptance pending director'
    write_json(CASE/'anatomy.json', anatomy)
    inputs = read_json(BASE/'inputs.json')
    inputs['design_placeholders'] = read_json(CASE/'proof_status.json')['design_followups']
    for view in VIEWS:
        inputs[view+'_job'] = f'spec/art_identity/jobs/hollow_mimic/mq11_{view}'
        receipt = 'director_08' if view == 'front' else 'director_06'
        inputs[view+'_delivery'] = f'tests/mq11_proof/{receipt}/hollow_mimic/capture'
    write_json(CASE/'inputs.json', inputs)
    # Same declared geometric domains; donors and all texels are re-derived.
    for name in ('joint_continuations.json', 'source_underlaps.json'):
        if not (CASE/name).exists(): shutil.copyfile(BASE/name, CASE/name)
    shutil.copyfile(DIRECTOR, CASE/'director_motion.json')
    layouts, reports, projection = {}, {}, {}
    for view in VIEWS:
        layouts[view], reports[view], projection[view] = build_view(view, inputs, anatomy,
            case=CASE, director=DIRECTOR, clean_residue=False, prepare_source=prepare_mq11)
    data = compile_motion(DIRECTOR, 'hollow_mimic', layouts, projection)
    write_json(CASE/'compiled_motion.json', data)
    definitions = read_json(Path(__file__).parent/'rr28/joint_continuations.json')
    for view, layout in layouts.items():
        for name, definition in definitions.get(view, {}).items():
            part = next(p for p in layout['parts'] if p['name'] == name)
            # rr28 targets are crop-local: re-register in new source coordinates.
            old = next(p for p in read_json(BASE/f'layouts/{view}.json')['parts'] if p['name'] == name)
            targets = [[x+old['offset'][0]-part['offset'][0], y+old['offset'][1]-part['offset'][1]]
                       for x,y in definition['local_targets']]
            with Image.open(CASE/part['file']) as image:
                targets = [[x,y] for x,y in targets if 0 <= x < image.width and 0 <= y < image.height
                           and image.getpixel((x,y))[3] == 0]
            recipe = nearest_donors(CASE, layout, part, targets)
            recipe['clips'] = definition['clips']
            layout.setdefault('gait_continuations', {})[name] = recipe
        scoped = CASE/'clip_continuation_targets.json'
        for clip, pieces in (read_json(scoped).get(view, {}) if scoped.exists() else {}).items():
            for name, definition in pieces.items():
                part = next(p for p in layout['parts'] if p['name'] == name)
                base = layout.get('gait_continuations', {}).get(name, {})
                targets = definition['local_targets'] + [[x,y] for x,y,_,_ in base.get('texels', [])]
                targets = [list(p) for p in sorted(set(map(tuple, targets)), key=lambda p:(p[1],p[0]))]
                layout.setdefault('clip_continuations', {}).setdefault(clip, {})[name] = nearest_donors(CASE, layout, part, targets)
        failures = continuation_errors(CASE, layout)
        if failures: raise ValueError(failures)
        write_json(CASE/f'layouts/{view}.json', layout)
    write_json(CASE/'cutout.json', {'character_id':'hollow_mimic', 'rig':'humanoid_v2',
        'layouts':{v:f'layouts/{v}.json' for v in VIEWS},'clips':data['clips'],
        'direction_clips':['bolt','mirror'], 'design_placeholders':inputs['design_placeholders'],
        'runtime_paths':['scripts/maquette_cutout_runtime/humanoid_motion.gd',
            'scripts/maquette_cutout_runtime/humanoid_presentation.gd',
            'assets/units/hollow_mimic_cutout/rig.gd', 'assets/units/hollow_mimic_cutout/draw_order.gd']})
    promote(ROOT, CASE, ASSETS, layouts)
    write_json(CASE/'proof/build.json', dict(reports['front'], views=reports,
        director_sha256=digest(DIRECTOR), native_proof='pending director windowed captures'))
    for folder in (CASE, ASSETS):
        for p in folder.rglob('*.png'):
            if 'proof' not in p.relative_to(folder).parts:
                Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    for view in VIEWS:
        print(f'RR29 {view.upper()} SOURCE REST: {reports[view]["rest_mismatch_pixels"]} px mismatch; '
              f'{reports[view]["presentation_changed_pixels"]} presentation changes')


if __name__ == '__main__': build()
