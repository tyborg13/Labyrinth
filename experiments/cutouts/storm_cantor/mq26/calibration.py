"""Read the director's real pixels and audit every CPU pocket/component location.

Historical input bytes are frozen beside the capture before a fix. This does
not authorize stale native frames as proof of the repaired rig.
"""
import argparse
from collections import Counter
from pathlib import Path
import numpy as np
from PIL import Image
from build import CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.native_frames import load_frame
from maquette_motion.silhouette import holes,components
from surface_policy import box


def contains(a,b):
    return a[0]<=b[0] and a[1]<=b[1] and a[2]>=b[2] and a[3]>=b[3]


def run(baseline,capture,output):
    cpu=read_json(baseline/'proof/cpu_sweep.json');manifest=read_json(capture/'frames.json')
    frozen=read_json(baseline.parent/'capture_binding.json')
    if frozen['manifest_sha256']!=digest(capture/'frames.json') or frozen['inputs']!=manifest['inputs']:
        raise ValueError('Changed director capture manifest')
    for name,expected in frozen['inputs'].items():
        if digest(baseline.parent/'bound'/name.replace(':','/'))!=expected:raise ValueError('Changed frozen source: '+name)
    index={(r['view'],r['clip'],r['frame']):r for r in cpu['diagnostics']};errors={}
    for row in cpu['errors']:errors.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    misses=[];differences=[];records=[];total_pockets=0;total_detached=0;certified_sampling=[]
    if cpu['inputs']!=frozen['inputs']:raise ValueError('CPU and native captured different inputs')
    native_piece={(r['view'],r['clip'],r['frame'],r['name']):r for r in manifest['pieces']}
    poses={(r['view'],r['clip'],r['frame']):r for r in read_json(baseline/'proof/raster_samples.json')['samples']}
    layouts={v:read_json(baseline/f'layouts/{v}.json') for v in ('front','rear')}

    def rigid_sampling_match(key,actual,candidates):
        from humanoid_cutout.canvas import for_case
        from humanoid_cutout.gates import matrix
        from maquette_motion import pixels
        for candidate in candidates:
            name=candidate.get('logical_part')
            part=next((p for p in layouts[key[0]]['parts'] if p['name']==name),None)
            if part is None or name in {m['name'] for m in layouts[key[0]]['joint_meshes']}:continue
            record=native_piece.get((*key,name))
            if record is None:continue
            with for_case(baseline):
                source=np.asarray(Image.open(baseline/part['file']).convert('RGBA'))
                expected=pixels.render(source,matrix(poses[key]['parts'][name]['transform']),with_ties=True)
                native=np.asarray(load_frame(capture/record['file']).convert('RGBA'))
                if pixels.native_frame_matches(native,expected.default,expected):
                    certified_sampling.append(dict(view=key[0],clip=key[1],frame=key[2],part=name,bbox=actual['bbox'],native_pixels=actual['pixel_count'],cpu_pixels=candidate['component']['pixel_count'],rule='Exact rigid-source nearest-UV tie candidates; CPU already rejects this same component location.'))
                    return True
        return False
    for frame in manifest['frames']:
        key=(frame['view'],frame['clip'],frame['frame']);image=np.asarray(load_frame(capture/frame['file']).convert('RGBA'));alpha=image[...,3]>0
        actual=[]
        for mask in holes(alpha):
            record={'bbox':box(mask),'pixel_count':int(mask.sum())};actual.append(record);total_pockets+=1
            found=[r for r in index[key]['holes'] if contains(r['bbox'],record['bbox'])]
            if not any(r['pixel_count']>=record['pixel_count'] for r in found):misses.append(dict(view=key[0],clip=key[1],frame=key[2],kind='pocket',**record))
            if found and found[0]!=record:differences.append(dict(view=key[0],clip=key[1],frame=key[2],native=record,cpu=found))
        labels,groups=components(alpha,8);detached=[]
        for label,size in groups[1:]:
            mask=labels==label;record={'bbox':box(mask),'pixel_count':int(size)};detached.append(record);total_detached+=1
            found=[e['component'] for e in errors[key] if e['kind']=='unmatched_detached_paint' and contains(e['component']['bbox'],record['bbox']) and e['component']['pixel_count']>=size]
            # A native-supplied independent rigid rest speck or valid release
            # is classified by the full native gate below, not guessed here.
            if not found:misses.append(dict(view=key[0],clip=key[1],frame=key[2],kind='raw_component',**record))
        records.append(dict(view=key[0],clip=key[1],frame=key[2],pockets=actual,detached=detached))
    gate_path=baseline/'proof/native_gates.json';gate=read_json(gate_path) if gate_path.exists() else None
    blocking_misses=[];native_counts=Counter()
    if gate:
        for row in gate['native_spaces']:
            key=(row['view'],row['clip'],row['frame'])
            for kind,field in [('joint_hole','failures'),('unmatched_detached_paint','unmatched_components')]:
                for actual in row.get(field,[]):
                    native_counts[kind]+=1
                    found=[]
                    for e in errors[key]:
                        if e['kind']!=kind:continue
                        candidate=e['source_space'] if kind=='joint_hole' else e['component']
                        if contains(candidate['bbox'],actual['bbox']) and candidate['pixel_count']>=actual['pixel_count']:found.append(e)
                    if not found and kind=='unmatched_detached_paint':
                        same=[e for e in errors[key] if e['kind']==kind and e['component']['bbox']==actual['bbox']]
                        if rigid_sampling_match(key,actual,same):found=same
                    if not found:blocking_misses.append(dict(view=key[0],clip=key[1],frame=key[2],kind=kind,actual=actual))
        for message in gate['errors']:
            if 'floating pieces:' in message or 'released held item ' in message:
                import ast
                native_counts['held_release']+=1
                identity,detail=message.split(': ',1);key=tuple(ast.literal_eval(identity))
                if not any(e['kind']=='held_release' and e['message']==detail for e in errors.get(key,[])):blocking_misses.append({'kind':'held_release','view':key[0],'clip':key[1],'frame':key[2],'message':detail})
    from cpu_native_superset import report as compare_components
    component_check=compare_components(baseline,capture,manifest,cpu,gate['native_spaces'],gate['errors']) if gate else {'ok':False}
    result={'ok':gate is not None and not blocking_misses and component_check['ok'],'component_check':component_check,'native_pixels':True,'diagnostic_historical_capture':True,
            'native_manifest_sha256':digest(capture/'frames.json'),'native_frames_read':len(records),
            'cpu_before_counts':dict(Counter(e['kind'] for e in cpu['errors'])),'native_before_counts':dict(native_counts),
            'native_pockets_checked':total_pockets,'native_raw_components_checked':total_detached,
            'raw_raster_misses':misses,'certified_sampling_differences':certified_sampling,'pocket_size_differences':differences,'blocking_locations_missed':blocking_misses,
            'frames':records,'current_rig_native_proof':'STALE after feedback 1 cut/motion/underlay changes'}
    write_json(output,result)
    print('RR56 NATIVE CALIBRATION: %s (%d frames; %d pockets; %d components; %d missed blocking locations; %d raw raster differences)'%('PASS' if result['ok'] else 'FAIL',len(records),total_pockets,total_detached,len(blocking_misses),len(misses)))
    return result

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path,default=CASE/'proof/feedback1_before/production_case');p.add_argument('--native',type=Path,default=CASE/'proof/native');p.add_argument('--output',type=Path,default=CASE/'proof/feedback1_calibration.json');a=p.parse_args();r=run(a.baseline,a.native,a.output);raise SystemExit(0 if r['ok'] else 1)
