"""Lossless cover-evidence packaging and real construction-reader compatibility."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/slag_mortar')]
from cutout_pipeline.cases import read_json,write_json
from rr30_case import CASE
import rr30_joint_calibrate as calibrate
from rr30_joint_storage import VIEWS,read_evidence,write_calibration,compact_calibration
from rr30_joint_covers import bound_action_domains
from rr30_joint_geometry import source_materials


def fixture():
    return {view:dict(basis=dict(visible={},joints='fixture',director_motion='fixture'),
        frames=1,cuts={'hidden_fore_near':[[3,2]]},evidence=[dict(clip='lob',frame=1,
        piece='hidden_fore_near',maximum_distance_px=3.5,source_texels=[[3,2],[3,2]])])
        for view in VIEWS}


class CalibrationStorageTests(unittest.TestCase):
    def test_repackaging_preserves_every_observation_and_operational_field(self):
        original=fixture()
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cuts.json'
            write_json(path,original)
            self.assertEqual(read_evidence(path,original),{v:original[v]['evidence'] for v in VIEWS})
            compact=compact_calibration(path)
            self.assertEqual(read_evidence(path,compact),{v:original[v]['evidence'] for v in VIEWS})
            for view in VIEWS:
                self.assertEqual(compact[view],{k:v for k,v in original[view].items() if k!='evidence'})
            before={p.name:p.read_bytes() for p in path.parent.iterdir()}
            self.assertEqual(compact_calibration(path),compact)
            self.assertEqual({p.name:p.read_bytes() for p in path.parent.iterdir()},before)

    def test_changed_or_missing_evidence_cannot_be_silently_extended(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cuts.json';compact=write_calibration(path,fixture())
            sidecar=path.parent/compact['full_evidence']['file']
            sidecar.write_bytes(sidecar.read_bytes()+b'changed')
            with self.assertRaisesRegex(ValueError,'hash differs'):read_evidence(path,compact)
            sidecar.unlink()
            with self.assertRaises(OSError):read_evidence(path,compact)

    def test_evidence_inventory_is_checked(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cuts.json';compact=write_calibration(path,fixture())
            compact['full_evidence']['rows']['front']+=1
            with self.assertRaisesRegex(ValueError,'inventory differs'):read_evidence(path,compact)

    def test_calibration_extension_restores_sidecar_evidence(self):
        original=fixture()
        with tempfile.TemporaryDirectory() as folder:
            case=Path(folder)/'case';path=case.parent/'cuts.json'
            write_calibration(path,original)
            for view in VIEWS:write_json(case/f'layouts/{view}.json',dict(parts=[],joints={}))
            with patch.object(calibrate,'CASE',case),patch.object(calibrate,'CUTS',path),\
                    patch.object(calibrate,'bindings',return_value={}),\
                    patch.object(calibrate,'CoveragePose'),patch.object(calibrate,'JointSurfaceGate'),\
                    patch.object(calibrate,'source_materials',return_value=({},None)),\
                    patch.object(calibrate,'basis',return_value=original['front']['basis']):
                result=calibrate.run(dict(inputs={},samples=[]),extend=True)
            self.assertEqual(read_evidence(path,result),{v:original[v]['evidence'] for v in VIEWS})
            for view in VIEWS:self.assertEqual(result[view]['cuts'],original[view]['cuts'])

    def test_real_action_domains_need_only_operational_json(self):
        operational=read_json(calibrate.CUTS)
        anatomy=read_json(CASE/'anatomy.json')
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cuts.json'
            # No sidecar is copied. A construction consumer must never open it.
            write_json(path,operational)
            for view in VIEWS:
                visible,_=source_materials(CASE,read_json(CASE/f'layouts/{view}.json'))
                before={name:np.ones(image.shape[:2],dtype=bool) for name,image in visible.items()}
                after=copy.deepcopy(before)
                bound_action_domains(before,visible,anatomy,view=view)
                with patch.object(calibrate,'CUTS',path):
                    bound_action_domains(after,visible,anatomy,view=view)
                for name in before:np.testing.assert_array_equal(before[name],after[name])

    def test_operational_record_is_compact_and_complete(self):
        record=read_json(calibrate.CUTS)
        self.assertIn('full_evidence',record)
        details=read_evidence(calibrate.CUTS,record)
        for view in VIEWS:
            self.assertEqual(set(record[view]),{'basis','frames','cuts'})
            observed={}
            for row in details[view]:
                observed.setdefault(row['piece'],set()).update(map(tuple,row['source_texels']))
            self.assertEqual({n:set(map(tuple,p)) for n,p in record[view]['cuts'].items()},observed)


if __name__=='__main__':unittest.main()
