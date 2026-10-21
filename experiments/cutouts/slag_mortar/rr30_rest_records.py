"""Retain certified density-treated rests when untreated source rest is unchanged.

Promotion temporarily copies the untreated painting. The certified native rest
also includes the existing density process; it must not be replaced with that
untreated copy. This preserves provenance, not new renderer acceptance.
"""
from PIL import Image
from cutout_pipeline.cases import read_json,write_json,digest


def retain(assets):
    return {view:(assets/view/'rest.png').read_bytes() for view in ('front','rear')
            if (assets/view/'rest.png').exists()}


def restore(assets,records,source_rests):
    for view,original in records.items():
        path=assets/view/'rest.png'
        with Image.open(source_rests[view]) as before,Image.open(path) as current:
            if before.size!=current.size or before.convert('RGBA').tobytes()!=current.convert('RGBA').tobytes():
                raise ValueError(view+': promoted untreated rest differs from approved source')
        path.write_bytes(original)
        layout=read_json(assets/(view+'.json'));layout['rest_source_sha256']=digest(path)
        write_json(assets/(view+'.json'),layout)
