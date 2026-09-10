"""Promote this case's explicit production closure; never load experiments at runtime."""
from pathlib import Path
import hashlib
import json
import shutil
import sys

CASE = Path(__file__).resolve().parents[1]
REPO = CASE.parents[3]
PRODUCTION = REPO / "assets/units/bile_bloomer_cutout"
config = json.loads((CASE / "cutout.json").read_text())
proof = CASE / (sys.argv[1] if len(sys.argv) > 1 else "proof")
manifest = {}
for facing, layout_file in config["layouts"].items():
    layout = json.loads((CASE / layout_file).read_text())
    folder = PRODUCTION / facing
    folder.mkdir(parents=True, exist_ok=True)
    mapping = {}
    for part in layout["parts"]:
        source = CASE / part["file"]
        relative = facing + "/" + part["name"] + ".png"
        shutil.copy2(source, PRODUCTION / relative)
        mapping[part["file"]] = relative
        part["file"] = relative
        Path(str(PRODUCTION / relative) + ".import").write_text('[remap]\n\nimporter="keep"\n')
        manifest[relative] = {"case_source": str(source.relative_to(CASE)), "sha256": hashlib.sha256(source.read_bytes()).hexdigest()}
    for mesh in layout["joint_meshes"]:
        mesh["file"] = mapping[mesh["file"]]
    shutil.copy2(proof / (facing + "_rest.png"), folder / "rest.png")
    Path(str(folder / "rest.png") + ".import").write_text('[remap]\n\nimporter="keep"\n')
    layout["rest_source"] = facing + "/rest.png"
    layout["rest_source_sha256"] = hashlib.sha256((folder / "rest.png").read_bytes()).hexdigest()
    (PRODUCTION / (facing + ".json")).write_text(json.dumps(layout, indent=2) + "\n")
script_folder = REPO / "scripts/bile_bloomer_cutout"
script_folder.mkdir(parents=True, exist_ok=True)
shutil.copy2(CASE / "motion.gd", script_folder / "motion.gd")
(CASE / "recipes/production_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
