"""Read-only byte guard for every existing delivery and both protected recipes."""
import json

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
