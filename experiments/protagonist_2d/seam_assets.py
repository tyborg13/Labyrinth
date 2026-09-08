"""Refine garment joins on the accepted sixth-pass protagonist paintings.

The frozen baseline retains its arm/sword art and complete 21-bone motion. This
pass changes cutout coverage, native-pixel color and compositing order. Rounded
painted joint covers conceal hard segment ends without deforming limb textures.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw
from registered_assets import mesh

HERE = Path(__file__).resolve().parent
BASELINE = HERE / 'references/pass7/baseline'


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def expanded(part):
    image = Image.new('RGBA', (255, 255))
    image.alpha_composite(Image.open(HERE / part['file']).convert('RGBA'), part['offset'])
    return image


def save_part(data, part, image):
    bbox = image.getbbox()
    assert bbox, part['name']
    path = HERE / f"assets/pass7/{data['facing']}/{part['name']}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    image.crop(bbox).save(path)
    part['file'] = str(path.relative_to(HERE))
    part['offset'] = list(bbox[:2])


def rounded_segment(image, center, radii, distal):
    """Round only the hidden cut edge; retain the painted segment's full body."""
    cx, cy = center
    rx, ry = radii
    result = image.copy()
    for y in range(255):
        for x in range(255):
            if (y > cy if distal else y < cy):
                if ((x-cx)/rx)**2 + ((y-cy)/ry)**2 > 1:
                    result.putpixel((x, y), (0, 0, 0, 0))
    return result


def complete_cuff(image, ankle):
    """Extend the hidden trouser paint into the shoe before rounding its hem.

    A few source columns ended above the ankle or beside the old empty collar.
    Fill that missing local paint from the same calf, without resizing the limb.
    """
    result = image.copy()
    cx, cy = ankle
    for x in range(cx-9, cx+10):
        samples = [image.getpixel((x,y)) for y in range(cy-9, cy-14, -1)
                   if image.getpixel((x,y))[3] == 255]
        if not samples:
            continue
        color = samples[0]
        for y in range(cy-9, cy+3):
            if ((x-cx)/10)**2 + ((y-(cy-6))/9)**2 <= 1 and result.getpixel((x,y))[3] == 0:
                result.putpixel((x,y), color)
    return result


def joint_cover(image, center, radii):
    cx, cy = center
    rx, ry = radii
    result = Image.new('RGBA', image.size)
    for y in range(max(0, int(cy-ry)), min(255, int(cy+ry)+1)):
        for x in range(max(0, int(cx-rx)), min(255, int(cx+rx)+1)):
            distance = (((x-cx)/rx)**2 + ((y-cy)/ry)**2) ** .5
            if distance <= 1:
                r, g, b, a = image.getpixel((x, y))
                # One native pixel at the cover edge blends the overlapping
                # paint; the underlying thigh/shin remain crisp and rigid.
                opacity = min(1.0, (1.0-distance)*min(rx, ry))
                result.putpixel((x, y), (r, g, b, round(a*opacity)))
    return result


def worn_boot(image, facing):
    """Remove the empty collar interior; a foreground trouser cuff covers it.

    Trimming is local to the shaft. In the rear projection the raised toe sits
    beside the collar, so a horizontal crop would wrongly remove the toe.
    """
    result = image.copy()
    for y in range(255):
        for x in range(255):
            r, g, b, a = image.getpixel((x, y))
            if not a:
                continue
            removed = y < 199 if facing == 'front' else (x < 104 and y < 189)
            if removed:
                result.putpixel((x, y), (0, 0, 0, 0))
            else:
                # Muted worn leather, preserving the original grouped values.
                result.putpixel((x, y), (round(r*.85), round(g*.90), min(255, round(b*1.10)), a))
    return result


