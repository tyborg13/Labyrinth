"""Pair exact caption moments from the two six-seed descents."""
import argparse
import json
from pathlib import Path
from statistics import median

SEEDS = range(30001, 30007)
KINDS = ("body", "health", "intent", "tiles")
LEGACY = {
    "30005-04-04-enemy_action-07": "Tunnel Crawler: Skitter Strike",
    "30003-03-01-enemy_action-01": "Unknown Presence: Advance",
}


def rows(path):
    return [json.loads(line) for line in path.read_text().splitlines()]


def write_selection(path, selected):
    path.write_text(json.dumps(selected, indent=2) + "\n")


def legacy(output):
    write_selection(output / "legacy.json", [
        {"key": key, "seed": int(key.split("-")[0]), "text": text, "rank": rank}
        for rank, (key, text) in enumerate(LEGACY.items(), 1)
    ])


def collect(output, side):
    captions = {}
    legacy_rows = {}
    for seed in SEEDS:
        folder = output / side / str(seed)
        runs = rows(folder / "runs.jsonl")
        if not runs or runs[-1].get("end") != "recap":
            raise ValueError(f"{side} seed {seed} did not reach recap")
        for row in rows(folder / "moments.jsonl"):
            lookup = legacy_rows if row.get("legacy") else captions
            if row["key"] in lookup:
                raise ValueError(f"Duplicate {side} moment {row['key']}")
            lookup[row["key"]] = row
    for key, expected in LEGACY.items():
        if legacy_rows.get(key, {}).get("text") != expected:
            raise ValueError(f"{side} missed fel-30 frame {key} with caption {expected!r}")
    return captions


def summarize(output):
    release = collect(output, "release")
    branch = collect(output, "branch")
    if release.keys() != branch.keys() or not release:
        raise ValueError(f"Different caption boundaries. Release-only {list(release.keys() - branch.keys())[:8]}, branch-only {list(branch.keys() - release.keys())[:8]}")

    counts_before = dict.fromkeys(KINDS, 0)
    counts_after = dict.fromkeys(KINDS, 0)
    covers_before = covers_after = fallback = clear = moved_clear = placed = hud_errors = 0
    problems = []
    shifts = []
    groups = {}
    cases = [row for row in branch.values() if row["placed"]]
    for key, row in branch.items():
        before = release[key]
        if before["text"] != row["text"] or before["actual_rect"] != row["before_rect"]:
            problems.append(f"{key} changed text, y, size or default x")
        groups.setdefault((row["seed"], row["combat"], row["action"]), []).append(row)
        if not row["placed"]:
            continue
        covered = any(row["before"].values())
        remains = any(row["after"].values())
        covers_before += covered
        covers_after += remains
        fallback += row["fallback"]
        if remains != row["fallback"]:
            problems.append(f"{key} fallback status differs from remaining overlap")
        for kind in KINDS:
            counts_before[kind] += row["before"][kind]
            counts_after[kind] += row["after"][kind]
        if not covered:
            clear += 1
            moved_clear += before["actual_rect"] != row["actual_rect"]
        if row["shift"]:
            placed += 1
            hud_errors += row["hud_overlap"] or not row["inside"]
        shifts.append(abs(row["shift"]))

    print(f"FEL34 OVERLAP captions={len(cases)} covering_before={covers_before} covering_after={covers_after} fallback={fallback} max_shift_px={max(shifts):g} median_shift_px={median(shifts):g}")
    for kind in KINDS:
        print(f"FEL34 COVERS kind={kind} before={counts_before[kind]} after={counts_after[kind]}")
    print(f"FEL34 UNCHANGED clear_at_default={clear} moved={moved_clear} {'FAIL' if moved_clear else 'PASS'}")
    print(f"FEL34 HUD_CLEAR placed={placed} overlaps={hud_errors} {'FAIL' if hud_errors else 'PASS'}")

    multi = [group for group in groups.values() if len(group) > 1
             and (group[0]["kind"] == "player" or len({row["round_zero"] for row in group}) > 1)]
    max_jump = max((jump(group) for group in multi), default=-1)
    print(f"FEL34R1 STABLE_ALL actions={len(multi)} max_jump_px={max_jump:g}")
    selected_stability = [
        group for group in multi if group[0]["seed"] == 30003 and group[0]["combat"] == 2
        and group[0]["text"] == "Tunnel Crawler: Skitter Strike"
        and any(row["kind"] == "melee" and row["round_zero"] == 34 for row in group)
    ]
    extra = []
    if len(selected_stability) == 1:
        witness = selected_stability[0]
        positions = len({row["actual_rect"][0] for row in witness})
        remaining = sum(any(row["after"].values()) for row in witness)
        print(f'FEL34R1 STABLE caption="{witness[0]["text"]}" positions={positions} max_jump_px={jump(witness):g} covers_after={remaining}')
        extra = [next(row for row in witness if row["kind"] == kind) for kind in ("move", "melee")]
        if positions != 1 or remaining:
            problems.append(f"Stability witness failed at {witness[0]['key']}")
    else:
        problems.append(f"Expected one 30003-02 walk and melee witness, got {len(selected_stability)}")
    if max_jump != 0:
        problems.append(f"Multi-step caption changed x by {max_jump}px")

    excluded = {row["key"] for row in extra}
    worst = sorted((row for row in cases if row["severity"] > 0 and row["key"] not in excluded),
                   key=lambda row: (-row["severity"], row["key"]))[:8]
    noctyrax = {"key": "noctyrax-night-coil", "seed": 0, "text": "Night Coil"}
    write_selection(output / "selection.json", [
        {"key": row["key"], "seed": row["seed"], "text": row["text"], "rank": rank}
        for rank, row in enumerate(rows_as_selection(output) + worst + extra + [noctyrax], 1)
    ])
    if not covers_before or not placed or covers_after != fallback or moved_clear or hud_errors or problems:
        raise ValueError(f"Census failed: {problems[:12]}")
    print(f"FEL34 PASS cases={len(cases)}")


def jump(group):
    return max((abs(before["actual_rect"][0] - after["actual_rect"][0])
                for before, after in zip(group, group[1:])), default=0)


def rows_as_selection(output):
    return json.loads((output / "legacy.json").read_text())


def verify_selection(output):
    selected = json.loads((output / "selection.json").read_text())
    keys = {entry["key"] for entry in selected}
    if len(selected) != 13 or len(keys) != 13 or not LEGACY.keys() <= keys or "noctyrax-night-coil" not in keys:
        raise ValueError("Expected both fel-30 frames, eight ranked captions, both crawler steps and Night Coil")
    for rank, entry in enumerate(selected, 1):
        if entry["rank"] != rank or not entry["text"]:
            raise ValueError(f"Missing caption or rank in selection {entry}")


def replay_selection(output):
    verify_selection(output)
    selected = json.loads((output / "selection.json").read_text())
    print(json.dumps([row for row in selected if row["key"] != "noctyrax-night-coil"]))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = {"legacy": legacy, "summarize": summarize, "verify-selection": verify_selection,
                "replay-selection": replay_selection}
    parser.add_argument("command", choices=commands)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    commands[args.command](args.output)


if __name__ == "__main__":
    main()
