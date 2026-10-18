"""Regenerate from a clean input-only project through the existing bridge.

No generated spec, saved model or cache is copied. The external approved CC0
bundle is the sole binary build dependency. --verify compares canonical clay
PNG SHA-256 values with the curated delivery.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys

from .bridge_client import run_job
from .compile_recipe import PROJECT
from .contract import DEFAULT_BUNDLE
from .curate_delivery import canonical_png, sha, write

REGENERATE_DEFAULTS = {'job_timeout_s': 900}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('figure', type=Path)
    parser.add_argument('--out', required=True, type=Path)
    parser.add_argument('--preview', action='store_true')
    parser.add_argument('--verify', action='store_true')
    parser.add_argument('--discard-build', action='store_true')
    args = parser.parse_args()
    figure, output = args.figure.resolve(), args.out.resolve()
    if output.exists() and any(output.iterdir()):
        raise ValueError('Regeneration requires a new empty output directory')
    output.mkdir(parents=True, exist_ok=True)
    project = output / 'clean_project'
    root = project / 'spec/art_identity/maquettes'
    root.mkdir(parents=True)
    source = PROJECT / 'spec/art_identity/maquettes'
    for path in source.glob('*.py'):
        shutil.copyfile(path, root / path.name)
    (root / 'blender').mkdir()
    for path in (source / 'blender').glob('*.py'):
        shutil.copyfile(path, root / 'blender' / path.name)
    (root / 'frostglass_lancer').mkdir()
    shutil.copyfile(source / 'frostglass_lancer/spec_r3.json', root / 'frostglass_lancer/spec_r3.json')
    clean_figure = root / figure.name
    clean_figure.mkdir()
    shutil.copyfile(figure / 'measurements.json', clean_figure / 'measurements.json')
    inputs = {str(p.relative_to(project)): sha(p) for p in project.rglob('*') if p.is_file()}
    write(output / 'clean_input_sha256.json', inputs)
    # Compile using the copied builder, not an existing generated spec.
    import subprocess
    subprocess.run([sys.executable, '-B', str(root / 'blender/compile_recipe.py'),
                    str(clean_figure / 'measurements.json')], check=True)
    capture = clean_figure / 'capture'
    values = [str(clean_figure / 'spec_native.json'), str(capture)]
    if args.preview:
        values.append('--preview')
    result = run_job(root / 'blender/build.py', values, timeout_s=REGENERATE_DEFAULTS['job_timeout_s'])
    (output / 'bridge.log').write_text(result['stdout'])
    if result['exit']:
        raise ValueError('Clean native build failed: ' + str(result['exit']))
    views = {}
    for view in ('front', 'rear'):
        name = view + '_clay.png'
        canonical_png(capture / name, output / name)
        actual = sha(output / name)
        expected = sha(figure / 'delivery' / name) if args.verify else None
        views[view] = {'sha256': actual, 'expected_sha256': expected,
                       'passed': not args.verify or actual == expected}
    passed = all(r['passed'] for r in views.values())
    write(output / 'regeneration.json', {'passed': passed, 'figure': figure.name, 'views': views,
        'cache_reused': False, 'bundle_sha256': sha(Path(DEFAULT_BUNDLE).expanduser()),
        'input_inventory_sha256': sha(output / 'clean_input_sha256.json')})
    if args.discard_build:
        entries = [[str(p.relative_to(project)), p.stat().st_size, sha(p)]
                   for p in sorted(project.rglob('*')) if p.is_file()]
        write(output / 'discarded_build_sha256.json', {'columns': ['path', 'bytes', 'sha256'], 'files': entries})
        shutil.rmtree(project)
    print('CLEAN_REGENERATION: ' + ('PASS' if passed else 'FAIL') + '; ' + figure.name + '; canonical_png_sha256=true')
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
