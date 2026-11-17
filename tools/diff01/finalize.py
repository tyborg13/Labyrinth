#!/usr/bin/env python3
"""Run the count-only census after combat workers exit, archive and report."""
import argparse
import gzip
import hashlib
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time
from inventory import crowded_catalog,legacy_rosters
from report import write_report

ROOT = Path(__file__).resolve().parents[2]
CENSUS_TIMEOUT_SECONDS = 300
PROJECTION_MARGIN = 1.15


def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def write_json(path,value): path.write_text(json.dumps(value,indent=2,sort_keys=True)+'\n')


def archive(path,rows):
    with path.open('wb') as raw, gzip.GzipFile(filename='',fileobj=raw,mode='wb',mtime=0) as stream:
        for row in rows: stream.write((json.dumps(row,sort_keys=True,separators=(',',':'))+'\n').encode())


def finalize(scratch,output,discarded=None,initial_contract=None):
    if (output/'census.jsonl.gz').exists(): raise RuntimeError('Census already exists; use report.py to regenerate report')
    contract = json.loads((output/'contract.json').read_text())
    assert 'elapsed_seconds' in contract, 'Finish collection before the census; never exceed four workers'
    started = time.time()
    path = scratch/'census.jsonl'
    cmd = [sys.executable,'tools/godot_task_runner.py','--task-id','diff-01','--timeout',str(CENSUS_TIMEOUT_SECONDS),
           '--stream','--','godot','--headless','--path','.','--script','tools/diff01/census.gd','--',
           '--directory',str(scratch),'--output',str(path)]
    log = scratch/'census.log'
    with log.open('w') as stream:
        result = subprocess.run(cmd,cwd=ROOT,env={**os.environ,'LABYRINTH_CEL_LOOK':'off'},stdout=stream,stderr=subprocess.STDOUT)
    record = dict(command='cd '+shlex.quote(str(ROOT))+' && '+shlex.join(cmd),log=str(log),started_unix=started,
                  elapsed_seconds=time.time()-started,returncode=result.returncode)
    commands = json.loads((output/'commands.json').read_text())
    commands.append(record)
    write_json(output/'commands.json',commands)
    if result.returncode or 'DIFF01_CENSUS_PASS' not in log.read_text(): raise RuntimeError(f'Census failed: {log}')
    census = [json.loads(line) for line in path.read_text().splitlines()]
    archive(output/'census.jsonl.gz',census)
    archive(output/'oversized_rooms.jsonl.gz',[r for r in census if r['start_count']>5])
    archive(output/'crowded_catalog.jsonl.gz',crowded_catalog())
    archive(output/'legacy_rosters.jsonl.gz',legacy_rosters())
    archive(output/'census_logs.jsonl.gz',[dict(path=str(log),text=log.read_text())])
    # Archive the original fixture records too, not just typed snapshots.
    reference = ROOT/'spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11/ladder_runs.jsonl.gz'
    with gzip.open(reference,'rt') as stream: ladders=[r for r in map(json.loads,stream) if r['seed']<=8]
    archive(output/'ladders.jsonl.gz',ladders)
    if discarded:
        archive(output/'discarded_planner.jsonl.gz',[dict(path=str(p),text=p.read_text()) for p in sorted(discarded.glob('*.log'))])
    if initial_contract:
        initial=json.loads(initial_contract.read_text())
        contract['successful_collection_started_unix']=contract['started_unix']
        contract['started_unix']=initial['started_unix']
    with gzip.open(output/'runs.jsonl.gz','rt') as stream: fights=[json.loads(line) for line in stream]
    omitted=set(range(6))-set(contract['selected_sections'])
    expected_omitted=sum(size for key,size in contract['block_expected_sizes'].items() if int(key.split('-')[0][1:]) in omitted)*8
    contract['omitted_fights_to_64']=expected_omitted-sum(r['section'] in omitted for r in fights)
    contract['projection_margin']=PROJECTION_MARGIN
    contract['omitted_projection_seconds']=contract['pilot_elapsed_seconds']/contract['pilot_fights']*contract['omitted_fights_to_64']*PROJECTION_MARGIN
    contract['collection_elapsed_seconds'] = contract['elapsed_seconds']
    contract['census_elapsed_seconds'] = time.time()-started
    contract['elapsed_seconds'] = time.time()-contract['started_unix']
    contract['artifact_sha256'] = {p.name:digest(p) for p in output.glob('*.gz')}
    contract['measurement_tool_sha256'] = {str(p.relative_to(ROOT)):digest(p) for p in sorted((ROOT/'tools/diff01').glob('*')) if p.suffix in ('.gd','.py')}
    write_json(output/'contract.json',contract)
    write_report(output)
    print(f"DIFF01_REPORT_PASS census_rows={len(census)} oversized_rows={sum(r['start_count']>5 for r in census)} wall_seconds={contract['elapsed_seconds']:.1f}")

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scratch-dir',type=Path,required=True)
    parser.add_argument('--output-dir',type=Path,required=True)
    parser.add_argument('--discarded-scratch-dir',type=Path)
    parser.add_argument('--initial-contract',type=Path)
    args=parser.parse_args()
    finalize(args.scratch_dir.resolve(),args.output_dir.resolve(),args.discarded_scratch_dir,args.initial_contract)
