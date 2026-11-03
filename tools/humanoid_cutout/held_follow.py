"""Optional held-item channel contract; absent fields preserve legacy tracks."""
import math


def validate(definition, layout, clip):
    follow = definition['held_follow']
    required = {'item', 'grip', 'deg_per_px', 'lag_s'}
    if (clip != 'move' or 'gait' not in definition or
            set(follow) - required - {'_doc', 'reference_frame', 'limit_deg'} or required - set(follow) or
            follow['item'] not in layout.get('held_items', {}) or
            layout['held_items'][follow['item']]['hand'] != follow['grip'] or
            any(type(follow[k]) not in (int, float) or not math.isfinite(follow[k])
                for k in ('deg_per_px', 'lag_s')) or follow['lag_s'] < 0):
        raise ValueError('TODO_DESIGN_held_follow')
    if 'limit_deg' in follow and (type(follow['limit_deg']) not in (int, float) or
            not math.isfinite(follow['limit_deg']) or not 0 < follow['limit_deg'] <= 35):
        raise ValueError('TODO_DESIGN_held_follow_limit_deg')
    if follow.get('reference_frame', 'world') not in ('world', 'moving_root', 'body'):
        raise ValueError('TODO_DESIGN_held_follow_reference_frame')


def angle(follow, displacement, projection_sign):
    value = follow['deg_per_px'] * displacement * projection_sign
    if 'limit_deg' in follow:
        value = max(-follow['limit_deg'], min(follow['limit_deg'], value))
    return value
