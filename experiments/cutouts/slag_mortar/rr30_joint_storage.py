"""Operational cover cuts stay JSON; repeated sweep evidence is a sidecar.

Construction reads only basis/cuts, without opening the evidence. Calibration
extension verifies and restores the complete historical evidence before adding
observations. Legacy inline records can be repackaged without recalibrating art.
"""
import gzip
import json
from cutout_pipeline.cases import digest,read_json,write_json

VIEWS=('front','rear')
EVIDENCE_GZIP_LEVEL=9
EVIDENCE_GZIP_MTIME=0  # Stable packaging, not a capture or animation timestamp.


def read_evidence(path,record):
    if 'full_evidence' not in record:
        return {view:record[view].get('evidence',[]) for view in VIEWS}
    reference=record['full_evidence']
    sidecar=path.parent/reference['file']
    if digest(sidecar)!=reference['sha256']:
        raise ValueError('Joint calibration evidence hash differs: '+str(sidecar))
    result=json.loads(gzip.decompress(sidecar.read_bytes()))
    if {view:len(result[view]) for view in VIEWS}!=reference['rows']:
        raise ValueError('Joint calibration evidence inventory differs')
    return result


def write_calibration(path,record):
    details={view:record[view]['evidence'] for view in VIEWS}
    sidecar=path.with_suffix('.evidence.json.gz')
    payload=(json.dumps(details,separators=(',',':'),allow_nan=False)+'\n').encode()
    sidecar.parent.mkdir(parents=True,exist_ok=True)
    sidecar.write_bytes(gzip.compress(payload,compresslevel=EVIDENCE_GZIP_LEVEL,
                                     mtime=EVIDENCE_GZIP_MTIME))
    compact={view:{k:v for k,v in record[view].items() if k!='evidence'} for view in VIEWS}
    compact['full_evidence']=dict(file=sidecar.name,sha256=digest(sidecar),
                                rows={view:len(rows) for view,rows in details.items()})
    write_json(path,compact)
    return compact


def compact_calibration(path):
    record=read_json(path)
    details=read_evidence(path,record)
    return write_calibration(path,{view:dict(record[view],evidence=details[view]) for view in VIEWS})
