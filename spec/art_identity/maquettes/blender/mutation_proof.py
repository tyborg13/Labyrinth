"""Reproduce the four surviving review mutations in isolated Python processes."""
import argparse
import importlib
import io
import json
from pathlib import Path
import subprocess
import sys
import unittest
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
sys.path.insert(0, str(PROJECT / 'tests'))

MUTATIONS = {
    'constant_torso': ('contract', 'label_faces', "result.append(max(sorted(totals), key=totals.get))", "result.append('torso')",
                       'OwnershipTests.test_multiple_weight_winners_and_stable_alphabetical_tie'),
    'material_index_zero': ('ownership', 'assign_materials', 'polygon.material_index = owner', 'polygon.material_index = 0',
                            'OwnershipTests.test_material_assignment_and_zero_index_mutation'),
    'omitted_cloth_context': ('cloth_cache', 'cache_key', "'context': context_key", "'context': 'omitted'",
                              'CacheTests.test_context_piece_blender_and_revision_invalidate_cache'),
    'disabled_cache_integrity': ('cloth_cache', 'read_cache', "if payload['mesh_hash'] != mesh_hash(payload['vertices'], payload['faces']):", 'if False:',
                                 'CacheTests.test_corrupt_cached_coordinates_and_topology_are_rejected'),
}


def exercise(name):
    module_name, function, before, after, test = MUTATIONS[name]
    module = importlib.import_module('spec.art_identity.maquettes.blender.' + module_name)
    source = Path(module.__file__).read_text()
    assert source.count(before) == 1, 'Mutation target no longer unique'
    namespace = dict(module.__dict__)
    exec(compile(source.replace(before, after), module.__file__, 'exec'), namespace)
    setattr(module, function, namespace[function])
    # Import the behavioral tests only after installing the isolated mutation.
    suite = unittest.defaultTestLoader.loadTestsFromName('test_maquette_regressions.' + test)
    stream = io.StringIO()
    result = unittest.TextTestRunner(stream=stream, verbosity=2).run(suite)
    if len(result.failures) < 1 or result.errors:
        print(stream.getvalue())
        return 1
    print('MUTATION_CAUGHT: ' + name + '; assertion_failures=' + str(len(result.failures)) + '; errors=0')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--mutation', choices=MUTATIONS)
    parser.add_argument('--out', type=Path)
    args = parser.parse_args()
    if args.mutation:
        return exercise(args.mutation)
    results = {}
    for name in MUTATIONS:
        process = subprocess.run([sys.executable, '-B', __file__, '--mutation', name], capture_output=True, text=True)
        print(process.stdout, end='')
        results[name] = {'caught': process.returncode == 0, 'result': process.stdout.strip(), 'stderr': process.stderr}
    if args.out:
        args.out.write_text(json.dumps(results, indent=2) + '\n')
    passed = all(r['caught'] for r in results.values())
    print('MQ03_MUTATIONS: ' + ('PASS; caught=4; survived=0' if passed else 'FAIL'))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
