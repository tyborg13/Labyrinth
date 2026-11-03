"""Four-frame, 90s native-evidence triage shards; no windowed execution."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import collections
from pathlib import Path
import subprocess
import sys
import time
from rr38_case import CASE, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest

SHARD_FRAMES=4
SHARD_WORKERS=2
SHARD_TIMEOUT_SECONDS=90


def run(case, treated, native, retained, output):
    cpu=read_json(case/'proof/logs/cpu_sweep.json')
    jobs=[(r['view'],r['clip'],r['start'],r['count']) for r in cpu['shards']
          if r['errors'] or r['flat_regions']]
    def job(values):
        view,clip,start,count=values
        folder=output/f'{view}_{clip}_{start:04d}'
        command=[sys.executable,'-B','experiments/cutouts/chainbound_gaoler/rr38_triage.py',
            '--case',str(case),'--treated-case',str(treated),'--native',str(native),
            '--view',view,'--clip',clip,'--start',str(start),'--count',str(count),'--output',str(folder)]
        if retained:command+=['--retained',str(retained)]
        began=time.monotonic()
        result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=SHARD_TIMEOUT_SECONDS)
        folder.mkdir(parents=True,exist_ok=True)
        (folder/'process.log').write_text(result.stdout+result.stderr)
        if result.returncode:raise RuntimeError('Triage failed: '+str(folder/'process.log'))
        report=read_json(folder/'triage.json')
        report['seconds']=time.monotonic()-began
        print(f'RR38 TRIAGE SHARD {view}/{clip}/{start}: PASS; {report["seconds"]:.3f}s',flush=True)
        return report
    with ThreadPoolExecutor(max_workers=SHARD_WORKERS) as pool:reports=list(pool.map(job,jobs))
    records=[r for report in reports for r in report['records']]
    expected=sum(len(s['errors'])+len(s['flat_regions']) for s in cpu['shards'])
    if len(records)!=expected:raise ValueError('Incomplete CPU finding triage')
    counts=dict(collections.Counter(r['kind']+'/'+r['classification'] for r in records))
    report={'native_acceptance':False,'source_cpu_log_sha256':digest(case/'proof/logs/cpu_sweep.json'),
        'native_manifest_sha256':digest(native/'frames.json'),'counts':counts,'records':records,
        'max_shard_seconds':max(r['seconds'] for r in reports),'timeout_count':0}
    write_json(output/'triage.json',report)
    print('RR38 TRIAGE INVENTORY: PASS '+str(counts),flush=True)
    return report


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('case','treated-case','native','retained','output'):p.add_argument('--'+name,type=Path,required=name!='retained')
    a=p.parse_args();run(a.case,a.treated_case,a.native,a.retained,a.output)
