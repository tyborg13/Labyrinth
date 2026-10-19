"""Shared both-leg walk gates and independent registered production rest."""
import numpy as np
from rr18_case import PROJECT, ASSETS
from humanoid_cutout.walk_gates import report as knee_report, support_report


def production_rest_report(layout, case, assets):
    """Compare production with independent density derivation, never raw paint.

    Source-space authoring identity remains a separate zero-pixel gate. The
    expected rest is composed from untouched adopted pieces processed by the
    registered density rule. Native sealing still requires the director.
    """
    from PIL import Image
    from cutout_pipeline.cases import read_json
    import process_board_density as density
    view = layout['facing']
    entry = next(e for e in density.load_registry()['entries'] if e['id']=='glacial_mirror_cutout')
    shipped = read_json(assets/'humanoid_v2'/(view+'.json'))
    actual = Image.new('RGBA',tuple(shipped['canvas_size']))
    expected = Image.new('RGBA',actual.size)
    errors = []
    for part in sorted(shipped['parts'],key=lambda p:p['z_index']):
        # Temporary mutation assets use the same immutable density registration.
        relative = str((ASSETS/'humanoid_v2'/part['file']).relative_to(PROJECT))
        derived, _ = density.derive(entry,relative)
        actual.alpha_composite(Image.open(assets/'humanoid_v2'/part['file']).convert('RGBA'),tuple(part['offset']))
        expected.alpha_composite(derived,tuple(part['offset']))
    mismatch = int(np.any(np.asarray(actual)!=np.asarray(expected),axis=-1).sum())
    rest = np.asarray(Image.open(assets/'humanoid_v2'/shipped['rest_source']).convert('RGBA'))
    rest_mismatch = int(np.any(rest!=np.asarray(expected),axis=-1).sum())
    errors += [f'{view}: treated production rest differs from density-processed reference by {mismatch} px; required 0'] if mismatch else []
    if rest_mismatch: errors.append(f'{view}: production rest snapshot differs from density-processed reference by {rest_mismatch} px')
    return {'ok':not errors,'errors':errors,'mismatch_pixels':mismatch,'snapshot_mismatch_pixels':rest_mismatch,
            'scope':'exact density-derived source-space rest; native seal pending director'}
