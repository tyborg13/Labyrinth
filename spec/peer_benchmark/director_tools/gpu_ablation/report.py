"""Validated marginal GPU census. Missing native evidence stays pending."""
from pathlib import Path
import argparse
import csv
import json
import math
import statistics

from proof import ROOT, PROJECT, STATES, save

SAMPLE_FRAMES = 660
BLOCK_FRAMES = 60
ATTRIBUTION = {
    'art_treatment': ('scripts/combat_board_view.gd', 'func _create_retained_render_layer', 'Fill within submitted geometry and overdraw; also canvas/material item count. Control bounds do not prove 167 full-screen fragment passes.'),
    'floor_light': ('assets/shaders/combat_floor_light.gdshader', 'void fragment()', 'Fill: cached floor texture area; light-loop work per covered pixel.'),
    'atmosphere_shade': ('scripts/combat_atmosphere.gd', 'const ATMOSPHERE_SHADER_CODE', 'Fill: one full-screen shade; motes remain enabled.'),
    'hud_hand': ('scripts/run_scene.gd', '@onready var hand_box', 'Item count and covered HUD/card pixels; hides UiRoot, top-level card proxies, board HudRenderLayer and hand-cache viewport; leaves Character modal visible.'),
    'static_board_cache': ('scripts/combat_board_view.gd', 'func set_static_render_cache_enabled', 'Signed cache benefit: cached floor composite versus existing direct tile draws; item count plus floor fill. Overlaps floor-light/art arms.'),
    'paper_doll': ('scripts/protagonist_cutout/renderer.gd', 'func _apply_pose', 'Offscreen texture area × draw cadence and rig item count; composition pixels separately. Dormant viewport has no offscreen saving.'),
    'card_strips': ('scripts/ui_card_strip.gd', 'var _art_material', 'Item count plus badge/textured strip pixels; render-only visibility override preserves layout.'),
    'skill_tree': ('scripts/skill_tree_view.gd', 'func _draw', 'Item count for nodes/links and covered pixel area; hidden retained trees may already be dormant.'),
}
OPTIONS = {
    'art_treatment': 'Composite eligible board layers, then apply art treatment once, preserving actor tags, lighting coordinates, premultiplied alpha, order and effects. Extra render-target/composite cost must be subtracted; material count alone predicts no savings.',
    'floor_light': 'Reuse an exactly evaluated per-pixel illumination field for repeated steady/live lighting calculations, or reuse the floor composite while all light inputs are unchanged. Animated flicker still requires updates.',
    'atmosphere_shade': 'Cache the static vignette field at the same output size; combine unchanged pool/hurt terms with it. Preserve shader arithmetic/output and invalidate on size or parameter changes.',
    'hud_hand': 'Retain/composite unchanged HUD and resting hand sections; invalidate on layout, focus, hover, card, tooltip and animation changes. Preserve motion and input behavior.',
    'static_board_cache': 'Reuse the existing cache only while its inputs are unchanged; inspect baseline cache draw cadence and invalidation causes before proposing additional work. A positive baseline-minus-cache-off delta means the cache currently costs GPU time; a negative delta means it saves time.',
    'paper_doll': 'Keep the existing pose-signature UPDATE_ONCE policy; suppress only redundant submissions of an identical pose or truly hidden Character doll. Preserve every distinct animated pose; no saving is available while it is already dormant.',
    'card_strips': 'Cache unchanged card badge/material output per source texture, size and state; invalidate exactly on source/state/hover changes and reuse across identical visible strips.',
    'skill_tree': 'Retain unchanged tree links and ornament layers across frames; redraw on geometry, progression, focus or size changes while keeping all live feedback separate.',
    'rig': 'Keep pose-signature UPDATE_ONCE and stop only identical-pose or truly hidden rig updates. The current rig code already implements change-triggered updates; idle motion changes the pose. Preserving all animated poses may yield zero saving.',
}


