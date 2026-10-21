"""Read-only calibration against integration's approved humanoid v2 cases.

Use shared mesh rasterization, actual Sprite2D matrices and Mimic draw order.
Canonical zones use the existing ownership tags (including garment segments),
not invented cut lines in the paintings. Accessories are not humanoid joints.
No threshold is installed until all six native negative controls are separated.
"""
from collections import Counter, defaultdict
from pathlib import Path
import argparse
import numpy as np
from rr30_case import CASE, PROJECT
from rr31_images import OUTPUT, ROUND3, composite, rest_pose
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose, mesh_map, mapped
from humanoid_cutout.gates import matrix, bindings
from humanoid_cutout.bone_evidence import evidence_errors
from humanoid_cutout.image_gates import measure, counts, interior, morphology, offsets
from humanoid_cutout.silhouette_gates import posed_owners
from humanoid_cutout.gait_continuations import active_recipe, texture
from maquette_motion import pixels
from maquette_motion.raster import SUBPIXEL_SCALE

APPROVED = ('hoarfrost_seer', 'arc_thrall', 'glacial_mirror', 'hollow_mimic')
METRICS = ('notches', 'frays', 'interior_contour')
# Semantic aliases for existing ownership records, not paint changes.
ALIASES = {
    'hoarfrost_seer': {'robe': 'pelvis'},
    'arc_thrall': {'loincloth': 'pelvis', 'tube': 'fore_near', 'claw': 'hand_far'},
    'glacial_mirror': {'fist_near': 'hand_near', 'fist_far': 'hand_far'},
    'hollow_mimic': {},
    'slag_mortar': {'belt': 'pelvis', 'bracer_near': 'fore_near', 'bracer_far': 'fore_far'},
}
ZONE_PAIRS = {'neck': [('head', 'torso')], 'waist': [('pelvis', 'torso')]}
for side in ('near', 'far'):
    ZONE_PAIRS.update({
        'shoulder_'+side: [('torso', 'upper_'+side)],
        'elbow_'+side: [('upper_'+side, 'fore_'+side)],
        'wrist_'+side: [('fore_'+side, 'hand_'+side)],
        'hip_'+side: [('pelvis', 'thigh_'+side), ('torso', 'thigh_'+side)],
        'knee_'+side: [('thigh_'+side, 'shin_'+side)],
        # Seer's robe meets the foot directly, without a visible leg cut.
        'ankle_'+side: [('shin_'+side, 'foot_'+side), ('pelvis', 'foot_'+side)],
    })
PROGRESS_INTERVAL = 100  # Debug logging only.
BARYCENTRIC_TOLERANCE = 1e-9  # Contact interpolation float tolerance only.
NEAREST_CONTACT_CHUNK_PIXELS = 1024  # Memory bound only.


def affine(points, transform):
    # Match the shared renderer's explicit arithmetic (no platform BLAS).
    return np.column_stack((points[:,0]*transform[0,0]+points[:,1]*transform[0,1]+transform[0,2],
                            points[:,0]*transform[1,0]+points[:,1]*transform[1,1]+transform[1,2]))


def rest_bones(layout):
    pose = rest_pose(layout)
    pose['bones'] = {n: {'global': [1, 0, 0, 1, *j['position']]}
                     for n, j in layout['joints'].items()}
    return pose


def interpolation(mesh, points):
    """Rest-point triangle coordinates; reuse for every posed contact centroid."""
    vertices = np.asarray(mesh['vertices'], dtype=float)
    indices = np.asarray(mesh['triangles'])
    selected = np.full(len(points), -1, dtype=int)
    weights = np.zeros((len(points), 3))
    for index, triangle in enumerate(vertices[indices]):
        a, b, c = triangle
        basis = np.column_stack((b-a, c-a))
        if abs(np.linalg.det(basis)) < BARYCENTRIC_TOLERANCE:
            continue
        candidates = np.flatnonzero((selected < 0) &
            (points >= triangle.min(axis=0)-BARYCENTRIC_TOLERANCE).all(axis=1) &
            (points <= triangle.max(axis=0)+BARYCENTRIC_TOLERANCE).all(axis=1))
        if not len(candidates): continue
        uv = affine(points[candidates]-a,np.column_stack((np.linalg.inv(basis),[0,0])))
        bary = np.column_stack((1-uv.sum(axis=1), uv))
        valid = (bary >= -BARYCENTRIC_TOLERANCE).all(axis=1)
        selected[candidates[valid]] = index
        weights[candidates[valid]] = bary[valid]
    if (selected < 0).any():
        raise ValueError('Paint contact lies outside its mesh')
    return indices[selected], weights


