"""Complete native grids and pixel-exact approved held-frame classification.

Only seam-hole findings can be classified as approved baseline. Pose, source,
composition, material and provenance checks remain errors. A changed pixel keeps
all seam findings in that frame active; there is no frame-number allowlist.
"""
import argparse
import ast
import math
from collections import Counter
from pathlib import Path
import re
import numpy as np
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.native_frames import frame_exists,frame_digest,load_frame

FPS=60
PHASE_TOLERANCE=0.0001  # Existing serialized-pose precision; not motion tuning.


def keys_for(motion,held_only=False):
    result={}
    for view in motion['view_tracks']:
        for clip,definition in motion['clips'].items():
            count=round(definition['seconds']*FPS)
            release=motion.get('view_release_at',{}).get(view,{}).get(clip,definition.get('release_at',{})).get('falchion',float('inf'))
            for frame in range(count):
                phase=frame/(count if definition.get('loop') else count-1)
                if not held_only or phase<release:result[view,clip,frame]=phase
    return result


def capture_errors(capture,motion):
    path=capture/'frames.json'
    if not path.is_file():return ['missing native manifest: '+str(path)]
    try:manifest=read_json(path)
    except (OSError,ValueError) as error:return ['invalid native manifest: '+str(path)+': '+str(error)]
    errors=[]
    if not manifest.get('ok') or manifest.get('errors'):errors.append(str(path)+': capture did not complete successfully')
    if (not manifest.get('native_pixels') or manifest.get('size')!=[1920,1080]
            or manifest.get('ui_scale')!=1 or manifest.get('fps')!=FPS):
        errors.append(str(path)+': native 1920x1080 / 100% / 60 fps required')
    rows=manifest.get('frames',[]);expected=keys_for(motion);counts=Counter((r['view'],r['clip'],r['frame']) for r in rows)
    by_key={(r['view'],r['clip'],r['frame']):r for r in rows}
    for key,phase in expected.items():
        row=by_key.get(key);logical=capture/(row['file'] if row else f'{key[0]}_{key[1]}/pose_{key[2]:04d}.png')
        if counts[key]!=1:errors.append(str(logical)+': expected one manifest frame, got '+str(counts[key]))
        if row is None or not frame_exists(logical):errors.append('missing native frame: '+str(logical))
        elif not math.isfinite(row.get('phase',float('inf'))) or abs(row.get('phase',float('inf'))-phase)>PHASE_TOLERANCE:errors.append(str(logical)+': native phase differs from clock')
    for key in counts.keys()-expected.keys():errors.append(str(path)+': undeclared native frame '+str(key))
    # Also name missing isolated/check surfaces before the downstream gates
    # open them. Baseline comparison itself only consumes the composed grid.
    surfaces=set()
    for table in ('pairs','pieces','idle_groups','rest_holes','joint_seams'):
        for row in manifest.get(table,[]):
            surfaces.update(row[field] for field in ('file','checks','rest') if field in row)
    if manifest.get('pieces'):surfaces.update(view+'_rest.png' for view in motion['view_tracks'])
    for relative in sorted(surfaces):
        if not frame_exists(capture/relative):errors.append('missing native surface: '+str(capture/relative))
    # Existence is checked for the entire grid before any digest/pixel access.
    # In particular, a hidden macOS window must not produce a mid-gate traceback.
    if errors:return errors
    for row in rows:
        logical=capture/row['file']
        try:
            if frame_digest(logical)!=row['sha256']:errors.append('changed native frame: '+str(logical))
        except (OSError,ValueError) as error:errors.append('unreadable native frame: '+str(logical)+': '+str(error))
    return errors


def compare(before,after,motion,*,native_pixels=True):
    if native_pixels:
        errors=capture_errors(before,motion)+capture_errors(after,motion)
        if errors:raise ValueError('\n'.join(errors))
    baseline=read_json(before/'frames.json');current=read_json(after/'frames.json')
    if native_pixels:
        for key,value in baseline['inputs'].items():
            if key.startswith(('runtime:','production:')) and current['inputs'].get(key)!=value:raise ValueError('Native runtime/production binding differs: '+key)
        if baseline['inputs'].get('compiled_motion.json')!=current['inputs'].get('compiled_motion.json'):raise ValueError('Native compiled motion differs')
    old={(r['view'],r['clip'],r['frame']):r for r in baseline['frames']};new={(r['view'],r['clip'],r['frame']):r for r in current['frames']}
    selected=keys_for(motion,held_only=True) if native_pixels else {k:r['phase'] for k,r in new.items()}
    records=[];differences=[]
    for key,phase in selected.items():
        arow,brow=old[key],new[key]
        if abs(arow['phase']-brow['phase'])>PHASE_TOLERANCE:raise ValueError('Native phases differ: '+str(key))
        for root,row in ((before,arow),(after,brow)):
            if frame_digest(root/row['file'])!=row['sha256']:raise ValueError('Changed native frame: '+str(root/row['file']))
        a=np.asarray(load_frame(before/arow['file']).convert('RGBA'));b=np.asarray(load_frame(after/brow['file']).convert('RGBA'))
        if a.shape!=b.shape:raise ValueError('Native frame dimensions differ: '+str(key))
        changed=np.any(a!=b,axis=-1)
        records.append({'view':key[0],'clip':key[1],'frame':key[2],'phase':phase,'pixel_diff':int(changed.sum())})
        for y,x in np.argwhere(changed):differences.append({'view':key[0],'clip':key[1],'frame':key[2],'xy':[int(x),int(y)],'before':a[y,x].tolist(),'after':b[y,x].tolist()})
    return {'ok':not differences,'native_pixels':native_pixels,'frames':len(records),'frame_comparisons':records,
            'differing_pixels':len(differences),'pixels':differences,
            'baseline_manifest_sha256':digest(before/'frames.json'),'current_manifest_sha256':digest(after/'frames.json')}


class HeldBaseline:
    def __init__(self,comparison):
        self.comparison=comparison
        self.identical={(r['view'],r['clip'],r['frame']) for r in comparison['frame_comparisons'] if r['pixel_diff']==0}
        self.findings=[]

    def classify(self,errors):
        active=[]
        for error in errors:
            key=None
            if error.endswith(': new joint-seam hole larger than 1px'):
                try:key=ast.literal_eval(error.split(':',1)[0])
                except (ValueError,SyntaxError):pass  # Unrecognized evidence stays active.
            else:
                match=re.fullmatch(r'([^/]+)/([^/]+)/(\d+): persistent director-underlay hole .*',error)
                if match:key=(match[1],match[2],int(match[3]))
            if isinstance(key,tuple) and key in self.identical:
                self.findings.append({'view':key[0],'clip':key[1],'frame':key[2],'pixel_diff':0,'finding':error,'classification':'approved held baseline'})
            else:active.append(error)
        return active


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    errors=capture_errors(a.capture,read_json(a.case/'compiled_motion.json'));write_json(a.output,{'ok':not errors,'errors':errors,'capture':str(a.capture)})
    print('RR57 NATIVE GRID:', 'FAIL' if errors else 'PASS',str(a.capture))
    for error in errors:print(error)
    return int(bool(errors))

if __name__=='__main__':raise SystemExit(main())
