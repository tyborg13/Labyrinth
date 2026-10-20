"""Compact tracked proof; full, hashed evidence remains in ignored logs."""
from case import CASE, read_json, write_json, digest
from humanoid_cutout.walk_gates import summary as walk_summary

def compact(result):
    if isinstance(result, list):
        return [compact(item) for item in result]
    if not isinstance(result, dict):
        return result
    counts = {key: len(value) for key, value in result.items()
              if key in ('rows', 'frames', 'stance', 'jab', 'rigid_air', 'overreach', 'rest_space') and isinstance(value, list)}
    retained = {key: compact(value) for key, value in result.items() if key not in counts}
    if counts:
        retained['sample_counts'] = {**retained.get('sample_counts', {}), **counts}
    if 'swings' in result and 'frames' in result:
        return compact(walk_summary(result))
    return retained


def write(name, result):
    full = CASE / f'proof/logs/{name}.full.json'
    write_json(full, result)
    summary = compact(result)
    summary['full_samples'] = {'file': str(full.relative_to(CASE / 'proof')), 'sha256': digest(full)}
    write_json(CASE / f'proof/{name}.json', summary)
