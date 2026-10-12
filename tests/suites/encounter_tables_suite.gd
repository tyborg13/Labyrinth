extends RefCounted

const Tables = preload("res://scripts/encounter_tables.gd")
const Generator = preload("res://scripts/room_generator.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const GameData = preload("res://scripts/game_data.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const Guided = preload("res://scripts/guided_combat_scenario.gd")
const FIXTURE_SEED: int = 83
# Fixed statistical fixtures for 10k samples with a relative 2% bound.
const WEIGHT_SEEDS: Dictionary = {"1": {"fire": 4723, "none": 4709}, "2": {"fire": 4820, "none": 4703}, "3": {"fire": 4743, "none": 4704}}
const WEIGHT_PICKS: int = 10000
const WEIGHT_RELATIVE_TOLERANCE: float = 0.02
const PLACEMENT_SEEDS: int = 32
const LEGACY_SEEDS: int = 64
const LEGACY_LAYOUT_SHA256: String = "dbdc515cc8b36127e2d0f913b508e70c886eb07588cb68636261b203164c3618"
const LEGACY_POOL_SHA256: String = "effa730618ac9f8acdc67de0198d8eb5682af2708e22b8f12c2da7cb0c2c8b59"
const LEGACY_STATE_SHA256: String = "7929444654f9757b01d24bd1f58e1f1416e34f7709c0b8e6d0e773a5a92db6c3"

# Force each authored entry through the actual generator/placement path without
# replacing the protected table or introducing a gameplay override.
class EntryGenerator:
	extends "res://scripts/room_generator.gd"
	var entry: Dictionary
	func _section_encounter(room: Dictionary, _tier: int, rng: RandomNumberGenerator) -> Dictionary:
		return preload("res://scripts/encounter_tables.gd").expand_entry(entry, room["element"], room["encounter_biome"], rng)

static func run(expect: Callable) -> void:
	_test_validation(expect)
	_test_tokens_and_trim(expect)
	_test_weights(expect)
	_test_history(expect)
	_test_run_history(expect)
	_test_legacy(expect)
	_test_placement(expect)
	print("Encounter base totals: ", JSON.stringify(expansion_report()))

static func _test_validation(expect: Callable) -> void:
	var table: Dictionary = Tables.load()
	expect.call(Tables.validate(table).is_empty(), "Protected encounter table validates")
	expect.call(is_same(table, Tables.load()), "Encounter definitions load once")
	for mutation: String in ["unit", "element", "biome", "weight", "group_weight", "token", "duplicate", "trim", "capacity", "fractional", "missing_biome"]:
		var bad: Dictionary = table.duplicate(true)
		match mutation:
			"unit": bad["tiers"]["1"][0]["units"][0] = "missing_enemy"
			"element": bad["element_regulars"]["bad_element"] = ["crawler"]
			"biome": bad["biome_groups"]["bad_biome"] = bad["biome_groups"]["earth"]
			"weight": bad["tiers"]["1"][0]["weight"] = 0
			"group_weight": bad["biome_groups"]["earth"][0]["weight"] = -1
			"token": bad["tiers"]["1"][0]["units"][0] = "$unknown"
			"duplicate": bad["tiers"]["2"][0]["id"] = bad["tiers"]["1"][0]["id"]
			"trim": bad["rules"]["trim_rule"] = "drop tokens"
			"capacity": bad["rules"]["max_units"] = 1
			"fractional": bad["rules"]["no_repeat_last"] = 0.5
			"missing_biome": bad["biome_groups"].erase("shadow")
		expect.call(not Tables.validate(bad).is_empty(), "Malformed table fails validation: " + mutation)
	expect.call(Tables.validate({}).size() > 0, "Missing schema fails validation")

static func _test_tokens_and_trim(expect: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	var table: Dictionary = Tables.load()
	var expanded: Dictionary = Tables.expand_entry(table["tiers"]["1"][5], "lightning", "ice", rng)
	expect.call(expanded["units"] == ["lightning_wisp", "lightning_wisp", "rime_whelp", "rime_spitter", "harrier"], "Tokens expand in place with the room regular and section biome")
	expect.call(not Tables.supports_element(table["tiers"]["1"][3], "none"), "Neutral rooms skip element tokens")
	var trimmed: Dictionary = Tables.expand_entry(table["tiers"]["3"][4], "fire", "shadow", rng)
	expect.call(trimmed["units"] == ["wick_shade", "wick_shade", "veilbound_acolyte", "wick_shade", "wick_shade", "veilbound_acolyte", "warden"], "Trim drops the last concrete unit, preserves both token groups")
	trimmed = Tables.expand_entry(table["tiers"]["3"][5], "lightning", "shadow", rng)
	expect.call(trimmed["units"] == ["lightning_wisp", "lightning_wisp", "lightning_wisp", "lightning_wisp", "wick_shade", "wick_shade", "veilbound_acolyte"], "Trim preserves token units at the seven-unit cap")
	trimmed = Tables.expand_entry({"id": "multi_trim_fixture", "units": ["crawler", "$biome", "harrier", "$biome", "warden", "acolyte"]}, "none", "shadow", rng)
	expect.call(trimmed["units"] == ["crawler", "wick_shade", "wick_shade", "veilbound_acolyte", "wick_shade", "wick_shade", "veilbound_acolyte"], "Trim walks backward across token groups and removes multiple concrete units")
	# A synthetic multi-group biome proves each token draws independently.
	var synthetic: Dictionary = table.duplicate(true)
	synthetic["biome_groups"]["earth"] = [{"id": "first", "weight": 1, "units": ["crawler"]}, {"id": "second", "weight": 3, "units": ["harrier"]}]
	Tables._table = synthetic
	var seen: Dictionary = {}
	var harriers: int = 0
	for index: int in range(WEIGHT_PICKS):
		var pick: Dictionary = Tables.expand_entry({"id": "pair", "units": ["$biome", "$biome"]}, "none", "earth", rng)
		seen[str(pick["units"])] = true
		for unit: String in pick["units"]:
			if unit == "harrier": harriers += 1
	Tables._table = table
	expect.call(seen.size() == 4, "Repeated biome tokens pick independently")
	expect.call(absf(float(harriers) / float(2 * WEIGHT_PICKS) - 0.75) <= 0.75 * WEIGHT_RELATIVE_TOLERANCE, "Biome token weights match the expected share")

static func _test_weights(expect: Callable) -> void:
	var table: Dictionary = Tables.load()
	for tier: int in range(1, 4):
		for element: String in ["fire", "none"]:
			var rng := RandomNumberGenerator.new()
			rng.seed = int(WEIGHT_SEEDS[str(tier)][element])
			var counts: Dictionary = {}
			var total_weight: float = 0.0
			for entry: Dictionary in table["tiers"][str(tier)]:
				if Tables.supports_element(entry, element): total_weight += float(entry["weight"])
			for index: int in range(WEIGHT_PICKS):
				var pick: Dictionary = Tables.pick(tier, element, "earth", [], rng)
				counts[pick["id"]] = int(counts.get(pick["id"], 0)) + 1
			var max_relative_error: float = 0.0
			for entry: Dictionary in table["tiers"][str(tier)]:
				var expected: float = float(entry["weight"]) / total_weight if Tables.supports_element(entry, element) else 0.0
				var actual: float = float(counts.get(entry["id"], 0)) / WEIGHT_PICKS
				var relative_error: float = absf(actual - expected) / expected if expected > 0.0 else 0.0
				max_relative_error = maxf(max_relative_error, relative_error)
				expect.call(relative_error <= WEIGHT_RELATIVE_TOLERANCE and (expected > 0.0 or actual == 0.0), "10k weighted picks within 2%% of expected share: %s/%s" % [entry["id"], element])
			print("Encounter weights tier %d/%s: 10000 picks, max relative error %.3f%%" % [tier, element, max_relative_error * 100.0])

static func _test_history(expect: Callable) -> void:
	for tier: int in range(1, 4):
		var rng := RandomNumberGenerator.new()
		rng.seed = FIXTURE_SEED
		var history: Array = []
		for index: int in range(100):
			var recent: Array = history.slice(maxi(0, history.size() - int(Tables.load()["rules"]["no_repeat_last"])))
			var pick: Dictionary = Tables.pick(tier, "fire", "shadow", history, rng)
			expect.call(not recent.has(pick["id"]), "Pick excludes the last no_repeat_last fights")
			history.append(pick["id"])
	var history_rng := RandomNumberGenerator.new()
	history_rng.seed = FIXTURE_SEED
	var saw_oldest: bool = false
	for index: int in range(100):
		var pick: Dictionary = Tables.pick(1, "fire", "earth", ["t1_crawl_pack", "t1_dust_line", "t1_surgeon"], history_rng)
		expect.call(pick["id"] not in ["t1_dust_line", "t1_surgeon"], "Only the recent history window is excluded")
		if pick["id"] == "t1_crawl_pack": saw_oldest = true
	expect.call(saw_oldest, "Old picks become eligible after leaving the history window")
	var original: Dictionary = Tables.load()
	var tiny: Dictionary = original.duplicate(true)
	tiny["tiers"]["1"] = [original["tiers"]["1"][0], original["tiers"]["1"][1]]
	Tables._table = tiny
	var rng := RandomNumberGenerator.new()
	rng.seed = FIXTURE_SEED
	var fallback: Dictionary = Tables.pick(1, "none", "fire", ["t1_crawl_pack", "t1_dust_line"], rng)
	expect.call(fallback["id"] in ["t1_crawl_pack", "t1_dust_line"], "No-repeat falls back only when every eligible entry is excluded")
	Tables._table = original
	var first := RandomNumberGenerator.new()
	var second := RandomNumberGenerator.new()
	first.seed = FIXTURE_SEED
	second.seed = FIXTURE_SEED
	for index: int in range(100):
		expect.call(Tables.pick(3, "ice", "air", [], first) == Tables.pick(3, "ice", "air", [], second), "Pick and expansion are deterministic per seed")

static func _test_run_history(expect: Callable) -> void:
	var engine := RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, Progression.default_data())
	expect.call(state.get("encounter_history") == [], "New section run starts with empty history")
	var destination: Vector2i = Graph.room(state, Vector2i.ZERO)["connections"][0]["coord"]
	var pending: Dictionary = engine.move_to_pre_battle(state, destination)
	var prepared: Dictionary = engine.prepare_pre_battle_combat(pending)
	var preview: Dictionary = engine.pre_battle_preview_state(pending, prepared)
	expect.call(pending["encounter_history"].is_empty() and preview["encounter_history"].is_empty(), "Preview and preparation do not advance history")
	var started: Dictionary = engine.begin_pre_battle_combat(pending, prepared)
	var direct: Dictionary = engine.move_to_room(state, destination)
	var room: Dictionary = Graph.room(started, destination)
	expect.call(started["encounter_history"] == [room.get("encounter_id")], "Combat Begin appends its stored room encounter id exactly once")
	expect.call(direct["encounter_history"] == started["encounter_history"] and direct["combat_state"] == started["combat_state"], "Direct and prepared entry have identical table composition and history")
	expect.call(engine.begin_pre_battle_combat(started) == started, "Repeated Begin cannot append another pick")
	expect.call(room["biome"] == preload("res://scripts/dragon_boss_library.gd").element_for_boss(str(Graph.section(started, 0)["boss_id"])), "Biome follows the section dragon")
	Progression.set_run_storage_path("user://enc_01_history.save")
	expect.call(Progression.save_run_state(started), "History saves through the real save writer")
	var loaded: Dictionary = engine.repair_loaded_run_state(Progression.load_saved_run())
	expect.call(loaded["encounter_history"] == started["encounter_history"] and Graph.room(loaded, destination)["encounter_id"] == room["encounter_id"], "History and room identity survive save/load")
	var old: Dictionary = state.duplicate(true)
	old.erase("encounter_history")
	expect.call(engine.repair_loaded_run_state(old)["encounter_history"] == [], "Old section saves default to empty history")
	# Actual mystery transaction selects its mystery element before table expansion.
	var mystery: Dictionary = state.duplicate(true)
	var hidden: Dictionary = Graph.room(mystery, destination)
	hidden.merge({"type": "mystery", "element": "none", "mystery_type": "combat", "mystery_element": "lightning"}, true)
	var resolved: Dictionary = engine.move_to_room(mystery, destination)
	expect.call(Graph.room(resolved, destination)["element"] == "lightning" and not resolved["encounter_history"].is_empty(), "Mystery combat uses its resolved element and records a table pick")
	var tutorial: Dictionary = Guided.mark_run_eligible(state)
	var authored: Dictionary = engine.move_to_room(tutorial, destination)
	expect.call(Guided.is_authored(authored["combat_state"]) and authored["encounter_history"].is_empty() and not Graph.room(authored, destination).has("encounter_id"), "Authored tutorial remains outside the table and history")
	for section_index: int in range(6):
		for node: Dictionary in state["rooms"].values():
			if node["type"] != "combat" or int(node["section_index"]) != section_index: continue
			var layout: Dictionary = engine._combat_layout_for_room(node, Vector2i.ZERO, loaded)
			expect.call(layout.get("biome") == preload("res://scripts/dragon_boss_library.gd").element_for_boss(str(Graph.section(state, section_index)["boss_id"])), "Each section uses its own biome")
			expect.call(not loaded["encounter_history"].has(layout["encounter_id"]), "Saved history excludes recent picks across rooms and sections")
			break
	Progression.set_run_storage_path("")

# Baselines captured before implementation on 79b1c6ba, using var_to_bytes.
static func _test_legacy(expect: Callable) -> void:
	var layouts: Array = []
	var pools: Array = []
	var states: Array = []
	var generator := Generator.new()
	for seed: int in range(LEGACY_SEEDS):
		for depth: int in range(1, 5):
			for element: String in ["none", "fire", "earth", "ice", "air", "lightning"]:
				var room: Dictionary = {"coord": Vector2i(depth, 0), "depth": depth, "type": "boss" if depth == 4 else "combat", "element": element, "connections": [{"door_dir": Vector2i(0, -1), "coord": Vector2i(depth + 1, 0)}]}
				layouts.append(generator.generate_room(seed, room, Vector2i(1, 0)))
				var rng := RandomNumberGenerator.new()
				rng.seed = seed
				pools.append(generator._encounter_enemy_types("combat", depth, rng, element))
		for type: String in ["guardian", "boss", "start"]:
			layouts.append(generator.generate_room(seed, {"coord": Vector2i(4, 0), "depth": 4, "type": type, "element":"fire", "boss_id":"vyraketh"}, Vector2i(1, 0)))
		var engine := RunEngineScript.new()
		var state: Dictionary = engine.create_new_run(seed, Progression.default_data(), false)
		states.append(state)
		states.append(engine.move_to_room(state, state["rooms"]["0,0"]["connections"][0]["coord"]))
		Graph._initialize_revision_3(state)
		states.append(state)
		states.append(engine.move_to_room(state, Graph.room(state, Vector2i.ZERO)["connections"][0]["coord"]))
	expect.call(hash_bytes(layouts) == LEGACY_LAYOUT_SHA256, "64-seed legacy room layouts remain byte-identical")
	expect.call(hash_bytes(pools) == LEGACY_POOL_SHA256, "64-seed legacy pool outputs remain byte-identical")
	expect.call(hash_bytes(states) == LEGACY_STATE_SHA256, "64-seed non-section and revision-3 run states remain byte-identical")
	print("Encounter legacy SHA256: layouts=%s pools=%s states=%s" % [hash_bytes(layouts), hash_bytes(pools), hash_bytes(states)])

static func hash_bytes(value: Variant) -> String:
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(var_to_bytes(value))
	return digest.finish().hex_encode()

static func _test_placement(expect: Callable) -> void:
	var generator := EntryGenerator.new()
	var table: Dictionary = Tables.load()
	var generated: int = 0
	var skipped: int = 0
	var largest: int = 0
	var directions: Array[Vector2i]
	directions.assign([Vector2i.ZERO, Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)])
	for tier: String in table["tiers"]:
		for entry: Dictionary in table["tiers"][tier]:
			generator.entry = entry
			for biome: String in Tables.BIOMES:
				for element: String in ["none", "fire", "earth", "ice", "air", "lightning"]:
					if not Tables.supports_element(entry, element):
						skipped += PLACEMENT_SEEDS
						continue
					for seed: int in range(PLACEMENT_SEEDS):
						var room: Dictionary = {"coord": Vector2i(int(tier), 0), "depth": int(tier), "type": "combat", "element": element, "section_index": 0, "section_map_layout_revision": 4, "encounter_biome": biome, "connections": []}
						for direction: Vector2i in directions:
							if direction != Vector2i.ZERO: room["connections"].append({"door_dir": direction, "coord": Vector2i(int(tier) + 1, 0)})
						var layout: Dictionary = generator.generate_room(seed, room, directions[seed % directions.size()])
						# Recreate just the expansion from the room RNG, before placement.
						var rng := RandomNumberGenerator.new()
						rng.seed = generator._room_seed(seed, room["coord"], 101)
						var grid: Array = generator._base_grid(rng)
						generator._apply_template(grid, rng)
						var expansion: Dictionary = Tables.expand_entry(entry, element, biome, rng)
						var expected: Array = generator._objective_adjusted_enemy_types(expansion["units"], layout["objective"], int(tier), rng)
						var actual: Array = []
						var occupied: Dictionary = {}
						var reachable: Dictionary = _reachable(layout)
						var valid: bool = true
						for enemy: Dictionary in layout["enemies"]:
							actual.append(enemy["type"])
							var pos: Vector2i = enemy["pos"]
							valid = valid and not occupied.has(pos) and reachable.has(pos) and PathUtils.manhattan(pos, layout["player_start"]) > Generator.ENEMY_SPAWN_SAFE_RADIUS and layout["grid"][pos.y][pos.x] != Generator.TILE_DOOR
							occupied[pos] = true
						var label: String = "%s/%s/%s/%d" % [entry["id"], biome, element, seed]
						expect.call(actual == expected and actual.size() == int(layout["objective"]["initial_enemy_count"]), "Every expanded unit and objective extra is placed: " + label)
						expect.call(valid, "Spawn tiles are distinct, reachable, outside the player halo and off doors: " + label)
						largest = maxi(largest, actual.size())
						generated += 1
	expect.call(largest >= int(table["rules"]["max_units"]), "Placement sweep exercises the full seven-unit cap and objective extras")
	print("Encounter placement sweep: %d layouts, %d ineligible neutral cases skipped, max %d units including objective extras" % [generated, skipped, largest])

