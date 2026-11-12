extends SceneTree
## Tools-only span semantics and off-path microbenchmark.
var telemetry: Node
var trace_enabled: bool = OS.get_environment("LABYRINTH_HITCH_TRACE") == "1"
const Assets = preload("res://scripts/asset_loader.gd")
const BENCHMARK_CALLS: int = 1000000
const BENCHMARK_ROUNDS: int = 7
const SPAN_FIXTURE_US: int = 1000
const FIXTURE_PATH: String = "res://scripts/typed_arrays.gd"
var sink: int = 0

class PolicyEngine extends RefCounted:
	func _enemy_footprint_tiles(enemy: Dictionary) -> Array:
		return [enemy["pos"]]

class PolicyMap extends RefCounted:
	func room_metadata(_state: Dictionary, tile: Vector2i) -> Dictionary:
		return {"section_index": tile.x, "map_step": tile.y}

class PolicyScene extends Node:
	var _run_state: Dictionary = {"mode": "combat"}
	var _combat_state: Dictionary = {"player": {"pos": Vector2i.ZERO}, "enemies": [{"hp": 9, "pos": Vector2i(2, 0)}]}
	var _combat_engine: RefCounted = PolicyEngine.new()
	var _run_engine: RefCounted = PolicyMap.new()
	var treasure_busy: bool = false
	var options: Dictionary = {}

	func _treasure_presentation_busy() -> bool:
		return treasure_busy

	func _card_play_options_for_index(index: int) -> Dictionary:
		return options[index]

	func _on_abandon_run_pressed() -> void:
		pass

func _check_policy() -> void:
	var policy := preload("res://tools/hitch_census/whole_policy.gd").new()
	policy.rng = RandomNumberGenerator.new()
	policy.rng.seed = 84
	policy.no_embrace = true
	var scene := PolicyScene.new()
	var attack: Dictionary = {"kind": "ranged", "preferred": true, "args": [Vector2i(2, 0)]}
	var advance: Dictionary = {"kind": "move", "tile": Vector2i(1, 0), "preferred": true}
	assert(policy.choose(scene, [advance, attack]) == attack)
	scene.options = {
		0: {"play": {"action": {"type": "melee"}, "target_tiles": [Vector2i(0, 1)]}},
		1: {"play": {"action": {"type": "ranged"}, "target_tiles": [Vector2i(2, 0)]}},
	}
	var miss: Dictionary = {"kind": "card", "args": [0]}
	var hit: Dictionary = {"kind": "card", "args": [1]}
	assert(policy.choose(scene, [miss, advance, hit]) == hit)
	assert(policy.choose(scene, [{"kind": "move", "tile": Vector2i(1, 1), "preferred": true}, advance]) == advance)
	scene._run_state["mode"] = "room"
	var forward: Dictionary = {"kind": "map_room", "args": [Vector2i(1, 2)]}
	assert(policy.choose(scene, [{"kind": "map_room", "args": [Vector2i(0, 9)]}, forward]) == forward)
	scene.treasure_busy = true
	var treasure_ui: Dictionary = {"kind": "ui"}
	assert(policy.choose(scene, [forward, treasure_ui]) == treasure_ui)
	scene.treasure_busy = false
	var retry_policy := preload("res://tools/hitch_census/whole_policy.gd").new()
	retry_policy.rng = policy.rng
	assert(retry_policy.choose(scene, [forward, treasure_ui]) == forward)
	assert(retry_policy.choose(scene, [forward, treasure_ui]) == treasure_ui)
	var begin: Dictionary = {"kind": "begin_combat"}
	assert(policy.choose(scene, [{"kind": "equipment"}, begin]) == begin)
	scene._run_state["mode"] = "combat"
	scene.options[2] = {"play": {"action": {"type": "block"}}}
	scene.options[3] = {"play": {"state": {"run_stats": {"damage_dealt": 4}}}}
	var targetless_attack: Dictionary = {"kind": "card", "args": [3]}
	assert(policy.choose(scene, [{"kind": "card", "args": [2]}, targetless_attack]) == targetless_attack)
	var pass_turn: Dictionary = {"kind": "pass"}
	assert(policy.choose(scene, [{"kind": "card", "args": [2]}, pass_turn])["kind"] == "card")
	scene._combat_state["enemies"].append({"hp": 1, "pos": Vector2i(3, 0)})
	var finish_enemy: Dictionary = {"kind": "ranged", "preferred": true, "args": [Vector2i(3, 0)]}
	assert(policy.choose(scene, [attack, finish_enemy]) == finish_enemy)
	scene._combat_state["objective"] = {"type": "reach_exit", "exits": [{"target_tile": Vector2i(0, 3)}]}
	var exit_move: Dictionary = {"kind": "move", "tile": Vector2i(0, 2), "preferred": true}
	assert(policy.choose(scene, [attack, exit_move]) == exit_move)
	scene._combat_state["enemies"][0]["id"] = 8
	scene._combat_state["objective"] = {"leader_id": 8}
	assert(policy.choose(scene, [attack, finish_enemy]) == attack)
	var abandon := Button.new()
	abandon.pressed.connect(scene._on_abandon_run_pressed)
	assert(policy._terminal_control(abandon))
	abandon.free()
	scene.free()
	print("HITCH WHOLE POLICY: hittable attacks, nearest advance, forward map, focus, hand cycling, treasure/exit/leader objectives, unchanged-transition retry, terminal filter PASS")

