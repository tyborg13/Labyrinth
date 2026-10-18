"""Lossless semantic-mask PNG packing before hash-bound native delivery staging.

Keep original clay bytes and every alpha/visible RGBA value. Only undefined
RGB under zero alpha and volatile PNG metadata are removed from mask exports.
Raw native exports remain in task proof until the normal SHA-256 curation.
"""
import json
from pathlib import Path
import shutil
import tempfile

from .capture_manifest import read_manifest,write_manifest
from .contract import digest
from .curate_delivery import canonical_png,sha,write

PACKING_DEFAULTS = {'report': 'capture_packing.json', 'raw_suffix': '_raw_png'}


def compact_capture(spec,folder):
    folder=Path(folder)
    manifest=read_manifest(folder,digest(spec),('full','preview'))
    report_path=folder/PACKING_DEFAULTS['report']
    if report_path.exists():
        report=json.loads(report_path.read_text())
        if report['spec_hash']!=digest(spec) or any(sha(folder/name)!=value['packed_sha256'] for name,value in report['images'].items()):
            raise ValueError('Stale compact-capture report')
        return report
    raw=folder.with_name(folder.name+PACKING_DEFAULTS['raw_suffix'])
    if raw.exists():raise ValueError('Raw export archive already exists; retain it before a replacement pack')
    images={}
    with tempfile.TemporaryDirectory(prefix='png_pack_',dir=folder) as temporary:
        temporary=Path(temporary)
        for name in manifest['images']:
            path=folder/name
            clay=name in ('front_clay.png','rear_clay.png')
            values={'native_sha256':sha(path),'native_bytes':path.stat().st_size,'clay_byte_copy':clay}
            if clay:
                values.update(packed_sha256=values['native_sha256'],packed_bytes=values['native_bytes'])
            else:
                target=temporary/name;target.parent.mkdir(parents=True,exist_ok=True)
                # This helper independently checks all alpha and all RGBA where
                # alpha is nonzero; an encoder/pixel change fails the operation.
                canonical_png(path,target,mask=True)
                values.update(packed_sha256=sha(target),packed_bytes=target.stat().st_size)
            images[name]=values
        raw.mkdir()
        write(raw/'native_capture_manifest.json',manifest)
        shutil.copyfile(folder/'capture_manifest.json',folder/'native_render_manifest.json')
        for name,values in images.items():
            if values['clay_byte_copy']:continue
            target=raw/name;target.parent.mkdir(parents=True,exist_ok=True)
            shutil.move(str(folder/name),str(target))
            (temporary/name).replace(folder/name)
    write_manifest(folder,digest(spec),manifest['mode'],manifest['images'])
    report={'schema':1,'passed':True,'spec_hash':digest(spec),'alpha_and_visible_rgba_unchanged':True,
            'native_clay_bytes_unchanged':True,'images':images,
            'native_render_manifest_sha256':sha(folder/'native_render_manifest.json'),
            'packing':'Lossless mask PNG canonicalisation only; original clay PNG bytes retained.'}
    write(report_path,report)
    print('NATIVE_CAPTURE_PACKING: PASS; raw_bytes='+str(sum(v['native_bytes'] for v in images.values()))+
          '; packed_bytes='+str(sum(v['packed_bytes'] for v in images.values())),flush=True)
    return report
