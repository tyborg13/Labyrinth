"""Independent authored-key and applied Bone2D motion gates (both views)."""
from __future__ import annotations
import argparse
import json
import math
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import digest, read_json, write_json
from maquette_motion.contract import expected as director_contract, phases as sample_phases, evaluate, approved_source
from cutout_pipeline.cases import CutoutError
from humanoid_cutout.native_frames import load_frame, frame_digest, frame_exists

PROJECT = Path(__file__).resolve().parents[2]
SOURCE = PROJECT / 'spec/peer_benchmark/staged/rr-04/motion_tracks.json'
TOLERANCE = 0.00003
POSE_SIZE = (512, 512)

def matrix(rotation, scale, position):
    c,s = math.cos(rotation), math.sin(rotation)
    return np.array([[c*scale[0],-s*scale[1],position[0]], [s*scale[0],c*scale[1],position[1]], [0,0,1]])

def unpack(v): return np.array([[v[0],v[2],v[4]], [v[1],v[3],v[5]], [0,0,1]])

def expected_bones(compiled, layout, view, clip, at, step, pixel_scale=1):
    values = {}
    for track in compiled['view_tracks'][view][clip]:
        value = evaluate(track['keys'], at)
        if track['channel']=='forward_px' and track['forward_mode']=='fraction_of_step': value*=step
        values.setdefault(track['bone'],{})[track['channel']]=value
    result = {}
    def bone(name):
        if name in result:return result[name]
        joint=layout['joints'][name];parent=joint['parent'];channels=values.get(name,{})
        origin=np.asarray(joint['position'],dtype=float) - (np.asarray(layout['joints'][parent]['position']) if parent else 0)
        origin+=(np.asarray(compiled['projection'][view]['forward'])*channels.get('forward_px',0)+[0,-channels.get('lift_px',0)])/pixel_scale
        squash=channels.get('squash',1);scale=channels.get('scale',1)
        local=matrix(math.radians(channels.get('raise_deg',0)+channels.get('lean_deg',0)),[scale/squash,scale*squash],origin)
        alpha=channels.get('alpha',1)
        inherited=alpha*(bone(parent)['inherited_alpha'] if parent else 1)
        result[name]={'local':local,'global':bone(parent)['global']@local if parent else local,'alpha':alpha,'inherited_alpha':inherited}
        return result[name]
    for name in layout['joints']:bone(name)
    return result

def errors(case, sample_path):
    actual=read_json(case/'compiled_motion.json')
    creature=actual['creature']
    failures=[]
    try:
        source = approved_source(case)
    except CutoutError as error:
        failures.append(str(error))
        source = SOURCE
    expected=director_contract(source,creature,read_json(PROJECT/'spec/art_identity/maquettes'/creature/'spec.json'))
    if actual!=expected:failures.append('Compiled authored keys/signs differ from protected source')
    sampled=read_json(sample_path)
    if not sampled['ok']:failures.append('Sampler failed')
    if sampled['compiled_sha256']!=digest(case/'compiled_motion.json'):failures.append('Stale motion samples')
    rows=sampled['samples']
    for view in ('front','rear'):
        layout=read_json(case/f'layouts/{view}.json')
        for clip in expected['clips']:
            selected=[r for r in rows if r['view']==view and r['clip']==clip]
            for at in sample_phases(expected,clip):
                matches=[r for r in selected if abs(r['phase']-at)<1e-8]
                if len(matches)!=1:
                    failures.append(f'{view}/{clip}: missing/duplicate authored key or midpoint {at}')
                    continue
                row=matches[0]
                bones=expected_bones(expected,layout,view,clip,at,sampled['step_distance_px'])
                for name,wanted in bones.items():
                    observed=row['bones'].get(name,{})
                    for field in ['local','global','alpha','inherited_alpha']:
                        value=unpack(observed[field]) if field in ('local','global') and field in observed else observed.get(field)
                        if value is None or not np.allclose(value,wanted[field],atol=TOLERANCE,rtol=0):
                            failures.append(f'{view}/{clip}/{name}: applied bone {field} differs at {at}')
    return failures

