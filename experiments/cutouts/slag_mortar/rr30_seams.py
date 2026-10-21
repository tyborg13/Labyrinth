"""Headless skin/rigid coverage diagnostic; never claims native GPU proof."""
import argparse
import numpy as np
from PIL import Image
from rr30_case import CASE
from cutout_pipeline.cases import read_json, write_json
from rr30_cpu import CpuPose
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import clean_metrics, bindings
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.source_space import DetachedSource, pocket_report, gate_errors as frame_errors
from humanoid_cutout.anatomy import load
from humanoid_cutout.rigid_air import for_case
from rr30_cpu import sprite_transform
from maquette_motion.material_palette import rules
from rr30_records import space_summary
from rr30_joint_gate import JointSurfaceGate

PROGRESS_INTERVAL_FRAMES = 50


def frame_report(model, pose):
    layers, maps = model.layers(pose)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'], 128)
    if not hasattr(model, 'air_policy'):
        model.air_policy = for_case(CASE, model.layout, load(CASE))
    if model.air_policy:
        transforms = {}
        for part in model.layout['parts']:
            t = sprite_transform(model.layout, pose, part)
            transforms[part['name']] = [t[0,0],t[1,0],t[0,1],t[1,1],t[0,2],t[1,2]]
        spaces = model.air_policy.report(owners > 0, owners, transforms)
    else:
        seam = np.logical_or.reduce(model.masks(pose, model.layout['proof_joint_seams'], maps))
        references = model.masks(pose, model.layout['proof_rest_holes'], maps)
        tears = joint_holes(owners > 0, seam, owners, references, pocket_details=True)
        spaces = pocket_report(layers, tears)
    defects = [{'bbox': r['bbox'], 'pixel_count': r['pixel_count']} for r in spaces['failures']]
    metrics = clean_metrics(layers, rules(CASE, model.layout['facing']))
    detached = model.detached_source.report(layers, {name: part['transform'] for name, part in pose['parts'].items()})
    metrics.update(detached['metrics'])
    return layers, defects, metrics, owners, dict(spaces, source_components=detached['source_components'],
                                               unmatched_components=detached['unmatched_components'])


def report(layout, samples, clips=None):
    view = layout['facing']
    model = CpuPose(CASE, layout)
    joint_gate = JointSurfaceGate(CASE, layout)
    from rr31_images import ImageGate
    image_gate, image_error = None, None
    try:
        image_gate = ImageGate(CASE, layout)
    except Exception as error:
        image_error = str(error)
    model.detached_source = DetachedSource(CASE, layout)
    rows = [r for r in samples['samples'] if r['view'] == view and r['kind'] == 'presented'
            and (not clips or r['clip'] in clips)]
    errors, failures, passed = [], [], []
    joint_maximum = 0.
    joint_failures = []
    image_failures = []
    print(f'RR30 {view.upper()} CPU COVERAGE: checking {len(rows)} frames', flush=True)
    for index, pose in enumerate(rows):
        layers, holes, metrics, _, spaces = frame_report(model, pose)
        surfaces = joint_gate.frame(pose, layers)
        try:
            if image_gate is None: raise ValueError(image_error)
            image = image_gate.frame(pose, layers)
        except Exception as error:
            image = dict(ok=False,errors=[{'diagnostic_unavailable':str(error)}],interior_contour=[])
        if not image['ok']:
            # Full source/RGBA attribution belongs to rr31's ignored CPU log;
            # retain a small tracked inventory in the existing rr30 summary.
            image_failures.append(dict(clip=pose['clip'],frame=pose['frame'],
                morphology_errors=len(image['errors']),interior_pieces=len(image['interior_contour'])))
        joint_maximum = max(joint_maximum, surfaces['maximum_visible_cover_distance_px'])
        if spaces['air_pockets'] or spaces['source_components']:
            passed.append(dict(clip=pose['clip'], frame=pose['frame'], **spaces))
        rejected = frame_errors((view, pose['clip'], pose['frame']), metrics, holes)
        if not surfaces['ok']:
            joint_failures.append(surfaces)
            rejected.append('%s/%s/%d: joint surfaces: %d cover violations; %d dark-seam violations' % (
                view,pose['clip'],pose['frame'],len(surfaces['cover_errors']),len(surfaces['dark_errors'])))
        if rejected:
            composite = Image.new('RGBA', (512, 512))
            for _, image, _ in sorted(layers, key=lambda r: r[0]['z_index']): composite.alpha_composite(Image.fromarray(image))
            path = CASE / f'proof/seam_cpu/{view}_{pose["clip"]}_{pose["frame"]:04d}.png'
            path.parent.mkdir(parents=True, exist_ok=True)
            composite.save(path)
            failures.append(dict(clip=pose['clip'], frame=pose['frame'], holes=holes, metrics=metrics,
                                 capture=str(path.relative_to(CASE))))
            errors += rejected
        if (index + 1) % PROGRESS_INTERVAL_FRAMES == 0:
            print(f'RR30 {view.upper()} CPU COVERAGE: {index+1} frames; {len(failures)} failures', flush=True)
    if not rows: errors.append(view + ': missing presented coverage evidence')
    return dict(ok=not errors, errors=errors, frames=len(rows), failures=failures, native_pixels=False,
                image_gates=dict(ok=not image_failures,blocking=False,frames=len(rows),failures=image_failures),
                joint_surfaces=dict(ok=not joint_failures,maximum_visible_cover_distance_px=joint_maximum,
                    frames=len(rows),failures=joint_failures,skin_luma_floors=joint_gate.skin),
                passed_spaces=passed, air_pockets_passed=sum(len(r['air_pockets']) for r in passed))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--clips', nargs='*')
    args = parser.parse_args()
    samples = read_report(CASE)
    if samples['inputs'] != bindings(CASE): raise ValueError('Refresh samples before coverage diagnostics')
    result = {v: report(read_json(CASE / f'layouts/{v}.json'), samples, args.clips) for v in ('front', 'rear')}
    write_json(CASE / 'proof/logs/seams_full.json', result)
    write_json(CASE / 'proof/seams.json', {v: dict(
        {k: x for k, x in r.items() if k not in ('failures', 'passed_spaces')},
        source_space=space_summary(r['passed_spaces'])) for v, r in result.items()})
    for view, r in result.items(): print(f'RR30 {view.upper()} CPU COVERAGE GATES: {"PASS" if r["ok"] else "FAIL"} ({r["frames"]} frames; {len(r["errors"])} errors)')
    raise SystemExit(int(any(not r['ok'] for r in result.values())))
