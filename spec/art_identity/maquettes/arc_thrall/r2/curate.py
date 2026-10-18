"""Keep the native-cell proof sheet and compact receipts within mq-04's budget.

Every removed byte is inventoried before deletion. The accepted baseline's
native captures stay untouched; its superseded multi-figure comparison is
replaced by this unit's required old/new shoulder sheet.
"""
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence, inventory, verify
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from spec.art_identity.maquettes.arc_thrall.r2.proof import FIGURE


def main():
    root = FIGURE / 'r2/proof'
    candidate = compile_recipe(json.loads((FIGURE / 'r2/measurements.json').read_text()))
    capture = root / 'capture'
    validate_delivery(candidate, capture)
    gates = json.loads((root / 'gates.json').read_text())
    if (not gates['passed'] or not all(gates['checks'].values()) or not gates['native_delivery_passed'] or
            not all(value['passed'] for value in gates['after_fit'].values()) or
            not (root / 'shoulder_tube_sheet.png').is_file()):
        raise ValueError('Cannot discard evidence before the required native/pose/IoU proof exists')
    for name in ('build_report.json', 'capture_checks.json', 'facing_report.json',
                 'ownership_validation.json', 'solo_coverage.json', 'capture_manifest.json',
                 'recipe_proof.json', 'exact_native_replay.json', 'joints_px.json'):
        shutil.copyfile(capture / name, root / ('native_' + name))
    directories = [root / name for name in ('native', 'front', 'rear', 'determinism', 'capture')]
    dropped = [path for folder in directories for path in inventory(folder)]
    dropped += [path for path in (root / 'spec_native.json', FIGURE / 'r2/spec_native.json',
                FIGURE / 'delivery/review/clay_comparison_lancer_r3.png') if path.exists()]
    discard_evidence(FIGURE, dropped, FIGURE / 'discarded_proof_sha256.json')
    for folder in directories:
        for path in sorted(folder.rglob('*'), key=lambda p: len(p.parts), reverse=True):
            if path.is_dir() and not any(path.iterdir()):
                path.rmdir()
        if folder.exists() and not any(folder.iterdir()):
            folder.rmdir()
    gates['retention'] = ('Native 1024 cells retained in shoulder_tube_sheet.png; standalone candidate PNGs, '
                          'blends and caches verified then hash-inventoried and discarded for the 6 MB budget. '
                          'Compact native reports are retained with native_ prefixes. Rebuild commands are in r2/README.md.')
    (root / 'gates.json').write_text(json.dumps(gates, indent=2) + '\n')
    manifest = FIGURE / 'COMMIT_MANIFEST.txt'
    manifest.write_text('# Paths relative to this figure. Shared builder: ../blender/*.py\n'
                        '# Accepted mq-04 input: measurements.json; mq-07 candidate: r2/measurements.json.\n' +
                        '\n'.join(str(path.relative_to(FIGURE)) for path in inventory(FIGURE)) + '\n')
    verify(FIGURE)


if __name__ == '__main__':
    main()
