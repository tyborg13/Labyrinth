extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/card_playability_summary_suite.gd")
var failures: Array[String]
var comparisons: int = 0
# Frozen pre-optimization algorithms; deliberately exercise independent copy and
# presentation-list paths rather than deriving expected results from the changes.
class OriginalRunEngine:
	extends RunEngine

	func set_combat_state(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
		var next_state: Dictionary = run_state.duplicate(true)
		next_state["combat_state"] = combat_state.duplicate(true)
		next_state["run_stats"] = CombatEngineScript.normalized_run_stats(combat_state.get("run_stats", next_state.get("run_stats", {})))
		next_state["player_hp"] = int((combat_state.get("player", {}) as Dictionary).get("hp", next_state.get("player_hp", 1)))
		next_state[DEFIANCE_CAPACITY_KEY] = maxi(0, int(combat_state.get(DEFIANCE_CAPACITY_KEY, next_state.get(DEFIANCE_CAPACITY_KEY, 0))))
		next_state[DEFIANCE_REMAINING_KEY] = clampi(
			int(combat_state.get(DEFIANCE_REMAINING_KEY, next_state.get(DEFIANCE_REMAINING_KEY, 0))),
			0,
			int(next_state.get(DEFIANCE_CAPACITY_KEY, 0))
		)
		next_state = _apply_recovered_embers_from_combat(next_state, combat_state)
		next_state = _apply_collected_equipment_from_combat(next_state, combat_state)
		# Combat owns pickup/consumption transactions, including duplicate copies.
		# Copying the snapshot is idempotent across checkpoints, finish and reload.
		if combat_state.has("equipped_items"):
			next_state["equipped_items"] = _item_card_array(combat_state.get("equipped_items", []))
			next_state["item_inventory"] = _item_card_array(combat_state.get("item_inventory", []))
			next_state = _rebuild_deck_cards(next_state)
			for loot: Dictionary in BattlefieldItemRules.pickups_between(run_state.get("combat_state", {}), combat_state):
				var card_id: String = str(loot.get("card_id", ""))
				if next_state["equipped_items"].has(card_id) or next_state["item_inventory"].has(card_id):
					next_state = _mark_loadout_unread(next_state, "equipment", card_id)
		return next_state

	func _repair_equipment_state(run_state: Dictionary) -> Dictionary:
		var next_state: Dictionary = run_state.duplicate(true)
		var equipped: Dictionary = (next_state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
		if equipped.is_empty():
			equipped = GameData.starting_equipped_equipment()
		for slot: String in GameData.equipment_slots():
			if not equipped.has(slot):
				equipped[slot] = str(GameData.starting_equipped_equipment().get(slot, ""))
		next_state["equipped_equipment"] = equipped
		if not next_state.has("equipment_inventory"):
			next_state["equipment_inventory"] = []
		next_state[UNREAD_LOADOUT_EQUIPMENT_KEY] = _string_array(next_state.get(UNREAD_LOADOUT_EQUIPMENT_KEY, []))
		next_state[UNREAD_LOADOUT_MAGIC_KEY] = _string_array(next_state.get(UNREAD_LOADOUT_MAGIC_KEY, []))
		next_state[NEW_LOADOUT_EQUIPMENT_KEY] = _string_array(next_state.get(NEW_LOADOUT_EQUIPMENT_KEY, []))
		next_state[NEW_LOADOUT_MAGIC_KEY] = _string_array(next_state.get(NEW_LOADOUT_MAGIC_KEY, []))
		if not next_state.has("collected_equipment"):
			var collected: Array = []
			for slot: String in GameData.equipment_slots():
				var equipped_id: String = str(equipped.get(slot, ""))
				if not equipped_id.is_empty() and not collected.has(equipped_id):
					collected.append(equipped_id)
			for equipment_var: Variant in next_state.get("equipment_inventory", []):
				var inventory_id: String = str(equipment_var)
				if not inventory_id.is_empty() and not collected.has(inventory_id):
					collected.append(inventory_id)
			next_state["collected_equipment"] = collected
		if not next_state.has("reward_cards"):
			next_state["reward_cards"] = _migrated_reward_cards_from_deck(next_state.get("deck_cards", []), equipped)
		next_state = _repair_magic_state(next_state)
		next_state = _repair_item_state(next_state)
		return _rebuild_deck_cards(next_state)

	func _repair_magic_state(run_state: Dictionary) -> Dictionary:
		var next_state: Dictionary = run_state.duplicate(true)
		var reward_cards: Array = _string_array(next_state.get("reward_cards", []))
		next_state["reward_cards"] = reward_cards
		if not next_state.has("attuned_magic_cards") and not next_state.has("magic_inventory"):
			var migrated_magic: Dictionary = _magic_loadout_from_collected_rewards(reward_cards)
			next_state["attuned_magic_cards"] = migrated_magic.get("attuned_magic_cards", [])
			next_state["magic_inventory"] = migrated_magic.get("magic_inventory", [])
			return next_state
		var attuned: Array = _string_array(next_state.get("attuned_magic_cards", []))
		var inventory: Array = _string_array(next_state.get("magic_inventory", []))
		var limit: int = GameData.magic_loadout_limit()
		if attuned.size() > limit:
			for index: int in range(limit, attuned.size()):
				inventory.append(str(attuned[index]))
			while attuned.size() > limit:
				attuned.pop_back()
		attuned = _filled_attuned_magic(attuned)
		next_state["attuned_magic_cards"] = attuned
		next_state["magic_inventory"] = inventory
		return next_state

	func _repair_item_state(run_state: Dictionary) -> Dictionary:
		var next_state: Dictionary = run_state.duplicate(true)
		var inventory: Array = _item_card_array(next_state.get("item_inventory", []))
		var equipped: Array = _item_card_array(next_state.get("equipped_items", []))
		var limit: int = GameData.item_loadout_limit()
		if equipped.size() > limit:
			for index: int in range(limit, equipped.size()):
				inventory.append(str(equipped[index]))
			while equipped.size() > limit:
				equipped.pop_back()
		next_state["item_inventory"] = inventory
		next_state["equipped_items"] = equipped
		return next_state

	func _rebuild_deck_cards(run_state: Dictionary) -> Dictionary:
		var next_state: Dictionary = run_state.duplicate(true)
		next_state["deck_cards"] = GameData.compile_deck_cards(
			next_state.get("equipped_equipment", {}) as Dictionary,
			next_state.get("attuned_magic_cards", []) as Array,
			next_state.get("equipped_items", []) as Array,
			next_state
		)
		return next_state

	func _apply_collected_equipment_from_combat(run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
		var next_state: Dictionary = _repair_equipment_state(run_state)
		var added_names: Array = []
		for equipment_var: Variant in combat_state.get("collected_equipment", []):
			var equipment_id: String = str(equipment_var)
			if equipment_id.is_empty() or _run_has_equipment(next_state, equipment_id):
				continue
			var inventory: Array = next_state.get("equipment_inventory", []).duplicate()
			inventory.append(equipment_id)
			next_state["equipment_inventory"] = inventory
			var collected: Array = next_state.get("collected_equipment", []).duplicate()
			if not collected.has(equipment_id):
				collected.append(equipment_id)
			next_state["collected_equipment"] = collected
			next_state = _mark_loadout_unread(next_state, "equipment", equipment_id)
			added_names.append(str(GameData.equipment_def(equipment_id).get("name", equipment_id)))
		if not added_names.is_empty():
			next_state["notice"] = "Found %s." % ", ".join(added_names)
		return next_state

class OriginalCombatEngine:
	extends CombatEngine

	func is_tile_visible_to_player(state: Dictionary, tile: Vector2i, visible_lookup: Dictionary = {}) -> bool:
		if not visible_lookup.is_empty():
			return visible_lookup.has(tile)
		if effective_umbra_radius(state) >= UMBRA_UNLIMITED_RADIUS:
			return true
		return umbra_visible_tiles(state).has(tile)

	func umbra_visible_tiles(state: Dictionary) -> Array[Vector2i]:
		var result: Array[Vector2i] = []
		var grid: Array = state.get("grid", [])
		var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
		var personal_radius: int = effective_umbra_radius(state)
		var sources: Array[Dictionary] = _effective_light_sources(state)
		for y: int in range(grid.size()):
			var row: Array = grid[y] as Array
			for x: int in range(row.size()):
				var tile := Vector2i(x, y)
				var visible: bool = personal_radius >= UMBRA_UNLIMITED_RADIUS or PathUtils.manhattan(player_pos, tile) <= personal_radius
				if not visible:
					for source: Dictionary in sources:
						var source_pos: Vector2i = source.get("pos", Vector2i(-999, -999))
						if PathUtils.manhattan(source_pos, tile) <= maxi(0, int(source.get("radius", 0))):
							visible = true
							break
				if visible:
					result.append(tile)
		return result

	func has_skill(state: Dictionary, skill_id: String) -> bool:
		return skill_ids(state).has(skill_id)

	func is_enemy_visible_to_player(state: Dictionary, enemy: Dictionary, visible_lookup: Dictionary = {}) -> bool:
		if int(enemy.get("hp", 0)) <= 0:
			return false
		var definition: Dictionary = GameData.enemy_def(str(enemy.get("type", "")))
		if bool(definition.get("boss_bar", false)):
			return true
		if _player_has_truesight(state):
			return true
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			if is_tile_visible_to_player(state, tile, visible_lookup):
				return true
		return false

	func _illusion_light_radius(state: Dictionary) -> int:
		return _illusion_light_radius_from_contributors(_illusion_light_contributors(state))

	func _light_source_umbra_suppression(state: Dictionary) -> int:
		var source_count: int = _effective_light_sources(state).size()
		var suppression: int = 0
		for effect: Dictionary in _relic_effects(state):
			if str(effect.get("type", "")) != "light_source_umbra_suppression":
				continue
			var thresholds: Array = effect.get("thresholds", []) as Array
			var stages: Array = effect.get("stages", []) as Array
			for index: int in range(mini(thresholds.size(), stages.size())):
				if source_count >= int(thresholds[index]):
					suppression = maxi(suppression, int(stages[index]))
		return suppression

	func _light_source_covers_tile(state: Dictionary, tile: Vector2i) -> bool:
		for source: Dictionary in _effective_light_sources(state):
			if PathUtils.manhattan(source.get("pos", INVALID_TILE), tile) <= maxi(0, int(source.get("radius", 0))):
				return true
		return false

class OriginalRunScene:
	extends RunScene

	func _card_widget_display(card_id: String, state: Dictionary) -> Dictionary:
		var card: Dictionary = _card_def(card_id, state)
		var summary_rows: Array = ActionIcons.cost_rows_for_card(card)
		var modifier_lines: PackedStringArray = []
		var preview_state: Dictionary = state.duplicate(true)
		var previous_action_row_index: int = -1
		for action_var: Variant in card.get("actions", []):
			var action: Dictionary = action_var
			var action_type: String = str(action.get("type", ""))
			var row: Array = []
			match action_type:
				"melee", "ranged", "aoe", "detonate":
					var attack_final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
					var attack_damage_modifiers: Array[Dictionary] = _combat_engine.damage_modifiers_for_player_action(preview_state, action)
					var attack_visible_modifiers: Array[Dictionary] = attack_damage_modifiers
					row = ActionIcons.tokens_for_action(action, {
						"final_damage": attack_final_damage,
						"tone_base_damage": _damage_tone_base_excluding_modifiers(attack_final_damage, attack_visible_modifiers, action),
						"damage_modifiers": attack_visible_modifiers
					})
					_consume_preview_damage_modifiers(preview_state, action)
				"push", "pull":
					var shove_final_damage: int = _combat_engine.final_damage_for_player_action(preview_state, action)
					var shove_damage_modifiers: Array[Dictionary] = _combat_engine.damage_modifiers_for_player_action(preview_state, action)
					var shove_visible_modifiers: Array[Dictionary] = shove_damage_modifiers
					row = ActionIcons.tokens_for_action(action, {
						"final_damage": shove_final_damage,
						"tone_base_damage": _damage_tone_base_excluding_modifiers(shove_final_damage, shove_visible_modifiers, action),
						"damage_modifiers": shove_visible_modifiers
					})
					_consume_preview_damage_modifiers(preview_state, action)
				_:
					row = ActionIcons.tokens_for_action(action)
			var annotated_row: Array = row
			previous_action_row_index = ActionIcons.append_action_row(summary_rows, action, annotated_row, previous_action_row_index)
			var bonus_row: Array = ActionIcons.tokens_for_surface_bonus(action)
			if not bonus_row.is_empty():
				summary_rows.append(bonus_row)
		var summary_text: String = ActionIcons.plain_text_for_rows(summary_rows)
		if summary_text.is_empty():
			summary_text = str(card.get("description", ""))
		return {
			"summary_bbcode": summary_text,
			"summary_rows": summary_rows,
			"modifier_lines": modifier_lines
		}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_test_checkpoints()
	_test_visibility_and_display()
	_test_hud_queries()
	_test_rule_lookup_edges()
	print("TEST RESULT: %s — %d boundary ownership/visibility/display comparisons (%d failures)" % ["PASS" if failures.is_empty() else "FAIL", comparisons, failures.size()])
	quit(0 if failures.is_empty() else 1)
func _test_checkpoints() -> void:
	var engine := RunEngine.new()
	var original := OriginalRunEngine.new()
	var combat := CombatEngine.new()
	var base: Dictionary = engine.create_new_run(20260917, ProgressionStore.default_data())
	for fixture: String in ["canonical", "legacy", "overflow", "recovery", "equipment", "items"]:
		var run: Dictionary = base.duplicate(true)
		var state: Dictionary = Fixture._fixture(combat, "surface_ready")
		run["mode"] = "combat"
		run["combat_state"] = state.duplicate(true)
		if fixture == "legacy":
			for key: String in ["equipped_equipment", "equipment_inventory", "collected_equipment", "reward_cards", "attuned_magic_cards", "magic_inventory", "equipped_items", "item_inventory"]: run.erase(key)
		if fixture == "overflow":
			run["attuned_magic_cards"] = ["pale_spark", "pale_spark", "pale_spark", "pale_spark", "pale_spark", "pale_spark", "pale_spark", "pale_spark"]
			run["equipped_items"] = ["crimson_draught", "crimson_draught", "crimson_draught"]
		if fixture == "recovery":
			state["recovered_embers_total"] = 12
			state["player"]["hp"] = 17
		if fixture == "equipment": state["collected_equipment"] = ["training_sword", "splintered_shield", "patched_cloak", "unknown", "training_sword"]
		if fixture == "items":
			state["equipped_items"] = ["crimson_draught", "crimson_draught"]
			state["item_inventory"] = ["crimson_draught", "unknown", "pale_spark"]
		var run_before: Dictionary = run.duplicate(true)
		var state_before: Dictionary = state.duplicate(true)
		var expected: Dictionary = original.set_combat_state(run, state)
		var actual: Dictionary = engine.set_combat_state(run, state)
		check(actual == expected, fixture + " checkpoint preserves every field")
		check(engine.set_combat_state(actual, state) == original.set_combat_state(expected, state), fixture + " repeated checkpoint remains idempotent")
		actual["combat_state"]["player"]["hp"] = -42
		actual["progression"]["embers"] = -42
		actual["deck_cards"].append("caller mutation")
		check(run == run_before and state == state_before, fixture + " output owns all nested run/combat fields")
		var repaired: Dictionary = engine._repair_equipment_state(run)
		check(repaired == original._repair_equipment_state(run), fixture + " repair API still migrates identically")
		repaired["progression"]["embers"] = -100
		check(run == run_before, fixture + " standalone repair still owns its output")
func _test_visibility_and_display() -> void:
	var combat := CombatEngine.new()
	var original := OriginalCombatEngine.new()
	var scene := RunScene.new()
	var original_scene := OriginalRunScene.new()
	for stage: String in ["clear", "pressing", "eclipse", "heart"]:
		for variant: int in range(8):
			var state: Dictionary = Fixture._fixture(combat, "dense")
			state["umbra"]["stage"] = stage
			state["umbra"]["truesight_activations"] = 1 if variant == 7 else 0
			if variant & 1: state["skill_ids"] = ["witchlight", "long_dawn"]
			if variant & 2: state["relics"] = ["witchglass_lantern", "witchglass_lantern", "tectonic_abacus"]
			if variant & 4:
				state["umbra"]["light_sources"] = [{"id": "lamp", "pos": Vector2i(7, 3), "radius": 2}, {"id": "zero", "pos": Vector2i(1, 1), "radius": -2}, "invalid"]
				state["guardian_braziers"] = [{"id": "lit", "pos": Vector2i(4, 4)}, {"id": "unlit", "pos": Vector2i(7, 1), "lit": false}]
			state["illusions"] = [{"id": 1, "pos": Vector2i(2, 4), "hp": 3}, {"id": 2, "pos": Vector2i(5, 5), "hp": 0}]
			var before: Dictionary = state.duplicate(true)
			check(combat._illusion_light_radius(state) == original._illusion_light_radius(state), "Illusion skill/relic stacking radius")
			check(combat.effective_umbra_stage(state) == original.effective_umbra_stage(state), "Light suppression including zero/unlit/invalid sources")
			check(combat.umbra_visible_tiles(state) == original.umbra_visible_tiles(state), "Complete visible tile ordering")
			check(combat.visible_enemy_ids(state) == original.visible_enemy_ids(state), "Visible enemies and conditional True Sight")
			for y: int in range(9):
				for x: int in range(11):
					check(combat._light_source_covers_tile(state, Vector2i(x, y)) == original._light_source_covers_tile(state, Vector2i(x, y)), "Every tile has identical light coverage")
					check(combat.is_tile_visible_to_player(state, Vector2i(x, y)) == original.is_tile_visible_to_player(state, Vector2i(x, y)), "Point visibility matches complete visible-board enumeration")
			for card: String in ["threaded_path", "pale_spark", "wildfire_halo", "shadow_step", "thunderline", "quick_stab"]:
				for action: Dictionary in combat.card_play_actions(card, state):
					check(combat.valid_targets_for_player_action(state, action) == original.valid_targets_for_player_action(state, action), card + " complete ordered target set")
				check(scene._card_widget_display(card, state) == original_scene._card_widget_display(card, state), card + " display modifiers remain identical")
			check(state == before, "Rules/display queries cannot mutate sources, flags or event history")
	scene.free()
	original_scene.free()
func check(ok: bool, message: String) -> void:
	comparisons += 1
	if not ok:
		failures.append(message)
		push_error(message)

func _test_hud_queries() -> void:
	var combat := CombatEngine.new()
	var engine := RunEngine.new()
	var base: Dictionary = engine.create_new_run(20260917, ProgressionStore.default_data())
	var blink_id: String = SkillTreeLibrary.skill_id_for_effect("arm_movement_blink")
	for fixture: String in ["open", "blocked", "dense", "heart", "frozen", "shocked", "immobilized", "surface_ready", "surface_spent"]:
		for remaining: int in [0, 1, 2, 3, 7]:
			for armed: bool in [false, true]:
				var state: Dictionary = Fixture._fixture(combat, fixture)
				state["player_movement_remaining"] = remaining
				if armed:
					state["skill_ids"] = [blink_id]
					state["skill_flags"] = {"movement_blink_armed": true}
				var before: Dictionary = state.duplicate(true)
				var targets: Array[Vector2i] = combat.player_movement_targets(state)
				check(combat.player_has_movement_target(state) == not targets.is_empty(), "Movement availability equals full legal target list: %s/%d/%s" % [fixture, remaining, armed])
				check(combat.player_movement_targets(state) == targets and state == before, "Availability preserves full targeting and state")
		var state: Dictionary = Fixture._fixture(combat, fixture)
		for variant: int in range(5):
			var run: Dictionary = base.duplicate(true)
			run["combat_state"] = state.duplicate(true)
			if variant == 0:
				run.clear()
			elif variant == 1:
				for key: String in [GrimoireLibrary.UNLOCKED_KEY, GrimoireLibrary.UNREAD_KEY, GrimoireLibrary.NOTICE_KEY]: run.erase(key)
			elif variant == 2:
				run[GrimoireLibrary.UNLOCKED_KEY] = ["unknown", "card:pale_spark", "card:pale_spark"]
				run[GrimoireLibrary.UNREAD_KEY] = ["enemy:crawler", "unknown"]
			elif variant == 3:
				run["progression"][GrimoireLibrary.UNLOCKED_KEY] = ["unknown", "enemy:crawler", "enemy:crawler"]
				run["progression"][GrimoireLibrary.UNREAD_KEY] = ["unknown", "enemy:crawler"]
			else:
				run["pending_reward"] = {"cards": ["wildfire_halo", "shadow_step"]}
			var before: Dictionary = run.duplicate(true)
			var normalized: Dictionary = GrimoireLibrary.ensure_run_state(run)
			var original_candidates: Array[String] = GrimoireLibrary.entry_ids_for_run_state(normalized)
			original_candidates.append_array(GrimoireLibrary.entry_ids_for_combat_state(state))
			var original: Dictionary = GrimoireLibrary.unlock_entries(normalized, original_candidates)
			var source: Dictionary = GrimoireLibrary.ensure_run_state(run) if run.is_empty() else run
			var candidates: Array[String] = GrimoireLibrary.entry_ids_for_run_state(source)
			candidates.append_array(GrimoireLibrary.entry_ids_for_combat_state(state))
			var actual: Dictionary = GrimoireLibrary.unlock_entries(source, candidates)
			check(actual == original, "One normalization preserves discoveries, notices and progression-write decisions: %s/%d" % [fixture, variant])
			(actual["state"][GrimoireLibrary.UNLOCKED_KEY] as Array).append("caller mutation")
			check(run == before, "Discovery output owns its nested snapshot")

func _test_rule_lookup_edges() -> void:
	var combat := CombatEngine.new()
	var original := OriginalCombatEngine.new()
	for values: Variant in [[], ["open_sky", "open_sky", "unknown", null, 7], ["", " quick_wits", "quick_wits"], "open_sky", null]:
		for skill_id: String in ["", "unknown", "open_sky", "quick_wits", "7"]:
			check(combat.has_skill({"skill_ids": values}, skill_id) == original.has_skill({"skill_ids": values}, skill_id), "Membership preserves string conversion, duplicate and unknown-ID handling")
	var relic_ids: Array = ["ember_lens", "witchglass_lantern", "ember_lens"]
	var relic_state: Dictionary = {"relics": relic_ids}
	for iteration: int in range(5):
		check(combat._relic_effects(relic_state) == GameData.relic_effects_for_ids(relic_ids), "Relic lookup equals uncached expansion after in-place edits")
		match iteration:
			0: relic_ids.reverse()
			1: relic_ids.append("tectonic_abacus")
			2: relic_ids.erase("ember_lens")
			3: relic_ids.clear()
	for source: String in ["lamp", "brazier", "illusion"]:
		for inside: bool in [false, true]:
			var state: Dictionary = Fixture._fixture(combat, "heart")
			state["skill_ids"] = ["open_sky", "witchlight"]
			state["relics"] = []
			state["umbra"]["truesight_activations"] = 0
			state["umbra"]["light_sources"] = []
			state["guardian_braziers"] = []
			state["illusions"] = []
			state["player"]["pos"] = Vector2i(4, 4) if inside else Vector2i(1, 1)
			match source:
				"lamp": state["umbra"]["light_sources"] = [{"pos": Vector2i(5, 4), "radius": 1}]
				"brazier": state["guardian_braziers"] = [{"id": "test", "pos": Vector2i(5, 4), "lit": true}]
				"illusion": state["illusions"] = [{"id": 1, "pos": Vector2i(5, 4), "hp": 10}]
			var before: Dictionary = state.duplicate(true)
			check(combat.player_has_truesight(state) == inside, "Open Sky must activate only inside " + source)
			check(combat.visible_enemy_ids(state) == original.visible_enemy_ids(state), "Conditional True Sight visibility matches original")
			for action: Dictionary in combat.card_play_actions("pale_spark", state):
				check(combat.valid_targets_for_player_action(state, action) == original.valid_targets_for_player_action(state, action), "Conditional True Sight targeting matches original")
			check(state == before, "Conditional light queries preserve state")
	for bent: bool in [false, true]:
		for remaining: int in [0, 1, 2, 3]:
			var state: Dictionary = Fixture._fixture(combat, "open")
			state["relics"] = ["winters_spur"]
			state["player_movement_remaining"] = remaining
			for tile: Vector2i in [Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4)]:
				preload("res://scripts/board_surface_rules.gd").place(state, tile, "ice")
			if bent:
				preload("res://scripts/board_surface_rules.gd").place(state, Vector2i(4, 3), "ice")
			check(combat.player_has_movement_target(state) == not original.player_movement_targets(state).is_empty(), "Winter's Spur availability preserves straight/bent sliding and partly spent budgets")
	var ragged: Dictionary = Fixture._fixture(combat, "heart")
	ragged["grid"] = [["floor"], [], ["floor", "floor"]]
	ragged["umbra"]["light_sources"] = [{"radius": 3000}]
	for tile: Vector2i in [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 2), Vector2i(0, 3)]:
		check(combat.is_tile_visible_to_player(ragged, tile) == original.is_tile_visible_to_player(ragged, tile), "Point visibility preserves ragged bounds and missing source position fallback")
	var scene := RunScene.new()
	var original_scene := OriginalRunScene.new()
	var state: Dictionary = Fixture._fixture(combat, "open")
	state["relics"] = ["first_attack_fixture"]
	state["turn_flags"] = {"first_attack_bonus_used": false, "unrelated": {"value": 9}}
	var before: Dictionary = state.duplicate(true)
	var effects: Array[Dictionary]
	effects.append({"type": "first_attack_bonus", "value": 4})
	for target: RunScene in [scene, original_scene]:
		var engine: RefCounted = target.get("_combat_engine")
		engine.set("_relic_effect_cache_ids", state["relics"].duplicate())
		engine.set("_relic_effect_cache", effects.duplicate(true))
	check((scene.get("_combat_engine") as CombatEngine).attack_bonus_for_current_turn(state) == 4, "Display fixture must exercise one-shot modifier consumption")
	check(scene._card_widget_display("cinder_fusillade", state) == original_scene._card_widget_display("cinder_fusillade", state), "Multiple damaging actions consume a display-only modifier identically")
	check(state == before, "Display-only consumption leaves nested committed flags untouched")
	scene.free()
	original_scene.free()
