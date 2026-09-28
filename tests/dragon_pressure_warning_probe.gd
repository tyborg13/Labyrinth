extends SceneTree

## Staged warning coverage, not a played encounter or queue/balance study.
## Start with the inspection recipe, then resolve the actual boss four times.
## Only setup health and the displayed current actor are restored; production
## terrain, surfaces, trails, helpers, held areas, positions and RNG carry on.
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Held = preload("res://scripts/guardian_combat_rules.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const ROSTER = {"vyraketh":4, "tharokh":8, "iskaldra":12, "vaeloryx":16, "zekarion":20, "noctyrax":24}
const GRIMOIRE_ENTRIES = ["combat:boss_eclipse", "enemy:noctyrax"]
const OUTPUT: String = "user://probes/dragon_pressure_warnings"
const SOURCES = [
	"data/enemies.json", "data/cards.json", "data/relics.json", "data/equipment.json", "data/grimoire.json",
	"scripts/combat_engine.gd", "scripts/run_engine.gd", "scripts/game_data.gd",
	"scripts/dragon_combat_rules.gd", "scripts/guardian_combat_rules.gd", "scripts/dragon_pressure_fields.gd",
	"scripts/committed_pattern_shapes.gd", "scripts/board_surface_rules.gd", "scripts/room_generator.gd",
	"scripts/run_scene.gd", "scripts/combat_board_view.gd", "scripts/dragon_presentation.gd", "scripts/grimoire_library.gd", "scripts/action_icon_library.gd",
	"tools/dragon_boss_inspection.gd", "tools/inspection_fixture.gd", "tests/dragon_pressure_warning_probe.gd"
]
var scene: Node
var canvas: SubViewport
var failures: Array[String]
var witnesses: Array[Dictionary]
var grimoire_witnesses: Array[Dictionary]
var combat := Combat.new()
var engine := Run.new()

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var source_hashes: Dictionary = _source_hashes()
	Store.set_storage_path("user://pressure_warning_profile.json")
	Store.set_run_storage_path("user://pressure_warning_run.save")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://pressure_warning_events")
	Settings.set_storage_path("user://pressure_warning_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	_expect(Settings.save_settings(settings), "Save isolated 100% UI settings")
	Settings.apply_settings(settings, root, false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var roster: Dictionary = _roster()
	for boss_id: String in roster:
		await _cycle(boss_id, int(roster[boss_id]))
	_expect(witnesses.size() == roster.size()*4, "Every requested authored warning has a distinct capture")
	if _include_grimoire():
		await _grimoire_pages()
		_expect(grimoire_witnesses.size() == _grimoire_entries().size(), "Every requested revised Grimoire page has a capture")
	_extra_assertions()
	_expect(source_hashes == _source_hashes(), "Declared source inputs stayed unchanged throughout the capture")
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"), FileAccess.WRITE)
	_expect(file != null, "Warning witness report can be written")
	if file != null:
		file.store_string(JSON.stringify(_json_value({
			"schema":1, "kind":"staged_production_warning_coverage", "native_play":false,
			"viewport":[1920,1080], "ui_scale":1.0, "source_sha256":source_hashes,
			"limits":[
				"Balanced inspection builds at depths 4/8/12/16/20/24, with the same default seed search, progression, skills and natural deck.",
				"Warnings after entry are staged by direct production boss resolution, not by playing cards or advancing the full initiative queue.",
				"Player HP/max HP become 999 only during setup resolution, then return to the inspection entry values; the entry current actor is restored for the warning UI.",
				"Terrain, surfaces, trails, helpers, held source snapshots, positions, statuses and RNG retain actual resolver results. Helpers do not take separate turns.",
				"The full input state and prior resolution action summaries are recorded. Warning agreement is with production preview, not a claim of every tile being unoccluded in the image.",
				"The source hash map covers the named inputs only; it is not a whole-repository artifact receipt or final-HEAD signoff."
			], "warnings":witnesses, "grimoire_pages":grimoire_witnesses, "failures":failures
		}), "  "))
		file.close()
	print("DRAGON PRESSURE WARNINGS: ", "PASS" if failures.is_empty() else "FAIL", " warnings=", witnesses.size(), " ", failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _roster() -> Dictionary:
	return ROSTER

func _include_grimoire() -> bool:
	return true

func _grimoire_entries() -> Array[String]:
	var result: Array[String]
	result.assign(GRIMOIRE_ENTRIES)
	return result

func _extra_assertions() -> void:
	pass

func _cycle(boss_id: String, depth: int) -> void:
	var options: Dictionary = {"dragon_id":boss_id, "dragon_depth":depth, "dragon_case":"encounter", "dragon_build":"balanced"}
	var progression: Dictionary = Store.default_data()
	progression["level"] = Factory.default_level(depth)
	progression["skill_ids"] = preload("res://scripts/skill_tree_library.gd").normalized_ids(Factory.default_skills(depth))
	progression = preload("res://scripts/contextual_combat_tutorial.gd").dismiss_tutorial(progression)
	var seed_value: int = Factory.seed_for_options(options)
	var original: Dictionary = Factory.build(engine, combat, engine.create_new_run(seed_value, progression), options)
	var state: Dictionary = original["combat_state"].duplicate(true)
	var entry_player: Dictionary = state["player"].duplicate(true)
	var entry_actor: Dictionary = state["current_actor"].duplicate(true)
	var seen: Dictionary = {}
	var previous_resolution: Dictionary = {}
	for phase: int in range(4):
		var index: int = _boss_index(state, boss_id)
		_expect(index >= 0, boss_id + " remains alive for all four staged warnings")
		if index < 0: return
		state["current_actor"] = entry_actor.duplicate(true)
		state["player"]["hp"] = entry_player["hp"]
		state["player"]["max_hp"] = entry_player["max_hp"]
		var enemy: Dictionary = state["enemies"][index]
		var intent_id: String = str(enemy["intent"]["id"])
		_expect(not seen.has(intent_id), boss_id + " has a distinct warning for phase " + str(phase))
		seen[intent_id] = true
		var label: String = "%02d_%s_d%02d_%s" % [witnesses.size()+1, boss_id, depth, intent_id]
		var before_preview: Dictionary = state.duplicate(true)
		var expected: Dictionary = combat.enemy_threat_tiles(state, index)
		var sources: Array[Dictionary] = _action_sources(state, enemy)
		_expect(state == before_preview, label + " preview/source reads preserve the resolver state and RNG")
		var run: Dictionary = original.duplicate(true)
		run["combat_state"] = state.duplicate(true)
		scene.set("_progression", run["progression"].duplicate(true))
		scene.call("_load_run_state", run)
		scene.call("_close_dialogue")
		scene.call("_close_large_map")
		scene.call("_set_show_all_enemy_intents", false)
		# Deferred choice-bar/hand refresh can trail the board by several frames.
		# Capture the settled player HUD rather than the first valid tile preview.
		var settle_deadline: int = Time.get_ticks_msec()+2000
		while Time.get_ticks_msec() < settle_deadline:
			await process_frame
			if int(scene.get("_hand_layout_pending_revision")) != int(scene.get("_hand_layout_revision")) and (scene.get("_play_meter") as Control).is_visible_in_tree() and (scene.get("_movement_meter") as Control).is_visible_in_tree():
				break
		_expect((scene.get("_play_meter") as Control).is_visible_in_tree(), label + " settled card-play budget is visible")
		_expect((scene.get("_movement_meter") as Control).is_visible_in_tree(), label + " settled movement budget is visible")
		await scene.call("_on_board_tile_clicked", enemy["pos"])
		await process_frame
		await RenderingServer.frame_post_draw
		var board: Node = scene.get("board_view")
		var shown: Dictionary = board.get("presentation")
		var previews: Array = shown.get("enemy_threat_previews", [])
		var actual: Dictionary = previews[0].duplicate(true) if previews.size() == 1 else {}
		var enemy_key: String = "enemy_%d" % int(enemy["id"])
		_expect(actual.get("enemy_key", "") == enemy_key, label + " production UI focuses this visible boss")
		actual.erase("enemy_key")
		_expect(actual == expected, label + " displayed warning matches complete production preview")
		_expect(shown.get("expanded_enemy_actor_keys", []).has(enemy_key), label + " keeps the authored intent text expanded")
		var image: Image = canvas.get_texture().get_image()
		_expect(image.get_size() == Vector2i(1920,1080), label + " renders at native 1920×1080")
		_expect(image.save_png(OUTPUT.path_join(label+".png")) == OK, label + " image saved")
		witnesses.append({
			"image":label+".png", "staged":true, "boss":boss_id, "depth":depth, "phase":phase,
			"seed":seed_value, "fixture_options":options, "progression_level":progression["level"],
			"skill_ids":progression["skill_ids"], "deck_cards":original["deck_cards"], "relics":original["relics"],
			"intent":enemy["intent"].duplicate(true), "action_sources":sources,
			"expected_warning":expected, "rendered_warning":actual,
			"projected_attack_tiles":shown.get("projected_attack_tiles", []),
			"expanded_enemy_actor_keys":shown.get("expanded_enemy_actor_keys", []),
			"resolver_state":state.duplicate(true), "previous_resolution":previous_resolution
		})
		print(ProjectSettings.globalize_path(OUTPUT.path_join(label+".png")))
		if phase == 3: break
		# Health protection exists only in setup. Do not replace declared source
		# fields or force a new intent: the resolver owns the next declaration.
		var setup: Dictionary = state.duplicate(true)
		setup["player"]["hp"] = 999
		setup["player"]["max_hp"] = 999
		var result: Dictionary = combat.resolve_enemy_turn_with_steps(setup, index)
		previous_resolution = {"intent_id":intent_id, "time_cost":result.get("time_cost", 0), "actions":_step_summary(result.get("steps", []))}
		state = result["state"].duplicate(true)
	for authored: Dictionary in Data.enemy_def(boss_id).get("intents", []):
		_expect(seen.has(str(authored["id"])), boss_id + " captures authored warning " + str(authored["id"]))

func _grimoire_pages() -> void:
	# Explicit page unlock is staged navigation only, without changing any copy.
	var unlocked: Dictionary = Grimoire.unlock_entries(scene.get("_run_state"), _grimoire_entries())
	var run: Dictionary = unlocked["state"]
	scene.set("_progression", run["progression"].duplicate(true))
	scene.call("_load_run_state", run)
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	scene.call("_open_grimoire_overlay")
	for entry_id: String in _grimoire_entries():
		scene.call("_on_grimoire_entry_pressed", entry_id)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var definition: Dictionary = Grimoire.entry_def(entry_id)
		var title: Label = scene.get("_grimoire_detail_title")
		var body: RichTextLabel = scene.get("_grimoire_detail_body")
		_expect(title.text == str(definition["title"]), entry_id + " selected production page is visible")
		_expect(body.text == str(scene.call("_grimoire_body_text", definition)), entry_id + " retains all authored rules")
		if GRIMOIRE_ENTRIES.has(entry_id):
			_expect(body.text.contains("fixed marked ground"), entry_id + " distinguishes marked ground from Eclipse darkness")
		_expect(body.is_visible_in_tree() and body.get_content_height() <= body.size.y+1.0, entry_id + " rules fit without clipping")
		var name: String = "grimoire_"+entry_id.replace(":", "_")+".png"
		var image: Image = canvas.get_texture().get_image()
		_expect(image.get_size() == Vector2i(1920,1080), entry_id + " native 1920×1080 page")
		_expect(image.save_png(OUTPUT.path_join(name)) == OK, entry_id + " image saved")
		grimoire_witnesses.append({"image":name, "entry_id":entry_id, "title":title.text, "body":body.text, "authored":definition, "body_height":body.get_content_height(), "available_height":body.size.y})
		print(ProjectSettings.globalize_path(OUTPUT.path_join(name)))
	scene.call("_close_grimoire_overlay")

func _action_sources(state: Dictionary, enemy: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for action: Dictionary in enemy["intent"].get("actions", []):
		var source: Dictionary = {"action":action.duplicate(true), "shape":Held.shape(action), "held":Held.handles(action)}
		if Held.handles(action):
			source["live_tiles_at_current_body"] = Held.live_tiles(combat, state, enemy, action)
			# The warning itself includes planned movement and sequential actions;
			# these live tiles are source evidence, not a replacement for that union.
		if action.has("snapshot_key"):
			source["enemy_source_snapshot"] = enemy.get(str(action["snapshot_key"]), null)
		if str(action.get("field_anchor", "")) == "player":
			source["semantics"] = "Fixed area held around field_center at declaration; radius and declared_tiles are authoritative."
		elif Held.shape(action) == "surface_snapshot":
			source["semantics"] = "Declared surface centers filtered by the living surface, expanded by snapshot_radius."
		elif Held.shape(action) == "trail_snapshot":
			source["semantics"] = "Fixed declared trail area retained from the resolver-created source."
		else:
			source["semantics"] = "Raw authored/committed action retained; complete sequential threat is expected_warning."
		result.append(source)
	return result

func _step_summary(steps: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for step: Dictionary in steps:
		if str(step.get("kind", "")) == "commit": continue
		var summary: Dictionary = {}
		for key: String in ["kind", "action_type", "intent_id", "committed_shape", "label", "from", "to", "tiles", "declared_tiles", "element", "amount", "interrupted", "spawned_enemies"]:
			if step.has(key): summary[key] = step[key]
		if not summary.is_empty(): result.append(summary)
	return result

func _boss_index(state: Dictionary, boss_id: String) -> int:
	for index: int in range(state["enemies"].size()):
		var enemy: Dictionary = state["enemies"][index]
		if str(enemy["type"]) == boss_id and int(enemy["hp"]) > 0: return index
	return -1

func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCES:
		var digest: String = FileAccess.get_sha256("res://"+path)
		_expect(not digest.is_empty(), "Fingerprint input exists: "+path)
		result[path] = digest
	result[str(get_script().resource_path)] = FileAccess.get_sha256(get_script().resource_path)
	return result

func _json_value(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I, TYPE_VECTOR2: return [value.x, value.y]
		TYPE_DICTIONARY:
			var result: Dictionary = {}
			for key: Variant in value: result[str(key)] = _json_value(value[key])
			return result
		TYPE_ARRAY:
			var result: Array = []
			for item: Variant in value: result.append(_json_value(item))
			return result
	return value

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
