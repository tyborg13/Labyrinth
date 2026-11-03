"""Named native-layer diagnostics for the five director-rejected rr35 defects.

These are provenance/ownership diagnostics, not a replacement for the director's
2x clip judgment. The same measurements can run on explicitly labelled CPU
construction frames; CPU results never certify a native pass.
"""
import argparse
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from rr35_case import PROJECT, CASE
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_frames import load_frame, frame_digest
from humanoid_cutout.gates import matrix, bindings
from rr35_features import violet

# Exact rejected frames, zero-based. Other frames still pass the existing gates.
FRAMES = {
    'D1': [('front', 'move', f) for f in (0, 13)],
    'D2': [('front', 'move', f) for f in (20, 27)] + [('front', 'ambush', f) for f in (17, 25)] + [('front', 'slash', 23)],
    'D3': [('rear', 'slash', f) for f in (21, 23)] + [('rear', 'ambush', f) for f in (17, 25)],
    'D4': [('front', 'slash', 14), ('front', 'ambush', 10)],
    'D5': [('front', 'slash', 23)] + [('front', 'ambush', f) for f in (17, 25)],
}
DESCRIPTIONS = {
    'D1': 'far-foot continuation draws near-heel floor wedge',
    'D2': 'near-shin undercoverage uses foreign or edge texels instead of wrapped limb',
    'D3': 'rear thigh ownership / band / duplicated violet drip in hidden cloth',
    'D4': 'same cloak paint split onto pelvis at horizontal seam',
    'D5': 'cloak hem fringe travels on leg or repeats in hidden cloth',
}
CONTRACT = CASE / 'rr36_material_contract.json'
LEGACY_CAPTURE = PROJECT / 'experiments/cutouts/gloam_stalker/rr36_native_fixture'
# Existing proof registration, not a camera or player-facing layout choice.
NATIVE_ORIGIN = np.array([128, 128])
FAR_FOOT_MAX_LOCAL_ROW = 20  # e4b crop y190; near-boot island starts below source y210.


def packed(image):
    rgba = np.asarray(image, dtype=np.uint32)
    return (rgba[..., 0] << 24) | (rgba[..., 1] << 16) | (rgba[..., 2] << 8) | rgba[..., 3]


def foreign_pixels(image, allowed):
    return int(((image[..., 3] > 0) & ~np.isin(packed(image), allowed)).sum())


def measure(defect, view, images, records, contract):
    palette = contract['views'][view]
    if defect == 'D1':
        image = images['foot_far']
        y, x = np.nonzero(image[..., 3])
        inverse = np.linalg.inv(matrix(records['foot_far']['transform']))
        local = (np.column_stack((x, y)) + .5 - NATIVE_ORIGIN) @ inverse[:2, :2].T + inverse[:2, 2]
        return {'floor_wedge_pixels': int((local[:, 1] >= FAR_FOOT_MAX_LOCAL_ROW).sum())}
    if defect == 'D2':
        return {'foreign_underfill_pixels': foreign_pixels(images['hidden_leg_near'], palette['wrapped_underfill'])}
    if defect == 'D3':
        metrics = {'foreign_thigh_band_pixels': foreign_pixels(images['hidden_leg_near'], palette['wrapped_underfill']),
                   'duplicated_drip_pixels': int(violet(images['hidden_cape_far']).sum())}
        if view == 'rear':
            # The retained pelvis draw node is empty after the ownership
            # repair: its thigh wraps all belong to leg_near across the cut.
            # Check native visible alpha independently of hidden fill colours.
            metrics['visible_thigh_on_pelvis_pixels'] = int((images['pelvis'][..., 3] > 0).sum())
        return metrics
    if defect == 'D4':
        return {'cloth_on_separate_pelvis_pixels': int((images['pelvis'][..., 3] > 0).sum())}
    return {'cloth_fringe_on_leg_pixels': foreign_pixels(images['leg_near'], palette['wrapped_visible']),
            'duplicated_hem_pixels': int(violet(images['hidden_cape_near']).sum())}


def report(frame_provider, *, native_pixels, contract=None):
    contract = read_json(CONTRACT) if contract is None else contract
    rows, errors = [], []
    for defect, frames in FRAMES.items():
        for view, clip, frame in frames:
            images, records = frame_provider(view, clip, frame)
            metrics = measure(defect, view, images, records, contract)
            failed = any(metrics.values())
            row = dict(defect=defect, view=view, clip=clip, frame=frame, metrics=metrics, ok=not failed)
            rows.append(row)
            if failed: errors.append(f'{defect} {view}/{clip}/{frame}: {DESCRIPTIONS[defect]}: {metrics}')
    return {'ok': not errors, 'native_pixels': native_pixels, 'errors': errors, 'frames': rows,
            'acceptance': 'director inspection of native clips at 2x required', 'contract_sha256': digest(CONTRACT)}


