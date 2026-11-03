"""Feedback-1 proof: accepted pose, far attachments, collisions and overlaps."""
import json

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.compile_recipe import PROJECT
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.fit_delivery import registered_parts
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.fitting import keyed_mask
from .shoulder_proof import evaluate, sheet

OCCLUSION_PROOF_PARTS = {'gale_herald': {'rear': {'upper_far': 'cape_far'}}}


def occlusion_evidence(figure):
    """Record actual native occlusion without editing authored source values."""
    capture = figure / 'proof/feedback1/native/capture'
    recipe = json.loads((figure / 'r2/measurements.json').read_text())
    spec = compile_recipe(recipe)
    rows, accepted = {}, {}
    for view, labels in OCCLUSION_PROOF_PARTS.get(figure.name, {}).items():
        raster = load_render(spec, capture, view)
        for label, covering in labels.items():
            mask = raster.masks[label]
            names, counts = np.unique(raster.owners[mask], return_counts=True)
            owners = {raster.names[int(i)] if i >= 0 else 'background': int(n) for i, n in zip(names, counts)}
            # Full coverage by the named native garment is stronger than an
            # empty visible-colour count. Keep the genuine unoccluded solo.
            passed = bool(mask.sum() and owners == {covering: int(mask.sum())})
            rows.setdefault(view, {})[label] = {'passed': passed, 'occluder': covering,
                'solo_pixels': int(mask.sum()), 'covering_owner_pixels': owners,
                'parts_sha256': sha(capture / (view + '_parts.png')),
                'solo_sha256': sha(capture / (view + '_solo_' + label + '.png'))}
            if passed:
                accepted.setdefault(view, {})[label] = rows[view][label]
    result = {'passed': all(r['passed'] for view in rows.values() for r in view.values()),
        'policy': 'mq-04 genuine pure-owner pixels or recorded occlusion. Author-provided occlusions stay unchanged; this certificate records the approved shoulder garment motion.',
        'parts': rows}
    write(figure / 'r2/review/feedback1_occlusions.json', result)
    return result, accepted


def overlap(figure, result):
    root = figure / 'proof/feedback1'
    recipe = json.loads((figure / 'r2/measurements.json').read_text())
    round0_gates = root / 'round0/review/mq12_gates.json'
    prior_overlap = figure / 'r2/review/gloam_front_per_part.json'
    old_fit = (json.loads(round0_gates.read_text())['fit_after']['front'] if round0_gates.exists() else
               json.loads(prior_overlap.read_text())['round0_fit'])
    painting = Image.open(PROJECT / recipe['sources']['front']).convert('RGBA')
    painting_mask = keyed_mask(painting)
    rows, legacy_near = {}, {}
    for label in recipe['labels']:
        masks, covered = {}, {}
        paths = {'original': root / 'original_delivery' / ('front_solo_' + label + '.png'),
                 'round0': root / 'round0_front' / ('front_solo_' + label + '.png'),
                 'feedback1': root / 'native/capture' / ('front_solo_' + label + '.png')}
        for version, path in paths.items():
            image = Image.open(path).convert('RGBA')
            if label == 'cape_near':
                legacy_near[version] = np.array(image)[..., 3] >= 128
                image = Image.open(root / 'isolated_near' / version / path.name).convert('RGBA')
            masks[version] = np.array(image)[..., 3] >= 128
            if version != 'original':
                fit = old_fit if version == 'round0' else result['fit_after']['front']
                registered = np.array(registered_parts(image, fit, painting.size))[..., 3] >= 128
                covered[version] = float((registered & painting_mask).sum() / max(1, registered.sum()))
        def iou(a, b):
            return float((a & b).sum() / max(1, (a | b).sum()))
        rows[label] = {'original_to_round0_iou': iou(masks['original'], masks['round0']),
            'original_to_feedback1_iou': iou(masks['original'], masks['feedback1']),
            'round0_to_feedback1_iou': iou(masks['round0'], masks['feedback1']),
            'painting_coverage_round0': covered['round0'], 'painting_coverage_feedback1': covered['feedback1']}
    allowed = {'upper_far', 'fore_far', 'claw_far', 'cape_far', 'carapace', 'torso', 'head'}
    for label, row in rows.items():
        row['allowed_far_shoulder_region'] = label in allowed
    isolated = {v: json.loads((root / 'isolated_near' / v / 'isolation.json').read_text()) for v in paths}
    near_exact = len({json.dumps(r['selected_faces'], sort_keys=True) for r in isolated.values()}) == 1
    report = {'method': 'Native 1024 part-alpha IoU against original mq-04, plus registered part coverage by approved painting alpha. cape_near uses actual isolated native faces because excluded transparent far faces affect the legacy solo alpha. No painting part segmentation is inferred.',
        'isolated_near': {'native_selected_faces_exact': near_exact, 'versions': isolated,
            'legacy_original_to_feedback1_iou': iou(legacy_near['original'], legacy_near['feedback1']),
            'legacy_changed_alpha_pixels': int((legacy_near['original'] != legacy_near['feedback1']).sum())},
        'round0_fit': old_fit,
        'confinement_passed': near_exact and all(row['original_to_feedback1_iou'] == 1 for label, row in rows.items() if label not in allowed),
        'region_scope': {'head': 'Lower far shoulder-cowl skirt only; native skull-cover/opening faces and near side independently fixed.',
            'torso': 'Far shoulder under-drape only; accepted body skin and near-side faces independently fixed.',
            'carapace': 'Far shoulder plates only; near-side faces independently fixed.',
            'cape_far': 'Far shoulder drape attachment blended to its remote edge.'},
        'semantic_aliases': {'hand_far': 'claw_far'}, 'parts': rows,
        'sources_sha256': recipe['source_sha256'],
        'native_inputs_sha256': {str(p.relative_to(root)): sha(p) for folder in
            ('original_delivery', 'round0_front', 'native/capture', 'isolated_near/original',
             'isolated_near/round0', 'isolated_near/feedback1') for p in sorted((root / folder).glob('front_solo_*.png'))}}
    write(figure / 'r2/review/gloam_front_per_part.json', report)
    lines = ['| Part | Original → round 0 IoU | Original → feedback 1 IoU | Round 0 → feedback 1 IoU | Painting coverage before | Painting coverage after |',
             '|---|---:|---:|---:|---:|---:|']
    for label, row in rows.items():
        lines.append(f'| {label} | {row["original_to_round0_iou"]:.6f} | {row["original_to_feedback1_iou"]:.6f} | '
                     f'{row["round0_to_feedback1_iou"]:.6f} | {row["painting_coverage_round0"]:.6f} | {row["painting_coverage_feedback1"]:.6f} |')
    lines += ['', '`hand_far` is owned by the existing `claw_far` label. IoU uses native unoccluded part masks, so occlusion by a moved garment cannot masquerade as a change to the protected part. Painting coverage uses whole source alpha; the painting has no supplied part segmentation.',
        '', 'Allowed changes are the far arm/claw and far shoulder garments. `torso` includes its shoulder under-drape; `head` includes the lower shoulder-cowl skirt. The independent native preservation guard fixes every accepted body vertex, the complete skull-cover/opening faces, all other meshes, and all near-side garment faces. See `../validation/native/preservation.json`. Confinement gate: ' + str(report['confinement_passed']) + '.']
    lines += ['', 'The legacy transparent-face `cape_near` solo has ' + str(report['isolated_near']['legacy_changed_alpha_pixels']) +
        ' changed alpha pixels (IoU ' + f'{report["isolated_near"]["legacy_original_to_feedback1_iou"]:.9f}' +
        ') despite identical native near-face geometry and ownership. The table uses fresh isolated-face native captures for this row, with excluded faces removed from a disposable scene. Native camera and solo settings are unchanged; original, round-0 and feedback selected-face hashes are identical. The legacy result is retained above and in the JSON. Delivery rendering is unchanged.']
    (figure / 'r2/review/gloam_front_per_part.md').write_text('\n'.join(lines) + '\n')
    return report


