extends "res://scripts/combat_pacing.gd"
## Delegate every scheduling decision to production. Observe its exact phase edges.

var census
var _wait_serial: int = 0


func before_step(step: Dictionary, activation_steps: Array = []) -> void:
	if not census.active():
		await super.before_step(step, activation_steps)
		return
	var kind: String = str(step.get("kind", ""))
	var is_action: bool = is_action_step(step) or kind in ["move", "reinforcement_spawn", "worldspine_pulse"]
	census.end_action(census.step)
	census.begin_step(step, is_action)
	var current: int = census.step
	var dependent: bool = _death_dependency(step) or _surface_dependency(step)
	var dependency_id: String = "dependency:%d" % current
	if dependent:
		census.begin("dependency wait", dependency_id, "combat_pacing.gd:412", {
			"death": _death_dependency(step), "surface": _surface_dependency(step),
		})
	await super.before_step(step, activation_steps)
	if dependent: census.end(dependency_id)
	census.start_action()


func after_step(step: Dictionary) -> void:
	var current: int = census.step
	await super.after_step(step)
	if census.active(): census.end_action(current)


func _wait_until(deadline: int) -> void:
	if not census.active():
		await super._wait_until(deadline)
		return
	_wait_serial += 1
	var id: String = "wait:%d" % _wait_serial
	var source: String = "combat_pacing.gd:427" if _phase == "pre-action delay" else "combat_pacing.gd:455" if _phase == "post-action settle" else "combat_pacing.gd:451"
	var kind: String = _phase if _phase in ["pre-action delay", "post-action settle", "number contact wait"] else "feedback deadline"
	if deadline > presentation_usec():
		census.begin(kind, id, source)
	await super._wait_until(deadline)
	census.end(id)


func _change_phase(phase: String) -> void:
	super._change_phase(phase)
	if census.active(): census.phase = phase


func finish_enemies() -> void:
	if census.active():
		census.end_action(census.step)
		census.step = -1
		census.actor = ""
		census.begin("hero hand-off drain", "drain", "combat_pacing.gd:248")
	await super.finish_enemies()
	if census.active(): census.end("drain")
