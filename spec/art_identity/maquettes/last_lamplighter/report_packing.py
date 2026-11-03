"""Remove redundant ray point clouds after preserving raw report hashes.

Counts, checks, geometry hashes, measurements and ownership are untouched.
This is offline evidence curation, not a relaxed acceptance validator.
"""
from copy import deepcopy
import json
from pathlib import Path
import shutil
from spec.art_identity.maquettes.blender.curate_delivery import sha,write

REPORT_NAMES=('build_report.json','native_probe.json')


def without_points(value):
    if isinstance(value,dict):return {k:without_points(v) for k,v in value.items() if k!='visible_points_body'}
    if isinstance(value,list):return [without_points(v) for v in value]
    return value


def compact_reports(folder,archive):
    folder,archive=Path(folder),Path(archive);archive.mkdir(parents=True,exist_ok=True)
    receipt=folder/'report_packing.json'
    if receipt.exists():
        report=json.loads(receipt.read_text())
        if any(sha(folder/n)!=r['packed_sha256'] for n,r in report['reports'].items()):raise ValueError('Stale packed reports')
        return report
    result={}
    for name in REPORT_NAMES:
        path=folder/name;before=sha(path);original=json.loads(path.read_text())
        destination=archive/(path.stem+'_'+before+'.json');shutil.copyfile(path,destination)
        packed=without_points(original);write(path,packed)
        if json.loads(path.read_text())!=without_points(deepcopy(original)):raise ValueError('Report packing changed observations')
        result[name]={'native_sha256':before,'packed_sha256':sha(path),
                      'native_bytes':destination.stat().st_size,'packed_bytes':path.stat().st_size}
    report={'passed':True,'measurements_counts_checks_hashes_unchanged':True,'removed_fields':['visible_points_body'],'reports':result}
    write(receipt,report)
    print('MQ18_REPORT_PACKING: PASS; redundant ray point clouds discarded with hashes',flush=True)
    return report
