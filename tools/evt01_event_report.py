"""Compare evt-01's matched event oracle without replacing a frozen assertion."""
import argparse
from collections import Counter
import json
from pathlib import Path


def added_or_removed(value, path, added):
    if isinstance(value, dict) and value:
        for key in sorted(value):
            yield from added_or_removed(value[key], f"{path}/{key}", added)
    elif isinstance(value, list) and value:
        for index, child in enumerate(value):
            yield from added_or_removed(child, f"{path}/{index}", added)
    else:
        yield {"field": path, "before": None if added else value,
               "after": value if added else None}


def differences(before, after, path=""):
    if isinstance(before, dict) and isinstance(after, dict):
        for key in sorted(before.keys() | after.keys()):
            field = f"{path}/{key}"
            if key not in before or key not in after:
                yield from added_or_removed(after[key] if key in after else before[key], field, key in after)
            else:
                yield from differences(before[key], after[key], field)
    elif isinstance(before, list) and isinstance(after, list):
        for index in range(max(len(before), len(after))):
            field = f"{path}/{index}"
            if index >= len(before) or index >= len(after):
                yield from added_or_removed(after[index] if index < len(after) else before[index], field, index < len(after))
            else:
                yield from differences(before[index], after[index], field)
    elif before != after:
        yield {"field": path, "before": before, "after": after}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", type=Path, required=True)
    parser.add_argument("--after", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    before = json.loads(args.before.read_text())
    after = json.loads(args.after.read_text())
    rows = list(differences(before["golden"], after["golden"], "/golden"))
    for row in rows:
        event = row["field"].split("/")[3]
        seed = row["field"].split("/")[2]
        row["reason"] = ("Director's 18 new events add authored choice/result transactions."
                         if event not in before["golden"][seed] else
                         "Director replaces dice outcomes with fixed tradeoffs; concrete seeded rewards follow the new ordered effect/RNG sequence.")
    report = {"distribution_before": {k: v for k, v in before.items() if k != "golden"},
              "distribution_after": {k: v for k, v in after.items() if k != "golden"},
              "changed_leaves": rows,
              "changed_events": dict(sorted(Counter(row["field"].split("/")[3] for row in rows).items()))}
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(f"EVT01 GOLDEN DIFF: {len(rows)} changed leaves across {len(report['changed_events'])} events; {args.output}")


if __name__ == "__main__":
    main()