def proof(figure):
    root = figure / 'proof/feedback1'
    occlusion, accepted = occlusion_evidence(figure)
    result = evaluate(figure, root=root / 'native', before_root=root / 'before',
                      regeneration=root / 'regeneration/regeneration.json', recorded_occlusions=accepted)
    result['recorded_occlusions'] = occlusion
    result['gates']['native_recorded_occlusions_valid'] = occlusion['passed']
    preserved = json.loads((root / 'native/preservation.json').read_text())
    result['gates']['accepted_round0_pose_exact'] = preserved['accepted_pose_exact']
    result['gates']['protected_round0_meshes_and_near_faces'] = preserved['passed']
    if figure.name == 'gloam_stalker':
        result['gates']['gloam_front_changes_confined'] = overlap(figure, result)['confinement_passed']
    result['passed'] = all(result['gates'].values())
    result['feedback_authority'] = 'mq-12 feedback 1: shoulder attachments follow the accepted pose; Gloam front IoU minimum 0.65.'
    review = figure / 'r2/review'
    write(review / 'mq12_gates.json', result)
    old = json.loads((root / 'original_delivery/joints_px.json').read_text())
    new = json.loads((root / 'native/capture/joints_px.json').read_text())
    sheet(figure, old, new, review / 'mq12_shoulders.html')
    path = review / 'mq12_shoulders.html'
    html = path.read_text().replace('Candidate collision failures are reported', 'Native collision and delivery gates are reported')
    html = html.replace('src="../../delivery/', 'src="mq12_before_')
    # Use the old clays once, losslessly, and link current native delivery PNGs.
    for view in ('front', 'rear'):
        source = Image.open(root / 'original_delivery' / (view + '_clay.png')).convert('RGBA')
        target = review / ('mq12_before_' + view + '_clay.webp')
        source.save(target, lossless=True, exact=True, method=6)
        if source.tobytes() != Image.open(target).convert('RGBA').tobytes():
            raise ValueError('Old-clay proof encoding changed RGBA')
        html = html.replace('src="mq12_before_' + view + '_clay.png"', 'src="' + target.name + '"')
    html = html.replace('src="../capture/', 'src="../../../proof/feedback1/native/capture/')
    path.write_text(html)
    rows = ['| View | Joint | Before (px) | After (px) |', '|---|---|---|---|']
    for view, joints in result['joint_table'].items():
        for name, values in joints.items():
            rows.append(f'| {view} | {name} | {values["before"]} | {values["after"]} |')
    rows += ['', '| View | Original IoU | Feedback 1 IoU | Gate |', '|---|---:|---:|---:|']
    for view in ('front', 'rear'):
        rows.append(f'| {view} | {result["fit_before"][view]["iou"]:.9f} | {result["fit_after"][view]["iou"]:.9f} | {result["fit_after"][view]["iou_min"]} |')
    (review / 'mq12_joint_table.md').write_text('\n'.join(rows) + '\n')
    write(review / 'feedback1_collision.json', json.loads((root / 'native/capture/build_report.json').read_text())['cloth'])
    print('MQ12_FEEDBACK1_GATES: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + figure.name + '; ' +
          '; '.join(k + '=' + str(v) for k, v in result['gates'].items()))
    return result
