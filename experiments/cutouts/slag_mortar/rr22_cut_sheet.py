"""Source-only diagnostic: outlines are proof annotations, never runtime paint."""
from PIL import Image
import numpy as np
from maquette_motion.silhouette import dilate

CUT_SHEET_ZOOM = 3
CUT_SHEET_COLUMNS = 4
CUT_SHEET_ROWS = 2
CUT_BOUNDARY_RGBA = (255, 255, 255, 255)


def outlined(paint, selected):
    image = np.zeros_like(paint)
    image[selected] = paint[selected]
    edge = selected & dilate(~selected, 1, grid_distance=True)
    image[edge] = CUT_BOUNDARY_RGBA
    return Image.fromarray(image)


def write_sheet(case, views):
    size = views['front']['paint'].shape[0]
    sheet = Image.new('RGBA', (size * CUT_SHEET_COLUMNS, size * CUT_SHEET_ROWS))
    for row, view in enumerate(('front', 'rear')):
        data = views[view]
        paint, owners, names = data['paint'], data['owners'], data['names']
        if view == 'front':
            groups = [('mortar',), ('torso',), ('upper_near', 'fore_near')]
        else:
            groups = [('fore_near',), ('hand_near',), ('upper_near', 'fore_near', 'hand_near')]
        overview = paint.copy()
        for group in groups[:2]:
            mask = np.isin(owners, [names.index(n) for n in group])
            edge = mask & dilate(~mask, 1, grid_distance=True)
            overview[edge] = CUT_BOUNDARY_RGBA
        sheet.alpha_composite(Image.fromarray(overview), (0, row * size))
        for column, group in enumerate(groups, 1):
            mask = np.isin(owners, [names.index(n) for n in group])
            sheet.alpha_composite(outlined(paint, mask), (column * size, row * size))
    path = case / 'proof/contact_sheets/source_cuts_outlined.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.resize((sheet.width * CUT_SHEET_ZOOM, sheet.height * CUT_SHEET_ZOOM), Image.Resampling.NEAREST).save(path)
    return path
