"""Copy this case's reviewed closure into Tharokh-owned production paths."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--rest-dir',type=Path)
    args=parser.parse_args()
    case=Path(__file__).resolve().parent
    root=case.parents[3]
    destination=root/'assets/units/tharokh_cutout'
    config=json.loads((case/'cutout.json').read_text())
    for view in ['front','rear']:
        layout=json.loads((case/config['layouts'][view]).read_text())
        for part in layout['parts']+layout.get('joint_meshes',[]):
            source=case/part['file']
            target=destination/view/source.name
            target.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(source,target)
            Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
            part['file']=view+'/'+source.name
        rest=destination/view/'rest.png'
        if args.rest_dir:
            shutil.copy2(args.rest_dir/(view+'_rest.png'),rest)
        elif not rest.exists():
            shutil.copy2(case/'source'/(view+'_registered.png'),rest)
        Path(str(rest)+'.import').write_text('[remap]\n\nimporter="keep"\n')
        layout['rest_source']=view+'/rest.png'
        layout['rest_source_sha256']=hashlib.sha256(rest.read_bytes()).hexdigest()
        (destination/(view+'.json')).write_text(json.dumps(layout,indent=2)+'\n')
    shutil.copy2(case/'motion.gd',root/'scripts/tharokh_cutout/motion.gd')

if __name__=='__main__':main()
