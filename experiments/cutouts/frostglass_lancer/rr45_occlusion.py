"""All-frame mq-14 shaft occlusion checks, including real isolated native paint.

Screen overlap alone is insufficient: only overlapping, opaque surfaces whose
transported mq-14 depth is nearer than the shaft create an obligation. Report
each violating frame/piece and a crop. Native acceptance additionally binds
inputs, complete inventories, hashes, dimensions and the composed pixels.
"""
import argparse
from collections import Counter
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from rr37_case import CASE, PROJECT, ASSETS
sys.path[:0] = [str(PROJECT/'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import mapped, mesh_map
from humanoid_cutout.gates import matrix, bindings
from humanoid_cutout.native_frames import load_frame, frame_digest
from maquette_motion import pixels
from rr37_raster import CpuPose
from rr45_depth import DepthOracle, OCCLUDERS, DEPTH_EPSILON_M
from rr45_preservation import lowered_depth

CROP_PADDING_PX = 8  # Diagnostic context only; native crops retain native pixels.
HISTORICAL_CAPTURE = CASE.parent/'rr39_fixture'


def apply():
    """Change only the existing rigid spear's layer; never paint or motion."""
    for root, pattern in ((CASE,'layouts/{}.json'),(ASSETS/'humanoid_v2','{}.json')):
        for view in ('front','rear'):
            path = root/pattern.format(view)
            layout = read_json(path)
            next(p for p in layout['parts'] if p['name']=='spear')['z_index'] = lowered_depth(layout)
            if 'proof_layers' in layout:
                layout['proof_layers']['spear']['z_index'] = lowered_depth(layout)
            write_json(path,layout)
    print('RR45 DEPTH ROUTING: PASS (only source/production spear z_index changed)')


def compose(layers):
    canvas = Image.new('RGBA', (layers[0][1].shape[1],layers[0][1].shape[0]))
    owners = np.full(layers[0][1].shape[:2],-1,np.int16)
    for index in sorted(range(len(layers)),key=lambda i:layers[i][0]['z_index']):
        _, image, _ = layers[index]
        canvas.alpha_composite(Image.fromarray(image))
        owners[image[...,3]>0] = index
    return np.asarray(canvas), owners


def measure(case, layout, pose, layers, maps, oracle, composed=None):
    """One common depth/ownership algorithm for software and native evidence."""
    image, owners = compose(layers)
    parts = {part['name']:part for part in layout['parts']}
    item = [i for i,(p,_,_) in enumerate(layers) if p['logical_part']=='spear']
    main = parts['spear']
    transform = matrix(pose['parts']['spear']['transform'])
    transform[:2,2] -= transform[:2,:2] @ np.asarray(main['offset'])
    depth_image = pixels.render(oracle.shaft_source(case),transform)
    shaft = (depth_image[...,3]>0) & np.logical_or.reduce([layers[i][1][...,3]>0 for i in item])
    depths = oracle.decode(depth_image)
    visible = np.isin(owners,item) & shaft
    failures, obligations, masks = [], {}, {}
    for index,(part,paint,_) in enumerate(layers):
        name = part['logical_part']
        # Radially expanded hidden tucks are seam capacity, not the maquette's
        # front surface. Letting that padding occlude visible paint would
        # change the approved rest (notably the wood beside the fist).
        if name not in OCCLUDERS or part.get('hidden_material'): continue
        x0,y0,x1,y1 = part['bbox']
        source = oracle.encoded_surfaces[name][y0:y1,x0:x1]
        depth = (mapped(source,maps[part['name']]) if part['name'] in maps else
            pixels.render(source,matrix(pose['parts'][part['name']]['transform'])))
        expected = shaft & (paint[...,3]>0) & (depth[...,3]>0) & (depths > oracle.decode(depth)+DEPTH_EPSILON_M)
        obligations[part['name']] = int(expected.sum())
        bad = expected & visible
        if bad.any():
            ys,xs = np.nonzero(bad)
            bbox = [int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
            failures.append({'view':layout['facing'],'clip':pose['clip'],'frame':pose['frame'],
                'piece':part['name'],'pixels':int(bad.sum()),'bbox':bbox})
            masks[part['name']] = bad
    # Native layer ordering must explain the actual full-frame pixels at every
    # relevant overlap. A fabricated z_index cannot turn a bad render green.
    if composed is not None:
        relevant = shaft & np.logical_or.reduce([p[...,3]>0 for row,p,_ in layers
            if row['logical_part'] in OCCLUDERS])
        if np.any(np.any(image!=composed,axis=-1)&relevant):
            raise ValueError('Native composite disagrees with isolated shaft/body draw order')
    return failures, obligations, image, masks


def save_crops(output, failures, image):
    if output is None: return
    output.mkdir(parents=True,exist_ok=True)
    for finding in failures:
        x0,y0,x1,y1 = finding['bbox']
        box = (max(0,x0-CROP_PADDING_PX),max(0,y0-CROP_PADDING_PX),
            min(image.shape[1],x1+CROP_PADDING_PX),min(image.shape[0],y1+CROP_PADDING_PX))
        path = output/('{view}_{clip}_{frame:04d}_{piece}.png'.format(**finding))
        Image.fromarray(image).crop(box).save(path)
        finding['crop'] = str(path.relative_to(output.parent))
        finding['crop_sha256'] = digest(path)


def result(rows, failures, native_pixels):
    counts = Counter(f['piece'] for f in failures)
    return {'ok':not failures,'native_pixels':native_pixels,'frames':rows,'findings':failures,
        'finding_counts':dict(sorted(counts.items())),
        'depth_authority':'mq-14 measurements.json: camera, spear path, armour mounts and registered cloak panel',
        'depth_authority_sha256':digest(PROJECT/'spec/art_identity/maquettes/frostglass_lancer/measurements.json')}


def cpu_shard(selected, *, case, crops):
    rows, failures = [], []
    with for_case(case):
        for view in ('front','rear'):
            layout = read_json(case/f'layouts/{view}.json')
            model, oracle = CpuPose(case,layout), DepthOracle(layout)
            for pose in (r for r in selected if r['view']==view):
                layers,maps = model.layers(pose)
                # CpuPose uses layout layers for old diagnostics. This gate
                # explicitly consumes actual sampled painted-node depths.
                layers = [(dict(p,z_index=pose['parts'][p['name']]['z_index']),im,checks) for p,im,checks in layers]
                bad,expected,image,_ = measure(case,layout,pose,layers,maps,oracle)
                save_crops(crops,bad,image)
                failures.extend(bad)
                rows.append({'view':view,'clip':pose['clip'],'frame':pose['frame'],'occluded_pixels':expected})
    return rows,failures


def cpu_report(samples, case=CASE, crops=None, rest_samples=None):
    from functools import partial
    from sweep_parallel import map_shards
    selected = [r for r in samples['samples'] if r['kind']=='presented']
    data = read_json(case/'compiled_motion.json')
    expected = {(v,c,f) for v in data['view_tracks'] for c,d in data['clips'].items()
        for f in range(round(d['seconds']*60))}
    keys = [(r['view'],r['clip'],r['frame']) for r in selected]
    if len(keys)!=len(set(keys)) or set(keys)!=expected:
        raise ValueError('RR45 incomplete or duplicate software frame inventory')
    if rest_samples:
        rest = rest_samples['samples']
        if len(rest)!=2 or {(r['view'],r['clip']) for r in rest}!={('front','rest'),('rear','rest')}:
            raise ValueError('RR45 incomplete rest inventory')
        selected += rest
    shards = map_shards(partial(cpu_shard,case=case,crops=crops),selected)
    rows = sorted([row for group,_ in shards for row in group],key=lambda r:(r['view'],r['clip'],r['frame']))
    failures = sorted([f for _,group in shards for f in group],key=lambda r:(r['view'],r['clip'],r['frame'],r['piece']))
    return result(rows,failures,False)


def native_report(capture, case=CASE, historical=False, crops=None):
    manifest = read_json(capture/'frames.json')
    if not manifest.get('native_pixels') or manifest.get('size')!=[1920,1080] or manifest.get('ui_scale')!=1:
        raise ValueError('RR45 requires native 1920x1080 / 100% capture')
    if historical:
        if capture.resolve()!=HISTORICAL_CAPTURE.resolve(): raise ValueError('Only the immutable rr-39 archive is a negative control')
    elif manifest.get('inputs')!=bindings(case):
        raise ValueError('RR45 native capture is stale')
    data = read_json(case/'compiled_motion.json')
    expected = {(v,c,f) for v in data['view_tracks'] for c,d in data['clips'].items()
        for f in range(round(d['seconds']*60))}
    keys = [(r['view'],r['clip'],r['frame']) for r in manifest['frames']]
    if len(keys)!=len(set(keys)) or (not historical and set(keys)!=expected) or not keys:
        raise ValueError('RR45 incomplete or duplicate native frame inventory')
    groups = {}
    for row in manifest['pieces']: groups.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    rows,failures = [],[]
    with for_case(CASE if historical else case):
        models,oracles = {},{}
        archive_poses = {}
        if historical:
            from rr39_fixture import models as historical_models
            models = historical_models()
            archive_poses = {(r['view'],r['clip'],r['frame']):r for r in read_json(capture/'poses.json')['samples']}
        for view in ('front','rear'):
            layout = models[view].layout if historical else read_json(case/f'layouts/{view}.json')
            # Pre-rr43 archives predate the measured painted grip field.
            if 'source_grip' not in layout['held_items']['spear']:
                from rr43_spear import source_grip
                layout['held_items']['spear']['source_grip'] = source_grip(layout)
            if not historical: models[view] = CpuPose(case,layout)
            oracles[view] = DepthOracle(layout)
            if historical:
                # This old archive has no feature-mask files. Its lower run
                # (grip to floor) is unambiguously wood in the maquette; use
                # only that run for these immutable negative controls.
                grip = np.array(layout['held_items']['spear']['source_grip'])
                floor = np.array(layout['held_items']['spear']['floor_end'])
                oracle = oracles[view]
                oracle._shaft_sources[case] = oracle.encode(oracle.shaft,(oracle.xy-grip)@(floor-grip)>=0)
        def load(row, field='file', hash_field='sha256'):
            path = capture/row[field]
            if frame_digest(path)!=row[hash_field]: raise ValueError('Changed native occlusion pixels: '+str(path))
            image = np.asarray(load_frame(path).convert('RGBA'))
            size = pixels.PROOF_DEFAULTS['canvas_size']
            if image.shape!=(size,size,4): raise ValueError('RR45 native layer dimensions differ')
            return image
        for full in manifest['frames']:
            key = (full['view'],full['clip'],full['frame'])
            model,oracle = models[full['view']],oracles[full['view']]
            parts = {p['name']:p for p in model.layout['parts']}
            records = groups.get(key,[])
            if len(records)!=len(parts) or {r['name'] for r in records}!=set(parts):
                raise ValueError('RR45 incomplete native isolated-layer inventory')
            pose = dict(full,parts={r['name']:{'transform':r['transform']} for r in records})
            if historical: pose['bones'] = archive_poses[key]['bones']
            elif 'bones' not in full: raise ValueError('RR45 native capture lacks source-space bone evidence; recapture')
            else: pose['bones'] = full['bones']
            maps = {name:mesh_map(model.layout,pose,mesh) for name,mesh in model.meshes.items()
                if parts[name]['logical_part'] in OCCLUDERS}
            layers = [(dict(parts[r['name']],z_index=r['z_index']),load(r),None) for r in records]
            composed = load(full)
            bad,obligations,_,_ = measure(case,model.layout,pose,layers,maps,oracle,composed)
            save_crops(crops,bad,composed)
            failures.extend(bad)
            rows.append({'view':full['view'],'clip':full['clip'],'frame':full['frame'],'occluded_pixels':obligations})
    return result(rows,failures,True)


if __name__=='__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,default=CASE)
    parser.add_argument('--apply',action='store_true')
    parser.add_argument('--samples',type=Path)
    parser.add_argument('--rest-samples',type=Path)
    parser.add_argument('--native',type=Path)
    parser.add_argument('--historical',action='store_true')
    parser.add_argument('--output',type=Path)
    args = parser.parse_args()
    if args.apply: apply();raise SystemExit(0)
    if args.output is None: parser.error('--output is required')
    crops = args.output.parent/(args.output.stem+'_crops')
    report = (native_report(args.native,args.case,args.historical,crops) if args.native else
        cpu_report(read_json(args.samples),args.case,crops,read_json(args.rest_samples) if args.rest_samples else None))
    write_json(args.output,report)
    print('RR45 SHAFT OCCLUSION: %s (%d frames; %d frame/piece findings; native=%s)' %
        ('PASS' if report['ok'] else 'FAIL',len(report['frames']),len(report['findings']),report['native_pixels']))
    raise SystemExit(not report['ok'])
