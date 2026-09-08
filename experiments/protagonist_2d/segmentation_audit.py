"""Audit semantic source ownership independently of rest reconstruction.

Landmarks/material fences are hand-reviewed source coordinates, not points
sampled from the generated masks. Source preservation alone does not establish
correct anatomy. The color maps and per-part sheets support visual inspection.
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess

from PIL import Image, ImageChops, ImageDraw, ImageFont

import cutout_assets as front
import rear_assets as rear

HERE = Path(__file__).resolve().parent
BASELINE = '6bcc01b2d8b0e05729fe1d217a1006c902ba24e5'
# The expected owner of each point was determined from the painted source.
LANDMARKS = {
 'front': {
  'head': [(130,35),(122,59)], 'scarf': [(125,84),(122,82)],
  'torso': [(128,99),(138,106)], 'hips': [(117,121),(143,137),(101,145),(103,135)],
  'cape_full': [(155,88),(193,148),(105,81),(101,92),(148,96)],
  'arm_r': [(100,102),(98,108)], 'forearm_r': [(94,118),(91,123)],
  'sword_hand_r': [(94,128),(54,163)], 'arm_l': [(165,121),(170,123)],
  'forearm_l': [(167,134),(166,146),(166,150)], 'hand_l': [(163,154),(173,155)],
  'thigh_r': [(115,151),(122,158),(99,153),(133,167),(133,168)],
  'shin_r': [(118,173),(119,172)], 'foot_r': [(101,189),(121,183)],
  'thigh_l': [(145,159),(156,170),(169,175)], 'shin_l': [(167,190),(160,183)],
  'foot_l': [(168,210),(168,216)],
 },
 'rear': {
  'head': [(124,33),(147,55)], 'scarf': [(123,70),(110,78),(106,78),(107,79)],
  'cape_full': [(115,79),(140,73),(90,70),(77,125),(60,159),(119,116)],
  'torso': [(126,125),(136,131)], 'hips': [(122,146),(128,140)],
  'arm_r': [(147,93),(151,104)], 'forearm_r': [(157,125),(169,139)],
  'sword_hand_r': [(168,153),(219,199)], 'thigh_l': [(103,162),(103,166)],
  'shin_l': [(98,171),(97,184)], 'foot_l': [(94,200),(104,198)],
  'thigh_r': [(137,164),(133,151)], 'shin_r': [(145,173),(141,186)],
  'foot_r': [(140,216),(160,210)],
 },
}
# Adjacent anatomical pieces may share only source material at their joints.
SHARED_PAIRS = [
 ('head','scarf'),('scarf','torso'),('torso','hips'),
 ('torso','arm_r'),('arm_r','forearm_r'),('forearm_r','sword_hand_r'),
 ('arm_l','forearm_l'),('forearm_l','hand_l'),
 ('hips','thigh_r'),('thigh_r','shin_r'),('shin_r','foot_r'),
 ('hips','thigh_l'),('thigh_l','shin_l'),('shin_l','foot_l'),
]
PALETTE = {
 'head':'#e86667', 'scarf':'#efcc56', 'cape_full':'#82ae68', 'torso':'#e59651',
 'hips':'#cfdf83', 'arm_r':'#66bcdc', 'forearm_r':'#779de5',
 'sword_hand_r':'#cc8ce8', 'arm_l':'#39b795', 'forearm_l':'#63847d',
 'hand_l':'#dea0c7', 'thigh_r':'#d6b381', 'shin_r':'#a897db',
 'foot_r':'#7ad5ba', 'thigh_l':'#c6849c', 'shin_l':'#8eb5d3', 'foot_l':'#bdbbc4',
}


def _labels(masks):
    labels = {}
    for name, mask in masks.items():
        for y in range(mask.height):
            for x in range(mask.width):
                if mask.getpixel((x,y)):
                    if (x,y) in labels:
                        raise AssertionError(f'Exclusive masks overlap at {(x,y)}')
                    labels[x,y] = name
    return labels


def _components(mask):
    unseen = {(x,y) for y in range(mask.height) for x in range(mask.width) if mask.getpixel((x,y))}
    result = []
    while unseen:
        queue, points = [unseen.pop()], []
        while queue:
            x,y = queue.pop(); points.append((x,y))
            for dx in (-1,0,1):
                for dy in (-1,0,1):
                    neighbor = x+dx,y+dy
                    if neighbor in unseen:
                        unseen.remove(neighbor); queue.append(neighbor)
        result.append({'pixels':len(points), 'bbox':[min(x for x,y in points), min(y for x,y in points),
                                                   max(x for x,y in points)+1,max(y for x,y in points)+1]})
    return sorted(result,key=lambda c:(-c['pixels'],c['bbox']))


def _baseline(source, facing):
    path = 'experiments/protagonist_2d/' + ('cutout_assets.py' if facing=='front' else 'rear_assets.py')
    text = subprocess.check_output(['git','show',BASELINE+':'+path],cwd=HERE,text=True)
    polygons = next(ast.literal_eval(n.value) for n in ast.parse(text).body if isinstance(n,ast.Assign)
                    and any(isinstance(t,ast.Name) and t.id=='POLYGONS' for t in n.targets))
    available, masks = source.getchannel('A').copy(), {}
    for name, points in polygons:
        owned = ImageChops.multiply(front._polygon(source.size,points),available)
        masks[name] = owned; available = ImageChops.subtract(available,owned)
    core = None if facing=='front' else [(108,78),(134,77),(143,87),(141,104),(149,132),
                                        (140,151),(125,154),(109,148),(104,119),(99,88)]
    front._assign_outline_fragments(masks,available,core)
    if facing=='rear':
        strip = ImageChops.multiply(masks['torso'],front._polygon(source.size,[(108,78),(116,78),(116,79),(108,79)]))
        masks['torso'] = ImageChops.subtract(masks['torso'],strip)
        masks['scarf'] = ImageChops.lighter(masks['scarf'],strip)
    return _labels(masks)


def _proof_images(source, masks, facing):
    output = HERE/'assets'/facing
    font_path = Path('/System/Library/Fonts/Supplemental/Arial.ttf')
    label_font = ImageFont.truetype(str(font_path),18) if font_path.exists() else ImageFont.load_default()
    heading_font = ImageFont.truetype(str(font_path),24) if font_path.exists() else ImageFont.load_default()
    ownership = Image.new('RGBA',source.size)
    for name,mask in masks.items(): ownership.paste(PALETTE[name],(0,0,*source.size),mask)
    ownership.save(output/'ownership_map.png')
    board = Image.new('RGBA',(1920,1080),(40,42,46,255)); draw = ImageDraw.Draw(board)
    for index,(label,im) in enumerate([('Unchanged painted source',source),('Exclusive part ownership',ownership)]):
        x=28+index*800
        board.alpha_composite(im.resize((765,765),Image.Resampling.NEAREST),(x,40))
        draw.text((x,10),f'{facing.upper()}  |  {label}',fill='white',font=heading_font)
        for coordinate in range(0,255,20):
            draw.text((x+coordinate*3,810),str(coordinate),fill='#bdc1c8')
        draw.text((x,836),'Source coordinates in pixels; nearest-neighbor enlargement',fill='#bdc1c8')
    for index,name in enumerate(masks):
        x=28+(index%6)*310; y=895+(index//6)*52
        draw.rectangle((x,y,x+18,y+18),fill=PALETTE[name])
        draw.text((x+28,y),name,fill='white',font=label_font)
    draw.text((1650,70),'Every source pixel',fill='white')
    draw.text((1650,94),'has one base owner.',fill='white')
    draw.text((1650,134),'Joint overlaps are',fill='#bdc1c8')
    draw.text((1650,158),'audited separately.',fill='#bdc1c8')
    board.save(output/'ownership_overview.png')
    names=list(masks); cols=5; cell_w,cell_h=340,285
    sheet=Image.new('RGBA',(cols*cell_w,((len(names)+cols-1)//cols)*cell_h),(52,54,58,255))
    draw=ImageDraw.Draw(sheet)
    for i,name in enumerate(names):
        cut=front._masked(source,masks[name]); cut=cut.crop(cut.getbbox())
        scale=min(5,310/cut.width,240/cut.height)
        cut=cut.resize((round(cut.width*scale),round(cut.height*scale)),Image.Resampling.NEAREST)
        x=(i%cols)*cell_w; y=(i//cols)*cell_h
        sheet.alpha_composite(cut,(x+(cell_w-cut.width)//2,y+26))
        draw.text((x+8,y+3),name,fill=PALETTE[name],font=label_font)
    sheet.save(output/'exclusive_part_review.png')


def audit(mod,facing,write_images):
    source=Image.open(mod.SOURCE).convert('RGBA'); masks,_=mod.build_base_masks(source)
    labels=_labels(masks); failures=[]
    alpha=source.getchannel('A'); occupied={(x,y) for y in range(255) for x in range(255) if alpha.getpixel((x,y))}
    if set(labels)!=occupied: failures.append('Exclusive ownership does not cover exactly the source alpha')
    if set(masks)!=set(LANDMARKS[facing]): failures.append('A part lacks semantic landmark coverage')
    landmarks=[]
    for expected,points in LANDMARKS[facing].items():
        for point in points:
            actual=labels.get(point); passed=actual==expected
            landmarks.append({'source_pixel':list(point),'expected':expected,'actual':actual,'passed':passed})
            if not passed: failures.append(f'{point}: expected {expected}, found {actual}')
    components={name:_components(mask) for name,mask in masks.items()}
    for name,parts in components.items():
        expected=2 if facing=='front' and name=='cape_full' else 1
        if len(parts)!=expected: failures.append(f'{name}: {len(parts)} components, expected {expected}')
    material_checks=[]
    regions = [
      ('opposite shoulder cloak fold',(95,69,113,97),'green',{'cape_full'}),
      ('cloak edge beside chest',(138,88,156,102),'green',{'cape_full'}),
      ('exposed sleeve under cloak',(163,120,176,140),'brown',{'arm_l','forearm_l'}),
      ('bracer below elbow',(160,141,177,149),'brown',{'forearm_l'}),
    ] if facing=='front' else [
      ('green cloak hem around brown collar',(88,64,152,81),'green',{'cape_full'}),
    ]
    for name,box,material,owners in regions:
        selected=[]; bad=[]
        for y in range(box[1],box[3]):
            for x in range(box[0],box[2]):
                r,g,b,a=source.getpixel((x,y))
                qualifies=a and (g>r+2 if material=='green' else r>g+8)
                if qualifies:
                    selected.append((x,y))
                    if labels.get((x,y)) not in owners: bad.append((x,y))
        if not selected or bad: failures.append(f'{name}: {len(bad)} misowned material pixels')
        material_checks.append({'name':name,'source_rect':list(box),'material':material,
                                'expected_owners':sorted(owners),'checked_pixels':len(selected),
                                'misowned_pixels':[list(p) for p in bad]})
    layout=json.loads((HERE/('cutout_layout.json' if facing=='front' else 'cutout_layout_rear.json')).read_text())
    assets=[]
    entries=layout['parts']+[dict(layout['cape_mesh'],name='cape_full')]
    for part in entries:
        name=part['name']; owner='cape_full' if name.startswith('cape_') else name
        permitted={owner}
        for a,b in SHARED_PAIRS:
            if owner==a: permitted.add(b)
            if owner==b: permitted.add(a)
        im=Image.open(HERE/part['file']).convert('RGBA'); ox,oy=part['offset']; wrong=foreign=0; actual_points=set()
        for y in range(im.height):
            for x in range(im.width):
                rgba=im.getpixel((x,y))
                if not rgba[3]: continue
                point=x+ox,y+oy; actual_points.add(point)
                if rgba!=source.getpixel(point): wrong+=1
                if labels.get(point) not in permitted: foreign+=1
        missing=0 if part.get('cape_segment') else sum(1 for p,n in labels.items() if n==owner and p not in actual_points)
        # Distal bracer material can only enter these rigid hand textures in the
        # small actual wrist neighborhood, never at the previous high cuff cut.
        wrist_violations=0
        if facing=='front' and name=='hand_l': wrist_violations=sum(y<148 for x,y in actual_points)
        if facing=='front' and name=='sword_hand_r': wrist_violations=sum(x>=88 and y<123 for x,y in actual_points)
        if wrong or foreign or missing or wrist_violations:
            failures.append(f'{name}: changed={wrong}, unrelated={foreign}, missing={missing}, wrist={wrist_violations}')
        assets.append({'part':name,'file':part['file'],'rgba_changed_pixels':wrong,
                       'unrelated_owner_pixels':foreign,'missing_owned_pixels':missing,
                       'out_of_wrist_overlap_pixels':wrist_violations})
    before=_baseline(source,facing); transfers=Counter((before[p],n) for p,n in labels.items() if before[p]!=n)
    if write_images: _proof_images(source,masks,facing)
    return {'source_sha256':hashlib.sha256(mod.SOURCE.read_bytes()).hexdigest(),
            'layout_sha256':hashlib.sha256((HERE/('cutout_layout.json' if facing=='front' else 'cutout_layout_rear.json')).read_bytes()).hexdigest(),
            'source_visible_pixels':len(occupied),'exclusive_owned_pixels':len(labels),
            'base_part_components':components,'intentional_occlusion':
              'Front cape has a separate visible far-shoulder fold; the connecting material is hidden by head/scarf.'
              if facing=='front' else 'The entire left arm is hidden in the rear source; it has bones but no invented cutouts.',
            'landmarks':landmarks,'material_boundary_checks':material_checks,'saved_asset_checks':assets,
            'comparison_to_baseline':{'revision':BASELINE,'pixels_with_changed_owner':sum(transfers.values()),
              'transfers':[{'from':a,'to':b,'pixels':n} for (a,b),n in sorted(transfers.items())]},
            'failures':failures,'passed':not failures}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--no-images',action='store_true');args=parser.parse_args()
    result={'scope':'Hand-reviewed semantic landmarks/material boundaries, connected components, source RGBA, and actual exported cutouts; complements renderer pose inspection.',
            'facings':{name:audit(mod,name,not args.no_images) for mod,name in [(front,'front'),(rear,'rear')]}}
    result['passed']=all(r['passed'] for r in result['facings'].values())
    path=HERE/'assets/segmentation_audit.json';path.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'passed':result['passed'],'facings':{n:{'landmarks':len(r['landmarks']),
          'changed_owners':r['comparison_to_baseline']['pixels_with_changed_owner'],'failures':r['failures']}
          for n,r in result['facings'].items()}},indent=2))
    raise SystemExit(0 if result['passed'] else 1)


if __name__=='__main__': main()