def production_errors(manifest, compiled):
    failures=[]
    integration=read_json(PROJECT/"assets/units"/(compiled["creature"]+"_cutout")/"integration.json")
    expected_inputs=input_bindings(PROJECT/integration["case"])
    expected_inputs.update(production_bindings(PROJECT/"assets/units"/(compiled["creature"]+"_cutout")))
    if manifest.get("inputs") != expected_inputs:failures.append("Production input bindings differ from final case/runtime")
    for clip in compiled['clips']:
        rows=[r for r in manifest['frames'] if r['stage']==clip and r['snapshot']['clip']==clip]
        if len(rows)<6:failures.append(clip+': fewer than six action frames')
        if len({r.get('pose_sha256') for r in rows})<6:failures.append(clip+': fewer than six changing bone poses')
        if manifest.get('native_pixels') and len({r.get('pixels_sha256') for r in rows})<6:failures.append(clip+': fewer than six changing native frames')
        contact=compiled['clips'][clip].get('contact')
        if contact is not None and not any(abs(r['snapshot']['phase']-contact)<1e-6 for r in rows):failures.append(clip+': missing real contact frame')
        phases=[r['snapshot']['phase'] for r in rows]
        if clip not in ('idle','move') and any(a>b+1e-6 for a,b in zip(phases,phases[1:])):failures.append(clip+': clip restarted during one action')
        if not phases or max(phases)-min(phases)<0.5:failures.append(clip+': phase did not progress')
    if manifest.get('completions',{}).get('hit',{}).get('clip')!='idle':failures.append('hit: missing return to idle')
    return failures

RUNTIME_PATHS = ['tests/maquette_cutout/capture_storage.gd', 'tools/humanoid_cutout/native_frames.py', 'scripts/maquette_cutout_runtime/motion.gd', 'scripts/maquette_cutout_runtime/rig.gd',
    'scripts/maquette_cutout_runtime/pixel_presentation.gd', 'tools/maquette_motion/features.py', 'tools/maquette_motion/pixels.py', 'tools/maquette_motion/raster.py',
    'tools/maquette_motion/material_palette.py', 'tools/maquette_motion/hidden_material.py', 'tools/maquette_motion/material_provenance.py', 'tools/maquette_motion/support_seeds.py', 'tools/maquette_motion/hidden_support.py', 'tools/maquette_motion/socket_edit.py',
    'tools/maquette_motion/joint_seams.py', 'tools/maquette_motion/seam_pose.py', 'tools/maquette_motion/seam_builder.py', 'tools/maquette_motion/silhouette.py', 'tools/maquette_motion/continuity.py', 'tools/maquette_motion/bleed.py', 'tools/maquette_motion/seam_support.py', 'tools/maquette_motion/contract.py', 'tools/maquette_motion/continuity_limits.py', 'tools/maquette_motion/feature_builder.py',
    'tests/maquette_cutout/seam_capture.gd', 'tests/maquette_cutout/reference_masks.gd', 'tests/maquette_cutout/pixel_capture.gd', 'tests/maquette_cutout/pixel_samples.gd', 'tests/maquette_cutout/proof_inputs.gd', 'tools/maquette_cutout_polish.py',
    'scripts/maquette_cutout_runtime/renderer.gd', 'scripts/maquette_cutout_runtime/action.gd',
    'scripts/maquette_cutout_runtime/presentation.gd', 'scripts/maquette_cutout_runtime/portrait.gd',
    'tests/maquette_cutout/native_capture.gd', 'tools/maquette_motion/compiler.py', 'scripts/run_scene.gd', 'scripts/combat_board_view.gd', 'scripts/cutout_context.gd', 'scripts/actor_presentation.gd', 'data/enemies.json']

def production_bindings(base):
    paths={'compiled_motion.json','front.json','rear.json','front/rest.png','rear/rest.png'}
    for view in ('front','rear'):paths.update(p['file'] for p in read_json(base/(view+'.json'))['parts'])
    return {'production:'+p:digest(base/p) for p in paths}

def input_bindings(case):
    paths = {'cutout.json','compiled_motion.json','director_motion.json','source/spec.json','motion.gd','layouts/front.json','layouts/rear.json'}
    if (case / 'seams.json').exists(): paths.add('seams.json')
    if (case / 'seam_parent_decisions.json').exists(): paths.add('seam_parent_decisions.json')
    if (case / 'director_amendments.json').exists(): paths.add('director_amendments.json')
    for relative in ('support_derivation.json', 'hidden_fills/index.json'):
        if (case / relative).exists(): paths.add(relative)
    for view in ('front','rear'):
        if (case / f'source/{view}/processed.json').exists(): paths.add(f'source/{view}/processed.json')
        paths.add('source/'+view+'/processed.png')
        paths.update(p['file'] for p in read_json(case/f'layouts/{view}.json')['parts'])
    if (case/'features.json').exists():
        paths.add('features.json')
        for feature in read_json(case/'features.json')['features']:
            paths.update(d['mask'] for d in feature['views'].values() if not d['mask'].startswith('TODO_DESIGN_'))
    result={p:digest(case/p) for p in paths}
    result.update({'runtime:'+p:digest(PROJECT/p) for p in RUNTIME_PATHS})
    for path in read_json(case / 'cutout.json').get('runtime_paths', []):
        result['runtime:' + path] = digest(PROJECT / path)
    return result


