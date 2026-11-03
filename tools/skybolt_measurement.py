#!/usr/bin/env python3
"""Paired, offline revision-7 card-addition measurement; never changes policy/data."""
from __future__ import annotations

import argparse
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path
import random
import statistics
import subprocess
import tempfile

from encounter_bot import compress_report, read_report, summarize
from encounter_sweep import ROOT, cell, run_engine

OUTPUT = ROOT / "spec/peer_benchmark/balance/skybolt"
TASK_ID = "meas-03"
RUNS = 150
FIRST_SEED = 1
WORKERS = 6
BOOTSTRAP_RESAMPLES = 10000
BOOTSTRAP_SEED = 3102026
POLICY_SHA256 = "c90b92005d67d7ea0137e7c35a508bdc8b10d1eee34d70bf7fa4a5d434aa5d82"
LOG_ROOT = Path("/private/tmp/labyrinth_codex/meas-03")
ARMS = {
    "none": {},
    "skybolt": {"card": "skybolt", "fields": {}},
    "wildfire_halo": {"card": "wildfire_halo", "fields": {}},
    "stormstring_shot": {"card": "stormstring_shot", "fields": {}},
    "V1": {"card": "skybolt", "fields": {"action_fields": {"shock_all_hits": False}}},
    "V2": {"card": "skybolt", "fields": {"burn": True}},
    "V3": {"card": "skybolt", "fields": {"action_fields": {"range": 5, "ignore_los": None}}},
    "V4": {"card": "skybolt", "fields": {"time": 9}},
    "V5": {"card": "skybolt", "fields": {"action_fields": {"shock_all_hits": False}, "burn": True}},
}
GROUPS = [(tier, cohort) for tier in (2, 3) for cohort in ("standard", "warband", "guardian")]
GROUPS.append((3, "boss"))
TOOL_FILES = ("encounter_bot.gd", "encounter_measurement_bot.gd", "encounter_measurement_engine.gd",
              "encounter_metric_repair.gd", "encounter_sweep.gd", "encounter_sweep.py", "skybolt_measurement.py", "skybolt_metric_refresh.py")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def identity(row: dict) -> tuple:
    return row["seed"], row["section_index"], row["coord"]["x"], row["coord"]["y"]


def paired_delta(base: list[dict], arm: list[dict]) -> dict:
    if not base or [identity(r) for r in base] != [identity(r) for r in arm]:
        raise ValueError("Paired arms require identical ordered seed/section/room identities")
    clusters = defaultdict(list)
    for before, after in zip(base, arm):
        clusters[before["seed"]].append((int(after["won"]) - int(before["won"]),
                                         after["hp_lost"] - before["hp_lost"]))
    # Rooms generated from the same map seed are correlated. Resample paired
    # seed clusters together, retaining their natural section/biome weights.
    totals = [(len(rows), sum(r[0] for r in rows), sum(r[1] for r in rows)) for rows in clusters.values()]
    rng = random.Random(BOOTSTRAP_SEED)
    draws = [[], []]
    for _ in range(BOOTSTRAP_RESAMPLES):
        selected = rng.choices(totals, k=len(totals))
        count = sum(r[0] for r in selected)
        for index in (0, 1): draws[index].append(sum(r[index + 1] for r in selected) / count)
    result = {"paired_rooms": len(base), "seed_clusters": len(totals)}
    for index, field in enumerate(("win_rate", "hp_lost")):
        ordered = sorted(draws[index])
        result[field] = {"mean": sum(t[index + 1] for t in totals) / len(base),
                         "ci95": [ordered[int(.025 * BOOTSTRAP_RESAMPLES)],
                                  ordered[int(.975 * BOOTSTRAP_RESAMPLES) - 1]]}
    return result


