"""Promote this reviewed-input candidate; native equality is checked separately.

No experimental path is kept in the production closure. Native neutral bakes
remain explicit inputs, never recomputed from a live texture every frame.
"""
from pathlib import Path
import argparse
import hashlib
import json
import shutil

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
parser = argparse.ArgumentParser()
parser.add_argument("--rest-proof", type=Path, required=True)
args = parser.parse_args()
case = ROOT / "v01"
config = json.loads((case / "cutout.json").read_text())
production = PROJECT / "assets/units/vaeloryx_cutout"
production.mkdir(parents=True, exist_ok=True)
records = {}
for facing, relative in config["layouts"].items():
    layout = json.loads((case / relative).read_text())
    for entry in layout["parts"] + layout["joint_meshes"]:
        source = case / entry["file"]
        target = production / facing / source.name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        Path(str(target) + ".import").write_text('[remap]\n\nimporter="keep"\n')
        records[str(target.relative_to(PROJECT))] = {"case_source": entry["file"], "sha256": hashlib.sha256(target.read_bytes()).hexdigest()}
        entry["file"] = facing + "/" + source.name
    rest = production / facing / "rest.png"
    shutil.copyfile(args.rest_proof / (facing + "_rest.png"), rest)
    Path(str(rest) + ".import").write_text('[remap]\n\nimporter="keep"\n')
    layout["rest_source"] = facing + "/rest.png"
    layout["rest_source_sha256"] = hashlib.sha256(rest.read_bytes()).hexdigest()
    (production / (facing + ".json")).write_text(json.dumps(layout, indent=2) + "\n")
shutil.copyfile(case / "motion.gd", PROJECT / "scripts/vaeloryx_cutout/motion.gd")
(ROOT / "production_promotion.json").write_text(json.dumps({"paint": records, "native_rest_proof": str(args.rest_proof), "verification": "Required separate production-vs-case native comparison and baked-rest equality"}, indent=2) + "\n")
config["sources"] = sorted(set(config["sources"] + [str(p.relative_to(case)) for folder in ["source", "recipes"] for p in (case / folder).rglob("*") if p.is_file()]))
(case / "cutout.json").write_text(json.dumps(config, indent=2) + "\n")
print("Promoted", len(records), "paint files, two layouts and the case motion sampler")
