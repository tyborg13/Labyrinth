"""Apply the rear shoulder recipe to the accepted closure without rebuilding it.

The raised arm exposes the top of its original shoulder cover in tether 61
and jab 26/27. Continue its own interior texels under the torso, retaining
every original texel, texture quad, presentation anchor and motion record.
"""
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.joint_continuations import domains
from humanoid_cutout.integration import record
from maquette_motion.bleed import edge_texels
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules, outline_class
from maquette_motion.pixels import rest_identity

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
ASSETS = PROJECT / 'assets/units/arc_thrall_cutout'
VIEW = 'rear'
PIECE = 'upper_near'
LAYER = 'hidden_upper_near'


def main():
    layout = read_json(CASE / f'layouts/{VIEW}.json')
    anatomy = read_json(CASE / 'anatomy.json')
    part = next(p for p in layout['parts'] if p['name'] == LAYER)
    visible = {p['logical_part']: source_pixels(CASE, p) for p in layout['parts']
               if not p.get('hidden_material')}
    hidden = {name: np.zeros_like(image) for name, image in visible.items()}
    for row in layout['parts']:
        if not row.get('hidden_material'): continue
        image = source_pixels(CASE, row)
        mask = image[..., 3] > 0
        hidden[row['logical_part']][mask] = image[mask]
    covers = [other for pair in anatomy['seam_joins'] if PIECE in pair
              for other in pair if other != PIECE]
    recipe = {PIECE: {'covers': covers,
        'source_points': read_json(CASE / 'joint_continuations.json')[VIEW][PIECE]}}
    required = domains(visible, hidden, recipe, **anatomy['joint_continuations'])[PIECE]
    missing = required & (hidden[PIECE][..., 3] == 0)
    for x, y in read_json(CASE / 'continuation_alpha_cleanup.json')[VIEW].get(PIECE, []):
        missing[y, x] = False
    left, top, right, bottom = part['bbox']
    bounded = np.zeros_like(missing)
    bounded[top:bottom, left:right] = True
    if (missing & ~bounded).any():
        raise ValueError('Shoulder continuation must retain its accepted texture quad')
    paint = Image.open(CASE / part['file']).convert('RGBA')
    target = ASSETS / 'humanoid_v2' / VIEW / (LAYER + '.png')
    if target.read_bytes() != (CASE / part['file']).read_bytes():
        raise ValueError('Case and production underlays differ before shoulder extension')
    definition = rules(CASE / 'rear_baseline', VIEW)
    fill = edge_texels(visible[PIECE], missing, definition)
    updated = np.asarray(paint).copy()
    local = missing[top:bottom, left:right]
    updated[local] = fill[top:bottom, left:right][local]
    Image.fromarray(updated).save(CASE / part['file'])
    checks = layout['proof_layers'][LAYER]
    mask = np.asarray(Image.open(CASE / checks['mask']).convert('RGBA')).copy()
    mask[local] = [255, 255, 0, 255]
    outline = outline_class(updated, definition)
    mask[local & outline, 2] = 255
    Image.fromarray(mask).save(CASE / checks['mask'])
    checks['source_sha256'] = digest(CASE / part['file'])
    write_json(CASE / f'layouts/{VIEW}.json', layout)
    if not rest_identity(CASE)['ok']:
        raise ValueError('Shoulder continuation changes the approved rest')
    target.write_bytes((CASE / part['file']).read_bytes())
    relative = str(target.relative_to(PROJECT))
    subprocess.run([sys.executable, '-B', 'tools/process_board_density.py', '--adopt', relative,
                    '--force-adopt'], cwd=PROJECT, check=True)
    subprocess.run([sys.executable, '-B', 'tools/process_board_density.py', '--only',
                    'arc_thrall_cutout'], cwd=PROJECT, check=True)
    if target.read_bytes() != (CASE / part['file']).read_bytes():
        raise ValueError('Density treatment changed the accepted shoulder texels')
    build = read_json(CASE / 'proof/build.json')
    build['native_proof'] = 'pending director feedback-3 shoulder recapture'
    write_json(CASE / 'proof/build.json', build)
    record(PROJECT, CASE, ASSETS)
    print('RR15 REAR SHOULDER CONTINUATION: PASS (%d added texels; fixed quad; rest 0 px)' % missing.sum())


if __name__ == '__main__':
    main()
