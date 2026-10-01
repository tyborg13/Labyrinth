"""Implementation definitions for every new or changed card in the card pool overhaul.

`pool_data.py` is the design record (rules text, verdicts). This module is the data contract:
exact `data/cards.json` entries. Each entry carries `_wave`, the earliest implementation wave
whose engine features it needs. `apply_pool.py` writes entries whose wave is enabled.

New data fields introduced by the overhaul (engine semantics are specified in
spec/card_pool_overhaul/mechanics.md):

Card level
  "empower":   {"cost": {"time": N} | {"health": N} | {"exhaust": true},
                "mods": [{"action": i, "add": {...}, "set": {...}}], "append": [action, ...]}
  "follow_up": {"mods": [...], "append": [...]}      # applies if a card was already played this turn
  "rite":      {"effects": [relic-style effect, ...]}  # card also has burn: true

Action level
  "stagger": N                                          # on attack actions
  "aim": "facing"                                       # aoe range 1: orientation = direction to target
  "state_bonus": [{"state": "light"|"frozen"|"half_hp", "damage": N, "stagger": N}]
  "scale_bonus": {"per": "stoneskin"|"tiles_moved", "damage": 1, "max": N}
  "on_result": {"when": "froze"|"killed", "rewards": [reward, ...]}
  "frozen_splash": N                                    # target Frozen before the hit -> N to its neighbors
  {"type": "retaliate", "amount": N, "bleed": n?, "shock": 1?, "push": n?}
  {"type": "quicken", "amount": N}
  {"type": "next_attack", "damage": n?, "pierce": bool?, "chain": n?, "element": e?, "per_tile_moved": {...}?}
  {"type": "outcrop", "range": R, "health": H, "pattern": [...]?, "rotate": bool?, "kind": k?}
  ... and the wave-4 families listed in mechanics.md.
"""

