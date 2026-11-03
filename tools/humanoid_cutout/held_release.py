"""Declared released-item component provenance, shared by raster and native gates.

The declaration supplies only item/clip identity. Release timing always comes
from compiled motion, with the same view override as the runtime. No size,
colour, frame number or proximity can authorize a detached component.
"""
import numpy as np
from maquette_motion.silhouette import components


class ComponentPolicy:
    def __init__(self, anatomy, motion, layout, rest_components):
        self.motion = motion
        self.view = layout['facing']
        self.baseline = rest_components
        self.parts = {part['name']: part for part in layout['parts']}
        self.declarations = anatomy.get('held_item_release_exemptions', [])
        for row in self.declarations:
            item, clip = row['item'], row['clip']
            if item not in layout.get('held_items', {}):
                raise ValueError('Release exemption is not a held item: ' + item)
            if clip not in motion['clips'] or self.release_at(clip).get(item) is None:
                raise ValueError('Release exemption has no motion release_at: ' + item + '/' + clip)

    def release_at(self, clip):
        return self.motion.get('view_release_at', {}).get(self.view, {}).get(
            clip, self.motion['clips'][clip].get('release_at', {}))

    def report(self, occupied, layers, clip, phase):
        labels, groups = components(occupied, 8)
        errors, masks, released = [], [], []
        active = [row['item'] for row in self.declarations
                  if row['clip'] == clip and phase >= self.release_at(clip)[row['item']]]
        if len(active) > 1:
            errors.append('more than one released held-item exemption in a clip')
        elif active:
            item = active[0]
            item_mask = np.zeros_like(occupied)
            other_mask = np.zeros_like(occupied)
            for row, image, _ in layers:
                part = self.parts[row['name']]
                target = item_mask if part.get('logical_part', part['name']) == item else other_mask
                target |= image[..., 3] > 0
            item_count = len(components(item_mask, 8)[1])
            if item_count != 1:
                errors.append('released held item ' + item + ': expected one 8-connected component, got ' + str(item_count))
            elif len(groups) > self.baseline:
                # The complete isolated item must equal one composite component;
                # no foreign paint can share that component. This also rejects
                # item fragments which happen to touch the body.
                label = labels[item_mask][0]
                mask = labels == label
                if label and np.array_equal(mask, item_mask) and not (mask & other_mask).any():
                    masks.append(mask)
                    released.append({'item': item, 'clip': clip,
                                     'release_at': self.release_at(clip)[item]})
        if len(groups) > self.baseline + len(masks):
            errors.append(f'floating pieces: {len(groups)} components > rest {self.baseline} + released {len(masks)}')
        return {'errors': errors, 'components': len(groups), 'rest_components': self.baseline,
                'released_components': released, 'masks': masks}
