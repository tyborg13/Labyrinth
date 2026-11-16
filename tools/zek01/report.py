"""Render the matched dragon table and the separate eight-fight damage audit."""
from __future__ import annotations
import argparse
from collections import Counter, defaultdict
import gzip
import json
import math
from pathlib import Path
import statistics

VARIANTS = ("baseline", "pattern50", "hp56", "hp62", "hp68", "hp74")
ROSTER = ("vyraketh", "tharokh", "vaeloryx", "iskaldra", "zekarion", "noctyrax")

def wilson(wins, n):
    z = 1.959963984540054
    center = (wins / n + z*z/(2*n)) / (1 + z*z/n)
    half = z * math.sqrt(wins/n*(1-wins/n)/n + z*z/(4*n*n)) / (1 + z*z/n)
    return center-half, center+half

def read_rows(directory):
    return [json.loads(line) for path in sorted(directory.glob("fights-*.jsonl")) for line in path.read_text().splitlines()]

def skybreak_hits(row):
    return sum(e["target"] == "player" and e.get("cause") == "enemy_attack" and e["source"].get("intent_id") == "skybreak" and e["source"].get("source_kind") == "direct_attack" for e in row["receipts"])

def overload_bolt_damage(row):
    return sum(e["hp_loss"] for e in row["receipts"] if e["target"] == "player" and e.get("cause") != "fatigue" and e["source"].get("intent_id") == "tempest_breath" and e["source"].get("source_kind") == "direct_attack")

def lightning_storm_damage(row):
    return sum(e["hp_loss"] for e in row["receipts"] if e["target"] == "player" and e.get("cause") != "fatigue" and e["source"].get("rule") == "lightning_storm")

def storm_damage(row):
    return sum(e["hp_loss"] for e in row["receipts"] if e["target"] == "player" and e.get("cause") != "fatigue" and (e["source"].get("rule") == "lightning_storm" or e["source"].get("intent_id") == "tempest_breath"))

