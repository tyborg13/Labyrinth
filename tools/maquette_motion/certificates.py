"""Saved gate results are valid only for the exact case and gate implementation.

Native capture bindings distinguish rendering from the oracle used to inspect
it. Certificates are stricter: even an oracle-only edit requires a fresh gate.
Writing a certificate never rewrites art, layouts or native capture evidence.
"""
import hashlib
import json
from pathlib import Path
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_motion import gates

CERTIFICATE_PATH = 'proof/pixel_gate_certificate.json'
SCHEMA_VERSION = 1
CASE_PROOFS = ('proof/continuity.json', 'proof/continuity_samples.json', 'proof/feature_derivation.json',
               'recipes/rig.json')


def checksum(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def bindings(case):
    inputs = gates.input_bindings(case)
    paths = set(CASE_PROOFS)
    if (case / 'cutout.json').exists():
        paths.update(read_json(case / 'cutout.json').get('sources', []))
    index = case / 'hidden_fills/index.json'
    if index.exists():
        for request in read_json(index).get('requests', []):
            paths.add(request['preview'])
            paths.add(f'registered/{request["view"]}_hidden_{request["part"]}.npy')
    paths.discard(CERTIFICATE_PATH)
    for path in paths:
        if (case / path).exists():
            inputs[path] = digest(case / path)
    return {'case_inputs': inputs, 'gate_tools': gates.verification_bindings()}


def issue(case, report, tested_bindings=None):
    """Seal a freshly computed report; callers cannot refresh a saved result."""
    result = {k: v for k, v in report.items() if k != 'certificate'}
    current = bindings(case)
    if tested_bindings is not None and tested_bindings != current:
        raise CutoutError('Case inputs or gate tools changed while gates were running')
    certificate = {'schema_version': SCHEMA_VERSION, 'ok': bool(result['ok']),
                   'errors': result.get('errors', []), 'bindings': current,
                   'gate_report_sha256': checksum(result)}
    return dict(certificate, certificate_sha256=checksum(certificate))


def verify(case, certificate, report=None):
    if not isinstance(certificate, dict):
        raise CutoutError('Invalid saved pixel-gate certificate')
    payload = {k: v for k, v in certificate.items() if k != 'certificate_sha256'}
    if (certificate.get('schema_version') != SCHEMA_VERSION
            or certificate.get('certificate_sha256') != checksum(payload)):
        raise CutoutError('Invalid saved pixel-gate certificate')
    if certificate.get('bindings') != bindings(case):
        raise CutoutError('Stale pixel-gate certificate: current case inputs or gate tools differ; run fresh gates')
    if report is not None and certificate.get('gate_report_sha256') != checksum(
            {k: v for k, v in report.items() if k != 'certificate'}):
        raise CutoutError('Saved pixel-gate report differs from its certificate')
    if not certificate.get('ok') or certificate.get('errors'):
        raise CutoutError('Saved pixel-gate certificate did not pass')


def save(case, report):
    certificate = report.get('certificate', {})
    verify(case, certificate, report)
    write_json(case / CERTIFICATE_PATH, certificate)


def require_current(case):
    path = case / CERTIFICATE_PATH
    if not path.is_file():
        raise CutoutError('Missing current pixel-gate certificate; run fresh gates before promotion')
    try:
        verify(case, read_json(path))
    except (OSError, KeyError, ValueError) as error:
        raise CutoutError('Invalid saved pixel-gate certificate: ' + str(error)) from error
