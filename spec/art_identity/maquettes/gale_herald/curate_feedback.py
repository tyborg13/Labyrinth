"""Seal the director's mq-12 feedback, then curate its native evidence."""
import argparse
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence, sha, stage, verify, write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery
from spec.art_identity.maquettes.blender.shoulder_garments import MOTION_DEFAULTS
from .curate_candidate import scope
from .feedback_proof import OCCLUSION_PROOF_PARTS
from .preservation_probe import GUARD_DEFAULTS
from .shoulder_proof import PROOF_DEFAULTS
from .shoulder_workflow import ROOT, WORKFLOW_DEFAULTS


def archive(figure, files):
    files = sorted({Path(p) for p in files if Path(p).is_file()})
    if files:
        discard_evidence(figure, files, figure / 'discarded_proof_sha256.json')


def install(figure):
    root = figure / 'proof/feedback1'
    review = figure / 'r2/review'
    gates = json.loads((review / 'mq12_gates.json').read_text())
    if not gates['passed']:
        raise ValueError('All feedback gates must pass before replacing delivery')
    recipe = figure / 'r2/measurements.json'
    spec = compile_recipe(json.loads(recipe.read_text()))
    capture = root / 'native/capture'
    compact_capture(spec, capture)
    seal_delivery(spec, capture)
    validate_delivery(spec, capture)
    # The original recipes and complete native exports are already snapshotted.
    # Hash every replaced byte before replacing the canonical input/delivery.
    historical = {p for folder in ('reference', 'review') for p in (figure / 'delivery' / folder).rglob('*') if p.is_file()}
    archive(figure, [figure / 'measurements.json',
                     *(p for p in (figure / 'delivery').rglob('*') if p not in historical)])
    shutil.copyfile(recipe, figure / 'measurements.json')
    stage(figure, capture)
    validate_delivery(spec, figure / 'delivery')
    sheet = review / 'mq12_shoulders.html'
    sheet.write_text(sheet.read_text().replace('../../../proof/feedback1/native/capture/', '../../delivery/'))
    shutil.copyfile(root / 'round0/measurements.json', review / 'mq12_round0_recipe.json')
    validation = figure / 'r2/validation'
    scope_state = json.loads((validation / 'scope.json').read_text()) if (validation / 'scope.json').exists() else None
    archive(figure, validation.rglob('*'))
    if scope_state is not None:
        write(validation / 'scope.json', scope_state)
    groups = {
        'native': (root / 'native', ['preservation.json', 'exact_native_replay.json']),
        'capture': (capture, ['native_observations.json']),
        'baseline': (root / 'before/build', ['build_report.json']),
        'regeneration': (root / 'regeneration', ['regeneration.json', 'clean_input_sha256.json',
            'input_state.json', 'build.json', 'build.log'])}
    for group, (source, names) in groups.items():
        for name in names:
            target = validation / group / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / name, target)
    for prefix, folder in [('native_build', root / 'native/bridge'), ('capture', root / 'native/capture_jobs'),
                           ('regeneration', root / 'regeneration/capture_jobs'), ('isolated_near', root / 'isolated_near')]:
        for path in sorted(folder.glob('*')):
            if path.is_file() and path.suffix in ('.json', '.log'):
                target = validation / 'bridge' / prefix / path.name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
    for path in sorted((root / 'isolated_near').glob('*/isolation.json')):
        target = validation / 'isolated_near' / (path.parent.name + '.json')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
    write(figure / 'r2/design_status.json', {'feedback': 1, 'status': 'implemented_and_sealed',
        'resolved_decisions': {'shoulder_cloth_clearance': 'Source fold meshes follow the accepted far shoulder at its attachments, blending to fixed near-side faces and remote edges.',
            'gloam_front_iou_min': .65, 'gloam_head_cover': 'The lower shoulder-cowl skirt is separated at the native skull lower boundary. Every face touching the skull boundary, the complete head cover/opening and near-side faces remain exactly round 0.'},
        'TODO_DESIGN': []})
    write(validation / 'chosen_defaults.json', {'workflow': WORKFLOW_DEFAULTS, 'proof': PROOF_DEFAULTS,
        'preservation': GUARD_DEFAULTS, 'attachment': MOTION_DEFAULTS,
        'occlusion_proof_parts': OCCLUSION_PROOF_PARTS,
        'attachment_bounds': 'Source surface bounds, actual native pin positions and native skull lower boundary. Root band is existing cloth thickness. Smoothstep interpolation.',
        'encoding': 'Original native clay PNG bytes; lossless masks preserving all alpha and visible RGBA; old clays lossless exact-RGBA WebP method 6.',
        'test_fixtures': 'TEST_DEFAULTS and MOTION_TEST_DEFAULTS in tests/test_mq12_shoulders.py; no gameplay values chosen.'})
    write(validation / 'sealed_delivery.json', {'passed': True, 'files': {
        str(p.relative_to(figure / 'delivery')): sha(p) for p in sorted((figure / 'delivery').rglob('*')) if p.is_file()}})
    rows = ['# ' + figure.name + ' — mq-12 feedback 1', '',
        'The accepted round-0 pose is preserved exactly. The canonical recipe and `../delivery/` now contain the sealed shoulder revision.', '',
        '1. Both shoulders are level in body space and meet the front projection rule. All limb lengths, spine/neck bend, near side, mask/head cover, legs and horn are preserved. Far shoulder garment attachments follow the shoulder delta with a source-bounded blend. Herald banners use their actual native pinned roots; the front waist-pinned tabard lies wholly on the protected near side and stays fixed, while the far rear tabard top follows the shoulder. Gloam’s single `head` mesh includes a lower shoulder-cowl skirt: only far skirt faces below the native skull boundary move; the head cover and opening stay exactly fixed.',
        '2. Every mq-04 label name and colour is unchanged.',
        '3. Shoulder, facing, collision, ownership, exact native determinism, true-turn in both views, fit, fresh regeneration and hash-bound delivery gates pass. See `review/mq12_gates.json`, `review/feedback1_collision.json` and `validation/native/preservation.json`. `review/feedback1_occlusions.json` records native coverage under the existing mq-04 occlusion rule; the source occlusion values remain unchanged.', '',
        '| View | Original IoU | Feedback 1 IoU | Minimum |', '|---|---:|---:|---:|']
    for view in ('front', 'rear'):
        rows.append(f'| {view} | {gates["fit_before"][view]["iou"]:.9f} | {gates["fit_after"][view]["iou"]:.9f} | {gates["fit_after"][view]["iou_min"]} |')
    rows += ['', 'Open `review/mq12_shoulders.html` for the native 1024 sheet: old front clay / new front clay / new front map, then rear; shoulder joints marked. `review/mq12_joint_table.md` gives shoulders, far elbow and hand before/after. Gloam additionally retains `review/gloam_front_per_part.md` and its hash-bound JSON. Unoccluded native part masks establish the changed regions; registered coverage uses whole painting alpha because no painting part segmentation was supplied.', '',
        'Fresh input-only regeneration matches both clay/map pixels and unrounded geometry. Three native builds (cold, shared-cache replay, independent cold) agree exactly. The eight other measured figure deliveries and compiled specifications, plus the Lancer source, are bound by `../../gale_herald/r2/validation/scope.json`.', '',
        'All generated blends, caches, duplicate exports, superseded proof and clean input trees are hashed in `../discarded_proof_sha256.json` before removal. `../COMMIT_MANIFEST.txt` lists every retained file; the per-figure limit is 6,000,000 bytes.', '',
        'Proof uses the director’s bridge only. For either figure run these operations in order (substitute its id):', '', '```sh',
        'python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow ' + figure.name + ' build --feedback1',
        'python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow ' + figure.name + ' capture --feedback1',
        'python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow ' + figure.name + ' regenerate --feedback1',
        *(['python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow gloam_stalker round0-front --feedback1'] if figure.name == 'gloam_stalker' else []),
        *(['python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow gloam_stalker isolated-near --feedback1'] if figure.name == 'gloam_stalker' else []),
        'python3 -B -m spec.art_identity.maquettes.gale_herald.shoulder_workflow ' + figure.name + ' proof --feedback1', '```', '',
        'No Godot, windowed probe or inspection fixture applies to this offline Blender-only change. The director owns inspection, full suites, peer review, commits and publication. Changes remain uncommitted.', '',
        'Chosen defaults are recorded in `validation/chosen_defaults.json`; no player-facing design values were chosen. No unresolved TODO_DESIGN placeholders.']
    (figure / 'r2/README.md').write_text('\n'.join(rows) + '\n')
    (figure / 'README.md').write_text('# ' + figure.name + ' — mq-12 curated maquette\n\n'
        'Feedback 1 preserves the accepted level-shoulder pose and updates the far shoulder garment attachments. '
        'The canonical `measurements.json` and sealed `delivery/` contain this revision. '
        'Native sheets, joint/overlap tables, gate results, exact bridge commands and chosen defaults are in [r2/README.md](r2/README.md).\n\n'
        '`measurements.json` preserves all authored source measurements, labels, solver settings and identity hashes. '
        'Gloam’s front fit minimum is the director-approved 0.65; all other fit minima remain unchanged. '
        'Generated native specifications, Blender models and caches are not tracked inputs. '
        '`COMMIT_MANIFEST.txt` lists every retained file; discarded proof is SHA-256 inventoried before removal.\n\n'
        'The native source fold pattern is preserved, with a source-bounded translation field at the far shoulder. '
        'Both views use one posed body turned 180 degrees. Original native clay PNG bytes are retained; '
        'mask packing preserves alpha and every visible RGBA value. Fresh regeneration and native preservation evidence '
        'are in `r2/validation/`.\n\n'
        'Historical mq-04 shared review files remain in Herald’s `delivery/review/`. Protected Lancer r3 reference clays '
        'remain byte-for-byte in Gloam’s `delivery/reference/lancer_r3/`. The current authoritative measurements '
        'and gates for these two revised figures are in their `r2/review/` folders.\n')
    print('MQ12_FEEDBACK1_INSTALL: PASS; ' + figure.name)


