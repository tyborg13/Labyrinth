"""Card pool overhaul proposal data (design only, 2026-09-30).

Every live card in data/cards.json gets a verdict here, and every new card is
authored in full. build_proposal.py reads this module, fills "was" text for
existing cards from data/cards.json, validates coverage, and emits
proposal.json plus the browsable HTML page.

Status values:
  keep    unchanged
  tweak   same identity, numbers or one rider changed
  rework  same slot and name family, new job
  moved   same card, new home (magic <-> gear)
  new     new card
  cut     removed from the pool

impl values (set by the builder unless given):
  0  expressible with today's action fields (data only)
  1  uses one of the proposed keywords
  2  needs a bespoke rule, condition or action type
"""

CARDS = []
PIECES = []


def card(cid, name, src, school, rarity, time, text, status="new", costs=None,
         note="", impl=None, was_id=None):
    CARDS.append({
        "id": cid,
        "name": name,
        "src": src,  # starter | magic | gear | item
        "school": school,  # fire ice lightning air earth radiance neutral
        "rarity": rarity,
        "time": time,
        "costs": costs or [],
        "text": text,
        "status": status,
        "note": note,
        "impl": impl,
        "was_id": was_id or (cid if status != "new" else None),
    })


def piece(pid, name, slot, rarity, theme, cards, status="keep", element=None,
          note=""):
    PIECES.append({
        "id": pid,
        "name": name,
        "slot": slot,
        "rarity": rarity,
        "element": element,
        "theme": theme,
        "cards": cards,
        "status": status,
        "note": note,
    })


# ---------------------------------------------------------------------------
# Starter magic (the six starting spell slots: 2x each)
# ---------------------------------------------------------------------------
S = "starter"
card("pale_spark", "Pale Spark", S, "neutral", "common", 3,
     "Deal 3 at range 3.", "tweak",
     note="Range 2 lost to a step plus a melee card. Range 3 lets the opener hit from safety while staying the weakest spell.")
card("dull_bolt", "Dull Bolt", S, "neutral", "common", 4,
     "Deal 4 at range 3.", "keep")
card("waning_pulse", "Waning Pulse", S, "neutral", "common", 4,
     "Deal 3 to each adjacent enemy and Push them 1.", "tweak",
     note="The lowest-scoring starter. Now it is the starter deck's escape from a surround, and it teaches Push on turn one.")
card("ember_jab", "Measured Cut", S, "neutral", "common", 3,
     "Strike for 5, then draw 1.", "cut",
     note="Flagged as a starter but used by no starting kit, reward or shop. Dead data.")

# ---------------------------------------------------------------------------
# FIRE: "What are you willing to burn?"
# ---------------------------------------------------------------------------
M = "magic"
F = "fire"
card("guiding_flare", "Guiding Flare", M, F, "common", 4,
     "Deal 3 at range 3. Leave Fire and radius-2 Light for 2 turns.", "tweak",
     note="Range 2 to 3. Fire's Light painter; Firebrand Volley no longer does its job better.")
card("firebrand_volley", "Firebrand Volley", M, F, "common", 3,
     "Deal 4 at range 3. Leave Fire.", "tweak",
     note="Was strictly better than Guiding Flare. Drops the Light rider and becomes the fast, plain painter.")
card("cinder_bloom", "Cinder Bloom", M, F, "common", 5,
     "Deal 2 in a cross at range 2. Leave Fire in the cross. Empower (Exhaust): the pattern becomes a radius-2 diamond.",
     "tweak",
     note="Time 6 to 5. The wide painter; the once-per-combat Empower paints a whole Detonate board.")
card("hearth_rush", "Hearth Rush", M, F, "common", 5,
     "Move 2, then strike for 6. Leave Fire beneath the target.", "keep")
card("cinderline_tempo", "Cinderline Tempo", M, F, "common", 3,
     "Deal 2 at range 2, then Detonate 6 at the target.", "tweak",
     note="Time 4 to 3. A cash-out that needs setup should be cheap.")
card("kindle", "Kindle", M, F, "common", 2,
     "Place Fire on a tile within range 3. Draw 1.",
     note="The cheapest Fire setup. Lets a hand holding only a Detonate still function.")
card("flame_jet", "Flame Jet", M, F, "common", 3,
     "Deal 4 to the first 3 tiles in a line from you (rotatable). Leave Fire on the farthest tile.",
     note="A close-range line, a shape Fire lacked. The far tile becomes the next Detonate anchor.")
card("scorch", "Scorch", M, F, "common", 4,
     "Deal 4 at range 3. +3 if the target stands on Fire.", impl=0,
     note="Non-consuming payoff: rewards keeping Fire on the board instead of spending it.")
card("stoke", "Stoke", M, F, "common", 4,
     "Each enemy you can see that stands on Fire takes 3.", impl=2,
     note="A wide, non-consuming payoff. Detonate spends Fire; Stoke rewards having lots of it.")
card("ember_ward", "Ember Ward", M, F, "common", 3,
     "Gain 5 Block. Leave Fire under each adjacent enemy.", impl=2,
     note="Ward cycle. Melee enemies that stay to hit you burn at their turn start.")
card("inferno_ritual", "Inferno Ritual", M, F, "rare", 6,
     "Deal 3 in a cross at range 2, then Detonate 9 in that pattern.", "keep")
card("molten_reach", "Molten Reach", M, F, "rare", 5,
     "Deal 4 along a 3-tile line at range 2. Leave Fire along it.", "tweak",
     note="Time 6 to 5, in line with the other painters.")
card("cinder_fusillade", "Cinder Fusillade", M, F, "rare", 5,
     "Flurry. Deal 2 at range 3 and leave Fire, once per play spent.", "keep", costs=["Flurry"])
card("flashsteam", "Flashsteam", M, F, "rare", 4,
     "Target a cross within range 3. Consume all Ice in it. Deal 3 to each enemy in the cross, +4 to enemies that stood on Ice.",
     impl=2, note="Fire + Ice bridge. An Ice player's leftover lanes become a Fire player's ammunition.")
card("magma_vent", "Magma Vent", M, F, "rare", 5,
     "Consume a Rubble tile within range 3. Deal 5 to each enemy on it and its four neighbors, then leave Fire there.",
     impl=2, note="Fire + Earth bridge. Card-level version of what Basalt Kiln does as a relic.")
card("cinder_wall", "Cinder Wall", M, F, "rare", 4,
     "Leave Fire on a 4-tile line within range 2 (rotatable). Gain 4 Block.", impl=0,
     note="Defensive Fire: a wall that makes approaching you cost health.")
card("immolation", "Immolation", M, F, "epic", 4,
     "Detonate 8 on every Fire tile within 1 of you, including your own. You take no damage from it. Empower (2 HP): within 2 instead.",
     impl=2, note="The firewalker's burst. Stand in your own Fire, then cash all of it out at once.")
card("pyroclasm", "Pyroclasm", M, F, "epic", 7,
     "Deal 9 at range 3. If the target stands on Fire, consume it and deal 6 more.", impl=2,
     note="Fire's single-target nuke, conditional on the element's own setup.")
card("rite_of_the_pyre", "Rite of the Pyre", M, F, "epic", 4,
     "Rite: your Fire tiles deal 2 more damage.", costs=["Rite"],
     note="Fire's engine piece. Every painter after this one is worth more.")
card("meteorfall", "Meteorfall", M, F, "epic", 7,
     "Mark a 3-tile line within range 4 (rotatable). At the start of your next turn, each marked tile takes 8 and becomes Fire.",
     impl=2, note="Vyraketh's marks, turned around. A telegraphed strike that controls where enemies are willing to stand.")
card("wildfire_halo", "Wildfire Halo", M, F, "legendary", 7,
     "Deal 4 in a large diamond at range 2, then Detonate 10 in that pattern.", "keep")
card("salamander_heart", "Salamander Heart", M, F, "legendary", 6,
     "Rite: you ignore Fire damage. At the start of your turn, if you stand on Fire, gain 3 Stoneskin and draw 1.",
     costs=["Rite"], impl=2,
     note="Build-around. Turns Fire from a shared hazard into your terrain.")

# ---------------------------------------------------------------------------
# ICE: "Set it up, then shatter it."
# ---------------------------------------------------------------------------
I = "ice"
card("frostbolt", "Frostbolt", M, I, "common", 4,
     "Deal 4 Ice at range 3. Leave Ice.", "keep")
card("rime_shard", "Rime Shard", M, I, "common", 3,
     "Deal 2 Ice along a 2-tile line at range 2. Leave Ice.", "keep")
card("cold_grasp", "Cold Grasp", M, I, "common", 4,
     "Strike at reach 2 for 7 Ice.", "keep")
card("icicle_lance", "Icicle Lance", M, I, "common", 5,
     "Deal 6 Ice at range 3. Pierce.", "keep")
card("frost_lane", "Frost Lane", M, I, "common", 3,
     "Leave Ice on a 3-tile line within range 3 (rotatable). Draw 1.", impl=0,
     note="Pure lane painter. Enemies that walk it are Chilled on entry.")
card("skate", "Skate", M, I, "common", 2,
     "Move 3. This turn, Ice costs you no movement and doesn't Chill you.", impl=2,
     note="Ice mobility. Your own lanes become roads for you and traps for them.")
card("shiver_shot", "Shiver Shot", M, I, "common", 2,
     "Deal 2 Ice at range 4.", impl=0,
     note="The cheapest Freeze trigger. Ice needed a fast card to convert Chilled into Frozen.")
card("hoarfrost_ward", "Hoarfrost Ward", M, I, "common", 3,
     "Gain 5 Block. Leave Ice under each adjacent enemy.", impl=2,
     note="Ward cycle. Enemies that stay adjacent start their turn Chilled for your next Ice hit.")
card("rimefang", "Rimefang", M, I, "common", 4,
     "Deal 4 Ice at range 2. Follow-up: +3, and leave Ice.",
     note="Rewards playing it second; played second after a painter, it can Freeze.")
