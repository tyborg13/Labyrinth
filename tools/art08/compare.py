"""Compare the real Burrow and Erupt presentation traces at matched proof times."""
import argparse
import json
from pathlib import Path


def compare(before, after):
    for kind in ("burrow", "erupt"):
        base = [row for row in before["timeline"][kind] if row["clip"] == kind]
        current = [row for row in after["timeline"][kind] if row["clip"] == kind]
        if not base or base != current:
            mismatch = next((i for i, pair in enumerate(zip(base, current)) if pair[0] != pair[1]), None)
            raise SystemExit(f"{kind} trace differs at sample {mismatch}. Counts {len(base)} and {len(current)}.")
        print(f"ART-08 BASE PARITY {kind}: PASS ({len(base)} samples, including root alpha, poses, timing and combat state)")
    for label in ("03_burrow_last", "04_after_burrow", "05_erupt_start", "06_erupt_contact", "07_erupt_contact_plus_233ms"):
        base = before["frames"][label]
        current = after["frames"][label]
        keys = ("seconds", "clip", "phase", "burrowed", "root_alpha", "tile", "player_hp")
        if any(base[key] != current[key] for key in keys):
            raise SystemExit(f"{label} differs between base and current")
        print(f"{label} t={current['seconds']:.6f}s phase={current['phase']:.6f} "
              f"burrowed={current['burrowed']} root_alpha={current['root_alpha']:.4f} tile={current['tile']}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("before", type=Path)
    parser.add_argument("after", type=Path)
    args = parser.parse_args()
    compare(json.loads(args.before.read_text()), json.loads(args.after.read_text()))
