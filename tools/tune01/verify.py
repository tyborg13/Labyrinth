#!/usr/bin/env python3
"""Validate collected tune-01 proof; no new permanent gameplay test module."""
import hashlib
import json
from pathlib import Path
from report import BASE, OUT, ROOT, archive, cost, key, kind, read


def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    contract=json.loads((OUT/'search_contract.json').read_text())
    assert contract['status']!='running','Wait for the bounded search to finish'
    assert contract['elapsed_seconds']<=contract['wall_seconds_limit']
    assert contract['max_workers']<=4
    assert contract['background_priority_verified']
    assert contract['policy_sha256']==sha(ROOT/'tools/encounter_bot.gd')
    assert contract['measurement_tool_sha256']['tools/tune01/measure.gd']==sha(ROOT/'tools/tune01/measure.gd')
    for path,digest in contract['source_sha256'].items():
        if path!='data/difficulty_tiers.json':assert sha(ROOT/path)==digest,path
    commands=json.loads((OUT/'commands.json').read_text())
    timeline=[]
    for c in commands:
        assert 'tools/godot_task_runner.py --task-id tune-01' in c['command']
        timeline += [(c['started_unix'],1),(c['started_unix']+c['elapsed_seconds'],-1)]
        assert c['returncode']==0 or c['started_unix']+c['elapsed_seconds']>=contract['deadline_unix']
        text=Path(c['log']).read_text()
        assert 'TUNE01_PRIORITY thread=LOW macos_qos=UTILITY start_result=0' in text
    peak=active=0
    for _,delta in sorted(timeline):active+=delta;peak=max(peak,active)
    assert peak<=4
    rows=[]
    for stage in ['normal','probe','damage1','damage2','damage3','confirm',*[f'postconfirm_damage{d}{suffix}' for d in range(1,4) for suffix in ['', '_confirm']]]:
        path=OUT/f'{stage}.jsonl.gz'
        if path.exists():
            rs=read(path);rows.extend(rs)
            assert len({(r['section'],r['ladder_seed'],r['room_coord'],r['repeat']) for r in rs})==len(rs),stage
    assert len(rows)==contract['completed_fights']
    for r in rows:
        assert r['max_hp']==r['hp_before']>0
        assert r['start_count']==r['start_summoned']+r['start_non_summoned']==len(r['enemy_roster'])
        assert r['start_non_summoned']<=5
        assert r['policy_sha256']==contract['policy_sha256']
        assert r['hp_lost']>=0 and cost(r)>=0
        assert r['combat_seed_input']==r['ladder_seed']+r['repeat']*1000003
        if r['category']!='normal':
            requested=r['dials'][f"{r['section']}:{kind(r)}"]
            assert r['difficulty_stats']['hp_percent']==requested[0]
            assert r['difficulty_stats']['damage_bonus']==requested[1]
    normals={key(r):r for r in rows if r['category']=='normal'}
    unpaired=[r for r in rows if r['category']!='normal' and key(r) not in normals]
    # A deadline can interrupt a slow control after a parallel target finishes.
    # Keep that raw fight, expose its missing pair, and exclude it from gaps.
    assert not unpaired or contract['status']=='budget reached'
    archive(OUT/'unpaired_targets.jsonl.gz',unpaired)
    tiers=json.loads((ROOT/'data/difficulty_tiers.json').read_text())
    placeholders=[]
    for entries in tiers['tiers'].values():
        for entry in entries.values():
            assert len(entry['hp_percent'])==len(entry['damage_bonus'])==6
            assert all(80<=x<=175 for x in entry['hp_percent'])
            for value in entry['damage_bonus']:
                if isinstance(value,str):assert value.startswith('TODO_DESIGN_');placeholders.append(value)
                else:assert 0<=value<=3
    scratch=Path('/private/tmp/labyrinth_codex/tune-01-search')
    archive(OUT/'tasks.jsonl.gz',[dict(path=str(p),sha256=sha(p),task=json.loads(p.read_text())) for p in sorted(scratch.glob('task-*.json'))]+[dict(path=str(p),sha256=sha(p),task=json.loads(p.read_text())) for p in sorted(scratch.glob('control-*.json'))]+[dict(path=str(p),sha256=sha(p),task=json.loads(p.read_text())) for p in sorted(scratch.glob('normal-*.json'))])
    archive(OUT/'batches.jsonl.gz',[dict(path=str(p),sha256=sha(p),jobs=json.loads(p.read_text())) for p in sorted(scratch.glob('batch-*.json')) if any(c['log']==str(p.with_suffix('.log')) for c in commands)])
    archive(OUT/'native_inputs.jsonl.gz',read(BASE/'inputs.jsonl.gz'))
    result=dict(fights=len(rows),peak_workers=peak,unpaired_targets=len(unpaired),placeholders=placeholders,proposal_sha256=sha(ROOT/'data/difficulty_tiers.json'),analysis_tool_sha256={str(p.relative_to(ROOT)):sha(p) for p in (ROOT/'tools/tune01').glob('*.py')},artifacts={p.name:sha(p) for p in OUT.glob('*.gz')})
    (OUT/'verification.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'TUNE01_VERIFY: PASS fights={len(rows)} peak_workers={peak} unpaired_targets={len(unpaired)} placeholders={len(placeholders)}')

if __name__=='__main__':main()
