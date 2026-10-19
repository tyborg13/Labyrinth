"""Bridge proof that an actual bounded solo cannot certify a full delivery."""
import argparse
import json
from pathlib import Path

from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from spec.art_identity.maquettes.glacial_mirror.workflow import FIGURE, job

PROBE_DEFAULTS = {'part': 'upper_far', 'view': 'front'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--regeneration', type=Path, default=FIGURE / 'proof/regeneration/glacial_mirror')
    parser.add_argument('--out', type=Path, default=FIGURE / 'proof/feedback1')
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    spec = args.regeneration / 'spec_native.json'
    output = args.out / 'native_partial'
    job(FIGURE / 'native_proof.py', [spec, args.regeneration / 'build', output,
        PROBE_DEFAULTS['view'], '--solos', PROBE_DEFAULTS['part']], args.out / 'native_partial.json', args.resume)
    manifest = output / 'capture_manifest.json'
    mode = json.loads(manifest.read_text())['mode']
    if mode != 'ownership':
        raise ValueError('Partial capture received incompatible mode: ' + mode)
    try:
        validate_delivery(json.loads(spec.read_text()), output)
    except ValueError as error:
        if 'Incompatible Blender capture mode' not in str(error):
            raise
        write(args.out / 'native_partial_result.json', {'passed': True, 'mode': mode,
            'full_certification_rejected': str(error), 'capture_manifest_sha256': sha(manifest)})
    else:
        raise ValueError('Partial capture received full certification')
    print('NATIVE_PARTIAL_CAPTURE: PASS; mode=ownership; full_certification=rejected')


if __name__ == '__main__':
    main()
