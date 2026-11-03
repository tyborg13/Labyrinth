"""rr-51: the Gaoler at the director's art_scale, density re-derived by the unchanged rule.

The director's decision (owner verdict gaoler-rig-2, 2026-10-29) is data:
`data/enemies.json` `chainbound_gaoler.art_scale`. This stage only re-derives
what depends on it, through the existing board-density tool and rr-38/rr-44
seals. Paint, cut, caps, underlays and motion are never written here.

  PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr51_scale.py density
  PYTHONPATH=tools python3 -B experiments/cutouts/chainbound_gaoler/rr51_scale.py check
"""
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from rr44_case import PROJECT, CASE, ASSETS
from cutout_pipeline.cases import read_json

DENSITY = PROJECT / 'spec/assets/board_pixel_density'
REGISTRY = DENSITY / 'registry.json'
LIVE_ID = 'chainbound_gaoler_cutout'
LEGACY_ID = 'chainbound_gaoler'
GAOLER_IDS = (LEGACY_ID, LIVE_ID)
# The approved scale before rr-51 (data/enemies.json at f4c938f36).
PRIOR_SCALE = 0.9
RETIRED_RIG_COMMIT = '783c9839b3c0b3857a5a1e1204e7f6176ce0321e'
# Director decision (2026-10-29): the retired rr-38 cutout keeps its approved
# 2026-10-07 grids under this override. Its parts are
# never drawn (the humanoid_v2 entry is the live Gaoler) and its rig script is
# gone, so its two rests can never be rebaked after a reprocess.
LEGACY_OVERRIDE = ('rr-51 director decision 2026-10-29: retired pre-rr-38 Gaoler cutout parts, never drawn (the humanoid_v2 entry '
                   'chainbound_gaoler_cutout is the live Gaoler at r = art_scale); its rig script was removed in '
                   '783c9839b, so its rests cannot be rebaked. Keeps its approved 2026-10-07 grids '
                   '(1.23 / 1.46, derived at r 0.9); r follows art_scale.')


def art_scale(root=PROJECT):
    """The single game value, read through the case's declared scale source."""
    scale = read_json(CASE / 'anatomy.json')['integration']['scale']
    definition = read_json(Path(root) / scale['file'])[scale['key']]
    return float(definition.get(scale['field'], scale['default']))


def rule(share, r):
    """The board-density rule, from the tool itself (no local copy of t or the threshold)."""
    from pixel_density import strength
    t = strength(share)
    grid = round(t / r, 2)
    return {'t': t, 'grid': grid, 'mode': 'regrid' if grid >= 1.2 else 'clean'}


def derived_entries(registry, scale):
    """Both Gaoler entries at `scale`; every other entry is returned untouched."""
    sys.path.insert(0, str(PROJECT / 'tools'))
    import process_board_density as tool
    from pixel_density import metrics
    entries = {e['id']: e for e in registry['entries']}
    live = json.loads(json.dumps(entries[LIVE_ID]))
    live['r'] = scale
    for settings in live['facings'].values():
        share = metrics(tool.calibration_sample(live, settings))['orphan_share']
        settings.update(orphan_share=share, **rule(share, scale))
    legacy = json.loads(json.dumps(entries[LEGACY_ID]))
    legacy['r'] = scale
    for facing, settings in legacy['facings'].items():
        share = metrics(tool.calibration_sample(legacy, settings))['orphan_share']
        approved = rule(share, PRIOR_SCALE)
        if (share, approved['t'], approved['grid'], approved['mode']) != (
                settings['orphan_share'], settings['t'], settings['grid'], settings['mode']):
            raise ValueError('Legacy Gaoler facing no longer matches its approved derivation: ' + facing)
    ordered = {}
    for key, value in legacy.items():
        if key != 'override': ordered[key] = value
        if key == 'r_derivation': ordered['override'] = LEGACY_OVERRIDE
    return {LEGACY_ID: ordered, LIVE_ID: live}


def write_registry(scale):
    registry = read_json(REGISTRY)
    replaced = derived_entries(registry, scale)
    registry['entries'] = [replaced.get(e['id'], e) for e in registry['entries']]
    REGISTRY.write_text(json.dumps(registry, indent=2, allow_nan=False) + '\n')
    return replaced


def family_hashes():
    return {str(p.relative_to(PROJECT)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(ASSETS.rglob('*')) if p.is_file()}


def tool(*args):
    subprocess.run([sys.executable, 'tools/process_board_density.py', *args], cwd=PROJECT, check=True)


def density():
    scale = art_scale()
    before = family_hashes()
    replaced = write_registry(scale)
    # Records only: clean-mode output pixels do not depend on the grid value,
    # and every encoded PNG must come back byte-identical.
    tool('--only', LIVE_ID)
    changed = [p for p, h in family_hashes().items() if before.get(p) != h]
    if changed or set(before) != set(family_hashes()):
        raise ValueError('Gaoler asset bytes changed during the scale re-derivation: ' + str(changed))
    import rr44_density
    pending = rr44_density.seal()
    if pending:
        raise ValueError('Gaoler rest rebake pending after re-derivation: ' + str(pending))
    changed = [p for p, h in family_hashes().items() if before.get(p) != h]
    if changed:
        raise ValueError('The identity seal changed Gaoler asset bytes: ' + str(changed))
    # `--report` has failed since rr-07 (storm_capacitor_cutout facings own no
    # facing-named paths); report.md is not regenerated by any unit since then.
    tool('--check')
    live = replaced[LIVE_ID]['facings']
    print('RR51 DENSITY: PASS (r=%.2f; front %s %.2f; rear %s %.2f; paint, rests and integration byte-identical)' %
          (scale, live['front']['mode'], live['front']['grid'], live['rear']['mode'], live['rear']['grid']))


def check(root=PROJECT):
    """Every Gaoler density record equals its rule derivation at the live art_scale."""
    scale = art_scale(root)
    registry = read_json(Path(root) / 'spec/assets/board_pixel_density/registry.json')
    expected = derived_entries(registry, scale)
    actual = {e['id']: e for e in registry['entries'] if e['id'] in GAOLER_IDS}
    errors = [name for name in GAOLER_IDS if actual.get(name) != expected[name]]
    return errors


if __name__ == '__main__':
    if sys.argv[1:] == ['density']:
        density()
    elif sys.argv[1:] == ['check']:
        failures = check()
        if failures:
            raise SystemExit('RR51 DENSITY CHECK: FAIL ' + str(failures))
        print('RR51 DENSITY CHECK: PASS')
    else:
        raise SystemExit(__doc__)
