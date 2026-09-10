"""Copy this case's selected paint, mesh topology and sampler to owned runtime paths."""
from pathlib import Path
import json, shutil, hashlib
root=Path(__file__).resolve().parent; repo=root.parents[3]
production=repo/'assets/units/lightning_wisp_cutout'
config=json.loads((root/'cutout.json').read_text())
for view,path in config['layouts'].items():
 layout=json.loads((root/path).read_text())
 for item in layout['parts']+layout.get('joint_meshes',[]):
  source=root/item['file']; target=production/view/source.name
  target.parent.mkdir(parents=True,exist_ok=True); shutil.copyfile(source,target)
  Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
  item['file']=f'{view}/{source.name}'
 rest=production/view/'rest.png'; shutil.copyfile(root/'source'/f'{view}_rest_baked.png',rest)
 Path(str(rest)+'.import').write_text('[remap]\n\nimporter="keep"\n')
 layout['rest_source']=f'{view}/rest.png'; layout['rest_source_sha256']=hashlib.sha256(rest.read_bytes()).hexdigest()
 (production/f'{view}.json').write_text(json.dumps(layout,indent=2)+'\n')
shutil.copyfile(root/'motion.gd',repo/'scripts/lightning_wisp_cutout/motion.gd')
