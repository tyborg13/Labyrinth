"""Replay the new cloth ruling over hash-verified, canonical native diagnostics.

All original physical failures survive except the director's exact cloth rule.
Changed cuts are predictions from the new CPU sweep, never substituted pixels.
"""
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from build import CASE
from archive import verify
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.native_frames import load_frame
from humanoid_cutout.source_space import DetachedSource
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import matrix
from humanoid_cutout.cpu_pose import mapped,mesh_map
from maquette_motion import pixels
from maquette_motion.silhouette import components
from cloth_rags import accepted,POLICY_NAME
from cpu_native_superset import report as component_report,pocket_report


def clip_job(args):
    base,capture,clip,frames,pieces,spaces,semantic=args
    rows={(r['view'],r['frame']):r for r in read_json(base/'proof/raster_samples.json')['samples'] if r['clip']==clip}
    layouts={v:read_json(base/f'layouts/{v}.json') for v in ('front','rear')};result=[];cleared=[];rejected=[]
    from surface_policy import model
    with for_case(base):
        models={v:model(base,v) for v in layouts}
        for frame in frames:
            view=frame['view'];key=(view,frame['frame']);layout=layouts[view];pose=rows[key];layers=[]
            for record in pieces[key]:layers.append((record,np.asarray(load_frame(capture/record['file']).convert('RGBA')),None))
            masks,records=accepted(layout,layers,clip)
            # Physical armour/weapon pixels that the source audit reassigns may
            # not use a cloth label left over in the archived cut.
            model_=models[view];uv_cache={};valid=[];valid_records=[]
            owner=np.zeros(layers[0][1].shape[:2],np.int16)
            for i,(p,image,_) in enumerate(sorted(layers,key=lambda r:r[0]['z_index'])):owner[image[...,3]>0]=i
            ordered=sorted(layers,key=lambda r:r[0]['z_index'])
            for mask,record in zip(masks,records):
                good=True
                for i in np.unique(owner[mask]):
                    name=ordered[int(i)][0]['name'];part=next(p for p in layout['parts'] if p['name']==name)
                    if name not in uv_cache:
                        source=model_.image(part['file']);yy,xx=np.indices(source.shape[:2]);encoded=np.zeros_like(source);encoded[...,0]=xx+part['offset'][0];encoded[...,1]=yy+part['offset'][1];encoded[...,3]=source[...,3]
                        if name in model_.meshes:uv_cache[name]=mapped(encoded,mesh_map(layout,pose,model_.meshes[name],native_skin=True,triangle_batch_size=128))
                        else:uv_cache[name]=pixels.render(encoded,matrix(pose['parts'][name]['transform']))
                    uv=uv_cache[name][mask&(owner==i)];good &= bool(np.all(uv[:,3]>0) and np.all(semantic[view][uv[:,1],uv[:,0]]))
                if good:valid.append(mask);valid_records.append(record)
                else:rejected.append(dict(view=view,clip=clip,frame=frame['frame'],**record,reason='source audit assigns physical pixels to non-cloth'))
            old=spaces[key];remaining=[]
            for component in old['unmatched_components']:
                xy=np.asarray(component['pixels']);matched=any(int(m.sum())==component['pixel_count'] and np.all(m[xy[:,1],xy[:,0]]) for m in valid)
                if not matched:remaining.append(component)
            occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers]);count=len(components(occupied,8)[1])
            baseline=len(components(np.asarray(load_frame(base/layout['rest_source']).convert('RGBA'))[...,3]>0,8)[1])
            released=len(old.get('released_components',[]));floating=count>baseline+released+len(valid)
            result.append(dict(old,unmatched_components=remaining,director_cloth_components=valid_records,floating=floating,component_count=count))
            cleared.extend(dict(view=view,clip=clip,frame=frame['frame'],**r) for r in valid_records)
    return result,cleared,rejected


