#!/usr/bin/env python3
"""Read-only live progress for the tier collector; no engine process launched."""
from collections import Counter
import json
from pathlib import Path
import sys
from statistics import median


def progress(directory):
    rows = [json.loads(p.read_text()) for p in directory.glob('fight-*.jsonl') if p.stat().st_size]
    counts = Counter(r['section'] for r in rows)
    blocks = Counter((r['section'],r['ladder_seed'],r['repeat']) for r in rows)
    print(f'DIFF01_PROGRESS raw_fights={len(rows)} complete_six_fight_blocks={sum(n==6 for n in blocks.values())} '
          f'by_section={dict(sorted(counts.items()))}')
    if rows:
        print(f"median_fight_seconds={median(r['elapsed_seconds'] for r in rows):.2f} "
              f"summed_fight_seconds={sum(r['elapsed_seconds'] for r in rows):.1f}")

if __name__=='__main__': progress(Path(sys.argv[1]))
