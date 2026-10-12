extends RefCounted

const Biomes = preload("res://scripts/biome_library.gd")
const Lighting = preload("res://scripts/combat_lighting_profiles.gd")
const Atmosphere = preload("res://scripts/combat_atmosphere.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Treatment = preload("res://scripts/combat_art_treatment.gd")
const ROOM_TYPES: PackedStringArray = ["combat", "guardian", "boss", "campfire", "treasure", "scavenger", "graftwright", "event", "start"]

static func run(expect: Callable) -> void:
	var data: Dictionary = Biomes.data()
	expect.call(data["version"] == 1 and Biomes.ids().size() == 7, "Biome registry version and seven domains")
	expect.call(Biomes.default_biome() == "stone", "Legacy default is stone")
	var sections: Array[Dictionary]
	for boss: String in data["section_biomes"]:
		sections.append({"boss_id": boss})
	var state: Dictionary = {"section_map_version": 1, "map_sections": sections}
	var before: Dictionary = state.duplicate(true)
	for index: int in range(sections.size()):
		var boss: String = sections[index]["boss_id"]
		for type: String in ROOM_TYPES:
			var room: Dictionary = {"section_index": index, "type": type}
			expect.call(Biomes.biome_for_run(state, room) == data["section_biomes"][boss], "Every room and entry threshold follows " + boss + "/" + type)
	expect.call(state == before, "Biome derivation never mutates run state")
	expect.call(Biomes.biome_for_run({}, {"section_index": 0}) == "stone", "Legacy run uses stone")
	expect.call(Biomes.biome_for_run(state, {}) == "stone", "Non-section room uses stone")
	expect.call(Biomes.biome_for_run(state, {"section_index": -1}) == "stone", "Invalid section uses stone")
	for id: String in Biomes.ids():
		var entry: Dictionary = Biomes.definition(id)
		expect.call(entry["light_color"].size() == 4 and entry["lighting"]["tint"].size() == 3, "Biome color dimensions: " + id)
		expect.call(float(entry["lighting"]["ambient_scale"]) > 0.0, "Positive ambient scale: " + id)
		expect.call(entry["light_flicker"] in ["flame", "glow", "spark"], "Known idle kind: " + id)
		var preset: Dictionary = Biomes.mote_preset(entry["atmosphere"]["motes"])
		expect.call(preset.has_all(["color", "count", "direction", "speed", "lifetime", "spread"]) and int(preset["count"]) > 0 and float(preset["lifetime"]) > 0.0, "Complete mote preset: " + id)
		expect.call(preset["direction"].size() == 2 and preset["speed"].size() == 2 and preset["color"].size() == 4, "Mote vector dimensions: " + id)
		var floors: Array[Texture2D] = Biomes.floor_textures(id)
		expect.call(floors.size() == 4 and not floors.has(null), "Four available floors: " + id)
		expect.call(Biomes.pillar_texture(id) != null, "Available pillar: " + id)
		for side: String in ["left", "right"]:
			expect.call(Biomes.light_texture(id, side) != null and Biomes.light_idle_frames(id, side).size() == 16, "Static light and sixteen idle frames: " + id + "/" + side)
		for profile: String in Lighting.ids():
			var original: Dictionary = Lighting.resolved_definition(profile, 3.0)
			var composed: Dictionary = Lighting.with_biome(original, id)
			if id == "stone":
				expect.call(composed == original, "Stone lighting remains pixel-identical: " + profile)
			else:
				var tint: Array = entry["lighting"]["tint"]
				expect.call((composed["tint"] as Vector3).is_equal_approx((original["tint"] as Vector3) * Vector3(tint[0], tint[1], tint[2])), "Biome tint multiplication: " + id + "/" + profile)
				expect.call(is_equal_approx(composed["ambient"], original["ambient"] * entry["lighting"]["ambient_scale"]), "Biome ambient multiplication: " + id + "/" + profile)
			composed["tint"] = original["tint"]
			composed["ambient"] = original["ambient"]
			expect.call(composed == original, "All other lighting profile fields unchanged")
	var legacy: CPUParticles2D = Atmosphere.build_motes(Atmosphere.MOTE_COUNT)
	var embers: CPUParticles2D = Atmosphere.build_preset_motes("embers")
	for property: String in ["amount", "lifetime", "preprocess", "direction", "spread", "gravity", "initial_velocity_min", "initial_velocity_max", "angular_velocity_min", "angular_velocity_max", "scale_amount_min", "scale_amount_max", "color"]:
		expect.call(legacy.get(property) == embers.get(property), "Embers exactly retains legacy " + property)
	expect.call(legacy.color_ramp.colors == embers.color_ramp.colors and legacy.color_ramp.offsets == embers.color_ramp.offsets, "Embers retains exact legacy ramp")
	legacy.free()
	embers.free()
	for name: String in data["mote_presets"]:
		var mote: CPUParticles2D = Atmosphere.build_preset_motes(name)
		var preset: Dictionary = data["mote_presets"][name]
		expect.call(mote.amount == preset["count"] and mote.lifetime == preset["lifetime"] and mote.spread == preset["spread"], "Mote scalar data: " + name)
		var expected_color: Color = Color.WHITE if str(preset.get("color_ramp", "")) == "legacy" else Biomes.color(preset["color"])
		expect.call(mote.direction == Vector2(preset["direction"][0], preset["direction"][1]) and mote.color == expected_color, "Mote direction and color data: " + name)
		expect.call(mote.initial_velocity_min == preset["speed"][0] and mote.initial_velocity_max == preset["speed"][1], "Mote speed data: " + name)
		mote.free()
	_test_fallback(expect)
	_test_board_dispatch(expect)
	_test_data_driven_legacy_defaults(expect)

static func _test_data_driven_legacy_defaults(expect: Callable) -> void:
	# Borrow approved Iskaldra/snow values to catch name-based stone/embers
	# bypasses. Mutations are private test fixtures and are restored afterward.
	var saved: Dictionary = Biomes._data.duplicate(true)
	Biomes._data["biomes"]["stone"]["lighting"] = Biomes.lighting("iskaldra")
	var look: Dictionary = Lighting.definition("warm")
	expect.call(Lighting.with_biome(look, "stone") == Lighting.with_biome(look, "iskaldra"), "Stone lighting reads the authored data, without an ID bypass")
	var fixture: Dictionary = Biomes.mote_preset("snow")
	fixture["color_ramp"] = "legacy"
	Biomes._data["mote_presets"]["embers"] = fixture
	var motes: CPUParticles2D = Atmosphere.build_preset_motes("embers")
	var legacy: CPUParticles2D = Atmosphere.build_motes(Atmosphere.MOTE_COUNT)
	expect.call(motes.amount == fixture["count"] and motes.lifetime == fixture["lifetime"] and motes.preprocess == fixture["lifetime"], "Legacy-ramp preset still reads count and lifetime data")
	expect.call(motes.direction == Vector2(fixture["direction"][0], fixture["direction"][1]) and motes.spread == fixture["spread"], "Legacy-ramp preset still reads direction and spread data")
	expect.call(motes.initial_velocity_min == fixture["speed"][0] and motes.initial_velocity_max == fixture["speed"][1], "Legacy-ramp preset still reads speed data")
	expect.call(motes.color == Color.WHITE and motes.color_ramp.colors == legacy.color_ramp.colors and motes.color_ramp.offsets == legacy.color_ramp.offsets, "Legacy marker preserves exact authored ramp and white modulation")
	motes.free()
	legacy.free()
	Biomes._data = saved

static func _test_fallback(expect: Callable) -> void:
	var saved: Dictionary = Biomes._data.duplicate(true)
	var entry: Dictionary = Biomes.definition("tharokh")
	entry["art_dir"] = "user://biome_partial"
	DirAccess.make_dir_recursive_absolute("user://biome_partial")
	var approved: Image = Image.load_from_file("res://assets/art/biomes/tharokh/floor_02.png")
	approved.save_png("user://biome_partial/floor_02.png")
	Biomes._data["biomes"]["test_partial"] = entry
	var floors: Array[Texture2D] = Biomes.floor_textures("test_partial")
	expect.call(floors[0] != Biomes.floor_textures("stone")[0], "Present asset remains biome-specific when its siblings are missing")
	for index: int in range(1, 4):
		expect.call(floors[index] == Biomes.floor_textures("stone")[index], "Missing floor falls back per asset")
	expect.call(Biomes.pillar_texture("test_partial") == Biomes.pillar_texture("stone"), "Missing pillar falls back")
	for side: String in ["left", "right"]:
		expect.call(Biomes.light_texture("test_partial", side) == Biomes.light_texture("stone", side), "Missing static light falls back")
		expect.call(Biomes.light_idle_sheet("test_partial", side) == Biomes.light_idle_sheet("stone", side), "Missing sheet falls back")
	var log_count: int = Biomes._missing_logged.size()
	Biomes.pillar_texture("test_partial")
	expect.call(Biomes._missing_logged.size() == log_count, "Missing asset logs once")
	Biomes._data = saved

static func _test_board_dispatch(expect: Callable) -> void:
	var board := Board.new()
	board._load_base_floor_assets()
	board._load_board_prop_assets()
	board._load_pillar_idle_assets()
	var stone_props: Dictionary = board._prop_textures.duplicate()
	var grid: Array = [["stone", "stone", "pillar"], ["stone", "stone", "stone"]]
	var state: Dictionary = {"grid": grid, "room_coord": Vector2i(1, 2)}
	board.set_combat_state(state)
	var choices: Dictionary = board._floor_variant_by_tile.duplicate()
	for id: String in Biomes.ids():
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"biome_id": id})
		expect.call(board._floor_variant_by_tile == choices, "Biome keeps deterministic per-tile variant choice: " + id)
		expect.call(board._floor_texture_for_tile("stone", Vector2i(0, 0)) == Biomes.floor_textures(id)[int(choices.get(Vector2i(0, 0), 0))], "Board dispatches floor: " + id)
		expect.call(board._prop_textures["column_torch_left"] == Biomes.light_texture(id, "left"), "Board dispatches light: " + id)
		expect.call(board._biome_light_color == Biomes.light_color(id), "Board dispatches pool color: " + id)
		for key: String in ["wall", "wall_row", "wall_col", "door", "door_row", "door_col"]:
			expect.call(board._prop_textures[key] == stone_props[key], "Unchanged wall/door: " + key)
	board.set_combat_state(state)
	expect.call(board._biome_id == "stone" and board._prop_textures["pillar"] == stone_props["pillar"], "Returning to legacy resets the biome")
	board.free()

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var atmosphere := Atmosphere.new()
	tree.root.add_child(atmosphere)
	atmosphere.set_motion_enabled(false)
	for id: String in Biomes.ids():
		atmosphere.set_biome(id)
		expect.call(not atmosphere._motes.visible and not atmosphere._motes.emitting, "Reduced motion disables motes in " + id)
		expect.call(atmosphere._material.get_shader_parameter("pool_color") == Biomes.color(Biomes.atmosphere(id)["pool_color"]), "Atmosphere uploads biome pool: " + id)
	atmosphere.set_biome("stone")
	expect.call(atmosphere._material.get_shader_parameter("pool_color") == Color(1.0, 0.60, 0.28, 1.0), "Stone restores exact legacy pool")
	var saved: Dictionary = Biomes._data.duplicate(true)
	Biomes._data["biomes"]["stone"]["atmosphere"]["pool_color"] = Biomes.atmosphere("iskaldra")["pool_color"]
	atmosphere.set_biome("iskaldra")
	atmosphere.set_biome("stone")
	expect.call(atmosphere._material.get_shader_parameter("pool_color") == Biomes.color(Biomes.atmosphere("iskaldra")["pool_color"]), "Stone pool reads authored data, without an ID bypass")
	Biomes._data = saved
	atmosphere.queue_free()
	var treatment := Treatment.new()
	var sources: Array[Dictionary]
	sources.append({"point": Vector2(20, 20), "height": 30.0, "radius": 80.0, "color": Color(1, 0.68, 0.36, 0.80)})
	for profile: String in Lighting.ids():
		treatment.set_preset(profile)
		for id: String in Biomes.ids():
			treatment.configure(sources, "ice", true)
			Lighting.apply_biome(treatment, id)
			var look: Dictionary = Lighting.with_biome(Lighting.resolved_definition(profile, 1.0), id)
			for material: ShaderMaterial in [treatment.material, treatment.floor_material, treatment.cache_bake_material]:
				expect.call(material.get_shader_parameter("art_look_tint") == look["tint"] and is_equal_approx(material.get_shader_parameter("art_ambient_level"), look["ambient"]), "All three materials compose biome: " + id + "/" + profile)
			treatment.configure(sources, "ice", true)
			Lighting.apply_biome(treatment, "stone")
			expect.call(treatment._parameters["art_look_tint"] == Lighting.resolved_definition(profile, 1.0)["tint"], "No cumulative biome lighting")
