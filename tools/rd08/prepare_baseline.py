"""Extract exact 14a369b61 sources in a disposable directory without Git writes."""
from pathlib import Path
import shutil
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '/private/tmp/labyrinth_codex/rd-08/base-14a369b61'


def main():
    target = Path(BASE)
    if target.exists():
        raise SystemExit(f'Preserving existing baseline: {target}; use a fresh directory or remove it deliberately')
    target.mkdir(parents=True)
    process = subprocess.Popen(['git', 'archive', '14a369b61'], cwd=ROOT, stdout=subprocess.PIPE)
    with tarfile.open(fileobj=process.stdout, mode='r|') as archive:
        archive.extractall(target)
    assert process.wait() == 0
    # Proof harness only: it uses APIs present on the baseline, never newer product code.
    for relative in ['tools/rd08/performance.gd', 'tools/rd08/native_capture.sh',
                     'tools/rd08/check_capture_log.py', 'tools/rd04/real_fixture.gd']:
        destination = target / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / relative, destination)
    # Approved cel assets are the identical input for A and B.
    shutil.copytree(ROOT / 'cel_look_variants', target / 'cel_look_variants', dirs_exist_ok=True)
    (target / '.rd08-baseline').write_text(subprocess.check_output(
        ['git', 'rev-parse', '14a369b61'], cwd=ROOT, text=True))
    print(f'RD08 EXACT BASELINE: PASS; {target}')


if __name__ == '__main__':
    main()
