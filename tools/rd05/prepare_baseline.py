"""Read-only HEAD comparison in task-local temporary outputs; no Git mutation."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path('/private/tmp/labyrinth_codex/rd-05/baseline')
OWNED = ('scripts/combat_board_view.gd', 'scripts/run_scene.gd',
         'scripts/settings_store.gd', 'scripts/settings_panel.gd',
         'scripts/turn_order_slots.gd')


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    (OUTPUT / '.gdignore').touch()
    for entry in ROOT.iterdir():
        if entry.name in ('.git', 'scripts', 'tools'):
            continue
        target = OUTPUT / entry.name
        if not target.exists():
            target.symlink_to(entry, target_is_directory=entry.is_dir())
    for folder in ('scripts', 'tools'):
        (OUTPUT / folder).mkdir(exist_ok=True)
        for entry in (ROOT / folder).iterdir():
            relative = str(entry.relative_to(ROOT))
            target = OUTPUT / relative
            if relative in OWNED:
                target.write_bytes(subprocess.check_output(['git', 'show', 'HEAD:' + relative], cwd=ROOT))
            elif not target.exists():
                target.symlink_to(entry, target_is_directory=entry.is_dir())
    print('RD05 baseline prepared from HEAD: ' + str(OUTPUT))


if __name__ == '__main__':
    main()
