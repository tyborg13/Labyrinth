#!/usr/bin/env python3
"""Summarize instrumentation smoke data without implying native hitch proof."""
import argparse
from collections import Counter
import json
from pathlib import Path

from report import frames


def summarize(path):
    counts, costs, phases, hits = Counter(), Counter(), Counter(), Counter()
    native = False
    samples = 0
    process_values = []
    stale_phase_maps = 0
    stale_maps_on_disk = 0
    resource_deltas = []
    for header, frame in frames(path):
        native = header['native']
        samples += 1
        stale_maps_on_disk += int(frame.get('phase_map_was_stale', False))
        if frame.get('process_wall_ms') is not None: process_values.append(frame['process_wall_ms'])
        if frame.get('phase_times_us') and frame.get('phase_frame') != frame['frame'] - (0 if native else 1): stale_phase_maps += 1
        if frame.get('resource_count_delta') is not None: resource_deltas.append(frame['resource_count_delta'])
        for label, event in frame['events'].items():
            if label.startswith('load:'):
                counts[label] += event['count']
                costs[label] += event['total_us']
                hits[label] += event['godot_cached_at_entry']
        for label, cost in frame.get('phase_times_us', {}).items():
            if label.startswith(('post_draw:', 'input:')):
                phases[label] += cost
    process_counts = Counter(process_values)
    longest_equal_run = 0
    equal_run = 0
    last_value = None
    for value in process_values:
        equal_run = equal_run + 1 if value == last_value else 1
        longest_equal_run = max(longest_equal_run, equal_run)
        last_value = value
    return dict(process_wall_ms=dict(samples=len(process_values), distinct=len(process_counts), longest_equal_run=longest_equal_run,
                                    min=min(process_values) if process_values else None,
                                    max=max(process_values) if process_values else None,
                                    most_repeated=process_counts.most_common(3)),
                stale_phase_maps_on_disk=stale_maps_on_disk, stale_phase_maps_after_reader=stale_phase_maps,
                resource_delta_proxy=dict(net=sum(resource_deltas), positive=sum(max(0, n) for n in resource_deltas)), native=native, frames=samples, load_event_count=sum(counts.values()),
                load_path_count=len(counts), godot_cached_at_entry=sum(hits.values()),
                top10_load_paths=[dict(path=k, total_us=v, count=counts[k], godot_cached_at_entry=hits[k])
                                  for k, v in costs.most_common(10)],
                post_draw_input_totals_us=dict(phases.most_common()),
                warning='Inclusive nested spans are not additive. Headless textures are dummies; load times understate native creation/uploads.' if not native else 'Inclusive nested spans are not additive.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('trace', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = summarize(args.trace)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print(f"HITCH SPANS: frames={result['frames']} loads={result['load_event_count']} paths={result['load_path_count']} godot_cached_at_entry={result['godot_cached_at_entry']} phases={len(result['post_draw_input_totals_us'])}")


if __name__ == '__main__':
    main()
