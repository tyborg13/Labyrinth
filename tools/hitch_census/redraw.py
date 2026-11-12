"""Streaming redraw comparisons; counts are exact, signal-gap costs are estimates."""
from collections import Counter


def new_cell():
    return dict(frames=0, counts=Counter(), frames_with_redraw=Counter(),
                ms=Counter(), polygons=Counter(), span_ms=0.0,
                remainder_samples=0, before_ms=0.0, after_ms=0.0,
                resume_phase_frames=Counter())


def add_frame(cell, frame):
    cell['frames'] += 1
    cell['counts'].update(frame['redraws'])
    cell['frames_with_redraw'].update(k for k, n in frame['redraws'].items() if n)
    cell['ms'].update(frame.get('redraw_ms_estimate', {}))
    for key, entry in frame.get('redraw_polygons', {}).items():
        for metric, count in entry.items():
            cell['polygons'][key + ':' + metric] += count
    span = frame.get('redraw_span_ms', 0.0)
    cell['span_ms'] += span
    process = frame['buckets_ms']['process']
    if process is not None:
        # Inclusive duration maps have no nesting/interval metadata. Largest
        # phase is a conservative outermost proxy; summing would double count.
        phases = frame.get('phase_times_us', {})
        outermost = max((v for k, v in phases.items()
                         if not k.startswith(('post_draw:', 'input:', 'await:'))), default=0) / 1000
        before = max(0.0, process - outermost)
        cell['before_ms'] += before
        cell['after_ms'] += max(0.0, before - span)
        cell['remainder_samples'] += 1
    cell['resume_phase_frames'].update(k for k in frame.get('phase_times_us', {})
                                       if k.startswith(('post_draw:', 'await:')))


def finish(cell):
    return dict(frames=cell['frames'], redraw_totals=dict(cell['counts']),
                frames_with_redraw=dict(cell['frames_with_redraw']),
                mean_redraws_per_frame=sum(cell['counts'].values()) / cell['frames'] if cell['frames'] else None,
                mean_redraws_per_key={k: v / cell['frames'] for k, v in cell['counts'].items()},
                top_by_ms_estimate=cell['ms'].most_common(10), top_by_count=cell['counts'].most_common(10),
                polygon_totals=dict(cell['polygons']), redraw_span_ms=cell['span_ms'],
                remainder_samples=cell['remainder_samples'],
                process_minus_outermost_phase_ms_estimate=cell['before_ms'] if cell['remainder_samples'] else None,
                process_minus_outermost_phase_and_redraw_ms_estimate=cell['after_ms'] if cell['remainder_samples'] else None,
                resume_phase_frames=dict(cell['resume_phase_frames']))


def markdown(rows):
    lines = ['', '## Redraw', '',
             'Exact signal counts; gap ms are estimates, not exclusive CPU. Ordinary means <= threshold. '
             'Remainder uses the largest inclusive non-input/non-resume phase as a conservative outermost proxy '
             '(nesting/phase start timestamps are unavailable); floors each frame at zero before and after '
             'subtracting the first-to-last redraw span. Resume counts are frames with a named phase, not invocation counts. '
             'Legacy traces are unmeasured. Loading is excluded.', '',
             '| Profile / cache / >ms | Slow / ordinary frames | Mean redraws slow / ordinary | Top estimated ms | Top counts | Per-key mean redraws slow / ordinary | Polygon totals | Span ms | Process remainder before / after ms (estimate) | Resume phase frames |',
             '|---|---:|---:|---|---|---|---|---:|---|---|']
    for row in rows:
        slow, ordinary = row['slow'], row['ordinary']
        keys = dict.fromkeys(k for cell in (slow, ordinary) for k, _ in cell['top_by_count'])
        means = {k: [cell['mean_redraws_per_key'].get(k, 0.0) if cell['frames'] else None
                     for cell in (slow, ordinary)] for k in keys}
        lines.append(f"| {row['profile']} / {row['cache']} / {row['threshold_ms']} | {slow['frames']} / {ordinary['frames']} | {slow['mean_redraws_per_frame']} / {ordinary['mean_redraws_per_frame']} | {slow['top_by_ms_estimate']} | {slow['top_by_count']} | {means} | {slow['polygon_totals']} | {slow['redraw_span_ms']:.3f} | {slow['process_minus_outermost_phase_ms_estimate']} / {slow['process_minus_outermost_phase_and_redraw_ms_estimate']} | {slow['resume_phase_frames']} |")
    return lines
