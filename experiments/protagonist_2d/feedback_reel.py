"""Compose existing renderer frames into fixed-framing animation review videos.

The shared source rectangle is chosen once across every action and both facings.
No camera follows a pose; all source pixels keep the same scale and registration.
Slow playback duplicates actual frames and never invents an intermediate pose.
"""
from __future__ import annotations

import hashlib
from functools import lru_cache
import json
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw, ImageFont

ACTIONS = ('walk', 'attack')
FACINGS = ('front', 'rear')
FPS = 72
SCALE = 2
FONT_PATH = Path(__file__).resolve().parents[2] / 'fonts/LabyrinthCrumble-Text.ttf'


@lru_cache(maxsize=16)
def _font(size):
    return ImageFont.truetype(str(FONT_PATH), size)


def _text(draw, at, value, size=24, color='#ded3c0', anchor=None):
    draw.text(at, value, font=_font(size), fill=color, anchor=anchor)


def _sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def _geometry(clips):
    bounds = [frame.getchannel('A').getbbox() for frames in clips.values() for frame in frames]
    if not bounds or any(box is None for box in bounds):
        raise ValueError('Feedback frames must contain painted pixels')
    # A single union across every animation and BOTH facings. Padding is fixed;
    # a sword reaching farther in one pose cannot change another pose's camera.
    crop = (min(b[0] for b in bounds) - 12, min(b[1] for b in bounds) - 12,
            max(b[2] for b in bounds) + 12, max(b[3] for b in bounds) + 12)
    tile = ((crop[2] - crop[0]) * SCALE, (crop[3] - crop[1]) * SCALE)
    size = (2 * tile[0] + 120, tile[1] + 260)
    return crop, tile, size


def _compose(clips, action, frame, geometry, pass_number, speed, repetition, repeats):
    crop, tile, size = geometry
    canvas = Image.new('RGB', size, '#1b1d20')
    draw = ImageDraw.Draw(canvas)
    _text(draw, (40, 28), f'PASS {pass_number} / ANIMATION REVIEW', 28)
    title = 'WALK / IN PLACE' if action == 'walk' else action.upper()
    _text(draw, (40, 78), title, 28, '#d7aa74')
    _text(draw, (size[0] - 40, 80), 'Normal speed / 1x' if speed == 1 else 'Half speed / 0.5x', 24, anchor='rt')
    for column, facing in enumerate(FACINGS):
        original = clips[facing, action][frame]
        bounds = original.getchannel('A').getbbox()
        if not (crop[0] <= bounds[0] and crop[1] <= bounds[1] and crop[2] >= bounds[2] and crop[3] >= bounds[3]):
            raise ValueError('Shared camera crops a painted pose')
        painted = original.crop(crop).resize(tile, Image.Resampling.NEAREST)
        position = (40 + column * (tile[0] + 40), 170)
        canvas.paste(painted, position, painted)
        _text(draw, (position[0] + tile[0] / 2, 132), facing.title(), 24, anchor='mt')
    count = len(clips['front', action])
    _text(draw, (40, size[1] - 58), f'Frame {frame + 1:02d} / {count:02d}', 21)
    _text(draw, (size[0] - 40, size[1] - 58), f'Playback {repetition + 1} / {repeats}', 21, anchor='rt')
    draw.line((40, size[1] - 24, size[0] - 40, size[1] - 24), fill='#4d4c48', width=3)
    draw.line((40, size[1] - 24, 40 + (size[0] - 80) * (frame + 1) / count, size[1] - 24), fill='#bd9568', width=3)
    return canvas


