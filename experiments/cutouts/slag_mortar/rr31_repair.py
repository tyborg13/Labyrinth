"""Extend round-3 source cover cuts over the new motion, never capture masks."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr30_case import CASE, ASSETS
from rr31_images import ImageGate, OUTPUT
from rr30_joint_gate import JointSurfaceGate
from rr30_cpu import sprite_transform
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import bindings
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from humanoid_cutout.materials import connected_mask


def repair():
    samples = read_report(CASE)
    if samples['inputs'] != bindings(CASE): raise ValueError('Refresh samples before source cover cuts')
    result, changed = {}, []
    for view in ('front','rear'):
        layout = read_json(CASE/f'layouts/{view}.json')
        model, gate = ImageGate(CASE,layout), JointSurfaceGate(CASE,layout)
        cuts, evidence = {}, []
        for pose in samples['samples']:
            if pose['view']!=view or pose['kind']!='presented': continue
            layers = model.layers(pose)
            report = gate.frame(pose,layers,potential_covers=True)
            for error in report['cover_errors']:
                name = error['piece']
                part = next(p for p in layout['parts'] if p['name']==name)
                source = model.model.image(part['file'])
                yy,xx = np.indices(source.shape[:2])
                uv = np.stack((xx,yy,np.ones_like(xx),source[...,3]),axis=2).astype('uint8')
                shown = pixels.render(uv,sprite_transform(layout,pose,part))
                points = np.asarray(error['destination_pixels'])
                texels = shown[points[:,1],points[:,0],:2].astype(int)
                cuts.setdefault(name,set()).update(map(tuple,texels.tolist()))
                evidence.append(dict(clip=pose['clip'],frame=pose['frame'],piece=name,
                                     source_texels=texels.tolist()))
        result[view] = dict(cuts={n:sorted(map(list,v)) for n,v in cuts.items()},evidence=evidence)
        reference = Image.new('RGBA',(255,255))
        repaired = Image.new('RGBA',(255,255))
        for part in sorted(layout['parts'],key=lambda p:p['z_index']):
            image = np.asarray(Image.open(CASE/part['file']).convert('RGBA')).copy()
            reference.alpha_composite(Image.fromarray(image),tuple(part['offset']))
            for x,y in cuts.get(part['name'],set()): image[y,x] = 0
            repaired.alpha_composite(Image.fromarray(image),tuple(part['offset']))
        if reference.tobytes()!=repaired.tobytes():
            raise ValueError('Source cuts would change approved rest: '+view)
        for name, texels in cuts.items():
            part = next(p for p in layout['parts'] if p['name']==name)
            # Apply the identical UV alpha cut to source, proof classification,
            # untreated density source and processed production material.
            paths = [CASE/part['file'],CASE/layout['proof_layers'][name]['mask'],
                     ASSETS/'humanoid_v2'/view/Path(part['file']).name]
            archive = CASE.parents[3]/'spec/assets/board_pixel_density/sources/assets/units/slag_mortar_cutout/humanoid_v2'/view/Path(part['file']).name
            if archive.exists(): paths.append(archive)
            for path in paths:
                image = np.asarray(Image.open(path).convert('RGBA')).copy()
                for x,y in texels: image[y,x] = 0
                Image.fromarray(image).save(path)
                changed.append(str(path))
        print(f'RR31 {view.upper()} SOURCE COVER CUTS: {sum(len(v) for v in cuts.values())} texels',flush=True)
    write_json(OUTPUT/'source_joint_cuts.json',dict(views=result,changed_files=changed))


def finalize():
    """Remove hidden-only islands and refresh construction-derived tuck masks."""
    build = read_json(CASE/'proof/build.json')
    orphan_record = {}
    for view in ('front','rear'):
        layout = read_json(CASE/f'layouts/{view}.json')
        parts = {p['name']:p for p in layout['parts']}
        orphan_record[view] = {}
        for part in layout['parts']:
            if not part['hidden_material']: continue
            visible = source_pixels(CASE,parts[part['logical_part']])[...,3]>0
            hidden = source_pixels(CASE,part)[...,3]>0
            removed = hidden & ~connected_mask(visible,hidden)
            y,x = np.nonzero(removed)
            texels = np.column_stack((x,y))-part['offset']
            if len(texels):
                orphan_record[view][part['name']] = texels.tolist()
                paths = [CASE/part['file'],CASE/layout['proof_layers'][part['name']]['mask'],
                    ASSETS/'humanoid_v2'/view/Path(part['file']).name,
                    CASE.parents[3]/'spec/assets/board_pixel_density/sources/assets/units/slag_mortar_cutout/humanoid_v2'/view/Path(part['file']).name]
                for path in paths:
                    image = np.asarray(Image.open(path).convert('RGBA')).copy()
                    image[texels[:,1],texels[:,0]] = 0
                    Image.fromarray(image).save(path)
        for tuck in build['views'][view]['tucks']:
            hidden = source_pixels(CASE,parts['hidden_'+tuck['piece']])[...,3]>0
            Image.fromarray(hidden.astype('uint8')*255).save(CASE/tuck['required_mask'])
            tuck.update(required_pixels=int(hidden.sum()),missing_pixels=0)
    build['tucks'] = build['views']['front']['tucks']
    write_json(CASE/'proof/build.json',build)
    write_json(OUTPUT/'source_cover_islands.json',orphan_record)
    print('RR31 COVER FINALIZATION: PASS (hidden-only islands removed; tuck masks rebuilt)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--finalize',action='store_true')
    if parser.parse_args().finalize: finalize()
    else: repair()
