extends "res://tests/scavenger_shop_probe.gd"
## Integrated purchase proof: transaction semantics, lifetime and real render.
## Reuses only the shop fixture and controller/probe utilities from its owner.

const SettingsStore = preload("res://scripts/settings_store.gd")
const PURCHASE_OUTPUT := "user://merchant_acquisition_probe/1920x1080_ui100"
var _purchase_viewport: SubViewport

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://merchant_acquisition_probe/progression.json")
	ProgressionStore.set_run_storage_path("user://merchant_acquisition_probe/run.save")
	SettingsStore.set_storage_path("user://merchant_acquisition_probe/settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PURCHASE_OUTPUT))
	await _capture_states()
	print(ProjectSettings.globalize_path(PURCHASE_OUTPUT))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_states() -> void:
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_purchase_viewport = SubViewport.new()
	_purchase_viewport.size = VIEWPORT_SIZE
	_purchase_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_purchase_viewport)
	_purchase_viewport.add_child(instance)
	await _settle()
	var engine := RunEngine.new()
	instance.call("_load_run_state", _scavenger_state(engine))
	await _settle()
	instance.call("_close_dialogue")
	await create_timer(0.60).timeout
	var shop: Control = instance.get("_scavenger_shop_view") as Control
	var effects: Control = shop.get("_purchase_effects") as Control
	_assert(shop.visible, "Live Scavenger shop should be visible")
	var id: String = "grave_mortar"
	var source: Control = _offer_source(shop, id, false)
	shop.call("_select_item", id, false, source)
	await _settle()
	await _save("01_selected.png")
	var before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var sound_before: int = _sound_generations(instance)
	instance.call("_on_merchant_buy_pressed", RunEngine.MERCHANT_SCAVENGER, id, source)
	var after: Dictionary = instance.get("_run_state") as Dictionary
	_assert(int(after["held_embers"]) == int(before["held_embers"]) - engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, id), "Purchase charges exact cost immediately")
	_assert((after["magic_inventory"] as Array).has(id), "Purchase grants owned magic immediately")
	_assert(not bool(instance.get("_merchant_trade_animation_active")), "Fanfare must not lock the next trade")
	_assert(effects.get_child_count() == 1, "Successful purchase creates one persistent receipt")
	_assert(_sound_generations(instance) == sound_before + 1, "Successful purchase plays one reward cue")
	_assert(_last_sound_is_reward(instance), "Purchase uses the production reward accepted cue")
	var currency: Label = shop.get("_currency_label") as Label
	_assert(currency.text == "EMBERS  %d" % int(after["held_embers"]), "Currency reflects ownership before fanfare ends")
	await create_timer(0.16).timeout
	await _save("02_magic_lift.png")
	# Rebuild the entire UI during lift. The owned receipt must survive.
	instance.call("_refresh_ui")
	await process_frame
	_assert(effects.get_child_count() == 1, "Ordinary full UI refresh preserves in-flight receipt")
	await create_timer(0.25).timeout
	await _save("03_magic_flight.png")
	await create_timer(0.36).timeout
	await _save("04_pack_arrival.png")
	await create_timer(0.30).timeout
	_assert(effects.get_child_count() == 0, "Receipt releases its proxy after arrival")
	await _save("05_settled.png")
	# A repeated stale request is denied by the real engine and stays silent.
	sound_before = _sound_generations(instance)
	before = (instance.get("_run_state") as Dictionary).duplicate(true)
	instance.call("_on_merchant_buy_pressed", RunEngine.MERCHANT_SCAVENGER, id, null)
	_assert_same_inventory(before, instance.get("_run_state") as Dictionary, "Stale repeat cannot charge twice")
	_assert(_sound_generations(instance) == sound_before and effects.get_child_count() == 0, "Denied repeat has no acquisition feedback")
	# Two different purchases can finish immediately while both receipts play.
	for next_id: String in ["duelist_rapier", "nail_bomb"]:
		instance.call("_on_merchant_buy_pressed", RunEngine.MERCHANT_SCAVENGER, next_id, _offer_source(shop, next_id, false))
	await process_frame
	_assert(effects.get_child_count() == 2, "Rapid distinct purchases retain independent receipts")
	await create_timer(0.14).timeout
	await _save("06_rapid_gear_item.png")
	instance.call("_on_merchant_hide_pressed")
	await process_frame
	_assert(not shop.visible and effects.get_child_count() == 0, "Closing cancels visual receipts without orphaned proxies")
	instance.call("_on_merchant_return_to_shop_pressed")
	await _settle()
	_assert(effects.get_child_count() == 0, "Reopening cannot replay purchase fanfare")
	await _save("07_reopened.png")
	# Actual insufficient-funds engine path, rather than only the disabled button.
	var poor: Dictionary = _scavenger_state(engine)
	poor["held_embers"] = 0
	poor["unbanked_embers"] = 0
	instance.call("_load_run_state", poor)
	instance.call("_close_dialogue")
	await _settle()
	before = (instance.get("_run_state") as Dictionary).duplicate(true)
	sound_before = _sound_generations(instance)
	instance.call("_on_merchant_buy_pressed", RunEngine.MERCHANT_SCAVENGER, "icicle_lance", _offer_source(shop, "icicle_lance", false))
	_assert_same_inventory(before, instance.get("_run_state") as Dictionary, "Unaffordable purchase cannot mutate inventory or embers")
	_assert(_sound_generations(instance) == sound_before and effects.get_child_count() == 0, "Unaffordable request stays silent and creates no receipt")
	# Reduced motion keeps feedback but removes movement, scale and particles.
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = true
	instance.set("_settings", settings)
	instance.call("_load_run_state", _scavenger_state(engine))
	instance.call("_close_dialogue")
	await _settle()
	sound_before = _sound_generations(instance)
	instance.call("_on_merchant_buy_pressed", RunEngine.MERCHANT_SCAVENGER, "icicle_lance", _offer_source(shop, "icicle_lance", false))
	_assert(_sound_generations(instance) == sound_before + 1, "Reduced-motion purchase still plays one cue")
	await create_timer(0.12).timeout
	var effect: Control = effects.get_child(0) as Control
	_assert(bool(effect.get("reduced_motion")), "Receipt follows reduced-motion setting")
	_assert(not (effect.get("proxy") as Control).visible, "Reduced motion suppresses travelling card proxy")
	await _save("08_reduced_confirmation.png")
	await create_timer(0.60).timeout
	_assert(effects.get_child_count() == 0, "Reduced receipt expires independently")
	instance.queue_free()
	await process_frame

func _sound_generations(instance: Node) -> int:
	var result: int = 0
	for player: AudioStreamPlayer in instance.get("_sfx_players") as Array:
		result += int(player.get_meta("play_generation", 0))
	return result

func _last_sound_is_reward(instance: Node) -> bool:
	for player: AudioStreamPlayer in instance.get("_sfx_players") as Array:
		if str(player.get_meta("sfx_id", "")) == "run.reward_accepted" and player.playing:
			return true
	return false

func _assert(value: bool, message: String) -> void:
	if not value:
		_fail(message)

func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _purchase_viewport.get_texture().get_image()
	_assert(image.get_size() == VIEWPORT_SIZE, "Proof must be native 1920x1080")
	image.save_png(ProjectSettings.globalize_path(PURCHASE_OUTPUT.path_join(filename)))

func _assert_same_inventory(before: Dictionary, after: Dictionary, message: String) -> void:
	# Rejection is allowed to update the engine-owned explanatory notice.
	for key: String in ["held_embers", "equipment_inventory", "magic_inventory", "item_inventory", "reward_cards", "deck_cards"]:
		_assert(before.get(key) == after.get(key), "%s (%s)" % [message, key])
