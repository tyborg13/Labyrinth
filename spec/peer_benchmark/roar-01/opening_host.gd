extends Node

const Arrival = preload("res://scripts/dragon_arrival.gd")
const Proof = preload("res://spec/peer_benchmark/roar-01/proof_data.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")

class RoomEngine extends RefCounted:
	func room_metadata(_state: Dictionary, _tile: Vector2i) -> Dictionary:
		return {"type": "boss", "boss_id": "vyraketh"}

class CueRecorder extends "res://scripts/sfx_cue_router.gd":
	var cues: Array[String]
	var arrival_usec: int = 0
	var clock: SceneTreeTimer
	var arrival_game_seconds: float = 0.0
	func request(cue_id: String, _opts: Dictionary = {}) -> void:
		cues.append(cue_id)
		if cue_id == "dragon.roar":
			arrival_usec = Time.get_ticks_usec()
			if clock != null: arrival_game_seconds = 100.0 - clock.time_left

class BoardRecorder extends Node:
	var rumbles: int = 0
	var rumble_values: Array
	func rumble(px: float, seconds: float, oscillations: float) -> void:
		rumbles += 1
		rumble_values = [px, seconds, oscillations]

var _combat_state: Dictionary
var _run_state: Dictionary = {"mode": "combat"}
var _run_engine := RoomEngine.new()
var _board_presentation: Dictionary = {"proof_unrelated": true}
var _sfx_router := CueRecorder.new()
var board_view := BoardRecorder.new()
var actor: Node
var reduced: bool = false
var can_continue: bool = true
var refreshes: int = 0
var last: Dictionary
var phases: Array[float]
var transition: Array

func _ready() -> void:
	add_child(board_view)

func configure(id: String, hero: Vector2i) -> void:
	_combat_state = Proof.state(id, hero)
	actor = Proof.renderer(id)
	add_child(actor)
	actor.set_process(false)

func _card_fx_can_continue_combat() -> bool:
	return can_continue

func _reduced_motion_enabled() -> bool:
	return reduced

func _ensure_sfx_bank() -> void:
	pass

func _transition_music(theme: Dictionary, hold: float, fade: float) -> void:
	transition = [theme, hold, fade]

func _refresh_stage_view() -> void:
	refreshes += 1
	var enemy: Dictionary = _combat_state["enemies"][0]
	var key: String = str(enemy["type"]) + "_motion"
	var motion: Dictionary = (_board_presentation.get(key, {}) as Dictionary).get("enemy_1", {})
	var center: Vector2i = Proof.ENEMY_TILE * 2 + Vector2i.ONE
	motion = Facing.with_idle_direction(motion, center, _combat_state["player"]["pos"] * 2)
	actor.call("present", motion, reduced)
	last = actor.call("snapshot")
	if last["clip"] == "roar": phases.append(float(last["phase"]))
