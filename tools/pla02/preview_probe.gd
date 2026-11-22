extends SceneTree
## pla-02 proof only (not a permanent test): the live preview must equal what
## the engine resolves for 7 preview gaps (playability audit section J).
## Headless: godot --headless --path . -s tools/pla02/preview_probe.gd
## Each case compares the production preview (run scene / board) with the
## production resolver on a private copy. Prints one PASS/FAIL line per case.

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Runs = preload("res://scripts/run_engine.gd")
const HeroCombat = preload("res://scripts/hero_facing_combat.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const SEED: int = 2702
const FILL: Array = ["quick_stab", "brace", "quick_stab", "brace", "quick_stab", "brace", "quick_stab"]

var scene: Node
var canvas: SubViewport
var engine: RefCounted = Combat.new()
var _failures: Array[String]
var _results: Dictionary = {}
var _only: String = ""

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Progression.set_storage_path("user://pla02_profile.json")
	Progression.set_run_storage_path("user://pla02_run.save")
	Settings.set_storage_path("user://pla02_settings.json")
	Progression.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): _only = arg.trim_prefix("--only=")
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	for frame: int in range(4): await process_frame
	engine = scene.get("_combat_engine")
	for case_id: String in ["1_draw_cap", "2_draw_fatigue", "3_summon_cap", "4_erupt_landing", "5_fade_landing", "6_buried_area", "7_meteor_self"]:
		if not _only.is_empty() and not case_id.begins_with(_only): continue
		var before: int = _failures.size()
		await call("_case_" + case_id.substr(2))
		_results[case_id] = "PASS" if _failures.size() == before else "FAIL"
		print("PLA-02 CASE %s: %s" % [case_id, _results[case_id]])
	scene.queue_free()
	canvas.queue_free()
	await process_frame
	for failure: String in _failures: print("PLA-02 FAIL: " + failure)
	print("PLA-02 PREVIEW PROBE: %s (%d cases, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _results.size(), _failures.size()])
	quit(0 if _failures.is_empty() else 1)

# ---------------------------------------------------------------- fixtures

func _install(units: Array, hero: Vector2i, size: Vector2i, hand: Array, draw: Array, discard: Array, element: String = "none") -> Dictionary:
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	return build(engine, units, hero, size, hand, draw, discard, element)

## A hero's-turn combat on an open stone floor (shared with tools/pla02/capture.gd).
static func build(combat: RefCounted, units: Array, hero: Vector2i, size: Vector2i, hand: Array, draw: Array, discard: Array, element: String = "none") -> Dictionary:
	var runs := Runs.new()
	var run: Dictionary = runs.create_new_run(SEED, Progression.default_data())
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
	layout["umbra_stage"] = "clear"
	for key: String in ["terrain", "traps", "loot", "npcs", "enemies"]: layout[key] = []
	layout["surfaces"] = {}
	layout["moss"] = {}
	for entry: Array in units:
		var definition: Dictionary = Data.enemy_def(entry[0])
		layout["enemies"].append({"id": layout["enemies"].size() + 1, "type": entry[0], "pos": entry[1], "hp": definition["max_hp"], "max_hp": definition["max_hp"]})
	var state: Dictionary = HeroCombat.new().create_combat(SEED, layout, runs._player_snapshot(run))
	state["relics"] = []
	state["player"]["hp"] = 20
	state["player"]["max_hp"] = 30
	state["player"]["block"] = 0
	var deck: Dictionary = state["deck"].duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = draw.duplicate()
	deck["discard"] = discard.duplicate()
	deck["burned"] = []
	deck["cycles"] = 0
	state["deck"] = deck
	state["current_actor"] = combat._player_actor_entry(int(state.get("initiative_clock", 0)), int(state.get("activation_seq", 0)))
	state["cards_played_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 3
	state["player_turn_time_spent"] = 0
	run["mode"] = "combat"
	run["current_room_layout"] = layout
	run["combat_state"] = state
	run["relics"] = []
	return {"run": run, "state": state}

func _load(fixture: Dictionary) -> void:
	var run: Dictionary = fixture["run"]
	run["combat_state"] = fixture["state"]
	scene.set("_animation_lock", false)
	scene.set("_run_state", run)
	scene.set("_combat_state", fixture["state"])
	scene.set("_card_play_count_override", -1)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	var progression: Dictionary = (scene.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in Tutorial.prompt_ids(): progression = Tutorial.resolve_progression(progression, prompt_id)
	scene.set("_progression", progression)
	scene.call("_refresh_contextual_combat_tutorial")
	await _settle()
	_expect(engine.is_player_turn(scene.get("_combat_state")), "fixture starts on the hero's turn")

func _settle() -> void:
	for frame: int in range(3): await process_frame

func _hover(tile: Vector2i) -> void:
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", tile))
	scene.call("_refresh_stage_view")
	await _settle()

func _select(index: int) -> void:
	await scene.call("_on_card_pressed", index)
	await _settle()
	if int(scene.get("_card_action_choice_index")) == index:
		await scene.call("_on_card_action_choice_pressed", "play")
		await _settle()

func _cancel() -> void:
	scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
	await scene.call("_on_cancel_requested")
	await _settle()

func _presentation() -> Dictionary:
	return (scene.get("board_view").get("presentation") as Dictionary)

# Engine truth: play hand card `index` with the given targets on a private copy.
func _resolve_card(state: Dictionary, index: int, targets: Array = []) -> Dictionary:
	var card_id: String = str(state["deck"]["hand"][index])
	var next: Dictionary = engine.prepare_player_card(state, index, "play")
	var cursor: int = 0
	var actions: Array = engine.card_def(card_id, next).get("actions", [])
	for action: Dictionary in actions:
		var target: Vector2i = Vector2i(-1, -1)
		if engine.player_action_needs_target(action):
			target = targets[cursor] if cursor < targets.size() else Vector2i(-1, -1)
			cursor += 1
		if engine.player_action_can_resolve(next, action) or target.x >= 0:
			next = engine.apply_player_action(next, action, target)
	return engine.finish_player_card(next, index, 1, {"play_mode": "play"})

static func _draw_tokens(rows: Array) -> Array:
	var values: Array = []
	for row: Variant in rows:
		if typeof(row) != TYPE_ARRAY: continue
		for token: Variant in row:
			if typeof(token) == TYPE_DICTIONARY and str((token as Dictionary).get("icon", "")) == "draw": values.append((token as Dictionary).get("value"))
	return values

# ---------------------------------------------------------------- 1. Draw near the hand cap

func _case_draw_cap() -> void:
	# Bitter Tonic draws 2. The played card is still in hand while the draw
	# resolves, so the 7-card cap leaves 7 - hand size of room.
	for hand_size: int in [4, 5, 6, 7]:
		var hand: Array = ["bitter_tonic"]
		hand.append_array(FILL.slice(0, hand_size - 1))
		var fixture: Dictionary = _install([["crawler", Vector2i(4, 1)]], Vector2i(1, 2), Vector2i(6, 5), hand, ["quick_stab", "brace", "quick_stab"], [])
		await _load(fixture)
		var live: Dictionary = scene.get("_combat_state")
		var resolved: Dictionary = _resolve_card(live, 0)
		var drawn: int = (resolved["deck"]["hand"] as Array).size() - (hand_size - 1)
		var shown: Array = _draw_tokens((scene.call("_card_widget_display_for_index", 0) as Dictionary).get("summary_rows", []))
		print("PLA-02 DRAW hand=%d resolved_draws=%d face_draw=%s" % [hand_size, drawn, str(shown)])
		_expect(shown.size() == 1 and int(shown[0]) == drawn, "hand %d: the Draw chip shows %d (engine draws %d)" % [hand_size, int(shown[0]) if not shown.is_empty() else -1, drawn])
	# Piles: 1 card left in draw + discard combined also limits the count.
	var short: Dictionary = _install([["crawler", Vector2i(4, 1)]], Vector2i(1, 2), Vector2i(6, 5), ["bitter_tonic", "brace"], [], ["quick_stab"])
	await _load(short)
	var resolved_short: Dictionary = _resolve_card(scene.get("_combat_state"), 0)
	var drawn_short: int = (resolved_short["deck"]["hand"] as Array).size() - 1
	var shown_short: Array = _draw_tokens((scene.call("_card_widget_display_for_index", 0) as Dictionary).get("summary_rows", []))
	print("PLA-02 DRAW piles=1 resolved_draws=%d face_draw=%s" % [drawn_short, str(shown_short)])
	_expect(shown_short.size() == 1 and int(shown_short[0]) == drawn_short, "1 card left in the piles: the Draw chip shows %d (engine draws %d)" % [int(shown_short[0]) if not shown_short.is_empty() else -1, drawn_short])

# ---------------------------------------------------------------- 2. Fatigue on a mid-turn Draw card

func _case_draw_fatigue() -> void:
	# Empty draw pile, cards in the discard: the draw reshuffles and pays Fatigue.
	for spec: Dictionary in [
		{"card": "bitter_tonic", "aim": Vector2i(-1, -1)},
		{"card": "ricochet_knife", "aim": Vector2i(3, 2)},
		{"card": "shadow_step", "aim": Vector2i(1, 4)},
		{"card": "bitter_tonic", "aim": Vector2i(-1, -1), "umbra": "eclipse"},
		{"card": "ricochet_knife", "aim": Vector2i(2, 2), "umbra": "eclipse"},
		{"card": "shadow_step", "aim": Vector2i(1, 3), "umbra": "eclipse"},
	]:
		var fixture: Dictionary = _install([["crawler", Vector2i(3, 2)]], Vector2i(1, 2), Vector2i(6, 5), [spec["card"], "brace"], [], ["quick_stab", "brace", "quick_stab"])
		fixture["state"]["enemies"][0]["hp"] = 40
		fixture["state"]["enemies"][0]["max_hp"] = 40
		if spec.has("umbra"):
			fixture["state"]["enemies"][0]["pos"] = Vector2i(2, 2)
			fixture["state"]["umbra"]["stage"] = spec["umbra"]
			fixture["state"]["umbra"]["stage_reduction"] = 0
		await _load(fixture)
		var live: Dictionary = scene.get("_combat_state")
		var aim: Vector2i = spec["aim"]
		var resolved: Dictionary = _resolve_card(live, 0, [aim] if aim.x >= 0 else [])
		var truth_hp: int = int(resolved["player"]["hp"])
		await _select(0)
		if aim.x >= 0: await _hover(aim)
		else: scene.call("_refresh_stage_view"); await _settle()
		var preview: Dictionary = (_presentation().get("damage_preview", {}) as Dictionary).get("player", {})
		var shown_hp: int = int(preview.get("hp", int(live["player"]["hp"])))
		print("PLA-02 FATIGUE %s umbra=%s limited=%s hp=%d resolved=%d preview=%s" % [spec["card"], str(spec.get("umbra", "clear")), str(scene.call("_preview_umbra_is_limited", live)), int(live["player"]["hp"]), truth_hp, str(preview)])
		_expect(truth_hp < int(live["player"]["hp"]), "%s: the fixture pays Fatigue" % spec["card"])
		_expect(shown_hp == truth_hp, "%s: the hero's Health bar previews %d (engine %d)" % [spec["card"], shown_hp, truth_hp])
		await _cancel()
	# Hovering the card in hand, before selecting it.
	var hovered: Dictionary = _install([["crawler", Vector2i(3, 2)]], Vector2i(1, 2), Vector2i(6, 5), ["bitter_tonic", "brace"], [], ["quick_stab", "brace", "quick_stab"])
	await _load(hovered)
	scene.call("_on_card_hover_started", 0)
	for frame: int in range(8): await process_frame
	scene.call("_refresh_stage_view")
	await _settle()
	var hover_preview: Dictionary = (_presentation().get("damage_preview", {}) as Dictionary).get("player", {})
	print("PLA-02 FATIGUE hand-hover preview=%s" % str(hover_preview))
	scene.call("_on_card_hover_ended", 0)
	await _settle()
	# Comparison: a Health-cost card hovered in hand (no Fatigue).
	var cost: Dictionary = _install([["crawler", Vector2i(3, 2)]], Vector2i(1, 2), Vector2i(6, 5), ["reprise", "brace"], ["quick_stab", "brace", "quick_stab", "brace", "quick_stab"], [])
	await _load(cost)
	scene.call("_on_card_hover_started", 0)
	for frame: int in range(8): await process_frame
	scene.call("_refresh_stage_view")
	await _settle()
	print("PLA-02 FATIGUE reprise hand-hover preview=%s" % str((_presentation().get("damage_preview", {}) as Dictionary).get("player", {})))
	scene.call("_on_card_hover_ended", 0)
	await _settle()

# ---------------------------------------------------------------- 3. Summon at its cap

func _summon_rows(unit: Dictionary) -> Array:
	var board: Control = scene.get("board_view")
	return board.call("_intent_rows_for_unit", unit, unit["intent"])

static func _row_text(rows: Array) -> String:
	var parts: PackedStringArray = []
	for row: Variant in rows:
		for token: Variant in row:
			if typeof(token) != TYPE_DICTIONARY: continue
			var t: Dictionary = token
			parts.append("%s|%s|%s" % [str(t.get("icon", t.get("kind", ""))), str(t.get("text", t.get("value", ""))), str(t.get("tooltip", "")).replace("\n", " / ")])
	return " ;; ".join(parts)

func _case_summon_cap() -> void:
	# Production intent choice and commit (tests/helpers/sum01_proof_fixture.gd),
	# then the live forecast against the resolver: the row names what arrives,
	# reads Summon blocked at the cap, and the green summon tiles match.
	var Fixtures: GDScript = load("res://tests/suites/en03_enemies_suite.gd")
	var Selection: GDScript = load("res://tests/helpers/sum01_proof_fixture.gd")
	var board: Control = scene.get("board_view")
	for summoner: String in ["storm_cantor", "zekarion", "noctyrax"]:
		for living: int in [1, 2]:
			var state: Dictionary = Fixtures.state([Fixtures.enemy(summoner, 1, Vector2i(2, 2))], Vector2i(6, 6))
			Selection.select_summon(engine, state)
			var action: Dictionary = {}
			for value: Dictionary in state["enemies"][0]["intent"]["actions"]:
				if str(value.get("type", "")) == "summon_minions": action = value
			for index: int in range(living):
				var minion: Dictionary = engine._spawned_enemy_entry(state, str(action["minion_type"]), 10 + index, Vector2i(6, 2 + index), true)
				if summoner == "storm_cantor": minion["guardian_helper"] = true
				state["enemies"].append(minion)
			Selection.select_summon(engine, state)
			if not (state["enemies"][0]["intent"]["actions"] as Array).any(func(value: Dictionary) -> bool: return str(value.get("type", "")) == "summon_minions"):
				print("PLA-02 SUMMON %s living=%d: production picks another move at the cap (%s)" % [summoner, living, str(state["enemies"][0]["intent"].get("name", ""))])
				continue
			var before_ids: Array = state["enemies"].map(func(enemy: Dictionary) -> int: return int(enemy["id"]))
			var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0, true, false)
			var arrived: Array = []
			for enemy: Dictionary in resolved["state"]["enemies"]:
				if not before_ids.has(int(enemy["id"])): arrived.append(enemy["pos"])
			board.set("combat_state", state)
			var text: String = _row_text(board.call("_intent_rows_for_unit", state["enemies"][0], state["enemies"][0]["intent"]))
			var tiles: Array = engine.enemy_threat_tiles(state, 0).get("summon", [])
			print("PLA-02 SUMMON %s living=%d arrived=%s tiles=%s rows=%s" % [summoner, living, str(arrived), str(tiles), text])
			var label: String = "%s with %d living" % [summoner, living]
			_expect(text.contains("Card Play") == not arrived.is_empty(), label + ": the +1 Card Play line appears only when something arrives")
			_expect(text.contains("Summon blocked") == arrived.is_empty(), label + ": the row reads Summon blocked exactly when nothing arrives")
			_expect(tiles.size() == arrived.size() and arrived.all(func(tile: Vector2i) -> bool: return tiles.has(tile)), label + ": the summon tiles are where it arrives")
	scene.call("_refresh_ui")

# ---------------------------------------------------------------- 4. Erupt landing tile

func _focus_threat(enemy_index: int) -> Dictionary:
	var live: Dictionary = scene.get("_combat_state")
	var enemy: Dictionary = live["enemies"][enemy_index]
	scene.call("_on_board_tile_hovered", enemy["pos"])
	scene.call("_refresh_stage_view")
	await _settle()
	return _presentation()

func _case_erupt_landing() -> void:
	for blocked: String in ["free", "outcrop", "cornered"]:
		var hero: Vector2i = Vector2i(1, 2) if blocked == "outcrop" else Vector2i(2, 2)
		var fixture: Dictionary = _install([["burrow_grub", Vector2i(4, 1)]], hero, Vector2i(6, 5), ["brace"], ["quick_stab"], [], "earth")
		var state: Dictionary = fixture["state"]
		var grub: Dictionary = state["enemies"][0]
		grub["burrowed"] = true
		grub["erupt_tile"] = Vector2i(2, 2)
		grub["intent"] = engine._intent_by_id(Data.enemy_def("burrow_grub")["intents"], "erupt").duplicate(true)
		if blocked == "outcrop":
			# An Outcrop now stands on the mark (the hero stepped off and raised it).
			state["terrain"] = [{"id": "pla02_outcrop", "kind": "crag_outcrop", "hp": 3, "max_hp": 3, "pos": Vector2i(2, 2), "blocks_sight": true}]
		elif blocked == "cornered":
			# The hero stands on the mark with every way out blocked by walls, so
			# the hero cannot be thrown aside and the Grub surfaces elsewhere.
			for tile: Vector2i in [Vector2i(1, 2), Vector2i(3, 2), Vector2i(2, 1), Vector2i(2, 3)]:
				state["grid"][tile.y][tile.x] = "wall"
		await _load(fixture)
		var live: Dictionary = scene.get("_combat_state")
		var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(live, 0, true, false)
		var landed: Vector2i = resolved["state"]["enemies"][0]["pos"]
		var shown: Dictionary = await _focus_threat(0)
		var ring: Vector2i = shown.get("projected_destination", Vector2i(-999, -999))
		var ghosts: Array = []
		for unit: Dictionary in shown.get("preview_units", []): ghosts.append(unit.get("pos"))
		print("PLA-02 ERUPT mark=%s (%s) landed=%s ring=%s ghosts=%s" % [str(Vector2i(2, 2)), blocked, str(landed), str(ring), str(ghosts)])
		_expect(ring == landed and ghosts.has(landed), "Erupt (%s mark): the preview rings the landing tile %s and shows the Grub there (ring %s)" % [blocked, str(landed), str(ring)])

# ---------------------------------------------------------------- 5. Fade landing tile

func _case_fade_landing() -> void:
	for blocked: bool in [false, true]:
		var fixture: Dictionary = _install([["gloam_stalker", Vector2i(4, 2)]], Vector2i(2, 2), Vector2i(6, 5), ["brace"], ["quick_stab"], [])
		var state: Dictionary = fixture["state"]
		var stalker: Dictionary = state["enemies"][0]
		stalker["intent"] = engine._intent_by_id(Data.enemy_def("gloam_stalker")["intents"], "fade").duplicate(true)
		var behind: Vector2i = Vector2i(2, 2) - engine.hero_facing_direction(state)
		if blocked: state["grid"][behind.y][behind.x] = "wall"
		await _load(fixture)
		var live: Dictionary = scene.get("_combat_state")
		var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(live, 0, true, false)
		var landed: Vector2i = resolved["state"]["enemies"][0]["pos"]
		var shown: Dictionary = await _focus_threat(0)
		var ring: Vector2i = shown.get("projected_destination", Vector2i(-999, -999))
		print("PLA-02 FADE blocked=%s behind=%s landed=%s ring=%s" % [str(blocked), str(behind), str(landed), str(ring)])
		_expect(ring == landed, "Fade (%s): the preview marks the landing tile %s (shows %s)" % ["blocked" if blocked else "open", str(landed), str(ring)])

# ---------------------------------------------------------------- 6. Area hits on a buried Burrow Grub

func _case_buried_area() -> void:
	var fixture: Dictionary = _install([["burrow_grub", Vector2i(4, 2)]], Vector2i(1, 2), Vector2i(6, 5), ["nail_bomb", "brace"], ["quick_stab"], [], "earth")
	var grub: Dictionary = fixture["state"]["enemies"][0]
	grub["burrowed"] = true
	grub["erupt_tile"] = Vector2i(1, 2)
	grub["intent"] = engine._intent_by_id(Data.enemy_def("burrow_grub")["intents"], "erupt").duplicate(true)
	await _load(fixture)
	var live: Dictionary = scene.get("_combat_state")
	var aim: Vector2i = Vector2i(4, 2)
	var resolved: Dictionary = _resolve_card(live, 0, [aim])
	var truth: int = int(live["enemies"][0]["hp"]) - int(resolved["enemies"][0]["hp"])
	await _select(0)
	await _hover(aim)
	var preview: Dictionary = (_presentation().get("damage_preview", {}) as Dictionary).get("enemy_%d" % int(live["enemies"][0]["id"]), {})
	print("PLA-02 BURIED truth_loss=%d preview=%s" % [truth, str(preview)])
	_expect(truth > 0, "the area hit damages the buried Grub in the engine")
	_expect(int(preview.get("hp_loss", 0)) == truth, "the area aim previews %d on the buried Grub (shows %d)" % [truth, int(preview.get("hp_loss", 0))])
	await _cancel()

# ---------------------------------------------------------------- 7. Meteorfall on your own tile

func _case_meteor_self() -> void:
	# Meteorfall marks a line of 3 within range 4; the hero's own tile can be one.
	var hero: Vector2i = Vector2i(2, 2)
	var fixture: Dictionary = _install([["crawler", Vector2i(6, 0)]], hero, Vector2i(7, 5), ["meteorfall", "brace"], ["quick_stab", "brace", "quick_stab", "brace", "quick_stab"], [], "fire")
	fixture["state"]["enemies"][0]["hp"] = 40
	fixture["state"]["enemies"][0]["intent"] = engine._intent_by_id(Data.enemy_def("crawler")["intents"], Data.enemy_def("crawler")["intents"][0]["id"]).duplicate(true)
	await _load(fixture)
	var live: Dictionary = scene.get("_combat_state")
	var rest: Dictionary = scene.call("_pass_preview_summary")
	var rest_loss: int = int(rest.get("hp_loss", 0))
	await _select(0)
	for spec: Array in [[Vector2i(1, 2), true], [Vector2i(4, 2), false]]:
		var aim: Vector2i = spec[0]
		await _hover(aim)
		var shown: Dictionary = _presentation()
		var focus: Array = shown.get("focus_tiles", [])
		var summary: Dictionary = scene.call("_pass_preview_summary")
		# Engine truth: commit the marks on a private copy, then run the hero's
		# next turn start (production preparation) and read the Health it loses.
		var resolved: Dictionary = _resolve_card(live, 0, [aim])
		var marked: bool = false
		for mark: Dictionary in resolved.get("meteor_marks", []):
			if (mark.get("tiles", []) as Array).has(hero): marked = true
		var landed: Dictionary = engine.SurfaceCardRules.resolve_meteor_marks(engine, resolved.duplicate(true))
		var self_hit: int = int(resolved["player"]["hp"]) - int(landed["player"]["hp"])
		var delta: int = int(summary.get("hp_loss", 0)) - rest_loss
		print("PLA-02 METEOR aim=%s on_hero=%s focus=%s marked=%s self_hit=%d pass_hp_loss=%d rest=%d" % [str(aim), str(spec[1]), str(focus), str(marked), self_hit, int(summary.get("hp_loss", 0)), rest_loss])
		_expect(focus.has(hero) == bool(spec[1]), "aim %s: the aimed footprint %s the hero's tile" % [str(aim), "includes" if spec[1] else "leaves out"])
		_expect(bool(shown.get("player_aoe_preview_active", false)), "aim %s: the marks use the area footprint fill and ring, above the target wash" % str(aim))
		_expect(marked == bool(spec[1]), "aim %s: the engine marks the hero's tile only when it is in the footprint" % str(aim))
		_expect(delta == self_hit, "aim %s: the Health forecast adds the self-hit %d (adds %d)" % [str(aim), self_hit, delta])
	# Committed: the mark under the hero is drawn like the others and the Pass
	# forecast at rest includes it.
	await _cancel()
	var committed: Dictionary = _resolve_card(live, 0, [Vector2i(1, 2)])
	committed["card_play_bonus_this_turn"] = 3
	fixture["state"] = committed
	await _load(fixture)
	var marks_drawn: Array = []
	for mark: Dictionary in (scene.get("_combat_state") as Dictionary).get("meteor_marks", []): marks_drawn.append_array(mark.get("tiles", []))
	var after: Dictionary = scene.call("_pass_preview_summary")
	print("PLA-02 METEOR committed marks=%s pass_hp_loss=%d" % [str(marks_drawn), int(after.get("hp_loss", 0))])
	_expect(marks_drawn.has(hero), "the committed marks include the hero's tile")
	_expect(int(after.get("hp_loss", 0)) - rest_loss == 8, "the rest Health forecast includes the 8 under the hero")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)
