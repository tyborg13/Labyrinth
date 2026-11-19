"""Generate the qa-111 report and exact per-window stacking ledger."""

import argparse
from collections import Counter, defaultdict
import csv
import json
from pathlib import Path

from tools.qa111.measure import ELECTRIC, ELECTRIC_FIX, ROOT, measure_registry
from tools.qa111.stacking import analyze_hunts


def line(*fields):
    return "| " + " | ".join(str(value).replace("|", "&#124;").replace("\n", " ") for value in fields) + " |"


def counts(values):
    return ", ".join(f"{cue} ×{count}" for cue, count in values.most_common()) or "—"


def seconds(value):
    return "—" if value is None else f"{value:.3f}"


def metric_cells(row):
    decay = seconds(row["decay"]) + ("†" if row["to_eof"] else "")
    return (seconds(row["duration"]), seconds(row["first_fall"]), decay, seconds(row["above_seconds"]),
            f"{row['sustain']:.1%}", f"{row['lufs_s']:.1f}", f"{row['true_peak']:.1f}", f"{row['hf']:.1%}")


def variant_name(row):
    path = row["path"].removeprefix("res://assets/audio/sfx/")
    return Path(path).name if path.startswith("cues/") else path


def evidence_label(row):
    inputs = ", ".join(f"d{decision} / S{section + 1} {room} / {action}"
                       for decision, section, room, action in row["inputs"])
    actors = ", ".join(" ".join(filter(None, (f"#{serial}", actor, action)))
                       for serial, actor, action in row["actors"] if action)
    return inputs + (f" [{actors}]" if actors else "")


def write_ledger(path, incidents):
    headers = ("seed", "rule", "first_ms", "span_ms", "action", "sources", "requested", "starts",
               "bank_results", "peak_allocated_voices", "voice_steals", "audible_overlap_ms", "peak_envelope_dbfs",
               "request_ids")
    with path.open("w", newline="") as output:
        writer = csv.writer(output, delimiter="\t", lineterminator="\n")
        writer.writerow(headers)
        for row in incidents:
            writer.writerow((row["seed"], row["kind"], f"{row['time_ms']:.3f}", f"{row['span_ms']:.3f}",
                             evidence_label(row), ", ".join(row["sites"]), counts(row["requests"]),
                             counts(row["starts"]), counts(row["results"]), row["allocated_peak"],
                             row["voices_cut_short"], row["overlap_ms"],
                             "" if row["sum_db"] is None else f"{row['sum_db']:.1f}",
                             ",".join(map(str, row["ids"]))))


def moment(row, observed):
    moments = observed.get((row["cue"], row["path"]), Counter())
    logged = " / ".join(f"{site} in {room} ({count})" for (site, room), count in moments.most_common(2))
    return row["trigger"] + (" **Log:** " + logged if logged else " **Log:** no start.")


