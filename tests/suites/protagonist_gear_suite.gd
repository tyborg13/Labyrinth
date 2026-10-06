extends RefCounted

const Gear = preload("res://scripts/protagonist_cutout/gear_visuals.gd")
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")
const Renderer = preload("res://scripts/protagonist_cutout/renderer.gd")
const Baker = preload("res://scripts/protagonist_cutout/gear_rest_baker.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const EnemyRig = preload("res://scripts/crawler_cutout/rig.gd")
const EnemyMotion = preload("res://scripts/crawler_cutout/motion.gd")
const Reaction = preload("res://scripts/cutout_reaction_playback.gd")
const L1: Dictionary = {"weapon": "war_maul", "offhand": "ward_kite", "armor": "undertaker_plate", "boots": "ironshod_sabatons", "trinket": "crown_of_thorns"}
const L2: Dictionary = {"weapon": "sawtooth_knife", "offhand": "parrying_dagger", "armor": "cinderweave_mail", "boots": "emberstriders", "trinket": "war_dancer_sash"}
const L3: Dictionary = {"weapon": "training_sword", "offhand": "ward_kite", "armor": "patched_cloak", "boots": "skirmisher_boots", "trinket": "war_dancer_sash"}
const L4: Dictionary = {"weapon": "grave_greatsword", "offhand": "tower_shield", "armor": "quarrymail", "boots": "worldroot_greaves", "trinket": "bone_dice"}

static func run(tree: SceneTree, expect: Callable) -> void:
	_check_registry(expect)
	_check_boot_shins(expect)
	await preload("res://tests/suites/protagonist_gear_motion_suite.gd").run(tree, expect)
	expect.call(Gear.resolve({}) == {"weapon": "training_sword", "offhand": "", "armor": "patched_cloak", "boots": "skirmisher_boots", "trinket": ""}, "Missing optional slots are bare; the body uses defaults")
	expect.call(Gear.resolve({"weapon": "", "offhand": "", "armor": "", "boots": "", "trinket": ""}) == Gear.resolve({}), "Empty slots follow the same fallback rules")
	expect.call(Gear.resolve(L4) == L4, "Every full-pass item draws its own registered art")
	var unknown: Dictionary = {"weapon": "not_an_item", "offhand": "not_an_item", "armor": "not_an_item", "boots": "not_an_item", "trinket": "not_an_item"}
	expect.call(Gear.resolve(unknown) == Gear.DEFAULTS, "An unregistered item falls back to its slot default visual")
	expect.call(Gear.resolve({"weapon": "ward_kite"})["weapon"] == "training_sword", "An item in the wrong slot also falls back")
	var arsenal: Dictionary = preload("res://scripts/visual_equipment.gd").native_slot_loadout({"weapon": "war_maul", "offhand": "tower_shield", "trinket": "grave_greatsword"})
	expect.call(arsenal == {"weapon": "war_maul", "offhand": "tower_shield"} and Gear.resolve(arsenal)["trinket"] == "", "An Open Arsenal trinket from another slot draws nothing")
	expect.call(Gear.resolve(arsenal)["offhand"] == "tower_shield", "A registered full-pass offhand retains its art through Open Arsenal filtering")
	expect.call(Gear.resolve({"weapon": "unregistered_weapon", "offhand": "unregistered_offhand"})["weapon"] == "training_sword" and Gear.resolve({"offhand": "unregistered_offhand"})["offhand"] == "splintered_shield", "Unregistered items still fall back to their slot defaults")
	expect.call(Gear.weapon_motion(L1) == "heavy" and Gear.weapon_motion(L2) == "stab" and Gear.weapon_motion({}) == "sword", "Weapon motion contract is data driven")
	expect.call(not Gear.is_two_handed(L1) and Gear.offhand_kind(L1) == "shield" and Gear.offhand_kind(L2) == "hand" and Gear.offhand_kind(Gear.DEFAULTS) == "shield", "One-handed and held-kind contracts")
	for facing: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = facing
		tree.root.add_child(rig)
		expect.call(rig.load_rig(), "Bare protagonist rig loads: " + facing)
		var bases: Dictionary = rig._gear_base_parts.duplicate(true)
		for loadout: Dictionary in [Gear.DEFAULTS, L1, L2, L3, L4]:
			rig.apply_gear(Gear.ops_for_facing(loadout, facing))
			if loadout == L1:
				expect.call(_offhand(rig) != null, "One-handed maul retains its offhand in " + facing)
			rig.apply_gear({})
			expect.call(rig._gear_attachments.is_empty(), "Reset frees every attachment")
			for name: String in bases:
				var base: Dictionary = bases[name]
				var node: Node2D = base["node"]
				expect.call(node.get("texture") == base["texture"] and node.position == base["position"], "Reset restores exact texture and position: " + facing + "/" + name)
		_check_boot_replacements(rig, expect)
		_check_visibility(rig, expect)
		rig.free()
	_check_enemy(tree, expect)
	var renderer := Renderer.new()
	tree.root.add_child(renderer)
	await tree.process_frame
	renderer.set_process(false)
	renderer.set_gear(L2)
	var revision: int = renderer._gear_revision
	var pose: Array = renderer._pose_signature.duplicate()
	renderer.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	renderer.set_gear(L2.duplicate())
	expect.call(renderer._gear_revision == revision and renderer._pose_signature == pose and renderer.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "Unchanged gear signature neither reapplies gear nor requests another render")
	expect.call(renderer.snapshot()["gear"] == Gear.signature(L2) and renderer.weapon_motion() == "stab" and renderer.offhand_kind() == "hand", "Renderer exposes the resolved gear and Unit 2 API")
	await _check_bake(tree, renderer, expect)
	renderer.free()
	await _check_board(tree, expect)

static func _check_registry(expect: Callable) -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Gear.PATH))
	Gear.resolve({})
	expect.call(Gear._items.size() == raw["items"].size(), "Every authored registry entry validates")
	for id: String in raw["items"]:
		for facing: String in raw["items"][id]["facings"]:
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Gear.BASE.path_join(facing + ".json")))
			for kind: String in ["replace", "attach"]:
				for op: Dictionary in raw["items"][id]["facings"][facing].get(kind, []):
					var path: String = Gear.BASE.path_join(op["file"])
					var texture: Texture2D = AssetLoader.load_texture_source_first(path)
					expect.call(FileAccess.file_exists(path) and texture != null, "Registry paint exists and loads: " + path)
					if kind == "replace":
						for mesh: Dictionary in layout.get("joint_meshes", []):
							if mesh.get("replaces_part") == op["part"]:
								expect.call(texture.get_size() == AssetLoader.load_texture_source_first(mesh["file"]).get_size(), "Mesh replacement retains original crop: " + path)
	expect.call(not Gear._valid_entry({"slot": "weapon", "facings": {}, "hands": 3, "motion": "sword"}, {}), "Broken registry schema is rejected")
	expect.call(Gear.ops_for_facing(L1, "front")["weapon_grip"] == raw["items"]["war_maul"]["facings"]["front"]["weapon_grip"], "Weapon grip landmarks pass through unchanged")

