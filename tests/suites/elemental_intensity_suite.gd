extends RefCounted

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ElementalIntensityHudArt = preload("res://scripts/elemental_intensity_hud_art.gd")
const ElementalIntensityRules = preload("res://scripts/elemental_intensity_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")

static func run(expect: Callable) -> void:
	_test_hanging_hud_asset_and_glow_contract(expect)
	_test_trap_curve_and_legacy_payloads(expect)
	_test_player_spenders_are_atomic(expect)
	_test_spend_visual_language(expect)
	_test_ambient_scaling_and_trap_readability(expect)
	_test_elemental_enemy_data_contract(expect)
	_test_enemy_build_and_spend_resolution(expect)

static func _test_hanging_hud_asset_and_glow_contract(expect: Callable) -> void:
	var charm_paths: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		var path: String = ElementData.intensity_charm_path(element_id)
		expect.call(not path.is_empty() and FileAccess.file_exists(path), "%s should have an authored hanging charm raster" % element_id)
		expect.call(not charm_paths.has(path), "%s should have a distinct hanging charm silhouette asset" % element_id)
		charm_paths[path] = true
	expect.call(FileAccess.file_exists(ElementalIntensityHudArt.RIG_TEXTURE_PATH), "Hanging intensity HUD should have an authored rail-and-chains raster")
	expect.call(FileAccess.file_exists(ElementalIntensityHudArt.PLACARD_TEXTURE_PATH), "Hanging intensity HUD should have an authored number placard raster")
	expect.call(ElementalIntensityHudArt.PLACARD_RECT.size.x <= ElementalIntensityHudArt.PLACARD_RECT.size.y, "The single-digit placard should be compact rather than a wide banner")
	expect.call(ElementalIntensityHudArt.NUMBER_LABEL_RECT.position.x >= ElementalIntensityHudArt.PLACARD_RECT.position.x and ElementalIntensityHudArt.NUMBER_LABEL_RECT.end.x <= ElementalIntensityHudArt.PLACARD_RECT.end.x, "The live digit should remain horizontally inside its authored placard")
	expect.call(ElementalIntensityHudArt.NUMBER_LABEL_RECT.position.y >= ElementalIntensityHudArt.PLACARD_RECT.position.y and ElementalIntensityHudArt.NUMBER_LABEL_RECT.end.y <= ElementalIntensityHudArt.PLACARD_RECT.end.y, "The live digit should remain vertically inside its authored placard")
	for element_id: String in ElementData.all_elements():
		expect.call(absf(ElementalIntensityHudArt.charm_attachment_x(element_id) - ElementalIntensityHudArt.chain_endpoint_x(element_id)) <= 0.5, "%s charm ring should align to its authored chain endpoint" % element_id)
	expect.call(ElementalIntensityHudArt.glow_strength(0) == 0.0, "An uncharged charm should have no glow")
	expect.call(ElementalIntensityHudArt.glow_strength(1) > 0.0 and ElementalIntensityHudArt.glow_strength(1) <= 0.16, "Intensity one should begin with a mild glow")
	for value: int in range(2, 7):
		expect.call(ElementalIntensityHudArt.glow_strength(value) > ElementalIntensityHudArt.glow_strength(value - 1), "Charm glow should strengthen at intensity %d" % value)
		expect.call(ElementalIntensityHudArt.glow_spread(value) > ElementalIntensityHudArt.glow_spread(value - 1), "Charm glow should widen at intensity %d" % value)

static func _test_trap_curve_and_legacy_payloads(expect: Callable) -> void:
	expect.call(ElementalIntensityRules.trap_scale_percent(0) == 72, "Quiet traps should begin at 72% of their authored base damage")
	expect.call(ElementalIntensityRules.trap_scale_percent(1) == 94, "Starting room intensity should put traps just below their former damage")
	expect.call(ElementalIntensityRules.trap_scale_percent(4) == 208, "Volatile intensity should make traps more than twice as deadly")
	expect.call(ElementalIntensityRules.trap_scale_percent(99) == 324, "Trap scaling should cap at intensity 6 for save safety")
	var combat := CombatEngine.new()
	var state: Dictionary = _combat_state(combat, ElementData.FIRE)
	var legacy_trap: Dictionary = {"element": ElementData.FIRE, "damage": 10}
	expect.call(combat.trap_damage(state, legacy_trap) == 9, "Legacy traps without base_damage should use their saved damage as the scalable base")
	_set_intensity(combat, state, ElementData.FIRE, 4)
	expect.call(combat.trap_damage(state, legacy_trap) == 21, "Live trap damage should follow the current room intensity")

