"""Focused calibration provenance, maxima, draw order and mutation checks."""
from copy import deepcopy
from pathlib import Path
import sys
import unittest
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/slag_mortar')]
from cutout_pipeline.cases import read_json,digest
from rr31_calibration import (CalibrationGate,APPROVED,METRICS,OUTPUT,CASE,
                              compare_thresholds,distribution,rest_bones,interpolation,affine)
from humanoid_cutout.cpu_pose import CpuPose
from rr31_images import composite

FIXTURE_HEIGHT_PX=200
FIXTURE_CONTACT_POINTS=np.array([[0.,0.],[.25,.25],[1.,1.]])
FIXTURE_THRESHOLD_PER_100PX=2.


class CalibrationTests(unittest.TestCase):
    def test_normalization_and_inclusive_limit_each_metric(self):
        thresholds={'neck':{metric:{'maximum_per_100px':FIXTURE_THRESHOLD_PER_100PX} for metric in METRICS}}
        row={'neck':{metric:4 for metric in METRICS}}
        self.assertEqual(compare_thresholds(row,FIXTURE_HEIGHT_PX,thresholds),[])
        for metric in METRICS:
            changed=deepcopy(row);changed['neck'][metric]+=1
            errors=compare_thresholds(changed,FIXTURE_HEIGHT_PX,thresholds)
            self.assertEqual([e['metric'] for e in errors],[metric])
            self.assertEqual(errors[0]['excess_per_100px'],.5)
            self.assertEqual(errors[0]['excess_native_px'],1.)

    def test_missing_zone_never_silently_passes(self):
        with self.assertRaises(ValueError):compare_thresholds({'neck':{'notches':1}},200,{})

    def test_distribution_keeps_every_observation(self):
        result=distribution([0,1,1,4],FIXTURE_HEIGHT_PX)
        self.assertEqual(result['histogram'],{'0':1,'1':2,'4':1})
        self.assertEqual(result['maximum_per_100px'],2.)
        self.assertEqual(result['samples'],4)

    def test_skin_contact_interpolation_is_affine_and_rejects_unmapped_points(self):
        mesh={'vertices':[[0,0],[1,0],[1,1],[0,1]],'triangles':[[0,1,2],[0,2,3]]}
        indices,weights=interpolation(mesh,FIXTURE_CONTACT_POINTS)
        vertices=np.asarray(mesh['vertices'],dtype=float)
        reconstructed=(vertices[indices]*weights[...,None]).sum(axis=1)
        np.testing.assert_allclose(reconstructed,FIXTURE_CONTACT_POINTS)
        transform=np.array([[0.,-1.,3.],[1.,0.,4.]])
        np.testing.assert_allclose(affine(FIXTURE_CONTACT_POINTS,transform),
            (affine(vertices,transform)[indices]*weights[...,None]).sum(axis=1))
        with self.assertRaises(ValueError):interpolation(mesh,np.array([[2.,2.]]))

    def test_shared_skin_raster_and_recorded_mimic_depth(self):
        creature='hollow_mimic'
        case=PROJECT/read_json(PROJECT/f'assets/units/{creature}_cutout/integration.json')['case']
        layout=read_json(case/'layouts/front.json')
        fixture=read_json(OUTPUT/'proof/calibration_pose.json')
        for path,sha256 in fixture['inputs'].items():
            self.assertEqual(sha256,digest(PROJECT/path))
        pose=fixture['pose']
        gate=CalibrationGate(creature,case,layout)
        actual=gate.layers(pose)
        shared,_=CpuPose(case,layout).layers(pose)
        for part,image,_ in shared:
            if part['name'] in gate.meshes:
                np.testing.assert_array_equal(image,next(r[1] for r in actual if r[0]['name']==part['name']))
        rank={n:i for i,n in enumerate(pose['part_draw_order'])}
        expected=sorted(layout['parts'],key=lambda p:(pose['parts'][p['name']]['z_index'],rank[p['name']]))
        self.assertEqual([p['name'] for p,_,_ in actual],[p['name'] for p in expected])
        depths=[pose['parts'][p['name']]['z_index'] for p,_,_ in actual]
        self.assertEqual(depths,sorted(depths))

    def test_recorded_maxima_and_all_frame_histograms(self):
        report=read_json(OUTPUT/'calibration.json')
        self.assertEqual(set(report['approved']),set(APPROVED))
        for creature,entry in report['approved'].items():
            for view,data in entry['views'].items():
                for zone,metrics in data['zones'].items():
                    for metric,values in metrics.items():
                        self.assertEqual(sum(values['histogram'].values()),data['frames'])
                        self.assertEqual(max(map(int,values['histogram'])),values['maximum'])
                        threshold=report['thresholds'][zone][metric]['maximum_per_100px']
                        self.assertGreaterEqual(threshold,values['maximum']*100/data['height'])
        for zone,metrics in report['thresholds'].items():
            for metric,value in metrics.items():
                maxima=[v['zones'][zone][metric]['maximum_per_100px']
                    for c in report['approved'].values() for v in c['views'].values() if zone in v['zones']]
                self.assertEqual(value['maximum_per_100px'],max(maxima))
                # Lowering a calibrated maximum must reject its approved witness.
                witness=value['witness'];mutated=deepcopy(report['thresholds'])
                mutated[zone][metric]['maximum_per_100px']-=1.
                self.assertTrue(compare_thresholds({zone:{metric:witness['pixels']}},witness['height'],mutated))

    def test_six_native_controls_keep_overlap_without_installing_thresholds(self):
        report=read_json(OUTPUT/'calibration.json')
        controls=report['negative_controls']
        self.assertEqual({(r['view'],r['clip'],r['frame']) for r in controls},
            {(v,c,f) for v in ('front','rear') for c,f in [('lob',32),('brace',20),('death',78)]})
        for row in controls:
            self.assertEqual(compare_thresholds(row['joints'],row['height'],report['thresholds']),row['excess'])
            self.assertEqual(row['rejected'],bool(row['excess']))
        self.assertEqual(report['separated'],all(r['rejected'] for r in controls))
        self.assertFalse(report['thresholds_installed'])
        self.assertEqual(report['implementation']['experiments/cutouts/slag_mortar/rr31_calibration.py'],
            digest(PROJECT/'experiments/cutouts/slag_mortar/rr31_calibration.py'))

    def test_all_eleven_seam_locations_and_source_files_are_bound(self):
        report=read_json(OUTPUT/'seam_observations.json')
        self.assertEqual(report['observations'],11)
        self.assertEqual(report['source_inverse_raster_disagreements'],11)
        for row in report['rows']:
            for failure in row['observations']:
                self.assertEqual(failure['flagged_pixels'],1)
                for trace in failure['traces']:
                    # Feedback 2 repairs those sources. Round-1 attribution
                    # remains bound to the untouched native input inventory.
                    repair=OUTPUT/'feedback2_source_fixes.json'
                    expected=(read_json(repair)['source_hashes_before'][trace['source_file']]
                              if repair.is_file() else digest(CASE/trace['source_file']))
                    self.assertEqual(trace['source_sha256'],expected)
                    self.assertEqual(trace['raster_rgba'][3],0)


if __name__=='__main__':unittest.main()
