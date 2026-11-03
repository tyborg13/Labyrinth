"""On-demand actual production contact/outcome checks, in both views."""
import argparse
from pathlib import Path
from rr52_build import CASE
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.production_gates import production_errors


def run(capture):
    manifest=read_json(capture/'logic_frames.json' if (capture/'logic_frames.json').exists() else capture/'frames.json');data=read_json(CASE/'compiled_motion.json')
    errors=production_errors(CASE,manifest,data)
    for clip in ('snuff','mourning_hook','last_procession'):
        rows=[r for r in manifest['frames'] if r['stage']==clip];contact=data['clips'][clip]['contact'];before=[r for r in rows if r['snapshot']['phase']<contact];after=[r for r in rows if r['snapshot']['phase']>=contact]
        if not before or not after:errors.append(clip+': missing contact boundary');continue
        first=before[0];hit=after[0]
        if any(r['player_hp']!=first['player_hp'] or r['player_pos']!=first['player_pos'] or r.get('enemy_count')!=first.get('enemy_count') or r.get('braziers_lit')!=first.get('braziers_lit') for r in before):errors.append(clip+': outcome applied before contact')
        if clip=='snuff':
            if hit.get('enemy_count',0)!=first.get('enemy_count',0)+1 or hit.get('braziers_lit')!=first.get('braziers_lit',0)-1:errors.append('snuff: summon/snuff absent at contact')
        else:
            if hit['player_hp']>=first['player_hp']:errors.append(clip+': hit absent at contact')
            if clip=='mourning_hook' and hit['player_pos']==first['player_pos']:errors.append('mourning_hook: Pull absent at contact')
    result={'ok':not errors,'errors':errors,'frames':len(manifest['frames']),'native_pixels':manifest['native_pixels']};write_json(capture/'outcomes.json',result)
    print(f'RR52 PRODUCTION CONTACTS: {"PASS" if not errors else "FAIL"} ({result["frames"]} frames)')
    for error in errors[:25]:print(error)
    return not errors

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('capture',type=Path);a=p.parse_args();raise SystemExit(int(not run(a.capture)))