static func _test_player_spenders_are_atomic(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _combat_state(combat, ElementData.FIRE)
	var actions: Array = combat.card_play_actions("inferno_ritual", state)
	expect.call(actions.size() >= 2 and str((actions[0] as Dictionary).get("type", "")) == "intensity_spend", "A spender card should prepend one explicit intensity cost action")
	expect.call(int((actions[0] as Dictionary).get("amount", 0)) == 2, "Inferno Ritual should spend two Fire intensity")
	expect.call(not combat.player_action_can_resolve(state, actions[0] as Dictionary), "A player should not be able to overspend room intensity")
	var host: Node = RunSceneScript.new()
	var insufficient_preview: Dictionary = host.call("_card_preview_from_state", "inferno_ritual", state, actions, 0)
	expect.call(bool(insufficient_preview.get("complete", false)) and not bool(insufficient_preview.get("playable", true)), "An unpaid card-level intensity cost should make printed play unavailable instead of skipping to its payoff")
	_set_intensity(combat, state, ElementData.FIRE, 2)
	var live_before_preview: int = combat.elemental_intensity(state, ElementData.FIRE)
	var payable_preview: Dictionary = host.call("_card_preview_from_state", "inferno_ritual", state, actions, 0)
	expect.call(bool(payable_preview.get("playable", false)), "A funded intensity spender should expose its normal target preview")
	expect.call(combat.elemental_intensity(state, ElementData.FIRE) == live_before_preview, "Previewing or cancelling a spender should not mutate live intensity")
	var after_spend: Dictionary = combat.apply_player_action(state, actions[0] as Dictionary)
	expect.call(combat.elemental_intensity(after_spend, ElementData.FIRE) == 0, "Resolving a funded cost should remove its intensity exactly once")
	expect.call(int(combat.elemental_intensity_counter(after_spend, "elemental_intensity_spent_total").get(ElementData.FIRE, 0)) == 2, "Player card costs should feed the existing intensity-spent analytics counter")
	var resolved_actions: Array = [actions[0]]
	var selected_targets: Array[Vector2i] = []
	var analytics_payload: Dictionary = host.call("_analytics_card_play_payload", "inferno_ritual", state, after_spend, resolved_actions, selected_targets)
	expect.call(int((analytics_payload.get("elemental_intensity_spent", {}) as Dictionary).get(ElementData.FIRE, 0)) == 2, "Card-play analytics should attribute a printed intensity cost to the played card")
	var rejected_overspend: Dictionary = combat.apply_player_action(after_spend, actions[0] as Dictionary)
	expect.call(combat.elemental_intensity(rejected_overspend, ElementData.FIRE) == 0, "Repeated cost resolution should clamp at zero instead of creating negative intensity")
	expect.call(int(combat.elemental_intensity_counter(rejected_overspend, "elemental_intensity_spent_total").get(ElementData.FIRE, 0)) == 2, "A rejected overspend should not inflate spent-intensity analytics")
	host.free()

static func _test_spend_visual_language(expect: Callable) -> void:
	var spend_rows: Array = ActionIcons.cost_rows_for_card(GameData.card_def("inferno_ritual"))
	var spend_token: Dictionary = ((spend_rows[0] as Array)[0] as Dictionary)
	expect.call(str(spend_token.get("kind", "")) == "intensity_spend" and str(spend_token.get("value", "")) == "-2", "Spender cards should print an element-colored negative intensity cost")
	expect.call(str(spend_token.get("tone", "")) == "penalty" and ActionIcons.token_tooltip(spend_token).contains("removes 2 Fire intensity"), "Spend tokens should read as a cost rather than a threshold bonus")
	var gate_found: bool = false
	for row_var: Variant in ActionIcons.rows_for_card(GameData.card_def("updraft")):
		for token_var: Variant in row_var as Array:
			if typeof(token_var) == TYPE_DICTIONARY and str((token_var as Dictionary).get("kind", "")) == "intensity_requirement":
				gate_found = true
	expect.call(gate_found and str(spend_token.get("kind", "")) != "intensity_requirement", "Intensity gates and spends should remain semantically and visually distinct")
	var widget: Control = CardWidget.new()
	var funded_token: Dictionary = spend_token.duplicate(true)
	funded_token["condition_active"] = true
	widget.call("set_display_overrides", "", [], [[funded_token]])
	widget.call("_refresh_intensity_active_glow")
	var active_glow: Control = widget.find_child("IntensityActiveGlow", false, false) as Control
	expect.call(active_glow != null and active_glow.visible, "A funded spender should use the established active intensity glow")
	expect.call(widget.find_child("IntensitySpendFrame", false, false) == null, "Spender cards should not render a separate decorative frame")
	funded_token["condition_active"] = false
	widget.call("set_display_overrides", "", [], [[funded_token]])
	widget.call("_refresh_intensity_active_glow")
	expect.call(active_glow != null and not active_glow.visible, "A starved spender should hide the active intensity glow")
	widget.free()

static func _test_ambient_scaling_and_trap_readability(expect: Callable) -> void:
	var board := CombatBoardView.new()
	var quiet_count: int = int(board.call("_ambient_particle_count", ElementData.FIRE, 72, 0))
	var baseline_count: int = int(board.call("_ambient_particle_count", ElementData.FIRE, 72, 1))
	var volatile_count: int = int(board.call("_ambient_particle_count", ElementData.FIRE, 72, 4))
	expect.call(quiet_count < baseline_count and baseline_count < volatile_count, "Room particle density should rise monotonically with live intensity")
	expect.call(ElementalIntensityRules.ambient_opacity_scale(4) > ElementalIntensityRules.ambient_opacity_scale(1), "High-intensity particles should become more opaque")
	expect.call(ElementalIntensityRules.ambient_speed_scale(4) > ElementalIntensityRules.ambient_speed_scale(1), "High-intensity particles should move more quickly")
	board.combat_state = {"elemental_intensity": {ElementData.FIRE: 4}}
	var tooltip: String = str(board.call("_trap_tooltip_text", {"element": ElementData.FIRE, "base_damage": 10, "damage": 10}))
	expect.call(tooltip == "Fire Trap\n21 damage", "Trap tooltips should show only the trap name and live scaled damage")
	var run_scene: Node = RunSceneScript.new()
	var intensity_tooltip: String = str(run_scene.call("_intensity_tooltip", ElementData.FIRE))
	expect.call(intensity_tooltip == "The intensity of Fire in the room.\nFire effects are stronger when this is higher.", "Intensity tooltips should stay concise and avoid implementation details")
	run_scene.free()
	board.free()

static func _test_elemental_enemy_data_contract(expect: Callable) -> void:
	var cinder_gate: Dictionary = _first_action_with_field(_intent("cinder_ooze", "cinder_bloom"), "intensity_bonus")
	var cinder_builder: Dictionary = _first_action_of_type(_intent("cinder_ooze", "slag_shell"), "intensity")
	var frost_gate: Dictionary = _first_action_with_field(_intent("frostglass_lancer", "frost_pin"), "intensity_bonus")
	var frost_builder: Dictionary = _first_action_of_type(_intent("frostglass_lancer", "refract_guard"), "intensity")
	var bile_gate: Dictionary = _first_action_with_field(_intent("bile_bloomer", "spore_mark"), "intensity_bonus")
	var bile_builder: Dictionary = _first_action_of_type(_intent("bile_bloomer", "pustule_shell"), "intensity")
	var gaoler_spend: Dictionary = _first_action_with_field(_intent("chainbound_gaoler", "chain_reel"), "spend_intensity")
	var gaoler_builder: Dictionary = _first_action_of_type(_intent("chainbound_gaoler", "iron_guard"), "intensity")
	var wisp_spend: Dictionary = _first_action_with_field(_intent("lightning_wisp", "blinding_arc"), "spend_intensity")
	var wisp_builder: Dictionary = _first_action_of_type(_intent("lightning_wisp", "static_lash"), "intensity")
	expect.call(not cinder_gate.is_empty() and not frost_gate.is_empty() and not bile_gate.is_empty(), "Fire, Ice, and Earth specialists should have intensity-gated payoff actions")
	expect.call(not cinder_builder.is_empty() and not frost_builder.is_empty() and not bile_builder.is_empty(), "Fire, Ice, and Earth specialists should build their matching room resource")
	expect.call(not gaoler_spend.is_empty() and not wisp_spend.is_empty(), "Air and Lightning specialists should consume intensity for stronger intents")
	expect.call(not gaoler_builder.is_empty() and not wisp_builder.is_empty(), "Consuming specialists should also telegraph ways to recharge their element")

static func _test_enemy_build_and_spend_resolution(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var builder_state: Dictionary = _enemy_state(combat, ElementData.FIRE, "cinder_ooze", "slag_shell")
	var builder_phase: Dictionary = combat.resolve_enemy_phase_with_steps(builder_state)
	var built_state: Dictionary = builder_phase.get("state", {}) as Dictionary
	expect.call(combat.elemental_intensity(built_state, ElementData.FIRE) == 2, "An elemental builder intent should raise the live room resource")
	var saw_builder_step: bool = false
	for step_var: Variant in builder_phase.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and str((step_var as Dictionary).get("kind", "")) == "intensity":
			saw_builder_step = int(((step_var as Dictionary).get("elemental_intensity_gained", {}) as Dictionary).get(ElementData.FIRE, 0)) == 1
	expect.call(saw_builder_step, "Enemy builder presentation and analytics steps should name the intensity gained")
	var starved_state: Dictionary = _enemy_state(combat, ElementData.LIGHTNING, "lightning_wisp", "blinding_arc")
	var spend_action: Dictionary = _first_action_with_field(_intent("lightning_wisp", "blinding_arc"), "spend_intensity")
	expect.call(not combat.enemy_action_can_resolve(starved_state, spend_action), "A telegraphed enemy payoff should be deniable by draining its element below cost")
	var starved_phase: Dictionary = combat.resolve_enemy_phase_with_steps(starved_state)
	var after_starved: Dictionary = starved_phase.get("state", {}) as Dictionary
	expect.call(int((after_starved.get("player", {}) as Dictionary).get("hp", 0)) == 240, "A starved enemy payoff should not damage the player")
	expect.call(combat.elemental_intensity(after_starved, ElementData.LIGHTNING) == 1, "A starved enemy payoff should not consume a partial payment")
	var starved_plan: Dictionary = combat.enemy_intent_plan(starved_state, 0)
	expect.call(not bool(starved_plan.get("attack_available", true)) and (starved_plan.get("projected_attack", []) as Array).is_empty(), "A starved enemy payoff should not paint a projected attack threat")
	var funded_state: Dictionary = _enemy_state(combat, ElementData.LIGHTNING, "lightning_wisp", "blinding_arc")
	_set_intensity(combat, funded_state, ElementData.LIGHTNING, 2)
	expect.call(combat.enemy_action_can_resolve(funded_state, spend_action), "A funded enemy payoff should become resolvable")
	var funded_plan: Dictionary = combat.enemy_intent_plan(funded_state, 0)
	expect.call(bool(funded_plan.get("attack_available", false)) and not (funded_plan.get("projected_attack", []) as Array).is_empty(), "A funded enemy payoff should restore its projected attack threat")
	var funded_phase: Dictionary = combat.resolve_enemy_phase_with_steps(funded_state)
	var after_funded: Dictionary = funded_phase.get("state", {}) as Dictionary
	expect.call(int((after_funded.get("player", {}) as Dictionary).get("hp", 0)) < 240, "A funded enemy payoff should resolve its stronger attack")
	expect.call(combat.elemental_intensity(after_funded, ElementData.LIGHTNING) == 0, "A funded enemy payoff should consume its full intensity cost")
	var saw_spend_step: bool = false
	for step_var: Variant in funded_phase.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and int(((step_var as Dictionary).get("elemental_intensity_spent", {}) as Dictionary).get(ElementData.LIGHTNING, 0)) == 2:
			saw_spend_step = true
	expect.call(saw_spend_step, "Enemy payoff steps should expose their intensity spend to analytics")
	var missed_state: Dictionary = _enemy_state(combat, ElementData.AIR, "chainbound_gaoler", "chain_reel")
	_set_intensity(combat, missed_state, ElementData.AIR, 2)
	var missed_player: Dictionary = (missed_state.get("player", {}) as Dictionary).duplicate(true)
	missed_player["pos"] = Vector2i(1, 1)
	missed_state["player"] = missed_player
	var missed_enemies: Array = (missed_state.get("enemies", []) as Array).duplicate(true)
	var missed_enemy: Dictionary = (missed_enemies[0] as Dictionary).duplicate(true)
	missed_enemy["pos"] = Vector2i(6, 5)
	missed_enemies[0] = missed_enemy
	missed_state["enemies"] = missed_enemies
	var missed_phase: Dictionary = combat.resolve_enemy_phase_with_steps(missed_state)
	var after_missed: Dictionary = missed_phase.get("state", {}) as Dictionary
	expect.call(combat.elemental_intensity(after_missed, ElementData.AIR) == 2, "An out-of-range enemy payoff should not pay intensity for an effect that never resolves")
	var missed_spend_step: bool = false
	for step_var: Variant in missed_phase.get("steps", []):
		if typeof(step_var) == TYPE_DICTIONARY and int(((step_var as Dictionary).get("elemental_intensity_spent", {}) as Dictionary).get(ElementData.AIR, 0)) > 0:
			missed_spend_step = true
	expect.call(not missed_spend_step, "A missed enemy payoff should not emit a phantom intensity-spend analytics step")

static func _combat_state(combat: CombatEngine, element_id: String) -> Dictionary:
	return combat.create_combat(78123, {"name": "Intensity Test", "type": "combat", "depth": 2, "element": element_id, "grid": _grid(), "player_start": Vector2i(2, 4), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 140, "max_hp": 140, "block": 0}], "traps": [], "loot": []}, {"hp": 24, "max_hp": 24, "deck_cards": ["inferno_ritual", "spark_dart"], "relics": [], "hand_size": 2, "heal_bonus": 0})

