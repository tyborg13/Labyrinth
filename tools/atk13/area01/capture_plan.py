#!/usr/bin/env python3
"""Print exact native cel proof commands from completed area-01 audit saves."""
import argparse
import json
from pathlib import Path
import shlex
ROOT=Path(__file__).resolve().parents[3]
CASES=(('tharokh','bedrock_breath'),('zekarion','skybreak'))
def main():
    p=argparse.ArgumentParser(__doc__)
    p.add_argument('--audit-dir',type=Path,required=True)
    p.add_argument('--output-dir',type=Path,required=True)
    a=p.parse_args()
    print('# Native cel proof: real Updraft targeting; relative breath and fixed sky marks.')
    for enemy,intent in CASES:
        selected=None
        for path in sorted(a.audit_dir.glob(f'{enemy}-*/samples.jsonl')):
            if not path.with_name('completed.json').exists():continue
            for row in map(json.loads,path.read_text().splitlines()):
                if row['kind'] != 'stamp_check' or row['card'] != 'updraft' or row['source'] != enemy or row['intent'] != intent or row['offset'] == '(0, 0)' or not row['source_matched_prediction']:continue
                if row.get('receipts'):selected=Path(row['repro'])
                if selected:break
            if selected:break
        if not selected:raise RuntimeError(f'No executed natural proof save: {enemy}/{intent}')
        out=a.output_dir/f'{enemy}-{intent}.png'
        args=['python3','tools/visual_probe_runner.py','--project',str(ROOT),'--godot',str(ROOT/'tools/rd07/native_capture.sh'),'--no-headless','--display-driver','macos','--audio-driver','Dummy','--rendering-driver','metal','--rendering-method','mobile','--timeout','300','--expect-size','1920x1080','--proof-contract','tools/atk13/area01/capture_contract.json','--result-manifest',str(out.with_suffix('.manifest.json')),'res://tools/atk13/area01/capture.gd','--task-id','area-01','--','--save-dir',str(selected),'--enemy',enemy,'--intent',intent,'--out',str(out)]
        print(f'cd {shlex.quote(str(ROOT))} && LABYRINTH_CEL_LOOK=all '+shlex.join(args))
if __name__=='__main__':main()
