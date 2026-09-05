extends RefCounted

const AttackSfxLibrary = preload("res://scripts/attack_sfx_library.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const PostCombatRewardSequence = preload("res://scripts/post_combat_reward_sequence.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const RunSfxLibrary = preload("res://scripts/run_sfx_library.gd")
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
	var card_play_entry: Dictionary = RunSceneScript.CARD_PLAY_SFX_ENTRY
	var card_play_path: String = str(card_play_entry.get("path", ""))
	var card_play_stream: AudioStream = AssetLoader.load_audio_stream(card_play_path)
	expect.call(card_play_path == "res://assets/audio/sfx/card_play_take.wav", "Confirmed card plays should use the supplied taking-card transient")
	expect.call(FileAccess.file_exists(card_play_path), "The card-play sound asset should exist")
	expect.call(card_play_stream != null, "The card-play sound should load as a playable audio stream")
	if card_play_stream != null:
		expect.call(card_play_stream.get_length() >= 0.21 and card_play_stream.get_length() <= 0.23, "The card-play sound should stay tightly trimmed to the card-to-center motion")
	expect.call(str(card_play_entry.get("bus", "")) == SettingsStore.UI_SFX_BUS, "Card-play confirmation should use the dry UI SFX path")
	expect.call(float(card_play_entry.get("volume_db", 99.0)) <= 0.0, "Card-play playback should not boost the mastered asset above its safe level")
	var reward_flip_entry: Dictionary = RunSceneScript.REWARD_CARD_FLIP_SFX_ENTRY
	var reward_flip_path: String = str(reward_flip_entry.get("path", ""))
	var reward_flip_stream: AudioStream = AssetLoader.load_audio_stream(reward_flip_path)
	expect.call(reward_flip_path == "res://assets/audio/sfx/reward_card_flip.wav", "Reward cards should use the isolated final flip from the supplied shuffle track")
	expect.call(FileAccess.file_exists(reward_flip_path), "The reward-card flip sound asset should exist")
	expect.call(reward_flip_stream != null, "The reward-card flip sound should load as a playable audio stream")
	if reward_flip_stream != null:
		expect.call(reward_flip_stream.get_length() >= 0.27 and reward_flip_stream.get_length() <= 0.29, "The reward-card flip should stay tightly trimmed around the final discrete source sound")
	expect.call(str(reward_flip_entry.get("bus", "")) == SettingsStore.UI_SFX_BUS, "Reward-card flips should use the dry UI SFX path")
	expect.call(float(reward_flip_entry.get("volume_db", 99.0)) <= 0.0, "Reward-card flip playback should not boost the mastered asset above its safe level")
	_expect_ui_sfx_asset(expect, RunSceneScript.ITEM_EQUIP_SFX_ENTRY, "res://assets/audio/sfx/item_equip.wav", 0.52, 0.54, "Item equip")
	_expect_ui_sfx_asset(expect, RunSfxLibrary.entry(RunSfxLibrary.REWARD_ACCEPTED_ID), "res://assets/audio/sfx/run/reward_accepted.wav", 4.85, 4.88, "Reward accepted")
	_expect_ui_sfx_asset(expect, RunSceneScript.RELIC_CHOICES_OPEN_SFX_ENTRY, "res://assets/audio/sfx/relic_choices_open.wav", 2.44, 2.46, "Relic choices open")
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
	instance.call("_play_card_play_sfx")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == generation_before + 1, "A confirmed card play should start exactly one taking-card sound")
	var card_play_players: Array = instance.get("_sfx_players") as Array
	for player_var: Variant in card_play_players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null and player.stream != null:
			expect.call(player.bus == SettingsStore.UI_SFX_BUS, "The active card-play sound should stay on the dry UI SFX path")
	await tree.create_timer(0.24).timeout
	var draw_generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	var draw_entries: Array = [
		{"card_id": "brace", "index": 1, "total": 3},
		{"card_id": "lantern_shot", "index": 2, "total": 3}
	]
	instance.call("_animate_draw_cards_fx", draw_entries)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == draw_generation_before + 1, "The first draw sound should begin with the first card launch")
	await tree.create_timer(0.18).timeout
	var players: Array = instance.get("_sfx_players") as Array
	expect.call(_sfx_generation_total(players) == draw_generation_before + 2, "A two-card draw should play exactly one staggered sound per card")
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			expect.call(player.bus == SettingsStore.UI_SFX_BUS, "Card-draw sounds should use the dry UI SFX path while inheriting shared SFX volume")
	await tree.create_timer(0.20).timeout
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == draw_generation_before + 2, "A completed draw should not schedule extra sounds")
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
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == draw_generation_before + 3, "A semantic same-ID replacement draw should still play exactly one sound without a visual diff entry")
	await tree.create_timer(0.20).timeout
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == draw_generation_before + 3, "A same-ID replacement draw should not schedule extra sounds")
	var relic_draw_transition: Dictionary = _iron_buckler_draw_transition()
	var relic_draw_before: Dictionary = relic_draw_transition.get("before", {}) as Dictionary
	var relic_draw_after: Dictionary = relic_draw_transition.get("after", {}) as Dictionary
	instance.call("_baseline_card_draw_sfx_revision", relic_draw_before)
	var relic_generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	var consumed_relic_draws: int = int(instance.call("_consume_pending_card_draw_sfx", relic_draw_after))
	expect.call(consumed_relic_draws == 1, "The generic sound consumer should detect Iron Buckler's non-draw-action reward")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_generation_before + 1, "Iron Buckler's real reward draw should play one sound")
	var stale_relic_draws: int = int(instance.call("_consume_pending_card_draw_sfx", relic_draw_before))
	expect.call(stale_relic_draws == 0, "Observing an older combat state should not rewind the exact-once draw cursor")
	var replayed_relic_draws: int = int(instance.call("_consume_pending_card_draw_sfx", relic_draw_after))
	expect.call(replayed_relic_draws == 0, "Revisiting a committed draw after a stale observation should stay silent")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_generation_before + 1, "Out-of-order state observations should not replay a committed relic draw")
	await _test_reward_flip_sequence(instance, tree, expect)
	await _test_ui_feedback_actions(instance, tree, expect)
	instance.queue_free()
	await tree.process_frame

