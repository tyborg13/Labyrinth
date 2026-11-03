"""Read-only byte guard, with exact successors to the historical inventory."""
import ast
import hashlib
import json
from pathlib import Path

from spec.art_identity.maquettes.blender.compile_recipe import PROJECT
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.contract import todos
from .candidate import ROOT, FIGURES, design_path

HERE = ROOT / 'hollow_mimic/owner_review'
REFERENCES = ('assets/units/protagonist_cutout/front/front_default_gear_rest.png',
              'assets/art/enemies/hollow_mimic.png', 'assets/art/enemies/hollow_mimic_rear.png')
SUCCESSOR_PATH = ROOT / 'gale_herald/r2/validation/mq11_successor.json'
SUCCESSOR_SHA256 = '37db94a2b2aab3f0da23f5ff1d06690cd42ef2f514814e4f5dc914ed1918e3e3'
SUCCESSOR_TREES = ('spec/art_identity/maquettes/gale_herald/delivery/',
                   'spec/art_identity/maquettes/gloam_stalker/delivery/')
GLOAM_BEFORE_PATH = PROJECT / 'tests/mq13_validation/validation/canonical_before_promotion.json'
GLOAM_BEFORE_SHA256 = 'a3db93e913d7b069f786f7520daa33c9f22150375019d1b8d7566c3966601959'
GLOAM_PROMOTED_PATH = PROJECT / 'tests/mq13_validation/validation/promoted_delivery.json'
GLOAM_PROMOTED_SHA256 = '6764593745116482a63132a9e7a752af7df4383ab547e97c6a4cefb2eb73238e'
GLOAM_DELIVERY_TREE = 'spec/art_identity/maquettes/gloam_stalker/delivery/'


def successor_inventory(baseline, baseline_sha256):
    """Replace only two historical trees with their reviewed, immutable pins.

    This is not an exemption for these figures: additions, deletions and edits
    still fail unless they exactly match the hash-bound mq-12 receipt. Keep the
    historical inventory intact, including every unrelated recipe/artwork pin.
    """
    blob = SUCCESSOR_PATH.read_bytes()
    if hashlib.sha256(blob).hexdigest() != SUCCESSOR_SHA256:
        raise ValueError('mq-12 successor receipt hash changed')
    receipt = json.loads(blob)
    if receipt['schema'] != 1 or receipt['unit'] != 'mq-12' or tuple(receipt['delivery_trees']) != SUCCESSOR_TREES:
        raise ValueError('mq-12 successor must authorize exactly the two approved delivery trees')
    if receipt['baseline_sha256'] != baseline_sha256:
        raise ValueError('Historical preservation inventory changed')
    replacements = receipt['files_sha256']
    if (any(not p.startswith(SUCCESSOR_TREES) or '..' in Path(p).parts or Path(p).as_posix() != p
            for p in replacements) or
            any(not any(p.startswith(prefix) for p in replacements) for prefix in SUCCESSOR_TREES)):
        raise ValueError('mq-12 successor contains an unauthorized delivery path')
    expected = {p: value for p, value in baseline['files_sha256'].items() if not p.startswith(SUCCESSOR_TREES)}
    expected.update(replacements)
    return expected, {'unit': 'mq-12', 'receipt_sha256': SUCCESSOR_SHA256,
                      'approved_revision': receipt['approved_revision'], 'files_authorized': len(replacements)}


def bound_gloam_receipt(path, expected_sha256, name):
    blob = path.read_bytes()
    if hashlib.sha256(blob).hexdigest() != expected_sha256:
        raise ValueError('mq-13 ' + name + ' receipt hash changed')
    receipt = json.loads(blob)
    if receipt['passed'] is not True:
        raise ValueError('mq-13 ' + name + ' receipt did not pass')
    return receipt


def relative_delivery_file(path):
    return (bool(path) and not Path(path).is_absolute() and '\\' not in path and
            '..' not in Path(path).parts and Path(path).as_posix() == path)


def gloam_successor_inventory(expected):
    """Advance only Gloam's exact mq-12 delivery to the director-accepted r3.

    Both receipts are immutable. The predecessor must match mq-12's complete
    Gloam subtree before its replacement; no other tree or input is exempted.
    """
    before = bound_gloam_receipt(GLOAM_BEFORE_PATH, GLOAM_BEFORE_SHA256, 'predecessor')
    promoted = bound_gloam_receipt(GLOAM_PROMOTED_PATH, GLOAM_PROMOTED_SHA256, 'promoted')
    previous = before['files_sha256']
    if (set(p for p in previous if not p.startswith('delivery/')) != {'measurements.json'} or
            any(not relative_delivery_file(p) for p in previous)):
        raise ValueError('mq-13 predecessor contains an unauthorized delivery path')
    predecessor = {GLOAM_DELIVERY_TREE + p[len('delivery/'):]: value
                   for p, value in previous.items() if p.startswith('delivery/')}
    if predecessor != {p: value for p, value in expected.items() if p.startswith(GLOAM_DELIVERY_TREE)}:
        raise ValueError('mq-13 predecessor does not match the mq-12 Gloam delivery')
    if promoted['previous_canonical_inventory_sha256'] != GLOAM_BEFORE_SHA256:
        raise ValueError('mq-13 promoted receipt does not bind its predecessor')
    replacements = promoted['files']
    if not replacements or any(not relative_delivery_file(p) for p in replacements):
        raise ValueError('mq-13 successor contains an unauthorized delivery path')
    updated = {p: value for p, value in expected.items() if not p.startswith(GLOAM_DELIVERY_TREE)}
    updated.update({GLOAM_DELIVERY_TREE + p: value for p, value in replacements.items()})
    return updated, {'unit': 'mq-13', 'predecessor_sha256': GLOAM_BEFORE_SHA256,
                     'receipt_sha256': GLOAM_PROMOTED_SHA256, 'files_authorized': len(replacements)}


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
    blob = (HERE / 'baseline.json').read_bytes()
    baseline = json.loads(blob)
    expected, successor = successor_inventory(baseline, hashlib.sha256(blob).hexdigest())
    expected, gloam_successor = gloam_successor_inventory(expected)
    actual = current_inputs()
    changed = sorted(p for p in expected.keys() | actual.keys() if expected.get(p) != actual.get(p))
    if changed:
        raise ValueError('Protected delivery/input changed: ' + '; '.join(changed))
    return {'passed': True, 'files_checked': len(actual), 'before_iou': baseline['before_iou'],
            'other_figure_delivery_bytes_unchanged': True, 'authorized_successor': successor,
            'authorized_gloam_successor': gloam_successor}


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
    # These immutable data receipts are runtime inputs of this guard. Bind them
    # to preparation without changing any other figure's workflow or inventory.
    if Path(__file__).resolve() in found:
        found.update((GLOAM_BEFORE_PATH, GLOAM_PROMOTED_PATH))
    return found
