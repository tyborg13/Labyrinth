"""Independent affine, folded-triangle, limit and evidence regressions."""
import sys
import unittest
import tempfile
from copy import deepcopy
from pathlib import Path
import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from humanoid_cutout.stretch import measure, edge_segments, rigid_measure, report

FIXTURE_SIZE_PX = 2
ROUNDING_PLACES = 5


class StretchTests(unittest.TestCase):
    def setUp(self):
        self.mesh = dict(vertices=[[0,0],[2,0],[0,2],[2,2]], uvs=[[0,0],[2,0],[0,2],[2,2]],
                         triangles=[[0,1,2],[1,3,2]], weights={'root':[1,1,1,1]})
        self.layout = dict(joints={'root':dict(position=[0,0])})
        self.image = np.full((FIXTURE_SIZE_PX,FIXTURE_SIZE_PX,4),255,dtype=np.uint8)

    def measured(self, transform):
        row = dict(clip='fixture',frame=0,phase=0,bones={'root':dict(global_=transform)})
        row['bones']['root']['global'] = row['bones']['root'].pop('global_')
        return measure(self.layout,self.mesh,self.image,[row])

    def test_rigid_translation_rotation_never_stretches(self):
        self.assertAlmostEqual(self.measured([0,1,-1,0,7,13])['maximum_stretch'],0,places=ROUNDING_PLACES)

    def test_exact_director_limit_and_above_limit(self):
        for scale in (1.12,1.1201,1.25):
            self.assertAlmostEqual(self.measured([scale,0,0,1,0,0])['maximum_stretch'],scale-1,places=ROUNDING_PLACES)

    def test_shear_cannot_hide_behind_unit_determinant(self):
        self.assertGreater(self.measured([1,0,1,1,0,0])['maximum_stretch'],.12)

    def test_triangle_boundary_counted_once(self):
        edges, segments = edge_segments(self.mesh,self.image)
        lengths = np.bincount([s[0] for s in segments],weights=[s[4] for s in segments],minlength=len(edges))
        np.testing.assert_allclose(lengths,1)
        self.assertEqual(len(edges),16)

    def test_split_uv_edge_measures_both_physical_sides(self):
        # Only the shared edge stretches 40%; its opposite physical side is rigid.
        # The other edges lengthen less than 2%, so UV deduplication hides failure.
        self.mesh = dict(vertices=[[0,0],[1,0],[0,1],[1,1],[1,0],[2,0],[1,1],[2,1]],
            uvs=[[0,0],[1,0],[0,1],[1,1],[1,0],[2,0],[1,1],[2,1]],
            triangles=[[0,1,2],[1,3,2],[4,5,6],[5,7,6]],
            weights={'root':[1,1,1,1,0,1,0,1], 'up':[0,0,0,0,1,0,0,0], 'down':[0,0,0,0,0,0,1,0]})
        self.layout['joints'].update(up=dict(position=[0,0]), down=dict(position=[0,0]))
        self.image=np.full((1,2,4),255,dtype=np.uint8)
        pose=dict(clip='fixture',frame=0,phase=0,bones={})
        for name, shift in [('root',0),('up',-.2),('down',.2)]:
            pose['bones'][name]={'global':[1,0,0,1,0,shift]}
        self.assertAlmostEqual(measure(self.layout,self.mesh,self.image,[pose])['maximum_stretch'],.4)

    def test_missing_triangle_fails_closed(self):
        self.mesh['triangles'].pop()
        with self.assertRaisesRegex(ValueError,'outside skin topology'): self.measured([1,0,0,1,0,0])

    def test_nonfinite_pose_fails_closed(self):
        with self.assertRaisesRegex(ValueError,'geometry'): self.measured([float('nan'),0,0,1,0,0])

    def test_hidden_only_texel_still_measured(self):
        self.image[:]=0; self.image[0,0]=[45,30,20,255]
        self.assertGreater(self.measured([1.3,0,0,1,0,0])['maximum_stretch'],.12)

    def rigid(self, transform, scale=1.):
        part=dict(name='piece', declared_uniform_scale=scale)
        pose=dict(clip='fixture',frame=0,phase=0,parts={'piece':dict(transform=transform)})
        return rigid_measure(part,[pose])

    def test_declared_uniform_scale_is_not_local_stretch(self):
        self.assertAlmostEqual(self.rigid([0,1.22,-1.22,0,7,13],1.22)['maximum_stretch'],0)
        self.assertGreater(self.rigid([1.22,0,0,1.22,0,0])['maximum_stretch'],.12)

    def test_rigid_shear_and_anisotropy_fail_the_same_limit(self):
        self.assertGreater(self.rigid([1,0,1,1,0,0])['maximum_stretch'],.12)
        self.assertGreater(self.rigid([1.3,0,0,1,0,0])['maximum_stretch'],.12)

    def test_invalid_scale_and_missing_rigid_pose_fail_closed(self):
        with self.assertRaisesRegex(ValueError,'uniform scale'): self.rigid([1,0,0,1,0,0],0)
        with self.assertRaises(KeyError):
            rigid_measure(dict(name='missing'),[dict(clip='fixture',frame=0,phase=0,parts={})])


