"""Process shards and checked-frame evidence shared by exhaustive sweeps."""
from __future__ import annotations

from concurrent.futures import ProcessPoolExecutor, ThreadPoolExecutor
import json
import multiprocessing
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
MAX_WORKERS = 8
GODOT_TIMEOUT_SECONDS = 180


def worker_count():
    configured = os.environ.get('LABYRINTH_SWEEP_WORKERS')
    if configured is not None:
        value = int(configured)
        if value < 1:
            raise ValueError('LABYRINTH_SWEEP_WORKERS must be positive')
        return min(MAX_WORKERS, value)
    return min(MAX_WORKERS, max(1, (os.cpu_count() or 1) - 2))


def partition(rows, workers):
    """Stable, disjoint pose shards; each nonempty shard preserves input order."""
    return [rows[index::workers] for index in range(min(workers, len(rows)))]


def map_shards(function, rows, workers=None):
    workers = worker_count() if workers is None else workers
    chunks = partition(rows, workers)
    if len(chunks) <= 1:
        return [function(chunk) for chunk in chunks]
    with ProcessPoolExecutor(max_workers=len(chunks), mp_context=multiprocessing.get_context('spawn')) as pool:
        return list(pool.map(function, chunks))


def frame_key(pose, variant=None):
    key = (pose['view'], pose['clip'], pose['frame'])
    return key if variant is None else (*key, variant)


def checked_frames(test_id, expected, checked, started):
    """Multiset equality catches duplicates as well as missing/extra frames."""
    expected, checked = sorted(expected), sorted(checked)
    if checked != expected:
        raise AssertionError(f'{test_id}: serial/parallel frame inventory differs')
    record = dict(test=test_id, workers=worker_count(), duration=time.monotonic() - started,
                  checked_frames=checked)
    directory = os.environ.get('LABYRINTH_SWEEP_PROOF_DIR')
    if directory:
        path = Path(directory) / (test_id + '.json')
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(record, sort_keys=True) + '\n')
    print(f'SWEEP CHECKED {test_id}: {len(checked)} frames/choices; '
          f'{record["workers"]} workers; {record["duration"]:.3f}s', flush=True)


def sample_poses(script, *args, label):
    """Separate Godot runner invocation and isolated task namespace per shard."""
    workers = worker_count()
    with tempfile.TemporaryDirectory(prefix='perf-06-samples-') as directory:
        def sample(index):
            output = Path(directory) / f'{index}.json'
            task = os.environ.get('LABYRINTH_TASK_ID', 'perf-06') + f'-{label}-{index}'
            command = [sys.executable, str(ROOT / 'tools/godot_task_runner.py'), '--task-id', task,
                       '--stream', '--', 'godot', '--headless', '--path', str(ROOT), '--script', script,
                       '--', *map(str, args), '--output', str(output),
                       '--sweep-shard-index', str(index), '--sweep-shard-count', str(workers)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                    timeout=GODOT_TIMEOUT_SECONDS)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
            return json.loads(output.read_text())
        with ThreadPoolExecutor(max_workers=workers) as pool:
            parts = list(pool.map(sample, range(workers)))
    result = dict(parts[0])
    metadata = {key: value for key, value in result.items() if key != 'samples'}
    if any({key: value for key, value in part.items() if key != 'samples'} != metadata for part in parts):
        raise AssertionError('Godot sample shards disagree about their inputs or runtime metadata')
    # Shards are round-robin partitions of the original authored/presented rows.
    result['samples'] = [row for group in __import__('itertools').zip_longest(
        *(part['samples'] for part in parts)) for row in group if row is not None]
    if any(part.get('errors') or not part.get('ok') for part in parts):
        raise AssertionError(parts)
    print(f'SWEEP SAMPLES {label}: {len(result["samples"])} poses; {workers} isolated Godot invocations', flush=True)
    return result
