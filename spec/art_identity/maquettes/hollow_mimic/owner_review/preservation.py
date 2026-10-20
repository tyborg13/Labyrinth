"""Read-only byte guard for every existing delivery and both protected recipes."""
import ast
import json
from pathlib import Path

from spec.art_identity.maquettes.blender.compile_recipe import PROJECT
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.contract import todos
from .candidate import ROOT, FIGURES, design_path

HERE = ROOT / 'hollow_mimic/owner_review'
REFERENCES = ('assets/units/protagonist_cutout/front/front_default_gear_rest.png',
              'assets/art/enemies/hollow_mimic.png', 'assets/art/enemies/hollow_mimic_rear.png')


def current_inputs():
    paths = [p for f in ROOT.iterdir() if f.is_dir() for p in (f / 'delivery').rglob('*') if p.is_file()]
    paths += [ROOT / name / 'measurements.json' for name in FIGURES]
    paths += [PROJECT / name for name in REFERENCES]
    for name in FIGURES:
        recipe = json.loads((ROOT / name / 'measurements.json').read_text())
        paths += [PROJECT / path for path in recipe['sources'].values()]
    return {str(p.relative_to(PROJECT)): sha(p) for p in sorted(set(paths))}


def snapshot():
    path = HERE / 'baseline.json'
    if path.exists():
        raise ValueError('Baseline already exists; it is immutable')
    write(path, {'schema': 1, 'files_sha256': current_inputs(), 'before_iou': {
        name: {v: row['iou'] for v, row in json.loads((ROOT / name / 'delivery/fit_report.json').read_text())['views'].items()}
        for name in FIGURES}})


def check():
    baseline = json.loads((HERE / 'baseline.json').read_text())
    expected, actual = baseline['files_sha256'], current_inputs()
    changed = sorted(p for p in expected.keys() | actual.keys() if expected.get(p) != actual.get(p))
    if changed:
        raise ValueError('Protected delivery/input changed: ' + '; '.join(changed))
    return {'passed': True, 'files_checked': len(actual), 'before_iou': baseline['before_iou'],
            'other_figure_delivery_bytes_unchanged': True}


def status():
    result = check()
    result['preservation_passed'] = result.pop('passed')
    result['design_todos'] = {name: todos(json.loads(design_path(name).read_text())['design']) for name in FIGURES}
    result['ready_for_native_proof'] = not any(result['design_todos'].values())
    result['native_acceptance_passed'] = None
    result['native_proof'] = 'pending director bridge run'
    result['after_iou'] = {name: None for name in FIGURES}
    return result


def source_dependencies(project, entry_points):
    """Include local imports in every branch, submodules and package initializers.

    Callers seed separately executed scripts and dynamically selected module
    families too; resolving source paths never requires bpy or host image tools.
    """
    project = Path(project).resolve()
    pending = {Path(p).resolve() for p in entry_points}
    found = set()

    def enqueue(name):
        parts = name.split('.')
        for count in range(1, len(parts) + 1):
            package = project.joinpath(*parts[:count]) / '__init__.py'
            if package.is_file():
                pending.add(package)
        module = project.joinpath(*parts).with_suffix('.py')
        if module.is_file():
            pending.add(module)

    while pending:
        path = pending.pop()
        if path in found:
            continue
        relative = path.relative_to(project)
        found.add(path)
        package = relative.parent.parts
        for node in ast.walk(ast.parse(path.read_text(), filename=str(path))):
            if isinstance(node, ast.Import):
                for alias in node.names:
                    enqueue(alias.name)
            elif isinstance(node, ast.ImportFrom):
                prefix = package[:len(package) - node.level + 1] if node.level else ()
                name = '.'.join((*prefix, *node.module.split('.'))) if node.module else '.'.join(prefix)
                if name:
                    enqueue(name)
                    for alias in node.names:
                        if alias.name != '*':
                            enqueue(name + '.' + alias.name)
            elif isinstance(node, ast.Call) and node.args and isinstance(node.args[0], ast.Constant):
                # Also cover literal dynamic imports. Nonliteral native module
                # dispatch is covered by the caller's family seeds.
                function = node.func.id if isinstance(node.func, ast.Name) else getattr(node.func, 'attr', '')
                if function in ('__import__', 'import_module') and isinstance(node.args[0].value, str):
                    name = node.args[0].value
                    if not name.startswith('.'):
                        enqueue(name)
    return found
