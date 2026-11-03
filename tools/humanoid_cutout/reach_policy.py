"""Optional anatomy-owned minimum reach for a standard leg in one view.

Arms, custom terminals and undeclared legs retain the caller's legacy margin.
This is an offline gate policy; it does not change runtime IK or motion.
"""
from .anatomy import for_layout


def minimum_reach_policy(layout, chain):
    for side in ('near', 'far'):
        if [chain[k] for k in ('first', 'second', 'target')] != [
                'thigh_' + side, 'shin_' + side, 'foot_' + side]:
            continue
        # Minimal synthetic layouts have no case, and preserve the old gate.
        if 'anatomy' not in layout and 'motion_data' not in layout:
            return None
        return for_layout(layout).get('legs', {}).get(side, {}).get(
            layout['facing'], {}).get('minimum_reach')
    return None
