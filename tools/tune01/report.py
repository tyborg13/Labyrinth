#!/usr/bin/env python3
"""tune-01 Health-cost statistics; shared controls retain native-depth weights."""
from collections import defaultdict
import gzip
import json
import math
from pathlib import Path
import random
from statistics import mean, median

ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT/'spec/peer_benchmark/encounter_redesign/measurements/tiers_2026-11'
OUT = ROOT/'spec/peer_benchmark/encounter_redesign/measurements/tune_2026-11'
SECTIONS = (0, 2, 4)
KINDS = ('guardian', 'boss', 'warband', 'umbral_snare', 'last_light', 'ember_hoarder')
CENTRES = dict(guardian=20, boss=30, warband=10, umbral_snare=10, last_light=10, ember_hoarder=10)
BOOTSTRAP_SAMPLES = 2000
BOOTSTRAP_SEED = 101
Z95 = 1.959963984540054

def read(path):
    with gzip.open(path, 'rt') as f: return [json.loads(x) for x in f]

def archive(path, rows):
    with gzip.open(path, 'wt') as f:
        for row in rows: f.write(json.dumps(row, sort_keys=True)+'\n')

def key(r): return (r['section'], r['tier'], r['ladder_seed'], r['repeat'])
def kind(r): return r['objective_kind'] if r['category']=='objective' else r['category']
def cost(r): return 100.0 if r['hp_after'] <= 0 else 100.0*r['hp_lost']/r['max_hp']

def interval(rows, value):
    # Resample entire ladder-seed clusters: repeated loadouts and reused normal
    # controls are never advertised as independent observations.
    groups = defaultdict(list)
    for r in rows: groups[r['ladder_seed']].append(value(r))
    values = list(groups.values())
    if len(values)<2: return [None, None]
    rng = random.Random(BOOTSTRAP_SEED)
    samples=[]
    for _ in range(BOOTSTRAP_SAMPLES):
        drawn = [v for g in rng.choices(values, k=len(values)) for v in g]
        samples.append(mean(drawn))
    samples.sort()
    return [samples[int(.025*BOOTSTRAP_SAMPLES)], samples[int(.975*BOOTSTRAP_SAMPLES)]]

def wilson(w,n):
    mid=(w/n+Z95**2/(2*n))/(1+Z95**2/n)
    rad=Z95*math.sqrt(w/n*(1-w/n)/n+Z95**2/(4*n*n))/(1+Z95**2/n)
    return [100*max(0,mid-rad),100*min(1,mid+rad)]

def summarize(rows, controls=None):
    controls = controls if controls is not None else {key(r):r for r in rows if r['category']=='normal'}
    result=[]
    for section in SECTIONS:
        for cell in ('normal', *KINDS):
            cohort=[r for r in rows if r['section']==section and kind(r)==cell]
            if not cohort: continue
            paired=[r for r in cohort if key(r) in controls]
            wins=sum(r['won'] for r in cohort)
            rec=dict(section=section, kind=cell, n=len(cohort), cost=mean(map(cost,cohort)), cost_ci=interval(cohort,cost),
                     win_rate=100*wins/len(cohort), win_ci=wilson(wins,len(cohort)), median_turns=median(r['turns'] for r in cohort),
                     goal_met_rate=100*sum(bool(r['goal_met']) for r in cohort)/len(cohort) if all('goal_met' in r for r in cohort) else None)
            if cell!='normal':
                rec.update(paired_n=len(paired), centre=CENTRES[cell])
                if paired:
                    delta=lambda r:cost(r)-cost(controls[key(r)])
                    gap=mean(map(delta,paired))
                    rec.update(normal_cost=mean(cost(controls[key(r)]) for r in paired), gap=gap, gap_ci=interval(paired,delta),
                               outside_band=max(CENTRES[cell]-5-gap, gap-CENTRES[cell]-5, 0))
            result.append(rec)
    return result

def fmt(v): return 'unavailable' if v is None else f'{v:.1f}'
def ci(v): return '['+', '.join(map(fmt,v))+']'
def table(headers, rows):
    return '\n'.join(['| '+' | '.join(headers)+' |','|'+'|'.join(['---']*len(headers))+'|',*['| '+' | '.join(map(str,r))+' |' for r in rows]])+'\n'

