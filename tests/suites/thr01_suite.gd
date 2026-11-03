extends RefCounted
const Fixture = preload("res://tests/helpers/thr01_fixture.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Proof = preload("res://tests/helpers/thr01_proof.gd")
const Store = preload("res://scripts/progression_store.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Sfx = preload("res://scripts/attack_sfx_library.gd")
const LEGACY_DEPTHS: Array = [1, 3, 6]
const SAVE_PATH: String = "user://thr01_legacy.save"
const SOURCE := Vector2i(1, 1)

static func run(expect: Callable) -> void:
	_bolt(expect)
	_legacy_save(expect)
	_rules(expect)

static func _bolt(expect: Callable) -> void:
	var engine := Combat.new()
	var before: Dictionary = Fixture.bolt()
	var plan: Dictionary = engine.enemy_intent_plan(before, 0)
	var phase: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0)
	var after: Dictionary = phase["state"]
	expect.call(before["enemies"][0]["intent"] == Data.enemy_def("arc_thrall")["intents"][0], "Thrall holds the approved Arc Bolt definition")
	expect.call(plan["path"].size() == 3 and after["enemies"][0]["pos"] == plan["destination"], "Arc Bolt moves two tiles to range three")
	expect.call(engine.PathUtils.manhattan(after["enemies"][0]["pos"], Fixture.HERO) == 3, "Arc Bolt fires at its range-three boundary")
	expect.call(before["player"]["hp"] - after["player"]["hp"] == 3 and int(after["player"].get("shock", 0)) == 0, "Arc Bolt deals three lightning damage using ordinary ranged rules")
	expect.call(Surfaces.element_at(after, Fixture.HERO) == "electrified", "Arc Bolt places Electrified on the target tile")
	var attacks: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("kind", "")) == "ranged")
	expect.call(attacks.size() == 1, "Arc Bolt emits one ordinary ranged step")
	if not attacks.is_empty():
		expect.call(Action.clip_for(attacks[0], before["enemies"][0]) == "tether", "Arc Bolt routes to the unchanged approved cast clip")
		expect.call(Action.playback_adapter(attacks[0], before["enemies"][0]) == load("res://scripts/maquette_cutout_runtime/contact_actions.gd"), "Arc Bolt uses ordinary contact playback")
		expect.call(Sfx.entry_for_enemy_step(attacks[0]) == Sfx.entry_for_enemy_step({"kind": "ranged", "element": "lightning", "enemy_type": "zekarion"}), "Arc Bolt shares Storm Lash's existing lightning ranged cue")
	var outside: Dictionary = Fixture.bolt()
	outside["player"]["pos"] = Vector2i(7, 4)
	outside["enemies"][0]["immobilize"] = true
	var missed: Dictionary = engine.resolve_enemy_turn_with_steps(outside, 0)["state"]
	expect.call(missed["player"]["hp"] == outside["player"]["hp"] and Surfaces.element_at(missed, outside["player"]["pos"]) == "", "Arc Bolt cannot hit or place a surface outside range")

