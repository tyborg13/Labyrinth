"""Render the two map audits as a compact, reviewable before/after report."""
import json
import hashlib
import math
from pathlib import Path

OUTPUT_DIR = Path("/private/tmp/labyrinth_codex/ptf-02")
PROJECT_ROOT = Path(__file__).resolve().parents[2]
COUNT_LABELS = {
    "fights": "fights", "event": "events", "scavenger": "scavengers",
    "treasure": "relics", "graftwright": "graftwrights", "guardian": "guardians",
    "special": "specials", "mystery": "unknowns", "campfire": "hearths",
}


def main():
    before, after = [json.loads((OUTPUT_DIR / f"map_audit_{phase}.json").read_text())
                     for phase in ("before", "after")]
    current_hash = hashlib.sha256((PROJECT_ROOT / "scripts/section_map_graph.gd").read_bytes()).hexdigest()
    assert after.get("source_sha256") == current_hash, "After audit must cover the current generator"
    assert before["phase"] == "before" and after["phase"] == "after"
    assert before["seeds"] == after["seeds"] == 500
    assert not after["rule_violations"] and after["routes_without_mid_hearth"] == 0
    assert after["routes_with_multiple_mid_hearths"] == 0
    lines = ["# ptf-02 map audit", "", "Seeds 1–500 × six sections. Counts are physical rooms summed over the 500 maps per section. Fights include combat, Guardian, special and hidden mystery combat; these overlap the corresponding identity columns. Relics are guaranteed treasure rooms; unknowns retain their mystery identity.", "",
             "| Section | " + " | ".join(COUNT_LABELS.values()) + " |",
             "| --- | " + " | ".join("---:" for _ in COUNT_LABELS) + " |"]
    for index in range(6):
        cells = [f'{before["sections"][index]["counts"][key]} → {after["sections"][index]["counts"][key]}'
                 for key in COUNT_LABELS]
        lines.append(f"| {index + 1} | " + " | ".join(cells) + " |")
    lines += ["", "Fights per route exclude the boss and count combat, Guardian, special and hidden mystery combat, using the same fight predicate as the room-count table. Every distinct entry-to-boss route (including recombinations at merges) has equal weight across seeds 1–500. Means are pooled over routes, not averaged over seeds.", "",
              "| Section | Before routes | After routes | Before mean fights/route | After mean fights/route |",
              "| --- | ---: | ---: | ---: | ---: |"]
    for index in range(6):
        old, new = before["sections"][index], after["sections"][index]
        for summary in (old, new):
            histogram = summary["fights_per_route_histogram"]
            assert sum(histogram.values()) == summary["routes"]
            assert sum(int(fights) * count for fights, count in histogram.items()) == summary["total_route_fights"]
            assert math.isclose(summary["mean_fights_per_route"], summary["total_route_fights"] / summary["routes"])
        lines.append(f'| {index + 1} | {old["routes"]} | {new["routes"]} | {old["mean_fights_per_route"]:.4f} | {new["mean_fights_per_route"]:.4f} |')
    lines += ["", "| Section | Fights per route (boss excluded) | Before route count | After route count |",
              "| --- | ---: | ---: | ---: |"]
    for index in range(6):
        old = before["sections"][index]["fights_per_route_histogram"]
        new = after["sections"][index]["fights_per_route_histogram"]
        for fights in sorted({int(key) for key in old} | {int(key) for key in new}):
            lines.append(f'| {index + 1} | {fights} | {old.get(str(fights), 0)} | {new.get(str(fights), 0)} |')
    lines += ["", "| Metric | Before | After |", "| --- | ---: | ---: |"]
    for key in ("routes", "routes_without_mid_hearth", "routes_with_multiple_mid_hearths",
                "generation_failures", "generation_failure_rate", "fallback_sections", "fallback_rate"):
        lines.append(f"| {key} | {before[key]} | {after[key]} |")
    for metric in ("generation_usec", "run_generation_usec"):
        for percentile in ("p50", "p99"):
            lines.append(f'| {metric} {percentile} | {before[metric][percentile]} | {after[metric][percentile]} |')
    lines += ["", "Timing measures headless generation only, on the same host and engine with diagnostics enabled. Shared host load is uncontrolled; this is not a performance qualification. Per-section counts, timing percentiles and fallback rates, plus source hashes, are retained in both JSON reports.", "",
              f'After-change rule violations: {json.dumps(after["rule_violations"], sort_keys=True)}', ""]
    target = OUTPUT_DIR / "map_audit_comparison.md"
    target.write_text("\n".join(lines))
    print(target)
    print("\n".join(lines))


if __name__ == "__main__":
    main()