static func _reachable(layout: Dictionary) -> Dictionary:
	var blocked: Dictionary = {}
	for terrain: Dictionary in layout["terrain"]: blocked[terrain["pos"]] = true
	var start: Vector2i = layout["player_start"]
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i]
	queue.append(start)
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction: Vector2i in PathUtils.DIRS_4:
			var next: Vector2i = current + direction
			if visited.has(next) or blocked.has(next) or not PathUtils.is_passable(layout["grid"], next): continue
			visited[next] = true
			queue.append(next)
	return visited

## Unweighted statistics over every legal entry x biome x room element x
## independent biome-group choice. Base HP excludes scaling and objectives.
static func expansion_report() -> Dictionary:
	var table: Dictionary = Tables.load()
	var report: Dictionary = {}
	for tier: String in table["tiers"]:
		var hps: Array[int]
		var counts: Array[int]
		for entry: Dictionary in table["tiers"][tier]:
			for biome: String in Tables.BIOMES:
				for element: String in ["none", "fire", "earth", "ice", "air", "lightning"]:
					if not Tables.supports_element(entry, element): continue
					for expansion: Array in _all_expansions(entry["units"], element, biome):
						var hp: int = 0
						for unit: String in expansion: hp += int(GameData.enemy_def(unit)["max_hp"])
						hps.append(hp)
						counts.append(expansion.size())
		report[tier] = {"expansions": hps.size(), "base_hp": _stats(hps), "units": _stats(counts)}
	return report

