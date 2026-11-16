"""Subject-local contract, source-scale framing, and board comparison proof."""
import hashlib
import json
import math
from pathlib import Path
import shutil
import sys

import numpy as np

from spec.art_identity.maquettes.geometry import build_meshes
from spec.art_identity.maquettes.raster import camera, project

PROJECT = Path(__file__).resolve().parents[3]
DEFAULT_RECIPE = Path(__file__).with_name('emaciated_man') / 'recipe.json'
DEFAULT_OUT = PROJECT / 'spec/art_identity/jobs/emaciated_man/mq_front'
PARTS = ('far_forearm_hand', 'far_upper_arm', 'legs', 'robe_torso', 'head_hood',
         'near_upper_arm', 'near_forearm', 'near_hand', 'ember_sack')
JOINTS = ('neck', 'shoulder_far', 'shoulder_near', 'elbow_far', 'elbow_near',
          'wrist_near', 'sack_base', 'root')
BRIEF = {'seated_height_over_hero': 0.62, 'head_over_standing_height': 0.2,
         'hunch_degrees': 15, 'head_pitch_degrees': 10, 'head_turn_degrees': 10,
         'sack_from_knee_tiles': 0.5, 'minimum_limb_game_pixels': 3}
# Diagnostic ownership colours only; these never become painting colours.
LABEL_COLOURS = ((0.35, 0.08, 0.6), (0.65, 0.2, 0.9), (0.1, 0.65, 0.55),
                (0.8, 0.15, 0.15), (0.9, 0.65, 0.15), (0.12, 0.3, 0.9),
                (0.15, 0.65, 0.95), (0.65, 0.85, 1.0), (0.55, 0.3, 0.08))
PROOF_DEFAULTS = {'render_size': 1024, 'K': 4, 'canvas': 256,
                  'ground_canvas': [128, 246], 'alpha_threshold': 128,
                  'geometry_tolerance': 1e-6, 'board_slots': [1, 2, 3]}


def canon_path(identity):
    canon = json.loads((PROJECT / 'spec/art_identity/canon.json').read_text())
    return PROJECT / next(entry['path'] for entry in canon['entries'] if entry['id'] == identity)


def canon_hero_height():
    # Blender bundles NumPy but need not bundle Pillow; use its native PNG loader.
    if 'bpy' in sys.modules:
        import bpy
        image = bpy.data.images.load(str(canon_path('hero_front')), check_existing=False)
        alpha = np.asarray(image.pixels[:]).reshape(image.size[1], image.size[0], 4)[:, :, 3]
        rows = np.where(np.any(alpha >= PROOF_DEFAULTS['alpha_threshold'] / 255, axis=1))[0]
        bpy.data.images.remove(image)
        return int(rows[-1] - rows[0] + 1)
    from PIL import Image
    with Image.open(canon_path('hero_front')) as image:
        bbox = image.convert('RGBA').getchannel('A').point(
            lambda a: 255 if a >= PROOF_DEFAULTS['alpha_threshold'] else 0).getbbox()
    return bbox[3] - bbox[1]


def pending(value, path='recipe'):
    if isinstance(value, str):
        return [path + ': ' + value] if value.startswith('TODO_DESIGN_') else []
    if isinstance(value, dict):
        return sum((pending(item, path + '.' + key) for key, item in value.items()), [])
    if isinstance(value, list):
        return sum((pending(item, path + '[' + str(i) + ']') for i, item in enumerate(value)), [])
    return []


def compile_spec(recipe_path=DEFAULT_RECIPE):
    recipe = json.loads(Path(recipe_path).read_text())
    missing = pending(recipe)
    if missing:
        raise ValueError('; '.join(missing))
    if set(recipe['joints']) != set(JOINTS):
        raise ValueError('Recipe must supply precisely the eight named joints')
    shapes = recipe['shapes']
    if set(shape['part'] for shape in shapes) != set(PARTS):
        raise ValueError('Recipe must supply all nine parts')
    # Ordering is explicit and shared by mesh creation and material assignment.
    shapes = sorted(shapes, key=lambda shape: PARTS.index(shape['part']))
    spec = {'front_yaw': 0, 'joints': recipe['joints'], 'shapes': shapes,
            'labels': dict(zip(PARTS, LABEL_COLOURS)), 'solo': list(PARTS),
            'part_options': {part: {'smooth_normals': True} for part in PARTS},
            'target': [0, 0, 0], 'ortho_scale': 1}
    meshes = build_meshes(spec)
    vertices = np.concatenate([mesh.vertices for mesh in meshes.values()])
    _, _, basis, _ = camera(spec)
    uv = np.einsum('ni,ji->nj', vertices, basis[:2])
    hero_height = canon_hero_height()
    desired_height = hero_height * BRIEF['seated_height_over_hero'] * PROOF_DEFAULTS['K']
    scale = float(np.ptp(uv[:, 1]) * PROOF_DEFAULTS['render_size'] / desired_height)
    # Root remains at the established 256-canvas board anchor, with no sprite fit/reduction.
    anchor = np.asarray(PROOF_DEFAULTS['ground_canvas']) / PROOF_DEFAULTS['canvas']
    spec['target'] = (basis[0] * (0.5 - anchor[0]) * scale
                      + basis[1] * (anchor[1] - 0.5) * scale).tolist()
    spec['ortho_scale'] = scale
    return spec


