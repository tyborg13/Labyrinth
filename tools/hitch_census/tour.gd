extends RefCounted
## Fixture-labelled screen census. Whole/demo drivers supply natural transition evidence.
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const CombatStops = preload("res://tools/hitch_census/combat_stops.gd")
const Store = preload("res://scripts/progression_store.gd")
const DepthRules = preload("res://scripts/depth_rules.gd")
const SCENARIOS: Array = ["start", "pre_battle", "combat", "guided_tutorial", "reward", "campfire", "treasure", "character", "scavenger", "graftwright", "boss", "guardian", "dragon", "snare", "warband", "last_light", "ember_hoarder", "event", "victory", "defeat"]
const OVERLAY_FIELDS: Dictionary = {"map": "_large_map_scrim", "character": "_upgrade_scrim", "grimoire": "_grimoire_scrim", "settings": "_settings_panel"}
const SITUATION_SECONDS: float = 1.0
const OVERLAYS: Array = [["map", "_open_large_map", "_close_large_map"], ["character", "_on_loadout_button_pressed", "_close_card_upgrade_overlay"], ["grimoire", "_open_grimoire_overlay", "_close_grimoire_overlay"], ["settings", "_open_settings_overlay", "_close_settings_overlay"]]

func run_tharokh(host: SceneTree) -> void:
	var builder := Fixtures.new()
	var release_builder := Callable(builder, "free")
	host.census_finished.connect(release_builder, CONNECT_ONE_SHOT)
	var installed: bool = await _install(host, builder, "tharokh")
	if is_instance_valid(builder):
		host.census_finished.disconnect(release_builder)
		builder.free()
	if installed and not host.finished:
		host.coverage["stop:tharokh"] = true
		await CombatStops.play(host, "tharokh")

static func missing_tharokh(coverage: Dictionary) -> PackedStringArray:
	var missing := PackedStringArray()
	for key: String in ["stop:tharokh", "playback:tharokh"]:
		if not coverage.has(key): missing.append(key)
	return missing

func run(host: SceneTree) -> void:
	host.mark("title", "tour")
	await host._enter_scene("res://scenes/main_menu.tscn")
	await host.hold(SITUATION_SECONDS)
	if host.finished: return
	if not is_instance_valid(host.scene) or not host.scene.is_visible_in_tree():
		host.errors.append("Tour title scene did not open")
		return
	host.coverage["stop:title"] = true
	await _difficulty_table(host)
	if host.finished: return
	var builder := Fixtures.new()
	# A timeout can exit the process while a fixture or Pass is awaiting frames.
	var release_builder := Callable(builder, "free")
	host.census_finished.connect(release_builder, CONNECT_ONE_SHOT)
	for kind: String in SCENARIOS + CombatStops.CASES.keys():
		if host.finished: break
		if not await _install(host, builder, kind): continue
		host.coverage["stop:" + kind] = true
		if CombatStops.CASES.has(kind): await CombatStops.play(host, kind)
		if kind == "start":
			for item: Array in OVERLAYS:
				if host.finished: break
				await _overlay(host, item)
	if is_instance_valid(builder):
		host.census_finished.disconnect(release_builder)
		builder.free()

static func missing_stops(coverage: Dictionary) -> PackedStringArray:
	var required := PackedStringArray(["stop:title", "table:difficulty_table"])
	for kind: String in SCENARIOS: required.append("stop:" + kind)
	for kind: String in CombatStops.CASES: required.append("playback:" + kind)
	for label: String in OVERLAY_FIELDS: required.append("overlay:" + label)
	var missing := PackedStringArray()
	for key: String in required:
		if not coverage.has(key): missing.append(key)
	return missing

func _install(host: SceneTree, builder: SceneTree, kind: String) -> bool:
	host.mark(kind, "fixture_prepare")
	var state: Dictionary = builder.make(kind, host.run_seed)
	if state.is_empty():
		host.errors.append(kind + ": " + builder.census_error)
		return false
	host.mark(kind, "fixture_install")
	if host.staged_tharokh_tour:
		if not await _resume_on_cover(host, state): return false
	else:
		await host._enter_scene("res://scenes/run_scene.tscn")
		if host.finished: return false
		host.scene.set("_progression", state["progression"])
		host.scene.call("_load_run_state", state)
	host.scene.call("_close_dialogue")
	await host.settle()
	if host.finished: return false
	host.mark(kind, "tour_visible")
	await host.hold(SITUATION_SECONDS)
	if host.finished: return false
	if not is_instance_valid(host.scene):
		host.errors.append(kind + ": the fixture scene was removed during the stop")
		return false
	var installed: Dictionary = host.scene.get("_run_state")
	if installed.get("mode") != state.get("mode") or installed.get("current_room") != state.get("current_room") or installed.get("seed") != state.get("seed"):
		host.errors.append(kind + ": requested fixture state did not remain installed")
		return false
	return true

func _resume_on_cover(host: SceneTree, state: Dictionary) -> bool:
	if not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		host.errors.append("Could not write the Tharokh tour checkpoint")
		return false
	await host._enter_scene("res://scenes/main_menu.tscn")
	var started: int = Time.get_ticks_usec()
	host.scene.call("_on_continue_button_pressed")
	while not host.finished and is_instance_valid(host.current_scene) and not host.current_scene.has_method("_committed_run_state"):
		await host.process_frame
	if host.finished: return false
	if not is_instance_valid(host.current_scene) or not host.current_scene.has_method("_committed_run_state"):
		host.errors.append("The Tharokh tour checkpoint did not resume")
		return false
	host.scene = host.current_scene
	host.coverage["tharokh_resume_wall_us"] = Time.get_ticks_usec() - started
	return true

func _overlay(host: SceneTree, item: Array) -> void:
	var label: String = item[0]
	host.mark(label, "tour_open")
	if label == "settings": host.scene.call("_open_menu_overlay")
	host.scene.call(item[1])
	await host.hold(SITUATION_SECONDS)
	if host.finished: return
	var panel: Control = host.scene.get(OVERLAY_FIELDS[label])
	if is_instance_valid(panel) and panel.is_visible_in_tree():
		host.coverage["overlay:" + label] = true
	else:
		host.errors.append("Tour overlay did not open: " + label)
	if host.scene.has_method(item[2]): host.scene.call(item[2])
	if label == "settings": host.scene.call("_close_menu_overlay")

func _difficulty_table(host: SceneTree) -> void:
	var profile: Dictionary = host.scene.get("_progression").duplicate(true)
	profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = DepthRules.MAX_DEPTH
	profile[Store.UMBRA_DEPTH_SELECTED_KEY] = DepthRules.MAX_DEPTH
	host.scene.set("_progression", profile)
	host.mark("difficulty_table", "tour_open")
	host.scene.call("_open_new_descent")
	await host.hold(SITUATION_SECONDS)
	if host.finished: return
	var panel: Control = host.scene.get("_new_descent_panel")
	var final_row: Control = panel.find_child("ModifierText%d" % DepthRules.MAX_DEPTH, true, false) if is_instance_valid(panel) else null
	if final_row == null or not final_row.is_visible_in_tree() or panel.get("selected_depth") != DepthRules.MAX_DEPTH:
		host.errors.append("Difficulty table did not show its final tier")
	else:
		host.coverage["table:difficulty_table"] = {"depth": panel.get("selected_depth")}
	host.scene.call("_close_new_descent")
