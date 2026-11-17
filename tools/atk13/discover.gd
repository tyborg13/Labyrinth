extends SceneTree
## Fast natural-map census; no rendering or writes to production state.
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := preload("res://scripts/run_engine.gd").new()
	var rows: Array[Dictionary]
	for seed_value: int in range(1301, 1341):
		var state: Dictionary = engine.create_new_run(seed_value, preload("res://scripts/progression_store.gd").default_data())
		var tiers: Array[int]
		for room: Dictionary in state["rooms"].values():
			if str(room.get("guardian_id", "")) == "storm_cantor":
				var tier: int = posmod(int(room["depth"]) - 1, 4) + 1
				if not tiers.has(tier): tiers.append(tier)
		rows.append({"seed": seed_value, "tiers": tiers})
	print("ATK13 DISCOVERY " + JSON.stringify(rows))
	quit()
