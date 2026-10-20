"""rr-27 own-piece joint copies, frozen poses, and study evidence integrity."""
from copy import deepcopy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/arc_thrall')]
from rr27_build import CASE, RECIPE, ASSETS, apply_front
from rr27_check import preservation
from rr27_check import committed
from rr27_preservation import REMOVED_COPY_OUTPUTS, copy_removal_is_exact
from rr27_tether_sheets import CANDIDATES, PHASES, compose, axis_crosses
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gait_continuations import active_recipe, errors as continuation_errors, texture
from humanoid_cutout.source_space import pocket_report
from humanoid_cutout.source_space import DetachedSource
from rr27_tether_feedback import channels, CANDIDATES as RAISE_CANDIDATES, STUDY
from rr24_seams import frame_report

POSE_MUTATION_PX = 1  # Debug-only corruption; no animation tuning.


class ThrallStrictProvenanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = read_json(CASE / 'layouts/front.json')
        cls.samples = read_json(CASE / 'proof/samples.json')

    def test_joint_copies_use_own_treated_donors_and_only_the_two_clips(self):
        layout = self.layout
        self.assertEqual(continuation_errors(CASE, layout), [])
        recipe = layout['gait_continuations']['upper_near']
        self.assertEqual(recipe['donor'], 'upper_near')
        self.assertEqual(recipe['clips'], ['jab', 'death'])
        part = next(p for p in layout['parts'] if p['name'] == 'upper_near')
        original = texture(CASE, layout, part)
        for clip in ('rest', 'idle', 'move', 'tether', 'hit'):
            self.assertIsNone(active_recipe(layout, part['name'], clip=clip, gait=clip == 'move'))
            np.testing.assert_array_equal(texture(CASE, layout, part, clip=clip, gait=clip == 'move'), original)
        for clip in recipe['clips']:
            filled = texture(CASE, layout, part, clip=clip)
            for x, y, u, v in recipe['texels']:
                self.assertEqual(original[y, x, 3], 0)
                np.testing.assert_array_equal(filled[y, x], original[v, u])

    def test_removing_joint_copies_reopens_both_reported_tears(self):
        original = deepcopy(self.layout)
        del original['gait_continuations']['upper_near']
        for clip, frame, box in [('jab', 22, [282,248,283,250]), ('death', 31, [280,252,282,256])]:
            pose = next(p for p in self.samples['samples'] if p['kind'] == 'presented' and
                        (p['view'], p['clip'], p['frame']) == ('front', clip, frame))
            for layout, expected in ((original, True), (deepcopy(self.layout), False)):
                layers, _, _, _, independent = frame_report(CpuPose(CASE, layout), pose)
                failures = pocket_report(layers, independent['failures'])['failures']
                self.assertEqual(any(row['bbox'] == box for row in failures), expected)

    def test_replay_is_idempotent_and_production_recipes_match(self):
        self.assertEqual(apply_front(deepcopy(self.layout)), self.layout)
        for path in (ASSETS / 'front.json', ASSETS / 'humanoid_v2/front.json'):
            self.assertEqual(read_json(path)['gait_continuations'], self.layout['gait_continuations'])

    def test_raw_pose_rows_paint_rests_and_motion_are_exact(self):
        self.assertTrue(preservation(self.samples)['ok'])

    def test_directed_copy_outputs_remove_only_the_declared_texel(self):
        for relative in REMOVED_COPY_OUTPUTS:
            self.assertTrue(copy_removal_is_exact(relative,committed(relative)),relative)

    def test_restoring_each_removed_copy_reopens_its_detached_component(self):
        from io import BytesIO
        from PIL import Image
        layout=read_json(CASE/'layouts/rear.json')
        original=json.loads(committed('experiments/cutouts/arc_thrall/rr11/layouts/rear.json'))
        for frame,name in [(14,'mq7b_continuation_leg_far'),(23,'mq7b_continuation_leg_near')]:
            pose=next(p for p in self.samples['samples'] if p['kind']=='presented' and
                      (p['view'],p['clip'],p['frame'])==('rear','move',frame))
            transforms={k:p['transform'] for k,p in pose['parts'].items()}
            source=DetachedSource(CASE,layout)
            self.assertEqual(source.report(CpuPose(CASE,deepcopy(layout)).layers(pose)[0],transforms)['unmatched_components'],[])
            trial=deepcopy(layout)
            overrides=None
            if frame==14:
                part=next(p for p in trial['parts'] if p['name']==name)
                overrides={p['name']:texture(CASE,trial,p,gait=True,clip='move') for p in trial['parts']}
                raw=committed(str((CASE/part['file']).relative_to(ROOT)))
                overrides[name]=np.asarray(Image.open(BytesIO(raw)).convert('RGBA'))
            else:
                trial['gait_continuations'][name]=deepcopy(original['gait_continuations'][name])
            report=source.report(CpuPose(CASE,trial).layers(pose,overrides)[0],transforms)
            self.assertEqual(len(report['unmatched_components']),1)

    def test_feedback_candidates_use_only_the_directors_prescribed_channels(self):
        approved=read_json(CASE/'compiled_motion.json')
        for name,pair in RAISE_CANDIDATES.items():
            author=read_json(STUDY/(name+'_author.json'))
            self.assertEqual(author['arc_thrall']['clips']['tether']['view_keys']['rear'],channels(pair))
            compiled=read_json(STUDY/(name+'_compiled.json'))
            self.assertEqual(compiled['view_tracks']['front'],approved['view_tracks']['front'])
            for clip,tracks in approved['view_tracks']['rear'].items():
                actual=compiled['view_tracks']['rear'][clip]
                if clip=='tether':
                    names={'tube_tip.forward_px','tube_tip.lift_px'}
                    self.assertEqual([t for t in actual if t['source'] not in names],
                                     [t for t in tracks if t['source'] not in names])
                else:self.assertEqual(actual,tracks)

    def test_feedback_gate_rejects_changed_candidate_motion_before_rendering(self):
        import rr27_tether_feedback as feedback
        # The three-pair rejection is archived after director feedback 2.
        # Exercise its integrity guard using that capture's own input epoch.
        request=read_json(STUDY/'request.json')
        original_digest=feedback.digest
        def changed_digest(path):
            if Path(path)==feedback.DIRECTOR:return request['director_sha256']
            return '0'*64 if Path(path).name=='F10_L110_compiled.json' else original_digest(path)
        with patch.object(feedback,'digest',side_effect=changed_digest), \
                patch.object(feedback,'bindings',return_value=request['inputs']):
            with self.assertRaisesRegex(ValueError,'candidate motion changed'):
                feedback.evaluate()

    def test_feedback2_motion_and_pose_pin_are_exactly_scoped(self):
        from rr27_tether_identity import scope_errors,pose_report,PIN
        self.assertEqual(scope_errors(),[])
        report=pose_report((CASE/'proof/samples.json').read_text())
        self.assertTrue(report['ok'],report['errors'])
        for group in report['inventories'].values():
            self.assertTrue(group['unchanged_scope_byte_identical'])
        for row in report['changed_pose_rows']+report['added_pose_rows']:
            self.assertEqual((row['view'],row['clip']),('rear','tether'))
        self.assertEqual(read_json(PIN)['channels'],{
            'tube_tip.forward_px':[[0,0],[.2,0],[.35,65],[.8,65],[.9,0],[1,0]],
            'tube_tip.lift_px':[[0,0],[.2,90],[.35,153],[.8,153],[.9,90],[1,0]]})

    def test_pose_pin_rejects_an_unapproved_front_or_rear_tether_row(self):
        from rr27_tether_identity import pose_report
        from rr27_check import raw_rows
        source=(CASE/'proof/samples.json').read_text()
        rows=raw_rows(source,'samples')
        for view,clip,expected in [('front','idle','outside rear/tether'),
                                   ('rear','tether','rear Tether raw pose rows differ')]:
            raw=next(r for r in rows if (lambda p:p['view']==view and p['clip']==clip and
                                        p['kind']=='presented' and p['frame']==1)(json.loads(r)))
            mutant=json.loads(raw)
            mutant['bones']['root']['global'][4]+=POSE_MUTATION_PX
            report=pose_report(source.replace(raw,json.dumps(mutant,separators=(',',':')),1))
            self.assertFalse(report['ok'])
            self.assertTrue(any(expected in error for error in report['errors']),report['errors'])

    def test_study_has_exact_candidates_and_all_six_phases_without_data_edits(self):
        report = read_json(RECIPE / 'tether_study/cpu/samples.json')
        self.assertTrue(report['ok'])
        self.assertFalse(report['native_pixels'])
        self.assertEqual(report['candidates'], CANDIDATES)
        self.assertEqual(report['phases'], PHASES)
        self.assertEqual(len(report['samples']), len(CANDIDATES) * len(PHASES))
        manifest = read_json(RECIPE / 'tether_study/cpu/manifest.json')
        self.assertEqual(len(manifest['files']), 6)
        self.assertEqual(len([r for r in manifest['rows'] if r['phase'] == .5]), 5)
        self.assertEqual(manifest['zoom'], 3)

    def test_native_composer_rejects_cpu_evidence_and_stale_input(self):
        with self.assertRaisesRegex(ValueError, 'Fresh, complete study evidence'):
            compose(RECIPE / 'tether_study/cpu')
        with tempfile.TemporaryDirectory(prefix='rr27-study-') as folder:
            report = read_json(RECIPE / 'tether_study/cpu/samples.json')
            report['inputs'] = {}
            write_json(Path(folder) / 'samples.json', report)
            with self.assertRaisesRegex(ValueError, 'Fresh, complete study evidence'):
                compose(Path(folder), cpu=True)

    def test_axis_crossing_distinguishes_socket_contact_from_interior(self):
        mask = np.zeros((32, 32), dtype=bool)
        mask[8:24, 8:24] = True
        self.assertTrue(axis_crosses(mask, np.array([0,16]), np.array([31,16])))
        self.assertFalse(axis_crosses(mask, np.array([0,0]), np.array([31,0])))


if __name__ == '__main__':
    unittest.main(verbosity=2)
