"""Compose walk and attack in front/rear views from actual combat-board capture pixels.

A single fixed native-pixel crop covers every actor pose and the full walk path.
The 72fps output preserves all 24fps action and 36fps walk frames; half speed
holds each recorded frame twice as long without interpolating new poses.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import shutil
import subprocess

from PIL import Image, ImageDraw

from feedback_reel import ACTIONS, FACINGS, FPS, FONT_PATH, _sha, _text


def write_board_reel(proof: Path) -> dict:
    proof = proof.resolve()
    evidence = json.loads((proof / 'validation.json').read_text())
    if not evidence.get('motion_frames_captured') or evidence.get('viewport') != [1920, 1080]:
        raise ValueError('Full real-renderer board motion is required')
    clips = {entry['name']: entry for entry in evidence['video_clips']}
    required = {facing + '_' + action for facing in FACINGS for action in ACTIONS}
    if set(clips) != required:
        raise ValueError('Board reel requires walk and attack in both facings')
    all_bounds = []
    hashes = {}
    for name, clip in clips.items():
        count = int(clip['frame_count'])
        fps = int(clip['fps'])
        if count <= 0 or fps <= 0 or FPS % fps:
            raise ValueError('Source timing cannot be preserved exactly')
        frames = Path(clip['frames_path']).resolve()
        frames.relative_to(proof)
        if len(clip.get('actor_bounds', [])) != count:
            raise ValueError('Every captured frame needs its actual board actor bounds')
        all_bounds.extend(clip['actor_bounds'])
        frame_hashes = []
        for index in range(count):
            path = frames / f'frame_{index:04d}.{clip["frame_extension"]}'
            with Image.open(path) as frame:
                frame.load()
                if frame.size != (1920, 1080):
                    raise ValueError('Unexpected native board frame dimensions')
            frame_hashes.append(_sha(path))
        hashes[name] = frame_hashes
    # Shared camera rectangle, with headroom for overhead blades/health bars
    # and enough floor around every footprint. Never track or fit single poses.
    crop = (math.floor((min(b[0] for b in all_bounds) - 56) / 2) * 2,
            math.floor((min(b[1] for b in all_bounds) - 44) / 2) * 2,
            math.ceil((max(b[2] for b in all_bounds) + 56) / 2) * 2,
            math.ceil((max(b[3] for b in all_bounds) + 44) / 2) * 2)
    if crop[0] < 20 or crop[1] < 134 or crop[2] > 1300 or crop[3] > 924:
        raise ValueError(f'Complete actor path does not fit inside the actual board: {crop}')
    width, height = crop[2] - crop[0], crop[3] - crop[1]
    size = (width * 2 + 96, height + 202)
    output = proof / 'videos'
    output.mkdir(exist_ok=True)
    destination = output / 'walk_attack_board.mp4'
    ffmpeg = shutil.which('ffmpeg')
    if not ffmpeg:
        raise RuntimeError('ffmpeg is required')
    encoder = subprocess.Popen([ffmpeg, '-hide_banner', '-loglevel', 'error', '-y',
        '-f', 'rawvideo', '-pix_fmt', 'rgb24', '-s', f'{size[0]}x{size[1]}', '-r', str(FPS),
        '-i', 'pipe:0', '-an', '-c:v', 'libx264', '-preset', 'medium', '-crf', '16',
        '-pix_fmt', 'yuv420p', '-movflags', '+faststart', str(destination)], stdin=subprocess.PIPE)
    total = 0
    segments = []
    proof_indices = {}
    try:
        for action in ACTIONS:
            front, rear = (clips[facing + '_' + action] for facing in FACINGS)
            if (front['frame_count'], front['fps']) != (rear['frame_count'], rear['fps']):
                raise ValueError('Paired board clips must share timing')
            count, rate = int(front['frame_count']), int(front['fps'])
            frames = {}
            for facing, clip in zip(FACINGS, (front, rear)):
                frames[facing] = []
                for index in range(count):
                    bounds = clip['actor_bounds'][index]
                    if not (crop[0] <= bounds[0] and crop[1] <= bounds[1] and crop[2] >= bounds[2] and crop[3] >= bounds[3]):
                        raise ValueError('Fixed crop cuts into an actor')
                    with Image.open(Path(clip['frames_path']) / f'frame_{index:04d}.{clip["frame_extension"]}') as image:
                        frames[facing].append(image.convert('RGB').crop(crop))
            for speed, repeats in ((1, 2), (0.5, 1)):
                duplicate = (FPS // rate) * (1 if speed == 1 else 2)
                start = total
                mode = 'normal' if speed == 1 else 'half'
                for repetition in range(repeats):
                    for index in range(count):
                        canvas = Image.new('RGB', size, '#100e12')
                        draw = ImageDraw.Draw(canvas)
                        _text(draw, (32, 20), 'PASS 7 / ON THE COMBAT BOARD', 25)
                        _text(draw, (32, 60), action.upper(), 25, '#d7aa74')
                        _text(draw, (size[0] - 32, 62), 'Normal speed / 1x' if speed == 1 else 'Half speed / 0.5x', 22, anchor='rt')
                        for column, facing in enumerate(FACINGS):
                            x = 32 + column * (width + 32)
                            _text(draw, (x + width / 2, 99), facing.title(), 22, anchor='mt')
                            canvas.paste(frames[facing][index], (x, 136))
                        if action == 'walk':
                            pose_count = count // int(front['gait_cycles'])
                            label = f'Cycle {index // pose_count + 1} / {front["gait_cycles"]}  ·  Pose {index % pose_count + 1:02d} / {pose_count}'
                        else:
                            label = f'Pose {index + 1:02d} / {count}'
                        _text(draw, (32, size[1] - 45), label, 20)
                        _text(draw, (size[0] - 32, size[1] - 45), f'Playback {repetition + 1} / {repeats}', 20, anchor='rt')
                        if repetition == 0:
                            selected = {0, count // 2, count - 1}
                            if action == 'attack':
                                selected.update({round((count - 1) * .29), round((count - 1) * .43)})
                            if index in selected:
                                proof_indices[total] = f'{action}_{mode}_{index:03d}.png'
                        pixels = canvas.tobytes()
                        for _ in range(duplicate):
                            encoder.stdin.write(pixels)
                            total += 1
                segments.append({'action': action, 'speed': speed, 'repetitions': repeats,
                    'source_frames_per_facing': count, 'source_fps': rate,
                    'source_frames_duplicated': duplicate, 'start_frame': start, 'frame_count': total - start,
                    'start_seconds': start / FPS, 'end_seconds': total / FPS})
    finally:
        encoder.stdin.close()
    if encoder.wait():
        raise RuntimeError('ffmpeg failed to encode board reel')
    metadata = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-select_streams', 'v:0',
        '-show_entries', 'stream=width,height,avg_frame_rate,nb_frames,duration', '-of', 'json', str(destination)], text=True))['streams'][0]
    if (metadata['width'], metadata['height']) != size or metadata['avg_frame_rate'] != f'{FPS}/1' or int(metadata['nb_frames']) != total:
        raise ValueError('Encoded board reel changed timing or dimensions')
    subprocess.run([ffmpeg, '-v', 'error', '-xerror', '-i', str(destination), '-f', 'null', '-'], check=True)
    proof_folder = proof / 'reel_proof'
    proof_folder.mkdir(exist_ok=True)
    indices = sorted(proof_indices)
    select = '+'.join(f'eq(n,{index})' for index in indices)
    subprocess.run([ffmpeg, '-v', 'error', '-y', '-i', str(destination), '-vf', "select='" + select + "'",
        '-fps_mode', 'vfr', '-frames:v', str(len(indices)), str(proof_folder / 'decoded_%03d.png')], check=True)
    for number, index in enumerate(indices, 1):
        (proof_folder / f'decoded_{number:03d}.png').replace(proof_folder / proof_indices[index])
    contact = Image.new('RGB', (1200, math.ceil(len(indices) / 3) * 240), '#100e12')
    for number, index in enumerate(indices):
        with Image.open(proof_folder / proof_indices[index]) as source:
            image = source.convert('RGB')
            image.thumbnail((400, 240), Image.Resampling.LANCZOS)
            contact.paste(image, ((number % 3) * 400, (number // 3) * 240))
    contact.save(output / 'walk_attack_board_contact.png')
    report = {'pass': 7, 'proof_kind': 'actual Godot combat-board frames',
        'native_capture_size': [1920, 1080], 'ui_scale': 1.0, 'source_pixel_scale': 1,
        'fixed_source_crop': list(crop), 'facings_left_to_right': list(FACINGS),
        'per_frame_camera_fitting': False, 'pose_interpolation': False,
        'fps': FPS, 'frames': total, 'duration_seconds': total / FPS, 'size': list(size),
        'segments': segments, 'source_frame_sha256': hashes,
        'source_validation_sha256': _sha(proof / 'validation.json'), 'builder_sha256': _sha(__file__),
        'font_sha256': _sha(FONT_PATH), 'video_sha256': _sha(destination), 'complete_decode': True,
        'metadata': metadata, 'decoded_proof_frames': [proof_indices[index] for index in indices]}
    (output / 'board_feedback_reel_validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'BOARD FEEDBACK REEL PASS: {total} frames at {FPS}fps, {total / FPS:.3f}s, {size}; crop={crop}')
    print(destination)
    return report


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('proof_directory', type=Path)
    write_board_reel(parser.parse_args().proof_directory)