def cause(event):
    source = event["source"]
    if event.get("cause") == "fatigue": return "Fatigue"
    if source.get("source_kind") == "battlefield_rule":
        return "Lightning Storm: Chain bounce" if source.get("hit_kind") == "chain" else "Lightning Storm: on Electrified ground"
    if "retaliat" in source.get("source_kind", ""): return "Retaliate"
    if source.get("enemy_type") == "lightning_wisp": return "Wisp"
    if source.get("intent_id") == "skybreak": return "Skybreak"
    if source.get("intent_id") == "storm_claw": return "Storm Lash"
    if source.get("intent_id") == "call_wisps": return "Call Wisps bolt"
    if source.get("intent_id") == "tempest_breath": return "Overload bolt"
    if "surface" in source.get("source_kind", "") or source.get("surface"): return "Surface: " + str(source.get("surface", source.get("source_kind")))
    return str(source.get("source_kind", event.get("cause", "other")))

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--audit", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)
    rows = read_rows(args.input_dir)
    contract = json.loads((args.input_dir / "contract.json").read_text())
    n = contract["samples"]
    assert len(rows) == n * 11, (len(rows), n*11)
    keys = [(r["sample"], r["variant"], r["dragon"]) for r in rows]
    assert len(set(keys)) == len(keys)
    lines = ["# zek-01 measurement", "", "Section 1 (depth 4), ladder-entry loadouts 1–8 from the archived `run_curve_dragons.py` constructor payloads. Each loadout is used with eight combat seeds (stride 1,000,003), for N=64 per cell. All dragons use that same entry-loadout/seed schedule. The room generator builds each dragon's own production arena/roster at depth 4; this changes the selected dragon, not its entry build. No later-section results are implied.", "", "Baseline is the current branch rules with Zekarion's pre-unit data restored in process (HP50, band7, original order). Pattern50 and the HP sweep use scatter9 and the five-slot order. Other dragons' baseline rows are reused in the other scenarios: their definitions and factories are unchanged. Values are relative results from the unchanged ladder bot, not player difficulty estimates. No tuning was performed.", "", "95% intervals are Wilson binomial intervals across combat seeds, conditional on these eight entry loadouts; they do not quantify uncertainty across all player builds. Medians include wins and losses. Health lost is cumulative actual damage received, including healing/recovery between hits. Skybreak strikes are mean registered hits per fight, including hits fully absorbed by Block or Stoneskin; empty strikes are excluded. Overload bolt and Lightning Storm columns report mean actual hero Health lost separately; the combined total is also in the JSON summary.", "", "| Scenario | Dragon | N | Wins (95% interval) | Median turns | Median Health lost | Skybreak hits/fight | Overload bolt HP/fight | Lightning Storm HP/fight |", "|---|---|---:|---|---:|---:|---:|---:|---:|"]
    summary = []
    for variant in VARIANTS:
        for dragon in ROSTER:
            source_variant = variant if dragon == "zekarion" else "baseline"
            cell = [r for r in rows if r["dragon"] == dragon and r["variant"] == source_variant]
            assert len(cell) == n
            wins = sum(r["won"] for r in cell)
            lo, hi = wilson(wins, n)
            if dragon == "zekarion": assert (hi-lo)/2 <= .12
            row = {"variant":variant, "dragon":dragon, "n":n, "wins":wins, "interval95":[lo,hi], "median_turns":statistics.median(r["turns"] for r in cell), "median_hp_lost":statistics.median(r["hp_lost"] for r in cell), "skybreak_hits_per_fight":statistics.mean(skybreak_hits(r) for r in cell), "overload_storm_damage_per_fight":statistics.mean(storm_damage(r) for r in cell), "overload_bolt_damage_per_fight":statistics.mean(overload_bolt_damage(r) for r in cell), "lightning_storm_damage_per_fight":statistics.mean(lightning_storm_damage(r) for r in cell)}
            summary.append(row)
            lines.append(f"| {variant} | {dragon} | {n} | {100*wins/n:.1f}% ({100*lo:.1f}–{100*hi:.1f}) | {row['median_turns']:g} | {row['median_hp_lost']:g} | {row['skybreak_hits_per_fight']:.2f} | {row['overload_bolt_damage_per_fight']:.2f} | {row['lightning_storm_damage_per_fight']:.2f} |")
    lines.extend(["", f"Observed caps: {sum(r['turn_cap_reached'] for r in rows)} turn-capped fights; {sum(r['search_capped'] for r in rows)} decision-capped fights. N=64 guarantees a Wilson half-width below 12 percentage points even at a 50% win rate. The eight entry-loadout clusters remain a practical limitation.", ""])
    (out / "measurement.md").write_text("\n".join(lines))
    (out / "summary.json").write_text(json.dumps(summary, indent=2)+"\n")
    with gzip.open(out / "fights.jsonl.gz", "wt") as stream:
        for row in sorted(rows, key=lambda r:(r["sample"],r["variant"],r["dragon"])): stream.write(json.dumps(row, sort_keys=True)+"\n")
    audit = [json.loads(line) for line in args.audit.read_text().splitlines()]
    assert len(audit) == 8 and all(r["variant"] == "hp62" for r in audit)
    events = []
    for row in audit:
        for index, event in enumerate(row["receipts"]):
            if event["hp_loss"] <= 0: continue
            hero_external = event["target"] == "player" and (event["phase"] == "enemy_phase" or "retaliat" in event["source"].get("source_kind", ""))
            boss_external = event["target"] == "1" and event["phase"] != "card"
            if not hero_external and not boss_external: continue
            events.append({**event, "sample":row["sample"], "combat_seed_input":row["combat_seed_input"], "receipt_index":index, "cause_name":cause(event), "target_name":"hero" if hero_external else "Zekarion", "number_scheduled":False if boss_external and event["source"].get("source_kind") == "battlefield_rule" else True, "cause_label_scheduled":False if event["source"].get("source_kind") == "battlefield_rule" else (True if cause(event) in ["Fatigue", "Retaliate"] else "visible_sources_only"), "screen_number_observed":None, "screen_cause_observed":None})
    counts = Counter((e["target_name"], e["cause_name"]) for e in events)
    audit_lines = ["# Eight-fight confusing-damage audit", "", "HP62, scatter9 and the five-slot cycle; section 1; archived ladder entry loadouts 1–8; first combat seed for each. Raw accepted-state receipts are in `audit.jsonl.gz`; speculative bot candidates do not enter this report. Each damage call is one receipt, so one Storm may contribute several actor losses.", "", "Actual screen visibility could not be observed: this worker has no macOS window server. Both requested screen fields remain null in the machine-readable report. The production playback routes below describe scheduled presentation only; the design owner must verify them with the windowed command in the handoff. No presentation or forecast fixes are included.", "", "| Target | Cause | Loss events | Total HP | Number scheduled | Cause label scheduled | Reproduction: seed / turn / clock |", "|---|---|---:|---:|---|---|---|"]
    for key, count in sorted(counts.items()):
        group = [e for e in events if (e["target_name"],e["cause_name"]) == key]
        e = group[0]
        audit_lines.append(f"| {key[0]} | {key[1]} | {count} | {sum(x['hp_loss'] for x in group)} | {e['number_scheduled']} | {e['cause_label_scheduled']} | {e['combat_seed_input']} / {e['turn']} / {e['clock']} |")
    audit_lines.extend(["", "Causes with no qualifying loss in these eight fights: " + ", ".join(c for c in ["Retaliate", "Surface", "Chain bounce"] if not any(c.lower() in e["cause_name"].lower() for e in events)) + ".", "", "Presentation source audit:", "", "- Ordinary enemy attacks carry target-loss receipts into `_floating_texts_for_target_losses`; their actor/intent captions identify the move when the source is visible; Umbra may anonymize hidden sources. This includes Wisp shots and Skybreak. Fatigue uses the existing reshuffle/turn-start feedback; its stale damage context is not attributed to the previous enemy. The number and named cause are scheduled, with actual visibility unverified.", "- Retaliate emits a dedicated `status_damage` step with label/trigger `Retaliate`; its loss number and named beat are scheduled. Fatigue also has a named number beat.", "- Lightning Storm resolves at Overload's completion. `hero_loss_playback.gd` reconciles an unreceipted hero loss with the existing number/bar/hit reaction. That helper adds no cause label. The battlefield rule panel names Lightning Storm separately.", "- That completion reconciliation is hero-only. Zekarion's own Lightning Storm loss has no equivalent actor-loss popup in the beat dispatcher; the committed state refresh updates his Health. No per-hit cause label is supplied there. This is a source-code finding, not a renderer observation.", "", "The full per-event log records seed, hero turn, initiative clock, target, actual Health/Block loss, phase, route kind and causal context. Player card losses and voluntary movement hazards are excluded from the qualifying audit; enemy-turn surface/status losses and Retaliate remain eligible. No cause is inferred from timing alone.", ""])
    (out / "damage_audit.md").write_text("\n".join(audit_lines))
    (out / "damage_events.json").write_text(json.dumps(events, indent=2)+"\n")
    with gzip.open(out / "audit.jsonl.gz", "wt") as stream:
        for row in audit: stream.write(json.dumps(row, sort_keys=True)+"\n")
    print(f"ZEK01 REPORT PASS N={n} raw_fights={len(rows)} audit_fights={len(audit)} qualifying_losses={len(events)}")

if __name__ == "__main__": main()
