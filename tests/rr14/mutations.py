"""Sequential guard-removal proof; restores every source file even on failure."""
import json
import os
from pathlib import Path
import subprocess
import sys

PROJECT = Path(__file__).resolve().parents[2]
SCRATCH = Path('/private/tmp/labyrinth_codex/rr-14/mutations')
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
     '_solve_two_bone(result, joints, "thigh_" + side, "shin_" + side, foot, true)',
     'pass # mutation: omit foot solve', RUNTIME_TESTS),
    ('reach_clamp', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'first + second if full_extension else first + second - SOLVE_EPSILON',
     'ray.length() if full_extension else first + second - SOLVE_EPSILON', RUNTIME_TESTS),
    ('bend_side', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'signf((c - a).cross(b - a))', '1.0', RUNTIME_TESTS),
    ('shin_rotation', 'scripts/maquette_cutout_runtime/humanoid_motion.gd',
     'world[fore] = Transform2D(wrapf(fore_angle, -PI, PI), elbow)',
     'world[fore] = Transform2D(0.0, elbow)', RUNTIME_TESTS),
    ('required_hierarchy', 'tools/humanoid_cutout/gates.py',
     "if layout['joints'].get(name, {}).get('parent', 'missing') != parent:",
     'if False:', ['tests.test_rr14_foundations.FoundationTests.test_case_hierarchy_and_mesh_guards']),
    ('required_meshes', 'tools/humanoid_cutout/gates.py',
     "if set(meshes) != set(anatomy['meshes']):", 'if False:',
     ['tests.test_rr14_foundations.FoundationTests.test_case_hierarchy_and_mesh_guards']),
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
