"""Copy the Cinder Droplet v01 closure into its production-owned namespace.

This does not register other enemies or modify combat rules. A fresh asset
comparison probe must verify these copies and the native rest bakes afterward.
"""
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
CASE = Path(__file__).resolve().parent / "v01"
DEST = ROOT / "assets/units/cinder_droplet_cutout"


def main():
    config=json.loads((CASE/'cutout.json').read_text())
    for facing,path in config['layouts'].items():
        layout=json.loads((CASE/path).read_text())
        folder=DEST/facing
        folder.mkdir(parents=True,exist_ok=True)
        used={'rest.png','rest.png.import'}
        for part in layout['parts']+layout.get('joint_meshes',[]):
            source=CASE/part['file']
            name=source.name
            shutil.copyfile(source,folder/name)
            Path(str(folder/name)+'.import').write_text('[remap]\n\nimporter="keep"\n')
            part['file']=facing+'/'+name
            used.update([name,name+'.import'])
        for path in folder.iterdir():
            if path.name not in used:
                path.unlink() # Only this enemy's superseded generated draft copies.
        layout.pop('shared_material_field',None)
        layout['rest_source']=facing+'/rest.png'
        (DEST/(facing+'.json')).write_text(json.dumps(layout,indent=2)+'\n')
    shutil.copyfile(CASE/'motion.gd',ROOT/'scripts/cinder_droplet_cutout/motion.gd')


if __name__=='__main__':
    main()
