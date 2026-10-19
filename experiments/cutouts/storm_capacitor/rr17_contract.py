"""Independent rr-17 oracle: reads director rows, never the semantic compiler."""
import math
import hashlib
import numpy as np
from PIL import Image
from rr17_build import ROOT, CASE, DIRECTOR, PAINTING, VIEWS, read, digest

TOLERANCE = 0.0001  # Same Bone2D float32 proof tolerance as rr-05.
MIN_ACTION_CHANGING_FRAMES = 6  # Brief gate; do not lower to fit protected holds.
TODO_DESIGN_hit_changing_frames = 'Protected hit has four transitions/four unique presented states; the brief requires at least six changing frames per action.'


def value(keys, phase):
    if phase <= keys[0][0]: return keys[0][1]
    for a, b in zip(keys, keys[1:]):
        if phase <= b[0]:
            kind = b[2] if len(b) > 2 else 'smoothstep'
            if kind == 'hold': return b[1] if phase == b[0] else a[1]
            t = (phase - a[0]) / (b[0] - a[0])
            if kind == 'smoothstep': t = t * t * (3 - 2 * t)
            return a[1] + (b[1] - a[1]) * t
    return keys[-1][1]


def definition(clip):
    return read(DIRECTOR / 'motion_tracks.json')['storm_capacitor']['clips'][clip]


def channels(clip, phase):
    return {name: value(rows, phase) for name, rows in definition(clip)['keys'].items()}


def held_phase(clip, phase):
    item = definition(clip)
    return (math.floor((phase % 1) * item['seconds'] * 10 + 1e-8) / 10) / item['seconds'] if item.get('loop') else phase


def matrix(x=0, y=0, angle=0):
    c, s = math.cos(angle), math.sin(angle)
    return np.array([[c, -s, x], [s, c, y], [0, 0, 1]])


def bones(clip, phase, view):
    ch = channels(clip, phase)
    sign = -1 if view == 'front' else 1
    travel = ch.get('body.forward_px', 0)
    root = matrix(sign * 2 / math.sqrt(5) * travel, -sign / math.sqrt(5) * travel)
    cap = matrix(131, 75 - ch.get('cap.lift_px', 0), math.radians(sign * ch.get('cap.lean_deg', 0)))
    return {'root': {'local': root, 'global': root}, 'column': {'local': np.eye(3), 'global': root},
            'cap': {'local': cap, 'global': root @ cap}}


def expected_paint():
    raw = np.asarray(Image.open(PAINTING).convert('RGBA'))
    cap_mask = np.asarray(Image.open(DIRECTOR / 'cap_mask.png'))[..., 3] > 0
    cap, column = raw.copy(), raw.copy()
    cap[~cap_mask] = 0
    column[cap_mask] = 0
    vent = Image.open(DIRECTOR / 'vent_fill.png').convert('RGBA')
    vent.alpha_composite(Image.fromarray(column))
    return {'column': vent, 'cap': Image.fromarray(cap)}


def expected_glow(image, level):
    result = np.asarray(image).copy()
    rgb = result[..., :3].astype(int)
    arc = (result[..., 3] > 0) & (rgb[..., 2] - rgb[..., 0] > 20) & (rgb[..., 2] - rgb[..., 1] > 40)
    if level:
        target = np.array([242, 230, 255] if level > 0 else [42, 18, 24])
        amount = {2: .70, 1: .35, -1: .55, -2: .90}[level]
        result[..., :3][arc] = np.floor(rgb[arc] * (1 - amount) + target * amount + .5)
    return result


def image_digest(image):
    return hashlib.sha256(np.asarray(image).tobytes()).hexdigest()