def stats(values):
    values = sorted(values)
    return {'median': statistics.median(values), 'p95': values[math.ceil(.95 * len(values)) - 1]} if values else {'median': None, 'p95': None}


def noise_band(a, b, metric):
    pooled = stats(a + b)[metric]
    blocks = [stats(v[i:i + BLOCK_FRAMES])[metric] for v in (a, b) for i in range(0, len(v), BLOCK_FRAMES) if len(v[i:i + BLOCK_FRAMES]) == BLOCK_FRAMES]
    return max([abs(stats(a)[metric] - stats(b)[metric]), *(abs(value - pooled) for value in blocks)])


def ref(path, marker):
    lines = (PROJECT / path).read_text().splitlines()
    return '%s:%d' % (path, next((i for i, line in enumerate(lines, 1) if marker in line), 1))


def attribution(arm, case=None):
    if arm.startswith('baseline_'):
        return {'source': 'all production rendering', 'scaling': 'reference'}
    if arm.startswith('rig__'):
        paths = case['notes']['ablation']['available'].get(arm, []) if case else []
        catalog = case.get('viewport_catalog', {}) if case else {}
        sources = sorted({m['source'].removeprefix('res://') for m in catalog.values() if m['path'] in paths})
        return {'source': '; '.join(ref(p, 'viewport = SubViewport.new()') + ', ' + ref(p, 'viewport.render_target_update_mode = SubViewport.UPDATE_ONCE') for p in sources), 'scaling': 'Offscreen own texture area × cadence; rig item count; main composition fill separately. Texture hidden by transparent clear, updates disabled; retained quads still submit.'}
    path, marker, scaling = ATTRIBUTION[arm]
    return {'source': ref(path, marker), 'scaling': scaling}


def scale_ok(value):
    # Godot reports content_scale_factor as float32 (1.14999997615814).
    return isinstance(value, (int, float)) and abs(value - 1.15) < 1e-4


def validate(case, index, state, arm):
    errors = []
    if case.get('headless') or index.get('headless'): errors.append('headless fixture is not GPU evidence')
    if index.get('errors'): errors.append('driver reported errors')
    for key, expected in [('size', [1280, 800]), ('cel_look', 'all'), ('renderer', 'mobile'), ('rendering_driver', 'vulkan')]:
        if index.get(key) != expected: errors.append('incorrect ' + key)
    if not scale_ok(index.get('ui_scale')): errors.append('incorrect ui_scale')
    if case.get('state') != state or case.get('arm') != arm: errors.append('state/arm mismatch')
    frames = case.get('frames', [])
    if len(frames) != SAMPLE_FRAMES: errors.append('expected 660 frames')
    ids = [f.get('timestamp_frame') for f in frames]
    if None in ids or len(set(ids)) != len(ids): errors.append('missing/duplicate timestamp frames')
    main = case['main_viewport_rid']
    for f in frames:
        row = f['viewports'].get(main, {})
        if not row.get('drew') or row.get('api_gpu_ms', 0) is None or row.get('api_gpu_ms', 0) <= 0 or row.get('timestamp', {}).get('gpu_ms', 0) <= 0:
            errors.append('missing/zero main GPU timestamp'); break
        if row.get('size') != [1280, 800] or not scale_ok(f.get('ui_scale')):
            errors.append('sample size/scale mismatch'); break
        # Director 2026-11-06: focus can't be forced without OS window control (not
        # allowed). Baseline A/B pairs show no focus bias (unfocused-vs-focused gaps
        # match focused-vs-focused drift in both directions), so unfocused samples count.
        context = f.get('submission_context', {})
        if context.get('phase') != ('action' if state == 'dragon_action' else 'steady') or (state == 'dragon_action' and (not context.get('animation_lock') or not context.get('enemy_action'))):
            errors.append('sample outside requested submission phase'); break
        if not arm.startswith('baseline_') and case['notes']['ablation'].get('target_present', True) and context.get('affected', 0) < 1:
            errors.append('ablation not applied at submission'); break
    if not arm.startswith('baseline_') and case['notes']['ablation'].get('target_present', True) and not case['notes']['ablation']['ever_affected_paths']:
        errors.append('selector affected no targets')
    if arm.startswith('rig__') or arm == 'paper_doll':
        paths = case['notes']['ablation']['available'].get(arm, [])
        rids = {rid for rid, meta in case['viewport_catalog'].items() if meta['path'] in paths}
        if any(f['viewports'].get(rid, {}).get('drew') for f in frames for rid in rids):
            errors.append('hidden rig viewport still drew during samples')
    return sorted(set(errors))


