"""Read current native previews for proportion guidance during cloth fitting."""
from copy import deepcopy
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from PIL import Image
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.fitting import measure
from spec.art_identity.maquettes.blender.fit_delivery import registered_parts, overlay_parts


def main(folders, capture_override=None):
    for folder in map(Path, folders):
        spec = json.loads((folder/'spec_native.json').read_text())
        recipe = json.loads((folder/'measurements.json').read_text())
        capture = Path(capture_override) if capture_override else folder/'proof/quality_r3'
        result = {}
        overlays = Image.new('RGBA',(512,256))
        for view in ('front','rear'):
            configured = deepcopy(spec)
            configured['fit'].update(recipe['fit'][view])
            raster = load_render(spec,capture,view)
            fit,comparison = measure(configured,Image.open(PROJECT/recipe['sources'][view]).convert('RGBA'),raster=raster)
            source = Image.open(PROJECT/recipe['sources'][view]).convert('RGBA')
            parts = registered_parts(Image.open(capture/(view+'_parts.png')).convert('RGBA'),fit,source.size)
            overlays.paste(overlay_parts(source,parts,.4),(0 if view=='front' else 256,0))
            result[view] = {'iou': fit['iou'], 'gate':recipe['fit'][view]['gate']['iou_min'],
                            'visible_pixels':{name:int((raster.owners==i).sum()) for i,name in enumerate(raster.names)}}
        overlays.save(capture/'preview_fit_overlay.png')
        (capture/'preview_proportion.json').write_text(json.dumps(result,indent=2)+'\n')
        print('PROPORTION_PREVIEW: '+folder.name+'; '+json.dumps(result))


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('folders',nargs='+')
    parser.add_argument('--capture')
    args=parser.parse_args()
    if args.capture and len(args.folders)!=1:
        parser.error('--capture requires one figure')
    main(args.folders,args.capture)
