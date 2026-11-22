extends SceneTree
## pla-02 proof only: real-renderer 1920x1080 captures of the 7 live previews
## (playability audit J5-J9) and the Stagger Grimoire page. Production run
## scene, fixtures from tools/pla02/preview_probe.gd. Run through
## tools/visual_probe_runner.py with LABYRINTH_CEL_LOOK=all and PLA02_OUT=<dir>.

const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Probe = preload("res://tools/pla02/preview_probe.gd")
const Data = preload("res://scripts/game_data.gd")
const Runs = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const DEFAULT_OUT: String = "/private/tmp/labyrinth_codex/pla-02/capture"
const SETTLE_FRAMES: int = 12
const PANEL_GAP := Vector2(24, -12)
var _viewport: SubViewport
var _errors: Array[String]
var _out: String = DEFAULT_OUT
var _texts: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Use tools/visual_probe_runner.py with a native renderer.")
		quit(1)
		return
	if not OS.get_environment("PLA02_OUT").is_empty(): _out = OS.get_environment("PLA02_OUT")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Playback.SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	var only: String = OS.get_environment("PLA02_ONLY")
	for id: String in ["draw_cap", "draw_fatigue", "summon_cap", "erupt_landing", "fade_landing", "buried_area", "meteor_self", "grimoire_stagger"]:
		if not only.is_empty() and not only.split(",").has(id): continue
		await call("_" + id)
	var report := FileAccess.open(_out.path_join("texts.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(_texts, "\t", true) + "\n")
	report.close()
	for failure: String in _errors: push_error(failure)
	print("PLA-02 CAPTURE RESULT: %s (%d images, %d failures)" % ["PASS" if _errors.is_empty() else "FAIL", _texts.size(), _errors.size()])
	quit(0 if _errors.is_empty() else 1)

# ---------------------------------------------------------------- fixtures

func _scene_for(fixture: Dictionary, id: String, biome: String) -> Node:
	var run: Dictionary = fixture["run"]
	run["combat_state"] = fixture["state"]
	var progression: Dictionary = Progression.default_data()
	for prompt_id: String in Tutorial.prompt_ids(): progression = Tutorial.resolve_progression(progression, prompt_id)
	run["progression"] = progression
	var scene: Node = await Playback.instance(self, _viewport, {"run": run, "id": id, "biome": biome}, false)
	if scene == null:
		_fail(id + " scene")
		return null
	scene.set("_progression", progression)
	scene.call("_refresh_contextual_combat_tutorial")
	for frame: int in range(SETTLE_FRAMES): await process_frame
	return scene

func _install(units: Array, hero: Vector2i, size: Vector2i, hand: Array, draw: Array, discard: Array, element: String = "none") -> Dictionary:
	return Probe.build(preload("res://scripts/hero_facing_combat.gd").new(), units, hero, size, hand, draw, discard, element)

func _intent(enemy: Dictionary, type: String, intent_id: String) -> void:
	for intent: Dictionary in Data.enemy_def(type)["intents"]:
		if str(intent["id"]) == intent_id: enemy["intent"] = intent.duplicate(true)

func _hover_tile(scene: Node, tile: Vector2i) -> void:
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", tile))
	scene.call("_refresh_stage_view")
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _select(scene: Node, index: int) -> void:
	await scene.call("_on_card_pressed", index)
	for frame: int in range(4): await process_frame
	if int(scene.get("_card_action_choice_index")) == index:
		await scene.call("_on_card_action_choice_pressed", "play")
		for frame: int in range(4): await process_frame

# ---------------------------------------------------------------- captures

func _draw_cap() -> void:
	# Bitter Tonic draws 2; with 6 cards in hand (the Tonic counts while it plays) only 1 fits.
	var hand: Array = ["bitter_tonic", "quick_stab", "brace", "quick_stab", "brace", "quick_stab"]
	var fixture: Dictionary = _install([["crawler", Vector2i(4, 1)]], Vector2i(1, 2), Vector2i(6, 5), hand, ["quick_stab", "brace", "quick_stab"], [])
	var scene: Node = await _scene_for(fixture, "pla02_draw_cap", "")
	if scene == null: return
	scene.call("_on_card_hover_started", 0)
	for frame: int in range(30):
		await process_frame
		await RenderingServer.frame_post_draw
	var rows: Array = (scene.call("_card_widget_display_for_index", 0) as Dictionary).get("summary_rows", [])
	_texts["draw_cap_rows"] = Probe._draw_tokens(rows)
	await _shot(scene, "1_draw_cap", [], [])
	await _free(scene)

func _draw_fatigue() -> void:
	# Shadow Step (Blink 3, then draw 1) in Eclipse with an empty draw pile:
	# the draw reshuffles and pays 2 Fatigue, shown on the hero's Health bar.
	var fixture: Dictionary = _install([["crawler", Vector2i(2, 2)]], Vector2i(1, 2), Vector2i(6, 5), ["shadow_step", "brace"], [], ["quick_stab", "brace", "quick_stab"])
	fixture["state"]["enemies"][0]["hp"] = 40
	fixture["state"]["enemies"][0]["max_hp"] = 40
	fixture["state"]["umbra"]["stage"] = "eclipse"
	fixture["state"]["umbra"]["stage_reduction"] = 0
	var scene: Node = await _scene_for(fixture, "pla02_draw_fatigue", "")
	if scene == null: return
	await _select(scene, 0)
	await _hover_tile(scene, Vector2i(1, 3))
	var shown: Dictionary = ((scene.get("board_view").get("presentation") as Dictionary).get("damage_preview", {}) as Dictionary).get("player", {})
	_texts["draw_fatigue_player_preview"] = shown
	if int(shown.get("hp_loss", 0)) != 2: _fail("Shadow Step aim does not preview 2 Fatigue")
	await _shot(scene, "2_draw_fatigue", [], [])
	await _free(scene)

func _summon_cap() -> void:
	# Zekarion's Call Wisps with its 2 Wisps already living: production picks and
	# commits the summon (tests/helpers/sum01_proof_fixture.gd); nothing arrives.
	var Dragons: GDScript = load("res://tools/dragon_boss_inspection.gd")
	var Selection: GDScript = load("res://tests/helpers/sum01_proof_fixture.gd")
	var runs := Runs.new()
	var combat: RefCounted = load("res://scripts/combat_engine.gd").new()
	var options: Dictionary = {"dragon_id": "zekarion", "dragon_depth": 8, "dragon_case": "encounter"}
	var run: Dictionary = Dragons.build(runs, combat, runs.create_new_run(Dragons.seed_for_options(options), Progression.default_data()), options)
	var battle: Dictionary = run["combat_state"]
	var dragon_index: int = -1
	var living: int = 0
	for index: int in range(battle["enemies"].size()):
		var enemy: Dictionary = battle["enemies"][index]
		if str(enemy["type"]) == "zekarion": dragon_index = index
		elif str(enemy["type"]) == "lightning_wisp" and int(enemy.get("hp", 0)) > 0: living += 1
	if dragon_index < 0:
		_fail("no Zekarion")
		return
	var free: Array[Vector2i] = combat._summon_tiles_for_enemy(battle, battle["enemies"][dragon_index], 2 - living)
	for tile: Vector2i in free:
		battle["enemies"].append(combat._spawned_enemy_entry(battle, "lightning_wisp", 90 + battle["enemies"].size(), tile, true))
	Selection.select_summon(combat, battle, dragon_index)
	run = runs.set_combat_state(run, battle)
	var progression: Dictionary = Progression.default_data()
	for prompt_id: String in Tutorial.prompt_ids(): progression = Tutorial.resolve_progression(progression, prompt_id)
	run["progression"] = progression
	var scene: Node = await Playback.instance(self, _viewport, {"run": run, "id": "pla02_summon_cap", "biome": "zekarion"}, false)
	if scene == null:
		_fail("summon scene")
		return
	scene.set("_progression", progression)
	scene.call("_refresh_contextual_combat_tutorial")
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var live: Dictionary = scene.get("_combat_state")
	var dragon: Dictionary = live["enemies"][dragon_index]
	await _hover_tile(scene, dragon["pos"])
	var rows: Array = board.call("_intent_rows_for_unit", dragon, dragon["intent"])
	var summon_text: String = ""
	var row_text := PackedStringArray()
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("icon", "")) == "summon_minions": summon_text = str(token.get("tooltip", ""))
			if str(token.get("kind", "")) == "text": row_text.append(str(token.get("value", "")))
	_texts["summon_cap_row"] = " | ".join(row_text)
	_texts["summon_cap_tiles"] = str(scene.get("_combat_engine").enemy_threat_tiles(live, dragon_index).get("summon", []))
	if not row_text.has("Summon blocked"): _fail("capped summon intent does not read Summon blocked")
	var at: Vector2 = board.get_global_transform() * board.call("_tile_center", dragon["pos"])
	var panel: Control = board.call("_make_custom_tooltip", str(dragon["intent"].get("name", "")) + "\n" + summon_text)
	await _shot(scene, "3_summon_cap", [panel], [at + PANEL_GAP + Vector2(120, 80)])
	await _free(scene)

func _erupt_landing() -> void:
	# An Outcrop stands on the Grub's mark, so the Grub surfaces on the nearest
	# free tile instead; the preview rings that tile and shows the Grub there.
	var fixture: Dictionary = _install([["burrow_grub", Vector2i(4, 1)]], Vector2i(1, 3), Vector2i(6, 5), ["brace"], ["quick_stab"], [], "earth")
	var grub: Dictionary = fixture["state"]["enemies"][0]
	grub["burrowed"] = true
	grub["erupt_tile"] = Vector2i(2, 2)
	_intent(grub, "burrow_grub", "erupt")
	fixture["state"]["terrain"] = [{"id": "pla02_outcrop", "kind": "crag_outcrop", "hp": 3, "max_hp": 3, "pos": Vector2i(2, 2), "blocks_sight": true}]
	var scene: Node = await _scene_for(fixture, "pla02_erupt_landing", "tharokh")
	if scene == null: return
	await _hover_tile(scene, Vector2i(4, 1))
	var ring: Vector2i = (scene.get("board_view").get("presentation") as Dictionary).get("projected_destination", Vector2i(-999, -999))
	var landed: Vector2i = scene.get("_combat_engine").resolve_enemy_turn_with_steps(scene.get("_combat_state"), 0, true, false)["state"]["enemies"][0]["pos"]
	_texts["erupt_landing"] = {"mark": "(2, 2)", "ring": str(ring), "landed": str(landed)}
	if ring != landed or landed == Vector2i(2, 2): _fail("Erupt fallback landing is not ringed")
	await _shot(scene, "4_erupt_landing", [], [])
	await _free(scene)

func _fade_landing() -> void:
	# The tile behind the hero is a wall, so the Gloam Stalker's Fade lands beside it.
	var fixture: Dictionary = _install([["gloam_stalker", Vector2i(4, 2)]], Vector2i(2, 2), Vector2i(6, 5), ["brace"], ["quick_stab"], [])
	_intent(fixture["state"]["enemies"][0], "gloam_stalker", "fade")
	var scene: Node = await _scene_for(fixture, "pla02_fade_landing", "")
	if scene == null: return
	var engine: RefCounted = scene.get("_combat_engine")
	var live: Dictionary = scene.get("_combat_state")
	var behind: Vector2i = Vector2i(2, 2) - engine.hero_facing_direction(live)
	live["grid"][behind.y][behind.x] = "wall"
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	for frame: int in range(SETTLE_FRAMES): await process_frame
	await _hover_tile(scene, Vector2i(4, 2))
	var ring: Vector2i = (scene.get("board_view").get("presentation") as Dictionary).get("projected_destination", Vector2i(-999, -999))
	var landed: Vector2i = engine.resolve_enemy_turn_with_steps(scene.get("_combat_state"), 0, true, false)["state"]["enemies"][0]["pos"]
	_texts["fade_landing"] = {"behind": str(behind), "ring": str(ring), "landed": str(landed)}
	if ring != landed: _fail("Fade ring %s differs from the landing %s" % [str(ring), str(landed)])
	await _shot(scene, "5_fade_landing", [], [])
	await _free(scene)

func _buried_area() -> void:
	var fixture: Dictionary = _install([["burrow_grub", Vector2i(4, 2)]], Vector2i(1, 2), Vector2i(6, 5), ["nail_bomb", "brace"], ["quick_stab"], [], "earth")
	var grub: Dictionary = fixture["state"]["enemies"][0]
	grub["burrowed"] = true
	grub["erupt_tile"] = Vector2i(1, 2)
	_intent(grub, "burrow_grub", "erupt")
	var scene: Node = await _scene_for(fixture, "pla02_buried_area", "tharokh")
	if scene == null: return
	await _select(scene, 0)
	await _hover_tile(scene, Vector2i(4, 2))
	var shown: Dictionary = ((scene.get("board_view").get("presentation") as Dictionary).get("damage_preview", {}) as Dictionary).get("enemy_%d" % int(grub["id"]), {})
	_texts["buried_area_preview"] = shown
	if int(shown.get("hp_loss", 0)) <= 0: _fail("the area aim previews no damage on the buried Grub")
	await _shot(scene, "6_buried_area", [], [])
	await _free(scene)

func _meteor_self() -> void:
	var fixture: Dictionary = _install([["crawler", Vector2i(6, 0)]], Vector2i(2, 2), Vector2i(7, 5), ["meteorfall", "brace"], ["quick_stab", "brace", "quick_stab", "brace", "quick_stab"], [], "fire")
	fixture["state"]["enemies"][0]["hp"] = 40
	var scene: Node = await _scene_for(fixture, "pla02_meteor_self", "vyraketh")
	if scene == null: return
	await _select(scene, 0)
	await _hover_tile(scene, Vector2i(1, 2))
	var shown: Dictionary = scene.get("board_view").get("presentation")
	var summary: Dictionary = scene.call("_pass_preview_summary")
	_texts["meteor_self"] = {"focus": str(shown.get("focus_tiles", [])), "pass_hp_loss": int(summary.get("hp_loss", 0))}
	if not (shown.get("focus_tiles", []) as Array).has(Vector2i(2, 2)): _fail("Meteorfall footprint leaves out the hero's tile")
	await _shot(scene, "7_meteor_self_aim", [], [])
	# Committed: the marks at rest, one under the hero, and the Pass forecast.
	scene.call("_on_board_tile_clicked", Vector2i(1, 2))
	for frame: int in range(4): await process_frame
	if bool(scene.call("_pending_card_requires_confirmation")): await scene.call("_on_confirm_card_play_pressed")
	for frame: int in range(240):
		await process_frame
		if not bool(scene.get("_animation_lock")): break
	await _hover_tile(scene, Vector2i(5, 4))
	var marks: Array = []
	for mark: Dictionary in (scene.get("_combat_state") as Dictionary).get("meteor_marks", []): marks.append_array(mark.get("tiles", []))
	_texts["meteor_self_committed"] = {"marks": str(marks), "pass_hp_loss": int((scene.call("_pass_preview_summary") as Dictionary).get("hp_loss", 0))}
	if not marks.has(Vector2i(2, 2)): _fail("committed Meteorfall has no mark under the hero")
	await _shot(scene, "7_meteor_self_marked", [], [])
	await _free(scene)

func _grimoire_stagger() -> void:
	var runs := Runs.new()
	var run: Dictionary = runs.create_new_run(Probe.SEED, Progression.default_data())
	var ids: Array[String]
	for entry: Dictionary in Grimoire.entries(): ids.append(entry["id"])
	run[Grimoire.UNLOCKED_KEY] = ids
	run[Grimoire.UNREAD_KEY] = []
	run["progression"][Grimoire.UNLOCKED_KEY] = ids.duplicate()
	run["progression"][Grimoire.UNREAD_KEY] = []
	var scene: Node = await Playback.instance(self, _viewport, {"run": run, "id": "pla02_grimoire", "biome": ""}, false)
	if scene == null:
		_fail("grimoire scene")
		return
	scene.call("_open_grimoire_overlay")
	for frame: int in range(SETTLE_FRAMES): await process_frame
	# PLA02_GRIMOIRE lists extra pages (r1: Petrify and Push beside Stagger).
	var pages: PackedStringArray = ["keyword:stagger"]
	if not OS.get_environment("PLA02_GRIMOIRE").is_empty(): pages = OS.get_environment("PLA02_GRIMOIRE").split(",")
	for page: String in pages:
		scene.call("_on_grimoire_entry_pressed", page)
		for frame: int in range(SETTLE_FRAMES): await process_frame
		var body: RichTextLabel = scene.get("_grimoire_detail_body")
		var name: String = page.split(":")[1]
		_texts["grimoire_" + name] = body.get_parsed_text() if body != null else ""
		await _shot(scene, "8_grimoire_" + name, [], [])
	await _free(scene)

# ---------------------------------------------------------------- helpers

func _shot(scene: Node, id: String, panels: Array, anchors: Array) -> void:
	var host: Control = scene.get("_pinned_tooltip_host")
	var veil: Control = scene.get("_pinned_tooltip_scrim")
	var limit := Rect2(Vector2(16, 16), Vector2(Playback.SIZE) - Vector2(32, 32))
	for index: int in range(panels.size()):
		var panel: Control = panels[index]
		host.add_child(panel)
		panel.size = panel.get_combined_minimum_size()
		var at: Vector2 = anchors[mini(index, anchors.size() - 1)]
		at.x = clampf(at.x, limit.position.x, limit.end.x - panel.size.x)
		at.y = clampf(at.y, limit.position.y, limit.end.y - panel.size.y)
		panel.global_position = at
	# The pinned host only draws while its scrim is up (production pinning).
	if not panels.is_empty(): veil.show()
	for frame: int in range(SETTLE_FRAMES): await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != Playback.SIZE:
		_fail("Could not read 1920x1080 proof for " + id)
	else:
		var file: String = _out.path_join(id + "_1920x1080.png")
		if image.save_png(file) != OK: _fail("Could not save " + file)
		else: print(file)
	_texts[id] = "captured"
	if not panels.is_empty(): veil.hide()
	for panel: Variant in panels:
		if panel is Control and is_instance_valid(panel): (panel as Control).queue_free()
	await process_frame

func _free(scene: Node) -> void:
	scene.queue_free()
	for frame: int in range(3): await process_frame

func _fail(message: String) -> void:
	_errors.append(message)
	push_error(message)