ADJ = [[0, -1], [1, 0], [0, 1], [-1, 0]]
DIAG = [[1, 1], [1, -1], [-1, 1], [-1, -1]]
RING8 = ADJ + DIAG
CROSS = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]
DIAMOND2 = CROSS + [[2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [1, -1], [-1, 1], [-1, -1]]
LINE2 = [[0, 0], [1, 0]]
LINE3 = [[0, 0], [1, 0], [2, 0]]
LINE4 = LINE3 + [[3, 0]]
LINE5 = LINE4 + [[4, 0]]
ARC3 = [[0, 0], [0, -1], [0, 1]]  # centered on the tile you face; with aim=facing this is the front arc

FIRE, ICE, LIGHTNING, AIR, EARTH = "fire", "ice", "lightning", "air", "earth"
ELEMENT_ACCENT = {FIRE: "#d9623f", ICE: "#5fa7d8", LIGHTNING: "#cfb347", AIR: "#72bea5", EARTH: "#89a15b"}
RARITY_ACCENT = {"common": "#8f9499", "rare": "#4b84d8", "epic": "#9b62d6", "legendary": "#d9862f"}
RADIANCE_ACCENT = "#e6c56c"

DEFS = {}


def card(cid, name, rarity, time, actions, desc, element=None, wave=1, radiance=False, burn=False,
         health_cost=0, flurry=False, reward_pool=None, item=False, **extra):
    entry = {"name": name}
    if element:
        entry["element"] = element
    entry.update({"rarity": rarity, "burn": burn, "health_cost": health_cost, "time": time,
                  "description": desc})
    if element:
        entry["accent"] = ELEMENT_ACCENT[element]
    elif radiance:
        entry["accent"] = RADIANCE_ACCENT
    else:
        entry["accent"] = RARITY_ACCENT[rarity]
    entry["art_path"] = f"res://assets/art/cards/{cid}.png"
    if radiance:
        entry["radiance"] = True
    if flurry:
        entry["flurry"] = True
    if item:
        entry.update({"item": True, "consume_on_play": True, "reward_pool": False,
                      "icon_path": f"res://assets/art/items/{cid}.png"})
    elif reward_pool is not None:
        entry["reward_pool"] = reward_pool
    entry.update(extra)
    entry["actions"] = actions
    entry["_wave"] = wave
    DEFS[cid] = entry


def gear(cid, name, rarity, time, actions, desc, element=None, wave=1, **kw):
    card(cid, name, rarity, time, actions, desc, element=element, wave=wave, reward_pool=False, **kw)


def mods(*items, append=None):
    out = {"mods": [m for m in items]}
    if append:
        out["append"] = append
    return out


def m(i, add=None, set=None):
    d = {"action": i}
    if add:
        d["add"] = add
    if set:
        d["set"] = set
    return d


def ranged(dmg, rng, el=None, **kw):
    a = {"type": "ranged", "damage": dmg, "range": rng, "element": el or "none"}
    a.update(kw)
    return a


def melee(dmg, rng=1, el=None, **kw):
    a = {"type": "melee", "damage": dmg, "range": rng, "element": el or "none"}
    a.update(kw)
    return a


def aoe(dmg, rng, pattern, el=None, rotate=False, **kw):
    a = {"type": "aoe", "damage": dmg, "range": rng, "pattern": pattern, "rotate": rotate, "element": el or "none"}
    a.update(kw)
    return a


def push(amount, dmg, rng, el=None, kind="push", **kw):
    a = {"type": kind, "damage": dmg, "range": rng, "amount": amount, "element": el or "none"}
    a.update(kw)
    return a


def pull(amount, dmg, rng, el=None, **kw):
    return push(amount, dmg, rng, el, kind="pull", **kw)


def act(t, **kw):
    a = {"type": t}
    a.update(kw)
    return a


def move(r, **kw):
    return act("move", range=r, **kw)


def blink(r, **kw):
    return act("blink", range=r, **kw)


def block(n, **kw):
    return act("block", amount=n, **kw)


def stoneskin(n, **kw):
    return act("stoneskin", amount=n, **kw)


def draw(n=1):
    return act("draw", amount=n)


def plays(n=1):
    return act("card_play", amount=n)


def surface(s, rng, pattern=None, rotate=False):
    a = {"type": "surface", "surface": s, "range": rng}
    if pattern:
        a["pattern"] = pattern
        a["rotate"] = rotate
    return a


# =============================================================================== starter spells
card("pale_spark", "Pale Spark", "common", 3, [ranged(3, 3)], "Deal 3 at range 3.", starter=True, reward_pool=False)
card("waning_pulse", "Waning Pulse", "common", 4, [aoe(3, 0, ADJ, push=1)],
     "Deal 3 to each adjacent enemy and push them 1.", starter=True, reward_pool=False)

# =============================================================================== FIRE
card("guiding_flare", "Guiding Flare", "common", 4,
     [ranged(3, 3, FIRE, surface="fire", illuminate_radius=2, illuminate_duration=2)],
     "Deal 3 at range 3, then leave Fire and radius-2 Light for 2 turns.", FIRE, radiance=True)
card("firebrand_volley", "Firebrand Volley", "common", 3, [ranged(4, 3, FIRE, surface="fire")],
     "Deal 4 at range 3, then leave Fire.", FIRE)
card("cinder_bloom", "Cinder Bloom", "common", 5, [aoe(2, 2, CROSS, FIRE, surface="fire")],
     "Deal 2 in a cross at range 2, then leave Fire in the pattern. Empower (Exhaust): the pattern becomes a radius-2 diamond.",
     FIRE, wave=2, empower={"cost": {"exhaust": True}, "mods": [m(0, set={"pattern": DIAMOND2})]})
card("cinderline_tempo", "Cinderline Tempo", "common", 3,
     [ranged(2, 2, FIRE), act("detonate", damage=6, range=0, pattern=[[0, 0]], rotate=False, target="previous_target", element="fire")],
     "Deal 2 at range 2, then Detonate 6 at the impact.", FIRE)
card("kindle", "Kindle", "common", 2, [surface("fire", 3), draw(1)], "Place Fire on a tile within range 3, then draw 1.", FIRE)
card("flame_jet", "Flame Jet", "common", 3,
     [aoe(4, 1, LINE3, FIRE, aim="facing", surface="fire", surface_pattern=[[2, 0]])],
     "Deal 4 to the first 3 tiles in a line from you, then leave Fire on the farthest tile.", FIRE)
card("scorch", "Scorch", "common", 4,
     [ranged(4, 3, FIRE, surface_bonus={"surface": "fire", "subject": "target", "present": True, "damage": 3})],
     "Deal 4 at range 3. Deal 3 more if the target stands on Fire.", FIRE)
card("stoke", "Stoke", "common", 4, [act("all_enemies", selector="on_fire", damage=3, element="fire")],
     "Each enemy you can see that stands on Fire takes 3.", FIRE, wave=4)
card("ember_ward", "Ember Ward", "common", 3, [block(5), act("surface_adjacent_enemies", surface="fire")],
     "Gain 5 Block, then leave Fire under each adjacent enemy.", FIRE, wave=4)
card("molten_reach", "Molten Reach", "rare", 5, [aoe(4, 2, LINE3, FIRE, rotate=True, surface="fire")],
     "Deal 4 along a three-tile line at range 2, then leave Fire along it.", FIRE)
card("flashsteam", "Flashsteam", "rare", 4,
     [aoe(3, 3, CROSS, FIRE, consume={"surface": "ice", "bonus_damage": 4})],
     "Deal 3 in a cross at range 3. Consume Ice there; enemies that stood on it take 4 more.", FIRE, wave=4)
card("magma_vent", "Magma Vent", "rare", 5,
     [act("detonate", damage=5, range=3, pattern=[[0, 0]], rotate=False, element="fire", detonate_surface="rubble",
          leave_surface="fire")],
     "Consume a Rubble tile within range 3 to deal 5 there and to its four neighbors, then leave Fire there.", FIRE, wave=4)
card("cinder_wall", "Cinder Wall", "rare", 4, [surface("fire", 2, LINE4, rotate=True), block(4)],
     "Leave Fire on a four-tile line within range 2, then gain 4 Block.", FIRE)
card("immolation", "Immolation", "epic", 4,
     [act("detonate", damage=8, range=0, pattern=[[0, 0]] + ADJ, rotate=False, element="fire", spare_player=True)],
     "Detonate 8 on every Fire tile within 1 of you, including yours. You take no damage from it. Empower (2 HP): within 2 instead.",
     FIRE, wave=4, empower={"cost": {"health": 2}, "mods": [m(0, set={"pattern": [[0, 0]] + ADJ + DIAG + [[2, 0], [-2, 0], [0, 2], [0, -2]]})]})
card("pyroclasm", "Pyroclasm", "epic", 7,
     [ranged(9, 3, FIRE, consume={"surface": "fire", "bonus_damage": 6})],
     "Deal 9 at range 3. If the target stands on Fire, consume it and deal 6 more.", FIRE, wave=4)
card("rite_of_the_pyre", "Rite of the Pyre", "epic", 4, [],
     "Rite: your Fire tiles deal 2 more damage.", FIRE, wave=3, burn=True,
     rite={"effects": [{"type": "surface_damage_bonus", "surface": "fire", "amount": 2, "owner": "player"}]})
card("meteorfall", "Meteorfall", "epic", 7,
     [act("meteor_marks", range=4, pattern=LINE3, rotate=True, damage=8, surface="fire", element="fire")],
     "Mark a three-tile line within range 4. At the start of your next turn, each marked tile takes 8 and becomes Fire.", FIRE, wave=4)
card("salamander_heart", "Salamander Heart", "legendary", 6, [],
     "Rite: you ignore Fire damage. At the start of your turn, if you stand on Fire, gain 3 Stoneskin and draw 1.", FIRE,
     wave=3, burn=True,
     rite={"effects": [{"type": "surface_immunity", "surface": "fire"},
                       {"type": "turn_start_on_surface", "surface": "fire",
                        "rewards": [{"type": "stoneskin", "amount": 3}, {"type": "draw", "amount": 1}]}]})

# =============================================================================== ICE
card("frost_lane", "Frost Lane", "common", 3, [surface("ice", 3, LINE3, rotate=True), draw(1)],
     "Leave Ice on a three-tile line within range 3, then draw 1.", ICE)
card("skate", "Skate", "common", 2, [act("self_flag", flag="ice_skate"), move(3)],
     "Move 3. This turn, Ice costs you no movement and doesn't Chill you.", ICE, wave=4)
card("shiver_shot", "Shiver Shot", "common", 2, [ranged(2, 4, ICE)], "Deal 2 Ice damage at range 4.", ICE)
card("hoarfrost_ward", "Hoarfrost Ward", "common", 3, [block(5), act("surface_adjacent_enemies", surface="ice")],
     "Gain 5 Block, then leave Ice under each adjacent enemy.", ICE, wave=4)
card("rimefang", "Rimefang", "common", 4, [ranged(4, 2, ICE)],
     "Deal 4 Ice damage at range 2. Follow-up: deal 3 more and leave Ice.", ICE, wave=2,
     follow_up=mods(m(0, add={"damage": 3}, set={"surface": "ice"})))
card("hush_of_winter", "Hush of Winter", "rare", 5,
     [ranged(5, 4, ICE, on_result={"when": "froze", "rewards": [{"type": "draw", "amount": 2}]})],
     "Deal 5 Ice damage at range 4. If this Freezes the target, draw 2.", ICE, wave=4)
card("shatterline", "Shatterline", "rare", 6, [aoe(5, 2, LINE3, ICE, rotate=True, pierce=True)],
     "Pierce a three-tile line for 5 Ice damage at range 2. Empower (+2 Time): the line is five tiles.", ICE, wave=2,
     empower={"cost": {"time": 2}, "mods": [m(0, set={"pattern": LINE5})]})
card("frost_circuit", "Frost Circuit", "rare", 3,
     [act("convert_surface", range=3, surface="ice", to="electrified", connected=True, damage=2, element="lightning", shock=1)],
     "Turn an Ice tile within range 3 and all Ice connected to it into Electrified. Deal 2 Lightning damage to each enemy on them and Shock them.",
     ICE, wave=4)
card("sleet_squall", "Sleet Squall", "rare", 5,
     [push(2, 0, 3, ICE), ranged(3, 3, ICE, target="previous_target")],
     "Push 2 at range 3, then deal 3 Ice damage to the target.", ICE, wave=4)
card("ice_sculpture", "Ice Sculpture", "rare", 5, [act("illusion", health=4, range=3, surface_ring="ice")],
     "Create a 4-health illusion within range 3, then leave Ice on each empty tile next to it.", ICE, wave=4)
card("frost_nova", "Frost Nova", "epic", 6, [aoe(4, 0, ADJ, ICE), surface("ice", 0, RING8)],
     "Deal 4 Ice damage to each adjacent enemy, then leave Ice on all eight tiles around you.", ICE)
card("shatter", "Shatter", "epic", 5, [ranged(5, 3, ICE, frozen_splash=5)],
     "Deal 5 Ice damage at range 3. If the target was Frozen, also deal 5 to each enemy next to it.", ICE, wave=4)
card("rite_of_hoarfrost", "Rite of Hoarfrost", "epic", 4, [],
     "Rite: whenever you Freeze an enemy, gain 3 Block and draw 1.", ICE, wave=3, burn=True,
     rite={"effects": [{"type": "status_applied_reward", "status": "freeze",
                        "rewards": [{"type": "block", "amount": 3}, {"type": "draw", "amount": 1}]}]})
card("white_silence", "White Silence", "legendary", 8, [act("all_enemies", selector="chilled", damage=4, element="ice")],
     "Deal 4 Ice damage to each Chilled enemy you can see. (This Freezes them.)", ICE, wave=4)
card("crystal_mantle", "Crystal Mantle", "legendary", 5, [act("mantle", amount=3)],
     "Exhaust. Gain 3 Mantle: each direct hit against you breaks one Mantle instead of dealing damage.", ICE, wave=4, burn=True)

# =============================================================================== LIGHTNING
card("chain_bolt", "Chain Bolt", "common", 4, [ranged(4, 3, LIGHTNING, chain=2)],
     "Deal 4 Lightning damage with Chain 2 at range 3. Empower (+2 Time): Chain 4.", LIGHTNING, wave=2,
     empower={"cost": {"time": 2}, "mods": [m(0, set={"chain": 4})]})
card("static_lash", "Static Lash", "common", 4,
     [ranged(4, 3, LIGHTNING, surface_bonus={"surface": "electrified", "subject": "conducted", "shock": 1})],
     "Deal 4 Lightning damage at range 3. Electrified-assisted hits also Shock.", LIGHTNING)
card("jolt", "Jolt", "common", 1, [ranged(2, 3, LIGHTNING)], "Deal 2 Lightning damage at range 3.", LIGHTNING)
card("static_rush", "Static Rush", "common", 2, [move(2), act("quicken", amount=2)],
     "Move 2. Quicken 2: your next card this turn costs 2 less Time.", LIGHTNING, wave=3)
card("capacitor", "Capacitor", "common", 2, [block(4), act("next_attack", element="lightning", chain=2)],
     "Gain 4 Block. Your next Lightning attack this turn gains Chain 2.", LIGHTNING, wave=3)
card("static_ward", "Static Ward", "common", 3,
     [block(5), act("surface_adjacent_enemies", surface="electrified", include_self=True)],
     "Gain 5 Block, then Electrify your tile and the tile of each adjacent enemy.", LIGHTNING, wave=4)
card("arc_flash", "Arc Flash", "common", 3, [ranged(3, 3, LIGHTNING)],
     "Deal 3 Lightning damage at range 3. Follow-up: Chain 2.", LIGHTNING, wave=2,
     follow_up=mods(m(0, set={"chain": 2})))
card("storm_relay", "Storm Relay", "rare", 6,
     [ranged(5, 3, LIGHTNING, chain=2, surface_bonus={"surface": "electrified", "subject": "conducted", "shock": 1})],
     "Deal 5 Lightning damage with Chain 2 at range 3. Electrified-assisted hits also Shock.", LIGHTNING)
card("overclock", "Overclock", "rare", 3, [draw(1), plays(1)],
     "Draw 1 and gain 1 card play. Empower (1 HP): draw 2 instead.", LIGHTNING, wave=2,
     empower={"cost": {"health": 1}, "mods": [m(0, set={"amount": 2})]})
card("plasma_arc", "Plasma Arc", "rare", 4,
     [ranged(3, 3, LIGHTNING, chain=2, consume={"surface": "fire", "bonus_damage": 4, "per_hit": True})],
     "Deal 3 Lightning damage with Chain 2 at range 3. Enemies hit on Fire take 4 more and the Fire is consumed.", LIGHTNING, wave=4)
card("thunderclap", "Thunderclap", "rare", 4, [aoe(3, 0, ADJ, LIGHTNING, push=1), surface("electrified", 0)],
     "Deal 3 Lightning damage to each adjacent enemy and push them 1, then Electrify your tile.", LIGHTNING)
card("thunderline", "Thunderline", "epic", 7,
     [aoe(6, 2, LINE3, LIGHTNING, rotate=True, chain=1, surface_bonus={"surface": "electrified", "subject": "conducted", "shock": 1})],
     "Deal 6 Lightning damage along a three-tile line at range 2 with Chain 1. Electrified-assisted hits also Shock.", LIGHTNING)
card("discharge", "Discharge", "epic", 4, [act("discharge", range=4, damage=5, element="lightning")],
     "Choose an Electrified tile within range 4. Deal 5 Lightning damage to each enemy on or next to its connected network, then remove the network.",
     LIGHTNING, wave=4)
card("ball_lightning", "Ball Lightning", "epic", 4,
     [act("illusion", health=3, range=3, surface="electrified", on_damaged={"damage": 4, "element": "lightning", "shock": 1})],
     "Create a 3-health illusion within range 3 and Electrify its tile. Enemies that damage it take 4 Lightning damage and are Shocked.",
     LIGHTNING, wave=4)
card("rite_of_the_storm", "Rite of the Storm", "epic", 5, [],
     "Rite: at the start of each of your turns, deal 2 Lightning damage to each enemy standing on Electrified.", LIGHTNING,
     wave=3, burn=True,
     rite={"effects": [{"type": "turn_start_surface_pulse", "surface": "electrified", "damage": 2, "element": "lightning"}]})
card("tempest_form", "Tempest Form", "legendary", 5, [],
     "Rite: your cards cost 1 less Time (minimum 1).", LIGHTNING, wave=3, burn=True,
     rite={"effects": [{"type": "card_time_discount", "amount": 1}]})
card("skybolt", "Skybolt", "legendary", 7,
     [ranged(7, 99, LIGHTNING, ignore_los=True, shock=1, shock_all_hits=True)],
     "Deal 7 Lightning damage to any enemy you can see, ignoring range and line of sight. It conducts; everything it hits is Shocked.",
     LIGHTNING, wave=4)

# =============================================================================== AIR
card("updraft", "Updraft", "common", 4, [push(2, 3, 3, AIR)], "Push 2 at range 3 for 3 damage.", AIR)
card("buffet", "Buffet", "common", 2, [push(1, 2, 2, AIR)], "Push 1 at range 2 for 2 damage.", AIR)
card("crosswind", "Crosswind", "common", 3, [push(2, 3, 3, AIR, _allow_sideways_force=True)],
     "Deal 3 at range 3 and push 2 in any direction.", AIR)
card("hurricane_palm", "Hurricane Palm", "common", 4, [push(3, 3, 1, AIR)], "Strike an adjacent enemy for 3 and push 3.", AIR)
card("gale_ward", "Gale Ward", "common", 3, [block(5), act("force_area", center="self", radius=1, push=1)],
     "Gain 5 Block, then push each adjacent enemy 1.", AIR, wave=4, role_emblem="block")
card("wind_shear", "Wind Shear", "common", 5, [aoe(3, 2, LINE3, AIR, rotate=True, push=1)],
     "Deal 3 along a three-tile line at range 2 and push each target 1 away from you. Empower (+2 Time): push 2 instead.", AIR,
     wave=2, empower={"cost": {"time": 2}, "mods": [m(0, set={"push": 2})]})
card("vacuum_line", "Vacuum Line", "rare", 6, [pull(3, 6, 3, AIR), draw(1)], "Pull 3 at range 3 for 6 damage, then draw 1.", AIR)
card("squall_shot", "Squall", "rare", 5, [aoe(2, 3, CROSS, AIR, push=1, force_mode="from_center")],
     "Deal 2 in a cross at range 3 and push each enemy in it 1 away from the center. The enemy on the center is pushed away from you.",
     AIR, wave=4)
card("changing_winds", "Changing Winds", "rare", 3, [act("swap", range=3, targets=["enemy", "illusion"])],
     "Swap places with a one-tile enemy or one of your illusions within range 3.", AIR, wave=4)
card("fan_the_flames", "Fan the Flames", "rare", 4, [push(2, 2, 3, AIR, trail_surface="fire")],
     "Push 2 at range 3 for 2 damage. Leave Fire on each tile the target passes through.", AIR, wave=4)
card("dust_devil", "Dust Devil", "rare", 4,
     [act("force_area", center="target", range=3, radius=1, push=2, expose=2, consume_center="rubble")],
     "Consume a Rubble tile within range 3. Push each enemy next to it 2 away and Expose 2.", AIR, wave=4)
card("kestrel_dive", "Kestrel Dive", "rare", 4, [blink(3), push(1, 5, 1, AIR, required=True)],
     "Blink 3, then strike an adjacent enemy for 5 and push 1.", AIR)
card("vortex", "Vortex", "epic", 5, [act("force_area", center="target", range=3, radius=2, pull=2)],
     "Choose a tile within range 3. Pull each enemy within 2 of it 2 tiles toward it.", AIR, wave=4)
card("eye_of_the_storm", "Eye of the Storm", "epic", 5, [block(6), act("retaliate", amount=0, push=2)],
     "Gain 6 Block. Until your next turn, enemies that hit you in melee are pushed 2.", AIR, wave=3)
card("rite_of_tailwinds", "Rite of Tailwinds", "epic", 3, [],
     "Rite: gain 1 extra independent movement each turn. Your Push and Pull move targets 1 tile farther.", AIR, wave=3, burn=True,
     rite={"effects": [{"type": "independent_movement_bonus", "amount": 1},
                       {"type": "forced_movement_bonus", "amount": 1}]})
card("skybreak_current", "Skybreak Current", "legendary", 7, [push(5, 4, 4, AIR)],
     "Push 5 at range 4 for 4 damage.", AIR)
card("cyclone_seal", "Cyclone Seal", "legendary", 7,
     [act("force_area", center="target", range=3, radius=3, pull=3),
      aoe(6, 0, ADJ, AIR, target="previous_target")],
     "Exhaust. Choose a tile within range 3. Pull every enemy within 3 of it up to 3 tiles toward it, then deal 6 to each enemy next to it.",
     AIR, wave=4, burn=True)

# =============================================================================== EARTH
card("root_snare", "Root Snare", "common", 4, [ranged(1, 3, EARTH, immobilize=True, surface="rubble")],
     "Deal 1 at range 3 and immobilize, then leave Rubble.", EARTH)
card("raise_stone", "Raise Stone", "common", 2, [act("outcrop", range=3, health=3), draw(1)],
     "Raise a 3-health outcrop on an empty tile within range 3, then draw 1.", EARTH)
card("stone_ward", "Stone Ward", "common", 3, [block(5), act("surface_adjacent_enemies", surface="rubble")],
     "Gain 5 Block, then leave Rubble under each adjacent enemy.", EARTH, wave=4)
card("rockburst", "Rockburst", "common", 4, [act("burst_terrain", range=3, damage=6, surface="rubble", surface_pattern=CROSS)],
     "Destroy an outcrop or crate within range 3 to deal 6 to each enemy next to it, then leave Rubble in a cross there.", EARTH, wave=4)
card("tremor", "Tremor", "common", 5, [aoe(3, 0, DIAMOND2, EARTH, stagger=2)],
     "Deal 3 to each enemy within 2 tiles of you and Stagger 2. Empower (+2 Time): Stagger 4.", EARTH, wave=2,
     empower={"cost": {"time": 2}, "mods": [m(0, set={"stagger": 4})]})
card("rooted_stance", "Rooted Stance", "common", 3, [stoneskin(6), act("self_flag", flag="no_move")],
     "Gain 6 Stoneskin. You can't Move, Blink or Swap for the rest of this turn.", EARTH, wave=4)
card("earthen_rampart", "Earthen Rampart", "rare", 5, [act("outcrop", range=2, health=3, pattern=LINE3, rotate=True), stoneskin(3)],
     "Raise outcrops on a three-tile line within range 2, then gain 3 Stoneskin. Empower (Exhaust): the line is five tiles.", EARTH,
     wave=2, empower={"cost": {"exhaust": True}, "mods": [m(0, set={"pattern": LINE5})]})
card("stonefist", "Stonefist", "rare", 4, [melee(5, 1, EARTH, scale_bonus={"per": "stoneskin", "damage": 1, "max": 6})],
     "Strike for 5, plus 1 for each Stoneskin you have (maximum 6 more).", EARTH, wave=2)
card("frost_heave", "Frost Heave", "rare", 4,
     [ranged(6, 3, EARTH, immobilize=True, surface="rubble", consume={"surface": "ice", "required": True})],
     "Consume the Ice under an enemy within range 3 to deal 6 to it, immobilize it, and leave Rubble.", EARTH, wave=4)
card("grounding", "Grounding", "rare", 3,
     [act("consume_surface", surface="electrified", target="player", pattern=DIAMOND2, min_consumed=1,
          rewards=[{"type": "stoneskin", "amount": 2, "per_tile": True, "max": 8}])],
     "Remove every Electrified tile within 2 of you. Gain 2 Stoneskin per tile removed (maximum 8).", EARTH, wave=4)
card("petrify", "Petrify", "epic", 5, [act("petrify", range=3, block=5)],
     "An enemy within range 3 (not a dragon) skips its next turn and gains 5 Block.", EARTH, wave=4)
card("rite_of_the_mountain", "Rite of the Mountain", "epic", 5, [],
     "Rite: at the start of each of your turns, gain 3 Stoneskin.", EARTH, wave=3, burn=True,
     rite={"effects": [{"type": "turn_start_reward", "rewards": [{"type": "stoneskin", "amount": 3}]}]})
card("tectonic_maul", "Tectonic Maul", "legendary", 8,
     [move(1), melee(11, 1, EARTH, required=True, surface="rubble", surface_pattern=CROSS, stagger=3,
                     surface_bonus={"surface": "rubble", "subject": "target", "present": True, "damage": 4})],
     "Move 1, then strike for 11, or 15 against a target on Rubble. Leave a cross of Rubble at the impact and Stagger 3.", EARTH, wave=2)
card("worldspine", "Worldspine", "legendary", 7,
     [act("outcrop", range=3, health=4, pattern=ADJ, around_target=True, kind="worldspine", pulse_damage=3)],
     "Exhaust. Raise a 4-health Worldspine on each empty tile next to a tile within range 3. At the start of each of your turns, each enemy next to a Worldspine takes 3.",
     EARTH, wave=4, burn=True)

# =============================================================================== RADIANCE
card("sunlance", "Sunlance", "common", 4, [ranged(4, 4, state_bonus=[{"state": "light", "damage": 3}])],
     "Deal 4 at range 4. Deal 3 more if the target stands in Light.", radiance=True, wave=2)
card("beacon", "Beacon", "common", 2, [act("illuminate", range=4, radius=2, duration=3), draw(1)],
     "Create radius-2 Light within range 4 for 3 turns, then draw 1.", radiance=True)
card("mirror_image", "Mirror Image", "common", 3, [act("illusion", health=3, range=3), draw(1)],
     "Create a 3-health illusion within range 3, then draw 1. Empower (+2 Time): 5 health instead.", radiance=True, wave=2,
     empower={"cost": {"time": 2}, "mods": [m(0, set={"health": 5})]})
card("dazzle", "Dazzle", "common", 3, [ranged(2, 3, state_bonus=[{"state": "light", "stagger": 3}])],
     "Deal 2 at range 3. If the target stands in Light, Stagger 3.", radiance=True, wave=2)
card("seekers_mark", "Seeker's Mark", "common", 2, [act("truesight", duration=2), draw(1)],
     "Gain Truesight for 2 turns, then draw 1.", radiance=True)
card("revealing_glare", "Revealing Glare", "rare", 3, [act("all_enemies", selector="in_light", range=4, damage=0, expose=3), draw(1)],
     "Each enemy in Light within range 4 is Exposed 3. Draw 1.", radiance=True, wave=4)
card("refraction", "Refraction", "rare", 4, [ranged(4, 3, also_hits_near_illusions=True)],
     "Deal 4 at range 3. It also hits each enemy next to one of your illusions.", radiance=True, wave=4)
card("shattered_reflection", "Shattered Reflection", "rare", 3,
     [act("destroy_illusion", range=6, damage=6, illuminate_radius=2, illuminate_duration=2)],
     "Destroy one of your illusions within range 6 to deal 6 to each enemy next to it and create radius-2 Light there for 2 turns.",
     radiance=True, wave=4)
card("break_the_veil", "Break the Veil", "rare", 3, [act("dispel_umbra", amount=1), draw(1)],
     "Exhaust. Reduce the Umbra by 1 stage, then draw 1.", radiance=True, burn=True)
card("hall_of_mirrors", "Hall of Mirrors", "epic", 6, [act("illusion", health=2, range=0, place="ring_around_self"), block(3)],
     "Create a 2-health illusion on each empty tile next to you, then gain 3 Block.", radiance=True, wave=4,
     role_emblem="illusion")
card("searing_light", "Searing Light", "epic", 5, [act("all_enemies", selector="in_light", damage=3)],
     "Deal 3 to each enemy standing in Light.", radiance=True, wave=4)
card("rite_of_noon", "Rite of Noon", "epic", 5, [],
     "Rite: you radiate radius-2 Light, and your attacks deal 2 more to enemies in Light.", radiance=True, wave=3, burn=True,
     rite={"effects": [{"type": "player_light_aura", "radius": 2},
                       {"type": "target_state_action_mod", "conditions": {"target_in_light": True}, "add": {"damage": 2}}]})
card("doppelganger", "Doppelganger", "legendary", 5, [act("illusion", health=5, range=3, ranged_origin=True)],
     "Create a 5-health illusion within range 3. While it lives, you may fire ranged attacks from its tile.", radiance=True, wave=4)

# =============================================================================== GEAR: weapons
gear("quick_stab", "Quick Stab", "common", 2, [melee(6)], "Strike an adjacent enemy for 6. Follow-up: deal 3 more.",
     wave=2, starter=True, follow_up=mods(m(0, add={"damage": 3})))
gear("bloody_lunge", "Bloody Lunge", "common", 6, [move(2), melee(9, required=True)],
     "Move 2, then strike for 9. Empower (1 HP): deal 4 more.", wave=2, starter=True,
     empower={"cost": {"health": 1}, "mods": [m(1, add={"damage": 4})]})
gear("cleaver_hook", "Cleaver Hack", "common", 3, [melee(5, sunder=4)], "Strike an adjacent enemy for 5 and Sunder 4.")
gear("needle_flurry", "Cleaver Sweep", "common", 4, [aoe(5, 1, ARC3, aim="facing")],
     "Strike the three tiles in an arc in front of you for 5.")
gear("butcher_chop", "Butcher Chop", "common", 5, [melee(10, state_bonus=[{"state": "half_hp", "damage": 5}])],
     "Strike an adjacent enemy for 10, or 15 if it is at or below half health.", wave=2)
gear("riposte_lunge", "Riposte Lunge", "rare", 4, [move(2), melee(5, required=True), act("retaliate", amount=4)],
     "Move 2, then strike for 5. Retaliate 4 until your next turn.", wave=3)
gear("battle_rhythm", "Parry Rhythm", "rare", 3, [block(4), act("retaliate", amount=3), draw(1)],
     "Gain 4 Block and Retaliate 3, then draw 1.", wave=3)
gear("bodkin_arrow", "Needle Thrust", "rare", 3, [melee(5, pierce=True)],
     "Pierce an adjacent enemy for 5. Follow-up: deal 4 more.", wave=2, follow_up=mods(m(0, add={"damage": 4})))
gear("grave_cleave", "Grave Cleave", "epic", 6, [aoe(7, 1, ARC3, aim="facing", expose=3)],
     "Strike the three tiles in an arc in front of you for 7 and Expose 3.")
gear("blood_price", "Blood Price", "epic", 6, [melee(12)],
     "Strike an adjacent enemy for 12. Empower (2 HP): deal 8 more and Pierce.", wave=2,
     empower={"cost": {"health": 2}, "mods": [m(0, add={"damage": 8}, set={"pierce": True})]})
gear("tombsplitter", "Tombsplitter", "epic", 8, [aoe(12, 1, LINE2, aim="facing", stagger=3)],
     "Strike the first two tiles in a line from you for 12 and Stagger 3.", wave=2)
gear("sawtooth_flurry", "Sawtooth Flurry", "common", 3, [melee(3, bleed=1)],
     "Flurry. Strike for 3 and Bleed 1 for each card play spent.", flurry=True)
gear("stormstring_shot", "Stormstring Shot", "rare", 4, [ranged(4, 4, LIGHTNING, chain=1, surface="electrified")],
     "Deal 4 Lightning damage with Chain 1 at range 4, then leave Electrified at the impact.", LIGHTNING)
gear("forked_nock", "Forked Nock", "rare", 5, [ranged(3, 3, LIGHTNING, chain=2, expose=2)],
     "Deal 3 Lightning damage with Chain 2 at range 3 and Expose 2.", LIGHTNING)
gear("sweeping_haft", "Sweeping Haft", "epic", 4, [aoe(6, 0, DIAG, sunder=3)],
     "Strike the four diagonal tiles for 6 and Sunder 3.")
gear("pinning_quarrel", "Pinning Quarrel", "rare", 5, [ranged(4, 4, immobilize=True)], "Deal 4 at range 4 and immobilize.")
gear("crushing_blow", "Crushing Blow", "common", 5, [melee(8, stagger=3)], "Strike an adjacent enemy for 8 and Stagger 3.", wave=2)
gear("haft_shove", "Haft Shove", "common", 3, [push(2, 2, 1)], "Strike an adjacent enemy for 2 and push 2.")
gear("overhead_smash", "Overhead Smash", "common", 7, [melee(12)],
     "Strike an adjacent enemy for 12. Empower (+2 Time): Stagger 4.", wave=2,
     empower={"cost": {"time": 2}, "mods": [m(0, set={"stagger": 4})]})
gear("spear_thrust", "Spear Thrust", "common", 4, [aoe(6, 1, LINE2, aim="facing")],
     "Strike the first two tiles in a line from you for 6.")
gear("brace_the_spear", "Brace the Spear", "common", 3, [block(3), act("retaliate", amount=5)],
     "Gain 3 Block and Retaliate 5 until your next turn.", wave=3)
gear("hurl_spear", "Hurl Spear", "common", 5, [ranged(6, 4)],
     "Deal 6 at range 4. Empower (Exhaust): deal 4 more and immobilize.", wave=2,
     empower={"cost": {"exhaust": True}, "mods": [m(0, add={"damage": 4}, set={"immobilize": True})]})
gear("ricochet_knife", "Ricochet Knife", "common", 3, [ranged(5, 2), draw(1)], "Deal 5 at range 2, then draw 1.")
gear("fan_of_knives", "Fan of Knives", "common", 4, [aoe(3, 2, LINE3, rotate=True)], "Deal 3 along a three-tile line at range 2.")
gear("palm_blade", "Palm Blade", "common", 2, [melee(4)], "Strike an adjacent enemy for 4. Follow-up: draw 1.", wave=2,
     follow_up=mods(append=[draw(1)]))
gear("censer_swing", "Censer Swing", "rare", 5,
     [aoe(5, 0, ADJ), act("illuminate", range=0, radius=2, duration=2)],
     "Strike all adjacent tiles for 5, then create radius-2 Light on yourself for 2 turns.", radiance=True)
gear("hallowed_strike", "Hallowed Strike", "rare", 4, [melee(6, state_bonus=[{"state": "light", "damage": 4}])],
     "Strike an adjacent enemy for 6, or 10 if it stands in Light.", wave=2, radiance=True)
gear("incense_haze", "Incense Haze", "rare", 3, [act("truesight", duration=2), block(3)],
     "Gain Truesight for 2 turns and 3 Block.", radiance=True)
gear("couched_lance", "Couched Lance", "rare", 4, [melee(4, 2, scale_bonus={"per": "tiles_moved", "damage": 1, "max": 5})],
     "Strike at reach 2 for 4, plus 1 for each tile you moved this turn (maximum 5 more).", wave=2)
gear("joust", "Joust", "rare", 5, [move(4, straight_line=True), melee(6, required=True)],
     "Move up to 4 in a straight line, then strike for 6.", wave=4)
gear("unhorse", "Unhorse", "rare", 4, [push(2, 5, 1)], "Strike an adjacent enemy for 5 and push 2.")
gear("rime_hack", "Rime Hack", "epic", 4, [melee(5, 1, ICE, surface="ice")], "Strike for 5 Ice damage, then leave Ice beneath the target.", ICE)
gear("frozen_bite", "Frozen Bite", "epic", 3,
     [melee(4, 1, ICE, on_result={"when": "froze", "rewards": [{"type": "card_play", "amount": 1}]})],
     "Strike for 4 Ice damage. If this Freezes the target, gain 1 card play.", ICE, wave=4)
gear("shatter_swing", "Shatter Swing", "epic", 5, [melee(8, 1, ICE, frozen_splash=4)],
     "Strike for 8 Ice damage. If the target is Frozen, also deal 4 to each enemy next to it.", ICE, wave=4)
gear("lash", "Lash", "rare", 3, [pull(1, 4, 3, AIR)], "Lash an enemy at reach 3 for 4 and pull 1.", AIR)
gear("crack_the_whip", "Crack the Whip", "rare", 3, [melee(3, 3, AIR, stagger=2)], "Strike at reach 3 for 3 and Stagger 2.", AIR, wave=2)
gear("snare_coil", "Snare Coil", "rare", 5, [pull(3, 2, 3, immobilize=True)], "Pull 3 at range 3 for 2, then immobilize.")
gear("fault_strike", "Fault Strike", "legendary", 6, [melee(11, 1, EARTH, surface="rubble", surface_pattern=[[0, 0], [1, 0], [2, 0]], surface_follows_facing=True)],
     "Strike for 11, then leave Rubble on the target's tile and the two tiles behind it.", EARTH, wave=4)
gear("raise_the_anvil", "Raise the Anvil", "legendary", 3, [act("outcrop", range=1, health=3), stoneskin(4)],
     "Raise an outcrop next to you, then gain 4 Stoneskin.", EARTH)
gear("worldbreak", "Worldbreak", "legendary", 6, [act("burst_terrain", range=1, owned_outcrop_only=True, line_damage=10, line_length=3, stagger=2)],
     "Destroy an adjacent outcrop you raised to deal 10 to each enemy in the three-tile line beyond it and Stagger 2.", EARTH, wave=4)

# =============================================================================== GEAR: offhands
gear("brace", "Brace", "common", 1, [block(6)], "Gain 6 Block.", starter=True)
gear("kite_bash", "Kite Bash", "common", 4, [block(6), push(1, 3, 1)], "Gain 6 Block, then bash an adjacent enemy for 3 and push 1.")
gear("mirror_feint", "Mirror Feint", "epic", 4, [act("illusion", health=3, range=3, place="adjacent_to_enemy", expose_adjacent=3)],
     "Create a 3-health illusion next to an enemy within range 3. That enemy is Exposed 3.", wave=4, role_emblem=None)
gear("spike_check", "Spike Check", "common", 3, [block(5), act("retaliate", amount=3)], "Gain 5 Block and Retaliate 3.", wave=3)
gear("reflected_threat", "Reflected Threat", "epic", 5, [act("illusion", health=4, range=3, reflect=True)],
     "Create a 4-health illusion within range 3. Enemies that damage it take that much damage too.", wave=4, role_emblem=None)
gear("anchor_slam", "Anchor Slam", "legendary", 7, [stoneskin(3), pull(2, 5, 3, sunder=4, immobilize=True)],
     "Gain 3 Stoneskin, then pull 2 at range 3 for 5, Sunder 4, and immobilize.")
gear("shield_wall", "Shield Wall", "rare", 3, [block(9), act("self_flag", flag="no_move")],
     "Gain 9 Block. You can't Move, Blink or Swap for the rest of this turn.", wave=4)
gear("shield_charge", "Shield Charge", "rare", 4, [move(2), push(2, 3, 1, required=True)],
     "Move 2, then bash an adjacent enemy for 3 and push 2.")
gear("deflect", "Deflect", "common", 2, [block(3), act("retaliate", amount=4)], "Gain 3 Block and Retaliate 4.", wave=3)
gear("main_gauche", "Main-Gauche", "common", 2, [melee(3)], "Strike an adjacent enemy for 3. Follow-up: deal 3 more and draw 1.",
     wave=2, follow_up=mods(m(0, add={"damage": 3}), append=[draw(1)]))
gear("sun_flash", "Sun Flash", "rare", 3, [block(5), act("illuminate", range=0, radius=2, duration=2)],
     "Gain 5 Block, then create radius-2 Light on yourself for 2 turns.", radiance=True)
gear("blinding_bash", "Blinding Bash", "rare", 3, [melee(4, state_bonus=[{"state": "light", "stagger": 3}])],
     "Bash an adjacent enemy for 4. If it stands in Light, Stagger 3.", wave=2, radiance=True)
gear("hoarfrost_wall", "Hoarfrost Wall", "epic", 4, [block(6), surface("ice", 0, ADJ)],
     "Gain 6 Block, then leave Ice on each tile next to you.", ICE)
gear("cold_shoulder", "Cold Shoulder", "epic", 3, [push(1, 4, 1, ICE)], "Bash an adjacent enemy for 4 Ice damage and push 1.", ICE)
gear("plant_pavise", "Plant Pavise", "rare", 4, [act("outcrop", range=1, health=3), block(5)],
     "Raise an outcrop next to you, then gain 5 Block.", EARTH)
gear("stonewall_stance", "Stonewall Stance", "rare", 3, [stoneskin(4)], "Gain 4 Stoneskin. Follow-up: gain 3 more.", EARTH, wave=2,
     follow_up=mods(m(0, add={"amount": 3})))
gear("grapple", "Grapple", "common", 3, [blink(4, destination_adjacent_to=["enemy", "terrain"])],
     "Blink to a tile next to an enemy, outcrop or crate within range 4.", wave=4)
gear("yank", "Yank", "common", 4, [pull(3, 2, 4)], "Pull 3 at range 4 for 2.")

# =============================================================================== GEAR: armor
gear("glassbone_guard", "Glassbone Guard", "rare", 4, [stoneskin(6), draw(1)], "Lose 1 health. Gain 6 Stoneskin, then draw 1.", health_cost=1)
gear("undertaker_stand", "Undertaker Stand", "epic", 6, [block(8), act("retaliate", amount=5)],
     "Gain 8 Block and Retaliate 5.", wave=3)
gear("threadbare_guard", "Unpick", "common", 2, [act("cleanse", statuses=["bleed", "immobilize", "chilled"]), block(4), draw(1)],
     "Remove Bleed, Immobilize and Chilled from yourself, gain 4 Block, then draw 1.", wave=4)
gear("voidsilk_molt", "Voidsilk Molt", "legendary", 4, [blink(3, illusion_at_origin=4), draw(1)],
     "Blink 3, leaving a 4-health illusion where you stood, then draw 1.", wave=4)
gear("empty_husk", "Empty Husk", "legendary", 2, [act("illusion_swap", range=99, transfer_block=True)],
     "Swap places with one of your illusions. Your Block moves onto it as extra health.", wave=4, role_emblem=None)
gear("barbed_mail", "Barbed Mail", "rare", 4, [block(5), act("retaliate", amount=3, bleed=1)],
     "Gain 5 Block and Retaliate 3 with Bleed 1.", wave=3)
gear("bristle", "Bristle", "rare", 2, [stoneskin(3), act("retaliate", amount=2)], "Gain 3 Stoneskin and Retaliate 2.", wave=3)
gear("quarry_plating", "Quarry Plating", "epic", 5, [stoneskin(5), surface("rubble", 0)], "Gain 5 Stoneskin, then leave Rubble beneath you.", EARTH)
gear("shrug_off", "Shrug Off", "epic", 2, [act("convert_block_to_stoneskin"), draw(1)],
     "Turn all your Block into Stoneskin, then draw 1.", EARTH, wave=4)
gear("static_mantle", "Static Mantle", "rare", 4, [block(5), act("retaliate", amount=0, shock=1)],
     "Gain 5 Block. Until your next turn, enemies that hit you in melee are Shocked.", LIGHTNING, wave=3)
gear("galvanize", "Galvanize", "rare", 1, [draw(1), act("quicken", amount=2)],
     "Draw 1. Quicken 2: your next card this turn costs 2 less Time.", LIGHTNING, wave=3)
gear("catch_the_wind", "Catch the Wind", "common", 2, [move(3, block_per_tile=1)], "Move 3 and gain 1 Block for each tile moved.", AIR, wave=4)
gear("windbreak", "Windbreak", "common", 3, [block(6), act("self_flag", flag="anchored")],
     "Gain 6 Block. You can't be pushed or pulled until your next turn.", AIR, wave=4)
gear("vigil", "Vigil", "common", 3, [block(5), act("vision", amount=1, duration=2)], "Gain 5 Block and 1 Vision for 2 turns.", radiance=True)
gear("blessed_salve", "Blessed Salve", "common", 3, [act("heal", amount=3), act("illuminate", range=0, radius=2, duration=2)],
     "Exhaust. Heal 3, then create radius-2 Light on yourself for 2 turns.", radiance=True, burn=True)

# =============================================================================== GEAR: boots
gear("dust_skip", "Dust Skip", "common", 2, [blink(2), draw(1)], "Blink 2, then draw 1.")
gear("spur_vault", "Spur Vault", "rare", 4, [blink(2), push(2, 4, 1, required=True)],
     "Blink 2, then kick an adjacent enemy for 4 and push 2.")
gear("shadow_gate", "Gravewind Gate", "epic", 4, [blink(4), act("next_attack", damage=3)],
     "Blink 4. Your next attack this turn deals 3 more.", wave=3)
gear("heel_hook", "Heel Stomp", "common", 4, [move(2), melee(4, required=True, stagger=2)],
     "Move 2, then stomp an adjacent enemy for 4 and Stagger 2.", wave=2)
gear("spur_spark", "Spur Spark", "rare", 2, [move(2, surface="electrified"), act("quicken", amount=1)],
     "Move 2 and leave Electrified where you arrive. Quicken 1.", LIGHTNING, wave=3)
gear("cloudstep_loop", "Cloudstep Loop", "epic", 3, [blink(3, if_no_adjacent_enemies=[{"type": "card_play", "amount": 1}])],
     "Blink 3. If you end with no adjacent enemies, gain 1 card play.", AIR, wave=4)
gear("iron_wheel", "Iron Wheel", "rare", 5, [move(3), melee(4, required=True, scale_bonus={"per": "tiles_moved", "damage": 1, "max": 5})],
     "Move 3, then strike for 4, plus 1 for each tile you moved this turn (maximum 5 more).", wave=2)
gear("headlong", "Headlong", "rare", 2, [move(4), act("next_attack", per_tile_moved={"damage": 1, "max": 4})],
     "Move 4. Your next attack this turn deals 1 more for each tile you moved this turn (maximum 4).", wave=3)
gear("glide", "Glide", "common", 2, [move(3, origin_surface="ice")], "Move 3, leaving Ice on the tile you started on.", ICE, wave=4)
gear("rime_step", "Rime Step", "common", 2, [move(2), act("surface_adjacent_enemies", surface="ice")],
     "Move 2, then leave Ice under each adjacent enemy.", ICE, wave=4)
gear("cinder_trail", "Cinder Trail", "rare", 3, [act("self_flag", flag="fire_immune_turn"), move(3, trail_surface="fire")],
     "Move 3, leaving Fire on each tile you leave. Fire doesn't damage you this turn.", FIRE, wave=4)
gear("hotfoot", "Hotfoot", "rare", 2,
     [move(2, if_started_on_surface={"surface": "fire", "rewards": [{"type": "block", "amount": 4}, {"type": "draw", "amount": 1}]})],
     "Move 2. If you started your turn on Fire, gain 4 Block and draw 1.", FIRE, wave=4)
gear("flowing_step", "Flowing Step", "common", 1, [move(2)], "Move 2. Follow-up: draw 1.", wave=2, follow_up=mods(append=[draw(1)]))
gear("palm_strike", "Palm Strike", "common", 3, [melee(4)], "Strike an adjacent enemy for 4. Follow-up: deal 3 more and push 1.",
     wave=2, follow_up=mods(m(0, add={"damage": 3}, set={"push": 1})))
gear("sunpath_stride", "Sunpath Stride", "rare", 3, [move(4, trail_light={"radius": 1, "duration": 2})],
     "Move 4, leaving radius-1 Light on each tile you enter for 2 turns.", radiance=True, wave=4)
gear("seek_the_light", "Seek the Light", "rare", 2, [blink(5, destination_requires_light=True)],
     "Blink to a tile in Light within range 5.", radiance=True, wave=4)

# =============================================================================== GEAR: trinkets
gear("lantern_shot", "Lantern Shot", "common", 3,
     [ranged(3, 3, illuminate_radius=2, illuminate_duration=2), draw(1)],
     "Deal 3 at range 3, then create radius-2 Light at the impact for 2 turns. Draw 1.", starter=True, radiance=True)
gear("clockwork_mark", "Clockwork Mark", "rare", 4, [ranged(4, 3, stagger=2), draw(1)], "Deal 4 at range 3 and Stagger 2, then draw 1.", wave=2)
gear("unsealed_gale", "Unsealed Gale", "legendary", 6, [act("force_area", center="self", radius=3, push=3)],
     "Exhaust. Push every enemy within 3 of you 3 tiles away.", AIR, wave=4, burn=True)
gear("borrowed_spark", "Borrowed Spark", "epic", 4, [surface("fire", 3, LINE2, rotate=True), draw(2), plays(1)],
     "Exhaust. Lose 1 health. Place a two-tile Fire line at range 3, draw 2, and gain 1 play.", FIRE, burn=True, health_cost=1)
gear("thorn_crown_pact", "Thorn Crown Pact", "legendary", 5, [],
     "Rite: enemies that hit you in melee take 3 and Bleed 1.", wave=3, burn=True, health_cost=1,
     rite={"effects": [{"type": "thorns", "damage": 3, "bleed": 1}]})
gear("royal_bramble", "Royal Bramble", "legendary", 5, [pull(2, 4, 2, bleed=2)],
     "Pull 2 at range 2 for 4 and Bleed 2. Empower (1 HP): Expose 4 and Sunder 4.", wave=2,
     empower={"cost": {"health": 1}, "mods": [m(0, set={"expose": 4, "sunder": 4})]})
gear("geode", "Geode", "common", 3, [act("outcrop", range=2, health=3), stoneskin(3)],
     "Raise an outcrop within range 2, then gain 3 Stoneskin.", EARTH)
gear("charged_orb", "Charged Orb", "rare", 2, [act("quicken", amount=2), act("next_attack", element="lightning", chain=1)],
     "Quicken 2. Your next Lightning attack this turn gains Chain 1.", LIGHTNING, wave=3)
gear("straw_double", "Straw Double", "common", 2, [act("illusion", health=2, range=1), draw(1)],
     "Create a 2-health illusion next to you, then draw 1.")
gear("headsmans_toll", "Headsman's Toll", "rare", 2,
     [ranged(3, 3, on_result={"when": "killed", "rewards": [{"type": "card_play", "amount": 1}, {"type": "draw", "amount": 1}]})],
     "Deal 3 at range 3. If this kills, gain 1 more card play and draw 1.", wave=4)
gear("stolen_moment", "Stolen Moment", "epic", 1, [act("quicken", amount=3), draw(1)],
     "Quicken 3: your next card this turn costs 3 less Time. Draw 1.", wave=3)
gear("reprise", "Reprise", "epic", 6, [draw(4), block(5)], "Lose 1 health. Draw 4 and gain 5 Block.", health_cost=1)
gear("sworn_oath", "Sworn Oath", "common", 2, [block(3), act("next_attack", damage=3)],
     "Gain 3 Block. Your next attack this turn deals 3 more.", wave=3)

# =============================================================================== ITEMS
card("nail_bomb", "Shrapnel Bomb", "common", 5, [aoe(4, 3, CROSS, sunder=2)], "Consume. Deal 4 in a cross at range 3 and Sunder 2.", item=True)
card("powder_keg", "Powder Keg", "rare", 3, [act("outcrop", range=2, health=3, kind="powder_keg", burst_damage=6)],
     "Consume. Place a 3-health keg within range 2. When destroyed, it deals 6 to its tile and each tile next to it.",
     FIRE, item=True, wave=4)
card("lamp_oil", "Lamp Oil", "common", 3, [surface("fire", 3, LINE3, rotate=True)], "Consume. Leave Fire on a three-tile line within range 3.", FIRE, item=True)
card("caltrops", "Caltrops", "common", 3, [aoe(0, 2, CROSS, EARTH, bleed=2, surface="rubble")],
     "Consume. Leave Rubble in a cross within range 2. Enemies in it Bleed 2.", EARTH, item=True)
card("hourglass_sand", "Hourglass Sand", "rare", 2, [act("quicken", amount=4), draw(1)],
     "Consume. Quicken 4: your next card this turn costs 4 less Time. Draw 1.", item=True, wave=3)
card("throwing_net", "Throwing Net", "common", 4, [ranged(0, 3, immobilize=True, stagger=3)],
     "Consume. Immobilize an enemy within range 3 and Stagger 3.", item=True, wave=2)
card("flash_powder", "Flash Powder", "common", 3, [aoe(0, 3, DIAMOND2, expose=2, illuminate_radius=3, illuminate_duration=2)],
     "Consume. Create radius-3 Light within range 3 for 2 turns. Enemies within 2 of its center are Exposed 2.", item=True, radiance=True, wave=4)
card("whetstone", "Whetstone", "common", 2, [act("next_attack", damage=4, pierce=True)],
     "Consume. Your next attack this turn deals 4 more and Pierces.", item=True, wave=3)
card("mirror_charm", "Mirror Charm", "rare", 3, [act("illusion", health=5, range=3)], "Consume. Create a 5-health illusion within range 3.",
     item=True, radiance=True)
card("bottled_gale", "Bottled Gale", "rare", 3, [act("force_area", center="self", radius=1, push=3)],
     "Consume. Push each adjacent enemy 3.", AIR, item=True, wave=4)
card("bitter_tonic", "Bitter Tonic", "common", 2, [draw(2), plays(1)], "Consume. Draw 2 and gain 1 card play.", item=True)
card("glacier_salts", "Glacier Salts", "common", 3, [surface("ice", 3, CROSS)], "Consume. Leave Ice in a cross within range 3.", ICE, item=True)
card("thunderstone", "Thunderstone", "epic", 4, [ranged(5, 99, LIGHTNING, ignore_los=True, stagger=2)],
     "Consume. Deal 5 Lightning damage to any enemy you can see, ignoring line of sight. Stagger 2.", LIGHTNING, item=True, wave=4)
card("smelling_salts", "Smelling Salts", "common", 3, [act("cleanse", statuses=["immobilize", "shock", "chilled"]), move(2)],
     "Consume. Remove Immobilize, Shock and Chilled from yourself, then move 2.", item=True, wave=4)
card("seers_candle", "Seer's Candle", "rare", 3, [act("truesight", duration=2), act("vision", amount=2, duration=2)],
     "Consume. Gain Truesight and 2 Vision for 2 turns.", item=True, radiance=True)


# Cut cards stay as retired entries so saves that still hold them resolve to a live replacement.
RETIRED = {
 "ember_jab": {
  "name": "Measured Cut",
  "rarity": "common",
  "burn": False,
  "health_cost": 0,
  "time": 3,
  "description": "Strike for 5, then draw 1.",
  "accent": "#bb5e34",
  "art_path": "res://assets/art/cards/ember_jab.png",
  "reward_pool": False,
  "actions": [
   {
    "type": "melee",
    "damage": 5,
    "range": 1,
    "element": "none"
   },
   {
    "type": "draw",
    "amount": 1
   }
  ],
  "retired": True,
  "replacement_id": "backhand_nick"
 },
 "cinderburst": {
  "name": "Shrapnel Burst",
  "rarity": "rare",
  "burn": False,
  "health_cost": 0,
  "time": 6,
  "description": "Deal 7 in a cross pattern at range 3.",
  "accent": "#cb6a39",
  "art_path": "res://assets/art/cards/cinderburst.png",
  "actions": [
   {
    "type": "aoe",
    "damage": 7,
    "range": 3,
    "pattern": [
     [
      0,
      0
     ],
     [
      1,
      0
     ],
     [
      -1,
      0
     ],
     [
      0,
      1
     ],
     [
      0,
      -1
     ]
    ],
    "rotate": False,
    "element": "none"
   }
  ],
  "reward_pool": False,
  "retired": True,
  "replacement_id": "ember_rain"
 },
 "gate_gambit": {
  "name": "Gate Gambit",
  "rarity": "epic",
  "burn": True,
  "health_cost": 1,
  "time": 8,
  "description": "Exhaust. Lose 1 health. Draw 3, gain 2 card plays, and gain 3 block.",
  "accent": "#8f6da8",
  "art_path": "res://assets/art/cards/gate_gambit.png",
  "actions": [
   {
    "type": "draw",
    "amount": 3
   },
   {
    "type": "card_play",
    "amount": 2
   },
   {
    "type": "block",
    "amount": 3
   }
  ],
  "reward_pool": False,
  "retired": True,
  "replacement_id": "trapdoor"
 }
}
