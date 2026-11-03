"""Portable mq-22 negative proof; mutate copies, never delivered geometry.

Run with --out to retain the caught/survived table. No engine is launched.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import numpy as np
from .recipe import compile_spec
from .checks import observe_generated_cloak

FIXTURE_DEFAULTS={'interior_displacement_over_H':.20,'fold_delta_over_H':.008,
                  'width_scale':1.08,'row_index_fraction':.5}


def reseal(surface,count):
    """Reseal both skins around a changed live surface, retaining orphans."""
    edges=Counter(tuple(sorted((a,b))) for f in surface for a,b in zip(f,f[1:]+f[:1]))
    faces=[]
    for f in surface:
        faces.extend([f,[i+count for i in reversed(f)]])
        for a,b in zip(f,f[1:]+f[:1]):
            if edges[tuple(sorted((a,b)))]==1:faces.append([b,a,a+count,b+count])
    return faces


def fixture():
    spec=compile_spec();piece=next(p for p in spec['pieces'] if p['id']=='full_back_cloak')
    return spec,np.asarray(piece['vertices']),piece['faces'],{k:np.asarray(v) for k,v in spec['joints'].items()}


def mutations(spec,points,faces):
    layout=spec['mq19']['cloak_layout'];n=layout['paired_vertices'];H=spec['mq19']['gauge_H_m']
    surface=[f for f in faces if all(i<n for i in f)];strip=layout['strips'][0]
    for name,rows in [('remove_lower_half_ribbon',strip['ribbon_rows'][len(strip['ribbon_rows'])//2:]),
                      ('remove_whole_ribbon',strip['ribbon_rows'][1:]),
                      ('detach_lower_half_ribbon',[strip['ribbon_rows'][len(strip['ribbon_rows'])//2]])]:
        deleted={i for row in rows for i in row}
        changed=reseal([f for f in surface if not any(i in deleted for i in f)],n)
        yield name,points,changed,('strip_lengths' if name=='remove_lower_half_ribbon' else
              'nine_actual_strips' if name=='remove_whole_ribbon' else 'continuous_shared_strip_roots')
    balloon=points.copy()
    for t,row in zip(layout['ts'],layout['solid_grid_indices']):
        indices=np.asarray([i for i in row if i>=0]);delta=FIXTURE_DEFAULTS['interior_displacement_over_H']*H*np.sin(np.pi*t)
        balloon[indices,0]-=delta;balloon[indices+n,0]-=delta
    yield 'balloon_interior_020H',balloon,faces,'standoff_profile'
    # A transverse stretch of one interior row must be measured independently
    # of the fold amplitude; both skins move by the same vector.
    width=points.copy();r=int(len(layout['ts'])*FIXTURE_DEFAULTS['row_index_fraction'])
    indices=np.asarray([i for i in layout['solid_grid_indices'][r] if i>=0])
    frame=np.asarray(layout['wrap_frame']);mid=(points[:n]+points[n:])/2
    local=np.einsum('nj,jk->nk',mid[indices],frame);delta=(local[:,1]-np.mean(local[:,1]))*(FIXTURE_DEFAULTS['width_scale']-1)
    shift=np.outer(delta,frame[:,1]);width[indices]+=shift;width[indices+n]+=shift
    yield 'stretch_interior_width',width,faces,'width_profile'
    folds=points.copy();us=np.asarray(layout['us']);theta=np.radians(200)*(us-.5)
    # The fixture wave is explicit and independent of the production generator.
    weights=np.asarray(spec['mq19']['design']['cloak']['fold_amplitude_multipliers']);centres=(np.arange(5)+.5)/5
    k=np.clip(np.searchsorted(centres,us)-1,0,3);blend=np.clip((us-centres[k])/(centres[k+1]-centres[k]),0,1)
    blend=(1-np.cos(np.pi*blend))/2;wave=(weights[k]*(1-blend)+weights[k+1]*blend)*np.sin(10*np.pi*us+np.pi/2)
    row=np.asarray(layout['solid_grid_indices'][r]);valid=row>=0;indices=row[valid]
    offset=FIXTURE_DEFAULTS['fold_delta_over_H']*H
    delta=np.column_stack([-wave[valid]*np.cos(theta[valid]),wave[valid]*np.sin(theta[valid]),np.zeros(valid.sum())])*offset
    shift=np.einsum('nj,kj->nk',delta,frame);folds[indices]+=shift;folds[indices+n]+=shift
    yield 'inflate_interior_folds',folds,faces,'fold_amplitude_growth'


def run():
    spec,points,faces,joints=fixture();baseline=observe_generated_cloak(spec,points,faces,joints)
    if not baseline['passed']:raise ValueError('Passing baseline required before mutation proof')
    table=[]
    for name,changed,polygons,guard in mutations(spec,points,faces):
        result=observe_generated_cloak(spec,changed,polygons,joints)
        caught=result['checks'][guard] is False and result['passed'] is False
        table.append({'mutation':name,'result':'caught' if caught else 'survived',
            'required_guard':guard,'failed_checks':[k for k,v in result['checks'].items() if not v],
            'measured_strip_count':result['strip_count'],
            'ignored_orphan_vertices':result['ribbon_drape']['ignored_orphan_vertices']})
    return {'baseline_passed':True,'passed':all(r['result']=='caught' for r in table),'mutations':table,
        'geometry_modified_on_disk':False,'fixture_defaults':FIXTURE_DEFAULTS}


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path);args=parser.parse_args()
    result=run()
    for row in result['mutations']:print('MQ22_MUTATION: '+row['mutation']+' '+row['result']+'; guard='+row['required_guard'])
    print('MQ22_MUTATIONS: '+('PASS' if result['passed'] else 'FAIL'))
    if args.out:args.out.write_text(json.dumps(result,indent=2)+'\n')
    if not result['passed']:raise SystemExit(1)


if __name__=='__main__':main()
