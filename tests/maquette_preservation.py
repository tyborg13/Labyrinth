"""Keep cold-build receipts useful without binding later units' validation/data."""
import hashlib
from contextlib import contextmanager
import importlib
from pathlib import Path
import tempfile
from unittest.mock import patch

from tools.unit_preservation import changed_paths, read_bytes, read_json, tracked_paths

PREFIX = 'spec/art_identity/maquettes/'
BUILDER = PREFIX + 'blender/'
FOREIGN_HELPERS = (PREFIX + 'gust_shrike.py', PREFIX + 'shrike_spec.py')
LANCER_INPUT = PREFIX + 'frostglass_lancer/spec_r3.json'
SHARED_FOLDERS = {'blender', 'base_meshes', 'proof_mq02'}
FLOOR_EXCEPTIONS = PREFIX + 'hoarfrost_seer/rear_turn/feedback2/floor_guard_exceptions.json'


def foreign_maquette_changes(project, baseline, end, owned_figures):
    """An endpoint receipt can agree with an unauthorized edit; compare trees too."""
    allowed = SHARED_FOLDERS | set(owned_figures)
    errors = []
    for relative in changed_paths(project, baseline, end):
        if relative == FLOOR_EXCEPTIONS:
            # mq-07 clears Thrall's own floor exception in this shared ledger.
            # Every other figure's entry and all metadata remain protected.
            before, after = [read_json(project, revision, relative) for revision in (baseline, end)]
            for data in (before, after):
                data['figures'] = {name: value for name, value in data['figures'].items()
                                   if name not in owned_figures}
            if before != after:
                errors.append(relative)
        elif relative in FOREIGN_HELPERS or (relative.startswith(PREFIX) and len(Path(relative).parts) > 4
                                             and Path(relative).parts[3] not in allowed):
            errors.append(relative)
    return errors


@contextmanager
def historical_compiler(project, revision):
    """Supply the unit's Lancer registration to both measured compiler paths.

    Only the test context changes; production compilation and its native input
    closure stay untouched. Both modules read PROJECT solely for this input.
    """
    compiler = importlib.import_module('spec.art_identity.maquettes.blender.compile_recipe')
    solids = importlib.import_module('spec.art_identity.maquettes.blender.creature_recipe')
    blob = read_bytes(project, revision, LANCER_INPUT)
    with tempfile.TemporaryDirectory(prefix='int04-lancer-', dir=project) as folder:
        root = Path(folder)
        target = root / LANCER_INPUT
        target.parent.mkdir(parents=True)
        target.write_bytes(blob)
        with patch.object(compiler, 'PROJECT', root), patch.object(solids, 'PROJECT', root):
            yield compiler.compile_recipe


def validation_source(relative):
    return relative.startswith(BUILDER) and Path(relative).name.startswith('test_') and relative.endswith('.py')


def regeneration_hashes(project, revision, figure, sources, recipe_path=None, own_recipe=False):
    """Keep native builder coverage live; scope foreign inputs and test receipts.

    source_files() deliberately copies every builder Python file, including its
    tests. Those tests validate a build but cannot change its pixels. Keep their
    exact sealed bytes/inventory historical, while still detecting new or edited
    native builder modules and changes to this unit's own recipe.
    """
    result = {}
    figure_prefix = PREFIX + figure + '/'
    for relative, source in sources.items():
        if validation_source(relative) or relative in FOREIGN_HELPERS:
            continue
        if not own_recipe and relative.startswith(figure_prefix):
            continue  # The historical recipe's name/selection is resolved below.
        path = Path(relative)
        foreign_data = (relative.startswith(PREFIX) and len(path.parts) > 4
                        and path.parts[3] != 'blender'
                        and not (own_recipe and path.parts[3] == figure))
        if foreign_data:
            blob = read_bytes(project, revision, source.relative_to(project).as_posix())
        else:
            blob = source.read_bytes()
        result[relative] = hashlib.sha256(blob).hexdigest()
    if not own_recipe:
        files = tracked_paths(project, revision, figure_prefix)
        name = 'measurements.json' if figure_prefix + 'measurements.json' in files else 'spec_r3.json'
        source = recipe_path.relative_to(project).as_posix() if recipe_path else figure_prefix + name
        result[figure_prefix + name] = hashlib.sha256(read_bytes(project, revision, source)).hexdigest()
    for relative in tracked_paths(project, revision, BUILDER):
        if validation_source(relative):
            result[relative] = hashlib.sha256(read_bytes(project, revision, relative)).hexdigest()
    for relative in FOREIGN_HELPERS:
        if tracked_paths(project, revision, relative):
            result[relative] = hashlib.sha256(read_bytes(project, revision, relative)).hexdigest()
    return result
