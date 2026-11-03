"""Keep exact director feedback-1 pixels; never use ignored logs in tests."""
import shutil
import hashlib
import json
from rr37_case import CASE
from cutout_pipeline.cases import read_json, write_json, digest

TARGET = CASE / 'feedback1_fixture'
SELECTION = {('front','idle',12), ('front','cast',12), ('front','cast',29),
             ('front','cast',36), ('front','cast',37), ('rear','idle',12), ('rear','cast',29)}


def compact_layout(layout, original_sha256):
    for mesh in layout['joint_meshes']:
        geometry={k:mesh.pop(k) for k in ('vertices','uvs','triangles','weights')}
        mesh['geometry_sha256']=hashlib.sha256(json.dumps(geometry,sort_keys=True,separators=(',',':')).encode()).hexdigest()
    layout['full_layout_sha256']=original_sha256
    return layout


def retain():
    if (TARGET/'frames.json').exists(): raise ValueError('Immutable feedback fixture already retained')
    source = CASE / 'proof/native'
    manifest = read_json(source / 'frames.json')
    result = {k: manifest[k] for k in ('native_pixels','size','ui_scale','fps','inputs')}
    result.update(selection_only=True, purpose='rejected director feedback 1; negative controls only',
                  source_manifest_sha256=digest(source/'frames.json'),
                  source_gate_log_sha256=digest(CASE/'proof/logs/native_gates.json'))
    files = []
    for key in ('frames','pieces','rest_holes','joint_seams'):
        result[key] = [r for r in manifest.get(key,[]) if (r['view'],r['clip'],r['frame']) in SELECTION]
        files += [r['file'] for r in result[key]]
        files += [r['checks'] for r in result[key] if 'checks' in r]
    files += [v+'_rest.png' for v in ('front','rear')]
    index = read_json(source/'native_storage.json')
    kept = {f:index['files'][f] for f in files}
    for r in kept.values():
        target=TARGET/r['stored_file']; target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(source/r['stored_file'],target)
    write_json(TARGET/'native_storage.json',dict(version=index['version'],files=kept))
    write_json(TARGET/'frames.json',result)
    samples=read_json(CASE/'proof/logs/samples.json')
    write_json(TARGET/'poses.json',{'full_samples_sha256':digest(CASE/'proof/logs/samples.json'),
        'samples':[r for r in samples['samples'] if r['kind']=='presented' and (r['view'],r['clip'],r['frame']) in SELECTION]})
    for view in ('front','rear'):
        for label, root, path in [('case',CASE,CASE/f'layouts/{view}.json'),
                                  ('production',CASE.parents[3]/'assets/units/frostglass_lancer_cutout/humanoid_v2',CASE.parents[3]/f'assets/units/frostglass_lancer_cutout/humanoid_v2/{view}.json')]:
            layout=read_json(path)
            for part in layout['parts']:
                target=TARGET/label/part['file']; target.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(root/part['file'],target)
            write_json(TARGET/label/f'{view}.json',compact_layout(layout,digest(path)))
    print('RR37 FEEDBACK 1 FIXTURE: PASS (7 exact native frames; hash-bound full manifest/log)')

if __name__=='__main__': retain()
