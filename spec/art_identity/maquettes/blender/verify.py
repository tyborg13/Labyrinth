"""Bind completed native captures, numerical proof and bridge receipts to r3."""
import argparse
import hashlib
import json
from pathlib import Path
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.contract import digest, todos
from spec.art_identity.maquettes.blender.director import proof_contract
from spec.art_identity.maquettes.raster import project

GALLERY_DEFAULTS = {'columns': 3, 'tile_px': 512,
                    'types': ['plate', 'lames', 'cloth', 'curve', 'crystal', 'gem']}


def read(path):
    return json.loads(Path(path).read_text())


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--spec', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--receipts', type=Path, nargs='+', required=True)
    parser.add_argument('--baseline', type=Path, required=True, help='Independent fresh build_report.json for the same spec')
    args = parser.parse_args()
    spec, out = read(args.spec), args.out
    folder = out / 'lancer_r3'
    build = read(folder / 'build_report.json')
    baseline = read(args.baseline)
    fit = read(out / 'measure/fit_report.json')
    facing = read(folder / 'facing_report.json')
    assert facing['passed'] and facing['frontal_axis_rejected']
    panel, = [p for p in spec['pieces'] if p.get('kind') == 'tabard']
    assert len(panel['pattern']['splits']['columns']) == 3
    integration = read(out / 'integration_final/integration_report.json')
    native_geometry = read(out / 'native_geometry.json')
    native_joints = native_geometry['native_joint_validation']
    assert not todos(spec) and spec['proposed']
    assert build['spec_hash'] == digest(spec) == baseline['spec_hash']
    assert build['passed'] and fit['passed'] and integration['passed'] and native_joints['passed']
    assert native_geometry['native_grip_validation']['passed']
    assert native_geometry['native_spear_validation']['passed']
    assert build['mesh_hashes'] == baseline['mesh_hashes'], 'Fresh lancer builds differ'
    contract = proof_contract(spec, folder)
    captures = {}
    for name in contract['required_images']:
        path = folder / name
        with Image.open(path) as image:
            assert list(image.size) == contract['size'], (name, image.size)
            assert image.mode == 'RGBA', (name, image.mode)
        captures[name] = sha(path)
    from spec.art_identity.maquettes.blender.facing import board_spec
    working = board_spec(spec)
    joints = read(folder / 'joints_px.json')
    max_error = max(float(np.linalg.norm(np.array(xy) - project(working, working['joints'][name], view)[:2]))
                    for view, points in joints.items() for name, xy in points.items())
    assert max_error <= 1, max_error
    receipts = [read(path) for path in args.receipts]
    assert all(r['exit'] == 0 for r in receipts)
    assert all('--factory-startup' in r['command'] and '--disable-autoexec' in r['command'] for r in receipts)
    # Proof-only contact sheets paste existing native images; no new artwork,
    # text, fonts, lighting or model geometry is created here.
    size = GALLERY_DEFAULTS['tile_px']
    columns = GALLERY_DEFAULTS['columns']
    rows = (len(GALLERY_DEFAULTS['types']) + columns - 1) // columns
    for view in ('front', 'rear'):
        sheet = Image.new('RGBA', (columns * size, rows * size))
        for i, kind in enumerate(GALLERY_DEFAULTS['types']):
            with Image.open(folder / 'piece_gallery' / f'{view}_{kind}.png') as image:
                tile = image.resize((size, size), Image.Resampling.LANCZOS)
                sheet.paste(tile, ((i % columns) * size, (i // columns) * size))
        sheet.save(folder / 'piece_gallery' / f'{view}_gallery.png')
    report = {'passed': True, 'spec_sha256': sha(args.spec), 'spec_hash': digest(spec),
              'source_sha256': sha(PROJECT / spec['fit']['source']), 'contract': contract,
              'captures_sha256': captures, 'bridge_receipts': receipts,
              'fresh_build_mesh_hashes_identical': True, 'geometry_checks': build['checks'],
              'projection_error_max_px': max_error, 'native_integration': integration,
              'native_joint_validation': native_joints,
              'native_grip_validation': native_geometry['native_grip_validation'],
              'native_spear_validation': native_geometry['native_spear_validation'],
              'facing': facing, 'single_tabard_strips': 4,
              'fit_metrics': {k: fit[k] for k in ('iou', 'median_band_error', 'max_band_error', 'landmarks', 'passed')},
              'overlay_sha256': sha(out / 'measure/fit_overlay.png'), 'gallery_layout': GALLERY_DEFAULTS}
    (out / 'proof_contract.json').write_text(json.dumps(contract, indent=2) + '\n')
    (out / 'proof_manifest.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'MQ03_PROOF: PASS; captures={len(captures)}; projection_error_max_px={max_error:.6f}; fresh_builds_identical=true')


if __name__ == '__main__':
    main()
