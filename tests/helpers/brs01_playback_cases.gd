extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Live = preload("res://tests/suites/movement_undo_suite.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
# Test-only positions/health: three FIFO deaths and a surviving hero/witness.
const CHAIN_START := Vector2i(3, 3)
const WITNESS_TILE := Vector2i(5, 4)
const CHAIN_HP: int = 4
const BLEED_DAMAGE: int = 6
const RETALIATE_DAMAGE: int = 6
const HIDDEN_SOURCE := Vector2i(3, 3)
const VISIBLE_TARGET := Vector2i(4, 4)

class PlaybackScene extends "res://scripts/run_scene.gd":
	var recording: bool = false
	var burst_samples: Array[Dictionary]
	var elapsed: float = 0.0
	func _render_board_state(state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
		super._render_board_state(state, shown, stable)
		if not recording: return
		for effect: Dictionary in shown.get("burst_effects", []):
			burst_samples.append({"effect": effect.duplicate(true), "clock": elapsed, "reduced": _reduced_motion_enabled()})
	func _play_timed_animation_frames(count: int, seconds: float, render: Callable) -> void:
		await super._play_timed_animation_frames(count, seconds, func(frame: int) -> void:
			elapsed = float(frame - 1) * seconds
			render.call(frame))
	func _play_death_sequence(clock: Dictionary, render: Callable) -> void:
		await super._play_death_sequence(clock, func(progress: float) -> void:
			elapsed = progress * float(clock["duration"])
			render.call(progress))

static func run(check: Callable) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	Live.prepare_storage()
	var raw: Control = load("res://scenes/run_scene.tscn").instantiate()
	raw.set_script(PlaybackScene)
	var scene := raw as PlaybackScene
	tree.root.add_child(scene)
	await Live.settle(tree)
	_traced_journal_ownership(check)
	for reduced: bool in [false, true]:
		Live.set_reduced_motion(scene, reduced)
		for trigger: String in ["bleed", "hidden_bleed", "retaliate"]:
			await _enemy_phase(scene, trigger, reduced, check)
		await _player_phase(scene, reduced, check)
		await _hidden_cascade(scene, reduced, check)
	scene.queue_free()
	await tree.process_frame
	return true

static func _chain() -> Dictionary:
	var state: Dictionary = Fixture.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler"])
	for index: int in range(3):
		state["enemies"][index]["pos"] = CHAIN_START + Vector2i(index, 0)
		if index > 0: state["enemies"][index]["hp"] = CHAIN_HP
	state["enemies"][3]["pos"] = WITNESS_TILE
	return state

static func _traced_journal_ownership(check: Callable) -> void:
	var before: Dictionary = _chain()
	var engine := Combat.new()
	var after: Dictionary = engine._damage_enemy(before.duplicate(true), 0, BLEED_DAMAGE)
	var header: Dictionary = engine._enemy_status_damage_step({"actor_key": "enemy_1"}, before, after)
	check.call(header.has("death_burst_events_after"), "Legacy status retains its newly resolved Burst journal")
	var entries: Array[Dictionary]
	entries.append({"source": {"action_type": "charge"}, "after": preload("res://scripts/reaction_presentation_trace.gd").snapshot(before), "losses": {"enemy_losses": [], "target_losses": [], "terrain_losses": []}, "sequence": 0})
	var steps: Array[Dictionary] = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").charge_steps(engine, before, after, entries, header)
	check.call(steps.size() == 1 and bool(steps[0]["traced_charge"]) and not steps[0].has("death_burst_events_after"), "Explicit traced cascades keep sole ownership; Bleed header cannot replay their journal")

static func _install(scene: PlaybackScene, state: Dictionary) -> void:
	Live.install(scene, state.duplicate(true))
	scene.burst_samples.clear()
	scene.recording = true

static func _enemy_phase(scene: PlaybackScene, trigger: String, reduced: bool, check: Callable) -> void:
	var state: Dictionary = _chain()
	if trigger in ["bleed", "hidden_bleed"]: state["enemies"][0]["bleed"] = BLEED_DAMAGE
	else: state["retaliate"] = {"amount": RETALIATE_DAMAGE}
	if trigger == "hidden_bleed": state["umbra"] = {"stage": "eclipse"}
	var original: Dictionary = state.duplicate(true)
	var phase: Dictionary = Combat.new().resolve_enemy_turn_with_steps(state, 0)
	var events: Array = phase["state"].get("death_burst_events", [])
	var label: String = "%s reduced=%s" % [trigger, reduced]
	check.call(events.size() == 3 and int(phase["state"]["player"]["hp"]) > 0, label + " rules resolve three Bursts with a surviving hero")
	_install(scene, state)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.begin_enemies()
	var animated: Dictionary = state.duplicate(true)
	await scene._animate_enemy_phase_steps(animated, phase["steps"])
	await pacing.finish_enemies()
	scene.recording = false
	var seen: Dictionary = {}
	var starts: Dictionary = {}
	for sample: Dictionary in scene.burst_samples:
		var effect: Dictionary = sample["effect"]
		seen[int(effect["id"])] = true
		# Recover each event's authored start independently of callback cadence.
		starts[int(effect["id"])] = float(sample["clock"]) - float(effect["elapsed"])
	check.call(scene.burst_samples.all(func(sample: Dictionary) -> bool: return bool(sample["reduced"]) == reduced), label + " keeps the current motion setting on every frame")
	check.call(seen.size() == events.size() and not events.is_empty(), label + " actual enemy-phase renderer receives every resolved Burst")
	for index: int in range(events.size()):
		var id: int = int(events[index]["id"])
		check.call(seen.has(id), label + " presents resolved Burst %d" % id)
		if index > 0 and starts.has(id) and starts.has(int(events[index - 1]["id"])):
			check.call(is_equal_approx(float(starts[id]) - float(starts[int(events[index - 1]["id"])]), Burst.BURST_CHAIN_SECONDS), label + " retains 0.18 s FIFO spacing")
	check.call(animated["player"] == phase["state"]["player"] and animated["enemies"] == phase["state"]["enemies"], label + " playback settles the real resolver outcome")
	check.call(state == original, label + " leaves rule input unchanged")
	print("BRS02 ENEMY PLAYBACK: %s; rules=%d; rendered=%d" % [label, events.size(), seen.size()])

static func _player_phase(scene: PlaybackScene, reduced: bool, check: Callable) -> void:
	var before: Dictionary = _chain()
	var after: Dictionary = Combat.new().apply_player_action(before, {"type": "ranged", "damage": BLEED_DAMAGE, "range": 5}, CHAIN_START)
	_install(scene, before)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.begin_card()
	await scene._animate_turn_order_alongside_defeats(before, after)
	pacing.end_scope()
	scene.recording = false
	var seen: Dictionary = {}
	for sample: Dictionary in scene.burst_samples: seen[int(sample["effect"]["id"])] = true
	check.call(seen.size() == 3 and seen.size() == (after["death_burst_events"] as Array).size(), "Player-card phase retains all three resolved Bursts, reduced=%s" % reduced)
	print("BRS02 PLAYER PLAYBACK: reduced=%s; rules=3; rendered=%d" % [reduced, seen.size()])

static func _hidden_cascade(scene: PlaybackScene, reduced: bool, check: Callable) -> void:
	var before: Dictionary = _chain()
	# Eclipse sight is one tile: the diagonal source is concealed.
	before["umbra"] = {"stage": "eclipse"}
	before["player"]["pos"] = VISIBLE_TARGET
	var engine := Combat.new()
	var after: Dictionary = engine._damage_enemy(before.duplicate(true), 0, BLEED_DAMAGE)
	var event: Dictionary = after["death_burst_events"][0]
	check.call(not engine.is_tile_visible_to_player(after, HIDDEN_SOURCE) and engine.is_tile_visible_to_player(after, VISIBLE_TARGET), "Hidden fixture conceals source and exposes victim")
	var step: Dictionary = {"kind": "status_damage", "action_type": "death_burst", "actor_key": "enemy_1", "hidden_by_umbra": true, "tile": Vector2i(-1, -1), "cascade": event, "reaction_after": preload("res://scripts/reaction_presentation_trace.gd").snapshot(after), "target_losses": [], "enemy_losses": [], "impact_actor_keys": ["player"]}
	_install(scene, before)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.begin_enemies()
	var animated: Dictionary = before.duplicate(true)
	await scene._animate_enemy_phase_steps(animated, [step])
	await pacing.finish_enemies()
	scene.recording = false
	var visible_feedback: bool = false
	var concealed_source: bool = true
	var visible_only: bool = true
	for sample: Dictionary in scene.burst_samples:
		var effect: Dictionary = sample["effect"]
		concealed_source = concealed_source and effect["tile"] == Vector2i(-1, -1) and not effect.has("id") and not effect.has("before") and not effect.has("after")
		for tile: Vector2i in effect["tiles"]:
			visible_only = visible_only and engine.is_tile_visible_to_player(after, tile)
		if (effect["tiles"] as Array).has(VISIBLE_TARGET) and float(effect["elapsed"]) > 0.0 and float(effect["elapsed"]) < 0.30: visible_feedback = true
	check.call(concealed_source and visible_only, "Every hidden Burst frame conceals its source and submits only visible affected tiles")
	check.call(visible_feedback, "Hidden cascade keeps visible Burst glow, reduced=%s" % reduced)
	check.call(animated["player"] == after["player"], "Hidden cascade settles the resolved visible victim")
	var none: Dictionary = {}
	var invisible: Dictionary = step.duplicate(true)
	invisible["cascade"]["tiles"] = [HIDDEN_SOURCE]
	preload("res://scripts/enemy_mechanics/deferred_death_view.gd").decorate_hidden_feedback(scene, after, invisible, none)
	check.call(not none.has("en01_burst"), "Fully concealed Burst creates no feedback")
	invisible = step.duplicate(true)
	invisible["cascade_continuation"] = true
	preload("res://scripts/enemy_mechanics/deferred_death_view.gd").decorate_hidden_feedback(scene, after, invisible, none)
	check.call(not none.has("en01_burst"), "Hidden continuation creates no duplicate Burst")
	print("BRS02 HIDDEN PLAYBACK: reduced=%s; visible_glow=%s; concealed_source=true" % [reduced, visible_feedback])
