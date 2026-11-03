"""Hash-checked CPU/native triage; unmatched historic poses stay pending.

This does not approve native art or relabel a stale capture. Retained captures
may establish individual pixel witnesses only when pose, source and geometry
match. Fresh capture provenance is otherwise mandatory.
"""
from pathlib import Path
import argparse
import collections
import numpy as np
from PIL import Image
from rr38_case import CASE
from rr38_uncovered import UncoveredSurface, flat_regions, CROP_ZOOM, FLAT_CONTEXT_PX
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame, frame_digest
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.anatomy import load
from maquette_motion.silhouette import components

POSE_EPSILON = .0001


def same_pose(first, second):
    return set(first['bones']) == set(second['bones']) and all(
        np.allclose(row['global'], second['bones'][name]['global'], atol=POSE_EPSILON, rtol=0)
        for name, row in first['bones'].items())


def compose(layers):
    result = np.zeros_like(layers[0][1])
    for part, image, _ in sorted(layers, key=lambda r:r[0]['z_index']):
        mask = image[..., 3] > 0
        result[mask] = image[mask]
    return result


def overlap(first, second):
    return max(first[0], second[0]) < min(first[2], second[2]) and max(first[1], second[1]) < min(first[3], second[3])


def crop(image, box, path):
    x0,y0,x1,y1 = box
    box = (max(0,x0-FLAT_CONTEXT_PX), max(0,y0-FLAT_CONTEXT_PX),
           min(image.shape[1],x1+FLAT_CONTEXT_PX), min(image.shape[0],y1+FLAT_CONTEXT_PX))
    preview = Image.fromarray(image).crop(box)
    path.parent.mkdir(parents=True, exist_ok=True)
    preview.resize((preview.width*CROP_ZOOM,preview.height*CROP_ZOOM),Image.Resampling.NEAREST).save(path)
    return str(path)


class Evidence:
    def __init__(self, case, native, retained=None):
        self.case, self.native = Path(case), Path(native)
        self.manifest = read_json(self.native/'frames.json')
        if not self.manifest.get('native_pixels') or self.manifest.get('size') != [1920,1080] or self.manifest.get('ui_scale') != 1:
            raise ValueError('Triage requires native 1920x1080 / 100% evidence')
        self.current = self.manifest['inputs'] == bindings(self.case)
        if retained is not None:
            self.current |= self.manifest['inputs'] == bindings(Path(retained))
        if not self.current and retained is None:
            raise ValueError('Stale native triage input; explicitly name its retained sampler case')
        self.retained = Path(retained) if retained else self.case
        old = read_json(self.retained/'proof/logs/samples.json')
        if digest(self.retained/'compiled_motion.json') != self.manifest['inputs']['compiled_motion.json']:
            raise ValueError('Retained sampler motion differs from captured motion')
        self.old_poses = {(r['view'],r['clip'],r['frame']):r for r in old['samples'] if r['kind']=='presented'}
        self.inventory = {}
        for field in ('frames','pieces','joint_seams','rest_holes'):
            rows = collections.defaultdict(list)
            for row in self.manifest[field]: rows[row['view'],row['clip'],row['frame']].append(row)
            self.inventory[field] = rows

    def read(self, row):
        path = self.native/row['file']
        if frame_digest(path) != row['sha256']:
            raise ValueError('Changed native triage evidence: '+str(path))
        return np.asarray(load_frame(path).convert('RGBA'))

    def matching(self, pose, model, treated_case):
        key = pose['view'],pose['clip'],pose['frame']
        if not same_pose(pose,self.old_poses[key]): return False, 'captured pose predates feedback motion'
        old_layout = read_json(self.retained/f'layouts/{pose["view"]}.json')
        old_meshes = {m['name']:m for m in old_layout['joint_meshes']}
        for mesh in model.layout['joint_meshes']:
            for name in ('vertices','uvs','triangles','weights'):
                if mesh[name] != old_meshes[mesh['name']][name]: return False, 'captured mesh differs'
        for part in model.layout['parts']:
            path = part['file']
            if digest(treated_case/path) != self.manifest['inputs'].get(path): return False, 'captured treated paint differs'
        for part in self.inventory['pieces'][key]:
            if not np.allclose(part['transform'],pose['parts'][part['name']]['transform'],atol=POSE_EPSILON,rtol=0):
                return False, 'captured node transform differs'
        return True, 'same sampled bones, mesh geometry and exact treated source'

    def frame(self, pose, model):
        key = pose['view'],pose['clip'],pose['frame']
        full = self.inventory['frames'][key]
        if len(full)!=1: raise ValueError('Incomplete or duplicate native frame')
        image = self.read(full[0]);parts={p['name']:p for p in model.layout['parts']}
        rows = self.inventory['pieces'][key]
        if len(rows)!=len(parts) or {r['name'] for r in rows}!=set(parts): raise ValueError('Incomplete native pieces')
        # Feedback 1's explicit depths preserve the measured original GPU tree order.
        layers = [(parts[row['name']],self.read(row),None) for row in rows]
        if not np.array_equal(compose(layers),image): raise ValueError('Native full frame differs from isolated composition')
        def masks(field): return [self.read(r)[...,3]>0 for r in self.inventory[field][key]]
        seams = masks('joint_seams')
        seam = np.logical_or.reduce(seams) if seams else np.zeros(image.shape[:2],bool)
        owners = posed_owners(layers,model.layout['parts'],pose['bones'],192,load(model.case)['ownership'])
        pockets = joint_holes(image[...,3]>0,seam,owners,masks('rest_holes'),pocket_details=True)
        return image,layers,pockets,full[0]