card("hush_of_winter", "Hush of Winter", M, I, "rare", 5,
     "Deal 5 Ice at range 4. If this Freezes the target, draw 2.", "rework", impl=2,
     note="Was a top-5 score with no identity (6 damage + draw). Now it pays you for doing the Ice setup.")
card("shatterline", "Shatterline", M, I, "rare", 6,
     "Deal 5 Ice along a 3-tile line at range 2. Pierce. Empower (+2 Time): the line is 5 tiles.",
     "tweak", note="Time 7 to 6, plus an optional long line.")
card("glacier_pin", "Glacier Pin", M, I, "rare", 6,
     "Deal 3 Ice along a 2-tile line at range 2 and Immobilize. Leave Ice.", "keep",
     note="Already Ice's best setup: pinned enemies can't walk off their Ice before it Chills them.")
card("icebound_chains", "Icebound Chains", M, I, "rare", 6,
     "Deal 5 Ice at range 2 and Immobilize. Gain Truesight for 2 turns.", "keep")
card("prism_sight", "Prism Sight", M, I, "rare", 4,
     "Gain Truesight for 2 turns and 4 Block. Draw 1.", "keep")
card("frost_circuit", "Frost Circuit", M, I, "rare", 3,
     "Choose an Ice tile within range 3. It and all Ice connected to it become Electrified. Deal 2 Lightning to each enemy on them and Shock them.",
     impl=2, note="Ice + Lightning bridge. Converts frozen lanes into a live network.")
card("sleet_squall", "Sleet Squall", M, I, "rare", 5,
     "Push 2 at range 3, then deal 3 Ice to the target.", impl=2,
     note="Ice + Air bridge. Push first, hit second: a target shoved onto Ice is Chilled on entry, so the hit Freezes it.")
card("ice_sculpture", "Ice Sculpture", M, I, "rare", 5,
     "Create a 4-health illusion within range 3. Leave Ice on each empty tile adjacent to it.", impl=2,
     note="A decoy that is also a trap. Enemies that step up to hit it arrive Chilled.")
card("frost_nova", "Frost Nova", M, I, "epic", 6,
     "Deal 4 Ice to each adjacent enemy. Leave Ice on all 8 tiles around you.", impl=2,
     note="Paints a whole ring at once. Pairs with Skate and Hoarfrost Wall.")
card("shatter", "Shatter", M, I, "epic", 5,
     "Deal 5 Ice at range 3. If the target was Frozen, also deal 5 to each enemy adjacent to it.", impl=2,
     note="The Freeze payoff that spreads: 15 to the Frozen target, shards to its neighbors.")
card("rite_of_hoarfrost", "Rite of Hoarfrost", M, I, "epic", 4,
     "Rite: whenever you Freeze an enemy, gain 3 Block and draw 1.", costs=["Rite"], impl=2,
     note="Ice's engine. Each Freeze now refunds a card.")
card("white_silence", "White Silence", M, I, "legendary", 8,
     "Deal 4 Ice to each Chilled enemy you can see. (Each is Frozen.)", "rework", impl=2,
     note="Was 10 damage at range 3, a big number and nothing more. Now it is the Ice capstone: a mass Freeze for a prepared board.")
card("crystal_mantle", "Crystal Mantle", M, I, "legendary", 5,
     "Exhaust. Gain 3 Mantle. Each direct hit against you breaks one Mantle instead of dealing damage.",
     costs=["Exhaust"], impl=2,
     note="Iskaldra's armor for the player. It negates hits by count, so it answers boss strikes that Block can't.")

# ---------------------------------------------------------------------------
# LIGHTNING: "How fast can you go?"
# ---------------------------------------------------------------------------
L = "lightning"
card("spark_dart", "Spark Dart", M, L, "common", 4,
     "Deal 4 Lightning at range 3. Leave Electrified and radius-1 Light for 2 turns.", "keep")
card("chain_bolt", "Chain Bolt", M, L, "common", 4,
     "Deal 4 Lightning at range 3. Chain 2. Empower (+2 Time): Chain 4.", "tweak",
     note="Time 5 to 4, plus an Empower. Lightning should be the fast element.")
card("spark_focus", "Spark Focus", M, L, "common", 3,
     "Leave Electrified on a 3-tile line within range 3 (rotatable). Draw 1. Gain 1 Vision for 2 turns.", "keep")
card("static_lash", "Static Lash", M, L, "common", 4,
     "Deal 4 Lightning at range 3. Hits conducted through Electrified also Shock.", "tweak",
     note="Time 6 to 4. A conditional common can't cost more than an unconditional rare.")
card("jolt", "Jolt", M, L, "common", 1,
     "Deal 2 Lightning at range 3.", impl=0,
     note="The one-Time zap. Finishes a wounded enemy for the kill play, or pokes a network.")
card("static_rush", "Static Rush", M, L, "common", 2,
     "Move 2. Quicken 2.", note="Reposition and make the next card cheaper.")
card("capacitor", "Capacitor", M, L, "common", 2,
     "Gain 4 Block. Your next Lightning attack this turn gains Chain 2.", impl=2,
     note="Setup card that turns any single bolt into a multi-target one.")
card("static_ward", "Static Ward", M, L, "common", 3,
     "Gain 5 Block. Electrify your tile and the tile of each adjacent enemy.", impl=2,
     note="Ward cycle. Your tile links the adjacent tiles, so the next bolt hits everyone around you.")
card("arc_flash", "Arc Flash", M, L, "common", 3,
     "Deal 3 Lightning at range 3. Follow-up: Chain 2.")
card("storm_relay", "Storm Relay", M, L, "rare", 6,
     "Deal 5 Lightning at range 3. Chain 2. Hits conducted through Electrified also Shock.", "tweak",
     note="Time 7 to 6.")
card("volt_surge", "Volt Surge", M, L, "rare", 5,
     "Deal 3 Lightning along a 3-tile line at range 2. Leave Electrified.", "keep")
card("storm_beacon", "Storm Beacon", M, L, "rare", 6,
     "Deal 3 Lightning at range 3. Chain 2. Leave Electrified and radius-2 Light for 2 turns at the impact.", "keep")
card("overclock", "Overclock", M, L, "rare", 3,
     "Draw 1. Gain 1 card play. Empower (1 HP): draw 2 instead.",
     note="Lightning's card-flow piece, with a blood option for the big turn.")
card("plasma_arc", "Plasma Arc", M, L, "rare", 4,
     "Deal 3 Lightning at range 3. Chain 2. Each enemy hit that stands on Fire takes 4 more; consume that Fire.",
     impl=2, note="Lightning + Fire bridge.")
card("thunderclap", "Thunderclap", M, L, "rare", 4,
     "Deal 3 Lightning to each adjacent enemy and Push them 1. Electrify your tile.", impl=2,
     note="Lightning + Air bridge. A shockwave that clears space and leaves a conductor behind.")
card("storm_salvo", "Storm Salvo", M, L, "epic", 6,
     "Flurry. Deal 2 Lightning at range 3 with Chain 1, then draw 1, once per play spent.", "keep",
     costs=["Flurry"])
card("thunderline", "Thunderline", M, L, "epic", 7,
     "Deal 6 Lightning along a 3-tile line at range 2. Chain 1. Hits conducted through Electrified also Shock.",
     "tweak", note="Legendary to epic, Time 8 to 7. Strong, but it doesn't change how you play.")
card("discharge", "Discharge", M, L, "epic", 4,
     "Choose an Electrified tile within range 4. Deal 5 Lightning to each enemy on or adjacent to its connected network, then remove the network.",
     impl=2, note="Cash in the wiring. Ordinary Lightning keeps the network; Discharge spends it for a bigger area.")
card("ball_lightning", "Ball Lightning", M, L, "epic", 4,
     "Create a 3-health illusion within range 3 and Electrify its tile. Enemies that damage it take 4 Lightning and are Shocked.",
     impl=2, note="A decoy that punishes whoever takes the bait.")
card("rite_of_the_storm", "Rite of the Storm", M, L, "epic", 5,
     "Rite: at the start of each of your turns, deal 2 Lightning to each enemy standing on Electrified.",
     costs=["Rite"], impl=2, note="Makes wiring worth doing even on turns you don't attack.")
card("tempest_form", "Tempest Form", M, L, "legendary", 5,
     "Rite: your cards cost 1 less Time (minimum 1).", costs=["Rite"], impl=2,
     note="Build-around for the turn clock. Pays for itself in about three turns, so it is strongest in long fights.")
card("skybolt", "Skybolt", M, L, "legendary", 7,
     "Deal 7 Lightning to any enemy you can see, ignoring range and line of sight. It conducts; everything it hits is Shocked.",
     impl=2, note="Zekarion's strike in the player's hand. The only card that ignores sight lines.")

# ---------------------------------------------------------------------------
# AIR: "Where should they be?"
# ---------------------------------------------------------------------------
A = "air"
card("dawnstep", "Dawnstep", M, A, "common", 2,
     "Move 3. Gain 2 Vision for 2 turns.", "keep")
card("threaded_path", "Threaded Path", M, A, "common", 2,
     "Move 3. Create radius-1 Light where you arrive for 2 turns. Draw 1.", "keep")
card("gust_step", "Gust Step", M, A, "common", 4,
     "Move 1, then Pull 2 at range 2 for 3.", "keep")
card("slipstream_cut", "Slipstream Cut", M, A, "common", 4,
     "Move 2, then strike for 5 and Push 1.", "keep",
     note="Unchanged text; it gains collision damage from the forced-movement rule.")
card("updraft", "Updraft", M, A, "common", 4,
     "Push 2 at range 3 for 3.", "tweak",
     note="1 less damage. Driving the target into a wall, crate or another enemy now adds up to 4 to each of them.")
