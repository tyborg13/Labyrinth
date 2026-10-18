"""Feedback proof plumbing and physical mutations; no windowed launch."""
import json
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
from humanoid_cutout.gates import bindings, source_errors
from humanoid_cutout.proof import compose, SHEET_COLUMNS, SHEET_LABEL_HEIGHT_PX, SHEET_CROP_MARGIN_PX
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import dilate, components

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
FIXTURE_FRAMES = ('mark_0030.png', 'bolt_0027.png')


def read(path):
    return json.loads(path.read_text())


class FeedbackTests(unittest.TestCase):
    def test_third_tuck_pixel_row_removal_fails_without_changing_report(self):
        layout, build = read(CASE/'layouts/front.json'), read(CASE/'proof/build.json')
        visible = source_pixels(CASE, next(p for p in layout['parts'] if p['name']=='head'))[...,3]>0
        tuck = next(t for t in build['tucks'] if t['piece']=='head')
        required = np.asarray(Image.open(CASE/tuck['required_mask']))>0
        third_row = required & dilate(visible,3,grid_distance=True) & ~dilate(visible,2,grid_distance=True)
        self.assertTrue(third_row.any())
        with tempfile.TemporaryDirectory(prefix='rr10-two-pixel-tuck-') as folder:
            case = Path(folder)/'case'
            shutil.copytree(CASE,case,ignore=shutil.ignore_patterns('proof'))
            part = next(p for p in layout['parts'] if p['name']=='hidden_head')
            source = source_pixels(case,part)
            source[third_row]=0
            x,y,right,bottom=part['bbox']
            Image.fromarray(source[y:bottom,x:right]).save(case/part['file'])
            self.assertIn('tuck: missing actual texels: head',source_errors(case,layout,build))

    def test_each_final_garment_has_one_connected_source_surface(self):
        layout=read(CASE/'layouts/front.json')
        for name in ('robe','sleeve_near','sleeve_far'):
            image=source_pixels(CASE,next(p for p in layout['parts'] if p['name']==name))
            with self.subTest(piece=name):
                self.assertEqual(len(components(image[...,3]>0)[1]),1)

    def test_director_flat_robe_band_regression_fails_cloth_gate(self):
        layout, build=read(CASE/'layouts/front.json'),read(CASE/'proof/build.json')
        with tempfile.TemporaryDirectory(prefix='rr10-flat-band-') as folder:
            case=Path(folder)/'case'
            shutil.copytree(CASE,case,ignore=shutil.ignore_patterns('proof'))
            part=next(p for p in layout['parts'] if p['name']=='robe')
            # Exact historical source texture that produced mark frame 30's
            # grey line. This is a source-space gate, never a skin oracle.
            shutil.copyfile(PROJECT/'tests/rr10/feedback1/robe_fill_band.png',case/part['file'])
            self.assertIn('dark-slab/cloth continuity: non-continuous robe fill: robe',source_errors(case,layout,build))

    def test_sheets_build_after_gate_pass_and_refuse_gate_failure(self):
        # The verifier boundary is mocked, explicitly: these historical bad
        # frames exercise sheet composition, never acceptance of native proof.
        with tempfile.TemporaryDirectory(prefix='rr10-sheet-fixture-') as folder:
            root=Path(folder); case=root/'case';capture=root/'capture';output=root/'sheets'
            case.mkdir();capture.mkdir()
            (case/'compiled_motion.json').write_text(json.dumps({'clips':{'fixture':{}},'view_tracks':{'front':{}}}))
            rows=[]
            for index,name in enumerate(FIXTURE_FRAMES):
                shutil.copyfile(PROJECT/'tests/rr10/feedback1'/name,capture/name)
                rows.append({'view':'front','clip':'fixture','frame':index,'phase':float(index),'file':name})
            (capture/'frames.json').write_text(json.dumps({'inputs':bindings(case),'native_pixels':True,'ok':True,'frames':rows}))
            with patch('humanoid_cutout.proof.native_errors',return_value=['planted regression']):
                with self.assertRaisesRegex(ValueError,'Native gates failed'):
                    compose(case,capture,output,'sheets')
            self.assertFalse(output.exists())
            with patch('humanoid_cutout.proof.native_errors',return_value=[]) as verify:
                compose(case,capture,output,'sheets')
                verify.assert_called_once_with(case,capture)
            sheet=Image.open(output/'front_fixture_3x.png')
            bounds=[Image.open(capture/name).getbbox() for name in FIXTURE_FRAMES]
            width=(max(b[2] for b in bounds)-min(b[0] for b in bounds)+2*SHEET_CROP_MARGIN_PX)*3
            height=(max(b[3] for b in bounds)-min(b[1] for b in bounds)+2*SHEET_CROP_MARGIN_PX)*3
            self.assertEqual(sheet.size,(width*SHEET_COLUMNS,height+SHEET_LABEL_HEIGHT_PX))
            self.assertNotEqual(sheet.crop((0,0,width,height)).tobytes(),sheet.crop((width,0,2*width,height)).tobytes())
            self.assertTrue(read(output/'manifest.json')['ok'])


if __name__=='__main__': unittest.main()
