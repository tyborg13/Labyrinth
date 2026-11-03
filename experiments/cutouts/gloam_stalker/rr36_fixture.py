"""Retain exact e4b native payloads needed by the five regression diagnostics.

This copies captured PNG bytes. It never renders, draws, resamples or changes
pixels. The subset is explicitly not a complete native acceptance capture.
"""
import shutil
from rr35_case import CASE, PROJECT
from rr36_native_checks import FRAMES
from cutout_pipeline.cases import read_json, write_json, digest

TARGET = PROJECT / 'experiments/cutouts/gloam_stalker/rr36_native_fixture'
NAMES = ('foot_far', 'leg_near', 'hidden_leg_near', 'pelvis', 'hidden_cape_near', 'hidden_cape_far')


def retain(source=CASE / 'proof/e4b60147b_native'):
    manifest = read_json(source / 'frames.json')
    selected = {frame for rows in FRAMES.values() for frame in rows}
    result = {k: manifest[k] for k in ('native_pixels', 'size', 'ui_scale', 'fps', 'inputs')}
    result.update(source_revision='e4b60147b4b87ced5e4a5195df827c2214b4fdb8',
                  source_manifest_sha256=digest(source / 'frames.json'),
                  selection_only=True, purpose='negative-control fixture; never current acceptance proof')
    result['frames'] = [r for r in manifest['frames'] if (r['view'], r['clip'], r['frame']) in selected]
    result['pieces'] = [r for r in manifest['pieces'] if (r['view'], r['clip'], r['frame']) in selected and r['name'] in NAMES]
    files = [r['file'] for r in result['frames'] + result['pieces']]
    index = read_json(source / 'native_storage.json')
    kept = {name: index['files'][name] for name in files}
    for record in kept.values():
        target = TARGET / record['stored_file']
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source / record['stored_file'], target)
    write_json(TARGET / 'native_storage.json', dict(version=index['version'], files=kept))
    write_json(TARGET / 'frames.json', result)
    print(f'RR36 LEGACY NATIVE FIXTURE: PASS ({len(result["frames"])} frames, {len(result["pieces"])} isolated layers; exact payload bytes)')


if __name__ == '__main__': retain()
