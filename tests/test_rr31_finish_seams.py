"""Director feedback 2: actual source coverage and non-blocking diagnostics."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/slag_mortar')]
import test_rr30_mortar as mortar_tests
import rr31_images as diagnostic
from rr30_case import CASE
from rr30_cpu import CpuPose,sprite_transform
from rr30_seams import frame_report,report
from cutout_pipeline.cases import read_json,digest
from humanoid_cutout.source_space import DetachedSource
from maquette_motion import pixels
from maquette_motion.pixels import rest_identity

PROOF_TIMEOUT_SECONDS=180
CPU_OBSERVATIONS={'front':{'lob':[33,67],'scatter':[39]},
                  'rear':{'lob':[59,60],'brace':[4,7,8,47,48,50]}}


class NonBlockingTests(unittest.TestCase):
    def test_cli_keeps_failed_and_unavailable_reports_without_blocking(self):
        with tempfile.TemporaryDirectory(prefix='rr31-diagnostic-') as folder:
            output=Path(folder)
            failure=dict(ok=False,frames=1,passed=0,failed=1,rows=[{'ok':False}])
            with mock.patch.object(diagnostic,'OUTPUT',output),mock.patch.object(sys,'argv',['rr31_images.py','cpu']):
                with mock.patch.object(diagnostic,'cpu_report',return_value=failure):
                    self.assertEqual(diagnostic.main(),0)
                    record=read_json(output/'proof/cpu.json')
                    self.assertFalse(record['ok'])
                    self.assertFalse(record['blocking'])
                    self.assertEqual(record['failed'],1)
                with mock.patch.object(diagnostic,'cpu_report',side_effect=ValueError('stale proof fixture')):
                    self.assertEqual(diagnostic.main(),0)
                    record=read_json(output/'proof/cpu.json')
                    self.assertTrue(record['unavailable'])
                    self.assertFalse(record['ok'])
                    self.assertFalse(record['blocking'])

    def test_driver_ignores_only_images_and_keeps_native_gate_blocking(self):
        with tempfile.TemporaryDirectory(prefix='rr31-dispatch-') as folder:
            root=Path(folder);shim=root/'python3';log=root/'commands.jsonl'
            shim.write_text('#!'+sys.executable+'\nimport json,os,sys\n'
                'with open(os.environ["RR31_COMMAND_LOG"],"a") as out: out.write(json.dumps(sys.argv[1:])+"\\n")\n'
                'if sys.argv[1:3]==["experiments/cutouts/slag_mortar/rr31_images.py","native"]: sys.exit(1)\n'
                'if sys.argv[1]=="experiments/cutouts/slag_mortar/rr30_gates.py": sys.exit(int(os.environ.get("RR31_NATIVE_FAIL","0")))\n')
            shim.chmod(0o755)
            env=dict(os.environ,PATH=str(root)+os.pathsep+os.environ['PATH'],
                     RR31_COMMAND_LOG=str(log),LABYRINTH_TASK_ID='rr-31')
            driver=['sh','experiments/cutouts/slag_mortar/rr30_proof.sh']
            for native_status in ('0','1'):
                run=subprocess.run(driver+['native'],cwd=PROJECT,env=dict(env,RR31_NATIVE_FAIL=native_status),
                    capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
                self.assertEqual(run.returncode,int(native_status),run.stdout+run.stderr)
            for stage in ('sheets','production','review'):
                run=subprocess.run(driver+[stage],cwd=PROJECT,env=env,capture_output=True,text=True,
                    timeout=PROOF_TIMEOUT_SECONDS)
                self.assertEqual(run.returncode,0,run.stdout+run.stderr)
            commands=[json.loads(line) for line in log.read_text().splitlines()]
            self.assertTrue(any(c[:3]==['-m','humanoid_cutout.proof','sheets'] for c in commands))
            self.assertTrue(any(c[:3]==['-m','humanoid_cutout.proof','review'] for c in commands))
            self.assertTrue(any(c[0]=='tools/capture_gate_runner.py' for c in commands))


class SourceSeamTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        mortar_tests.MortarV2Tests.setUpClass.__func__(cls)

    def model(self,view,disable=False):
        layout=read_json(CASE/f'layouts/{view}.json')
        model=CpuPose(CASE,layout)
        model.detached_source=DetachedSource(CASE,layout)
        if disable:
            repair=read_json(diagnostic.OUTPUT/'feedback2_source_fixes.json')
            for name,row in repair['views'][view]['additions'].items():
                part=next(p for p in layout['parts'] if p['name']==name)
                image=model.image(part['file']).copy()
                for x,y,_,_ in row['texels']:image[y,x]=0
                model.images[part['file']]=image
        return model

    def test_all_eleven_cpu_observations_are_clean(self):
        count=0
        for view,clips in CPU_OBSERVATIONS.items():
            model=self.model(view)
            for clip,frames in clips.items():
                for frame in frames:
                    pose=next(p for p in self.samples['samples'] if
                        (p['view'],p['clip'],p['frame'],p['kind'])==(view,clip,frame,'presented'))
                    _,holes,metrics,_,_=frame_report(model,pose)
                    self.assertEqual(holes,[],(view,clip,frame))
                    self.assertEqual(metrics['stray_pixels'],0,(view,clip,frame))
                    count+=1
        self.assertEqual(count,11)
        print('RR31 SEAM CPU TARGETS: PASS (11/11 clean)',flush=True)

    def test_removing_source_covers_restores_both_native_failure_regions(self):
        for view,clip,frame in [('front','lob',33),('rear','brace',7)]:
            model=self.model(view,disable=True)
            pose=next(p for p in self.samples['samples'] if
                (p['view'],p['clip'],p['frame'],p['kind'])==(view,clip,frame,'presented'))
            _,holes,_,_,_=frame_report(model,pose)
            self.assertTrue(holes,(view,clip,frame))
        print('RR31 SEAM MUTATION: CAUGHT (front shoulder and rear upper-arm covers removed)',flush=True)

    def test_all_legal_native_uv_choices_cover_the_seven_observed_holes(self):
        fixture=read_json(diagnostic.OUTPUT/'feedback2_native_targets.json')
        for target in fixture['targets']:
            model=self.model(target['view'])
            part=next(p for p in model.layout['parts'] if p['name']==target['piece'])
            paint=model.image(part['file'])
            from humanoid_cutout.gates import matrix
            samples=pixels.render(paint,matrix(target['transform']),with_ties=True)
            x,y=target['destination']
            self.assertTrue(all(candidate[y,x,3]==255 for candidate in samples.candidates),target)
        self.assertEqual(len(fixture['targets']),7)
        print('RR31 NATIVE-POSE SOURCE COVERAGE: PASS (7/7 holes covered for every legal UV tie; CPU source replay)',flush=True)

    def test_image_failure_cannot_fail_cpu_acceptance(self):
        layout=read_json(CASE/'layouts/front.json')
        pose=next(p for p in self.samples['samples'] if
            (p['view'],p['clip'],p['frame'],p['kind'])==('front','idle',0,'presented'))
        diagnostic_failure=dict(ok=False,errors=[{'metric':'notches'}],interior_contour=[])
        with mock.patch.object(diagnostic.ImageGate,'frame',return_value=diagnostic_failure):
            result=report(layout,dict(samples=[pose]))
        self.assertEqual(result['errors'],[])
        self.assertTrue(result['ok'])
        self.assertFalse(result['image_gates']['ok'])
        self.assertFalse(result['image_gates']['blocking'])
        with mock.patch.object(diagnostic.ImageGate,'frame',side_effect=ValueError('diagnostic fixture')):
            unavailable=report(layout,dict(samples=[pose]))
        self.assertEqual(unavailable['errors'],[])
        self.assertTrue(unavailable['ok'])
        self.assertFalse(unavailable['image_gates']['ok'])

    def test_visible_cuts_and_both_rests_are_unchanged(self):
        before=read_json(diagnostic.OUTPUT/'feedback2_source_fixes.json')['source_hashes_before']
        for view in ('front','rear'):
            layout=read_json(CASE/f'layouts/{view}.json')
            for part in layout['parts']:
                if not part['hidden_material']:self.assertEqual(digest(CASE/part['file']),before[part['file']])
        result=rest_identity(CASE)
        self.assertTrue(result['ok'],result)
        self.assertEqual([r['different_pixels'] for r in result['views'].values()],[0,0])


if __name__=='__main__':unittest.main()
