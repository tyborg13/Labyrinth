extends SceneTree
const Fixture = preload("res://tools/rd02/fixture.gd")
const Real = preload("res://tools/ptf09/real_fixture.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	Fixture.install(args[args.find("--case") + 1] if args.has("--case") else "hero")
	var canvas: SubViewport = Real.make_canvas(self)
	var scene: Node = Real.resume(self, canvas)
	for frame: int in range(Fixture.SETTLE_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var sources: Array[Dictionary] = Sources.collect(board)
	var alpha := Alpha.new()
	alpha.prepare(sources)
	for unit: Dictionary in board.call("_visible_units"): print("UNIT ", unit.get("key"), " ", unit.get("type"), " pos=", unit.get("pos"), " footprint=", unit.get("footprint"))
	var target: Dictionary
	for source: Dictionary in sources:
		if source.get("key") == "player": target = source
	print("TARGET ", str(target["rect"]), " pose=", target["mask_pose"], " texture=", target["mask_texture"].get_meta("asset_source_path", target["mask_texture"].resource_path))
	print("HERO ", JSON.stringify(board.call("protagonist_animation_snapshot")))
	var index: int = sources.find(target)
	for later: int in range(index + 1, sources.size()):
		var blockers: Array[Dictionary]
		blockers.append(sources[later])
		var amount: float = Alpha.coverage(target, blockers)
		if amount > 0:
			print("BLOCKER ", sources[later].get("key", ""), " ", sources[later].get("prop_kind", ""), " ", str(sources[later]["rect"]), " pose=", sources[later].get("mask_pose", ""), " amount=", amount, " texture=", sources[later]["mask_texture"].get_meta("asset_source_path", sources[later]["mask_texture"].resource_path))

	for entry_index: int in range(sources.size()):
		var source: Dictionary = sources[entry_index]
		if bool(source["eligible"]): print("ALPHA_TARGET ", source["key"], "=", alpha.coverage_for(sources, entry_index))
	var texture: Texture2D = board.call("_loot_texture", {"kind": "item", "card_id": "nail_bomb"})
	var occupied: Dictionary = {}
	for source: Dictionary in sources:
		if source["kind"] == "unit": occupied[(source["data"] as Dictionary).get("pos")] = true
	for tile: Vector2i in board.call("_rendered_tiles_in_draw_order"):
		if occupied.has(tile) or not str(board.get("combat_state")["grid"][tile.y][tile.x]) in ["stone", "ember"]: continue
		var hero_probe: Dictionary = target.duplicate(false)
		hero_probe["rect"] = board.call("_unit_draw_rect_for_center", target["data"], board.call("world_position_for_unit_origin", target["data"], tile))
		var hero_blockers: Array[Dictionary]
		for source: Dictionary in sources:
			if source["kind"] == "unit" and source.get("key") != "player" and board.call("_tile_draws_before", tile, source["tile"]): hero_blockers.append(source)
		print("HERO_CANDIDATE ", tile, "=", Alpha.coverage(hero_probe, hero_blockers))
		var probe: Dictionary = {"kind": "loot", "mask_texture": texture, "rect": board.call("_loot_rect_for_tile", tile, texture, {"kind": "item"})}
		probe["mask"] = alpha.mask_for(probe)
		var blockers: Array[Dictionary]
		for source: Dictionary in sources:
			if source["kind"] == "unit" and (source["tile"] == tile or board.call("_tile_draws_before", tile, source["tile"])): blockers.append(source)
		var amount: float = Alpha.coverage(probe, blockers)
		if amount >= 0.40: print("LOOT_CANDIDATE ", tile, "=", amount)
	quit()