def native_report(capture, *, require_current=True):
    manifest = read_json(capture / 'frames.json')
    contract = read_json(CONTRACT)
    if not manifest.get('native_pixels') or manifest.get('size') != [1920, 1080] or manifest.get('ui_scale') != 1:
        raise ValueError('RR36 native diagnostics require 1920x1080 / 100% native capture')
    if require_current and manifest['inputs'] != bindings(CASE):
        raise ValueError('RR36 native inputs are stale; recapture instead of relabelling')
    if not require_current and digest(capture / 'frames.json') not in contract['legacy_manifest_sha256'].values():
        raise ValueError('RR36 legacy capture is not the pinned e4b60147b manifest')
    rows = {(p['view'], p['clip'], p['frame'], p['name']): p for p in manifest['pieces']}
    loaded = {}
    def frames(view, clip, frame):
        key = (view, clip, frame)
        if key not in loaded:
            full = [r for r in manifest['frames'] if (r['view'], r['clip'], r['frame']) == key]
            if len(full) != 1 or frame_digest(capture / full[0]['file']) != full[0]['sha256']:
                raise ValueError('RR36 missing/changed native frame: ' + str(key))
            records = {name: rows[(*key, name)] for name in
                       ('foot_far', 'leg_near', 'hidden_leg_near', 'pelvis', 'hidden_cape_near', 'hidden_cape_far')}
            images = {name: np.asarray(load_frame(capture / row['file']).convert('RGBA')) for name, row in records.items()}
            for row in records.values():
                expected = row.get('sha256') if require_current else contract['legacy_layers_sha256'][row['file']]
                if not expected or frame_digest(capture / row['file']) != expected:
                    raise ValueError('RR36 changed isolated native layer: ' + row['file'])
            loaded[key] = images, records
        return loaded[key]
    return report(frames, native_pixels=True, contract=contract)


def cpu_report():
    from rr35_raster import CpuPose
    # The full samples log is gitignored; the committed fixture keeps only the rejected frames' presented poses.
    samples = read_json(CASE / 'proof/rr36_cpu_poses.json')
    if samples['full_samples_sha256'] != read_json(CASE / 'proof/samples.json')['full_samples']['sha256']:
        raise ValueError('rr36_cpu_poses.json is stale: re-extract it from the current proof/logs/samples.json')
    models = {v: CpuPose(CASE, read_json(CASE / f'layouts/{v}.json')) for v in ('front', 'rear')}
    loaded = {}
    def frames(view, clip, frame):
        key = (view, clip, frame)
        if key not in loaded:
            pose = next(p for p in samples['samples'] if (p['view'], p['clip'], p['frame'], p['kind']) == (*key, 'presented'))
            layers, _ = models[view].layers(pose)
            loaded[key] = {p['name']: im for p, im, _ in layers}, pose['parts']
        return loaded[key]
    return report(frames, native_pixels=False)


def seal_material_contract():
    """Record exact own-material palette; no approximate colour thresholds."""
    from maquette_motion.features import source_pixels
    result = {'views': {}, 'scope': 'approved wrapped source ownership and copied interior donors; not visual acceptance'}
    legacy = LEGACY_CAPTURE
    manifest = read_json(legacy / 'frames.json')
    result['legacy_manifest_sha256'] = {'full': manifest['source_manifest_sha256'], 'retained_subset': digest(legacy / 'frames.json')}
    selected = set(frame for frames in FRAMES.values() for frame in frames)
    result['legacy_layers_sha256'] = {p['file']: frame_digest(legacy / p['file']) for p in manifest['pieces']
        if (p['view'], p['clip'], p['frame']) in selected and p['name'] in
        ('foot_far', 'leg_near', 'hidden_leg_near', 'pelvis', 'hidden_cape_near', 'hidden_cape_far')}
    for view in ('front', 'rear'):
        layout = read_json(CASE / f'layouts/{view}.json')
        parts = {p['name']: p for p in layout['parts']}
        result['views'][view] = {}
        for key, name in [('wrapped_visible', 'leg_near'), ('wrapped_underfill', 'hidden_leg_near')]:
            image = source_pixels(CASE, parts[name])
            result['views'][view][key] = sorted(map(int, np.unique(packed(image)[image[..., 3] > 0])))
    write_json(CONTRACT, result)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--legacy', action='store_true', help='diagnose immutable e4b captures without claiming current provenance')
    parser.add_argument('--seal', action='store_true')
    args = parser.parse_args()
    if args.seal: seal_material_contract(); raise SystemExit(0)
    result = native_report(args.native, require_current=not args.legacy) if args.native else cpu_report()
    for defect in FRAMES:
        selected = [r for r in result['frames'] if r['defect'] == defect]
        print(f'RR36 {defect}: {"PASS" if all(r["ok"] for r in selected) else "FAIL"} ({len(selected)} frames; native={result["native_pixels"]})')
    write_json(CASE / f'proof/logs/rr36_{"legacy" if args.legacy else "native" if args.native else "cpu"}_defects.json', result)
    for error in result['errors']: print(error)
    raise SystemExit(not result['ok'])
