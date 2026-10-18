"""Derive fixed actor framing from every sampled painted texel, including mirrors."""
from rr07_inputs import *
from rr07_prepare import case_for
from maquette_motion.pixels import unpack
from maquette_motion.gates import expected_bones


def hull(points):
    points = sorted(set(map(tuple, points)))
    if len(points) <= 2:
        return np.asarray(points, dtype=float) + .5
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    lower, upper = [], []
    for section, order in ((lower, points), (upper, reversed(points))):
        for p in order:
            while len(section) >= 2 and cross(section[-2], section[-1], p) <= 0:
                section.pop()
            section.append(p)
    return np.asarray(lower[:-1] + upper[:-1], dtype=float) + .5


def derive(creature):
    case = case_for(creature)
    samples = read_json(case / 'proof/continuity_samples.json')
    data = read_json(case / 'compiled_motion.json')
    low, high = np.full(2, np.inf), np.full(2, -np.inf)
    for view in VIEWS:
        layout = read_json(case / f'layouts/{view}.json')
        anchor = np.asarray(layout['joints']['root']['position'])
        shapes = {}
        for part in layout['parts']:
            y, x = np.nonzero(np.asarray(Image.open(case / part['file']).convert('RGBA'))[..., 3])
            shapes[part['name']] = hull(np.c_[x, y])
        for row in samples['samples']:
            if row['view'] != view:
                continue
            travel = np.zeros(2)
            if row['clip'] == 'move':
                # Board framing follows the moving unit's world position.
                # Reserve its intrinsic body, not a second copy of tile travel.
                bones = expected_bones(data, layout, view, 'move', row['presented_phase'], samples['step_distance_px'])
                travel = bones['root']['global'][:2, 2] - anchor
            for name, part in row['parts'].items():
                if part['alpha'] <= 0:
                    continue
                m = unpack(part['transform'])
                points = (m[:2, :2] @ shapes[name].T).T + m[:2, 2] - anchor - travel
                extent = np.abs(m[:2, :2]).sum(axis=1) * .5
                a, b = np.floor(points.min(0) - extent), np.ceil(points.max(0) + extent)
                reflected_a, reflected_b = np.array([-b[0], a[1]]), np.array([-a[0], b[1]])
                low = np.minimum(low, np.minimum(a, reflected_a))
                high = np.maximum(high, np.maximum(b, reflected_b))
    report = {'basis': 'all 60 Hz Godot transforms; convex hull of opaque source texel squares; both views/reflections',
              'movement_registration': 'Root tile travel follows unit_world_positions and is subtracted once',
              'native_pixels': False, 'rect': [*low.tolist(), *(high-low).tolist()]}
    write_json(case / 'proof/actor_bounds.json', report)
    return report


if __name__ == '__main__':
    import re
    script = PROJECT / 'scripts/actor_presentation.gd'
    code = script.read_text()
    for creature in CREATURES:
        rect = derive(creature)['rect']
        line = '\t"%s": Rect2(%s),\n' % (creature, ', '.join(str(v) for v in rect))
        code = re.sub(r'\t"' + creature + r'": Rect2\([^\n]+\n', '', code)
        code = code.replace('const ACTION_BOUNDS: Dictionary = {\n', 'const ACTION_BOUNDS: Dictionary = {\n' + line)
        print(creature + ': ' + line.strip())
    script.write_text(code)
