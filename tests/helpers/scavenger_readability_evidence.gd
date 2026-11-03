extends RefCounted

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Reading = preload("res://tests/helpers/card_reading_contexts.gd")
const ProofViewport = preload("res://tests/helpers/card_legibility_viewport.gd")
const OUTPUT: String = "res://tests/pt13_03/feedback3/scavenger_inspection.json"
const PROFILE_PATH: String = "user://pt13_03_focus_profile.json"
const RUN_PATH: String = "user://pt13_03_focus_run.save"
const SETTINGS_PATH: String = "user://pt13_03_focus_settings.json"
var pressed_count: int = 0

func run(tree: SceneTree, expect: Callable) -> Dictionary:
	Reading.Store.set_storage_path(PROFILE_PATH)
	Reading.Store.set_run_storage_path(RUN_PATH)
	Reading.Settings.set_storage_path(SETTINGS_PATH)
	var settings: Dictionary = Reading.Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["display_mode"] = Reading.Settings.DISPLAY_WINDOWED
	Reading.Settings.save_settings(settings)
	Reading.Store.save_data(preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(Reading.Store.default_data()))
	Reading.Store.clear_saved_run()
	var viewport: SubViewport = ProofViewport.create(tree)
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	await Reading._settle(tree)
	var engine := Reading.RunEngine.new()
	var state: Dictionary = Reading.Magic.shop_fixture(engine)
	state["rooms"]["2,1"][Reading.RunEngine.MERCHANT_STOCK_KEY] = Reading.SHOP_MAGIC_FIXTURE + Reading.SHOP_GEAR_FIXTURE + Reading.SHOP_ITEM_FIXTURE
	scene.call("_load_run_state", engine.repair_loaded_run_state(state))
	scene.call("_close_dialogue")
	await Reading._settle(tree)
	var shop: Control = scene.get("_scavenger_shop_view")
	var original_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	var observations: Array = []
	for id: String in Reading.SHOP_MAGIC_FIXTURE:
		var button: Button = shop.find_child("MagicOffer_" + id, true, false)
		expect.call(button != null, "Live Scavenger contains test offer " + id)
		if button == null: continue
		button.pressed.connect(func() -> void: pressed_count += 1)
		# Real GUI focus dispatches focus_entered; no activation or private
		# selection callback is used to expose the production detail panel.
		button.grab_focus()
		await Reading._settle(tree)
		var host: Control = shop.get("_detail_card_host")
		var widgets: Array = []
		Reading._collect_faces(host, widgets)
		var shown: bool = widgets.size() == 1 and widgets[0].card_id == id and shop.get("_detail_panel").is_visible_in_tree()
		expect.call(viewport.gui_get_focus_owner() == button and shown, "Focus without activation shows the same card in scavenger_detail: " + id)
		var measurement: Dictionary = Audit.measure(widgets[0]) if shown else {}
		if shown:
			var minimum: float = INF
			for px: Variant in measurement["text_px"].values():
				if px != null: minimum = minf(minimum, float(px))
			measurement["minimum_text_px"] = minimum
			measurement["native_card_size"] = [widgets[0].size.x, widgets[0].size.y]
			var ancestor_scale: Vector2 = widgets[0].get_global_transform_with_canvas().get_scale()
			measurement["ancestor_scale"] = [ancestor_scale.x, ancestor_scale.y]
			expect.call(widgets[0].size == Audit.Card.BASE_CARD_SIZE and ancestor_scale.is_equal_approx(Vector2.ONE), "Focused detail keeps the complete 250x352 composition at scale 1: " + id)
			expect.call(minimum != INF and minimum + Audit.EPSILON >= 16.0, "Focused detail renders every shown rules/number role at 16px: " + id)
			measurement.erase("runs")
		observations.append({"offer": id, "route": "Control.grab_focus -> focus_entered -> _focus_item -> _select_item -> _sync_detail -> _render_detail_card", "focus_owner": str(viewport.gui_get_focus_owner().name), "detail_visible": shown, "measurement": measurement})
	expect.call(pressed_count == 0, "Inspection evidence emitted no pressed signal or click")
	expect.call(scene.get("_run_state") == original_state, "Focus inspection preserves inventory, deck and Embers")
	var result: Dictionary = {"branch": "focus_without_click", "pressed_signals": pressed_count, "run_state_unchanged": scene.get("_run_state") == original_state, "observations": observations, "shop_sha256": FileAccess.get_sha256("res://scripts/scavenger_shop_view.gd")}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.get_base_dir()))
	var file := FileAccess.open(OUTPUT, FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t") + "\n")
	scene.free()
	ProofViewport.dispose(viewport)
	return result
