"""Calibrated rr-38 CPU superset diagnostics plus exact painting provenance."""
import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import numpy as np
from PIL import Image
from rr42_underlay import CASE, PROJECT, inputs, domains, certificates, extra_authority
from cutout_pipeline.cases import read_json,write_json,digest
from rr38_cpu_diagnostics import Diagnostics
from rr38_uncovered import UncoveredSurface
from rr42_exposure import PaintedExposure
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from maquette_motion.features import source_pixels
from humanoid_cutout.native_defects import packed
from humanoid_cutout.gates import bindings
from rr42_raster import pose_for_raster

SHARD_FRAMES=4
SHARD_WORKERS=2
SHARD_TIMEOUT_SECONDS=180
CROP_CONTEXT_PX=12
CROP_ZOOM=4
DIAGNOSTIC_FILES=('rr38_cpu_diagnostics.py','rr38_uncovered.py','rr42_sweep.py',
                  'rr42_exposure.py','rr42_underlay.py','rr42_references.py',
                  'rr42_fragments.py','rr42_gates.py','rr42_runtime_gates.py',
                  'rr42_native_checks.py','rr42_native_cache.py','rr42_raster.py','rr42_sampling.py','rr42_tucks.py','rr42_retained.py',
                  'rr42_feedback1_repairs.json',
                  'rr42_feedback1_fragments.json','rr42_feedback1_clamps.json')


def diagnostic_bindings():
    result={name:digest(CASE.parent/name) for name in DIAGNOSTIC_FILES}
    result['native_origin_sampler']=digest(PROJECT/'tests/rr42/native_samples.gd')
    result['retained_native_fixture']=digest(CASE/'proof/feedback2_native/manifest.json')
    for name in ('pixels.py','raster.py'):
        result['rigid_raster:'+name]=digest(PROJECT/'tools/maquette_motion'/name)
    return result


class Surfaces(UncoveredSurface):
    def __init__(self,case,model):
        super().__init__(case,model)
        if model.layout['facing']=='front':
            paint,masks=inputs(); authority=np.logical_or.reduce(list(masks.values()))
            # Director-owned alpha=0 is explicitly justified clear. Opaque
            # painting remains independently required, not inferred from fill.
            required=domains()
            for name in self.domains:
                self.domains[name][authority|extra_authority(name)]=False
                if name in required: self.domains[name] |= required[name]
                supplied=certificates().get('hidden_'+name)
                if supplied is not None:self.domains[name] |= supplied
            for part in model.layout['parts']:
                image=source_pixels(case,part); approved=(image[...,3]>0)&np.all(image==paint,axis=-1)
                name=part['name']; logical=part['logical_part']
                self.part_palettes[name]=np.union1d(self.part_palettes[name],np.unique(packed(image)[approved]))
                self.palettes[logical]=np.union1d(self.palettes[logical],np.unique(packed(image)[approved]))
                self.bad_source[name] &= ~approved
                self.painted[name] = approved


