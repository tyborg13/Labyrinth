"""Keep cold-build receipts useful without binding later units' validation/data."""
import hashlib
from pathlib import Path

from tools.unit_preservation import read_bytes, tracked_paths

PREFIX = 'spec/art_identity/maquettes/'
BUILDER = PREFIX + 'blender/'
FOREIGN_HELPERS = (PREFIX + 'gust_shrike.py', PREFIX + 'shrike_spec.py')


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
