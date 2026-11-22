extends "res://tools/atk07/frozen_span_proof.gd"
## The hunt's resolution oracle needs the same horizon as the approved forecast.
const Hunt = preload("res://tools/qa127/whole_run.gd")

func _freezing_hit(scene: Node, engine: RefCounted) -> void:
	super._freezing_hit(scene, engine)
	scene.set("_combat_engine", engine)
	var state: Dictionary = _fixture()
	var expected: Dictionary = _live_span(engine, state)
	var actual: Dictionary = Hunt.replay_pass(scene, state)
	var hp: int = int(expected["state"]["player"]["hp"])
	_assert(actual["complete"] and actual["skipped"] == expected["skipped"], "The audit resolves the frozen span")
	_assert(int(actual["state"]["player"]["hp"]) == hp, "The audit checks Health when the hero can act")
	_assert(int(actual["first"]["player"]["hp"]) == int(expected["first_hp"]), "The audit retains the first live handoff")
	_assert(int(actual["losses"]["hp"]) == int(state["player"]["hp"]) - hp, "The audit adds the loss from the skipped turn")
