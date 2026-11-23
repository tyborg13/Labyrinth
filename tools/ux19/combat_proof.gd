extends RefCounted

const Keys = preload("res://scripts/key_bindings.gd")
const Movement = preload("res://tests/suites/movement_undo_suite.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")

const COMBAT_SEED: int = 123
const UNLOCK_TIMEOUT_MSEC: int = 15000
const SETTLE_FRAMES: int = 5
const EMPOWER_CARD := "overclock"
const REBOUND := {
	Keys.PASS: KEY_Q, Keys.HURRY: KEY_F, Keys.EMPOWER: KEY_G,
	Keys.UNDO_WALK: KEY_V, Keys.ENEMY_INTENTS: KEY_J, Keys.MAP: KEY_K,
}

static func setup(tree: SceneTree, viewport: SubViewport, profile: Dictionary, check: Callable) -> Control:
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await _settle(tree)
	var engine := Run.new()
	var run: Dictionary = engine.create_new_run(COMBAT_SEED, profile)
	for candidate: Vector2i in engine.available_moves(run):
		if str(engine.room_metadata(run, candidate).get("type", "")) != "combat": continue
		var state: Dictionary = engine.begin_pre_battle_combat(engine.move_to_pre_battle(run, candidate))
		scene.call("_load_run_state", state)
		await _settle(tree)
		check.call(await _wait_unlocked(tree, scene), "Real combat fixture unlocks")
		return scene
	check.call(false, "Fixture seed offers a combat room")
	return scene

