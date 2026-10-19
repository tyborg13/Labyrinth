"""Rebuild only motion in an existing approved case; preserve density and paint."""
import argparse
import shutil
import hashlib
from pathlib import Path

from cutout_pipeline.cases import read_json, write_json
from .compiler import compile_motion


def rebuild(case, director, assets):
    old = read_json(case / 'compiled_motion.json')
    layouts = {v: read_json(case / f'layouts/{v}.json') for v in old['view_tracks']}
    shutil.copyfile(director, case / 'director_motion.json')
    data = compile_motion(director, old['creature'], layouts, old['projection'])
    for view in layouts:
        for clip in old['clips']:
            if clip != 'move' and old['view_tracks'][view][clip] != data['view_tracks'][view][clip]:
                raise ValueError('Non-move tracks changed: ' + view + '/' + clip)
    for view, layout in layouts.items():
        layout['gait_leg_scale_max'] = data['clips']['move']['gait'].get('leg_scale_max', 1.22)
        write_json(case / f'layouts/{view}.json', layout)
    write_json(case / 'compiled_motion.json', data)
    cutout = read_json(case / 'cutout.json')
    cutout['clips'] = data['clips']
    write_json(case / 'cutout.json', cutout)
    for name in ('compiled_motion.json', 'director_motion.json'):
        shutil.copyfile(case / name, assets / name)
    build = read_json(case / 'proof/build.json')
    build['director_sha256'] = data['director_sha256']
    write_json(case / 'proof/build.json', build)
    integration_path = assets.parent / 'integration.json'
    if integration_path.is_file():
        integration = read_json(integration_path)
        integration['director_sha256'] = data['director_sha256']
        for name in integration['files']:
            path = assets.parent / name
            if path.suffix == '.json': integration['files'][name] = hashlib.sha256(path.read_bytes()).hexdigest()
        write_json(integration_path, integration)
    print('GAIT MOTION REBUILD: PASS (' + old['creature'] + '; non-move tracks unchanged; paint/density untouched)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('case', 'director', 'assets'): parser.add_argument('--' + name, type=Path, required=True)
    rebuild(**vars(parser.parse_args()))
