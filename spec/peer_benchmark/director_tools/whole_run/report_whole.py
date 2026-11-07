"""Exact per-boundary bytes, whole-session semantics and strict >33.3 ms counts."""
from collections import Counter
from pathlib import Path
import json
import statistics

BASE=Path('/private/tmp/labyrinth_codex/perf-65')
TYPES=['combat_step','enemy_round','room_change','reward','explicit_save','durable_outbox',
       'durable_ack','durable_cursor','victory','defeat','direct_save']


def load(folder,name):return json.loads((folder/name).read_text())


def main():
    timings=[];identities={};frequency=[];labels=[];errors=[]
    for seed in [83,84217]:
        for side in ['before','after']:
            folder=BASE/f'whole-{side}-{seed}'
            f=load(folder,'frames.json');s=load(folder,'summary.json');b=load(folder,'save-boundaries.json')
            values=[r[1] for r in f['samples']]
            elapsed=sum(values)/1000
            timings.append(dict(seed=seed,side=side,frames=len(values),over33_3=sum(v>33.3 for v in values),
                                median_ms=statistics.median(values),max_ms=max(values),elapsed_s=elapsed,
                                decisions=s['decisions'],outcome=s['outcome'],findings=s.get('findings',[]),
                                real_max_hp_frames=f['real_max_hp_frames']))
            counts=Counter(r['type'] for r in b['rows'])
            for kind in TYPES:
                frequency.append(dict(seed=seed,side=side,type=kind,count=counts[kind],
                                      per_simulated_minute=counts[kind]*60/b['simulated_seconds'],
                                      per_wall_minute=counts[kind]*60/elapsed))
            labels.extend(dict(seed=seed,side=side,boundary=label,count=count)
                          for label,count in Counter(r['boundary'] for r in b['rows']).items())
            if s['outcome']!='three_sections' or s.get('findings') or b['write_failures']:
                errors.append(f'{seed} {side}: incomplete run, findings, or save failure')
        ta=load(BASE/f'whole-before-{seed}','summary.json');tb=load(BASE/f'whole-after-{seed}','summary.json')
        if ta['decisions']!=tb['decisions'] or ta['action_counts']!=tb['action_counts']:
            errors.append(f'{seed}: timing arms used different decisions/action counts')
        a=BASE/f'whole-before-{seed}-identity';b=BASE/f'whole-after-{seed}-identity'
        ar=load(a,'save-boundaries.json');br=load(b,'save-boundaries.json')
        signature=lambda r:(r['boundary'],r['mode'],r['type'],r['saved'],r.get('exists'))
        same_boundaries=[signature(r) for r in ar['rows']]==[signature(r) for r in br['rows']]
        # The after replay already compared PackedByteArray values directly;
        # additionally re-read every raw baseline oracle to bind the row digest.
        import hashlib
        for row in ar['rows']:
            raw=(a/'oracles'/('%06d.save'%row['index'])).read_bytes()
            if hashlib.sha256(raw).hexdigest()!=row['sha256']:errors.append('baseline oracle digest mismatch')
        ai=load(a,'identity.json');bi=load(b,'identity.json')
        diffs=[]
        for left,right in zip(ai,bi):
            keys=[key for key in left[1] if left[1][key]!=right[1].get(key)]
            if left[0]!=right[0] or keys:diffs.append(dict(decision=left[0],fields=keys))
        af=load(a,'frames.json');bf=load(b,'frames.json')
        sa=load(a,'summary.json');sb=load(b,'summary.json')
        aa=load(a,'complete-analytics.json');ba=load(b,'complete-analytics.json')
        counts=Counter(r['type'] for r in br['rows'])
        result=dict(boundaries_before=len(ar['rows']),boundaries_after=len(br['rows']),
                    boundary_counts=dict(counts),boundary_order_equal=same_boundaries,
                    byte_differences=br['byte_failures'],all_oracle_reads_joined=all(r['joined'] for r in ar['rows']+br['rows']),
                    worker_dispatches_compared=sum(r['worker_started_for_oracle'] for r in br['rows']),
                    decision_snapshots_before=len(ai),decision_snapshots_after=len(bi),snapshot_differences=len(diffs),
                    first_snapshot_differences=diffs[:10],decision_hashes_equal=af['decision_hashes']==bf['decision_hashes'],
                    action_counts_equal=sa['action_counts']==sb['action_counts'],raw_analytics_equal=aa==ba,
                    analytics_events_before=len(aa),analytics_events_after=len(ba),outcomes=[sa['outcome'],sb['outcome']])
        identities[seed]=result
        if (not same_boundaries or br['byte_failures'] or not result['all_oracle_reads_joined'] or
            len(ai)!=len(bi) or diffs or not result['decision_hashes_equal'] or not result['action_counts_equal'] or aa!=ba or
            sa['outcome']!='three_sections' or sb['outcome']!='three_sections'):
            errors.append(f'{seed}: whole identity mismatch')
        if result['worker_dispatches_compared'] <= 0:
            errors.append(f'{seed}: identity oracle did not exercise worker transactions')
    hitch_changes={seed:next(r['over33_3'] for r in timings if r['seed']==seed and r['side']=='after')-
                       next(r['over33_3'] for r in timings if r['seed']==seed and r['side']=='before')
                   for seed in [83,84217]}
    data=dict(timings=timings,identity=identities,frequency=frequency,boundary_labels=labels,
              hitch_count_changes=hitch_changes,pacing_regression=any(v>0 for v in hitch_changes.values()),errors=errors)
    (BASE/'whole-results.json').write_text(json.dumps(data,indent=2)+'\n')
    lines=['# perf-65 whole-run proof','',
           'Inherited perf55 three-section driver: real maximum HP, room-entry heal, private lethal floor 1; fixed 120 Hz, 8x simulation. Headless, uncapped process intervals include driver work; these are not rendered display intervals. AB/BA timing order: before83, after83, after84217, before84217. One run per arm/seed; no whole-run IQR inferred. Identity is a separate replay, with joins/readback excluded from timings. Source assets are used equally (no cel cache in this checkout).','',
           '| Seed | Arm | Frames | >33.3 ms | Median ms | Decisions | Outcome |',
           '|---:|---|---:|---:|---:|---:|---|']
    for row in timings:
        lines.append('| {seed} | {side} | {frames} | {over33_3} | {median_ms:.3f} | {decisions} | {outcome} |'.format(**row))
    lines+=['','| Seed | Compared save boundaries | Worker dispatches compared | Raw byte differences | Decision snapshots | Snapshot differences | Raw analytics events | Analytics differences |',
            '|---:|---:|---:|---:|---:|---:|---:|---:|']
    for seed,r in identities.items():
        lines.append(f"| {seed} | {r['boundaries_after']} | {r['worker_dispatches_compared']} | {r['byte_differences']} | {r['decision_snapshots_after']} | {r['snapshot_differences']} | {r['analytics_events_after']} | {0 if r['raw_analytics_equal'] else 'FAIL'} |")
    lines+=['','Counts/rates below are timing-run save boundaries; rates per simulated gameplay minute include menus/driver waits. The JSON also records wall-minute rates and every original boundary label. Identity counts are separately retained above.','',
            '| Boundary type | Seed 83 before count / per min | Seed 83 after count / per min | Seed 84217 before count / per min | Seed 84217 after count / per min | Compared identity boundaries 83 / 84217 |',
            '|---|---:|---:|---:|---:|---:|']
    for kind in TYPES:
        cells=[]
        for seed,side in [(83,'before'),(83,'after'),(84217,'before'),(84217,'after')]:
            row=next(r for r in frequency if (r['seed'],r['side'],r['type'])==(seed,side,kind))
            cells.append(f"{row['count']} / {row['per_simulated_minute']:.3f}")
        identity_counts=' / '.join(str(identities[seed]['boundary_counts'].get(kind,0)) for seed in [83,84217])
        lines.append(f"| {kind} | {' | '.join(cells)} | {identity_counts} |")
    lines+=['','Raw-byte identity pins only nondeterministic wall-time/generated analytics-ID inputs in disposable projects; no save fields are stripped or normalized. Persisted RNG and analytics fields participate in the exact byte comparison. perf57 decision/control/board/run/combat/progression hashes and complete raw analytics content are also compared. Queued snapshots are explicitly dispatched on the worker before the oracle joins, without advancing gameplay a frame. Normal timing runs retain normal clocks.','',
            f'Headless >33.3 ms count changes: {hitch_changes}. The measured pacing regression remains open.',
            f'Save/semantic validation errors: {errors}','']
    (BASE/'whole-tables.md').write_text('\n'.join(lines))
    for seed,result in identities.items():print('PERF65 WHOLE IDENTITY',seed,json.dumps(result),flush=True)
    print('PERF65 WHOLE SAVE/SEMANTIC IDENTITY: '+('PASS' if not errors else 'FAIL'),flush=True)
    print('PERF65 WHOLE HITCH COUNT CHANGES: '+json.dumps(hitch_changes),flush=True)
    if errors:raise SystemExit(1)


if __name__=='__main__':main()
