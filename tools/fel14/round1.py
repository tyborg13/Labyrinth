"""Compare the pinned round-zero census with the paint-order census and plan replay."""

import argparse
from collections import Counter, defaultdict
import json
from math import ceil, floor
from pathlib import Path
import subprocess

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
BEFORE = "7cd924f52656aa6b5ddeeffc8a547a811343029d"
LOSS = 0.15
MAX_GAIN = 2
NAMED = (2, 3, 4, 7, 8, 9)
CROPS = (2, 7, 8)
STAGE = {"action_caption", "turn_banner", "boss_name", "boss_health", "boss_status"}
CROP_PADDING = 24
CONTROL_MAX = 0.001


def release_census():
    return json.loads(subprocess.check_output(
        ["git", "show", f"{BEFORE}:tools/fel14/census.json"], cwd=ROOT
    ))


def state_id(state):
    beat = state["beat"]
    return state["fixture"], state["phase"], beat.get("number"), tuple(state["samples"])


def label_id(label):
    owner = label["owner"]
    return label["kind"], owner["id"], tuple(owner["tile"]), label["detail"], tuple(label["text"])


def pair_id(a, b):
    return tuple(sorted((label_id(a), label_id(b))))


def label_title(label):
    owner = label["owner"]
    key = owner["id"] or (str(tuple(owner["tile"])) if owner["tile"] else "")
    return " ".join(filter(None, (label["kind"], key, ", ".join(label["text"]) or label["detail"]))).replace("|", r"\|")


def pairs(state):
    labels = state["labels"]
    return [(labels[low], labels[high], area, loss, counts)
            for low, high, area, _, loss, counts in state["pairs"]]


def state_lookup(data):
    return {state_id(state): state for state in data["states"]}


def pair_lookup(state):
    return {pair_id(low, high): (low, high, area, loss, count)
            for low, high, area, loss, count in pairs(state) if area > 0}


def tally(data):
    counted, losses, tops = Counter(), Counter(), defaultdict(Counter)
    for state in data["states"]:
        for low, high, _, loss, count in pairs(state):
            key = tuple(sorted((low["kind"], high["kind"])))
            if count:
                counted[key] += 1
                tops[key][high["kind"]] += 1
            if loss >= LOSS:
                losses[key] += 1
    return counted, losses, tops


def inherited_overlap(low, high):
    """The fixed boss HUD and unchanged ground overlaps may coexist with a control."""
    kinds = {low["kind"], high["kind"]}
    return kinds <= STAGE or (
        kinds <= {"objective_leader", "objective_threshold", "mark_medallion"}
        and all(label["kind"] != "mark_medallion" or not label["text"] for label in (low, high))
    ) or (
        bool(kinds & {"loot_icon", "trap_icon"})
        and bool(kinds & {"loot_icon", "trap_icon", "intent_badge", "intent_tab",
                          "unit_health", "terrain_health", "status_chip", "defense_chip",
                          "leader_crest", "charge_pip", "mark_medallion"})
    )


def make_plan(before, after):
    old_states = state_lookup(before)
    new_states = state_lookup(after)
    targets = []
    for rank in CROPS:
        old = before["worst"][rank - 1]
        new = new_states[state_id(old)]
        low, high, _, _, _ = pair_lookup(new)[pair_id(old["lower"], old["upper"])]
        targets.append({"name": f"rank-{rank:02}", "fixture": old["fixture"], "phase": old["phase"],
                        "samples": old["samples"], "beat": old["beat"],
                        "release": [old["lower"], old["upper"]], "branch": [low, high]})
    for fixture in before["fixtures"]:
        candidates = []
        for key, old in old_states.items():
            if old["fixture"] != fixture["id"] or key not in new_states:
                continue
            new = new_states[key]
            old_pairs, new_pairs = pair_lookup(old), pair_lookup(new)
            if old_pairs.keys() != new_pairs.keys():
                continue
            if any(label_id(one[0]) != label_id(new_pairs[pair][0])
                   or not inherited_overlap(one[0], one[1]) for pair, one in old_pairs.items()):
                continue
            candidates.append((bool(old_pairs), old["phase"] != "rest", old["frame"], old))
        if not candidates:
            raise ValueError(f"No control with matching paint for {fixture['id']}")
        excepted, _, _, state = min(candidates, key=lambda row: row[:3])
        targets.append({"name": f"control-{fixture['id']}", "fixture": fixture["id"], "phase": state["phase"],
                        "samples": state["samples"], "beat": state["beat"], "excepted": excepted})
    movie = before["worst"][6]
    return {"stills": targets, "movie": {"fixture": movie["fixture"], "beat": movie["beat"]}}


