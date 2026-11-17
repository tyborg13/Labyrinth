#!/usr/bin/env python3
"""Focused measurement validity and report-statistics checks; no game changes."""
import argparse
import base64
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
from report import read,write_report,wilson,outside,matched,count_stats
from inventory import expanded_max,crowded_catalog,knob_rows,legacy_rosters

ROOT = Path(__file__).resolve().parents[2]


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(output):
    contract=json.loads((output/'contract.json').read_text())
    assert 1<=contract['max_workers']<=4
    assert contract['elapsed_seconds']<=contract['wall_seconds_limit'], 'Wall budget exceeded'
    for path,digest in contract['source_sha256'].items(): assert sha(ROOT/path)==digest,path
    for path,digest in contract['measurement_tool_sha256'].items(): assert sha(ROOT/path)==digest,path
    for path,digest in contract['artifact_sha256'].items(): assert sha(output/path)==digest,path
    commands=json.loads((output/'commands.json').read_text())
    worker_logs={r['path']:r['text'] for r in read(output/'worker_logs.jsonl.gz')}
    events=[]
    for command in commands:
        if command['returncode']!=0:
            assert not contract['complete'] and command['started_unix']+command['elapsed_seconds']>=contract['deadline_unix']
            assert 'timed out' in worker_logs.get(command['log'],'').lower(), 'Unexpected worker failure'
        assert 'tools/godot_task_runner.py --task-id diff-01' in command['command']
        events.extend([(command['started_unix'],1),(command['started_unix']+command['elapsed_seconds'],-1)])
    active=0
    peak=0
    for _,change in sorted(events):
        active+=change
        peak=max(peak,active)
    assert peak<=4,'Engine worker cap exceeded'
    raw=read(output/'runs.jsonl.gz')
    assert len(raw)==contract['completed_fights']
    keys=[(r['section'],r['category'],r['tier'],r['ladder_seed'],r['repeat']) for r in raw]
    assert len(set(keys))==len(keys),'Duplicate observation'
    inputs=read(output/'inputs.jsonl.gz')
    indexed={(r['section'],r['ladder_seed'],r['room_coord']):r for r in inputs}
    assert len(indexed)==len(inputs)
    for row in inputs: assert hashlib.sha256(base64.b64decode(row['typed_payload_base64'])).hexdigest()==row['input_sha256']
    entries=read(output/'entry_loadouts.jsonl.gz')
    assert len(entries)==48
    for entry in entries:
        assert hashlib.sha256(base64.b64decode(entry['typed_payload_base64'])).hexdigest()==entry.get('input_sha256',entry.get('sha256'))
    assert {(r['ladder_seed'],r['section']) for r in entries}=={(s,c) for s in range(1,9) for c in range(6)}
    ladders=read(output/'ladders.jsonl.gz')
    assert {r['seed'] for r in ladders}==set(range(1,9))
    assert len(ladders)==8 and all(r['completed_ladder'] and r['policy_sha256']==contract['policy_sha256'] for r in ladders)
    for row in raw:
        key=(row['section'],row['ladder_seed'],row['room_coord'])
        assert key in indexed
        original=indexed[key]
        assert row['input_sha256']==original['input_sha256']
        for key in ['section','tier','ladder_seed','category','objective_kind','room_coord','start_count','start_summoned']:
            assert row[key]==original[key],key
        assert row['hp_before']==row['max_hp']>0
        assert row['policy_sha256']==contract['policy_sha256']
        assert row['combat_seed_input']==row['ladder_seed']+row['repeat']*1000003
        assert isinstance(row['won'],bool) and 1<=row['turns']<=30
        assert row['hp_lost']>=0
        assert row['start_count']==row['start_non_summoned']+row['start_summoned']
    groups=defaultdict(list)
    for r in raw: groups[(r['section'],r['ladder_seed'],r['repeat'])].append(r)
    blocks=[b for b in groups.values() if len(b)==contract['block_expected_sizes'][f"s{b[0]['section']}-l{b[0]['ladder_seed']}"]]
    for block in blocks:
        assert Counter(r['category'] for r in block)==Counter(normal=len(block)-3,objective=1,guardian=1,boss=1)
        normal={r['tier']:r for r in block if r['category']=='normal'}
        assert set(normal) in ({1,2,3},{1,3})
        for r in block:
            if r['tier'] in normal: assert r['max_hp']==normal[r['tier']]['max_hp']
    expected={(section,seed,repeat) for section in contract['selected_sections'] for seed in range(1,9) for repeat in range(8)}
    complete=all(key in groups and len(groups[key])==contract['block_expected_sizes'][f's{key[0]}-l{key[1]}'] for key in expected)
    assert complete==contract['complete'],'Completion flag mismatch'
    census=read(output/'census.jsonl.gz')
    assert set(r['scenario'] for r in census)=={'first_eligible','late_k6','native_prefix'}
    census_keys=[(r['ladder_seed'],r['room_coord'],r['scenario'],r['fight_number']) for r in census]
    assert len(census_keys)==len(set(census_keys))
    for row in census:
        assert row['start_count']==row['start_non_summoned']+row['start_summoned']==len(row['roster'])
    original_counts={(r['ladder_seed'],r['room_coord']):r for r in read(output/'inventory.jsonl.gz')}
    for r in census:
        if r['scenario']=='first_eligible' and not r['mystery']:
            old=original_counts[(r['ladder_seed'],r['room_coord'])]
            for key in ['start_count','start_non_summoned','start_summoned']: assert r[key]==old[key],(r,key)
    assert read(output/'oversized_rooms.jsonl.gz')==[r for r in census if r['start_count']>5]
    assert read(output/'crowded_catalog.jsonl.gz')==crowded_catalog()
    assert read(output/'legacy_rosters.jsonl.gz')==legacy_rosters()
    enemies=json.loads((ROOT/'data/enemies.json').read_text())
    assert all(unit in enemies for r in legacy_rosters() for unit in r['units'])
    assert len(knob_rows())>=29
    # Statistical boundary and matching tests use deliberately asymmetric depth
    # mixtures so an unweighted section baseline cannot accidentally pass.
    assert abs(wilson(0,64)[1]-5.662405979280534)<1e-10
    assert outside(-10,'objective')==0 and outside(-15,'objective')==0
    assert outside(0,'guardian')==15 and outside(-40,'boss')==5
    a=dict(section=0,tier=1,ladder_seed=1,repeat=0,won=False,category='guardian')
    control={**a,'won':True,'category':'normal'}
    assert matched([a],{(0,1,1,0):control})==[1,'100.0%','-100.0','75.0']
    assert count_stats([dict(start_count=6,start_non_summoned=4,start_summoned=2)])==[1,'6/6/6','100.0%','4/4/4','0.0%','2/2/2']
    fixture=dict(element_regulars={'fire':['a','b']},biome_groups={'fire':[dict(units=['c','d','e'])]})
    assert expanded_max(dict(units=['x','$element','$biome','y']),fixture,'fire','fire',6)==6
    assert expanded_max(dict(units=['x','$element','$biome','y']),fixture,'fire','fire',4)==0
    before=(output/'report.md').read_bytes()
    write_report(output)
    assert before==(output/'report.md').read_bytes(),'Report must reproduce byte-for-byte'
    summary=json.loads((output/'summary.json').read_text())
    assert summary['reported_fights']==sum(len(b) for b in blocks)
    print(f"DIFF01_ARTIFACT_VALIDITY_PASS raw_fights={len(raw)} complete_blocks={len(blocks)} inputs={len(inputs)} entries=48 source_hashes=true full_health=true paired_depth=true max_concurrency={peak} target_complete={str(complete).lower()}")
    print(f"DIFF01_COUNT_INVENTORY_PASS census_rows={len(census)} exhaustive_compositions={len(crowded_catalog())} source_anchors={len(knob_rows())}")
    print('DIFF01_STATISTICS_PASS Wilson=true band_edges=true matched_weights=true summon_separation=true token_capacity=true report_reproducible=true')

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output',type=Path)
    verify(parser.parse_args().output.resolve())
