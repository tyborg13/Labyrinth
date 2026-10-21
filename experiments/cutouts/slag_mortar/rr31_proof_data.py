"""Read-only preservation checks and selected full-canvas CPU proof exports."""
import hashlib
from pathlib import Path
import subprocess
import numpy as np
from PIL import Image
from rr30_case import CASE, PROJECT, ASSETS, DIRECTOR
from rr31_images import OUTPUT, ImageGate, composite
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import bindings
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.pixels import rest_identity

SELECTED_FRAMES = {'lob':32,'brace':20,'death':78}  # CPU proof selection only.


def baseline_digest(path):
    relative = str(path.relative_to(PROJECT))
    original = subprocess.run(['git','show','HEAD:'+relative],cwd=PROJECT,check=True,
                              capture_output=True).stdout
    return hashlib.sha256(original).hexdigest()


def record():
    samples = read_report(CASE)
    if samples['inputs']!=bindings(CASE): raise ValueError('Refresh samples before preservation proof')
    immutable = [CASE/f'source/{view}/{name}.png' for view in ('front','rear')
                 for name in ('approved','processed')]
    immutable += [ASSETS/f'humanoid_v2/{view}/rest.png' for view in ('front','rear')]
    immutable += [PROJECT/'spec/art_identity/registry.json',DIRECTOR]
    for view in ('front','rear'):
        layout = read_json(CASE/f'layouts/{view}.json')
        immutable += [CASE/p['file'] for p in layout['parts'] if not p['hidden_material']]
        immutable += [ASSETS/'humanoid_v2'/view/Path(p['file']).name
                      for p in layout['parts'] if not p['hidden_material']]
    preserved = {str(p.relative_to(PROJECT)):dict(sha256=digest(p),unchanged=digest(p)==baseline_digest(p))
                 for p in immutable}
    frames = []
    for view in ('front','rear'):
        gate = ImageGate(CASE,read_json(CASE/f'layouts/{view}.json'))
        for clip,frame in SELECTED_FRAMES.items():
            pose = next(p for p in samples['samples'] if p['view']==view and p['clip']==clip
                        and p['kind']=='presented' and p['frame']==frame)
            image,_ = composite(sorted(gate.layers(pose),key=lambda r:r[0]['z_index']))
            target = OUTPUT/f'proof/cpu_frames/{view}_{clip}_{frame:04d}.png'
            target.parent.mkdir(parents=True,exist_ok=True)
            Image.fromarray(image).save(target)
            frames.append(dict(view=view,clip=clip,frame=frame,file=str(target.relative_to(OUTPUT))))
    result = dict(ok=all(p['unchanged'] for p in preserved.values()) and rest_identity(CASE)['ok'],
        protected=preserved,rests=rest_identity(CASE),
        director_imports_byte_identical=all(p.read_bytes()==DIRECTOR.read_bytes() for p in (
            CASE/'director_motion.json',ASSETS/'humanoid_v2/director_motion.json')),
        native_pixels=False,cpu_frames=frames)
    write_json(OUTPUT/'proof/preservation.json',result)
    write_json(OUTPUT/'proof/chosen_defaults.json',dict(
        cpu_proof_frames=SELECTED_FRAMES,joint_sweep_grid_step_px_or_deg=.25,
        joint_sweep_fine_extent_px_or_deg=16,coarse_search=[24,32,48,64,90,128],
        cpu_log_progress_frames=100,test_fixture_size_px=48,test_zone_centroid=[24,12],
        sampler_test_step_px=96,sampler_test_screen_scale=2,sampler_test_offset=6,
        isolated_clip_seconds=1.0,contour_mutation_translation_px=4,
        focused_subprocess_timeout_seconds=180,full_godot_timeout_seconds=1200,
        notes='All values here are proof/test choices. Gate radii, limits and authored motion come from the brief.'))
    print(f'RR31 PRESERVATION: {"PASS" if result["ok"] and result["director_imports_byte_identical"] else "FAIL"} '
          f'({len(preserved)} immutable files; rests {result["rests"]["views"]}; 6 full-canvas CPU exports)')
    return result


if __name__ == '__main__': raise SystemExit(not record()['ok'])