static func _all_expansions(units: Array, element: String, biome: String) -> Array:
	var table: Dictionary = Tables.load()
	var variants: Array = [{"units": [], "tokens": []}]
	for unit: String in units:
		var groups: Array = []
		if unit == "$element": groups.append(table["element_regulars"][element])
		elif unit == "$biome":
			for group: Dictionary in table["biome_groups"][biome]: groups.append(group["units"])
		else: groups.append([unit])
		var next: Array = []
		for variant: Dictionary in variants:
			for group: Array in groups:
				var copy: Dictionary = variant.duplicate(true)
				for expanded_unit: String in group:
					copy["units"].append(expanded_unit)
					copy["tokens"].append(unit.begins_with("$"))
				next.append(copy)
		variants = next
	var result: Array = []
	for variant: Dictionary in variants:
		for index: int in range(variant["units"].size() - 1, -1, -1):
			if variant["units"].size() <= int(table["rules"]["max_units"]): break
			if not variant["tokens"][index]:
				variant["units"].remove_at(index)
				variant["tokens"].remove_at(index)
		result.append(variant["units"])
	return result

static func _stats(values: Array[int]) -> Dictionary:
	var total: int = 0
	for value: int in values: total += value
	return {"min": values.min(), "mean": float(total) / values.size(), "max": values.max()}

