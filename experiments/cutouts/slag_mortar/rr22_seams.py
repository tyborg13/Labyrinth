"""Headless skin/rigid coverage diagnostic; never claims native GPU proof."""
import argparse
import numpy as np
from PIL import Image
from rr22_case import CASE
from cutout_pipeline.cases import read_json, write_json
from rr22_cpu import CoveragePose as CpuPose
from humanoid_cutout.gates import clean_metrics, bindings
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.native_exceptions import frame_errors
from maquette_motion.material_palette import rules
from rr22_records import samples as read_samples

PROGRESS_INTERVAL_FRAMES = 50


def frame_report(model, pose):
    layers, maps = model.layers(pose)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'], 128)
    seam = np.logical_or.reduce(model.masks(pose, model.layout['proof_joint_seams'], maps))
    references = model.masks(pose, model.layout['proof_rest_holes'], maps)
    defects = joint_holes(owners > 0, seam, owners, references, pocket_details=True)
    metrics = clean_metrics(layers, rules(CASE, model.layout['facing']))
    return layers, defects, metrics, owners


def report(layout, samples, clips=None):
    view = layout['facing']
    model = CpuPose(CASE, layout)
    rows = [r for r in samples['samples'] if r['view'] == view and r['kind'] == 'presented'
            and (not clips or r['clip'] in clips)]
    errors, failures = [], []
    print(f'RR22 {view.upper()} CPU COVERAGE: checking {len(rows)} frames', flush=True)
    for index, pose in enumerate(rows):
        layers, holes, metrics, _ = frame_report(model, pose)
        rejected = frame_errors((view, pose['clip'], pose['frame']), metrics, holes)
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
            print(f'RR22 {view.upper()} CPU COVERAGE: {index+1} frames; {len(failures)} failures', flush=True)
    if not rows: errors.append(view + ': missing presented coverage evidence')
    return dict(ok=not errors, errors=errors, frames=len(rows), failures=failures, native_pixels=False)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--clips', nargs='*')
    args = parser.parse_args()
    samples = read_samples()
    if samples['inputs'] != bindings(CASE): raise ValueError('Refresh samples before coverage diagnostics')
    result = {v: report(read_json(CASE / f'layouts/{v}.json'), samples, args.clips) for v in ('front', 'rear')}
    write_json(CASE / 'proof/logs/seams_full.json', result)
    write_json(CASE / 'proof/seams.json', {v: {k: x for k, x in r.items() if k != 'failures'} for v, r in result.items()})
    for view, r in result.items(): print(f'RR22 {view.upper()} CPU COVERAGE GATES: {"PASS" if r["ok"] else "FAIL"} ({r["frames"]} frames; {len(r["errors"])} errors)')
    raise SystemExit(int(any(not r['ok'] for r in result.values())))
