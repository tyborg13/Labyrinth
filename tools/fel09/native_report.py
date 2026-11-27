"""Measure consecutive lossless native frames and merge their turn timelines."""

import argparse
from bisect import bisect_left
import csv
import json
from pathlib import Path
import shutil
from statistics import median
from tempfile import TemporaryDirectory

from PIL import Image, ImageChops, ImageDraw

SIZE = (1920, 1080)
PIXELS = SIZE[0] * SIZE[1]
STILL_THRESHOLD_PER_MILLE = 1
MIN_STILL_MS = 150
STRIP_INTERVAL_MS = 50
STRIP_COLUMNS = 4
STRIP_SAMPLE_SIZE = (480, 270)
STRIP_LABEL_HEIGHT = 20
TOP_STRIPS = 3
TOP_ROWS = 10
EXPECTED_FIXTURES = 12
REPORT = Path(__file__).with_name("census.md")
NATIVE_HEADING = "\n## Native renderer measurements\n"
VISIBLE_BEATS = {
    "Pass pressed", "hero input accepted", "terminal outcome", "caption shown", "turn banner shown",
    "turn-order rail", "camera move", "unit move", "attack wind-up", "contact", "impact effect start",
    "number on screen", "death animation", "defeated body held", "death in displayed state", "unit spawned in displayed state",
    "reinforcement arrival animation", "intent callout", "surface effect", "hand draw", "hero turn-start fire",
    "hero fatigue", "ground state changed",
}
BLOCKING_BEATS = {
    "pre-action delay", "post-action settle", "feedback deadline", "dependency wait",
    "hero hand-off drain", "hit stop", "hand draw", "hero turn-start fire", "hero fatigue",
    "unit move", "sampled playback", "floating feedback", "locked hand capture",
    "surface playback", "move hand-off", "defeat playback", "publish hero UI",
}


def write_json(path, data):
    path.write_text(json.dumps(data, indent=2) + "\n")


def changed_pixels(before, after):
    red, green, blue = ImageChops.difference(before, after).split()
    unchanged = ImageChops.lighter(ImageChops.lighter(red, green), blue).histogram()[0]
    return before.width * before.height - unchanged


def is_still(changed):
    return changed * 1000 < PIXELS * STILL_THRESHOLD_PER_MILLE


def still_intervals(frames):
    start = None
    end = None
    for previous, current in zip(frames, frames[1:]):
        if is_still(current["changed_pixels"]):
            if start is None:
                start = previous["ms"]
            end = current["ms"]
        elif start is not None:
            if end - start >= MIN_STILL_MS:
                yield start, end
            start = None
    if start is not None and end - start >= MIN_STILL_MS:
        yield start, end


def visible_edges(events):
    edges = []
    for event in events:
        if event["type"] not in VISIBLE_BEATS:
            continue
        label = event["type"]
        actor = event["actor"]
        detail = event["details"].get("text") or event["details"].get("label") or actor
        if event["start_ms"] == event["end_ms"]:
            edges.append((event["start_ms"], label, detail))
        else:
            edges.append((event["start_ms"], f"{label} begins", detail))
            if not event.get("clipped"):
                edges.append((event["end_ms"], f"{label} ends", detail))
    return sorted(edges)


def describe(edge):
    return {"ms": edge[0], "beat": edge[1], "detail": edge[2]}


def attribute_still(start, end, events, edges):
    before = max((edge for edge in edges if edge[0] <= start), default=(start, "Pass pressed", ""))
    after = min((edge for edge in edges if edge[0] > end), default=(end, "measurement boundary", ""))
    waits = [
        {"name": event["type"], "source": event["source"],
         "overlap_ms": min(end, event["end_ms"]) - max(start, event["start_ms"])}
        for event in events
        if event["type"] in BLOCKING_BEATS and event["start_ms"] < end and event["end_ms"] > start
    ]
    waits.sort(key=lambda wait: -wait["overlap_ms"])
    return {
        "start_ms": start, "end_ms": end, "duration_ms": end - start,
        "before": describe(before), "after": describe(after),
        "holding_wait": waits[0] if waits and waits[0]["overlap_ms"] >= end - start else "unknown",
        "overlapping_waits": waits,
    }


def read_frame(directory, index):
    return Image.frombytes("RGB", SIZE, (directory / f"frame{index:08d}.rgb").read_bytes())


def nearest_frame(stamps, at):
    index = bisect_left(stamps, at)
    if index == len(stamps) or (index and at - stamps[index - 1] < stamps[index] - at):
        return index - 1
    return index