static func _check_boot_shins(expect: Callable) -> void:
	expect.call(Gear.REPLACE_PARTS["boots"] == ["foot_r", "foot_l", "shin_r", "shin_l"], "Full boots own both feet and both shins")
	var layouts: Dictionary = {}
	var entry: Dictionary = {"slot": "boots", "facings": {}}
	for facing: String in ["front", "rear"]:
		var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Gear.BASE.path_join(facing + ".json")))
		layouts[facing] = layout
		var replacements: Array = []
		for part: Dictionary in layout["parts"]:
			if str(part["name"]) in ["shin_r", "shin_l"]:
				replacements.append({"part": part["name"], "file": str(part["file"]).trim_prefix(Gear.BASE + "/")})
		entry["facings"][facing] = {"replace": replacements}
	expect.call(Gear._valid_entry(entry, layouts), "Boot registry accepts matching shin crops before alternate shaft art arrives")
	var bad: Dictionary = entry.duplicate(true)
	bad["facings"]["rear"]["replace"][0]["file"] = "front/crossbow.png"
	expect.call(not Gear._valid_entry(bad, layouts), "Skinned rear shin replacements retain the same-size validation")
	for id: String in Gear._items:
		if Gear._items[id]["slot"] == "weapon":
			expect.call(not Gear.is_two_handed({"weapon": id}), "Every slice weapon is one-handed: " + id)

static func _offhand(rig: Node) -> Sprite2D:
	for attachment: Sprite2D in rig.get("_gear_attachments"):
		if str(attachment.name) == "GearOffhand":
			return attachment
	return null

