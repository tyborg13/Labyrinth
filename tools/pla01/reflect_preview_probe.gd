extends SceneTree
## pla-01 proof only (not a test): the Reflect attack preview on a real Glacial
## Mirror fight. The ice_mirror pair (Glacial Mirror + Rime Spitter) stands in
## the production run scene on a Rime Hall board; each still selects a real
## card from data and aims it at the Mirror so the live preview shows:
##   a. Ember Rain (area) from 3 tiles: bounced damage on the hero, none on the
##      Mirror, the Rime Spitter beside it hit.
##   b. Chain Bolt (Chain 2) from 3 tiles: the Mirror's link bounces and the
##      Chain carries on to the Rime Spitter.
##   c. Updraft (Push 2) from 2 tiles: bounced, no travel preview.
##   d. Pale Spark from the adjacent tile: lands on the Mirror.
##   e. Lodestone Reversal from 2 tiles: bounced, no travel preview.
##   f. Pale Spark absorbed by Block: the existing chip shows Block loss.
##   g. Pale Spark absorbed by Defiance: the existing chip shows the charge.
## Native, 1920x1080 at 100% UI scale (the director queues it with the cel look):
##   LABYRINTH_CEL_LOOK=all PLA01_OUT="$PWD/output/pla-01r3/windowed" python3 tools/visual_probe_runner.py tools/pla01/reflect_preview_probe.gd --task-id pla-01r3 --no-headless --display-driver macos --audio-driver Dummy --timeout 240 --expect-size 1920x1080 --proof-contract tools/pla01/reflect_preview_contract.json
## (Headless check: python3 tools/godot_task_runner.py --task-id pla-01r3 --stream -- godot --headless --path . --script tools/pla01/reflect_preview_probe.gd)
## Writes pla01_reflect_<case>_1920x1080.png and
## reflect_preview.json to PLA01_OUT. A headless run checks the same preview
## truth without images (parse/logic check only).

