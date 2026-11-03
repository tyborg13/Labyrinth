"""Native capture acceptance, shared-scale comparison sheet and source seals."""
import csv
import io
import json
from pathlib import Path
import shutil
import numpy as np
from PIL import Image,ImageDraw

from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha,write
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from ..acceptance import OCCLUSIONS
from .checks import numeric_contract,captured_pose_gates
from ..recipe import FOLDER as BASE,PROJECT

DELIVERY_DEFAULTS = {'tile_px':1088,'caption_px':32,'height_px':1248,'sole_px':1164,
                     'background_rgba':[24,24,24,255],'budget_bytes':6_000_000,
                     'alpha_threshold':128,'caption_padding_px':8,'webp_method':6}


def inspect(spec,capture,write_outputs=True):
    capture = Path(capture); read_manifest(capture,digest(spec),('full',))
    native = json.loads((capture/'mq19_native.json').read_text())
    build = json.loads((capture/'build_report.json').read_text())
    if native.get('spec_hash')!=digest(spec) or native.get('native_mesh_hash')!=build['combined_mesh_hash']:
        raise ValueError('Stale mq-19 opened native observations')
    coverage = {}; missing = []; cloak_coverage = {}
    table = io.StringIO(); writer = csv.writer(table,lineterminator='\n')
    writer.writerow(['view','part','solo_pixels','pure_owner_pixels','explicit_occlusion'])
    for view in ('front','rear'):
        raster = load_render(spec,capture,view)
        rgba = np.asarray(Image.open(capture/(view+'_parts.png')).convert('RGBA'))
        coverage[view] = part_coverage(spec,raster,rgba)
        for name,row in coverage[view].items():
            occlusion = OCCLUSIONS[view].get(name) if row['pure_owner_pixels']==0 else ''
            row['explicit_occlusion'] = occlusion
            if not row['solo_pixels'] or row['clipped_at_canvas'] or (not row['pure_owner_pixels'] and not occlusion):
                missing.append(view+':'+name)
            writer.writerow([view,name,row['solo_pixels'],row['pure_owner_pixels'],occlusion])
        torso = raster.masks['torso']; cloak = raster.owners==raster.names.index('cloak')
        cloak_coverage[view] = {'torso_silhouette_pixels':int(torso.sum()),
            'cloak_over_torso_pixels':int((torso&cloak).sum()),
            'share_of_torso_silhouette':float((torso&cloak).sum()/max(1,torso.sum()))}
    joint_gates = captured_pose_gates(spec,json.loads((capture/'joints_px.json').read_text()),native)
    joint_gates['checks'] = {k:bool(v) for k,v in joint_gates['checks'].items()}
    checks = {'native_joints_match_capture':joint_gates['passed'],'all_pose_rows':numeric_contract(spec,native),'opened_native':native.get('passed') is True and all(native.get('checks',{}).values()),
        'complete_labels':not missing,'design_resolved':not spec['mq19']['diagnostic_only'],
        'native_mutations':native.get('mutations')=={'detached_staff':True,'flattened_finger':True}}
    result = {'passed':all(checks.values()),'checks':checks,'spec_hash':digest(spec),
        'native_mesh_hash':build['combined_mesh_hash'],'native_probe_sha256':sha(capture/'mq19_native.json'),
        'capture_manifest_sha256':sha(capture/'capture_manifest.json'),'per_part_coverage':coverage,
        'unexplained_parts':missing,'cloak_coverage':cloak_coverage,
        'pose_values':native['pose_values'],'staff_top_over_H':native['staff_top_over_H'],
        'shoulder_and_turn':native['shoulder_and_turn'],'capture_joint_gates':joint_gates}
    if write_outputs:
        (capture/'per_part_coverage.csv').write_text(table.getvalue())
        lines = ['| Requirement | Value | Target | Native | Tolerance | Result |','|---|---|---:|---:|---:|---|']
        for r in native['pose_values']:
            lines.append(f"| {r['requirement']} | {r['name']} | {r['target']:.9f} | {r['measured']:.9f} | {r['tolerance']} | {'PASS' if r['passed'] else 'FAIL'} |")
        lines += ['',f"Top staff tine / inherited H: {native['staff_top_over_H']:.9f} (brief: about 1.0 H).",
            '',native['definition'],'',json.dumps(native['shoulder_and_turn'],sort_keys=True),
            '',json.dumps(cloak_coverage,sort_keys=True)]
        (capture/'pose_table.md').write_text('\n'.join(lines)+'\n')
        baseline = spec['mq19']['baseline_proportions']
        # These calipers come from opened native vertices/endpoints, keeping
        # inherited H/L rather than renormalizing the shorter posed stature.
        observed = native['proportions']
        lines = ['| Proportion | Current art / H | mq-17 / H | mq-19 / H |','|---|---:|---:|---:|']
        for name,row in baseline.items():
            lines.append(f"| {name} | {row['source']:.9f} | {row['native']:.9f} | {observed[name]:.9f} |")
        (capture/'proportion_table.md').write_text('\n'.join(lines)+'\n')
        result['proof_text_sha256'] = {n:sha(capture/n) for n in ('pose_table.md','proportion_table.md','per_part_coverage.csv')}
        write(capture/'mq19_acceptance.json',result)
    return result


