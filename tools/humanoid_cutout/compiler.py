"""Compile protected v2 channels without changing their values or clock."""
import hashlib
import json

CHANNELS = {'forward_px', 'lift_px', 'inward_px', 'lean_deg', 'angle_deg'}


def compile_motion(source, creature, layouts, projection):
    author = json.loads(source.read_bytes())[creature]
    if author['rig'] != 'humanoid_v2' or author['units'] != 'source_px':
        raise ValueError('Expected humanoid_v2 source-pixel tracks')
    result = {'rig': author['rig'], 'units': author['units'], 'creature': creature,
              'director_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'projection': projection, 'clips': {}, 'view_tracks': {}, 'TODO_DESIGN': {}}
    for view, layout in layouts.items():
        result['view_tracks'][view] = {}
        for clip, definition in author['clips'].items():
            result['clips'][clip] = {k: v for k, v in definition.items() if k != 'keys'}
            tracks, release = [], {}
            for name, keys in definition['keys'].items():
                bone, channel = name.rsplit('.', 1)
                if bone not in layout['joints']:
                    raise ValueError('TODO_DESIGN_' + name)
                if channel == 'forward_mode':
                    if keys not in ('fraction_of_step', 'world_step'):
                        raise ValueError('TODO_DESIGN_' + name)
                    continue
                if channel == 'release_at':
                    if clip != 'death' or not 0 <= keys <= 1:
                        raise ValueError('TODO_DESIGN_' + name)
                    release[bone] = keys
                    continue
                if channel not in CHANNELS:
                    raise ValueError('TODO_DESIGN_' + name)
                sign = projection[view]['lean_sign'] if channel in ('lean_deg', 'angle_deg') else 1
                rows = []
                for row in keys:
                    interpolation = row[2] if len(row) > 2 else 'smoothstep'
                    if interpolation not in ('smoothstep', 'linear', 'hold'):
                        raise ValueError('TODO_DESIGN_interpolation_' + name)
                    rows.append({'at': row[0], 'value': row[1] * sign, 'interpolation': interpolation})
                if not rows or any(not 0 <= k['at'] <= 1 for k in rows) or any(
                        a['at'] >= b['at'] for a, b in zip(rows, rows[1:])):
                    raise ValueError('Invalid keys: ' + name)
                tracks.append({'source': name, 'bone': bone, 'channel': channel, 'keys': rows,
                               'forward_mode': definition['keys'].get(bone + '.forward_mode', 'pixels')})
            result['view_tracks'][view][clip] = tracks
            result['clips'][clip]['release_at'] = release
    return result
