extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const InlineIcons = preload("res://scripts/inline_icon_text.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const SurfaceFixture = preload("res://tests/suites/surface_relic_suite.gd")
const SkillFixture = preload("res://tests/suites/skill_run_suite.gd")
const TIERS := {"common": 1, "rare": 2, "epic": 3, "legendary": 4}
# Authored inventory, imported from spec/relic_pool_overhaul/relic_data.py for U1.
const NEW_IDS := [
  "recoil_plates",
  "millstone_fob",
  "tallow_candle",
  "pocket_sundial",
  "leaden_pommel",
  "pitch_gloves",
  "hobnail_cleats",
  "grounding_pin",
  "rubblewalker_greaves",
  "grave_dirt",
  "waxen_effigy",
  "quick_draw_bandolier",
  "briar_vambrace",
  "fencers_gloves",
  "feint_ribbon",
  "battering_yoke",
  "pendulum_weight",
  "martyrs_gorget",
  "reliquary_box",
  "changelings_rattle",
  "copper_shod_staff",
  "ashen_phylactery",
  "bonded_set",
  "overclock_coil",
  "fetter_spikes",
  "masons_plumb",
  "breaking_wheel",
  "hollow_puppet",
  "toll_late_bell",
  "rosary_of_vows",
  "siege_ram_totem",
  "echoing_blade",
  "alchemists_retort",
  "crown_of_surplus",
  "mirror_triptych",
  "liturgy_of_ash",
  "pyre_keepers_urn",
  "briar_throne",
  "whirling_sash",
  "quartermasters_ledger"
]
const UPDATED_IDS := [
  "hourglass_awl",
  "iron_buckler",
  "coffin_nails",
  "duelist_whetstone",
  "flint_edge",
  "iron_lung",
  "hourglass_splinter",
  "chorus_mask",
  "gale_tabi",
  "mirror_shard",
  "venom_signet",
  "ember_siphon",
  "beaconrunner_spurs",
  "cold_mirror",
  "vaulting_sigil",
  "overflow_censer",
  "funeral_bell",
  "bloodmoon_chalice",
  "glassway_compass",
  "storm_crown",
  "black_sun_dial",
  "fivefold_knot",
  "borrowed_hourglass",
  "unclouded_sun",
  "unbound_pinion"
]
const REPLACEMENTS := {
  "true_north": "bonded_set",
  "dawnstitch_cord": "martyrs_gorget",
  "starless_astrolabe": "changelings_rattle",
  "voltaic_tuning_fork": "copper_shod_staff",
  "moonless_compass": "echoing_blade",
  "witchglass_lantern": "hollow_puppet",
  "glowstone_matrix": "grave_dirt",
  "hollow_die": "tallow_candle",
  "dawnbrand_filament": "fencers_gloves",
  "mossbound_wraps": "rubblewalker_greaves",
  "ion_spool": "grounding_pin",
  "cinderbrand_tongs": "pitch_gloves"
}

const AUTHORED_TEXT := {
  "hourglass_awl": "Attacks on cards that cost 6 or more @term(time) gain @kw(pierce).",
  "iron_buckler": "At the start of your turn, keep up to 3 of your @term(block).",
  "coffin_nails": "When an enemy attack hits your @term(block) and deals no @term(health) damage, the attacker gains @term(bleed) 1.",
  "duelist_whetstone": "Attacks on cards that also @kw(move) or @kw(blink) deal 1 more damage per tile you moved this turn, up to 3 more.",
  "flint_edge": "Your @kw(melee) attacks @kw(surface_consume) the @term(surface_fire), @term(surface_ice) or @term(surface_electrified) under their target to deal 3 more damage.",
  "recoil_plates": "You take 1 @kw(collision) damage per lost tile instead of 2. Whenever you are part of a @kw(collision), gain 3 @term(block).",
  "millstone_fob": "When an enemy you @kw(push) or @kw(pull) collides, the tile it stopped on becomes @term(surface_rubble).",
  "tallow_candle": "At the start of combat, create radius-2 @term(illuminate) on your tile for 3 turns.",
  "pocket_sundial": "If your turn ends with no @kw(wait), your next turn comes 2 @term(time) sooner.",
  "leaden_pommel": "Attacks on cards that cost 5 or more @term(time) gain +1 @kw(stagger).",
  "pitch_gloves": "@term(surface_fire) deals you 1 less damage. @kw(surface_fire) you create deals enemies 1 more.",
  "hobnail_cleats": "@term(surface_ice) doesn't make you @term(chilled). While you stand on @term(surface_ice), your @term(element_ice) attacks deal 2 more damage.",
  "grounding_pin": "Your single-target attacks against enemies on @term(surface_electrified) gain +1 @kw(chain).",
  "rubblewalker_greaves": "@term(surface_rubble) doesn't slow you. At the start of your turn, if you stand on @kw(surface_rubble), gain 1 @term(stoneskin).",
  "grave_dirt": "At the start of combat, gain 4 @term(stoneskin).",
  "waxen_effigy": "At the start of combat, create a 2-@term(health) @term(illusion) on the empty tile next to you nearest an enemy.",
  "quick_draw_bandolier": "Your @kw(item|Items) don't use a @term(card_play), but cost 1 more @term(time).",
  "briar_vambrace": "When a card gives you @term(block), also gain @kw(retaliate) 1, once per card.",
  "fencers_gloves": "Your second card each turn costs 1 less @term(time).",
  "iron_lung": "Every @term(health_cost), including an @kw(empower) cost, is paid from your @term(stoneskin) first, at 2 @kw(stoneskin) per @term(health).",
  "hourglass_splinter": "When you play a card that costs 6 or more @term(time), @kw(quicken) 2.",
  "chorus_mask": "A card whose element differs from the last card you played this turn deals 2 more damage and grants 2 more @term(block).",
  "gale_tabi": "After you @kw(blink), your next attack this turn deals 1 more damage per tile blinked, up to 4 more. A later @kw(blink) replaces it.",
  "mirror_shard": "When your @term(illusion) is destroyed, it shatters, dealing 3 damage to each enemy next to it.",
  "venom_signet": "Enemies standing on @term(surface_rubble) take 1 more damage from everything: attacks, @kw(collision), @term(surface_fire) and @kw(retaliate).",
  "ember_siphon": "When an enemy dies on @term(surface_fire), @kw(surface_fire) spreads to each tile next to it without @kw(surface_fire), @term(surface_ice) or @term(surface_electrified).",
  "beaconrunner_spurs": "Each tile in your @term(illuminate) you enter during a @kw(move) refunds 1 @kw(movement), up to 2 each turn.",
  "feint_ribbon": "If you've traveled 2 or more tiles this turn, your first card counts as a @kw(follow_up).",
  "battering_yoke": "When your @kw(push) or @kw(pull) slams an enemy into another, that one is knocked 1 tile the same way and can collide too.",
  "pendulum_weight": "@kw(stagger) beyond an enemy's per-turn limit is dealt to it as damage instead.",
  "martyrs_gorget": "When your @kw(retaliate) damages an attacker, gain that much @term(block).",
  "reliquary_box": "Your opening hand includes a @kw(rite) from your deck, if you have one. Each @kw(rite) costs 1 less @term(time).",
  "changelings_rattle": "When an enemy destroys your @term(illusion), that enemy suffers @kw(stagger) 3 and @term(expose) 2.",
  "copper_shod_staff": "For your @kw(element_lightning), your @kw(outcrop|Outcrops) and @term(illusion|Illusions) count as @term(surface_electrified) and take no damage from it.",
  "ashen_phylactery": "When you @kw(exhaust) a non-@kw(item) card, gain @term(stoneskin) equal to the @term(time) you paid for it, up to 5.",
  "bonded_set": "Cards from an equipment piece that shares its element with another equipped piece deal 1 more damage and grant 1 more @term(block).",
  "overclock_coil": "When you @kw(empower) a card, @kw(quicken) 2.",
  "fetter_spikes": "Enemies with @term(immobilize) take double @kw(collision) damage.",
  "masons_plumb": "Your @kw(outcrop|Outcrops) have 2 more @term(health). An enemy that collides with one of your @kw(outcrop|Outcrops) takes 2 more damage, and the @kw(outcrop) takes none.",
  "cold_mirror": "When you @term(freeze) an enemy while you have 4 or more @term(block), trade all your @kw(block) for 1 @term(frost_armor) layer per 4, up to 2.",
  "vaulting_sigil": "Your @kw(move) can pass through enemies, but not end on one. Each enemy you pass through suffers @kw(stagger) 2.",
  "overflow_censer": "When you place @term(surface_fire), @term(surface_ice) or @term(surface_electrified) over a different one, it also spreads to each tile next to it that has none.",
  "funeral_bell": "When an enemy dies with 2 or more different statuses, such as @term(bleed) and @term(expose), each enemy next to it gains them.",
  "bloodmoon_chalice": "When you lose @term(health) during your turn, your next attack this turn deals 2 more damage per @kw(health) lost, up to 8 more.",
  "glassway_compass": "Your @kw(move) and @kw(blink) can end on one of your @term(illusion|Illusions) to @kw(swap) with it, skipping the tiles between.",
  "breaking_wheel": "When an enemy collides on ground, @kw(surface_consume) it. @term(surface_fire): 3 more damage. @term(surface_ice): @term(freeze). @term(surface_electrified): @term(shock) it and enemy blockers. @term(surface_rubble): @kw(stagger) 3.",
  "hollow_puppet": "Your @kw(push) and @kw(pull) can target your @term(illusion|Illusions) harmlessly. An @kw(illusion) that collides with an enemy shatters and deals its remaining @term(health) to it instead.",
  "toll_late_bell": "Enemies set to act after your next turn on the @kw(turn_clock) are late: your attacks deal them 3 more damage.",
  "rosary_of_vows": "At the start of your turn, gain 2 @term(block) for each active @kw(rite) you have.",
  "siege_ram_totem": "When an enemy takes @kw(collision) damage, it also suffers that much @kw(stagger).",
  "echoing_blade": "When a @kw(follow_up) bonus applies, @kw(quicken) 1. Your next card this turn deals 2 more damage.",
  "alchemists_retort": "Your @kw(item|Items)' damage, @term(block), @kw(heal) and @term(stoneskin) are increased by half, rounded up.",
  "storm_crown": "Your @kw(chain) attacks rebound: after the last hop, the bolt travels back along its route, hitting each enemy again for half damage, rounded down.",
  "black_sun_dial": "Store up to 3 @kw(surface_consume|Expended) ground tiles. Your next attack releases them: +2 damage each. @term(surface_fire): @kw(surface_fire) beneath. @term(surface_ice): @term(chilled). @term(surface_electrified): @term(shock). @term(surface_rubble): @kw(stagger) 2.",
  "fivefold_knot": "Each element you play this combat ties a knot. 3 knots: your attacks @kw(pierce). 4: also @kw(chain) 1. 5: every card grants 3 @term(block).",
  "borrowed_hourglass": "The first time each combat you end your turn with a @term(card_play) unused, take another turn at once. This turn's @term(time) is added to it.",
  "unclouded_sun": "When you @kw(move), the centers of your @term(illuminate|Lights) count as next to each other.",
  "crown_of_surplus": "Cards without @kw(empower) gain one: pay 3 @term(time) to repeat the card's first action. @kw(rite|Rites), @kw(item|Items) and @kw(flurry) cards are excluded.",
  "mirror_triptych": "Up to 3 @term(illusion|Illusions) repeat your first attack each turn for half damage, rounded down. Each hits the nearest reachable enemy and loses 1 @term(health).",
  "liturgy_of_ash": "@kw(rite) cards don't use a @term(card_play).",
  "pyre_keepers_urn": "At the start of your turn, return your last @kw(exhaust|Exhausted) card to your hand, unless it is a @kw(rite) or heals.",
  "briar_throne": "Your @kw(retaliate) no longer expires, and grows by 1 each time it triggers. Cards can't give you @term(block).",
  "whirling_sash": "Gain 1 extra @term(card_play) each turn. Each card after your second each turn costs 2 more @term(time).",
  "quartermasters_ledger": "Your @kw(item|Items) @kw(exhaust) instead of @kw(consume) unless they heal, so each can be used once per combat.",
  "unbound_pinion": "Once per turn, when your @kw(push) or @kw(pull) moves an enemy 2 or more tiles or makes it collide, refill your @kw(movement) and @kw(draw) 1."
}

static func run(expect: Callable) -> void:
	_test_live_data(expect)
	_test_authored_copy(expect)
	_test_retired_definitions(expect)
	_test_offer_weights(expect)
	_test_seeded_offers(expect)
	_test_saved_run_migration(expect)
	_test_profile_gifts(expect)
	_test_claim_and_deferred_offer(expect)
	_test_hourglass_awl_threshold(expect)

static func _test_live_data(expect: Callable) -> void:
	var live_ids: Array = GameData.relic_ids()
	expect.call(live_ids.size() == 100, "U1: exactly 100 live relics")
	var names: Array[String]
	var offered_by_rarity := {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
	var exclusive_count: int = 0
	var record: String = FileAccess.get_file_as_string("res://spec/relic_pool_overhaul/relic_data.py")
	for relic_id: String in live_ids:
		var raw: Dictionary = GameData.relics()[relic_id]
		for field: String in ["name", "rarity", "description", "icon_path", "accent", "effects", "design_version", "condition_tier", "upside_tier", "build_tags"]:
			expect.call(raw.has(field), "U1 live data/%s: required field %s" % [relic_id, field])
		var name: String = str(raw.get("name", ""))
		expect.call(not name.is_empty() and not names.has(name), "U1 live data/%s: unique nonempty name" % relic_id)
		names.append(name)
		var rarity: String = str(raw.get("rarity", ""))
		expect.call(TIERS.has(rarity), "U1 live data/%s: valid rarity" % relic_id)
		expect.call(str(raw.get("accent", "")) == GameData.relic_rarity_accent(rarity), "U1 live data/%s: rarity accent" % relic_id)
		expect.call(int(raw.get("condition_tier", 0)) in [1, 2, 3, 4] and int(raw.get("upside_tier", 0)) in [1, 2, 3, 4], "U1 live data/%s: valid design tiers" % relic_id)
		expect.call((raw.get("build_tags", []) as Array).size() >= 2, "U1 live data/%s: two build tags" % relic_id)
		var description: String = str(GameData.relic_def(relic_id).get("description", ""))
		expect.call(not description.is_empty() and not description.contains("{") and InlineIcons.invalid_icon_keys(description).is_empty(), "U1 live data/%s: valid resolved copy and established icons" % relic_id)
		var icon_exists: bool = FileAccess.file_exists(str(raw.get("icon_path", "")))
		expect.call(icon_exists, "U1 live data/%s: icon exists" % relic_id)
		if NEW_IDS.has(relic_id):
			expect.call(int(raw.get("condition_tier", 0)) == int(TIERS.get(rarity, 0)) and int(raw.get("upside_tier", 0)) == int(TIERS.get(rarity, 0)), "U1 new data/%s: tiers equal rarity" % relic_id)
			expect.call(record.contains('relic("%s",' % relic_id), "U1 new data/%s: ID appears in Python design record" % relic_id)
			expect.call(int(raw.get("design_version", 0)) == 4, "U1 new data/%s: design version 4" % relic_id)
			expect.call(str(raw.get("icon_path", "")) == "res://assets/art/relics/%s.png" % relic_id, "U1 new data/%s: supplied purpose-built icon path" % relic_id)
		if bool(raw.get("exclusive_guardian", false)) or not str(raw.get("exclusive_boss", "")).is_empty():
			exclusive_count += 1
		else:
			offered_by_rarity[rarity] = int(offered_by_rarity.get(rarity, 0)) + 1
	expect.call(NEW_IDS.size() == 40, "U1: forty new IDs")
	for relic_id: String in NEW_IDS:
		expect.call(live_ids.has(relic_id), "U1 new data/%s: live inventory membership" % relic_id)
	for relic_id: String in UPDATED_IDS:
		expect.call(int(GameData.relics()[relic_id].get("design_version", 0)) == 4, "U1 updated data/%s: design version 4" % relic_id)
	expect.call(offered_by_rarity == {"common": 25, "rare": 29, "epic": 20, "legendary": 14}, "U1: 88 offered with exact 25/29/20/14 rarity mix")
	expect.call(exclusive_count == 12, "U1: twelve guardian or dragon exclusives")

static func _test_retired_definitions(expect: Callable) -> void:
	var retired_count: int = 0
	for relic_id: String in GameData.relics():
		var raw: Dictionary = GameData.relics()[relic_id]
		if not bool(raw.get("retired", false)): continue
		retired_count += 1
		var replacement: String = str(raw.get("replacement_id", ""))
		expect.call(GameData.normalized_relic_ids([relic_id, "pilgrim_boots", replacement]) == _ids(["pilgrim_boots", replacement]), "U1 retired/%s: drop alias while preserving the live ownership order" % relic_id)
		expect.call(REPLACEMENTS.get(relic_id, "") == replacement, "U1 retired/%s: authored replacement" % relic_id)
		expect.call(GameData.relic_ids().has(replacement) and not GameData.relic_ids().has(relic_id), "U1 retired/%s: valid live replacement and filtered ID" % relic_id)
		expect.call(GameData.relic_def(relic_id) == GameData.relic_def(replacement), "U1 retired/%s: definition resolves to replacement" % relic_id)
		expect.call(GameData.relic_effects(relic_id) == GameData.relic_effects(replacement), "U1 retired/%s: effect lookup resolves to replacement" % relic_id)
	expect.call(retired_count == 12, "U1: exactly twelve retired entries")
	expect.call(GameData.relic_def("unknown_u1_relic").is_empty(), "U1: unknown definitions remain empty")
	expect.call(GameData.normalized_relic_ids(["pilgrim_boots"]) == _ids(["pilgrim_boots"]), "U1: live loadouts are unchanged")

static func _test_offer_weights(expect: Callable) -> void:
	expect.call(GameData.RELIC_RARITY_OFFER_WEIGHTS == {"common": 10, "rare": 8, "epic": 6, "legendary": 5}, "U1: pin exact 10/8/6/5 offer weights")

static func _test_seeded_offers(expect: Callable) -> void:
	var engine := RunEngine.new()
	for seed_value: int in range(500):
		var choices: Array = engine._generate_relic_choices({"seed": seed_value, "relics": []}, Vector2i(2, 3))
		expect.call(choices.size() == 3 and GameData.normalized_relic_ids(choices).size() == 3, "U1 offers/seed %d: three unique live choices" % seed_value)
		for relic_id: String in choices:
			var raw: Dictionary = GameData.relics()[relic_id]
			expect.call(not bool(raw.get("retired", false)) and not bool(raw.get("exclusive_guardian", false)) and str(raw.get("exclusive_boss", "")).is_empty(), "U1 offers/seed %d: retired and trophies never offered" % seed_value)
	var blocked: Array = GameData.relic_ids()
	expect.call(engine._generate_relic_choices({"seed": 3, "relics": blocked}, Vector2i(2, 3)).is_empty(), "U1: owning the live pool yields no offers")
	for retired_id: String in REPLACEMENTS:
		var without_replacement: Array = blocked.duplicate()
		without_replacement.erase(REPLACEMENTS[retired_id])
		without_replacement.append(retired_id)
		expect.call(engine._generate_relic_choices({"seed": 3, "relics": without_replacement}, Vector2i(2, 3)).is_empty(), "U1 retired/%s: legacy ownership excludes its replacement from offers" % retired_id)

static func _test_saved_run_migration(expect: Callable) -> void:
	var previous_path: String = Store._run_storage_path
	Store.set_run_storage_path("user://relic_u1_migration.save")
	var engine := RunEngine.new()
	var base: Dictionary = engine.create_new_run(19807, Store.default_data())
	for retired_id: String in REPLACEMENTS:
		var replacement: String = REPLACEMENTS[retired_id]
		for already_owned: bool in [false, true]:
			var old: Dictionary = base.duplicate(true)
			var owned: Array = [retired_id]
			if already_owned: owned.append(replacement)
			old["relics"] = owned
			old["pending_relics"] = [retired_id, replacement, "pilgrim_boots"]
			old[RunEngine.SKILL_STATE_KEY]["pending_relic"] = retired_id
			old["combat_state"] = {"relics": owned.duplicate(), "player": {"hp": 24, "max_hp": 24}}
			old["mode"] = "combat"
			old[RunEngine.COMBAT_CONTINUATION_KEY] = [{"boundary": "u1", "state": old["combat_state"].duplicate(true)}]
			expect.call(Store.save_run_state(old), "U1 migration/%s: save legacy run" % retired_id)
			var repaired: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
			expect.call(repaired["relics"] == _ids([replacement]), "U1 migration/%s: replace owned ID without duplicates (already owned %s)" % [retired_id, already_owned])
			expect.call(repaired["combat_state"]["relics"] == _ids([replacement]), "U1 migration/%s: active combat uses live ID" % retired_id)
			expect.call(repaired[RunEngine.COMBAT_CONTINUATION_KEY][0]["state"]["relics"] == _ids([replacement]), "U1 migration/%s: checkpoint uses live ID" % retired_id)
			expect.call(repaired["pending_relics"] == _ids(["pilgrim_boots"]), "U1 migration/%s: owned replacement dropped from pending offers" % retired_id)
			expect.call(str(repaired[RunEngine.SKILL_STATE_KEY]["pending_relic"]).is_empty(), "U1 migration/%s: owned replacement dropped from Curator reserve" % retired_id)
			expect.call(Store.save_run_state(repaired), "U1 migration/%s: resave repaired run" % retired_id)
			expect.call(engine.repair_loaded_run_state(Store.load_saved_run())["relics"] == _ids([replacement]), "U1 migration/%s: resume is idempotent" % retired_id)
		var pending: Dictionary = base.duplicate(true)
		pending["pending_relics"] = [retired_id, replacement]
		pending[RunEngine.SKILL_STATE_KEY]["pending_relic"] = retired_id
		expect.call(Store.save_run_state(pending), "U1 pending/%s: save a pending legacy offer" % retired_id)
		var repaired_pending: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
		expect.call(repaired_pending["pending_relics"] == _ids([replacement]), "U1 pending/%s: unowned replacement remains one offer" % retired_id)
		expect.call(repaired_pending[RunEngine.SKILL_STATE_KEY]["pending_relic"] == replacement, "U1 pending/%s: unowned Curator reserve migrates" % retired_id)
		pending["mode"] = "treasure"
		pending["relics"] = [replacement]
		var emptied: Dictionary = engine.repair_loaded_run_state(pending)
		expect.call(emptied["mode"] == "room", "U1 pending/%s: dropping the owned offer cannot leave an empty treasure prompt" % retired_id)
	Store.clear_saved_run()
	Store.set_run_storage_path(previous_path)

static func _test_profile_gifts(expect: Callable) -> void:
	var engine := RunEngine.new()
	var previous_path: String = Store._storage_path
	Store.set_storage_path("user://relic_u1_profile.json")
	for retired_id: String in REPLACEMENTS:
		var replacement: String = REPLACEMENTS[retired_id]
		var old: Dictionary = Store.default_data()
		old[Store.STARTING_RELIC_GIFTS_KEY] = [{"id": "old_award", "relic_id": retired_id}]
		# Write the old profile directly, to exercise load normalization itself.
		var file := FileAccess.open(Store._storage_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(old))
		file.close()
		var profile: Dictionary = Store.load_data()
		expect.call(profile[Store.STARTING_RELIC_GIFTS_KEY][0]["relic_id"] == replacement, "U1 gift/%s: profile load migrates starting gift" % retired_id)
		var run_state: Dictionary = engine.create_new_run(19807, profile)
		expect.call(run_state["relics"] == [replacement], "U1 gift/%s: new run grants the live replacement" % retired_id)
		old[Store.STARTING_RELIC_GIFTS_KEY].append({"id": "live_award", "relic_id": replacement})
		var gifts: Array = Store.normalized_data(old)[Store.STARTING_RELIC_GIFTS_KEY]
		expect.call(gifts.size() == 1 and gifts[0]["id"] == "live_award", "U1 gift/%s: preserve live gift and drop retired duplicate" % retired_id)
		var awarded: Dictionary = Store.award_starting_relic_gift(Store.default_data(), "new_award", retired_id)
		expect.call(awarded[Store.STARTING_RELIC_GIFTS_KEY][0]["relic_id"] == replacement, "U1 gift/%s: new awards never store retired IDs" % retired_id)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Store._storage_path))
	Store.set_storage_path(previous_path)