static func _legacy_save(expect: Callable) -> void:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path(SAVE_PATH)
	for depth: int in LEGACY_DEPTHS:
		var before: Dictionary = Fixture.bolt()
		before["room_depth"] = depth
		var expected: Dictionary = Combat.new()._scale_enemy_intent(Data.enemy_def("arc_thrall")["intents"][0], depth, before, before["enemies"][0])
		before["enemies"][0]["intent"] = {"id": "tether", "name": "Tether", "time": 5, "weight": 3, "tether_plan": {"partner_id": 99}, "actions": [{"type": "tether_beam", "damage": 4}]}
		var continuation: Dictionary = before.duplicate(true)
		continuation["saved_action"] = {"actor_key": "enemy_1", "type": "tether_beam", "pattern": "line_between_thralls"}
		continuation["saved_step"] = {"actor_key": "enemy_1", "kind": "aoe", "action_type": "tether_beam", "intent_id": "tether", "label": "Tether", "pattern": "line_between_thralls", "tether_plan": {"partner_id": 99}, "from": Fixture.ACTOR, "to": Fixture.HERO}
		continuation["saved_step"]["en03_after"] = {"player": before["player"].duplicate(true), "enemies": before["enemies"].duplicate(true)}
		continuation["saved_kind_step"] = {"actor_key": "enemy_1", "kind": "tether_beam", "intent_id": "tether", "from": Fixture.ACTOR, "to": Fixture.HERO}
		var crawler: Dictionary = Fixture.state([Fixture.enemy("crawler", 1, Fixture.ACTOR)])
		crawler["enemies"][0]["intent"] = {"id": "tether", "actions": [{"type": "block", "amount": 77}], "tether_plan": {"keep": true}}
		crawler["saved_step"] = continuation["saved_step"].duplicate(true)
		crawler["saved_step"]["en03_after"] = {"player": crawler["player"].duplicate(true), "enemies": crawler["enemies"].duplicate(true)}
		crawler["saved_step"]["enemy_type"] = "arc_thrall" # A payload cannot assert its own ownership.
		var unrelated: Dictionary = crawler.duplicate(true)
		before["history"] = continuation.duplicate(true)
		var out_of_scope: Dictionary = {"id": "tether", "actions": [{"type": "block", "amount": 77}], "intent_id": "tether", "tether_plan": {"keep": true}}
		var run: Dictionary = {"mode": "combat", "combat_state": before, "pending_combat_checkpoints": [{"state": continuation}, {"state": crawler}], "unrelated": out_of_scope, "analytics_events": [{"intent_id": "tether", "action_type": "tether_beam"}]}
		expect.call(Store.save_run_state(run), "Legacy Thrall save writes through the real save store")
		var loaded: Dictionary = Store.load_saved_run()
		var saved: Dictionary = loaded["pending_combat_checkpoints"][0]["state"]
		expect.call(loaded["combat_state"]["enemies"][0]["intent"] == expected and saved["enemies"][0]["intent"] == expected, "Legacy held Tether converts in combat and continuation snapshots")
		expect.call(saved["saved_step"]["en03_after"]["enemies"][0]["intent"] == expected, "Partial continuation snapshot inherits encounter scaling")
		var action: Dictionary = saved["saved_action"]
		expect.call(action["type"] == "ranged" and action["damage"] == expected["actions"][1]["damage"] and not action.has("pattern"), "Owned legacy action converts and drops the retired pattern")
		expect.call(saved["saved_step"]["action_type"] == "ranged" and not saved["saved_step"].has("pattern") and not saved["saved_step"].has("tether_plan"), "Owned legacy step drops the retired pattern and plan")
		expect.call(Action.clip_for(saved["saved_kind_step"], saved["enemies"][0]) == "tether" and not Sfx.entry_for_enemy_step(saved["saved_step"]).is_empty(), "Migrated steps reach the existing cast and ranged cue")
		expect.call(loaded["pending_combat_checkpoints"][1]["state"] == unrelated, "THR01 CRAWLER OWNERSHIP: Block 77 and same-ID continuation steps stay unchanged")
		expect.call(loaded["unrelated"] == out_of_scope and loaded["combat_state"]["history"] == before["history"] and loaded["analytics_events"] == run["analytics_events"], "Migration leaves unrelated dictionaries, history and analytics unchanged")
		var again: Dictionary = loaded.duplicate(true)
		preload("res://scripts/arc_thrall_save_migration.gd").migrate(again)
		expect.call(again == loaded, "Scoped migration is idempotent")
		var after: Dictionary = Combat.new().resolve_enemy_turn_with_steps(loaded["combat_state"], 0)["state"]
		expect.call(after["player"]["hp"] == Fixture.HERO_HP - int(expected["actions"][1]["damage"]) and Surfaces.element_at(after, Fixture.HERO) == "electrified", "Reloaded legacy fight plays a real Arc Bolt")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)

static func _rules(expect: Callable) -> void:
	var engine := Combat.new()
	for instance_id: String in ["dynamo", "snare_lightning"]:
		var before: Dictionary = Fixture.state([Fixture.enemy("arc_thrall", 1, Fixture.ACTOR, "arc_bolt"), Fixture.enemy("storm_capacitor", 2, SOURCE, "discharge")])
		Rules.install(engine, before, Rules.instance_for(instance_id, 2))
		var after: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0)["state"]
		expect.call(Surfaces.element_at(after, Fixture.HERO) == "electrified", "%s receives fuel from a real Arc Bolt" % instance_id)
		var hp: int = int(after["player"]["hp"])
		var steps: Array[Dictionary]
		# Existing beat fuel matures at the next player activation, for both rules.
		after = engine.prepare_next_player_turn(after)
		if instance_id == "dynamo":
			after["enemies"][1]["charge"] = 3
			after = engine.resolve_enemy_turn_with_steps(after, 1)["state"]
		else:
			after = engine.finish_player_activation(after)
		expect.call(hp - int(after["player"]["hp"]) == (4 if instance_id == "dynamo" else 3), "%s strikes Arc Bolt's Electrified tile for its unchanged damage" % instance_id)

