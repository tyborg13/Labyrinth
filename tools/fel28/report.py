#!/usr/bin/env python3
"""Compare isolated fel-28 takes and encode the director's native review."""

import argparse
import json
from pathlib import Path
import subprocess
from importlib.util import module_from_spec, spec_from_file_location

census_spec = spec_from_file_location("fel20_report", Path(__file__).resolve().parents[1] / "fel20/report.py")
census = module_from_spec(census_spec)
census_spec.loader.exec_module(census)

CASES = ("shadow", "humanoid", "multi", "burst", "terrain", "enemy_turn", "midfight", "reduced")
NATIVE_CASES = ("shadow", "humanoid", "multi", "enemy_turn")
HITCH_MS = 33
LIMIT_MS = 50
# The last sampled death overlay precedes the authored 40 ms settle. At
# 60 fps this leaves three process frames plus the draw-boundary observation.
# Measure phase ordering in frames so dummy-renderer wall-clock stalls do not
# change the result. The native path separately checks all frame intervals.
DEATH_HANDOFF_OBSERVATION_FRAMES = 4
RGB_THRESHOLD = 8
STRIP_FPS = 20
STRIP_COLUMNS = 10


def read(path):
    return json.loads(path.read_text())


def take(root, build, name):
    return read(root / build / name / "take.json")


def emit(case, key, before, after, passed):
    def value(amount):
        return f"{amount:.3f}" if isinstance(amount, float) else str(amount)
    print(f"FEL28 {case} {key} before={value(before)} after={value(after)} {'PASS' if passed else 'FAIL'}")
    return passed


def death_gap(row):
    beats = row["beats"]
    return beats["victory"] - beats["last_death"]


def long_frames(case, build, row):
    phases = {frame["frame_id"]: frame["exclusive_phase_usec"]
              for frame in row["performance"]["top_frames"]}
    for frame, previous in zip(row["frames"], [{}] + row["frames"]):
        if frame["gap_ms"] <= HITCH_MS:
            continue
        parts = []
        for label, frame_id in (("draw frame", frame.get("frame")), ("preceding process frame", previous.get("frame"))):
            work = phases.get(frame_id, {})
            if work:
                ranked = sorted(work, key=work.get, reverse=True)[:3]
                parts.append(label + " " + ", ".join(f"{key}={work[key] / 1000:.2f}ms" for key in ranked))
        cause = " | ".join(parts)
        if not cause:
            cause = f"{frame['phase']} frame; no attributed CPU span"
        if previous.get("capture_ms", 0) >= 0.01:
            cause += f", previous readback/spool={previous['capture_ms']:.2f}ms"
        print(f"FEL28 HITCH {case} {build} t_ms={frame['ms']:.3f} frame_ms={frame['gap_ms']:.3f} {cause}")


def headless(root):
    before_roster, after_roster = (read(root / build / "roster/deaths.json") for build in ("release", "branch"))
    before_clocks = {row["type"]: row for row in before_roster}
    after_clocks = {row["type"]: row for row in after_roster}
    same_deaths = emit("roster", "unchanged_frames", len(before_clocks), len(after_clocks),
                       bool(before_clocks) and before_clocks == after_clocks)
    for name in sorted(before_clocks.keys() | after_clocks.keys()):
        if before_clocks.get(name) != after_clocks.get(name):
            print(f"FEL28 DEATH SAMPLE DIFFERENCE {name}")

    passed = 0
    for case in CASES:
        before, after = (take(root, build, case) for build in ("release", "branch"))
        controlled = bool(after["victims"]) and before["victims"] == after["victims"]
        if case == "multi":
            controlled &= len(after["victims"]) == 2
        if case == "burst":
            controlled &= before["burst_count"] == after["burst_count"] == 2
        if case == "terrain":
            controlled &= before["terrain_seen"] and after["terrain_seen"]
        checks = [emit(case, "fixture", int(bool(before["victims"])), int(controlled), controlled)]
        old_rail, rail = (int(any(frame.get("rail", False) for frame in row["frames"])) for row in (before, after))
        checks.append(emit(case, "rail_reflow", old_rail, rail, rail == (old_rail if case == "midfight" else 0)))
        if case != "midfight":
            old_gap, gap = death_gap(before), death_gap(after)
            old_frames, frames = (row["first_victory_frame"] - row["last_death_frame"] for row in (before, after))
            checks.append(emit(case, "death_to_victory_frames", old_frames, frames,
                               0 < frames <= DEATH_HANDOFF_OBSERVATION_FRAMES))
            print(f"FEL28 HEADLESS HANDOFF {case} release_ms={old_gap:.3f} branch_ms={gap:.3f}")
            old_prepared, prepared = (int(any(frame["phase"] == "victory" and frame.get("prepared", False)
                                               for frame in row["frames"])) for row in (before, after))
            checks.append(emit(case, "prepared_during_victory", old_prepared, prepared, prepared == 1))
        old_ready, ready = (row["ready_ms"] for row in (before, after))
        checks.append(emit(case, "input_to_ready_ms", old_ready, ready, ready > 0))
        for row, build in ((before, "release"), (after, "branch")):
            maximum = max(frame["gap_ms"] for frame in row["frames"])
            print(f"FEL28 HEADLESS TIMING {case} {build} max_frame_ms={maximum:.3f} "
                  f"reveal_start_frame_ms={row['first_reveal_frame_ms']:.3f}")
            long_frames(case, build, row)
        passed += int(all(checks))

    saves = []
    for case in ("shadow", "enemy_turn"):
        for phase in ("death", "victory", "reveal"):
            prefix = "quit" if case == "shadow" else "quit-enemy"
            path = Path(f"{prefix}-{phase}") / "quit-save.json"
            before, after = (read(root / build / path) for build in ("release", "branch"))
            # The existing run_seconds counter samples wall clock play time.
            for state in (before, after):
                state.get("run_stats", {}).pop("run_seconds", None)
            saves.append(emit(case, f"quit_{phase}_save", before.get("mode"), after.get("mode"), bool(before) and before == after))
            if not saves[-1]:
                keys = sorted(key for key in before.keys() | after.keys() if before.get(key) != after.get(key))
                print(f"FEL28 SAVE DIFFERENCES {case} {phase} {' '.join(keys)}")

    pending = read(root / "branch/quit-enemy-checkpoint/quit-save.json")
    checkpoint_take = take(root, "branch", "quit-enemy-checkpoint")
    saves.append(emit("enemy_turn", "quit_in_flight", "reward", pending.get("mode"),
                      checkpoint_take["stopped"] and pending.get("mode") == "reward"
                      and pending.get("pending_reward", {}).get("intro_pending", False)
                      and not pending.get("pending_combat_checkpoints", [])))
    outcome = same_deaths and passed == len(CASES) and all(saves)
    print(f"FEL28 {'PASS' if outcome else 'FAIL'} cases={passed}/{len(CASES)}" if not outcome else f"FEL28 PASS cases={passed}")
    return 0 if outcome else 1


