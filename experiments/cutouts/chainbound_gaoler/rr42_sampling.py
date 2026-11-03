"""Canonical bone contracts plus native-origin raster transforms; no motion edit."""
import argparse
from pathlib import Path
import subprocess
import sys
from rr42_underlay import CASE, PROJECT
from rr38_evidence import refresh_samples,compact_samples
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings


def refresh(case):
    refresh_samples(case)
    path=case/'proof/logs/native_origin_samples.json'
    subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-42','--stream','--',
                    'godot','--headless','--path','.','--script','tests/rr42/native_samples.gd','--',
                    '--case',str(case),'--output',str(path)],cwd=PROJECT,check=True)
    native=read_json(path);samples=read_json(case/'proof/logs/samples.json')
    if not native['ok'] or native['inputs']!=bindings(case):raise ValueError('Stale native-origin poses')
    if native['compiled_sha256']!=digest(case/'compiled_motion.json'):raise ValueError('Different motion at native origin')
    expected=read_json(case/'cutout.json')['proof_geometry']['source_offset']
    if native['origin']!=[expected,expected]:raise ValueError('Native-origin registration differs')
    rows={(r['view'],r['clip'],r['frame']):r for r in native['samples']}
    presented=[r for r in samples['samples'] if r['kind']=='presented']
    if set(rows)!={(r['view'],r['clip'],r['frame']) for r in presented}:raise ValueError('Incomplete native-origin poses')
    for row in presented:
        raster=rows[row['view'],row['clip'],row['frame']]
        row.update(raster_bones=raster['bones'],raster_parts=raster['parts'])
    samples.update(raster_origin=native['origin'],raster_samples_sha256=digest(path))
    write_json(case/'proof/logs/samples.json',samples);compact_samples(case)
    print('RR42 RASTER REGISTRATION: PASS (%d native-origin poses; canonical contracts retained)'%len(rows))


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE/'proof/production_case')
    refresh(p.parse_args().case)
