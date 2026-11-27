extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const FIXTURE_SEED: int = 6
const INSTALL_COUNT: int = 3
const PROFILE_PATH: String = "user://qa136_profile.json"
const CHECKPOINT_PATH: String = "user://qa136_checkpoint.save"
const RELEASE_PROFILE_PATH: String = "res://tools/qa136/release_profile.json"
const CAPTURE_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 4
const CAPTURE_DIR: String = "user://qa136/1920x1080"
const RECOVERED_KILLERS := ["Felled by an Ash Hound", "Felled by an Ashen Reaver's Raking Flame"]

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_run_native" if "--native" in OS.get_cmdline_user_args() else "_run")

func _run() -> void:
	Store.set_storage_path(PROFILE_PATH)
	Store.set_run_storage_path(CHECKPOINT_PATH)
	root.set_meta(InitialGraph.SEED_OVERRIDE, FIXTURE_SEED)
	var scene: Node = RunScene.instantiate()
	root.add_child(scene)
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	await process_frame
	var state: Dictionary = scene.get("_run_state")
	var profile: Dictionary = pristine_profile()
	profile["run_counter"] = Store.load_data()["run_counter"]
	if state.is_empty() or not Store.save_data(profile):
		push_error("QA136 witness could not seed the run and profile")
		quit(1)
		return
	var before: String = FileAccess.get_file_as_string(PROFILE_PATH)
	var after: String = before
	var release: bool = "--release" in OS.get_cmdline_user_args()
	var passed: bool = true
	for install: int in range(1, INSTALL_COUNT + 1):
		scene.set("_progression", Store.load_data())
		scene.call("_load_run_state", state)
		after = FileAccess.get_file_as_string(PROFILE_PATH)
		print("QA136 install %d: profile bytes identical=%s" % [install, str(after == before)])
		passed = passed and ((after != before) == release)
	if release:
		print_diff(JSON.parse_string(before), JSON.parse_string(after), "profile")
		var fixture := FileAccess.open(RELEASE_PROFILE_PATH, FileAccess.WRITE)
		passed = passed and fixture != null
		if fixture != null:
			fixture.store_string(JSON.stringify(JSON.parse_string(after), "\t") + "\n")
			fixture.close()
	scene.queue_free()
	await _settle()
	if not release:
		passed = await _show_release_records(false) and passed
	print("QA136 %s INSTALL WITNESS: %s" % ["RELEASE" if release else "BRANCH", "PASS" if passed else "FAIL"])
	quit(0 if passed else 1)

func _run_native() -> void:
	var passed: bool = await _show_release_records(DisplayServer.get_name() != "headless")
	print("QA136 NATIVE FIXTURE %s: %s" % ["HEADLESS DRY RUN" if DisplayServer.get_name() == "headless" else "RENDER", "PASS" if passed else "FAIL"])
	quit(0 if passed else 1)

func _show_release_records(capture: bool) -> bool:
	var fixture: String = FileAccess.get_file_as_string(RELEASE_PROFILE_PATH)
	var profile := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if fixture.is_empty() or profile == null:
		return false
	profile.store_string(fixture)
	profile.close()
	Store.set_storage_path(PROFILE_PATH)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	if not Settings.save_settings(settings):
		return false
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = CAPTURE_SIZE
	root.size = CAPTURE_SIZE
	var presenter := SubViewportContainer.new()
	presenter.size = Vector2(CAPTURE_SIZE)
	root.add_child(presenter)
	var canvas := SubViewport.new()
	canvas.size = CAPTURE_SIZE
	canvas.msaa_2d = Viewport.MSAA_4X
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	presenter.add_child(canvas)
	var menu: Control = preload("res://scenes/main_menu.tscn").instantiate()
	canvas.add_child(menu)
	await _settle()
	if canvas.size != CAPTURE_SIZE or root.content_scale_factor != UI_SCALE:
		return false
	menu.call("_on_chronicle_button_pressed")
	var panel: Control = menu.get_node("ChroniclePanel")
	var records: Array = panel.get("records")
	var passed: bool = panel.visible and records.size() == RECOVERED_KILLERS.size()
	for index: int in range(records.size()):
		panel.call("select_record", index, false)
		await _settle()
		var subline := panel.find_child("ChronicleSubline", true, false) as RichTextLabel
		var flow: Node = panel.find_child("ChronicleRelics", true, false).get_child(1)
		var killer: String = subline.get_parsed_text().get_slice(" · ", subline.get_parsed_text().get_slice_count(" · ") - 1)
		var shown: Array = []
		for icon: Control in flow.get_children():
			var id: String = str(icon.name).trim_prefix("Relic_")
			var path: String = str(Data.relic_def(id).get("icon_path", ""))
			var texture: Texture2D = icon.get("texture")
			shown.append({"name": icon.get("tooltip_title"), "icon": path if texture != null else ""})
			passed = passed and texture != null and texture == Assets.load_texture(path)
		print("QA136 Chronicle %s: %s | relics=%s" % [records[index]["run_id"], killer, JSON.stringify(shown)])
		var relic: Dictionary = Data.relic_def("liturgy_of_ash")
		passed = passed and index < RECOVERED_KILLERS.size() and killer == RECOVERED_KILLERS[index]
		passed = passed and shown == [{"name": relic["name"], "icon": relic["icon_path"]}]
		if capture:
			passed = await _capture(canvas, str(records[index]["run_id"])) and passed
	passed = passed and FileAccess.get_file_as_string(PROFILE_PATH) == fixture
	print("QA136 Chronicle source profile bytes identical=%s" % str(FileAccess.get_file_as_string(PROFILE_PATH) == fixture))
	presenter.queue_free()
	await _settle()
	return passed

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(canvas: SubViewport, name: String) -> bool:
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	var path: String = CAPTURE_DIR.path_join(name + ".png")
	if image == null or image.get_size() != CAPTURE_SIZE:
		return false
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CAPTURE_DIR)) != OK or image.save_png(path) != OK:
		return false
	print(ProjectSettings.globalize_path(path))
	return true

