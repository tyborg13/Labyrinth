"""rr-37/38 runtime contracts plus rr-44 source, elbow and motion gates."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr44_case import CASE, STAGED, protected
from rr44_movement import report as arm_report, held_report
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.elbows import report as elbow_report
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings, native_errors
from humanoid_cutout.walk_gates import support_report
from humanoid_cutout.reach import report as reach_report
from rr38_acceptance import ownership_errors, chain_errors, draw_order_errors, hook_contact_errors
from rr44_release import RigidSourcePolicy


class NativeRigidSourcePolicy(RigidSourcePolicy):
    def report(self,occupied,layers,clip,phase,*,pose=None):
        from rr42_raster import pose_for_raster
        return super().report(occupied,layers,clip,phase,pose=pose_for_raster(pose) if pose is not None else None)


def evaluate(case, samples_path, native=None):
    protected();data=read_json(case/'compiled_motion.json');samples=read_json(samples_path);current=bindings(case)
    director=read_json(CASE/'director_motion.json');build=read_json(CASE/'proof/build.json')
    errors=[];views={}
    for view in data['view_tracks']:
        layout=read_json(case/f'layouts/{view}.json');source=read_json(CASE/f'layouts/{view}.json')
        from rr44_contract import errors as contract_errors,sample_errors as cap_binding_errors
        rows=structure_errors(source,build)+source_errors(CASE,source,build)+ownership_errors(case,layout)
        from humanoid_cutout.gait_continuations import errors as continuation_errors
        rows+=continuation_errors(case,layout)
        rows+=contract_errors(layout)
        rows+=cap_binding_errors(layout,samples)
        rows+=bone_errors(layout,data,samples,current)+chain_errors(layout,data,samples)+draw_order_errors(layout,samples)
        rows+=support_report(layout,data,samples)['errors']
        rows+=reach_report(layout,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale'])['errors']
        elbow=elbow_report(layout,data,samples);arms=arm_report(layout,data,director,samples);held=held_report(layout,data,director,samples)
        rows+=elbow['errors']+arms['errors']+held['errors']
        views[view]=dict(errors=rows,elbow=elbow,pendulum=arms,held_follow=held);errors+=rows
    sweep_path=case/'proof/logs/rr44_sweep.json'
    if not sweep_path.exists():errors.append('All-frame painted exposure/native-defect sweep pending')
    else:
        sweep=read_json(sweep_path)
        from rr44_sweep import diagnostic_inputs
        from rr49_calibration import valid as final_native_valid
        if sweep.get('diagnostic_inputs')!=diagnostic_inputs():errors.append('Stale CPU sweep implementation')
        if not final_native_valid(sweep.get('final_native_calibration',{})):errors.append('Final rr44 native calibration is missing or incomplete')
        if sweep['inputs']!=current or sweep['samples_sha256']!=digest(samples_path):errors.append('Stale CPU sweep')
        errors += [f'{r["view"]}/{r["clip"]}/{r["frame"]}: {r["kinds"]}' for r in sweep['errors']]
    if native:
        manifest=read_json(native/'frames.json')
        if manifest.get('inputs')!=current or not manifest.get('native_pixels'):errors.append('Missing/stale native frames')
        else:
            errors+=native_errors(case,native,failure_output=case/'proof/logs/native_failures',release_policy_factory=NativeRigidSourcePolicy)
            # The native gate above already checks every component using the
            # exact source contract. Do not duplicate it with a legacy policy.
            errors+=hook_contact_errors(case,native,manifest)
            exact_path=case/'proof/logs/rr44_native_exact.json'
            if not exact_path.exists():errors.append('All-frame exact native painted-source proof pending')
            else:
                exact=read_json(exact_path)
                from rr44_native_exact import implementation as native_implementation
                if exact.get('inputs')!=current or exact.get('implementation')!=native_implementation() or exact.get('capture_sha256')!=digest(native/'frames.json'):errors.append('Stale native painted-source proof')
                errors += [f'{r["view"]}/{r["clip"]}/{r["frame"]}: native source RGBA {r["errors"]}' for r in exact['errors']]
    # rr-51: both gate modes read the director's 1.10 move acceptance through
    # the sweep and the native exact-source shards; a changed file fails here.
    from rr51_acceptance import binding as director_acceptance
    try:acceptance=director_acceptance()
    except ValueError as error:acceptance=None;errors.append(str(error))
    from rr44_calibration import certificate
    calibration=certificate();maquette=read_json(CASE/'maquette/fit_status.json')
    if not calibration['ok']:errors.append('Missing or stale round-0 CPU/native calibration')
    if not maquette.get('native_verified'):errors.append('Maquette native acceptance pending')
    result=dict(ok=not errors,errors=sorted(set(errors)),views=views,native_pixels=bool(native),production_ready=False,
                native_calibrated=calibration['ok'],native_calibration=calibration,maquette_native=maquette,director_acceptance=acceptance)
    write_json(case/('proof/logs/native_gates.json' if native else 'proof/logs/gates.json'),result)
    if native: write_json(case/'proof/native_gates.json',{k:v for k,v in result.items() if k!='views'})
    write_json(CASE/'proof/gates_summary.json',{k:v for k,v in result.items() if k!='views'})
    print(f'RR44 ALL GATES: {"PASS" if not errors else "FAIL"} ({len(result["errors"])} errors; native={bool(native)})')
    for error in result['errors'][:15]: print(error)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE/'proof/production_case');p.add_argument('--samples',type=Path);p.add_argument('--native',type=Path)
    a=p.parse_args();result=evaluate(a.case,a.samples or a.case/'proof/logs/samples.json',a.native)
    raise SystemExit(not result['ok'])
