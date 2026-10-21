"""Source-only belt, flap and iron ownership; annotations never enter paint."""
import numpy as np
from PIL import Image
from rr22_cut_sheet import outlined, CUT_SHEET_ZOOM, CUT_BOUNDARY_RGBA
from maquette_motion.silhouette import dilate

CUT_GROUPS = ('belt', 'flap', 'bracer_near', 'bracer_far')
CUT_ROWS = ('front', 'rear')


def write_sheet(case, views):
    size = views['front']['paint'].shape[0]
    sheet = Image.new('RGBA', (size * (1 + len(CUT_GROUPS)), size * len(CUT_ROWS)))
    for row, view in enumerate(CUT_ROWS):
        data = views[view]
        paint, owners, names = data['paint'], data['owners'], data['names']
        overview = paint.copy()
        for column, name in enumerate(CUT_GROUPS, 1):
            mask = owners == names.index(name)
            overview[mask & dilate(~mask, 1, grid_distance=True)] = CUT_BOUNDARY_RGBA
            sheet.alpha_composite(outlined(paint, mask), (column * size, row * size))
        sheet.alpha_composite(Image.fromarray(overview), (0, row * size))
    path = case / 'proof/contact_sheets/source_cuts_outlined.png'
    path.parent.mkdir(parents=True, exist_ok=True)
    sheet.resize((sheet.width * CUT_SHEET_ZOOM, sheet.height * CUT_SHEET_ZOOM), Image.Resampling.NEAREST).save(path)
    return path
