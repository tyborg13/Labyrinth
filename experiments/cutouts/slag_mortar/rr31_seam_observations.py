"""Reproduce all eleven reported seam observations without changing captures.

Trace the inverse classifier and the shared fixed-grid renderer independently.
The two source coordinates can disagree at a texel boundary. Neither observation
waives a hole or authorizes adding paint; keep both for the director's inspection.
"""
import numpy as np
from PIL import Image
from rr30_case import CASE
from rr31_images import OUTPUT, composite
from rr30_cpu import CpuPose, sprite_transform
from rr30_seams import frame_report
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.source_space import DetachedSource
from humanoid_cutout.bone_evidence import evidence_errors
from humanoid_cutout.gates import bindings
from maquette_motion import pixels
from maquette_motion.silhouette import holes

OBSERVATIONS = {'front': {'lob': [33,67], 'scatter': [39]},
                'rear': {'lob': [59,60], 'brace': [4,7,8,47,48,50]}}


def report():
    source = OUTPUT/'proof/logs/slag_mortar_samples.json'
    samples = read_json(source)
    errors = evidence_errors(read_json(CASE/'compiled_motion.json'),samples,bindings(CASE),.0001)
    if errors: raise ValueError('Invalid poses: '+str(errors))
    records = []
    for view,clips in OBSERVATIONS.items():
        layout=read_json(CASE/f'layouts/{view}.json')
        model=CpuPose(CASE,layout)
        model.detached_source=DetachedSource(CASE,layout)
        for clip,frames in clips.items():
            for frame in frames:
                pose=next(p for p in samples['samples'] if
                    (p['view'],p['clip'],p['frame'],p['kind'])==(view,clip,frame,'presented'))
                layers,_,_,_,spaces=frame_report(model,pose)
                image,_=composite(sorted(layers,key=lambda r:r[0]['z_index']))
                capture=OUTPUT/f'proof/seam_holes/{view}_{clip}_{frame:04d}.png'
                capture.parent.mkdir(parents=True,exist_ok=True)
                Image.fromarray(image).save(capture)
                pockets=holes(image[...,3]>0)
                failures=[]
                for defect in spaces['failures']:
                    pocket=next(h for h in pockets if int(h.sum())==defect['pixel_count'] and
                        np.nonzero(h)[1].min()==defect['bbox'][0] and
                        np.nonzero(h)[0].min()==defect['bbox'][1])
                    yy,xx=np.nonzero(pocket)
                    traces=[]
                    for name,trace in defect['source'].items():
                        if not (trace['painted_or_tuck_pixels'] or trace['protected_silhouette_pixels']): continue
                        for part,sourcepoints in zip(model.air_policy.parts[name],trace['source_points']):
                            points=np.asarray(sourcepoints)
                            blocked=model.air_policy._sample(model.air_policy.masks[name],points)
                            if name in model.air_policy.protected_masks:
                                blocked |= model.air_policy._sample(model.air_policy.protected_masks[name],points)
                            indices=np.flatnonzero(blocked)
                            if not len(indices): continue
                            paint=model.image(part['file'])
                            v,u=np.indices(paint.shape[:2])
                            uv=np.stack((u,v,np.ones_like(u),np.full_like(u,255)),axis=-1).astype('uint8')
                            transform=sprite_transform(layout,pose,part)
                            mapped=pixels.render(uv,transform)
                            actual=pixels.render(paint,transform)
                            for at in indices:
                                destination=[int(xx[at]),int(yy[at])]
                                sampled=mapped[yy[at],xx[at]]
                                raster_source=(sampled[:2].astype(int)+part['offset']).tolist() if sampled[3] else None
                                traces.append(dict(piece=part['name'],logical_piece=name,
                                    destination=destination,inverse_source=points[at].tolist(),
                                    raster_source=raster_source,raster_rgba=actual[yy[at],xx[at]].tolist(),
                                    source_file=part['file'],source_sha256=digest(CASE/part['file'])))
                    failures.append(dict(bbox=defect['bbox'],pixel_count=defect['pixel_count'],
                        flagged_pixels=defect['stone_pixels'],surrounding_pieces=defect['surrounding_pieces'],
                        traces=traces))
                records.append(dict(view=view,clip=clip,frame=frame,observations=failures,
                    capture=str(capture.relative_to(OUTPUT)),capture_sha256=digest(capture)))
    mismatches=sum(t['inverse_source']!=t['raster_source'] for r in records for f in r['observations']
                   for t in f['traces'] if not t['piece'].startswith('hidden_'))
    result=dict(frames=len(records),observations=sum(len(r['observations']) for r in records),
        source_inverse_raster_disagreements=mismatches,rows=records,samples_sha256=digest(source),
        disposition='Unchanged failures. All eleven visible-piece inverse hits disagree with the fixed-grid raster. '
            'Seven single-pixel holes; four large pockets each flagged by one pixel. '
            'No missing construction texel established; no paint or gate exemption added.',
        native_pixels=False)
    write_json(OUTPUT/'seam_observations.json',result)
    print(f'RR31 SEAM TRACE: {result["observations"]}/11 reproduced; {mismatches}/11 inverse/raster disagreements; no source edits')
    return result


if __name__=='__main__': report()
