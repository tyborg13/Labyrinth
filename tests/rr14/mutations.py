"""Sequential guard-removal proof; restores every source file even on failure."""
import json
import os
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
SCRATCH = Path('/private/tmp/labyrinth_codex/rr-14/feedback1/mutations')
PROOF_TIMEOUT_SECONDS = 180
DOMAIN_TESTS = ['tests.test_rr14_continuation_domains']
RUNTIME_TESTS = ['tests.test_rr14_foundations.FoundationTests.test_second_anatomy_compiler_gates_and_headless_runtime']
MUTATIONS = [
    ('idle_group_anchor', 'tools/humanoid_cutout/gates.py',
     "anchor = anatomy['idle_groups'][group]['bones'][0]", "anchor = 'root'",
     ['tests.test_rr14_foundations.FoundationTests.test_native_idle_offset_uses_the_lagged_weapon_group_anchor']),
    ('named_cover', 'tools/humanoid_cutout/joint_continuations.py',
     ' & cover & ~own', ' & ~own', DOMAIN_TESTS),
    ('garment_bounds', 'tools/humanoid_cutout/joint_continuations.py',
     '            target &= bounds', '            pass  # mutation: omit bounds', DOMAIN_TESTS),
    ('connectivity', 'tools/humanoid_cutout/joint_continuations.py',
     'result[name] = connected_mask(base, target)', 'result[name] = target', DOMAIN_TESTS),
    ('foot_dispatch', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     '_solve_two_bone(result, joints, "thigh_" + side, "shin_" + side, foot, true, float(policy["bend_side"]))',
     'pass # mutation: omit foot solve', RUNTIME_TESTS),
    ('reach_clamp', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'first + second if full_extension else first + second - SOLVE_EPSILON',
     'ray.length() if full_extension else first + second - SOLVE_EPSILON', RUNTIME_TESTS),
    ('bend_side', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'if full_extension: bend_side = leg_bend_side', 'if full_extension: bend_side = 1.0', RUNTIME_TESTS),
    ('shin_rotation', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'world[fore] = Transform2D(wrapf(fore_angle, -PI, PI), elbow)',
     'world[fore] = Transform2D(0.0, elbow)', RUNTIME_TESTS),
    ('required_hierarchy', 'tools/humanoid_cutout/gates.py',
     "if layout['joints'].get(name, {}).get('parent', 'missing') != parent:",
     'if False:', ['tests.test_rr14_foundations.FoundationTests.test_case_hierarchy_and_mesh_guards']),
    ('required_meshes', 'tools/humanoid_cutout/gates.py',
     "if set(meshes) != set(anatomy['meshes']):", 'if False:',
     ['tests.test_rr14_foundations.FoundationTests.test_case_hierarchy_and_mesh_guards']),
    ('missing_knee_policy', 'scripts/maquette_cutout_runtime/humanoid_anatomy.gd',
     'if rest_side == 0.0 and authored == null:', 'if false:',
     ['tests.test_rr14_anatomy.AnatomyTests.test_runtime_missing_and_conflicting_knee_policies_fail_loudly']),
    ('conflicting_knee_policy', 'scripts/maquette_cutout_runtime/humanoid_anatomy.gd',
     'if rest_side != 0.0 and authored != null and float(authored) != rest_side:', 'if false:',
     ['tests.test_rr14_anatomy.AnatomyTests.test_runtime_missing_and_conflicting_knee_policies_fail_loudly']),
    ('knee_policy_rejection', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'push_error("Invalid humanoid leg IK: " + str(policy["error"]))\n\t\t\t\treturn {}',
     'push_error("Invalid humanoid leg IK: " + str(policy["error"]))\n\t\t\t\tpass',
     ['tests.test_rr14_anatomy.AnatomyTests.test_runtime_missing_and_conflicting_knee_policies_fail_loudly']),
    ('bent_knee_rest_side', 'scripts/maquette_cutout_runtime/humanoid_anatomy.gd',
     'signf(cross) if absf(cross)', '1.0 if absf(cross)', RUNTIME_TESTS),
    ('python_missing_knee_policy', 'tools/humanoid_cutout/bone_contracts.py',
     ".get('bend_side')", ".get('bend_side', 1)",
     ['tests.test_rr14_anatomy.AnatomyTests.test_straight_legs_require_per_view_policy_and_compiler_copies_it']),
    ('python_conflicting_knee_policy', 'tools/humanoid_cutout/bone_contracts.py',
     'if rest_side != 0 and authored is not None and authored != rest_side:', 'if False:',
     ['tests.test_rr14_anatomy.AnatomyTests.test_bent_leg_keeps_rest_side_and_rejects_disagreeing_data']),
    ('compiled_leg_policy', 'tools/humanoid_cutout/compiler.py',
     "result.setdefault('legs', {}).setdefault(side, {})[view] = dict(policy)", 'pass', RUNTIME_TESTS),
    ('authored_attachment_local', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'world[name] = (world[parent] as Transform2D) * (authored[name] as Transform2D)',
     'world[name] = (world[parent] as Transform2D) * Transform2D(0.0, Tracks.point(joints[name]["position"]) - Tracks.point(joints[parent]["position"]))', RUNTIME_TESTS),
    ('attachment_grandchild', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'affected[name] = true', 'pass # mutation: immediate children only', RUNTIME_TESTS),
    ('held_item_descendants', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'solved[item] = true\n\t\t_propagate_descendants(result, joints, authored, order, solved)',
     'solved[item] = true', RUNTIME_TESTS),
    ('loaded_schema_validation', 'tools/humanoid_cutout/anatomy.py',
     "return validate(read_json(Path(case) / 'anatomy.json'))", "return read_json(Path(case) / 'anatomy.json')",
     ['tests.test_rr14_anatomy.AnatomyTests.test_schema_version_and_types_apply_to_embedded_as_well_as_loaded']),
    ('embedded_schema_validation', 'tools/humanoid_cutout/anatomy.py',
     "return validate(layout['anatomy'])", "return layout['anatomy']",
     ['tests.test_rr14_anatomy.AnatomyTests.test_schema_version_and_types_apply_to_embedded_as_well_as_loaded']),
    ('unknown_schema_keys', 'tools/humanoid_cutout/schema.py',
     'elif additional is False:', 'elif False:',
     ['tests.test_rr14_anatomy.AnatomyTests.test_unknown_keys_at_each_structured_level_are_rejected']),
    ('explicit_grip_role', 'tools/humanoid_cutout/schema.py',
     'if required not in value:', "if required != 'grip' and required not in value:",
     ['tests.test_rr14_anatomy.AnatomyTests.test_absent_grip_requires_explicit_null_and_griip_is_not_accepted']),
    ('bone_gate_bend_side', 'tools/humanoid_cutout/bone_contracts.py',
     'if cross(c-a, b-a) * expected_side < -epsilon:', 'if False:',
     ['tests.test_rr14_bone_guards.BoneGuardTests.test_reflected_knee_preserves_lengths_and_target_but_fails_specific_bend_error']),
    ('bone_gate_foot_target', 'tools/humanoid_cutout/bone_contracts.py',
     'if not np.allclose(c, a + axis * distance, atol=epsilon, rtol=0):',
     "if kind != 'foot' and not np.allclose(c, a + axis * distance, atol=epsilon, rtol=0):",
     ['tests.test_rr14_bone_guards.BoneGuardTests.test_wrong_foot_target_preserves_lengths_and_bend_side_but_fails_specific_target_error']),
]