def shard(case, treated_case, native, retained, view, clip, start, count, output):
    data=read_json(case/'proof/logs/cpu_sweep.json')
    samples=read_json(case/'proof/logs/samples.json')
    poses={(r['view'],r['clip'],r['frame']):r for r in samples['samples'] if r['kind']=='presented'}
    frames={r['frame']:(r,s) for s in data['shards'] if s['view']==view and s['clip']==clip for r in s['frames']}
    treated_data=read_json(treated_case/'proof/logs/cpu_sweep.json')
    treated_flags={r['frame']:r['flat_regions'] for s in treated_data['shards'] if s['view']==view and s['clip']==clip for r in s['frames']}
    evidence=Evidence(case,native,retained)
    model=CpuPose(case,read_json(case/f'layouts/{view}.json'),triangle_batch_size=128)
    treated=CpuPose(treated_case,read_json(treated_case/f'layouts/{view}.json'),triangle_batch_size=128)
    gate=UncoveredSurface(case,model,include_intentionally_empty=True)
    native_gate=UncoveredSurface(treated_case,treated)
    records=[]
    with for_case(case):
        for index in range(start,start+count):
            cpu,parent=frames[index];pose=poses[view,clip,index]
            errors=[e for e in parent['errors'] if e.startswith(f'{view}/{clip}/{index}:')]
            flags=cpu['flat_regions']
            if not errors and not flags: continue
            matching,reason=evidence.matching(pose,model,treated_case)
            common={'view':view,'clip':clip,'frame':index,'pose_equivalent':matching,'reason':reason}
            if not matching:
                for error in errors:
                    accepted='uncovered_missing_pixels=' in error and not cpu['metrics']['uncovered_foreign_texels']
                    if accepted:
                        cpu_layers,maps=model.layers(pose)
                        strict=UncoveredSurface(case,model)
                        accepted=not strict.measure(pose,cpu_layers,maps)['uncovered_missing_pixels']
                    row=dict(common,kind='gate',finding=error,classification='c_accepted_rule' if accepted else 'pending_native')
                    if accepted:row['accepted_rule']='Director feedback 1 intentionally empty rear surfaces; corrected required domains leave zero missing pixels. No native claim for this changed pose.'
                    records.append(row)
                records.extend(dict(common,kind='flat',finding=r,classification='pending_native') for r in flags)
                continue
            actual,layers,pockets,frame=evidence.frame(pose,model)
            native_metrics=native_gate.measure(pose,layers)
            native_flat=flat_regions(native_gate,pose,layers)
            common.update(native_frame=frame['file'],native_frame_sha256=frame['sha256'])
            cpu_layers,maps=model.layers(pose);gate.measure(pose,cpu_layers,maps)
            missing=gate.last_masks.get('missing',np.zeros(actual.shape[:2],bool))
            for error in errors:
                row=dict(common,kind='gate',finding=error)
                if 'joint tears=' in error:
                    row.update(classification='a_native' if pockets else 'b_cpu_only',native_joint_pockets=pockets)
                    boxes=[r['bbox'] for r in pockets] or [r['bbox'] for r in cpu['joint_tears']]
                elif 'uncovered_missing_pixels=' in error:
                    y,x=np.nonzero(missing)
                    witnesses=[{'xy':[int(a),int(b)],'native_rgba':actual[b,a].tolist()} for a,b in zip(x,y)]
                    empty=load(case).get('intentionally_empty',{}).get(view,{})
                    required_by={}
                    for logical,domain in gate.domains.items():
                        name=next(n for n in ('covered_'+logical,'hidden_'+logical,logical) if n in gate.parts)
                        hits=gate.transport(name,domain,pose)&missing
                        if hits.any():required_by[logical]=int(hits.sum())
                    accepted=bool(required_by) and set(required_by)<=set(empty)
                    row.update(classification='c_accepted_rule' if accepted else ('a_native' if native_metrics['uncovered_missing_pixels'] else 'b_cpu_only'),
                        native_missing_pixels=native_metrics['uncovered_missing_pixels'],cpu_missing_witnesses=witnesses)
                    row['required_by']=required_by
                    if accepted:row['accepted_rule']='Director feedback 1: rear near arm/glove and front-only tabard remain unpainted; maquette solos do not invent their hidden paint.'
                    boxes=[[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]] if len(x) else []
                elif 'uncovered_tiny_components=' in error:
                    labels,groups=components(actual[...,3]>0,8)
                    tiny=[(n,size) for n,size in groups if size<=3]
                    row.update(classification='a_native' if native_metrics['uncovered_tiny_components'] else 'b_cpu_only',native_tiny_components=len(tiny))
                    boxes=[]
                    for n,_ in tiny:
                        y,x=np.nonzero(labels==n);boxes.append([int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)])
                else:
                    raise ValueError('Unclassified CPU error: '+error)
                row['crops']=[crop(actual,box,output/f'{view}_{clip}_{index:04d}_gate_{len(records)}_{i}.png') for i,box in enumerate(boxes)]
                records.append(row)
            for flag in flags:
                present=[r for r in native_flat if r['piece']==flag['piece'] and overlap(r['bbox'],flag['bbox'])]
                row=dict(common,kind='flat',finding=flag,classification='a_native' if present else 'b_cpu_only',native_regions=present)
                treated_match=[r for r in treated_flags[index] if r['piece']==flag['piece'] and overlap(r['bbox'],flag['bbox'])]
                if not present and not treated_match:
                    row['classification']='c_accepted_rule'
                    row['accepted_rule']='Production is density-treated paint; the exact treated CPU/native regions do not have this raw-source variance flag.'
                if row['classification']=='b_cpu_only':
                    treated_layers,_=treated.layers(pose)
                    expected=compose(treated_layers)
                    x0,y0,x1,y1=flag['bbox']
                    changed=np.any(actual[y0:y1,x0:x1]!=expected[y0:y1,x0:x1],axis=-1)
                    row['native_pixel_witnesses']=[{'xy':[int(x+x0),int(y+y0)],
                        'native_rgba':actual[y+y0,x+x0].tolist(),'cpu_rgba':expected[y+y0,x+x0].tolist()}
                        for y,x in np.argwhere(changed)]
                row['crop']=crop(actual,flag['bbox'],output/f'{view}_{clip}_{index:04d}_flat_{len(records)}.png')
                records.append(row)
    result={'native_acceptance':False,'source_cpu_log_sha256':digest(case/'proof/logs/cpu_sweep.json'),
        'native_manifest_sha256':digest(native/'frames.json'),'current_capture':evidence.current,'records':records}
    write_json(output/'triage.json',result)
    counts=collections.Counter((r['kind']+'/'+r['classification']) for r in records)
    print(f'RR38 TRIAGE {view}/{clip}/{start}: '+str(dict(counts)),flush=True)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('case','treated-case','native','retained','output'):p.add_argument('--'+name,type=Path,required=name!='retained')
    p.add_argument('--view',choices=['front','rear'],required=True);p.add_argument('--clip',required=True)
    p.add_argument('--start',type=int,required=True);p.add_argument('--count',type=int,default=4)
    a=p.parse_args()
    if not 1<=a.count<=4:p.error('Use triage shards of at most four frames')
    shard(a.case,a.treated_case,a.native,a.retained,a.view,a.clip,a.start,a.count,a.output)