# These files only interpret saved pixels/matrices; Godot does not execute
# them. Re-checking a retained native capture with a revised oracle must not
# pretend that its recorded oracle hashes are today's hashes. All case paint,
# layouts, authored motion, derivation code and native runtime bindings remain
# exact. Preserve the original manifests and expose both oracle revisions.
VERIFICATION_ONLY_PATHS = ('tools/maquette_motion/pixels.py',
                           'tools/maquette_motion/raster.py', 'tools/maquette_cutout_polish.py')


def bindings_match(case, recorded):
    current = input_bindings(case)
    ignored = {'runtime:' + p for p in VERIFICATION_ONLY_PATHS}
    return isinstance(recorded, dict) and recorded.keys() == current.keys() and all(
        recorded[key] == value for key, value in current.items() if key not in ignored)


def verification_bindings():
    paths = (*VERIFICATION_ONLY_PATHS, 'tools/maquette_motion/native_ties.py', 'tools/maquette_motion/gates.py',
             'tools/maquette_motion/certificates.py')
    return {p: digest(PROJECT / p) for p in paths}

def native_errors(case, capture):
    failures=[]
    manifest=read_json(capture/'frames.json')
    compiled=read_json(case/'compiled_motion.json')
    if not bindings_match(case, manifest.get('inputs')):failures.append('Native input bindings differ from final case/runtime')
    if not manifest.get('ok') or not manifest.get('native_pixels') or manifest.get('fps') != 60:failures.append('Native renderer proof incomplete')
    if manifest.get('compiled_sha256')!=digest(case/'compiled_motion.json'): failures.append('Stale native motion capture')
    expected_frames=0
    for view in ('front','rear'):
        approved=load_frame(case/f'source/{view}/processed.png').convert('RGBA')
        actual=load_frame(capture/f'{view}_rest.png').convert('RGBA')
        if approved.size!=actual.size or approved.tobytes()!=actual.tobytes():failures.append(view+': native rest differs')
        for clip,definition in compiled['clips'].items():
            count=round(definition['seconds']*60)
            rows=[r for r in manifest['frames'] if r['view']==view and r['clip']==clip]
            expected_frames+=count
            if len(rows)!=count or {r['frame'] for r in rows}!=set(range(count)):failures.append(view+'/'+clip+': missing native 60fps frames')
            for row in rows:
                at=row['frame']/(count if definition.get('loop') else count-1)
                if abs(row['phase']-at)>1e-8:failures.append(view+'/'+clip+': native phase differs from authored 60fps clock')
            hashes=[]
            for row in rows:
                path=capture/row['file']
                if not frame_exists(path) or frame_digest(path)!=row['sha256']:failures.append('Changed native frame: '+str(path));continue
                image=np.asarray(load_frame(path).convert('RGBA'))
                if image.shape[:2] != POSE_SIZE:
                    failures.append('Wrong native pose dimensions: '+str(path));continue
                opaque=image[...,3]>0
                if np.any(opaque & (image[...,0]==255)&(image[...,1]==0)&(image[...,2]==255)):failures.append('Magenta hidden material: '+str(path))
                if opaque[0].any() or opaque[-1].any() or opaque[:,0].any() or opaque[:,-1].any():failures.append('Clipped native pose: '+str(path))
                hashes.append(row['sha256'])
            if len(set(hashes))<6:failures.append(view+'/'+clip+': frozen native motion')
    if len(manifest['frames'])!=expected_frames:failures.append('Unexpected/duplicate native frames')
    pairs=manifest.get('pairs',[])
    if len(pairs)*2!=expected_frames:failures.append('Missing native pair frames')
    for pair in pairs:
        path=capture/pair['file']
        if not frame_exists(path) or frame_digest(path)!=pair['sha256']:failures.append('Changed native pair: '+str(path))
    return failures

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,required=True);p.add_argument('--samples',type=Path);p.add_argument('--native',type=Path);p.add_argument('--production',type=Path);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    failures=errors(a.case,a.samples) if a.samples else native_errors(a.case,a.native) if a.native else production_errors(read_json(a.production),read_json(a.case/'compiled_motion.json'))
    report={'ok':not failures,'errors':failures}
    write_json(a.output,report)
    print('MAQUETTE MOTION GATES: '+('PASS' if not failures else 'FAIL')+' ('+str(len(failures))+' errors)')
    for failure in failures[:20]:print(failure)
    return int(bool(failures))
if __name__=='__main__':raise SystemExit(main())
