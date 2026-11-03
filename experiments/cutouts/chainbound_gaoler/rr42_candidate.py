"""Fresh isolated channel-budget candidates; never edit protected tracks."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys
from rr42_underlay import CASE,PROJECT
from rr42_density import PROOF_CASE
from cutout_pipeline.cases import read_json,write_json
from rr42_sweep import frames,sweep


def authored_motion(motion_case):
    from humanoid_cutout.compiler import compile_motion
    current=read_json(motion_case/'compiled_motion.json')
    layouts={v:read_json(motion_case/f'layouts/{v}.json') for v in ('front','rear')}
    return compile_motion(motion_case/'director_motion.json','chainbound_gaoler',layouts,current['projection'])


def candidate_motion(motion_case,clip,channels):
    """Re-test authored peaks after promotion without resetting live clamps."""
    data=read_json(motion_case/'compiled_motion.json');authored=authored_motion(motion_case)
    for view in data['view_tracks']:
        for source,peak in channels.items():
            track=next(t for t in authored['view_tracks'][view][clip] if t['source']==source)
            target=max(abs(k['value']) for k in track['keys'])
            if not 0<=peak<=target:raise ValueError('Channel candidate must move toward authored rest')
            for key in track['keys']:key['value']*=peak/target
            tracks=data['view_tracks'][view][clip]
            tracks[next(i for i,t in enumerate(tracks) if t['source']==source)]=track
    return data


def prepare(label,clip,channels,witnesses=None):
    output=CASE/'proof/feedback1_limits'/label
    shutil.copytree(PROOF_CASE,output,dirs_exist_ok=True,ignore=shutil.ignore_patterns('proof'))
    data=candidate_motion(PROOF_CASE,clip,channels)
    for view in data['view_tracks']:
        layout=read_json(output/f'layouts/{view}.json')
        layout['motion_data']='res://'+str(output.relative_to(PROJECT)/'compiled_motion.json')
        write_json(output/f'layouts/{view}.json',layout)
    write_json(output/'compiled_motion.json',data);write_json(output/'channel_peaks.json',channels)
    command=[sys.executable,'tools/godot_task_runner.py','--task-id','rr-42','--stream','--','godot','--headless','--path','.',
             '--script','tests/rr38/samples.gd','--','--case',str(output),'--clips',clip,'--output',str(output/'proof/logs/samples.json')]
    if witnesses is not None:command += ['--presented-only','--frames',','.join(map(str,witnesses))]
    subprocess.run(command,cwd=PROJECT,check=True)
    return output


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--label',required=True);p.add_argument('--clip',required=True)
    p.add_argument('--channel',action='append',required=True,help='source=peak');p.add_argument('--frames');p.add_argument('--exposure',action='store_true')
    a=p.parse_args();channels={k:float(v) for k,v in (row.split('=') for row in a.channel)}
    witnesses=list(map(int,a.frames.split(','))) if a.frames else None
    output=prepare(a.label,a.clip,channels,witnesses)
    if witnesses is None:raise SystemExit(not sweep(output,a.clip,a.exposure)['ok'])
    for view in ('front','rear'):frames(output,view,a.clip,0,max(witnesses)+1,a.exposure)
    rows=[r for view in ('front','rear') for r in read_json(output/f'proof/logs/rr42_shards/{view}_{a.clip}_000.json')['frames']]
    bad=[(r['view'],r['frame'],r['kinds']) for r in rows if r['kinds']]
    write_json(output/'witness.json',{'ok':not bad,'errors':bad})
    print('RR42 CHANNEL WITNESS:',a.label,'PASS' if not bad else 'FAIL',bad)
    raise SystemExit(bool(bad))
