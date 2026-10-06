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
	await preload("res://tests/suites/protagonist_gear_motion_suite.gd").run(tree, expect)
	expect.call(Gear.resolve({}) == {"weapon": "training_sword", "offhand": "", "armor": "patched_cloak", "boots": "skirmisher_boots", "trinket": ""}, "Missing optional slots are bare; the body uses defaults")
	expect.call(Gear.resolve({"weapon": "", "offhand": "", "armor": "", "boots": "", "trinket": ""}) == Gear.resolve({}), "Empty slots follow the same fallback rules")
	expect.call(Gear.resolve(L4) == Gear.DEFAULTS and Gear.signature(L4) == Gear.signature(Gear.DEFAULTS), "Out-of-slice loadout resolves exactly to default visuals")
	expect.call(Gear.resolve({"weapon": "ward_kite"})["weapon"] == "training_sword", "An item in the wrong slot also falls back")
	expect.call(Gear.weapon_motion(L1) == "heavy" and Gear.weapon_motion(L2) == "stab" and Gear.weapon_motion({}) == "sword", "Weapon motion contract is data driven")
	expect.call(Gear.is_two_handed(L1) and Gear.offhand_kind(L1).is_empty() and Gear.offhand_kind(L2) == "hand" and Gear.offhand_kind(Gear.DEFAULTS) == "shield", "Two-handed and held-kind contracts")
	for facing: String in ["front", "rear"]:
		var rig := Rig.new()
		rig.facing = facing
		tree.root.add_child(rig)
		expect.call(rig.load_rig(), "Bare protagonist rig loads: " + facing)
		var bases: Dictionary = rig._gear_base_parts.duplicate(true)
		for loadout: Dictionary in [Gear.DEFAULTS, L1, L2, L3, L4]:
			rig.apply_gear(Gear.ops_for_facing(loadout, facing))
			if loadout == L1:
				expect.call(_offhand(rig) == null, "Two-hander omits offhand in " + facing)
			rig.apply_gear({})
			expect.call(rig._gear_attachments.is_empty(), "Reset frees every attachment")
			for name: String in bases:
				var base: Dictionary = bases[name]
				var node: Node2D = base["node"]
				expect.call(node.get("texture") == base["texture"] and node.position == base["position"], "Reset restores exact texture and position: " + facing + "/" + name)
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

static func _offhand(rig: Node) -> Sprite2D:
	for attachment: Sprite2D in rig.get("_gear_attachments"):
		if str(attachment.name) == "GearOffhand":
			return attachment
	return null

static func _check_visibility(rig: Node, expect: Callable) -> void:
	rig.apply_gear(Gear.ops_for_facing(L2, rig.facing))
	for clip: String in ["shoot", "cast", "block", "hit", "walk", "rest", "death"]:
		for phase: float in [0.0, 0.1, 0.42, 0.8, 1.0]:
			Reaction.apply_pose(rig, clip, phase, false)
			var crossbow: bool = rig.bones["weapon_l"].visible
			expect.call(_offhand(rig).visible == not (clip == "shoot" and crossbow), "Held offhand yields exactly while the crossbow is visible: " + rig.facing + "/" + clip)
	for reduce: bool in [false, true]:
		rig.apply_gear(Gear.ops_for_facing(Gear.DEFAULTS, rig.facing))
		for clip: String in ["cast", "shoot", "block", "hit", "death", "rest"]:
			Reaction.apply_pose(rig, clip, 0.42, reduce)
			expect.call(_offhand(rig).visible, "Shield remains visible through actions and reduced stills: " + clip)
	if rig.facing == "front":
		rig.apply_gear(Gear.ops_for_facing(L2, "front"))
		expect.call(_offhand(rig).z_index == 48 and rig.skeleton.get_index() < (rig._gear_base_parts["arm_l"]["node"] as Node).get_index(), "Equal-z dagger precedes the sleeve mesh; fist z49 covers the grip")

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
