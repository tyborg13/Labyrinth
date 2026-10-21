"""Non-blocking rr31 diagnostics, using posed contacts for CPU and GPU.

Exterior contour means a visible piece texel on the assembled rest silhouette
(including painted holes), not an internal ownership cut. Otherwise unchanged
rests would fail their own reference. Attribution follows the topmost rendered
piece, so hidden/occluded source texels cannot falsely fail the contour gate.
"""
import argparse
from collections import Counter
from pathlib import Path
import numpy as np
from PIL import Image
from rr30_case import CASE, PROJECT
from rr30_cpu import CpuPose
from rr30_joint_gate import JointSurfaceGate, source_transform
from rr30_joint_geometry import source_materials, interfaces, declared_joins
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.image_gates import measure, compare, interior, morphology, offsets
from humanoid_cutout.native_frames import load_frame, frame_digest
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.bone_evidence import evidence_errors
from humanoid_cutout.gates import bindings
from maquette_motion import pixels
from rr30_cpu import sprite_transform
from humanoid_cutout.gait_continuations import active_recipe, texture

OUTPUT = CASE.parent / 'rr31'
ROUND3 = PROJECT.parent / 'rr-30/experiments/cutouts/slag_mortar/rr30'
PROGRESS_FRAMES = 100  # Logging only.


def verification_bindings():
    return {str(path.relative_to(PROJECT)):digest(path) for path in (
        Path(__file__),Path(__file__).with_name('rr31_budgets.py'),
        PROJECT/'tools/humanoid_cutout/image_gates.py')}


def rest_pose(layout):
    return dict(view=layout['facing'], clip='rest', frame=0, parts={
        p['name']: {'transform': [1, 0, 0, 1, *p['offset']]}
        for p in layout['parts']})


def composite(layers):
    result = np.zeros_like(layers[0][1])
    owner = np.full(result.shape[:2], -1, dtype=np.int16)
    for index, (_, image, _) in enumerate(layers):
        selected = image[..., 3] > 0
        result[selected] = image[selected]
        owner[selected] = index
    return result, owner


