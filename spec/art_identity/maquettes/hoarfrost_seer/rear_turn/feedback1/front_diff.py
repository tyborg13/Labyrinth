"""Measure feedback 1 limits against frozen native front delivery files."""
import json
from pathlib import Path

import numpy as np
from PIL import Image

PROOF_LIMITS = {'changed_figure_fraction': .005, 'label_displacement_px': 2,
                'joint_displacement_px': 1, 'alpha_threshold': 128}


def pixels(path):
    with Image.open(path) as image:
        return np.array(image.convert('RGBA'))


def silhouette_motion(before, after):
    if np.array_equal(before, after):
        return {'max_displacement_px': 0, 'passed': True}
    for radius in range(1, PROOF_LIMITS['label_displacement_px'] + 1):
        def expanded(mask):
            padded = np.pad(mask, radius)
            result = np.zeros_like(mask)
            for y in range(-radius, radius + 1):
                for x in range(-radius, radius + 1):
                    if x * x + y * y <= radius * radius:
                        result |= padded[radius + y:radius + y + mask.shape[0],
                                         radius + x:radius + x + mask.shape[1]]
            return result
        a, b = expanded(before), expanded(after)
        if not (before & ~b).any() and not (after & ~a).any():
            return {'max_displacement_px': radius, 'passed': True}
    return {'max_displacement_px': '>2', 'passed': False}


def main():
    output = Path(__file__).resolve().parent
    delivery = output.parents[1] / 'delivery'
    capture = output / 'corrected'
    report = {'limits': PROOF_LIMITS, 'images': {}, 'labels': {}}
    for kind in ('clay', 'parts', 'silhouette'):
        name = 'front_' + kind + '.png'
        old, new = pixels(delivery / name), pixels(capture / name)
        figure = (old[..., 3] > 0) | (new[..., 3] > 0)
        changed = np.any(old != new, axis=-1) & figure
        count, denominator = int(changed.sum()), int(figure.sum())
        report['images'][kind] = {'changed_figure_pixels': count, 'figure_pixels': denominator,
            'changed_fraction': count / max(1, denominator),
            'alpha_changed_pixels': int((old[..., 3] != new[..., 3]).sum()),
            'passed': bool(count / max(1, denominator) <= PROOF_LIMITS['changed_figure_fraction'])}
    for path in sorted(delivery.glob('front_solo_*.png')):
        old = pixels(path)[..., 3] >= PROOF_LIMITS['alpha_threshold']
        new = pixels(capture / path.name)[..., 3] >= PROOF_LIMITS['alpha_threshold']
        report['labels'][path.stem.removeprefix('front_solo_')] = silhouette_motion(old, new)
    old = json.loads((delivery / 'joints_px.json').read_text())['front']
    new = json.loads((capture / 'joints_px.json').read_text())['front']
    report['joints'] = {name: float(np.max(abs(np.subtract(point, new[name])))) for name, point in old.items()}
    report['max_joint_displacement_px'] = max(report['joints'].values())
    report['passed'] = (all(row['passed'] for row in report['images'].values()) and
                        all(row['passed'] for row in report['labels'].values()) and
                        report['max_joint_displacement_px'] <= PROOF_LIMITS['joint_displacement_px'])
    (output / 'front_pixel_diff.json').write_text(json.dumps(report, indent=2) + '\n')
    print('MQ06_FRONT_DIFF: ' + ('PASS' if report['passed'] else 'FAIL') + '; ' +
          '; '.join(kind + '=' + str(row['changed_figure_pixels']) + '/' + str(row['figure_pixels']) +
                    ' (' + format(row['changed_fraction'], '.6%') + ')' for kind, row in report['images'].items()) +
          '; max_joint_px=' + str(report['max_joint_displacement_px']))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
