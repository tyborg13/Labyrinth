extends SceneTree
## perf-164 headless probe: synchronous loads, frame costs and semantic receipts
## on the six reviewed paths. Tools-only; production code is untouched.
## Cases: continue_pre_battle, arena, map_history, grimoire, chronicle, abandon_dragon.

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const GuardianInspection = preload("res://tools/guardian_inspection.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const GameData = preload("res://scripts/game_data.gd")
const Construction = preload("res://scripts/maquette_cutout_runtime/construction.gd")
const CardTile = preload("res://scripts/chronicle_card_tile.gd")
const SectionArt = preload("res://scripts/run_section_art.gd")
const Run = preload("res://scripts/run_engine.gd")
const VIEWPORT := Vector2i(1920, 1080)
const WAIT_FRAMES: int = 20000
const DRAGON_DEPTHS: Dictionary = {"vyraketh": 4, "iskaldra": 4, "zekarion": 4, "vaeloryx": 4, "tharokh": 4, "noctyrax": 24}

var case_name: String = ""
var fixture_name: String = ""
var output: String = ""
var run_seed: int = 7
var trace: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"
var telemetry: Node
var label: String = "boot"
var last_us: int = 0
var intervals: Array[Array]
var sync_loads: Array[Dictionary]
var prepared_loads: int = 0
var factory_begins: int = 0
var errors: PackedStringArray
var receipt: Dictionary = {}
var _hashes: Dictionary = {}
var storage: String = ""
var from_save: bool = false
var capture: bool = false
var deck: bool = false
var native: bool = DisplayServer.get_name() != "headless"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--case="): case_name = argument.trim_prefix("--case=")
		elif argument.begins_with("--fixture="): fixture_name = argument.trim_prefix("--fixture=")
		elif argument.begins_with("--output="): output = argument.trim_prefix("--output=")
		elif argument.begins_with("--seed="): run_seed = int(argument.trim_prefix("--seed="))
		elif argument.begins_with("--storage="): storage = argument.trim_prefix("--storage=")
		elif argument == "--from-save": from_save = true
		elif argument == "--capture": capture = true
		elif argument == "--deck": deck = true
	process_frame.connect(_on_frame)
	_run.call_deferred()

func _on_frame() -> void:
	var now: int = Time.get_ticks_usec()
	if last_us > 0: intervals.append([now - last_us, label])
	last_us = now
	if not trace: return
	if telemetry == null: telemetry = root.get_node_or_null("PerformanceTelemetry")
	if telemetry == null: return
	var events: Dictionary = telemetry.take_hitch_events()
	var phases: Dictionary = telemetry.take_hitch_phases()
	if phases.has("preparation:encounter:factory:begin"): factory_begins += 1
	for key: String in events:
		if not key.begins_with("texture_load:"): continue
		var parts: PackedStringArray = key.split(":", true, 2)
		var path: String = parts[2]
		var entry: Dictionary = events[key]
		var prepared: bool = false
		for prefix: String in ["preparation:texture:import:", "preparation:texture:source_upload:", "preparation:texture:source_fallback:"]:
			if phases.has(prefix + path): prepared = true
		if prepared:
			prepared_loads += int(entry["count"])
		else:
			sync_loads.append({"path": path, "label": label, "count": int(entry["count"]), "us": int(entry["total_us"]), "frame": Engine.get_process_frames()})

func _run() -> void:
	root.mode = Window.MODE_WINDOWED
	# --deck keeps the copy-only project's Deck window override (native timing).
	if not deck: root.size = VIEWPORT
	var directory: String = output if not output.is_empty() else OS.get_user_data_dir().path_join("perf164")
	DirAccess.make_dir_recursive_absolute(directory)
	output = directory
	# A shared absolute storage lets one process Save and Quit and the next Continue cold.
	var base: String = storage if not storage.is_empty() else "user://"
	if not storage.is_empty(): DirAccess.make_dir_recursive_absolute(storage)
	Store.set_storage_path(base.path_join("perf164-profile.json"))
	Store.set_run_storage_path(base.path_join("perf164-run.save"))
	Settings.set_storage_path(base.path_join("perf164-settings.json"))
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"display_mode": "windowed"} if deck else {"display_mode": "windowed", "ui_scale": 1.0}, true)
	# Pixel takes compare arms frame for frame: no motion, fixed 1920x1080 target.
	if capture: settings["reduced_motion"] = true
	if not Settings.save_settings(settings): errors.append("could not write settings")
	if native and not capture: DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_apply_capture_viewport()
	if not from_save: Store.clear_saved_run()
	match case_name:
		"save_quit_pre_battle": await _save_quit_pre_battle()
		"continue_pre_battle": await _continue_pre_battle()
		"arena": await _arena()
		"map_history": await _map_history()
		"grimoire": await _grimoire()
		"chronicle": await _chronicle()
		"abandon_dragon": await _abandon_dragon()
		"finish_dragon": await _finish_dragon()
		_: errors.append("unknown case " + case_name)
	_finish()

