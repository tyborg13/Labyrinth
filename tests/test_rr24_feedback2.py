"""Own-paint continuations, layout rest selection and root-relative proof crops."""
from copy import deepcopy
import hashlib
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/arc_thrall')]
from rr24_build import CASE,RECIPE,read_json,source_pixels,clean_residue
from rr24_baseline import canonical
from rr24_check import source_errors
from rr24_materials import donor_palettes,exposed_provenance
from rr24_crops import collar_box,frame_root,crop_plan,CELL_SIZE,CROP_MARGIN_PX,CROP_ZOOM,LABEL_HEIGHT_PX,CLIPS
from rr24_capture_source import source as capture_source,THRALL_PROBE
from rr11_gates import source_errors as case_source_errors
from maquette_motion.material_palette import rules
from tools.humanoid_cutout.cpu_pose import CpuPose
from tests.test_rr24_thrall import FIXTURE_FOREIGN_FILL_RGBA

WALK_WIDTHS={'front':{'old':382,'stabilised':142},'rear':{'old':338,'stabilised':96}}
JAB11_EXPOSURE={'mq7b_continuation_loincloth':98,'mq7b_continuation_sleeve_far':36,'hidden_torso':202}
RAW_CLEAN_DIFFERENCES={'front':2,'rear':5}