def run():
    root=CASE/'proof/feedback2_before';capture=CASE/'proof/native';base,manifest=verify(root,capture)
    gate=read_json(base/'proof/native_gates.json');cpu=read_json(base/'proof/cpu_sweep.json')
    semantic={}
    from maquette_motion.features import source_pixels
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');mask=np.zeros((255,255),bool)
        for part in sorted(layout['parts'],key=lambda p:p['z_index']):
            alpha=source_pixels(CASE,part)[...,3]>0;mask[alpha]=part['logical_part'] in ('cloak','tabard')
        semantic[view]=mask
    spaces={(r['view'],r['clip'],r['frame']):r for r in gate['native_spaces']};jobs=[]
    for clip in read_json(base/'compiled_motion.json')['clips']:
        frames=[r for r in manifest['frames'] if r['clip']==clip];ps={};ss={}
        for r in manifest['pieces']:
            if r['clip']==clip:ps.setdefault((r['view'],r['frame']),[]).append(r)
        for r in frames:ss[r['view'],r['frame']]=spaces[r['view'],clip,r['frame']]
        jobs.append((base,capture,clip,frames,ps,ss,semantic))
    with ProcessPoolExecutor(max_workers=4) as pool:values=list(pool.map(clip_job,jobs))
    native_spaces=[r for v in values for r in v[0]];cleared=[r for v in values for r in v[1]];rejected=[r for v in values for r in v[2]]
    errors=[e for e in gate['errors'] if 'floating pieces:' not in e and 'detached opaque component' not in e and not e.startswith('CPU superset:')]
    for row in native_spaces:
        key=(row['view'],row['clip'],row['frame'])
        if row['floating']:errors.append(str(key)+': floating pieces: '+str(row['component_count'])+' components remain after director cloth')
        if row['unmatched_components']:errors.append(str(key)+': detached opaque component outside director cloth policy')
    holes=[dict(view=r['view'],clip=r['clip'],frame=r['frame'],pockets=r['failures']) for r in native_spaces if r['failures']]
    pockets=pocket_report(cpu,holes)
    # The archive CPU used the stricter old rule. Its original counter failures
    # already catch each surviving native floating location.
    compare_errors=[e for e in errors if 'floating pieces:' not in e]+[e for e in gate['errors'] if 'floating pieces:' in e and any(str((r['view'],r['clip'],r['frame'])) in e and r['floating'] for r in native_spaces)]
    # R1 did not record slab metrics in CPU output. Replay those exact old
    # poses with the complete CPU oracle; never infer them from native pixels.
    import ast
    from humanoid_cutout.native_exceptions import METRIC_RULES
    metric_keys=set()
    for e in errors:
        if any(e.endswith(': '+rule) for key,rule in METRIC_RULES.items() if key!='stray_components'):
            metric_keys.add(tuple(ast.literal_eval(e.rsplit(': ',1)[0])))
    metric_replay={'errors':[]}
    if metric_keys:
        from cpu_sweep import measure
        samples=read_json(base/'proof/raster_samples.json');samples['samples']=[r for r in samples['samples'] if (r['view'],r['clip'],r['frame']) in metric_keys]
        metric_replay=measure(samples,case=base)
    extended=dict(cpu,errors=cpu['errors']+[r for r in metric_replay['errors'] if r['kind']=='paint_metric'])
    comp=component_report(base,capture,manifest,extended,native_spaces,compare_errors)
    if not pockets['ok'] or not comp['ok']:errors.append('CPU superset missed a native blocking location')
    report={'ok':not errors,'errors':errors,'historical_native':True,'current_native_fresh':False,
            'native_manifest_sha256':digest(capture/'frames.json'),'policy_sha256':digest(CASE/'cloth_rags.py'),'policy':POLICY_NAME,'frames':len(manifest['frames']),
            'native_spaces':native_spaces,'cloth_cleared':cleared,'noncloth_semantic_rejections':rejected,
            'cpu_superset':{'ok':pockets['ok'] and comp['ok'],'pockets':pockets,'components':comp},
            'legacy_cpu_metric_replay':metric_replay,'before_error_lines':len(gate['errors']),'after_error_lines':len(errors),'stale_current_poses':'all 976 after source cuts/strand and coverage changes'}
    write_json(CASE/'proof/feedback2/offline_native.json',report)
    print('RR56 OFFLINE NATIVE: %s (%d frames; %d cloth components cleared; %d error lines; CPU superset %s)'%('PASS' if report['ok'] else 'FINDINGS',report['frames'],len(cleared),len(errors),'PASS' if report['cpu_superset']['ok'] else 'FAIL'))
    return report

if __name__=='__main__':run()
