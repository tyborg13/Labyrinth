"""Index the matched fel-03 native strips and summarize their timing replay."""
import argparse
import json
from pathlib import Path
from statistics import median_high

PROOF = json.loads(Path(__file__).with_name("proof_contract.json").read_text())
FIRST_FIGHT = "01-s0-seed15-0-0_2-t2"
TIMING_PAIRS = (("before", "after"), ("after", "before"), ("before", "after"))
TIMED_STRIKES = (("first", "Quick Stab"), ("second", "Stone Warden: Crushing Step"))
RATIO_LIMIT = 1.5


def write_strip_index(out):
    manifest = read_manifest(out / "visual-proof.json")
    sizes = {Path(image["path"]).name: [image["width"], image["height"]] for image in manifest["images"]}
    if PROOF["viewport"] not in sizes.values():
        raise SystemExit("Missing viewport-size native evidence")
    rows = {}
    for line in (out / "index.md").read_text().splitlines():
        if "[melee](" not in line:
            continue
        columns = [column.strip() for column in line.split("|")]
        stem = columns[2].split("[melee](", 1)[1].split("-sheet.png)", 1)[0]
        rows[stem] = columns
    width, height = PROOF["viewport"]
    scale = PROOF["ui_scale"]
    fps = PROOF["frames_per_second"]
    strips = ["# fel-05 after-strips", "", f"{width} × {height} at {scale:.0%} UI scale, {fps} Hz.", ""]
    for stem, (action, shape) in PROOF["matched_strips"].items():
        row = rows[stem]
        if action not in row[4] or row[5] != shape:
            raise SystemExit(f"Unexpected matched strip {stem}: {row}")
        strips.append(strip_link(out, sizes, stem, action))
    elemental = next(((stem, row) for stem, row in rows.items() if row[6] == "yes"), None)
    if elemental is None:
        strips.extend(["", "Elemental melee strip — none."])
    else:
        stem, row = elemental
        strips.append(strip_link(out, sizes, stem, f"{row[4]} ({row[7]})"))
    (out / "after-strips.md").write_text("\n".join(strips) + "\n")


def strip_link(out, sizes, stem, name):
    sheet = stem + "-sheet.png"
    frame_count = len(list((out / stem).glob("frame-*.png")))
    if sizes.get(sheet) != PROOF["sheet_size"] or frame_count != PROOF["frames_per_strip"]:
        raise SystemExit(f"Incomplete strip: {stem}")
    return f"- {name} · [sheet]({sheet}) · [frames]({stem}/)"


def read_manifest(path):
    manifest = json.loads(path.read_text())
    if not manifest["ok"]:
        raise SystemExit(f"Native proof was rejected: {path}")
    return manifest


def write_timings(out, dry_run=False):
    report = [
        "# effect_overlay CPU time", "",
        "The production render-section counter includes overlay work and trail submission/draw callbacks.",
        "Times are in microseconds for the first two strikes in the same saved fight.",
        "Order is before/after, after/before, before/after. Ratios use redrawn frames, as in the director's run.",
        "The live median also includes held frames where the renderer reused the previous submission.", "",
        "| Pair | Revision | Action | Redrawn | Live | First frame | Redrawn median | Live median | Max |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    breakdown = [
        "", "## After breakdown by frame", "",
        "These are per-column medians in microseconds. The draw column covers canvas command submission.",
        "GPU execution is outside the CPU counter. Medians of components can differ from the median of the total.", "",
        "| Pair | Action | Submit | Raster | Draw | Other overlay | Reused frames |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: |",
    ]
    verdict = ["", "## Paired median ratios", "",
               "| Pair | Quick Stab | Warden | Both ≤ 1.5× |", "| --- | ---: | ---: | --- |"]
    renderer = None
    passes = []
    for number, order in enumerate(TIMING_PAIRS, 1):
        pair = f"pair-{number:02}"
        medians = {}
        for revision in order:
            directory = out / pair / revision
            if not dry_run:
                manifest = read_manifest(directory / "timing-proof.json")
                current = (manifest["rendering_method"], manifest["rendering_driver"])
                if renderer is None:
                    renderer = current
                if current != renderer:
                    raise SystemExit("Timing invocations used different renderers")
            row = json.loads((directory / (FIRST_FIGHT + "-effect-overlay.json")).read_text())
            if row["fixture"] != FIRST_FIGHT:
                raise SystemExit(f"Unexpected timing fixture in {directory}")
            medians[revision] = []
            for ordinal, (period, action) in enumerate(TIMED_STRIKES, 1):
                stats = row[period]
                frames = [sample for sample in row["frames"] if sample["strike"] == ordinal]
                if not frames or len(frames) != stats["frames"] or stats["action"] != action:
                    raise SystemExit(f"Missing {period} strike ({action}) in {directory}")
                drawn = [frame for frame in frames if frame["redrawn"]]
                if not drawn or stats["redrawn_frames"] != len(drawn):
                    raise SystemExit(f"Missing redrawn {period} strike frames in {directory}")
                numbers = [str(stats[key]) for key in ("redrawn_frames", "frames", "first_frame_usec",
                                                      "median_usec", "live_median_usec", "max_usec")]
                report.append(f"| {number} | {revision} | {action} | {' | '.join(numbers)} |")
                medians[revision].append(stats["median_usec"])
                if revision == "after":
                    samples = [frame["breakdown"] for frame in drawn]
                    parts = [str(median_high(item[key] for item in samples))
                             for key in ("submit_usec", "raster_usec", "draw_usec", "other_usec")]
                    held = sum(not frame["redrawn"] for frame in frames)
                    breakdown.append(f"| {number} | {action} | {' | '.join(parts)} | {held} |")
        ratios = [after / before for after, before in zip(medians["after"], medians["before"])]
        passed = all(ratio <= RATIO_LIMIT for ratio in ratios)
        passes.append(passed)
        verdict.append(f"| {number} | {ratios[0]:.2f}× | {ratios[1]:.2f}× | {'yes' if passed else 'no'} |")
    if dry_run:
        verdict.extend(["", "Headless diagnostic only. The performance verdict requires the native renderer."])
    else:
        verdict.extend(["", "Native target met in all three pairs." if all(passes)
                        else "Native target did not hold in all three pairs. Step costs are listed above."])
    destination = out / ("effect-overlay-dry.md" if dry_run else "effect-overlay.md")
    destination.write_text("\n".join(report + breakdown + verdict) + "\n")
    print(f"FEL05 {'DRY' if dry_run else 'NATIVE'} TIMING REPORT pairs={len(TIMING_PAIRS)} within_target={sum(passes)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--timings", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    if args.timings:
        write_timings(args.output, args.dry_run)
    else:
        write_strip_index(args.output)
