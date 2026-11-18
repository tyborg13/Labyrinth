extends RefCounted
## Rearrange resolved receipts for simultaneous primary bolts, then actual hops.
## Scalar patches affect only the displayed copy; no targeting/damage is rerun.
const Typed = preload("res://scripts/typed_arrays.gd")
const Bursts = preload("res://scripts/enemy_mechanics/burst_playback.gd")

static func losses(engine: RefCounted, before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = engine._actor_target_losses(before, after)
	result.append_array(engine._enemy_target_losses(before, after))
	# The normal defeat sequence shows each Burst's damage on its own contact.
	return Bursts.without_burst_losses(engine, {"target_losses": result}, before, after)["target_losses"]

static func _receipt(engine: RefCounted, before: Dictionary, after: Dictionary) -> Dictionary:
	var changes: Array[Dictionary]
	for actor: Dictionary in engine._surface_actor_records(before):
		var old: Dictionary = engine._surface_actor(before, actor["kind"], actor["id"])
		var next: Dictionary = engine._surface_actor(after, actor["kind"], actor["id"])
		var fields: Dictionary = {}
		for field: Variant in next:
			if next[field] == old.get(field): continue
			fields[field] = next[field]
		var delta: Dictionary = {}
		for field: String in ["hp", "block", "stoneskin"]:
			if fields.has(field):
				delta[field] = int(next.get(field, 0)) - int(old.get(field, 0))
				fields.erase(field)
		if not fields.is_empty() or not delta.is_empty(): changes.append({"kind": actor["kind"], "id": actor["id"], "fields": fields.duplicate(true), "delta": delta})
	return {"changes": changes, "losses": losses(engine, before, after)}

static func stages(engine: RefCounted, beat: Dictionary) -> Array[Dictionary]:
	var primary: Dictionary = {"effect": {"kind": "lightning_strikes", "action_type": "lightning_strikes", "element": "lightning", "tiles": beat["tiles"]}, "changes": [], "losses": []}
	var result: Array[Dictionary] = Typed.dictionaries([primary])
	var previous: Dictionary = beat["before"]
	for hit: Dictionary in beat.get("chain_hits", []):
		var snapshot: Dictionary = hit.get("state", {})
		if snapshot.is_empty(): continue
		var receipt: Dictionary = _receipt(engine, previous, snapshot)
		if str(hit.get("kind", "")) == "actor" and hit.get("from") != hit.get("to"):
			receipt["effect"] = {"kind": "chain", "element": "lightning", "from": hit["from"], "to": hit["to"], "path": hit.get("path", [])}
			result.append(receipt)
		else:
			primary["changes"].append_array(receipt["changes"])
			primary["losses"].append_array(receipt["losses"])
		previous = snapshot
	# Resolver cleanup can include collateral losses. They belong to the final
	# contact, never an unexplained committed-state refresh.
	var tail: Dictionary = _receipt(engine, previous, beat["after"])
	result[-1]["changes"].append_array(tail["changes"])
	result[-1]["losses"].append_array(tail["losses"])
	var displayed: Dictionary = (beat["before"] as Dictionary).duplicate(true)
	for stage: Dictionary in result:
		stage["before"] = displayed.duplicate(true)
		for change: Dictionary in stage["changes"]:
			var unit: Dictionary = engine._surface_actor(displayed, change["kind"], change["id"])
			for field: String in change["delta"]: unit[field] = int(unit.get(field, 0)) + int(change["delta"][field])
			unit.merge(change["fields"].duplicate(true), true)
		stage["after"] = displayed.duplicate(true)
	result[-1]["after"] = (beat["after"] as Dictionary).duplicate(true)
	return result
