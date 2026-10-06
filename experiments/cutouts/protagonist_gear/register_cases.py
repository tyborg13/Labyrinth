#!/usr/bin/env python3
"""Register the brief's stand-ins once, after three fresh seed-protagonist calls."""
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT.parents[2]
sys.path.insert(0, str(PROJECT / "tools"))
from cutout_pipeline.assets import replace_part
from cutout_pipeline.cases import baseline, read_json, write_json
from PIL import Image


def main():
    registry = read_json(PROJECT / "assets/units/protagonist_cutout/gear_visuals.json")
    for case_name, item_id, clip, frames, duration in [
        ("heavy_v01", "war_maul", "attack_heavy", 43, 0.72),
        ("stab_v01", "sawtooth_knife", "attack_stab", 24, 0.40),
        ("shield_v01", "splintered_shield", "block_shield", 25, 0.30),
    ]:
        case = ROOT / case_name
        source = case / "source"
        source.mkdir()  # Refuse to replace an authored case's provenance.
        shutil.copyfile(case / "motion.gd", source / "seed_motion.gd")
        shutil.copyfile(case / "cutout.json", source / "seed_cutout.json")
        config = read_json(case / "cutout.json")
        # The seed snapshots live idle/walk/sword playback; preserve those.
        # Expose the other already-seeded sampler actions with their own timing.
        for name, count, seconds in [
            ("hit", 25, 0.36), ("block", 25, 0.30), ("death", 41, 0.64232),
            ("cast", 48, 0.92), ("shoot", 36, 0.44),
        ]:
            config["clips"][name] = {"frames": count, "duration": seconds, "loop": False}
        config["clips"][clip] = {
            "frames": frames, "duration": duration, "loop": False,
            "phase_curve": [[0.0, 0.0], [1.0, 1.0]],
        }
        config["rigid_bones"] += ["hand_r", "hand_l", "weapon_r", "weapon_l"]
        registration = {"item": item_id, "registry": "assets/units/protagonist_cutout/gear_visuals.json", "facings": {}}
        for facing, operations in registry["items"][item_id]["facings"].items():
            layout_path = case / config["layouts"][facing]
            shutil.copyfile(layout_path, source / (facing + "_seed.json"))
            if "replace" in operations:
                part = operations["replace"][0]
                replace_part(case, facing, "weapon_r",
                             PROJECT / "assets/units/protagonist_cutout" / part["file"],
                             tuple(part["offset"]))
                layout = read_json(layout_path)
                layout["weapon_grip"] = operations["weapon_grip"]
            else:
                attachment = operations["attach"][0]
                file = "assets/gear/splintered_shield/" + Path(attachment["file"]).name
                target = case / file
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(PROJECT / "assets/units/protagonist_cutout" / attachment["file"], target)
                Path(str(target) + ".import").write_text('[remap]\n\nimporter="keep"\n')
                layout = read_json(layout_path)
                # A child pivot follows the forearm exactly in accepted actions.
                # Only block_shield counter-rotates about the painted centre:
                # rear guard IK cannot also keep a directly parented shield upright.
                joint = layout["joints"]["forearm_l"]
                layout["joints"]["gear_offhand_mount"] = {
                    "parent": "forearm_l", "position": joint["position"],
                }
                layout["parts"].append({
                    "name": "gear_offhand", "bone": "gear_offhand_mount",
                    "file": file, "offset": attachment["offset"],
                    "z_index": attachment["z_index"], "equipment_slot": "offhand",
                })
                with Image.open(target) as image:
                    layout["gear_offhand_anchor"] = [
                        attachment["offset"][0] + image.width / 2,
                        attachment["offset"][1] + image.height / 2,
                    ]
                layout.pop("rest_source", None)
                layout.pop("rest_source_sha256", None)
            write_json(layout_path, layout)
            registration["facings"][facing] = operations
        write_json(source / "gear_registration.json", registration)
        config["sources"] = ["source/seed_motion.gd", "source/seed_cutout.json",
                             "source/front_seed.json", "source/rear_seed.json", "source/gear_registration.json"]
        write_json(case / "cutout.json", config)
        # Retain the seed hash record; register only the deliberate gear changes
        # as the art baseline protected during motion authoring.
        shutil.copyfile(case / "baseline.sha256.json", source / "seed.sha256.json")
        baseline(case)
        print("GEAR_CASE_REGISTERED: " + case_name)


if __name__ == "__main__":
    main()