class CalibrationGate:
    def __init__(self, creature, case, layout):
        self.creature, self.case, self.layout = creature, case, layout
        self.model = CpuPose(case, layout)
        self.parts = {p['name']: p for p in layout['parts']}
        self.meshes = self.model.meshes
        self.cache = {}
        rest = rest_bones(layout)
        layers = self.layers(rest)
        image, owner = composite(layers)
        alpha = image[..., 3] > 0
        yy = np.nonzero(alpha)[0]
        self.height = int(yy.max()-yy.min()+1)
        # Only topmost texels of the assembled rest exterior are contours.
        edge = alpha & ~morphology(alpha, offsets(1), erode=True)
        self.contours = {}
        for index, (part, _, _) in enumerate(layers):
            source = self.model.image(part['file'])
            x, y = np.asarray(part['offset']) + pixels.PROOF_DEFAULTS['source_offset']
            contour = np.zeros_like(source)
            contour[..., 3] = (edge & (owner == index))[y:y+source.shape[0],x:x+source.shape[1]] * 255
            self.contours[part['name']] = contour
        # Existing segment ownership supplies virtual elbows/knees inside skins.
        visible = [r for r in layers if not r[0].get('hidden_material',False)]
        owners = posed_owners(visible, layout['parts'], rest['bones'], 128)
        ownership = read_json(case/'anatomy.json')['ownership']
        alias = ALIASES[creature]
        ids = {name: i+1 for i, name in enumerate(ownership['names'])}
        canonical = defaultdict(list)
        for name, value in ids.items(): canonical[alias.get(name, name)].append(value)
        _, piece_owner = composite(visible)
        self.contacts, self.contact_interpolation, self.contact_methods = {}, {}, {}
        for zone, pairs in ZONE_PAIRS.items():
            points = defaultdict(list)
            for first, second in pairs:
                a, b = [np.isin(owners, canonical[n]) for n in (first, second)]
                for left, right in ((a,b),(b,a)):
                    for axis in (0,1):
                        selected = (left[:-1] & right[1:]) if axis == 0 else (left[:,:-1] & right[:,1:])
                        y,x = np.nonzero(selected)
                        for xx,yy in zip(x,y):
                            # Edge midpoint = mean of the original segment endpoints.
                            point = [xx+.5 if axis==0 else xx+1, yy+1 if axis==0 else yy+.5]
                            for px,py in ((xx,yy),(xx+(axis==1),yy+(axis==0))):
                                part = visible[int(piece_owner[py,px])][0]
                                points[part['name']].append(np.asarray(point)-128)
            method = 'painted shared grid-edge midpoints'
            if not points:
                # Approved separated stones still have joint zones. Use the
                # exact nearest painted pixel-centre pair, never a new radius
                # or a hand-positioned test camera. Hidden anatomical regions
                # (e.g. Seer's knees under its robe) have no such pair.
                closest = None
                for first,second in pairs:
                    ya,xa=np.nonzero(np.isin(owners,canonical[first]))
                    yb,xb=np.nonzero(np.isin(owners,canonical[second]))
                    if not len(xa) or not len(xb): continue
                    aa,bb=np.column_stack((xa,ya)),np.column_stack((xb,yb))
                    for at in range(0,len(aa),NEAREST_CONTACT_CHUNK_PIXELS):
                        delta=aa[at:at+NEAREST_CONTACT_CHUNK_PIXELS,None]-bb
                        distances=(delta*delta).sum(axis=2)
                        minimum=int(distances.min())
                        ia,ib=np.nonzero(distances==minimum)
                        selected=list(zip(aa[at+ia],bb[ib]))
                        if closest is None or minimum<closest[0]: closest=(minimum,selected)
                        elif minimum==closest[0]: closest[1].extend(selected)
                if closest:
                    for pair in closest[1]:
                        for xx,yy in pair:
                            part=visible[int(piece_owner[yy,xx])][0]
                            points[part['name']].append(np.asarray([xx+.5,yy+.5])-128)
                    method='mean of all exact nearest painted pixel-centre pairs'
            if points:
                self.contacts[zone] = {n: np.asarray(p) for n,p in points.items()}
                self.contact_methods[zone] = method
                self.contact_interpolation[zone] = {n: interpolation(self.meshes[n], p)
                    for n,p in self.contacts[zone].items() if n in self.meshes}
        self.rest = self.frame(rest)['joints']

    def transform(self, pose, part):
        captured = pose.get('parts', {}).get(part['name'])
        if captured is not None and part['name'] not in self.meshes:
            return matrix(captured['transform'])
        from humanoid_cutout.cpu_pose import sprite_transform
        return sprite_transform(self.layout, pose, part)

    def layers(self, pose, *, contours=False):
        result = []
        for part in self.layout['parts']:
            name = part['name']
            recipe = active_recipe(self.layout,name,gait=pose['clip']=='move',clip=pose['clip'])
            if name in self.meshes:
                mesh = self.meshes[name]
                key = tuple(tuple(pose['bones'][n]['global']) for n in mesh['weights'])
            else:
                key = tuple(self.transform(pose,part).ravel())
            key = (key, str(recipe))
            cached = self.cache.get(name)
            if cached is None or key != cached['key']:
                source = self.model.image(part['file']) if recipe is None else texture(
                    self.case,self.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                mapping = mesh_map(self.layout,pose,self.meshes[name]) if name in self.meshes else None
                render = (lambda image: mapped(image,mapping)) if mapping is not None else (
                    lambda image: pixels.render(image,self.transform(pose,part)))
                cached = {'key':key,'image':render(source), 'mapping':mapping}
                if hasattr(self,'contours'):
                    cached['contour'] = render(self.contours[name])[...,3]>0
                self.cache[name] = cached
            if contours and 'contour' not in cached:
                cached['contour'] = (mapped(self.contours[name],cached['mapping']) if name in self.meshes
                    else pixels.render(self.contours[name],self.transform(pose,part)))[...,3]>0
            result.append((part,cached['contour'] if contours else cached['image'],None))
        rank = {n:i for i,n in enumerate(pose.get('part_draw_order',[]))}
        return sorted(result,key=lambda r: (
            pose.get('parts',{}).get(r[0]['name'],{}).get('z_index',r[0]['z_index']),
            rank.get(r[0]['name'],0)))

    def centroids(self, pose):
        result = {}
        for zone, parts in self.contacts.items():
            posed = []
            for name, points in parts.items():
                if name not in self.meshes:
                    t = self.transform(pose,self.parts[name])
                    posed.append(affine(points-self.parts[name]['offset'],t)+128)
                    continue
                mesh = self.meshes[name]
                vertices = np.asarray(mesh['vertices'],dtype=float)
                xy = np.zeros_like(vertices)
                for bone, weights in mesh['weights'].items():
                    t = matrix(pose['bones'][bone]['global'])
                    bind = self.layout['joints'][bone]['position']
                    xy += np.asarray(weights,dtype=np.float32)[:,None]*affine(vertices-bind,t)
                xy = np.floor((xy+128)*SUBPIXEL_SCALE+.5)/SUBPIXEL_SCALE
                triangles,bary = self.contact_interpolation[zone][name]
                posed.append((xy[triangles]*bary[...,None]).sum(axis=1))
            result[zone] = np.concatenate(posed).mean(axis=0).tolist()
        return result

    def frame(self, pose, *, alpha=None):
        layers = self.layers(pose)
        image,owner = composite(layers)
        if alpha is None: alpha=image[...,3]>0
        centroids = self.centroids(pose)
        metrics = measure(alpha,centroids)
        rejected = np.zeros_like(alpha)
        attribution = {}
        inside = interior(alpha)
        for index,(part,contour,_) in enumerate(self.layers(pose,contours=True)):
            selected = contour & (owner==index) & inside
            rejected |= selected
            if selected.any(): attribution[part['name']]=int(selected.sum())
        for zone,value in counts(rejected,centroids).items(): metrics[zone]['interior_contour']=value
        return dict(view=pose['view'],clip=pose['clip'],frame=pose['frame'],
                    joints=metrics,centroids=centroids,interior_pieces=attribution)


def distribution(rows, height):
    histogram = Counter(rows)
    return dict(samples=len(rows), histogram={str(k):v for k,v in sorted(histogram.items())},
        minimum=min(rows),median=float(np.median(rows)),p95=float(np.percentile(rows,95)),
        maximum=max(rows),maximum_per_100px=max(rows)*100/height)


def compare_thresholds(joints, height, thresholds):
    errors = []
    for zone, metrics in joints.items():
        for metric, value in metrics.items():
            if zone not in thresholds or metric not in thresholds[zone]:
                raise ValueError('No approved calibration for '+zone+'/'+metric)
            limit = thresholds[zone][metric]['maximum_per_100px']
            normalized = value*100/height
            if normalized > limit:
                errors.append(dict(zone=zone,metric=metric,pixels=value,per_100px=normalized,
                    threshold_per_100px=limit,excess_per_100px=normalized-limit,
                    excess_native_px=value-limit*height/100))
    return errors


def collect():
    report = dict(schema=1, status='measuring', normalized_unit='pixels per 100px rest figure height',
        zone_radius_native_px=14, contour_depth_native_px=2,
        height_definition='assembled rest silhouette inclusive vertical bounding-box span',
        zones=ZONE_PAIRS,ownership_aliases=ALIASES,approved={},thresholds={},
        hero=dict(included=False,reason='Protagonist uses its own rig/motion, cape and equipment schema; no humanoid_v2 ownership/joint zones.',
            files={p:digest(PROJECT/p) for p in ('scripts/protagonist_cutout/rig.gd','assets/units/protagonist_cutout/front.json','assets/units/protagonist_cutout/rear.json')}),
        implementation={str(Path(__file__).relative_to(PROJECT)):digest(Path(__file__)),
            'tools/humanoid_cutout/image_gates.py':digest(PROJECT/'tools/humanoid_cutout/image_gates.py')})
    all_rows = {}
    for creature in APPROVED:
        integration = PROJECT/f'assets/units/{creature}_cutout/integration.json'
        case = PROJECT/read_json(integration)['case']
        samples_path=OUTPUT/f'proof/logs/{creature}_samples.json'
        samples = read_json(samples_path)
        errors=evidence_errors(read_json(case/'compiled_motion.json'),samples,bindings(case),.0001)
        if errors: raise ValueError(creature+': '+str(errors))
        creature_report=dict(case=str(case.relative_to(PROJECT)),integration_sha256=digest(integration),
            samples_sha256=digest(samples_path),inputs=samples['inputs'],views={})
        all_rows[creature]=[]
        for view in ('front','rear'):
            gate=CalibrationGate(creature,case,read_json(case/f'layouts/{view}.json'))
            poses=[p for p in samples['samples'] if p['view']==view and p['kind']=='presented']
            rows=[]
            for pose in poses:
                rows.append(gate.frame(pose))
                if len(rows)%PROGRESS_INTERVAL==0: print(f'RR31 CALIBRATION: {creature}/{view} {len(rows)}/{len(poses)}',flush=True)
            all_rows[creature]+=rows
            zones={}
            for zone in gate.contacts:
                zones[zone]={metric:distribution([r['joints'][zone][metric] for r in rows],gate.height) for metric in METRICS}
                for metric,values in zones[zone].items():
                    target=report['thresholds'].setdefault(zone,{})
                    if metric not in target or target[metric]['maximum_per_100px']<values['maximum_per_100px']:
                        witness=next(r for r in rows if r['joints'][zone][metric]==values['maximum'])
                        target[metric]=dict(maximum_per_100px=values['maximum_per_100px'],
                            witness=dict(creature=creature,view=view,clip=witness['clip'],frame=witness['frame'],
                                pixels=values['maximum'],height=gate.height))
            creature_report['views'][view]=dict(frames=len(rows),height=gate.height,rest=gate.rest,zones=zones,
                clips=dict(Counter(r['clip'] for r in rows)),
                contact_centroids_rest=gate.centroids(rest_bones(gate.layout)))
            creature_report['views'][view]['contact_methods']=gate.contact_methods
            print(f'RR31 CALIBRATION: {creature}/{view} complete ({len(rows)} frames; {len(zones)} zones)',flush=True)
        report['approved'][creature]=creature_report
    write_json(OUTPUT/'proof/logs/calibration_frames.json',all_rows)
    report['frame_records_sha256']=digest(OUTPUT/'proof/logs/calibration_frames.json')
    return report


def negatives(report):
    from humanoid_cutout.native_frames import load_frame,frame_digest
    manifest=read_json(ROUND3/'proof/native/frames.json')
    # Mortar is rigid; its native part matrices are sufficient for all three
    # metrics. Do not substitute the new motion's bones for the historical pose.
    indexed={}
    for part in manifest['pieces']:
        indexed.setdefault((part['view'],part['clip'],part['frame']),{})[part['name']]=part
    controls=[]
    for view in ('front','rear'):
        gate=CalibrationGate('slag_mortar',ROUND3,read_json(ROUND3/f'layouts/{view}.json'))
        for clip,frame in (('lob',32),('brace',20),('death',78)):
            row=next(r for r in manifest['frames'] if (r['view'],r['clip'],r['frame'])==(view,clip,frame))
            capture=ROUND3/'proof/native'/row['file']
            if frame_digest(capture)!=row['sha256']:raise ValueError('Changed historical native frame')
            pose=dict(row,parts=indexed[(view,clip,frame)])
            alpha=np.asarray(load_frame(capture).convert('RGBA'))[...,3]>0
            measured=gate.frame(pose,alpha=alpha)
            # Contour is CPU with attribution, not a native contour claim.
            cpu=gate.frame(pose)
            for zone in measured['joints']:
                measured['joints'][zone]['interior_contour']=cpu['joints'][zone]['interior_contour']
            excess=compare_thresholds(measured['joints'],gate.height,report['thresholds'])
            controls.append(dict(view=view,clip=clip,frame=frame,height=gate.height,
                native_sha256=row['sha256'],joints=measured['joints'],excess=excess,
                rejected=bool(excess),centroids=measured['centroids'],
                interior_source='CPU raster of historical native captured Sprite2D matrices',
                metric_margins={zone:{metric:value*100/gate.height-report['thresholds'][zone][metric]['maximum_per_100px']
                    for metric,value in metrics.items()} for zone,metrics in measured['joints'].items()}))
    report['negative_controls']=controls
    report['separated']=all(c['rejected'] for c in controls)
    report['status']='separated' if report['separated'] else 'STOP_overlap'
    report['overlap_frames']=[f"{r['view']}/{r['clip']}{r['frame']}" for r in controls if not r['rejected']]
    report['thresholds_installed']=False
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reuse-approved',action='store_true')
    args=parser.parse_args()
    report=read_json(OUTPUT/'calibration.json') if args.reuse_approved else collect()
    # Save measured distributions even when historical evidence is unavailable.
    write_json(OUTPUT/'calibration.json',report)
    report=negatives(report)
    write_json(OUTPUT/'calibration.json',report)
    frames=sum(v['frames'] for c in report['approved'].values() for v in c['views'].values())
    failed=sum(c['rejected'] for c in report['negative_controls'])
    print(f'RR31 CALIBRATION: {report["status"]} ({frames} approved frames; {failed}/6 torn frames rejected)')
    raise SystemExit(0 if report['separated'] else 2)
