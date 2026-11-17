#!/usr/bin/env python3
"""Four-worker, three-hour native tier measurement using meas-06/07 fixtures."""
from __future__ import annotations
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'tools/meas07')]
from run_curve import policy_hash, sha256
from meas07.collect import archive, write_json

WORKERS = 4
LOADOUTS = 8
REPEATS = 8
WALL_SECONDS = 3 * 60 * 60
RESERVE_SECONDS = 120
PROJECTION_MARGIN = 1.15
BATCH_SIZE = 4
PLANNING_TIMEOUT_SECONDS = 600
REFERENCE = ROOT / 'spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11'
OUTPUT = ROOT / 'spec/peer_benchmark/encounter_redesign/measurements/tiers_2026-11'


def command(arguments, timeout):
    return [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'diff-01', '--timeout', str(timeout),
            '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tools/diff01/measure.gd', '--', *arguments]


def collect(scratch, output, resume=False, priority_only=False):
    if not resume and scratch.exists() and any(scratch.iterdir()):
        raise RuntimeError('Use fresh scratch to preserve earlier measurements')
    if not resume and (output / 'contract.json').exists():
        raise RuntimeError('Use fresh output to preserve earlier measurements')
    scratch.mkdir(parents=True, exist_ok=True)
    output.mkdir(parents=True, exist_ok=True)
    started = json.loads((output/'contract.json').read_text())['started_unix'] if resume else time.time()
    deadline = started + WALL_SECONDS - RESERVE_SECONDS
    sources = [*sorted((ROOT/'scripts').rglob('*.gd')), *sorted((ROOT/'data').rglob('*.json')),
               *sorted((ROOT/'tools').glob('run_curve*.gd')), ROOT/'tools/encounter_bot.gd']
    contract = dict(task='diff-01', risk_tier='standard', started_unix=started, deadline_unix=deadline,
                    max_workers=WORKERS, wall_seconds_limit=WALL_SECONDS, target_n=64,
                    source_head=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    policy_sha256=policy_hash(), source_sha256={str(p.relative_to(ROOT)): sha256(p) for p in sources},
                    fixture_sha256=sha256(REFERENCE/'dragons_loadouts.jsonl.gz'),
                    acceptance=['A: section and difficulty tier win rates, median turns and gross Health loss; matched depth bands',
                                'A: target N>=64; prioritize s0,s2,s4 if projected full grid exceeds three hours',
                                'B: scaling inventory and starting enemy count distributions, summons separate',
                                'C: exact existing Health/damage knob locations without tuning',
                                'Proof: report, exact commands, gzipped JSONL and wall time'],
                    inspection='Not applicable: headless measurement only; no game or presentation changes')
    if resume:
        original = json.loads((output/'contract.json').read_text())
        assert original['source_sha256'] == contract['source_sha256']
        contract = original
    write_json(output/'contract.json', contract)
    with gzip.open(REFERENCE/'dragons_loadouts.jsonl.gz', 'rt') as stream:
        entries = [r for r in map(json.loads, stream) if r['ladder_seed'] <= LOADOUTS]
    assert len(entries) == LOADOUTS*6
    for entry in entries:
        (scratch/f"entry-{entry['ladder_seed']}-{entry['section']}.bin").write_bytes(base64.b64decode(entry['typed_payload_base64']))
    archive(output/'entry_loadouts.jsonl.gz', entries)
    commands = [json.loads(p.read_text()) for p in sorted(scratch.glob('*.command.json'))] if resume else []

    def execute(arguments, log, marker, timeout):
        cmd = command(arguments, timeout)
        before = time.time()
        with log.open('w') as stream:
            result = subprocess.run(cmd, cwd=ROOT, env={**os.environ, 'LABYRINTH_CEL_LOOK': 'off'}, stdout=stream, stderr=subprocess.STDOUT)
        record = dict(command='cd '+shlex.quote(str(ROOT))+' && '+shlex.join(cmd), log=str(log),
                      started_unix=before, elapsed_seconds=time.time()-before, returncode=result.returncode)
        write_json(log.with_suffix('.command.json'), record)
        commands.append(record)
        if result.returncode or marker not in log.read_text():
            raise RuntimeError(f'Worker failed: {log}; exit={result.returncode}')

    if not resume:
        execute(['--native-plan', '--directory', str(scratch)], scratch/'plan.log', 'DIFF01_PLAN_PASS', PLANNING_TIMEOUT_SECONDS)
    plan = json.loads((scratch/'plan.json').read_text())
    inventory = json.loads((scratch/'inventory.json').read_text())
    archive(output/'inventory.jsonl.gz', inventory)
    for index, task in enumerate(plan):
        task['task_file'] = str(scratch/f'task-{index}.json')
        write_json(Path(task['task_file']), task)
    # Every normal depth tier is sampled. Objective rooms rotate in native order;
    # Guardians are the first native Guardian, matching meas-07's selection.
    def jobs_for(sections, repeat, seeds=range(1, LOADOUTS+1)):
        jobs = []
        for section in sections:
            for seed in seeds:
                eligible = [t for t in plan if t['section'] == section and t['ladder_seed'] == seed]
                objectives = [t for t in eligible if t['category'] == 'objective']
                assert objectives
                selected = [t for t in eligible if t['category'] != 'objective']
                selected.append(objectives[(repeat + seed - 1) % len(objectives)])
                assert len(selected) in (5, 6), (section, seed, len(selected))
                for task in selected:
                    jobs.append(dict(task=task['task_file'], repeat=repeat,
                                     output=str(scratch/f"fight-s{section}-{task['category']}-t{task['tier']}-l{seed}-r{repeat}.jsonl")))
        return jobs

    contract['block_expected_sizes'] = {f's{section}-l{seed}': sum(t['section']==section and t['ladder_seed']==seed and t['category']!='objective' for t in plan)+1 for section in range(6) for seed in range(1,LOADOUTS+1)}
    batch_index = 1 + max([int(p.stem.split('-')[1]) for p in scratch.glob('batch-*.json') if p.stem.split('-')[1].isdigit()], default=-1)
    def run_jobs(jobs):
        nonlocal batch_index
        jobs = [j for j in jobs if not Path(j['output']).exists()]
        batches = []
        for offset in range(0, len(jobs), BATCH_SIZE):
            path = scratch/f'batch-{batch_index}.json'
            batch_index += 1
            write_json(path, jobs[offset:offset+BATCH_SIZE])
            batches.append(path)
        def batch(path):
            if time.time() >= deadline: return
            try:
                execute(['--jobs', str(path), '--deadline-unix', str(deadline)], path.with_suffix('.log'),
                        'DIFF01_BATCH_PASS', max(1, deadline-time.time()))
            except RuntimeError:
                if time.time() < deadline: raise
                print(f'DIFF01_DEADLINE partial_batch={path.name}', flush=True)
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            list(pool.map(batch, batches))

    pilot = jobs_for(range(6), 0, [1])
    pilot_started = time.time()
    run_jobs(pilot)
    pilot_elapsed = contract['pilot_elapsed_seconds'] if resume else time.time()-pilot_started
    projected_full = pilot_elapsed/len(pilot) * (6*LOADOUTS*6*REPEATS-len(pilot)) * PROJECTION_MARGIN
    sections = [0,2,4] if priority_only or projected_full > deadline-time.time() else list(range(6))
    contract['resumed_after_native_control_audit'] = resume
    contract.update(pilot_fights=len(pilot), pilot_elapsed_seconds=pilot_elapsed,
                    projected_remaining_full_seconds=projected_full, selected_sections=sections,
                    projected_remaining_priority_seconds=projected_full/2)
    write_json(output/'contract.json', contract)
    print(f'DIFF01_BUDGET sections={sections} pilot_seconds={pilot_elapsed:.1f} full_remaining_seconds={projected_full:.1f}', flush=True)
    for repeat in range(REPEATS):
        run_jobs(jobs_for(sections, repeat))
        print(f'DIFF01_REPEAT_DONE repeat={repeat} elapsed_seconds={time.time()-started:.1f}', flush=True)
        if time.time() >= deadline: break
    rows = [json.loads(p.read_text()) for p in sorted(scratch.glob('fight-*.jsonl')) if p.stat().st_size]
    assert len({(r['section'],r['category'],r['tier'],r['ladder_seed'],r['repeat']) for r in rows}) == len(rows)
    assert all(r['hp_before'] == r['max_hp'] and r['policy_sha256'] == contract['policy_sha256'] for r in rows)
    assert all(sha256(ROOT/p) == digest for p,digest in contract['source_sha256'].items())
    archive(output/'runs.jsonl.gz', rows)
    archive(output/'inputs.jsonl.gz', [{**{k:v for k,v in t.items() if k not in ('input_file','task_file')},
             'typed_payload_base64':base64.b64encode(Path(t['input_file']).read_bytes()).decode()} for t in plan])
    archive(output/'worker_logs.jsonl.gz', [dict(path=str(p),text=p.read_text()) for p in sorted(scratch.glob('*.log'))])
    write_json(output/'commands.json', sorted(commands,key=lambda c:c['started_unix']))
    contract.update(elapsed_seconds=time.time()-started, completed_fights=len(rows),
                    complete=all(Path(j['output']).exists() for repeat in range(REPEATS) for j in jobs_for(sections, repeat)),
                    artifact_sha256={p.name:sha256(p) for p in output.glob('*.gz')},
                    measurement_tool_sha256={str(p.relative_to(ROOT)):sha256(p) for p in sorted((ROOT/'tools/diff01').glob('*')) if p.suffix in ('.py','.gd')})
    write_json(output/'contract.json', contract)
    print(f"DIFF01_COLLECTION_DONE fights={len(rows)} wall_seconds={contract['elapsed_seconds']:.1f}", flush=True)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--scratch-dir', type=Path, required=True)
    parser.add_argument('--priority-only', action='store_true', help='Reproduce the documented s0/s2/s4 fallback grid')
    parser.add_argument('--resume', action='store_true', help='Continue unchanged-source interrupted collection within original wall deadline')
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    args = parser.parse_args()
    collect(args.scratch_dir.resolve(), args.output_dir.resolve(), args.resume, args.priority_only)
