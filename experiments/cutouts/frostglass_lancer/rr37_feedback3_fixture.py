"""Retain immutable round-2 native pixels before repairing their source cuts."""
import shutil
from rr37_case import CASE
from rr37_fixture import compact_layout
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_frames import frame_digest

TARGET = CASE / 'feedback3_fixture'
SELECTION = {('front', 'cast', 0), ('front', 'cast', 4), ('front', 'cast', 12),
             ('front', 'lunge', 20), ('front', 'guard', 25), ('rear', 'lunge', 36),
             ('rear', 'cast', 0)}


def retain():
    if TARGET.exists(): raise ValueError('Immutable round-2 fixture already retained')
    capture = CASE / 'proof/native'
    source = CASE / 'proof/production_case'
    full = read_json(capture / 'frames.json')
    report = {k: full[k] for k in ('native_pixels', 'size', 'ui_scale', 'fps', 'inputs')}
    report.update(selection_only=True, source_manifest_sha256=digest(capture/'frames.json'),
                  source_gate_log_sha256=digest(CASE/'proof/logs/native_gates.json'),
                  purpose='director feedback 3: rejected round-2 native surfaces; two rest controls')
    files = []
    for key in ('frames', 'pieces', 'rest_holes', 'joint_seams'):
        report[key] = [r for r in full[key] if (r['view'], r['clip'], r['frame']) in SELECTION]
        for row in report[key]:
            assert frame_digest(capture/row['file']) == row['sha256']
            files.append(row['file'])
            if 'checks' in row:
                assert frame_digest(capture/row['checks']) == row['checks_sha256']
                files.append(row['checks'])
    files += [v+'_rest.png' for v in ('front', 'rear')]
    index = read_json(capture/'native_storage.json')
    kept = {f: index['files'][f] for f in files}
    for row in kept.values():
        target = TARGET/row['stored_file']; target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(capture/row['stored_file'], target)
    write_json(TARGET/'native_storage.json', dict(version=index['version'], files=kept))
    write_json(TARGET/'frames.json', report)
    samples = source/'proof/logs/samples.json'
    write_json(TARGET/'poses.json', {'full_samples_sha256': digest(samples),
        'samples': [r for r in read_json(samples)['samples'] if r['kind']=='presented'
                    and (r['view'], r['clip'], r['frame']) in SELECTION]})
    for view in ('front', 'rear'):
        layout_path = source/f'layouts/{view}.json'
        layout = read_json(layout_path)
        for part in layout['parts']:
            for path in (part['file'], layout['proof_layers'][part['name']]['mask']):
                target = TARGET/'case'/path; target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(source/path, target)
        path = layout['rest_source']; target = TARGET/'case'/path
        target.parent.mkdir(parents=True, exist_ok=True); shutil.copyfile(source/path, target)
        write_json(TARGET/f'case/layouts/{view}.json', compact_layout(layout, digest(layout_path)))
    for name in ('anatomy.json', 'compiled_motion.json'):
        shutil.copyfile(source/name, TARGET/'case'/name)
    print('RR37 ROUND2 NATIVE FIXTURE: PASS (5 requested failures + 2 rest controls; exact bytes, full manifest/log hashes)')


if __name__ == '__main__': retain()


def models(target=TARGET):
    """Reconstitute exact historical mesh geometry, verified against its hash."""
    import hashlib,json
    from rr37_raster import CpuPose
    from humanoid_cutout.mesh import grid, weights_for
    from humanoid_cutout.anatomy import load
    result={}
    for view in ('front','rear'):
        layout=read_json(target/f'case/layouts/{view}.json')
        for mesh in layout['joint_meshes']:
            vertices,uvs,triangles=grid(mesh['bbox'])
            geometry={'vertices':vertices,'uvs':uvs,'triangles':triangles,
                      'weights':weights_for(vertices,mesh['weight_bounds'],layout['joints'],load(target/'case')['meshes'][mesh['garment']])}
            assert hashlib.sha256(json.dumps(geometry,sort_keys=True,separators=(',',':')).encode()).hexdigest()==mesh['geometry_sha256']
            mesh.update(geometry)
        result[view]=CpuPose(target/'case',layout)
    return result
