"""Run isolated verifier regressions with each feedback-5 guard removed."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

from .curate_delivery import write

MUTATIONS = {
    'failed_reports_accepted': ("""
from spec.art_identity.maquettes.blender import quality_delivery,curate_delivery
quality_delivery.validate_delivery=lambda *a,**k:None
curate_delivery.validate_delivery=lambda *a,**k:None
""", 'DeliveryValidationTests.test_copied_thrall_mutation_exits_nonzero_in_both_delivery_tools'),
    'part_maps_ignored': ("""
from spec.art_identity.maquettes.blender import test_delivery_validation as t
original=t.compare_captures
def broken(*a,**k):
    result=original(*a,**k)
    for view in result.values():view['parts']['passed']=True
    return result
t.compare_captures=broken
""", 'RegenerationRasterTests.test_correct_clays_cannot_mask_missing_or_red_maps'),
    'native_pngs_reencoded': ("""
from spec.art_identity.maquettes.blender import curate_delivery as c
original=c.shutil.copyfile
def broken(source,destination,*a,**k):
    if str(source).endswith('.png'):return c.canonical_png(source,destination,mask='clay' not in str(source))
    return original(source,destination,*a,**k)
c.shutil.copyfile=broken
""", 'DeliveryValidationTests.test_staging_preserves_native_png_bytes_including_stamps'),
    'disabled_modifiers_accepted': ("""
from spec.art_identity.maquettes.blender import sculpted_mass as m
original=m.native_stack_matches
def broken(piece,source):
    states=[(mod,mod.show_viewport,mod.show_render) for mod in source.modifiers]
    for mod,_,_ in states:mod.show_viewport=mod.show_render=True
    try:return original(piece,source)
    finally:
        for mod,viewport,render in states:mod.show_viewport,mod.show_render=viewport,render
m.native_stack_matches=broken
""", 'modifier_feedback2'),
    'frozen_base_mesh_accepted': ("from spec.art_identity.maquettes.blender import sculpted_mass as m;m.frozen_differs_from_base=lambda *a:True", 'frozen_feedback2'),
    'foot_height_ignored': ("""
from pathlib import Path
from spec.art_identity.maquettes.blender import foot_projection as m
source=Path(m.__file__).read_text();before="'passed':distance<=FOOT_LIMITS['ground_tolerance_m']"
assert source.count(before)==1
namespace=dict(m.__dict__);exec(compile(source.replace(before,"'passed':True"),m.__file__,'exec'),namespace)
m.report=namespace['report']
""", 'foot_feedback2'),
    'foot_projection_ignored': ("""
from pathlib import Path
from spec.art_identity.maquettes.blender import foot_projection as m
source=Path(m.__file__).read_text();before="entry['passed'] &= passed"
assert source.count(before)==1
namespace=dict(m.__dict__);exec(compile(source.replace(before,'pass'),m.__file__,'exec'),namespace)
m.report=namespace['report']
""", 'foot_feedback2'),
    'fit_not_recomputed': ("from spec.art_identity.maquettes.blender import solid_fit;solid_fit.validate_fit=lambda *a,**k:None", 'fit_feedback2'),
    'native_contacts': ("from spec.art_identity.maquettes.blender import delivery_validation as v; original=v.geometry_checks;v.geometry_checks=lambda s:tuple(k for k in original(s) if k!='native_contacts')", 'feedback2'),
    'native_sculpted_sections': ("from spec.art_identity.maquettes.blender import delivery_validation as v; original=v.geometry_checks;v.geometry_checks=lambda s:tuple(k for k in original(s) if k!='native_sculpted_sections')", 'feedback2'),
    'required_parts_not_rejected': ("""
from spec.art_identity.maquettes.blender import ownership
ownership.require_solos=lambda *a,**k:None
""", 'existing_helper'),
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = {}
    for name, (mutation, test) in MUTATIONS.items():
        module = 'spec.art_identity.maquettes.blender.test_delivery_validation'
        if test=='foot_feedback2':
            module='spec.art_identity.maquettes.blender.test_feedback2'
            test='FeedbackTwoTests.test_each_foot_rejects_unpainted_projection_and_wrong_height'
        if test in ('modifier_feedback2','frozen_feedback2'):
            module='spec.art_identity.maquettes.blender.test_feedback2'
            test='FeedbackTwoTests.'+('test_every_required_modifier_must_evaluate_in_both_modes' if test=='modifier_feedback2' else 'test_frozen_surface_must_differ_from_base_mesh')
        if test == 'fit_feedback2':
            module='spec.art_identity.maquettes.blender.test_feedback2'
            test='FeedbackTwoTests.test_failed_zero_stale_and_forged_fit_rejected_for_every_figure'
        if test == 'feedback2':
            module='spec.art_identity.maquettes.blender.test_feedback2'
            test='FeedbackTwoTests.test_native_contacts_and_sculpted_sections_cannot_be_omitted'
        if test == 'existing_helper':
            module = 'spec.art_identity.maquettes.blender.test_delivery'
            test = 'DeliveryTests.test_required_parts_reject_missing_zero_and_negative_solos'
        if name == 'failed_reports_accepted':
            # The entry-point test launches fresh interpreters. Inject the
            # mutation in each child rather than only patching this process.
            mutation = """
import subprocess
original=subprocess.run
def broken(command,**kwargs):
    if 'unittest' not in command:
        prefix="from spec.art_identity.maquettes.blender import delivery_validation as v;v.validate_delivery=lambda *a,**k:None;"
        if '-m' in command:
            i=command.index('-m');module=command[i+1];argv=command[i+2:]
            code=prefix+"import sys,runpy;sys.argv="+repr([module]+argv)+";runpy.run_module("+repr(module)+",run_name='__main__')"
        else:
            script=command[2];argv=command[3:]
            code=prefix+"import sys,runpy;sys.argv="+repr([script]+argv)+";runpy.run_path("+repr(script)+",run_name='__main__')"
        command=[command[0],'-B','-c',code]
    return original(command,**kwargs)
subprocess.run=broken
"""
        code = mutation + '\nimport unittest\nsuite=unittest.defaultTestLoader.loadTestsFromName(' + repr(module + '.' + test) + ')\n'
        code += 'result=unittest.TextTestRunner(verbosity=2).run(suite)\nraise SystemExit(0 if result.wasSuccessful() else 1)\n'
        result = subprocess.run([sys.executable, '-B', '-c', code], text=True, capture_output=True)
        (args.out / (name + '.log')).write_text(result.stdout + result.stderr)
        # An import/runner error is not evidence that the mutation was caught.
        caught = result.returncode == 1 and 'FAIL:' in result.stderr and 'Ran 1 test' in result.stderr
        results[name] = {'caught': caught, 'test_exit': result.returncode,
                         'regression': module + '.' + test}
    passed = all(r['caught'] for r in results.values())
    write(args.out / 'mutation_results.json', {'passed': passed, 'mutations': results})
    print('DELIVERY_MUTATIONS: ' + ('PASS' if passed else 'FAIL') + '; caught=' +
          str(sum(r['caught'] for r in results.values())) + '; survived=' + str(sum(not r['caught'] for r in results.values())))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
