"""Exercise the real merged build dispatcher with native APIs mocked out."""
from contextlib import ExitStack
from copy import deepcopy
import ast
import inspect
from pathlib import Path
import tempfile
from types import ModuleType, SimpleNamespace as NS
import unittest
from unittest.mock import Mock, patch

from spec.art_identity.maquettes import blender as package
from spec.art_identity.maquettes.blender import build, facing, ownership, pose_adjustment, socket_tuck
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import validate
import json

ROOT = Path(__file__).resolve().parents[1] / 'spec/art_identity/maquettes'
DISPATCH_FIXTURE = {'joints': {'root': [0, 0, 0], 'elbow': [1, 0, 0]},
                    'source_joints': {'root': [0, 0, 0], 'elbow': [0, 1, 0]},
                    'triangle': [[0, 0, 0], [1, 0, 0], [0, 1, 0]],
                    'colour': [0.1, 0.2, 0.3], 'gravity': [0, 0, -9.81], 'fps': 24,
                    'bundle_bytes': b'approved anatomy fixture', 'forward': [1, 0, 0]}


class StopAfterGeometry(Exception):
    pass


class MatrixFixture:
    def copy(self):
        return self

    def __matmul__(self, value):
        return value


class ObjectFixture(dict):
    def __init__(self, name, points=(), faces=()):
        super().__init__()
        self.name = name
        self.data = NS(vertices=[NS(co=point) for point in points],
                       polygons=[NS(vertices=face) for face in faces], materials=[])
        self.matrix_world = MatrixFixture()

    def hide_set(self, value):
        self.hidden = value


class BuilderWiringTests(unittest.TestCase):
    def dispatch(self, procedural):
        events = []
        rig = ObjectFixture('rig')
        rig['posed_forward'] = DISPATCH_FIXTURE['forward']
        body = ObjectFixture('body')
        posed = ObjectFixture('posed', DISPATCH_FIXTURE['triangle'], [[0, 1, 2]])
        owners = [] if procedural else ['torso']
        spec = {'base': {'asset': 'procedural_chain' if procedural else 'approved_fixture'},
                'joints': DISPATCH_FIXTURE['joints'], 'source_fit_joints': DISPATCH_FIXTURE['source_joints'],
                'simulation': {'gravity': DISPATCH_FIXTURE['gravity'], 'fps': DISPATCH_FIXTURE['fps']},
                'labels': {'torso': DISPATCH_FIXTURE['colour']}, 'pieces': []}
        def call(name, result):
            def invoke(*args):
                events.append(name)
                return result
            return Mock(side_effect=invoke)
        append = call('append', body)
        bind = call('bind', (rig, posed, owners))
        fit = call('fit', {})
        repose = call('repose', None)
        create = call('create', (rig, posed, owners))
        split = call('split', ObjectFixture('body_torso'))
        def tucks(working, anatomy, regions, objects):
            events.append('tucks')
            self.assertIs(anatomy, posed)
            self.assertEqual(regions, owners)
            self.assertEqual([obj.get('part') for obj in objects], [] if procedural else ['torso'])
        def finish(*args):
            events.append('geometry')
            raise StopAfterGeometry
        modules = {
            'rig': {'append_body': append, 'bind_and_pose': bind, 'evaluated_mesh': Mock()},
            'pieces': {'mesh_object': split}, 'cloth': {'cloth': Mock()},
            'source_cage': {'fit_body': fit}, 'creature_rig': {'create': create},
            'render': {'material': Mock()}, 'validation': {'geometry_report': finish}}
        with tempfile.TemporaryDirectory() as temporary, ExitStack() as stack:
            root = Path(temporary)
            bundle = root / 'bundle.blend'
            bundle.write_bytes(DISPATCH_FIXTURE['bundle_bytes'])
            bpy = NS(ops=NS(wm=NS(read_factory_settings=Mock())),
                     context=NS(preferences=NS(filepaths=NS()), scene=NS(render=NS())))
            replacements = {'bpy': bpy}
            for name, fields in modules.items():
                module = ModuleType(package.__name__ + '.' + name)
                module.__dict__.update(fields)
                replacements[module.__name__] = module
                stack.enter_context(patch.object(package, name, module, create=True))
            stack.enter_context(patch.dict('sys.modules', replacements))
            contract = stack.enter_context(patch.object(build, 'validate'))
            stack.enter_context(patch.object(facing, 'board_spec', side_effect=deepcopy))
            stack.enter_context(patch.object(pose_adjustment, 'repose', repose))
            stack.enter_context(patch.object(socket_tuck, 'append_tucks', side_effect=tucks))
            stack.enter_context(patch.object(ownership, 'assign_materials'))
            stack.enter_context(patch.object(ownership, 'expected_materials', return_value=[]))
            with self.assertRaises(StopAfterGeometry):
                build.build(spec, root / 'output', bundle, root / 'cache')
            contract.assert_called_once_with(spec)
        if procedural:
            self.assertEqual(events, ['create', 'tucks', 'geometry'])
            for function in (append, bind, fit, repose):
                function.assert_not_called()
            create.assert_called_once()
        else:
            self.assertEqual(events, ['append', 'bind', 'fit', 'repose', 'split', 'tucks', 'geometry'])
            create.assert_not_called()
            self.assertEqual(bind.call_args.args[0]['joints'], DISPATCH_FIXTURE['source_joints'])
            self.assertEqual(fit.call_args.args[0]['joints'], DISPATCH_FIXTURE['source_joints'])
            self.assertEqual(repose.call_args.args[0]['joints'], DISPATCH_FIXTURE['joints'])

    def test_procedural_chain_dispatch_skips_appended_body_and_fitting(self):
        self.dispatch(procedural=True)

    def test_fit_repose_split_and_socket_tuck_order(self):
        self.dispatch(procedural=False)


