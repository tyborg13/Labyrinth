"""Conservative room-fit record from final source paint and sampled transforms.

The native owner probe still verifies this envelope. No art scale, pose or
framing margin is selected here: the existing actor framing margin stays 8px.
"""
import re
import numpy as np
from rr37_case import CASE, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.bone_evidence import read_report
from maquette_motion import pixels

# Director-supplied painted soles; mirrors are included in the fixed envelope.
LANDMARKS=PROJECT/'spec/art_identity/jobs/frostglass_lancer/mq14_landmarks_pair.json'


def measure(write_profile=False):
    samples=read_report(CASE);landmarks=read_json(LANDMARKS);result={}
    with for_case(CASE):
        for view,points in landmarks.items():
            anchor=np.mean(list(points.values()),axis=0)
            layout=read_json(CASE/f'layouts/{view}.json');cpu=CpuPose(CASE,layout)
            low=np.array([np.inf,np.inf]);high=-low.copy();edge_pixels=0
            for row in samples['samples']:
                if row['view']!=view or row['kind']!='presented':continue
                layers,_=cpu.layers(row);alpha=np.logical_or.reduce([image[...,3]>0 for _,image,_ in layers])
                edge_pixels+=int(alpha[0].sum()+alpha[-1].sum()+alpha[:,0].sum()+alpha[:,-1].sum())
                y,x=np.nonzero(alpha)
                root=np.array(row['bones']['root']['global'][4:])-layout['joints']['root']['position'] if row['clip']=='move' else np.zeros(2)
                low=np.minimum(low,np.array([x.min(),y.min()])-pixels.PROOF_DEFAULTS['source_offset']-anchor-root)
                high=np.maximum(high,np.array([x.max()+1,y.max()+1])-pixels.PROOF_DEFAULTS['source_offset']-anchor-root)
            result[view]={'low':low.tolist(),'high':high.tolist(),'canvas_edge_pixels':edge_pixels}
    extent=int(np.ceil(max(abs(x) for v in result.values() for x in (v['low'][0],v['high'][0]))))
    top=int(np.floor(min(v['low'][1] for v in result.values())));bottom=int(np.ceil(max(v['high'][1] for v in result.values())))
    rect=[-extent,top,extent*2,bottom-top]
    if any(v['canvas_edge_pixels'] for v in result.values()): raise ValueError('Source paint reaches action-canvas edge')
    if write_profile:
        path=PROJECT/'scripts/actor_presentation.gd';text=path.read_text()
        line='"frostglass_lancer": Rect2(%s),' % ', '.join(str(v)+'.0' for v in rect)
        text=re.sub(r'"frostglass_lancer": Rect2\([^\n]+\),',line,text,count=1);path.write_text(text)
    write_json(CASE/'proof/action_bounds_cpu.json',{'native_pixels':False,'views':result,'rect':rect,
        'full_samples_sha256':read_json(CASE/'proof/samples.json')['full_samples']['sha256'],
        'note':'CPU construction envelope; native owner proof remains required'})
    print('RR37 ACTION CAPACITY: PASS (%s; zero canvas-edge pixels; CPU construction)' % rect)
    return result


if __name__=='__main__':
    import sys
    measure('--write-profile' in sys.argv)
