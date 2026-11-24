#!/usr/bin/env python3
"""Combine the eco-03 receipts, verify the paired seeds, and print the tables."""
import json
import math
from pathlib import Path
import sys

CATEGORIES = ("gear", "magic", "item")
RARITIES = ("common", "rare", "epic", "legendary")
MAP_SEEDS = set(range(1, 1001))
BOT_SEEDS = set(range(1, 101))
MAP_SHARDS = (1, 251, 501, 751)
BOT_SHARDS = (1, 26, 51, 76)


def read_rows(path):
    # The first release shard hit the runner timeout. Count completed rows
    # only, then require every seed after merging the continuation.
    raw = path.read_text()
    return [json.loads(line) for line in raw[:raw.rfind("\n")].splitlines()]


def index_seeds(rows, expected):
    index = {row["seed"]: row for row in rows}
    assert len(index) == len(rows) and index.keys() == expected
    return index


def percentiles(values):
    values = sorted(values)
    return [values[max(0, math.ceil(len(values) * p) - 1)] for p in (0, 0.1, 0.5, 0.9)]


def table(headers, rows):
    print("| " + " | ".join(headers) + " |")
    print("| " + " | ".join("---" for _ in headers) + " |")
    for row in rows:
        print("| " + " | ".join(str(value) for value in row) + " |")
    print()


def affordable(stock, wallet):
    assert len(stock) == 9
    return sum(offer["buy"] <= wallet for offer in stock)


def report_maps(before, after):
    samples = (("Release", before), ("Revision 8", after))
    rows = []
    for phase, sample in samples:
        for label, values in (("Rooms through arrival", [len(row["path"]) for row in sample.values()]),
                              ("Fights before arrival", [row["fights"] for row in sample.values()]),
                              ("Base Embers on arrival", [row["embers"] for row in sample.values()])):
            rows.append((phase, label, *percentiles(values)))
    table(("Map", "Section I metric", "Min", "P10", "Median", "P90"), rows)

    rows = []
    for section in range(6):
        old = sum(row["shops"][section] for row in before.values()) / len(before)
        new = sum(row["shops"][section] for row in after.values()) / len(after)
        assert new >= 0.9 * old
        rows.append((section + 1, f"{old:.3f}", f"{new:.3f}", f"{(new / old - 1) * 100:+.2f}%"))
    table(("Section", "Release Scavengers", "Revision 8 Scavengers", "Change"), rows)
    counts = []
    for label, sample in samples:
        counts.append((label, sum(row["early_sections"] > 0 for row in sample.values()),
                       sum(row["early_sections"] for row in sample.values()),
                       sum(row["fallback_sections"] for row in sample.values())))
    table(("Map", "Seeds with early shops", "Sections with early shops", "Fallback sections"), counts)
    assert counts[1][1] == 0

    old_median = percentiles([row["embers"] for row in before.values()])[2]
    new_median = percentiles([row["embers"] for row in after.values()])[2]
    affordability = [
        (label, wallet, percentiles([affordable(row[key], wallet) for row in sample.values()])[2])
        for label, wallet, sample, key in (
            ("Release routes and stock", old_median, before, "stock"),
            ("Revision 8 routes before common guarantee", new_median, after, "rolled_stock"),
            ("Revision 8 routes with common guarantee", new_median, after, "stock"),
        )
    ]
    table(("Sample", "Median wallet", "Median independently affordable offers out of nine"), affordability)
    for name, sample, wallet in (("Release", before, old_median), ("Revision 8", after, new_median)):
        at_median = [row for row in sample.values() if row["embers"] == wallet]
        example = min(at_median, key=lambda row: row["seed"])
        path = " → ".join(f'{kind} ({coord})' for coord, kind in zip(example["path"], example["kinds"]))
        print(f"{name} median-wallet example, seed {example['seed']}. Start → {path}.")
        zero = sum(affordable(row["stock"], row["embers"]) == 0 for row in sample.values())
        print(f"{name} seeds with zero affordable offers at their own projected wallet, {zero}/{len(sample)}.")
        print()
    return new_median


def report_prices(directory):
    before = json.loads((directory / "prices-before.json").read_text())
    after = json.loads((directory / "prices-after.json").read_text())
    assert before == after
    rows = []
    for category in CATEGORIES:
        for rarity in RARITIES:
            quote = after["rows"][f"{category}/{rarity}"]
            assert len(set(quote["buy"][:16])) == 1 and len(set(quote["buy"][16:])) == 1
            rows.append((category, rarity, f'{quote["buy"][1]} → {quote["buy"][1]}',
                         f'{quote["buy"][16]} → {quote["buy"][16]}', quote["sell"],
                         quote["debt_buy"][1], quote["debt_buy"][16]))
    table(("Category", "Rarity", "Buy depth 0–15 before → after", "Buy depth 16–20 before → after",
           "Sell both", "Debt buy depth 1 both", "Debt buy depth 16 both"), rows)
    table(("Prior priced purges", "Purge price both", "Debt purge price both"),
          [(count, row["base"], row["debt"]) for count, row in enumerate(after["purge"])])


def report_bot(directory):
    rows = [row for start in BOT_SHARDS for row in read_rows(directory / f"bot-complete-{start}.jsonl")]
    results = []
    for phase in ("before", "after"):
        sample = index_seeds([row for row in rows if row["phase"] == phase], BOT_SEEDS)
        arrived = [row for row in sample.values() if row["arrival"]]
        assert all(row["arrival"]["section"] == 1 for row in arrived)
        results.append((phase, len(arrived), sum(row["forced_victories"] for row in sample.values()),
                        *percentiles([row["arrival"]["embers"] for row in arrived])))
    table(("Ladder", "Shop arrivals / 100", "Forced victories", "Min", "P10", "Median", "P90"),
          [(phase, f"{arrivals}/100", *stats) for phase, arrivals, *stats in results])


def main():
    directory = Path(sys.argv[1])
    before = index_seeds([row for name in ("before", "before-900")
                          for row in read_rows(directory / f"{name}.jsonl")[1:]], MAP_SEEDS)
    after = index_seeds([row for start in MAP_SHARDS
                         for row in read_rows(directory / f"final-{start}.jsonl")[1:]], MAP_SEEDS)
    median = report_maps(before, after)
    print("## Price identity\n")
    report_prices(directory)
    fixtures = [row for row in after.values() if row["embers"] == median and row["stock"] != row["rolled_stock"]]
    fixture = min(fixtures, key=lambda row: row["seed"])
    print("Native fixture:", json.dumps({"seed": fixture["seed"], "held_embers": median,
          "stock": [offer["id"] for offer in fixture["stock"]],
          "rolled_stock": [offer["id"] for offer in fixture["rolled_stock"]]}))
    print()
    if "--without-bot" not in sys.argv:
        print("## Bot arrival wallet\n")
        report_bot(directory)
    print("ECO03 MEASUREMENT: PASS")


if __name__ == "__main__":
    main()