func _initialize() -> void:
	_run.call_deferred()

func _baseline() -> void:
	sink += 1

func _gated() -> void:
	var _span: RefCounted
	if trace_enabled: _span = telemetry.hitch_phase("input:check")
	sink += 1

func _run() -> void:
	telemetry = root.get_node("PerformanceTelemetry")
	_check_policy()
	if not trace_enabled:
		var baseline: Array[float]
		var gated: Array[float]
		for round_index: int in BENCHMARK_ROUNDS:
			var started: int = Time.get_ticks_usec()
			for index: int in BENCHMARK_CALLS: _baseline()
			baseline.append(float(Time.get_ticks_usec() - started) * 1000.0 / BENCHMARK_CALLS)
			started = Time.get_ticks_usec()
			for index: int in BENCHMARK_CALLS: _gated()
			gated.append(float(Time.get_ticks_usec() - started) * 1000.0 / BENCHMARK_CALLS)
		baseline.sort()
		gated.sort()
		print("HITCH OFF GATE: baseline_ns/call=%.3f gated_ns/call=%.3f delta_ns/call=%.3f calls=%d rounds=%d" % [baseline[3], gated[3], gated[3] - baseline[3], BENCHMARK_CALLS, BENCHMARK_ROUNDS])
		assert(root.get_node("PerformanceTelemetry").take_hitch_events().is_empty() and root.get_node("PerformanceTelemetry").take_hitch_phases().is_empty())
		print("HITCH OFF ASSERTIONS: no events/phases PASS")
	else:
		root.get_node("PerformanceTelemetry").take_hitch_events()
		root.get_node("PerformanceTelemetry").take_hitch_phases()
		var span: RefCounted = telemetry.hitch_phase("post_draw:check:return")
		OS.delay_usec(SPAN_FIXTURE_US)
		# A live span survives a sample boundary and publishes on completion.
		assert(root.get_node("PerformanceTelemetry").take_hitch_phases().is_empty())
		span = null
		assert(int(root.get_node("PerformanceTelemetry").take_hitch_phases()["post_draw:check:return"]) >= SPAN_FIXTURE_US)
		var resource: Resource = telemetry.hitch_resource_load(FIXTURE_PATH)
		resource = telemetry.hitch_resource_load(FIXTURE_PATH)
		var events: Dictionary = root.get_node("PerformanceTelemetry").take_hitch_events()
		assert(int(events["load:" + FIXTURE_PATH]["count"]) == 2)
		assert(int(events["load:" + FIXTURE_PATH]["godot_cached_at_entry"]) >= 1)
		assert(resource != null)
		var texture: Texture2D = Assets.load_texture("res://assets/art/portraits/cinder_droplet.png")
		assert(texture != null)
		assert(root.get_node("PerformanceTelemetry").take_hitch_events().has("load:res://assets/art/portraits/cinder_droplet.png"))
		assert(root.get_node("PerformanceTelemetry").take_hitch_events().is_empty())
		print("HITCH HOOK ASSERTIONS: completed spans, drain, resource cache hits, AssetLoader PASS")
	quit()