def usage(rows: list[dict]) -> dict:
    fields = ("skybolt_hits", "skybolt_kills", "skybolt_cancelled_attacks", "skybolt_hits_beyond_5",
              "skybolt_hits_without_los", "skybolt_casts_beyond_5", "skybolt_casts_without_los")
    totals = {key: int(sum(r["card_usage"][key] for r in rows)) for key in fields}
    casts = int(sum(r["card_usage"]["casts"].get("skybolt", 0) for r in rows))
    return {"n": len(rows), "casts": casts, **totals,
            "casts_per_fight": casts / len(rows),
            "hits_per_cast": totals["skybolt_hits"] / casts if casts else None,
            "cancelled_attacks_per_cast": totals["skybolt_cancelled_attacks"] / casts if casts else None,
            "kills_per_fight": totals["skybolt_kills"] / len(rows)}


def render(report: dict) -> str:
    lines = ["# Skybolt paired measurement", "",
             f'Revision 7; policy v2 `{report["policy_sha256"]}`; source HEAD `{report["source_head"]}`. '
             f'{report["runs_per_arm"]} fights per arm per cohort/tier, first seed {report["first_seed"]}. '
             'Each arm adds exactly one card to the unchanged tier preset; `none` retains the preset. '
             'No gameplay, authored data, or policy changes.', "",
             'Samples follow the existing revision-7 bot: ascending seeds, then production section order, '
             'taking the first 150 natural matching rooms per cohort/tier (bosses pooled across six dragons). '
             'Arms use identical ordered seed/section/room/entrance identities. A seed supplies multiple fights; '
             '150 fights does not mean 150 distinct seeds. All outcomes enter turns and HP percentiles. '
             'HP lost is cumulative actual `damage_received`, including fatigue, rather than net HP loss. '
             'Turns count hero activations; turn-cap losses retain the existing policy limit.', "",
             'Tables give median (nearest-rank P10–P90). Deltas are arm minus `none`: mean paired win '
             'difference in percentage points and mean paired cumulative HP difference. Negative HP means '
             'less damage received. Brackets are 95% percentile bootstrap CIs, resampling whole paired map-seed '
             f'clusters ({BOOTSTRAP_RESAMPLES:,} resamples; RNG seed {BOOTSTRAP_SEED}). These describe this bounded '
             'policy and sample, not optimal human play. Raw records, deck lists, literal overrides, hashes '
             'and recomputable summaries are in `data/` and `summary.json`.', "",
             'V1 sets `shock_all_hits: false`; V2 sets `burn: true`; V3 sets range 5 and removes '
             '`ignore_los`; V4 sets Time 9; V5 combines V1 and V2. Production carries printed '
             '`shock: 1` onto conducted hits even when `shock_all_hits` is false. The offline engine '
             'therefore adapts that override to suppress Shock on every enemy except the aimed primary '
             'target, preserving conducted damage and all other rules. A ground/conductor aim has no '
             'primary enemy to Shock. This adapter applies only to V1/V5; production is unchanged.', ""]
    for tier, cohort in GROUPS:
        lines += [f'## Tier {tier} — {cohort}', "",
                  '| Arm | N | Win rate | Turns | HP lost | Δ wins pp [95% CI] | Δ HP [95% CI] |',
                  '|---|---:|---:|---:|---:|---:|---:|']
        for group in report["groups"]:
            if (group["tier"], group["cohort"]) != (tier, cohort): continue
            def delta(field: str, scale: float = 1) -> str:
                d = group["paired_delta"][field]
                return f'{d["mean"] * scale:+.2f} [{d["ci95"][0] * scale:+.2f}, {d["ci95"][1] * scale:+.2f}]'
            lines.append(f'| {group["arm"]} | {group["n"]} | {group["win_rate"]:.1%} | '
                         f'{cell(group["turns"])} | {cell(group["hp_lost"])} | {delta("win_rate", 100)} | {delta("hp_lost")} |')
        lines.append("")
    lines += ['## Skybolt usage', '',
              'Counts include committed states only; speculative policy branches and intent previews are excluded. '
              'Hits include primary and conducted enemies, including blocked or lethal hits, with each footprint '
              'counted once. Cancelled attacks count damaging instructions in the intent at the start '
              'of an activation restricted by Shock attributed to Skybolt; dead, Frozen or Petrified '
              'activations and special actions exempt from Shock are excluded. This counts prohibited '
              'attack instructions, not counterfactual hits or HP saved. '
              'Kills use the production kill-counter delta during the card action, excluding objective-cleared '
              'followers. Range/LOS use the nearest footprint tile/any footprint tile from the casting origin; '
              'LOS means physical line of sight, distinct from Umbra visibility. Conduction can carry a hit '
              'beyond the primary targeting limits, including for V3. Cast shares count a cast once if any hit '
              'qualifies. All ratios use total casts, including fights with zero casts.', '',
              '| Tier / cohort | Arm | Casts / fight (total) | Enemies / cast | Cancelled attacks / cast | Kills (per fight) | Hits >5 / no LOS | Casts with >5 / no LOS |',
              '|---|---|---:|---:|---:|---:|---:|---:|']
    for group in report['groups']:
        if 'skybolt_usage' not in group: continue
        u = group['skybolt_usage']
        def ratio(value: int) -> str:
            return f'{value / u["casts"]:.1%}' if u['casts'] else '—'
        lines.append(f'| {group["tier"]} / {group["cohort"]} | {group["arm"]} | '
                     f'{u["casts_per_fight"]:.2f} ({u["casts"]}) | {u["hits_per_cast"]:.2f} | '
                     f'{u["cancelled_attacks_per_cast"]:.2f} | {u["skybolt_kills"]} ({u["kills_per_fight"]:.2f}) | '
                     f'{u["skybolt_hits_beyond_5"]} / {u["skybolt_hits_without_los"]} | '
                     f'{ratio(u["skybolt_casts_beyond_5"])} / {ratio(u["skybolt_casts_without_los"])} |')
    pooled = {arm: [g for g in report['groups'] if g['arm'] == arm] for arm in ARMS}
    def wins(arm: str) -> float:
        return statistics.mean(g['win_rate'] for g in pooled[arm])
    lines += ['', '## Comparisons', '',
              f'Across the seven equally sized cohorts, `none` won {wins("none"):.1%}, Skybolt '
              f'{wins("skybolt"):.1%}, Wildfire Halo {wins("wildfire_halo"):.1%}, and Stormstring Shot '
              f'{wins("stormstring_shot"):.1%}. V1–V5 won ' + ', '.join(f'{wins(a):.1%}' for a in ('V1', 'V2', 'V3', 'V4', 'V5')) +
              ', respectively. '
              'Cohort-specific paired differences and uncertainty are shown above.', '']
    return '\n'.join(lines)


