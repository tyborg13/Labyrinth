"""Native 1:1 comparison sheets and current-capture numerical acceptance."""
import json
from pathlib import Path

from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.blender.solid_fit import silhouette_fit
from spec.art_identity.maquettes.hollow_mimic.batch_proof import pose_gates
from spec.art_identity.maquettes.raster import project
from tests.test_maquette_rear_turn import observations
from .candidate import ROOT, GATES
from .preservation import HERE, PROJECT

PROOF_DEFAULTS = {'header_px': 28, 'joint_radius_px': 3, 'caption_offset_px': 4,
                  'background': (24, 24, 24, 255), 'mark': 'white',
                  'head_display_height_px': 256,
                  'hero_head_box': (92, 7, 164, 73), 'hero_skull_height_px': 40,
                  'original_head_box': (92, 37, 162, 103), 'original_skull_height_px': 44}


def inspect(spec, capture):
    recipe = json.loads((ROOT / spec['id'] / 'measurements.json').read_text())
    views = {}
    for view in ('front', 'rear'):
        source = PROJECT / recipe['sources'][view]
        if sha(source) != recipe['source_sha256'][view]:
            raise ValueError('Protected painting changed')
        raster = load_render(spec, capture, view)
        with Image.open(source) as image:
            report = silhouette_fit(image.convert('RGBA'), raster, GATES['iou'][view])
        with Image.open(capture / (view + '_parts.png')) as image:
            coverage = part_coverage(spec, raster, image.convert('RGBA'))
        missing = [part for part, row in coverage.items() if not row['solo_pixels'] or row['clipped_at_canvas'] or
                   (not row['pure_owner_pixels'] and not recipe['occlusions'][view].get(part))]
        report.update(per_part_coverage=coverage, missing_unoccluded_parts=missing)
        report['passed'] &= not missing
        views[view] = report
    joints = json.loads((capture / 'joints_px.json').read_text())
    pose = pose_gates(spec, joints)
    turn = observations(capture, labels=spec['labels'])
    turn_checks = {v + '_lower_foot_right': turn[v]['lower_foot_right'] for v in turn}
    turn_checks.update(front_near_over_torso=turn['front']['body_side_pixels_over_torso']['near'] > turn['front']['body_side_pixels_over_torso']['far'],
                       rear_far_over_torso=turn['rear']['body_side_pixels_over_torso']['far'] > turn['rear']['body_side_pixels_over_torso']['near'])
    before = json.loads((ROOT / spec['id'] / 'delivery/build_report.json').read_text())['mesh_hashes']
    build = json.loads((capture / 'build_report.json').read_text())
    after = build['mesh_hashes']
    changed = {'hair_crown_render'} if spec['id'] == 'hollow_mimic' else {'leather_apron_render', 'rear_leather_apron_render', 'leather_belt_render'}
    untouched = {k: v for k, v in before.items() if k not in changed} == {k: v for k, v in after.items() if k not in changed}
    shape = json.loads((capture / 'mq11_shape.json').read_text())
    if (shape['spec_hash'] != digest(spec) or shape['build_report_sha256'] != sha(capture / 'build_report.json') or
            shape['cold_mesh_hash'] != build['combined_mesh_hash'] or
            shape['blend_sha256'] != sha(capture / 'maquette.blend')):
        raise ValueError('Stale native accessory measurements')
    result = {'passed': pose['passed'] and all(turn_checks.values()) and all(r['passed'] for r in views.values()) and shape['passed'] and untouched,
              'spec_hash': digest(spec), 'views': views, 'pose': pose,
              'true_turn': {'passed': all(turn_checks.values()), 'checks': turn_checks, 'observations': turn},
              'unchanged_native_body_mask_and_other_accessories': untouched, 'native_shape': shape}
    write(capture / 'mq11_fit.json', result)
    baseline = json.loads((HERE / 'baseline.json').read_text())['before_iou'][spec['id']]
    print('MQ11_FIT: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + spec['id'] + '; ' +
          '; '.join(v + '=' + format(baseline[v], '.9f') + ' -> ' + format(views[v]['iou'], '.9f') for v in views))
    return result


