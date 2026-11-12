"""Frame attribution and stable catalog identities; timers are not additive GPU work."""
from array import array
import re

BUCKETS = ('process', 'physics', 'pre_process', 'draw', 'subviewports', 'driver', 'observer')


def hitch_id(frame):
    context = frame['context']
    action = context.get('action', 'unknown')
    if action.startswith('controller:'):
        # Godot as_text(): Joypad Button 0 (A, Cross) ... . Preserve stable
        # button identity while dropping device/pressure/pressed decorations.
        text = action.split(':', 1)[1]
        button = re.search(r'Joypad Button (\d+) \(([^,)]+)', text)
        axis = re.search(r'Joypad Motion on Axis (\d+)', text)
        buttons = {0: 'A', 1: 'B', 2: 'X', 3: 'Y', 4: 'Back', 5: 'Guide', 6: 'Start',
                   7: 'LS', 8: 'RS', 9: 'LB', 10: 'RB', 11: 'D-pad Up', 12: 'D-pad Down',
                   13: 'D-pad Left', 14: 'D-pad Right'}
        short = buttons.get(int(button.group(1)), button.group(2)) if button else ('axis:' + axis.group(1) if axis else text.split()[0])
        action = 'controller:' + short
    return context.get('screen', 'unknown') + '/' + action


def attribute(frame, previous_video_bytes):
    driver = sum(frame.get('driver_cpu_us', {}).values()) / 1000.0
    # The previous sample callback (trace writes included) runs after post_draw, so its cost lands in
    # this frame's interval and pre_process bucket; it is observer time, not game time.
    observer = (frame.get('observer_previous_us') or 0) / 1000.0
    game = max(0.0, frame['draw_interval_ms'] - driver - observer)
    accurate = frame.get('frame_accurate', False)
    driver_buckets = frame.get('driver_bucket_us', {})
    def wall(key, bucket, extra=0.0):
        value = frame.get(key) if accurate else None
        return max(0.0, value - driver_buckets.get(bucket, 0) / 1000.0 - extra) if value is not None else None
    buckets = dict(process=wall('process_wall_ms', 'process'),
                   physics=wall('physics_wall_ms', 'physics'),
                   pre_process=wall('pre_process_ms', 'pre_process', observer),
                   draw=wall('draw_wall_ms', 'draw'),
                   subviewports=(frame.get('subviewports') or {}).get('cpu_ms'), driver=driver, observer=observer)
    video = frame.get('monitors', {}).get('RENDER_VIDEO_MEM_USED')
    delta = (video - previous_video_bytes) / (1024 * 1024) if video is not None and previous_video_bytes is not None else None
    return dict(game_ms=game, buckets_ms=buckets, video_mem_delta_mb=delta, resource_count_delta=frame.get('resource_count_delta')), video


def new_catalog_row(frame, run):
    return dict(hitch_id=hitch_id(frame), profile=run['profile'], cache=run['cache'],
                values=array('d'), raw_values=array('d'), slow_buckets={k: [] for k in BUCKETS},
                over_ms={'50.0': 0, '100.0': 0}, pipeline_compiles=0, instances_added=0,
                redraw_spans=[], load_totals_us={}, continuation_totals_us={}, explained_pre_process_ms=[],
                resource_deltas=[], video_delta_total=0.0, video_delta_count=0, worst=None)


def add_catalog_frame(row, frame, replay):
    game = frame['game_ms']
    row['values'].append(game)
    row['raw_values'].append(frame['draw_interval_ms'])
    for threshold in (50.0, 100.0):
        row['over_ms'][str(threshold)] += int(game > threshold)
    if game > 50:
        if 'redraw_span_ms' in frame: row['redraw_spans'].append(frame['redraw_span_ms'])
        load_total = 0
        continuation_total = 0
        for label, entry in frame['events'].items():
            if label.startswith('load:'):
                usec = entry['total_us']
                row['load_totals_us'][label] = row['load_totals_us'].get(label, 0) + usec
                load_total += usec
        # These spans are drained at the observer boundary, independently of the
        # process telemetry frame ID (which can reset before a draw continuation).
        for label, usec in frame.get('phase_times_us', {}).items():
            if label.startswith(('post_draw:', 'input:')):
                row['continuation_totals_us'][label] = row['continuation_totals_us'].get(label, 0) + usec
                continuation_total += usec
        pre_process = frame['buckets_ms']['pre_process']
        if pre_process is not None:
            row['explained_pre_process_ms'].append(min(pre_process, (load_total + continuation_total) / 1000.0))
        for name, value in frame['buckets_ms'].items():
            if value is not None:
                row['slow_buckets'][name].append(value)
    for event, count in frame['events'].items():
        if event.startswith('pipeline:'): row['pipeline_compiles'] += count
        if event.startswith('instance:'): row['instances_added'] += count
    if frame.get('resource_count_delta') is not None: row['resource_deltas'].append(frame['resource_count_delta'])
    delta = frame['video_mem_delta_mb']
    if delta is not None:
        row['video_delta_total'] += delta
        row['video_delta_count'] += 1
    if row['worst'] is None or game > row['worst']['game_ms']:
        row['worst'] = dict(frame=frame['frame'], game_ms=game, replay=replay,
                            seed=frame['context'].get('seed'), decision=frame['context'].get('decision'))


