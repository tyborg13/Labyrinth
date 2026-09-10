"""Copy this case into its actor-specific production closure; no Git writes."""
from pathlib import Path
import argparse,json,shutil
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument("--baked-rest",type=Path,required=True,help="Native asset-probe folder containing front_rest.png and rear_rest.png")
args=parser.parse_args()
case=Path(__file__).resolve().parents[1];repo=case.parents[3];out=repo/'assets/units/zekarion_cutout'
for facing in ['front','rear']:
 layout=json.loads((case/f'layouts/{facing}_skinned.json').read_text());dest=out/facing;dest.mkdir(exist_ok=True)
 for group in ['parts','joint_meshes']:
  for p in layout[group]:
   old=case/p['file'];p['file']=f'{facing}/{old.name}';shutil.copyfile(old,out/p['file'])
   Path(str(out/p['file'])+'.import').write_text('[remap]\n\nimporter="keep"\n')
 shutil.copyfile(args.baked_rest/f'{facing}_rest.png',dest/'rest.png');(dest/'rest.png.import').write_text('[remap]\n\nimporter="keep"\n')
 layout['rest_source']=f'{facing}/rest.png'
 layout['landmarks']['maw']=[68,140] if facing=='front' else [round(178*243/255+6),round(85*243/255+3)]
 layout['landmarks']['strike']=[118,202] if facing=='front' else [round(193*243/255+6),round(187*243/255+3)]
 (out/f'{facing}.json').write_text(json.dumps(layout,indent=2)+'\n')
shutil.copyfile(case/'motion.gd',repo/'scripts/zekarion_cutout/motion.gd')