# Native probes record actual body draw submissions. This subclass lives only
# in tests; production boards and renderer preparation keep their normal API.
class DrawCheckedBoard:
	extends "res://scripts/combat_board_view.gd"
	var drawn_unit_keys: Dictionary = {}
	func _draw_unit_body(unit: Dictionary) -> void:
		super._draw_unit_body(unit)
		if _texture_for_unit(unit) == null or not _unit_texture_draw_rect(unit, _unit_center(unit)).has_area(): return
		var owner: Node = _render_instrumentation_owner if is_instance_valid(_render_instrumentation_owner) else self
		owner.drawn_unit_keys[str(unit["key"])] = true

static func renderer_readiness_errors(board: Node, state: Dictionary) -> Array[String]:
	var errors: Array[String]
	var units: Dictionary = {}
	for unit: Dictionary in board.call("_visible_units"): units[str(unit["key"])] = unit
	var required: Array[String]
	required.append("player")
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: required.append("enemy_%d" % int(enemy["id"]))
	var layers: Dictionary = board.get("_scene_render_layers_by_tile")
	for key: String in required:
		if not units.has(key):
			errors.append(key + " missing from visible roster")
			continue
		var unit: Dictionary = units[key]
		if board.call("_texture_for_unit", unit) == null: errors.append(key + " texture not prepared")
		var renderer: Node = board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer):
			var rigs: Dictionary = renderer.get("rigs")
			if rigs.size() != 2: errors.append(key + " cutout facings not prepared")
			for rig: Node in rigs.values():
				if not (rig.get("load_errors") as PackedStringArray).is_empty() or (rig.get("bones") as Dictionary).is_empty(): errors.append(key + " rig preparation failed")
		var tile: Vector2i = board.call("_scene_render_tile_for_unit", unit)
		var layer: Node = layers.get(tile)
		if not is_instance_valid(layer):
			errors.append(key + " draw layer missing")
			continue
		# _draw_scene_tile_render_layer returns immediately for empty state.
		if (layer.get("combat_state") as Dictionary).is_empty(): errors.append(key + " draw layer has empty combat_state")
		var found: bool = false
		for submitted: Dictionary in (layer.get("_units_by_draw_tile_cache") as Dictionary).get(tile, []):
			if str(submitted["key"]) == key: found = true
		if not found: errors.append(key + " absent from its retained draw tile")
	return errors

