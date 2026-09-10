"""Copy this case's runtime closure; native rest bakes are required for promotion."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[3]


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--native-rest-dir',type=Path,required=True)
    args=parser.parse_args()
    config=json.loads((ROOT/'cutout.json').read_text())
    target=PROJECT/'assets/units/iskaldra_cutout'
    for facing,relative in config['layouts'].items():
        rest=args.native_rest_dir/(facing+'_rest.png')
        if not rest.is_file():raise SystemExit('Missing native rest: '+str(rest))
        layout=json.loads((ROOT/relative).read_text())
        files={}
        for part in layout['parts']:
            files[part['file']]=facing+'/'+part['name']+'.png'
        for part in layout['parts']+layout.get('joint_meshes',[]):
            source=part['file'];destination=target/files[source]
            destination.parent.mkdir(parents=True,exist_ok=True)
            shutil.copy2(ROOT/source,destination)
            destination.with_suffix('.png.import').write_text('[remap]\n\nimporter="keep"\n')
            part['file']=files[source]
        rest_out=target/facing/'rest.png'
        shutil.copy2(rest,rest_out)
        rest_out.with_suffix('.png.import').write_text('[remap]\n\nimporter="keep"\n')
        layout['rest_source']=facing+'/rest.png'
        layout['rest_source_sha256']=hashlib.sha256(rest_out.read_bytes()).hexdigest()
        (target/(facing+'.json')).write_text(json.dumps(layout,indent=2)+'\n')
    shutil.copy2(ROOT/'motion.gd',PROJECT/'scripts/iskaldra_cutout/motion.gd')


if __name__=='__main__':main()