class ImageGate:
    def __init__(self, case, layout, rest_alpha=None):
        self.case, self.layout = case, layout
        self.parts = {p['name']: p for p in layout['parts']}
        visible, _ = source_materials(case, layout)
        self.contacts = {name: row for name, row in interfaces(visible,
            declared_joins(read_json(case/'anatomy.json'))).items() if row['segments']}
        if not self.contacts:
            raise ValueError('Missing painted joint contacts')
        self.model = CpuPose(case, layout)
        self.layer_cache, self.contour_cache = {}, {}
        self.rest_layers = sorted(self.model.layers(rest_pose(layout))[0], key=lambda r: r[0]['z_index'])
        rest, owner = composite(self.rest_layers)
        alpha = rest[..., 3] > 0 if rest_alpha is None else rest_alpha
        self.rest = measure(alpha, self.centroids(rest_pose(layout)))
        contour = alpha & ~morphology(alpha, offsets(1), erode=True)
        self.contours = {}
        for index, (part, image, _) in enumerate(self.rest_layers):
            # At rest every part matrix is an integer translation; map the
            # actually visible outside edge back to its immutable source texel.
            x, y = np.asarray(part['offset'], dtype=int) + pixels.PROOF_DEFAULTS['source_offset']
            source = self.model.image(part['file'])
            selected = contour & (owner == index)
            mask = np.zeros_like(source)
            mask[..., 3] = selected[y:y+source.shape[0], x:x+source.shape[1]] * 255
            self.contours[part['name']] = mask

    def layers(self, pose):
        """Reuse identical rigid rasters; retain only the last per-piece image."""
        result = []
        for part in self.layout['parts']:
            name = part['name']
            transform = sprite_transform(self.layout, pose, part)
            recipe = active_recipe(self.layout,name,gait=pose['clip']=='move',clip=pose['clip'])
            key = (transform.tobytes(), bool(recipe))
            cached = self.layer_cache.get(name)
            if cached is None or cached[0] != key:
                source = self.model.image(part['file']) if recipe is None else texture(
                    self.case,self.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                cached = key, pixels.render(source,transform)
                self.layer_cache[name] = cached
            result.append((part,cached[1],None))
        return result

    def centroids(self, pose):
        result = {}
        for name, row in self.contacts.items():
            points = np.asarray(row['segments'], dtype=float).reshape(-1, 2)
            posed = []
            for piece in row['pieces']:
                transform = source_transform(self.layout, pose, self.parts[piece])
                posed.append(points @ transform[:2, :2].T + transform[:2, 2])
            result[name] = np.concatenate(posed).mean(axis=0).tolist()
        return result

    def frame(self, pose, layers=None, alpha=None):
        ordered = None if layers is None else sorted(layers, key=lambda r: r[0]['z_index'])
        if alpha is None:
            image, owner = composite(ordered)
            alpha = image[..., 3] > 0
        metrics = measure(alpha, self.centroids(pose))
        errors = compare(self.rest, metrics)
        contours = []
        if ordered is not None:
            if 'owner' not in locals(): _, owner = composite(ordered)
            inside = interior(alpha)
            for index, (part, _, _) in enumerate(ordered):
                if not self.contours[part['name']][...,3].any(): continue
                transform = sprite_transform(self.layout, pose, part)
                key = transform.tobytes()
                cached = self.contour_cache.get(part['name'])
                if cached is None or cached[0] != key:
                    cached = key, pixels.render(self.contours[part['name']],transform)[...,3]>0
                    self.contour_cache[part['name']] = cached
                shown = cached[1]
                rejected = shown & (owner == index) & inside
                if rejected.any():
                    yy, xx = np.nonzero(rejected)
                    source = self.model.image(part['file'])
                    vv,uu = np.indices(source.shape[:2])
                    uv = np.stack((uu,vv,np.ones_like(uu),source[...,3]),axis=2).astype('uint8')
                    mapped = pixels.render(uv,transform)
                    texels = mapped[yy,xx,:2].astype(int)
                    contours.append(dict(piece=part['name'], pixels=int(rejected.sum()),
                        destination_pixels=np.column_stack((xx, yy)).tolist(),
                        source_pixels=(texels+part['offset']).tolist(),
                        rgba=source[texels[:,1],texels[:,0]].tolist()))
        return dict(ok=not(errors or contours), view=self.layout['facing'],
                    clip=pose['clip'], frame=pose['frame'], joints=metrics,
                    errors=errors, interior_contour=contours)


def summarize(rows):
    failures = [r for r in rows if not r['ok']]
    groups = Counter((r['view'], r['clip']) for r in failures)
    return dict(ok=bool(rows) and not failures, frames=len(rows), passed=len(rows)-len(failures),
        failed=len(failures), failures_by_clip={v+'/'+c: n for (v,c),n in sorted(groups.items())},
        failing_frames={v+'/'+c: [r['frame'] for r in failures if (r['view'],r['clip'])==(v,c)]
                        for v,c in sorted(groups)})


def cpu_report(case=CASE, samples=None):
    samples = read_report(case) if samples is None else samples
    errors = evidence_errors(read_json(case/'compiled_motion.json'),samples,bindings(case),.0001)
    if errors: raise ValueError('Invalid CPU samples: '+str(errors))
    rows = []
    for view in ('front', 'rear'):
        layout = read_json(case/f'layouts/{view}.json')
        gate, surface = ImageGate(case, layout), JointSurfaceGate(case, layout)
        for pose in samples['samples']:
            if pose['view'] != view or pose['kind'] != 'presented': continue
            layers = gate.layers(pose)
            row = gate.frame(pose, layers)
            row['surfaces'] = surface.frame(pose, layers)
            row['ok'] &= row['surfaces']['ok']
            rows.append(row)
            if len(rows) % PROGRESS_FRAMES == 0:
                print(f'RR31 CPU IMAGES: {len(rows)} frames', flush=True)
    return dict(summarize(rows), native_pixels=False, rows=rows, inputs=samples['inputs'],
                verification_inputs=verification_bindings())


def native_report(case, capture, *, historical=False):
    manifest = read_json(capture/'frames.json')
    if not historical and manifest['inputs'] != bindings(case):
        raise ValueError('Stale native proof; rerun rr30_proof.sh native')
    if not manifest['native_pixels'] or not manifest['ok'] or manifest['errors']:
        raise ValueError('Incomplete native capture')
    if manifest['size']!=[1920,1080] or manifest['ui_scale']!=1.0 or manifest['fps']!=60:
        raise ValueError('Native capture must be 1920x1080, 100% UI scale, 60 Hz')
    expected = {(view,clip,frame) for view in ('front','rear')
                for clip,definition in read_json(case/'compiled_motion.json')['clips'].items()
                for frame in range(round(definition['seconds']*60))}
    actual = [(r['view'],r['clip'],r['frame']) for r in manifest['frames']]
    if len(actual)!=len(expected) or set(actual)!=expected:
        raise ValueError('Missing/duplicate native frame inventory')
    indexed = {}
    for part in manifest['pieces']:
        indexed.setdefault((part['view'],part['clip'],part['frame']), {})[part['name']] = part
    rows = []
    for view in ('front', 'rear'):
        layout = read_json(case/f'layouts/{view}.json')
        rest = np.zeros((512,512), dtype=bool)
        rest[128:383,128:383] = np.asarray(load_frame(capture/f'{view}_rest.png'))[...,3] > 0
        gate = ImageGate(case, layout, rest)
        for frame in manifest['frames']:
            if frame['view'] != view: continue
            if frame_digest(capture/frame['file']) != frame['sha256']:
                raise ValueError('Native frame hash differs: '+frame['file'])
            pose = dict(frame, parts=indexed[(view,frame['clip'],frame['frame'])])
            if pose['parts'].keys() != gate.parts.keys():
                raise ValueError('Missing native posed part transforms')
            alpha = np.asarray(load_frame(capture/frame['file']).convert('RGBA'))[...,3] > 0
            if alpha.shape!=(512,512): raise ValueError('Native figure pixels must remain 1:1')
            row = gate.frame(pose, alpha=alpha)
            row['file'] = frame['file']
            rows.append(row)
    return dict(summarize(rows), native_pixels=True, historical=historical,
                manifest_sha256=digest(capture/'frames.json'), rows=rows,
                verification_inputs=verification_bindings())


def save(name, result):
    result['blocking'] = False
    write_json(OUTPUT/f'proof/logs/{name}_full.json', result)
    summary = {k:v for k,v in result.items() if k not in ('rows','inputs')}
    write_json(OUTPUT/f'proof/{name}.json', summary)
    print(f'RR31 {name.upper()} DIAGNOSTIC: {"PASS" if result["ok"] else "FAIL"} '
          f'({result["passed"]}/{result["frames"]} passed; {result["failed"]} failed)', flush=True)
    return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['cpu','round3','native'])
    parser.add_argument('--capture', type=Path)
    args = parser.parse_args()
    try:
        if args.mode == 'cpu': result = cpu_report()
        else:
            case = ROUND3 if args.mode == 'round3' else CASE
            result = native_report(case, args.capture or case/'proof/native', historical=args.mode=='round3')
        save(args.mode, result)
    except Exception as error:
        # Preserve the unavailable evidence in a report, without changing
        # canonical rr30 acceptance or allowing it to block a proof stage.
        write_json(OUTPUT/f'proof/{args.mode}.json',dict(ok=False,blocking=False,
            unavailable=True,error=str(error),verification_inputs=verification_bindings()))
        print(f'RR31 {args.mode.upper()} DIAGNOSTIC: UNAVAILABLE ({error}; non-blocking)',flush=True)
    return 0


if __name__ == '__main__': raise SystemExit(main())