def compare(before, after):
    old_states = state_lookup(before)
    new_states = state_lookup(after)
    old_counts, old_losses, _ = tally(before)
    new_counts, new_losses, tops = tally(after)
    named_failures = []
    gains = []
    out = [
        "## Round 1", "",
        f"The before census replays the reviewed baseline at `{BEFORE[:9]}`. "
        f"It has {len(before['states'])} frames and {sum(old_counts.values())} collisions. "
        f"The after census has {len(after['states'])} frames and {sum(new_counts.values())} collisions. "
        f"The two runs share {len(old_states.keys() & new_states.keys())} fixture and sample keys.", "",
        "The board now paints plates and chips, intent badges and tabs, tile numerals, expanded intents, "
        "intent result callouts, and floating feedback in that order. "
        "Mark discs and icons stay with board effects. Boss area marks use the shared painter and keep their existing icon-only presentation.", "",
        "A mark disc and its numeral keep a single footprint for the collision matrix. "
        "Text loss tests only ink above the lower label’s readable part. The top-kind column counts after collisions.", "",
        "| Pair | Collisions before | Collisions after | ≥15% loss before | ≥15% loss after | After top kind |",
        "|---|---:|---:|---:|---:|---|",
    ]
    for kinds in sorted(old_counts.keys() | new_counts.keys() | old_losses.keys() | new_losses.keys()):
        if new_losses[kinds] - old_losses[kinds] > MAX_GAIN:
            gains.append((kinds, new_losses[kinds] - old_losses[kinds]))
        top = ", ".join(f"{kind} ({count})" for kind, count in tops[kinds].most_common()) or "—"
        out.append(f"| {' × '.join(kinds)} | {old_counts[kinds]} | {new_counts[kinds]} | "
                   f"{old_losses[kinds]} | {new_losses[kinds]} | {top} |")
    out.extend(["", "### Named cases", "", "| Before rank | Fixture | After frame | Important label | Before loss | After loss |",
                "|---:|---|---:|---|---:|---:|"])
    for rank in NAMED:
        row = before["worst"][rank - 1]
        new = new_states[state_id(row)]
        low, high, _, loss, _ = pair_lookup(new)[pair_id(row["lower"], row["upper"])]
        important = row["lower"]
        important_id = label_id(important)
        after_loss = max((entry[3] for entry in pairs(new) if label_id(entry[0]) == important_id), default=0)
        if after_loss >= LOSS:
            named_failures.append(rank)
        out.append(f"| {rank} | {row['fixture']} | {new['frame']} | {label_title(important)} | "
                   f"{row['text_loss']:.1%} | {after_loss:.1%} |")
    out.extend(["", "### New ≥15% losses", ""])
    crossings = []
    for key, state in new_states.items():
        earlier = pair_lookup(old_states[key]) if key in old_states else {}
        for low, high, _, loss, _ in pairs(state):
            if loss < LOSS:
                continue
            old = earlier.get(pair_id(low, high))
            old_loss = old[3] if old and label_id(old[0]) == label_id(low) else 0.0
            if old_loss < LOSS:
                crossings.append((state, low, high, old_loss, loss))
    if gains:
        out.append("Pair types above the allowed gain of two instances " +
                   ", ".join(f"`{' × '.join(key)}` (+{gain})" for key, gain in gains) + ".")
    else:
        out.append("Every pair type gained at most two instances.")
    out.extend(["", "| Fixture | After frame | Phase | Lower label | Upper label | Before loss | After loss |",
                "|---|---:|---|---|---|---:|---:|"])
    for state, low, high, before_loss, loss in crossings:
        out.append(f"| {state['fixture']} | {state['frame']} | {state['phase']} | {label_title(low)} | "
                   f"{label_title(high)} | {before_loss:.1%} | {loss:.1%} |")
    out.extend(["", "### New worst 15", "", "| Rank | Fixture | Frame | Phase | Lower label | Upper label | Text loss |",
                "|---:|---|---:|---|---|---|---:|"])
    for row in after["worst"]:
        out.append(f"| {row['rank']} | {row['fixture']} | {row['frame']} | {row['phase']} | "
                   f"{label_title(row['lower'])} | {label_title(row['upper'])} | {row['text_loss']:.1%} |")
    plan = make_plan(before, after)
    exceptions = [target["fixture"] for target in plan["stills"] if target.get("excepted")]
    out.extend(["", "### Renderer controls", "",
                "The selected control is overlap-free wherever the sampled cohort supplies one. "
                "The following fixtures only supply controls with fixed stage HUD, unchanged objective and mark icons, or out-of-scope ground overlap "
                "and no change in paint order across those overlaps.", ""])
    out.extend(f"- {fixture}" for fixture in exceptions)
    out.extend(["", "Run `tools/fel14/native.sh` from this worktree to capture both sides. "
                "The release-side project is an isolated copy at the reviewed round-zero ref. "
                "The script writes the 2× paired crops, raw control frames, a pixel-difference report, "
                "and `rank-07-enemy-turn.mp4` under `tools/fel14/captures/round1-native.*/`. "
                "Each control is checked against the 0.1% pixel-difference limit."])
    print(f"FEL14 ROUND 1 COMPARE named={len(NAMED) - len(named_failures)}/{len(NAMED)} "
          f"crossings={len(crossings)} pair_types_above_limit={len(gains)} controls={len(plan['stills']) - len(CROPS)}")
    return "\n".join(out) + "\n", plan, not named_failures and not gains


