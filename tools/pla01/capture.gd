extends SceneTree
## pla-01 proof only: real-renderer 1920x1080 captures of the tooltips the
## exception strip rewrites. Production scenes and panel builders; nothing here
## changes rules or copy. Run through tools/visual_probe_runner.py with
## LABYRINTH_CEL_LOOK=all and PLA01_OUT=<dir>.

const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Panels = preload("res://scripts/ui_tooltip_panel.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Data = preload("res://scripts/game_data.gd")
const Context = preload("res://scripts/tooltip_loop_context.gd")
const Runs = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const HeroCombat = preload("res://scripts/hero_facing_combat.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const Dragons = preload("res://tools/dragon_boss_inspection.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const DEFAULT_OUT: String = "/private/tmp/labyrinth_codex/pla-01/capture"
const SETTLE_FRAMES: int = 10
const SCAN_STEP: int = 6
const PANEL_GAP := Vector2(24, -12)
const CHIP_GAP := Vector2(90, 34) # After-only chip hovers: keep the chip itself in view.
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
	if not OS.get_environment("PLA01_OUT").is_empty(): _out = OS.get_environment("PLA01_OUT")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Playback.SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	await _trap_tile()
	await _guardian_room()
	await _burrow()
	await _warband()
	await _dragon()
	await _extras()
	var report := FileAccess.open(_out.path_join("texts.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(_texts, "\t", true) + "\n")
	report.close()
	for failure: String in _errors: push_error(failure)
	print("PLA-01 CAPTURE RESULT: %s (%d images, %d failures)" % ["PASS" if _errors.is_empty() else "FAIL", _texts.size(), _errors.size()])
	quit(0 if _errors.is_empty() else 1)

# ---------------------------------------------------------------- fixtures

static func _battle(id: String, units: Array, element: String, size: Vector2i, hero: Vector2i) -> Dictionary:
	var runs := Runs.new()
	var run: Dictionary = runs.create_new_run(Fixture.SEED, Progression.default_data())
	var layout: Dictionary = run["current_room_layout"].duplicate(true)
	var grid: Array = []
	for y: int in range(size.y):
		var row: Array = []
		for x: int in range(size.x): row.append("stone")
		grid.append(row)
	layout["grid"] = grid
	layout["player_start"] = hero
	layout["type"] = "combat"
	layout["depth"] = 2
	layout["objective"] = {}
	layout["element"] = element
	for key: String in ["terrain", "traps", "loot", "npcs", "enemies"]: layout[key] = []
	layout["surfaces"] = {}
	layout["moss"] = {}
	for entry: Array in units:
		var definition: Dictionary = Data.enemy_def(entry[0])
		layout["enemies"].append({"id": layout["enemies"].size() + 1, "type": entry[0], "pos": entry[1], "hp": definition["max_hp"], "max_hp": definition["max_hp"]})
	var state: Dictionary = HeroCombat.new().create_combat(Fixture.SEED, layout, runs._player_snapshot(run))
	run["mode"] = "combat"
	run["current_room_layout"] = layout
	run["combat_state"] = state
	return {"run": run, "state": state, "card": "", "id": id, "layout": layout}

# ---------------------------------------------------------------- captures

func _trap_tile() -> void:
	var fixture: Dictionary = Fixture.build("trap_fire")
	var scene: Node = await Playback.instance(self, _viewport, fixture, false)
	if scene == null: _fail("trap scene"); return
	var board: Control = scene.get("board_view")
	var center: Vector2 = board._tile_center(Fixture.Traps.CENTER)
	var text: String = board._get_tooltip(center)
	if text.is_empty(): _fail("trap tile has no tooltip")
	var tile_panel: Control = board._make_custom_tooltip(text)
	var keyword: Control = Panels.make_text(Icons.tooltip("traps"))
	var at: Vector2 = board.get_global_transform() * center
	await _shot(scene, "trap_tile", [tile_panel, keyword], [at + PANEL_GAP, at + PANEL_GAP + Vector2(0, 300)], false)
	await _free(scene)

func _guardian_room() -> void:
	# Storm Cantor (summon + Lightning Storm) and Glacial Mirror (Reflect).
	var fixture: Dictionary = _battle("pla01_guardians", [["storm_cantor", Vector2i(3, 1)], ["glacial_mirror", Vector2i(4, 3)]], "lightning", Vector2i(6, 5), Vector2i(1, 3))
	var state: Dictionary = fixture["state"]
	var cantor: Dictionary = state["enemies"][0]
	cantor["intent"] = Combat.new()._intent_by_id(Data.enemy_def("storm_cantor")["intents"], "call_the_spark").duplicate(true)
	var scene: Node = await Playback.instance(self, _viewport, {"run": fixture["run"], "id": fixture["id"], "biome": "zekarion"}, false)
	if scene == null: _fail("guardian scene"); return
	scene.call("_set_show_all_enemy_intents", true)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var shown: Dictionary = scene.get("_combat_state")
	# The summon token's hover text is exactly what the board registers.
	var summon: Dictionary = await _hover(board, "Calls Lightning Wisp")
	print("PLA-01 NOTE: summon hover %s" % ("found" if not summon.is_empty() else "not found; using the intent row token"))
	if summon.is_empty():
		var rows: Array = board._intent_rows_for_unit(shown["enemies"][0], shown["enemies"][0]["intent"])
		for row: Array in rows:
			for token: Dictionary in row:
				if str(token.get("icon", "")) == "summon_minions": summon = {"text": str(token.get("display_tooltip", Icons.token_tooltip(token))), "at": board.get_global_rect().get_center()}
	if summon.is_empty(): _fail("no summon token")
	else: await _shot(scene, "summon_intent", [board._make_custom_tooltip(summon["text"])], [summon["at"] + PANEL_GAP], false)
	var reflect: Dictionary = await _hover(board, "Reflect")
	if reflect.is_empty(): _fail("no Reflect chip hover")
	else: await _shot(scene, "reflect", [board._make_custom_tooltip(reflect["text"])], [reflect["at"] + PANEL_GAP], false)
	# Lightning Storm battlefield rule, installed from the Cantor's own catalog row.
	var engine: RefCounted = scene.get("_combat_engine")
	var live: Dictionary = shown.duplicate(true)
	Rules.install(engine, live, Rules.instance_for("storm_cantor", int(live["enemies"][0]["id"])))
	var hud: Control = scene.get("_battlefield_rule_hud")
	hud.set_combat_state(live, engine)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	await _shot(scene, "lightning_storm_rule", [hud._make_custom_tooltip(hud.tooltip_text)], [hud.get_global_rect().position + Vector2(0, hud.size.y + 8)], false)
	var keyword: Control = Panels.make_text(Icons.tooltip("lightning_storm"))
	await _shot(scene, "lightning_storm_keyword", [keyword], [hud.get_global_rect().position + Vector2(0, hud.size.y + 8)], false)
	# Umbra HUD subtitle at a limited-vision stage.
	shown["umbra"]["stage"] = "deep"
	scene.call("_refresh_umbra_subtitle")
	var subtitle: Label = scene.get("umbra_subtitle")
	if subtitle.tooltip_text.is_empty():
		shown["umbra"]["stage"] = "eclipse"
		scene.call("_refresh_umbra_subtitle")
	await _shot(scene, "umbra_hud", [subtitle._make_custom_tooltip(subtitle.tooltip_text)], [subtitle.get_global_rect().position + Vector2(0, subtitle.size.y + 8)], false)
	await _free(scene)

func _burrow() -> void:
	var fixture: Dictionary = Fixture.build("marked_burrow_grub")
	var scene: Node = await Playback.instance(self, _viewport, fixture, false)
	if scene == null: _fail("burrow scene"); return
	scene.call("_set_show_all_enemy_intents", true)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var unit: Dictionary = fixture["state"]["enemies"][0]
	var source: Dictionary = Context.enemy_unit(unit)
	var text: String = str(unit["intent"]["name"]) + "\n" + board.enemy_intent_tooltip("enemy_%d" % int(unit["id"]))
	var popup: Control = Context.panel_for_text(text, source, Context.term_in(text, source))
	if popup == null: popup = Panels.make_text(text)
	var at: Vector2 = board.get_global_transform() * board._tile_center(unit["pos"])
	await _shot(scene, "burrow", [popup], [at + PANEL_GAP], false)
	await _free(scene)

func _warband() -> void:
	var runs := Runs.new()
	var combat := Combat.new()
	var state: Dictionary = Warband.build(runs, combat, runs.create_new_run(Warband.FIXTURE_SEED, Progression.default_data()), {"warband_case": "encounter", "warband_biome": "air"})
	var scene: Node = await Playback.instance(self, _viewport, {"run": state, "id": "pla01_warband", "biome": "vaeloryx"}, false)
	if scene == null: _fail("warband scene"); return
	var board: Control = scene.get("board_view")
	var live: Dictionary = scene.get("_run_state")
	var captain: Dictionary = {}
	for enemy: Dictionary in live["combat_state"]["enemies"]:
		if bool(enemy.get("is_leader", false)): captain = enemy
	if captain.is_empty(): _fail("no Warband captain"); return
	scene.set("_pre_battle_preview_run_state", live)
	var panel: Control = scene.call("_build_pre_battle_enemy_inspection_panel", captain, true)
	await _shot(scene, "warband_captain", [panel], [Vector2(620, 150)], true)
	var hud: Control = scene.get("_combat_objective_hud")
	if not hud.tooltip_text.is_empty() or hud.focus_mode != Control.FOCUS_NONE:
		_fail("Warband Objective must skip hover and focus tooltips")
	await _shot(scene, "warband_objective", [], [], false)
	var command: Dictionary = await _hover(board, "Command")
	if command.is_empty(): print("PLA-01 NOTE: no Command chip on the board (expected before pla-01)")
	else: await _shot(scene, "warband_command_chip", [board._make_custom_tooltip(command["text"])], [command["at"] + CHIP_GAP], false)
	await _free(scene)

func _dragon() -> void:
	var runs := Runs.new()
	var combat := Combat.new()
	var options: Dictionary = {"dragon_id": "vyraketh", "dragon_depth": 4, "dragon_case": "encounter"}
	var state: Dictionary = Dragons.build(runs, combat, runs.create_new_run(Dragons.seed_for_options(options), Progression.default_data()), options)
	var scene: Node = await Playback.instance(self, _viewport, {"run": state, "id": "pla01_dragon", "biome": "vyraketh"}, false)
	if scene == null: _fail("dragon scene"); return
	var board: Control = scene.get("board_view")
	var live: Dictionary = scene.get("_run_state")
	var dragon: Dictionary = {}
	for enemy: Dictionary in live["combat_state"]["enemies"]:
		if str(enemy.get("type", "")) == "vyraketh": dragon = enemy
	if dragon.is_empty(): _fail("no dragon"); return
	scene.set("_pre_battle_preview_run_state", live)
	var panel: Control = scene.call("_build_pre_battle_enemy_inspection_panel", dragon, true)
	await _shot(scene, "dragon_steadfast", [panel], [Vector2(620, 110)], true)
	var chip: Dictionary = await _hover(board, "Steadfast")
	if chip.is_empty(): print("PLA-01 NOTE: no Steadfast chip on the board (expected before pla-01)")
	else: await _shot(scene, "dragon_steadfast_chip", [board._make_custom_tooltip(chip["text"])], [chip["at"] + CHIP_GAP], false)
	await _free(scene)

func _extras() -> void:
	# After-only witnesses: Zekarion's Steadfast + Immune rows, and the Gallows
	# Roc's Anchored chip (Push, Pull and Wind truly can't move it).
	var runs := Runs.new()
	var combat := Combat.new()
	var options: Dictionary = {"dragon_id": "zekarion", "dragon_depth": 8, "dragon_case": "encounter"}
	var state: Dictionary = Dragons.build(runs, combat, runs.create_new_run(Dragons.seed_for_options(options), Progression.default_data()), options)
	var scene: Node = await Playback.instance(self, _viewport, {"run": state, "id": "pla01_zekarion", "biome": "zekarion"}, false)
	if scene == null: _fail("zekarion scene"); return
	var live: Dictionary = scene.get("_run_state")
	for enemy: Dictionary in live["combat_state"]["enemies"]:
		if str(enemy.get("type", "")) == "zekarion":
			scene.set("_pre_battle_preview_run_state", live)
			await _shot(scene, "zekarion_traits", [scene.call("_build_pre_battle_enemy_inspection_panel", enemy, true)], [Vector2(620, 110)], true)
	await _free(scene)
	var fixture: Dictionary = _battle("pla01_roc", [["gallows_roc", Vector2i(3, 1)]], "air", Vector2i(6, 5), Vector2i(1, 3))
	scene = await Playback.instance(self, _viewport, {"run": fixture["run"], "id": fixture["id"], "biome": "vaeloryx"}, false)
	if scene == null: _fail("roc scene"); return
	var chip: Dictionary = await _hover(scene.get("board_view"), "Anchored")
	if chip.is_empty(): print("PLA-01 NOTE: no Anchored chip on the Gallows Roc (expected before pla-01)")
	else: await _shot(scene, "gallows_roc_anchored_chip", [scene.get("board_view")._make_custom_tooltip(chip["text"])], [chip["at"] + CHIP_GAP], false)
	await _free(scene)

# ---------------------------------------------------------------- helpers

## Scans the board like a pointer would and returns the first hover text that
## contains needle, with its global point. Uses the board's own _get_tooltip.
func _hover(board: Control, needle: String) -> Dictionary:
	for frame: int in range(2): await process_frame
	var size: Vector2 = board.size
	for y: int in range(0, int(size.y), SCAN_STEP):
		for x: int in range(0, int(size.x), SCAN_STEP):
			var local := Vector2(x, y)
			var text: String = board._get_tooltip(local)
			if text.contains(needle) and not text.begins_with("tile-effects:"):
				return {"text": text, "at": board.get_global_transform() * local}
	return {}

func _shot(scene: Node, id: String, panels: Array, anchors: Array, scrim: bool) -> void:
	var host: Control = scene.get("_pinned_tooltip_host")
	var veil: Control = scene.get("_pinned_tooltip_scrim")
	var limit := Rect2(Vector2(16, 16), Vector2(Playback.SIZE) - Vector2(32, 32))
	var texts := PackedStringArray()
	for index: int in range(panels.size()):
		var panel: Control = panels[index]
		if panel == null:
			_fail(id + " panel is missing")
			continue
		host.add_child(panel)
		panel.size = panel.get_combined_minimum_size()
		var at: Vector2 = anchors[mini(index, anchors.size() - 1)]
		at.x = clampf(at.x, limit.position.x, limit.end.x - panel.size.x)
		at.y = clampf(at.y, limit.position.y, limit.end.y - panel.size.y)
		panel.global_position = at
	# The pinned host only draws while its scrim is up (production pinning).
	if not panels.is_empty(): veil.show()
	for frame: int in range(SETTLE_FRAMES): await process_frame
	for panel: Variant in panels:
		if panel is Control: texts.append(_panel_text(panel))
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != Playback.SIZE:
		_fail("Could not read 1920x1080 proof for " + id)
	else:
		var file: String = _out.path_join(id + "_1920x1080.png")
		if image.save_png(file) != OK: _fail("Could not save " + file)
		else: print(file)
	_texts[id] = "\n---\n".join(texts)
	print("PLA-01 TEXT %s: %s" % [id, _texts[id].replace("\n", " | ")])
	veil.hide()
	for panel: Variant in panels:
		if panel is Control and is_instance_valid(panel): (panel as Control).queue_free()
	await process_frame

static func _panel_text(node: Node) -> String:
	var parts := PackedStringArray()
	for child: Node in node.find_children("*", "", true, false):
		if child is RichTextLabel and child.is_visible_in_tree(): parts.append((child as RichTextLabel).get_parsed_text().strip_edges())
		elif child is Label and child.is_visible_in_tree(): parts.append((child as Label).text.strip_edges())
	return "\n".join(parts)

func _free(scene: Node) -> void:
	scene.queue_free()
	for frame: int in range(3): await process_frame

func _fail(message: String) -> void:
	_errors.append(message)
	push_error(message)
