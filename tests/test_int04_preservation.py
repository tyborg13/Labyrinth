"""Committed mutations in disposable histories; no production bytes are edited."""
from copy import deepcopy
import hashlib
from io import BytesIO
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

from tools import unit_preservation
from tests import test_arc_thrall_maquette_r2 as thrall_specs
from tests import test_rr24_feedback2 as colours
from tests.test_rr21_cutout import prior_figure_changes
from experiments.cutouts.hollow_mimic.rr20_preservation import protected_changes, BASELINE_COMMIT, UNIT_HEAD
from spec.art_identity.maquettes.hoarfrost_seer.rear_turn import preservation as mq06
from experiments.cutouts.glacial_mirror import rr23_preservation as mirror_scope
from tests.maquette_preservation import regeneration_hashes, PREFIX, BUILDER

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_FOREIGN_PATH = 'assets/units/arc_thrall_cutout/front.json'
FIXTURE_OWN_PATH = 'assets/units/hollow_mimic_cutout/front.json'
FIXTURE_ORIGINAL_BYTES = b'approved fixture\n'
FIXTURE_BASELINE_BYTES = b'pre-unit fixture\n'
FIXTURE_MUTATION_BYTES = b'foreign mutation inside unit range\n'
FIXTURE_SPEC_ID = 'int04_foreign_spec_mutation'
FIXTURE_OFFSET_PX = 1
FIXTURE_ALPHA_XOR = 1
FIXTURE_EMPTY_REGISTRY = {'entries': []}
FIXTURE_FOREIGN_REGISTRY = {'entries': [{'id': FIXTURE_SPEC_ID}]}


class PreservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='int04-preservation-', dir=ROOT/'tests')
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        self.git('init', '-q')
        self.git('config', 'user.name', 'Preservation fixture')
        self.git('config', 'user.email', 'fixture@example.invalid')
        self.git('config', 'commit.gpgsign', 'false')

    def git(self, *args):
        return subprocess.check_output(['git', *args], cwd=self.project).decode().strip()

    def write(self, relative, blob):
        path = self.project/relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(blob)

    def commit_fixture(self):
        # Only this disposable repository, never the implementation worktree.
        self.git('add', '.')
        self.git('commit', '-qm', 'preservation fixture')
        return self.git('rev-parse', 'HEAD')

    def copy_snapshot(self, revision, paths):
        archive = subprocess.check_output(['git', 'archive', revision, '--', *paths], cwd=ROOT)
        originals = {}
        with tarfile.open(fileobj=BytesIO(archive)) as tar:
            for member in tar:
                if member.isfile():
                    originals[member.name] = tar.extractfile(member).read()
                    self.write(member.name, originals[member.name])
        return originals

    def test_pinned_ranges_reject_foreign_edits_and_ignore_later_units(self):
        self.write(FIXTURE_FOREIGN_PATH, FIXTURE_ORIGINAL_BYTES)
        base = self.commit_fixture()
        self.write(FIXTURE_OWN_PATH, FIXTURE_ORIGINAL_BYTES)
        unit = self.commit_fixture()
        self.write(FIXTURE_FOREIGN_PATH, FIXTURE_MUTATION_BYTES)
        mutant = self.commit_fixture()
        # Even a clean today's tree can contain the regression in the unit range.
        self.assertEqual(self.git('diff', '--name-only'), '')
        for check in (protected_changes, prior_figure_changes):
            self.assertEqual(check(self.project, base, unit), [])
            self.assertEqual(check(self.project, base, mutant), [FIXTURE_FOREIGN_PATH])
        # Later working edits also cannot change the meaning of either range.
        self.write(FIXTURE_FOREIGN_PATH, FIXTURE_ORIGINAL_BYTES)
        self.assertEqual(protected_changes(self.project, base, unit), [])
        self.assertEqual(protected_changes(self.project, base, mutant), [FIXTURE_FOREIGN_PATH])
        self.assertEqual(unit_preservation.changed_paths(self.project, unit, unit), [])
        print('INT04 RANGE MUTATION: PASS (committed foreign edit caught; later commits/working edits ignored)')

    def test_hash_table_reads_foreign_unit_snapshot_and_keeps_own_live_pin(self):
        foreign = 'spec/art_identity/maquettes/arc_thrall/measurements.json'
        own = 'spec/art_identity/maquettes/hoarfrost_seer/measurements.json'
        pins = {p: hashlib.sha256(FIXTURE_ORIGINAL_BYTES).hexdigest() for p in (foreign, own)}
        for p in pins: self.write(p, FIXTURE_ORIGINAL_BYTES)
        unit = self.commit_fixture()
        self.write(foreign, FIXTURE_MUTATION_BYTES)
        mutant = self.commit_fixture()
        self.write(foreign, FIXTURE_ORIGINAL_BYTES)
        self.assertEqual(mq06.protected_hash_changes(self.project, pins, unit), [])
        self.assertEqual(mq06.protected_hash_changes(self.project, pins, mutant), [foreign])
        self.write(own, FIXTURE_MUTATION_BYTES)
        self.assertEqual(mq06.protected_hash_changes(self.project, pins, unit), [own])
        print('INT04 HASH TABLE MUTATION: PASS (foreign historical bytes and own live bytes enforced)')

    def test_exact_hash_exception_uses_unit_head_even_after_later_edits(self):
        foreign='spec/peer_benchmark/staged/rr-11/motion_tracks.json'
        self.write(foreign,FIXTURE_BASELINE_BYTES)
        base=self.commit_fixture()
        self.write(foreign,FIXTURE_ORIGINAL_BYTES)
        unit=self.commit_fixture()
        approved={foreign:hashlib.sha256(FIXTURE_ORIGINAL_BYTES).hexdigest()}
        self.write(foreign,FIXTURE_MUTATION_BYTES)
        mutant=self.commit_fixture()
        self.assertEqual(mirror_scope.protected_changes(self.project,base,approved,end=unit),[])
        self.assertEqual(mirror_scope.protected_changes(self.project,base,approved,end=mutant),[foreign])
        self.assertEqual(mirror_scope.protected_changes(self.project,base,approved),[foreign])
        self.write(foreign,FIXTURE_ORIGINAL_BYTES)
        self.assertEqual(mirror_scope.protected_changes(self.project,base,approved,end=mutant),[foreign])
        print('INT04 EXACT HASH MUTATION: PASS (allowlisted path still requires the pinned endpoint bytes)')

    def test_rr24_keeps_exact_own_live_bytes_and_historical_foreign_records(self):
        from rr24_preservation import preservation_errors, SHARED_RECORDS
        own='spec/art_identity/jobs/arc_thrall/fixture.txt'
        foreign=FIXTURE_OWN_PATH  # Mimic is foreign to the Thrall unit.
        for relative in SHARED_RECORDS:
            data={} if relative.endswith('outputs.json') else FIXTURE_EMPTY_REGISTRY
            self.write(relative,json.dumps(data).encode())
        for name in (own,foreign): self.write(name,FIXTURE_ORIGINAL_BYTES)
        base=self.commit_fixture()
        self.write('assets/units/arc_thrall_cutout/fixture.txt',FIXTURE_ORIGINAL_BYTES)
        unit=self.commit_fixture()
        self.write(foreign,FIXTURE_MUTATION_BYTES)
        mutant=self.commit_fixture()
        self.assertEqual(preservation_errors(self.project,base,unit),[])
        self.assertIn('Protected figures/paint/motion differ: '+foreign,
                      preservation_errors(self.project,base,mutant))
        registry=SHARED_RECORDS[0]
        self.write(registry,json.dumps(FIXTURE_FOREIGN_REGISTRY).encode())
        registry_mutant=self.commit_fixture()
        self.write(registry,json.dumps(FIXTURE_EMPTY_REGISTRY).encode())
        self.assertIn('Unrelated registry record changed: '+registry,
                      preservation_errors(self.project,base,registry_mutant))
        self.write(own,FIXTURE_MUTATION_BYTES)
        self.assertIn('Protected Thrall input changed: '+own,preservation_errors(self.project,base,unit))
        print('INT04 REGISTRY MUTATION: PASS (foreign historical entry caught; own live inputs pinned)')

    def test_compiled_foreign_spec_mutation_at_unit_head_is_rejected(self):
        paths = [f'spec/art_identity/maquettes/{name}/{file}' for name in
                 ('hoarfrost_seer', 'gale_herald', 'gloam_stalker') for file in
                 ('measurements.json', 'delivery/build_report.json')]
        originals = self.copy_snapshot(thrall_specs.UNIT_HEAD, paths)
        unit = self.commit_fixture()
        path = paths[0]
        recipe = json.loads(originals[path]); recipe['id'] = FIXTURE_SPEC_ID
        self.write(path, json.dumps(recipe).encode())
        mutant = self.commit_fixture()
        self.write(path, originals[path])
        method = thrall_specs.ThrallRevisionTests.test_other_figure_spec_hashes_remain_their_delivered_values
        # Call the original assertion, including its subtests, on a separate
        # TestCase so an expected failure cannot be swallowed by subTest.
        case = thrall_specs.ThrallRevisionTests()
        with patch.object(thrall_specs, 'ROOT', self.project/'spec/art_identity/maquettes'):
            with patch.object(thrall_specs, 'UNIT_HEAD', unit): method(case)
            with patch.object(thrall_specs, 'UNIT_HEAD', mutant):
                with self.assertRaises(AssertionError): method(case)
        print('INT04 COMPILED SPEC MUTATION: PASS (foreign unit-head recipe change caught)')

    def test_colour_snapshot_rejects_geometry_targets_and_alpha_mutations(self):
        paths = []
        for view in ('front', 'rear'):
            relative = str((colours.CASE/f'layouts/{view}.json').relative_to(ROOT))
            paths.append(relative)
            layout = unit_preservation.read_json(ROOT, colours.UNIT_HEAD, relative)
            paths += [str((colours.CASE/p['file']).relative_to(ROOT)) for p in layout['parts']]
        originals = self.copy_snapshot(colours.UNIT_HEAD, sorted(set(paths)))
        unit = self.commit_fixture()
        colours.assert_colour_rebuild_preserved(self, unit, self.project)
        relative = paths[0]
        original = json.loads(originals[relative])
        geometry = deepcopy(original)
        geometry['parts'][0]['offset'][0] += FIXTURE_OFFSET_PX
        targets = deepcopy(original)
        next(iter(targets['gait_continuations'].values()))['texels'][0][0] += FIXTURE_OFFSET_PX
        image_path = str((colours.CASE/original['parts'][0]['file']).relative_to(ROOT))
        image = np.array(Image.open(BytesIO(originals[image_path])).convert('RGBA'))
        image[0, 0, 3] ^= FIXTURE_ALPHA_XOR
        buffer = BytesIO(); Image.fromarray(image).save(buffer, format='PNG')
        for label, path, blob in (
                ('geometry', relative, json.dumps(geometry).encode()),
                ('targets', relative, json.dumps(targets).encode()),
                ('alpha', image_path, buffer.getvalue())):
            with self.subTest(label=label):
                for name, data in originals.items(): self.write(name, data)
                self.write(path, blob)
                mutant = self.commit_fixture()
                self.write(path, originals[path])
                with self.assertRaises(AssertionError):
                    colours.assert_colour_rebuild_preserved(self, mutant, self.project)
        print('INT04 COLOUR MUTATIONS: PASS (unit-head geometry, gait targets and alpha caught)')

    def test_original_history_and_retired_coverage_are_enforced(self):
        self.assertEqual(protected_changes(ROOT, BASELINE_COMMIT, UNIT_HEAD), [])
        self.assertEqual(prior_figure_changes(), [])
        ledger=ROOT/'experiments/cutouts/hollow_mimic/rr20/rr26_source_coverage.json'
        original=ledger.read_bytes()
        result=subprocess.run([sys.executable,'experiments/cutouts/hollow_mimic/rr26_refresh.py','coverage'],
                              cwd=ROOT,capture_output=True,text=True)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RR26 COVERAGE RETIRED: PASS',result.stdout)
        self.assertEqual(ledger.read_bytes(),original)
        pins = json.loads((ROOT/'spec/art_identity/maquettes/hoarfrost_seer/rear_turn/protected_sha256.json').read_text())
        foreign = {p: v for p, v in pins.items() if mq06.other_figure(p)}
        self.assertEqual(mq06.protected_hash_changes(ROOT, foreign), [])

    def test_regeneration_receipts_keep_native_and_own_recipe_guards(self):
        native=BUILDER+'build.py'
        validation=BUILDER+'test_fixture.py'
        own=PREFIX+'hollow_mimic/measurements.json'
        foreign=PREFIX+'frostglass_lancer/spec_r3.json'
        sources={name:self.project/name for name in (native,validation,own,foreign)}
        for name in sources:self.write(name,FIXTURE_ORIGINAL_BYTES)
        unit=self.commit_fixture()
        expected={name:hashlib.sha256(FIXTURE_ORIGINAL_BYTES).hexdigest() for name in sources}
        def hashes(end=unit,live=True):
            return regeneration_hashes(self.project,end,'hollow_mimic',sources,own_recipe=live)
        self.assertEqual(hashes(),expected)
        for name in (validation,foreign):self.write(name,FIXTURE_MUTATION_BYTES)
        self.assertEqual(hashes(),expected)
        self.write(native,FIXTURE_MUTATION_BYTES)
        self.assertNotEqual(hashes()[native],expected[native])
        self.write(own,FIXTURE_MUTATION_BYTES)
        self.assertNotEqual(hashes()[own],expected[own])
        added=BUILDER+'new_native.py'
        self.write(added,FIXTURE_ORIGINAL_BYTES);sources[added]=self.project/added
        self.assertIn(added,hashes())
        del sources[added];(self.project/added).unlink()
        for name in sources:self.write(name,FIXTURE_ORIGINAL_BYTES)
        self.write(own,FIXTURE_MUTATION_BYTES)
        mutant=self.commit_fixture()
        self.write(own,FIXTURE_ORIGINAL_BYTES)
        self.assertEqual(hashes(unit,False),expected)
        self.assertNotEqual(hashes(mutant,False)[own],expected[own])
        print('INT04 REGENERATION MUTATIONS: PASS (foreign historical recipe caught; native/own inputs and new modules still guarded)')


if __name__ == '__main__': unittest.main(verbosity=2)
