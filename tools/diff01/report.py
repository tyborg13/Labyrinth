#!/usr/bin/env python3
"""Deterministic report from fresh tier fights and production count censuses."""
from collections import Counter, defaultdict
import gzip
import json
import math
from pathlib import Path
from statistics import median
import sys
from inventory import knob_rows, crowded_catalog, legacy_rosters

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT = ROOT/'spec/peer_benchmark/encounter_redesign/measurements/tiers_2026-11'
BANDS = {'objective':(-15,-5), 'guardian':(-25,-15), 'boss':(-35,-25)}


def read(path):
    with gzip.open(path,'rt') as stream: return [json.loads(line) for line in stream]


def wilson(wins,n):
    z = 1.959963984540054
    center = (wins/n + z*z/(2*n))/(1+z*z/n)
    radius = z*math.sqrt(wins/n*(1-wins/n)/n+z*z/(4*n*n))/(1+z*z/n)
    return 100*max(0.0,center-radius),100*min(1.0,center+radius)


def outside(gap, category):
    low,high = BANDS[category]
    return max(low-gap,gap-high,0)


def stats(rows):
    n = len(rows)
    if not n: return ['0','—','—','—']
    wins = sum(r['won'] for r in rows)
    lo,hi = wilson(wins,n)
    return [f'{wins}/{n}',f'{100*wins/n:.1f}% [{lo:.1f}, {hi:.1f}]',f"{median(r['turns'] for r in rows):g}",f"{median(r['hp_lost'] for r in rows):g}"]


def table(headers, rows):
    return '\n'.join(['| '+' | '.join(headers)+' |','|'+'|'.join(['---']*len(headers))+'|',
                      *['| '+' | '.join(map(str,row))+' |' for row in rows]])+'\n'


def matched(rows, controls):
    pairs = [(r,controls[(r['section'],r['tier'],r['ladder_seed'],r['repeat'])]) for r in rows
             if (r['section'],r['tier'],r['ladder_seed'],r['repeat']) in controls]
    if not pairs: return ['0','—','—','—']
    gap = 100*sum(int(r['won'])-int(c['won']) for r,c in pairs)/len(pairs)
    return [len(pairs),f"{100*sum(c['won'] for _,c in pairs)/len(pairs):.1f}%",f'{gap:+.1f}',f"{outside(gap,rows[0]['category']):.1f}"]


def count_stats(rows):
    counts = [r['start_count'] for r in rows]
    non = [r['start_non_summoned'] for r in rows]
    summons = [r['start_summoned'] for r in rows]
    return [len(rows),f'{min(counts)}/{median(counts):g}/{max(counts)}',f'{100*sum(n>5 for n in counts)/len(counts):.1f}%',
            f'{min(non)}/{median(non):g}/{max(non)}', f'{100*sum(n>5 for n in non)/len(non):.1f}%',
            f'{min(summons)}/{median(summons):g}/{max(summons)}']


