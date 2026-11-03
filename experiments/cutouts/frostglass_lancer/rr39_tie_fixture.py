"""Retain the director's 64 exact native edge failures, without re-rendering."""
import shutil
from rr37_case import CASE
from rr37_proof_case import PROOF_CASE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_frames import frame_digest

TARGET = CASE.parent/'rr39_tie_fixture'
EMPTY_CERTIFICATE = TARGET/'empty_painted_certificate.png'
EMPTY_CERTIFICATE_SHA256 = 'fc8e7d63694feb864fbdad602bab822404195b79378089a3cb73b7d3e9c13fc8'


def retained_bindings(inputs, case):
    """Canonicalize only verified zero optional certificates in this fixture.

    rr37_surfaces.provenance intentionally unlinks empty painted_* masks. The
    retained capture predates that cleanup. Its exact zero-PNG witness proves
    those hashes mean no certified texels; no other source binding is waived.
    This is NOT the current-renderer/native binding policy.
    """
    from PIL import Image
    if digest(EMPTY_CERTIFICATE)!=EMPTY_CERTIFICATE_SHA256:
        raise ValueError('Changed retained empty certificate witness')
    with Image.open(EMPTY_CERTIFICATE) as image:
        if image.mode!='L' or image.size!=(255,255) or image.getextrema()!=(0,0):
            raise ValueError('Retained optional certificate witness is not all zero')
    optional = {f'uncovered/painted_{view}_{part["name"]}.png'
        for view in ('front','rear') for part in read_json(case/f'layouts/{view}.json')['parts']}
    # rr-43 retires the rear flap layer. The historical archive still declares
    # its optional zero certificate; undeclared or nonempty claims stay strict.
    from rr41_fixture import legacy_case
    with legacy_case() as retained:
        optional |= {f'uncovered/painted_{view}_{part["name"]}.png'
            for view in ('front','rear') for part in read_json(retained/f'layouts/{view}.json')['parts']}
    return {key:value for key,value in inputs.items() if not key.startswith('runtime:')
            and not (key in optional and value==EMPTY_CERTIFICATE_SHA256)}


def verify_retained_bindings(recorded, current, case):
    expected, actual = retained_bindings(recorded,case), retained_bindings(current,case)
    different = sorted(key for key in expected.keys() | actual.keys() if expected.get(key)!=actual.get(key))
    if different: raise ValueError('Retained paint/geometry bindings differ: '+', '.join(different))


def retain():
    if TARGET.exists(): raise ValueError('Immutable native tie fixture already retained')
    capture = CASE/'proof/native'
    original = read_json(PROOF_CASE/'proof/logs/uncovered_surfaces.json')
    before = [r for r in original['frames'] if any(r['metrics'].values())]
    if len(before)!=64: raise ValueError('Expected the director\'s 64 native failures')
    keys = {(r['view'],r['clip'],r['frame']) for r in before}
    full = read_json(capture/'frames.json')
    report = {k:full[k] for k in ('native_pixels','size','ui_scale','fps','inputs')}
    report.update(selection_only=True,purpose='rr-39 feedback 2: retained native UV ties; not fresh renderer proof',
        source_manifest_sha256=digest(capture/'frames.json'),
        source_gate_log_sha256=digest(PROOF_CASE/'proof/logs/uncovered_surfaces.json'))
    files = []
    for field in ('frames','pieces','rest_holes','joint_seams'):
        report[field] = []
        for row in full[field]:
            if (row['view'],row['clip'],row['frame']) not in keys: continue
            if frame_digest(capture/row['file'])!=row['sha256']: raise ValueError('Changed retained native frame')
            # This fixture exercises uncovered evaluation, which consumes the
            # isolated paint and seam/hole references, not the other gates'
            # colour-check surfaces. Keep only files actually retained.
            report[field].append({k:v for k,v in row.items() if k not in ('checks','checks_sha256')})
            files.append(row['file'])
    index = read_json(capture/'native_storage.json')
    kept = {f:index['files'][f] for f in files}
    for row in kept.values():
        target = TARGET/row['stored_file'];target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copyfile(capture/row['stored_file'],target)
    write_json(TARGET/'native_storage.json',dict(version=index['version'],files=kept))
    write_json(TARGET/'frames.json',report)
    write_json(TARGET/'before.json',{'source_gate_log_sha256':report['source_gate_log_sha256'],'frames':before})
    poses = PROOF_CASE/'proof/logs/samples.json'
    write_json(TARGET/'poses.json',{'full_samples_sha256':digest(poses),
        'samples':[r for r in read_json(poses)['samples'] if r['kind']=='presented'
                   and (r['view'],r['clip'],r['frame']) in keys]})
    print('RR39 NATIVE TIE FIXTURE: PASS (64 exact native frames; original paint and reference hashes)')


if __name__=='__main__': retain()