card("buffet", "Buffet", M, A, "common", 2,
     "Push 1 at range 2 for 2.",
     note="A cheap nudge: one tile onto a trap or Fire, or 2 collision damage against a wall.")
card("crosswind", "Crosswind", M, A, "common", 3,
     "Deal 3 at range 3 and Push 2 in any direction.", impl=0,
     note="Sideways force. Uses the engine's existing sideways-force flag (Quarry Winch's aiming) without the Rubble cost.")
card("hurricane_palm", "Hurricane Palm", M, A, "common", 4,
     "Strike for 3 and Push 3.",
     note="The big shove. Against a wall or another enemy, the collision adds up to 6 to each.")
card("gale_ward", "Gale Ward", M, A, "common", 3,
     "Gain 5 Block. Push each adjacent enemy 1.", impl=2,
     note="Ward cycle. Disengage without spending a move.")
card("wind_shear", "Wind Shear", M, A, "common", 5,
     "Deal 3 along a 3-tile line at range 2 and Push each target 1 away from you. Empower (+2 Time): Push 2 instead.")
card("vacuum_line", "Vacuum Line", M, A, "rare", 6,
     "Pull 3 at range 3 for 6. Draw 1.", "tweak", note="Time 7 to 6.")
card("squall_shot", "Squall", M, A, "rare", 5,
     "Deal 2 in a cross at range 3. Push each enemy in it 1 away from the center; an enemy on the center is pushed away from you.", "rework",
     impl=2, note="Was a hard-to-read three-tile pattern that scored 1.95. Now a scatter: break up a formation into walls and each other.")
card("razor_gale", "Razor Gale", M, A, "rare", 4,
     "Flurry. Deal 2 at range 2 and Push 1, once per play spent.", "keep", costs=["Flurry"],
     note="Unchanged. Once the first copy pins the target against something, each later copy also collides.")
card("changing_winds", "Changing Winds", M, A, "rare", 3,
     "Swap places with a one-tile enemy or one of your illusions within range 3.", impl=2,
     note="The positional classic the pool lacked: put them where you were, on your hazards.")
card("fan_the_flames", "Fan the Flames", M, A, "rare", 4,
     "Push 2 at range 3 for 2. Leave Fire on each tile the target passes through.", impl=2,
     note="Air + Fire bridge. Draws a Fire line with the enemy's own body.")
card("dust_devil", "Dust Devil", M, A, "rare", 4,
     "Consume a Rubble tile within range 3. Push each enemy adjacent to it 2 away from it. Expose 2.",
     impl=2, note="Air + Earth bridge.")
card("kestrel_dive", "Kestrel Dive", M, A, "rare", 4,
     "Blink 3, then strike an adjacent enemy for 5 and Push 1.",
     note="Air's melee: drop in from above and knock the target into something.")
card("vortex", "Vortex", M, A, "epic", 5,
     "Choose a tile within range 3. Pull each enemy within 2 of it 2 tiles toward it.", impl=2,
     note="Gathers a group for an area attack, the opposite of Squall. Each enemy stops next to the tile or level with it; one pulled into another enemy collides.")
card("eye_of_the_storm", "Eye of the Storm", M, A, "epic", 5,
     "Gain 6 Block. Until your next turn, enemies that hit you in melee are Pushed 2.",
     note="A Retaliate variant: the answer to being surrounded.")
card("rite_of_tailwinds", "Rite of Tailwinds", M, A, "epic", 3,
     "Rite: gain 1 extra independent movement each turn. Your Push and Pull move targets 1 tile farther.",
     costs=["Rite"], impl=2)
card("skybreak_current", "Skybreak Current", M, A, "legendary", 7,
     "Deal 4 at range 4 and Push 5.", "rework",
     note="Was Updraft for 3 more Time (6 damage, Push 2). Now a real legendary: launch one enemy across the room. Stopped after one tile, it deals 8 more to the target and to what it hit.")
card("cyclone_seal", "Cyclone Seal", M, A, "legendary", 7,
     "Exhaust. Choose a tile within range 3. Pull every enemy within 3 of it up to 3 tiles toward it, then deal 6 to each enemy adjacent to it.",
     "moved", costs=["Exhaust"], impl=2,
     note="Was Force Seal, a neutral spell no reward could offer. Keeps its name and becomes Air's gathering finisher.")

# ---------------------------------------------------------------------------
# EARTH: "Hold the ground."
# ---------------------------------------------------------------------------
E = "earth"
card("venom_claw", "Quarry Claw", M, E, "common", 4,
     "Strike for 8. Leave Rubble beneath the target.", "keep")
card("stone_plate", "Stone Plate", M, E, "common", 4,
     "Gain 4 Stoneskin. Draw 1.", "keep")
card("quarry_step", "Quarry Step", M, E, "common", 5,
     "Move 2, then strike for 6. Leave Rubble beneath the target.", "keep")
card("thorn_skewer", "Thorn Skewer", M, E, "common", 3,
     "Strike for 6. Pierce. +3 if the target stands on Rubble.", "keep")
card("root_snare", "Root Snare", M, E, "common", 4,
     "Deal 1 at range 3 and Immobilize. Leave Rubble.", "rework",
     note="The name promised a snare. Trades its Light for Immobilize; the Rubble stays.")
card("raise_stone", "Raise Stone", M, E, "common", 2,
     "Raise an outcrop on an empty tile within range 3. Draw 1.",
     note="Cheap cover. Outcrops block sight, so this answers archers and casters, and gives pushes something to collide with.")
card("stone_ward", "Stone Ward", M, E, "common", 3,
     "Gain 5 Block. Leave Rubble under each adjacent enemy.", impl=2,
     note="Ward cycle. Enemies that want to chase you pay 2 movement to leave.")
card("rockburst", "Rockburst", M, E, "common", 4,
     "Destroy an outcrop or crate within range 3. Deal 6 to each enemy adjacent to it. Leave Rubble in a cross there.",
     impl=2, note="Crates are in every combat room, so this works with no setup.")
card("tremor", "Tremor", M, E, "common", 5,
     "Deal 3 to each enemy within 2 tiles of you. Stagger 2. Empower (+2 Time): Stagger 4.", impl=1)
card("rooted_stance", "Rooted Stance", M, E, "common", 3,
     "Gain 6 Stoneskin. You can't Move, Blink or Swap for the rest of this turn.", impl=2,
     note="Cheap persistent defense with a real cost. Play it last.")
card("basalt_guard", "Basalt Guard", M, E, "rare", 6,
     "Create a 4-health illusion on Rubble within range 3. Gain 4 Block and 2 Stoneskin.", "keep")
card("grave_mortar", "Grave Mortar", M, E, "rare", 6,
     "Strike all adjacent tiles for 9. Leave Rubble there.", "keep")
card("glowstone_ward", "Glowstone Ward", M, E, "rare", 5,
     "Gain 4 Stoneskin. Create lasting radius-2 Light within range 3.", "keep")
card("earthen_rampart", "Earthen Rampart", M, E, "rare", 5,
     "Raise outcrops on a 3-tile line within range 2 (rotatable). Gain 3 Stoneskin. Empower (Exhaust): the line is 5 tiles.",
     note="A wall. Cuts a room in half, blocks a firing lane, or builds something to push enemies into.")
card("stonefist", "Stonefist", M, E, "rare", 4,
     "Strike for 5. +1 for each Stoneskin you have (maximum +6).", impl=2,
     note="Stoneskin as offense. The first payoff in the pool for stacking it.")
card("frost_heave", "Frost Heave", M, E, "rare", 4,
     "Consume the Ice under an enemy within range 3. Deal 6 to it, Immobilize it, and leave Rubble.",
     impl=2, note="Earth + Ice bridge.")
card("grounding", "Grounding", M, E, "rare", 3,
     "Remove every Electrified tile within 2 of you. Gain 2 Stoneskin per tile removed (maximum 8).",
     impl=2, note="Earth + Lightning bridge. Also strips Zekarion's and the wisps' wiring from under your feet.")
card("spike_mantle", "Spike Mantle", M, E, "epic", 6,
     "Strike all adjacent tiles for 8, or 12 against targets on Rubble. Pierce. Consume adjacent Rubble to gain 4 Stoneskin.",
     "keep")
card("petrify", "Petrify", M, E, "epic", 5,
     "An enemy within range 3 (not a dragon) skips its next turn and gains 5 Block.", impl=2,
     note="A full turn skip, like Freeze, but the target comes back harder to kill.")
card("rite_of_the_mountain", "Rite of the Mountain", M, E, "epic", 5,
     "Rite: at the start of each of your turns, gain 3 Stoneskin.", costs=["Rite"], impl=2)
card("tectonic_maul", "Tectonic Maul", M, E, "legendary", 8,
     "Move 1, then strike for 11, or 15 against a target on Rubble. Leave a cross of Rubble at the impact. Stagger 3.",
     "tweak", note="Adds Stagger 3, so the slowest card in the pool buys some of its Time back.")
card("worldspine", "Worldspine", M, E, "legendary", 7,
     "Exhaust. Raise a 4-health Worldspine on each empty tile next to a tile within range 3. At the start of each of your turns, each enemy next to a Worldspine takes 3.",
     costs=["Exhaust"], impl=2,
     note="Tharokh's spires for the player: a cage around one enemy, or a pulsing wall across the room.")

# ---------------------------------------------------------------------------
# RADIANCE (neutral magic): "What can you see?"
# ---------------------------------------------------------------------------
R = "radiance"
card("sunlance", "Sunlance", M, R, "common", 4,
     "Deal 4 at range 4. +3 if the target stands in Light.", impl=2,
     note="The basic Light payoff on a card instead of a relic.")
card("beacon", "Beacon", M, R, "common", 2,
     "Create radius-2 Light within range 4 for 3 turns. Draw 1.", impl=0,
     note="Pure Light setup, cheap enough to play alongside the payoff.")
