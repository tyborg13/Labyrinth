extends RefCounted

const AttackSfxLibrary = preload("res://scripts/attack_sfx_library.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const EXPECTED_PATHS: Dictionary = {
	"fire": "res://assets/audio/sfx/elemental/fire_attack.wav",
	"earth": "res://assets/audio/sfx/elemental/earth_attack.wav",
	"air": "res://assets/audio/sfx/elemental/air_attack.wav",
	"lightning": "res://assets/audio/sfx/elemental/lightning_attack.wav",
	"ice": "res://assets/audio/sfx/elemental/ice_attack.wav"
}

static func run(expect: Callable) -> void:
	for element_id: String in EXPECTED_PATHS:
		var player_entry: Dictionary = AttackSfxLibrary.entry_for_player_action(
			{"element": element_id},
			{"type": "ranged", "range": 6, "_card_element": element_id}
		)
		expect.call(str(player_entry.get("path", "")) == str(EXPECTED_PATHS[element_id]), "%s ranged attacks should use their selected elemental sound" % element_id.capitalize())
		expect.call(FileAccess.file_exists(str(player_entry.get("path", ""))), "%s elemental sound asset should exist" % element_id.capitalize())
		expect.call(AssetLoader.load_audio_stream(str(player_entry.get("path", ""))) != null, "%s elemental sound should load as a playable audio stream" % element_id.capitalize())
		var trap_entry: Dictionary = AttackSfxLibrary.entry_for_trap({"element": element_id})
		expect.call(str(trap_entry.get("path", "")) == str(EXPECTED_PATHS[element_id]), "%s traps should use the same selected elemental sound" % element_id.capitalize())

	var generic_entry: Dictionary = AttackSfxLibrary.entry_for_player_action({}, {"type": "ranged", "range": 5})
	expect.call(str(generic_entry.get("id", "")) == AttackSfxLibrary.RANGED_SFX_ID, "Non-elemental ranged attacks should retain the bow sound")
	var melee_entry: Dictionary = AttackSfxLibrary.entry_for_player_action({"element": "fire"}, {"type": "melee", "range": 1, "_card_element": "fire"})
	expect.call(str(melee_entry.get("id", "")) == AttackSfxLibrary.MELEE_SFX_ID, "Elemental melee attacks should retain their melee sound until they receive matching authored VFX")

	var card_draw_entry: Dictionary = RunSceneScript.CARD_DRAW_SFX_ENTRY
	var card_draw_path: String = str(card_draw_entry.get("path", ""))
	var card_draw_stream: AudioStream = AssetLoader.load_audio_stream(card_draw_path)
	expect.call(card_draw_path == "res://assets/audio/sfx/card_draw_deal.wav", "Card draws should use the confirmed isolated deal transient")
	expect.call(FileAccess.file_exists(card_draw_path), "The card-draw sound asset should exist")
	expect.call(card_draw_stream != null, "The card-draw sound should load as a playable audio stream")
	if card_draw_stream != null:
		expect.call(card_draw_stream.get_length() >= 0.28 and card_draw_stream.get_length() <= 0.30, "The card-draw sound should stay tightly trimmed before the following impact")
	expect.call(float(card_draw_entry.get("volume_db", 99.0)) <= 0.0, "Card-draw playback should not boost the mastered asset above its safe level")
	var draw_state: Dictionary = {
		"player": {"hp": 10},
		"enemies": [{"id": 0, "type": "crawler", "hp": 10, "max_hp": 10}],
		"deck": {
			"draw": ["brace"],
			"hand": ["brace"],
			"discard": [],
			"draw_revision": 4
		}
	}
	var draw_before: Dictionary = draw_state.duplicate(true)
	var draw_after: Dictionary = CombatEngine.new().call("_draw_cards_in_place", draw_state, 1)
	expect.call(int((draw_after.get("deck", {}) as Dictionary).get("draw_revision", 0)) == 5, "CombatEngine should increment the semantic draw revision for every successful deck draw")
	expect.call(RunSceneScript.card_draw_sfx_count_between_states(draw_before, draw_after) == 1, "A same-ID replacement draw should still count as one card-draw sound")
	var recall_after: Dictionary = draw_before.duplicate(true)
	var recall_deck: Dictionary = recall_after.get("deck", {}) as Dictionary
	recall_deck["hand"] = ["brace", "lantern_shot"]
	recall_deck["discard"] = []
	recall_after["deck"] = recall_deck
	expect.call(RunSceneScript.card_draw_sfx_count_between_states(draw_before, recall_after) == 0, "Moving a card from discard to hand should not count as a deck-draw sound")
	expect.call(RunSceneScript.opening_hand_draw_sfx_count(draw_after) == 5, "Opening-hand cadence should use the exact number of successful initial deck draws")
	var relic_draw_transition: Dictionary = _iron_buckler_draw_transition()
	var relic_draw_before: Dictionary = relic_draw_transition.get("before", {}) as Dictionary
	var relic_draw_after: Dictionary = relic_draw_transition.get("after", {}) as Dictionary
	expect.call(
		RunSceneScript.card_draw_sfx_count_between_states(relic_draw_before, relic_draw_after) == 1,
		"Iron Buckler's real block-card reward should register one semantic draw even though the card has no draw action"
	)
	var distinct_traps: Array[Dictionary] = AttackSfxLibrary.entries_for_traps([
		{"element": "fire"},
		{"element": "fire"},
		{"element": "ice"}
	])
	expect.call(distinct_traps.size() == 2, "A simultaneous same-element trap chain should not layer duplicate copies of one sound")

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var run_scene: PackedScene = load("res://scenes/run_scene.tscn")
	expect.call(run_scene != null, "Run scene should load for live card-draw sound coverage")
	if run_scene == null:
		return
	var instance: Node = run_scene.instantiate()
	tree.root.add_child(instance)
	await tree.process_frame
	await tree.process_frame
	instance.call("_close_dialogue")
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	instance.set("_run_state", run_state)
	var generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_animate_draw_cards_fx", [])
	await tree.process_frame
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == generation_before, "An empty draw transition should stay silent")
	var draw_entries: Array = [
		{"card_id": "brace", "index": 1, "total": 3},
		{"card_id": "lantern_shot", "index": 2, "total": 3}
	]
	instance.call("_animate_draw_cards_fx", draw_entries)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == generation_before + 1, "The first draw sound should begin with the first card launch")
	await tree.create_timer(0.18).timeout
	var players: Array = instance.get("_sfx_players") as Array
	expect.call(_sfx_generation_total(players) == generation_before + 2, "A two-card draw should play exactly one staggered sound per card")
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			expect.call(player.bus == SettingsStore.SFX_BUS, "Card-draw sounds should route through the shared SFX volume bus")
	await tree.create_timer(0.20).timeout
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == generation_before + 2, "A completed draw should not schedule extra sounds")
	var replacement_before: Dictionary = {
		"player": {"hp": 10},
		"enemies": [{"id": 0, "type": "crawler", "hp": 10, "max_hp": 10}],
		"deck": {
			"draw": ["brace"],
			"hand": ["brace", "lantern_shot"],
			"discard": [],
			"draw_revision": 0
		}
	}
	var replacement_draw_state: Dictionary = replacement_before.duplicate(true)
	var replacement_draw_deck: Dictionary = replacement_draw_state.get("deck", {}) as Dictionary
	replacement_draw_deck["hand"] = ["lantern_shot"]
	replacement_draw_deck["discard"] = ["brace"]
	replacement_draw_state["deck"] = replacement_draw_deck
	var replacement_after: Dictionary = CombatEngine.new().call("_draw_cards_in_place", replacement_draw_state, 1)
	var replacement_entries: Array = instance.call("_draw_entries_between_states", replacement_before, replacement_after) as Array
	expect.call(replacement_entries.is_empty(), "The visual hand diff fixture should reproduce the same-ID replacement blind spot")
	instance.call(
		"_animate_draw_cards_fx",
		replacement_entries,
		Rect2(),
		RunSceneScript.card_draw_sfx_count_between_states(replacement_before, replacement_after)
	)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == generation_before + 3, "A semantic same-ID replacement draw should still play exactly one sound without a visual diff entry")
	await tree.create_timer(0.20).timeout
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == generation_before + 3, "A same-ID replacement draw should not schedule extra sounds")
	var relic_draw_transition: Dictionary = _iron_buckler_draw_transition()
	var relic_draw_before: Dictionary = relic_draw_transition.get("before", {}) as Dictionary
	var relic_draw_after: Dictionary = relic_draw_transition.get("after", {}) as Dictionary
	instance.call("_baseline_card_draw_sfx_revision", relic_draw_before)
	var relic_generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	var consumed_relic_draws: int = int(instance.call("_consume_pending_card_draw_sfx", relic_draw_after))
	expect.call(consumed_relic_draws == 1, "The generic sound consumer should detect Iron Buckler's non-draw-action reward")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_generation_before + 1, "Iron Buckler's real reward draw should play one sound")
	var replayed_relic_draws: int = int(instance.call("_consume_pending_card_draw_sfx", relic_draw_after))
	expect.call(replayed_relic_draws == 0, "The exact-once revision guard should consume a committed draw transition only once")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_generation_before + 1, "Revisiting the same committed relic state should stay silent")
	instance.queue_free()
	await tree.process_frame

static func _iron_buckler_draw_transition() -> Dictionary:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.create_combat(40942, _relic_draw_room(), {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["brace", "quick_stab", "lantern_shot"],
		"relics": ["iron_buckler"],
		"hand_size": 1
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["brace"]
	deck["draw"] = ["quick_stab", "lantern_shot"]
	deck["discard"] = []
	deck["draw_revision"] = 1
	state["deck"] = deck
	var before: Dictionary = state.duplicate(true)
	var after: Dictionary = combat.finish_player_card(state, 0, 1, {"play_mode": "play"})
	return {"before": before, "after": after}

static func _relic_draw_room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array[String]
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {
		"name": "Card Draw SFX Test Room",
		"coord": Vector2i(1, 0),
		"depth": 1,
		"type": "combat",
		"grid": grid,
		"player_start": Vector2i(2, 4),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(6, 2), "hp": 100, "max_hp": 100}],
		"loot": [],
		"traps": []
	}

static func _sfx_generation_total(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			total += int(player.get_meta("play_generation", 0))
	return total
