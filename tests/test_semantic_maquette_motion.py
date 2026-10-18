#!/usr/bin/env python3
"""rr-04 authored-key, applied-bone and production freeze regressions."""
import copy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.cases import read_json, write_json, digest, CutoutError
from maquette_cutout_build import SOURCE, CREATURES, case_for
from maquette_motion import compiler, gates
from maquette_motion.contract import approved_source
from maquette_cutout_review import plan

class SemanticMotionTests(unittest.TestCase):
    def test_feedback7_restores_the_protected_bloomer_idle_key(self):
        case = case_for('shale_bloomer')
        self.assertFalse((case/'director_amendments.json').exists())
        self.assertEqual((case/'director_motion.json').read_bytes(), SOURCE.read_bytes())
        self.assertEqual(read_json(approved_source(case))['shale_bloomer']['clips']['idle']['keys']['tendril_high_r.raise_deg'][1], [0.5, 5])
        with tempfile.TemporaryDirectory(dir=PROJECT/'tests') as temporary:
            root = Path(temporary)
            for name in ('director_motion.json', 'cutout.json'):
                shutil.copyfile(case/name, root/name)
            changed = read_json(root/'director_motion.json')
            changed['shale_bloomer']['clips']['idle']['keys']['tendril_low_r.raise_deg'][0][1] += 1
            write_json(root/'director_motion.json', changed)
            with self.assertRaises(CutoutError): approved_source(root)

    def run_sampler(self,case,output):
        p=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-05','--stream','--',
            'godot','--headless','--path','.', '--script','tests/maquette_cutout/samples.gd','--','--case',str(case),'--output',str(output)],
            cwd=PROJECT,text=True,capture_output=True,timeout=60)
        self.assertEqual(p.returncode,0,p.stdout+p.stderr)

    def test_compiler_accepts_an_explicit_graph_for_another_maquette(self):
        spec=read_json(PROJECT/'spec/art_identity/maquettes/lightning_wisp/spec.json')
        recipe=read_json(case_for('lightning_wisp')/'recipes/rig.json')
        data=read_json(SOURCE)
        with tempfile.TemporaryDirectory() as temporary:
            source=Path(temporary)/'motion.json'
            source.write_text(json.dumps({'fixture_cloud':data['lightning_wisp']}))
            compiled=compiler.compile_creature(source,'fixture_cloud',spec,recipe)
            self.assertEqual(compiled['view_tracks'],read_json(case_for('lightning_wisp')/'compiled_motion.json')['view_tracks'])
            self.assertEqual(compiled['parts']['arc_left'],'core')

    def test_protected_keys_and_byte_copies(self):
        for creature in CREATURES:
            case=case_for(creature)
            source = approved_source(case)
            self.assertEqual((case/'director_motion.json').read_bytes(),source.read_bytes())
            self.assertEqual((case/'source/spec.json').read_bytes(),(PROJECT/'spec/art_identity/maquettes'/creature/'spec.json').read_bytes())
            for view,job in read_json(SOURCE)[creature]['art'].items():
                for name in ['processed.png','processed.json','kit.json']:
                    self.assertEqual((case/'source'/view/name).read_bytes(),(PROJECT/job/name).read_bytes())
            compiled=read_json(case/'compiled_motion.json')
            expected=compiler.compile_creature(source,creature,read_json(PROJECT/'spec/art_identity/maquettes'/creature/'spec.json'))
            self.assertEqual(compiled,expected)
            self.assertFalse(read_json(case/'hidden_fills/index.json')['pending_design'])
            self.assertEqual(read_json(case/'build_report.json')['rest_identity']['front']['different_pixels'],0)
            self.assertEqual(read_json(case/'build_report.json')['rest_identity']['rear']['different_pixels'],0)

    def test_real_bones_at_all_authored_keys_and_midpoints(self):
        for creature in CREATURES:
            case=case_for(creature)
            with tempfile.TemporaryDirectory(dir=PROJECT/'tests') as temporary:
                output=Path(temporary)/'samples.json';self.run_sampler(case,output)
                self.assertEqual(gates.errors(case,output),[])

    def test_flip_raise_sign_and_drop_key_fail_after_actual_resampling(self):
        for creature in CREATURES:
            for mutation in ['flip_raise_sign','drop_key']:
                with self.subTest(creature=creature,mutation=mutation),tempfile.TemporaryDirectory(dir=case_for(creature).parent) as temporary:
                    case=Path(temporary)/'case';shutil.copytree(case_for(creature),case)
                    compiled=read_json(case/'compiled_motion.json')
                    for view in compiler.VIEWS:
                        track=next(t for t in compiled['view_tracks'][view]['idle'] if t['channel']=='raise_deg')
                        if mutation=='flip_raise_sign':
                            for key in track['keys']:key['value']*=-1
                        else:track['keys'].pop(1)
                    write_json(case/'compiled_motion.json',compiled)
                    output=Path(temporary)/'samples.json';self.run_sampler(case,output)
                    failures=gates.errors(case,output)
                    self.assertIn('Compiled authored keys/signs differ from protected source',failures)
                    for view in compiler.VIEWS:self.assertTrue(any(f.startswith(view+'/') for f in failures),failures)
                    print(f'MAQUETTE MUTATION: {creature}/{mutation} rejected in both views')

    def test_bad_compiler_sign_cannot_certify_itself_after_recompilation(self):
        for creature in CREATURES:
            with self.subTest(creature=creature),tempfile.TemporaryDirectory(dir=case_for(creature).parent) as temporary:
                case=Path(temporary)/'case';shutil.copytree(case_for(creature),case)
                original=compiler.projection
                def broken(*args):
                    axes=original(*args)
                    for item in axes['parts'].values():
                        if 'raise_deg' in item:item['raise_deg']*=-1
                    return axes
                # Keep the broken compiler installed while verifying as well.
                # An oracle that invokes the compiler would accept this output.
                with patch.object(compiler,'projection',broken):
                    compiled=compiler.compile_creature(SOURCE,creature,read_json(case/'source/spec.json'))
                    write_json(case/'compiled_motion.json',compiled)
                    output=Path(temporary)/'samples.json';self.run_sampler(case,output)
                    failures=gates.errors(case,output)
                    self.assertIn('Compiled authored keys/signs differ from protected source',failures)
                    for view in compiler.VIEWS:self.assertTrue(any(f.startswith(view+'/') for f in failures),failures)
                print('MAQUETTE MUTATION: '+creature+'/broken_compiler rejected by independent director oracle')

    def overlay(self,destination,target):
        def link_tree(source,out,remaining):
            out.mkdir(exist_ok=True)
            for child in source.iterdir():
                if child.name in ['.git','.codex','.agents']:continue
                path=out/child.name
                if child.name!=remaining.parts[0]:path.symlink_to(child,target_is_directory=child.is_dir())
                elif len(remaining.parts)>1:link_tree(child,path,Path(*remaining.parts[1:]))
                else:
                    text=child.read_text();needle='rig.apply_pose(shown, progress)'
                    self.assertEqual(text.count(needle),1)
                    path.write_text(text.replace(needle,'rig.apply_pose(shown, 0.0 if shown == "idle" else progress)'))
        link_tree(PROJECT,destination,target)

    def test_frozen_idle_fails_focused_test_and_actual_production_recorder(self):
        target=Path('scripts/maquette_cutout_runtime/renderer.gd');before=digest(PROJECT/target)
        with tempfile.TemporaryDirectory(prefix='rr04_idle_mutation_') as temporary:
            root=Path(temporary)/'overlay';self.overlay(root,target)
            for script,args,marker in [
                ('tests/maquette_cutout_test.gd',[], 'production idle applies changing bone poses'),
                ('tests/maquette_cutout/production_capture.gd',['--','--type','lightning_wisp','--output',str(Path(temporary)/'production'),'--logic-only'],'idle: fewer than six changing bone poses')]:
                p=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-05','--timeout','180','--stream','--',
                    'godot','--headless','--path',str(root),'--script','res://'+script,*args],cwd=PROJECT,capture_output=True,text=True,timeout=200)
                output=p.stdout+p.stderr
                self.assertNotEqual(p.returncode,0,output)
                self.assertNotIn('SCRIPT ERROR',output)
                self.assertIn(marker,output)
                print('MAQUETTE MUTATION: frozen_idle rejected by '+script)
        self.assertEqual(digest(PROJECT/target),before)

    def test_fraction_step_squash_alpha_and_review_plan(self):
        for creature in CREATURES:
            case=case_for(creature);compiled=read_json(case/'compiled_motion.json')
            for view in compiler.VIEWS:
                layout=read_json(case/f'layouts/{view}.json')
                end=gates.expected_bones(compiled,layout,view,'move',1,96)
                start=gates.expected_bones(compiled,layout,view,'move',0,96)
                self.assertAlmostEqual(float(__import__('numpy').linalg.norm(end['root']['local'][:2,2]-start['root']['local'][:2,2])),96)
                self.assertEqual(compiled['clips']['death']['terminal'],True)
            self.assertEqual(dict(plan(compiled))['idle'],3)
            self.assertEqual(dict(plan(compiled))['move'],3)
            self.assertEqual(dict(plan(compiled))['death'],1)
            authored=list(read_json(SOURCE)[creature]['clips'])
            ordered=plan(compiled,authored)
            self.assertEqual([clip for clip,_ in ordered][:2],['idle','move'])
            self.assertEqual(ordered[-1],('death',1))
            self.assertEqual([clip for clip,_ in ordered][2:-1],[clip for clip in authored if clip not in ('idle','move','death')])
        self.assertAlmostEqual(compiler.evaluate([{'at':0,'value':0,'interpolation':'smoothstep'},{'at':1,'value':1,'interpolation':'hold'}],.5),0)
        self.assertAlmostEqual(compiler.evaluate([{'at':0,'value':0,'interpolation':'smoothstep'},{'at':1,'value':1,'interpolation':'hold'}],1),1)

if __name__=='__main__':unittest.main()
