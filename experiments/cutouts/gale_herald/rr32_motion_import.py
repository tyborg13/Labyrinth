"""Import director replacement motion without rebuilding registered art/density."""
import shutil
import sys
from rr32_case import PROJECT, CASE, ASSETS, DIRECTOR, HAND_DIRECTION_CLIPS, BODY_DIRECTION_CLIPS, PLACEHOLDERS
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion


def import_motion():
    # Freeze the entire registered paint and anatomy closure across this import.
    preserved = {str(p.relative_to(PROJECT)): digest(p) for root in (CASE, ASSETS)
                 for p in root.rglob('*.png') if 'proof' not in p.relative_to(root).parts}
    for path in [CASE / 'anatomy.json', *[CASE / f'layouts/{v}.json' for v in ('front', 'rear')],
                 *[ASSETS / base / f'{v}.json' for base in ('', 'humanoid_v2') for v in ('front', 'rear')]]:
        preserved[str(path.relative_to(PROJECT))] = digest(path)
    protected_digest = digest(DIRECTOR)
    old = read_json(CASE / 'compiled_motion.json')
    layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in old['view_tracks']}
    compiled = compile_motion(DIRECTOR, old['creature'], layouts, old['projection'])
    for root in (CASE, ASSETS / 'humanoid_v2'):
        shutil.copyfile(DIRECTOR, root / 'director_motion.json')
        write_json(root / 'compiled_motion.json', compiled)
    inputs = read_json(CASE / 'inputs.json')
    inputs['design_placeholders'] = PLACEHOLDERS
    write_json(CASE / 'inputs.json', inputs)
    cutout = read_json(CASE / 'cutout.json')
    cutout.update(clips=compiled['clips'], design_placeholders=PLACEHOLDERS,
                  direction_clips=HAND_DIRECTION_CLIPS, body_direction_clips=BODY_DIRECTION_CLIPS)
    write_json(CASE / 'cutout.json', cutout)
    build = read_json(CASE / 'proof/build.json')
    build['director_sha256'] = compiled['director_sha256']
    write_json(CASE / 'proof/build.json', build)
    path = ASSETS / 'integration.json'
    integration = read_json(path)
    integration.update(director_sha256=compiled['director_sha256'], design_placeholders=PLACEHOLDERS)
    for name in integration['files']: integration['files'][name] = digest(ASSETS / name)
    write_json(path, integration)
    assert digest(DIRECTOR) == protected_digest, 'Protected source changed during import'
    assert all(digest(PROJECT / path) == expected for path, expected in preserved.items()), 'Paint/anatomy changed during motion import'
    write_json(CASE / 'proof/motion_import.json', {'director_sha256': protected_digest,
        'imported_byte_identical': all((root / 'director_motion.json').read_bytes() == DIRECTOR.read_bytes()
                                     for root in (CASE, ASSETS / 'humanoid_v2')),
        'preserved_inputs_sha256': preserved, 'design_placeholders': PLACEHOLDERS,
        'authority': 'rr-32 director feedback 1; supplied protected replacement motion'})
    print('RR32 MOTION IMPORT: PASS (protected bytes exact; %d paint/anatomy files unchanged)' % len(preserved))


if __name__ == '__main__': import_motion()
