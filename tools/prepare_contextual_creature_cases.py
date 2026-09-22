"""Prepare portable current-production creature contextual animation cases.

This recipe intentionally does not replay historical builders. Production is the
source of every layout, PNG and sampler; historical cases supply clip contracts.
The pre-pass sampler is retained from BASELINE_COMMIT for exact pose regression.
Use a fresh --output directory; generated paint and proof stay outside git.
"""
from pathlib import Path
import argparse, hashlib, json, re, shutil, subprocess, sys
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import baseline, image_records, write_json
VERSIONS = {'crawler':'v01','harrier':'v02','stone_warden':'v04','bile_bloomer':'v01','lightning_wisp':'v01','cinder_ooze':'v01','cinder_droplet':'v01'}
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, default=ROOT / 'output/contextual-animation-polish/creatures/cases')
parser.add_argument('--contextual-only', action='store_true', help='Final focused proof after the full baseline cycle audit; crawler retains all actions because its hip weights changed')
args = parser.parse_args()
BASELINE_COMMIT = '0d104bcdc907bdc17f581f9e25c68bf872eec4bf'
for character, version in VERSIONS.items():
    folder = args.output.resolve() / character
    folder.mkdir(parents=True, exist_ok=False)
    source = ROOT / f'assets/units/{character}_cutout'
    old = json.loads((ROOT / f'experiments/cutouts/{character}/{version}/cutout.json').read_text())
    config = {key: old[key] for key in ['schema_version','character_id','source_size','canvas_size','source_offset','default_facing','clips','rigid_bones','contact_feet']}
    if 'draw_order_parts' in old: config['draw_order_parts'] = old['draw_order_parts']
    config.update(layouts={f:f'layouts/{f}.json' for f in ['front','rear']},motion='motion.gd',sources=['source/baseline_motion.gd','source/renderer.gd'])
    source_files = set()
    for facing, relative in config['layouts'].items():
        original = source / f'{facing}.json'
        layout = json.loads(original.read_text()); source_files.add(original)
        def copy_image(value):
            image = ROOT / value.removeprefix('res://') if value.startswith('res://') else source / value
            local = Path('assets') / image.relative_to(source)
            target = folder / local; target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(image,target); source_files.add(image)
            Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
            return str(local)
        for item in image_records(layout): item['file'] = copy_image(item['file'])
        if layout.get('rest_source'): layout['rest_source'] = copy_image(layout['rest_source'])
        write_json(folder/relative,layout)
    motion = ROOT / f'scripts/{character}_cutout/motion.gd'
    renderer = ROOT / f'scripts/{character}_cutout/renderer.gd'
    (folder/'source').mkdir(exist_ok=True)
    shutil.copyfile(motion,folder/'motion.gd')
    (folder/'source/baseline_motion.gd').write_text(subprocess.check_output(['git','show',BASELINE_COMMIT+':scripts/'+character+'_cutout/motion.gd'],cwd=ROOT,text=True))
    shutil.copyfile(renderer,folder/'source/renderer.gd')
    source_files.update([motion,renderer])
    text=renderer.read_text()
    for clip, constant in [('walk','WALK_CYCLE_SECONDS'),('retreat','WALK_CYCLE_SECONDS'),('idle','IDLE_CYCLE_SECONDS')]:
        if clip in config['clips']:
            duration=float(re.search(rf'const {constant}: float = ([0-9.]+)',text)[1]); config['clips'][clip]['duration']=duration
    config['source_baseline']={'kind':'enemy_production','commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'files':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(source_files)}}
    config['clips']['hit']={'frames':24,'duration':0.36,'loop':False}
    config['clips']['death']={'frames':40,'duration':0.64232,'loop':False}
    config['source_baseline']['comparison_commit']=BASELINE_COMMIT
    if args.contextual_only and character != 'crawler':
        config['clips']={key:value for key,value in config['clips'].items() if key in ['idle','hit','death']}
        config['clips']['idle']['preview_cycles']=1
    write_json(folder/'cutout.json',config); baseline(folder)
    print(character, folder)
