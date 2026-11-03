"""Immutable rr-39 evidence remains testable after the intentional rr-41 repaint.

Never compare that retained capture to changed production or relabel it current.
The archive preserves the exact former proof inputs, including omitted optional
certificates. Production comparisons use actual retained PNGs and registrations.
"""
from contextlib import contextmanager
from pathlib import Path
import tempfile
import zipfile
import hashlib
from rr41_underlay import BASELINE
from cutout_pipeline.cases import read_json, digest
from humanoid_cutout.gates import bindings


@contextmanager
def legacy_case():
    archive = BASELINE/'rr39_case.zip'
    if digest(archive) != read_json(BASELINE/'baseline.json')['files'][archive.name]:
        raise ValueError('Changed immutable rr-39 proof archive')
    with tempfile.TemporaryDirectory(prefix='rr41-retained-rr39-') as temporary:
        root = Path(temporary)
        with zipfile.ZipFile(archive) as source:
            if any(Path(n).is_absolute() or '..' in Path(n).parts for n in source.namelist()):
                raise ValueError('Invalid retained case path')
            source.extractall(root)
        yield root


def legacy_bindings(case):
    current = bindings(case)
    # rr-43 intentionally replaces the rear and re-owns front shaft paint.
    # Bind the historical capture to actual archived production bytes, never
    # today's production and never hashes copied from the capture manifest.
    prefix = 'production:assets/units/frostglass_lancer_cutout/humanoid_v2/'
    with zipfile.ZipFile(BASELINE/'rr39_case.zip') as archive:
        current[prefix+'front.json'] = hashlib.sha256(
            archive.read('proof/production_front_original.json')).hexdigest()
    from rr37_case import CASE
    rear = CASE/'rr43/retained_production_rear.json'
    if digest(rear) != '7226ca46719164f864766001c83cea58824c7508dccd8d547e4e9022bd35bed1':
        raise ValueError('Changed retained rear production layout')
    current[prefix+'rear.json'] = digest(rear)
    for view in ('front','rear'):
        layout = read_json(case/f'layouts/{view}.json')
        for part in layout['parts']:
            path = BASELINE/'production/front'/Path(part['file']).name if view=='front' else case/part['file']
            current[prefix+view+'/'+path.name] = digest(path)
        current[prefix+view+'/rest.png'] = digest(BASELINE/f'production/{view}/rest.png')
    return current