static func verify(tree: SceneTree, scene: Control, check: Callable) -> void:
	var viewport := scene.get_viewport()
	var defaults: Dictionary = Keys.defaults()
	var old_key := func(action: String) -> void: await send_key(tree, viewport, defaults[action])
	var new_key := func(action: String) -> void: await send_key(tree, viewport, REBOUND[action])
	var gameplay_before: Dictionary = scene.get("_combat_state").duplicate(true)
	await old_key.call(Keys.ENEMY_INTENTS)
	check.call(not scene.get("_show_all_enemy_intents"), "Old I leaves enemy intents off")
	await new_key.call(Keys.ENEMY_INTENTS)
	check.call(scene.get("_show_all_enemy_intents"), "Rebound J shows enemy intents")
	var intents: Button = scene.get("_enemy_intent_toggle_button")
	var intent_mark: Label = intents.find_child("IntentKey", true, false)
	check.call(intent_mark.visible and intent_mark.text == "J" and intents.tooltip_text.ends_with("[J]"), "Details mark and tooltip show J")

	var map: Control = scene.get("_large_map_scrim")
	await old_key.call(Keys.MAP)
	check.call(not map.visible, "Old M leaves Map closed")
	await new_key.call(Keys.MAP)
	check.call(map.visible, "Rebound K opens Map")
	await new_key.call(Keys.MAP)
	check.call(not map.visible, "Rebound K closes Map")
	check.call(scene.get("mini_map_overlay").tooltip_text == "Map [K]" and scene.get("_section_map_hud_button").tooltip_text == "Map [K]", "Map tooltips show K")

	var pacing: Node = scene.get("_combat_pacing")
	scene.set("_animation_lock", true)
	pacing.begin_enemies()
	var speed: float = Engine.time_scale
	viewport.push_input(key_event(defaults[Keys.HURRY], true), true)
	check.call(is_equal_approx(Engine.time_scale, speed), "Old Space leaves enemy pacing unchanged")
	viewport.push_input(key_event(defaults[Keys.HURRY], false), true)
	viewport.push_input(key_event(REBOUND[Keys.HURRY], true), true)
	check.call(is_equal_approx(Engine.time_scale, speed * 2.0), "Rebound F holds hurry in real combat pacing")
	viewport.push_input(key_event(REBOUND[Keys.HURRY], false), true)
	check.call(is_equal_approx(Engine.time_scale, speed), "Releasing F ends hurry")
	pacing.end_scope()
	scene.set("_animation_lock", false)

	# Keep the production wiring, with the walk suite's reversible board fixture.
	var before: Dictionary = Movement.install(scene)
	await _settle(tree)
	await Movement.walk(scene)
	await _settle(tree)
	var after_walk: Dictionary = scene.get("_combat_state").duplicate(true)
	var undo: Button = scene.get("_movement_undo_button")
	var undo_mark: Label = undo.find_child("UndoKey", true, false)
	check.call(after_walk != before and undo.visible and undo_mark.visible and undo_mark.text == "V", "Walk exposes reversible Undo marked V")
	await old_key.call(Keys.UNDO_WALK)
	check.call(scene.get("_combat_state") == after_walk, "Old Z leaves the walk in place")
	await new_key.call(Keys.UNDO_WALK)
	check.call(await _wait_unlocked(tree, scene) and scene.get("_combat_state") == before, "Rebound V restores the pre-walk state")
	await Movement.walk(scene)
	await _settle(tree)
	await send_key(tree, viewport, KEY_Z, KEY_Z, true)
	check.call(await _wait_unlocked(tree, scene) and scene.get("_combat_state") == before, "Fixed Ctrl+Z restores the walk after rebinding")
	await Movement.walk(scene)
	await _settle(tree)
	await send_key(tree, viewport, KEY_Z, KEY_Z, false, true)
	check.call(await _wait_unlocked(tree, scene) and scene.get("_combat_state") == before, "Fixed Cmd+Z restores the walk after rebinding")

	var empower_state: Dictionary = before.duplicate(true)
	empower_state["deck"]["hand"] = [EMPOWER_CARD]
	scene.set("_combat_state", empower_state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _settle(tree)
	await scene.call("_on_card_pressed", 0)
	await _settle(tree)
	var widget: Control = scene.call("_hand_card_control", 0)
	var seal: Control = widget.get_node_or_null("EmpowerSeal")
	check.call(seal != null and seal.get("hint") == "G" and seal.tooltip_text.ends_with("Click the seal or press G"), "Empower seal and tooltip show G")
	await old_key.call(Keys.EMPOWER)
	check.call(not scene.call("_selected_card_empowered"), "Old E leaves Empower off")
	await new_key.call(Keys.EMPOWER)
	check.call(scene.call("_selected_card_empowered"), "Rebound G toggles Empower")
	await new_key.call(Keys.EMPOWER)
	await send_key(tree, viewport, KEY_ESCAPE)

	# Unbind with the production Settings panel while combat and its HUD exist.
	scene.call("_open_menu_overlay")
	scene.call("_open_settings_overlay")
	await _settle(tree)
	var panel: Control = scene.get("_settings_panel")
	for action: String in Keys.DEFAULT_KEYS:
		var caps: Dictionary = panel.get("_keycaps")
		(caps[action] as Button).grab_focus()
		await send_key(tree, viewport, KEY_ENTER)
		await send_key(tree, viewport, KEY_DELETE)
	scene.call("_close_menu_overlay")
	await _settle(tree)
	var pass_mark: Label = scene.find_child("PassKeyHint", true, false)
	check.call(pass_mark != null and not pass_mark.visible and not intent_mark.visible and not undo_mark.visible, "Unbinding hides the Pass, Details and Undo marks")
	check.call(intents.tooltip_text.find("[") == -1 and scene.get("mini_map_overlay").tooltip_text == "Map", "Unbinding removes the Details and Map tooltip marks")
	await old_key.call(Keys.PASS)
	await new_key.call(Keys.PASS)
	check.call(not scene.get("_animation_lock") and scene.get("_combat_state").get("turn") == empower_state.get("turn"), "Unbound Pass ignores both the old and replacement key")
	await scene.call("_on_card_pressed", 0)
	await _settle(tree)
	widget = scene.call("_hand_card_control", 0)
	seal = widget.get_node_or_null("EmpowerSeal")
	check.call(seal != null and seal.get("hint") == "" and seal.tooltip_text.ends_with("Click the seal"), "Unbound Empower hides its seal mark and drops the key from its tooltip")
	await send_key(tree, viewport, KEY_ESCAPE)

	# Restore fixture settings for the native Pass capture and the restart check.
	Settings.save_preferences(_with_rebound(Settings.load_settings()))
	Settings.apply_settings(Settings.load_settings(), scene.get_window(), false)
	scene.call("_on_settings_changed", Settings.load_settings())
	var fresh_run: Dictionary = scene.get("_run_state").duplicate(true)
	fresh_run["combat_state"] = gameplay_before
	scene.call("_load_run_state", fresh_run)
	await _settle(tree)
	check.call(await _wait_unlocked(tree, scene), "Pass proof returns to unlocked combat")
	pass_mark = scene.find_child("PassKeyHint", true, false)
	check.call(pass_mark != null and pass_mark.visible and pass_mark.text == "Q", "Live Pass face shows the rebound Q")
	var turn: int = int(scene.get("_combat_state").get("turn"))
	await old_key.call(Keys.PASS)
	check.call(not scene.get("_animation_lock") and int(scene.get("_combat_state").get("turn")) == turn, "Old P does not pass")
	var redraw := func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": tree.process_frame.connect(redraw)
	await new_key.call(Keys.PASS)
	check.call(await _wait_unlocked(tree, scene) and int(scene.get("_combat_state").get("turn")) > turn, "Rebound Q passes the turn")
	if tree.process_frame.is_connected(redraw): tree.process_frame.disconnect(redraw)

static func _with_rebound(settings: Dictionary) -> Dictionary:
	settings[Keys.SETTING] = REBOUND.duplicate()
	return settings

static func key_event(physical: Key, down: bool, logical: Key = KEY_NONE) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = physical if logical == KEY_NONE else logical
	event.physical_keycode = physical
	event.pressed = down
	return event

static func send_key(tree: SceneTree, viewport: Viewport, physical: Key, logical: Key = KEY_NONE, ctrl: bool = false, meta: bool = false) -> void:
	for down: bool in [true, false]:
		var event := key_event(physical, down, logical)
		event.ctrl_pressed = ctrl
		event.meta_pressed = meta
		viewport.push_input(event, true)
		await tree.process_frame

static func _settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame

static func _wait_unlocked(tree: SceneTree, scene: Node) -> bool:
	var deadline: int = Time.get_ticks_msec() + UNLOCK_TIMEOUT_MSEC
	while scene.get("_animation_lock") and Time.get_ticks_msec() < deadline: await tree.process_frame
	return not scene.get("_animation_lock")
