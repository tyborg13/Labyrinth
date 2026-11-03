"""Lossless, hash-bound storage of the unchanged foreign-source inventory."""
import gzip
import hashlib
import json
import os
from pathlib import Path

from spec.art_identity.maquettes.blender.curate_delivery import sha,write

INVENTORY_DEFAULTS={'compression_level':9,'gzip_mtime':0,
                    'payload_name':'preservation_inventory.json.gz'}


def load_preservation(folder):
    folder=Path(folder);receipt=json.loads((folder/'preservation.json').read_text())
    if 'files' in receipt:
        result=receipt
    else:
        if (receipt.get('schema')!='mq17_lossless_preservation_v1' or
            receipt.get('payload')!=INVENTORY_DEFAULTS['payload_name']):raise ValueError('Invalid preservation inventory receipt')
        payload=folder/receipt['payload']
        if sha(payload)!=receipt.get('payload_sha256'):raise ValueError('Preservation payload hash differs')
        try:raw=gzip.decompress(payload.read_bytes())
        except (OSError,EOFError) as error:raise ValueError('Invalid preservation payload') from error
        if hashlib.sha256(raw).hexdigest()!=receipt.get('original_json_sha256'):raise ValueError('Expanded preservation hash differs')
        result=json.loads(raw)
        if (receipt.get('file_count')!=len(result.get('files',{})) or
            receipt.get('compiled_spec_count')!=len(result.get('compiled_foreign_specs',[])) or
            receipt.get('passed') is not True or receipt.get('builder_changed') is not False):raise ValueError('Preservation summary differs')
    if (result.get('passed') is not True or result.get('builder_changed') is not False or not result.get('files') or
        not result.get('compiled_foreign_specs') or any(v.get('passed') is not True for v in result['files'].values())):
        raise ValueError('Missing or failed foreign-source preservation')
    return result


def compact_preservation(folder):
    folder=Path(folder);path=folder/'preservation.json';original=load_preservation(folder)
    if 'files' not in json.loads(path.read_text()):return
    raw=path.read_bytes();payload=folder/INVENTORY_DEFAULTS['payload_name']
    compressed=gzip.compress(raw,compresslevel=INVENTORY_DEFAULTS['compression_level'],mtime=INVENTORY_DEFAULTS['gzip_mtime'])
    with payload.open('wb') as stream:
        stream.write(compressed);stream.flush();os.fsync(stream.fileno())
    write(path,{'schema':'mq17_lossless_preservation_v1','passed':True,'builder_changed':False,
        'file_count':len(original['files']),'compiled_spec_count':len(original['compiled_foreign_specs']),
        'payload':payload.name,'payload_sha256':sha(payload),'original_json_sha256':hashlib.sha256(raw).hexdigest(),
        'storage':'Complete original JSON bytes, losslessly gzip-compressed; every source hash and result is retained.'})
    if load_preservation(folder)!=original:raise ValueError('Lossless preservation round trip differs')
    print('MQ17_PRESERVATION_PACKING: PASS; original_bytes='+str(len(raw))+'; packed_bytes='+str(len(compressed)),flush=True)
