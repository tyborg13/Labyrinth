#!/usr/bin/env python3
"""Print exact native capture commands, choosing real saved visible intents.

Run this on completed census output. Nothing executes unless the owner runs
this printed shell script. Does not install or modify a game inspection save.
"""
import argparse
import json
from pathlib import Path
import shlex

PROJECT=Path(__file__).resolve().parents[2]
ROOT=Path('/private/tmp/labyrinth_codex/atk-13/audit')
REQUIRED={'storm_cantor':['lay_the_choir','peal','broken_rhythm','call_the_spark'],
          'lightning_wisp':['spark_dart','static_lash','blinding_arc']}

def commands(root,label):
    found={};rule=None
    for p in sorted((root/label).glob('*/samples.jsonl')):
        if not (p.parent/'completed.json').exists():continue
        for line in p.read_text().splitlines():
            row=json.loads(line)
            if row.get('kind')!='check' or row['mode']!='pass':continue
            for enemy in row['context']['enemies']:
                key=(enemy['type'],enemy['intent'])
                if enemy['visible'] and key[0] in REQUIRED and key[1] in REQUIRED[key[0]]:found.setdefault(key,row['repro'])
                if key==('storm_cantor','peal') and enemy['visible'] and any(r.get('source','').startswith('peal_') for r in row['receipts']):rule=rule or row['repro']
    missing=[(e,i) for e,ids in REQUIRED.items() for i in ids if (e,i) not in found]
    if missing:raise SystemExit(f'Missing real visible intent saves: {missing}')
    if rule is None:raise SystemExit('Missing real Peal rule save')
    result=[]
    for enemy,ids in REQUIRED.items():
        for intent in ids:
            for view in ['intent','portrait']:
                result.append([found[(enemy,intent)],view,f'{enemy}_{intent}_{view}','--enemy',enemy,'--intent',intent])
        result.append([found[(enemy,ids[0])],'prebattle',f'{enemy}_prebattle','--enemy',enemy])
    for view in ['rule','rule_loop','playback']:result.append([rule,view,f'cantor_{view}'])
    return result

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root',type=Path,default=ROOT)
    parser.add_argument('--label',default='census')
    args=parser.parse_args()
    print('#!/bin/sh\nset -eu')
    for values in commands(args.root,args.label):
        print('cd '+shlex.quote(str(PROJECT))+' && sh tools/atk13/native_capture.sh '+' '.join(shlex.quote(v) for v in values))
if __name__=='__main__':main()
