"""Source-located difficulty inventory and exhaustive table-token count bounds."""
from itertools import product
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]


def location(path, needle):
    lines = (ROOT/path).read_text().splitlines()
    line = next(i for i,s in enumerate(lines, 1) if needle in s)
    return f'`{path}:{line}`'


def knob_rows():
    rows = [
      ('Map section/depth bands and route fight budgets', 'scripts/section_map_graph.gd', 'const FIGHT_COUNTS', 'FIGHT_COUNTS, ROOM_COUNTS, _depth_bands; global depth = section×4 + native band. Map weighting, fallback maps, guaranteed Guardians, optional mysteries and special substitutions determine what is encountered.'),
      ('Dragon and biome roster order', 'scripts/dragon_boss_library.gd', 'static func elemental_boss_order', 'Seeded permutation of five elemental dragons in s0–s4; Noctyrax in s5. Biome changes normal token groups, Warband escorts, Snare pressure and Last Light attackers. Guardian identity follows the dragon.'),
      ('Normal tier and route fight number', 'scripts/encounter_tables.gd', 'static func fight_number(', 'k counts cleared combat/special/Guardian rooms in this section (including resolved mysteries), not dragons. effective tier=min(native depth tier, min(3,1+(k−1)/2)); persisted fight_number retains the entry choice.'),
      ('Normal compositions, weights and caps', 'data/encounters.json', '"rules":', '/tiers, /element_regulars, /biome_groups, /rules: global max 7; tier caps 3/5/6; k caps 3/3/4/5/5/6, last repeats. Recent-history exclusion 2; weighted tokens must fit, concrete units trim from the end. Current tier-3 k≥6 can exceed five.'),
      ('Count selection and legacy fallback', 'scripts/room_generator.gd', 'func _encounter_enemy_types', 'Boss/Guardian rosters bypass normal caps. Legacy normal pools have 3/4/5 units by local depth. Element-locked groups add roster alternatives, not extra units. Invalid table data or exempt rooms use these legacy pools.'),
      ('Normal table legacy-save exception', 'scripts/encounter_tables.gd', 'if legacy: return expand_entry', 'Old rooms without persisted k retain the old picker and global seven-unit cap; modern per-tier/per-k caps are bypassed.'),
      ('Trap damage by local depth and section', 'scripts/room_generator.gd', 'const TRAP_DAMAGE_BY_ENCOUNTER_DEPTH', 'Local bands 1/2/3/4 use 6/7/8/5, plus section additions 0/1/1/2/2/3. Trap counts and positions use seeded geometry; Guardian arenas can replace traps.'),
      ('Special-room Umbra exceptions', 'scripts/combat_engine.gd', 'func _initial_umbra_state', 'The automatic section Umbra baseline applies to combat, Guardian and boss layouts, plus shadow Snare. Other special layouts default clear unless they set an explicit override; Last Light explicitly sets sight-radius-3 Umbra. Warband and Hoarder therefore do not automatically inherit normal-room section darkness.'),
      ('Fatigue and fight length', 'scripts/combat_engine.gd', 'var fatigue_damage: int', 'Deck cycles increase fatigue damage from base 2 by cycles−1; optional Umbra Depth18 adds1. This is turn/deck-dependent, not a tier/section multiplier; Survive duration and enemy healing can expose it more often.'),
      ('Health: shared local-depth and section scaling', 'scripts/room_generator.gd', 'func _scaled_enemy_max_hp', 'ceil(base×local), then ceil(result×(1+0.08×section)), plus flat bonus 0×section. Local factors: band 1=.85, band 2=1, band 3=1.12, boss band 4=1. Applies to initial enemies before special overrides.'),
      ('Health: combat spawns', 'scripts/combat_engine.gd', 'func _scaled_enemy_max_hp', 'Duplicate shared local/section Health formula used for reinforcements, splits and summons; keep both implementations coherent if tuned later.'),
      ('Damage and support by section', 'scripts/combat_engine.gd', 'const ENEMY_DAMAGE_BONUS_BY_SEQUENCE', 'Damage flat additions s0–s5: 0/1/1/2/2/3; support: 0/0/1/1/2/2. Local damage deltas are both 0; local support band 1 is −1, band 3 is 0. These are fixed-point runtime units, not multipliers.'),
      ('Damage action applicability and exemptions', 'scripts/combat_engine.gd', 'func _scale_enemy_action_for_depth', 'scale_damage=false opts standard attacks out. ATTACK_ACTION_TYPES, lightning_strikes and BOSS_DAMAGE_ACTION_TYPES receive damage additions; lob_land center/arm fields have a separate path. Block/Stoneskin/guard/heal/raised-terrain Health receive support additions.'),
      ('Fixed-point base stats and intrinsic difficulty', 'scripts/game_data.gd', 'static func _scale_enemy_fixed_point', 'data/enemies.json /<id>/max_hp and /<id>/intents/*/actions (damage, healing, statuses, summons, durations, time_cost), defenses, initiative and movement; fixed-point conversion is global representation, not section tuning. No separate general elite-roll or captain-roll scaler was found.'),
      ('Guardian roster, initial helpers and arenas', 'scripts/guardian_library.gd', 'const DEFINITIONS', 'DEFINITIONS helpers (overridden by enemy guardian_initial_helpers), plus one Guardian. Authored pillars, surfaces and rule instances are identity-specific; starting lightning_wisp/wick_shade helpers are marked summoned. Other attendants count normally.'),
      ('Guardian reinforcement and phase picks', 'scripts/guardian_combat_rules.gd', 'static func available_summon_tiles', 'Guardian helpers use live caps (two total and guardian_cap per type), replacement/special intents, and production battlefield mechanics. These later arrivals are separate from starting counts.'),
      ('Dragon initial rosters', 'scripts/room_generator.gd', 'if room_type == "boss":', 'Zekarion has two starting lightning wisps; Noctyrax two Veilbound Acolytes. Others use data/enemies.json /<dragon>/dragon_helpers. These starting wisps are not automatically flagged summoned by the Guardian-only helper path.'),
      ('Special placement and scarcity', 'data/special_encounters.json', '"placement":', '/placement chooses 2 or 3 distinct kinds per section, caps route specials at 2, excludes adjacent Guardians and requires a route without specials; enabled and first_layout_revision gate kinds. All four enabled kinds are inventoried.'),
      ('Warband size, captain and command', 'scripts/warband_room_rules.gd', 'static func roster', '1 captain + first tier+2 ordered escorts: total 4/5/6. Captain selection is authored by biome, not an elite random roll. /types/warband/captain: Health ×1.25, Stoneskin 2/3/4; Command +1 printed damage in radius 2; variant orders add distinct battlefield effects.'),
      ('Warband live damage command', 'scripts/warband_combat_rules.gd', 'static func command_bonus', 'Converts the authored +1 to fixed-point at use; only living non-captains in a living captain’s radius qualify. Placement and keep-away/formation rules also change difficulty.'),
      ('Snare size, stats and sealing clock', 'scripts/snare_room_rules.gd', 'static func roster', '1 jailer + door_count−1 Sealbinders + biome start_hunters. Ice starts 3 hunters: three exits yield 6 units. Jailer Health ×2, Stoneskin 2/3/4; binders override scaled Health with SEALBINDER_HP=4. Doors seal on authored 2/4 turns (two-exit exception 3); non-Ice hunters arrive later up to hunters_max=3.'),
      ('Snare biome pressure', 'scripts/snare_pressure_rules.gd', 'static func definition', '/types/umbral_snare/variants/*/pressure: rubble, spreading fire, headwind, ice, lightning and shadow pressure. Pressure fields, battlefield instance and per-turn timing are biome-specific.'),
      ('Last Light roster and duration', 'scripts/last_light_rules.gd', 'static func roster', '2 Wick Shades + two biome attackers =4 starters. /types/last_light/time_target_by_depth=60/66/72; sight_radius=3; three braziers. Survive waves later add enemies independently of the starting cap.'),
      ('Hoarder roster, relative Health and escape', 'scripts/hoarder_room_rules.gd', 'static func roster', '/types/ember_hoarder: one Hoarder +3 Ember Ticks =4 starters. configure overrides Hoarder Health to 3×its brood’s final scaled Tick Health; escape clock by tier 5/4/4. Capturing and escaping are both combat victories once remaining foes are gone; bonus goal_met is distinct from won.'),
      ('Generic legacy objectives', 'scripts/combat_objective_rules.gd', 'const SURVIVAL_TARGET_BY_ENCOUNTER_DEPTH', 'Revision≥6 normal rooms are Kill All. Older saved maps: the highest-scaled-Health enemy becomes leader (first in roster on ties), then leader Health ×1.5 and Stoneskin 2+tier; Reach Exit adds 1/2/2 enemies and terrain +3; Survive targets 42/46/50 and wave interval 16 (new random Survive picks parked). Guardian/dragon leader scaling is ×1 and +0 Stoneskin.'),
      ('Omen count and combat effects', 'scripts/run_engine.gd', 'var extra_enemies: int = OmenRules.amount', 'Hunted adds one ordinary enemy after normal cap/placement, only combat rooms; specials/Guardians/dragons excluded. Active omens also affect initial block, Stoneskin, Expose, sight/Umbra, card plays, movement and fire; data/events.json /omens is authoritative.'),
      ('Extra-enemy placement bypass', 'scripts/room_generator.gd', 'func _add_omen_enemies', 'Additions sample legacy type pools and available floor, bypassing normal table caps. A five-unit normal plus Hunted becomes six; six becomes seven if space permits.'),
      ('Umbra stage and visibility progression', 'scripts/combat_engine.gd', 'const FIRST_SECTION_UMBRA_START_STEP', 'Section baseline advances through clear/fringe/advancing/pressing/deep/heart; s0 fringe begins at local step 2. Radii 99/6/5/4/3/2; eclipse radius 1. Omens, Light, relics, boss eclipse and room overrides modify effective visibility; normal shared section pressure is independent of roster count.'),
      ('Optional Umbra Depth difficulty', 'scripts/depth_rules.gd', 'static func enemy_hp', 'data/depths.json /levels: cumulative unlock mode independent of run section. Regular/Guardian/dragon Health percentages 110/110/108, damage flat bonuses 1/2/2; Guardian weight ×1.6; initiative −1, extra helper +1, Noctyrax Health ×1.25 and damage +2. Further changes cover sight, fatigue, starting Health/omen, healing and reward/economy. This measurement uses depth 0.'),
      ('Umbra Depth helper and Health application order', 'scripts/room_generator.gd', 'func _apply_umbra_depth', 'Apply optional Guardian helper before DepthRules.enemy_hp. Hoarder, Snare and Last Light configure after this pass, so their overrides matter. Spawned helper paths and summoned classification have separate DepthRules treatment.'),
      ('Summons and other mid-fight arrivals', 'scripts/combat_engine.gd', 'func _enemy_summon_minions', 'data/enemies.json intents summon count/minion_type/summon_cap, guardian_cap; _spawn_due_survival_reinforcements uses objective clock/pool; _trigger_enemy_death_spawn splits (data/enemies.json /<id>/death_spawn); Snare hunters and Snuff Shade arrivals have their own rules. These do not enter the starting-count distribution.'),
      ('Battlefield phases and modifiers', 'scripts/battlefield_rules/dispatcher.gd', 'static func data()', 'data/battlefield_rules.json /rules and /instances specify damage, range, cadence, duration, surfaces and half-Health phase replacements for boss/Guardian/Warband/Snare identities. The unchanged bot bypasses committed.accept’s half-Health checks; interpret results as relative policy measurements.'),
    ]
    return [(name, location(path,needle), description) for name,path,needle,description in rows]


