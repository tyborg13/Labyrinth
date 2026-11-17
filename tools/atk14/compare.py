#!/usr/bin/env python3
"""Compare preserved atk13 baseline and atk14 census using actual presentation rows.

No generated data or renderer claims. Status false alarms compare the aggregate
PASS row to gained-status receipts, including gains consumed before hero start.
"""
from collections import Counter
import json
from pathlib import Path

BASE = Path('/private/tmp/labyrinth_codex/atk-13/audit')
AFTER = Path('/private/tmp/labyrinth_codex/atk-14/audit')

def samples(root, labels):
    return [json.loads(line) for label in labels for path in sorted((root/label).glob('tier-*/samples.jsonl'))
            if (path.parent/'completed.json').exists()
            for line in path.read_text().splitlines() if json.loads(line).get('kind') == 'check' and json.loads(line).get('mode') in ('pass', 'move')]

def analyze(checks):
    status_matrix = Counter()
    status_amounts = Counter()
    chain = Counter()
    for row in checks:
        shown = row['shown'].get('status_rows', {})
        actual = Counter()
        for receipt in row.get('receipts', []): actual.update(receipt.get('statuses', {}))
        # Action-external status gains are retained by the activation oracle.
        sliced = Counter()
        for part in row['actual']['slices']: sliced.update(part.get('statuses', {}))
        actual |= sliced
        for status in set(shown) | set(actual):
            status_matrix[f'{status}:{int(shown.get(status, 0)>0)}{int(actual[status]>0)}'] += 1
            if int(shown.get(status, 0)) != actual[status]: status_amounts[status] += 1
        if row['mode'] == 'move' and row.get('forecast_chain_receipt_version') == 1:
            expected = bool(row['forecast_chain_hero_owners'])
            if expected:
                chain['forecast_hits'] += 1
                chain['red'] += bool(row.get('red_hover'))
                chain['misses'] += not bool(row.get('red_hover'))
    return dict(checks=len(checks), status_matrices=dict(status_matrix), status_amount_disagreements=dict(status_amounts), hovered_forecast_chain=dict(chain))

def main():
    result = {'before': analyze(samples(BASE, ['census', 'real-health'])),
              'after': analyze(samples(AFTER, ['census-after', 'real-health-after']))}
    out = AFTER.parent/'comparison.json'
    out.write_text(json.dumps(result, indent=2)+'\n')
    for label, value in result.items(): print(f'ATK14 COMPARE {label}: '+json.dumps(value, sort_keys=True))
    print(f'ATK14 COMPARISON: {out}')

if __name__ == '__main__': main()