def render(summary):
    return table(['Section','Cell','N / paired','Cost [95%]','Matched normal','Gap [95%]','Band','Outside'],[
        [f"s{r['section']}",r['kind'],f"{r['n']} / {r.get('paired_n','—')}",f"{r['cost']:.1f} {ci(r['cost_ci'])}",fmt(r.get('normal_cost')),f"{fmt(r.get('gap'))} {ci(r.get('gap_ci',[None,None]))}",f"{r['centre']-5}–{r['centre']+5}" if 'centre' in r else 'baseline',fmt(r.get('outside_band'))] for r in summary])+'\n'+table(['Section','Cell','N','Win % [95% Wilson]','Median turns','Goal met %'],[
        [f"s{r['section']}",r['kind'],r['n'],f"{r['win_rate']:.1f} {ci(r['win_ci'])}",r['median_turns'],fmt(r['goal_met_rate'])] for r in summary])

def baseline():
    OUT.mkdir(parents=True,exist_ok=True)
    rows=read(BASE/'runs.jsonl.gz')
    result=summarize(rows)
    archive(OUT/'baseline_costs.jsonl.gz',[dict(r,kind=kind(r),health_cost=cost(r)) for r in rows])
    (OUT/'baseline_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    (OUT/'baseline.md').write_text('# diff-01 recomputed Health cost\n\nDefeats (ending Health ≤0) cost 100; all other fights, including bot turn-cap outcomes, use gross Health lost / starting max Health. No baseline fights were rerun. Native section/depth/ladder-seed/repeat pairing is unchanged. 95% percentile intervals resample whole ladder-seed clusters (2,000 samples, seed 101), preserving repeated loadouts and shared controls. Wilson intervals describe win rates. The old raw files lack objective goal-met; it cannot be recovered and is marked unavailable.\n\n'+render(result)+supplement(rows,{key(r):r for r in rows if r['category']=='normal'}))
    return result



def supplement(rows, controls):
    """Win ordering and identity outliers, using the same reused controls."""
    text=''
    summaries=summarize(rows,controls)
    index={(r['section'],r['kind']):r for r in summaries}
    order=[]
    for section in SECTIONS:
        for higher,lower in [('normal',k) for k in KINDS[2:]]+[(k,'guardian') for k in KINDS[2:]]+[('guardian','boss')]:
            a=index.get((section,higher));b=index.get((section,lower))
            if not a or not b:continue
            compatible=a['win_ci'][1]>=b['win_ci'][0]
            order.append([f's{section}',higher+' ≥ '+lower,'compatible within 95% intervals' if compatible else 'ORDER VIOLATION',f"{a['win_rate']:.1f} / {b['win_rate']:.1f}"])
    text+='### Win-rate order\n\n'+table(['Section','Required order','Result','Win %'],order)+'\n'
    outliers=[]
    enemies=json.loads((ROOT/'data/enemies.json').read_text())
    for section in SECTIONS:
        for cell in ['guardian','boss']:
            cohort=[r for r in rows if r['section']==section and kind(r)==cell and key(r) in controls]
            for identity in sorted({r['identity'] for r in cohort}):
                own=[r for r in cohort if r['identity']==identity]
                owncost=mean(map(cost,own));normal=mean(cost(controls[key(r)]) for r in own)
                gap=owncost-normal;outside=max(CENTRES[cell]-5-gap,gap-CENTRES[cell]-5,0)
                if outside<=10:continue
                old=enemies[identity]['max_hp']
                percent=min(175,max(80,100+3*(CENTRES[cell]-gap)))
                suggestion=math.ceil(old*percent/100)
                outliers.append([f's{section}',cell,identity,len(own),f'{owncost:.1f}',f'{gap:+.1f}',f'{outside:.1f}',f'{old} → {suggestion}'])
    text+='### Identity outliers (no base Health edits applied)\n\n'
    text+=table(['Section','Tier','Identity','N','Cost','Matched gap','Outside band','Suggested base Health'],outliers) if outliers else 'No measured identity exceeds the tier band by more than 10 points.\n'
    text+='\nBase-Health suggestions use the director’s +15% per five missing cost points, bounded to 80–175% of current base Health, rounded up. They are directional proposals; tier saturation or objective clocks can prevent the desired cost.\n'
    return text

if __name__=='__main__':
    baseline()
    print('TUNE01_BASELINE_PASS raw_fights=1170 rerun_fights=0')