const Playback = preload("res://tools/tooltip_loops/playback.gd")
const Fixture = preload("res://tools/tooltip_loops/fixture.gd")
const Data = preload("res://scripts/game_data.gd")
const Runs = preload("res://scripts/run_engine.gd")
const HeroCombat = preload("res://scripts/hero_facing_combat.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Reflect = preload("res://scripts/enemy_mechanics/reflect.gd")
const DEFAULT_OUT: String = "output/pla-01r3/reflect-preview"
const BIOME: String = "iskaldra" # Rime Hall, the ice_mirror encounter's biome.
const BOARD := Vector2i(8, 5)
const MIRROR_TILE := Vector2i(4, 2)
const SPITTER_TILE := Vector2i(4, 1)
const HAND: Array = ["ember_rain", "chain_bolt", "updraft", "pale_spark"]
const SETTLE_FRAMES: int = 12
const DEFENDED_BLOCK: int = 6
const LETHAL_START_HEALTH: int = 1
const CASES: Array = [
	{"id": "a_area", "card": "ember_rain", "hero": Vector2i(1, 2), "bounce": true, "spitter_hit": true},
	{"id": "b_chain", "card": "chain_bolt", "hero": Vector2i(1, 2), "bounce": true, "spitter_hit": true},
	{"id": "c_push", "card": "updraft", "hero": Vector2i(2, 2), "bounce": true, "spitter_hit": false},
	{"id": "d_adjacent", "card": "pale_spark", "hero": Vector2i(3, 2), "bounce": false, "spitter_hit": false},
	{"id": "e_pull", "card": "lodestone_reversal", "hero": Vector2i(2, 2), "bounce": true, "spitter_hit": false},
	{"id": "f_block", "card": "pale_spark", "hero": Vector2i(2, 2), "bounce": true, "spitter_hit": false, "block": DEFENDED_BLOCK},
	{"id": "g_defiance", "card": "pale_spark", "hero": Vector2i(2, 2), "bounce": true, "spitter_hit": false, "defiance": true},
]
var _viewport: SubViewport
var _headless: bool = false
var _out: String = ProjectSettings.globalize_path("res://").path_join(DEFAULT_OUT)
var _errors: Array[String]
var _report: Dictionary = {}
var _images: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	if _headless: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if not OS.get_environment("PLA01_OUT").is_empty(): _out = OS.get_environment("PLA01_OUT")
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = Playback.SIZE
	root.content_scale_size = root.size
	_viewport = Playback.canvas(self)
	for spec: Dictionary in CASES: await _case(spec)
	_report["cel_look"] = OS.get_environment("LABYRINTH_CEL_LOOK")
	_report["renderer"] = DisplayServer.get_name()
	var file := FileAccess.open(_out.path_join("reflect_preview.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_report, "\t", true) + "\n")
	file.close()
	print(_out.path_join("reflect_preview.json"))
	for failure: String in _errors: push_error(failure)
	print("PLA-01 REFLECT PREVIEW TEST RESULT: %s (%d cases, %d images, %d failures%s)" % ["PASS" if _errors.is_empty() else "FAIL", CASES.size(), _images, _errors.size(), "; headless, no images" if _headless else ""])
	quit(0 if _errors.is_empty() else 1)

# ---------------------------------------------------------------- fixture

## A real combat: production run, ice_mirror pair and the probe's cards in hand.
static func _battle(spec: Dictionary) -> Dictionary:
	var runs := Runs.new()
	var progression: Dictionary = Progression.default_data()
	if bool(spec.get("defiance", false)): progression["level"] = Progression.DEFIANCE_LEVEL_INTERVAL
	var run: Dictionary = runs.create_new_run(Fixture.SEED, progression)
	var layout: Dictionary = run["current_room_layout"].duplicate(true)
	var grid: Array = []
	for y: int in range(BOARD.y):
		var row: Array = []
		for x: int in range(BOARD.x): row.append("stone")
		grid.append(row)
	layout["grid"] = grid
	layout["player_start"] = spec["hero"]
	layout["type"] = "combat"
	layout["depth"] = 2
	layout["objective"] = {}
	layout["element"] = "none" # No room bonus or ground: the numbers are the cards'.
	for key: String in ["terrain", "traps", "loot", "npcs", "enemies"]: layout[key] = []
	layout["surfaces"] = {}
	layout["moss"] = {}
	for entry: Array in [["glacial_mirror", MIRROR_TILE], ["rime_spitter", SPITTER_TILE]]:
		var definition: Dictionary = Data.enemy_def(entry[0])
		layout["enemies"].append({"id": layout["enemies"].size() + 1, "type": entry[0], "pos": entry[1], "hp": definition["max_hp"], "max_hp": definition["max_hp"]})
	var state: Dictionary = HeroCombat.new().create_combat(Fixture.SEED, layout, runs._player_snapshot(run))
	state["player"]["block"] = int(spec.get("block", 0))
	if bool(spec.get("defiance", false)): state["player"]["hp"] = LETHAL_START_HEALTH
	var hand: Array[String]
	for card: String in HAND: hand.append(card)
	if not hand.has(spec["card"]): hand.append(spec["card"])
	state["deck"]["hand"] = hand
	run["mode"] = "combat"
	run["current_room_layout"] = layout
	run["combat_state"] = state
	return run

# ---------------------------------------------------------------- cases

func _case(spec: Dictionary) -> void:
	var id: String = spec["id"]
	var scene: Node = await Playback.instance(self, _viewport, {"run": _battle(spec), "id": "pla01_reflect_" + id, "biome": BIOME}, false)
	if scene == null: _fail(id + ": run scene did not load"); return
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var engine: RefCounted = scene.get("_combat_engine")
	var board: Control = scene.get("board_view")
	var live: Dictionary = scene.get("_combat_state")
	_check(engine.is_player_turn(live), id + ": the fight opens on the hero's turn")
	_check(is_equal_approx(Typography.ui_scale(scene), 1.0), id + ": 100% UI scale")
	var slot: int = (live["deck"]["hand"] as Array).find(spec["card"])
	_check(slot >= 0, id + ": %s is in hand" % spec["card"])
	await scene.call("_on_card_pressed", slot)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_check(not (scene.get("_pending_target_tiles") as Array).is_empty(), id + ": %s is selected and aiming" % spec["card"])
	_check((scene.get("_pending_target_tiles") as Array).has(MIRROR_TILE), id + ": the Mirror is a legal target")
	# GUI dispatch owns the tile hover; the arrow follows the same point. The
	# probe never moves the OS pointer. If the injected motion doesn't reach the
	# board (headless), the board's own hover update emits the same tile.
	var local: Vector2 = board.call("_tile_center", MIRROR_TILE)
	var point: Vector2 = board.get_global_transform_with_canvas() * local
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	if scene.get("_hovered_board_tile") != MIRROR_TILE:
		print("PLA-01 NOTE: %s injected motion did not reach the board; using the board's hover update" % id)
		board.set("_pointer_over_board", true)
		board.set("_last_pointer_position", local)
		board.call("_update_hover_at", local)
	scene.call("_sync_click_targeting_arrow", point)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_check(scene.get("_hovered_board_tile") == MIRROR_TILE, id + ": aimed at the Mirror")
	var presentation: Dictionary = board.get("presentation")
	var losses: Dictionary = presentation.get("damage_preview", {})
	var chip: Dictionary = presentation.get("en05_reflect_preview", {})
	var cache: Dictionary = scene.get("_surface_preview_cache")
	var after: Dictionary = cache.get("state", {})
	var mirror_key: String = "enemy_%d" % int(live["enemies"][0]["id"])
	var spitter_key: String = "enemy_%d" % int(live["enemies"][1]["id"])
	var mirror_after: Dictionary = engine._surface_actor(after, "enemy", int(live["enemies"][0]["id"]))
	var hero_loss: int = _loss(losses.get("player", {}))
	var hero_labels: Array[String]
	for outcome: Dictionary in presentation.get("friendly_damage_chips", []):
		if outcome.get("actor_key") == "player": hero_labels.append(str(outcome.get("label", "")))
	var force_tiles: Array = presentation.get("effect", {}).get("force_tiles", [])
	var defiance_spent: int = int(live.get("defiance_remaining", 0)) - int(after.get("defiance_remaining", 0))
	var row: Dictionary = {"card": spec["card"], "hero": str(spec["hero"]), "target": str(MIRROR_TILE), "distance": engine._enemy_distance_to_tile(live["enemies"][0], spec["hero"]),
		"reflect_chip": chip.get("damage", null), "hero_loss": hero_loss, "mirror_loss": _loss(losses.get(mirror_key, {})), "spitter_loss": _loss(losses.get(spitter_key, {})),
		"mirror_tile_after": str(mirror_after.get("pos", Vector2i(-1, -1))), "bounces": Reflect.bounces_between(cache.get("before", live), after).size(),
		"hero_labels": hero_labels, "force_tiles": force_tiles.size(), "defiance_spent": defiance_spent}
	_report[id] = row
	print("PLA-01 CASE %s: %s" % [id, JSON.stringify(row)])
	if bool(spec["bounce"]):
		_check(bool(chip.get("merged", false)) and not hero_labels.is_empty() and hero_labels[0].begins_with("↶ "), id + ": the hero's existing chip carries the return marker")
		if bool(spec.get("defiance", false)):
			_check(defiance_spent == 1 and hero_labels.has("↶ You: −1 Defiance"), id + ": the hero previews the Defiance charge")
		else:
			_check(int(chip.get("damage", -1)) == hero_loss and hero_loss > 0, id + ": the chip equals the hero's previewed loss")
		if spec.has("block"):
			_check(hero_labels.has("↶ You: −%d Block" % hero_loss), id + ": the hero previews the Block lost")
		if spec["card"] in ["updraft", "lodestone_reversal"]:
			_check(force_tiles.is_empty() and presentation.get("displacement_paths", []).is_empty(), id + ": bounced force previews no travel or destination")
		_check(not losses.has(mirror_key), id + ": no damage previewed on the Mirror")
		_check(mirror_after.get("pos") == MIRROR_TILE, id + ": the Mirror stays on its tile")
	else:
		_check(chip.is_empty(), id + ": no reflection chip for an adjacent hit")
		_check(_loss(losses.get(mirror_key, {})) > 0 and hero_loss == 0, id + ": the hit lands on the Mirror")
	_check(losses.has(spitter_key) == bool(spec["spitter_hit"]), id + ": the Rime Spitter is %shit" % ("" if bool(spec["spitter_hit"]) else "not "))
	await _shot("pla01_reflect_%s" % id)
	scene.call("_on_cancel_requested")
	scene.queue_free()
	for frame: int in range(3): await process_frame

# ---------------------------------------------------------------- helpers

static func _loss(entry: Dictionary) -> int:
	return int(entry.get("hp_loss", 0)) + int(entry.get("block_loss", 0)) + int(entry.get("stoneskin_loss", 0))

func _shot(name: String) -> void:
	if _headless: return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != Playback.SIZE:
		_fail("Could not read the 1920x1080 still for " + name)
		return
	var file: String = _out.path_join(name + "_1920x1080.png")
	if image.save_png(file) != OK: _fail("Could not save " + file)
	else:
		_images += 1
		print(file)

func _check(condition: bool, message: String) -> void:
	if not condition: _fail(message)

func _fail(message: String) -> void:
	_errors.append(message)
	push_error(message)
