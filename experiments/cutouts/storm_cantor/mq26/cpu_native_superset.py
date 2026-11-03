"""Strict location/provenance comparison for every native component rule."""
import ast
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from humanoid_cutout.gates import matrix
from humanoid_cutout.canvas import for_case
from humanoid_cutout.native_frames import load_frame
from maquette_motion import pixels


def contains(a,b):
    return a[0]<=b[0] and a[1]<=b[1] and a[2]>=b[2] and a[3]>=b[3]


def report(case,capture,manifest,cpu,spaces,native_errors):
    errors={};missing=[];certified=[]
    for row in cpu['errors']:errors.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    poses={(r['view'],r['clip'],r['frame']):r for r in read_json(case/'proof/raster_samples.json')['samples']}
    layouts={v:read_json(case/f'layouts/{v}.json') for v in ('front','rear')}
    pieces={(r['view'],r['clip'],r['frame'],r['name']):r for r in manifest['pieces']}
    for row in spaces:
        key=(row['view'],row['clip'],row['frame']);candidates=[e for e in errors.get(key,[]) if e['kind']=='unmatched_detached_paint']
        for component in row.get('unmatched_components',[]):
            found=any(contains(e['component']['bbox'],component['bbox']) and e['component']['pixel_count']>=component['pixel_count'] for e in candidates)
            if not found:
                for candidate in candidates:
                    if candidate['component']['bbox']!=component['bbox']:continue
                    name=candidate['logical_part'];layout=layouts[key[0]]
                    part=next((p for p in layout['parts'] if p['name']==name),None)
                    if part is None or name in {m['name'] for m in layout['joint_meshes']}:continue
                    record=pieces.get((*key,name))
                    if record is None:continue
                    with for_case(case):
                        source=np.asarray(Image.open(case/part['file']).convert('RGBA'))
                        expected=pixels.render(source,matrix(poses[key]['parts'][name]['transform']),with_ties=True)
                        actual=np.asarray(load_frame(capture/record['file']).convert('RGBA'))
                        if pixels.native_frame_matches(actual,expected.default,expected):
                            certified.append({'view':key[0],'clip':key[1],'frame':key[2],'part':name,
                                'bbox':component['bbox'],'native_pixels':component['pixel_count'],
                                'cpu_pixels':candidate['component']['pixel_count'],
                                'rule':'CPU rejects same location; native rigid surface matches exact nearest-source UV tie candidates.'})
                            found=True;break
            if not found:missing.append({'view':key[0],'clip':key[1],'frame':key[2],'kind':'unmatched_detached_paint','bbox':component['bbox']})
    for message in native_errors:
        if 'floating pieces:' not in message and 'released held item ' not in message:continue
        identity,detail=message.split(': ',1)
        try:key=tuple(ast.literal_eval(identity))
        except (ValueError,SyntaxError,TypeError):missing.append({'kind':'held_release','message':message});continue
        if not any(e['kind']=='held_release' and e['message']==detail for e in errors.get(key,[])):
            missing.append({'view':key[0],'clip':key[1],'frame':key[2],'kind':'held_release','message':detail})
    from humanoid_cutout.native_exceptions import METRIC_RULES
    for message in native_errors:
        for metric,rule in METRIC_RULES.items():
            if metric=='stray_components' or not message.endswith(': '+rule):continue
            identity=message.rsplit(': ',1)[0]
            try:key=tuple(ast.literal_eval(identity))
            except (ValueError,SyntaxError,TypeError):continue
            if not any(e['kind']=='paint_metric' and e['metric']==metric for e in errors.get(key,[])):
                missing.append({'view':key[0],'clip':key[1],'frame':key[2],'kind':'paint_metric','metric':metric})
    return {'ok':not missing,'missing':missing,'certified_rigid_sampling_differences':certified}


def pocket_report(cpu,native_holes):
    """Compare rejected locations, keeping measured raster sizes separate.

    A 68-pixel CPU rejection and 70-pixel native rejection at the identical
    pocket are one caught defect. Raw air diagnostics cannot satisfy this:
    the CPU must itself reject a joint hole at that location.
    """
    index={};missing=[];differences=[]
    for row in cpu['errors']:
        if row['kind']=='joint_hole':index.setdefault((row['view'],row['clip'],row['frame']),[]).append(row['source_space'])
    for row in native_holes:
        for hole in row['pockets']:
            candidates=index.get((row['view'],row['clip'],row['frame']),[])
            found=[c for c in candidates if c['bbox']==hole['bbox'] or (contains(c['bbox'],hole['bbox']) and c['pixel_count']>=hole['pixel_count'])]
            if not found:missing.append(dict(view=row['view'],clip=row['clip'],frame=row['frame'],pocket=hole))
            elif found[0]['pixel_count']!=hole['pixel_count']:
                differences.append(dict(view=row['view'],clip=row['clip'],frame=row['frame'],bbox=hole['bbox'],cpu_pixels=found[0]['pixel_count'],native_pixels=hole['pixel_count']))
    return {'ok':not missing,'missing':missing,'pixel_count_differences':differences}
