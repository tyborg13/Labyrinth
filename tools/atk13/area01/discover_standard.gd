extends SceneTree
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Tables = preload("res://scripts/encounter_tables.gd")
const PROOF_FIRST_SEED: int = 1301
const PROOF_SEEDS: int = 10
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var engine := Run.new()
	for seed_value: int in range(PROOF_FIRST_SEED,PROOF_FIRST_SEED+PROOF_SEEDS):
		var run: Dictionary = engine.create_new_run(seed_value, Store.default_data())
		for previous: Dictionary in run["rooms"].values():
			if str(previous.get("type", "")) == "combat": previous["cleared"] = true; break
		var found: Dictionary = {}
		var roster: Dictionary = {}
		for room: Dictionary in run["rooms"].values():
			Graph.resolve_mystery(run,room)
			if str(room.get("type", "")) != "combat" or bool(room.get("cleared", false)): continue
			Tables.record_room_entry(run,room)
			var layout: Dictionary = engine._combat_layout_for_room(room,Vector2i.UP,run)
			for enemy: Dictionary in layout.get("enemies", []):
				var id: String = str(enemy["type"])
				roster[id] = int(roster.get(id,0))+1
				if id in ["briar_weaver","burrow_grub"]: found[id] = {"coord":str(room["coord"]),"type":room["type"],"special":room.get("special_variant", ""),"fight_number":room.get("fight_number")}
		print("AREA01 DISCOVERY ",seed_value," ",JSON.stringify(found)," roster=",JSON.stringify(roster))
	quit(0)
