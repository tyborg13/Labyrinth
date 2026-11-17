#!/usr/bin/env python3
"""Focused evidence-accounting checks (not a default project test module)."""
import argparse
import json
from pathlib import Path
from reporting import analyze, rows, RESOURCE_FIELDS
from capture_plan import commands
import inventory

ROOT=Path('/private/tmp/labyrinth_codex/atk-13/audit')

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    args=parser.parse_args()
    report=json.loads((args.root/'all/report.json').read_text())
    assert report['oracle_mismatches']==0
    assert report['receipt_hp_exceeds_actual']==0
    assert report['integrity']['replica_mismatches']==0
    for tier in ['1','2','3']:
        for key in ['lay_the_choir','peal','broken_rhythm','call_the_spark']:
            assert report['visible_coverage'][tier]['storm_cantor:'+key]>=20,(tier,key,'insufficient visible coverage')
            assert report['walked'][tier][key]>=20,(tier,key,'insufficient executed walk coverage')
        assert any(name.startswith('tier-'+tier+'-') and name.endswith('-hp0') for name in report['runs'])
    checks=0
    for label in ['census','real-health']:
        for path in sorted((args.root/label).glob('*/samples.jsonl')):
            assert (path.parent/'completed.json').exists(),f'Incomplete run {path.parent}'
            for row in rows(path):
                if row['kind']!='check' or row['mode'] not in ['pass','move']:continue
                checks+=1
                finding=analyze(row)
                exclusive=[v for k,v in finding.items() if k!='reaimed']
                for field in RESOURCE_FIELDS:
                    expected=sum(s.get(field,0) for s in row['actual']['slices'] if not(field=='block' and s['actor']=='turn_start'))
                    accounted=sum(v['effects'][field] for v in exclusive)
                    assert accounted==expected,(path,row['point'],row['mode'],field,expected,accounted)
                # Own walk is not harm; slices can move without any loss/status.
                actual_hit=any(any(s.get(k,0)>0 for k in RESOURCE_FIELDS if not(k=='block' and s['actor']=='turn_start')) or s.get('statuses') or s.get('moved') and s['actor']!='move' for s in row['actual']['slices'])
                assert bool(actual_hit)==any(v['hit'] for v in exclusive),(path,row['point'],'unclassified hit')
                for name in ['run.save','progression.json','combat_state.txt']:
                    assert (Path(row['repro'])/name).is_file(),(row['repro'],name)
                if not row['disclosed']:
                    assert row['shown']['hp']==row['actual']['hp'],(path,row['point'],'certain Health mismatch')
    assert checks==report['checks'],('stale aggregate',checks,report['checks'])
    values=inventory.rows()
    assert len(values)==len({r['name'] for r in values})
    assert all(r['model'] in ['Locked','Follows','Neither'] for r in values)
    # Every scoped catalog definition appears once, including compound moves.
    expected=sum(any(inventory.scoped(a) for a in i['actions']) or bool(i.get('restore_braziers')) for e in inventory.ENEMIES.values() for i in e.get('intents',[]))
    expected+=sum(bool(e.get('death_burst')) for e in inventory.ENEMIES.values())+len(inventory.RULES)
    assert len(values)==expected
    native=commands(args.root,'census')
    assert len(native)==19 and all((Path(c[0])/'run.save').is_file() for c in native)
    print(f'ATK13 EVIDENCE CHECKS: PASS ({checks} alternatives; 3 tiers × 4 intents >=20 visible/executed; {len(values)} inventory rows; {len(native)} native commands)')

if __name__=='__main__':main()
