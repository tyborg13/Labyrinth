extends "res://tools/rd08/integration_proof.gd"

const HERO_BLOCK: int = 7
const TOOLTIP_WAIT: float = 0.8
const HOLD_SETTLE: float = 3.0
const VYRAKETH_HERO_OFFSET := Vector2i(-1, 0)
var check_only: bool = false
var hover_only: bool = false
var capture_dir: String
var target: Dictionary
var capture_samples: Array[Dictionary]

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	check_only = args.has("--check-only")
	hover_only = args.has("--hover-only")
	case_name = args[args.find("--case") + 1] if args.has("--case") else "overlap"
	if not check_only and DisplayServer.get_name() == "headless":
		push_error("Native captures belong to the design owner"); quit(1); return
	Fixture.install_save(ROOT + "/" + case_name + ".json")
	canvas = Fixture.make_canvas(self)
	canvas.gui_embed_subwindows = true
	scene = Fixture.resume(self, canvas)
	await _settle()
	board = scene.get("board_view")
	capture_dir = ROOT + ("/feedback1/stills/" if hover_only else "/stills/") + case_name
	DirAccess.make_dir_recursive_absolute(capture_dir)
	Settings._applied_board_health_bars = Settings.BOARD_HEALTH_CONTEXTUAL
	if hover_only:
		if case_name == "overlap":
			var found: Dictionary = Cases.find(board)
			target = Isolation.enemy_at_tile(board, found.enemy.pos)
		else:
			for unit: Dictionary in board.call("_visible_units"):
				if str(unit.get("type", "")) == case_name: target = unit
		_check(not target.is_empty(), "Requested hover capture has its real enemy")
		if target.is_empty(): quit(1); return
		await _hover(board.call("_unit_footprint_tiles", target).back())
		_assert_no_enemy_tooltip(target, "Native hover capture setup")
		_check(board.plate_visibility.opacity(target.key) == 1.0 and _expanded(target.key), "Hovered capture retains plate and unfurled intent")
		await _still("03_enemy_hover" if case_name == "overlap" else "11_zekarion_hover")
	elif case_name == "overlap":
		var found: Dictionary = Cases.find(board)
		target = Isolation.enemy_at_tile(board, found.enemy.pos)
		await _hover(found.empty)
		Settings._applied_board_health_bars = Settings.BOARD_HEALTH_ALWAYS
		board.refresh_plate_visibility()
		await _still("01_rest_always")
		Settings._applied_board_health_bars = Settings.BOARD_HEALTH_CONTEXTUAL
		board.refresh_plate_visibility()
		await _still("02_rest_on_hover_and_aim")
		await _hover(target.pos)
		await _still("03_enemy_hover")
		await _hover(found.overlap)
		_check((board.presentation.get("isolated_enemy_actor_keys", []) as Array).size() == 2, "Reverse still isolates both attackers")
		await _still("04_overlap_hover")
		var crate: Dictionary = board.combat_state.terrain.filter(func(p: Dictionary) -> bool: return int(p.get("max_hp", 0)) > 0)[0]
		await _hover(crate.pos)
		board.plate_visibility.advance(FADE_SETTLE)
		_check(board.plate_visibility.opacity(board.plate_visibility.terrain_key(crate)) == 1.0, "Crate still shows Health")
		await _still("05_crate_hover")
		var state: Dictionary = scene.get("_combat_state").duplicate(true)
		state.player.block = HERO_BLOCK
		scene.set("_combat_state", state); scene.call("_refresh_stage_view")
		await _hover(found.empty)
		await _still("06_hero_block_rest")
		await _hover(state.player.pos)
		await _still("07_hero_block_hover")
		await scene.call("_on_card_pressed", 0)
		await _hover(target.pos)
		var stepped_back: int = 0
		for unit: Dictionary in board.call("_visible_units"):
			if not board.get("_aim_focus").full_strength(board, unit): stepped_back += 1
		_check(stepped_back > 0, "Ranged aim still has out-of-reach foes")
		await _still("08_ranged_aim")
		await scene.call("_on_cancel_requested")
		await _hover(found.empty)
		scene.call("_on_enemy_intent_toggle_toggled", true)
		await _still("09_details")
	else:
		for unit: Dictionary in board.call("_visible_units"):
			if str(unit.get("type", "")) == case_name: target = unit
		_check(not target.is_empty(), "Real arena dragon exists")
		if case_name == "zekarion":
			await _hover(Vector2i(-1, -1))
			await _still("10_zekarion_rest")
			await _hover(board.call("_unit_footprint_tiles", target).back())
			await _still("11_zekarion_hover")
		else:
			# Proof-only hero placement behind the actual dragon in its real arena.
			var state: Dictionary = scene.get("_combat_state").duplicate(true)
			state.player.pos = target.pos + VYRAKETH_HERO_OFFSET
			scene.set("_combat_state", state); scene.call("_refresh_stage_view")
			await _hover(Vector2i(-1, -1))
			var overlay: Node2D = board.get("_occlusion_silhouettes")
			overlay.sync_coverage(); overlay._process(FADE_SETTLE)
			_check(overlay.entries.has("player") and bool(overlay.entries.player.on), "Hero has live x-ray behind Vyraketh")
			await _still("12_hero_behind_vyraketh")
	var file := FileAccess.open(capture_dir + "/semantics.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": capture_samples, "failures": failures, "check_only": check_only, "size": [1920,1080], "ui_scale": 1.0}, "\t"))
	print(capture_dir)
	for failure: String in failures: push_error(failure)
	print("RD08 CAPTURE SETUP: %s (%s, %d samples, %s)" % ["PASS" if failures.is_empty() else "FAIL", case_name, capture_samples.size(), "headless; no images" if check_only else "native"])
	quit(0 if failures.is_empty() else 1)

func _still(label: String) -> void:
	board.plate_visibility.advance(HOLD_SETTLE)
	await _settle()
	await create_timer(TOOLTIP_WAIT).timeout
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "100% UI scale")
	if not check_only:
		await RenderingServer.frame_post_draw
		var picture: Image = canvas.get_texture().get_image()
		_check(picture.get_size() == Fixture.SIZE and picture.save_png(capture_dir + "/" + label + ".png") == OK, "1920x1080 " + label)
	var outlined: Dictionary = {}
	var overlay: Node2D = board.get("_occlusion_silhouettes")
	for key: String in overlay.entries: outlined[key] = bool(overlay.entries[key].on)
	capture_samples.append({"image": label + ".png", "setting": Settings._applied_board_health_bars, "tooltip_at_pointer": board.call("_get_tooltip", board.get("_last_pointer_position")), "plate_opacity": board.plate_visibility.opacity(str(target.key)), "isolated": board.presentation.get("isolated_enemy_actor_keys", []), "intents": Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", [])), "xray": outlined})