static func _test_claim_and_deferred_offer(expect: Callable) -> void:
	var engine := RunEngine.new()
	for retired_id: String in REPLACEMENTS:
		var replacement: String = REPLACEMENTS[retired_id]
		var old: Dictionary = engine.create_new_run(19807, Store.default_data())
		old["pending_relics"] = [retired_id]
		old["mode"] = "treasure"
		var claimed: Dictionary = engine.claim_relic(old, retired_id)
		expect.call(claimed["relics"] == _ids([replacement]), "U1 claim/%s: legacy offers grant a live ID" % retired_id)
	var run_state: Dictionary = SkillFixture._new_run(engine, ["curators_patience"])
	run_state["mode"] = "treasure"
	run_state["pending_relics"] = ["pilgrim_boots", "true_north"]
	var claimed: Dictionary = engine.claim_relic(run_state, "pilgrim_boots", "true_north")
	expect.call(claimed[RunEngine.SKILL_STATE_KEY]["pending_relic"] == "bonded_set", "U1: Curator saves the live ID when deferring a legacy offer")
	# Real treasure entry uses the normalized reserve alongside ordinary offers.
	var origin := Vector2i(3, 0)
	var destination := Vector2i(3, 1)
	claimed = SkillFixture._with_room(claimed, origin, "treasure", true)
	claimed = SkillFixture._with_room(claimed, destination, "treasure", false)
	claimed["current_room"] = origin
	claimed[RunEngine.SKILL_STATE_KEY]["pending_relic"] = "true_north"
	var entered: Dictionary = engine.move_to_room(claimed, destination)
	expect.call(entered.get("current_room") == destination and (entered.get("pending_relics", []) as Array).has("bonded_set"), "U1: actual treasure entry inserts the live Curator reserve")
	expect.call(not (entered.get("pending_relics", []) as Array).has("true_north"), "U1: deferred offer path never offers retired IDs")

