"""Reuse only a positive exact-pixel proof with unchanged models and native bytes."""
from cutout_pipeline.cases import read_json,digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import frame_digest


def key(case,capture):
    from rr42_sweep import diagnostic_bindings
    return dict(inputs=bindings(case),models=diagnostic_bindings(),
                samples_sha256=digest(case/'proof/logs/samples.json'),
                native_manifest_sha256=digest(capture/'frames.json'))


def positive(case,capture,manifest,expected):
    path=case/'proof/logs/rr42_native_paint.json'
    if not path.exists():return None
    report=read_json(path)
    if not report.get('ok') or report.get('errors') or not report.get('native_pixels') or report.get('cache_key')!=expected:return None
    wanted={(r['clip'],r['frame']) for r in manifest['frames'] if r['view']=='front'}
    rows=report.get('frames',[])
    if len(rows)!=len(wanted) or {(r['clip'],r['frame']) for r in rows}!=wanted:return None
    if any(any(r['metrics'].values()) for r in rows):return None
    # A manifest alone is insufficient: a changed native PNG must invalidate
    # reuse even if its manifest was not updated. Check every retained layer.
    for row in manifest['pieces']:
        if row['view']=='front' and frame_digest(capture/row['file'])!=row['sha256']:
            raise ValueError('Changed native layer: '+row['file'])
    return dict(report,cached=True)
