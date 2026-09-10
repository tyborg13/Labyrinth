"""Prepare or reopen an independently verified pre-action Gaoler combat fixture."""
from pathlib import Path
import argparse,subprocess,sys
ROOT=Path(__file__).resolve().parents[1];REPO=ROOT.parents[3]
p=argparse.ArgumentParser();p.add_argument('--intent',choices=['chain_reel','manacle_pin','cudgel_press','iron_guard'],default='chain_reel');p.add_argument('--launch',action='store_true');a=p.parse_args()
command=[sys.executable,str(REPO/'tools/inspection_fixture.py'),'--project',str(REPO),'--task-id','chainbound-gaoler-editable-cutout-and-gameplay-animation','--run-id','gaoler-cutout-'+a.intent.replace('_','-')+'-inspection','--scenario','combat','--enemy-types','chainbound_gaoler','--enemy-positions','3:3','--enemy-intents',a.intent,'--player-position','3:5','--player-hp','40','--player-max-hp','40','--hand','quick_stab,brace,sidestep_slash,bone_dart,patch_up','--summary','Gaoler prepared for '+a.intent.replace('_',' ')+'. Pass to see its action; move around it to inspect four facing directions.']
if a.launch:command.append('--launch')
raise SystemExit(subprocess.call(command,cwd=REPO))
