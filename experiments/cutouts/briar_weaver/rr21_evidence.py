"""Compact committed proof, with hash-bound full transforms in ignored logs."""
from collections import Counter
from rr21_case import CASE
from cutout_pipeline.cases import read_json, write_json, digest

FULL_SAMPLES = CASE / 'proof/logs/samples.json'


def compact_samples():
    data = read_json(FULL_SAMPLES)
    result = {key: value for key, value in data.items() if key != 'samples'}
    counts = Counter((r['view'], r['clip'], r['kind']) for r in data['samples'])
    result['sample_counts'] = [dict(view=v, clip=c, kind=k, count=n)
                               for (v, c, k), n in sorted(counts.items())]
    result['full_samples'] = {'file': str(FULL_SAMPLES.relative_to(CASE / 'proof')),
                              'sha256': digest(FULL_SAMPLES)}
    write_json(CASE / 'proof/samples.json', result)
    print('RR21 COMPACT SAMPLES: PASS (%d poses; full transforms in ignored logs)' % len(data['samples']))
    return result


if __name__ == '__main__': compact_samples()