def read_regions(raw, index, regions):
    result = []
    for x, y, width, height in regions:
        for line in range(y, y + height):
            raw.seek(index * census.RGBA_BYTES + (line * census.SIZE[0] + x) * 4)
            result.append(raw.read(width * 4))
    return result


def changed(left, right):
    return any(abs(a - b) > RGB_THRESHOLD for row_a, row_b in zip(left, right)
               if row_a != row_b for index, (a, b) in enumerate(zip(row_a, row_b)) if index % 4 != 3)


def estimate_empty_tile(row, source):
    """Compare actor regions with the last clean pre-VICTORY board.

    This is a take estimate. The paired, authored-frame sweep supplies the
    per-subject counterfactual and checks reference stability independently.
    """
    regions = row.get("death_regions", [])
    frames = row["frames"]
    if not regions:
        return -1
    victory = next(i for i, frame in enumerate(frames) if frame["phase"] == "victory")
    blank = victory - 1
    if frames[blank]["progress"] not in (-1, 1):
        return -1
    with source.open("rb") as raw:
        clean = read_regions(raw, blank, regions)
        for i in range(blank - 1, -1, -1):
            if changed(read_regions(raw, i, regions), clean):
                return round(frames[victory]["ms"] - frames[i]["ms"])
    return -1


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y", *map(str, args)], check=True)


def native(root):
    passed = True
    for case in NATIVE_CASES:
        case_media = []
        for build in ("release", "branch"):
            directory = root / build / case
            path = directory / "spool/00001/record.json"
            row = read(path)
            empty = estimate_empty_tile(row, path.parent / "frames.rgba")
            maximum = max(frame["gap_ms"] for frame in row["frames"])
            print(f"FEL28 NATIVE {case} {build} ready_ms={round(row['ready_ms'])} empty_tile_ms={empty} max_moving_frame_ms={round(maximum)}")
            long_frames(case, build, row)
            if build == "branch": passed &= maximum <= LIMIT_MS and empty >= 0
            census.convert_capture(path, directory)
            case_media.append(directory / "00001-kill.reward.mp4")
        pair = root / f"{case}-side-by-side.mp4"
        ffmpeg("-i", case_media[0], "-i", case_media[1],
               "-filter_complex", "[0:v]setsar=1[left];[1:v]setsar=1[right];[left][right]hstack[v];"
               "[0:a]pan=stereo|c0=c0|c1=0*c1[old];[1:a]pan=stereo|c0=0*c0|c1=c1[new];"
               "[old][new]amix=inputs=2:normalize=0[a]",
               "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", pair)
        duration_seconds = max(take(root, build, case)["ready_ms"] for build in ("branch", "release")) / 1000
        count = int(duration_seconds * STRIP_FPS) + 1
        rows = (count + STRIP_COLUMNS - 1) // STRIP_COLUMNS
        ffmpeg("-i", pair, "-vf",
               f"fps={STRIP_FPS},scale=640:-2,tile={STRIP_COLUMNS}x{rows}:nb_frames={count}:padding=2",
               "-frames:v", 1, "-update", 1, root / f"{case}-20fps.png")
    return 0 if passed else 1


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("headless", "native"))
    parser.add_argument("root", type=Path)
    config = parser.parse_args()
    raise SystemExit((headless if config.mode == "headless" else native)(config.root))