## perf-158's proof viewport: macOS clamps the window, so keep a fixed-size
## root render target and letterbox it in the host window.
func _apply_capture_viewport() -> void:
	if not capture: return
	root.content_scale_size = VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT

## Native pixel take: the drawn frame plus each touched control's region.
func _capture(name: String, nodes: Array) -> void:
	if not capture: return
	if not native:
		errors.append("--capture needs a native renderer")
		return
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.get_size() != VIEWPORT or not is_equal_approx(root.content_scale_factor, 1.0):
		errors.append("capture %s: expected 1920x1080 at 100%% UI scale, got %s at %.2f" % [name, str(image.get_size() if image != null else Vector2i.ZERO), root.content_scale_factor])
		return
	var path: String = output.path_join(name + ".png")
	if image.save_png(path) != OK:
		errors.append("could not write " + path)
		return
	print(path)
	var regions: Dictionary = {}
	for node: Variant in nodes:
		if not is_instance_valid(node) or not (node is Control) or not (node as Control).is_visible_in_tree(): continue
		var rect := Rect2i((node as Control).get_global_rect()).intersection(Rect2i(Vector2i.ZERO, VIEWPORT))
		if rect.has_area(): regions[str(root.get_path_to(node))] = {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "sha256": _sha(image.get_region(rect).get_data())}
	var captures: Dictionary = receipt.get("captures", {})
	captures[name] = {"path": path, "sha256": _sha(image.get_data()), "regions": regions}
	receipt["captures"] = captures