def finish(figure):
    archive(figure, [*(figure / 'proof').rglob('*'), *(figure / 'r2/capture').rglob('*'),
                     figure / 'r2/review/capture_encoding.json'])
    path = figure / 'discarded_proof_sha256.json'
    data = json.loads(path.read_text())
    data['files'] = list(dict.fromkeys(tuple(row) for row in data['files']))
    write(path, data)
    for path in sorted(figure.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    manifest = figure / 'COMMIT_MANIFEST.txt'
    archive(figure, [manifest])
    manifest.write_text('# Paths relative to this figure. mq-12 sealed native delivery and validation repairs.\n'
        '# Shared builder changes: build, cloth, cloth_cache, compile_recipe, deferred_pose, delivery_validation, pose_adjustment, shoulder_garments, shoulder_motion_audit.\n' +
        '\n'.join(sorted({'COMMIT_MANIFEST.txt'} | {str(p.relative_to(figure)) for p in figure.rglob('*') if p.is_file()})) + '\n')
    return verify(figure)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('figure', choices=('gale_herald', 'gloam_stalker'))
    parser.add_argument('operation', choices=('install', 'finish', 'scope'))
    args = parser.parse_args()
    if args.operation == 'scope':
        scope()
    else:
        (install if args.operation == 'install' else finish)(ROOT / args.figure)
