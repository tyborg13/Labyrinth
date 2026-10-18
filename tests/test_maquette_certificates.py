"""Promotion must reject stale paint, layouts and gate code before copying."""
import copy
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import CutoutError, read_json, write_json
from maquette_motion import certificates, gates, hidden_material
import maquette_cutout_build

CASE = PROJECT / 'experiments/cutouts/shale_bloomer/mq3'
MUTATION_OUTLINE_RGB = (20, 16, 21)
MUTATION_POSE = ('rear', 'shell', 14)
MUTATION_GATE_HASH = '0' * 64


class CertificateTests(unittest.TestCase):
    def fixture(self, root):
        case = root / 'case'
        shutil.copytree(CASE, case, ignore=shutil.ignore_patterns('*.import', '*.uid'))
        (case / certificates.CERTIFICATE_PATH).unlink(missing_ok=True)
        # Other blocking gates are already exercised against this real case.
        # This fixture isolates persistence/freshness, not their implementations.
        report = {'ok': True, 'errors': [], 'proof_basis': 'prevalidated case-copy fixture'}
        report['certificate'] = certificates.issue(case, report, certificates.bindings(case))
        certificates.save(case, report)
        return case, report

    def test_recoloured_support_rejects_promotion_and_fresh_material_gate(self):
        with tempfile.TemporaryDirectory(prefix='rr05-certificate-test-') as directory:
            root = Path(directory)
            case, _ = self.fixture(root)
            maquette_cutout_build.validate_derived_material(case)
            samples = read_json(case / 'proof/continuity_samples.json')
            view, clip, frame = MUTATION_POSE
            selected = {'samples': [r for r in samples['samples']
                                   if (r['view'], r['clip'], r['frame']) == MUTATION_POSE]}
            self.assertTrue(hidden_material.report(case, selected)['ok'])
            for facing in ('front', 'rear'):
                for part in read_json(case / f'layouts/{facing}.json')['parts']:
                    if part.get('hidden_material'):
                        path = case / part['file']
                        paint = np.array(Image.open(path).convert('RGBA'))
                        paint[paint[..., 3] > 0, :3] = MUTATION_OUTLINE_RGB
                        Image.fromarray(paint).save(path)
            destination = root / 'production'
            with patch.object(maquette_cutout_build, 'case_for', return_value=case), \
                    patch.object(maquette_cutout_build, 'PROJECT', destination):
                with self.assertRaisesRegex(CutoutError, 'Stale pixel-gate certificate'):
                    maquette_cutout_build.promote('shale_bloomer')
            self.assertFalse(destination.exists(), 'No production copy may start after a mismatch')
            fresh = hidden_material.report(case, selected)
            self.assertFalse(fresh['ok'])
            self.assertTrue(any(f'{view}/{clip}/{frame:04d}: exposed derived dark slab' in e for e in fresh['errors']))
            print('MAQUETTE CERTIFICATE MUTATION: stale support rejected before copying; fresh material gate:', fresh['errors'])

    def test_layout_tool_report_and_certificate_changes_all_reject(self):
        with tempfile.TemporaryDirectory(prefix='rr05-certificate-test-') as directory:
            case, report = self.fixture(Path(directory))
            certificates.require_current(case)
            path = case / 'layouts/rear.json'
            original = path.read_bytes()
            layout = read_json(path)
            layout['parts'][0]['z_index'] += 1
            write_json(path, layout)
            with self.assertRaisesRegex(CutoutError, 'Stale pixel-gate certificate'):
                certificates.require_current(case)
            path.write_bytes(original)
            tools = gates.verification_bindings()
            tools['tools/maquette_cutout_polish.py'] = MUTATION_GATE_HASH
            with patch.object(gates, 'verification_bindings', return_value=tools):
                with self.assertRaisesRegex(CutoutError, 'Stale pixel-gate certificate'):
                    certificates.require_current(case)
            changed = copy.deepcopy(report)
            changed['proof_basis'] = 'changed after certification'
            with self.assertRaisesRegex(CutoutError, 'report differs'):
                certificates.save(case, changed)
            changed = copy.deepcopy(report['certificate'])
            changed['ok'] = False
            with self.assertRaisesRegex(CutoutError, 'Invalid saved'):
                certificates.verify(case, changed)
            (case / certificates.CERTIFICATE_PATH).unlink()
            with self.assertRaisesRegex(CutoutError, 'Missing current'):
                certificates.require_current(case)

    def test_inputs_cannot_change_during_gate_then_receive_a_new_binding(self):
        with tempfile.TemporaryDirectory(prefix='rr05-certificate-test-') as directory:
            case, report = self.fixture(Path(directory))
            before = certificates.bindings(case)
            path = case / 'cutout.json'
            config = read_json(path)
            config['debug_certificate_mutation'] = True
            write_json(path, config)
            with self.assertRaisesRegex(CutoutError, 'changed while gates were running'):
                certificates.issue(case, report, before)


if __name__ == '__main__':
    unittest.main()
