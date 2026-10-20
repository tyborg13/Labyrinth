"""All-frame CPU joint coverage diagnostic; never native acceptance."""
import argparse
import numpy as np
from PIL import Image
from case import CASE, VIEWS, read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose as FullCpuPose, mesh_map, mapped, sprite_transform
from maquette_motion import pixels
from humanoid_cutout.gates import bindings, clean_metrics
from humanoid_cutout.silhouette_gates import posed_owners
from humanoid_cutout.anatomy import load
from humanoid_cutout.source_space import DetachedSource, pocket_report as pockets
from maquette_motion.pixels import PROOF_DEFAULTS
from humanoid_cutout.bone_evidence import read_report


# Prune only triangles whose entire UV rectangle is transparent. The original
# full-canvas hole template has far-away empty triangles that can balloon when
# its two-segment field folds. Opaque fragments and all their weights survive.
PROOF_UV_MARGIN_PX = 1
PROGRESS_INTERVAL_FRAMES = 100

def prune_mask_triangles(mesh, alpha):
    uv = np.asarray(mesh['uvs'])
    kept = []
    for triangle in mesh['triangles']:
        low = np.maximum(0, np.floor(uv[triangle].min(axis=0)).astype(int) - PROOF_UV_MARGIN_PX)
        high = np.minimum(alpha.shape[::-1], np.ceil(uv[triangle].max(axis=0)).astype(int) + PROOF_UV_MARGIN_PX)
        if alpha[low[1]:high[1], low[0]:high[0]].any(): kept.append(triangle)
    mesh['triangles'] = kept
    return mesh


class CpuPose(FullCpuPose):
    def __init__(self, case, layout):
        super().__init__(case, layout)
        for record in layout['proof_rest_holes'] + layout['proof_joint_seams']:
            if 'mesh_template' not in record: continue
            mesh = read_json(case / record['mesh_template'])
            alpha = self.image(record['file'])[..., 3] > 0
            prune_mask_triangles(mesh, alpha)
            self.templates[record['mesh_template']] = mesh

    def masks(self, pose, records, maps):
        result = []
        for record in records:
            image = self.image(record['file'])
            if 'mesh_template' in record:
                key=record['mesh_template']
                if key not in maps: maps[key]=mesh_map(self.layout,pose,self.templates[key])
                posed=mapped(image,maps[key])
            else:
                part={'bone':record['bone'],'offset':[0,0]}
                posed=pixels.render(image,sprite_transform(self.layout,pose,part))
            result.append(posed[...,3]>0)
        return result


def state(model, pose):
    layers, maps = model.layers(pose)
    owners = posed_owners(layers, model.layout['parts'], pose['bones'],
                          PROOF_DEFAULTS['source_offset'], load(CASE)['ownership'])
    defects = pockets(layers)['failures']
    return layers, maps, owners, defects


def report(view, samples, output):
    current = bindings(CASE)
    if samples['inputs'] != current: raise ValueError('Refresh bound samples before CPU diagnostic')
    model = CpuPose(CASE, read_json(CASE / f'layouts/{view}.json'))
    detached_source = DetachedSource(CASE, model.layout)
    failures, space_records, count = [], [], 0
    for pose in samples['samples']:
        if pose['view'] != view or pose['kind'] != 'presented': continue
        layers, _, _, defects = state(model, pose)
        metrics = clean_metrics(layers)
        space = pockets(layers)
        detached = detached_source.report(layers, {name: part['transform'] for name, part in pose['parts'].items()})
        metrics.update(detached['metrics'])
        if space['air_pockets'] or space['failures'] or detached['source_components']:
            space_records.append({'clip':pose['clip'],'frame':pose['frame'],**space,
                                  'source_components':detached['source_components']})
        rejected = {k:metrics[k] for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks','outline_outside_pixels','stray_components') if metrics[k]}
        if defects or rejected:
            failures.append({'clip':pose['clip'],'frame':pose['frame'],'holes':defects,'metrics':rejected})
            composite = Image.new('RGBA', (PROOF_DEFAULTS['canvas_size'],)*2)
            for _, image, _ in sorted(layers, key=lambda item:item[0]['z_index']): composite.alpha_composite(Image.fromarray(image))
            output.mkdir(parents=True, exist_ok=True)
            composite.save(output / f'{view}_{pose["clip"]}_{pose["frame"]:04d}.png')
        count += 1
        if count % PROGRESS_INTERVAL_FRAMES == 0: print(f'RR20 CPU {view}: {count} frames; {len(failures)} failing', flush=True)
    stale = bindings(CASE) != current
    if stale: failures.append({'evidence_error':'Inputs changed during CPU diagnostic'})
    result = {'ok':not failures,'native_pixels':False,'scope':'CPU estimate; director GPU recapture required',
              'view':view,'frames':count,'failures':failures,'rest_space':space_records,'inputs':current}
    write_json(output / 'report.json', result)
    print(f'RR20 CPU {view.upper()}: {"PASS" if result["ok"] else "FAIL"} ({count} frames; {len(failures)} failing frames)', flush=True)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--view', choices=VIEWS, required=True)
    parser.add_argument('--output', type=__import__('pathlib').Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(CASE / 'proof/seam_cpu'): raise ValueError('CPU output belongs in ignored proof/seam_cpu')
    raise SystemExit(int(not report(args.view, read_report(CASE), args.output)['ok']))
