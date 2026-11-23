#!/usr/bin/env python3
"""Run the same card and board proof against candidate 4 and the pol-71 worktree."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile


HERE = Path(__file__).resolve().parent
WORKTREE = HERE.parent.parent
CANDIDATE_4 = "76aac505bcc3f1f915344a5e7b14e8e20e1e1fae"
OUTPUT_ROOT = Path("/private/tmp/labyrinth_codex/pol-71")
FULL_SIZE = (1920, 1080)
CROP_SIZE = (640, 384)
CAMERA_EPSILON_PX = 0.001
CAMERA_TRACKING_PARTS = {"BoardUnderlay", "CombatObjectiveHud", "CardPlayMeter", "PlayerMovementMeter"}
NATIVE_TIMEOUT_SECONDS = 180
EXPOSE_STRIP_INTERVAL = 4
BUFF_LABELS = {
    "whetstone": ("next_attack", "+4"),
    "hourglass_sand": ("quicken", "+4"),
    "undertaker_stand": ("retaliate", "+5"),
}


def expected_images(shots):
    return [
        {"pattern": name + suffix + ".png", "width": size[0], "height": size[1]}
        for name in shots
        for suffix, size in (("", FULL_SIZE), ("_2x", CROP_SIZE))
    ]


def run_probe(project, output, dry_run):
    output.mkdir()
    script = str(HERE / "capture.gd")
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all")
    if dry_run:
        command = [
            sys.executable, "tools/godot_task_runner.py", "--task-id", "pol-71", "--stream",
            "--", "godot", "--headless", "--path", str(project), "--script", script,
            "--", str(output), "--dry-run",
        ]
    else:
        block_shots = [f"block_confirm_{frame:02d}" for frame in range(0, 49, 2)]
        images = expected_images([*block_shots, "expose_divergent_00", "expose_divergent_delivery"])
        contract = output / "contract.json"
        contract.write_text(json.dumps({
            "min_images": len(images), "expected_sizes": ["1920x1080"],
            "required_images": images,
        }, indent=2) + "\n")
        env["POL71_WINDOWED_ENGINE"] = "1"
        command = [
            sys.executable, "tools/visual_probe_runner.py", script, "--project", str(project),
            "--task-id", "pol-71", "--no-headless", "--display-driver", "macos",
            "--audio-driver", "Dummy", "--godot", str(HERE / "native.sh"),
            "--timeout", str(NATIVE_TIMEOUT_SECONDS), "--proof-contract", str(contract),
            "--result-manifest", str(output / "native.json"), "--", str(output),
        ]
    log = output / "probe.log"
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=WORKTREE, env=env, stdout=stream, stderr=subprocess.STDOUT)
    for line in log.read_text(errors="replace").splitlines():
        if (line.startswith("POL71 gameplay proof:") or line.startswith("Validated ")
                or line.startswith("/") and line.endswith(".png")):
            print(line, flush=True)
    if result.returncode:
        raise ValueError(f"Probe returned {result.returncode}. See {log}")
    receipt = json.loads((output / "receipt.json").read_text())
    if not dry_run:
        case = receipt["cases"]["push_ice_disagreement"]
        shots = [*block_shots, "expose_divergent_delivery"]
        shots.extend(f"expose_divergent_{frame:02d}" for frame in case["expose_strip_frames"])
        manifest = json.loads((output / "native.json").read_text())
        actual = {(Path(image["path"]).name, image["width"], image["height"]) for image in manifest["images"]}
        expected = {(image["pattern"], image["width"], image["height"]) for image in expected_images(shots)}
        require(actual == expected, f"{output}: native strip images or dimensions differ")
    return receipt


def edges(rect):
    x, y, width, height = rect
    return x, y, x + width, y + height


def compare_rects(before, after):
    left, right = before["rest"], after["rest"]
    require(left["geometry"] == right["geometry"] == "1920x1080 SubViewport", "Rest viewport mismatch")
    first, second = left["controls"], right["controls"]
    require(first and first.keys() == second.keys(), f"Rest controls differ: {first.keys() ^ second.keys()}")
    maximum = 0.0
    for path, rect in first.items():
        delta = max(abs(a - b) for a, b in zip(edges(rect), edges(second[path])))
        maximum = max(maximum, delta)
        limit = CAMERA_EPSILON_PX if CAMERA_TRACKING_PARTS.intersection(path.split("/")) else 0.0
        require(delta <= limit, f"Rest edge moved {delta:.4f} px: {path}")
    compare_plates("Rest combat", left["plates"], right["plates"])
    print(f"RECT COMPARISON: PASS ({len(first)} matched paths, maximum edge delta {maximum:.4f} px)")


def compare_plates(name, first, second):
    require(first["chips"] and first["chips"].keys() == second["chips"].keys(), f"{name}: status chips differ")
    rects = [(first[key], second[key]) for key in ("hero_health", "foe_health", "intent_chip")]
    for key, chip in first["chips"].items():
        other = second["chips"][key]
        for measure in ("health_overlap_pct", "intent_overlap_pct", "combined_overlap_pct"):
            require(chip[measure] == other[measure], f"{name}: {key} {measure} changed")
        rects.append((chip["rect"], other["rect"]))
    require(all(abs(a - b) <= CAMERA_EPSILON_PX for left, right in rects
                for a, b in zip(edges(left), edges(right))), f"{name}: HUD plate geometry changed")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify(before, after):
    for receipt in (before, after):
        require(receipt["size"] == list(FULL_SIZE) and receipt["ui_scale"] == 1.0, "Proof viewport or UI scale differs")
    old, new = before["cases"], after["cases"]
    require(old.keys() == new.keys(), "Scenario lists differ")
    for name in old:
        for when in ("before", "final", "events"):
            require(old[name][when] == new[name][when], f"{name}: resolved {when} differs")
    print(f"RULE VALUE GUARD: PASS ({len(old)} scenarios, Health, Block, statuses and surface events identical)")

    for card, (icon, text) in BUFF_LABELS.items():
        for cases in (old, new):
            peak = cases[card]["peaks"]["peak"]
            require((peak["icon"], peak["text"]) == (icon, text), f"{card}: expected existing numeric label")
    print("BUFF LABELS: STALE (3 existing icon-plus-number labels on candidate 4)")

    for name in ("push_fire", "push_fire_collision"):
        base, revised = old[name], new[name]
        loss = base["before"]["enemy_1"]["hp"] - base["final"]["enemy_1"]["hp"]
        contact = sum(event["health_lost"] for event in base["events"] if event["kind"] == "surface_damage")
        require(base["peaks"]["push_peak"]["text"] == f"−{loss}" and "fire_peak" not in base["peaks"], f"{name}: base did not merge the two losses")
        push, fire = (revised["peaks"][tag] for tag in ("push_peak", "fire_peak"))
        require((push["text"], fire["text"], fire["icon"]) == (f"−{loss - contact}", f"−{contact}", "surface_fire"), f"{name}: split values or icon differ")
        require(push["birth"] < fire["birth"], f"{name}: contact did not follow the push")
        base_fire = [cue for cue in base["cues"] if cue["cue"] == "surface.fire"]
        new_fire = [cue for cue in revised["cues"] if cue["cue"] == "surface.fire"]
        require(not base_fire and len(new_fire) == 1 and new_fire[0]["result"] == "played", f"{name}: missing or repeated Fire sound")
        print(f"{name}: {base['peaks']['push_peak']['text']} → {push['text']} then Fire {fire['text']}, surface.fire played once")

    area = new["area_push_fire"]
    area_loss = area["before"]["enemy_1"]["hp"] - area["final"]["enemy_1"]["hp"]
    contacts = [event for event in area["events"] if event["kind"] == "surface_damage"]
    require(len(contacts) == 2 and sum(event["health_lost"] for event in contacts) == area_loss,
            "Area push should lose Health only from the two crossed Fire tiles")
    require(old["area_push_fire"]["peaks"]["push_peak"]["text"] == f"−{area_loss}", "Area push base number differs")
    require(set(area["peaks"]) == {"fire_peak"} and area["peaks"]["fire_peak"]["text"] == f"−{area_loss}",
            "Fire-only push adds an empty push number or drops part of the Fire damage")
    require(sum(cue["cue"] == "surface.fire" and cue["result"] == "played" for cue in area["cues"]) == 1,
            "Fire-only push should play one existing Fire cue")
    print(f"area_push_fire: Fire −{area_loss} across two tiles, one number and one cue")

    verify_handoffs(old, new)
    compare_rects(before, after)
    for direction, shot in before["adjacency"].items():
        compare_plates(direction, shot, after["adjacency"][direction])
        overlap = ", ".join(f"{key}: {value['combined_overlap_pct']:.2f}%" for key, value in shot["chips"].items())
        print(f"WARDEN {direction.upper()}: {overlap}")


def status_samples(case, actor, icon):
    return [sample["values"][actor]["badges"].get(icon, {}) for sample in case["hud_transitions"]]


def verify_handoffs(old, new):
    for name, actor, icon in (("undertaker_stand", "player", "retaliate"), ("push_ice", "enemy_1", "expose")):
        prior, revised = (status_samples(cases[name], actor, icon) for cases in (old, new))
        require(all(prior) and any(badge["popping"] for badge in prior), f"{name}: base status handoff differs")
        require(all(revised) and revised[0]["forecast"] and not revised[-1]["forecast"], f"{name}: status preview did not bridge playback")
        require(not any(badge["popping"] for badge in revised), f"{name}: matching status replayed a pop")
    for cases in (old, new):
        block = cases["undertaker_stand"]
        require(all(sample["values"]["player"]["block"] == block["preview"]["player"]["block"] for sample in block["hud_transitions"]), "Block preview blinked")
    mismatch = "push_ice_disagreement"
    for name, case in new.items():
        if name == mismatch:
            continue
        refreshes = case["commit"]["extra_refreshes"]
        second_pops = 0
        for actor, row in case["preview"].items():
            for icon, badge in row["badges"].items():
                if not badge["forecast"]:
                    continue
                samples = status_samples(case, actor, icon)
                require(all(samples) and samples[0]["forecast"] and not samples[-1]["forecast"],
                        f"{name}: matching {actor} {icon} did not bridge playback")
                second_pops += sum(sample["popping"] for sample in samples)
        print(f"MATCHING {name}: {refreshes} extra commit refreshes, {second_pops} second status pops")
        require(refreshes == 0 and second_pops == 0, f"{name}: matching handoff replayed a refresh or pop")

    for stage, cases in (("before", old), ("after", new)):
        case = cases[mismatch]
        commit = case["commit"]
        initial_value = case["before"]["enemy_1"]["expose"]
        committed_hud = commit["values"]["enemy_1"]
        final_value = case["final"]["enemy_1"]["expose"]
        require(committed_hud["expose"] == initial_value and not committed_hud["badges"].get("expose", {}).get("forecast", False),
                f"{stage}: contradicted Expose survived the synchronous commit")
        if stage == "after":
            require(commit["extra_refreshes"] == 1, "Divergent Expose should trigger one commit refresh")

        samples = case["expose_frames"]
        hover = [sample for sample in samples if sample["frame"] < 0]
        playback = [sample for sample in samples if sample["frame"] >= 0]
        require(hover and hover[-1]["value"] == 3 and hover[-1]["forecast"], f"{stage}: divergent hover fixture did not show Expose 3")
        require([sample["frame"] for sample in playback] == list(range(case["delivery_frame"] + 1)),
                f"{stage}: per-frame Expose trace is incomplete")
        between = [sample for sample in playback[:-1] if sample["engine_frame"] >= commit["engine_frame"]]
        require(between and all(sample["value"] == initial_value and not sample["forecast"] for sample in between),
                f"{stage}: contradicted Expose appeared in playback after commit")
        require(playback[-1]["value"] == final_value and not playback[-1]["forecast"],
                f"{stage}: Expose delivery did not display the resolved value")
        require(case["expose_strip_frames"] == list(range(0, case["delivery_frame"] + 1, EXPOSE_STRIP_INTERVAL)),
                f"{stage}: Expose strip misses a fourth frame")
        print(f"EXPOSE {stage} commit (engine frame {commit['engine_frame']}): "
              f"{committed_hud['expose']}, {commit['extra_refreshes']} extra commit refreshes")
        for sample in samples:
            frame = sample["frame"]
            phase = "hover" if frame < 0 else "delivery" if frame == case["delivery_frame"] else "playback"
            label = sample["label"] or "no pill"
            print(f"EXPOSE {stage} {phase} {frame:+03d}: {sample['value']} ({label})")
    print("PREVIEW HANDOFF: PASS (contradicted Expose pruned at commit, matching previews held without a second pop or extra refresh)")


def git(project, *args):
    return subprocess.check_output(["git", "-C", str(project), *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--before", type=Path, default=WORKTREE.parent / "mrg-15")
    args = parser.parse_args()
    base = args.before.resolve()
    try:
        require(git(base, "branch", "--show-current") == "codex/mrg-15" and git(base, "rev-parse", "HEAD") == CANDIDATE_4,
                f"Expected codex/mrg-15 at {CANDIDATE_4} in {base}")
        # Verify the separate baseline project, leaving its checkout untouched.
        require(not git(base, "status", "--porcelain", "--untracked-files=no"), f"Candidate 4 has tracked edits in {base}")
        output = Path(tempfile.mkdtemp(prefix="headless-" if args.dry_run else "native-", dir=OUTPUT_ROOT))
        print(f"POL71 OUTPUT: {output}", flush=True)
        before = run_probe(base, output / "before", args.dry_run)
        after = run_probe(WORKTREE, output / "after", args.dry_run)
        if args.dry_run:
            verify(before, after)
        else:
            verify_handoffs(before["cases"], after["cases"])
        return 0
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
