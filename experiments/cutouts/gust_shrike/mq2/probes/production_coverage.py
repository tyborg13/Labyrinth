"""Verify actual per-action pixels and phases before encoding a production reel."""
import hashlib
import json
import math
from pathlib import Path
from PIL import Image

ACTIONS = ['move', 'dive', 'talon_rake', 'hover', 'hit', 'death']
# Existing production clocks (FloatingCombatText / CutoutContext), not tuning.
HIT_PHASE_SAMPLE_STEP = (1 / 60) / .36


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
        targets = list(required[clip])
        if clip in ['dive', 'hover', 'death']: targets.append(0)
        if clip in ['move', 'talon_rake', 'hover', 'death']: targets.append(1)
        if clip == 'dive': targets.append(contact + (1 - contact) * 5 / 6)
        tolerance = HIT_PHASE_SAMPLE_STEP if clip == 'hit' else 1e-6
        for target in targets:
            if not any(abs(p - target) <= tolerance for p in phases): result.append(clip + ': missing required phase ' + str(target))
        keys = director[clip]['flight' if clip == 'dive' else 'keys']
        preparation_limit = min(k['t'] for k in keys if k['t'] > 0)
        if not any(p < preparation_limit for p in phases): result.append(clip + ': missing preparation')
        if clip == 'hit' and manifest.get('completions', {}).get(clip, {}).get('clip') != 'idle':
            result.append(clip + ': missing production return to idle')
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
