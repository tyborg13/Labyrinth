"""Register every missing receiver UV measured by the complete CPU sweep."""
from collections import defaultdict
import numpy as np
from PIL import Image
from rr52_build import CASE,ROOT,MESHES,partition
from rr52_source import plans,support_paths,DEPTH_PX
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.silhouette import components,dilate


def run(measurement=None,joint_overlap=False):
    measurement=measurement or CASE/'proof/cpu_sweep.json';report=read_json(measurement);groups=defaultdict(dict)
    for row in report['cap_requests']:groups[row['view'],row['part']].setdefault(tuple(row['uv']),row)
    old=read_json(CASE/'underlay_joint_caps.json')['caps'];records={(r['view'],r['part']):r for r in old};unreachable=[]
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');underlay=np.asarray(Image.open(ROOT/f'spec/peer_benchmark/staged/rr-52/{view}_body_underlay.png').convert('RGBA'))
        base,_=plans(CASE,layout,partition(view)[2],underlay,MESHES,include_measured=False)
        painted=underlay[...,3]>0;labels,_=components(painted,8)
        for facing,name in set(records)|set(groups):
            if facing!=view:continue
            witnesses=groups.get((facing,name),{})
            row=records.setdefault((view,name),{'view':view,'part':name,'texels':[],'witnesses':[],'support_texels':[]})
            prior={tuple(w['uv']):w for w in row['witnesses']};prior.update(witnesses)
            source=base[name]['image'][...,3]>0;core_labels,core_groups=components(source,8)
            core=core_labels==core_groups[0][0];reachable=set(map(int,labels[core&painted]))-{0}
            valid={uv:w for uv,w in prior.items() if int(labels[uv[1],uv[0]]) in reachable}
            unreachable += [dict(w,reason='No director-painted path to receiving core') for uv,w in prior.items() if uv not in valid]
            row['texels']=[list(uv) for uv in sorted(valid)];row['witnesses']=[valid[uv] for uv in sorted(valid)]
            centers=set(map(tuple,row.get('overlap_centers',[])))
            if joint_overlap:centers|=set(witnesses)
            if centers:
                mask=np.zeros_like(painted)
                for u,v in centers:mask[v,u]=True
                overlap=dilate(mask,DEPTH_PX)&painted;yy,xx=np.nonzero(overlap)
                row.update(overlap_centers=[list(p) for p in sorted(centers)],overlap_depth_px=DEPTH_PX,overlap_texels=np.column_stack((xx,yy)).tolist())
            targets=set(valid)|set(map(tuple,row.get('overlap_texels',[])))
            row['support_texels']=[list(p) for p in sorted(support_paths(source,painted,targets))]
    value={'caps':list(records.values()),'rule':'Measured missing receiver UVs, binding three-pixel opaque-underlay tuck around native witnesses, and exact shortest 8-connected director-painted support; no new paint','native_pixels':report.get('native_pixels',False),'sweep_sha256':digest(measurement),'unreachable':unreachable}
    write_json(CASE/'underlay_joint_caps.json',value)
    print('RR52 MEASURED UNDERLAY CAPS: %d UVs; %d support texels; %d unreachable'% (sum(len(r['texels']) for r in value['caps']),sum(len(r['support_texels']) for r in value['caps']),len(unreachable)))

if __name__=='__main__':
    import argparse
    from pathlib import Path
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--measurement',type=Path);parser.add_argument('--joint-overlap',action='store_true');args=parser.parse_args();run(args.measurement,args.joint_overlap)