static func _expect_ui_sfx_asset(expect: Callable, entry: Dictionary, expected_path: String, min_length: float, max_length: float, label: String) -> void:
	var path: String = str(entry.get("path", ""))
	var stream: AudioStream = AssetLoader.load_audio_stream(path)
	expect.call(path == expected_path, "%s should use its authored trimmed asset" % label)
	expect.call(FileAccess.file_exists(path), "%s sound asset should exist" % label)
	expect.call(stream != null, "%s sound should load as a playable audio stream" % label)
	if stream != null:
		expect.call(stream.get_length() >= min_length and stream.get_length() <= max_length, "%s should retain its intentional trimmed duration" % label)
	expect.call(str(entry.get("bus", "")) == SettingsStore.UI_SFX_BUS, "%s should use the dry UI SFX path" % label)
	expect.call(float(entry.get("volume_db", 99.0)) <= 0.0, "%s playback should not boost the mastered asset above its safe level" % label)

static func _test_ui_feedback_actions(instance: Node, tree: SceneTree, expect: Callable) -> void:
	var engine := RunEngine.new()
	var loadout_state: Dictionary = engine.create_new_run(6904, ProgressionStore.default_data())
	loadout_state["mode"] = "room"
	loadout_state["equipment_inventory"] = ["ward_kite"]
	loadout_state["magic_inventory"] = ["spark_dart"]
	loadout_state["attuned_magic_cards"] = ["pale_spark"]
	loadout_state["item_inventory"] = ["crimson_draught"]
	loadout_state["equipped_items"] = []
	instance.call("_load_run_state", loadout_state)
	await tree.process_frame
	await tree.process_frame

	instance.set("_progression_overlay_mode", "equipment")
	var equipment_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_equip_equipment_from_overlay", "ward_kite")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == equipment_before + 1, "A successful equipment swap should play exactly one item-equip cue")
	await instance.call("_equip_equipment_from_overlay", "ward_kite")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == equipment_before + 1, "Re-equipping the already active equipment should stay silent")

	instance.set("_progression_overlay_mode", "magic")
	var magic_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_swap_magic_from_overlay", 0, 0)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == magic_before + 1, "A successful magic attunement should play exactly one item-equip cue")
	await instance.call("_swap_magic_from_overlay", -1, 0)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == magic_before + 1, "An invalid magic swap should stay silent")

	instance.set("_progression_overlay_mode", "equipment")
	var item_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_equip_item_from_overlay", 0)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == item_before + 1, "A successful item equip should play exactly one item-equip cue")
	await instance.call("_equip_item_from_overlay", 0)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == item_before + 1, "Equipping from an empty item slot should stay silent")

	var reward_state: Dictionary = engine.create_new_run(31233, ProgressionStore.default_data())
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["spark_dart"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0,
		"intro_pending": false
	}
	instance.call("_load_run_state", reward_state)
	await tree.process_frame
	await tree.process_frame
	var reward_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_on_reward_card_pressed", "spark_dart")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == reward_before + 1, "Claiming a post-combat card should start exactly one reward-collect cue with its acquisition animation")
	await instance.call("_on_reward_card_pressed", "spark_dart")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == reward_before + 1, "A stale post-combat card activation should stay silent")

	var treasure_state: Dictionary = engine.create_new_run(44698, ProgressionStore.default_data())
	treasure_state["mode"] = "treasure"
	treasure_state["current_room"] = Vector2i(2, 1)
	treasure_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	var treasure_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_load_run_state", treasure_state)
	await tree.process_frame
	await tree.process_frame
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == treasure_before + 1, "A relic offer should play the loot-open cue once as its choices appear")
	instance.call("_refresh_choice_bar")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == treasure_before + 1, "Refreshing the same relic offer should not replay the loot-open cue")
	var relic_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_on_relic_pressed", "iron_lung")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_before + 1, "Claiming a relic should start exactly one reward-collect cue with its acquisition animation")
	await instance.call("_on_relic_pressed", "iron_lung")
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_before + 1, "A stale relic activation should stay silent")

	for player_var: Variant in instance.get("_sfx_players") as Array:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null and player.stream != null:
			expect.call(player.bus == SettingsStore.UI_SFX_BUS, "Active equip and reward feedback should stay on the dry UI SFX path")