def sheet(spec, capture, output):
    output.mkdir(parents=True, exist_ok=True)
    size, header = GATES['native_size'], PROOF_DEFAULTS['header_px']
    sources = {}
    for view in ('front', 'rear'):
        result = Image.new('RGBA', (3 * size, size + header), PROOF_DEFAULTS['background'])
        draw = ImageDraw.Draw(result)
        cells = [(ROOT / spec['id'] / 'delivery' / (view + '_clay.png'), 'old clay'),
                 (capture / (view + '_clay.png'), 'new clay'), (capture / (view + '_parts.png'), 'new part map')]
        for column, (path, label) in enumerate(cells):
            with Image.open(path) as image:
                if image.size != (size, size):
                    raise ValueError('Native review cells must be 1024x1024')
                result.alpha_composite(image.convert('RGBA'), (column * size, header))
            joints_file = path.parent / 'joints_px.json'
            joints = json.loads(joints_file.read_text())[view]
            for name, (x, y) in joints.items():
                x, y = x + column * size, y + header
                r = PROOF_DEFAULTS['joint_radius_px']
                draw.ellipse((x - r, y - r, x + r, y + r), outline=PROOF_DEFAULTS['mark'])
                draw.text((x + r, y), name, fill=PROOF_DEFAULTS['mark'])
            draw.text((column * size + PROOF_DEFAULTS['caption_offset_px'], PROOF_DEFAULTS['caption_offset_px']),
                      spec['id'] + ' / ' + view + ' / ' + label + ' / 1:1', fill=PROOF_DEFAULTS['mark'])
            sources[str(path.relative_to(PROJECT))] = sha(path)
            sources[str(joints_file.relative_to(PROJECT))] = sha(joints_file)
        result.save(output / (view + '_old_new_parts.png'), optimize=True)
    if spec['id'] == 'hollow_mimic':
        head_comparison(spec, capture, output, sources)
    outputs = {p.name: sha(p) for p in sorted(output.glob('*.png'))}
    write(output / 'proof_contract.json', {'schema': 1, 'spec_hash': digest(spec),
          'cell_size_px': [size, size], 'cell_scale': 1,
          'sheet_size_px': [3 * size, size + header], 'joints_marked_every_cell': True,
          'sources_sha256': sources, 'outputs_sha256': outputs})


def head_comparison(spec, capture, output, sources):
    size = GATES['native_size']
    skull = spec['mq11']['design']['skull']
    crown, base = project(spec, [skull['crown_m'], skull['base_m']], 'front', size)
    native_height = float(base[1] - crown[1])
    if native_height <= 0:
        raise ValueError('Front skull has no projected height')
    pictures = []
    paths = [(capture / 'front_clay.png', 'new Mimic', None, native_height),
             (PROJECT / 'assets/units/protagonist_cutout/front/front_default_gear_rest.png', 'hero',
              PROOF_DEFAULTS['hero_head_box'], PROOF_DEFAULTS['hero_skull_height_px']),
             (PROJECT / 'assets/art/enemies/hollow_mimic.png', 'original Mimic',
              PROOF_DEFAULTS['original_head_box'], PROOF_DEFAULTS['original_skull_height_px'])]
    with Image.open(capture / 'front_solo_head.png') as mask:
        native_box = mask.getbbox()
    for path, caption, box, skull_height in paths:
        with Image.open(path) as original:
            image = original.convert('RGBA').crop(box or native_box)
        factor = PROOF_DEFAULTS['head_display_height_px'] / skull_height
        image = image.resize(tuple(max(1, round(d * factor)) for d in image.size), Image.Resampling.NEAREST)
        pictures.append((image, caption))
        sources[str(path.relative_to(PROJECT))] = sha(path)
    header = PROOF_DEFAULTS['header_px']
    result = Image.new('RGBA', (sum(p.width for p, _ in pictures), max(p.height for p, _ in pictures) + header), PROOF_DEFAULTS['background'])
    draw, x = ImageDraw.Draw(result), 0
    for image, caption in pictures:
        result.alpha_composite(image, (x, header))
        draw.text((x + 4, 4), caption + ' / same skull height', fill=PROOF_DEFAULTS['mark'])
        x += image.width
    result.save(output / 'mimic_hero_original_heads.png', optimize=True)
    sources[str((capture / 'front_solo_head.png').relative_to(PROJECT))] = sha(capture / 'front_solo_head.png')
