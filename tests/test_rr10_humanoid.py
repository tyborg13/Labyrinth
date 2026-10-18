"""Two-view v2 evidence and planted regressions. Never launches a GUI."""
import copy
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import shutil
import unittest

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, idle_pixel_errors, matrix, clean_metrics, bindings, joint_holes
from humanoid_cutout.mesh import robe_weights, sleeve_weights
from humanoid_cutout.compiler import compile_motion

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-10/motion_tracks.json'
PROOF_TIMEOUT_SECONDS = 180


def read(path):
    return json.loads(path.read_bytes())


class HumanoidTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = read(CASE / 'layouts/front.json')
        cls.data = read(CASE / 'compiled_motion.json')
        cls.build = read(CASE / 'proof/build.json')
        with tempfile.TemporaryDirectory(prefix='rr10-bones-') as folder:
            target = Path(folder) / 'samples.json'
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-10', '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', 'tests/rr10/samples.gd', '--', '--output', str(target)]
            process = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.samples = read(target)

    def test_exact_protected_copy_and_compilation(self):
        self.assertEqual((CASE / 'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR, 'hoarfrost_seer', {v:read(CASE/f'layouts/{v}.json') for v in ('front','rear')}, self.data['projection']), self.data)
        self.assertEqual(self.build['front_rest_mismatch_pixels'], 0)
        idle=read(PROJECT/'tests/rr10/feedback1/approved_idle.json')
        self.assertEqual(self.data['clips']['idle'],idle['clip'])
        self.assertEqual(self.data['view_tracks']['front']['idle'],idle['tracks'])

    def test_promoted_paint_has_a_production_only_closure(self):
        assets=PROJECT/'assets/units/hoarfrost_seer_cutout/humanoid_v2'
        self.assertTrue(list(assets.rglob('*.png')))
        self.assertEqual((assets/'director_motion.json').read_bytes(),DIRECTOR.read_bytes())
        for view in ('front','rear'):
            layout=read(assets/(view+'.json'))
            for part in layout['parts']+layout['joint_meshes']:
                self.assertNotIn('experiments/',part['file'])
                self.assertTrue((assets/part['file']).is_file())

    def test_structure_and_all_real_bones(self):
        self.assertEqual(structure_errors(self.layout, self.build), [])
        self.assertEqual(source_errors(CASE,self.layout,self.build), [])
        self.assertEqual(bone_errors(self.layout, self.data, self.samples), [])

    def test_weights_top_hem_elbow_and_normalization(self):
        weights = robe_weights([[0,0],[0,4],[0,10],[12,10],[6,10]], [0,0,12,10])
        self.assertEqual(weights['pelvis'][:2], [1,1])
        self.assertEqual(weights['hem_far'][2], 1)
        self.assertEqual(weights['hem_near'][3], 1)
        self.assertEqual(weights['hem_near'][4], .5)
        weights = sleeve_weights([[0,6],[0,10],[4,10]], [0,0],[0,10],[10,10], 'near')
        self.assertTrue(np.allclose(weights['fore_near'], [0,.5,1]))
        layout=copy.deepcopy(self.layout)
        mesh=next(m for m in layout['joint_meshes'] if m['name']=='robe')
        mesh['weights']['pelvis'][0]=.9
        mesh['weights']['hem_far'][0]=.1
        self.assertTrue(any('weight rule differs' in error for error in structure_errors(layout,self.build)))

    def mutant(self, clip, bone, operation):
        report = copy.deepcopy(self.samples)
        row = next(r for r in report['samples'] if r['clip'] == clip and r['kind'] == 'presented')
        operation(row['bones'][bone]['global'])
        return bone_errors(self.layout, self.data, report)

    def test_one_degree_idle_torso_rotation_fails(self):
        def rotate(t):
            t[:4] = [math.cos(math.radians(1)), math.sin(math.radians(1)), -math.sin(math.radians(1)), math.cos(math.radians(1))]
        self.assertTrue(any('idle rotation' in e for e in self.mutant('idle','torso',rotate)))

    def test_split_robe_fails(self):
        layout = copy.deepcopy(self.layout)
        layout['joint_meshes'] = [m for m in layout['joint_meshes'] if m['name'] != 'robe']
        layout['joints']['skirt_near'] = {'position': [0,0], 'parent':'torso'}
        self.assertTrue(any('robe' in e for e in structure_errors(layout, self.build)))

    def test_two_pixel_tuck_fails(self):
        build = copy.deepcopy(self.build)
        build['tucks'][0]['minimum_px'] = 2
        self.assertTrue(any('tuck' in e for e in structure_errors(self.layout, build)))

    def test_forty_degree_staff_fails(self):
        def rotate(t):
            t[:4] = [math.cos(math.radians(40)), math.sin(math.radians(40)), -math.sin(math.radians(40)), math.cos(math.radians(40))]
        self.assertTrue(any('staff angle limit' in e for e in self.mutant('ward','staff',rotate)))

    def test_ward_hem_translation_fails(self):
        self.assertTrue(any('anchor moved' in e for e in self.mutant('ward','hem_near',lambda t: t.__setitem__(4,t[4]+1))))

    def test_signed_key_and_midpoint_mutations_fail(self):
        report = copy.deepcopy(self.samples)
        row = next(r for r in report['samples'] if r['clip']=='ward' and r['kind']=='authored' and r['phase']==.3)
        row['bones']['torso']['local'][4] += 1
        self.assertTrue(any('signed translation' in e for e in bone_errors(self.layout,self.data,report)))
        row = next(r for r in report['samples'] if r['clip']=='ward' and r['kind']=='authored' and r['phase']==.15)
        row['bones']['hand_near']['global'][4] += 1
        self.assertTrue(any('signed hand target' in e for e in bone_errors(self.layout,self.data,report)))

    def test_world_step_and_release_floor_end(self):
        rows = [r for r in self.samples['samples'] if r['kind']=='authored' and r['view']=='front']
        planted = [r for r in rows if r['clip']=='move' and r['phase'] <= .02]
        self.assertGreater(len(planted), 1)
        self.assertTrue(all(np.allclose(r['bones']['hem_near']['global'][4:], planted[0]['bones']['hem_near']['global'][4:]) for r in planted))
        rest = np.asarray(self.layout['held_items']['staff']['floor_end']) - self.layout['joints']['staff']['position']
        death = [r for r in rows if r['clip']=='death' and r['phase'] >= .2]
        points = [(matrix(r['bones']['staff']['global']) @ [*rest,1])[:2] for r in death]
        self.assertTrue(np.allclose(points, points[0], atol=.0001))

    def test_idle_pixel_gate_detects_single_bad_texel(self):
        rest = np.zeros((8,8,4), dtype=np.uint8)
        rest[2:4,2:4] = [10,20,30,255]
        shifted = np.zeros_like(rest)
        shifted[4:6,2:4] = rest[2:4,2:4]
        self.assertEqual(idle_pixel_errors(rest,shifted,[0,2]),0)
        shifted[4,2,0] += 1
        self.assertEqual(idle_pixel_errors(rest,shifted,[0,2]),1)
        shifted[0,0,0]=99
        self.assertEqual(idle_pixel_errors(rest,shifted,[0,2]),1)

    def test_actual_tuck_removal_and_feature_repaint_fail(self):
        from PIL import Image
        with tempfile.TemporaryDirectory(prefix='rr10-source-mutations-') as folder:
            case = Path(folder) / 'case'
            shutil.copytree(CASE,case,ignore=shutil.ignore_patterns('proof'))
            part = next(p for p in self.layout['parts'] if p['name']=='hidden_head')
            image = np.asarray(Image.open(case / part['file']).convert('RGBA')).copy()
            image[:] = 0
            Image.fromarray(image).save(case / part['file'])
            self.assertIn('tuck: missing actual texels: head',source_errors(case,self.layout,self.build))
            part = next(p for p in self.layout['parts'] if p['name']=='staff')
            image = np.asarray(Image.open(case / part['file']).convert('RGBA')).copy()
            image[image[...,3]>0,0] ^= 1
            Image.fromarray(image).save(case / part['file'])
            self.assertIn('feature integrity: ice_crystal',source_errors(case,self.layout,self.build))

    def test_clean_piece_dark_slab_tuck_hole_and_silhouette_mutations(self):
        image=np.zeros((10,10,4),dtype=np.uint8)
        image[2:8,2:8]=[30,30,30,255]
        checks=np.zeros_like(image)
        checks[2:8,2:8]=[255,0,0,255]
        row={'z_index':0}
        baseline=clean_metrics([(row,image,checks)])
        self.assertTrue(all(not value for value in baseline.values()),baseline)
        mutant=image.copy(); mutant[1,1]=[30,30,30,255]
        self.assertEqual(clean_metrics([(row,mutant,checks)])['outside_pixels'],1)
        mutant=checks.copy(); mutant[3:6,3:6,1:3]=255
        self.assertGreater(clean_metrics([(row,image,mutant)])['dark_slab_blocks'],0)
        mutant=checks.copy(); mutant[2,2,1]=255
        self.assertEqual(clean_metrics([(row,image,mutant)])['exposed_continuation_pixels'],1)
        self.assertEqual(clean_metrics([(row,image,mutant)])['exposed_outline_pixels'],0)
        mutant[2,2,2]=255
        self.assertEqual(clean_metrics([(row,image,mutant)])['exposed_outline_pixels'],1)
        cover=np.zeros_like(image); cover[2,2]=[30,30,30,255]
        self.assertEqual(clean_metrics([(row,image,mutant),({'z_index':1},cover,checks)])['exposed_outline_pixels'],0)
        mutant=image.copy(); mutant[4:6,4:6]=0
        self.assertEqual(clean_metrics([(row,mutant,checks)])['interior_hole_sizes'],[4])
        old=np.zeros((10,10),dtype=bool); old[4:6,4:6]=True
        seam=old.copy()
        from humanoid_cutout.silhouette_gates import OWNER_IDS
        owners=np.full(old.shape,OWNER_IDS['upper_far'],dtype=np.uint8)
        owners[5:]=OWNER_IDS['fore_far']
        self.assertEqual(joint_holes(mutant[...,3]>0,seam,owners,[old]),[])
        displaced=np.zeros_like(old); displaced[3,3:5]=True
        self.assertEqual(joint_holes(mutant[...,3]>0,seam,owners,[displaced]),[4])
        occupied=np.zeros((14,14),dtype=bool); occupied[1:13,1:13]=True
        occupied[3:5,3:5]=False; occupied[8:10,8:10]=False
        reference=np.zeros_like(occupied); reference[3:5,3:5]=True
        # Unjoined negative space may change freely. Only the second, joint
        # local opening is a defect; a one-pixel opening remains allowed.
        seam=np.zeros_like(occupied);seam[9,9]=True
        owners=np.full(occupied.shape,OWNER_IDS['upper_far'],dtype=np.uint8)
        owners[9:]=OWNER_IDS['fore_far']
        self.assertEqual(joint_holes(occupied,seam,owners),[4])
        seam[:]=False
        self.assertEqual(joint_holes(occupied,seam,owners),[])

    def test_stray_gate_rejects_all_five_director_regression_frames(self):
        from PIL import Image
        from cutout_pipeline.cases import digest
        folder=PROJECT/'tests/rr10/feedback1'
        for row in read(folder/'captures.json')['frames']:
            with self.subTest(clip=row['clip'],frame=row['frame']):
                self.assertEqual(digest(folder/row['file']),row['fixture_sha256'])
                image=np.asarray(Image.open(folder/row['file']).convert('RGBA'))
                checks=np.zeros_like(image); checks[image[...,3]>0]=[255,0,0,255]
                metrics=clean_metrics([({'z_index':0},image,checks)])
                self.assertGreater(metrics['stray_components'],0)
        image=np.zeros((20,20,4),dtype=np.uint8);image[4:16,4:16]=[50,60,70,255]
        checks=np.zeros_like(image);checks[image[...,3]>0]=[255,0,0,255]
        image[1,1]=[0,0,0,255]
        definition={'visible_luma_cutoff':1,'outline_palette':[]}
        metrics=clean_metrics([({'z_index':0},image,checks)],definition)
        self.assertEqual(metrics['outline_outside_pixels'],1)
        self.assertEqual(metrics['stray_pixels'],1)

    def test_derived_continuations_have_no_outline_fragments(self):
        from PIL import Image
        from maquette_motion.material_palette import rules,outline_class
        definition=rules(CASE,'front')
        for name,record in self.layout['proof_layers'].items():
            checks=np.asarray(Image.open(CASE/record['mask']).convert('RGBA'))
            image=np.asarray(Image.open(CASE/record['source']).convert('RGBA'))
            with self.subTest(piece=name):
                self.assertFalse(((checks[...,1]>0)&outline_class(image,definition)).any())

    def test_staff_depth_policy_in_both_views_and_mutation(self):
        from humanoid_cutout.materials import held_depths
        depths={p['name']:p['z_index'] for p in self.layout['parts']}
        for view in ('front','rear'):
            result=held_depths(depths,view,self.layout['held_item_depth'])
            body=[result[n] for n in ('torso','sleeve_near','sleeve_far','robe')]
            self.assertTrue(result['staff']<min(body) if view=='front' else result['staff']>max(body))
            self.assertGreater(result['hand_far'],result['staff'])
        bad=copy.deepcopy(self.layout)
        next(p for p in bad['parts'] if p['name']=='staff')['z_index']=40
        self.assertTrue(any('held depth' in e for e in structure_errors(bad,self.build)))

    def test_rigid_native_agreement_rejects_changed_paint(self):
        from maquette_motion.pixels import native_frame_matches
        image=np.zeros((32,32,4),dtype=np.uint8); image[2:22,2:22]=[30,40,50,255]
        self.assertTrue(native_frame_matches(image,image))
        mutant=image.copy(); mutant[2:22,2:22,0]=120
        self.assertFalse(native_frame_matches(mutant,image))

    def test_runtime_seed_portrait_units_and_native_input_bindings(self):
        with tempfile.TemporaryDirectory(prefix='rr10-runtime-') as folder:
            target=Path(folder)/'bindings.json'
            command=[sys.executable,'tools/godot_task_runner.py','--task-id','rr-10','--stream','--',
                     'godot','--headless','--path','.','--script','tests/rr10/runtime_checks.gd','--','--bindings-output',str(target)]
            process=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
            self.assertEqual(process.returncode,0,process.stdout+process.stderr)
            self.assertEqual(read(target),bindings(CASE))

    def test_real_production_callbacks_use_v2_and_exact_contacts(self):
        with tempfile.TemporaryDirectory(prefix='rr10-production-') as folder:
            command=[sys.executable,'tools/godot_task_runner.py','--task-id','rr-10','--stream','--',
                     'godot','--headless','--path','.','--script','tests/rr10/production_capture.gd','--',
                     '--type','hoarfrost_seer','--output',folder,'--logic-only']
            process=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
            self.assertEqual(process.returncode,0,process.stdout+process.stderr)
            report=read(Path(folder)/'logic_frames.json')
            self.assertTrue(report['ok'],report['errors'])
            self.assertTrue(report['production_promoted'])
            self.assertTrue(all(r['snapshot']['rig_count']==2 for r in report['frames']))
            for clip in ('mark','land','bolt','ward'):
                contact=self.data['clips'][clip]['contact']
                self.assertTrue(any(r['stage']==clip and abs(r['snapshot']['phase']-contact)<1e-6 for r in report['frames']))
            marks=[r for r in report['frames'] if r['stage']=='mark' and r['marks']>0]
            self.assertAlmostEqual(min(r['snapshot']['phase'] for r in marks),self.data['clips']['mark']['contact'],places=6)


if __name__ == '__main__':
    unittest.main()