def main():
    SCRATCH.mkdir(parents=True, exist_ok=True)
    rows = []
    for name, filename, old, new, tests in MUTATIONS:
        path = PROJECT / filename
        original = path.read_bytes()
        source = original.decode()
        if source.count(old) != 1: raise ValueError('Ambiguous mutation anchor: ' + name)
        try:
            path.write_text(source.replace(old, new))
            env = dict(os.environ, LABYRINTH_TASK_ID='rr-14', PYTHONDONTWRITEBYTECODE='1')
            result = subprocess.run([sys.executable, '-B', '-m', 'unittest', *tests, '-v'],
                                    cwd=PROJECT, env=env, capture_output=True, text=True,
                                    timeout=PROOF_TIMEOUT_SECONDS)
            log = result.stdout + result.stderr
            (SCRATCH / (name + '.log')).write_text(log)
            # A parse/import/launch failure does not prove an assertion guard.
            caught = result.returncode != 0 and 'FAIL:' in log and 'Parse Error' not in log
            rows.append({'mutation': name, 'result': 'caught' if caught else 'survived',
                         'exit_code': result.returncode, 'log': str(SCRATCH / (name + '.log'))})
        finally:
            path.write_bytes(original)
        print('RR14 MUTATION %s: %s' % (name, rows[-1]['result'].upper()), flush=True)
    (SCRATCH / 'results.json').write_text(json.dumps(rows, indent=2) + '\n')
    caught = sum(row['result'] == 'caught' for row in rows)
    print('RR14 MUTATIONS: %d caught; %d survived' % (caught, len(rows) - caught))
    return int(caught != len(rows))


if __name__ == '__main__':
    raise SystemExit(main())
