#!/usr/bin/env python3
"""Render the atk13 report from completed evidence; no inferred capture success."""
from collections import Counter
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import statistics
import subprocess
import sys

from capture_plan import commands
import inventory

PROJECT=Path(__file__).resolve().parents[2]
ARTIFACTS=Path('/private/tmp/labyrinth_codex/atk-13')
REPORT=PROJECT/'spec/peer_benchmark/readability/atk13_storm_cantor_and_area_attacks.md'
NAMES={'peal_direct':'Peal, primary','peal_chain':'Peal, Chain','capacitor_shock':'Capacitor Arc, conducted Shock','capacitor_damage':'Capacitor Arc, damage','static_lash':'Static Lash + its tile','spark_dart':'Spark Dart','broken_rhythm':'Broken Rhythm','new_wisp':'Wisp arriving after forecast','other':'Other (Tender / ticks / Fatigue)','reaimed':'Re-aimed after shown (overlap)'}

def tuple4(d):return ' / '.join(str(d.get(c,0)) for c in ['11','10','01','00'])

def source_table(data,mode):
    out=['| Source | Rest red | Hovered red | PASS number/status | Striking move text/tooltip |','|---|---:|---:|---:|---:|']
    for src in NAMES:
        out.append('| '+NAMES[src]+' | '+' | '.join(tuple4(data['matrices'].get(f'{mode}:{src}:{channel}',{})) for channel in ['red_rest','red_hover','panel','intent'])+' |')
    return '\n'.join(out)

def repro(hit):
    seed=hit['point'].split('-')[0]
    at=hit['tile'] if hit['mode']=='move' else hit['hero_tile']
    return f'seed {seed}, turn {hit["turn"]}, {hit["mode"]} at {at}; `{hit["save"]}`'

def pick(data,source,**criteria):
    matches=[h for h in data['hits'] if h['source']==source and all(h.get(k)==v for k,v in criteria.items())]
    return matches[0] if matches else None

def all_rows():
    out=[]
    for label in ['census','real-health']:
        for p in sorted((ARTIFACTS/'audit'/label).glob('*/samples.jsonl')):
            if not(p.parent/'completed.json').exists():continue
            for line in p.read_text().splitlines():
                row=json.loads(line)
                if row.get('kind')=='check' and row['mode'] in ['pass','move']:
                    row['_run']=p.parent.name;out.append(row)
    return out