static func _enemy_state(combat: CombatEngine, element_id: String, enemy_type: String, intent_id: String) -> Dictionary:
	var state: Dictionary = _combat_state(combat, element_id)
	var enemy_def: Dictionary = GameData.enemy_def(enemy_type)
	state["player"] = {"pos": Vector2i(2, 4), "hp": 240, "max_hp": 240, "block": 0, "stoneskin": 0}
	state["enemies"] = [{"id": 1, "type": enemy_type, "pos": Vector2i(5, 4), "hp": int(enemy_def.get("max_hp", 100)), "max_hp": int(enemy_def.get("max_hp", 100)), "block": 0, "stoneskin": 0, "intent": _intent(enemy_type, intent_id)}]
	return state

static func _set_intensity(combat: CombatEngine, state: Dictionary, element_id: String, amount: int) -> void:
	var intensity: Dictionary = combat.elemental_intensities(state)
	intensity[element_id] = amount
	state["elemental_intensity"] = intensity

static func _intent(enemy_type: String, intent_id: String) -> Dictionary:
	for intent_var: Variant in GameData.enemy_def(enemy_type).get("intents", []):
		if typeof(intent_var) == TYPE_DICTIONARY and str((intent_var as Dictionary).get("id", "")) == intent_id:
			return (intent_var as Dictionary).duplicate(true)
	return {}

static func _first_action_of_type(intent: Dictionary, action_type: String) -> Dictionary:
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) == TYPE_DICTIONARY and str((action_var as Dictionary).get("type", "")) == action_type:
			return (action_var as Dictionary).duplicate(true)
	return {}

static func _first_action_with_field(intent: Dictionary, field: String) -> Dictionary:
	for action_var: Variant in intent.get("actions", []):
		if typeof(action_var) == TYPE_DICTIONARY and (action_var as Dictionary).has(field):
			return (action_var as Dictionary).duplicate(true)
	return {}

static func _grid() -> Array:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(8):
			row.append(1 if x == 0 or y == 0 or x == 7 or y == 6 else 0)
		grid.append(row)
	return grid
