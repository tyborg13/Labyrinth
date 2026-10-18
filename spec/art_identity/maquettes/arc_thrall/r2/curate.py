"""Keep the native-cell proof sheet and compact receipts within mq-04's budget.

Every removed byte is inventoried before deletion. The old clays and measured
baseline remain available beside the required old/new shoulder sheet.
"""
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence, inventory, verify, stage
from spec.art_identity.maquettes.arc_thrall.r2.proof import FIGURE
from spec.art_identity.maquettes.arc_thrall.r2.gate_receipt import binding, validate_receipt


def main():
    root = FIGURE / 'r2/proof'
    recipe = json.loads((FIGURE / 'r2/measurements.json').read_text())
    candidate = compile_recipe(recipe)
    capture = root / 'capture'
    gates = validate_receipt(candidate, recipe, capture, root)
    # Promotion is authorized only after both native views pass all gates.
    discard_evidence(FIGURE, inventory(FIGURE / 'delivery'), FIGURE / 'discarded_proof_sha256.json')
    shutil.copyfile(FIGURE / 'r2/measurements.json', FIGURE / 'measurements.json')
    stage(FIGURE, capture, pack_pngs=True)
    for name in ('front_proportion_report.json', 'rear_proportion_report.json'):
        shutil.copyfile(capture / name, FIGURE / 'delivery' / name)
    # stage() verified that packing preserved all measurement pixels. Bind the
    # same accepted measurements to the packed bytes before discarding sources.
    gates['binding'] = binding(candidate, FIGURE / 'delivery', root)
    validate_receipt(candidate, recipe, FIGURE / 'delivery', root, gates)
    directories = [root / name for name in ('native', 'front', 'rear', 'determinism', 'capture')]
    dropped = [path for folder in directories for path in inventory(folder)]
    dropped += [path for path in (root / 'spec_native.json', FIGURE / 'r2/spec_native.json') if path.exists()]
    dropped += [path for path in inventory(root / 'baseline')
                if path.name not in ('front_clay.png', 'rear_clay.png')]
    dropped += [path for path in root.glob('native_*.json')]
    discard_evidence(FIGURE, dropped, FIGURE / 'discarded_proof_sha256.json')
    for folder in directories:
        for path in sorted(folder.rglob('*'), key=lambda p: len(p.parts), reverse=True):
            if path.is_dir() and not any(path.iterdir()):
                path.rmdir()
        if folder.exists() and not any(folder.iterdir()):
            folder.rmdir()
    gates['retention'] = ('Planted r2 is promoted to delivery; native clay RGBA and every visible mask '
                          'pixel/alpha are preserved by the shared lossless packer. Old native clays and immutable '
                          'baseline recipe/registration remain for the 1024 sheet. Temporary blends, caches and '
                          'duplicate captures are hash-inventoried before deletion.')
    (root / 'gates.json').write_text(json.dumps(gates, indent=2) + '\n')
    manifest = FIGURE / 'COMMIT_MANIFEST.txt'
    manifest.write_text('# Paths relative to this figure. Shared builder: ../blender/*.py\n'
                        '# Canonical planted r2 input: measurements.json; mq-04 comparison: r2/baseline_measurements.json.\n' +
                        '\n'.join(str(path.relative_to(FIGURE)) for path in inventory(FIGURE)) + '\n')
    verify(FIGURE)


if __name__ == '__main__':
    main()