static func _check_boot_replacements(rig: Node, expect: Callable) -> void:
	# The approved full-boot shafts exercise the rigid/front and skinned/rear swap.
	var replacements: Array = []
	var geometry: Dictionary = {}
	for op: Dictionary in Gear.ops_for_facing({"boots": "ironshod_sabatons"}, rig.facing)["replace"]:
		if str(op["part"]) in ["shin_r", "shin_l"]:
			replacements.append(op)
	expect.call(replacements.size() == 2, "Full boots replace both shin shafts: " + rig.facing)
	for op: Dictionary in replacements:
		var node: Node2D = rig._gear_base_parts[op["part"]]["node"]
		if node is Polygon2D:
			geometry[op["part"]] = {"polygon": node.polygon, "uv": node.uv, "polygons": node.polygons}
	rig.apply_gear({"replace": replacements})
	for op: Dictionary in replacements:
		var base: Dictionary = rig._gear_base_parts[op["part"]]
		var node: Node2D = base["node"]
		expect.call(node.get("texture") != base["texture"] and str(node.get("texture").get_meta("asset_source_path")).ends_with(op["file"]), "Boot layer replaces the actual shin texture: " + rig.facing + "/" + op["part"])
		if node is Polygon2D:
			var before: Dictionary = geometry[op["part"]]
			expect.call(node.polygon == before["polygon"] and node.uv == before["uv"] and node.polygons == before["polygons"], "Boot replacement preserves rear shin skin geometry")
	rig.apply_gear({})
	for op: Dictionary in replacements:
		var base: Dictionary = rig._gear_base_parts[op["part"]]
		expect.call(base["node"].get("texture") == base["texture"], "Clearing boots restores the exact original shin texture")

static func _check_visibility(rig: Node, expect: Callable) -> void:
	for loadout: Dictionary in [Gear.DEFAULTS, L1, L2]:
		rig.apply_gear(Gear.ops_for_facing(loadout, rig.facing))
		for clip: String in ["rest", "idle", "walk", "attack", "attack_heavy", "attack_stab", "cast", "shoot", "block", "block_shield", "hit", "death"]:
			for phase: float in [0.0, 0.01, 0.011, 0.1, 0.42, 0.8, 0.939, 0.94, 1.0]:
				Reaction.apply_pose(rig, clip, phase, false)
				expect.call(_offhand(rig) != null and _offhand(rig).visible, "Every equipped offhand stays visible: " + rig.facing + "/" + clip)
				var crossbow: bool = rig.bones["crossbow_r"].visible
				expect.call(crossbow == (clip == "shoot" and phase > 0.01 and phase < 0.94), "Only shooting exposes the right-hand crossbow during its existing window")
				expect.call(rig.bones["weapon_r"].visible == not crossbow, "The main weapon yields exactly while the right-hand crossbow is visible")
	for reduce: bool in [false, true]:
		for loadout: Dictionary in [Gear.DEFAULTS, L1, L2]:
			rig.apply_gear(Gear.ops_for_facing(loadout, rig.facing))
			for clip: String in ["cast", "shoot", "block", "hit", "death", "rest"]:
				Reaction.apply_pose(rig, clip, 0.42, reduce)
				expect.call(_offhand(rig).visible, "Offhands remain visible through reactions and reduced stills: " + clip)
	if rig.facing == "front":
		rig.apply_gear(Gear.ops_for_facing(L2, "front"))
		# The dagger draws over the sleeve (z50); its texture has the fist's rest
		# silhouette cut out, so the fist reads as gripping it in every pose.
		expect.call(_offhand(rig).z_index == 50, "The held dagger draws over the sleeve with the fist cut out of its grip")

static func _check_enemy(tree: SceneTree, expect: Callable) -> void:
	var enemy := EnemyRig.new()
	tree.root.add_child(enemy)
	expect.call(enemy.load_rig() and enemy._gear_attachments.is_empty(), "Enemy loads without an opt-in gear layer")
	for clip: String in ["idle", "walk", "attack"]:
		enemy.apply_pose(clip, 0.42)
		var sample: Dictionary = EnemyMotion.sample_pose(clip, 0.42, enemy.layout, enemy.facing)
		for name: String in enemy.bones:
			var value: Dictionary = sample.get(name, {})
			var expected := Transform2D(float(value.get("rotation", 0.0)), value.get("scale", Vector2.ONE), float(value.get("skew", 0.0)), value.get("position", enemy.rest_transforms[name].origin))
			expect.call(enemy.bones[name].transform == expected, "Enemy transforms retain the original loader/pose contract: " + name)
	for base: Dictionary in enemy._gear_base_parts.values():
		expect.call(base["node"].get("texture") == base["texture"] and base["node"].position == base["position"], "Enemy paint and placement stay unchanged")
	enemy.free()