class Feedback2Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layouts={v:read_json(CASE/f'layouts/{v}.json')for v in ('front','rear')}
        cls.samples=read_json(CASE/'proof/samples.json')['samples']

    def palettes(self,view):
        visible={p.stem:clean_residue(np.asarray(Image.open(p).convert('RGBA')))[0]
                 for p in (RECIPE/'raw'/view).glob('*.png')}
        return donor_palettes(visible,rules(CASE,view))

    def test_hidden_colours_belong_to_current_own_piece(self):
        for view,layout in self.layouts.items():
            own={p.stem:set(map(tuple,clean_residue(np.asarray(Image.open(p).convert('RGBA')))[0].reshape(-1,4)))
                 for p in (RECIPE/'raw'/view).glob('*.png')}
            for part in layout['parts']:
                if not part.get('hidden_material'):continue
                image=source_pixels(CASE,part)
                self.assertTrue(all(tuple(c)in own[part['logical_part']]for c in image[image[...,3]>0]),(view,part['name']))
            self.assertEqual(source_errors(view,layout),[])

    def test_colour_rebuild_preserves_every_alpha_and_layout_field(self):
        before=read_json(RECIPE/'feedback2_preservation.json')
        for view,layout in self.layouts.items():
            old=before['views'][view]
            geometry=deepcopy(layout);geometry.pop('gait_continuations')
            for layer in geometry['proof_layers'].values():layer.pop('source_sha256')
            self.assertEqual(canonical(geometry),old['layout_without_colour_sha256'])
            targets={name:[row[:2]for row in recipe['texels']]for name,recipe in layout['gait_continuations'].items()}
            self.assertEqual(canonical(targets),old['gait_target_positions_sha256'])
            self.assertEqual({p['name']for p in layout['parts']},set(old['alpha_sha256']))
            for part in layout['parts']:
                alpha=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))[...,3]
                self.assertEqual(hashlib.sha256(alpha.tobytes()).hexdigest(),old['alpha_sha256'][part['name']],(view,part['name']))

    def test_foreign_skirt_colour_is_rejected_in_both_views(self):
        for view,layout in self.layouts.items():
            name='mq7b_continuation_loincloth'
            def contaminated(case,part):
                image=source_pixels(case,part)
                if part['name']==name:
                    y,x=np.argwhere(image[...,3]>0)[0]
                    image[y,x]=FIXTURE_FOREIGN_FILL_RGBA
                return image
            with patch('rr24_check.source_pixels',side_effect=contaminated):
                error='hidden fill must use own mq7b texels: '+name
                self.assertIn(error,source_errors(view,layout))
                self.assertIn(error,case_source_errors(CASE,layout,read_json(CASE/'proof/build.json')))

    def jab_layers(self):
        layout=self.layouts['front']
        pose=next(p for p in self.samples if p['view']=='front'and p['clip']=='jab'and p['frame']==11 and p['kind']=='presented')
        return CpuPose(CASE,layout).layers(pose)[0]

    def test_reviewed_jab_exposures_have_no_foreign_colour(self):
        rows=exposed_provenance(self.jab_layers(),self.palettes('front'))
        by_name={r['piece']:r for r in rows}
        for name,count in JAB11_EXPOSURE.items():self.assertEqual(by_name[name]['exposed_pixels'],count)
        self.assertEqual(sum(r['foreign_pixels']for r in rows),0)

    def test_exposed_foreign_skirt_colour_cannot_pass(self):
        layers=deepcopy(self.jab_layers())
        for part,image,_ in layers:
            if part['name']=='mq7b_continuation_loincloth':image[image[...,3]>0]=FIXTURE_FOREIGN_FILL_RGBA
        rows=exposed_provenance(layers,self.palettes('front'))
        self.assertEqual(next(r['foreign_pixels']for r in rows if r['piece']=='mq7b_continuation_loincloth'),98)

    def test_walk_crop_overflow_reproduces_from_metadata_and_is_removed(self):
        for view,layout in self.layouts.items():
            contour=read_json(RECIPE/'ownership.json')[view]
            for clip in CLIPS.values():
                poses=[p for p in self.samples if p['view']==view and p['clip']==clip and p['kind']=='presented']
                boxes=[collar_box(layout,contour,p)for p in poses];roots=[frame_root(p)for p in poses]
                bounds,size,crops=crop_plan(boxes,roots)
                self.assertLessEqual(size[0],CELL_SIZE[0]);self.assertLessEqual(size[1],CELL_SIZE[1]-LABEL_HEIGHT_PX)
                for crop,root in zip(crops,roots):np.testing.assert_array_equal(np.asarray(crop)-np.tile(root,2),bounds)
                if clip=='move':
                    old=(math.ceil(max(b[2]for b in boxes))-math.floor(min(b[0]for b in boxes))+2*CROP_MARGIN_PX)*CROP_ZOOM
                    self.assertEqual(old,WALK_WIDTHS[view]['old'])
                    self.assertGreater(old,CELL_SIZE[0]);self.assertEqual(size[0],WALK_WIDTHS[view]['stabilised'])

    def test_thrall_probe_preserves_shared_render_code_and_all_paths_use_it(self):
        self.assertEqual(THRALL_PROBE.read_text(),capture_source())
        self.assertIn('var source: Image = rest_reference(view)',THRALL_PROBE.read_text())
        commands=(CASE.parent/'rr11_proof.sh').read_text().splitlines()
        paths=[line for line in commands if '--proof-contract tests/rr11/'in line and 'native_capture.gd'in line]
        self.assertEqual(len(paths),3)
        self.assertTrue(all('experiments/cutouts/arc_thrall/rr24_native_capture.gd'in line for line in paths))

    def test_real_probe_loads_layout_rest_references_headless(self):
        with tempfile.TemporaryDirectory(prefix='rr24-rest-reference-')as folder:
            command=[sys.executable,'tools/godot_task_runner.py','--task-id','rr-24','--stream','--','godot',
                     '--headless','--path','.','--script',str(THRALL_PROBE.relative_to(PROJECT)),
                     '--','--case',str(CASE.relative_to(PROJECT)),'--output',folder,'--validate-only']
            result=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,check=False)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            self.assertIn('RR11 NATIVE PROBE LOAD: PASS',result.stdout)
            for view,layout in self.layouts.items():
                self.assertIn(f'RR24 REST REFERENCE {view.upper()}: source/{view}/presentation.png',result.stdout)
                raw=np.asarray(Image.open(CASE/layout['raw_rest_source']).convert('RGBA'))
                cleaned=np.asarray(Image.open(CASE/layout['rest_source']).convert('RGBA'))
                self.assertEqual(int(np.any(raw!=cleaned,axis=2).sum()),RAW_CLEAN_DIFFERENCES[view])


if __name__=='__main__':unittest.main(verbosity=2)
