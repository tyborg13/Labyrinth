"""Source/effect accounting for the opt-in Cantor audit. Stdlib only.

2x2 cells are 11=told/hit, 10=told/no hit, 01=not told/hit, 00=neither.
Red is coarse, source-owned warning, not a status-specific promise. The panel
has aggregate numeric rows only. Intent is effect disclosure, not hit prediction.
"""
from collections import Counter, defaultdict
import json

SOURCES = ['peal_direct','peal_chain','capacitor_shock','capacitor_damage','static_lash','spark_dart','broken_rhythm','new_wisp','other','reaimed']
RESOURCE_FIELDS = ['hp','block','stoneskin']

def rows(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line.strip()]

def harms(receipt):
    return any(receipt.get(k,0)>0 for k in RESOURCE_FIELDS) or bool(receipt.get('moved') or receipt.get('statuses'))

def owner(value):
    for prefix in ['hit:','later:','died_first:']:
        if value.startswith(prefix): return value[len(prefix):]
    return value

def base_source(receipt,known):
    if receipt.get('source') in ['peal_direct','peal_chain']: return receipt['source']
    if receipt.get('source')=='lightning_wisp' and receipt.get('owner') not in known:return 'new_wisp'
    intent=receipt.get('intent')
    if intent=='blinding_arc':return 'capacitor_damage'
    if intent in ['static_lash','spark_dart','broken_rhythm']:return intent
    return 'other'

def predicted_sources(row,known,peal_kind):
    result=defaultdict(Counter)
    for s in row['forecast_sim']['slices']:
        actor=s['actor']
        if s.get('intent')=='peal' and s.get('beat'):
            source=peal_kind
        elif actor.startswith('enemy_'):
            source=base_source(dict(source=s.get('type'),owner=actor,intent=s.get('intent')),known)
        else:source='other'
        for k in RESOURCE_FIELDS:
            if k=='block' and actor=='turn_start':continue # expiry is not harm
            result[source][k]+=s.get(k,0)
    return result

