extends "res://scripts/combat_pacing.gd"
## Observe production enemy beats. Use frame time only where a dry run lacks MovieWriter.

const FPS := preload("res://tools/fel03/evidence.gd").FPS

var dry: bool
var step_seen: Callable

class FrameHitStop extends "res://scripts/combat_hit_stop.gd":
	func request(damage: int, killed: bool = false, hero: bool = false, reduced: bool = false, allowed: bool = true, now_usec: int = -1) -> bool:
		return super.request(damage, killed, hero, reduced, allowed, now_usec if now_usec >= 0 else _frame_usec())

	func poll(now_usec: int = -1) -> void:
		super.poll(now_usec if now_usec >= 0 else _frame_usec())

	func _frame_usec() -> int:
		return roundi(Engine.get_process_frames() * 1000000.0 / FPS)


func install(host: Node) -> void:
	super.install(host)
	if not dry: return
	hit_stop.free()
	hit_stop = FrameHitStop.new()
	hit_stop.name = "CombatHitStop"
	hit_stop.restore_scale = current_scale
	hit_stop.scale_changing.connect(_sync_clock)
	hit_stop.stop_ended.connect(_release_flashes)
	add_child(hit_stop)


func _sync_clock() -> void:
	if not dry:
		super._sync_clock()
		return
	_clock_usec += _movie_clock.advance(Engine.get_process_frames(), 1.0 / FPS, Engine.time_scale, is_inside_tree() and get_tree().paused)


func before_step(step: Dictionary, activation_steps: Array = []) -> void:
	if enemies_active and step_seen.is_valid(): step_seen.call(step)
	await super.before_step(step, activation_steps)
