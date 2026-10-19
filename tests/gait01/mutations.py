"""Isolated test mutations; never edit the working runtime or authored data."""
import ast
from contextlib import contextmanager
import inspect
from pathlib import Path
import re
import tempfile


def without_transparent_target_guard(validator):
    tree = ast.parse(inspect.getsource(validator))
    guard = next(node for node in ast.walk(tree) if isinstance(node, ast.If)
                 and 'len(set(targets))' in ast.unparse(node.test))
    guard.test = ast.Constant(False)
    namespace = validator.__globals__.copy()
    exec(compile(ast.fix_missing_locations(tree), '<disabled transparent-target guard>', 'exec'), namespace)
    return namespace[validator.__name__]


@contextmanager
def without_bind_anchor(project):
    runtime = project / 'scripts/maquette_cutout_runtime'

    def source(name):
        # Copies live in a test fixture directory; retain every original
        # dependency except the single gait helper being mutated.
        return re.sub(r'preload\("([^"/]+\.gd)"\)',
                      r'preload("res://scripts/maquette_cutout_runtime/\1")',
                      (runtime / name).read_text())

    with tempfile.TemporaryDirectory(prefix='mutation_', dir=project / 'tests/gait01') as folder:
        folder = Path(folder)
        resource = 'res://' + folder.relative_to(project).as_posix()
        gait = source('humanoid_gait.gd')
        anchored = ('\tvar anchor: Vector2 = to_world * bind\n'
                    '\treturn to_world.affine_inverse() * (anchor + (to_world * target - anchor).round())')
        if gait.count(anchored) != 1:
            raise AssertionError('Bind-anchor mutation no longer matches the runtime helper')
        gait = gait.replace(anchored, '\treturn to_world.affine_inverse() * (to_world * target).round()')
        (folder / 'gait.gd').write_text(gait)
        presentation = source('humanoid_presentation.gd').replace(
            'preload("res://scripts/maquette_cutout_runtime/humanoid_gait.gd")',
            'preload("' + resource + '/gait.gd")')
        (folder / 'presentation.gd').write_text(presentation)
        (folder / 'rig.gd').write_text('''extends "res://assets/units/glacial_mirror_cutout/rig.gd"
const MutantPresentation = preload("presentation.gd")

func apply_pose(clip_name: String, phase_value: float) -> void:
	layout["motion_data"] = base_path().path_join("compiled_motion.json")
	var data: Dictionary = SemanticMotion.data_for(layout)
	apply_authored_pose(clip_name, Pixels.phase_for(data, clip_name, phase_value))
	MutantPresentation.apply(self, clip_name)
''')
        yield resource + '/rig.gd'
