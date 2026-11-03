extends SceneTree

const Data = preload("res://scripts/game_data.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const Fx = preload("res://scripts/enemy_mechanics/burst_fx.gd")
const Kindle = preload("res://scripts/enemy_mechanics/kindle_view.gd")
const En01 = preload("res://tests/suites/en01_enemies_suite.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Hud = preload("res://scripts/combat_objective_hud.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const HEADLESS_SETTLE_FRAMES: int = 3
const HUD_PROOF_HEIGHT: float = 88.0
const FIXTURE_BURST_TILE := Vector2i(3, 3)
const FIXTURE_EAST_TILE := Vector2i(4, 3)
const FIXTURE_WEST_TILE := Vector2i(2, 3)
const PREVIEW_CARD_DAMAGE: int = 6
const POP_PEAK_SAMPLE_SECONDS: float = 0.125
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	_run.call_deferred()

func _run() -> void:
	_glow_geometry()
	_preview_and_copy()
	await preload("res://tests/helpers/brs01_feedback_cases.gd").run(_expect)
	_expect(await preload("res://tests/helpers/brs01_playback_cases.gd").run(_expect), "Actual Burst playback cases complete")
	_burst_and_kindle_clocks()
	_no_mechanic_outlines()
	await _feedback_redraws()
	await _objective_titles()
	preload("res://tests/suites/combat_objective_suite.gd").run(_expect)
	for failure: String in failures: push_error(failure)
	print("BRS01 FOCUSED RESULT: %s (%d checks; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _glow_geometry() -> void:
	var state: Dictionary = preload("res://tests/suites/warband_orders_suite.gd").battle("air")
	var board := Board.new()
	board.combat_state = state
	var leader: Dictionary = board.WarbandRules.captain(state)
	var oracle = preload("res://tests/fixtures/brs01_warband_glow.gd")
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			var tile := Vector2i(x, y)
			var polygon: PackedVector2Array = board._tile_polygon(tile)
			var actual: Array = board.WarbandView.glow_fan(state, leader, tile, polygon, Color.WHITE)
			_expect(actual == oracle.glow_fan(state, leader, tile, polygon, Color.WHITE), "Warband geometry/vertex colours unchanged at %s" % tile)
	var capture := board.WarbandView.CommandCapture.new()
	preload("res://scripts/tile_glow.gd").draw(capture, board._tile_polygon(FIXTURE_BURST_TILE), Burst.FIRE, 0.34, 0.08)
	_expect(capture.triangles.size() == 4, "Tile glow draws exactly four triangles")
	for triangle: Array in capture.triangles:
		_expect(is_equal_approx(triangle[1][0].a, 0.34) and is_equal_approx(triangle[1][1].a, 0.08) and is_equal_approx(triangle[1][2].a, 0.08), "Preview centre/corner alphas are exact")
	board.free()

func _preview_and_copy() -> void:
	var state: Dictionary = En01.fixture(["ember_tick", "crawler", "crawler"])
	state["enemies"][0]["pos"] = FIXTURE_BURST_TILE
	state["enemies"][1]["pos"] = FIXTURE_EAST_TILE
	state["enemies"][2]["pos"] = FIXTURE_WEST_TILE
	var scene := preload("res://scripts/run_scene.gd").new()
	var preview: Dictionary = scene._preview_damage_for_action(state, {"type": "ranged", "range": 5, "damage": PREVIEW_CARD_DAMAGE}, FIXTURE_BURST_TILE)
	var board := Board.new()
	board.combat_state = state
	board.presentation = {"damage_preview": preview}
	for actor: Dictionary in [state["player"], state["enemies"][1], state["enemies"][2]]:
		var unit: Dictionary = actor.duplicate(true)
		unit["key"] = "enemy_%d" % int(unit["id"]) if unit.has("id") else "player"
		var shown: Dictionary = board._unit_damage_preview(unit)
		_expect(int(shown.get("hp_loss", 0)) == 4, "Burst preview reaches ordinary HP preview for " + str(unit["key"]))
		_expect(board._health_bar_fill_hp(unit, shown) == int(unit["hp"]) - 4 and board._damage_preview_shows_lost_hp(shown), "Ordinary HP number and ghost include Burst for " + str(unit["key"]))
	for type: String in ["ember_tick", "ember_hoarder"]:
		for bonus: int in [0, 2, 4]:
			var unit: Dictionary = {"type": type, "kindled_bonus": bonus}
			var token: Dictionary = Burst.trait_token(unit)
			_expect(token["value"] == "Bursts %d" % (4 + bonus) and token["tooltip"] == "When it dies, it hits every unit next to it for %d and leaves Fire." % (4 + bonus), "Live Burst trait copy " + type)
			var tags: Array = preload("res://scripts/pre_battle_threat_tags.gd").build(type, unit)
			_expect(tags.size() == 1 and tags[0]["icon_key"] == "burst" and tags[0]["text"] == token["value"], "Pre-battle Burst caption " + type)
			var rows: Array = board._intent_rows_for_unit(unit, Data.enemy_def(type)["intents"][0])
			var rules := PackedStringArray()
			for index: int in range(1, preload("res://scripts/enemy_mechanics/burst_trait_text.gd").title_index(rows)): rules.append(str(rows[index][0]["value"]))
			_expect(rows[0][0] == token and " ".join(rules) == token["tooltip"], "Combat trait above moves " + type)
	var kindle_action: Dictionary = {"type": "kindle", "amount": 2}
	var token: Dictionary = Icons.tokens_for_action(kindle_action)[0]
	_expect(token["icon"] == "burst" and token["value"] == "Burst +2" and token["tooltip"] == "Its Burst hits 2 harder, up to +4.", "Exact Kindle row and tooltip")
	_expect(Kindle.rows({"actions": [kindle_action]})[0][0] == token, "Board/pre-battle Kindle tokens agree")
	var inspection = preload("res://scripts/pre_battle_inspection_view.gd")
	var move: Control = inspection.build_move(scene, Data.enemy_def("ember_tick")["intents"][1])
	_expect(move.tooltip_text == "Its Burst hits 2 harder, up to +4.", "Actual Kindle move plate exposes the exact tooltip")
	move.free()
	var existing: Control = inspection.build_move(scene, Data.enemy_def("crawler")["intents"][0])
	_expect(existing.tooltip_text.is_empty(), "Other known-move tooltip behavior stays unchanged")
	existing.free()
	var trait_row: Control = inspection.build_trait(Burst.trait_token({"type": "ember_tick", "kindled_bonus": 2}))
	_expect(trait_row.find_child("EnemyBurstTraitTitle", true, false).text == "Bursts 6", "Actual pre-battle trait shows live number")
	trait_row.free()
	board.free()
	scene.free()

func _burst_and_kindle_clocks() -> void:
	_expect(is_equal_approx(Fx.feedback_duration({"en01_burst": {}}, 0.18), 0.30) and is_equal_approx(Fx.feedback_duration({"en01_burst": {}}, 0.48), 0.48) and is_equal_approx(Fx.feedback_duration({}, 0.18), 0.18), "Empty Burst feedback completes its glow; existing damage and other status durations stay intact")
	_expect(is_zero_approx(Fx.glow_alpha(0.0)) and is_equal_approx(Fx.glow_alpha(0.06), 0.55) and is_zero_approx(Fx.glow_alpha(0.30)), "Burst glow rises by 0.06 and ends at 0.30 seconds")
	_expect(is_equal_approx(Fx.RIBBON_SECONDS, 0.28) and is_equal_approx(Burst.BURST_CHAIN_SECONDS, 0.18), "Ribbon and existing chain durations")
	var before: Dictionary = En01.fixture(["ember_tick", "ember_tick"])
	before["enemies"][0]["pos"] = FIXTURE_BURST_TILE
	before["enemies"][1]["pos"] = FIXTURE_EAST_TILE
	before["enemies"][1]["hp"] = 4
	var after: Dictionary = preload("res://scripts/combat_engine.gd").new()._damage_enemy(before.duplicate(true), 0, 6)
	var frame: Dictionary = Burst.decorate(before, after, {}, 0.25, {"first_start": 0.01, "duration": 1.0})
	_expect(frame.get("burst_effects", []).size() == 2 and is_equal_approx(float(frame["burst_effects"][1]["elapsed"]), 0.06), "Chain effects overlap with independent event clocks")
	for time: float in [0.0, POP_PEAK_SAMPLE_SECONDS, 0.25]:
		var scale: float = Kindle.badge_scale({"kindle_pop": {"actor_key": "enemy_1", "elapsed": time}}, "enemy_1")
		_expect(is_equal_approx(scale, 1.35 if time == POP_PEAK_SAMPLE_SECONDS else 1.0), "Kindle badge pop at %s" % time)
	var state: Dictionary = En01.fixture(["ember_tick"])
	state["enemies"][0]["intent"] = Data.enemy_def("ember_tick")["intents"][1].duplicate(true)
	var steps: Array = preload("res://scripts/combat_engine.gd").new().resolve_enemy_turn_with_steps(state, 0)["steps"]
	var found: bool = false
	for step: Dictionary in steps:
		if str(step.get("action_type", "")) != "kindle": continue
		found = true
		_expect(int(step["enemy_after"]["kindled_bonus"]) == 2 and Kindle.texts(step)[0]["text"] == "Burst +2", "Resolved Kindle updates number and fire status text")
		var shown: Dictionary = {"effect": step}
		Kindle.decorate(shown, POP_PEAK_SAMPLE_SECONDS)
		_expect(is_equal_approx(Kindle.badge_scale(shown, str(step["actor_key"])), 1.35), "Production status feedback drives badge pop")
	_expect(found, "Kindle fixture executes actual status step")

func _feedback_redraws() -> void:
	var state: Dictionary = En01.fixture(["ember_tick"])
	var board := Board.new()
	board.size = Vector2(1920, 1080)
	root.add_child(board)
	board.set_combat_state(state)
	for frame: int in range(HEADLESS_SETTLE_FRAMES): await process_frame
	board.reset_render_instrumentation()
	for elapsed: float in [0.06, POP_PEAK_SAMPLE_SECONDS, 0.30]:
		var effects: Array[Dictionary]
		effects.append({"tile": state["enemies"][0]["pos"], "tiles": preload("res://scripts/enemy_mechanics/death_burst.gd").tiles(state, state["enemies"][0]), "elapsed": elapsed})
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"burst_effects": effects, "kindle_pop": {"actor_key": "enemy_1", "elapsed": elapsed}})
		for frame: int in range(HEADLESS_SETTLE_FRAMES): await process_frame
	var counts: Dictionary = board.render_instrumentation_snapshot()
	_expect(int(counts["full_dynamic_redraw_count"]) == 0 and int(counts["layer_draw_counts"].get("scene_tile", 0)) == 0, "Burst/Kindle clocks redraw only overlay/effect/HUD layers")
	board.queue_free()
	await process_frame

func _no_mechanic_outlines() -> void:
	var forbidden := RegEx.create_from_string("\\b(_draw_tile_ring|draw_dashed_line|draw_ring|_draw_dashed_line)\\s*\\(")
	for path: String in DirAccess.get_files_at("res://scripts/enemy_mechanics"):
		if not path.ends_with(".gd"): continue
		for line: String in FileAccess.get_file_as_string("res://scripts/enemy_mechanics/" + path).split("\n"):
			_expect(forbidden.search(line.get_slice("#", 0)) == null, "Enemy mechanics contain no ring/dash drawing: " + path)

static func objective_cases() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for type: String in [Objectives.KILL_ALL, Objectives.KILL_LEADER, Objectives.SURVIVE, Objectives.REACH_EXIT]: result.append({"type": type})
	for variant: Dictionary in Specials.definition("warband")["variants"].values(): result.append({"type": Objectives.KILL_LEADER, "special_type": "warband", "leader_display_name": variant["title"]})
	result.append({"type": Objectives.KILL_ALL, "special_type": "umbral_snare", "special_variant": "fire"})
	result.append({"type": Objectives.KILL_LEADER, "special_type": "ember_hoarder", "leader_id": 1})
	result.append({"type": Objectives.SURVIVE, "special_type": "last_light"})
	for id: String in Data.enemies():
		if bool(Data.enemies()[id].get("guardian", false)) or preload("res://scripts/dragon_boss_library.gd").is_dragon_boss_id(id): result.append({"type": Objectives.KILL_LEADER, "leader_type": id})
	return result

func _objective_titles() -> void:
	var hud := Hud.new()
	root.add_child(hud)
	for objective: Dictionary in objective_cases():
		var title: String = Objectives.title_for_objective(objective)
		_expect(title.begins_with("Defeat") or title.begins_with("Survive") or title.begins_with("Reach"), "Objective starts with an instruction: " + title)
		var state: Dictionary = {"objective": objective, "enemies": [{"id": 1, "type": "ember_hoarder", "hp": 24, "max_hp": 24}]}
		hud.set_combat_state(state)
		hud._set_intro_font_progress(1.0)
		_expect(hud._intro_title.get_theme_font("font").get_string_size(hud._intro_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, hud._intro_title.get_theme_font_size("font_size")).x <= Hud.INTRO_TEXT_SIZE.x - 32.0, "Objective intro fits: " + title)
		hud.set_hud_rect(Rect2(Vector2.ZERO, Vector2(hud.preferred_width(), HUD_PROOF_HEIGHT)))
		await process_frame
		_expect(hud.preferred_width() < 1920.0, "Objective panel fits 1080p: " + title)
		for label: Label in [hud._title, hud._detail]:
			_expect(label.get_theme_font("font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "Objective label fits: " + label.text)
		if str(objective.get("special_type", "")) == "ember_hoarder":
			_expect(hud._title.text == "DEFEAT THE HOARDER" and hud._intro_title.text == "DEFEAT THE EMBER HOARDER BEFORE IT ESCAPES!" and hud._detail.text == "Before it escapes · 24/24 HP", "Hoarder HUD/intro/live detail use their respective titles")
	_expect(Objectives.hud_title_for_objective({"type": Objectives.KILL_ALL, "special_type": "ember_hoarder"}) == "Defeat All Enemies", "Escaped Hoarder returns to generic HUD objective")
	_expect(Objectives.title_for_objective({"type": Objectives.KILL_LEADER, "special_type": "warband", "leader_display_name": "The Thornmother"}) == "Defeat the Thornmother", "Warband keeps the title's article")
	hud.free()

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
