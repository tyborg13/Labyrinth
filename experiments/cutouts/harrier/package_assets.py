"""Assemble inspection sheets from native pixels and audit their source witnesses."""
from pathlib import Path
import argparse, hashlib, json, math
from PIL import Image, ImageChops, ImageDraw, ImageFilter

p = argparse.ArgumentParser()
p.add_argument('capture', type=Path)
p.add_argument('--previous', type=Path)
args = p.parse_args()
root = args.capture.resolve()
report = json.loads((root / 'comparison.json').read_text())
assert report['ok'] and not report['bake_only'] and not report['errors']
sheets = root.parent / 'inspection_sheets'
sheets.mkdir(exist_ok=True)
views = ['front', 'rear', 'front_reflected', 'rear_reflected']
clips = ['idle', 'walk', 'retreat', 'attack', 'cast']
all_paths = [f for view in views for f in (root / view).glob('*.png')]
bounds = [Image.open(f).getchannel('A').getbbox() for f in all_paths]
crop = (min(b[0] for b in bounds)-8, min(b[1] for b in bounds)-8,
        max(b[2] for b in bounds)+8, max(b[3] for b in bounds)+8)
dimensions = (crop[2]-crop[0], crop[3]-crop[1])
ratio = min(250/dimensions[0], 250/dimensions[1])
scaled = tuple(round(v*ratio) for v in dimensions)
for view in views:
    for clip in clips:
        files = sorted((root / view).glob(clip+'_*.png'))
        canvas = Image.new('RGB', (2080, math.ceil(len(files)/8)*280), '#20262c')
        draw = ImageDraw.Draw(canvas)
        for index, path in enumerate(files):
            x, y = index % 8 * 260, index // 8 * 280
            pose = Image.open(path).crop(crop).resize(scaled, Image.Resampling.NEAREST)
            canvas.paste(pose, (x+(260-scaled[0])//2, y+24), pose)
            draw.text((x+5,y+5), path.stem, fill='white')
        canvas.save(sheets / (view+'_'+clip+'.png'))
(sheets / 'assembly.json').write_text(json.dumps({'crop':crop,'scale':ratio,
    'method':'Common full-action crop, nearest-neighbor display scaling and contact-sheet assembly only. Original full-canvas native PNGs are retained.'},indent=2)+'\n')

original = Image.open(root.parents[4] / 'assets/placeholders/units/harrier_anime_trial.png').convert('RGBA')
native = Image.open(root / 'front/rest_000.png').convert('RGBA')
opaque = mismatches = 0
for y in range(original.height):
    for x in range(original.width):
        if original.getpixel((x,y))[3] == 255:
            opaque += 1
            mismatches += original.getpixel((x,y)) != native.getpixel((128+x-16,128+y))
assert opaque == 8999 and mismatches == 0
(root.parent/'front_source_preservation.json').write_text(json.dumps({'opaque_pixels':opaque,
    'mismatches':mismatches,'uniform_translation':[-16,0],
    'original_sha256':hashlib.sha256(original.tobytes()).hexdigest(),
    'native_file_sha256':hashlib.sha256((root/'front/rest_000.png').read_bytes()).hexdigest()},indent=2)+'\n')

reflection=[]
for view in ['front','rear']:
    for path in sorted((root/view).glob('*.png')):
        base=Image.open(path).convert('RGBA')
        actual=Image.open(root/(view+'_reflected')/path.name).convert('RGBA')
        # Godot reflects geometry around world x=255.5; image samples lie at
        # pixel centers. A Pillow flip therefore needs a one-pixel left shift.
        expected=ImageChops.offset(base.transpose(Image.Transpose.FLIP_LEFT_RIGHT),-1,0)
        exact=expected.tobytes()==actual.tobytes()
        am=actual.getchannel('A').point(lambda a:255 if a>=64 else 0)
        em=expected.getchannel('A').point(lambda a:255 if a>=64 else 0)
        outside=(ImageChops.subtract(am,em.filter(ImageFilter.MaxFilter(3))).getbbox() is not None
                 or ImageChops.subtract(em,am.filter(ImageFilter.MaxFilter(3))).getbbox() is not None)
        assert not outside, path
        reflection.append({'view':view,'frame':path.name,'pixel_identical':exact,'silhouette_within_one_source_pixel':True})
(root.parent/'reflection_audit.json').write_text(json.dumps({'pairs':len(reflection),
    'reflection_axis_world_x':255.5,'image_flip_pixel_shift':-1,
    'pixel_identical_pairs':sum(r['pixel_identical'] for r in reflection),
    'note':'Nearest-neighbor subpixel translation and rotation under a reflected parent can select adjacent paint texels. Every silhouette is checked against the expected reflection with a one-source-pixel tolerance.',
    'results':reflection},indent=2)+'\n')
if args.previous:
    same=[];changed=[]
    for path in all_paths:
        relative=path.relative_to(root);old=args.previous/relative
        (same if old.is_file() and Image.open(path).tobytes()==Image.open(old).tobytes() else changed).append(str(relative))
    assert all('/cast_' in path and path.startswith('rear') for path in changed),changed
    (root.parent/'previous_capture_comparison.json').write_text(json.dumps({'identical_frames':len(same),
        'changed_frames':changed,'allowed_change':'Rear/reflected rear casting preparation only; all other native poses must remain pixel-identical.'},indent=2)+'\n')
print('Packaged',len(all_paths),'native frames; original front and reflection audits PASS')
