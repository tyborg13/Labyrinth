"""Optional proof-surface capacity; source pixels and authored poses are unchanged."""
from contextlib import contextmanager
from cutout_pipeline.cases import read_json
from maquette_motion import pixels


@contextmanager
def for_case(case):
    geometry=read_json(case/'cutout.json').get('proof_geometry')
    if geometry is None:
        yield
        return
    size,offset=geometry['canvas_size'],geometry['source_offset']
    if type(size) is not int or type(offset) is not int or size<255 or offset<0 or offset+255>size:
        raise ValueError('Invalid proof canvas geometry')
    before=dict(pixels.PROOF_DEFAULTS)
    pixels.PROOF_DEFAULTS.update(canvas_size=size,source_offset=offset)
    try: yield
    finally:
        pixels.PROOF_DEFAULTS.clear();pixels.PROOF_DEFAULTS.update(before)
