#!/usr/bin/env python3
"""Run the atk-13 real-scene matrix in each naturally generated boss fight."""
import argparse
import ast
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[3]
TARGETS = ('tharokh','vyraketh','vaeloryx','iskaldra','zekarion','noctyrax','ashen_reaver','storm_cantor','gallows_roc','last_lamplighter','craghide','burrow_grub','briar_weaver')
FOLLOWUPS = {'vyraketh': {'kindle_ground','cinder_maw','crownfire'}, 'tharokh': {'faultline'}, 'vaeloryx': {'eye_of_storm'}}

def translated(receipt):
    anchor = ast.literal_eval(receipt['area_anchor'])
    origin = ast.literal_eval(receipt['area_planned_origin'])
    offset = tuple(a-b for a,b in zip(anchor,origin)) if receipt['area_kind']=='relative_to_source' else (0,0)
    return {tuple(a+b for a,b in zip(ast.literal_eval(tile),offset)) for tile in receipt['area_shown']}

def raw_tiles(tiles):
    return {ast.literal_eval(tile) for tile in tiles}

def report(out):
    moves = defaultdict(Counter)
    matrices = defaultdict(Counter)
    forecast_matrices = defaultdict(Counter)
    certain_matrices = defaultdict(Counter)
    totals = Counter()
    examples = []
    seeds_by_move = defaultdict(set)
    stamps = defaultdict(Counter)
    for path in sorted(out.glob('*/samples.jsonl')):
        rows = [json.loads(line) for line in path.read_text().splitlines()]
        assert any(r['kind']=='audit_totals' and r['decision_points']>0 for r in rows), path
        for row in rows:
            if row['kind'] == 'announced_red_sample':
                totals['announced_red_samples'] += 1
                totals['unannounced_red_drawn'] += len(row['unannounced_red'])
                if row['unannounced_red'] and len(examples) < 20:
                    examples.append({'path': str(path), 'unannounced_red': row['unannounced_red']})
            if row['kind'] == 'stamp_check':
                key = f"{row['source']}/{row['intent']}"
                counts = stamps[key]
                counts[row['card']+'_checks'] += 1
                counts['displaced_checks'] += row['offset'] != '(0, 0)'
                counts['forecast_mismatches'] += not row['forecast_matches']
                counts['source_prediction_disagreements'] += not row['source_matched_prediction']
                counts['oracle_mismatches'] += not row['oracle_matches_production']
                for receipt in row['receipts']:
                    counts['strike_checks'] += 1
                    expected = translated(receipt)-raw_tiles(receipt['area_inert'])
                    counts['strike_mismatches'] += expected != raw_tiles(receipt['area_struck'])
                    warned = raw_tiles(row['forecast_red'])
                    if receipt['area_kind']=='fixed_at_announcement': warned &= raw_tiles(receipt['area_shown'])
                    forecast_mismatch = warned-raw_tiles(receipt['area_inert']) != raw_tiles(receipt['area_struck'])
                    counts['end_to_end_forecast_mismatches'] += forecast_mismatch
                    counts['undisclosed_end_to_end_forecast_mismatches'] += forecast_mismatch and not row.get('forecast_disclosed',False)
            if row['kind'] == 'walked':
                for receipt in row.get('receipts', []):
                    if 'area_shown' in receipt: moves[f"{receipt['source']}/{receipt['intent']}"]['walked_executions'] += 1
                    if 'marked_landing' in receipt: totals['walked_grub_marked_landings'] += 1
            if row['kind'] != 'check': continue
            totals['alternatives'] += 1
            totals['oracle_mismatches'] += not row.get('oracle_matches_production',False)
            totals['ui_replica_mismatches'] += not row.get('replica_matches_ui', False)
            announcements = row.get('area01_announcements', {})
            def followups(receipts):
                selected = {}
                for h in receipts:
                    if h['intent'] not in FOLLOWUPS.get(h['source'],set()) or h['action'].get('type') not in ['melee','ranged'] or 'area_shown' in h:continue
                    key = (h['source'],h['intent'],h['clock'],h['action']['type'])
                    selected[key] = bool(h['hp'] or h['block'] or h['stoneskin'] or h['moved'] or h['statuses'])
                return selected
            if 'area01_followup_forecast_receipts' in row:
                actual = followups(row.get('receipts', []))
                predicted = followups(row['area01_followup_forecast_receipts'])
                for key in actual.keys() | predicted.keys():
                    label = '/'.join(key[:2])
                    cell = f'{int(predicted.get(key,False))}{int(actual.get(key,False))}'
                    forecast_matrices[label][cell] += 1
                    if not row.get('disclosed'):certain_matrices[label][cell] += 1
            first_area_clocks = {}
            for receipt in row.get('receipts', []):
                key = f"{receipt['source']}/{receipt['intent']}"
                if 'marked_landing' in receipt:
                    totals['grub_marked_landings'] += 1
                    totals['grub_marked_hit_mismatches'] += any(str(hit['target_tile']) != str(receipt['marked_landing']) for hit in receipt['marked_player_hits'])
                if 'area_shown' in receipt:
                    moves[key]['executed_alternatives'] += 1
                    seeds_by_move[key].add(path.parent.name.rsplit('-',1)[-1])
                    declared = set(map(str,receipt.get('area_expected',receipt['area_shown'])))
                    struck = set(map(str,receipt['area_struck']))
                    inert = set(map(str,receipt['area_inert']))
                    mismatch = declared-inert != struck
                    if 'area_kind' in receipt:
                        moves[key]['stamp_shape_mismatches'] += translated(receipt) != raw_tiles(receipt['area_expected'])
                    moves[key]['tile_mismatches'] += mismatch
                    owner = receipt['owner']
                    first_area_clock = first_area_clocks.setdefault(owner, receipt['clock'])
                    shown = announcements.get(owner, {})
                    moves[key]['relative_to_source' if receipt.get('area_kind') == 'relative_to_source' else 'fixed_at_announcement'] += 1
                    # A later cast can repeat the intent at the same anchor,
                    # with a footprint that is a subset of the earlier one.
                    if (receipt['clock'] == first_area_clock and shown.get('intent') == receipt['intent']
                        and set(map(str,receipt['area_shown'])) <= set(map(str, shown.get('original',shown.get('areas', []))))):
                        moves[key]['announced_at_turn_start'] += 1
                        missing = set(map(str,shown.get('areas',[])))-set(map(str,shown.get('rest_red',[])))
                        moves[key]['red_omissions'] += bool(missing)
                        moved = receipt.get('area_kind') == 'relative_to_source' and receipt.get('area_anchor') != shown.get('anchor')
                        moves[key]['natural_displacement_checks' if moved else 'no_displacement_checks'] += 1
                        if not moved:
                            # A Weaver can show its previous pending wall as
                            # well as this declaration. Compare this action's
                            # fixed marks, not both announcements as one hit.
                            current = receipt['area_shown'] if receipt.get('area_kind') == 'fixed_at_announcement' else shown.get('areas',[])
                            moves[key]['rest_strike_mismatches'] += set(map(str,current))-inert != struck
                    if mismatch and len(examples)<20: examples.append({'path':str(path),'point':row.get('point'),'receipt':receipt})
                if receipt['intent'] in FOLLOWUPS.get(receipt['source'],set()) and receipt['action'].get('type') in ['melee','ranged'] and 'area_shown' not in receipt:
                    hit = bool(receipt['hp'] or receipt['block'] or receipt['stoneskin'] or receipt['moved'] or receipt['statuses'])
                    told = receipt['owner'] in row.get('hover_owners' if row.get('mode')=='move' else 'red_owners',[])
                    matrices[key][f'{int(told)}{int(hit)}'] += 1
    result = {'totals':dict(totals),'moves':{k:{**dict(v),'seeds':sorted(seeds_by_move[k])} for k,v in sorted(moves.items())}, 'stamp_checks':{k:dict(v) for k,v in sorted(stamps.items())}, 'followup_red_matrices_11_10_01_00': {k:[v[x] for x in ['11','10','01','00']] for k,v in sorted(matrices.items())}, 'followup_action_forecast_matrices_11_10_01_00': {k:[v[x] for x in ['11','10','01','00']] for k,v in sorted(forecast_matrices.items())}, 'undisclosed_followup_action_forecast_matrices_11_10_01_00': {k:[v[x] for x in ['11','10','01','00']] for k,v in sorted(certain_matrices.items())}, 'examples':examples}
    (out/'report.json').write_text(json.dumps(result,indent=2)+'\n')
    for k,v in sorted(moves.items()): print(f"{k}: walked={v['walked_executions']} alternatives={v['executed_alternatives']} announced={v['announced_at_turn_start']} mismatches={v['tile_mismatches']} red_omissions={v['red_omissions']}")
    print(json.dumps(result['totals']))
    assert moves and not any(v['tile_mismatches'] or v['red_omissions'] or v['stamp_shape_mismatches'] or v['rest_strike_mismatches'] for v in moves.values()), 'Area truth mismatch: see report.json'
    assert not totals['oracle_mismatches'] and not totals['ui_replica_mismatches'] and not totals['grub_marked_hit_mismatches']
    assert not any(v['forecast_mismatches'] or v['strike_mismatches'] or v['oracle_mismatches'] for v in stamps.values()), 'Stamp targeting mismatch'
    assert not any(v['undisclosed_end_to_end_forecast_mismatches'] for v in stamps.values()), 'Undisclosed end-to-end stamp forecast mismatch'
    assert not any(v['10'] or v['01'] for v in certain_matrices.values()), 'Undisclosed follow-up forecast mismatch'
    rest_mismatches = sum(v['rest_strike_mismatches'] for v in moves.values())
    print(f'AREA01 ANNOUNCED MOVE STRIKE: {rest_mismatches} mismatches', flush=True)
    if totals['announced_red_samples']:
        print(f'AREA04 RED DRAWN FOR AN UNANNOUNCED MOVE: {totals["unannounced_red_drawn"]} '
              f'({totals["announced_red_samples"]} board samples)', flush=True)
        assert totals['unannounced_red_drawn'] == 0, 'Unannounced move red: see report.json'
    print('AREA01 TRUTH AUDIT PASS')