# Test-only geometry includes the director's Shrike/collateral reproduction.
const ROSTER_ACTOR := Vector2i(2, 4)
const SETTLE_FRAMES: int = 8
const PROOF_SIZE := Vector2i(1920, 1080)
const ILLUSION_HERO := Vector2i(1, 1)
const ILLUSION_ACTOR := Vector2i(3, 4)
const ILLUSION_TARGET := Vector2i(6, 4)

class PlaybackScene extends "res://scripts/run_scene.gd":
	var cast_frames: Array[Dictionary]
	func _render_board_state(state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
		super._render_board_state(state, shown, stable)
		var motion: Dictionary = shown.get("arc_thrall_motion", {}).get("enemy_1", {})
		if motion.is_empty(): return
		var renderer: Node = board_view.unit_cutout_renderer({"type": "arc_thrall", "id": 1})
		cast_frames.append({"direction": motion.get("direction", Vector2i.ZERO), "phase": float(motion.get("phase", 1.0)), "facing": renderer.snapshot().get("facing", "") if renderer != null else "missing"})

static func run_live(tree: SceneTree, expect: Callable, only: String = "") -> void:
	var previous_size: Vector2i = tree.root.size
	var previous_scale_size: Vector2i = tree.root.content_scale_size
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(PlaybackScene)
	tree.root.add_child(scene)
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	scene._load_run_state(Proof.build("thrall"))
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	tree.root.size = PROOF_SIZE
	tree.root.content_scale_size = PROOF_SIZE
	if only in ["", "roster"]: await _roster_at_rest(tree, scene, expect)
	if only in ["", "illusion"]: await _illusion_playback(tree, scene, expect)
	scene.queue_free()
	await tree.process_frame
	tree.root.size = previous_size
	tree.root.content_scale_size = previous_scale_size

static func _install(scene: Control, state: Dictionary) -> void:
	scene._combat_state = state.duplicate(true)
	scene._run_state["combat_state"] = scene._combat_state
	scene._run_state["current_room_layout"]["enemies"] = state["enemies"]
	scene._animation_lock = false
	scene._selected_card_index = -1
	scene._hovered_card_index = -1
	scene._drag_card_index = -1
	scene._hovered_board_tile = scene.INVALID_TARGET_TILE
	scene._show_all_enemy_intents = false
	scene._turn_order_hovered_enemy_key = ""
	scene._clear_focused_enemy_intent()
	scene._mark_combat_preview_state_changed()
	scene._refresh_stage_view()

static func _drawn_paths(board: Control) -> int:
	var commands: Array[Dictionary]
	board._path_captured_commands = commands
	board._path_command_capture_active = true
	board._draw_path_preview()
	board._path_command_capture_active = false
	return board._path_captured_commands.size()

static func _roster_at_rest(tree: SceneTree, scene: Control, expect: Callable) -> void:
	var engine := Combat.new()
	var count: int = 0
	for type: String in Data.enemies():
		var footprint: Array = Data.enemy_def(type).get("footprint", [1, 1])
		var collateral: Vector2i = ROSTER_ACTOR + Vector2i(int(footprint[0]), 0)
		var hero: Vector2i = collateral + Vector2i.RIGHT
		for intent: Dictionary in Data.enemy_def(type).get("intents", []):
			var state: Dictionary = Fixture.state([Fixture.enemy(type, 1, ROSTER_ACTOR), Fixture.enemy("crawler", 2, collateral)], hero)
			state["enemies"][0]["intent"] = engine._surface_prepare_enemy_intent(state, state["enemies"][0], intent.duplicate(true))
			if intent.get("id", "") == "discharge": state["enemies"][0]["charge"] = 3
			_install(scene, state)
			await tree.process_frame
			var commands: int = _drawn_paths(scene.board_view)
			expect.call(commands == 0, "THR01 REST PATHS %s/%s: %d drawn commands with collateral" % [type, intent.get("id", ""), commands])
			expect.call(not scene.board_view.presentation.get("threats_at_rest", {}).get("badges", []).is_empty(), "%s keeps approved threat badges at rest" % type)
			if intent.get("id", "") == "discharge": expect.call(not scene.board_view.presentation.get("projected_attack_tiles", []).is_empty(), "Capacitor retains its approved attack markers at rest")
			count += 1
	# Explicit focus/show-all retain the same real path commands suppressed at rest.
	var focused: Dictionary = Fixture.state([Fixture.enemy("gust_shrike", 1, ROSTER_ACTOR, "dive"), Fixture.enemy("crawler", 2, Vector2i(3, 4))], Vector2i(4, 4))
	_install(scene, Fixture.bolt())
	await tree.process_frame
	scene._on_board_tile_hovered(Fixture.ACTOR)
	scene._refresh_stage_view()
	await tree.process_frame
	expect.call(_drawn_paths(scene.board_view) > 0, "Focused enemy retains movement/displacement path commands")
	_install(scene, focused)
	scene._show_all_enemy_intents = true
	scene._refresh_stage_view()
	expect.call(_drawn_paths(scene.board_view) > 0, "Show-all retains movement/displacement path commands")
	var player_path: Array = [Vector2i(4, 4), Vector2i(5, 4)]
	var submitted: Dictionary = {"path_tiles": player_path, "displacement_paths": [player_path]}
	var decorated: Dictionary = submitted.duplicate(true)
	decorated["displacement_paths"].append([Vector2i(3, 4), Vector2i(3, 3)])
	var filtered: Dictionary = preload("res://scripts/enemy_path_presentation.gd").without_enemy_paths(decorated, submitted)
	expect.call(filtered == submitted, "Shared gate preserves caller-owned player preview paths")
	print("THR01 ROSTER DRAW: %d intents through full RunScene with collateral" % count)

static func _illusion_playback(tree: SceneTree, scene: Control, expect: Callable) -> void:
	for reduced: bool in [false, true]:
		var state: Dictionary = Fixture.state([Fixture.enemy("arc_thrall", 1, ILLUSION_ACTOR, "arc_bolt")], ILLUSION_HERO)
		state["illusions"] = [{"id": 7, "pos": ILLUSION_TARGET, "hp": Fixture.HERO_HP, "max_hp": Fixture.HERO_HP, "block": 0, "stoneskin": 0}]
		var phase: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state, 0, false)
		var attacks: Array = phase["steps"].filter(func(step: Dictionary) -> bool: return step.get("kind", "") == "ranged")
		print("THR01 ILLUSION RESOLVED: ", attacks.map(func(step: Dictionary) -> Dictionary: return {"from": step.get("from"), "to": step.get("to"), "target_key": step.get("target_key"), "tiles": step.get("tiles")}))
		expect.call(attacks.size() == 1 and attacks[0].get("to") == ILLUSION_TARGET, "Arc Bolt really targets the illusion")
		_install(scene, state)
		scene._settings["reduced_motion"] = reduced
		scene.cast_frames.clear()
		scene._animation_lock = true
		scene._combat_pacing.begin_enemies()
		await scene._animate_enemy_phase_steps(state.duplicate(true), phase["steps"])
		scene._combat_pacing.end_scope()
		var live_frames: Array = scene.cast_frames.filter(func(frame: Dictionary) -> bool: return frame["phase"] < 1.0)
		expect.call(not scene.cast_frames.is_empty() and scene.cast_frames.all(func(frame: Dictionary) -> bool: return frame["direction"] == ILLUSION_TARGET - ILLUSION_ACTOR), "THR01 ILLUSION AIM: every playback submission aims at the resolved target (reduced=%s)" % reduced)
		# Completed poses use the existing idle-facing policy; inspect the live cast.
		if not reduced: expect.call(not live_frames.is_empty() and live_frames.all(func(frame: Dictionary) -> bool: return frame["facing"] == "front"), "THR01 ILLUSION AIM: the actual in-flight renderer faces front")
	print("THR01 ILLUSION PLAYBACK: normal and reduced motion checked")
