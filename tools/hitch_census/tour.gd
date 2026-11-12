extends RefCounted
## Fixture-labelled screen census. Whole/demo drivers supply natural transition evidence.
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const SCENARIOS: Array = ["start", "pre_battle", "combat", "guided_tutorial", "reward", "campfire", "treasure", "character", "scavenger", "graftwright", "boss", "guardian", "dragon", "snare", "warband", "last_light", "ember_hoarder", "event", "victory", "defeat"]
const OVERLAY_FIELDS: Dictionary = {"map": "_large_map_scrim", "character": "_upgrade_scrim", "grimoire": "_grimoire_scrim", "settings": "_settings_panel"}
const SITUATION_SECONDS: float = 1.0
const OVERLAYS: Array = [["map", "_open_large_map", "_close_large_map"], ["character", "_on_loadout_button_pressed", "_close_card_upgrade_overlay"], ["grimoire", "_open_grimoire_overlay", "_close_grimoire_overlay"], ["settings", "_open_settings_overlay", "_close_settings_overlay"]]

func run(host: SceneTree) -> void:
	host.mark("title", "tour")
	await host._enter_scene("res://scenes/main_menu.tscn")
	await host.hold(SITUATION_SECONDS)
	var builder := Fixtures.new()
	for kind: String in SCENARIOS:
		if host.finished: break
		# Include generation/loading in the trace, but label it as fixture work.
		host.mark(kind, "fixture_prepare")
		var state: Dictionary = builder.make(kind, host.run_seed)
		if state.is_empty():
			host.errors.append(kind + ": " + builder.census_error)
			continue
		host.mark(kind, "fixture_install")
		await host._enter_scene("res://scenes/run_scene.tscn")
		host.scene.set("_progression", state["progression"])
		host.scene.call("_load_run_state", state)
		host.scene.call("_close_dialogue")
		await host.settle()
		host.mark(kind, "tour_visible")
		await host.hold(SITUATION_SECONDS)
		if kind == "start":
			for item: Array in OVERLAYS:
				host.mark(str(item[0]), "tour_open")
				if str(item[0]) == "settings": host.scene.call("_open_menu_overlay")
				host.scene.call(item[1])
				await host.hold(SITUATION_SECONDS)
				var panel: Control = host.scene.get(OVERLAY_FIELDS[item[0]])
				if panel == null or not panel.is_visible_in_tree(): host.errors.append("Tour overlay did not open: " + str(item[0]))
				if host.scene.has_method(item[2]): host.scene.call(item[2])
				if str(item[0]) == "settings": host.scene.call("_close_menu_overlay")
	builder.free()
