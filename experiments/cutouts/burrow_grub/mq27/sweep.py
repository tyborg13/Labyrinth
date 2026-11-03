"""On-demand conservative CPU silhouette sweep, including native UV tie choices."""
from prepare import *
from maquette_motion import pixels, silhouette
from maquette_motion.raster import nearest_quad

PROOF_DEFAULTS = {'mutation_canvas_size': 32, 'main_rect': [8, 8, 20, 20],
                  'stray_origin': [4, 4], 'bridge_column': 12,
                  'bridge_rows': [5, 8]}


def safe_occupancy(guaranteed, possible):
    """Every legal native occupancy is connected if this stronger test passes.

    Each optional pixel must directly touch the guaranteed main component.
    Consequently no independent combination of native u/v tie choices can
    disconnect a one-pixel fleck or a larger island. Never union ties to hide it.
    """
    labels, groups = silhouette.components(guaranteed)
    if not groups:
        return not possible.any()
    main = labels == groups[0][0]
    return len(groups) == 1 and not (possible & ~silhouette.dilate(main, 1, grid_distance=True)).any()


def report():
    data = read_json(CASE / 'proof/continuity_samples.json')
    failures, rows = [], []
    for view in inputs.VIEWS:
        layout = read_json(CASE / f'layouts/{view}.json')
        images = {p['name']: Image.open(CASE / p['file']).convert('RGBA') for p in layout['parts']}
        cache = {}
        for row in (r for r in data['samples'] if r['view'] == view):
            signature = tuple((name, tuple(n['transform']), n['alpha']) for name, n in row['parts'].items())
            if signature not in cache:
                certain = np.zeros((512, 512), dtype=bool)
                possible = certain.copy()
                for part in layout['parts']:
                    node = row['parts'][part['name']]
                    if node['alpha'] <= 0: continue
                    transform = pixels.unpack(node['transform'])
                    transform[:2, 2] += 128
                    image = images[part['name']]
                    corners = np.array([[0,0],[image.width,0],[image.width,image.height],[0,image.height]])
                    pts = corners @ transform[:2,:2].T + transform[:2,2]
                    lo = np.maximum(0, np.floor(pts.min(0)).astype(int)-1)
                    hi = np.minimum(512, np.ceil(pts.max(0)).astype(int)+1)
                    if np.any(hi <= lo): continue
                    bounds = (*lo, *hi)
                    samples = nearest_quad(image, transform, bounds, with_ties=True)
                    masks = [pixels.modulated_alpha(c[..., 3], node['alpha']) > 0 for c in samples.candidates]
                    region = np.s_[lo[1]:hi[1],lo[0]:hi[0]]
                    certain[region] |= np.logical_and.reduce(masks)
                    possible[region] |= np.logical_or.reduce(masks)
                cache[signature] = {'safe': bool(safe_occupancy(certain, possible)),
                    'uncertain_pixels': int((possible & ~certain).sum()),
                    'certain_components': [n for _,n in silhouette.components(certain)[1]]}
            metric = dict(view=view, clip=row['clip'], frame=row['frame'], **cache[signature])
            rows.append(metric)
            if not metric['safe']: failures.append(f'{view}/{row["clip"]}/{row["frame"]}: native tie occupancy may disconnect')
    # Prove the conservative test catches the native-only one-pixel bridge and
    # every forbidden 1..8 detached component; a possible union is insufficient.
    mutations = []
    size_px = PROOF_DEFAULTS['mutation_canvas_size']
    left, top, right, bottom = PROOF_DEFAULTS['main_rect']
    stray_x, stray_y = PROOF_DEFAULTS['stray_origin']
    for size in range(1, 9):
        guaranteed = np.zeros((size_px,size_px), dtype=bool); guaranteed[top:bottom,left:right] = True
        possible = guaranteed.copy(); possible[stray_y,stray_x:stray_x+size] = True
        mutations.append(not safe_occupancy(guaranteed, possible))
    guaranteed = np.zeros((size_px,size_px),dtype=bool); guaranteed[top:bottom,left:right] = True
    column = PROOF_DEFAULTS['bridge_column']
    first_row, last_row = PROOF_DEFAULTS['bridge_rows']
    guaranteed[stray_y,column] = True
    possible = guaranteed.copy(); possible[first_row:last_row,column] = True
    mutations.append(not safe_occupancy(guaranteed,possible))
    if not all(mutations): failures.append('Conservative CPU mutations were accepted')
    result = {'ok': not failures, 'native_pixels': False,
        'basis': '8-bit native quad raster, all independent u/v candidates; guaranteed core plus direct adjacency of every optional texel',
        'errors': failures, 'poses': rows, 'mutations_rejected': sum(mutations), 'mutations': len(mutations)}
    write_json(CASE / 'proof/cpu_sweep.json', result)
    print('MQ27 CPU SWEEP: %s (%d poses; %d/%d mutations rejected; %d failures)' % ('PASS' if result['ok'] else 'FAIL', len(rows),sum(mutations),len(mutations),len(failures)))
    for error in failures[:12]: print(error)
    return result


if __name__ == '__main__':
    raise SystemExit(0 if report()['ok'] else 1)