static func run_renderer_preparation(tree: SceneTree, expect: Callable) -> void:
	var Board = preload("res://scripts/combat_board_view.gd")
	var Combat = preload("res://scripts/combat_engine.gd")
	var Preparation = preload("res://scripts/encounter_asset_preparation.gd")
	var Assets = preload("res://scripts/asset_loader.gd")
	var RigData = preload("res://scripts/protagonist_cutout/rig_data.gd")
	var Biomes = preload("res://scripts/biome_library.gd")
	var Bosses = preload("res://scripts/dragon_boss_library.gd")
	var checked_groups: int = 0
	var checked_enemies: int = 0
	for biome: String in Tables.BIOMES:
		for group: Dictionary in Tables.load()["biome_groups"][biome]:
			var generator := EntryGenerator.new()
			generator.entry = {"id": "renderer_fixture_" + str(group["id"]), "units": group["units"]}
			var room: Dictionary = {"coord": Vector2i(2, 0), "depth": 2, "type": "combat", "element": "none", "section_index": 0, "section_map_layout_revision": 4, "encounter_biome": biome, "objective_onboarding": true}
			var layout: Dictionary = generator.generate_room(FIXTURE_SEED, room, Vector2i.ZERO)
			var state: Dictionary = Combat.new().create_combat(FIXTURE_SEED, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["pale_spark"]})
			expect.call(state["room_type"] == "combat" and state["guardian_id"] == "" and state["boss_id"] == "", "Renderer fixture is an ordinary combat: " + str(group["id"]))
			var board: Control = Board.new()
			board.size = Vector2(1920, 1080)
			tree.root.add_child(board)
			var manifest: Dictionary = board.call("unit_rig_preparation_manifest", state)
			var present: Callable = _preparation_frame.bind(tree)
			var alive: Callable = func() -> bool: return is_instance_valid(board) and board.is_inside_tree()
			var prepared: Variant = await Assets.prepare_cpu_value_for(tree.root, Preparation._prepare_sources.bind(manifest["sources"]), present, alive)
			expect.call(prepared is Array, "Regular-room CPU renderer preparation completes: " + str(group["id"]))
			var holds: Array[RefCounted]
			if prepared is Array:
				for entry: Dictionary in prepared:
					var source: RefCounted = RigData.publish_owned_source(entry["path"], entry["data"])
					expect.call(source != null, "Prepared rig source publishes: " + str(entry["path"]))
					if source != null:
						holds.append(source)
						manifest["textures"].merge(RigData.source_texture_manifest(source, entry["path"]))
			await Assets.prepare_textures_for(tree.root, manifest["textures"], present, alive)
			board.call("prepare_unit_assets_for_state", state)
			var biome_id: String = ""
			for boss_id: String in Biomes.data()["section_biomes"]:
				if Bosses.element_for_boss(boss_id) == biome: biome_id = str(Biomes.data()["section_biomes"][boss_id])
			expect.call(not biome_id.is_empty(), "Regular renderer fixture resolves the real section biome")
			# No Umbra filter in this test presentation: every group unit must draw.
			board.call("set_combat_state", state, [], [], state["player"]["pos"], "", "", {}, {}, {"biome_id": biome_id, "reduced_motion": true})
			await tree.process_frame
			var errors: Array[String] = renderer_readiness_errors(board, state)
			expect.call(errors.is_empty(), "Every regular-room renderer and retained draw layer is ready for %s: %s" % [group["id"], "; ".join(errors)])
			print("Encounter regular renderer group %s: %d enemies + hero, %d readiness errors" % [group["id"], state["enemies"].size(), errors.size()])
			checked_groups += 1
			checked_enemies += state["enemies"].size()
			board.queue_free()
			await tree.process_frame
	print("Encounter regular renderer preparation: %d groups, %d enemies + %d heroes checked" % [checked_groups, checked_enemies, checked_groups])

static func _preparation_frame(tree: SceneTree) -> void:
	await tree.process_frame