def _encode(ffmpeg, destination, clips, geometry, pass_number, feedback, proof_folder, source_fps):
    size = geometry[2]
    encoder = subprocess.Popen([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{size[0]}x{size[1]}', '-r', str(FPS),
        '-i', 'pipe:0', '-an', '-c:v', 'libx264', '-crf', '16', '-preset', 'medium',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(destination)], stdin=subprocess.PIPE)
    total = 0
    segments = []
    proof_frames = []
    try:
        for action in ACTIONS:
            count = len(clips['front', action])
            modes = ((1, 2, 1), (0.5, 1, 2)) if feedback else ((1, 1, 1),)
            for speed, repeats, duplicate in modes:
                if FPS % source_fps[action]:
                    raise ValueError('Output cadence must preserve every source frame exactly')
                duplicate *= FPS // source_fps[action]
                start = total
                for repetition in range(repeats):
                    for frame in range(count):
                        canvas = _compose(clips, action, frame, geometry, pass_number, speed, repetition, repeats)
                        if feedback and repetition == 0 and frame in (0, count // 2, count - 1):
                            name = f'{action}_{"normal" if speed == 1 else "half"}_{frame:03d}.png'
                            canvas.save(proof_folder / name)
                            proof_frames.append(name)
                        pixels = canvas.tobytes()
                        for _ in range(duplicate):
                            encoder.stdin.write(pixels)
                            total += 1
                segments.append({'action': action, 'speed': speed, 'repetitions': repeats,
                    'source_frames_per_facing': count, 'start_frame': start, 'frame_count': total - start,
                    'start_seconds': start / FPS, 'end_seconds': total / FPS})
    finally:
        encoder.stdin.close()
    if encoder.wait():
        raise RuntimeError('ffmpeg failed to encode ' + str(destination))
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,avg_frame_rate,nb_frames,duration', '-of', 'json', str(destination)], text=True))['streams'][0]
    if (metadata['width'], metadata['height']) != size or int(metadata['nb_frames']) != total or metadata['avg_frame_rate'] != f'{FPS}/1':
        raise ValueError('Encoded video changed frame geometry or cadence')
    subprocess.run([ffmpeg, '-v', 'error', '-xerror', '-i', str(destination), '-f', 'null', '-'], check=True)
    return {'file': destination.name, 'sha256': _sha(destination), 'frames': total, 'duration_seconds': total / FPS,
            'segments': segments, 'complete_decode': True, 'metadata': metadata, 'proof_frames': proof_frames}


def write_previews(clips, output, pass_number=7, source_fps=None):
    source_fps = source_fps or {action: 24 for action in ACTIONS}
    for action in ACTIONS:
        if not all((facing, action) in clips for facing in FACINGS):
            raise ValueError('Walk and attack need both actual facings')
        if len(clips['front', action]) != len(clips['rear', action]):
            raise ValueError('Paired animation frame counts differ')
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('ffmpeg is required for the animation feedback reel')
    output = Path(output)
    proof_folder = output / 'video_frames' / 'feedback'
    proof_folder.mkdir(parents=True, exist_ok=True)
    geometry = _geometry(clips)
    records = [_encode(ffmpeg, output / name, clips, geometry, pass_number, feedback, proof_folder, source_fps)
               for name, feedback in (('animation_showcase.mp4', False), ('walk_attack_feedback.mp4', True))]
    manifest = {'pass': pass_number, 'fps': FPS, 'size': geometry[2], 'shared_source_crop': geometry[0],
        'source_pixel_scale': SCALE, 'facings_left_to_right': list(FACINGS), 'per_frame_camera_fitting': False,
        'pose_interpolation': False, 'source_fps': source_fps, 'half_speed_method': 'Hold each actual source frame twice as long; output cadence preserves both 24fps and 36fps inputs',
        'builder_sha256': _sha(__file__), 'font_sha256': _sha(FONT_PATH),
        'source_sha256': {path.name: _sha(path) for path in sorted(output.glob('*.png')) if path.stem in {f + '_' + a for f in FACINGS for a in ACTIONS}},
        'videos': records}
    (output / 'feedback_reel_validation.json').write_text(json.dumps(manifest, indent=2) + '\n')
    # A small full-reel overview; the numbered full-size stills are scratch.
    contact = Image.new('RGB', (1200, len(ACTIONS) * 440), '#1b1d20')
    for row, action in enumerate(ACTIONS):
        count = len(clips['front', action])
        for column, frame in enumerate((0, count // 2, count - 1)):
            for speed_row, speed in enumerate((1, 0.5)):
                canvas = _compose(clips, action, frame, geometry, pass_number, speed, 0, 2 if speed == 1 else 1)
                canvas.thumbnail((400, 220), Image.Resampling.LANCZOS)
                contact.paste(canvas, (column * 400, row * 440 + speed_row * 220))
    contact.save(output / 'feedback_reel_contact.png')
    walk = [_compose(clips, 'walk', frame, geometry, pass_number, 1, 0, 1) for frame in range(len(clips['front', 'walk']))]
    return walk, records[0]['frames']
