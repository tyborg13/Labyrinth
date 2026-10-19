"""Immutable input-only snapshots for cold maquette regeneration and resume."""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.curate_delivery import sha, write

FIGURE = Path(__file__).resolve().parent
BUILDER = FIGURE.parent / 'blender'
COMPILE_PROGRAM = '''import json,sys
from pathlib import Path
sys.path.insert(0,sys.argv[1])
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
print(json.dumps(compile_recipe(json.loads(Path(sys.argv[2]).read_text())),indent=2,allow_nan=False))
'''


def source_files(figure, recipe_path=None):
    prefix = Path('spec/art_identity/maquettes')
    sources = {str(prefix / p.name): p for p in FIGURE.parent.glob('*.py')}
    sources.update({str(prefix / 'blender' / p.name): p for p in BUILDER.glob('*.py')})
    sources[str(prefix / 'frostglass_lancer/spec_r3.json')] = FIGURE.parent / 'frostglass_lancer/spec_r3.json'
    measured = (figure / 'measurements.json').is_file()
    name = 'measurements.json' if measured else 'spec_r3.json'
    sources[str(prefix / figure.name / name)] = Path(recipe_path or figure / name)
    return sources, prefix / figure.name / name


def validate_input_tree(project, inventory):
    if project.is_symlink():
        raise ValueError('Input snapshot root is a symlink')
    permitted_directories = {str(parent) for name in inventory for parent in Path(name).parents if str(parent) != '.'}
    actual = {}
    for path in project.rglob('*'):
        name = str(path.relative_to(project))
        if path.is_symlink():
            raise ValueError('Input snapshot contains a symlink: ' + name)
        if path.is_dir() and name not in permitted_directories:
            raise ValueError('Generated directory in input snapshot: ' + name)
        if path.is_file():
            actual[name] = sha(path)
    if actual != inventory:
        raise ValueError('Input-only inventory changed or contains generated outputs')


def clean_inputs(output, figure=FIGURE, recipe_path=None, resume=False):
    output, figure = Path(output), Path(figure)
    project = output / 'clean_project'
    inventory_path, state_path = output / 'clean_input_sha256.json', output / 'input_state.json'
    sources, recipe_name = source_files(figure, recipe_path)
    expected = {name: sha(path) for name, path in sorted(sources.items())}
    if resume:
        if not project.is_dir() or not inventory_path.is_file() or not state_path.is_file():
            raise ValueError('Resume requires the original input-only inventory and state')
        state = json.loads(state_path.read_text())
        inventory = json.loads(inventory_path.read_text())
        if state.get('inventory_sha256') != sha(inventory_path) or inventory != expected:
            raise ValueError('Original input-only inventory or source inputs changed')
        validate_input_tree(project, inventory)
    else:
        if output.exists() and any(output.iterdir()):
            raise ValueError('New regeneration requires a fresh empty output directory')
        project.mkdir(parents=True)
        for name, source in sources.items():
            if source.is_symlink():
                raise ValueError('Input source must be a regular file: ' + str(source))
            target = project / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
        validate_input_tree(project, expected)
        write(inventory_path, expected)
        state = {'schema': 1, 'inventory_sha256': sha(inventory_path)}
    recipe = project / recipe_name
    if recipe.name == 'measurements.json':
        compiled = subprocess.check_output([sys.executable, '-B', '-c', COMPILE_PROGRAM, str(project.resolve()), str(recipe.resolve())])
    else:
        compiled = recipe.read_bytes()
    compiled_sha = hashlib.sha256(compiled).hexdigest()
    destination = output / 'spec_native.json'
    if resume:
        if state.get('compiled_spec_sha256') != compiled_sha:
            raise ValueError('Compiled specification differs from original input snapshot')
        if destination.is_file() and sha(destination) != compiled_sha:
            raise ValueError('Generated specification was changed during resume')
    else:
        state['compiled_spec_sha256'] = compiled_sha
        write(state_path, state)
    if not destination.exists():
        destination.write_bytes(compiled)
    validate_input_tree(project, expected)
    return destination


def input_builder(spec_path):
    return Path(spec_path).parent / 'clean_project/spec/art_identity/maquettes/blender/build.py'
