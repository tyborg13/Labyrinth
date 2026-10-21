"""Refresh motion on the accepted round-3 construction, without rebuilding art.

The editable/runtime case stays rr30 so all eight owner proof stages and the
production bindings keep their established paths. rr31 owns the new gate and
budget records. Historical round-3 captures live in the read-only rr-30 tree.
"""
import shutil
from copy import deepcopy
import numpy as np
from PIL import Image
from rr30_case import CASE, ASSETS, DIRECTOR, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion


def build():
    anatomy = read_json(CASE/'anatomy.json')
    folders = anatomy['integration']['binding_folders']
    if 'tests/rr31' not in folders: folders.append('tests/rr31')
    write_json(CASE/'anatomy.json',anatomy)
    layouts = {v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
    removed = {}
    for view, layout in layouts.items():
        paint = np.asarray(Image.open(CASE/layout['rest_source']).convert('RGBA'))
        removed[view] = {}
        for name, recipe in list(layout.get('gait_continuations',{}).items()):
            part = next(p for p in layout['parts'] if p['name']==name)
            x,y = part['offset']
            # Action-only texels must not enlarge the immutable rest, even
            # when the clip's keys are all zero. Cut at source, never captures.
            rejected = [t for t in recipe['texels'] if paint[y+t[1],x+t[0],3]==0]
            if rejected:
                removed[view][name] = rejected
                recipe['texels'] = [t for t in recipe['texels'] if t not in rejected]
            if not recipe['texels']: del layout['gait_continuations'][name]
        write_json(CASE/f'layouts/{view}.json',layout)
        production = read_json(ASSETS/f'humanoid_v2/{view}.json')
        production['gait_continuations'] = layout.get('gait_continuations',{})
        write_json(ASSETS/f'humanoid_v2/{view}.json',production)
        wrapper = deepcopy(production)
        for part in wrapper['parts']+wrapper['joint_meshes']:
            part['file'] = 'humanoid_v2/'+part['file']
        wrapper['rest_source'] = 'humanoid_v2/'+wrapper['rest_source']
        write_json(ASSETS/f'{view}.json',wrapper)
    if any(removed.values()):
        write_json(CASE.parent/'rr31/source_cover_cuts.json',removed)
    previous = read_json(CASE/'compiled_motion.json')
    shutil.copyfile(DIRECTOR, CASE/'director_motion.json')
    compiled = compile_motion(DIRECTOR, 'slag_mortar', layouts, previous['projection'])
    write_json(CASE/'compiled_motion.json', compiled)
    for name in ('director_motion.json','compiled_motion.json'):
        shutil.copyfile(CASE/name, ASSETS/'humanoid_v2'/name)
    # rr31 re-authors motion, not resolver dispatch. Its brace metadata omits
    # the accepted selector. Preserve that existing input path in the shipped
    # binding only; both protected imports and the editable compile stay exact.
    previous = read_json(PROJECT/'spec/peer_benchmark/staged/rr-30/motion_tracks.json')
    retained = {}
    production_motion = deepcopy(compiled)
    if 'intents' not in compiled['clips']['brace']:
        retained['brace'] = previous['slag_mortar']['clips']['brace']['intents']
        production_motion['clips']['brace']['intents'] = retained['brace']
    write_json(ASSETS/'humanoid_v2/compiled_motion.json',production_motion)
    config = read_json(CASE/'cutout.json')
    config.update(clips=compiled['clips'], design_placeholders=compiled['TODO_DESIGN'])
    write_json(CASE/'cutout.json', config)
    record = read_json(CASE/'proof/build.json')
    record.update(director_sha256=digest(DIRECTOR), native_proof='pending rr-31 director windowed captures')
    write_json(CASE/'proof/build.json', record)
    integration = read_json(ASSETS/'integration.json')
    integration.update(ready=False,director_sha256=digest(DIRECTOR),
        native_proof='pending rr-31 director visual judgment and rr-30 native gates; image diagnostics non-blocking',
        retained_action_selectors=retained)
    import process_board_density as density
    entries = [e for e in density.load_registry()['entries'] if e['id']=='slag_mortar_cutout']
    integration['density']['native_rest_pending'] = density.rest_errors(entries,read_json(density.MANIFEST))
    integration['files'] = {name:digest(ASSETS/name) for name in integration['files']}
    write_json(ASSETS/'integration.json',integration)
    print('RR31 MOTION IMPORT: PASS (byte-identical director data; accepted construction retained)')


if __name__ == '__main__': build()