def frames(case,view,clip,start,count,exposure,inventory=False):
    rows=[r for r in read_json(case/'proof/logs/samples.json')['samples'] if r['kind']=='presented' and r['view']==view and r['clip']==clip and start<=r['frame']<start+count]
    model=CpuPose(case,read_json(case/f'layouts/{view}.json'),native_skin=True,triangle_batch_size=128)
    diagnostic=Diagnostics(case,model); diagnostic.surface=Surfaces(case,model)
    painted=PaintedExposure(model) if view=='front' and exposure else None
    results=[]
    with for_case(case):
        for row in rows:
            row=pose_for_raster(row)
            layers,maps=model.layers(row); result=diagnostic.measure(row,layers,maps)
            if painted:
                provenance=painted.measure(row,collect_texels=inventory)
                result['metrics'].update(provenance)
                if any(provenance.values()): result['kinds'].append('procedural')
            for metric in ('uncovered_foreign_texels','uncovered_outline_pixels','uncovered_outside_surface_pixels'):
                if result['metrics'].get(metric): result['kinds'].append(metric)
            if inventory and painted:
                from humanoid_cutout.gait_continuations import texture
                parts={p['name']:p for p in model.layout['parts']}
                image,_=inputs(); result['repair_texels']=[]
                for name,x,y in sorted(painted.last_texels):
                    part=parts[name];ox,oy=part['offset']
                    source=texture(case,model.layout,part,gait=clip=='move',clip=clip)
                    result['repair_texels'].append({'part':name,'uv':[x,y],'before_rgba':source[y-oy,x-ox].tolist(),
                        'director_rgba':image[y,x].tolist(),'decision':'paint' if image[y,x,3] else 'clear'})
            result['kinds']=sorted(set(result['kinds']))
            result.update(view=view,clip=clip,frame=row['frame'])
            if result['kinds']:
                output=case/'proof/logs/rr42_crops';output.mkdir(parents=True,exist_ok=True)
                actual=np.zeros_like(layers[0][1])
                for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):actual[image[...,3]>0]=image[image[...,3]>0]
                ys,xs=np.nonzero(actual[...,3]); context=CROP_CONTEXT_PX
                crop=Image.fromarray(actual).crop((int(xs.min())-context,int(ys.min())-context,int(xs.max())+context+1,int(ys.max())+context+1))
                path=output/f'{view}_{clip}_{row["frame"]:03d}_4x.png'
                crop.resize((crop.width*CROP_ZOOM,crop.height*CROP_ZOOM),Image.Resampling.NEAREST).save(path)
                result['crop']=str(path.relative_to(case))
            results.append(result)
    output=case/f'proof/logs/rr42_shards/{view}_{clip}_{start:03d}.json'
    write_json(output,{'frames':results,'ok':not any(r['kinds'] for r in results)})


def sweep(case,clips,exposure,inventory=False):
    before=bindings(case)
    diagnostic_before=diagnostic_bindings()
    data=read_json(case/'compiled_motion.json')
    jobs=[(v,c,start,min(SHARD_FRAMES,round(d['seconds']*60)-start)) for v in data['view_tracks'] for c,d in data['clips'].items()
          if not clips or c in clips.split(',') for start in range(0,round(d['seconds']*60),SHARD_FRAMES)]
    def run(job):
        view,clip,start,count=job
        command=[sys.executable,'-B',__file__,'--case',str(case),'--view',view,'--clip',clip,'--start',str(start),'--count',str(count)]
        if exposure: command.append('--exposure')
        if inventory: command.append('--inventory')
        result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=SHARD_TIMEOUT_SECONDS)
        if result.returncode: raise RuntimeError(result.stdout+result.stderr)
        return read_json(case/f'proof/logs/rr42_shards/{view}_{clip}_{start:03d}.json')['frames']
    with ThreadPoolExecutor(max_workers=SHARD_WORKERS) as pool:
        results=[]
        for index,group in enumerate(pool.map(run,jobs)):
            results+=group
            if index%20==0:print(f'RR42 SWEEP SHARDS: {index+1}/{len(jobs)}',flush=True)
    if bindings(case)!=before: raise RuntimeError('Source inputs changed during sweep; rerun required')
    if diagnostic_bindings()!=diagnostic_before: raise RuntimeError('Diagnostic inputs changed during sweep; rerun required')
    errors=[{k:r[k] for k in ('view','clip','frame','kinds','crop')} for r in results if r['kinds']]
    result={'ok':not errors,'native_pixels':False,'calibration':'rr-38 263/263 native signatures; identical diagnostic with director clear/paint policy',
            'samples_sha256':digest(case/'proof/logs/samples.json'),'inputs':before,'diagnostic_inputs':diagnostic_before,
            'all_rounding':exposure,'frames':results,'errors':errors}
    write_json(case/'proof/logs/rr42_sweep.json',result)
    if inventory:
        from rr42_repairs import merge_rows
        merge_rows(results)
    print(f'RR42 CALIBRATED SWEEP: {"PASS" if not errors else "FAIL"} ({len(results)} frames; {len(errors)} findings; painted_exposure={exposure}; native_pixels=False)')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--case',type=Path,default=CASE/'proof/production_case')
    parser.add_argument('--clips');parser.add_argument('--exposure',action='store_true');parser.add_argument('--view');parser.add_argument('--clip')
    parser.add_argument('--inventory',action='store_true')
    parser.add_argument('--start',type=int,default=0);parser.add_argument('--count',type=int,default=4)
    args=parser.parse_args()
    if args.view: frames(args.case,args.view,args.clip,args.start,args.count,args.exposure,args.inventory)
    else: raise SystemExit(not sweep(args.case,args.clips,args.exposure,args.inventory)['ok'])