def analyze(row):
    known={e['key']:e for e in row['context']['enemies']}
    by_source=defaultdict(list)
    for r in row['receipts']:
        source=base_source(r,known)
        normal=dict(r)
        if r.get('intent')=='blinding_arc' and r.get('statuses',{}).get('shock',0)>0:
            shock=dict(r,hp=0,block=0,stoneskin=0,moved=False,statuses={'shock':r['statuses']['shock']})
            by_source['capacitor_shock'].append(shock)
            normal['statuses']={k:v for k,v in r['statuses'].items() if k!='shock'}
        by_source[source].append(normal)
        # Explicit overlapping reason, not a second exclusive damage source.
        if (harms(r) and r.get('owner') in known and known[r['owner']]['visible'] and known[r['owner']]['intent']==r.get('intent') and r.get('action',{}).get('type') in ['melee','ranged','aoe','push','pull']):
            at=row['tile'] if row['mode']=='move' else row['context']['hero_tile']
            if at not in row.get('shown_plans',{}).get(r['owner'],[]):by_source['reaimed'].append(r)
    # All actual non-action damage (usually drawing Fatigue) is accounted for.
    residual={}
    for k in RESOURCE_FIELDS:
        actual=sum(s.get(k,0) for s in row['actual']['slices'] if not (k=='block' and s['actor']=='turn_start'))
        recorded_amount=sum(r.get(k,0) for r in row['receipts'])
        if actual>recorded_amount:residual[k]=actual-recorded_amount
    if residual:by_source['other'].append(dict(**residual,reason='outside_enemy_action'))
    gained=Counter()
    recorded=Counter()
    for s in row['actual']['slices']:
        gained.update(s.get('statuses',{}))
        if s.get('moved') and s['actor'] not in ['move'] and not any(r.get('moved') for r in row['receipts']):by_source['other'].append(dict(moved=True,reason=s['actor']))
    for r in row['receipts']:recorded.update(r.get('statuses',{}))
    remainder=gained-recorded
    if remainder:by_source['other'].append(dict(statuses=dict(remainder),reason='outside_enemy_action'))
    rest={owner(o) for o in row['red_owners']}
    hover={owner(o) for o in row.get('hover_owners',[])} if row['mode']=='move' else rest
    peal_records=[r for r in row['receipts'] if r.get('source') in ['peal_direct','peal_chain']]
    peal_kind=peal_records[0]['source'] if peal_records else 'peal_direct'
    predicted=predicted_sources(row,known,peal_kind)
    result={}
    for source in SOURCES:
        receipts=by_source[source]
        ids={r.get('owner') for r in receipts}
        announced=[]
        for e in known.values():
            matches=(source==e['intent'] or source in ['capacitor_damage','capacitor_shock'] and e['intent']=='blinding_arc' or source in ['peal_direct','peal_chain'] and e['intent']=='peal' and e['key'] in row.get('announced_rule_rows',{}))
            if matches:
                if source not in ['peal_direct','peal_chain']:ids.add(e['key'])
                if e['visible']:announced.append(e)
        if source==peal_kind and (peal_records or 'battlefield_rule' in rest|hover):ids.add('battlefield_rule')
        # Other includes Tender and residual hazards; never steal a known move's red.
        if source=='other':
            for e in known.values():
                if e['type']=='bell_tender' and e['intent']=='staff_bolt':
                    ids.add(e['key'])
                    if e['visible']:announced.append(e)
        rest_told=bool(rest&ids);hover_told=bool(hover&ids)
        effects={k:sum(r.get(k,0) for r in receipts) for k in RESOURCE_FIELDS}
        statuses=Counter()
        for r in receipts:statuses.update(r.get('statuses',{}))
        panel_fields=[k for k in RESOURCE_FIELDS if row['shown'].get(k,0)>0 and predicted[source][k]>0]
        # Peal move row is Move 1. Its rule sentence is separately disclosed.
        # Arc bonus and other direct move numbers are emitted by the real builders.
        intent_told=bool(announced) and source in ['peal_direct','peal_chain','capacitor_damage','capacitor_shock','static_lash','spark_dart','broken_rhythm','other']
        for receipt in receipts:
            actor=known.get(receipt.get('owner'),{})
            move_known=bool(actor.get('visible') and actor.get('intent')==receipt.get('intent')) or receipt.get('owner')=='battlefield_rule' and any(e.get('visible') and e.get('intent')==receipt.get('intent') and e.get('key') in row.get('announced_rule_rows',{}) for e in known.values())
            move_told=move_known and (source not in ['peal_direct','peal_chain','new_wisp'] or receipt.get('owner')=='battlefield_rule' and bool(row.get('announced_rule_rows')))
            relevant=[s for s in row['forecast_sim']['slices'] if (s.get('intent')=='peal' if receipt.get('owner')=='battlefield_rule' else s['actor']==receipt.get('owner') and s.get('intent')==receipt.get('intent'))]
            if receipt.get('reason')=='outside_enemy_action':relevant=[s for s in row['forecast_sim']['slices'] if not s['actor'].startswith('enemy_')]
            fields=[k for k in RESOURCE_FIELDS if receipt.get(k,0)>0 and row['shown'].get(k,0)>0 and any(s.get(k,0)>0 for s in relevant)]
            status_told=bool(receipt.get('statuses')) and all(row['shown'].get('status_rows',{}).get(k,0)>=v for k,v in receipt.get('statuses',{}).items())
            receipt['told']={'red_rest':bool(row['red']),'red_hover':bool(row.get('red_hover',row['red'])),
                             'owner_red_rest':receipt.get('owner') in rest,'owner_red_hover':receipt.get('owner') in hover,
                             'panel':bool(fields) or status_told,'panel_fields':fields,'intent':move_told,
                             'status_in_panel':status_told,'status_in_move':bool(receipt.get('statuses')) and receipt.get('intent')=='blinding_arc' and move_known}
        hurt_receipts=[r for r in receipts if harms(r)]
        if hurt_receipts:
            rest_told=all(r['told']['owner_red_rest'] for r in hurt_receipts)
            hover_told=all(r['told']['owner_red_hover'] for r in hurt_receipts)
            intent_told=all(r['told']['intent'] for r in hurt_receipts)
            panel_told=all(r['told']['panel'] for r in hurt_receipts)
        else:panel_told=bool(panel_fields)
        result[source]=dict(hit=any(harms(r) for r in receipts),red_rest=rest_told,red_hover=hover_told,panel=panel_told,intent=intent_told,
                            panel_fields=panel_fields,statuses=dict(statuses),effects=effects,receipts=receipts,
                            raw_red_rest=bool(row['red']),raw_red_hover=bool(row.get('red_hover',row['red'])),
                            status_in_panel=bool(statuses) and all(row['shown'].get('status_rows',{}).get(k,0)>=v for k,v in statuses.items()),status_in_move=bool(statuses) and source=='capacitor_shock' and intent_told)
    return result

