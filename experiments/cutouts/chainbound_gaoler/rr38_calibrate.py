"""Compare fresh four-frame CPU shards with the immutable director error set."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import time
from rr38_case import CASE,PROJECT
from cutout_pipeline.cases import read_json,write_json,digest

SHARD_FRAMES=4
WORKERS=2
TIMEOUT_SECONDS=90


def run(case,fixture,output):
    truth=read_json(fixture);expected={tuple(s) for s in truth['signatures']}
    wanted={s[:3] for s in expected}
    motion=read_json(case/'compiled_motion.json')
    jobs=sorted({(v,c,f//SHARD_FRAMES*SHARD_FRAMES) for v,c,f in wanted})
    def job(key):
        v,c,start=key;folder=output/f'{v}_{c}_{start:04d}'
        count=min(SHARD_FRAMES,round(motion['clips'][c]['seconds']*60)-start)
        command=[sys.executable,'-B','experiments/cutouts/chainbound_gaoler/rr38_frames.py','--case',str(case),'--view',v,'--clip',c,'--start',str(start),'--count',str(count),'--only-frames',str(fixture),'--output',str(folder)]
        began=time.monotonic();r=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=TIMEOUT_SECONDS)
        folder.mkdir(parents=True,exist_ok=True);(folder/'process.log').write_text(r.stdout+r.stderr)
        if r.returncode not in (0,1) or not (folder/'report.json').exists():raise ValueError(str(folder/'process.log'))
        report=read_json(folder/'report.json');report['seconds']=time.monotonic()-began
        print(f'RR38 CALIBRATION SHARD {v}/{c}/{start}: {len(report["frames"])} frames; {report["seconds"]:.3f}s',flush=True)
        return report
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:reports=list(pool.map(job,jobs))
    actual={(r['view'],r['clip'],frame['frame'],kind) for r in reports for frame in r['frames'] for kind in frame['kinds']}
    missing=sorted(expected-actual)
    result={'ok':not missing,'native_pixels':False,'fixture_sha256':digest(fixture),'native_gate_log_sha256':truth['native_gate_log_sha256'],
        'native_manifest_sha256':truth['native_manifest_sha256'],'raw_native_errors':len(truth['errors']),
        'expected_signatures':len(expected),'observed_signatures':[list(s) for s in sorted(actual)],'missing':[list(s) for s in missing],
        'max_shard_seconds':max(r['seconds'] for r in reports),'shards':reports}
    write_json(output/'calibration.json',result)
    print(f'RR38 CPU/NATIVE CALIBRATION: {"PASS" if not missing else "FAIL"} ({len(expected)-len(missing)}/{len(expected)} frame/kind signatures; {len(truth["errors"])} native errors; {len(missing)} misses)',flush=True)
    for row in missing:print('MISSED '+str(row),flush=True)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True)
    p.add_argument('--fixture',type=Path,default=CASE/'proof/feedback3_native_errors.json');p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();raise SystemExit(not run(a.case,a.fixture,a.output)['ok'])
