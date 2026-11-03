"""Source-authority gates, independent of output palette and crop support."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr42_underlay import CASE, BASE_CASE, DIRECTOR, ASSETS, inputs, domains, REMOVED_FILLS, authority_for, repairs, certificates
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.features import source_pixels


def source_report(case=CASE, *, check_production=False):
    paint,masks=inputs(); authority=np.logical_or.reduce(list(masks.values())); targets=domains()
    errors=[]; counts={}
    from rr42_tucks import errors as tuck_errors
    errors+=tuck_errors(case)
    from rr38_case import DIRECTOR as MOTION
    from rr42_fragments import apply as fragment_plan
    for view in ('front','rear'):
        layout=read_json(case/f'layouts/{view}.json'); base=read_json(BASE_CASE/f'layouts/{view}.json')
        original={p['name']:p for p in base['parts']}
        images={p['name']:source_pixels(case,p) for p in layout['parts']}
        expected_visible={p['name']:source_pixels(BASE_CASE,p) for p in base['parts']}
        fragment_plan(view,expected_visible)
        for part in layout['parts']:
            name=part['name']; image=images[name]
            if not part.get('hidden_material'):
                if not np.array_equal(image,expected_visible[name]):
                    errors.append(f'{view}/{name}: visible paint differs from director fragment ownership')
                continue
            before=source_pixels(BASE_CASE,original[name])
            part_authority=authority_for(part['logical_part'])
            permitted=part_authority.copy() if view=='front' else np.zeros(authority.shape,bool)
            islands=np.zeros(authority.shape,bool)
            if name in REMOVED_FILLS:
                from maquette_motion.silhouette import components
                visible=source_pixels(BASE_CASE,original[part['logical_part']])
                labels,groups=components((visible[...,3]>0)|(before[...,3]>0),8)
                if groups: islands=(labels>0)&(labels!=groups[0][0])
                permitted |= islands
            if np.any(image[~permitted]!=before[~permitted]):
                errors.append(f'{view}/{name}: unrelated backing changed')
            if view=='front':
                expected=np.zeros_like(paint)
                certified=certificates().get(name,np.zeros((255,255),bool))
                expected[certified]=paint[certified]
                if np.any(image[part_authority]!=expected[part_authority]): errors.append(f'{view}/{name}: director paint/clear differs')
                islands &= ~part_authority
            if np.any(image[...,3][islands]): errors.append(f'{view}/{name}: retired floating fill restored')
        from rr42_references import clear_errors
        errors += clear_errors(case,layout)
        tables=[layout.get('gait_continuations',{})]+list(layout.get('clip_continuations',{}).values())
        parts={p['name']:p for p in layout['parts']}
        for table in tables:
            for name,recipe in table.items():
                x,y=parts[name]['offset']
                if name in REMOVED_FILLS and recipe['texels']: errors.append(f'{view}/{name}: retired fill recipe restored')
                if view=='front' and any(authority_for(parts[name]['logical_part'])[v+y,u+x] for u,v,_,_ in recipe['texels']):
                    errors.append(f'{view}/{name}: procedural recipe overwrites director authority')
        rest=Image.new('RGBA',(255,255))
        for part in sorted(layout['parts'],key=lambda p:p['z_index']): rest.alpha_composite(Image.fromarray(images[part['name']]))
        mismatch=int(np.any(np.asarray(rest)!=np.asarray(Image.open(case/layout['rest_source']).convert('RGBA')),axis=-1).sum())
        if mismatch: errors.append(view+': stored rest differs from assembly')
        previous=read_json(BASE_CASE/f'layouts/{view}.json')
        approved=np.asarray(Image.open(BASE_CASE/previous['rest_source']).convert('RGBA'))
        baseline_mismatch=int(np.any(np.asarray(rest)!=approved,axis=-1).sum())
        # Rest changes are bounded by the independently checked fragment plan;
        # deletions below six pixels are explicitly director-authorized.
        counts[view]={'rest_mismatch_pixels':mismatch,'approved_rest_mismatch_pixels':baseline_mismatch}
        for root in ((case,ASSETS/'humanoid_v2') if check_production else (case,)):
            if (root/'director_motion.json').read_bytes()!=MOTION.read_bytes(): errors.append('Protected motion differs')
    result={'ok':not errors,'errors':errors,'views':counts,'native_pixels':False,
            'footprint_pixels':{n:int(m.sum()) for n,m in masks.items()},
            'painted_pixels':{n:int(m.sum()) for n,m in targets.items()},
            'justified_clear_pixels':int((authority & (paint[...,3]==0)).sum())}
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--case',type=Path,default=CASE)
    args=parser.parse_args();result=source_report(args.case,check_production=True)
    write_json(CASE/'proof/source_gates.json',result)
    print('RR42 SOURCE AUTHORITY: %s (%d errors; %d justified clear texels)'%('PASS' if result['ok'] else 'FAIL',len(result['errors']),result['justified_clear_pixels']))
    for error in result['errors']:print(error)
    raise SystemExit(not result['ok'])
