extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ElementData = preload("res://scripts/element_data.gd")
const ElementalIntensityHudArt = preload("res://scripts/elemental_intensity_hud_art.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const OUTPUT_DIR: String = "user://probes/hanging_elemental_intensity_hud"
const PRODUCTION_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const RELIC_IDS: Array[String] = [
	"iron_lung",
	"ember_lens",
	"pilgrim_boots",
	"mirror_shard",
	"coffin_nails",
	"reinforced_shield",
	"iron_buckler",
	"flint_edge",
]
const SKILL_IDS: Array[String] = ["quick_wits", "borrowed_time", "measured_breath", "carry_the_guard"]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(PRODUCTION_VIEWPORT)
	root.content_scale_size = PRODUCTION_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.size = PRODUCTION_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://hanging_intensity_progression.json")
	ProgressionStore.set_run_storage_path("user://hanging_intensity_run.save")
	ProgressionStore.clear_saved_run()
	_assert_glow_curve()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load for the hanging intensity HUD proof")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	instance.call("_close_dialogue")

	await _load_fixture(instance, {
		ElementData.FIRE: 0,
		ElementData.ICE: 1,
		ElementData.LIGHTNING: 0,
		ElementData.AIR: 0,
		ElementData.EARTH: 0,
	}, false)
	await _assert_hud_contract(instance, false)
	await _save_root_screenshot("%s/concept_ice_one_1920x1080.png" % OUTPUT_DIR)

	await _load_fixture(instance, {
		ElementData.FIRE: 1,
		ElementData.ICE: 2,
		ElementData.LIGHTNING: 3,
		ElementData.AIR: 4,
		ElementData.EARTH: 6,
	}, true)
	await _assert_hud_contract(instance, true)
	await _save_root_screenshot("%s/crowded_header_glow_ramp_1920x1080.png" % OUTPUT_DIR)

	print("HANGING ELEMENTAL INTENSITY HUD PROBE: PASS")
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	instance.queue_free()
	await process_frame
	quit(0)

func _load_fixture(instance: Node, intensities: Dictionary, crowded: bool) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var layout: Dictionary = _room_layout()
	var relics: Array[String] = []
	if crowded:
		relics.append_array(RELIC_IDS)
	var combat_state: Dictionary = combat.create_combat(92845 if crowded else 15126, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"],
		"relics": relics,
		"hand_size": 5,
		"heal_bonus": 0,
	})
	combat_state["name"] = "Hanging Ward Gallery"
	combat_state["elemental_intensity"] = intensities.duplicate(true)
	combat_state["relics"] = relics.duplicate()
	combat_state["skill_ids"] = SKILL_IDS.duplicate() if crowded else []
	combat_state["defiance_capacity"] = 3 if crowded else 0
	combat_state["defiance_remaining"] = 2 if crowded else 0
	var umbra: Dictionary = (combat_state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = "heart" if crowded else "clear"
	umbra["stage_reduction"] = 0
	combat_state["umbra"] = umbra
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state.duplicate(true)
	run_state["relics"] = relics.duplicate()
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	instance.call("_refresh_relic_bar")
	instance.call("_layout_header_hud")
	instance.call("_layout_elemental_intensity_bar")
	await _settle_ui()

func _assert_hud_contract(instance: Node, crowded: bool) -> void:
	_assert(root.content_scale_size == PRODUCTION_VIEWPORT, "HUD proof must use the production 1920x1080 logical canvas")
	var bar: Control = instance.get("_intensity_bar") as Control
	_assert(bar != null and bar.visible, "Combat should show the hanging elemental intensity cluster")
	_assert(bar.size == ElementalIntensityHudArt.CLUSTER_SIZE, "Hanging cluster should keep its compact authored size")
	var intensity_badges: Dictionary = instance.get("_intensity_badges") as Dictionary
	_assert(intensity_badges.size() == 5, "Hanging cluster should expose exactly five element hit regions")
	var labels: Dictionary = instance.get("_intensity_labels") as Dictionary
	var glows: Dictionary = instance.get("_intensity_glows") as Dictionary
	var charm_paths: Dictionary = {}
	for element_id: String in ElementData.all_elements():
		var badge: PanelContainer = intensity_badges.get(element_id, null)
		var label: Label = labels.get(element_id, null)
		var glow: TextureRect = glows.get(element_id, null)
		var value: int = int((instance.get("_combat_state") as Dictionary).get("elemental_intensity", {}).get(element_id, 0))
		var path: String = str(badge.get_meta("charm_art_path", "")) if badge != null else ""
		_assert(badge != null and badge.get_theme_stylebox("panel") is StyleBoxEmpty, "%s should use an invisible tooltip host rather than a generic box" % element_id)
		_assert(not path.is_empty() and FileAccess.file_exists(path), "%s should use a real authored raster charm" % element_id)
		_assert(not charm_paths.has(path), "%s should have a silhouette-specific charm asset" % element_id)
		charm_paths[path] = true
		_assert(badge.find_child("AuthoredCharmArt", true, false) is TextureRect, "%s should render its authored charm art" % element_id)
		_assert(badge.find_child("AuthoredNumberPlacard", true, false) is TextureRect, "%s should render the separate authored number placard" % element_id)
		_assert(label != null and label.text == str(value), "%s placard should show the live intensity value" % element_id)
		_assert(badge.tooltip_text == "The intensity of %s in the room.\n%s effects are stronger when this is higher." % [ElementData.name(element_id), ElementData.name(element_id)], "%s should preserve its concise hover explanation" % element_id)
		_assert(glow != null and glow.visible == (value > 0), "%s glow visibility should begin exactly at intensity one" % element_id)
		_assert(glow != null and is_equal_approx(float(glow.get_meta("glow_strength", -1.0)), ElementalIntensityHudArt.glow_strength(value)), "%s glow should track the authored intensity ramp" % element_id)
	var rig: TextureRect = bar.find_child("AuthoredRailAndChains", false, false) as TextureRect
	_assert(rig != null and rig.size.x == bar.size.x and rig.get_parent() == bar, "The cluster should render one unclipped full-width authored rail-and-chains layer")
	var fire_badge: Control = intensity_badges.get(ElementData.FIRE, null)
	var ice_badge: Control = intensity_badges.get(ElementData.ICE, null)
	var lightning_badge: Control = intensity_badges.get(ElementData.LIGHTNING, null)
	var air_badge: Control = intensity_badges.get(ElementData.AIR, null)
	var earth_badge: Control = intensity_badges.get(ElementData.EARTH, null)
	_assert(fire_badge.position.y == ice_badge.position.y and ice_badge.position.y == lightning_badge.position.y, "Fire, Ice, and Lightning should form the upper hanging tier")
	_assert(air_badge.position.y == earth_badge.position.y and air_badge.position.y > fire_badge.position.y, "Air and Earth should hang on the lower tier")
	var board_bounds: Rect2 = instance.call("_contextual_combat_rendered_board_bounds") as Rect2
	var overlap: Rect2 = bar.get_global_rect().intersection(board_bounds)
	var overlap_ratio: float = overlap.get_area() / maxf(1.0, board_bounds.get_area())
	_assert(overlap_ratio <= 0.012, "Hanging cluster should cover almost none of the default board (ratio %.4f, bar=%s, board=%s)" % [overlap_ratio, bar.get_global_rect(), board_bounds])
	await _assert_hover_ownership(intensity_badges)
	if crowded:
		var relic_bar: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/RelicBar") as Control
		var umbra_subtitle: Label = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/UmbraSubtitle") as Label
		_assert(umbra_subtitle != null and umbra_subtitle.visible and umbra_subtitle.text == "Heart Umbra", "Crowded proof should include the live Umbra header line")
		_assert(instance.get("_skill_sigil") is Button and (instance.get("_skill_sigil") as Button).visible, "Crowded proof should include the Abilities header entry")
		_assert(relic_bar != null and relic_bar.visible and relic_bar.get_child_count() >= RELIC_IDS.size(), "Crowded proof should include Defiance, Abilities, and all eight relics")
		_assert(bar.global_position.y >= float(instance.call("_relic_bar_visible_bottom_y")), "Hanging cluster should remain below every populated header line")

func _assert_hover_ownership(intensity_badges: Dictionary) -> void:
	var viewport: Viewport = root.get_viewport()
	for element_id: String in ElementData.all_elements():
		var badge: Control = intensity_badges.get(element_id, null)
		var pointer_position: Vector2 = badge.get_global_transform_with_canvas() * ElementalIntensityHudArt.POINTER_HIT_CENTER
		var logical_owners: Array[String] = []
		for candidate_id: String in ElementData.all_elements():
			var candidate: Control = intensity_badges.get(candidate_id, null)
			var candidate_local_position: Vector2 = candidate.get_global_transform_with_canvas().affine_inverse() * pointer_position if candidate != null else Vector2.ZERO
			if candidate != null and ElementalIntensityHudArt.pointer_hit_test(candidate_local_position):
				logical_owners.append(candidate_id)
		_assert(logical_owners == [element_id], "%s hover center should belong to exactly that charm, got %s" % [element_id, logical_owners])
		var motion := InputEventMouseMotion.new()
		motion.position = pointer_position
		motion.global_position = pointer_position
		viewport.push_input(motion, true)
		await process_frame
		_assert(viewport.gui_get_hovered_control() == badge, "%s charm should own its actual pointer hover" % element_id)
	var clear_motion := InputEventMouseMotion.new()
	clear_motion.position = Vector2(PRODUCTION_VIEWPORT) * 0.5
	clear_motion.global_position = clear_motion.position
	viewport.push_input(clear_motion, true)
	await process_frame

func _assert_glow_curve() -> void:
	_assert(ElementalIntensityHudArt.glow_strength(0) == 0.0, "Intensity zero should have no glow")
	_assert(ElementalIntensityHudArt.glow_strength(1) > 0.0 and ElementalIntensityHudArt.glow_strength(1) <= 0.16, "Intensity one glow should be present but mild")
	var previous_strength: float = 0.0
	var previous_spread: float = 0.0
	for value: int in range(1, 7):
		var strength: float = ElementalIntensityHudArt.glow_strength(value)
		var spread: float = ElementalIntensityHudArt.glow_spread(value)
		_assert(strength > previous_strength and spread > previous_spread, "Glow strength and spread should grow at intensity %d" % value)
		previous_strength = strength
		previous_spread = spread

func _room_layout() -> Dictionary:
	return {
		"name": "Hanging Ward Gallery",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{"type": "crawler", "pos": Vector2i(5, 3)}],
		"traps": [],
		"terrain": [],
		"loot": [],
	}

func _grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	_assert(image != null, "Hanging intensity HUD proof should capture a renderer image")
	if image == null:
		return
	if image.get_size() != PRODUCTION_VIEWPORT:
		image.resize(PRODUCTION_VIEWPORT.x, PRODUCTION_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	_assert(image.save_png(ProjectSettings.globalize_path(output_path)) == OK, "Could not save %s" % output_path)

func _clear_probe_output(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