def render_variants(baseline, electrical, medians, high_cutoff, observed, repeat_overlap):
    sounds = json.loads(Path(__file__).with_name("sounds.json").read_text())

    def priority(row):
        # Give extra weight to the direct sustained/high-frequency match.
        return (row["loop"], "H" not in row["flags"], not row["flags"],
                -(min(row["above_seconds"], 2) * (1 + row["hf"])
                  + 2 * row["sustain"] + max(0, row["bus_delta"]) / 10
                  + (0.25 if repeat_overlap.get(row["cue"]) else 0)),
                row["cue"], row["path"])

    bus_text = ", ".join(f"{bus} {median:.1f} LUFS-S" for bus, median in sorted(medians.items()))
    lines = [
        "## Every active registry variant",
        "",
        f"{len(baseline)} active cue/variant bindings across {len({row['cue'] for row in baseline})} cues, including inherited samples and the active ambience fallback. Rows rank concern for a long or abrasive one-shot. Individual flags still apply to the intentional loop beds. Sound descriptions come from sample provenance, documented cue intent and signal shape.",
        "",
        "Durations and spectra describe the encoded files at nominal pitch. The RMS envelope uses the shared 5 ms centered window. **First −20** is seconds from the strongest RMS peak to the first crossing below −20 dB relative to that peak. **Last −20** is seconds from the peak to the point after which the file stays below −20 dB. † means it reaches EOF before staying below. **Time ≥−20** sums all above-threshold time, including early attack and later rebounds. **Sustain** is the fraction of the full file spent within 6 dB of peak after 150 ms. **HF** is summed channel spectral energy above 4 kHz divided by total spectral energy (Hann Welch, up to 4,096 samples per frame).",
        "",
        "**LUFS-S** is the maximum ungated 3 s K-weighted window, sampled at 100 ms plus the final full window and zero-padded for shorter cues. **dBTP** is the 4× reconstructed true peak. Both apply the authored cue volume_db before bus gain or per-use gain. Runtime overlap uses the bank's actual gain and pitch, including legacy fallback gain. Bus medians use all non-electric cue/variant rows, including loops.",
        "",
        f"Flags **S** sustain >40%, **T** more than 0.600 s ≥−20 dB for a hit, impact or status (manifest impact/status and registry hit/spell-impact/status/surface families), **L** >3 LU over the bus median ({bus_text}), **H** sustained and at or above the 90th-percentile HF share ({high_cutoff:.1%}). Ranking combines the flag types with decay, sustain, HF, relative loudness and observed same-cue overlap. Loops play on the shared World SFX bus through the bank's loop slots.",
        "",
        line("Cue", "Variant", "File s", "First −20 s", "Last −20 s", "Time ≥−20 s", "Sustain",
             "LUFS-S", "dBTP", "HF", "Bus / loop", "Flags", "Trigger and logged moment", "Sound"),
        line(*["---"] * 14),
    ]
    for row in sorted((row for row in baseline if row["cue"] not in ELECTRIC), key=priority):
        description = sounds["ambience.stone" if row["loop"] else row["cue"]]
        lines.append(line(row["cue"], variant_name(row), *metric_cells(row),
                          row["bus"] + (" / yes" if row["loop"] else " / no"),
                          " ".join(row["flags"]) or "—", moment(row, observed), description))

    lines.extend(("", "## Electric comparison · already addressed by sfx-06", "",
                  f"Baseline → fixed measurements from {ELECTRIC_FIX}. All four are World one-shots. The fallback is included for comparison and is outside the {len(baseline)} active registry bindings.",
                  "",
                  line("Cue / file", "File s", "First −20 s", "Last −20 s", "Time ≥−20 s", "Sustain", "LUFS-S",
                       "dBTP", "HF", "Flags", "Trigger and logged starts (baseline)", "Sound"),
                  line(*["---"] * 12)))
    for old, fixed in electrical:
        identity = f"{old['cue']} / {variant_name(old)}" + (" (fallback)" if old["fallback"] else "")
        lines.append(line(identity, *(f"{a} → {b}" for a, b in zip(metric_cells(old), metric_cells(fixed))),
                          f"{' '.join(old['flags']) or '—'} → {' '.join(fixed['flags']) or '—'}",
                          moment(old, observed), "Sparking electric hit." if old["fallback"] else sounds[old["cue"]]))
    return lines


def render_stacking(runs, incidents, repeat_groups, repeat_overlap, results, seen):
    bursts = [row for row in incidents if row["kind"] == "burst"]
    lines = [
        "## Stacking in the six hunts",
        "",
        "Every qualifying action and window is in [STACKING.tsv](STACKING.tsv), including bank result counts, actual voice starts, per-window source functions, input decisions, combat actor/action serials, and request IDs. A window that spans decisions or combat sub-actions lists each context. Repeats use the same resolved cue, including legacy aliases. A burst is any four or more requests, including repetitions. Overlapping maximal windows and instances that meet both rules are preserved.",
        "",
        line("Seed", "Terminal outcome", "Decisions", "Sections", "Bank requests", "Voice starts",
             "Repeat windows", "Burst windows", "Runner exit"),
        line(*["---"] * 9),
    ]
    for seed, evidence, requests, starts in runs:
        finish = evidence["finish"]
        totals = Counter(row["kind"] for row in incidents if row["seed"] == seed)
        lines.append(line(seed, finish["outcome"], finish["decisions"],
                          ", ".join(str(int(index) + 1) for index in finish["sections"]),
                          requests, starts, totals["repeat"], totals["burst"], evidence["returncode"]))

    lines.extend(("", f"**Total:** {sum(row[2] for row in runs):,} requests, {sum(row[3] for row in runs):,} actual starts across the bank, including {len(seen)} distinct registry cues. Bank results: {counts(results)}. A loop request can return played without starting another copy. Where a voice slot is reused, the earlier voice ends at replacement.",
                  "",
                  "Overlap uses pitch- and gain-adjusted 5 ms RMS envelopes on a 1 ms grid, with voice steals, one-shot ends and loop crossfades applied. Two or more admitted voices must simultaneously clear both their own −20 dB relative floor and −60 dBFS. The peak sum is RMS power addition (assumed uncorrelated) over those frames, before bus and master processing. This audibility proxy excludes masking. Scores refer to voices requested within the listed window.",
                  "",
                  "### Same cue in 150 ms",
                  "",
                  line("Cue", "Windows", "With audible overlap", "Most requests → starts in one window", "Common logged source", "Example"),
                  line(*["---"] * 6)))
    for cue, group in sorted(repeat_groups.items(), key=lambda pair: (-repeat_overlap[pair[0]], -len(pair[1]), pair[0])):
        most = max(group, key=lambda row: (sum(row["requests"].values()), sum(row["starts"].values())))
        example = max(group, key=lambda row: (row["sum_db"] if row["sum_db"] is not None else -999, row["span_ms"]))
        sites = Counter(site for row in group for site in row["sites"])
        lines.append(line(cue, len(group), repeat_overlap[cue], f"{most['requests'][cue]} → {most['starts'][cue]}",
                          sites.most_common(1)[0][0], f"{example['seed']} · {evidence_label(example)}"))

    lines.extend(("", "### Four or more cues in 100 ms", "",
                  f"{len(bursts)} windows, {sum(row['overlap_ms'] > 0 for row in bursts)} with audible overlap. Highest estimated sums below. The TSV contains all qualifying windows.",
                  "",
                  line("Seed / action", "Requested", "Voice starts", "Overlap ms / peak dBFS"),
                  line(*["---"] * 4)))
    for row in sorted(bursts, key=lambda row: row["sum_db"] if row["sum_db"] is not None else -999, reverse=True)[:10]:
        peak = "—" if row["sum_db"] is None else f"{row['sum_db']:.1f}"
        lines.append(line(f"{row['seed']} · {evidence_label(row)}", counts(row["requests"]),
                          counts(row["starts"]), f"{row['overlap_ms']} / {peak}"))
    return lines