def expanded_max(entry, table, element, biome, cap):
    options = []
    for unit in entry['units']:
        if unit == '$element':
            if element not in table['element_regulars']: return 0
            options.append([tuple((x,True) for x in table['element_regulars'][element])])
        elif unit == '$biome':
            options.append([tuple((x,True) for x in group['units']) for group in table['biome_groups'][biome]])
        else:
            options.append([((unit,False),)])
    maximum = 0
    for groups in product(*options):
        units = [unit for group in groups for unit in group]
        if sum(token for _,token in units) > cap: continue
        for index in range(len(units)-1,-1,-1):
            if len(units) <= cap: break
            if not units[index][1]: units.pop(index)
        maximum = max(maximum,len(units))
    return maximum


def crowded_catalog():
    table = json.loads((ROOT/'data/encounters.json').read_text())
    out = []
    for tier,entries in table['tiers'].items():
        for mode,legacy,extra in [
            ('current_k6plus',False,0), ('current_with_hunted',False,1),
            ('legacy_picker',True,0), ('legacy_picker_hunted',True,1),
            ('legacy_reach_exit',True,[1,2,2][int(tier)-1]),
            ('legacy_reach_exit_hunted',True,[1,2,2][int(tier)-1]+1),
        ]:
            cap = table['rules']['max_units'] if legacy else min(table['rules']['max_units'],table['rules']['tier_max_units'][tier],table['rules']['fight_max_units']['6'])
            for entry in entries:
                variants = []
                for element in ['none',*table['element_regulars']]:
                    for biome in table['biome_groups']:
                        base = expanded_max(entry,table,element,biome,cap)
                        n = base+extra if base else 0
                        if n > 5: variants.append(dict(element=element,biome=biome,max_count=n))
                if variants:
                    out.append(dict(source='data/encounters.json',tier=int(tier),id=entry['id'],
                                    mode=mode,max_count=max(v['max_count'] for v in variants),variants=variants))
    return out