def write_strip(directory, frames, still, path):
    stamps = [frame["ms"] for frame in frames]
    start, end = still["start_ms"], still["end_ms"]
    requests = [(still["before"]["ms"], "before")]
    offset = 0
    while start + offset <= end:
        requests.append((start + offset, "still"))
        offset += STRIP_INTERVAL_MS
    if requests[-1][0] < end:
        requests.append((end, "still end"))
    requests.append((still["after"]["ms"], "after"))

    width, height = STRIP_SAMPLE_SIZE
    cell_height = height + STRIP_LABEL_HEIGHT
    rows = (len(requests) + STRIP_COLUMNS - 1) // STRIP_COLUMNS
    sheet = Image.new("RGB", (STRIP_COLUMNS * width, rows * cell_height))
    labels = ImageDraw.Draw(sheet)
    samples = []
    for output_index, (target, label) in enumerate(requests):
        frame = frames[nearest_frame(stamps, target)]
        image = read_frame(directory, int(frame["index"]))
        image.thumbnail(STRIP_SAMPLE_SIZE, Image.Resampling.LANCZOS)
        row, column = divmod(output_index, STRIP_COLUMNS)
        x, y = column * width, row * cell_height
        sheet.paste(image, (x, y))
        labels.text((x + 4, y + height + 3), f"{label}  {frame['ms']:.1f} ms (target {target:.1f})")
        samples.append({"frame": frame["index"], "ms": frame["ms"], "target_ms": target, "label": label})
    sheet.save(path)
    write_json(path.with_suffix(".json"), samples)


def measure_idle_control(folder, control):
    if not control:
        return {"pairs": 0, "above": 0}
    frames = control["frames"]
    if len(frames) < 2 or control["spool"]["written_frames"] != len(frames):
        raise ValueError(f"Incomplete idle control in {folder}")
    previous = read_frame(folder, 0)
    above = 0
    for index in range(1, len(frames)):
        current = read_frame(folder, index)
        above += int(not is_still(changed_pixels(previous, current)))
        previous = current
    return {"pairs": len(frames) - 1, "above": above, "duration_ms": frames[-1]["ms"]}



def analyze_fixture(folder):
    document = json.loads((folder / "timeline.json").read_text())
    fixture, = document["fixtures"]
    frames = fixture["frames"]
    rgb = folder / "rgb"
    if (document["mode"] != "native" or fixture["fixture"] != folder.name or len(frames) < 2
            or fixture["spool"]["written_frames"] != len(frames)):
        raise ValueError(f"Incomplete native input in {folder}")

    previous = read_frame(rgb, 0)
    idle_pairs = 0
    idle_above = 0
    still_ms = 0.0
    for index, (left, right) in enumerate(zip(frames, frames[1:]), 1):
        if right["ms"] <= left["ms"] or right["index"] != index:
            raise ValueError(f"Nonconsecutive frame metadata in {folder} at {index}")
        current = read_frame(rgb, index)
        count = changed_pixels(previous, current)
        right["changed_pixels"] = count
        if is_still(count):
            still_ms += right["ms"] - left["ms"]
        if index > 1 and not (left["foreground_busy"] or right["foreground_busy"]):
            idle_pairs += 1
            idle_above += int(not is_still(count))
        previous = current

    with (folder / "frame-diffs.csv").open("w", newline="") as target:
        writer = csv.DictWriter(target, fieldnames=["index", "ms", "readback_ms", "foreground_busy", "changed_pixels"])
        writer.writeheader()
        writer.writerows(frames)

    events = fixture["timeline"]
    edges = visible_edges(events)
    runs = [attribute_still(start, end, events, edges) for start, end in still_intervals(frames)]
    runs.sort(key=lambda run: -run["duration_ms"])
    for rank, run in enumerate(runs[:TOP_STRIPS], 1):
        name = f"still-{rank}.png"
        write_strip(rgb, frames, run, folder / name)
        run["strip"] = name
    metrics = {
        "fixture": folder.name, "frame_count": len(frames), "still_ms": still_ms,
        "long_still_ms": sum(run["duration_ms"] for run in runs), "runs": runs,
        "idle_pairs": idle_pairs, "idle_above": idle_above,
        "idle_control": measure_idle_control(folder / "idle-rgb", fixture.get("idle_control")),
        "median_readback_ms": median(frame["readback_ms"] for frame in frames[1:]),
        "median_frame_ms": median(right["ms"] - left["ms"] for left, right in zip(frames, frames[1:])),
        "max_frame_ms": max(right["ms"] - left["ms"] for left, right in zip(frames, frames[1:])),
    }
    write_json(folder / "still.json", metrics)
    shutil.rmtree(rgb)
    if fixture.get("idle_control"):
        shutil.rmtree(folder / "idle-rgb")
    print(f"FEL09 PIXELS PASS fixture={folder.name} frames={len(frames)} still_runs={len(runs)}")


