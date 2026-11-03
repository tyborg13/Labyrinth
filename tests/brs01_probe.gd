extends "res://tests/en01_enemies_probe.gd"

const Settings = preload("res://scripts/settings_store.gd")
const HoarderFixture = preload("res://tools/hoarder_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const ObjectiveCases = preload("res://tests/brs01_test.gd")
const Fx = preload("res://scripts/enemy_mechanics/burst_fx.gd")
const TOOLTIP_WAIT_SECONDS: float = 1.5
const HOVER_TIMEOUT_MSEC: int = 3000
const HOVER_POLL_SECONDS: float = 0.05
const PROOF_GLOW_PEAK_SECONDS: float = 0.06
const PROOF_AOE_PROGRESS: float = 0.55
var _proof_heading_rect: Rect2
var _hover_check_only: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Settings.set_storage_path("user://brs01-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	_hover_check_only = OS.get_cmdline_user_args().has("--hover-check-only")
	if _hover_check_only:
		_hover_check.call_deferred()
		return
	if OS.get_cmdline_user_args().has("--check-only"): _check_extra_fixtures()
	super._initialize()

# Dummy-renderer routing proof exercises the real controls and tooltip Windows;
# renderer capture and native appearance still belong to the director's run.
func _hover_check() -> void:
	LiveFixture.prepare_storage()
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.gui_embed_subwindows = true
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_canvas.add_child(_scene)
	await LiveFixture.settle(self)
	await _objectives_and_pre_battle()
	_finish("BRS02 TOOLTIP ROUTING RESULT")

func _capture(label: String, facts: Dictionary) -> void:
	if _hover_check_only: return
	await super._capture(label, facts)

func _check_extra_fixtures() -> void:
	var engine := Run.new()
	var options: Dictionary = {"hoarder_biome": "fire", "hoarder_tier": 2, "hoarder_case": "pre_battle"}
	var pre: Dictionary = HoarderFixture.build(engine, Combat.new(), engine.create_new_run(HoarderFixture.FIXTURE_SEED, Progression.default_data()), options)
	var prepared: Dictionary = HoarderFixture.prepared(engine, Combat.new(), pre)
	_expect(Objectives.title_for_objective(prepared["combat_state"]["objective"]) == "Defeat the Ember Hoarder before it escapes!", "Native Hoarder proof has the exact production objective")
	_expect((prepared["combat_state"]["enemies"] as Array).any(func(enemy: Dictionary) -> bool: return str(enemy["type"]) == "ember_tick"), "Native move-panel proof has a Tick")
	var cases: Array[Dictionary] = ObjectiveCases.objective_cases()
	for objective: Dictionary in cases:
		var title: String = Objectives.title_for_objective(objective)
		_expect(title.begins_with("Defeat") or title.begins_with("Survive") or title.begins_with("Reach"), "Native objective case is an instruction")
	print("BRS01 PROBE CONTRACT: %s (%d objective cases; 1920x1080; 100%% UI scale)" % ["PASS" if _failures.is_empty() else "FAIL", cases.size()])

func _capture_additional(after: Dictionary, chain_presentation: Dictionary) -> void:
	# Native reduced-motion proof: exactly the same burst, with glows only.
	LiveFixture.set_reduced_motion(_scene, true)
	var reduced: Dictionary = chain_presentation.duplicate(true)
	reduced["reduced_motion"] = true
	await _show(after, reduced)
	await _capture("10_burst_reduced_motion", {"glow_only": true, "ui_scale": 1.0})
	LiveFixture.set_reduced_motion(_scene, false)
	# Explicit peak sample of the traced feedback path, including pixel routing.
	var peak: Dictionary = {"en01_burst": chain_presentation["en01_burst"]}
	Fx.decorate(peak, PROOF_GLOW_PEAK_SECONDS)
	await _show(after, peak)
	await _capture("11_burst_peak", {"elapsed": PROOF_GLOW_PEAK_SECONDS, "centre_alpha": 0.55, "ribbons": 8, "smoke_puffs": 1})
	var aoe_state: Dictionary = Suite.fixture(["ember_tick", "crawler"])
	var tiles: Array[Vector2i]
	tiles.assign([Vector2i(3, 3), Vector2i(3, 4), Vector2i(4, 3), Vector2i(4, 4)])
	await _show(aoe_state, {"effect": {"kind": "aoe", "actor_key": "enemy_2", "from": aoe_state["enemies"][1]["pos"], "to": Vector2i(3, 3), "tiles": tiles, "element": "fire"}, "effect_progress": PROOF_AOE_PROGRESS})
	await _capture("12_enemy_aoe_impact", {"fire_footprint": true, "outlined_edge": false})
	await _objectives_and_pre_battle()

func _objectives_and_pre_battle() -> void:
	# Match board_tile_tooltip_probe's synthetic viewport setup before hover.
	_canvas.notify_mouse_entered()
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	var engine := Run.new()
	var options: Dictionary = {"hoarder_biome": "fire", "hoarder_tier": 2, "hoarder_case": "encounter"}
	var run: Dictionary = HoarderFixture.build(engine, Combat.new(), engine.create_new_run(HoarderFixture.FIXTURE_SEED, Progression.default_data()), options)
	var pre: Dictionary = run.duplicate(true)
	pre["mode"] = "pre_battle"
	pre["pre_battle_pending"] = true
	pre["pre_battle_travel_dir"] = HoarderFixture.FIXTURE_TRAVEL
	pre["combat_state"] = {}
	_scene.set("_run_state", pre)
	var prepared: Dictionary = HoarderFixture.prepared(engine, Combat.new(), pre)
	_scene.set("_prepared_pre_battle_factory", prepared)
	_expect(bool(_scene.call("_show_pre_battle_preview")), "Actual Hoarder pre-battle factory opens")
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	var panel: Control = _scene.get("_pre_battle_panel")
	var title: Label = panel.find_child("PreBattleObjectiveTitle", true, false)
	_proof_heading_rect = (title.get_parent().get_parent().get_parent() as Control).get_global_rect()
	_expect(title.text == "OBJECTIVE · Defeat the Ember Hoarder before it escapes!", "Exact Hoarder pre-battle heading")
	_expect(title.tooltip_text.begins_with("Defeat the Ember Hoarder before it escapes!"), "Hoarder heading tooltip uses full title")
	await _capture("13_hoarder_pre_battle", {"objective_title": title.text, "captions": "Bursts 4"})
	var tick: Dictionary = {}
	for enemy: Dictionary in prepared["combat_state"]["enemies"]:
		if str(enemy["type"]) == "ember_tick": tick = enemy; break
	_expect(not tick.is_empty(), "Hoarder roster has a Tick for move inspection")
	if not tick.is_empty():
		var source: Control = null
		var flow: Control = panel.find_child("PreBattleEnemyFlow", true, false)
		for candidate: Control in flow.get_children():
			var enemy: Dictionary = candidate.get("enemy")
			if int(enemy.get("id", -1)) == int(tick["id"]): source = candidate; break
		_expect(source != null, "Tick proof finds the real pre-battle hover source")
		if source != null:
			var popup: Window = await _hover_enemy(source)
			_expect(popup != null, "Tick hover opens its native inspection popup")
			if popup != null:
				var inspection: Control = popup.find_child("PreBattleEnemyInspection", true, false)
				_expect(inspection != null and inspection.is_visible_in_tree(), "Real inspection panel is visible above the pre-battle screen")
				if inspection != null:
					_expect(inspection.find_child("EnemyBurstTraitTitle", true, false).text == "Bursts 4", "Actual hover panel shows Burst trait")
					var labels := PackedStringArray()
					for label: Label in inspection.find_children("*", "Label", true, false): labels.append(label.text)
					_expect(labels.has("Kindle") and labels.has("Scuttle") and labels.has("Burst +2"), "Actual hover panel shows both known moves and Kindle's value")
					var rules: Label = inspection.find_child("EnemyBurstTraitRules", true, false)
					_expect(rules.size.x <= preload("res://scripts/enemy_mechanics/burst_trait_text.gd").WIDTH, "Pre-battle Burst rules wrap at 420 px")
				await _capture("14_tick_pre_battle_moves", {"native_hover": true, "trait": "Bursts 4", "moves": ["Kindle", "Scuttle"], "row": "Burst +2", "tooltip": "Its Burst hits 2 harder, up to +4."})
			await _pointer(Vector2.ZERO)
	await _capacitor_pre_battle()
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	_scene.call("_close_pre_battle_preview")
	# Each objective uses the production dock and production pre-battle heading.
	var index: int = 0
	var state: Dictionary = Suite.fixture(["ember_hoarder", "crawler"])
	await _show(state)
	for objective: Dictionary in ObjectiveCases.objective_cases():
		var shown: Dictionary = state.duplicate(true)
		shown["objective"] = objective.duplicate(true)
		shown["objective"]["leader_id"] = 1
		var hud: Control = _scene.get("_combat_objective_hud")
		hud.set_combat_state(shown)
		hud.cancel_intro()
		_scene.call("_layout_combat_action_dock")
		_scene.call("_layout_combat_objective_hud")
		for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
		_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(hud.get_global_rect()), "Objective panel stays in 1080p viewport")
		for label: Label in [hud._title, hud._detail]: _expect_fits(label)
		var heading: Control = preload("res://scripts/pre_battle_view.gd").build_objective(shown)
		heading.position = _proof_heading_rect.position
		heading.size = _proof_heading_rect.size
		_canvas.add_child(heading)
		for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
		var heading_label: Label = heading.find_child("PreBattleObjectiveTitle", true, false)
		_expect_fits(heading_label)
		_expect(heading.get_global_rect().encloses(heading_label.get_global_rect()), "Full pre-battle heading stays inside its panel")
		await _capture("objective_%02d" % index, {"full_title": Objectives.title_for_objective(objective), "hud_title": hud._title.text, "all_labels_fit": true})
		# Keyboard focus proof exercises the heading's existing tooltip path.
		if str(objective.get("special_type", "")) == "ember_hoarder":
			heading_label.grab_focus()
			for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
			await _capture("15_objective_keyboard_focus", {"focus_tooltip": true})
		heading.queue_free()
		index += 1

func _expect_fits(label: Label) -> void:
	_expect(label != null and label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "Untruncated objective text: " + (label.text if label != null else "missing label"))

func _pointer(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_canvas.push_input(motion, true)
	await process_frame

func _hover_enemy(source: Control) -> Window:
	await _pointer(Vector2.ZERO)
	# Match board_tile_tooltip_probe's native hover: canvas coordinates, routed
	# viewport input and the full tooltip delay. No detached debug panel.
	await _pointer(source.get_global_transform_with_canvas() * (source.size * 0.5))
	await create_timer(TOOLTIP_WAIT_SECONDS).timeout
	var deadline: int = Time.get_ticks_msec() + HOVER_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline:
		var popup: Window = _inspection_popup(_canvas)
		if popup != null: return popup
		await create_timer(HOVER_POLL_SECONDS).timeout
	return null

func _inspection_popup(parent: Node) -> Window:
	# Native tooltip Windows may be internal children of the viewport rather
	# than descendants returned by the hover source's find_children call.
	for child: Node in parent.get_children(true):
		if child is Window and child.visible and not child.is_queued_for_deletion() and child.theme_type_variation == &"TooltipPanel" and child.find_child("PreBattleEnemyInspection", true, false) != null:
			return child
		var found: Window = _inspection_popup(child)
		if found != null: return found
	return null

# Debug roster substitution uses the same pre-battle factory result, controls,
# native hover and inspector. It never changes encounter or enemy data.
func _capacitor_pre_battle() -> void:
	var preview: Dictionary = _scene.get("_pre_battle_preview_run_state").duplicate(true)
	preview["combat_state"]["enemies"] = Suite.fixture(["storm_capacitor"])["enemies"]
	_scene.set("_pre_battle_preview_run_state", preview)
	_scene.call("_rebuild_pre_battle_overlay")
	for frame: int in range(PROOF_SETTLE_FRAMES): await process_frame
	var panel: Control = _scene.get("_pre_battle_panel")
	var flow: Control = panel.find_child("PreBattleEnemyFlow", true, false)
	var source: Control = flow.get_child(0)
	var popup: Window = await _hover_enemy(source)
	_expect(popup != null, "Capacitor proof opens the real native moves panel")
	if popup != null:
		var inspection: Control = popup.find_child("PreBattleEnemyInspection", true, false)
		_expect(inspection != null and inspection.is_visible_in_tree(), "Actual Capacitor inspector is visible")
		if inspection != null:
			var labels := PackedStringArray()
			for label: Label in inspection.find_children("*", "Label", true, false): labels.append(label.text)
			_expect(labels.has("Charge") and labels.has("Arc Burst") and labels.has("+1") and labels.has("6") and not labels.has("Special action"), "Native Capacitor panel shows the approved numeric move rows")
		await _capture("16_capacitor_pre_battle_moves", {"native_hover": true, "moves": ["Charge", "Arc Burst"], "rows": ["+1", "6"]})
	await _pointer(Vector2.ZERO)