def inspect_geometry(spec):
    meshes = build_meshes(spec)
    tolerance = PROOF_DEFAULTS['geometry_tolerance']
    vertices = np.concatenate([mesh.vertices for mesh in meshes.values()])
    if not np.isfinite(vertices).all() or any(len(mesh.faces) == 0 for mesh in meshes.values()):
        raise ValueError('Non-finite or empty geometry')
    hood_top = float(meshes['head_hood'].vertices[:, 2].max())
    if abs(hood_top - BRIEF['seated_height_over_hero']) > tolerance or abs(vertices[:, 2].min()) > tolerance:
        raise ValueError('Recipe must use hero standing H=1, floor Z=0 and hood top Z=0.62')
    pixels = project(spec, vertices)[:, :2]
    if (pixels < 0).any() or (pixels >= PROOF_DEFAULTS['render_size']).any():
        raise ValueError('Drawn-size framing clips geometry; owner geometry needs adjustment')
    limb_widths = {}
    for shape in spec['shapes']:
        if shape['type'] in ('capsule', 'limb'):
            radii = shape['radii'] if shape['type'] == 'limb' else [shape['r1'], shape.get('r2', shape['r1'])]
            width = min(radii) * 2 * PROOF_DEFAULTS['render_size'] / spec['ortho_scale'] / PROOF_DEFAULTS['K']
            limb_widths.setdefault(shape['part'], []).append(width)
            if width < BRIEF['minimum_limb_game_pixels']:
                raise ValueError('Limb below three game pixels: ' + shape['part'])
    return {'passed': True, 'parts_back_to_front': list(PARTS), 'hood_top_over_H': hood_top,
            'minimum_z': float(vertices[:, 2].min()), 'limb_widths_game_pixels': limb_widths,
            'brief': BRIEF, 'note': 'Pose, overlaps and silhouette require owner inspection.'}


def proof(spec, output):
    from PIL import Image
    from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, require_image
    from spec.art_identity.maquettes.blender.contract import digest
    sys.path.insert(0, str(PROJECT / 'tools'))
    from tools.art_identity_gate import render_board_row, compose_board_scales

    output = Path(output)
    manifest = read_manifest(output, digest(spec), ('full',))
    expected = ['front_parts.png', 'front_clay.png'] + ['front_solo_' + part + '.png' for part in PARTS]
    for name in expected:
        require_image(manifest, name)
        with Image.open(output / name) as image:
            if image.size != (PROOF_DEFAULTS['render_size'],) * 2 or not image.convert('RGBA').getchannel('A').getbbox():
                raise ValueError('Empty or incorrectly sized capture: ' + name)
    joints = json.loads((output / 'joints_px.json').read_text())
    if set(joints) != {'front'} or set(joints['front']) != set(JOINTS):
        raise ValueError('Expected front-only joint projection')
    refs = output / 'refs'
    refs.mkdir(exist_ok=True)
    for source, destination in [('front_parts.png', '01_maquette_front_parts.png'),
                                ('front_clay.png', '02_maquette_front_clay.png')]:
        shutil.copyfile(output / source, refs / destination)
    # Use the existing approved board capture, never the synthetic fallback tiles.
    backdrop_folder = PROJECT / 'spec/art_identity/backdrop'
    backdrop_spec = json.loads((backdrop_folder / 'slots.json').read_text())
    backdrop = Image.open(backdrop_folder / backdrop_spec['empty_board_capture']).convert('RGBA')
    slots = [backdrop_spec['rows'][0][i] for i in PROOF_DEFAULTS['board_slots']]
    clay = Image.open(output / 'front_clay.png').convert('RGBA')
    sprite = clay.resize((PROOF_DEFAULTS['canvas'],) * 2, Image.Resampling.NEAREST)
    sprite.save(output / 'front_clay_drawn.png')
    subjects = [(Image.open(canon_path('hero_front')).convert('RGBA'), 1.0, 'hero front'),
                (sprite, 1.0, 'Emaciated Man — clay'),
                (Image.open(canon_path('grave_surgeon_front')).convert('RGBA'), 1.0, 'Grave Surgeon front')]
    row = render_board_row(backdrop, slots, subjects)
    # Crop to the three occupied approved slots without changing native pixel scale.
    spacing = slots[1]['centre'][0] - slots[0]['centre'][0]
    row = row.crop((round(slots[0]['centre'][0] - spacing / 2), 0,
                    round(slots[-1]['centre'][0] + spacing / 2), row.height))
    row.save(output / 'board_row_1x.png')
    row.resize((row.width * 2, row.height * 2), Image.Resampling.NEAREST).save(output / 'board_row_2x.png')
    compose_board_scales(row, output / 'board_comparison.png')
    report = {'passed': True, 'spec_hash': digest(spec), 'views': ['front'],
              'parts_back_to_front': list(PARTS), 'brief': BRIEF, 'defaults': PROOF_DEFAULTS,
              'images': {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in expected},
              'owner_review_required': ['pose', 'overlaps', 'empty lap', 'scale', 'sack beside near knee']}
    (output / 'proof_report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('EMAC_PROOF: PASS; native captures=11; views=1; board_scales=1x,2x_NEAREST')