def measures(case):
    main = case['main_viewport_rid']
    frames = case['frames']
    main_values = [f['viewports'][main]['timestamp']['gpu_ms'] for f in frames]
    totals = [sum(v.get('timestamp', {}).get('gpu_ms', 0) for v in f['viewports'].values() if v.get('drew')) for f in frames]
    sub = []
    for rid, meta in case['viewport_catalog'].items():
        if rid == main: continue
        rows = [f['viewports'].get(rid, {}) for f in frames]
        values = [r.get('timestamp', {}).get('gpu_ms', 0) if r.get('drew') else 0 for r in rows]
        sub.append({'path': meta['path'], 'source': meta['source'], 'drawn_frames': sum(bool(r.get('drew')) for r in rows), 'amortized_ms': statistics.mean(values), **stats(values)})
    return main_values, totals, sub


def csv_file(path, rows, fields):
    with path.open('w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(rows)


def cell(value):
    return 'pending' if value is None else '%.3f' % value


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-dir', type=Path, default=ROOT / 'native-director')
    parser.add_argument('--output-dir', type=Path)
    args = parser.parse_args()
    out = args.output_dir or args.run_dir / 'tables'
    out.mkdir(parents=True, exist_ok=True)
    plan = json.loads((ROOT / 'native_commands.json').read_text())
    if Path(plan['run_dir']) != args.run_dir:
        raise SystemExit('Run directory does not match prepared commands')
    rows, invalid, available, cases, totals = [], [], {}, {}, {}
    for entry in plan['arms']:
        state, arm = entry['state'], entry['arm']
        directory = args.run_dir / state / arm
        path, index_path = directory / (state + '.json'), directory / 'index.json'
        item = {'state': state, 'arm': arm, 'status': 'pending_native', 'main_median_ms': None, 'main_p95_ms': None, 'delta_median_ms': None, 'delta_p95_ms': None, 'noise_median_ms': None, 'noise_p95_ms': None, 'total_median_ms': None, 'total_p95_ms': None}
        if path.exists() and index_path.exists():
            case, index = json.loads(path.read_text()), json.loads(index_path.read_text())
            issues = validate(case, index, state, arm)
            manifest = directory / 'renderer-manifest.json'
            proof = json.loads(manifest.read_text()) if manifest.is_file() else {}
            if proof.get('ok') is not True or proof.get('rendering_driver') != 'vulkan' or proof.get('expected_sizes') != [[1280, 800]]:
                issues.append('passing Vulkan 1280x800 renderer manifest required')
            if issues:
                item['status'] = 'invalid'
                invalid.append({'state': state, 'arm': arm, 'issues': issues})
            else:
                values, total, sub = measures(case)
                available[state, arm] = values
                cases[state, arm] = case
                totals[state, arm] = total
                item.update(status='measured' if case['notes']['ablation'].get('target_present', True) else 'not_present_noop', main_median_ms=stats(values)['median'], main_p95_ms=stats(values)['p95'], total_median_ms=stats(total)['median'], total_p95_ms=stats(total)['p95'], subviewports=sub)
        item.update(attribution(arm, cases.get((state, arm))))
        rows.append(item)
    rankings = []
    total_rankings = []
    for state in STATES:
        a, b = available.get((state, 'baseline_a')), available.get((state, 'baseline_b'))
        if not a or not b: continue
        scheduled = {r['arm'] for r in rows if r['state'] == state and not r['arm'].startswith('baseline_')}
        # Deferred production preparation may instantiate additional rigs after
        # the short headless discovery. Never silently omit a native target.
        discovered = {arm for baseline in ('baseline_a', 'baseline_b') for arm in cases[state, baseline]['notes']['ablation']['available'] if arm.startswith('rig__')}
        if discovered - scheduled:
            invalid.append({'state': state, 'issues': ['native targets absent from headless plan: ' + ', '.join(sorted(discovered - scheduled))]})
        reference = stats(a + b)
        bands = {m: noise_band(a, b, m) for m in ('median', 'p95')}
        ta, tb = totals[state, 'baseline_a'], totals[state, 'baseline_b']
        total_reference = stats(ta + tb)
        total_bands = {m: noise_band(ta, tb, m) for m in ('median', 'p95')}
        candidates = []
        for item in rows:
            if item['state'] != state or item['status'] != 'measured': continue
            for metric in ('median', 'p95'):
                item['noise_' + metric + '_ms'] = bands[metric]
                item['delta_' + metric + '_ms'] = reference[metric] - item['main_' + metric + '_ms']
                item['delta_total_' + metric + '_ms'] = total_reference[metric] - item['total_' + metric + '_ms']
                item['noise_total_' + metric + '_ms'] = total_bands[metric]
            item['resolution'] = 'above empirical noise' if item['delta_median_ms'] > bands['median'] else 'negative beyond noise' if item['delta_median_ms'] < -bands['median'] else 'within empirical noise'
            if not item['arm'].startswith('baseline_'): candidates.append(item)
        for rank, item in enumerate(sorted(candidates, key=lambda r: r['delta_median_ms'], reverse=True)[:5], 1):
            rankings.append({'rank': rank, **item})
        for rank, item in enumerate(sorted(candidates, key=lambda r: r['delta_total_median_ms'], reverse=True)[:5], 1):
            total_rankings.append({'rank': rank, **item})
    summary = {'status': 'invalid' if invalid else 'complete' if all(r['status'] in ('measured', 'not_present_noop') for r in rows) else 'pending_native', 'arms': rows, 'invalid': invalid, 'top_five': rankings, 'top_five_summed_viewports': total_rankings, 'noise_note': 'Empirical repeat/drift band from two baselines and contiguous 60-frame blocks; not a confidence interval. No additive attribution or Deck conversion.', 'options_note': 'Ranges are removal envelopes, not forecast net gains; native implementation measurement would be required.', 'clock_source': 'https://github.com/godotengine/godot/blob/4.6-stable/servers/rendering/rendering_device.cpp#L6615'}
    save(out / 'summary.json', summary)
    fields = ['state', 'arm', 'status', 'main_median_ms', 'main_p95_ms', 'delta_median_ms', 'delta_p95_ms', 'noise_median_ms', 'noise_p95_ms', 'total_median_ms', 'total_p95_ms', 'delta_total_median_ms', 'delta_total_p95_ms', 'noise_total_median_ms', 'noise_total_p95_ms', 'source', 'scaling']
    csv_file(out / 'arms.csv', rows, fields)
    csv_file(out / 'top_five.csv', rankings, ['rank', *fields])
    csv_file(out / 'top_five_summed_viewports.csv', total_rankings, ['rank', *fields])
    lines = ['# sd-12 GPU ablation census', '', 'Status: **' + summary['status'] + '**. No native values are inferred from headless runs or sd-10. Positive Δ means baseline − ablated GPU time. Median/p95 deltas compare distributions; p95 is not a paired-frame difference. Main viewport and summed viewport timings are separate; ablations overlap. Rig hiding clears its texture once and disables updates, retaining transparent composition quads. Cache-off uses direct floor drawing.', '', summary['noise_note'], '', '| State | Arm | Main median/p95 ms | Δ median/p95 ms | Noise median/p95 ±ms | Result |', '|---|---|---:|---:|---:|---|']
    for r in rows:
        lines.append('| %s | %s | %s / %s | %s / %s | %s / %s | %s |' % (r['state'], r['arm'], cell(r['main_median_ms']), cell(r['main_p95_ms']), cell(r['delta_median_ms']), cell(r['delta_p95_ms']), cell(r['noise_median_ms']), cell(r['noise_p95_ms']), r.get('resolution', r['status'])))
    lines.extend(['', '## Top five nominal marginal costs per state', '', 'Unresolved rows retain their noise label; a rank alone is not evidence of cost. Cache-off measures a replacement path and must not be interpreted as an isolated layer removal. Full source/scaling attribution is in arms.csv.', '', '| State | Rank | Arm | Δ median ms | Noise ±ms | Evidence | Source | Scaling |', '|---|---:|---|---:|---:|---|---|---|'])
    for state in STATES:
        top = [r for r in rankings if r['state'] == state]
        if not top: lines.append('| %s | — | pending native baselines/arms | — | — | unavailable | — | — |' % state)
        for r in top:
            lines.append('| %s | %d | %s | %.3f | %.3f | %s | %s | %s |' % (state, r['rank'], r['arm'], r['delta_median_ms'], r['noise_median_ms'], r['resolution'], r['source'], r['scaling']))
    lines.extend(['', '## Companion ranking: summed viewport scopes', '', 'Includes offscreen rig work. This sum is not whole-frame GPU time. Main-viewport rankings above remain the required comparison.', '', '| State | Rank | Arm | Sum Δ median/p95 ms | Sum noise median/p95 ±ms | Source |', '|---|---:|---|---:|---:|---|'])
    for r in total_rankings:
        lines.append('| %s | %d | %s | %.3f / %.3f | %.3f / %.3f | %s |' % (r['state'], r['rank'], r['arm'], r['delta_total_median_ms'], r['delta_total_p95_ms'], r['noise_total_median_ms'], r['noise_total_p95_ms'], r['source']))
    if not total_rankings: lines.append('| All states | — | pending native measurements | — | — | — |')
    if invalid: lines.extend(['', 'Invalid evidence: `' + json.dumps(invalid) + '`'])
    (out / 'tables.md').write_text('\n'.join(lines) + '\n')
    options = ['# Invisible options for the measured top three', '', 'No fixes implemented. These are conditional engineering options requiring identical-output validation. A removal envelope is the largest component saving suggested by its ablation plus empirical noise; a replacement adds overhead and may save zero or regress. No numerical net-saving forecast is defensible without a prototype.', '']
    for state in STATES:
        options.append('## ' + state)
        top = [r for r in rankings if r['state'] == state and r['rank'] <= 3]
        if not top: options.append('Ranking and numerical savings pending native measurements. Candidate mechanisms are listed below; no top-three claim is made.')
        for r in top:
            arm = r['arm']
            envelope = max(0, r['delta_median_ms'] + r['noise_median_ms'])
            options.append('%d. %s (%s): %s Main-viewport removal envelope 0–%.3f ms; p95 envelope 0–%.3f ms. Net saving unmeasured. %s' % (r['rank'], arm, r['resolution'], OPTIONS['rig' if arm.startswith('rig__') else arm], envelope, max(0, r['delta_p95_ms'] + r['noise_p95_ms']), 'Offscreen rig cost/cadence is separately retained in summary.json; do not add it to this main-only envelope.' if arm.startswith('rig__') or arm == 'paper_doll' else ''))
        options.append('')
    options.extend(['## Candidate mechanisms (unranked until native proof)', ''])
    options.extend('- **%s:** %s Expected saving: pending; bounded only by a future measured removal envelope, with replacement overhead deducted.' % (k, v) for k, v in OPTIONS.items())
    (out / 'options.md').write_text('\n'.join(options) + '\n')
    print('SD-12 REPORT: %s measured=%d/%d ranked=%d invalid=%d fabricated_values=0' % (summary['status'].upper(), len(available), len(rows), len(rankings), len(invalid)))
    return 1 if invalid else 0


if __name__ == '__main__':
    raise SystemExit(main())