def build_report(output: Path, metadata: dict) -> dict:
    groups = []
    for tier, cohort in GROUPS:
        base = read_report(output / 'data' / f't{tier}-{cohort}-none.json.gz')['results']
        for arm, addition in ARMS.items():
            path = output / 'data' / f't{tier}-{cohort}-{arm}.json.gz'
            raw = read_report(path)
            rows = raw['results']
            if len(rows) != metadata['runs_per_arm'] or len({identity(r) for r in rows}) != len(rows):
                raise ValueError(f'Incomplete or duplicate arm: {path}')
            if raw.get('deck_override', {}) != addition:
                raise ValueError(f'Override mismatch: {path}')
            if arm in ('V1', 'V5') and not all(r.get('primary_only_shock_adapter') for r in rows):
                raise ValueError(f'Primary-only Shock requires adapter-aware records: {path}')
            if addition.get('card') == 'skybolt' and not all(r['card_usage'].get('origin_metric') == 'caster_v1' for r in rows):
                raise ValueError(f'Skybolt range/LOS requires caster-origin counters: {path}')
            if addition and not sum(r['card_usage']['casts'].get(addition['card'], 0) for r in rows):
                raise RuntimeError('TODO_DESIGN_bot_never_plays_' + addition['card'])
            group = {'tier': tier, 'cohort': cohort, 'arm': arm, **summarize(rows),
                     'paired_delta': paired_delta(base, rows), 'file': str(path.relative_to(output)), 'sha256': sha(path)}
            if addition.get('card') == 'skybolt': group['skybolt_usage'] = usage(rows)
            groups.append(group)
    return {**metadata, 'groups': groups}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    parser.add_argument('--workers', type=int, default=WORKERS)
    parser.add_argument('--report-only', action='store_true')
    parser.add_argument('--resume-dir', type=Path, help='existing temporary raw checkpoint directory')
    parser.add_argument('--refresh-skybolt-metrics', action='store_true', help='replay stale Skybolt counters, requiring identical outcomes')
    args = parser.parse_args()
    if args.workers < 1: parser.error('workers must be positive')
    if args.refresh_skybolt_metrics and (not args.resume_dir or args.report_only):
        parser.error('--refresh-skybolt-metrics requires a measured --resume-dir run')
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.report_only:
        metadata = json.loads((output / 'summary.json').read_text())
        metadata.pop('groups', None)
    else:
        if sha(ROOT / 'tools/encounter_bot.gd') != POLICY_SHA256:
            raise RuntimeError('Frozen policy hash changed')
        LOG_ROOT.mkdir(parents=True, exist_ok=True)
        work = args.resume_dir or Path(tempfile.mkdtemp(prefix='sweep-', dir=LOG_ROOT))
        (output / 'data').mkdir(exist_ok=True)
        metadata = {'schema_version': 1, 'revision': 7, 'policy_sha256': POLICY_SHA256,
                    'source_head': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
                    'runs_per_arm': RUNS, 'first_seed': FIRST_SEED, 'arms': ARMS, 'workers': args.workers,
                    'ci_method': {'type': 'paired seed-cluster percentile bootstrap', 'resamples': BOOTSTRAP_RESAMPLES, 'seed': BOOTSTRAP_SEED},
                    'tool_sha256': {name: sha(ROOT / 'tools' / name) for name in TOOL_FILES},
                    'data_sha256': {name: sha(ROOT / 'data' / name) for name in ('cards.json', 'enemies.json')},
                    'measurement_adapters': ['primary_only_shock_v1'], 'design_placeholders': []}
        (output / 'summary.json').write_text(json.dumps(metadata, indent=2) + '\n')
        print(f'SKYBOLT CHECKPOINTS: {work}', flush=True)

        def measure(job: tuple) -> None:
            tier, cohort, arm = job
            addition = ARMS[arm]
            stem = f't{tier}-{cohort}-{arm}'
            path = work / f'{stem}.json'
            arguments = ['--revision', '7', '--tier', str(tier), '--cohort', cohort, '--seed', str(FIRST_SEED),
                         '--runs', str(RUNS), '--output', str(path), '--measure-usage']
            if addition: arguments += ['--add-card', addition['card'], '--card-overrides', json.dumps(addition['fields'])]
            if path.exists(): arguments += ['--resume-report', str(path)]
            if args.refresh_skybolt_metrics: arguments += ['--refresh-skybolt-metrics']
            run_engine('tools/encounter_measurement_bot.gd', arguments, work / f'{stem}.log', task_id=TASK_ID)
            compress_report(path, output / 'data' / f'{stem}.json.gz')
        with ThreadPoolExecutor(max_workers=args.workers) as pool:
            list(pool.map(measure, [(t, c, a) for t, c in GROUPS for a in ARMS]))
        for name, digest in metadata['tool_sha256'].items():
            if sha(ROOT / 'tools' / name) != digest: raise RuntimeError('Tool changed during measurement: ' + name)
        for name, digest in metadata['data_sha256'].items():
            if sha(ROOT / 'data' / name) != digest: raise RuntimeError('Data changed during measurement: ' + name)
    report = build_report(output, metadata)
    (output / 'summary.json').write_text(json.dumps(report, indent=2) + '\n')
    (output / 'report.md').write_text(render(report))
    print(f'SKYBOLT MEASUREMENT: PASS ({len(report["groups"])} arms/cohorts; {RUNS * len(report["groups"])} paired fights); {output / "report.md"}')


if __name__ == '__main__':
    main()
