"""Feedback 2 ownership, continuous held paint and shared-anchor invariants."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import digest
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components


def errors(case, layout):
    from rr34_layering import errors as layering_errors
    findings = layering_errors(layout)
    source = np.asarray(Image.open(case / layout['rest_source']).convert('RGBA'))
    partition = np.zeros(source.shape[:2], dtype=int)
    parts = {p['name']: p for p in layout['parts']}
    for record in layout.get('ownership_repairs', []):
        path = case / record['file']
        if digest(path) != record['sha256']:
            findings.append('repair ownership hash differs: ' + record['piece'])
        expected = np.asarray(Image.open(path)) > 0
        actual = source_pixels(case, parts[record['piece']])
        partition += expected
        if int(expected.sum()) != record['pixels'] or not np.array_equal(expected, actual[..., 3] > 0):
            findings.append('repair ownership differs: ' + record['piece'])
        if np.any(actual[expected] != source[expected]):
            findings.append('repair changed approved paint: ' + record['piece'])
    if not np.array_equal(partition, (source[..., 3] > 0).astype(int)):
        findings.append('repair partition must own every approved pixel exactly once')
    for name in ('horn', 'hand_far'):
        anchor = np.floor(np.asarray(layout['joints'][name]['position']) + .5).astype(int).tolist()
        for part in (parts[name], parts['hidden_' + name]):
            if part.get('presentation_anchor') != anchor:
                findings.append('held-piece grip anchor differs: ' + part['name'])
    if parts['hand_far']['z_index'] <= parts['horn']['z_index']:
        findings.append('horn shaft must draw behind the gripping fist')
    horn = [source_pixels(case, parts[n])[..., 3] > 0 for n in ('horn', 'hidden_horn')]
    if len(components(horn[0] | horn[1], 8)[1]) != 1:
        findings.append('horn source shaft is not continuous through the fist')
    return findings
