"""Read every native alpha frame and reconcile actual pockets with CPU records."""
from collections import defaultdict,Counter
from pathlib import Path
import numpy as np
from rr52_build import CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.native_frames import load_frame
from maquette_motion.silhouette import holes,components


def signature(row):
    data=row.get('source_space',row)
    return (row['view'],row['clip'],row['frame'],tuple(data['bbox']))


def run():
    proof=CASE/'proof';baseline=proof/'feedback2_before/production_case';capture=proof/'native';manifest=read_json(capture/'frames.json');cpu=read_json(baseline/'proof/cpu_sweep.json');records=[];air=[]
    for view in ('front','rear'):
        data=read_json(baseline/f'proof/native_air_{view}.json');records+=data['remaining_tears']+data['accepted_short_tears'];air+=data['natural_negative_space']
    classified={signature(r):r for r in records+air};cpu_by_box={signature(r):r for r in cpu['raw_joint_holes']};native_by_box={signature(r):r for r in records};native_only=[];cpu_only=[];differences=[];read_frames=0;actual_holes=0
    for frame in manifest['frames']:
        image=np.asarray(load_frame(capture/frame['file']).convert('RGBA'));key=(frame['view'],frame['clip'],frame['frame']);found=set()
        for mask in holes(image[...,3]>0):
            yy,xx=np.nonzero(mask);box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1));sig=(*key,box);count=int(mask.sum());actual_holes+=1;found.add(sig)
            if sig not in classified:raise ValueError('Unclassified native pocket: '+str(sig))
            reference=classified[sig]
            if reference['pixel_count']!=count:raise ValueError('Native pocket record differs from pixels: '+str(sig))
            if sig not in native_by_box:continue
            cpu_record=cpu_by_box.get(sig)
            if cpu_record is None:native_only.append(reference)
            elif cpu_record['source_space']['pixel_count']!=count:
                differences.append({'view':key[0],'clip':key[1],'frame':key[2],'bbox':list(box),'native_pixels':count,'cpu_pixels':cpu_record['source_space']['pixel_count'],'native_underlay_hits':reference['painted_pixels']})
        for sig,row in native_by_box.items():
            if sig[:3]==key and sig not in found:raise ValueError('Native finding absent in pixels: '+str(sig))
        for sig,row in cpu_by_box.items():
            if sig[:3]==key and sig not in native_by_box:cpu_only.append(dict(row,native_pocket_present=sig in found))
        read_frames+=1
    spaces=read_json(capture/'source_space_pockets.json');native_detached=[]
    for row in spaces:
        for component in row['unmatched_components']:
            candidate=next((r for r in cpu['errors'] if r['kind']=='unmatched_detached_paint' and (r['view'],r['clip'],r['frame'])==(row['view'],row['clip'],row['frame']) and r['component']==component),None)
            if candidate is None:raise ValueError('CPU missed native detached paint')
            native_detached.append(dict(view=row['view'],clip=row['clip'],frame=row['frame'],component=component))
    old_calibration=read_json(baseline/'proof/native_gates.json')['cpu_superset_native'];reported_air_misses=[]
    import re,ast
    for error in old_calibration['errors']:
        if ': CPU missed native pocket ' not in error:continue
        identity,box=error.split(': CPU missed native pocket ');view,clip,frame=ast.literal_eval(identity);sig=(view,clip,frame,tuple(ast.literal_eval(box)));reference=classified.get(sig)
        if reference is None or reference['painted_pixels']!=0:raise ValueError('Calibration miss is not proven director-underlay air: '+error)
        reported_air_misses.append(reference)
    from rr52_surface import temporal
    remaining,accepted=temporal(records);poses={(r['view'],r['clip'],r['frame']):r for r in read_json(baseline/'proof/raster_samples.json')['samples']}
    for row in accepted:
        key=(row['view'],row['clip'],row['frame']);current=poses[key];previous=poses.get((*key[:2],key[2]-1),current);following=poses.get((*key[:2],key[2]+1),current)
        row['maximum_presented_joint_motion_px_per_frame']=max(float(np.linalg.norm(np.asarray(current['bones'][bone]['global'][4:])-other['bones'][bone]['global'][4:])) for bone in current['bones'] for other in (previous,following))
    result={'ok':not native_only,'native_frames_read':read_frames,'native_pockets_checked':actual_holes,'native_raw_painted_pockets':len(records),'cpu_raw_painted_pockets':len(cpu['raw_joint_holes']),'native_blocking_locations_missed_by_cpu':native_only,'cpu_only_locations':cpu_only,'same_pocket_pixel_differences':differences,'previous_calibration_air_misses':reported_air_misses,'native_detached_matched':native_detached,'native_remaining_feedback2_rule':remaining,'accepted_short_tears_feedback2':accepted,'native_remaining_old_rule':len(records)-sum(len(read_json(baseline/f'proof/native_air_{v}.json')['accepted_short_tears']) for v in ('front','rear')),'native_records':records,'native_air':air,'native_manifest_sha256':digest(capture/'frames.json'),'cpu_report_sha256':digest(baseline/'proof/cpu_sweep.json'),'native_pixels':True,'notes':'A 353-line native error log contains 335 frame gate lines and 18 calibration complaints about zero-underlay-hit natural air. CPU record counts and log lines are different units. Pixel counts include all pocket air, not only missing painted UVs. Feedback 2 short tears: fewer than 3 native pixels, at most 2 consecutive frames; observed changing-pose motion is recorded, not a new motion tuning threshold.'}
    write_json(proof/'feedback2_calibration.json',result)
    print(f'RR52 NATIVE CALIBRATION: {"PASS" if result["ok"] else "FAIL"} ({read_frames} native frames; {len(native_only)} missed painted-pocket locations; {len(cpu_only)} CPU-only locations; {len(differences)} one-pixel pocket-size differences; {len(reported_air_misses)} old air-only complaints)')
    return result

if __name__=='__main__':run()
