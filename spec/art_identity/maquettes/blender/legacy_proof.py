"""Serial bridge proof for the five mq-02 legacy maquettes, one view per job."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.compatibility import BASELINES, native_report

PROOF_DEFAULTS = {'baseline_ref': '61b0c2f0ba8793db3499038de3d959b1a6f220d4',
                  'root': '/private/tmp/labyrinth_codex/mq-03/round4/compatibility', 'timeout_s': 120}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, default=Path(PROOF_DEFAULTS['root']))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name in ('humanoid', 'gust_shrike'):
        source = subprocess.run(['git', 'show', PROOF_DEFAULTS['baseline_ref'] + ':spec/art_identity/maquettes/' + name + '.py'],
                                cwd=PROJECT, check=True, capture_output=True).stdout
        (args.out / ('legacy_' + name + '.py')).write_bytes(source)
    for name in BASELINES:
        for version in ('legacy', 'shared'):
            source_name = 'gust_shrike' if name == 'gust_shrike' else 'humanoid'
            source = args.out / ('legacy_' + source_name + '.py') if version == 'legacy' else PROJECT / 'spec/art_identity/maquettes' / (source_name + '.py')
            folder = args.out / name / version
            folder.mkdir(parents=True, exist_ok=True)
            for view in ('front', 'rear'):
                receipt = folder / (view + '_bridge.json')
                if receipt.exists() and json.loads(receipt.read_text())['exit'] == 0:
                    continue
                result = run_job(Path(__file__).with_name('legacy_capture.py'),
                                 [name, version, view, source, folder], timeout_s=PROOF_DEFAULTS['timeout_s'])
                receipt.write_text(json.dumps({k: v for k, v in result.items() if k != 'stdout'}, indent=2) + '\n')
                (folder / (view + '.log')).write_text(result['stdout'])
                print(f"LEGACY_CAPTURE: {name} {version} {view} exit={result['exit']} seconds={result['seconds']}", flush=True)
                if result['exit']:
                    return result['exit']
    report = native_report(args.out)
    (args.out / 'compatibility_report.json').write_text(json.dumps(report, indent=2) + '\n')
    passed = all(v['minimum_part_silhouette_iou'] >= .98 and v['max_joint_error_px'] <= 1
                 for figure in report.values() for view, v in figure.items() if view in ('front', 'rear'))
    print('BLENDER_LEGACY_COMPATIBILITY: ' + ('PASS' if passed else 'FAIL'), flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
