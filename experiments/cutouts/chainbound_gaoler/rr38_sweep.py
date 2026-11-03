"""Re-runnable CPU diagnostic shards with strict per-process budgets."""
from concurrent.futures import ThreadPoolExecutor
import argparse
from pathlib import Path
import subprocess
import sys
import time
from rr38_case import CASE, PROJECT
from rr38_frames import SHARD_FRAMES
from cutout_pipeline.cases import read_json, write_json, digest

SHARD_WORKERS = 2
SHARD_TIMEOUT_SECONDS = 90


def run(job, case=CASE):
    view,clip,start,count=job
    output=case/f'proof/cpu_frames/{view}_{clip}_{start:04d}'
    command=[sys.executable,'-B','experiments/cutouts/chainbound_gaoler/rr38_frames.py',
        '--case',str(case),'--view',view,'--clip',clip,'--start',str(start),'--count',str(count)]
    began=time.monotonic()
    try:
        result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=SHARD_TIMEOUT_SECONDS)
        log=result.stdout+result.stderr
        output.mkdir(parents=True,exist_ok=True);(output/'process.log').write_text(log)
        row=read_json(output/'report.json')
        row.update(seconds=time.monotonic()-began,exit_code=result.returncode)
    except Exception as error:
        row={'view':view,'clip':clip,'start':start,'count':count,'errors':[str(error)],'frames':[],
            'flat_regions':[],'seconds':time.monotonic()-began,'exit_code':2}
    print(f'RR38 SHARD {view}/{clip}/{start}: {row["exit_code"]}; {row["seconds"]:.3f}s',flush=True)
    return row


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,default=CASE)
    parser.add_argument('--clips',help='Comma-separated focused clips; omitted runs every clip')
    args=parser.parse_args()
    case=args.case.resolve()
    data=read_json(case/'compiled_motion.json')
    jobs=[(v,c,start,min(SHARD_FRAMES,round(d['seconds']*60)-start)) for v in data['view_tracks']
        for c,d in data['clips'].items() if not args.clips or c in args.clips.split(',') for start in range(0,round(d['seconds']*60),SHARD_FRAMES)]
    with ThreadPoolExecutor(max_workers=SHARD_WORKERS) as pool:results=list(pool.map(lambda job:run(job,case),jobs))
    errors=[error for r in results for error in r['errors']]
    flags=[flag for r in results for flag in r['flat_regions']]
    summary={'native_pixels':False,'ok':not errors,'frames':sum(r['count'] for r in results),
        'full_samples_sha256':digest(case/'proof/logs/samples.json'),'errors':errors,'flat_regions':flags,
        'max_shard_seconds':max(r['seconds'] for r in results),'shards':results}
    write_json(case/'proof/logs/cpu_sweep.json',summary)
    write_json(case/'proof/cpu_sweep.json',dict(summary,errors=errors[:20],error_count=len(errors),
        flat_regions=flags[:20],flat_region_count=len(flags),shards=[],full_log='logs/cpu_sweep.json',
        full_log_sha256=digest(case/'proof/logs/cpu_sweep.json')))
    print(f'RR38 CPU SWEEP: {"FAIL" if errors else "PASS"} ({summary["frames"]} frames; {len(errors)} findings; {len(flags)} flat regions; native=False)')
    raise SystemExit(bool(errors))