def legacy_rosters():
    """Read the small authored literal pools; fail visibly if their syntax moves."""
    import ast
    import re
    source=(ROOT/'scripts/room_generator.gd').read_text().splitlines()
    start=next(i for i,line in enumerate(source) if line.startswith('func _base_encounter_enemy_type_pool'))
    end=next(i for i,line in enumerate(source[start+1:],start+1) if line.startswith('func _pick_boss_enemy_positions'))
    tier=None
    element='base'
    rows=[]
    collecting=False
    for line_number in range(start,end):
        line=source[line_number]
        match=re.fullmatch(r'\t\t(1|2|_):',line)
        if match:
            tier={'1':1,'2':2,'_':3}[match[1]]
            element='base'
        match=re.fullmatch(r'\t{4}ElementData\.(\w+):',line)
        if match: element=match[1].lower()
        if line.strip()=='pool = [': collecting=True; continue
        if collecting and line.strip()==']': collecting=False; continue
        literal=None
        if collecting and line.strip().startswith('['): literal=line.strip().rstrip(',')
        match=re.search(r'pool\.append\((\[.*\])\)',line)
        if match: literal=match[1]
        if literal:
            units=ast.literal_eval(literal)
            assert isinstance(units,list) and all(isinstance(x,str) for x in units)
            rows.append(dict(tier=tier,element=element,units=units,line=line_number+1))
    assert _roster_tier_counts(rows)=={1:12,2:8,3:9},'Authored legacy pool inventory changed; audit literal parsing'
    return rows


def _roster_tier_counts(rows):
    return {tier:sum(r['tier']==tier for r in rows) for tier in (1,2,3)}