class InvalidNativeContracts(unittest.TestCase):
    def test_invalid_socket_contracts_are_rejected(self):
        spec = compile_recipe(json.loads((ROOT / 'arc_thrall/measurements.json').read_text()))
        validate(spec)
        mutations = [lambda s: s['base']['socket_tucks'][0].update(socket='missing'),
                     lambda s: s['base']['socket_tucks'][0].update(source_region='torso'),
                     lambda s: s['base']['socket_tucks'][0].update(part='missing', source_region='missing'),
                     lambda s: s['base']['socket_tucks'][0].update(adjacent_region='torso'),
                     lambda s: s['base']['socket_tucks'][0].update(end_joint='missing'),
                     lambda s: s['base']['socket_tucks'].append(deepcopy(s['base']['socket_tucks'][0])),
                     lambda s: s['base']['socket_tucks'][0].update(id='forearm_sheath'),
                     lambda s: next(p for p in s['pieces'] if p['id']=='forearm_sheath')['socket'].update(axis=[0,0,0]),
                     lambda s: next(p for p in s['pieces'] if p['id']=='forearm_sheath')['socket'].update(inner_radius=0)]
        for index, mutation in enumerate(mutations):
            with self.subTest(mutation=index):
                changed = deepcopy(spec)
                mutation(changed)
                with self.assertRaises(ValueError):
                    validate(changed)

    def test_foot_exception_is_rejected_even_with_a_valid_support_path(self):
        spec = compile_recipe(json.loads((ROOT / 'ember_tick/measurements.json').read_text()))
        validate(spec)
        spec['foot_contacts']['exceptions'] = [{'point': spec['foot_contacts']['pieces'][0],
                                                'reason': 'test fixture', 'authority': 'test fixture'}]
        with self.assertRaisesRegex(ValueError, 'No lifted-foot design exceptions'):
            validate(spec)


class ReviewedRemovalTests(unittest.TestCase):
    def test_each_reviewed_removal_fails_its_regression(self):
        from spec.art_identity.maquettes.blender import contract
        import sys
        cases = [('procedural_chain', build, 'build', BuilderWiringTests,
                  'test_procedural_chain_dispatch_skips_appended_body_and_fitting'),
                 ('repose', build, 'build', BuilderWiringTests, 'test_fit_repose_split_and_socket_tuck_order'),
                 ('append_tucks', build, 'build', BuilderWiringTests, 'test_fit_repose_split_and_socket_tuck_order'),
                 ('socket_contract', contract, 'validate', InvalidNativeContracts, 'test_invalid_socket_contracts_are_rejected'),
                 ('foot_exception', contract, 'validate', InvalidNativeContracts,
                  'test_foot_exception_is_rejected_even_with_a_valid_support_path')]
        for mutation, module, name, case, method in cases:
            class Removal(ast.NodeTransformer):
                matches = 0

                def visit_Expr(self, node):
                    if (mutation in ('repose', 'append_tucks') and isinstance(node.value, ast.Call) and
                            isinstance(node.value.func, ast.Name) and node.value.func.id == mutation):
                        self.matches += 1
                        return None
                    return self.generic_visit(node)

                def visit_If(self, node):
                    if mutation == 'procedural_chain' and any(isinstance(child, ast.Constant) and
                            child.value == 'procedural_chain' for child in ast.walk(node.test)):
                        self.matches += 1
                        node.test = ast.Constant(False)
                    if mutation == 'foot_exception' and ast.unparse(node.test) == "contact.get('exceptions')":
                        self.matches += 1
                        return None
                    return self.generic_visit(node)

                def visit_For(self, node):
                    if mutation == 'socket_contract' and isinstance(node.target, ast.Name) and node.target.id == 'tuck':
                        self.matches += 1
                        return None
                    return self.generic_visit(node)
            with self.subTest(removal=mutation):
                removal = Removal()
                tree = removal.visit(ast.parse(inspect.getsource(getattr(module, name))))
                self.assertEqual(removal.matches, 1)
                namespace = {}
                exec(compile(ast.fix_missing_locations(tree), module.__file__, 'exec'), module.__dict__, namespace)
                target = build if name == 'build' else sys.modules[__name__]
                with patch.object(target, name, namespace[name]):
                    result = unittest.TestResult()
                    case(method).run(result)
                self.assertEqual(result.errors, [])
                self.assertTrue(result.failures, 'Removal escaped regression: ' + mutation)
                print('MQ07_REVIEW_MUTATION_REJECTED: ' + mutation)


if __name__ == '__main__':
    unittest.main()