static func pristine_profile() -> Dictionary:
	var profile: Dictionary = Store.default_data()
	var shapes: Array = []
	var keyed: Dictionary = {}
	var pattern := RegEx.create_from_string("(?i)(?<![[:alnum:]])ash[[:alnum:]_-]*")
	var catalogs: Dictionary = {
		"card": Data.cards(), "relic": Data.relics(), "enemy": Data.enemies(),
		"event": Data.events(), "omen": Data.omens(), "equipment": Data.equipment(),
		"npc": Data.npcs(), "upgrade": Data.upgrades()
	}
	for entry_id: String in Grimoire.entry_map():
		var parts: PackedStringArray = entry_id.split(":", false, 1)
		if parts.size() == 2 and not catalogs.has(parts[0]):
			catalogs[parts[0]] = {}
		if parts.size() == 2 and pattern.search(parts[1]) != null:
			catalogs[parts[0]][parts[1]] = true if not catalogs[parts[0]].has(parts[1]) else catalogs[parts[0]][parts[1]]
	for prefix: String in catalogs:
		for id: String in catalogs[prefix]:
			if pattern.search(id) == null:
				continue
			for spelling: String in [id, prefix + ":" + id]:
				if shapes.has(spelling): continue
				shapes.append(spelling)
				keyed[spelling] = spelling
	profile["qa136_catalog_ids"] = shapes
	profile["qa136_catalog_keys"] = keyed
	profile[Store.GRIMOIRE_UNLOCKED_KEY] = ["enemy:ash_hound", "enemy:ashen_reaver", "omen:tithe_of_ash"]
	profile[Store.GRIMOIRE_UNREAD_KEY] = profile[Store.GRIMOIRE_UNLOCKED_KEY].duplicate()
	profile[Store.CHRONICLE_RECORDS_KEY] = [
		_record("qa136-ambiguous", ["ashen_brand", "liturgy_of_ash"]),
		_record("qa136-reaver", ["ashen_phylactery", "liturgy_of_ash"])
	]
	profile[Store.CHRONICLE_RECORDS_KEY][1]["killer_text"] = "Felled by an Ashen Reaver's Raking Flame"
	return profile

static func _record(id: String, relics: Array) -> Dictionary:
	return {
		"run_id": id, "outcome": "defeat", "ended_at": "24 Nov",
		"section_name": "Cinder Crown", "section_names": ["Cinder Crown"],
		"section_index": 0, "room_index": 2, "room_total": 4, "score_total": 136,
		"path": [["combat", "combat"]], "dragon_ids": ["vyraketh"],
		"killer_text": "Felled by an Ash Hound", "relics": relics,
		"gear": ["training_sword"], "deck": [["pale_spark", 1]]
	}

static func print_diff(before: Variant, after: Variant, path: String) -> void:
	if before == after:
		return
	if before is Dictionary and after is Dictionary:
		for key: Variant in before:
			if not after.has(key):
				print("QA136 diff %s/%s: - %s" % [path, key, JSON.stringify(before[key])])
			else:
				print_diff(before[key], after[key], path + "/" + str(key))
		for key: Variant in after:
			if not before.has(key):
				print("QA136 diff %s/%s: + %s" % [path, key, JSON.stringify(after[key])])
	elif before is Array and after is Array and before.size() == after.size():
		for index: int in range(before.size()):
			print_diff(before[index], after[index], path + "/" + str(index))
	else:
		print("QA136 diff %s: %s -> %s" % [path, JSON.stringify(before), JSON.stringify(after)])