def build(facing):
    suffix = '' if facing == 'front' else '_rear'
    data = json.loads((BASELINE / f'cutout_layout{suffix}.json').read_text())
    parts = {part['name']: part for part in data['parts']}
    changes = []
    for side in ['r', 'l']:
        upper, lower, boot = (parts[name+'_'+side] for name in ['thigh', 'shin', 'foot'])
        leg = expanded(upper)
        leg.alpha_composite(expanded(lower))
        knee = data['joints']['shin_'+side]['position']
        # Existing overlaps ended on horizontal source rows. Round those ends
        # and cover the pivot with the same local paint at the same pixel scale.
        radius = (12, 9) if (facing, side) == ('front', 'r') else (17, 11)
        upper_image = rounded_segment(leg, [knee[0], knee[1]-2], radius, True)
        lower_image = rounded_segment(leg, [knee[0], knee[1]+2], radius, False)
        # Keep the original segment extents away from its joining end.
        for y in range(255):
            for x in range(255):
                if y > knee[1]+8:
                    upper_image.putpixel((x,y), (0,0,0,0))
                if y < knee[1]-9:
                    lower_image.putpixel((x,y), (0,0,0,0))
        ankle = data['joints']['foot_'+side]['position']
        lower_image = complete_cuff(lower_image, ankle)
        lower_image = rounded_segment(lower_image, [ankle[0], ankle[1]-3], [11, 8], True)
        save_part(data, upper, upper_image)
        save_part(data, lower, lower_image)
        # The trouser leg sits OVER the opening rather than behind an empty
        # rigid shoe collar. Toe, heel and sole stay on the unchanged foot bone.
        boot['z_index'] = upper['z_index'] - 1
        if side == 'l':
            save_part(data, boot, worn_boot(expanded(boot), facing))
        cover = {'name':'knee_cover_'+side, 'equipment_slot':'legs',
                 'bone':'shin_'+side, 'z_index':lower['z_index']+1}
        save_part(data, cover, joint_cover(leg, knee, [radius[0]-2, radius[1]-2]))
        data['parts'].append(cover)
        data['equipment_slots']['legs'].append(cover['name'])
        changes.append({'joint':'knee_'+side, 'method':'rounded overlapping cutouts and rigid painted joint cover', 'center':knee, 'radii':radius})
    if facing == 'rear':
        old_cape = data['cape_mesh']
        # Bring the drape's own neckline up to the actual shoulders, and put it
        # over the previous mantle pieces so the two collars cannot stack.
        delta = [-6, -13]
        cape_part = {'name':'cape_drape', 'equipment_slot':'cloak', 'bone':'cape_root',
                     'z_index':72, 'file':old_cape['file'],
                     'offset':[old_cape['offset'][i]+delta[i] for i in range(2)]}
        save_part(data, cape_part, expanded(cape_part))
        def influences(x, y):
            def smooth(v):
                v = max(0, min(1, v))
                return v*v*(3-2*v)
            middle = smooth((y-85)/46)
            end = smooth((y-127)/44)
            return {'cape_root':1-middle, 'cape_mid':middle*(1-end), 'cape_tip':middle*end}
        data['cape_mesh'] = mesh(cape_part, influences, 'cape')
        changes.append({'joint':'rear_cloak', 'translation':delta, 'z_index':72,
                        'method':'one drape neckline over the shoulder mantle joins'})
    data['version'] = 7
    data['seam_refinement'] = {'baseline_commit':'a01366412c8dd9263044751ac63bce6c556b9544', 'changes':changes,
                               'existing_pose_curves_unchanged':True}
    data['rest_source'] = f'references/pass7/{facing}_assembled_rest.png'
    canvas = Image.new('RGBA', (255,255))
    without = Image.new('RGBA', (255,255))
    for part in sorted(data['parts']+[data['cape_mesh']], key=lambda p:p['z_index']):
        image = expanded(part)
        canvas.alpha_composite(image)
        if part['equipment_slot'] != 'cloak':
            without.alpha_composite(image)
    output = HERE / data['rest_source']
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output)
    without.save(HERE / f'references/pass7/{facing}_without_cloak.png')
    data['rest_source_sha256'] = sha(output)
    (HERE / f'cutout_layout{suffix}.json').write_text(json.dumps(data, indent=2)+'\n')
    return data


def assembly_review():
    review = Image.new('RGB', (1530, 1100), '#303437')
    draw = ImageDraw.Draw(review)
    for row, facing in enumerate(['front', 'rear']):
        for col, (number, suffix) in enumerate([(6, 'assembled_rest'), (7, 'assembled_rest'), (7, 'without_cloak')]):
            picture = Image.open(HERE / f'references/pass{number}/{facing}_{suffix}.png').convert('RGBA')
            picture = picture.resize((510,510), Image.Resampling.NEAREST)
            review.paste(picture, (510*col,550*row+30), picture)
            draw.text((510*col+10,550*row+8), f'Pass {number} / {facing} / {suffix.replace("_", " ")} / 2x', fill='white')
    review.save(HERE / 'references/pass7/assembly_review.png')


def main():
    for facing in ['front', 'rear']:
        build(facing)
    assembly_review()
    print('Seventh-pass garment joins built; original motion and arms/weapon retained.')


if __name__ == '__main__':
    main()