static func _sha(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _finish() -> void:
	receipt.merge({"case": case_name, "fixture": fixture_name, "seed": run_seed, "trace": trace, "errors": errors,
		"sync_loads": sync_loads, "sync_load_count": _count(sync_loads), "prepared_loads": prepared_loads,
		"factory_begins": factory_begins, "maquette_fallbacks": Construction.fallback_constructions,
		"frames": _frame_summary()}, true)
	var file := FileAccess.open(output.path_join("receipt.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(receipt, "  ", true))
	file.close()
	print("PERF164 PROBE: %s %s %s sync_loads=%d factory_begins=%d errors=%d" % [case_name, fixture_name, "PASS" if errors.is_empty() else "FAIL", _count(sync_loads), factory_begins, errors.size()])
	for error: String in errors: push_error(error)
	if is_instance_valid(current_scene): current_scene.queue_free()
	await process_frame
	await process_frame
	quit(0 if errors.is_empty() else 1)

static func _count(loads: Array[Dictionary]) -> int:
	var total: int = 0
	for entry: Dictionary in loads: total += int(entry["count"])
	return total

func _frame_summary() -> Dictionary:
	var result: Dictionary = {}
	for row: Array in intervals:
		var key: String = row[1]
		var entry: Dictionary = result.get(key, {"frames": 0, "total_us": 0, "max_us": 0, "first_us": int(row[0])})
		entry["frames"] += 1
		entry["total_us"] += int(row[0])
		entry["max_us"] = maxi(int(entry["max_us"]), int(row[0]))
		result[key] = entry
	return result

func _until(condition: Callable, what: String, limit: int = WAIT_FRAMES) -> bool:
	for frame: int in range(limit):
		if bool(condition.call()): return true
		await process_frame
	errors.append("timeout: " + what)
	return false

func _frames(count: int) -> void:
	for frame: int in range(count): await process_frame

func _seconds(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until: await process_frame

func _enter(path: String) -> Node:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	var scene: Node = (load(path) as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	_apply_capture_viewport()
	return scene

func _save(state: Dictionary) -> bool:
	if state.is_empty():
		errors.append("empty fixture")
		return false
	if not Store.save_data(state["progression"]) or not Store.save_run_state(state):
		errors.append("could not save fixture")
		return false
	return true

## Title -> Continue -> covered loading -> revealed run. Returns the run scene.
func _continue(state: Dictionary) -> Node:
	if not from_save and not _save(state): return null
	label = "title"
	var menu: Node = await _enter("res://scenes/main_menu.tscn")
	await _frames(30)
	label = "continue"
	var started: int = Time.get_ticks_usec()
	menu.call("_on_continue_button_pressed")
	var installed := func() -> bool:
		var scene: Node = current_scene
		return is_instance_valid(scene) and scene.has_method("_committed_run_state") and bool(scene.get("_initial_ui_complete")) and root.find_child("MenuRunTransition", false, false) == null
	if not await _until(installed, "covered Continue"): return null
	receipt["continue_wall_us"] = Time.get_ticks_usec() - started
	label = "revealed"
	_apply_capture_viewport()
	return current_scene

func _builder_state(kind: String, extra: Dictionary = {}) -> Dictionary:
	var builder := Fixtures.new()
	var state: Dictionary = builder.make(kind, run_seed, extra)
	if state.is_empty(): errors.append("fixture %s: %s" % [kind, builder.census_error])
	builder.free()
	return state

func _arena_state(name: String) -> Dictionary:
	var parts: PackedStringArray = name.split(":")
	if parts.size() != 2:
		errors.append("fixture must be guardian:<id> or dragon:<id>")
		return {}
	if parts[0] == "guardian":
		return _builder_state("guardian", {"guardian_id": parts[1], "guardian_case": "pre_battle"})
	if parts[0] == "dragon":
		return _builder_state("dragon", {"dragon_id": parts[1], "dragon_depth": int(DRAGON_DEPTHS.get(parts[1], 4)), "dragon_case": "pre_battle"})
	if parts[0] == "room":
		return _builder_state("pre_battle")
	errors.append("unknown arena fixture " + name)
	return {}

# --- 1 and 2: Continue into pre-battle ------------------------------------------

## The review's route: Save and Quit from the pre-battle screen (real save path).
func _save_quit_pre_battle() -> void:
	if fixture_name.is_empty(): fixture_name = "room:pre_battle"
	var state: Dictionary = _arena_state(fixture_name)
	if state.get("mode") != "pre_battle":
		errors.append("fixture is not pre-battle")
		return
	var scene: Node = await _continue(state)
	if scene == null: return
	if not await _until(func() -> bool: return is_instance_valid(scene._pre_battle_scrim) and scene._pre_battle_scrim.is_visible_in_tree(), "pre-battle preview"): return
	await _seconds(2.0)
	label = "save_quit"
	scene.call("_on_save_and_quit_pressed")
	if not await _until(func() -> bool: return is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/main_menu.tscn", "title after Save and Quit"): return
	await _frames(30)
	for name: String in ["perf164-run.save", "perf164-profile.json"]:
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(storage.path_join(name))
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(bytes)
		receipt["sha256:" + name] = context.finish().hex_encode()
	receipt["saved_mode"] = Store.read_resumable_checkpoint().get("state", {}).get("mode", "")

func _continue_pre_battle() -> void:
	if fixture_name.is_empty(): fixture_name = "room:pre_battle"
	var state: Dictionary = {} if from_save else _arena_state(fixture_name)
	if not from_save and state.get("mode") != "pre_battle":
		errors.append("fixture is not pre-battle")
		return
	var scene: Node = await _continue(state)
	if scene == null: return
	if not await _until(func() -> bool: return is_instance_valid(scene._pre_battle_scrim) and scene._pre_battle_scrim.is_visible_in_tree(), "pre-battle preview"): return
	await process_frame
	receipt["pre_battle_first_frame"] = _snapshot(scene._pre_battle_panel)
	await _capture("pre_battle_first", [scene._pre_battle_panel])
	await _frames(60)
	# Compare the settled preview: its reveal tween is wall-clock driven.
	label = "settled"
	await _seconds(3.0)
	receipt["pre_battle"] = _snapshot(scene._pre_battle_panel)
	await _capture("pre_battle_settled", [scene._pre_battle_panel])
	receipt["ink_pools"] = _ink_pools(scene._pre_battle_panel)

func _ink_pools(panel: Node) -> Array:
	var result: Array = []
	for node: Node in panel.find_children("*", "Control", true, false):
		var script: Script = node.get_script()
		if script == null or not script.resource_path.ends_with("ui_ink_pool_stage.gd"): continue
		var path: String = script.call("texture_path", node.variant)
		result.append({"node": str(panel.get_path_to(node)), "variant": node.variant, "texture": _texture_receipt(Assets.load_texture(path))})
	return result

# --- 3: Guardian and dragon arena entry through ordinary travel -----------------

func _arena() -> void:
	var state: Dictionary = _arena_state(fixture_name)
	if state.is_empty(): return
	var arena: Vector2i = state["current_room"]
	var engine := Run.new()
	var predecessor: Dictionary = {}
	for room: Dictionary in (state["rooms"] as Dictionary).values():
		for link: Dictionary in room.get("connections", []):
			if link["coord"] == arena and int(room.get("section_index", -1)) == int(Graph.room(state, arena).get("section_index", -2)):
				predecessor = room
		if not predecessor.is_empty(): break
	if predecessor.is_empty():
		errors.append("no predecessor room for " + fixture_name)
		return
	predecessor["cleared"] = true
	predecessor["visited"] = true
	predecessor["revealed"] = true
	var target: Dictionary = Graph.room(state, arena)
	target["visited"] = false
	target["cleared"] = false
	state["current_room"] = predecessor["coord"]
	state["mode"] = "room"
	state["combat_state"] = {}
	state.erase("pre_battle_pending")
	state.erase("pre_battle_travel_dir")
	state["current_room_layout"] = engine._display_layout_for_room(int(state["seed"]), predecessor, Vector2i.ZERO)
	Graph.refresh_knowledge(state)
	if not engine.available_moves(state).has(arena):
		errors.append("arena is not an available move from its predecessor")
		return
	var scene: Node = await _continue(state)
	if scene == null: return
	scene.call("_close_dialogue")
	await _frames(60)
	label = "travel"
	var started: int = Time.get_ticks_usec()
	scene.call("_on_map_view_room_selected", arena)
	if not await _until(func() -> bool: return str(scene._run_state.get("mode", "")) == "pre_battle" and is_instance_valid(scene._pre_battle_scrim) and scene._pre_battle_scrim.is_visible_in_tree(), "arena pre-battle"): return
	receipt["travel_wall_us"] = Time.get_ticks_usec() - started
	label = "preview"
	await _capture("arena_preview", [scene._pre_battle_panel])
	await _frames(30)
	label = "begin"
	started = Time.get_ticks_usec()
	scene.call("_on_pre_battle_start_pressed")
	if not await _until(func() -> bool: return str(scene._run_state.get("mode", "")) == "combat", "arena combat"): return
	receipt["board"] = _board_receipt(scene)
	await _capture("arena_first_combat", [scene.board_view])
	await process_frame
	label = "opening"
	if not await _until(func() -> bool: return not bool(scene._animation_lock), "arena opening", 3000): return
	receipt["begin_wall_us"] = Time.get_ticks_usec() - started
	label = "combat"
	await _frames(60)

func _board_receipt(scene: Node) -> Dictionary:
	var board: Node = scene.board_view
	var units: Dictionary = {}
	for field: String in ["_unit_textures", "_unit_rear_textures"]:
		var textures: Dictionary = board.get(field)
		for type: String in textures:
			units["%s:%s" % [field, type]] = _texture_receipt(textures[type] as Texture2D)
	return units

# --- 4: Map history tab ---------------------------------------------------------

func _map_history() -> void:
	var state: Dictionary = _builder_state("start")
	if state.is_empty(): return
	var section: int = 3
	var entry: Vector2i = Graph.section(state, section).get("entry", Graph.INVALID)
	# Each earlier section is walked from its entry to its cleared boss.
	for index: int in range(section):
		var info: Dictionary = Graph.section(state, index)
		var from: Vector2i = state["current_room"] if index == 0 else info.get("entry", Graph.INVALID)
		if not GuardianInspection._mark_route(state, from, info.get("boss", Graph.INVALID)):
			errors.append("no route through section %d" % index)
			return
	if entry == Graph.INVALID:
		errors.append("no Section IV entry")
		return
	for index: int in range(section + 1): Graph.section(state, index)["entered"] = true
	Graph.room(state, entry).merge({"visited": true, "revealed": true, "cleared": true}, true)
	var room: Dictionary = Graph.room(state, entry)
	state["current_room"] = entry
	state["mode"] = "room"
	state["combat_state"] = {}
	state["current_room_layout"] = Run.new()._display_layout_for_room(int(state["seed"]), room, Vector2i.ZERO)
	Graph.refresh_knowledge(state)
	var scene: Node = await _continue(state)
	if scene == null: return
	scene.call("_close_dialogue")
	await _frames(60)
	if Graph.active_section(scene._run_state) != section:
		errors.append("the resumed run is not in Section IV")
		return
	var history: Array = []
	for index: int in range(section): history.append(SectionArt.background_path(Graph.section(scene._run_state, index)))
	receipt["history_cached_before_open"] = history.map(func(path: String) -> bool: return Assets.has_cached_texture(path))
	label = "map_open"
	var map: Control = scene._large_map_view
	scene.call("_open_large_map")
	await process_frame
	receipt["map_first_frame"] = _snapshot(map)
	await _capture("map_first", [map])
	receipt["map_first_background"] = _texture_receipt(map._background.texture)
	label = "map_idle"
	await _frames(240)
	receipt["history_cached_before_select"] = history.map(func(path: String) -> bool: return Assets.has_cached_texture(path))
	var selections: Array = []
	for index: int in [0, 1, 2]:
		label = "select_%d" % index
		var started: int = Time.get_ticks_usec()
		map.call("select_section", index)
		var cost: int = Time.get_ticks_usec() - started
		await process_frame
		selections.append({"section": index, "call_us": cost, "background": _texture_receipt(map._background.texture), "panel": _snapshot(map)})
		await _capture("map_section_%d" % index, [map._background, map])
		label = "after_%d" % index
		await _frames(30)
	receipt["selections"] = selections
	label = "settled"
	scene.call("_close_large_map")
	await _frames(5)

# --- 5: Grimoire and Chronicle --------------------------------------------------

func _discovered_profile_entries(state: Dictionary, card_ids: Array) -> Array[String]:
	var entries: Array[String]
	for card_id: String in card_ids:
		for entry_id: String in Grimoire.entry_ids_for_card_id(card_id): entries.append(entry_id)
	var progression: Dictionary = state["progression"]
	var unlocked: Array = (progression.get(Grimoire.UNLOCKED_KEY, []) as Array).duplicate()
	for entry_id: String in entries:
		if not unlocked.has(entry_id): unlocked.append(entry_id)
	progression[Grimoire.UNLOCKED_KEY] = Grimoire.ordered_entry_ids(unlocked)
	return entries

const OLD_DECK: Array = ["rockburst", "frostbolt", "molten_reach", "root_snare", "storm_beacon", "dawnstep", "reprise", "gust_step", "chain_bolt"]

func _grimoire() -> void:
	var state: Dictionary = _builder_state("start")
	if state.is_empty(): return
	var candidates: Array = []
	for card_id: String in OLD_DECK:
		if not (state.get("deck_cards", []) as Array).has(card_id) and not GameData.card_def(card_id).is_empty(): candidates.append(card_id)
	var entries: Array[String] = _discovered_profile_entries(state, candidates)
	state["progression"].erase(Grimoire.UNREAD_KEY)
	var scene: Node = await _continue(state)
	if scene == null: return
	scene.call("_close_dialogue")
	await _frames(60)
	label = "grimoire_open"
	scene.call("_open_grimoire_overlay")
	await process_frame
	receipt["grimoire_first_frame"] = _snapshot(scene._grimoire_dialog)
	await _capture("grimoire_first", [scene._grimoire_dialog])
	label = "grimoire_idle"
	await _frames(240)
	# The open section first, then each other section through its own tab:
	# its pass starts after the switch's first frame, before any selection.
	var sections: Array[String]
	sections.append(str(scene._grimoire_selected_section))
	for entry_id: String in entries:
		var entry_section: String = str(Grimoire.entry_def(entry_id).get("section", ""))
		if not sections.has(entry_section): sections.append(entry_section)
	var switches: Array = []
	for index: int in range(sections.size()):
		var section: String = sections[index]
		if index > 0:
			label = "switch:" + section
			var switch_started: int = Time.get_ticks_usec()
			scene.call("_on_grimoire_section_pressed", section)
			switches.append({"section": section, "call_us": Time.get_ticks_usec() - switch_started})
			await process_frame
			label = "switch_idle:" + section
			await _frames(240)
		for entry_id: String in entries:
			if str(Grimoire.entry_def(entry_id).get("section", "")) == section: await _select_grimoire_entry(scene, entry_id)
	receipt["switches"] = switches
	label = "settled"
	scene.call("_close_grimoire_overlay")
	await _frames(5)

func _select_grimoire_entry(scene: Node, entry_id: String) -> void:
	var selections: Array = receipt.get("selections", [])
	label = "select:" + entry_id
	var started: int = Time.get_ticks_usec()
	scene.call("_on_grimoire_entry_pressed", entry_id)
	var cost: int = Time.get_ticks_usec() - started
	await process_frame
	selections.append({"entry": entry_id, "call_us": cost, "icon": _texture_receipt(scene._grimoire_detail_icon.texture), "detail": _snapshot(scene._grimoire_detail_content)})
	receipt["selections"] = selections
	if entry_id.begins_with("magick:"): await _capture("grimoire_" + entry_id.replace(":", "_"), [scene._grimoire_detail_content, scene._grimoire_detail_icon])
	label = "after:" + entry_id
	await _frames(20)

func _chronicle() -> void:
	var state: Dictionary = _builder_state("defeat")
	if state.is_empty(): return
	var progression: Dictionary = state["progression"]
	for index: int in range(4):
		var deck: Array = []
		for offset: int in range(4): deck.append([OLD_DECK[(index * 2 + offset) % OLD_DECK.size()], 1 + offset % 2])
		progression = Store.record_chronicle(progression, {"run_id": "perf164-%d" % index, "outcome": "defeat",
			"section_name": "Worldspine Roots", "section_index": 0, "score_total": 100 + index, "path": [["combat"]],
			"section_names": ["Worldspine Roots"], "deck": deck, "relics": ["iron_buckler"], "gear": ["iron_cleaver", "ward_kite"]})
	state["progression"] = progression
	# The recap's seeded title reads the run identity; fix it across processes.
	state["analytics"] = {"run_id": "run_perf164_chronicle", "combat_counter": 0}
	# A terminal run has no Continue: install the defeat on a fresh run scene, as
	# the recap appears after the final fight (the art caches are equally cold).
	if not Store.save_data(progression):
		errors.append("could not save the Chronicle profile")
		return
	label = "install"
	var scene: Node = await _enter("res://scenes/run_scene.tscn")
	await _frames(10)
	scene.set("_progression", progression)
	scene.call("_load_run_state", state)
	label = "revealed"
	var recap: Control = scene.get("_run_end_recap")
	if not await _until(func() -> bool: return is_instance_valid(recap) and recap.is_visible_in_tree(), "run-end recap"): return
	await _frames(120)
	recap.call("skip_presentation")
	await _frames(30)
	label = "chronicle_open"
	recap.call("_open_chronicle")
	var panel: Control = recap.get("_chronicle")
	await process_frame
	receipt["chronicle_first_frame"] = _snapshot(panel)
	await _capture("chronicle_first", [panel])
	label = "chronicle_idle"
	await _frames(240)
	var selections: Array = []
	for index: int in range(1, mini(5, (panel.get("records") as Array).size())):
		label = "select_record_%d" % index
		var started: int = Time.get_ticks_usec()
		panel.call("select_record", index, true)
		var cost: int = Time.get_ticks_usec() - started
		await process_frame
		selections.append({"record": index, "call_us": cost, "detail": _snapshot(panel.get("_detail"))})
		await _capture("chronicle_record_%d" % index, [panel.get("_detail")])
		label = "after_record_%d" % index
		await _frames(20)
	receipt["selections"] = selections
	label = "settled"
	await _frames(5)

# --- 6: Abandon a dragon fight --------------------------------------------------

## Dragon defeat (defeat:<id>) or the final victory (victory:noctyrax): the
## engine's own finish path, the recap, then the recap's Main Menu.
func _finish_dragon() -> void:
	if fixture_name.is_empty(): fixture_name = "defeat:tharokh"
	var parts: PackedStringArray = fixture_name.split(":")
	var state: Dictionary = _builder_state("dragon", {"dragon_id": parts[1], "dragon_depth": int(DRAGON_DEPTHS.get(parts[1], 4)), "dragon_case": "encounter"})
	if state.get("mode") != "combat":
		errors.append("dragon fixture is not a fight")
		return
	var scene: Node = await _continue(state)
	if scene == null: return
	scene.call("_close_dialogue")
	await _frames(60)
	receipt["cache_in_fight"] = _cache_keys()
	var battle: Dictionary = (scene._combat_state as Dictionary).duplicate(true)
	if parts[0] == "defeat":
		battle["player"]["hp"] = 0
	else:
		for index: int in range((battle["enemies"] as Array).size()):
			if str(battle["enemies"][index]["type"]) == parts[1]:
				battle = scene._combat_engine._damage_enemy(battle, index, int(battle["enemies"][index]["hp"]) + 999, true, true)
				break
	var finished: Dictionary = scene._combat_checkpoint_with_shared_map_events(scene._run_state, battle, true)
	if parts[0] == "victory": finished = scene._run_engine.continue_dragon_reward(finished)
	if str(finished.get("mode", "")) != parts[0]:
		errors.append("finish produced mode %s" % str(finished.get("mode", "")))
		return
	label = "recap"
	scene.call("_load_run_state", finished)
	var recap: Control = scene.get("_run_end_recap")
	# Teardown reads only the committed terminal mode; the recap may still be presenting.
	for frame: int in range(600):
		if is_instance_valid(recap) and recap.is_visible_in_tree(): break
		await process_frame
	receipt["recap_visible"] = is_instance_valid(recap) and recap.is_visible_in_tree()
	receipt["terminal_mode"] = str(scene._run_state.get("mode", ""))
	await _frames(60)
	label = "main_menu"
	scene.call("_on_back_to_menu_pressed")
	if not await _until(func() -> bool:
		return is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/main_menu.tscn" and root.find_child("DepartedRunCleanup", false, false) == null
	, "title after the recap"): return
	label = "title_after"
	await _frames(60)
	receipt["cache_at_title"] = _cache_keys()

func _abandon_dragon() -> void:
	if fixture_name.is_empty(): fixture_name = "dragon:tharokh"
	var parts: PackedStringArray = fixture_name.split(":")
	var state: Dictionary = _builder_state("dragon", {"dragon_id": parts[1], "dragon_depth": int(DRAGON_DEPTHS.get(parts[1], 4)), "dragon_case": "encounter"})
	if state.get("mode") != "combat":
		errors.append("dragon fixture is not a fight")
		return
	var scene: Node = await _continue(state)
	if scene == null: return
	scene.call("_close_dialogue")
	await _frames(60)
	receipt["cache_in_fight"] = _cache_keys()
	label = "abandon"
	scene.call("_on_abandon_run_pressed")
	if not await _until(func() -> bool:
		return is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/main_menu.tscn" and root.find_child("DepartedRunCleanup", false, false) == null
	, "title after abandon"): return
	label = "title_after"
	await _frames(60)
	receipt["cache_at_title"] = _cache_keys()
	receipt["checkpoint_cleared"] = Store.read_resumable_checkpoint().get("state", {}).is_empty()

func _cache_keys() -> Dictionary:
	var keys: Array = Assets._texture_cache.keys()
	keys.sort()
	var bytes: int = 0
	for path: String in keys:
		var texture: Texture2D = Assets._texture_cache[path] as Texture2D
		if texture != null: bytes += texture.get_width() * texture.get_height() * 4
	return {"textures": keys, "rgba8_bytes": bytes, "maquette_sources": Construction._sources.size()}

# --- Semantic receipts ----------------------------------------------------------

func _texture_receipt(texture: Texture2D) -> Variant:
	if texture == null: return null
	var result: Dictionary = {"class": texture.get_class(), "source": str(texture.get_meta("asset_source_path", texture.resource_path)), "size": [texture.get_width(), texture.get_height()]}
	if texture is AtlasTexture:
		result["region"] = str((texture as AtlasTexture).region)
		result["atlas"] = _texture_receipt((texture as AtlasTexture).atlas)
		return result
	result["pixels"] = _pixel_hash(texture)
	return result

func _pixel_hash(texture: Texture2D) -> String:
	var id: int = texture.get_instance_id()
	if _hashes.has(id): return _hashes[id]
	var image: Image = texture.get_image()
	var digest: String = "no-image"
	if image != null and not image.is_empty():
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(image.get_data())
		digest = "%dx%d:%s" % [image.get_width(), image.get_height(), context.finish().hex_encode().left(24)]
	_hashes[id] = digest
	return digest

func _snapshot(node: Node) -> Array:
	var rows: Array = []
	if not is_instance_valid(node): return rows
	_snapshot_into(node, node, rows)
	return rows

func _snapshot_into(base: Node, node: Node, rows: Array) -> void:
	if node is CanvasItem and not (node as CanvasItem).is_visible_in_tree(): return
	var row: Dictionary = {"node": str(base.get_path_to(node)), "class": node.get_class()}
	var script: Script = node.get_script()
	if script != null: row["script"] = script.resource_path.get_file()
	if node is Control:
		var control := node as Control
		var rect: Rect2 = control.get_global_rect()
		row["rect"] = [snappedf(rect.position.x, 0.01), snappedf(rect.position.y, 0.01), snappedf(rect.size.x, 0.01), snappedf(rect.size.y, 0.01)]
	if node is CanvasItem:
		row["modulate"] = (node as CanvasItem).modulate.to_html()
		row["self_modulate"] = (node as CanvasItem).self_modulate.to_html()
	for property: String in ["texture", "icon", "texture_normal"]:
		var value: Variant = node.get(property) if property in node else null
		if value is Texture2D: row[property] = _texture_receipt(value)
	for property: String in ["text", "variant", "feet_anchor", "pool_size", "figure_width"]:
		if property in node and node.get(property) != null: row[property] = str(node.get(property))
	rows.append(row)
	for child: Node in node.get_children():
		_snapshot_into(base, child, rows)
