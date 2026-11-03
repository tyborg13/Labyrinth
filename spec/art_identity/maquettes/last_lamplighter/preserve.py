"""Lossless, hash-verified storage for the unchanged foreign-file inventory."""
import gzip
import base64
import json
import lzma
from pathlib import Path
from spec.art_identity.maquettes.blender.curate_delivery import write,sha

PACKING_DEFAULTS={'compression_level':9,'gzip_mtime':0,'inventory':'preservation_files.json.gz',
                  'discard_inventory':'discarded_proof_files.json.xz','lzma_preset':6}


def save(folder,result):
    folder=Path(folder);summary=dict(result);files=summary.pop('files')
    raw=json.dumps(files,sort_keys=True,separators=(',',':')).encode()
    inventory=folder/PACKING_DEFAULTS['inventory']
    inventory.write_bytes(gzip.compress(raw,compresslevel=PACKING_DEFAULTS['compression_level'],mtime=PACKING_DEFAULTS['gzip_mtime']))
    summary.update(inventory_file=inventory.name,inventory_sha256=sha(inventory),files_count=len(files))
    write(folder/'preservation.json',summary)


def load(folder):
    folder=Path(folder);report=json.loads((folder/'preservation.json').read_text())
    if 'files' in report:return report
    inventory=folder/report['inventory_file']
    if sha(inventory)!=report['inventory_sha256']:raise ValueError('Stale preservation inventory')
    report['files']=json.loads(gzip.decompress(inventory.read_bytes()))
    if len(report['files'])!=report['files_count']:raise ValueError('Preservation inventory count differs')
    return report


def load_discard(archive):
    archive=Path(archive);report=json.loads(archive.read_text())
    if 'files' in report:return report
    payload=archive.with_name(report['inventory_file'])
    if sha(payload)!=report['inventory_sha256']:raise ValueError('Stale discarded-proof inventory')
    decompress=lzma.decompress if payload.suffix=='.xz' else gzip.decompress
    report['files']=json.loads(decompress(payload.read_bytes()))
    if len(report['files'])!=report['files_count']:raise ValueError('Discarded-proof inventory count differs')
    return report


def discard(folder,paths,archive):
    """Keep the complete durable-before-removal receipt through repeat curation."""
    from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence
    archive=Path(archive);paths=list(paths)
    if archive.exists():
        report=load_discard(archive);previous=archive.with_name(report.get('inventory_file',PACKING_DEFAULTS['discard_inventory']))
        if previous.is_file() and previous.name!=PACKING_DEFAULTS['discard_inventory']:paths.append(previous)
        write(archive,report)
    discard_evidence(folder,paths,archive)
    report=json.loads(archive.read_text());files=report.pop('files')
    payload=archive.with_name(PACKING_DEFAULTS['discard_inventory'])
    payload.write_bytes(lzma.compress(json.dumps(files,separators=(',',':')).encode(),preset=PACKING_DEFAULTS['lzma_preset']))
    report.update(inventory_file=payload.name,inventory_sha256=sha(payload),files_count=len(files))
    write(archive,report)


def compact_auxiliary(folder):
    """Losslessly encode completed auxiliary logs; native capture bytes stay intact."""
    folder=Path(folder)
    pack_bridge(folder)
    paths=list((folder/'delivery/validation/bridge').glob('*'))
    paths += [folder/'delivery/validation/regeneration/clean_input_sha256.json']
    paths += [folder/n for n in ('f1_python_isolation_audit.log','f1_art_identity.log','f1_native_proof.log','f1_regeneration.log')]
    for path in paths:
        if not path.is_file() or path.suffix not in ('.log','.json') or path.stat().st_size<1024:continue
        raw=path.read_bytes();packed=gzip.compress(raw,compresslevel=PACKING_DEFAULTS['compression_level'],mtime=PACKING_DEFAULTS['gzip_mtime'])
        if len(packed)>=len(raw):continue
        destination=path.with_name(path.name+'.gz')
        if destination.exists():discard(folder,[destination],folder/'discarded_proof_sha256.json')
        destination.write_bytes(packed)
        if gzip.decompress(destination.read_bytes())!=raw:raise ValueError('Auxiliary packing changed bytes')
        discard(folder,[path],folder/'discarded_proof_sha256.json')


def pack_bridge(folder):
    """One lossless archive shares repeated bridge paths without touching renders."""
    folder=Path(folder);directory=folder/'delivery/validation/regeneration/bridge'
    paths=sorted(p for p in directory.glob('*') if p.is_file())
    if not paths:return
    files={p.name:base64.b64encode(p.read_bytes()).decode('ascii') for p in paths}
    raw=json.dumps({'encoding':'base64','files':files},separators=(',',':')).encode()
    destination=directory.parent/'bridge_evidence.json.gz'
    if destination.exists():discard(folder,[destination],folder/'discarded_proof_sha256.json')
    destination.write_bytes(gzip.compress(raw,compresslevel=PACKING_DEFAULTS['compression_level'],mtime=PACKING_DEFAULTS['gzip_mtime']))
    observed=json.loads(gzip.decompress(destination.read_bytes()))['files']
    if any(base64.b64decode(observed[p.name])!=p.read_bytes() for p in paths):
        raise ValueError('Bridge evidence packing changed bytes')
    discard(folder,paths,folder/'discarded_proof_sha256.json')
    if not any(directory.iterdir()):directory.rmdir()