def review_sheet(capture,debug=False):
    capture = Path(capture); d = DELIVERY_DEFAULTS; size = d['tile_px']
    refs = [('Old art',PROJECT/'assets/units/storm_cantor.png',4),
        ('mq-17 front',BASE/'delivery/front_clay.png',1),('mq-19 front',capture/'front_clay.png',1),
        ('mq-17 rear',BASE/'delivery/rear_clay.png',1),('mq-19 rear',capture/'rear_clay.png',1)]
    if debug: refs=[(title+' [DEBUG]' if title.startswith('mq-19') else title,path,scale) for title,path,scale in refs]
    canvas = Image.new('RGBA',(len(refs)*size,d['height_px']),tuple(d['background_rgba']))
    draw = ImageDraw.Draw(canvas); inputs = []
    for k,(title,path,scale) in enumerate(refs):
        im = Image.open(path).convert('RGBA')
        if scale!=1: im = im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
        edge = int(np.argwhere(np.asarray(im)[:,:,3]>=d['alpha_threshold'])[:,0].max())+1
        y = d['sole_px']-edge
        if y<d['caption_px'] or y+im.height>canvas.height: raise ValueError('Comparison sheet clips its source')
        canvas.alpha_composite(im,(k*size+(size-im.width)//2,y)); draw.text((k*size+d['caption_padding_px'],d['caption_padding_px']),title,fill='white')
        inputs.append({'path':str(path.resolve().relative_to(PROJECT)) if path.is_relative_to(PROJECT) else path.name,
                       'sha256':sha(path),'display_scale':scale,'y_px':y})
    canvas.save(capture/'contact_sheet.webp',lossless=True,exact=True,method=d['webp_method'])
    if not np.array_equal(np.asarray(canvas),np.asarray(Image.open(capture/'contact_sheet.webp').convert('RGBA'))):
        raise ValueError('Contact-sheet codec changed pixels')
    write(capture/'contact_sheet.json',{'inputs':inputs,'sheet_sha256':sha(capture/'contact_sheet.webp'),
        'registration':'All native clays 1:1 on inherited mq-17 scale. Old art 4x nearest. Common sole baseline; translation only.'})


def rear_cloak_crop(capture):
    """A 2x nearest pixel crop of the native rear, registered by its solo mask."""
    capture=Path(capture)
    source=capture/'rear_clay.png';mask_path=capture/'rear_solo_cloak.png'
    mask=np.asarray(Image.open(mask_path).convert('RGBA'))[:,:,3]>=DELIVERY_DEFAULTS['alpha_threshold']
    ys,xs=np.where(mask)
    if not len(xs):raise ValueError('Rear cloak solo is empty')
    im=Image.open(source).convert('RGBA');padding=8
    box=[max(0,int(xs.min())-padding),max(0,int(ys.min())-padding),
         min(im.width,int(xs.max())+padding+1),min(im.height,int(ys.max())+padding+1)]
    crop=im.crop(box);crop=crop.resize((crop.width*2,crop.height*2),Image.Resampling.NEAREST)
    crop.save(capture/'rear_cloak_2x.webp',lossless=True,exact=True,method=6)
    if not np.array_equal(np.asarray(crop),np.asarray(Image.open(capture/'rear_cloak_2x.webp').convert('RGBA'))):
        raise ValueError('Cloak crop codec changed pixels')
    write(capture/'rear_cloak_2x.json',{'source':'rear_clay.png','source_sha256':sha(source),
        'mask_sha256':sha(mask_path),'box_px':box,'scale':2,'resampling':'nearest',
        'crop_sha256':sha(capture/'rear_cloak_2x.webp')})


def front_far_crop(capture):
    """2x native front crop showing the staff hand, body and far cloth edge."""
    capture=Path(capture);source=capture/'front_clay.png'
    im=Image.open(source).convert('RGBA')
    joints=json.loads((capture/'joints_px.json').read_text())['front']
    hand=joints['hand_far'];shoulder=joints['shoulder_far'];ankle=joints['ankle_far']
    box=[max(0,int(min(hand[0],shoulder[0]))-64),max(0,int(shoulder[1])-48),
         min(im.width,int(joints['pelvis'][0])+32),min(im.height,int(ankle[1])+24)]
    crop=im.crop(box).resize(((box[2]-box[0])*2,(box[3]-box[1])*2),Image.Resampling.NEAREST)
    crop.save(capture/'front_far_2x.webp',lossless=True,exact=True,method=6)
    write(capture/'front_far_2x.json',{'source':'front_clay.png','source_sha256':sha(source),
        'box_px':box,'scale':2,'resampling':'nearest','crop_sha256':sha(capture/'front_far_2x.webp')})