static func _test_hourglass_awl_threshold(expect: Callable) -> void:
	for card_id: String in ["blood_price", "butcher_chop"]:
		var base: Dictionary = GameData.card_def(card_id)
		var transformed: Dictionary = GameData.card_def_for_progression(card_id, {"relics": ["hourglass_awl"]})
		var expected_pierce: bool = int(base["time"]) >= 6
		expect.call(bool(transformed["actions"][0].get("pierce", false)) == expected_pierce, "U1 Hourglass Awl/%s: exact 6+ Time boundary" % card_id)
		var combat := Combat.new()
		var state: Dictionary = SurfaceFixture.fixture(combat, ["hourglass_awl"])
		state["player"]["pos"] = Vector2i(3, 3)
		state["enemies"][0]["hp"] = 100
		state["enemies"][0]["block"] = 20
		var action: Dictionary = transformed["actions"][0]
		var forecast: Dictionary = combat.surface_preview_for_player_action(state, action, Vector2i(4, 3), true)
		var committed: Dictionary = combat.apply_player_action(state, action, Vector2i(4, 3))
		expect.call(forecast.get("state") == committed, "U1 Hourglass Awl/%s: forecast equals commit" % card_id)
		if expected_pierce:
			expect.call(int(committed["enemies"][0]["hp"]) == 100 - int(action["damage"]) and int(committed["enemies"][0]["block"]) == 20, "U1 Hourglass Awl/%s: qualifying attack bypasses Block" % card_id)
		else:
			expect.call(int(committed["enemies"][0]["hp"]) == 100, "U1 Hourglass Awl/%s: under-threshold attack remains blocked" % card_id)
	var no_awl: Dictionary = GameData.card_def_for_progression("blood_price", {})
	expect.call(not bool(no_awl["actions"][0].get("pierce", false)), "U1 Hourglass Awl: relic absent leaves six-Time attack unchanged")

static func _ids(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values: result.append(str(value))
	return result

static func _test_authored_copy(expect: Callable) -> void:
	var approved: Dictionary = {}
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/text/relic_rewrite.json")):
		approved[str(row["id"])] = str(row["description"])
	for relic_id: String in AUTHORED_TEXT:
		var text: String = AUTHORED_TEXT[relic_id]
		expect.call(approved[relic_id] == text, "U1 exact copy/%s: authored text matches the approved UX-04 record" % relic_id)
		var markup: String = str(GameData.relic_def(relic_id).get("description", ""))
		expect.call(markup == text, "U1 exact copy/%s: preserve every word, token, number and punctuation mark" % relic_id)
	# An inline icon stands alone: letters glued to it ("@icon(stagger)ed",
	# "@icon(illusion)s") render as a glyph followed by a stray suffix.
	var glued := RegEx.new()
	glued.compile("@icon\\([a-z0-9_]+\\)['A-Za-z]")
	for relic_id: String in GameData.relic_ids():
		var description: String = str(GameData.relic_def(relic_id).get("description", ""))
		expect.call(glued.search(description) == null, "U1 icon text/%s: no letters attached to an inline icon" % relic_id)
