#!/usr/bin/env python3
"""Matched bos-04 fuel-boundary measurements using the bos-02/03 harnesses."""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import subprocess
import sys
from encounter_bot import BOSS_IDS, read_report, compress_report, summarize
from guardian_rules_measurement import GUARDIANS

ROOT = Path(__file__).resolve().parents[1]
# Offline execution defaults; unchanged sample sizes and policy from bos-02/03.
WORKERS = 6
TIMEOUT_SECONDS = 14400

def measure(source: Path, output: Path, workers: int, lightning_only: bool = False) -> None:
    output.mkdir(parents=True, exist_ok=True)
    jobs = []
    for boss in BOSS_IDS:
        jobs.append((boss, 'tools/dragon_rule_measurement.gd', ['--revision','7','--tier','3','--cohort','boss','--boss-id',boss,'--runs','50','--seed','1']))
    for guardian in GUARDIANS:
        jobs.append((guardian, 'tools/guardian_rules_measurement.gd', ['--guardian',guardian,'--variant','after','--runs-per-tier','30']))
    for tier in (1,2,3):
        jobs.append((f'warband-{tier}', 'tools/bos04_warband_measurement.gd', ['--tier',str(tier)]))
    if lightning_only:
        jobs = [(name, script, args + (['--rule','lightning_storm'] if name.startswith('warband') else []))
                for name, script, args in jobs if name in ('zekarion','storm_cantor','warband-1','warband-2','warband-3')]
        jobs.append(('snare-lightning','tools/bos04_snare_measurement.gd',[]))
    def one(job):
        name, script, args = job
        destination = output / (name+'.json')
        command = [sys.executable,str(ROOT/'tools/godot_task_runner.py'),'--task-id','bos-04','--timeout',str(TIMEOUT_SECONDS),'--stream','--','godot','--headless','--path',str(source),'--script',script,'--',*args,'--output',str(destination)]
        with (output/(name+'.log')).open('w') as stream:
            result = subprocess.run(command,cwd=ROOT,stdout=stream,stderr=subprocess.STDOUT)
        if result.returncode: raise RuntimeError(f'{name}: exit {result.returncode}; see {output/(name+".log")}')
        compress_report(destination, output/(name+'.json.gz'))
        print(f'BOS04 MEASUREMENT: PASS {name}',flush=True)
    with ThreadPoolExecutor(max_workers=workers) as pool: list(pool.map(one,jobs))

def report(before: Path, after: Path, destination: Path, lightning_only: bool = False) -> None:
    lines = ['# bos-04 matched fuel-boundary measurements','','Production bos-02/03 policy and samples. No tuning. Guardian: 30 per natural tier; dragon: 50 tier-3; Warband: 30 per rule per tier. Beat → hero is actual HP lost, as in the original harnesses.','','| Fight | N | Before | After | Change (pp) | Beat → hero before | After |','|---|---:|---:|---:|---:|---:|---:|']
    summaries = {}
    names = ('zekarion','storm_cantor','warband-1','warband-2','warband-3','snare-lightning') if lightning_only else (*BOSS_IDS,*GUARDIANS,'warband-1','warband-2','warband-3')
    if lightning_only:
        lines[0] = '# bos-04 feedback 1: round 0 → beat conductor eligibility'
        lines[2] += ' Lightning fights only; Snare: 30 per natural tier.'
        lines[4] += ' Beats fired before → after |'
        lines[5] += '---|'
    for name in names:
        pair = [read_report(folder/(name+'.json.gz')) for folder in (before,after)]
        if lightning_only:
            expected_count = 50 if name=='zekarion' else 90 if name in ('storm_cantor','snare-lightning') else 30
            assert all(len(raw['results'])==expected_count for raw in pair), (name,'incomplete cohort')
        for field in ('defaults','decks','revision','cohort'): assert pair[0][field] == pair[1][field], (name,field)
        groups = [''] if not name.startswith('warband') else sorted({r['rule'] for r in pair[0]['results']})
        if lightning_only and name=='snare-lightning': groups = ['','tier-1','tier-2','tier-3']
        for group in groups:
            rows = [[r for r in raw['results'] if not group or (r['tier']==int(group[5:]) if group.startswith('tier-') else r['rule']==group)] for raw in pair]
            fields = ('seed','tier','section_index','coord','travel_dir','special_variant','guardian_id','boss_id')
            assert [[{k:r.get(k) for k in fields} for r in rs] for rs in rows][0] == [[{k:r.get(k) for k in fields} for r in rs] for rs in rows][1], name
            stats = [summarize(rs) for rs in rows]
            hero = [sum(r.get('dragon_metrics',r.get('metrics',{})).get('damage_to_player',r.get('metrics',{}).get('beat_damage_to_hero',0)) for r in rs) for rs in rows]
            label = name+('/'+group if group else '')
            delta = 100*(stats[1]['win_rate']-stats[0]['win_rate'])
            summaries[label] = {'before':stats[0],'after':stats[1],'change_pp':delta,'beat_to_hero':hero}
            line = f'| {label} | {len(rows[0])} | {stats[0]["win_rate"]:.1%} | {stats[1]["win_rate"]:.1%} | {delta:+.1f}{" *" if abs(delta)>3 else ""} | {hero[0]} | {hero[1]} |'
            if lightning_only:
                beats = [sum(r.get('dragon_metrics',r.get('metrics',{})).get('beats_fired',0) for r in rs) for rs in rows]
                summaries[label]['beats_fired'] = beats
                line += f' {beats[0]} → {beats[1]} |'
            lines.append(line)
    lines += ['','* marks every absolute win-rate change greater than 3 percentage points.']
    destination.write_text('\n'.join(lines)+'\n')
    destination.with_suffix('.json').write_text(json.dumps(summaries,indent=2)+'\n')
    print(f'BOS04 MATCHED REPORT: PASS ({len(summaries)} groups)')

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root',type=Path,default=ROOT)
    parser.add_argument('--output-dir',type=Path)
    parser.add_argument('--workers',type=int,default=WORKERS)
    parser.add_argument('--lightning-only',action='store_true')
    parser.add_argument('--before',type=Path)
    parser.add_argument('--after',type=Path)
    parser.add_argument('--report',type=Path)
    args=parser.parse_args()
    if args.output_dir: measure(args.source_root.resolve(),args.output_dir.resolve(),args.workers,args.lightning_only)
    if args.report: report(args.before,args.after,args.report,args.lightning_only)