def main():
    data=json.loads((ARTIFACTS/'audit/all/report.json').read_text())
    text=json.loads((ARTIFACTS/'text.json').read_text())
    rows=all_rows()
    if len(rows)!=data['checks']:raise SystemExit('Aggregate is stale; rerun audit.py report after completed runs settle')
    pass_rows=[r for r in rows if r['mode']=='pass'];move_rows=[r for r in rows if r['mode']=='move']
    certain=[r for r in rows if not r['disclosed']]
    numeric_errors=sum(any(r['shown'][k]!=r['actual'][k] for k in ['hp','stoneskin']) for r in certain)
    defenses={k:sum(sum(s.get(k,0) for s in r['actual']['slices'] if not(k=='block' and s['actor']=='turn_start')) for r in rows) for k in ['block','stoneskin']}
    fresh_health=sorted({r['context']['hero_hp'] for r in pass_rows if 'hp0' in r['_run'] and r['context']['turn']==1})
    scope=inventory.rows();models=Counter(r['model'] for r in scope)
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=PROJECT,text=True).strip()
    outputs=[]
    def add(s):outputs.append(s.strip()+'\n')
    add(f'''# atk-13 — Storm Cantor and tile-targeted attacks: shown versus played

Audit only, 2026-11-16. Base `{head}`. The audited game code/data paths have no diff against the owner's Steam build `1fc819f59` (`git diff 1fc819f59 -- scripts/combat_engine.gd scripts/run_scene.gd data/enemies.json data/battlefield_rules.json`). No game code, data, art, tests, analytics or save formats changed. atk-06 itself is untouched; the opt-in subclass is `tools/atk13/audit.gd`.

**The central omission is Shock, rather than an observed undisclosed error in the Health number.** Lightning Storm injects Shock 1 as well as its 3 damage and Chain 2. Neither Peal's move row, the Cantor rule sentence, nor the PASS rows name that Shock. Capacitor Arc's conditional Shock **is** present in the expanded move rows and pre-battle rows. The compact badge and PASS do not name its condition/status. The rule's Chain can hit plain floor; its field forecast marks primary Electrified fuel, not the whole Chain route.

Native captures are **pending owner execution**, as required by the sandbox's lack of a window server. No 1920×1080 image or native pointer result is claimed here. The supplied native script uses cel rendering, 1920×1080, 100% scale, production panels/assets and saved audited decisions; headless checks cover its component/semantic paths. Three existing loop frames were decoded and inspected, not rendered or generated.''')
    add('''## A. Forecast truth in the Storm Cantor fight

### Method and denominators

The atk-06 real-scene PASS/rest/destination audit and atk-09 in-run old/current red pairing run unchanged through inheritance. Each decision audits PASS and every legal movement destination, then continues a seeded walk without hero attacks. Encounters are actual natural map guardian rooms; no tier is assigned to a room that did not generate at that tier. The fresh profile/loadout is retained, so this is a targeted encounter walk, not a claim to reproduce a progressed player's build. Local encounter tiers 1, 2 and 3 are the three non-boss depth bands (`section_map_graph.gd:1024`, `room_generator.gd:649`); Umbra depth is the fresh profile default 0. Global section scaling and visibility are left intact.

“Hit” includes Health, Block or Stoneskin actually lost, any harmful status gained, and involuntary displacement before the next playable turn. Walking voluntarily is excluded; harm incurred during the walk is included. Block expiry is excluded. Status gains are recorded at action/activation boundaries, even if consumed at the next hero start. The Cantor-fight observed status is Shock. Per-action oracle wrappers call the production resolver, mute all planning-copy observations, and compare the complete legacy actual trace with an uninstrumented production trace at every check. Receipt Health must not exceed actual Health loss; residual ticks/Fatigue/defense loss enter Other. Every point has a production resumable `run.save`, `progression.json`, and `combat_state.txt`.

Rows are alternative choices from the same saved decisions, not independent played fights or a probability estimate. “All” coverage counts observed decision-point intents, “visible” requires that the player can currently see that foe; “executed” below deduplicates source/clock/intent receipts only along each continued walk, never all counterfactual branches.''')
    add(f'''Completed evidence: **{len(data['runs'])} encounter runs; {len(pass_rows)} PASS decisions; {len(move_rows)} destination checks; {len(rows)} total alternatives**. Real-Health starting values: {fresh_health}. Oracle/production trace mismatches: **{data['oracle_mismatches']}**; receipt Health overcounts: **{data['receipt_hp_exceeds_actual']}**; UI forecast/replica mismatches: **{data['integrity']['replica_mismatches']}**. Among **{len(certain)}** checks with no uncertainty disclosed, Health/Stoneskin number disagreements: **{numeric_errors}**; widened-hit boolean disagreements: **{data['integrity']['undisclosed_hit_mismatches']}**. These walks incurred Block loss {defenses['block']} and Stoneskin loss {defenses['stoneskin']}; they do not establish coverage of defended builds.''')
    coverage=['| Tier | Lay all / visible / executed | Peal all / visible / executed | Broken Rhythm all / visible / executed | Call the Spark all / visible / executed |','|---|---:|---:|---:|---:|']
    for tier in ['1','2','3']:
        shown=data['coverage'].get(tier,{})
        actual=data['walked'].get(tier,{})
        visible=data['visible_coverage'].get(tier,{})
        coverage.append('| '+tier+' | '+' | '.join(f'{shown.get("storm_cantor:"+key,0)} / {visible.get("storm_cantor:"+key,0)} / {actual.get(key,0)}' for key in ['lay_the_choir','peal','broken_rhythm','call_the_spark'])+' |')
    add('\n'.join(coverage))
    add(f'''Shock gains across alternative choice/source windows: Peal primary **{data['status_hits'].get('peal_direct:shock',0)}**, Peal Chain **{data['status_hits'].get('peal_chain:shock',0)}**, Capacitor Arc **{data['status_hits'].get('capacitor_shock:shock',0)}**. These count gains, not refreshes of an already-present layer or unique played events.''')
    add('''### Agreement matrices

Each cell below is **told+hit / told+no-hit / not-told+hit / not-told+no-hit**. The second cell is a false alarm for a red or numerical prediction. For intent text it means a disclosed possible effect that did not occur, not an incorrect promise to hit.

When several harmful receipts share a source row, its told flag requires all of those receipts to be covered. Each individual receipt also carries its own `told` flags in the JSON. First, the literal board color against **any** widened hit, regardless of owner:''')
    total_table=['| Choice / red queried | 11 / 10 / 01 / 00 |','|---|---:|']
    for k,title in [('pass:rest','Hero at rest, PASS'),('move:rest','Destination in the rest set'),('move:hover','Destination while hovered')]:total_table.append('| '+title+' | '+tuple4(data['global_matrices'].get(k,{}))+' |')
    add('\n'.join(total_table))
    add('''Per-source matrices use the red owners the board records. A tile can be red for another foe while this source is untold; raw global rest/hover booleans remain beside **every hit** in `audit/all/report.json`. Red is a generic danger signal, so an Arc-owned red tile counts as told for both Arc damage and its Shock; it does not explain Shock. Peal primary versus Chain is separated by the actual rule impact: hero inside supplied fuel tiles versus off those tiles. Shared rule ownership is allocated to that branch, not duplicated across both.

The PASS column counts a resource row attributable to that source's activation in the forecast replica and actually present in the panel. PASS has no status row. It does not display source-by-source amounts; a number caused by a different foe does not count as telling this source's hit. The striking-move column requires a visible currently announced matching intent, not an unseen future roll or a move listed earlier in a reference panel. Peal's separate rule sentence is documented in B, not credited to its Move 1 row. Sources may co-occur in one choice; the re-aim row is explicitly overlapping evidence, and the two Arc rows separate effects. These source rows must not be summed as independent choice counts.

**PASS / hero at rest:**''')
    add(source_table(data,'pass'))
    add('**Movement destinations:**')
    add(source_table(data,'move'))
    add('''“Re-aimed” means an actual damaging attack reaches a hero tile absent from that foe's plan at the shown boundary. This is an observed changed aim/coverage, not a claim that a wrong footprint was drawn. It can be ordinary following, an earlier actor changing the board, or a later activation. Named move sources retain their own rows; this reason overlaps them.

Global clear-and-hit / red-and-safe classifications, by contributing source (multiple causes can share a choice):''')
    cause_table=['| Choice / warning result | Sources and counts |','|---|---|']
    for key,counts in data['global_causes'].items():cause_table.append('| '+key+' | '+', '.join(f'{NAMES[k]}: {v}' for k,v in counts.items())+' |')
    add('\n'.join(cause_table))
    add('### Findings and concrete reproductions')
    findings=[
      ('F1 — Peal applies unnamed Shock 1','peal_direct',dict(mode='pass'), 'The rule primitive constructs `shock: 1`; the primary strike and a Chain strike can both deliver it. Peal itself has no attack action. PASS still counts known damage, but no status row warns of this gained Shock. Source: `scripts/battlefield_rules/lightning_storm.gd:13`, `data/enemies.json:1999`, `data/battlefield_rules.json:277`, `scripts/pass_forecast_focus_tooltip.gd:84`.'),
      ('F2 — Chain can leave the painted electrical field','peal_chain',dict(mode='move',raw_red_hover=False), 'Rule fuel is a primary tile set. `_board_attack_plan` adds live unit/relay hops and conduction. `battlefield_rules/outcomes.gd:50` exports only fuel to `tiles.strike`; the `hits` projection does retain the Chain victim. atk-11 can add a known resource-hit warning on the hero tile, but this is not a complete Chain route map. `mechanics.gd` separately confirms a plain-floor hero takes 3 and Shock 1 while missing from the rule tile projection.'),
      ('F3 — Arc Shock exists in expanded text, but not PASS or the compact rider','capacitor_shock',dict(mode='pass',intent=True), 'The expanded combat/pre-battle row says `if Electrified used: Shock +1`. The conditional uses `electrically_assisted` in the shared board resolver, including direct victims touching the conducting component. The compact badge picks riders from `tokens_for_action`, not `tokens_for_surface_bonus`; PASS lists resource losses and uncertainty, not status gains. This disconfirms the lead that Shock is absent from every intent surface.'),
      ('F4 — A clear tile can still be hit when Static Lash is unresolved under uncertainty','static_lash',dict(mode='pass',raw_red_rest=False), 'This run shows an actual Static Lash loss on a clear tile with an uncertainty marker. Inspect the save before labeling it a numerical lie: the report found no widened-hit mismatch without disclosed uncertainty. Its separate range-0 Electrified action lays ground under the Wisp, not under the struck hero (`combat_engine.gd:4720`). Newly placed ground cannot fuel a rule until the next player activation; `battlefield_rules/fuel.gd:1`.'),
      ('F5 — Spark Dart is an ordinary approach and melee, without innate Shock','spark_dart',dict(mode='pass'), 'The data action is Move 3 followed by non-elemental melee. Its name does not make it a Shock or tile-lightning attack. Misses here must be read with visibility/uncertainty, rather than credited to a missing Shock rider. Source: `data/enemies.json:1742`.'),
      ('F6 — Changed aim/coverage after the shown boundary','reaimed',dict(mode='move',raw_red_rest=False), 'Compare the saved rest plan with the destination branch. The harness records `shown_plans`, actual per-action receipts and both red-owner sets. This overlap requires a visible foe and the same currently announced intent; hidden/unannounced moves are not called re-aims. This is also why a rest-red footprint is not a fixed-location contract for every move. C separates ordinary live aim from held-direction/live-origin patterns.')]
    for title,src,criteria,body in findings:
        hit=pick(data,src,**criteria)
        add(f'**{title}.** {body}\n\nReproduction: '+(repro(hit) if hit else 'Not observed in this completed sample; static/controlled evidence only.'))
    nohit={src:sum(data['matrices'].get(f'{mode}:{src}:red_hover',{}).get(c,0) for mode in ['pass','move'] for c in ['11','01']) for src in ['broken_rhythm','new_wisp']}
    add(f'''Broken Rhythm actual hits in these alternatives: **{nohit['broken_rhythm']}**; post-forecast new-Wisp hits: **{nohit['new_wisp']}**. Zero is an observation, not proof those cases are impossible. Broken Rhythm declarations/executed actions do meet the coverage target. Other includes Bell Tender's Staff Bolt and non-action loss such as Fatigue. Full per-channel, per-source miss/alarm examples, with seed, turn and save, are in `audit/all/report.json → examples`; every underlying check is in each run's `samples.jsonl`.''')
    add('''**F7 — A red/number false alarm under disclosed uncertainty.** Seed 1303, turn 2, hero (6,7) → (7,7), save `/private/tmp/labyrinth_codex/atk-13/audit/census/tier-2-seed-1303-hp9999/repro/1303-2`. The hover is red with owners `enemy_3` and `hit:battlefield_rule`; PASS shows 3 and an Umbra uncertainty marker. Actual Peal fires with no hero route and no hero harm; the Tender also deals none. This is a Chain-source and Tender-source false alarm in the matrices, not an undisclosed sure prediction. A hidden Wisp acts in the actual span but is excluded from the shown forecast span, so the two boards differ before Peal. Replay with `--tile 7,7`; no claim is made that the filtered route is the real route.

''')
    add('''## B. Each Cantor-fight move: visible wording versus effects

The following is an exact production row-builder export at seed 1305's tier-1, section-5 guardian (global depth 17), not unscaled catalog damage. Numbers change with normal encounter scaling; the rule remains 3 / Chain 2. The shared row/tooltip builders are invoked by `tools/atk13/presentation.gd`; text evidence is `/private/tmp/labyrinth_codex/atk-13/text.json`.''')
    move_table=['| Move | Expanded combat / pre-battle summary | Effect/target information not stated there |','|---|---|---|']
    omissions={
     'lay_the_choir':'No tile map, seed/path score, tie breaks, full-budget fill, held-plan/translation timing, or fuel eligibility delay. Connector tooltip/notes do say it extends existing Electrified toward its target. Move 2 is stated.',
     'peal':'Only Move 1. Omits the separate 3-damage all-eligible-Electrified beat, Chain 2, Shock 1 and team-neutral victims. The rule sentence supplies damage/Chain, not Shock.',
     'broken_rhythm':'No additional intrinsic rider found; Move 2, melee damage and Range 2 are stated in action order. No innate Shock.',
     'call_the_spark':'Summon count/caps and the exact first-action initiative boundary are not fully described by the short row. No innate strike or Shock; a newly arriving Wisp can require an unknown-arrival forecast.',
     'spark_dart':'No extra intrinsic effect found. Non-elemental melee; no innate Shock. Move 3 is stated before the hit.',
     'static_lash':'The standalone Electrified row does not say it is laid under the Wisp. Lightning can conduct through existing connected ground; rule fuel eligibility waits until next player activation. Move 1 is stated.',
     'blinding_arc':'The conditional Shock is stated. “Used” is not a full description of electrically-assisted contact/conduction, and the compact badge omits this conditional rider. Retreat 1 is stated before the shot.',
     'connector':'Same connector selector/held-origin/fuel-delay omissions as Lay the Choir, with a budget of 2.',
     'staff_bolt':'Lightning may conduct through connected Electrified; no innate Shock. Movement and ranged damage/range are stated.'}
    for m in text['moves']:
        summary=m['combat_text'].replace('\n',' / ')
        pre=m['prebattle_text'].replace('\n',' / ')
        if pre!=summary:summary+='; pre-battle: '+pre
        move_table.append('| '+m['enemy']+' — '+m['name']+' | '+summary+' | '+omissions[m['id']]+' |')
    add('\n'.join(move_table))
    add('''The turn-order enemy portrait deliberately has **no second tooltip panel** (`run_scene.gd:13057`); hover focuses that foe and opens its board rows. Thus the same Arc bonus is reachable through the focused board callout, while the portrait itself does not spell out Shock. The compact disc's rider extraction omits `surface_bonus` (`intent_badges.gd:230`).

### Lay the Choir selector and advance warning

At declaration, the guardian planner predicts its approach destination and target. Within range 5 and line of sight, existing Electrified tiles become seeds; absent any, the planned origin is used. It tries paths from each seed to the target and its four cardinal neighbors. It collects nonconductive path tiles until range/sight/budget stops it, scoring `−30 × endpoint distance + 2 × new tile count`, plus 100 for reaching the target and 10 for a conductive seed. The first strictly better candidate wins. To spend the six-tile authored budget even when the shortest connector reaches the hero early, a frontier then walks the linked conductive region, adds legal floor candidates, and picks nearest to target, then y/x. Blockers, saturation and available floor can reduce the result below six. This is deterministic board selection, not an unannounced random rain (`guardian_combat_rules.gd:611–672`).

For a concrete declaration, seed 1305, turn 9, hero (2,4), save `census/tier-1-seed-1305-hp9999/repro/1305-9` holds these six new tiles: **(4,3), (3,1), (4,2), (5,3), (4,1), (5,2)**. The hero is already in the electrical network. Replay prints both `declared_tiles` and `live_tiles`.

There is **no surface footprint in the at-rest red layer**, including foe hover or destination hover: `intent_badges.gd:202` does not classify a surface action as an attack. The expanded row says six linked tiles and its tooltip says extension toward its target. During the cast, production utility playback focuses declared tiles and lands surface feedback at release; that is after the decision to end the turn. Held connector tiles are translated from declared origin to actual origin and filtered by live passability/line of sight (`guardian_combat_rules.gd:394`), so they are not absolutely Locked.

### The `storm_cantor` Lightning Storm panel, loop and firing cue

The visible sentence is: **“When the Cantor uses Peal, lightning strikes every Electrified tile for 3, with Chain 2.”** Its rule icon tooltip says some storms Chain; the nested Lightning Strikes definition says it strikes marked tiles and leaves them Electrified. Neither explains this instance's Shock 1, team-neutral resolution, fuel-age boundary, or that this beat itself creates no additional Electrified. The primitive expressly omits a surface rider (`battlefield_rules/lightning_storm.gd:13–16`).

The rule panel selects the approved `lightning_strikes.tlw` recording by battlefield-rule identity. The recording's fixture is **`snare_lightning`, Chain 0**, not the Cantor's Chain 2 (`tools/tooltip_loops/tip03_fixture.gd:16`). It demonstrates walking from an Electrified tile to plain floor and an ordinary strike on the remaining occupied field tile. It does **not** demonstrate Chain, a plain-floor Chain victim or the Cantor. Existing frames 0, 23 and 46 were decoded and visually inspected under `/private/tmp/labyrinth_codex/atk-13/mechanics/approved-loop-*.png`.

At activation, the existing source caption can say **Storm Cantor: Peal**. The actual rule firing has **no distinct Lightning Storm banner or dedicated lightning-strike step**: `dispatcher.gd:140–180` appends a dedicated action only for Gust. The atk-12 hero-loss reconciliation supplies the damage number, Health change and hero hit reaction at source-turn completion (`hero_loss_playback.gd:18`); it does not submit a falling-bolt effect or a separate Chain animation. Generic hit/status audio can still arise from rendered state changes (`sfx_cue_router.gd:393–416`), including Shock, but there is no dedicated rule-firing cue here. The headless production playback also reached `Storm Cantor: Peal` at frame 297 with no effect kind, then `Bell Tender: Shocked` at frame 539 and `Storm Cantor: Shocked` at frame 769; it submitted no rule falling-bolt effect. The timeline is `/private/tmp/labyrinth_codex/atk-13/headless/cantor_playback.json`. This is code/step evidence, not a claim of having heard native audio. The supplied native playback capture logs the same fields for owner confirmation.''')
    add('''## C. Every tile-targeted move / battlefield beat

Scope is all current enemy/guardian/dragon intent definitions with a tile pattern, laid surface or trail, lightning conduction, Chain, force movement, Marked, delayed wall or Light snuff/relight; both Burst traits; and every battlefield-rule instance. Ordinary single-target damage/status, heals/buffs, ordinary summons and pure buff/heal surface-fuel payments/clears are excluded (they are not attacks or laid fields). Peal is represented by its rule instance, not invented as an attack action. A move with several applicable actions has one row. No separate splash verb exists in the current enemy catalog; its applicable effects are the AoE, Erupt neighbor, Burst and detonation rows. Warband modifiers reuse those moves: captain retreat is before planning, Slagmaster Lob has a saved side/barrage variant, and rule orders use the listed named instances. Removed legacy actions filtered by migration are not counted as active moves.

Models use the brief's **whole-move, absolute-tile** definition. **Locked** means the stored landing tiles remain the strike tiles after you move. **Follows** means current target/body aim at activation, including direct lightning's live network extension. **Neither** includes held direction with a live origin, fixed pressure plus a live direct shot, live board/rule fuel, and deferred displacement whose destination depends on blockers. A held orientation is not silently called Locked. Upheaval's stored marks can be pruned by live legality/connectivity, so it is also Neither under this strict definition.

Every row that is shown at one place and can fire elsewhere is marked **HYBRID**. This includes conventional Follows moves, not only held-direction shapes. **NO RED / NO TILES** identifies absent footprints; the visibility/due-turn limits apply to all other rows. “No lock/follow contract” means no on-screen statement of that temporal contract, not an absence of all shape/range/keyword information. Red is generally only before the next hero turn and only on currently visible tiles; foe hover isolates rather than pins it; destination hover rebuilds it.''')
    buffer=io.StringIO()
    with redirect_stdout(buffer):inventory.main()
    add(buffer.getvalue())
    add('''Inventory source audit: `inventory.py` reads every intent/action in `data/enemies.json`, both current `death_burst` definitions and every instance in `data/battlefield_rules.json`. All six dragons, six guardians, helpers and ordinary foes are included. Source locations point to owning intent IDs, not another enemy's repeated `bite`/`circle` ID. Variant details retain existing data; no extra prototype-only geometric actions are manufactured. This is a static code/data census, not all separately played encounter reproductions. The Cantor connector/Chain/changed-aim examples above are runtime reproductions of the relevant models; other rows explicitly rely on their cited resolver paths.''')
    add('''## D. “The red squares coming down” in this fight

The data and emitted action-step paths distinguish these cases; final pixel identification of what the owner meant is pending the native playback command.

| Candidate in the Cantor fight | What decides the tiles | Does it land on the painted tiles? / above-strike identity |
|---|---|---|
| Due Peal / Lightning Storm primary field | Eligible Electrified at the beat; ground laid in this player activation is ineligible until the next one. | Primary victims intersect that live fuel set. The earlier rest forecast can differ after intervening ground changes. Red comes from the rule projection plus known hero-loss receipts. The live Cantor rule has no dedicated falling-bolt action step, despite the generic Lightning Strikes painter existing. |
| Peal Chain off the field | Current units and conductor/relay network from primary heads; Chain 2 can leave Electrified. | Can hit plain floor outside the painted primary field. A known Health/defense-loss receipt may mark the hero there; there is no complete bounce-route red or live rule Chain animation. F2 is a saved reproduction. |
| Wisp Static Lash / Capacitor Arc, and Tender Staff Bolt | Live aimed target after that foe's movement, with conductor extension. | These are ranged lightning/projectile/contact effects, not a fixed rain footprint. Rest shows today's aim; destination hover rebuilds it. Earlier actions or visibility can still change coverage. Arc's Shock is a conditional rider, not a separate square falling from above. |
| Lay the Choir / Tender connector ground arrival | Held connector plan, translated/filtered from the actual caster origin. | Not a damage strike. No rest-red surface footprint; focus and ground flashes arrive during the cast. Treating those lightning ground effects as immediate damage squares conflates setup with the later rule beat. |
| Spark Dart / Broken Rhythm | Live approach + melee. | Ordinary melee contact; no authored overhead tile strike or innate Shock. |

There is **no authored Zekarion-style `lightning_strikes` attack in the Cantor or Wisp move list**. The literal descending-bolt painter is `combat_board_view.gd:12190`, reached by that effect kind; Peal's rule resolver does not append it. Therefore the audit cannot label an observed falling effect as a fixed Peal rain attack merely from its appearance. The dedicated native playback timeline is supplied to resolve the owner's visual reference without changing the game.''')
    add('''## Proof for the design owner

All commands start in the task worktree. No windowed run was attempted in this sandbox. Native rendering, visual quality, exact pixel bounds and native pointer interaction must be checked by the owner. Headless capture sidecars explicitly say `headless_semantics_only: true` and cannot count as renderer proof. Pre-battle and rule-loop panels use the production components at named debug-only staging positions so they are captured in the same viewport; no content or artwork is fabricated.

Headless audits and aggregate:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/audit.py run --label census --count 5 --health 9999 --turns 36
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/audit.py run --label real-health --count 2 --health 0 --turns 36
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/audit.py report --label all --include-label census real-health
```

Natural seed lists are in `audit.py → SEEDS`; runs skip only completed outputs. Each `cost.json` retains the exact runner command and ATK13 environment. Each seed executes `python3 tools/godot_task_runner.py --task-id atk-13 --stream -- godot --headless ...`. The existing atk-06 command/options/output are unchanged; `--script tools/atk13/audit.gd` is the opt-in extension.

Reproduce a saved finding (append `--tile x,y` for a destination alternative):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/godot_task_runner.py --task-id atk-13 --stream -- godot --headless --path . --script tools/atk13/replay.gd -- --save-dir /private/tmp/labyrinth_codex/atk-13/audit/census/tier-1-seed-1305-hp9999/repro/1305-9
```

Generate all exact native commands from the completed real saves:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && python3 tools/atk13/capture_plan.py --label census > /private/tmp/labyrinth_codex/atk-13/capture_commands.sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/atk-13 && sh /private/tmp/labyrinth_codex/atk-13/capture_commands.sh
```

The commands expanded below capture every Cantor/Wisp intent on body hover and portrait hover, both native pre-battle known-move panels, the rule HUD, its existing loop, and the real Peal playback. Output is `/private/tmp/labyrinth_codex/atk-13/captures/<name>.png`, `.json`, `.manifest.json`, `.log`, plus `_loop0..2.png` and playback `_step*.png`. `native_capture.sh` explicitly selects cel/Metal mobile via `tools/visual_probe_runner.py`, uses `--expect-size 1920x1080`, the proof contract, and no retries. These are expected paths, not claimed captured files.''')
    cmds=['```sh']
    import shlex
    for parts in commands(ARTIFACTS/'audit','census'):
        cmds.append('cd '+str(PROJECT)+' && sh tools/atk13/native_capture.sh '+' '.join(shlex.quote(p) for p in parts))
    cmds.append('```');add('\n'.join(cmds))
    add('''`tools/inspection_fixture.py` is not needed: these commands resume the real audited production saves in isolated runner homes, and stage only read-only inspection panels. No fixture installation or global Continue save is changed.

### Checks and cost
''')
    add(f'''Observed result lines:

```text
ATK13 REPORT all: runs={len(data['runs'])} checks={len(rows)} oracle_mismatches={data['oracle_mismatches']} receipt_hp_exceeds_actual={data['receipt_hp_exceeds_actual']}
ATK13 EVIDENCE CHECKS: PASS ({len(rows)} alternatives; 3 tiers × 4 intents >=20 visible/executed; {len(scope)} inventory rows; 19 native commands)
ATK13 MECHANICS: PASS (11 assertions)
ATK13 CAPTURE SEMANTICS: PASS (18 views; no renderer claims)
ATK13 CAPTURE playback: PASS
ATK13 REPLAY: PASS turn=9 hero=(2, 4) destination=
ISOLATION AUDIT: 56 modules; /private/tmp/labyrinth_codex/atk-13/python-audit/isolation-audit.md
```

Wall time per completed seed/run: median **{statistics.median(data['costs']):.3f}s**, range **{min(data['costs']):.3f}–{max(data['costs']):.3f}s**. This includes boot, real-scene forecasts, every destination, in-run pairing, instrumented/uninstrumented actual traces and production save copies. Some headless proof jobs overlapped; these are observed wall costs, not an isolated performance benchmark.''')
    costs=['| Run | Seconds |','|---|---:|']
    for label in ['census','real-health']:
        for path in sorted((ARTIFACTS/'audit'/label).glob('*/cost.json')):
            if (path.parent/'completed.json').exists():costs.append(f'| {label}/{path.parent.name} | {json.loads(path.read_text())["seconds"]:.3f} |')
    add('\n'.join(costs))
    add('''Headless semantic sidecars/logs are under `/private/tmp/labyrinth_codex/atk-13/headless/`; controlled proof JSON and the inspected loop frames are under `/private/tmp/labyrinth_codex/atk-13/mechanics/`. Python byte-compilation with a task-local `PYTHONPYCACHEPREFIX`, shell syntax, and protected-path Git diff checks exited 0. Focused check commands are recorded in `tools/atk13/README.md`; no full Python/GDScript suite or gameplay-identity gate was required for this audit-only unit. No tests were edited or added to `tests/`; proof checks live under `tools/atk13/`. The Python isolation audit still ran with `--audit-only`. Initial harness/parser/input-staging errors were fixed; production assertions were not rewritten. The macOS CA-certificate message and existing HUD anchor warnings appeared in headless logs; they did not become script failures or get suppressed.

### Chosen defaults / limits

Debug-only choices: seeds 1301–1340 for discovery and the natural tier-specific lists in `audit.py`; five full-Health and two ordinary-Health runs per tier; 36 decision points per walk; 75% seeded movement before PASS; entry direction UP; headless presentation time scale 64 and uncapped FPS; a 900-second driver timeout for known all-destination simulation work (early runs used the inherited 300 seconds). Capture staging: panel (72,80), rule tooltip (980,260), parked pointer (960,4), 90 boot frames, 1.2-second settle, 12 layout/cleanup frames, three existing-loop samples 0.7 seconds apart, playback budget 1800 frames / 60 signature-change captures. Controlled mechanics proof uses hero (4,5), Cantor (4,4), Health 9999, empty hazards/terrain, and an explicitly crossed player-activation boundary so newly placed fuel is eligible. No player-visible production value was selected or changed.

**TODO_DESIGN placeholders:** none added; no new perceivable design was required. **Open proof:** owner-native frames/audio interpretation and visual inspection. **Scope limit:** static C rows outside the Cantor fight are code/data findings, not claims of having played/captured every move. Unknown-arrival and defended-build cases with no observed hit remain reported as zero/untested. All changes remain uncommitted; peer review, publication and inspection approval are the design owner's steps.''')
    REPORT.parent.mkdir(parents=True,exist_ok=True)
    REPORT.write_text('\n'.join(outputs))
    print(f'ATK13 REPORT WRITTEN: {REPORT} ({len(scope)} inventory rows; {len(rows)} alternatives)')

if __name__=='__main__':main()
