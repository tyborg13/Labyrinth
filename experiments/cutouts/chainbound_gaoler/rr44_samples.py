"""Fresh, bounded rr-44 samples, including the real native capture origin."""
import argparse
import os
from pathlib import Path
import subprocess
import sys
from rr44_case import PROJECT, CASE, DEFAULTS
from cutout_pipeline.cases import read_json, write_json, digest


def refresh(case):
    output=case/'proof/logs/samples.json';native=case/'proof/logs/native_origin_samples.json'
    for script,target in [('tests/rr44/samples.gd',output),('tests/rr42/native_samples.gd',native)]:
        subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',os.environ.get('LABYRINTH_TASK_ID','rr-49'),'--timeout','85','--stream','--',
                        'godot','--headless','--path','.','--script',script,'--','--case',str(case),'--output',str(target)],cwd=PROJECT,check=True,timeout=87)
    data=read_json(output);origin=read_json(native)
    if data['inputs']!=origin['inputs'] or data['compiled_sha256']!=origin['compiled_sha256']:raise ValueError('Native-origin sample binding differs')
    by_key={(r['view'],r['clip'],r['frame']):r for r in origin['samples']}
    for row in data['samples']:
        if row['kind']!='presented':continue
        other=by_key[row['view'],row['clip'],row['frame']]
        row.update(raster_bones=other['bones'],raster_parts=other['parts'],raster_cap_bones=other.get('cap_bones',{}))
        if 'stable_geometry' in other:row['raster_stable_geometry']=other['stable_geometry']
    data.update(raster_origin=origin['origin'],raster_samples_sha256=digest(native));write_json(output,data)
    from rr38_evidence import compact_samples
    compact_samples(case)
    print(f'RR44 SAMPLE ORIGINS: PASS ({len(by_key)} presented frames; canonical + native-origin; no renderer claim)')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE/'proof/production_case');refresh(p.parse_args().case)
