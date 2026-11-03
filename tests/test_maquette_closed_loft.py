"""Opt-in closed forms: topology, cap shading and input validation."""
from collections import Counter
from copy import deepcopy
import unittest
from spec.art_identity.maquettes.blender.closed_loft import loft, sheet, sweep

FIXTURE = {'samples':8,'sections':[[0,0,0,1,1],[0,0,1,.9,.9]]}
SHEET = {'rows':[[[0,0,0],[0,1,0]],[[0,0,1],[0,1,1]]],
         'thickness':.1,'thickness_axis':[1,0,0]}


def closed(faces):
    edges=Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,face[1:]+face[:1]))
    return bool(edges) and set(edges.values())=={2}


class ClosedLoftTests(unittest.TestCase):
    def test_caps_are_flat_and_every_edge_has_two_faces(self):
        vertices,faces,caps=loft(FIXTURE)
        self.assertTrue(closed(faces));self.assertEqual(caps,[8,9])
        self.assertEqual(len(vertices),16);self.assertEqual(loft(FIXTURE),(vertices,faces,caps))

    def test_periodic_collar_is_closed_without_cap_faces(self):
        item=deepcopy(FIXTURE);item['sections'] += [[0,0,1,.7,.7],[0,0,0,.8,.8]];item['periodic']=True
        _,faces,caps=loft(item);self.assertTrue(closed(faces));self.assertFalse(caps)

    def test_front_recess_moves_vertices_without_deleting_faces(self):
        item=deepcopy(FIXTURE);item['sector_recess']={'angle':0,'half_angle':.7,'depth':.1,'z_range':[0,1]}
        before,faces,_=loft(FIXTURE);after,changed,_=loft(item)
        self.assertEqual(faces,changed);self.assertLess(after[0][0],before[0][0]);self.assertEqual(after[4],before[4])
        self.assertTrue(closed(changed))

    def test_invalid_profiles_are_rejected(self):
        for key,value in [('axes',[[1,0,0],[1,0,0]]),('samples',7),('sections',[[0,0,0,0,1]])]:
            item=deepcopy(FIXTURE);item[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):loft(item)

    def test_thick_sheet_closes_all_four_boundaries(self):
        vertices,faces,caps=sheet(SHEET);self.assertTrue(closed(faces));self.assertFalse(caps);self.assertEqual(len(vertices),8)
        self.assertEqual(sheet(SHEET),(vertices,faces,caps))

    def test_invalid_sheets_are_rejected(self):
        for key,value in [('rows',[]),('thickness',0),('thickness_axis',[2,0,0])]:
            item=deepcopy(SHEET);item[key]=value
            with self.subTest(key=key),self.assertRaises(ValueError):sheet(item)

    def test_closed_sweep_caps_share_their_boundary_vertices(self):
        path=[[0,0,0],[0,0,1],[0,1,2],[0,2,2]]
        vertices,faces,caps=sweep(path,[.1]*4,16)
        self.assertTrue(closed(faces));self.assertEqual(len(vertices),64)
        self.assertEqual(len(caps),2);self.assertEqual(sweep(path,[.1]*4,16),(vertices,faces,caps))
        with self.assertRaises(ValueError):sweep([[0,0,0],[0,0,0]],[.1,.1],16)

    def test_rounded_box_section_is_opt_in_and_closed(self):
        item=deepcopy(FIXTURE);before=loft(item);item['cross_section_exponent']=4
        vertices,faces,_=loft(item);self.assertTrue(closed(faces));self.assertNotEqual(vertices,before[0])
        item['cross_section_exponent']=9
        with self.assertRaises(ValueError):loft(item)


if __name__=='__main__':unittest.main()