static func _check_bake(tree: SceneTree, renderer: Node, expect: Callable) -> void:
	if DisplayServer.get_name() == "headless":
		expect.call(renderer.rest_texture() != null, "Dummy renderer uses the static rest fallback")
		print("PROTAGONIST GEAR GPU BAKE: deferred to real-renderer probe")
		return
	var signature: String = Gear.signature(L2)
	for frame: int in range(8):
		await tree.process_frame
		await RenderingServer.frame_post_draw
	var texture: Texture2D = renderer.rest_texture()
	expect.call(texture != null and texture.get_size() == Vector2(255, 255) and Baker._readbacks.get(signature, 0) == 1, "Neutral rest bakes exactly once per signature at 255x255")
	expect.call(texture.has_meta("gear_rest_image") and AssetLoader.texture_source_image(texture) == texture.get_meta("gear_rest_image"), "Silhouette extraction reuses bake pixels without another GPU readback")
	for repeat: int in range(100):
		expect.call(renderer.rest_texture() == texture, "Rest texture remains cached between frames")
	renderer.set_gear(L1)
	for frame: int in range(8):
		await tree.process_frame
		await RenderingServer.frame_post_draw
	renderer.set_gear(L2)
	expect.call(renderer.rest_texture() == texture and Baker._readbacks.get(signature, 0) == 1, "Returning to a previous signature reuses its GPU bake")
	var echo := Renderer.new()
	echo.set_gear(L2)
	tree.root.add_child(echo)
	await tree.process_frame
	expect.call(echo.rest_texture() == texture and Baker._readbacks.get(signature, 0) == 1, "A second renderer shares the signature cache without GPU readback")
	echo.free()

static func _check_board(tree: SceneTree, expect: Callable) -> void:
	var board := Board.new()
	tree.root.add_child(board)
	await tree.process_frame
	var state: Dictionary = {"player": {"pos": Vector2i(2, 2), "hp": 24}, "illusions": [{"id": 9, "pos": Vector2i(3, 2), "hp": 2}]}
	var preview: Dictionary = {"key": "illusion_preview", "role": "illusion_preview", "type": "player", "pos": Vector2i(2, 3)}
	for loadout: Dictionary in [L1, L2, Gear.DEFAULTS]:
		board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"equipped_equipment": loadout, "preview_units": [preview]})
		expect.call(board.protagonist_animation_snapshot()["gear"] == Gear.signature(loadout), "Board updates protagonist gear at the presentation boundary")
		for renderer: Node in board.get("_illusion_renderers").values():
			expect.call(renderer.snapshot()["gear"] == Gear.signature(loadout), "Every illusion and preview wears current gear before presentation")
	var anchor: Texture2D = board.call("_unit_hud_anchor_texture", {"type": "player"})
	if FileAccess.file_exists(Renderer.DEFAULT_GEAR_REST_PATH):
		expect.call(str(anchor.get_meta("asset_source_path", "")) == Renderer.DEFAULT_GEAR_REST_PATH, "Default hero retains the static gear rest identity for cached shadows")
	# Exercise the async bake handoff without pretending the dummy renderer has
	# GPU pixels: a CPU copy of static source art stands in only for the signal.
	var pixels: Image = AssetLoader.texture_source_image(anchor)
	var replacement: Texture2D = ImageTexture.create_from_image(pixels)
	replacement.set_meta("gear_rest_image", pixels)
	expect.call(AssetLoader.texture_source_image(replacement) == pixels, "The gear-only CPU pixel path is opt-in")
	var hero: Node = board.get("_protagonist_renderer")
	hero.set("_rest_texture", replacement)
	hero.emit_signal("rest_texture_changed")
	expect.call(board.call("_unit_hud_anchor_texture", {"type": "player"}) == replacement and board.get("_unit_textures")["player"] == replacement, "A completed rest bake refreshes player shadow and HUD sources")
	var layer: Node = board.get("_dynamic_render_layer")
	expect.call(layer.get("_unit_textures")["player"] == replacement, "Retained layers receive the new silhouette source")
	board.queue_free()
	await tree.process_frame
