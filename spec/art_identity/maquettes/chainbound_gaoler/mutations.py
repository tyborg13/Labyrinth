"""Remove individual guards in fresh interpreters; each regression must fail."""
import argparse
import json
from pathlib import Path
import subprocess
import sys


MUTATIONS = {
    'determinism': ("text", "raise ValueError('Cold/replay geometry differs')", 'pass',
                    'test_cold_replay_divergence_cannot_hide_behind_summary_pass'),
    'cache_replay': ("text", "raise ValueError('Exact native replay differs: ' + field)", 'pass',
                     'test_exact_cache_replay_cannot_differ'),
    'hash_binding': ("text", "raise ValueError('Missing or stale cold-proof report hash binding')", 'pass',
                     'test_hash_binding_rejects_changed_even_passing_report'),
    'custom_native_reports': ("text", "report_names += tuple(spec.get('delivery_reports', []))", 'pass',
                              'test_extra_native_report_is_required_before_sealing'),
    'native_facing_control': ("text", "('passed', 'torso_asymmetry_passed', 'frontal_axis_rejected')",
                              "('passed', 'torso_asymmetry_passed')", 'test_native_facing_requires_a_rejected_frontal_control'),
    'true_turn': ("acceptance_text", "not np.array_equal(front[:, ::-1], rear)", 'True',
                  'test_a_mirrored_rear_is_rejected_independently_of_its_hash'),
    'proportion_limits': ("acceptance_text", "'passed': abs(error) <= limit", "'passed': True",
                          'test_proportions_are_measured_against_the_declared_limit'),
    'ownership': ("patch", 'v.require_solos=lambda *a,**k:None', '',
                   'test_ownership_requires_each_nonempty_native_solo'),
    'native_weights': ("patch", "original=v.geometry_checks;v.geometry_checks=lambda s:tuple(k for k in original(s) if k!='body_weight_ownership')", '',
                        'test_native_weight_guard_cannot_be_omitted'),
    'shoulder_level': ("patch", "from spec.art_identity.maquettes.chainbound_gaoler import acceptance;a=acceptance.PROOF_DEFAULTS;a['level_tolerance_m']=1", '',
                       'test_measured_native_shoulder_level_is_required'),
    'native_height_parity': ("patch", "from spec.art_identity.maquettes.chainbound_gaoler import acceptance;acceptance.height_parity=lambda f,r:{'passed':True,'relative_error':0}", '',
                             'test_rear_native_height_has_a_real_three_percent_guard'),
    'proportion_recomputation': ("patch", "from spec.art_identity.maquettes.chainbound_gaoler import acceptance;acceptance.validate_acceptance=lambda *a,**k:{'passed':True}", '',
                               'test_forged_proportion_table_cannot_be_resealed_as_acceptance'),
}


for row in ('helm_width','chain_fist','near_fist','near_shin','near_boot',
            'upper_near_minimum','fore_near_minimum','upper_far_minimum','fore_far_minimum'):
    MUTATIONS['mass_'+row] = ('patch',
        "from spec.art_identity.maquettes.chainbound_gaoler import mass_gates as g;original=g.mass_row_passed;"
        + "g.mass_row_passed=lambda name,*args:True if name==" + repr(row) + " else original(name,*args)",
        '', 'MassGuardTests.test_each_mass_row_has_its_own_enforced_limit')
for guard,test in {
    'no_see_through':'test_no_see_through_rejects_both_background_and_pants',
    'holes':'test_holes_wider_than_one_pixel_fail',
    'open_front':'test_open_front_and_rear_cannot_be_closed_by_coat_tails',
    'lower_leg_visible':'test_far_shin_and_boot_must_both_show_below_tabard',
    'closed_forms_passed':'test_closed_topology_guard_rejects_a_torn_collar',
    'pants_above_belt':'test_pants_cannot_show_above_the_belt_even_outside_collar_band',
    'chest_passed':'test_barrel_chest_has_an_eighty_percent_minimum',
}.items():
    expression='True' if guard in ('closed_forms_passed','chest_passed') else "{'passed':True}"
    MUTATIONS['mass_'+guard]=('patch',
        'from spec.art_identity.maquettes.chainbound_gaoler import mass_gates as g;g.'+guard+'=lambda *a,**k:'+expression,
        '', 'MassGuardTests.'+test)


for row in ('front_coat_near_width','front_coat_near_hem','front_coat_far_width','front_coat_far_hem',
            'front_tabard_width','front_tabard_hem','rear_coat_near_width','rear_coat_near_hem',
            'rear_coat_far_width','rear_coat_far_hem'):
    MUTATIONS['cloth_'+row]=('patch',
        'from spec.art_identity.maquettes.chainbound_gaoler import cloth_gates as g;original=g.cloth_row_passed;'
        + 'g.cloth_row_passed=lambda name,*args:True if name=='+repr(row)+' else original(name,*args)',
        '', 'tests.test_mq15_cloth.ClothTests.test_every_cloth_width_and_hem_guard_is_enforced')
MUTATIONS['cloth_ragged_points']=('patch',
    'from spec.art_identity.maquettes.chainbound_gaoler import cloth_gates as g;g.hem_points_passed=lambda *a:True',
    '', 'tests.test_mq15_cloth.ClothTests.test_ragged_hems_require_the_directors_point_counts')
