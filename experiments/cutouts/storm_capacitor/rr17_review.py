"""Director rr-04 review reel and every-presented-frame 3x sheets."""
import argparse
import json
import subprocess
from PIL import Image, ImageDraw
from rr17_build import *
from rr17_gates import pixel_gate

PROOF_DEFAULTS = {'sheet_columns': 6, 'label_height': 24, 'crop_margin': 3}


def compose(native, output):
    verified = pixel_gate(read(CASE / 'proof/samples.json'), native)
    if not verified['ok']: raise ValueError(verified['errors'])
    report = read(native / 'frames.json')
    author = read(DIRECTOR / 'motion_tracks.json')['storm_capacitor']['clips']
    sequence, count = [], 0
    sheets = CASE / 'proof/contact_sheets'
    sheets.mkdir(parents=True, exist_ok=True)
    manifest = {}
    for clip, definition in author.items():
        rows = sorted((r for r in report['frames'] if r['view'] == 'front' and r['clip'] == clip), key=lambda r: r['frame'])
        repeats = 3 if clip == 'idle' else 1 if clip == 'death' else 2
        for _ in range(repeats):
            for row in rows:
                path = (native / row['overview']).resolve()
                if digest(path) != row['overview_sha256']: raise ValueError('Overview changed: ' + str(path))
                sequence.extend(["file '" + str(path).replace("'", "'\\''") + "'", 'duration %.12f' % (1 / 60)])
                count += 1
        if clip == 'death':
            for _ in range(60):
                sequence.extend(["file '" + str(path).replace("'", "'\\''") + "'", 'duration %.12f' % (1 / 60)])
                count += 1
        bounds = [Image.open(native / row['file']).getbbox() for row in rows]
        box = [min(b[0] for b in bounds), min(b[1] for b in bounds), max(b[2] for b in bounds), max(b[3] for b in bounds)]
        margin = PROOF_DEFAULTS['crop_margin']
        box = (box[0] - margin, box[1] - margin, box[2] + margin, box[3] + margin)
        w, h = (box[2] - box[0]) * 3, (box[3] - box[1]) * 3
        columns, label = PROOF_DEFAULTS['sheet_columns'], PROOF_DEFAULTS['label_height']
        sheet = Image.new('RGB', (columns * w, math.ceil(len(rows) / columns) * (h + label)), '#1E1E24')
        draw = ImageDraw.Draw(sheet)
        for index, row in enumerate(rows):
            image = Image.open(native / row['file']).convert('RGBA').crop(box).resize((w, h), Image.Resampling.NEAREST)
            x, y = index % columns * w, index // columns * (h + label)
            sheet.paste(image, (x, y + label), image)
            draw.text((x, y), '%s %03d  %.4f' % (clip, row['frame'], row['phase']), fill='white')
        filename = clip + '_all_frames_3x.png'
        sheet.save(sheets / filename)
        manifest[clip] = {'file': filename, 'frames': len(rows), 'crop': box, 'sha256': digest(sheets / filename)}
    # Explicit last file plus -frames:v ensures concat demuxer rounding cannot
    # truncate recovery or append a stray output frame.
    sequence.append("file '" + str(path).replace("'", "'\\''") + "'")
    listing = output.with_suffix('.concat.txt')
    listing.write_text('\n'.join(sequence) + '\n')
    subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(listing),
                    '-vf', 'fps=60', '-frames:v', str(count), '-c:v', 'libx264', '-crf', '18', '-pix_fmt', 'yuv420p', str(output)], check=True)
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_entries',
        'stream=nb_frames,width,height,r_frame_rate,duration', '-of', 'json', str(output)]))['streams'][0]
    if int(metadata['nb_frames']) != count or metadata['width'] != 1920 or metadata['height'] != 1080 or metadata['r_frame_rate'] != '60/1':
        raise ValueError('Review reel count/format differs: ' + str(metadata))
    write(sheets / 'manifest.json', manifest)
    write(output.with_suffix('.json'), {'ok': True, 'frames': count, 'format': metadata, 'sha256': digest(output), 'native_manifest_sha256': digest(native / 'frames.json')})
    print('RR17 REVIEW: PASS (%d frames; %s)' % (count, output))


if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--native', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    compose(args.native, args.output)