def render(runs, incidents, observed, results, metrics):
    baseline, electrical, medians, high_cutoff = metrics
    repeat_groups = defaultdict(list)
    for incident in incidents:
        if incident["kind"] == "repeat":
            repeat_groups[next(iter(incident["requests"]))].append(incident)
    repeat_overlap = {cue: sum(row["overlap_ms"] > 0 for row in group) for cue, group in repeat_groups.items()}
    seen = {cue for cue, _ in observed} & {row["cue"] for row in baseline}
    command_fence = chr(96) * 3
    lines = [
        "# qa-111 · SFX outliers",
        "",
        "Registry and runtime baseline ef75a9a66 (codex/release at task start), with the qa-101 drivers supplied at e7a414e25. Electric cue files are shown as comparisons with sfx-06 and excluded from the ranked list.",
        "",
        "**Closest match to the electric complaint:** illusion.break has 60.6% of its energy above 4 kHz and sits within 6 dB of peak for 59.4% of the file after the opening 150 ms. It is the only ranked variant that meets the harshness flag. Dragon.roar and omen.bane are the other sustained one-shots. Both clear their bus loudness threshold by over 10 LU. Defiance, illusion.spawn and spell.shadow spend more than a second within 20 dB of peak.",
        "",
        f"**Most consistent stack:** the legacy card deal overlaps in {repeat_overlap.get('legacy:res://assets/audio/sfx/card_draw_deal.wav', 0)} repeat windows, followed by reward flips in {repeat_overlap.get('legacy:res://assets/audio/sfx/reward_card_flip.wav', 0)}. The table below separates those starts from requests absorbed by cooldown.",
        "",
        *render_variants(baseline, electrical, medians, high_cutoff, observed, repeat_overlap),
        "",
        *render_stacking(runs, incidents, repeat_groups, repeat_overlap, results, seen),
        "",
        "## Scope and rerun",
        "",
        "The qa-101 policy uses its existing fastest combat setting, 8× scene clock, 120 fps cap and 9,999 starting Health. Timing windows use elapsed wall-clock time, matching the bank's cooldown and voice allocator. Playback speed within each voice is the bank's recorded pitch. Accelerated scene pacing and headless scheduling can bunch presentation beats more closely than default-speed Windows play. Scope covers the RunScene cue bank and the naturally reached rooms. It excludes main-menu/loading audio, router requests discarded before the bank, and actions the policy did not encounter.",
        "",
        "Use a fresh output directory. Per-seed sfx.jsonl holds raw request/arbitration/slot history, trace.jsonl holds hunt decisions, and godot.log and command.json contain the runner receipt and exact seed invocation.",
        "",
        command_fence + "sh",
        f"cd {ROOT} && LABYRINTH_GROUND_FX= LABYRINTH_DEMO= python3 -B tools/qa111/campaign.py --seed 101001 --runs 6 --processes 2 --script tools/qa111/hunt.gd --output-dir output/qa111/repro",
        f"cd {ROOT} && ~/.cache/umbra-sfx/venv/bin/python -B -m tools.qa111.report --campaign output/qa111/repro --out output/qa111/repro-report",
        command_fence,
        "",
    ]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    cues = json.loads((ROOT / "data/sfx_cues.json").read_text())["cues"]
    runs, incidents, observed, results = analyze_hunts(args.campaign, cues)
    if len(runs) != 6 or any(run[1]["finish"] is None for run in runs):
        parser.error("Six complete hunts with terminal receipts are required")
    metrics = measure_registry(cues)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "REPORT.md").write_text(render(runs, incidents, observed, results, metrics))
    write_ledger(args.out / "STACKING.tsv", incidents)
    print(f"QA111 REPORT: {len(metrics[0])} registry variants, {len(metrics[1])} electric files, "
          f"{len(runs)} terminal runs, {len(incidents)} stacking windows")


if __name__ == "__main__":
    main()
