"""Independent rr-04 director/geometry oracle; never invokes the compiler.

This intentionally reads authored rows and geometry again. Recompiling with a
broken sign or discarded key must not teach the verifier the same mistake.
"""
from __future__ import annotations
import hashlib
import math
import numpy as np
from maquette_cutout import projected, shape_center
from cutout_pipeline.cases import read_json, digest, CutoutError
from pathlib import Path

DIRECTOR_SOURCE = Path(__file__).resolve().parents[2] / 'spec/peer_benchmark/staged/rr-04/motion_tracks.json'


def approved_source(case):
    """Validate a case-local director amendment without recopying other rigs.

    The amendment records the exact supplied old/new value and base digest.
    Every other field, including other creatures, remains protected.
    """
    path = case / 'director_amendments.json'
    if not path.exists():
        if (case / 'director_motion.json').read_bytes() != DIRECTOR_SOURCE.read_bytes():
            raise CutoutError('Protected motion copy differs')
        return DIRECTOR_SOURCE
    amendment = read_json(path)
    if amendment['base_sha256'] != digest(DIRECTOR_SOURCE):
        raise CutoutError('Director amendment base differs')
    expected = read_json(DIRECTOR_SOURCE)
    creature = read_json(case / 'cutout.json')['character_id']
    for edit in amendment['edits']:
        if edit['path'][0] != creature:
            raise CutoutError('Director amendment changes another creature')
        parent = expected
        for field in edit['path'][:-1]:
            parent = parent[field]
        field = edit['path'][-1]
        if parent[field] != edit['before']:
            raise CutoutError('Director amendment old value differs')
        parent[field] = edit['after']
    source = case / 'director_motion.json'
    if read_json(source) != expected:
        raise CutoutError('Protected motion copy differs beyond director amendment')
    return source

ANGLE_EPSILON = 1e-12


def expected(source, creature, spec):
    author=read_json(source)[creature]
    shapes={label:[s for s in spec['shapes'] if s['part']==label] for label in spec['labels']}
    anchors={'root':spec['joints']['root']}
    parents={'root':None}
    material_bones={}
    cloud=creature=='lightning_wisp'
    if creature not in ('shale_bloomer','lightning_wisp'):
        raise ValueError('An independent geometry contract is required for '+creature)
    for label,geometry in shapes.items():
        bone='core' if cloud and label in ('crown','arc_left','arc_right') else label
        material_bones[label]=bone
        if label!=bone:continue
        if label in spec['joints']:anchor=spec['joints'][label]
        elif label=='trunk':anchor=spec['joints']['base']
        elif geometry[0]['type']=='capsule':anchor=geometry[0]['a']
        else:anchor=np.mean([edge for shape in geometry for edge in shape['pts'][:2]],axis=0).tolist()
        anchors[bone]=anchor
        if cloud:parent='root' if bone=='core' else 'core'
        elif bone=='trunk':parent='root'
        elif bone=='core' or bone.startswith('petal_'):parent='crown'
        elif bone.startswith('root_tip_'):parent='root_stem_'+bone[len('root_tip_'):]
        else:parent='trunk'
        parents[bone]=parent
    if not cloud:
        anchors['crown']=spec['joints']['crown'];parents['crown']='trunk'
    views={}
    for view in ('front','rear'):
        origin=np.asarray(projected(spec,[0,0,0],view))
        def screen(direction):return np.asarray(projected(spec,direction,view))-origin
        up=screen([0,0,1]);forward=screen([1,0,0])
        def turn(ray,target):
            # Signed angular difference is independent of the compiler's
            # cross-product/sign implementation and compiled projection table.
            sine=math.sin(math.atan2(target[1],target[0])-math.atan2(ray[1],ray[0]))
            return None if abs(sine)<ANGLE_EPSILON else math.copysign(1.0,sine)
        parts={}
        for bone,anchor in anchors.items():
            geometry=[s for group in shapes.values() for s in group if material_bones[s['part']]==bone]
            axes={'lean_deg':turn(up,forward),'joint_3d':anchor}
            if geometry:
                tip=np.mean([shape_center(s,spec['joints']) for s in geometry],axis=0)
                raised=turn(screen(tip-np.asarray(anchor)),up)
                if raised is not None:axes['raise_deg']=raised
            parts[bone]=axes
        views[view]={'forward':(forward/np.linalg.norm(forward)).tolist(),'parts':parts}
    result={'creature':creature,'director_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
            'joints_3d':anchors,'parents':parents,'parts':material_bones,'projection':views,
            'clips':{},'view_tracks':{'front':{},'rear':{}},'TODO_DESIGN':{}}
    for name,clip in author['clips'].items():
        result['clips'][name]={field:value for field,value in clip.items() if field!='keys'}
        for view in ('front','rear'):
            tracks=[]
            for channel,rows in clip['keys'].items():
                part,field=channel.rsplit('.',1)
                if field=='forward_mode':continue
                bone='root' if part=='body' else part
                factor=views[view]['parts'][bone][field] if field in ('raise_deg','lean_deg') else 1.0
                tracks.append({'source':channel,'bone':bone,'channel':field,
                    'keys':[{'at':row[0],'value':row[1]*factor,'interpolation':row[2] if len(row)>2 else 'smoothstep'} for row in rows],
                    'forward_mode':clip['keys'].get(part+'.forward_mode','pixels')})
            result['view_tracks'][view][name]=tracks
    return result


def phases(data,clip):
    values={0.0,1.0}
    for track in data['view_tracks']['front'][clip]:
        times=[row['at'] for row in track['keys']]
        values.update(times)
        values.update((a+b)*0.5 for a,b in zip(times,times[1:]))
    if 'contact' in data['clips'][clip]:values.add(data['clips'][clip]['contact'])
    return sorted({round(value,12) for value in values})


def evaluate(rows,t):
    if t<=rows[0]['at']:return rows[0]['value']
    for a,b in zip(rows,rows[1:]):
        if t>b['at']:continue
        u=(t-a['at'])/(b['at']-a['at'])
        if b['interpolation']=='hold':return b['value'] if t==b['at'] else a['value']
        if b['interpolation']=='smoothstep':u=3*u*u-2*u*u*u
        return (1-u)*a['value']+u*b['value']
    return rows[-1]['value']
