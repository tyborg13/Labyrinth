extends RefCounted

const Candidate = preload("res://tests/perf/hover_draw_candidate.gd")
const Reference = preload("res://tests/perf/hover_draw_reference.gd")
const Arena = preload("res://tests/suites/warband_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const PROOF_SIZE := Vector2(1920, 1080)
const PILLAR_TILE := Vector2i(4, 3)
const ERUPT_TILE := Vector2i(3, 4)
const BURROW_TILE := Vector2i(2, 3)
const BURST_TILE := Vector2i(3, 2)
const ZONE_TILE := Vector2i(5, 4)
const NEXT_ZONE_TILE := Vector2i(5, 5)
const TORCH_CLOCKS: Array = [0.0, 0.3, 1.1, 4.8]
const SETTLE_FRAMES: int = 3

static func fixture() -> Dictionary:
	var state: Dictionary = Arena.arena()
	state["grid"][PILLAR_TILE.y][PILLAR_TILE.x] = "pillar"
	var grub: Dictionary = state["enemies"][1]
	grub.merge({"type": "burrow_grub", "pos": BURROW_TILE, "burrowed": true, "erupt_tile": ERUPT_TILE,
		"intent": (Data.enemy_def("burrow_grub")["intents"] as Array).back().duplicate(true)}, true)
	state["enemies"][2].merge({"type": "ember_tick", "pos": BURST_TILE,
		"intent": (Data.enemy_def("ember_tick")["intents"] as Array).front().duplicate(true)}, true)
	return state

static func presentation_for(state: Dictionary, seconds: float) -> Dictionary:
	return {"reduced_motion": true, "torch_mote_proof_seconds": seconds, "threats_proof_seconds": seconds,
		"threats_at_rest": {"hero_tile": state["player"]["pos"], "threats": [
			{"key": "enemy_%d" % int(state["enemies"][0]["id"]), "area": true, "order": "1·3", "alpha": 1.0,
				"attacker_tile": state["enemies"][0]["pos"], "tiles": [ZONE_TILE, NEXT_ZONE_TILE]}]}}

static func run(tree: SceneTree, expect: Callable) -> void:
	var candidate := Candidate.new()
	var reference := Reference.new()
	for board: Control in [candidate, reference]:
		board.size = PROOF_SIZE
		tree.root.add_child(board)
		board.set_process(false)
	var state: Dictionary = fixture()
	var last_torch: Array = []
	var last_overlay: Array = []
	var comparisons: int = 0
	for mutation: int in range(TORCH_CLOCKS.size()):
		var shown: Dictionary = presentation_for(state, TORCH_CLOCKS[mutation])
		mutate_fixture(state, shown, mutation)
		for board: Control in [candidate, reference]:
			board._hover_tile = BURST_TILE if mutation < 2 else Vector2i(-1, -1)
			board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, shown.duplicate(true))
			# Force the actual retained callbacks at each deterministic proof clock.
			board._queue_render_layer_redraw(board._overlay_render_layer)
			board._queue_render_layer_redraw(board._foreground_render_layer)
		for frame: int in range(SETTLE_FRAMES): await tree.process_frame
		var overlays: Array = candidate._overlay_render_layer.overlay_commands
		var expected: Array = reference._overlay_render_layer.overlay_commands
		expect.call(not overlays.is_empty() and not expected.is_empty(), "Real retained overlay draw executes")
		expect.call(overlays == expected, "Retained overlay draw inputs/glow geometry match independent selectors: %d" % mutation)
		if mutation == 0:
			for field: int in [2, 3, 4, 5]:
				expect.call(overlays.any(func(command: Array) -> bool: return bool(command[field]) if field == 4 else not command[field].is_empty()), "Retained draw fixture exercises overlay selector %d" % field)
		else:
			expect.call(overlays != last_overlay, "Changing overlay input changes actual retained tile content")
		var torches: Array = candidate._foreground_render_layer.torch_commands
		var old_torches: Array = reference._foreground_render_layer.torch_commands
		expect.call(not torches.is_empty() and not old_torches.is_empty(), "Real retained foreground emits torch sprite/trail commands")
		expect.call(torches == old_torches, "Live torch cycle preserves every ordered sprite/trail command: %s" % TORCH_CLOCKS[mutation])
		if mutation > 0: expect.call(torches != last_torch, "Changing the proof clock changes actual torch commands")
		last_torch = torches.duplicate(true)
		last_overlay = overlays.duplicate(true)
		comparisons += 1
	candidate.queue_free()
	reference.queue_free()
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
	preload("res://tests/perf/hover_draw_manifest.gd")._textures.clear()
	print("PERF04 RETAINED DRAW RESULT: %d live overlay/torch comparisons; leader, burrow, burst, zone and clock mutations exercised" % comparisons)

static func mutate_fixture(state: Dictionary, shown: Dictionary, mutation: int) -> void:
	if mutation == 1:
		state["enemies"][0]["pos"] += Vector2i.RIGHT
		state["enemies"][1]["erupt_tile"] = NEXT_ZONE_TILE
		shown["threats_at_rest"]["threats"][0]["order"] = "2"
	if mutation == 2:
		shown["visible_enemy_ids"] = [state["enemies"][1]["id"], state["enemies"][2]["id"]]
		state["grid"][NEXT_ZONE_TILE.y][NEXT_ZONE_TILE.x] = "wall"
		shown["damage_preview"] = {"enemy_%d" % int(state["enemies"][2]["id"]): {"lethal": true}}
	if mutation == 3:
		state["enemies"][1]["burrowed"] = false
		state["enemies"][2]["hp"] = 0
		shown["threats_at_rest"]["threats"] = []
