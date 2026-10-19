"""rr-20 gait integration, compact provenance and continuation mutations."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'experiments/cutouts/hollow_mimic')]
from case import CASE, ASSETS, DIRECTOR, VIEWS, read_json, write_json, digest
from humanoid_cutout.bone_evidence import read_samples
from humanoid_cutout.walk_gates import report as walk_report
from humanoid_cutout.gates import bindings
from humanoid_cutout.cpu_pose import CpuPose as FullPose
from cpu_proof import CpuPose
from continuations import derivation_errors
import proof_records

FIXTURE_VALUE=5
GAIT_ENDPOINT_ALPHA_MISMATCH_PX=20


class FeedbackTwoTests(unittest.TestCase):
    def test_new_director_import_gait_and_readable_leading_hand(self):
        self.assertEqual((CASE/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        self.assertEqual((ASSETS/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        data=read_json(CASE/'compiled_motion.json')
        self.assertEqual(data['clips']['move']['seconds'],.8)
        self.assertEqual(data['clips']['move']['gait']['steps_per_tile'],6)
        self.assertEqual(data['clips']['move']['gait']['lead'],'near')
        self.assertNotIn('leg_roles',read_json(CASE/'anatomy.json'))
        for view in VIEWS:
            self.assertNotIn('leg_roles',read_json(CASE/f'layouts/{view}.json'))
            production=read_json(ASSETS/(view+'.json'))
            self.assertEqual(production['rest_source_sha256'],digest(ASSETS/production['rest_source']))
            for clip in ('bolt','mirror'):
                tracks=data['view_tracks'][view][clip]
                near=next(t for t in tracks if t['bone']=='hand_near' and t['channel']=='forward_px')
                far=next(t for t in tracks if t['bone']=='hand_far' and t['channel']=='forward_px')
                self.assertGreater(max(k['value'] for k in far['keys']),max(k['value'] for k in near['keys']))

    def test_compact_samples_hashes_and_legacy_full_remain_readable(self):
        with tempfile.TemporaryDirectory(prefix='rr20-record-') as folder:
            case=Path(folder);full={'samples':[{'fixture':FIXTURE_VALUE}]}
            write_json(case/'proof/samples.json',full)
            self.assertEqual(read_samples(case),full)
            evidence=case/'proof/logs/samples.full.json';write_json(evidence,full)
            write_json(case/'proof/samples.json',{'full_evidence':{'file':'logs/samples.full.json','sha256':digest(evidence)}})
            self.assertEqual(read_samples(case),full)
            write_json(evidence,{'samples':[]})
            with self.assertRaisesRegex(ValueError,'evidence changed'):read_samples(case)
            write_json(case/'proof/samples.json',{'full_evidence':{'file':'../outside.json','sha256':''}})
            with self.assertRaises(ValueError):read_samples(case)

    def test_compact_records_keep_extrema_swings_and_failures(self):
        original={'ok':False,'errors':['fixture failure'],'views':{'front':{'knees':{
            'frames':[{'fixture':FIXTURE_VALUE}],'stance':[],'rigid_air':[],'swings':[{'peak_bend_deg':15}],
            'maximum_fit_px':FIXTURE_VALUE,'errors':['fixture failure']}}}}
        compact=proof_records.compact(original)
        knee=compact['views']['front']['knees']
        self.assertNotIn('frames',knee)
        self.assertEqual(knee['sample_counts']['frames'],1)
        self.assertEqual(knee['maximum_fit_px'],FIXTURE_VALUE)
        self.assertEqual(knee['swings'],original['views']['front']['knees']['swings'])
        self.assertEqual(compact['errors'],original['errors'])

    def test_covered_continuations_are_exact_own_edge_copies_and_mutation_fails(self):
        for view in VIEWS:
            layout=read_json(CASE/f'layouts/{view}.json')
            self.assertEqual(derivation_errors(layout),[])
            original=read_json(CASE/'joint_continuations.json')
            mutant=copy.deepcopy(original);mutant[view]={}
            with patch('continuations.read_json',side_effect=lambda path:mutant if Path(path).name=='joint_continuations.json' else read_json(path)):
                if original[view]:self.assertTrue(derivation_errors(layout))

    def test_cpu_mask_pruning_preserves_opaque_reference_fragments(self):
        # Compare pruned proof triangles with the original oracle at a rest
        # pose, before walking can fold distant transparent template triangles.
        samples=proof_records.samples()
        for view in VIEWS:
            layout=read_json(CASE/f'layouts/{view}.json')
            row=next(r for r in samples['samples'] if r['view']==view and r['clip']=='idle' and r['kind']=='presented')
            full,pruned=FullPose(CASE,copy.deepcopy(layout)),CpuPose(CASE,copy.deepcopy(layout))
            for records in ('proof_rest_holes','proof_joint_seams'):
                actual=pruned.masks(row,layout[records],pruned.layers(row)[1])
                expected=full.masks(row,layout[records],full.layers(row)[1])
                for a,b in zip(actual,expected):np.testing.assert_array_equal(a,b)

    def test_gait_candidate_stays_inactive_and_would_change_rest_endpoints(self):
        from humanoid_cutout.gait_continuations import errors
        layout=read_json(CASE/'layouts/rear.json')
        self.assertNotIn('gait_continuations',layout)
        candidate=copy.deepcopy(layout)
        candidate['gait_continuations']=read_json(CASE/'gait_continuations.proposal.json')['rear']
        self.assertEqual(errors(CASE,candidate),[])
        before,after=CpuPose(CASE,layout),CpuPose(CASE,candidate)
        samples=proof_records.samples()
        frames=[r for r in samples['samples'] if r['view']=='rear' and r['clip']=='move' and r['kind']=='presented']
        for row in (frames[0],frames[-1]):
            original=np.logical_or.reduce([image[...,3]>0 for _,image,_ in before.layers(row)[0]])
            proposed=np.logical_or.reduce([image[...,3]>0 for _,image,_ in after.layers(row)[0]])
            self.assertEqual(int((original!=proposed).sum()),GAIT_ENDPOINT_ALPHA_MISMATCH_PX)

    def test_binder_prunes_ignored_native_tree(self):
        import humanoid_cutout.gates as gates
        real_walk=gates.os.walk
        traversed=[]
        def tracked_walk(path):
            for directory,children,files in real_walk(path):
                traversed.append(Path(directory));yield directory,children,files
        with patch.object(gates.os,'walk',tracked_walk):
            result=bindings(CASE)
        self.assertTrue(result)
        self.assertFalse(any('proof' in path.relative_to(CASE).parts for path in traversed))


if __name__=='__main__':unittest.main()