class StretchReportTests(unittest.TestCase):
    """Complete evidence reaches the public gate, including both rejection paths."""
    setUp = StretchTests.setUp

    def reported(self, kind, relative_scale, declared=1.22):
        scale = relative_scale * declared if type(declared) in (int, float) else 1.
        transform = [scale,0,0,scale,7,13]
        part = dict(name='piece',file='piece.png',declared_uniform_scale=declared)
        layout = dict(self.layout,parts=[part],joint_meshes=[])
        if kind == 'skinned':
            layout['joint_meshes'] = [dict(self.mesh,name='piece',file='piece.png')]
        data = dict(clips={'fixture':dict(seconds=2/60)},view_tracks={'front':{'fixture':[]}})
        bindings = {'compiled_motion.json':'fixture-digest'}
        rows = [dict(view='front',clip='fixture',kind=kind_,frame=frame,phase=phase,
                     bones={'root':{'global':transform}},parts={'piece':dict(transform=transform)})
                for kind_,frame,phase in [('authored',-1,0.),('authored',-1,1.),
                                         ('presented',0,0.),('presented',1,1.)]]
        samples = dict(ok=True,errors=[],inputs=bindings,compiled_sha256='fixture-digest',fps=60,samples=rows)
        with tempfile.TemporaryDirectory(prefix='rr30-stretch-') as folder:
            Image.fromarray(self.image).save(Path(folder)/'piece.png')
            return report(Path(folder),{'front':layout},data,samples,bindings,maximum_stretch=.12)

    def test_report_normalizes_both_piece_types_at_the_boundary(self):
        for kind in ('rigid','skinned'):
            for relative in (1.,1.12):
                with self.subTest(kind=kind,relative=relative):
                    result=self.reported(kind,relative)
                    self.assertTrue(result['ok'],result['errors'])
                    piece=result['pieces']['front/piece']
                    self.assertEqual(piece['declared_uniform_scale'],1.22)
                    self.assertAlmostEqual(piece['maximum_stretch'],relative-1)

    def assert_rejects_strain(self, kind):
        result=self.reported(kind,1.1201)
        self.assertFalse(result['ok'])
        self.assertEqual(len(result['errors']),1,result['errors'])
        self.assertIn('front/piece: 12.010000% exceeds 12.000000%',result['errors'][0])
        self.assertGreater(result['pieces']['front/piece']['maximum_stretch'],.12)

    def test_report_rejects_rigid_strain(self):
        self.assert_rejects_strain('rigid')

    def test_report_rejects_skinned_strain(self):
        self.assert_rejects_strain('skinned')

    def test_report_rejects_invalid_declared_scale_for_both_types(self):
        for kind in ('rigid','skinned'):
            for scale in (0.,-1.,float('nan'),float('inf'),True,'1.22'):
                with self.subTest(kind=kind,scale=scale):
                    result=self.reported(kind,1.,scale)
                    self.assertFalse(result['ok'])
                    self.assertEqual(result['errors'],['front/piece: invalid declared uniform scale',
                                                       'stretch: no painted pieces measured'])


if __name__ == '__main__': unittest.main()