def report(args):
    checks=[];visible_cover=defaultdict(Counter);cover=defaultdict(Counter);walked=defaultdict(set);costs=[];runs=[]
    inputs=[p for label in (args.include_label or [args.label]) for p in (args.root/label).glob('tier-*/samples.jsonl')]
    for path in sorted(inputs):
        # Never silently count a partial / timed-out run as a finished audit.
        if not (path.parent/'completed.json').exists():continue
        runs.append(path.parent.name)
        for row in rows(path):
            if row['kind']=='check' and row['mode'] in ['pass','move']:
                row['_run']=path.parent.name;checks.append(row)
                if row['mode']=='pass':
                    for enemy in row['context']['enemies']:
                        if enemy['visible']:visible_cover[row['tier']][enemy['type']+':'+enemy['intent']]+=1
            if row['kind']=='atk13_coverage':cover[row['tier']].update(row['intents'])
            if row['kind']=='walked':
                tier=int(path.parent.name.split('-')[1])
                for r in row['receipts']:
                    if r['source']=='storm_cantor':walked[tier].add((path.parent.name,r.get('clock'),r['intent']))
        costs.append(json.loads((path.parent/'cost.json').read_text())['seconds'])
    matrices=defaultdict(Counter);global_matrix=defaultdict(Counter);examples={};details=[];unmatched=0;oracle_bad=0;pairing=Counter();status_counts=Counter();source_causes=defaultdict(Counter);integrity=Counter();global_causes=defaultdict(Counter)
    for row in checks:
        findings=analyze(row)
        if sum(r.get('hp',0) for r in row['receipts'])>row['actual']['hp']:unmatched+=1
        if not row.get('oracle_matches_production',False):oracle_bad+=1
        actual_hit=any(s['hit'] for k,s in findings.items() if k!='reaimed')
        forecast_hit=any(s.get(k,0)>0 for s in row['forecast_sim']['slices'] for k in RESOURCE_FIELDS if not(k=='block' and s['actor']=='turn_start')) or any(s.get('statuses') or s.get('moved') and s['actor']!='move' for s in row['forecast_sim']['slices'])
        pairing[(row['mode'],forecast_hit==actual_hit)]+=1
        integrity['replica_mismatches']+=not row['replica_matches_ui']
        integrity['undisclosed_hit_mismatches']+=forecast_hit!=actual_hit and not row['disclosed']
        integrity['disclosed_checks']+=row['disclosed']
        for channel,red in [('red_rest',row['red']),('red_hover',row.get('red_hover',row['red']))]:
            if bool(red)==actual_hit:continue
            kind='alarm' if red else 'miss'
            involved=[source for source,info in findings.items() if source!='reaimed' and (info[channel] if red else info['hit'])]
            for source in involved or ['other']:global_causes[f'{row["mode"]}:{channel}:{kind}'][source]+=1
        for channel,red in [('rest',row['red']),('hover',row.get('red_hover',row['red']))]:global_matrix[(row['mode'],channel)][f'{int(red)}{int(actual_hit)}']+=1
        for source,info in findings.items():
            for channel in ['red_rest','red_hover','panel','intent']:
                told=info[channel];hit=info['hit']
                matrices[(row['mode'],source,channel)][f'{int(told)}{int(hit)}']+=1
                if told!=hit:
                    kind='alarm' if told else 'miss'
                    source_causes[channel][f'{source}:{kind}']+=1
                    key=f'{row["mode"]}:{source}:{channel}:{kind}'
                    examples.setdefault(key,dict(seed=row['context']['seed'],turn=row['context']['turn'],point=row['point'],tile=row['tile'],save=row['repro'],run=row['_run']))
            if info['hit']:
                for status,n in info['statuses'].items():status_counts[f'{source}:{status}']+=1
                details.append(dict(run=row['_run'],point=row['point'],turn=row['context']['turn'],mode=row['mode'],tile=row['tile'],source=source,**info,save=row['repro'],shown=row['shown'],disclosed=row['disclosed'],hero_tile=row['context']['hero_tile']))
    result=dict(label=args.label,runs=runs,checks=len(checks),coverage=dict(cover),visible_coverage=dict(visible_cover),walked={str(t):dict(Counter(k[2] for k in rs)) for t,rs in walked.items()},costs=costs,
                oracle_mismatches=oracle_bad,receipt_hp_exceeds_actual=unmatched,integrity=dict(integrity),global_causes=dict(global_causes),pairing={f'{mode}:{equal}':n for (mode,equal),n in pairing.items()},status_hits=dict(status_counts),
                matrices={':'.join(k):dict(v) for k,v in matrices.items()},global_matrices={':'.join(k):dict(v) for k,v in global_matrix.items()},causes=dict(source_causes),examples=examples,hits=details)
    out=args.root/args.label/'report.json';out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,indent=2)+'\n')
    print(f'ATK13 REPORT {args.label}: runs={len(runs)} checks={len(checks)} oracle_mismatches={oracle_bad} receipt_hp_exceeds_actual={unmatched}')
    print('WALKED',json.dumps(result['walked'],sort_keys=True))
    print('SHOWN',json.dumps(result['coverage'],sort_keys=True))
    print('STATUS_HITS',json.dumps(result['status_hits'],sort_keys=True))
    print('PAIRING',json.dumps(result['pairing'],sort_keys=True))
    print('MATRIX cells: told+hit, told+nohit, not-told+hit, not-told+nohit')
    for key,counts in result['matrices'].items():
        if key.endswith(':red_hover') or key.endswith(':panel'):print(key,*(counts.get(c,0) for c in ['11','10','01','00']))
    print(out)