def write_report(output):
    contract = json.loads((output/'contract.json').read_text())
    raw = read(output/'runs.jsonl.gz')
    inventory = read(output/'inventory.jsonl.gz')
    census = read(output/'census.jsonl.gz')
    # Require complete section/seed/repeat blocks for comparisons. Partial fights
    # remain in raw data; do not bias depth matching by selective completion.
    grouped = defaultdict(list)
    for row in raw: grouped[(row['section'],row['ladder_seed'],row['repeat'])].append(row)
    rows = [r for block in grouped.values() if len(block)==contract['block_expected_sizes'][f"s{block[0]['section']}-l{block[0]['ladder_seed']}"] for r in block]
    controls = {(r['section'],r['tier'],r['ladder_seed'],r['repeat']):r for r in rows if r['category']=='normal'}
    priority_checks=[matched([r for r in rows if r['section']==s and r['category']==cat],controls) for s in contract['selected_sections'] for cat in BANDS]
    outside_count=sum(float(check[3])>0 for check in priority_checks if check[0])
    lines = ['# Four difficulty tiers by section — 2026-11-16','',
      f"Measured HEAD `{contract['source_head']}`. No tuning, game code, data or test changes. Policy SHA-256 `{contract['policy_sha256']}`.",'',
      f"Fresh fights: **{len(raw)} raw**, **{len(rows)} in complete native-room blocks**. Total measurement wall time **{contract['elapsed_seconds']:.1f} seconds ({contract['elapsed_seconds']/60:.2f} minutes)**; at most **{contract['max_workers']} engine workers**. Selected sections: {contract['selected_sections']}. Target N=64 for each selected section × difficulty tier; normal rooms additionally target N=64 at each native depth band. Non-priority sections retain only the one-loadout/one-repeat pilot (N=1 per non-normal tier, N=3 pooled normals), which is diagnostic rather than a section estimate. Per-kind objective sample sizes are below.",'',
      f"**{outside_count}/{len(priority_checks)} priority-section tier comparisons fall outside their director bands at the point estimate.** The tables retain uncertainty, per-kind sample sizes and depth-matched baselines; these are relative bot results, not human win probabilities.",'',
      '## A. Win rates and director bands','',
      'Normal = current Kill All combat rooms. Objective = every enabled special kind (Warband, Umbral Snare, Last Light, Ember Hoarder), pooled for the section target; per-kind results are retained. Guardian and dragon identities are native to each seeded map. Local depth band t1–t3 is distinct from these four difficulty tiers; dragons occupy local step 4 and are matched to clamped t3, as in meas-07. No tier is transplanted between sections.','',
      'Each non-normal fight is paired with the first normal room at the same section, clamped depth band, ladder seed and combat-repeat index. The s3/seed7 map has no normal t2 room (including hidden mysteries); if collected, its t2 objective outcomes are retained but have no matched control and are excluded only from gap calculations. No room is fabricated. The normal comparator is reweighted to exactly that target cohort’s depth/loadout mix. Thus the comparator in the gap table can differ between objective, Guardian and dragon rows, and from the equally depth-weighted pooled normal row. Shared controls are reused rather than presented as independent extra fights. Gap = target win rate − matched normal win rate, in percentage points. Outside-band distance is zero inside the inclusive band, otherwise the positive distance to its nearest edge. These distances describe point estimates, not statistically established band violations. Objective band [−15,−5]; Guardian [−25,−15]; dragon [−35,−25].','',
      table(['Section','Tier','Wins/N','Win rate [95% Wilson]','Median turns','Median gross Health lost'],
            [[f's{s}',cat,*stats([r for r in rows if r['section']==s and r['category']==cat])] for s in range(6) for cat in ['normal','objective','guardian','boss']]),'',
      table(['Section','Tier','Paired N','Matched normal win rate','Gap (pp)','Outside band (pp)'],
            [[f's{s}',cat,*matched([r for r in rows if r['section']==s and r['category']==cat],controls)] for s in range(6) for cat in BANDS]),'',
      '### Objective kind and native depth detail','',
      table(['Section','Objective kind','Wins/N','Win rate [95% Wilson]','Median turns','Median gross Health lost','Paired N','Matched normal','Gap (pp)','Outside band (pp)'],
            [[f's{s}',kind,*stats(selected:= [r for r in rows if r['section']==s and r['category']=='objective' and r['objective_kind']==kind]),*matched(selected,controls)]
             for s in range(6) for kind in ['warband','umbral_snare','last_light','ember_hoarder']]),'',
      table(['Section','Native depth band','Tier','Wins/N','Win rate [95% Wilson]','Median turns','Median gross Health lost','Paired N','Matched normal','Gap (pp)','Outside band (pp)'],
            [[f's{s}',f't{tier}',cat,*stats(selected:=[r for r in rows if r['section']==s and r['tier']==tier and r['category']==cat]),
              *(matched(selected,controls) if cat!='normal' else ['—','baseline','0.0','0.0'])]
             for s in range(6) for tier in range(1,4) for cat in ['normal','objective','guardian','boss'] if any(r['section']==s and r['tier']==tier and r['category']==cat for r in rows)]),'',
      '## B. How scaling works today','',
      table(['Knob','Exact code/data anchor','Current behavior'],knob_rows()),'',
      '### Starting enemy-count distributions','',
      'Count census: eight production seeded maps, every direct encounter node, plus resolved combat mysteries in the supplemental census. Each node is counted once in each fixed-k scenario, and once per reachable k in native_prefix, never once per combat repeat. These are unweighted node distributions for those maps and controlled fight schedules, not human route probabilities or an exhaustive distribution over all map seeds. Counts are enemy entries, not occupied footprint tiles. All enemies actually present at room start are shown first; game `summoned=true` flags are then separated so the director’s summon exclusion can be assessed. Starting Ice Snare hunters and starting dragon wisps are not automatically excluded as summons. Mid-fight arrivals never enter these tables.','',
      'Two fixed scheduling scenarios expose the count-cap dependency: **first_eligible** sets k=1/3/5 by depth band, matching the fights; **late_k6** sets k=6 at every room as a count sensitivity check. The latter is a counterfactual at early bands and is not claimed to be a reachable sixth fight in every room. **native_prefix** additionally propagates all possible completed-fight counts over the section DAG (including hidden combat mysteries) and retains a real incoming direction witnessing each k. It reports equally weighted node/k cases; path multiplicity and encounter histories are not natural-route probability weights. The depth-band column remains the native band; raw effective_encounter_tier records the roster tier after the k clamp. Histories remain empty; archived active omens apply. Umbra Depth is zero.','',
      table(['Scenario','Section','Tier','Cases','All start min/median/max','All >5','Non-summoned min/median/max','Non-summoned >5','Flagged summons min/median/max'],
            [[scenario,f's{s}',cat,*count_stats(selected)] for scenario in ['first_eligible','late_k6','native_prefix'] for s in range(6) for cat in ['normal','objective','guardian','boss']
             if (selected:=[r for r in census if r['scenario']==scenario and r['section']==s and r['category']==cat])]),'',
      table(['Scenario','Section','Depth band','Tier/kind','Cases','All start min/median/max','All >5','Non-summoned min/median/max','Non-summoned >5','Flagged summons min/median/max'],
            [[scenario,f's{s}',f't{tier}',kind,*count_stats(selected)] for scenario in ['first_eligible','late_k6','native_prefix'] for s in range(6) for tier in range(1,4)
             for kind in ['normal','warband','umbral_snare','last_light','ember_hoarder','guardian','boss']
             if (selected:=[r for r in census if r['scenario']==scenario and r['section']==s and r['tier']==tier and (r['objective_kind']==kind if r['category']=='objective' else r['category']==kind)])]),'',
      '### Every count path that can exceed five','',
      'The exhaustive token expansion audit below enumerates each authored normal composition, every supported room element and biome-group choice, then applies production token-preserving concrete trimming. The attached `crowded_catalog.jsonl.gz` retains all qualifying element/biome combinations. Modes explicitly separate Hunted and legacy Reach Exit additions; current k6plus is the maximum-cap normal schedule and current_with_hunted also covers qualifying k4/5 rooms. IDs not listed cannot exceed five under that mode. Additions assume available floor positions. All six terrain TEMPLATE_LIBRARY layouts are count-neutral; any can host an oversized normal/legacy roster.','',
      table(['Normal composition ID','Depth tier','Picker','Maximum'],[[r['id'],r['tier'],r['mode'],r['max_count']] for r in crowded_catalog()]),'',
      '- **Warband:** all six biome variants (earth, fire, air, ice, lightning, shadow) at local tier 3: captain +5 escorts =6. Tiers 1/2 start at 4/5. Ordered rosters: `data/special_encounters.json /types/warband/variants/*/escort`.\n'
      '- **Ice Umbral Snare:** three outgoing eligible exits give jailer +2 Sealbinders +3 initial hunters =6. Two exits give5. Other biomes have no initial hunters and start at the eligible exit count (at most three distinct physical exits in these maps).\n'
      '- **Hunted normal rooms:** any expanded five-unit normal roster becomes6; a six-unit late roster becomes7, when a placement tile is available. This also applies to legacy/mystery fights resolved as ordinary combat. It bypasses the table cap. No Hunted addition applies to special/Guardian/dragon rooms.\n'
      '- **Legacy Reach Exit:** each five-unit legacy tier-3 pool listed by `_base_encounter_enemy_type_pool` and `_add_element_locked_enemy_type_pools` can start at7 after +2 blockers; tier2 four-unit pools become6. Legacy encounter-table rosters can also exceed5 before/after the +1/+2 exit additions. These objectives do not generate in current revision≥6 normal rooms, but saved legacy rooms retain them. The three base tier-3 rosters and every fire/earth/ice/air tier-3 alternative qualify; all base and elemental tier-2 four-unit alternatives qualify.\n'
      '- **No other current authored special/Guardian/dragon initial roster exceeds5:** Hoarder4; Last Light4; Guardians2–3 (optional Umbra Depth19 helper adds1); dragons2–3. These bounds count starting flagged helpers too. Mid-fight summons, splits, hunters and survival reinforcements are separate.', '',
      'The following are **every hard-coded legacy pool roster** that can exceed5 after Reach Exit and/or Hunted. Array order is retained. A dash means that mode does not exceed5. Tier1 hard-coded pools cannot exceed5 even with both additions. These pools are separate from the token-table IDs above.', '',
      table(['Native tier','Pool','Ordered roster','Source line','Normal + Hunted','Reach Exit','Reach Exit + Hunted'],
            [[r['tier'],r['element'],', '.join(r['units']),f"`scripts/room_generator.gd:{r['line']}`",
              len(r['units'])+1 if len(r['units'])+1>5 else '—',
              len(r['units'])+[1,2,2][r['tier']-1] if len(r['units'])+[1,2,2][r['tier']-1]>5 else '—',
              len(r['units'])+[1,2,2][r['tier']-1]+1]
             for r in legacy_rosters() if len(r['units'])+[1,2,2][r['tier']-1]+1>5]),'',
      f'Every terrain template is count-neutral and can host the oversized roster paths: `RoomGenerator.TEMPLATE_LIBRARY[0]`, `[1]`, `[2]`, `[3]`, `[4]`, `[5]`. Their exact authored cells are in {location("scripts/room_generator.gd", "const TEMPLATE_LIBRARY")}; templates do not choose or cap the enemy roster.', '',
      'Actual oversized nodes in the controlled census (every occurrence, all three scenarios) are retained in `oversized_rooms.jsonl.gz`; the following compact table lists every distinct offending kind/encounter ID by scenario, section and depth band.','',
      table(['Scenario','Section','Depth band','Kind / encounter','Cases >5','Maximum'],
            [[*key,len(values),max(r['start_count'] for r in values)] for key,values in sorted(group_crowded(census).items())]),'',
      '### Shared section stat schedule','',
      'These are existing factors/additions, not proposed tuning. Health first rounds base×local upward, then rounds that integer×section upward; products below are explanatory nominal factors, not a replacement for those two ceilings. The same local schedule applies to normal, objective and Guardian starters before special overrides. Dragons use local step4 (factor1), even though their comparison depth is clamped to t3. Current fixed-point scale is1.', '',
      table(['Section','Section Health factor','Local t1 / t2 / t3','Dragon local step4','Damage addition','Support addition','Trap section addition'],
            [[f's{s}',f'{1+.08*s:.2f}','0.85 / 1.00 / 1.12','1.00',[0,1,1,2,2,3][s],[0,0,1,1,2,2][s],[0,1,1,2,2,3][s]] for s in range(6)]),'',
      '## C. Existing knobs for a stat-only scale','',
      'Health already has a shared **local-depth multiplier**, a shared **per-section slope**, base enemy Health, captain/jailer/hoarder relative multipliers and optional Umbra Depth class percentages. Damage currently uses **additive section arrays**, zero local-depth deltas, base action damage, Warband Command and optional Umbra Depth class bonuses; it has **no existing general per-difficulty-tier × section damage-multiplier matrix**. There is likewise no four-difficulty-tier × section Health table. Umbra Depth class selectors distinguish regular/Guardian/dragon, not special-objective tier or section. Normal enemies and special enemies share their base definitions, so base-stat edits alone can affect several tiers.','',
      table(['Purpose','Exact existing location','Scope / constraint'],[
       ['Initial Health',location('scripts/room_generator.gd','const ENEMY_HP_SCALE_PER_SEQUENCE'),'ENEMY_HP_SCALE_PER_SEQUENCE=.08; FLAT_BONUS=0; DEPTH_ONE=.85; DEPTH_THREE=1.12; _scaled_enemy_max_hp applies two ceilings'],
       ['Spawned Health',location('scripts/combat_engine.gd','const ENEMY_HP_SCALE_PER_SEQUENCE'),'Matching constants and _scaled_enemy_max_hp must stay coherent with RoomGenerator'],
       ['Section damage/support',location('scripts/combat_engine.gd','const ENEMY_DAMAGE_BONUS_BY_SEQUENCE'),'ENEMY_DAMAGE_BONUS_BY_SEQUENCE and ENEMY_SUPPORT_BONUS_BY_SEQUENCE are per-section additions'],
       ['Local damage/support',location('scripts/combat_engine.gd','const ENEMY_DAMAGE_DELTA_DEPTH_ONE'),'ENEMY_DAMAGE_DELTA_DEPTH_ONE/THREE and ENEMY_SUPPORT_DELTA_DEPTH_ONE/THREE; step2/4 fallback zero'],
       ['Identity base Health / damage',location('data/enemies.json','"crawler"'),'JSON /<id>/max_hp and /<id>/intents/*/actions/*/damage (plus special damage fields); global fixed-point conversion in GameData'],
       ['Warband / Snare / Hoarder',location('data/special_encounters.json','"warband"'),'JSON /types/warband/captain/hp_multiplier; /types/umbral_snare/jailer/hp_multiplier; /types/ember_hoarder/hoarder/hp_multiplier; Command damage_bonus'],
       ['Optional class Health/damage',location('data/depths.json','"levels"'),'JSON /levels/*/modifier: enemy_hp_percent, enemy_damage_bonus, boss_enrage; DepthRules.enemy_hp / damage_bonus, not run-section tables'],
      ]),'',
      'A later four-tier section matrix would need an explicit tier classifier/context at the existing Health and action-scaling sites, with a defined order relative to captain multipliers and overrides, and consistent spawn propagation. No such matrix, values or design choice is introduced here. Count caps, Warband escort slicing and Hunted additions are independent of these stat knobs.','',
      '## Protocol, budget and limitations','',
      f"Pilot: {contract['pilot_fights']} fights in {contract['pilot_elapsed_seconds']:.1f}s. Remaining full-grid projection with 15% margin: {contract['projected_remaining_full_seconds']:.1f}s. Selected sections {contract['selected_sections']}; priority-grid projection {contract['projected_remaining_priority_seconds']:.1f}s. At resume, the full-grid projection exceeded the remaining three-hour budget, so s0/s2/s4 were prioritized; s1/s3/s5 pilot observations remain clearly low-N. Remaining omitted-grid sample: {contract.get('omitted_fights_to_64', 'not yet tabulated')} fights to reach the same repeat target; projected cost {contract.get('omitted_projection_seconds', contract['projected_remaining_full_seconds']/2)/60:.1f} minutes at pilot throughput with the same margin. This is not a promise of equal workload across sections.",'',
      f"Turn caps (raw): {sum(r['turn_cap_reached'] for r in raw)}; decision-cap fights: {sum(r['search_capped'] for r in raw)}. Caps count as losses. Median Health lost is the production run_stats.damage_received increment, including damage later healed, over both wins and losses. Turns also include losses. Wilson intervals are fight-level descriptive intervals; seeds share decks and geometry, so these are not cluster-adjusted estimates for future loadouts, rooms or players.",'',
      'The meas-06 ladder collector (`tools/run_curve_ladder.py`, meas-06 run_curve report) supplies eight saved ladder identities and typed **pre-dragon fight-entry** snapshots per section, reused exactly as in meas-07’s corrected protocol. They are not fresh current-HEAD full-run recoveries or snapshots at every room’s actual arrival time. Current HEAD room/enemy/card/combat factories apply to those fixed fixtures; every measured fight starts at full maximum Health. Thus the report isolates relative fight difficulty conditional on that fixed ladder-entry library, not natural attrition or player win probability. Production choices, deck upgrades, equipment, grafts, items, relics and active omens are retained. No previous fight outcomes are reused. The source ladder continues after loss/cap using an unmeasured forced-victory transition so rewards and deck growth reach later sections; completed_ladder means protocol completion, not survival. This inherited continuation shapes the fixture library.','',
      'Selection: first native normal room per depth band; first native Guardian per section; native dragon; objective nodes rotate by (repeat+seed−1) modulo that section’s native objective count in map-step/lane order. The first incoming predecessor in coordinate-string order supplies a real production travel direction. The initial diff-01 planner reused meas-07’s ZERO entrance and failed Snare placement; that discarded planner log is preserved separately. Empty encounter history and k=1/3/5 are controlled contexts, not fully reconstructed routes. Every current normal room asserts Kill All. Raw inputs preserve coordinates, seeds, rosters, constructor payloads and hashes.','',
      'Frozen `tools/encounter_bot.gd` and `tools/run_curve_combat.gd` are used unchanged. Their base CombatEngine transitions bypass `scripts/battlefield_rules/committed.gd` acceptance callbacks, including half-Health battlefield phase switches. The meas-07 fidelity caveat therefore also applies to objective/Guardian/dragon rule comparisons. Numbers are relative only; no tuning recommendations or human difficulty conclusions are inferred.','',
      '## Proof and reproduction','',
      'Exact expanded engine commands, return codes and per-process wall time: [commands.json](commands.json). Collection contract, frozen source hashes and total wall time: [contract.json](contract.json). Fresh outcomes: [runs.jsonl.gz](runs.jsonl.gz). Full native constructor payloads: [inputs.jsonl.gz](inputs.jsonl.gz). Archived fixture provenance: [entry_loadouts.jsonl.gz](entry_loadouts.jsonl.gz). Native-node counts: [inventory.jsonl.gz](inventory.jsonl.gz), extended count sensitivity: [census.jsonl.gz](census.jsonl.gz), every oversized census occurrence: [oversized_rooms.jsonl.gz](oversized_rooms.jsonl.gz), exhaustive table combinations: [crowded_catalog.jsonl.gz](crowded_catalog.jsonl.gz), hard-coded rosters: [legacy_rosters.jsonl.gz](legacy_rosters.jsonl.gz). Logs: [worker_logs.jsonl.gz](worker_logs.jsonl.gz) and [census_logs.jsonl.gz](census_logs.jsonl.gz). Focused check results: [verification.txt](verification.txt). Top-level collection history and resolved setup failures: [collection_history.json](collection_history.json), [discarded_planner.jsonl.gz](discarded_planner.jsonl.gz). Resource audit: [resource_audit.md](resource_audit.md).','',
      '```sh',
      'cd /Users/borgerding/workspace/Labyrinth.worktrees/diff-01 && python3 tools/diff01/collect.py --scratch-dir /private/tmp/labyrinth_codex/diff01-reproduction --output-dir /private/tmp/labyrinth_codex/diff01-reproduction-output --priority-only',
      'cd /Users/borgerding/workspace/Labyrinth.worktrees/diff-01 && python3 tools/diff01/finalize.py --scratch-dir /private/tmp/labyrinth_codex/diff01-reproduction --output-dir /private/tmp/labyrinth_codex/diff01-reproduction-output',
      'cd /Users/borgerding/workspace/Labyrinth.worktrees/diff-01 && python3 tools/diff01/verify.py /private/tmp/labyrinth_codex/diff01-reproduction-output',
      '```','',
      'No windowed command, capture or inspection fixture applies: this unit has no visual/player-facing change. No TODO_DESIGN placeholder was needed. Chosen defaults are measurement-only: seeds1–8, repeats0–7, seed stride1000003 (meas-07), first eligible k1/3/5, late-count sensitivity k6, first native normal/Guardian, rotating native specials, coordinate-sorted incoming predecessor, four workers, batch size4, planning timeout600s, count-census timeout300s, audit seed7/section3/band2, unused fallback travel RIGHT, LABYRINTH_CEL_LOOK=off, three-hour wall budget, 120s archival reserve, 15% projection margin and 95% Wilson descriptive intervals (as in meas-07). Combat bounds remain the existing bot’s bounds.','']
    (output/'report.md').write_text('\n'.join(lines))
    summary = dict(raw_fights=len(raw),reported_fights=len(rows),excluded_partial_fights=len(raw)-len(rows),
                   n_by_section_category={f's{s}-{cat}':sum(r['section']==s and r['category']==cat for r in rows) for s in range(6) for cat in ['normal','objective','guardian','boss']},
                   inventory_nodes=len(inventory),census_rows=len(census))
    (output/'summary.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')


def location(path,needle):
    from inventory import location as locate
    return locate(path,needle)


def group_crowded(census):
    groups = defaultdict(list)
    for r in census:
        if r['start_count']>5:
            key=(r['scenario'],f"s{r['section']}",f"t{r['tier']}",r['objective_kind'] if r['category']=='objective' else (r['encounter_id'] or r['category']))
            groups[key].append(r)
    return groups

if __name__ == '__main__': write_report(Path(sys.argv[1]) if len(sys.argv)>1 else DEFAULT_OUTPUT)
