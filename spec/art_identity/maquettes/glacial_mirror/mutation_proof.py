"""Run mq-08 guard-removal mutations in memory; never edit accepted assets."""
import argparse
import ast
from contextlib import ExitStack, redirect_stdout
from copy import deepcopy
import importlib.util
import inspect
import io
import json
from pathlib import Path
import textwrap
import unittest
from unittest.mock import patch

from spec.art_identity.maquettes.blender import capture_manifest
from spec.art_identity.maquettes.blender.curate_delivery import write
from spec.art_identity.maquettes.glacial_mirror import guards, regeneration_inputs, shoulder_revision, workflow

FIGURE = Path(__file__).resolve().parent
PROJECT = FIGURE.parents[3]


def load_tests(name):
    spec = importlib.util.spec_from_file_location(name, PROJECT / 'tests' / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def altered_function(function, predicate):
    tree = ast.parse(textwrap.dedent(inspect.getsource(function)))
    matches = 0
    for node in ast.walk(tree):
        if isinstance(node, ast.If) and predicate(ast.unparse(node.test)):
            node.test = ast.Constant(False)
            matches += 1
    if matches != 1:
        raise ValueError('Mutation must remove exactly one guard: ' + function.__name__)
    ast.fix_missing_locations(tree)
    namespace = dict(function.__globals__)
    exec(compile(tree, '<mq08-memory-mutation>', 'exec'), namespace)
    return namespace[function.__name__]


def run_case(module, class_name, names):
    suite = unittest.TestSuite(getattr(module, class_name)(name) for name in names)
    result = unittest.TestResult()
    with redirect_stdout(io.StringIO()):
        suite.run(result)
    return {'tests_run': result.testsRun, 'passed': result.wasSuccessful(),
            'failures': [str(test) for test, _ in result.failures],
            'errors': [str(test) for test, _ in result.errors]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=FIGURE / 'proof/feedback1/mutations')
    args = parser.parse_args()
    shoulder = load_tests('test_glacial_mirror_shoulder')
    inputs = load_tests('test_glacial_mirror_regeneration')
    cases = [
        ('cap_migration_and_recipe_up_80px', shoulder, 'GlacialMirrorShoulderTests',
         ['test_migration_reproduces_canonical_recipe_without_modifying_input',
          'test_far_cap_uses_existing_near_crest_dimensions_and_sculpt']),
        ('shoulder_guard_removed', shoulder, 'GlacialMirrorShoulderTests', ['test_live_shoulder_guard_rejects_lowered_shoulder']),
        ('pauldron_guard_removed', shoulder, 'GlacialMirrorShoulderTests', ['test_live_pauldron_guard_rejects_cap_lift_in_migration_and_canonical']),
        ('turn_guard_removed', shoulder, 'GlacialMirrorShoulderTests', ['test_live_turn_guard_rejects_mirrored_rear']),
        ('partial_mode_guard_removed', shoulder, 'GlacialMirrorShoulderTests', ['test_partial_capture_never_receives_full_delivery_certification']),
        ('fresh_directory_guard_removed', inputs, 'RegenerationInputTests', ['test_new_run_requires_fresh_empty_directory']),
        ('input_tree_guard_removed', inputs, 'RegenerationInputTests', ['test_resume_refuses_generated_files_and_directories_inside_snapshot']),
        ('original_inventory_guard_removed', inputs, 'RegenerationInputTests', ['test_resume_refuses_snapshot_and_inventory_forged_together']),
        ('cache_reuse_reporting_removed', inputs, 'RegenerationInputTests', ['test_cache_and_receipt_reuse_are_reported_from_actual_execution'])]
    results = []
    for name, module, class_name, names in cases:
        baseline = run_case(module, class_name, names)
        if not baseline['passed']:
            raise ValueError('Baseline test failed before mutation: ' + name + '; ' + json.dumps(baseline))
        with ExitStack() as stack:
            if name == 'cap_migration_and_recipe_up_80px':
                original_revise, original_read = shoulder.revise, Path.read_text
                def shifted(recipe):
                    candidate = deepcopy(recipe)
                    cap = next(p for p in candidate['native_solids']['surfaces'] if p['id'] == 'shoulder_far_mass')
                    for point in cap['centre_px']:
                        point[1] -= shoulder.TEST_DEFAULTS['cap_lift_px'] / 4
                    return candidate
                bad = shifted(shoulder.current())
                def read(path, *values, **options):
                    return json.dumps(bad) if path == FIGURE / 'measurements.json' else original_read(path, *values, **options)
                stack.enter_context(patch.object(Path, 'read_text', read))
                stack.enter_context(patch.object(shoulder, 'revise', side_effect=lambda before: shifted(original_revise(before))))
            elif name in ('shoulder_guard_removed', 'pauldron_guard_removed', 'turn_guard_removed'):
                target = {'shoulder_guard_removed': 'shoulder_rule', 'pauldron_guard_removed': 'pauldron_rule',
                          'turn_guard_removed': 'turn_rule'}[name]
                stack.enter_context(patch.object(guards, target, return_value=True))
            elif name == 'partial_mode_guard_removed':
                stack.enter_context(patch.object(capture_manifest, 'capture_mode', return_value='full'))
            elif name == 'fresh_directory_guard_removed':
                mutant = altered_function(regeneration_inputs.clean_inputs, lambda text: 'output.exists()' in text)
                stack.enter_context(patch.object(regeneration_inputs, 'clean_inputs', mutant))
            elif name == 'input_tree_guard_removed':
                stack.enter_context(patch.object(regeneration_inputs, 'validate_input_tree', return_value=None))
            elif name == 'original_inventory_guard_removed':
                mutant = altered_function(regeneration_inputs.clean_inputs, lambda text: "state.get('inventory_sha256')" in text)
                stack.enter_context(patch.object(regeneration_inputs, 'clean_inputs', mutant))
            else:
                stack.enter_context(patch.object(workflow, 'reuse_summary', return_value={
                    'cache_reused': False, 'build_receipts_reused': True, 'resumed': True}))
            mutated = run_case(module, class_name, names)
        caught = bool(mutated['failures'])
        results.append({'mutation': name, 'baseline': baseline, 'mutated': mutated, 'caught': caught})
        print('MQ08_MUTATION: ' + name + '; ' + ('CAUGHT' if caught else 'SURVIVED'))
    passed = all(r['caught'] for r in results)
    write(args.out / 'mutations.json', {'passed': passed, 'mutations': results})
    table = ['| Removed guard / mutation | Result |', '|---|---|']
    table += [f"| {r['mutation']} | {'CAUGHT' if r['caught'] else 'SURVIVED'} |" for r in results]
    (args.out / 'mutation_table.md').write_text('\n'.join(table) + '\n')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