card("mirror_image", "Mirror Image", M, R, "common", 3,
     "Create a 3-health illusion within range 3. Draw 1. Empower (+2 Time): 5 health instead.",
     note="The baseline decoy. Illusions move to Radiance: they are tricks of light.")
card("dazzle", "Dazzle", M, R, "common", 3,
     "Deal 2 at range 3. If the target stands in Light, Stagger 3.", impl=2)
card("seekers_mark", "Seeker's Mark", M, R, "common", 2,
     "Gain Truesight for 2 turns. Draw 1.", impl=0)
card("trapdoor", "Trapdoor", M, R, "rare", 4,
     "Blink 4 and gain 5 Block. Gain 2 Vision for 2 turns.", "keep")
card("ember_rain", "Lantern Rain", M, R, "rare", 5,
     "Deal 3 in a cross at range 3. Create radius-2 Light at the impact for 2 turns.", "keep")
card("revealing_glare", "Revealing Glare", M, R, "rare", 3,
     "Each enemy in Light within range 4 is Exposed 3. Draw 1.", impl=2,
     note="Sets up one big hit on every lit enemy.")
card("refraction", "Refraction", M, R, "rare", 4,
     "Deal 4 at range 3. It also hits each enemy adjacent to one of your illusions.", impl=2,
     note="Illusions become relays: enemies crowding a decoy all get hit.")
card("shattered_reflection", "Shattered Reflection", M, R, "rare", 3,
     "Destroy one of your illusions within range 6. Deal 6 to each enemy adjacent to it and create radius-2 Light there for 2 turns.",
     impl=2, note="Spend a decoy once the enemies have gathered around it.")
card("break_the_veil", "Break the Veil", M, R, "rare", 3,
     "Exhaust. Dispel Umbra 1. Draw 1.", costs=["Exhaust"], impl=0,
     note="A cheap, narrow Daybreak for deep rooms.")
card("hall_of_mirrors", "Hall of Mirrors", M, R, "epic", 6,
     "Create a 2-health illusion on each empty tile adjacent to you. Gain 3 Block.", impl=2,
     note="Up to four decoys at once. Enemies prefer illusions on distance ties, so this screens you.")
card("searing_light", "Searing Light", M, R, "epic", 5,
     "Deal 3 to each enemy standing in Light.", impl=2)
card("rite_of_noon", "Rite of Noon", M, R, "epic", 5,
     "Rite: you radiate radius-2 Light. Your attacks against enemies in Light deal 2 more.",
     costs=["Rite"], impl=2)
card("daybreak", "Daybreak", M, R, "legendary", 7,
     "Exhaust. Dispel Umbra 2. Draw 2. Gain 1 card play.", "keep", costs=["Exhaust"])
card("doppelganger", "Doppelganger", M, R, "legendary", 5,
     "Create a 5-health illusion within range 3. While it lives, you may fire ranged attacks from its tile.",
     impl=2, note="A second firing position. Every ranged card gains a new angle.")

# Neutral magic that no reward can currently offer (the general slot only
# accepts elemental or Radiance cards).
card("iron_wheel", "Iron Wheel", "gear", "neutral", "rare", 5,
     "Move 3, then strike for 4. +1 for each tile you moved this turn (maximum +5).", "moved", impl=2,
     note="Was unreachable neutral magic. Moves to Ironshod Sabatons and becomes the momentum card: the free 2 tiles now count.")
card("ricochet_knife", "Ricochet Knife", "gear", "neutral", "common", 3,
     "Deal 5 at range 2. Draw 1.", "moved",
     note="Was unreachable neutral magic. Moves to Tinker's Knives.")
card("reprise", "Reprise", "gear", "neutral", "epic", 6,
     "Draw 4. Gain 5 Block. Health cost 1.", "moved", costs=["HP 1"],
     note="Was unreachable neutral magic. Moves to Gambler's Watch, next to a Quicken card that offsets its Time.")
card("cinderburst", "Shrapnel Burst", M, "neutral", "rare", 6,
     "Deal 7 in a cross at range 3.", "cut",
     note="Unreachable neutral magic. Its job moves to the Shrapnel Bomb item.")
card("gate_gambit", "Gate Gambit", M, "neutral", "epic", 8,
     "Exhaust. Draw 3. Gain 2 card plays and 3 Block. Health cost 1.", "cut",
     costs=["Exhaust", "HP 1"],
     note="Unreachable, and 8 Time before the extra plays pay off. Overclock, Crank Reload and Gathering Rhythm cover the role.")

# ---------------------------------------------------------------------------
# GEAR
# ---------------------------------------------------------------------------
G = "gear"
N = "neutral"

# Weapons ------------------------------------------------------------------
piece("training_sword", "Training Sword", "weapon", "common",
      "Starter blade. Teaches playing a card second (Follow-up) and paying extra for more (Empower).",
      ["quick_stab", "whirlwind_slash", "bloody_lunge"], "tweak")
card("quick_stab", "Quick Stab", G, N, "common", 2,
     "Strike for 6. Follow-up: +3.", "tweak",
     note="9 damage for 2 Time was the best melee rate in the game, on a starter. Still 9 when played second.")
card("whirlwind_slash", "Whirlwind Slash", G, N, "common", 5,
     "Strike all adjacent tiles for 8.", "keep")
card("bloody_lunge", "Bloody Lunge", G, N, "common", 6,
     "Move 2, then strike for 9. Empower (1 HP): +4.", "rework",
     note="Was a mandatory 1 HP at Time 8. The health payment becomes your choice, and the card gets playable.")

piece("iron_cleaver", "Iron Cleaver", "weapon", "common",
      "A butcher's blade. Breaks armor and finishes wounded enemies.",
      ["cleaver_hook", "needle_flurry", "butcher_chop"], "rework")
card("cleaver_hook", "Cleaver Hack", G, N, "common", 3,
     "Strike for 5. Sunder 4.", "rework",
     note="Was a push-1 hit. Now the cleaver opens armor for the next card, which matters against Warden and Surgeon rooms.")
card("needle_flurry", "Cleaver Sweep", G, N, "common", 4,
     "Strike the 3-tile arc in front of you for 5 (rotatable).", "rework", impl=0,
     note="Was the same four-tile ring as five other cards. A front arc is a new shape.")
card("butcher_chop", "Butcher Chop", G, N, "common", 5,
     "Strike for 10. +5 against a target at or below half health.", "rework", impl=2,
     note="Execute. The cleaver's identity is finishing.")

piece("duelist_rapier", "Duelist Rapier", "weapon", "rare",
      "Parry and punish. The Retaliate weapon.",
      ["riposte_lunge", "battle_rhythm", "bodkin_arrow"], "rework")
card("riposte_lunge", "Riposte Lunge", G, N, "rare", 4,
     "Move 2, then strike for 5. Retaliate 4.", "rework",
     note="The name finally does what it says.")
card("battle_rhythm", "Parry Rhythm", G, N, "rare", 3,
     "Gain 4 Block. Retaliate 3. Draw 1.", "rework",
     note="Was Cinch Straps at rare. Now it is the parry you play when you see a melee intent coming.")
card("bodkin_arrow", "Needle Thrust", G, N, "rare", 3,
     "Strike for 5. Pierce. Follow-up: +4.", "tweak")

piece("grave_greatsword", "Grave Greatsword", "weapon", "epic",
      "Slow, enormous, and paid for in blood.",
      ["grave_cleave", "blood_price", "tombsplitter"], "rework")
card("grave_cleave", "Grave Cleave", G, N, "epic", 6,
     "Strike the 3-tile arc in front of you for 7 (rotatable). Expose 3.", "rework", impl=0,
     note="Front arc instead of the shared ring; it sets up the Blood Price that follows.")
card("blood_price", "Blood Price", G, N, "epic", 6,
     "Strike for 12. Empower (2 HP): +8 and Pierce.", "rework",
     note="20 piercing damage when you choose to pay, 12 when you don't.")
card("tombsplitter", "Tombsplitter", G, N, "epic", 8,
     "Strike the first 2 tiles in a line from you for 12 (rotatable). Stagger 3.", "rework",
     note="Was the four-tile ring again, at 1.72. Now a heavy line that knocks the target back on the turn clock.")

piece("sawtooth_knife", "Sawtooth Knife", "weapon", "common",
      "Many small cuts. Bleed and Expose at low Time.",
      ["sawtooth_flurry", "serrated_slip", "backhand_nick"], "tweak")
card("sawtooth_flurry", "Sawtooth Flurry", G, N, "common", 3,
     "Flurry. Strike for 3 and Bleed 1, once per play spent.", "rework", costs=["Flurry"],
     note="Was named Flurry without being one. Now it is: Bleed stacks per copy.")
card("serrated_slip", "Serrated Slip", G, N, "common", 3,
     "Move 2, then strike for 3. Expose 3.", "keep")
card("backhand_nick", "Backhand Nick", G, N, "common", 3,
     "Strike for 4. Bleed 1. Draw 1.", "keep")

piece("stormstring_bow", "Stormstring Bow", "weapon", "rare",
      "Arrows that leave charge behind.",
      ["stormstring_shot", "forked_nock", "far_draw"], "tweak", element="lightning")
card("stormstring_shot", "Stormstring Shot", G, L, "rare", 4,
     "Deal 4 Lightning at range 4. Chain 1. Leave Electrified at the impact.", "tweak",
     note="3 to 4 damage, Time 5 to 4.")
card("forked_nock", "Forked Nock", G, L, "rare", 5,
     "Deal 3 Lightning at range 3. Chain 2. Expose 2.", "tweak", note="Time 6 to 5.")
card("far_draw", "Far Draw", G, L, "rare", 3,
     "Leave Electrified on a tile within range 3. Draw 1.", "keep",
     note="Now unique to this bow; Windlass Repeater gets its own card.")

piece("hookspine_halberd", "Hookspine Halberd", "weapon", "epic",
      "Reach 2 and control. Hooks, pins and flank sweeps.",
      ["hookspine_reap", "sweeping_haft", "hook_and_hold"], "tweak")
