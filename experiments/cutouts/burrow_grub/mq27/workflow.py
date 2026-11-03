"""Staged rr55 proof. Windowed stages are executed only by the design owner."""
import argparse
import subprocess
from prepare import *

PROOF_DEFAULTS = {'rest_timeout_seconds': 120, 'action_timeout_seconds': 900}
PRODUCTION_CEL_MODE = 'all'  # rr55 brief; isolated rest/native/sheets stay off.


def run(*args, cel='off'):
    import os
    subprocess.run([sys.executable, *map(str,args)], cwd=PROJECT,
        env=dict(os.environ, LABYRINTH_CEL_LOOK=cel), check=True)


def gates_command(command, input_path=None, output=None):
    import argparse
    with adapters(), patch.object(sys, 'argv', ['rr12_gates.py', command, '--creature', CREATURE]
        + (['--input', str(input_path)] if input_path else [])
        + (['--output', str(output)] if output else [])):
        if gates.main(): raise CutoutError(command + ' gates failed')


def headless():
    with adapters():
        sample(CASE, 'samples')
        sample(CASE)
    gates_command('motion')
    gates_command('pixels')
    run(CASE/'sweep.py')


def native():
    directory = CASE/'proof/native'
    run('tools/godot_task_runner.py', '--task-id','rr-55','--stream','--','godot','--headless','--path','.',
        '--script','tests/maquette_cutout/pixel_samples.gd','--','--case',CASE,'--output',directory/'pixel_samples.json')
    run('tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',PROOF_DEFAULTS['action_timeout_seconds'],'--expect-size','1920x1080','--proof-contract','tests/rr12/burrow_grub_render_contract.json',
        'tests/maquette_cutout/native_capture.gd','--','--case',CASE,'--output',directory)
    gates_command('native',directory,directory/'verification.json')


def sheets():
    gates_command('review',CASE/'proof/native',CASE/'proof/burrow_grub_review.mp4')
    run('experiments/cutouts/burrow_grub/rr12_contacts.py','--capture',CASE/'proof/native','--output',CASE/'proof/contact_sheets')


def rest():
    run('tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',PROOF_DEFAULTS['rest_timeout_seconds'],'--expect-size','1920x1080','--proof-contract','tests/rr12/rest_contract.json',
        'tests/maquette_cutout/native_capture.gd','--','--case',CASE,'--output',CASE/'proof/native_rest','--rest-only')


def density():
    run('tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',PROOF_DEFAULTS['rest_timeout_seconds'],'--expect-size','255x255','--proof-contract','tests/rr12/burrow_grub_density_contract.json',
        'tools/rebake_cutout_rests.gd','--','--only','burrow_grub_cutout')
    run('tools/process_board_density.py','--only','burrow_grub_cutout','--record-rests')
    density_resume()


def density_resume():
    """Resume after a successful native rebake and recorded rests, headlessly.

    The seal verifies the existing part/rest records before any follow-up;
    this stage never rebakes, adopts, processes paint or records new rests.
    """
    run(CASE/'promote.py','seal')
    run('tools/godot_task_runner.py','--task-id','rr-55','--stream','--','godot','--headless','--path','.',
        '--script',CASE/'cache_refresh.gd')
    run('tools/process_board_density.py','--only','burrow_grub_cutout','--check')
    run('tools/cel_look.py','build','--if-stale')
    run(CASE/'promote.py','pins')


def production_verify():
    """Verify retained production captures without capturing or rebinding them."""
    directory = CASE/'proof/production_native'
    source_bindings = gates.gates.production_bindings

    def expected_bindings(base):
        # The shared rr12 helper fixes source-art proof to off. Production is
        # explicitly captured with all here. Preserve every current file hash
        # and the strict equality check; change only this expected launch mode.
        bindings = source_bindings(base)
        bindings['cel_look_mode'] = PRODUCTION_CEL_MODE
        return bindings

    with patch.object(gates.gates, 'production_bindings', expected_bindings):
        gates_command('production',directory/'frames.json',directory/'verification.json')


def production():
    directory=CASE/'proof/production_native'
    run('tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',PROOF_DEFAULTS['action_timeout_seconds'],'--expect-size','1920x1080','--proof-contract','tests/rr12/burrow_grub_production_contract.json',
        'tests/rr12/production_capture.gd','--','--type',CREATURE,'--output',directory,cel=PRODUCTION_CEL_MODE)
    production_verify()
    import os
    subprocess.run([sys.executable,'tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',str(PROOF_DEFAULTS['rest_timeout_seconds']),'--expect-size','1920x1080','--proof-contract','tests/grb01_ground_contact_probe_contract.json',
        'tests/grb01_ground_contact_probe.gd'],cwd=PROJECT,
        env=dict(os.environ,LABYRINTH_CEL_LOOK=PRODUCTION_CEL_MODE,LABYRINTH_GRB01_PROOF_OUTPUT=str(CASE/'proof/ground_contact')),check=True)
    run('tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',PROOF_DEFAULTS['rest_timeout_seconds'],'--expect-size','1920x1080','--proof-contract',CASE/'surfaces_contract.json',
        CASE/'surfaces.gd',cel=PRODUCTION_CEL_MODE)
    run('tools/visual_probe_runner.py','--task-id','rr-55','--no-headless','--display-driver','macos','--audio-driver','Dummy',
        '--timeout',PROOF_DEFAULTS['rest_timeout_seconds'],'--expect-size','1920x1080','--proof-contract','tests/bestiary_lineup_probe_contract.json',
        'tests/bestiary_lineup_probe.gd',cel=PRODUCTION_CEL_MODE)


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage',choices=['headless','density','density-resume','rest','native','sheets','production','production-verify'])
    args=parser.parse_args()
    (CASE/'proof/native').mkdir(parents=True,exist_ok=True)
    (CASE/'proof/production_native').mkdir(parents=True,exist_ok=True)
    globals()[args.stage.replace('-', '_')]()
