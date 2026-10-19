"""Compile protected v2 channels without changing their values or clock."""
import hashlib
import json

from .anatomy import for_layout
from .bone_contracts import visible_leg, leg_bend_side
from .leg_roles import roles_for, resolve_bone
from .gait import expand

CHANNELS = {'forward_px', 'lift_px', 'inward_px', 'lean_deg', 'angle_deg', 'lane_px'}


def keys_for_view(definition, view, views):
    """A view replaces complete channels before roles/signs are resolved."""
    overrides = definition.get('view_keys', {})
    if not isinstance(overrides, dict) or set(overrides) - set(views):
        raise ValueError('view_keys: expected maps for declared views')
    if any(not isinstance(keys, dict) for keys in overrides.values()):
        raise ValueError('view_keys: each view must contain a channel map')
    keys = dict(definition['keys'])
    keys.update(overrides.get(view, {}))
    return keys


def compile_motion(source, creature, layouts, projection):
    author = json.loads(source.read_bytes())[creature]
    if author['rig'] != 'humanoid_v2' or author['units'] != 'source_px':
        raise ValueError('Expected humanoid_v2 source-pixel tracks')
    result = {'rig': author['rig'], 'units': author['units'], 'creature': creature,
              'director_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'projection': projection, 'clips': {}, 'view_tracks': {}, 'TODO_DESIGN': {}}
    for view, layout in layouts.items():
        anatomy = for_layout(layout)
        roles = roles_for(anatomy, view)
        if roles:
            result.setdefault('leg_roles', {})[view] = dict(roles)
            result.setdefault('view_forward_modes', {})[view] = {}
        if 'knee_policy' in anatomy:
            result['knee_policy'] = dict(anatomy['knee_policy'])
        for side in ('near', 'far'):
            if not visible_leg(layout['joints'], side): continue
            leg_bend_side(layout, anatomy, side, view)
            policy = anatomy.get('legs', {}).get(side, {}).get(view)
            if policy is not None:
                result.setdefault('legs', {}).setdefault(side, {})[view] = dict(policy)
        result['view_tracks'][view] = {}
        for clip, definition in author['clips'].items():
            result['clips'][clip] = {k: v for k, v in definition.items() if k not in ('keys', 'view_keys')}
            effective_keys = keys_for_view(definition, view, projection)
            generated = expand(definition['gait'], layout, clip) if 'gait' in definition else {}
            generated_channels = {(resolve_bone(name.rsplit('.', 1)[0], anatomy, view), name.rsplit('.', 1)[1]) for name in generated}
            conflicts = [name for name in effective_keys if (resolve_bone(name.rsplit('.', 1)[0], anatomy, view), name.rsplit('.', 1)[1]) in generated_channels]
            if conflicts:
                raise ValueError('gait: director key on generated channel: ' + str(sorted(conflicts)))
            effective_keys.update(generated)
            tracks, release = [], {}
            modes = {}
            for name, keys in effective_keys.items():
                source_bone, channel = name.rsplit('.', 1)
                bone = resolve_bone(source_bone, anatomy, view)
                if bone not in layout['joints']:
                    raise ValueError('TODO_DESIGN_' + name)
                if channel == 'forward_mode':
                    if keys not in ('fraction_of_step', 'world_step', 'body'):
                        raise ValueError('TODO_DESIGN_' + name)
                    modes[bone] = keys
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
                    if interpolation not in ('smoothstep', 'linear', 'hold') and not (name in generated and interpolation == 'sine_power'):
                        raise ValueError('TODO_DESIGN_interpolation_' + name)
                    rows.append({'at': row[0], 'value': row[1] * sign, 'interpolation': interpolation})
                if not rows or any(not 0 <= k['at'] <= 1 for k in rows) or any(
                        a['at'] >= b['at'] for a, b in zip(rows, rows[1:])):
                    raise ValueError('Invalid keys: ' + name)
                tracks.append({'source': name, 'bone': bone, 'channel': channel, 'keys': rows,
                               'forward_mode': effective_keys.get(source_bone + '.forward_mode', 'pixels')})
            # Only positional tracks make a support keyed in the runtime.
            # Rotation-only supports still need explicit mode metadata, just
            # like mode-only supports. Preserve legacy positional-track bytes.
            tracked_bones = {track['bone'] for track in tracks
                             if track['channel'] in ('forward_px', 'lift_px', 'inward_px')}
            if roles or anatomy.get('channel_aliases') or any(bone not in tracked_bones for bone in modes):
                result.setdefault('view_forward_modes', {}).setdefault(view, {})[clip] = modes
            result['view_tracks'][view][clip] = tracks
            view_release = any(name.endswith('.release_at') for keys in definition.get('view_keys', {}).values()
                               for name in keys)
            if view_release:
                # Preserve the base clip's metadata for the other view. Emit
                # resolved grip policies only when this extension needs them.
                result.setdefault('view_release_at', {}).setdefault(view, {})[clip] = release
                result['clips'][clip]['release_at'] = {
                    resolve_bone(name.rsplit('.', 1)[0], anatomy, view): value
                    for name, value in definition['keys'].items() if name.endswith('.release_at')}
            else:
                result['clips'][clip]['release_at'] = release
    return result
