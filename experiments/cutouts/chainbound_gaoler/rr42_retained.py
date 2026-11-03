"""Replay the immutable director capture across analysis-only Python changes."""
from rr42_underlay import CASE
from cutout_pipeline.cases import read_json,digest

SOURCE_MANIFEST_SHA256='3180050c54f6702a805238e97da70c3435b1d74ede47fc21f8bf7f6904caae71'
FIXTURE_MANIFEST_SHA256='3d0b1241dad17952f9f91e5996fa58b5b9bdeec853fc1048a893d8123123f2cf'
ANALYSIS_ONLY_INPUTS=frozenset(('runtime:tools/humanoid_cutout/gates.py',
                              'runtime:tools/humanoid_cutout/proof.py',
                              'runtime:tools/maquette_motion/pixels.py',
                              'runtime:tools/maquette_motion/raster.py'))
FIXTURE=CASE/'proof/feedback2_native'


def verify_inputs(recorded,current):
    if digest(FIXTURE/'manifest.json')!=FIXTURE_MANIFEST_SHA256:
        raise ValueError('Changed retained native calibration fixture')
    fixture=read_json(FIXTURE/'manifest.json')
    if fixture['source_manifest_sha256']!=SOURCE_MANIFEST_SHA256 or recorded!=fixture['inputs']:
        raise ValueError('Retained native input fixture changed')
    changed={key for key in recorded.keys()|current.keys() if recorded.get(key)!=current.get(key)}
    if not changed<=ANALYSIS_ONLY_INPUTS:
        raise ValueError('Retained render inputs changed: '+', '.join(sorted(changed-ANALYSIS_ONLY_INPUTS)))
    if recorded.keys()!=current.keys():raise ValueError('Retained input inventory changed')
    return {key:dict(before=recorded[key],after=current[key]) for key in sorted(changed)}


def verify(recorded,current,capture):
    if digest(capture/'frames.json')!=SOURCE_MANIFEST_SHA256:
        raise ValueError('Retained capture is not the director round-1 manifest')
    return verify_inputs(recorded,current)


def current(case,capture):
    from humanoid_cutout.gates import bindings
    manifest=read_json(capture/'frames.json')
    valid=(manifest.get('native_pixels') and manifest.get('ok') and manifest.get('size')==[1920,1080]
           and manifest.get('ui_scale')==1 and 'clip_scope' not in manifest)
    if not valid:return False
    expected=bindings(case)
    if manifest.get('inputs')==expected:return True
    try:verify(manifest['inputs'],expected,capture)
    except ValueError:return False
    return True
