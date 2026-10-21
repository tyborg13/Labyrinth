"""Certification failure and exact owner-driver wiring; no windowed execution."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import shutil
from unittest import mock

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/slag_mortar')]
import rr30_identity as identity
import visual_probe_runner as probe
import rr30_density as density

PROOF_TIMEOUT_SECONDS=180


class IdentityCertificationTests(unittest.TestCase):
    def test_failed_certification_cannot_persist_director_pass(self):
        entries=[dict(facing=view,judge=dict(verdict='PASS')) for view in ('front','rear')]
        with mock.patch.object(identity,'certify',side_effect=ValueError('chroma over limit')) as certify, \
             mock.patch.object(identity,'write_json') as write, \
             mock.patch.object(identity,'replace_entries') as replace:
            with self.assertRaisesRegex(ValueError,'CERTIFICATION: FAIL; director verdict not recorded'):
                identity.record_certified(entries)
        certify.assert_called_once_with(entries)
        self.assertEqual(len(write.call_args_list),2)
        self.assertTrue(all(c.args[1]['verdict']=='FAILED_CERTIFICATION' for c in write.call_args_list))
        self.assertTrue(all(e['judge']['verdict']=='FAILED_CERTIFICATION' for e in replace.call_args.args[0]))

    def test_verdict_is_written_only_after_certification(self):
        events=[]
        entries=[dict(facing=view,judge=dict(verdict='PASS')) for view in ('front','rear')]
        with mock.patch.object(identity,'certify',side_effect=lambda _:events.append('certify')), \
             mock.patch.object(identity,'write_json',side_effect=lambda *_:events.append('write')), \
             mock.patch.object(identity,'replace_entries',side_effect=lambda _:events.append('register')):
            identity.record_certified(entries)
        self.assertEqual(events,['certify','write','write','register'])


class DensityProofTests(unittest.TestCase):
    def test_density_calibration_keeps_untreated_input_separate_from_native_rest(self):
        view='front'
        source=PROJECT/'experiments/cutouts/slag_mortar/rr30/source/front/processed.png'
        native=PROJECT/'assets/units/slag_mortar_cutout/humanoid_v2/front/rest.png'
        expected=identity.read_json(PROJECT/'spec/assets/board_pixel_density/registry.json')
        entry=next(e for e in expected['entries'] if e['id']=='slag_mortar_cutout')
        with tempfile.TemporaryDirectory(prefix='rr30-density-source-') as folder:
            root=Path(folder);case=root/'case';assets=root/'assets';archive=root/'density'
            (case/'source/front').mkdir(parents=True);(assets/'humanoid_v2/front').mkdir(parents=True)
            shutil.copyfile(source,case/'source/front/processed.png')
            shutil.copyfile(native,assets/'humanoid_v2/front/rest.png')
            with mock.patch.multiple(density,PROJECT=root,CASE=case,ASSETS=assets,DENSITY=archive):
                result=density.untreated_rest_calibration(view,entry,refresh_sources=True)
            self.assertEqual(result['orphan_share'],entry['facings'][view]['orphan_share'])
            self.assertEqual(result['grid'],entry['facings'][view]['grid'])
            self.assertEqual((archive/'sources/assets/humanoid_v2/front/rest.png').read_bytes(),source.read_bytes())
            self.assertEqual((assets/'humanoid_v2/front/rest.png').read_bytes(),native.read_bytes())

    def test_exact_density_stage_order_and_visual_command(self):
        # Interpret the real shell driver, replacing only executable dispatch.
        # No source, production rest, native image or proof manifest is written.
        with tempfile.TemporaryDirectory(prefix='rr30-driver-') as folder:
            folder=Path(folder)
            log=folder/'commands.jsonl'
            shim=folder/'python3'
            shim.write_text('#!'+sys.executable+'\nimport json,os,sys\n'
                'with open(os.environ["RR30_COMMAND_LOG"],"a") as out:\n'
                ' out.write(json.dumps(sys.argv[1:])+"\\n")\n')
            shim.chmod(0o755)
            env=dict(os.environ,PATH=str(folder)+os.pathsep+os.environ['PATH'],
                     RR30_COMMAND_LOG=str(log),LABYRINTH_TASK_ID='rr-30')
            result=subprocess.run(['sh','experiments/cutouts/slag_mortar/rr30_proof.sh','density'],
                                  cwd=PROJECT,env=env,capture_output=True,text=True)
            self.assertEqual(result.returncode,0,result.stdout+result.stderr)
            commands=[json.loads(line) for line in log.read_text().splitlines()]
        self.assertEqual(len(commands),6)
        self.assertEqual(commands[0],['tools/process_board_density.py','--only','slag_mortar_cutout'])
        self.assertEqual(commands[2],commands[0]+['--record-rests'])
        self.assertEqual(commands[3],['experiments/cutouts/slag_mortar/rr30_density.py','seal'])
        self.assertEqual(commands[4],['tools/godot_task_runner.py','--task-id','rr-30','--stream','--',
            'godot','--headless','--path','.','--script','tests/rr22/shadow_refresh.gd'])
        self.assertEqual(commands[5],commands[0]+['--check'])
        visual=commands[1]
        self.assertEqual(visual[0],'tools/visual_probe_runner.py')
        separator=visual.index('--')
        args=probe.build_parser().parse_args(visual[1:separator])
        args.probe_args=visual[separator+1:]
        self.assertEqual(args.script,'tests/rr30/density_rebake.gd')
        self.assertFalse(args.headless)
        self.assertEqual(args.expect_size,[(1920,1080)])
        self.assertEqual(args.probe_args,['--only','slag_mortar_cutout'])
        self.assertTrue(args.overwrite_result_manifest)
        self.assertEqual(args.proof_contract,'tests/rr22/density_contract.json')
        contract=probe.load_proof_contract(args.proof_contract)
        pair=next(r for r in contract['required_images'] if r['pattern']=='rr22_density_pair.png')
        self.assertEqual((pair['width'],pair['height']),(1920,1080))
        self.assertIn('1920x1080',contract['expected_sizes'])

    def test_density_probe_loads_fixed_capture_viewport_headless(self):
        result=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-30','--stream','--',
            'godot','--headless','--path','.','--script','tests/rr30/density_rebake.gd','--',
            '--only','slag_mortar_cutout','--validate-only'],cwd=PROJECT,capture_output=True,text=True,
            timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RR30 DENSITY PROBE LOAD: PASS (1920x1080 summary; 255x255 rests; headless structure only)',result.stdout)


if __name__=='__main__': unittest.main()