card("hookspine_reap", "Hookspine Reap", G, N, "epic", 4,
     "Pull 1 at range 2 for 6. Bleed 1.", "keep")
card("sweeping_haft", "Sweeping Haft", G, N, "epic", 4,
     "Strike the four diagonal tiles for 6. Sunder 3.", "rework", impl=0,
     note="Diagonals are tiles orthogonal enemies can't strike you from. The halberd hits what flanks you.")
card("hook_and_hold", "Hook and Hold", G, N, "epic", 4,
     "Strike at reach 2 for 4. Immobilize. Expose 4.", "keep")

piece("phoenix_brand", "Phoenix Brand", "weapon", "legendary",
      "Fire melee that detonates what it strikes.",
      ["phoenix_cleave", "ember_guard", "rekindle_edge"], "keep", element="fire")
card("phoenix_cleave", "Phoenix Cleave", G, F, "legendary", 5,
     "Exhaust. Strike all adjacent tiles for 10, then Detonate 10 on those tiles. Health cost 1.", "keep",
     costs=["Exhaust", "HP 1"])
card("ember_guard", "Ember Guard", G, F, "legendary", 4,
     "Gain 7 Block. Leave Fire on a tile within range 1.", "keep")
card("rekindle_edge", "Rekindle Edge", G, F, "legendary", 4,
     "Strike for 8, then Detonate 8 at the target.", "keep")

piece("windlass_repeater", "Windlass Repeater", "weapon", "rare",
      "The Flurry crossbow.",
      ["windlass_volley", "crank_reload", "pinning_quarrel"], "tweak")
card("windlass_volley", "Windlass Volley", G, N, "rare", 4,
     "Flurry. Deal 2 along a 2-tile line at range 3, once per play spent.", "keep", costs=["Flurry"])
card("crank_reload", "Crank Reload", G, N, "rare", 3,
     "Draw 1. Gain 1 card play.", "keep")
card("pinning_quarrel", "Pinning Quarrel", G, N, "rare", 5,
     "Deal 4 at range 4. Immobilize.", impl=0,
     note="Replaces the Far Draw copy the repeater shared with Stormstring Bow.")

piece("war_maul", "War Maul", "weapon", "common",
      "Blunt force. Stagger, and shoves into walls.",
      ["crushing_blow", "haft_shove", "overhead_smash"], "new")
card("crushing_blow", "Crushing Blow", G, N, "common", 5,
     "Strike for 8. Stagger 3.")
card("haft_shove", "Haft Shove", G, N, "common", 3,
     "Strike for 2 and Push 2.",
     note="Cheap setup: shove the target onto a hazard, or into a wall for 4 more.")
card("overhead_smash", "Overhead Smash", G, N, "common", 7,
     "Strike for 12. Empower (+2 Time): Stagger 4.")

piece("hunting_spear", "Hunting Spear", "weapon", "common",
      "Reach, a brace against charges, and one throw.",
      ["spear_thrust", "brace_the_spear", "hurl_spear"], "new")
card("spear_thrust", "Spear Thrust", G, N, "common", 4,
     "Strike the first 2 tiles in a line from you for 6 (rotatable).", impl=0)
card("brace_the_spear", "Brace the Spear", G, N, "common", 3,
     "Gain 3 Block. Retaliate 5.")
card("hurl_spear", "Hurl Spear", G, N, "common", 5,
     "Deal 6 at range 4. Empower (Exhaust): +4 and Immobilize.")

piece("tinkers_knives", "Tinker's Knives", "weapon", "common",
      "Cheap blades and quick hands. Low Time, card flow.",
      ["ricochet_knife", "fan_of_knives", "palm_blade"], "new")
card("fan_of_knives", "Fan of Knives", G, N, "common", 4,
     "Deal 3 along a 3-tile line at range 2 (rotatable).", impl=0)
card("palm_blade", "Palm Blade", G, N, "common", 2,
     "Strike for 4. Follow-up: draw 1.")

piece("dawnlight_censer", "Dawnlight Censer", "weapon", "rare",
      "A swinging censer of holy light. Radiance melee.",
      ["censer_swing", "hallowed_strike", "incense_haze"], "new")
card("censer_swing", "Censer Swing", G, R, "rare", 5,
     "Strike all adjacent tiles for 5. Create radius-2 Light on yourself for 2 turns.", impl=0)
card("hallowed_strike", "Hallowed Strike", G, R, "rare", 4,
     "Strike for 6. +4 if the target stands in Light.", impl=2)
card("incense_haze", "Incense Haze", G, R, "rare", 3,
     "Gain Truesight for 2 turns and 3 Block.", impl=0)

piece("tourney_lance", "Tourney Lance", "weapon", "rare",
      "Momentum. Every tile you move this turn adds damage.",
      ["couched_lance", "joust", "unhorse"], "new")
card("couched_lance", "Couched Lance", G, N, "rare", 4,
     "Strike at reach 2 for 4. +1 for each tile you moved this turn (maximum +5).", impl=2)
card("joust", "Joust", G, N, "rare", 5,
     "Move up to 4 in a straight line, then strike for 6.", impl=2)
card("unhorse", "Unhorse", G, N, "rare", 4,
     "Strike for 5 and Push 2.")

piece("rimebite_hatchet", "Rimebite Hatchet", "weapon", "epic",
      "Ice melee. Chill up close, then cash in the Freeze.",
      ["rime_hack", "frozen_bite", "shatter_swing"], "new", element="ice")
card("rime_hack", "Rime Hack", G, I, "epic", 4,
     "Strike for 5 Ice. Leave Ice beneath the target.", impl=0)
card("frozen_bite", "Frozen Bite", G, I, "epic", 3,
     "Strike for 4 Ice. If this Freezes the target, gain 1 card play.", impl=2)
card("shatter_swing", "Shatter Swing", G, I, "epic", 5,
     "Strike for 8 Ice damage. If the target is Frozen, also deal 4 to each enemy adjacent to it.", impl=2)

piece("galewhip", "Galewhip", "weapon", "rare",
      "Reach 3. Drag, startle and bind.",
      ["lash", "crack_the_whip", "snare_coil"], "new", element="air")
card("lash", "Lash", G, A, "rare", 3,
     "Strike at reach 3 for 4 and Pull 1.", impl=0)
card("crack_the_whip", "Crack the Whip", G, A, "rare", 3,
     "Strike at reach 3 for 3. Stagger 2.")
card("snare_coil", "Snare Coil", G, N, "rare", 5,
     "Pull 3 at range 3 for 2. Immobilize.", impl=0,
     note="Neutral, not Air: Immobilize stays on neutral, Ice and Earth cards.")

piece("worldbreaker", "Worldbreaker", "weapon", "legendary",
      "Earth legendary. Raise stone, then break it into projectiles.",
      ["fault_strike", "raise_the_anvil", "worldbreak"], "new", element="earth")
card("fault_strike", "Fault Strike", G, E, "legendary", 6,
     "Strike for 11. Leave Rubble on the target's tile and the 2 tiles behind it.", impl=2)
card("raise_the_anvil", "Raise the Anvil", G, E, "legendary", 3,
     "Raise an outcrop adjacent to you. Gain 4 Stoneskin.")
card("worldbreak", "Worldbreak", G, E, "legendary", 6,
     "Destroy an adjacent outcrop you raised. Deal 10 to each enemy in the 3-tile line beyond it. Stagger 2.", impl=2)

# Offhands -----------------------------------------------------------------
piece("splintered_shield", "Splintered Shield", "offhand", "common",
      "Starter shield. Cheap Block and a free extra play.",
      ["brace", "guarded_step"], "tweak")
card("brace", "Brace", G, N, "common", 1,
     "Gain 6 Block.", "tweak",
     note="8 Block for 1 Time outclassed every later defensive card. Still the cheapest Block in the game.")
card("guarded_step", "Guarded Step", G, N, "common", 3,
     "Move 2. Gain 3 Block. Gain 1 card play.", "keep")

piece("ward_kite", "Ward-Kite", "offhand", "common",
      "A kite shield for advancing and shoving.",
      ["kite_bash", "warded_advance"], "tweak")
card("kite_bash", "Kite Bash", G, N, "common", 4,
     "Gain 6 Block. Bash an adjacent enemy for 3 and Push 1.", "keep")
card("warded_advance", "Warded Advance", G, N, "common", 3,
     "Move 2. Gain 7 Block.", "keep")

piece("chain_guard", "Chain Guard", "offhand", "rare",
      "Hook and hold at range 2.",
      ["chain_catch", "chain_lock"], "keep")
card("chain_catch", "Chain Catch", G, N, "rare", 4,
     "Pull 2 at range 2 for 2. Gain 5 Block.", "keep")
card("chain_lock", "Chain Lock", G, N, "rare", 5,
     "Deal 3 at range 2. Immobilize. Gain 4 Block.", "keep")

piece("mirror_guard", "Mirror Guard", "offhand", "epic",
      "Decoys that open enemies up.",
      ["mirror_feint", "mirror_flash"], "rework")
card("mirror_feint", "Mirror Feint", G, N, "epic", 4,
     "Create a 3-health illusion adjacent to an enemy within range 3. That enemy is Exposed 3.", "rework",
     impl=2, note="Was one of five near-identical illusion-plus-Block cards. Now a flanking decoy.")
card("mirror_flash", "Mirror Flash", G, N, "epic", 3,
     "Create a 2-health illusion within range 2. Gain 4 Block.", "keep")

piece("buckler_of_nails", "Buckler of Nails", "offhand", "common",
      "A spiked buckler. Pierce and Retaliate.",
      ["nail_parry", "spike_check"], "tweak")
card("nail_parry", "Nail Parry", G, N, "common", 3,
     "Gain 5 Block. Strike for 3. Pierce. Sunder 2.", "keep")