def finish_catalog(rows, stats):
    result = []
    for row in rows.values():
        row['top_load_paths_over50_us'] = sorted(row.pop('load_totals_us').items(), key=lambda item: (-item[1], item[0]))[:5]
        row['top_post_draw_input_over50_us'] = sorted(row.pop('continuation_totals_us').items(), key=lambda item: (-item[1], item[0]))[:5]
        spans = row.pop('redraw_spans')
        row['redraw_span_ms'] = sum(spans) / len(spans) if spans else None
        explained = row.pop('explained_pre_process_ms')
        row['mean_explained_pre_process_over50_ms_estimate'] = sum(explained) / len(explained) if explained else None
        row.update(stats(row.pop('values')))
        row['raw_interval_ms'] = stats(row.pop('raw_values'))
        row['mean_buckets_over50_ms'] = {k: sum(v) / len(v) if v else None
                                         for k, v in row.pop('slow_buckets').items()}
        # SubViewport CPU is nested inside draw; driver is removed from game time.
        exclusive = {k: v for k, v in row['mean_buckets_over50_ms'].items()
                     if k not in ('subviewports', 'driver', 'observer') and v is not None}
        row['dominant_bucket'] = max(exclusive, key=exclusive.get) if exclusive else 'n/a'
        resource_deltas = row.pop('resource_deltas')
        row['resource_count_delta_proxy'] = dict(net=sum(resource_deltas), positive=sum(max(0, n) for n in resource_deltas), samples=len(resource_deltas))
        count = row.pop('video_delta_count')
        row['mean_video_mem_delta_mb'] = row.pop('video_delta_total') / count if count else None
        result.append(row)
    return sorted(result, key=lambda r: (-r['over_ms']['100.0'], -r['max'], r['hitch_id'], r['profile'], r['cache']))


def catalog_markdown(rows):
    lines = ['| Hitch id / profile / cache | Raw p99 / p99.9 / max ms | Frames / >50 / >100 | Game p99 / p99.9 / max ms | Mean >50 buckets ms: process / physics / pre_process / draw (SubVP) / driver | Dominant | Pipeline / instances | Mean video Δ MiB / resource Δ proxy (net, positive) | Top 5 loads µs (>50) | Top 5 post_draw/input µs (>50) | Explained pre_process mean ms (estimate, capped) | redraw_span_ms (mean >50) | Worst replay |',
             '|---|---:|---:|---:|---|---|---:|---:|---|---|---:|---:|---|']
    def number(value):
        return 'n/a' if value is None else f'{value:.3f}'
    for row in rows:
        raw = row['raw_interval_ms']
        buckets = row['mean_buckets_over50_ms']
        bucket_text = ' / '.join(number(buckets[k]) + (' (' + number(buckets['subviewports']) + ')' if k == 'draw' else '')
                                 for k in ('process', 'physics', 'pre_process', 'draw', 'driver'))
        replay = row['worst']['replay'].replace('|', '&#124;').replace('\n', ' ')
        lines.append(f"| {row['hitch_id']} / {row['profile']} / {row['cache']} | " +
                     ' / '.join(number(raw[k]) for k in ('p99', 'p99.9', 'max')) +
                     f" | {row['count']} / {row['over_ms']['50.0']} / {row['over_ms']['100.0']} | " +
                     ' / '.join(number(row[k]) for k in ('p99', 'p99.9', 'max')) +
                     f" | {bucket_text} | {row['dominant_bucket']} | {row['pipeline_compiles']} / {row['instances_added']} | {number(row['mean_video_mem_delta_mb'])} / {row['resource_count_delta_proxy']['net']}, {row['resource_count_delta_proxy']['positive']} | {row['top_load_paths_over50_us']} | {row['top_post_draw_input_over50_us']} | {number(row['mean_explained_pre_process_over50_ms_estimate'])} | {number(row['redraw_span_ms'])} | `{replay}` |")
    return lines