for guard in ('complete_gloved_grip','four_wrapped_fingers','knuckles_forward_of_palm',
              'thumb_over_fingers','top_link_in_grip_envelope','correct_hand_ownership'):
    patch=('from spec.art_identity.maquettes.chainbound_gaoler import geometry_checks as g\n'
           'original=g.grip_observation\n'
           'def mutant(*a,**k):\n'
           ' r=original(*a,**k)\n'
           ' r["checks"]['+repr(guard)+']=True\n'
           ' r["passed"]=all(r["checks"].values())\n'
           ' return r\n'
           'g.grip_observation=mutant')
    MUTATIONS['grip_'+guard]=('patch',patch,'','tests.test_mq15_cloth.ClothTests.test_each_gloved_grip_guard_rejects_its_failure')


MUTATIONS['fit_centroid']=('patch',
    'from spec.art_identity.maquettes.chainbound_gaoler import pose_fit as g;g.centroid_passed=lambda *a:True',
    '', 'tests.test_mq15_pose_fit.FitTests.test_six_pixel_head_shift_is_rejected')
MUTATIONS['fit_translation_search']=('patch',
    'from spec.art_identity.maquettes.chainbound_gaoler import pose_fit as g;g.best_translation=lambda *a:{"translation_px":[0,0],"iou":1}',
    '', 'tests.test_mq15_pose_fit.FitTests.test_translation_search_cannot_be_dropped')
MUTATIONS['fit_iou_limit']=('patch',
    'from spec.art_identity.maquettes.chainbound_gaoler import pose_fit as g;g.iou_passed=lambda *a:True',
    '', 'tests.test_mq15_pose_fit.FitTests.test_iou_threshold_is_enforced')
MUTATIONS['native_mesh_binding']=('patch',
    'from spec.art_identity.maquettes.chainbound_gaoler import geometry_checks as g\n'
    'original=g.native_mesh_binding\n'
    'def mutant(*a):\n r=original(*a);r["passed"]=True;return r\n'
    'g.native_mesh_binding=mutant',
    '', 'tests.test_mq15_native_geometry.NativeGeometryTests.test_changed_native_mesh_with_old_copied_hash_is_rejected')


for name,predicate in {
    'lateral_overlap':"overlap[2]>=g.GEOMETRY_PROOF_DEFAULTS['thumb_minimum_overlap_m'] and gap<=g.GEOMETRY_PROOF_DEFAULTS['thumb_maximum_gap_m']",
    'vertical_overlap':"overlap[0]>=g.GEOMETRY_PROOF_DEFAULTS['thumb_minimum_overlap_m'] and gap<=g.GEOMETRY_PROOF_DEFAULTS['thumb_maximum_gap_m']",
    'gap':"overlap[0]>=g.GEOMETRY_PROOF_DEFAULTS['thumb_minimum_overlap_m'] and overlap[2]>=g.GEOMETRY_PROOF_DEFAULTS['thumb_minimum_overlap_m']",
}.items():
    MUTATIONS['grip_thumb_'+name]=('patch',
        'from spec.art_identity.maquettes.chainbound_gaoler import geometry_checks as g;g.thumb_contact_passed=lambda overlap,gap:'+predicate,
        '', 'tests.test_mq15_native_geometry.NativeGeometryTests.test_thumb_needs_lateral_and_vertical_overlap_and_a_bounded_gap')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    results = {}
    for name, (kind, before, after, test) in MUTATIONS.items():
        code = 'from spec.art_identity.maquettes.blender import delivery_validation as v\n'
        if kind in ('text', 'acceptance_text'):
            code += ('from spec.art_identity.maquettes.chainbound_gaoler import acceptance as m\n'
                     if kind == 'acceptance_text' else 'm=v\n')
            function = 'inspect' if kind == 'acceptance_text' and name == 'true_turn' else 'proportions' if kind == 'acceptance_text' else 'validate_delivery'
            code += ('from pathlib import Path\nsource=Path(m.__file__).read_text()\n'
                     f'assert source.count({before!r})==1\nnamespace=dict(v.__dict__)\n'
                     'namespace=dict(m.__dict__)\n'
                     f'exec(compile(source.replace({before!r},{after!r}),m.__file__,"exec"),namespace)\n'
                     f'm.{function}=namespace[{function!r}]\n')
        else:
            code += before + '\n'
        case=test if '.' in test else 'DeliveryTests.'+test
        case=case if case.startswith('tests.') else 'tests.test_mq15_maquette.'+case
        code += ('import unittest\n'
                 f'suite=unittest.defaultTestLoader.loadTestsFromName("{case}")\n'
                 'result=unittest.TextTestRunner(verbosity=2).run(suite)\n'
                 'raise SystemExit(0 if result.wasSuccessful() else 1)\n')
        run = subprocess.run([sys.executable, '-B', '-c', code], text=True, capture_output=True)
        (args.out / (name + '.log')).write_text(run.stdout + run.stderr)
        caught = run.returncode == 1 and 'FAIL:' in run.stderr and 'Ran 1 test' in run.stderr and 'ERROR:' not in run.stderr
        results[name] = {'caught': caught, 'exit': run.returncode, 'regression': test}
    passed = all(r['caught'] for r in results.values())
    (args.out / 'mutation_results.json').write_text(json.dumps({'passed': passed, 'mutations': results}, indent=2) + '\n')
    print('MQ15_MUTATIONS: ' + ('PASS' if passed else 'FAIL') + '; caught=' +
          str(sum(r['caught'] for r in results.values())) + '; survived=' + str(sum(not r['caught'] for r in results.values())))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
