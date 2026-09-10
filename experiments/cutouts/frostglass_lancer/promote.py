"""Copy this case's selected paint/layouts/motion to its production namespace.

Run after inspecting the case; then rerun native parity and gameplay proof.
No shared registrations, generated source paint or other enemy assets change.
"""
from pathlib import Path
import json
import shutil

PROJECT = Path(__file__).resolve().parents[3]
CASE = Path(__file__).resolve().parent / "v01"
DESTINATION = PROJECT / "assets/units/frostglass_lancer_cutout"
config = json.loads((CASE / "cutout.json").read_text())
for facing, relative in config["layouts"].items():
    folder = DESTINATION / facing
    folder.mkdir(parents=True, exist_ok=True)
    layout = json.loads((CASE / relative).read_text())
    copied = {}

    def copy_paint(value):
        if isinstance(value, dict):
            for key, child in value.items():
                if key == "file":
                    source = CASE / child
                    target = folder / source.name
                    if target.name in copied:
                        assert copied[target.name] == source.read_bytes()
                    else:
                        copied[target.name] = source.read_bytes()
                        shutil.copyfile(source, target)
                        Path(str(target) + ".import").write_text('[remap]\n\nimporter="keep"\n')
                    value[key] = facing + "/" + source.name
                else:
                    copy_paint(child)
        elif isinstance(value, list):
            for child in value:
                copy_paint(child)

    copy_paint(layout)
    (DESTINATION / (facing + ".json")).write_text(json.dumps(layout, indent=2) + "\n")
    # Native parity verifies that the neutral assembly equals this exact source.
    shutil.copyfile(CASE / "source" / (facing + "_registered.png"), folder / "rest.png")
    (folder / "rest.png.import").write_text('[remap]\n\nimporter="keep"\n')
shutil.copyfile(CASE / config["motion"], PROJECT / "scripts/frostglass_lancer_cutout/motion.gd")
print("Promoted selected Frostglass case; native parity/gameplay proof required.")