def native_pairs(directory):
    from PIL import Image, ImageChops

    plan = json.loads((directory / "plan.json").read_text())
    failed = False
    rows = []
    for shot in plan["stills"]:
        name = shot["name"]
        frames = [Image.open(directory / side / f"{name}.png").convert("RGBA")
                  for side in ("release", "branch")]
        if any(frame.size != (1920, 1080) for frame in frames):
            raise ValueError(f"{name} capture is not 1920×1080")
        if name.startswith("control-"):
            difference = ImageChops.difference(*frames)
            changed = sum(any(rgb) for rgb in difference.getdata())
            fraction = changed / (1920 * 1080)
            rows.append(f"{name}: {changed} changed pixels ({fraction:.4%})")
            failed = failed or fraction > CONTROL_MAX
            continue
        rects = [label["rect"] for side in ("release", "branch") for label in shot[side]]
        crop = (max(0, floor(min(r[0] for r in rects)) - CROP_PADDING),
                max(0, floor(min(r[1] for r in rects)) - CROP_PADDING),
                min(1920, ceil(max(r[0] + r[2] for r in rects)) + CROP_PADDING),
                min(1080, ceil(max(r[1] + r[3] for r in rects)) + CROP_PADDING))
        width, height = (crop[2] - crop[0]) * 2, (crop[3] - crop[1]) * 2
        joined = Image.new("RGB", (width * 2, height))
        for index, frame in enumerate(frames):
            joined.paste(frame.crop(crop).resize((width, height), Image.Resampling.NEAREST), (width * index, 0))
        joined.save(directory / f"{name}-release-branch-2x.png")
    (directory / "control-pixels.txt").write_text("\n".join(rows) + "\n")
    print("\n".join(rows))
    return not failed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--report", action="store_true")
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--native-pairs", type=Path)
    args = parser.parse_args()
    if args.native_pairs:
        return 0 if native_pairs(args.native_pairs) else 1
    markdown, plan, passed = compare(release_census(), json.loads((HERE / "census.json").read_text()))
    if args.report:
        path = HERE / "result.md"
        original = path.read_text().split("\n## Round 1\n", 1)[0]
        path.write_text(original.rstrip() + "\n\n" + markdown)
    if args.plan:
        args.plan.write_text(json.dumps(plan, indent=2) + "\n")
    return 0 if passed or args.plan else 1


if __name__ == "__main__":
    raise SystemExit(main())
