"""Lossless numerical mq-17 shape reference; no image-library dependency."""
import base64
import gzip
import json
from spec.art_identity.maquettes.blender.contract import digest

REFERENCE_DEFAULTS={'gzip_level':9,'gzip_mtime':0}
CHANGED={'near_cloak_streamer','front_tabard','tabard_sigils','staff','pennant_sigils'}|{'finger_near_'+str(i) for i in range(4)}


def encode(baseline):
    values={p['id']:p['vertices'] for p in baseline['pieces'] if p['id'] not in CHANGED}
    raw=json.dumps(values,sort_keys=True,separators=(',',':')).encode()
    return {'sha256':digest(values),'gzip_json_base64':base64.b64encode(gzip.compress(raw,
        compresslevel=REFERENCE_DEFAULTS['gzip_level'],mtime=REFERENCE_DEFAULTS['gzip_mtime'])).decode()}


def decode(reference):
    values=json.loads(gzip.decompress(base64.b64decode(reference['gzip_json_base64'])))
    if digest(values)!=reference['sha256']:raise ValueError('Corrupt immutable shape reference')
    return values