card("spike_check", "Spike Check", G, N, "common", 3,
     "Gain 5 Block. Retaliate 3.", "rework",
     note="Was a three-rider bash (Push, Bleed, Block). Spikes should hurt whoever hits you.")

piece("lodestone_buckler", "Lodestone Buckler", "offhand", "rare",
      "Magnetic defense for Lightning builds.",
      ["lodestone_reversal", "polar_guard"], "keep", element="lightning")
card("lodestone_reversal", "Lodestone Reversal", G, L, "rare", 5,
     "Pull 2 at range 2 for 3 Lightning. Leave Electrified at the destination. Gain 5 Block.", "keep")
card("polar_guard", "Polar Guard", G, L, "rare", 3,
     "Gain 6 Block, or 9 while standing on Electrified.", "keep")

piece("witchglass_aegis", "Witchglass Aegis", "offhand", "epic",
      "Reflection. Decoys that return what they take.",
      ["witchglass_double", "reflected_threat"], "rework")
card("witchglass_double", "Witchglass Double", G, N, "epic", 4,
     "Create a 3-health illusion within range 3. Gain 4 Block. Draw 1.", "keep")
card("reflected_threat", "Reflected Threat", G, N, "epic", 5,
     "Create a 4-health illusion within range 3. Enemies that damage it take that much damage too.", "rework",
     impl=2, note="Witchglass reflects. Now a decoy that hits back.")

piece("sunken_anchor", "Sunken Anchor", "offhand", "legendary",
      "Drag enemies in and crush them against you.",
      ["anchor_slam", "undertow_guard"], "tweak")
card("anchor_slam", "Anchor Slam", G, N, "legendary", 7,
     "Gain 3 Stoneskin. Pull 2 at range 3 for 5. Sunder 4. Immobilize.", "keep")
card("undertow_guard", "Undertow Guard", G, N, "legendary", 6,
     "Gain 9 Block. Pull 2 at range 3 for 2. Expose 4.", "keep")

piece("tower_shield", "Tower Shield", "offhand", "rare",
      "Plant it or charge with it.",
      ["shield_wall", "shield_charge"], "new")
card("shield_wall", "Shield Wall", G, N, "rare", 3,
     "Gain 9 Block. You can't Move, Blink or Swap for the rest of this turn.", impl=2)
card("shield_charge", "Shield Charge", G, N, "rare", 4,
     "Move 2, then bash an adjacent enemy for 3 and Push 2.")

piece("parrying_dagger", "Parrying Dagger", "offhand", "common",
      "The duelist's second blade. Retaliate and Follow-up.",
      ["deflect", "main_gauche"], "new")
card("deflect", "Deflect", G, N, "common", 2,
     "Gain 3 Block. Retaliate 4.")
card("main_gauche", "Main-Gauche", G, N, "common", 2,
     "Strike for 3. Follow-up: +3 and draw 1.")

piece("sunward_targe", "Sunward Targe", "offhand", "rare",
      "A polished targe that throws light.",
      ["sun_flash", "blinding_bash"], "new", element="radiance")
card("sun_flash", "Sun Flash", G, R, "rare", 3,
     "Gain 5 Block. Create radius-2 Light on yourself for 2 turns.", impl=0)
card("blinding_bash", "Blinding Bash", G, R, "rare", 3,
     "Bash an adjacent enemy for 4. If it stands in Light, Stagger 3.", impl=2)

piece("glacial_bulwark", "Glacial Bulwark", "offhand", "epic",
      "Ice defense. Freeze the ground you hold.",
      ["hoarfrost_wall", "cold_shoulder"], "new", element="ice")
card("hoarfrost_wall", "Hoarfrost Wall", G, I, "epic", 4,
     "Gain 6 Block. Leave Ice on each tile adjacent to you, including under enemies.", impl=2)
card("cold_shoulder", "Cold Shoulder", G, I, "epic", 3,
     "Bash an adjacent enemy for 4 Ice and Push 1.", impl=0)

piece("basalt_pavise", "Basalt Pavise", "offhand", "rare",
      "Earth offhand. Plant stone cover.",
      ["plant_pavise", "stonewall_stance"], "new", element="earth")
card("plant_pavise", "Plant Pavise", G, E, "rare", 4,
     "Raise an outcrop adjacent to you. Gain 5 Block.")
card("stonewall_stance", "Stonewall Stance", G, E, "rare", 3,
     "Gain 4 Stoneskin. Follow-up: +3 Stoneskin.")

piece("grapple_hook", "Grapple Hook", "offhand", "common",
      "Reach across the room, either way.",
      ["grapple", "yank"], "new")
card("grapple", "Grapple", G, N, "common", 3,
     "Blink to a tile adjacent to an enemy, outcrop or crate within range 4.", impl=2)
card("yank", "Yank", G, N, "common", 4,
     "Pull 3 at range 4 for 2.")

# Armor --------------------------------------------------------------------
piece("patched_cloak", "Patched Cloak", "armor", "common",
      "Starter armor. One emergency patch and a blink.",
      ["patch_up", "shadow_step"], "keep")
card("patch_up", "Patch Up", G, N, "common", 2,
     "Exhaust. Heal 2. Gain 2 Block.", "keep", costs=["Exhaust"])
card("shadow_step", "Shadow Step", G, N, "common", 4,
     "Blink 3. Draw 1.", "keep")

piece("boiled_leather", "Boiled Leather", "armor", "common",
      "Plain, dependable leather.",
      ["leather_roll", "rallying_breath"], "keep")
card("leather_roll", "Leather Roll", G, N, "common", 3,
     "Move 2. Gain 6 Block.", "keep")
card("rallying_breath", "Cinch Straps", G, N, "common", 3,
     "Gain 7 Block. Draw 1.", "keep")

piece("glassbone_cuirass", "Glassbone Cuirass", "armor", "rare",
      "Fragile, strong armor that runs on health.",
      ["glassbone_guard", "last_light"], "tweak")
card("glassbone_guard", "Glassbone Guard", G, N, "rare", 4,
     "Gain 6 Stoneskin. Draw 1. Health cost 1.", "tweak", costs=["HP 1"],
     note="Weakest gear card in the pool (1.45). Same trade, now worth making.")
card("last_light", "Glass Mending", G, N, "rare", 4,
     "Exhaust. Heal 3. Gain 2 Stoneskin.", "keep", costs=["Exhaust"])

piece("undertaker_plate", "Undertaker Plate", "armor", "epic",
      "Heavy plate that punishes whoever gets close.",
      ["undertaker_stand", "grave_sprint"], "rework")
card("undertaker_stand", "Undertaker Stand", G, N, "epic", 6,
     "Gain 8 Block. Retaliate 5.", "rework",
     note="Was 10 Block and 2 Stoneskin, a bigger Brace. Now plate that makes melee enemies pay.")
card("grave_sprint", "Coffin Brace", G, N, "epic", 6,
     "Exhaust. Gain 12 Block. Heal 2.", "keep", costs=["Exhaust"])

piece("stitcher_apron", "Stitcher Apron", "armor", "common",
      "The field surgeon's apron. Patch wounds, cut bindings.",
      ["field_suture", "threadbare_guard"], "tweak")
card("field_suture", "Field Suture", G, N, "common", 2,
     "Exhaust. Heal 2. Gain 5 Block.", "keep", costs=["Exhaust"])
card("threadbare_guard", "Unpick", G, N, "common", 2,
     "Remove Bleed, Immobilize and Chilled from yourself. Gain 4 Block. Draw 1.", "rework", impl=2,
     note="Was Cinch Straps with 1 less Block, in the same slot. Now the pool's only cleanse, for Crawler, Gaoler and Lancer rooms.")

piece("cinderweave_mail", "Cinderweave Mail", "armor", "rare",
      "Fire armor for standing close.",
      ["cinderweave_guard", "cinder_patch"], "keep", element="fire")
card("cinderweave_guard", "Cinderweave Guard", G, F, "rare", 5,
     "Gain 5 Block. Strike all adjacent tiles for 2 and leave Fire there.", "keep")
card("cinder_patch", "Cinder Patch", G, F, "rare", 3,
     "Exhaust. Heal 2. Gain 4 Block. Clear Fire beneath you.", "keep", costs=["Exhaust"])

piece("rimeplate_harness", "Rimeplate Harness", "armor", "epic",
      "Ice armor that pins what it hits.",
      ["rimeplate_lock", "hoarfrost_shell"], "keep", element="ice")
card("rimeplate_lock", "Rimeplate Lock", G, I, "epic", 6,
     "Gain 3 Stoneskin and 3 Block. Deal 2 Ice at range 2. Immobilize. Leave Ice.", "keep")
card("hoarfrost_shell", "Hoarfrost Shell", G, I, "epic", 5,
     "Gain 6 Block. Leave Ice on a 2-tile line within range 2 (rotatable).", "keep")

piece("voidsilk_carapace", "Voidsilk Carapace", "armor", "legendary",
      "Shed your skin and leave it behind.",
      ["voidsilk_molt", "empty_husk"], "rework")
card("voidsilk_molt", "Voidsilk Molt", G, N, "legendary", 4,
     "Blink 3, leaving a 4-health illusion where you stood. Draw 1.", "rework", impl=2,
     note="Was an Exhaust blink with Block and draw. Now the husk you leave behind takes the hit meant for you.")
card("empty_husk", "Empty Husk", G, N, "legendary", 2,
     "Swap places with one of your illusions. Your Block moves onto it as extra health.", "rework", impl=2,
     note="Was the fifth illusion-plus-Block card. Now the escape half of the Molt pair.")

piece("thornmail", "Thornmail", "armor", "rare",
      "Barbs that answer every blow.",
      ["barbed_mail", "bristle"], "new")
card("barbed_mail", "Barbed Mail", G, N, "rare", 4,
     "Gain 5 Block. Retaliate 3 with Bleed 1.")
card("bristle", "Bristle", G, N, "rare", 2,
     "Gain 3 Stoneskin. Retaliate 2.")

