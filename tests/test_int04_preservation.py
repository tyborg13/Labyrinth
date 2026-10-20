"""Committed mutations in disposable histories; no production bytes are edited."""
from copy import deepcopy
import hashlib
import importlib
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
from tests import test_glacial_mirror_shoulder as mirror_specs
from tests import test_mq09_maquettes as batch_specs
from spec.art_identity.maquettes.blender import test_creature as creature_specs
from tests import test_rr24_feedback2 as colours
from tests.test_rr21_cutout import prior_figure_changes
from experiments.cutouts.hollow_mimic.rr20_preservation import protected_changes, BASELINE_COMMIT, UNIT_HEAD
from spec.art_identity.maquettes.hoarfrost_seer.rear_turn import preservation as mq06
from experiments.cutouts.glacial_mirror import rr23_preservation as mirror_scope
from tests.maquette_preservation import (regeneration_hashes, PREFIX, BUILDER, LANCER_INPUT,
    FLOOR_EXCEPTIONS, foreign_maquette_changes, historical_compiler)
from spec.art_identity.maquettes.blender.contract import digest as spec_digest

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
FIXTURE_LANCER_TARGET_OFFSET = 0.01  # Director's live-input mutation.
FIXTURE_HEAD_SCALE_MULTIPLIER = 2  # Director's coordinated recipe/report mutation.
LANCER_REFERENCE = PREFIX+'burrow_grub/delivery/validation/feedback_2/baselines/frostglass_lancer/regeneration.json'
MAQUETTE_CHECKS = (
    ('mq-05', creature_specs, creature_specs.CreatureContractTests.test_batch_a_compiles_to_unchanged_delivery_hashes,
     creature_specs.FIGURES),
    ('mq-07', thrall_specs, thrall_specs.ThrallRevisionTests.test_other_figure_spec_hashes_remain_their_delivered_values,
     thrall_specs.OWNED_FIGURES),
    ('mq-08', mirror_specs, mirror_specs.GlacialMirrorShoulderTests.test_every_other_compiled_recipe_matches_its_unchanged_delivery,
     mirror_specs.OWNED_FIGURES),
    ('mq-09', batch_specs, batch_specs.RecipeTests.test_new_sampling_and_attachment_fields_are_opt_in,
     batch_specs.FIGURES))


class PreservationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='int04-preservation-', dir=ROOT/'tests')
        self.addCleanup(self.temporary.cleanup)
        self.project = Path(self.temporary.name)
        self.initialize_repository()

    def initialize_repository(self):
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

    def copy_maquette_inputs(self, revision):
        paths=[]
        for relative in unit_preservation.tracked_paths(ROOT,revision,PREFIX):
            path=Path(relative)
            if (relative in (LANCER_INPUT,LANCER_REFERENCE) or
                    len(path.parts)==5 and path.name=='measurements.json' or
                    len(path.parts)==6 and relative.endswith('/delivery/build_report.json')):
                paths.append(relative)
        return self.copy_snapshot(revision,paths)

    def assert_maquette_check(self, module, method, baseline, end):
        root=self.project if module is mirror_specs else self.project/PREFIX
        with patch.object(module,'ROOT',root), patch.object(module,'BASELINE_COMMIT',baseline), \
                patch.object(module,'UNIT_HEAD',end):
            method(unittest.TestCase())

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
                 ('measurements.json', 'delivery/build_report.json')]+[LANCER_INPUT]
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
            with patch.object(thrall_specs, 'BASELINE_COMMIT', unit):
                with patch.object(thrall_specs, 'UNIT_HEAD', unit): method(case)
                with patch.object(thrall_specs, 'UNIT_HEAD', mutant):
                    with self.assertRaises(AssertionError): method(case)
        print('INT04 COMPILED SPEC MUTATION: PASS (foreign unit-head recipe change caught)')

    def test_live_lancer_change_cannot_affect_any_historical_maquette_check(self):
        compiler=importlib.import_module('spec.art_identity.maquettes.blender.compile_recipe')
        solids=importlib.import_module('spec.art_identity.maquettes.blender.creature_recipe')
        lancer=unit_preservation.read_json(ROOT,None,LANCER_INPUT)
        lancer['target'][0]+=FIXTURE_LANCER_TARGET_OFFSET
        self.write(LANCER_INPUT,json.dumps(lancer).encode())
        with patch.object(compiler,'PROJECT',self.project), patch.object(solids,'PROJECT',self.project):
            for name in ('hoarfrost_seer','burrow_grub'):
                relative=PREFIX+name
                recipe=unit_preservation.read_json(ROOT,mirror_specs.UNIT_HEAD,relative+'/measurements.json')
                expected=unit_preservation.read_json(ROOT,mirror_specs.UNIT_HEAD,relative+'/delivery/build_report.json')['spec_hash']
                self.assertNotEqual(spec_digest(compiler.compile_recipe(recipe)),expected,name)
            for unit,module,method,_ in MAQUETTE_CHECKS:
                with self.subTest(unit=unit):method(unittest.TestCase())
                print('INT04 LIVE LANCER MUTATION: PASS ('+unit+'; cloth and solids use historical input)')

    def test_coordinated_foreign_recipe_and_report_mutations_are_rejected(self):
        parent=self.project
        recipe_path=PREFIX+'hoarfrost_seer/measurements.json'
        report_path=PREFIX+'hoarfrost_seer/delivery/build_report.json'
        for unit,module,method,_ in MAQUETTE_CHECKS:
            with self.subTest(unit=unit):
                self.project=parent/unit;self.project.mkdir();self.initialize_repository()
                originals=self.copy_maquette_inputs(module.UNIT_HEAD)
                baseline=self.commit_fixture()
                self.assert_maquette_check(module,method,baseline,baseline)
                recipe=json.loads(originals[recipe_path])
                recipe['bone_scales']['head']=[v*FIXTURE_HEAD_SCALE_MULTIPLIER for v in recipe['bone_scales']['head']]
                report=json.loads(originals[report_path])
                with historical_compiler(self.project,baseline) as compile_historical:
                    report['spec_hash']=spec_digest(compile_historical(recipe))
                self.write(recipe_path,json.dumps(recipe).encode())
                self.write(report_path,json.dumps(report).encode())
                mutant=self.commit_fixture()
                with historical_compiler(self.project,mutant) as compile_historical:
                    self.assertEqual(spec_digest(compile_historical(recipe)),report['spec_hash'])
                with self.assertRaisesRegex(AssertionError,'hoarfrost_seer'):
                    self.assert_maquette_check(module,method,baseline,mutant)
                print('INT04 COORDINATED EDIT MUTATION: PASS ('+unit+'; matching spec_hash cannot authorize foreign edits)')

    def test_mq09_foreign_recipe_deletion_is_rejected(self):
        self.copy_maquette_inputs(batch_specs.UNIT_HEAD)
        baseline=self.commit_fixture()
        self.assert_maquette_check(batch_specs,MAQUETTE_CHECKS[-1][2],baseline,baseline)
        relative=PREFIX+'hoarfrost_seer/measurements.json'
        (self.project/relative).unlink()
        mutant=self.commit_fixture()
        self.assertNotIn(relative,unit_preservation.tracked_paths(self.project,mutant,PREFIX))
        with self.assertRaisesRegex(AssertionError,'hoarfrost_seer/measurements.json'):
            self.assert_maquette_check(batch_specs,MAQUETTE_CHECKS[-1][2],baseline,mutant)
        print('INT04 RECIPE DELETION MUTATION: PASS (mq-09; omitted inventory entry is rejected)')

    def test_foreign_maquette_additions_and_shared_floor_entries_are_guarded(self):
        foreign=PREFIX+'hoarfrost_seer/measurements.json'
        original={'figures':{'arc_thrall':['fixture exception'],'hoarfrost_seer':[]}}
        self.write(foreign,FIXTURE_ORIGINAL_BYTES)
        self.write(FLOOR_EXCEPTIONS,json.dumps(original).encode())
        baseline=self.commit_fixture()
        added=PREFIX+'new_foreign_figure/measurements.json'
        self.write(added,FIXTURE_MUTATION_BYTES)
        mutant=self.commit_fixture()
        for unit,_,_,owned in MAQUETTE_CHECKS:
            with self.subTest(unit=unit):
                self.assertEqual(foreign_maquette_changes(self.project,baseline,baseline,owned),[])
                self.assertEqual(foreign_maquette_changes(self.project,baseline,mutant,owned),[added])
        original['figures']['arc_thrall']=[]
        self.write(FLOOR_EXCEPTIONS,json.dumps(original).encode())
        own=self.commit_fixture()
        self.assertEqual(foreign_maquette_changes(self.project,mutant,own,('arc_thrall',)),[])
        original['figures']['hoarfrost_seer']=[FIXTURE_SPEC_ID]
        self.write(FLOOR_EXCEPTIONS,json.dumps(original).encode())
        other=self.commit_fixture()
        self.assertEqual(foreign_maquette_changes(self.project,own,other,('arc_thrall',)),[FLOOR_EXCEPTIONS])
        print('INT04 FOREIGN ADDITION MUTATION: PASS (all four units; only owned floor entries may change)')

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
