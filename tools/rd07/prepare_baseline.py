"""Prepare a read-only HEAD comparison; never change the checkout or Git state."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-07/baseline')
OWNED = {Path(name).name for name in subprocess.check_output(
    ["git", "diff", "--name-only", "--", "scripts"], cwd=ROOT, text=True).splitlines()}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / '.gdignore').touch()
    for entry in ROOT.iterdir():
        if entry.name in ('.git', 'scripts'):
            continue
        target = OUTPUT / entry.name
        if not target.exists():
            target.symlink_to(entry, target_is_directory=entry.is_dir())
    (OUTPUT / 'scripts').mkdir(exist_ok=True)
    for entry in (ROOT / 'scripts').iterdir():
        target = OUTPUT / 'scripts' / entry.name
        if entry.name in OWNED:
            target.write_bytes(subprocess.check_output(['git', 'show', 'HEAD:scripts/' + entry.name], cwd=ROOT))
        elif not target.exists():
            target.symlink_to(entry, target_is_directory=entry.is_dir())
    print('RD07 HEAD baseline prepared: ' + str(OUTPUT))


if __name__ == '__main__':
    main()
