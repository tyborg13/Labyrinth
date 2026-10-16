"""Verify actual per-action pixels and phases before encoding a production reel."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ACTIONS = ['move', 'dive', 'talon_rake', 'hover', 'hit', 'death']


def errors(manifest, director):
    result = []
    if not manifest.get('native_pixels'): result.append('Native pixel evidence required')
    contact = .35 / (.35 + 6 / 30)
    required = {'move': [max(director['move']['keys'], key=lambda k: k['lift_px'])['t']],
                'dive': [contact], 'talon_rake': [director['talon_rake']['contact_phase']],
                'hover': [max(director['hover']['keys'], key=lambda k: abs(k['wings_raise']))['t']],
                'hit': [max(director['hit']['keys'], key=lambda k: k['recoil_px'])['t']], 'death': []}
    for clip in ACTIONS:
        frames = [f for f in manifest['frames'] if f.get('stage') == clip and f.get('snapshot', {}).get('clip') == clip]
        phases = [f['snapshot']['phase'] for f in frames]
        if not all(math.isfinite(p) and 0 <= p <= 1 for p in phases): result.append(clip + ': invalid phase')
        if len(frames) < 6: result.append(clip + ': fewer than six action frames')
        for target in [0, 1] + required[clip]:
            if not any(abs(p - target) < 1e-6 for p in phases): result.append(clip + ': missing required phase ' + str(target))
        boundary = contact if clip == 'dive' else director['talon_rake']['contact_phase'] if clip == 'talon_rake' else .5
        if not any(boundary < p < 1 for p in phases): result.append(clip + ': missing recovery')
        for before, after in zip(frames, frames[1:]):
            if before['snapshot']['phase'] >= after['snapshot']['phase']: result.append(clip + ': phase did not advance')
            if before.get('pose_sha256') == after.get('pose_sha256'): result.append(clip + ': identical consecutive visible poses')
    return result


def verify(capture, manifest):
    director = json.loads((Path(__file__).resolve().parent.parent / 'director_motion.json').read_text())
    failures = errors(manifest, director)
    for frame in manifest['frames']:
        pose = capture / frame.get('pose_file', '')
        if pose.parent != capture or not pose.is_file():
            failures.append('Missing local pose PNG')
            continue
        with Image.open(pose) as image:
            rgba = image.convert('RGBA')
            if rgba.size != (512, 512) or not rgba.getchannel('A').getbbox(): failures.append('Empty or wrong-size pose PNG')
            if hashlib.sha256(rgba.tobytes()).hexdigest() != frame.get('pose_sha256'): failures.append('Pose pixel hash differs')
        with Image.open(capture / frame['file']) as board:
            if board.size != (1920, 1080): failures.append('Wrong-size board frame')
    if failures: raise ValueError('\n'.join(failures))
