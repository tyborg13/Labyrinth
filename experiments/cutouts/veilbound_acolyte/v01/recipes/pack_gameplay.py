"""Retain native RunScene PNGs and encode captured poses at their measured speed.

JPEG samples remain in the isolated probe directory. The delivered 60fps clips
hold the most recent real sample; they never interpolate or synthesize a pose.
"""
import argparse
import bisect
import hashlib
import json
import math
import os
from pathlib import Path
import shutil
import statistics
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('raw', type=Path)
parser.add_argument('output', type=Path)
args = parser.parse_args()
raw, output = args.raw.resolve(), args.output.resolve()
output.mkdir(parents=True, exist_ok=False)
manifest = json.loads((raw / 'manifest.json').read_text())
assert manifest['ok'] and not manifest['errors']
for path in raw.glob('*.png'):
    shutil.copy2(path, output / path.name)
shutil.copy2(raw / 'manifest.json', output / 'manifest.json')
videos = output / 'videos'
videos.mkdir()
timeline = []
for clip in manifest['clips']:
    label, samples = clip['label'], clip['samples']
    times = [sample['seconds'] for sample in samples]
    gaps = [b-a for a, b in zip(times, times[1:])]
    last_hold = statistics.median(gaps) if gaps else 1/30
    duration = times[-1] - times[0] + last_hold
    count = math.ceil(duration * 60 - 1e-9)
    with tempfile.TemporaryDirectory(prefix='veilbound-encode-') as scratch:
        scratch = Path(scratch)
        mapping = []
        for frame in range(count):
            source = max(0, bisect.bisect_right(times, times[0] + frame/60) - 1)
            mapping.append(source)
            os.link(raw / label / f'frame_{source:04d}.jpg', scratch / f'frame_{frame:06d}.jpg')
        video = videos / (label + '.mp4')
        subprocess.run(['ffmpeg', '-v', 'error', '-y', '-framerate', '60', '-i', str(scratch / 'frame_%06d.jpg'), '-an', '-c:v', 'libx264', '-preset', 'fast', '-crf', '18', '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(video)], check=True)
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0', '-count_frames', '-show_entries', 'stream=nb_read_frames,avg_frame_rate,width,height', '-of', 'json', str(video)], text=True))['streams'][0]
    assert int(metadata['nb_read_frames']) == count and metadata['avg_frame_rate'] == '60/1'
    assert (metadata['width'], metadata['height']) == (1920, 1080)
    assert 0 <= count/60-duration < 1/60+1e-6
    timeline.append({'label':label, 'file':str(video.relative_to(output)), 'source_samples':len(samples), 'source_seconds':duration, 'encoded_seconds':count/60, 'duration_error_seconds':count/60-duration, 'encoded_frame_source_indices':mapping})
concat = videos / 'clips.ffconcat'
concat.write_text('ffconcat version 1.0\n' + ''.join(f"file '{Path(clip['file']).name}'\n" for clip in timeline))
reel = videos / 'gameplay_review.mp4'
subprocess.run(['ffmpeg', '-v', 'error', '-y', '-f', 'concat', '-safe', '0', '-i', str(concat), '-c', 'copy', '-movflags', '+faststart', str(reel)], check=True)
subprocess.run(['ffmpeg', '-v', 'error', '-i', str(reel), '-f', 'null', '-'], check=True)
(output / 'video_timeline.json').write_text(json.dumps({'timing':'Measured native sample time, 60fps holds, no synthesized poses; each clip rounds by less than one frame', 'full_decode':'PASS', 'clips':timeline}, indent=2)+'\n')
(output / 'output_sha256.json').write_text(json.dumps({str(p.relative_to(output)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(output.rglob('*')) if p.is_file()}, indent=2)+'\n')
print(json.dumps({'ok':True,'clips':len(timeline),'seconds':sum(c['encoded_seconds'] for c in timeline),'pngs':len(list(output.glob('*.png'))),'reel':str(reel)}))
