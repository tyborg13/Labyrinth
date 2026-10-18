"""Regenerate from a clean input-only project through the existing bridge.

No generated spec, saved model or cache is copied. The external approved CC0
bundle is the sole binary build dependency. --verify compares canonical clay
and part-map PNG SHA-256 values. Delivered PNG files are never rewritten.
"""
import argparse
import json
from pathlib import Path
import shutil
import sys
import tempfile

from .bridge_client import run_job
from .compile_recipe import PROJECT
from .contract import DEFAULT_BUNDLE
from .curate_delivery import canonical_png, sha, write
from .delivery_validation import seal_delivery, validate_delivery
from .compile_recipe import compile_recipe

REGENERATE_DEFAULTS = {'job_timeout_s': 900}


def compare_captures(capture, delivery, output, verify=True):
    """Canonicalize both sides in temporary storage; retain raw file identity."""
    views = {}
    with tempfile.TemporaryDirectory(prefix='mq04_compare_') as temporary:
        temporary = Path(temporary)
        for view in ('front', 'rear'):
            views[view] = {}
            for kind in ('clay', 'parts'):
                name = view + '_' + kind + '.png'
                source, expected = Path(capture) / name, Path(delivery) / name
                result = {'passed': False}
                views[view][kind] = result
                if not source.is_file() or (verify and not expected.is_file()):
                    result['error'] = 'Missing required capture: ' + name
                    continue
                canonical_png(source, temporary / name, mask=kind == 'parts')
                result['sha256'] = sha(temporary / name)
                result['native_file_sha256'] = sha(source)
                if verify:
                    canonical_png(expected, temporary / ('expected_' + name), mask=kind == 'parts')
                    result['expected_sha256'] = sha(temporary / ('expected_' + name))
                    result['delivery_file_sha256'] = sha(expected)
                result['passed'] = not verify or result['sha256'] == result['expected_sha256']
    return views


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
    views = compare_captures(capture, figure / 'delivery', output, args.verify)
    passed = all(r['passed'] for view in views.values() for r in view.values())
    binding = None
    if args.verify and not args.preview:
        # Fresh capture reports must pass independently and agree with the
        # retained cold/replay proof before they can be sealed or discarded.
        for name in ('recipe_proof.json', 'exact_native_replay.json'):
            shutil.copyfile(figure / 'delivery' / name, capture / name)
        spec = compile_recipe(json.loads((figure / 'measurements.json').read_text()))
        seal_delivery(spec, capture)
        binding = validate_delivery(spec, capture)
    write(output / 'regeneration.json', {'passed': passed, 'figure': figure.name, 'views': views,
        'native_reports': binding, 'bridge_job': {k: result[k] for k in ('id', 'exit', 'seconds')},
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