static func _test_reward_flip_sequence(instance: Node, tree: SceneTree, expect: Callable) -> void:
	var host := Control.new()
	host.name = "RewardFlipSoundTestHost"
	instance.add_child(host)
	var banner := TextureRect.new()
	host.add_child(banner)
	var title := Label.new()
	host.add_child(title)
	var secondary_actions := Control.new()
	host.add_child(secondary_actions)
	PostCombatRewardSequence.prepare_banner(banner, title)
	PostCombatRewardSequence.prepare_secondary_actions(secondary_actions)
	var slots: Array[Control] = []
	for index: int in range(3):
		slots.append(_reward_flip_slot(host, index))
	var generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	var reveal_started: int = Time.get_ticks_msec()
	await PostCombatRewardSequence.play_reward_reveal(
		host,
		banner,
		title,
		slots,
		secondary_actions,
		false,
		Callable(instance, "_play_reward_card_flip_sfx")
	)
	expect.call(Time.get_ticks_msec() - reveal_started < 1250, "Three reward cards should become readable together without a serialized flip queue")
	for slot: Control in slots:
		expect.call((slot.find_child("CardWidget", true, false) as Control).visible, "Every reward face must be visible before reveal completes")
	var players: Array = instance.get("_sfx_players") as Array
	expect.call(_sfx_generation_total(players) == generation_before + slots.size(), "An animated three-card reward reveal should play exactly one flip sound per card")
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null and player.stream != null:
			expect.call(player.bus == SettingsStore.UI_SFX_BUS, "Every active reward-card flip should stay on the dry UI SFX path")

	var reduced_host := Control.new()
	reduced_host.name = "ReducedMotionRewardFlipSoundTestHost"
	instance.add_child(reduced_host)
	var reduced_slots: Array[Control] = []
	for index: int in range(3):
		reduced_slots.append(_reward_flip_slot(reduced_host, index))
	var reduced_generation_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await PostCombatRewardSequence.play_reward_reveal(
		reduced_host,
		null,
		null,
		reduced_slots,
		null,
		true,
		Callable(instance, "_play_reward_card_flip_sfx")
	)
	expect.call(_sfx_generation_total(instance.get("_sfx_players") as Array) == reduced_generation_before, "Reduced motion should settle reward cards without implying three animated flips through audio")
	host.queue_free()
	reduced_host.queue_free()
	await tree.process_frame

static func _reward_flip_slot(host: Control, index: int) -> Control:
	var slot := Control.new()
	slot.name = "RewardFlipSoundSlot%d" % index
	host.add_child(slot)
	var scaler := Control.new()
	scaler.name = PostCombatRewardSequence.CARD_FRAME_NAME
	slot.add_child(scaler)
	scaler.set_meta("reward_reveal_base_position", Vector2.ZERO)
	scaler.set_meta("reward_reveal_base_scale", Vector2.ONE)
	scaler.position = Vector2(0.0, 58.0)
	var widget := Control.new()
	widget.name = "CardWidget"
	widget.visible = false
	scaler.add_child(widget)
	var back := TextureRect.new()
	back.name = PostCombatRewardSequence.CARD_BACK_NAME
	scaler.add_child(back)
	slot.modulate = Color(1.0, 1.0, 1.0, 0.0)
	return slot

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