def main():
    p=argparse.ArgumentParser(__doc__)
    p.add_argument('command',choices=['run','report'])
    p.add_argument('--output-dir',type=Path,required=True)
    p.add_argument('--seeds',type=int,nargs='+',default=[1301,1302])
    p.add_argument('--targets',nargs='+',default=TARGETS)
    p.add_argument('--turns',type=int,default=36)
    p.add_argument('--workers',type=int,default=3)
    p.add_argument('--followups',action='store_true')
    p.add_argument('--stamps',action='store_true')
    p.add_argument('--task-id',default='area-01')
    a=p.parse_args(); out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=True)
    if a.command=='report': report(out);return
    def worker(pair):
        target,seed=pair; dest=out/f'{target}-{seed}';dest.mkdir(exist_ok=True)
        if (dest/'completed.json').exists():return
        env=dict(os.environ,AREA01_TARGET=target,ATK13_TIER='0',ATK13_TURNS=str(a.turns))
        script = 'stamp_audit.gd' if a.stamps else 'followup_audit.gd' if a.followups else 'audit.gd'
        cmd=[sys.executable,'tools/godot_task_runner.py','--task-id',a.task_id,'--timeout','1800','--stream','--','godot','--headless','--path','.', '--script','tools/atk13/area01/'+script,'--','--seed',str(seed),'--output-dir',str(dest),'--health','9999','--no-embrace','true']
        with (dest/'godot.log').open('w') as log: r=subprocess.run(cmd,cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT)
        if r.returncode:raise RuntimeError(f'Audit failed: {dest}/godot.log')
        (dest/'completed.json').write_text(json.dumps({'command':cmd,'environment':{k:env[k] for k in ['AREA01_TARGET','ATK13_TIER','ATK13_TURNS']}}))
        print(f'AREA01 AUDIT COMPLETE {target} seed={seed}',flush=True)
    with ThreadPoolExecutor(max_workers=a.workers) as pool:list(pool.map(worker,[(t,s) for t in a.targets for s in a.seeds]))
    report(out)
if __name__=='__main__':main()
