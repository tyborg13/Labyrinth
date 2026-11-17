#!/usr/bin/env python3
"""Make the review table describe the exact proposed dials and unique evidence."""
import json
from pathlib import Path
from statistics import mean,median
from report import OUT,ROOT,SECTIONS,KINDS,CENTRES,archive,ci,cost,fmt,interval,key,kind,read,supplement,table,wilson

STAGES = ['probe','damage1','damage2','damage3','confirm',*[f'postconfirm_damage{d}{suffix}' for d in range(1,4) for suffix in ['', '_confirm']]]

def main():
    contract=json.loads((OUT/'search_contract.json').read_text())
    proposals=json.loads((OUT/'proposals.json').read_text())
    baseline=json.loads((OUT/'baseline_summary.json').read_text())
    controls={key(r):r for r in read(OUT/'normal.jsonl.gz')}
    observed=[r for stage in STAGES if (OUT/f'{stage}.jsonl.gz').exists() for r in read(OUT/f'{stage}.jsonl.gz')]
    summaries=[];selected=[];statuses={}
    for section in SECTIONS:
        for cell in KINDS:
            ck=f'{section}:{cell}';hp,damage=proposals['proposed'][ck]
            matches=[r for r in observed if r['section']==section and kind(r)==cell and r.get('difficulty_stats',{}).get('hp_percent')==hp and r.get('difficulty_stats',{}).get('damage_bonus')==damage]
            unique={}
            for r in sorted(matches,key=lambda r:r['started_unix']):
                case=(r['ladder_seed'],r['room_coord'],r['repeat'])
                if case in unique:
                    assert all(unique[case][field]==r[field] for field in ['won','turns','hp_lost','hp_after','max_hp','goal_met']),('Non-deterministic duplicate',ck,case)
                unique[case]=r
            rows=list(unique.values());selected+=rows
            paired=[r for r in rows if key(r) in controls]
            confirm_n=sum('confirm' in r['stage'] for r in rows)
            rec=dict(section=section,kind=cell,hp_percent=hp,damage_bonus=damage,n=len(rows),paired_n=len(paired),confirmation_n=confirm_n,
                     baseline_cost=next(r['cost'] for r in baseline if r['section']==section and r['kind']==cell),
                     baseline_gap=next(r['gap'] for r in baseline if r['section']==section and r['kind']==cell),centre=CENTRES[cell])
            if rows:
                wins=sum(r['won'] for r in rows)
                rec.update(cost=mean(map(cost,rows)),cost_ci=interval(rows,cost),win_rate=100*wins/len(rows),win_ci=wilson(wins,len(rows)),median_turns=median(r['turns'] for r in rows),goal_met_rate=100*sum(r['goal_met'] for r in rows)/len(rows))
            if paired:
                delta=lambda r:cost(r)-cost(controls[key(r)])
                gap=mean(map(delta,paired))
                rec.update(normal_cost=mean(cost(controls[key(r)]) for r in paired),gap=gap,gap_ci=interval(paired,delta),outside_band=max(CENTRES[cell]-5-gap,gap-CENTRES[cell]-5,0))
            if not rows:status='unmeasured proposal'
            elif len(paired)<len(rows):status=f'incomplete pairing ({len(paired)}/{len(rows)})'
            elif hp==175 and damage==3 and len(rows)>=48 and rec.get('outside_band',0)>0:status='stat-limit probe outside band'
            elif confirm_n>=96:status='confirmed in band' if rec.get('outside_band')==0 else 'confirmed outside band'
            else:status=f'unconfirmed ({confirm_n}/96 confirmation fights)'
            rec['status']=statuses[ck]=status;summaries.append(rec)
    archive(OUT/'proposed_unique_runs.jsonl.gz',selected)
    proposals.setdefault('algorithm_status',proposals.get('status',{}))
    proposals['status']=statuses
    (OUT/'proposals.json').write_text(json.dumps(proposals,indent=2)+'\n')
    (OUT/'final_summary.json').write_text(json.dumps(summaries,indent=2)+'\n')
    body='# tune-01 review report\n\n'
    body+=f"Campaign wall time: **{contract['elapsed_seconds']:.1f} seconds**; search status: **{contract['status']}**. Four low-priority simulation workers maximum. {sum(r['status']=='confirmed in band' for r in summaries)}/18 cells have a full N=96 confirmation inside the Health-cost band. The table below evaluates the exact proposed Health/damage pairs; it never combines different dials.\n\n"
    body+='Baseline: [cost and win tables](baseline.md). Count rule: [before/after census](census.md). Methods, focused checks and owner-run visual command: [implementation and proof](implementation.md). All stage tables and win-order/identity details remain in [the search report](search.md).\n\n'
    body+='## Normal controls under the new count cap\n\n'
    normals=[]
    for section in SECTIONS:
        rows=[r for r in controls.values() if r['section']==section]
        if not rows:continue
        wins=sum(r['won'] for r in rows)
        normals.append([f's{section}',len(rows),f'{mean(map(cost,rows)):.1f} {ci(interval(rows,cost))}',f'{100*wins/len(rows):.1f} {ci(wilson(wins,len(rows)))}',median(r['turns'] for r in rows)])
    body+=table(['Section','N','Cost [95%]','Win % [95% Wilson]','Median turns'],normals)
    body+='\nThese are unique section/depth/seed/repeat controls. Each target gap below reweights its exact matched controls, so its matched-normal cost can differ from the pooled section value.\n\n'
    body+='## Proposed cost table\n\n'
    body+=table(['Section','Cell','Health % / damage','N / paired / confirm','Baseline cost / gap','Proposed cost [95%]','Matched normal','Gap [95%]','Band','Outside','Status'],[
        [f"s{r['section']}",'dragon' if r['kind']=='boss' else r['kind'],f"{r['hp_percent']} / +{r['damage_bonus']}",f"{r['n']} / {r['paired_n']} / {r['confirmation_n']}",f"{r['baseline_cost']:.1f} / {r['baseline_gap']:+.1f}",f"{fmt(r.get('cost'))} {ci(r.get('cost_ci',[None,None]))}",fmt(r.get('normal_cost')),f"{fmt(r.get('gap'))} {ci(r.get('gap_ci',[None,None]))}",f"{r['centre']-5}–{r['centre']+5}",fmt(r.get('outside_band')),r['status']] for r in summaries])
    body+='\n## Proposed win-rate table\n\n'
    body+=table(['Section','Cell','N','Win % [95% Wilson]','Median turns','Objective goal met %'],[
        [f"s{r['section']}",'dragon' if r['kind']=='boss' else r['kind'],r['n'],f"{fmt(r.get('win_rate'))} {ci(r.get('win_ci',[None,None]))}",r.get('median_turns','—'),fmt(r.get('goal_met_rate')) if r['kind'] not in ['guardian','boss'] else '—'] for r in summaries])
    body+='\nN counts unique native-room/seed/repeat cases at the exact proposed dials. Identical probe/confirmation repeats are deduplicated, with their confirmation label retained; raw repeated executions remain archived. Gap intervals preserve shared normal controls and resample whole loadout clusters. Unmatched deadline-cutoff cases are retained in raw costs but excluded from gaps. The original baseline lacks goal-met flags.\n\n'
    body+='## Win-order feasibility within the intervals\n\n'
    normal_summary={s:_normal_summary([r for r in controls.values() if r['section']==s]) for s in SECTIONS}
    idx={(r['section'],r['kind']):r for r in summaries}
    order=[]
    for s in SECTIONS:
        for obj in KINDS[2:]:
            chain=[normal_summary[s],idx[(s,obj)],idx[(s,'guardian')],idx[(s,'boss')]]
            feasible=None
            if all('win_ci' in r for r in chain):
                ceiling=100.;feasible=True
                for r in chain:
                    if r['win_ci'][0]>ceiling:feasible=False
                    ceiling=min(ceiling,r['win_ci'][1])
            order.append([f's{s}',f'normal ≥ {obj} ≥ Guardian ≥ dragon','compatible' if feasible is True else 'ORDER VIOLATION' if feasible is False else 'insufficient data'])
    body+=table(['Section','Required order','Joint interval result'],order)
    (OUT/'win_order.json').write_text(json.dumps(order,indent=2)+'\n')
    body+='\nThe joint check requires one consistent ordering inside all four intervals; pairwise interval overlap alone does not establish that ordering.\n'
    body+='\n'+supplement(list(controls.values())+selected,controls)
    tiers=json.loads((ROOT/'data/difficulty_tiers.json').read_text())
    interpolation=[];todos=[]
    for cell in KINDS:
        entry=tiers['tiers'][cell if cell in ['guardian','boss'] else 'objective'][cell if cell not in ['guardian','boss'] else 'default']
        entry['section_provenance']=[statuses[f'0:{cell}'],'interpolated',statuses[f'2:{cell}'],'interpolated',statuses[f'4:{cell}'],'copied_s4']
        for s in [1,3,5]:
            interpolation.append([f's{s}',cell,entry['hp_percent'][s],entry['damage_bonus'][s],'copied s4' if s==5 else 'interpolated'])
        todos += [v for v in entry['damage_bonus'] if isinstance(v,str)]
    (ROOT/'data/difficulty_tiers.json').write_text(json.dumps(tiers,indent=2)+'\n')
    body+='\n## Unmeasured sections\n\n'+table(['Section','Cell','Health %','Damage','Source'],interpolation)
    body+='\n## TODO_DESIGN and open issues\n\n'
    body+=('\n'.join('- '+v for v in todos)+'\n') if todos else 'No active fractional-damage placeholders in the proposed data.\n'
    body+='\nThe named `TODO_DESIGN_FRACTIONAL_DAMAGE_FALLBACK` constant retains the prior zero tier addition if an unapproved fractional interpolation is present. Each unresolved band/sample status is listed above. The design owner decides objective redesigns and base-Health identity suggestions; no `data/enemies.json` edits were applied. Windowed Hunted captures remain owner-run.\n'
    (OUT/'report.md').write_text(body)
    print(f'TUNE01_FINAL_REPORT: cells=18 confirmed_in_band={sum(r["status"]=="confirmed in band" for r in summaries)} active_design_placeholders={len(todos)}')

def _normal_summary(rows):
    if not rows:return {}
    return dict(win_ci=wilson(sum(r['won'] for r in rows),len(rows)))

if __name__=='__main__':main()
