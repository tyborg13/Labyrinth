"""All-frame native diagnostics, or explicitly labelled CPU construction proof."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr38_case import CASE, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_defects import measure, packed, DESCRIPTIONS
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame, frame_digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import interior_donors, rules

CONTRACT=CASE/'material_contract.json'
FIXTURE=CASE/'proof/cpu_poses.json'


def seal():
    result={'views':{},'acceptance':'director native clips at 2x required'}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');definition=rules(CASE,view);palettes={}
        for part in layout['parts']:
            if part.get('hidden_material'): continue
            image=interior_donors(source_pixels(CASE,part),definition)
            palettes[part['logical_part']]=sorted(map(int,np.unique(packed(image)[image[...,3]>0])))
        result['views'][view]={'floor_pieces':['foot_near','foot_far','leg_near','leg_far'],
            'cloth_pieces':['tabard','coat_near','coat_far'],'interior_palettes':palettes}
    write_json(CONTRACT,result)


def report(provider, poses, native_pixels, case=CASE):
    contract=read_json(case/'material_contract.json');rows=[];errors=[]
    for view,clip,frame in poses:
        layers=provider(view,clip,frame)
        metrics=measure(layers,contract['views'][view])
        rows.append({'view':view,'clip':clip,'frame':frame,'metrics':metrics})
        for defect,count in metrics.items():
            if count: errors.append(f'{defect} {view}/{clip}/{frame}: {DESCRIPTIONS[defect]}: {count}')
    if not rows: errors.append('missing native defect inventory')
    return {'ok':not errors,'errors':errors,'frames':rows,'native_pixels':native_pixels,
        'contract_sha256':digest(case/'material_contract.json'),'acceptance':'director inspection of native clips at 2x required'}


def cpu_report():
    from humanoid_cutout.canvas import for_case
    with for_case(CASE): return _cpu_report()


def _cpu_report():
    from humanoid_cutout.cpu_pose import CpuPose
    fixture=read_json(FIXTURE)
    if fixture['full_samples_sha256'] != read_json(CASE/'proof/samples.json')['full_samples']['sha256']:
        raise ValueError('CPU fixture is stale')
    models={v:CpuPose(CASE,read_json(CASE/f'layouts/{v}.json')) for v in ('front','rear')}
    rows={(r['view'],r['clip'],r['frame']):r for r in fixture['samples']}
    def provide(view,clip,frame): return models[view].layers(rows[view,clip,frame])[0]
    return report(provide,rows,False)


def native_report(capture, case=CASE):
    manifest=read_json(capture/'frames.json')
    if not manifest.get('native_pixels') or manifest.get('size') != [1920,1080] or manifest.get('ui_scale') != 1:
        raise ValueError('RR38 requires native 1920x1080 / 100% capture')
    if manifest['inputs'] != bindings(case): raise ValueError('RR38 native capture is stale')
    data=read_json(case/'compiled_motion.json')
    expected={(v,c,f) for v in data['view_tracks'] for c,d in data['clips'].items() for f in range(round(d['seconds']*60))}
    rows={(r['view'],r['clip'],r['frame']):r for r in manifest['frames']}
    if set(rows)!=expected or len(rows)!=len(manifest['frames']): raise ValueError('RR38 incomplete native inventory')
    groups={}
    for row in manifest['pieces']: groups.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    layouts={v:read_json(case/f'layouts/{v}.json') for v in data['view_tracks']}
    def provide(view,clip,frame):
        full=rows[view,clip,frame]
        if frame_digest(capture/full['file'])!=full['sha256']: raise ValueError('changed native frame')
        pieces=groups[view,clip,frame];parts={p['name']:p for p in layouts[view]['parts']}
        if {p['name'] for p in pieces}!=set(parts) or len(pieces)!=len(parts): raise ValueError('incomplete native layers')
        result=[]
        for row in pieces:
            if frame_digest(capture/row['file'])!=row['sha256']: raise ValueError('changed native layer')
            if frame_digest(capture/row['checks'])!=row['checks_sha256']: raise ValueError('changed native check layer')
            result.append((dict(parts[row['name']],z_index=row['z_index']),np.asarray(load_frame(capture/row['file']).convert('RGBA')),
                np.asarray(load_frame(capture/row['checks']).convert('RGBA'))))
        return result
    return report(provide,sorted(expected),True,case)


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--native',type=Path);p.add_argument('--seal',action='store_true');a=p.parse_args()
    if a.seal: seal();raise SystemExit(0)
    result=native_report(a.native,a.case) if a.native else cpu_report()
    for defect in DESCRIPTIONS:
        count=sum(r['metrics'][defect] for r in result['frames'])
        print(f'RR38 {defect}: {"FAIL" if count else "PASS"} ({len(result["frames"])} frames; native={result["native_pixels"]}; defects={count})')
    write_json(CASE/f'proof/logs/{"native" if a.native else "cpu"}_defects.json',result)
    raise SystemExit(not result['ok'])