def render_beat_table(rows):
    return [
        "| Beat | Samples | Median (ms) | Max (ms) |",
        "|---|---:|---:|---:|",
        *(f"| {name} | {samples} | {middle:.1f} | {maximum:.1f} |" for name, samples, middle, maximum in rows),
    ]


def beat_metrics(documents):
    samples = {}
    for fixture in documents:
        for event in fixture["timeline"]:
            duration = event["end_ms"] - event["start_ms"]
            if (duration > 0 or event["details"].get("derived")) and not event.get("clipped"):
                samples.setdefault(event["type"], []).append(duration)
    return sorted(
        ((name, len(values), median(values), max(values)) for name, values in samples.items()),
        key=lambda row: (-row[2], row[0]),
    )


def markdown_cell(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def render_timeline(fixture):
    lines = [
        f"### {fixture['fixture']}", "",
        "| Start (ms) | End (ms) | Step | Actor | Beat | Details |",
        "|---:|---:|---:|---|---|---|",
    ]
    for event in sorted(fixture["timeline"], key=lambda event: event["start_ms"]):
        label = event["type"] + (" (clipped)" if event.get("clipped") else "")
        detail = json.dumps(event["details"], ensure_ascii=False) if event["details"] else "—"
        step = event["step"] if event["step"] >= 0 else "—"
        lines.append(f"| {event['start_ms']:.1f} | {event['end_ms']:.1f} | {step} | {event['actor']} | {label} | {markdown_cell(detail)} |")
    return lines + [""]


def merge(folder):
    fixture_dirs = sorted(path.parent for path in folder.glob("*/still.json"))
    if len(fixture_dirs) != EXPECTED_FIXTURES:
        raise ValueError(f"Expected {EXPECTED_FIXTURES} validated fixture results in {folder}")
    results = [json.loads((path / "timeline.json").read_text())["fixtures"][0] for path in fixture_dirs]
    metrics = [json.loads((path / "still.json").read_text()) for path in fixture_dirs]
    all_runs = sorted(
        ((fixture["fixture"], run) for fixture in metrics for run in fixture["runs"]),
        key=lambda entry: -entry[1]["duration_ms"],
    )
    idle_pairs = sum(row["idle_pairs"] for row in metrics)
    idle_above = sum(row["idle_above"] for row in metrics)
    idle_rate = f"{100 * idle_above / idle_pairs:.1f}%" if idle_pairs else "no eligible pairs"
    control_pairs = sum(row["idle_control"]["pairs"] for row in metrics)
    control_above = sum(row["idle_control"]["above"] for row in metrics)
    control_rate = f"{100 * control_above / control_pairs:.1f}%" if control_pairs else "no eligible pairs"
    action_count = sum(row["action_count"] for row in results)
    turns = sum(row["input_accepted"] for row in results)
    rel = folder.relative_to(REPORT.parent)

    lines = [
        NATIVE_HEADING.rstrip(), "",
        f"Native 1920×1080 RGB, 100% UI scale, default Combat speed, reduced motion off and cel look all. [Capture artifacts]({rel.as_posix()}/).",
        "Zero is activation of the production Pass control. Paired images are consecutive post-draw frames. "
        "Readback is synchronous and can affect cadence. The table records measured readback and frame intervals.",
        "", "### Native per fixture", "",
        "| Fixture | Pass to endpoint (ms) | Actions | ms/action | All still (ms) | Still in ≥150 ms runs (ms) | Ambient candidates above threshold | Resting control above threshold | Median frame / readback (ms) | Longest frame gap (ms) | Endpoint |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for result, row in zip(results, metrics):
        count = result["action_count"]
        rate = f"{result['turn_ms'] / count:.1f}" if count else "—"
        endpoint = result["input_witness"] or result["outcome"]
        lines.append(
            f"| [{row['fixture']}]({rel.as_posix()}/{row['fixture']}/still.json) | {result['turn_ms']:.1f} | {count} | {rate}"
            f" | {row['still_ms']:.1f} | {row['long_still_ms']:.1f} | {row['idle_above']}/{row['idle_pairs']}"
            f" | {row['idle_control']['above']}/{row['idle_control']['pairs']}"
            f" | {row['median_frame_ms']:.1f} / {row['median_readback_ms']:.1f} | {row['max_frame_ms']:.1f} | {endpoint} |"
        )
    lines.extend([
        "", f"The settled next-hero-turn idle control exceeded the threshold in **{control_above}/{control_pairs} pairs ({control_rate})**. "
        "This separate resting-board sample measures idle and persistent idle-UI motion without Pass, travel or attack playback.",
        "", f"During the enemy turn, motion with no observed foreground activity met or exceeded the threshold in **{idle_above}/{idle_pairs} pairs ({idle_rate})**.",
        "This is an ambient-only candidate count. Both endpoint frames had no tracked foreground transitions or animation. "
        "Untracked changes can enter the count, and idle motion overlapping a foreground beat cannot be isolated this way.",
        "", "### Ten longest still runs", "",
        "| Fixture | Start–end (ms) | Duration (ms) | Before | After | Holding wait | Strip |",
        "|---|---:|---:|---|---|---|---|",
    ])
    for rank, (fixture, run) in enumerate(all_runs[:TOP_ROWS], 1):
        before, after = run["before"], run["after"]
        holding = run["holding_wait"]
        wait = f"{holding['name']} ({holding['source']})" if holding != "unknown" else "unknown"
        strip = "—"
        if rank <= TOP_STRIPS:
            source = folder / fixture / run["strip"]
            name = f"longest-{rank:02d}.png"
            shutil.copyfile(source, folder / name)
            shutil.copyfile(source.with_suffix(".json"), (folder / name).with_suffix(".json"))
            strip = f"[frame strip]({rel.as_posix()}/{name})"
        lines.append(
            f"| {fixture} | {run['start_ms']:.1f}–{run['end_ms']:.1f} | {run['duration_ms']:.1f}"
            f" | {markdown_cell(before['beat'] + ' ' + str(before['detail']))}"
            f" | {markdown_cell(after['beat'] + ' ' + str(after['detail']))} | {wait} | {strip} |"
        )
    if not all_runs:
        lines.append("\nNo still run reached 150 ms.")
    lines.extend(["", "Each fixture's linked JSON lists all qualifying intervals and partially overlapping waits."])
    beats = beat_metrics(results)
    lines.extend(["", "### Ten slowest beat types by median", "", *render_beat_table(beats[:TOP_ROWS])])
    lines.extend(["", "### All measured beat durations", "", *render_beat_table(sorted(beats))])
    lines.extend(["", "### Native event timelines", ""])
    for result in results:
        lines.extend(render_timeline(result))
    headless = REPORT.read_text().split(NATIVE_HEADING, maxsplit=1)[0] if REPORT.exists() else "# Enemy-turn pacing census\n"
    headless = headless.replace("Native pixel measurements are pending. ", "")
    REPORT.write_text(headless.rstrip() + "\n" + "\n".join(lines) + "\n")
    write_json(folder / "summary.json", {"fixtures": metrics, "longest_still_runs": all_runs[:TOP_ROWS], "beats": beats})
    print(f"FEL09 NATIVE PASS fixtures={len(results)} turns={turns} actions={action_count} still_runs={len(all_runs)}")
    print(REPORT)


def check():
    before = Image.new("RGB", SIZE)
    after = before.copy()
    after.putpixel((0, 0), (0, 0, 1))
    after.putpixel((1919, 1079), (0, 1, 0))
    assert changed_pixels(before, after) == 2
    assert is_still(2073) and not is_still(2074)
    frames = [
        {"ms": 0}, {"ms": 60, "changed_pixels": 0}, {"ms": 150, "changed_pixels": 2073},
        {"ms": 200, "changed_pixels": 2074}, {"ms": 340, "changed_pixels": 0},
        {"ms": 350, "changed_pixels": 0},
    ]
    assert list(still_intervals(frames)) == [(0, 150), (200, 350)]
    events = [{"type": "post-action settle", "start_ms": 0, "end_ms": 150, "source": "test"}]
    assert attribute_still(0, 150, events, [])["holding_wait"]["source"] == "test"
    assert attribute_still(0, 151, events, [])["holding_wait"] == "unknown"
    assert nearest_frame([0, 56, 120], 50) == 1
    with TemporaryDirectory(prefix="fel09-pixel-check-") as temporary:
        directory = Path(temporary)
        for index in range(3):
            (directory / f"frame{index:08d}.rgb").write_bytes(before.tobytes())
        proof_frames = [{"ms": 80 * index, "index": index} for index in range(3)]
        still = attribute_still(0, 160, [], [])
        path = directory / "strip.png"
        write_strip(directory, proof_frames, still, path)
        with Image.open(path) as strip:
            assert strip.size == (1920, 580)
        samples = json.loads(path.with_suffix(".json").read_text())
        assert [sample["target_ms"] for sample in samples if sample["label"] == "still"] == [0, 50, 100, 150]
    print("FEL09 PIXEL DRY RUN PASS threshold=0.1% min_still_ms=150 strip_interval_ms=50")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    command = parser.add_mutually_exclusive_group(required=True)
    command.add_argument("--fixture", type=Path)
    command.add_argument("--merge", type=Path)
    command.add_argument("--check", action="store_true")
    args = parser.parse_args()
    if args.fixture:
        analyze_fixture(args.fixture)
    elif args.merge:
        merge(args.merge)
    else:
        check()


if __name__ == "__main__":
    main()
