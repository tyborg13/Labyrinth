extends RefCounted

const UiSkin = preload("res://scripts/ui_skin.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var feedback: Node = tree.root.get_node_or_null("CursorFeedback")
	expect.call(feedback != null, "Shared button sound should use the existing UI feedback owner")
	if feedback == null: return
	var router: Node = tree.root.get_node("InputRouter")
	var original_modality: String = str(router.call("modality"))
	SettingsStore.apply_audio_settings(SettingsStore.default_settings())
	while bool(feedback.call("is_loading")):
		await tree.process_frame
	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tree.root.add_child(surface)
	var skin := UiSkin.new()
	var first := Button.new()
	var second := OptionButton.new()
	second.add_item("Windowed")
	var disabled := Button.new()
	disabled.disabled = true
	var buttons: Array[BaseButton] = [first, second, disabled]
	for index: int in range(buttons.size()):
		var button: BaseButton = buttons[index]
		button.position = Vector2(80 + index * 240, 100)
		button.size = Vector2(200, 60)
		skin.apply_button_stylebox_overrides(button)
		surface.add_child(button)
	first.focus_next = first.get_path_to(second)
	second.focus_previous = second.get_path_to(first)
	first.focus_neighbor_right = first.get_path_to(second)
	await tree.process_frame
	_move(tree, Vector2(20, 20))
	await tree.process_frame
	var before: int = _count(feedback)
	_move(tree, first.get_global_rect().get_center())
	await tree.process_frame
	expect.call(_count(feedback) == before + 1, "Pointer entering an available action plays one focus cue")
	await _wait(tree)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = first.get_global_rect().get_center()
	press.pressed = true
	tree.root.push_input(press, true)
	press.pressed = false
	tree.root.push_input(press, true)
	await tree.process_frame
	expect.call(first.has_focus(), "Pointer press retains native button focus")
	expect.call(_count(feedback) == before + 1, "Click focus does not double the hover cue")
	skin.apply_button_stylebox_overrides(first, UiSkin.VARIANT_SELECTED)
	_move(tree, Vector2(20, 20))
	first.release_focus()
	await _wait(tree)
	_move(tree, first.get_global_rect().get_center())
	await tree.process_frame
	expect.call(_count(feedback) == before + 2, "Restyled controls keep a single connection and sound once on re-entry")
	_move(tree, Vector2(20, 20))
	first.grab_focus()
	await _wait(tree)
	before = _count(feedback)
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	tree.root.push_input(tab, true)
	tab.pressed = false
	tree.root.push_input(tab, true)
	await tree.process_frame
	expect.call(second.has_focus(), "Native keyboard traversal reaches the next action")
	expect.call(_count(feedback) == before + 1, "Keyboard traversal receives the same focus sound")
	first.grab_focus()
	await _wait(tree)
	before = _count(feedback)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_DPAD_RIGHT
	joy.pressed = true
	tree.root.push_input(joy, true)
	joy.pressed = false
	tree.root.push_input(joy, true)
	await tree.process_frame
	expect.call(second.has_focus(), "Controller directional input preserves native focus traversal")
	expect.call(_count(feedback) == before + 1, "Controller navigation receives one focus cue")
	second.release_focus()
	await _wait(tree)
	before = _count(feedback)
	_move(tree, disabled.get_global_rect().get_center())
	await tree.process_frame
	expect.call(_count(feedback) == before, "Disabled controls stay silent on hover")
	first.hide()
	first.mouse_entered.emit()
	expect.call(_count(feedback) == before, "Hidden controls cannot emit focus feedback")
	first.show()
	_move(tree, Vector2(20, 20))
	await tree.process_frame
	_move(tree, first.get_global_rect().get_center())
	_move(tree, second.get_global_rect().get_center())
	expect.call(_count(feedback) == before + 1, "Rapid target crossings cannot stack focus cues")
	var player: AudioStreamPlayer = feedback.get("_focus_player") as AudioStreamPlayer
	var entry: Dictionary = RunSfx.entry(RunSfx.HEARTH_FOCUS_ID)
	expect.call(player != null, "Hover feedback should acquire an audio player")
	if player != null:
		expect.call(player.stream == AssetLoader.load_audio_stream(str(entry["path"])), "Shared buttons reuse the exact approved Hearth waveform")
		expect.call(is_equal_approx(player.volume_db, float(entry["volume_db"])), "Shared buttons preserve the approved hover mix level")
		expect.call(player.bus == SettingsStore.UI_SFX_BUS and player.max_polyphony == 1, "Hover uses one dry UI voice")
		var muted: Dictionary = SettingsStore.default_settings()
		muted["sfx_volume"] = 0.0
		SettingsStore.apply_audio_settings(muted)
		expect.call(AudioServer.is_bus_mute(AudioServer.get_bus_index(SettingsStore.SFX_BUS)), "Player SFX mute silences the shared hover path")
		SettingsStore.apply_audio_settings(SettingsStore.default_settings())
	# Material-specific merchant controls opt into the same behavior without
	# acquiring an action-button plate or changing their native input paths.
	var merchant_scripts: Array[Script] = [
		preload("res://scripts/graftwright_choice.gd"),
		preload("res://scripts/scavenger_action.gd"),
		preload("res://scripts/scavenger_ware.gd")
	]
	_move(tree, Vector2(20, 20))
	for script: Script in merchant_scripts:
		var button: Button = script.new()
		button.position = Vector2(80, 220)
		button.size = Vector2(200, 60)
		surface.add_child(button)
		await _wait(tree)
		before = _count(feedback)
		button.grab_focus()
		expect.call(_count(feedback) == before + 1, "Merchant control receives shared navigation feedback: " + script.resource_path)
		button.queue_free()
		await tree.process_frame
	# Freeing a focused screen cannot leave its highlight state on the next one.
	surface.queue_free()
	await tree.process_frame
	var replacement := Button.new()
	replacement.position = Vector2(80, 100)
	replacement.size = Vector2(200, 60)
	skin.apply_button_stylebox_overrides(replacement)
	tree.root.add_child(replacement)
	await _wait(tree)
	before = _count(feedback)
	replacement.grab_focus()
	expect.call(_count(feedback) == before + 1, "New screens receive feedback after the old focused control is freed")
	replacement.queue_free()
	await tree.process_frame
	router.call("set_modality", original_modality)

static func _move(tree: SceneTree, point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.relative = Vector2(1, 1)
	tree.root.push_input(event, true)

static func _count(feedback: Node) -> int:
	return int(feedback.call("feedback_counts").get("focus", 0))

static func _wait(tree: SceneTree) -> void:
	# Feedback rate limits use wall time, including in an uncapped headless run.
	var deadline: int = Time.get_ticks_msec() + 110
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
