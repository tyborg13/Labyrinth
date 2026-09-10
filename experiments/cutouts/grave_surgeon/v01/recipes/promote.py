"""Copy the selected Grave Surgeon case closure into production-owned paths."""
import hashlib
import json
import shutil
from pathlib import Path

case=Path(__file__).resolve().parents[1]
root=case.parents[3]
destination=root/'assets/units/grave_surgeon_cutout'
config=json.loads((case/'cutout.json').read_text())
records=[]
for facing,path in config['layouts'].items():
    layout=json.loads((case/path).read_text())
    (destination/facing).mkdir(parents=True,exist_ok=True)
    remap={}
    for part in layout['parts']:
        source=case/part['file']
        relative=facing+'/'+part['name']+'.png'
        target=destination/relative
        shutil.copyfile(source,target)
        Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
        remap[part['file']]=relative
        records.append({'source':str(source.relative_to(root)),'production':str(target.relative_to(root)),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
        part['file']=relative
    for mesh in layout.get('joint_meshes',[]):
        mesh['file']=remap[mesh['file']]
    # Initial source rest is replaced with the native assembled bake after QA.
    baked=case/'bakes'/ (facing+'_rest.png')
    rest=baked if baked.exists() else case/'source'/(facing+'_registered.png')
    shutil.copyfile(rest,destination/facing/'rest.png')
    (destination/facing/'rest.png.import').write_text('[remap]\n\nimporter="keep"\n')
    layout['rest_source']=facing+'/rest.png'
    layout['rest_source_sha256']=hashlib.sha256((destination/facing/'rest.png').read_bytes()).hexdigest()
    (destination/(facing+'.json')).write_text(json.dumps(layout,indent=2)+'\n')
scripts=root/'scripts/grave_surgeon_cutout'
scripts.mkdir(parents=True,exist_ok=True)
shutil.copyfile(case/'motion.gd',scripts/'motion.gd')
(case/'recipes/production_copy.json').write_text(json.dumps(records,indent=2)+'\n')