piece("quarrymail", "Quarrymail", "armor", "epic",
      "Earth armor. Turn temporary defense into permanent defense.",
      ["quarry_plating", "shrug_off"], "new", element="earth")
card("quarry_plating", "Quarry Plating", G, E, "epic", 5,
     "Gain 5 Stoneskin. Leave Rubble beneath you.", impl=0)
card("shrug_off", "Shrug Off", G, E, "epic", 2,
     "Convert all your Block into Stoneskin. Draw 1.", impl=2)

piece("stormweave_robe", "Stormweave Robe", "armor", "rare",
      "Lightning armor. Shock what touches you, move faster.",
      ["static_mantle", "galvanize"], "new", element="lightning")
card("static_mantle", "Static Mantle", G, L, "rare", 4,
     "Gain 5 Block. Until your next turn, enemies that hit you in melee are Shocked.",
     note="A Retaliate variant that cancels the next attack instead of dealing damage.")
card("galvanize", "Galvanize", G, L, "rare", 1,
     "Draw 1. Quicken 2.")

piece("gale_cloak", "Gale Cloak", "armor", "common",
      "Air armor. Move freely and don't get moved.",
      ["catch_the_wind", "windbreak"], "new", element="air")
card("catch_the_wind", "Catch the Wind", G, A, "common", 2,
     "Move 3. Gain 1 Block per tile moved.", impl=2)
card("windbreak", "Windbreak", G, A, "common", 3,
     "Gain 6 Block. You can't be Pushed or Pulled until your next turn.", impl=2,
     note="An answer to Gaolers, Vaeloryx and trap pushes.")

piece("pilgrim_vestments", "Pilgrim Vestments", "armor", "common",
      "Radiance armor for deep, dark rooms.",
      ["vigil", "blessed_salve"], "new", element="radiance")
card("vigil", "Vigil", G, R, "common", 3,
     "Gain 5 Block. Gain 1 Vision for 2 turns.", impl=0)
card("blessed_salve", "Blessed Salve", G, R, "common", 3,
     "Exhaust. Heal 3. Create radius-2 Light on yourself for 2 turns.", costs=["Exhaust"], impl=0)

# Boots --------------------------------------------------------------------
piece("skirmisher_boots", "Skirmisher Boots", "boots", "common",
      "Starter boots. Step in and hit, or step in and pin.",
      ["sidestep_slash", "hamstring_shot"], "keep")
card("sidestep_slash", "Sidestep Slash", G, N, "common", 3,
     "Move 2, then strike for 5.", "keep")
card("hamstring_shot", "Low Sweep", G, N, "common", 4,
     "Move 2, then strike for 3. Immobilize.", "keep")

piece("dust_tabi", "Dust Tabi", "boots", "common",
      "Light, quick footwear.",
      ["dust_skip", "dust_glide"], "tweak")
card("dust_skip", "Dust Skip", G, N, "common", 2,
     "Blink 2. Draw 1.", "tweak",
     note="Was identical to Cloudstep Loop and one Time cheaper than Shadow Step. Now the short, cheap blink.")
card("dust_glide", "Dust Glide", G, N, "common", 2,
     "Move 3. Gain 3 Block.", "keep")

piece("trapdoor_spurs", "Trapdoor Spurs", "boots", "rare",
      "Spring over trouble and kick it into walls.",
      ["spur_vault", "hamstring_slice"], "tweak")
card("spur_vault", "Spur Vault", G, N, "rare", 4,
     "Blink 2, then kick an adjacent enemy for 4 and Push 2.", "rework",
     note="Was a 2.10 kick. The vault now lets you choose the side you kick from, so you pick the wall.")
card("hamstring_slice", "Spur Trip", G, N, "rare", 4,
     "Move 2, then strike for 5. Immobilize.", "keep")

piece("gravewind_soles", "Gravewind Soles", "boots", "epic",
      "Ghost-step in for the kill.",
      ["gravewind_step", "shadow_gate"], "tweak")
card("gravewind_step", "Gravewind Step", G, N, "epic", 4,
     "Blink 3. Gain 4 Block.", "keep")
card("shadow_gate", "Gravewind Gate", G, N, "epic", 4,
     "Blink 4. Your next attack this turn deals 3 more.", "rework", impl=2,
     note="Was Gravewind Step with 1 more Block. Two near-copies on one item.")

piece("hobnail_grips", "Hobnail Grips", "boots", "common",
      "Heavy hobnailed boots. Kick and stomp.",
      ["hobnail_drive", "heel_hook"], "tweak")
card("hobnail_drive", "Hobnail Drive", G, N, "common", 3,
     "Move 2, then kick an adjacent enemy for 3 and Push 2.", "keep")
card("heel_hook", "Heel Stomp", G, N, "common", 4,
     "Move 2, then stomp an adjacent enemy for 4. Stagger 2.", "rework",
     note="Was a common that out-scored the rare Spur Trip at the same job. Now the stomp that delays.")

piece("static_spurs", "Static Spurs", "boots", "rare",
      "Lightning boots. Wire the floor as you go.",
      ["static_pivot", "spur_spark"], "tweak", element="lightning")
card("static_pivot", "Static Pivot", G, L, "rare", 4,
     "Move 3. Leave Electrified where you arrive. Gain 3 Block.", "keep")
card("spur_spark", "Spur Spark", G, L, "rare", 2,
     "Move 2. Leave Electrified where you arrive. Quicken 1.", "tweak", note="Adds Quicken 1.")

piece("cloudstep_sandals", "Cloudstep Sandals", "boots", "epic",
      "Air boots. Stay out of reach and keep acting.",
      ["cloudstep_loop", "zephyr_feint"], "tweak", element="air")
card("cloudstep_loop", "Cloudstep Loop", G, A, "epic", 3,
     "Blink 3. If you end with no adjacent enemies, gain 1 card play.", "rework", impl=2,
     note="Was an exact copy of Dust Skip at epic. Now it pays you for kiting.")
card("zephyr_feint", "Zephyr Feint", G, A, "epic", 4,
     "Move 3. Draw 1. Gain 2 Block.", "keep")

piece("worldroot_greaves", "Worldroot Greaves", "boots", "legendary",
      "Earth legendary. Rubble as armor.",
      ["worldroot_stride", "rooted_kick"], "keep", element="earth")
card("worldroot_stride", "Worldroot Stride", G, E, "legendary", 6,
     "Move 3. Gain 4 Stoneskin, or 6 if you arrived on Rubble. Leave Rubble beneath you.", "keep")
card("rooted_kick", "Rooted Kick", G, E, "legendary", 4,
     "Move 2, then strike for 5, Push 1 and Sunder 3. Leave Rubble at the target's destination.", "keep")

piece("ironshod_sabatons", "Ironshod Sabatons", "boots", "rare",
      "Momentum boots. Moving further hits harder.",
      ["iron_wheel", "headlong"], "new")
card("headlong", "Headlong", G, N, "rare", 2,
     "Move 4. Your next attack this turn deals 1 more for each tile you moved this turn (maximum +4).",
     impl=2, note="Gives momentum to any attack, including magic.")

piece("frostwalkers", "Frostwalkers", "boots", "common",
      "Ice boots. Leave a cold trail.",
      ["glide", "rime_step"], "new", element="ice")
card("glide", "Glide", G, I, "common", 2,
     "Move 3. Leave Ice on the tile you started on.", impl=2)
card("rime_step", "Rime Step", G, I, "common", 2,
     "Move 2. Leave Ice under each adjacent enemy.", impl=2)

piece("emberstriders", "Emberstriders", "boots", "rare",
      "Fire boots. Walk through flame and leave more behind.",
      ["cinder_trail", "hotfoot"], "new", element="fire")
card("cinder_trail", "Cinder Trail", G, F, "rare", 3,
     "Move 3, leaving Fire on each tile you leave. Fire doesn't damage you this turn.", impl=2,
     note="A wall of Fire behind you. Enemies that chase you walk through it.")
card("hotfoot", "Hotfoot", G, F, "rare", 2,
     "Move 2. If you started your turn on Fire, gain 4 Block and draw 1.", impl=2)

piece("monks_wraps", "Monk's Wraps", "boots", "common",
      "Footwraps for a two-card rhythm.",
      ["flowing_step", "palm_strike"], "new")
card("flowing_step", "Flowing Step", G, N, "common", 1,
     "Move 2. Follow-up: draw 1.")
card("palm_strike", "Palm Strike", G, N, "common", 3,
     "Strike for 4. Follow-up: +3 and Push 1.")

piece("dawnwalkers", "Dawnwalkers", "boots", "rare",
      "Radiance boots. Light a path, then travel along the light.",
      ["sunpath_stride", "seek_the_light"], "new", element="radiance")
card("sunpath_stride", "Sunpath Stride", G, R, "rare", 3,
     "Move 4. Leave radius-1 Light on each tile you enter for 2 turns.", impl=2)
card("seek_the_light", "Seek the Light", G, R, "rare", 2,
     "Blink to any tile in Light within range 5.", impl=2)

# Trinkets -----------------------------------------------------------------
piece("cracked_lantern", "Cracked Lantern", "trinket", "common",
      "Starter light.", ["lantern_shot"], "tweak")
card("lantern_shot", "Lantern Shot", G, N, "common", 3,
     "Deal 3 at range 3. Create radius-2 Light at the impact for 2 turns. Draw 1.", "tweak",
     note="4 to 3 damage. Scored 4.85 as a starter, above most rewards.")

piece("ember_pendant", "Ember Pendant", "trinket", "common",
      "A small fire charm.", ["ember_tithe"], "keep", element="fire")
card("ember_tithe", "Ember Tithe", G, F, "common", 4,
     "Exhaust. Deal 3 at range 2 and leave Fire. Heal 1.", "keep", costs=["Exhaust"])

piece("clockwork_arrowhead", "Clockwork Arrowhead", "trinket", "rare",
      "A timed bolt that sets back the target's clock.", ["clockwork_mark"], "rework")
card("clockwork_mark", "Clockwork Mark", G, N, "rare", 4,
     "Deal 4 at range 3. Stagger 2. Draw 1.", "rework",
     note="Was Ricochet Knife with worse numbers. A clockwork trinket should touch the turn clock.")

piece("sealed_cyclone", "Sealed Cyclone", "trinket", "legendary",
      "A storm in a bottle, once per fight.", ["unsealed_gale"], "rework")
card("unsealed_gale", "Unsealed Gale", G, A, "legendary", 6,
     "Exhaust. Push every enemy within 3 of you 3 tiles away.", "rework", costs=["Exhaust"], impl=2,
     note="Was an Exhaust Force Seal with Push 1. Now the escape that also drives everyone into the walls.")

piece("bone_dice", "Bone Dice", "trinket", "common",
      "The gambler's charm: marks and extra plays.",
      ["loaded_toss", "snake_eyes"], "keep")
card("loaded_toss", "Loaded Toss", G, N, "common", 3,
     "Deal 2 at range 2. Draw 1. Gain 1 card play.", "keep")
card("snake_eyes", "Snake Eyes", G, N, "common", 2,
     "Exhaust. Deal 1 at range 2. Expose 6. Draw 1.", "keep", costs=["Exhaust"])

piece("rime_locket", "Rime Locket", "trinket", "rare",
      "An Ice charm.", ["locket_chill", "kept_breath"], "keep", element="ice")
card("locket_chill", "Locket Chill", G, I, "rare", 4,
     "Deal 3 Ice at range 2. Leave Ice.", "keep")
card("kept_breath", "Kept Breath", G, I, "rare", 4,
     "Gain 4 Block. Draw 1. Leave Ice on a tile within range 2.", "keep")

piece("ember_hourglass", "Ember Hourglass", "trinket", "epic",
      "Borrowed Time, paid in fire.",
      ["borrowed_spark", "cinder_second"], "tweak", element="fire")
card("borrowed_spark", "Borrowed Spark", G, F, "epic", 4,
     "Exhaust. Leave Fire on a 2-tile line within range 3. Draw 2. Gain 1 card play. Health cost 1.",
     "tweak", costs=["Exhaust", "HP 1"], note="Time 5 to 4.")
card("cinder_second", "Cinder Second", G, F, "epic", 4,
     "Gain 2 Block. Detonate 4 within range 2. Draw 1.", "keep")

piece("crown_of_thorns", "Crown of Thorns", "trinket", "legendary",
      "Blood legendary. Bleed them, and bleed for it.",
      ["thorn_crown_pact", "royal_bramble"], "rework")
card("thorn_crown_pact", "Thorn Crown Pact", G, N, "legendary", 5,
     "Rite: enemies that hit you in melee take 3 and Bleed 1. Health cost 1.", "rework",
     costs=["Rite", "HP 1"], impl=2,
     note="Was a grab bag of Stoneskin, Pierce, Bleed and Sunder. Now one permanent thorn aura, bought with blood.")
card("royal_bramble", "Royal Bramble", G, N, "legendary", 5,
     "Pull 2 at range 2 for 4. Bleed 2. Empower (1 HP): Expose 4 and Sunder 4.", "rework",
     note="Keeps its riders but moves the health payment into an optional Empower.")

piece("war_dancer_sash", "War-Dancer Sash", "trinket", "epic",
      "The Flurry trinket.", ["blade_dance", "gathering_rhythm"], "keep")
card("blade_dance", "Blade Dance", G, N, "epic", 4,
     "Flurry. Gain 2 Block, then strike for 4, once per play spent.", "keep", costs=["Flurry"])
card("gathering_rhythm", "Gathering Rhythm", G, N, "epic", 4,
     "Move 2. Draw 1. Gain 2 card plays.", "keep")

piece("geode_charm", "Geode Charm", "trinket", "common",
      "An Earth charm that grows stone.", ["geode"], "new", element="earth")
card("geode", "Geode", G, E, "common", 3,
     "Raise an outcrop within range 2. Gain 3 Stoneskin.")

piece("stormglass_orb", "Stormglass Orb", "trinket", "rare",
      "A Lightning charm for speed.", ["charged_orb"], "new", element="lightning")
card("charged_orb", "Charged Orb", G, L, "rare", 2,
     "Quicken 2. Your next Lightning attack this turn gains Chain 1.", impl=2)

piece("doppel_doll", "Doppel Doll", "trinket", "common",
      "A straw double for illusion builds.", ["straw_double"], "new")
card("straw_double", "Straw Double", G, N, "common", 2,
     "Create a 2-health illusion adjacent to you. Draw 1.", impl=0)

piece("headsmans_coin", "Headsman's Coin", "trinket", "rare",
      "A finisher's token.", ["headsmans_toll"], "new")
card("headsmans_toll", "Headsman's Toll", G, N, "rare", 2,
     "Deal 3 at range 3. If this kills, gain 1 more card play and draw 1.", impl=2,
     note="Stacks with the normal kill play: a successful toll is a 2-play refund.")

piece("gamblers_watch", "Gambler's Watch", "trinket", "epic",
      "Time trinket. Buy speed now, pay for cards later.",
      ["stolen_moment", "reprise"], "new")
card("stolen_moment", "Stolen Moment", G, N, "epic", 1,
     "Quicken 3. Draw 1.")

piece("oathstone", "Oathstone", "trinket", "common",
      "A sworn promise to hit hard.", ["sworn_oath"], "new")
card("sworn_oath", "Sworn Oath", G, N, "common", 2,
     "Gain 3 Block. Your next attack this turn deals 3 more.", impl=2)

# ---------------------------------------------------------------------------
# ITEMS (Scavenger consumables)
# ---------------------------------------------------------------------------
IT = "item"
C = ["Consume"]
card("crimson_draught", "Crimson Draught", IT, N, "common", 3, "Heal 2.", "keep", costs=C)
card("mossglass_elixir", "Mossglass Elixir", IT, N, "rare", 4, "Heal 2. Gain 1 Stoneskin.", "keep", costs=C)
card("nail_bomb", "Shrapnel Bomb", IT, N, "common", 5,
     "Deal 4 in a cross at range 3. Sunder 2.", "rework", costs=C,
     note="Was the lowest-scoring card in the game (1.19). Takes over Shrapnel Burst's job.")
card("pitch_firebomb", "Pitch Firebomb", IT, F, "rare", 5,
     "Deal 2 in a cross at range 2. Leave Fire in the cross.", "keep", costs=C)
card("frost_snare", "Frost Snare", IT, I, "rare", 5,
     "Deal 2 Ice at range 2. Immobilize. Leave Ice.", "keep", costs=C)
card("storm_jar", "Storm Jar", IT, L, "epic", 5,
     "Deal 2 Lightning at range 3. Chain 1. Hits conducted through Electrified also Shock.", "keep", costs=C)
card("smoke_bomb", "Smoke Bomb", IT, N, "common", 3, "Blink 2. Gain 2 Block.", "keep", costs=C)
card("jaw_trap", "Jaw Trap", IT, N, "common", 4,
     "Deal 2 at range 2. Immobilize.", "keep", costs=C)
card("bone_ward_charm", "Bone-Ward Charm", IT, N, "epic", 4,
     "Gain 2 Stoneskin and 3 Block.", "keep", costs=C)
card("grave_dust_satchel", "Quarry Dust", IT, E, "epic", 5,
     "Deal 2 in a cross at range 2. Pierce. Leave Rubble.", "keep", costs=C)
card("powder_keg", "Powder Keg", IT, F, "rare", 3,
     "Place a 3-health keg on an empty tile within range 2. When it's destroyed, it deals 6 to its tile and each adjacent tile.",
     costs=C, impl=2, note="A bomb enemies can set off for you. Crates and traps already teach the idea.")
card("lamp_oil", "Lamp Oil", IT, F, "common", 3,
     "Leave Fire on a 3-tile line within range 3 (rotatable).", costs=C, impl=0)
card("caltrops", "Caltrops", IT, E, "common", 3,
     "Leave Rubble in a cross within range 2. Enemies in it Bleed 2.", costs=C, impl=0)
card("hourglass_sand", "Hourglass Sand", IT, N, "rare", 2,
     "Quicken 4. Draw 1.", costs=C)
card("throwing_net", "Throwing Net", IT, N, "common", 4,
     "Immobilize an enemy within range 3. Stagger 3.", costs=C)
card("flash_powder", "Flash Powder", IT, R, "common", 3,
     "Create radius-3 Light within range 3 for 2 turns. Enemies within 2 of its center are Exposed 2.", costs=C, impl=2)
card("whetstone", "Whetstone", IT, N, "common", 2,
     "Your next attack this turn deals 4 more and Pierces.", costs=C, impl=2)
card("mirror_charm", "Mirror Charm", IT, R, "rare", 3,
     "Create a 5-health illusion within range 3.", costs=C, impl=0)
card("bottled_gale", "Bottled Gale", IT, A, "rare", 3,
     "Push each adjacent enemy 3.", costs=C, impl=2)
card("bitter_tonic", "Bitter Tonic", IT, N, "common", 2,
     "Draw 2. Gain 1 card play.", costs=C, impl=0)
card("glacier_salts", "Glacier Salts", IT, I, "common", 3,
     "Leave Ice in a cross within range 3.", costs=C, impl=0)
card("thunderstone", "Thunderstone", IT, L, "epic", 4,
     "Deal 5 Lightning to any enemy you can see, ignoring line of sight. Stagger 2.", costs=C, impl=2)
card("smelling_salts", "Smelling Salts", IT, N, "common", 3,
     "Remove Immobilize, Shock and Chilled from yourself. Move 2.", costs=C, impl=2)
card("seers_candle", "Seer's Candle", IT, R, "rare", 3,
     "Gain Truesight and 2 Vision for 2 turns.", costs=C, impl=0)
