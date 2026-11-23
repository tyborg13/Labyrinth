extends SceneTree
## Scripted contact cases. Actual RunScene frame measurements come from native.sh --dry-run.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Contact = preload("res://scripts/resolved_contact_bursts.gd")
const Burst = preload("res://scripts/tile_burst_fx.gd")
const Surface = preload("res://scripts/board_surface_presentation.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const HERO := Vector2i(1, 1)
const TARGET := Vector2i(2, 1)
const OTHER := Vector2i(3, 1)
const TEST_HP := 40
const TEST_LOSS := 4
const PACING_CASES: Array[String] = ["strike", "bite", "push_wall", "erupt", "hurl_spear"]

class MappedShot extends RefCounted:
	static func resolve(effect: Dictionary) -> String:
		return "spear" if effect.get("base_card_id") == "hurl_spear" else ""

var _contact := Contact.new()
var _state: Dictionary
var _checks: int
var _failures: int

func _initialize() -> void:
	Runtime.apply_from_environment()
	call_deferred("_verify")

func _verify() -> void:
	_state = {"grid": [["floor", "floor", "floor", "floor"], ["floor", "floor", "floor", "floor"], ["floor", "floor", "floor", "floor"]],
		"player": {"pos": HERO, "hp": TEST_HP}, "enemies": [{"id": 1, "pos": TARGET, "hp": TEST_HP}]}
	_attacks()
	_events()
	_mechanics()
	_overlap()
	_reduced()
	_check_pacing()
	print("FX-17 VERIFY: %d checks, %d failures" % [_checks, _failures])
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(1 if _failures else 0)

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if condition: return
	_failures += 1
	push_error(message)

static func _visible(_tile: Vector2i) -> bool:
	return true

func _rows(label: String, specs: Array, names: Array, reduced: bool = false) -> void:
	var emitted: Array
	var rows: Dictionary = Burst.metadata()["rows"]
	for spec: Dictionary in specs:
		for entry: Dictionary in Burst.plan(spec, _state["grid"], spec.get("contact_hits", {}), _visible, reduced):
			var row: String = spec["name"] + ("_hit" if entry["hit"] else "_floor")
			_expect(entry["rear"] == rows[row + "_rear"] and entry["front"] == rows[row + "_front"], label + " uses the approved pair.")
			_expect(entry["delay"] == 0.0, label + " starts at contact.")
			emitted.append([row, entry["tile"]])
	_expect(emitted == names, "%s rows: %s expected %s" % [label, emitted, names])
	print("FX-17 CASE %s %s" % [label, emitted])

func _attack(label: String, effect: Dictionary, after: Dictionary, expected: Array, visible: Callable = _visible) -> void:
	_contact.begin(_state)
	var specs: Array[Dictionary]
	_contact.append_attack(specs, effect, _state, after, visible)
	_rows(label, specs, expected)
	var tile: Vector2i = effect["to"]
	_expect(Contact.suppresses_decal(effect, tile) == not expected.is_empty(), label + " controls the old decal submission.")

func _attacks() -> void:
	var hit: Dictionary = _state.duplicate(true)
	hit["enemies"][0]["hp"] -= TEST_LOSS
	var melee: Dictionary = {"kind": "melee", "to": TARGET}
	_attack("melee hit", melee.duplicate(), hit, [["steel_hit", TARGET]])
	var blocked: Dictionary = _state.duplicate(true)
	_state["enemies"][0]["block"] = TEST_LOSS
	_attack("blocked to zero health loss", melee.duplicate(), blocked, [["steel_hit", TARGET]])
	_state["enemies"][0].erase("block")
	_attack("miss", melee.duplicate(), _state, [["steel_floor", TARGET]])
	_attack("unmapped ranged", {"kind": "ranged", "element": "fire", "to": TARGET}, hit, [["fire_hit", TARGET]])
	_attack("defeat", melee.duplicate(), {"grid": _state["grid"], "player": _state["player"], "enemies": []}, [["steel_hit", TARGET]])
	_attack("shadow contact", {"kind": "melee", "element": "shadow", "to": TARGET}, hit, [["shadow_hit", TARGET]])
	_attack("hidden tile", melee.duplicate(), hit, [], func(_tile: Vector2i) -> bool: return false)
	_state["enemies"][0]["footprint"] = Vector2i(2, 1)
	_attack("named tile on a large target", {"kind": "melee", "to": OTHER}, hit, [["steel_hit", OTHER]])
	_state["enemies"][0].erase("footprint")
	for pool: String in ["stoneskin", "frost_armor", "defiance_remaining"]:
		var defended: Dictionary = _state.duplicate(true)
		var before_pool: Dictionary = _state if pool == "defiance_remaining" else _state["player"]
		before_pool[pool] = TEST_LOSS
		_attack(pool + " loss", {"kind": "melee", "to": HERO}, defended, [["steel_hit", HERO]])
		before_pool.erase(pool)

func _event(label: String, event: Dictionary, expected: Array, mark: String, after: Dictionary = {}) -> void:
	if after.is_empty(): after = _state
	_contact.clear()
	_contact.begin(_state)
	event["sequence"] = 1
	var shown: Dictionary = {"surface_feedback_events": [event]}
	_rows(label, _contact.observe(shown, after, _visible), expected)
	_expect(shown["surface_feedback_events"][0].get(Contact.REPLACED, "") == mark, label + " masks only its previous drawing.")
	_expect(_contact.observe(shown, after, _visible).is_empty(), label + " stays one-shot on resubmission.")
	_expect(not event.has(Contact.REPLACED), label + " leaves the resolver journal unchanged.")

func _events() -> void:
	_event("Push into a wall", {"kind": "force_collision", "tile": TARGET, "blockers": [{"kind": "wall", "tile": OTHER}]}, [["impact_hit", TARGET]], "collision")
	_event("Push into a unit", {"kind": "force_collision", "tile": TARGET, "blockers": [{"kind": "enemy", "tile": OTHER, "damage": TEST_LOSS}]}, [["impact_hit", TARGET], ["impact_hit", OTHER]], "collision")
	_event("Pull into a prop", {"kind": "force_collision", "tile": TARGET, "force": "pull", "blockers": [{"kind": "terrain", "tile": OTHER, "damage": TEST_LOSS}]}, [["impact_hit", TARGET]], "collision")
	for kind: String in ["ice", "rubble", "fire", "electrified"]:
		var element: String = Contact.SURFACE_ELEMENTS[kind]
		_event(kind + " break", {"kind": "surface_removed", "tile": TARGET, "surface": kind}, [[element + "_floor", TARGET]], "break")
	_expect(Surface.leaving_alpha(TARGET, "ice", [{"tile": TARGET, "break_surface": "ice", Contact.REPLACED: "break"}], 0.0) == 1.0, "An Ice break keeps the outgoing fade.")
	var after: Dictionary = _state.duplicate(true)
	after["enemies"][0]["hp"] -= TEST_LOSS
	_event("unstamped trap with loss", {"kind": "trap_triggered", "tile": TARGET, "element": "ice"}, [["ice_hit", TARGET]], "trap", after)
	_event("unstamped neutral trap", {"kind": "trap_triggered", "tile": TARGET}, [["impact_floor", TARGET]], "trap")
	_event("shadow trap", {"kind": "trap_triggered", "tile": TARGET, "element": "shadow"}, [["shadow_floor", TARGET]], "trap")

func _mechanics() -> void:
	var before: Dictionary = _state.duplicate(true)
	before["enemies"][0]["type"] = "burrow_grub"
	var after: Dictionary = before.duplicate(true)
	after["enemies"][0].merge({"burrowed": true, "erupt_tile": HERO}, true)
	var step: Dictionary = {"kind": "burrow", "actor_key": "enemy_1", "from": TARGET, "to": TARGET, "state_after": after}
	_contact.begin(before, step)
	var shown: Dictionary = {"burrow_grub_motion": {"enemy_1": {"phase": 0.0}}}
	_expect(_contact.observe(shown, before, _visible).is_empty(), "Burrow wind-up does not spawn.")
	shown["burrow_grub_motion"]["enemy_1"]["phase"] = Action.data_for("burrow_grub")["clips"]["burrow"].get("contact", 1.0)
	_rows("Burrow dive", _contact.observe(shown, after, _visible), [["earth_floor", TARGET]])
	before = after
	after = before.duplicate(true)
	after["enemies"][0].merge({"pos": HERO, "burrowed": false}, true)
	after["player"].merge({"pos": TARGET, "hp": TEST_HP - TEST_LOSS}, true)
	step = {"kind": "erupt", "actor_key": "enemy_1", "from": TARGET, "to": HERO, "state_after": after}
	_contact.begin(before, step)
	shown = {"burrow_grub_motion": {"enemy_1": {"phase": 1.0}}, "unit_world_positions": {"player": Vector2.ONE}}
	_expect(_contact.observe(shown, before, _visible).is_empty(), "An airborne victim's hit waits for the number.")
	shown.erase("unit_world_positions")
	_rows("Burrow erupt with health loss", _contact.observe(shown, after, _visible), [["earth_hit", HERO]])
	after["player"]["hp"] = TEST_HP
	_contact.begin(before, step)
	_rows("Burrow erupt without health loss", _contact.observe(shown, after, _visible), [["earth_floor", HERO]])
	for mode: String in ["grow_bramble", "bramble_expiry"]:
		_contact.begin(_state)
		shown = {"effect": {"en04_mechanic": mode, "tiles": [TARGET] if mode == "grow_bramble" else [], "expired_bramble": [{"pos": TARGET}] if mode == "bramble_expiry" else []}}
		_rows(mode, _contact.observe(shown, _state, _visible), [["earth_floor", TARGET]])

func _overlap() -> void:
	var effect: Dictionary = {"kind": "aoe", "intent_id": "bile_burst", "element": "earth", "tiles": [TARGET], "to": TARGET}
	_expect(Burst.select_enemy(effect) == "earth", "Shale Burst lands the Earth burst (fx-22 director decision).")
	_contact.begin(_state)
	var original: Dictionary = Burst.area_spec("earth", effect)
	_contact.reserve([original], _state["grid"], _visible)
	var added: Array[Dictionary]
	_contact.append_attack(added, {"kind": "melee", "to": TARGET}, _state, _state, _visible)
	var shown: Dictionary = {"surface_feedback_events": [{"kind": "surface_removed", "surface": "ice", "tile": TARGET, "sequence": 1}]}
	_expect(added.is_empty() and _contact.observe(shown, _state, _visible).is_empty(), "An fx-12 tile blocks both contact and surface duplicates.")
	_expect(shown["surface_feedback_events"][0].get(Contact.REPLACED) == "break", "Existing fx-12 coverage also masks break fragments.")
	var shot := {"kind": "ranged", "element": "none", "to": TARGET, "base_card_id": "hurl_spear"}
	_contact.begin(_state)
	if not ResourceLoader.exists(Contact.SHOT_PATH):
		_contact._shot = MappedShot
		print("FX-17 SHOT: FX-14 resolver boundary simulated; renderer absent on the base.")
	_contact.append_attack(added, shot, _state, _state, _visible)
	_expect(added.is_empty() and Contact.suppresses_decal(shot, TARGET), "A mapped shot reserves its tile and skips the old contact decal.")
	shown = {"surface_feedback_events": [{"kind": "force_collision", "tile": TARGET, "sequence": 2}]}
	_expect(_contact.observe(shown, _state, _visible).is_empty(), "A mapped shot also excludes the collision fallback at its tile.")
	_contact._shot = null

func _reduced() -> void:
	var board: Control = (load("res://scripts/combat_board_view.gd") as Script).new()
	root.add_child(board)
	board.set_combat_state(_state, [], [], HERO, "", "", {}, {}, {"reduced_motion": true})
	board.present_tile_bursts([Contact.spec("earth", TARGET, false)], _state, _state, true)
	var player: Burst = board._tile_bursts
	_expect(player._stamps.size() == 2, "Reduced motion spawns just one pair.")
	for stamp: Burst.Stamp in player._stamps:
		_expect(stamp.sample.x == int(Burst.metadata()["reduced_motion_frame"]) and stamp.tile == TARGET, "Reduced motion uses the same fx-12 still and tile.")
	board.clear_tile_bursts()
	board.present_tile_bursts([Contact.spec("earth", TARGET, false)], _state, _state, false)
	var duration: float = float(Burst.metadata()["frames"]) / float(Burst.metadata()["fps"])
	var sample_margin: float = 0.001
	player.advance(duration - sample_margin, -1)
	_expect(player._stamps.size() == 2, "The burst remains until the last authored frame.")
	player.advance(sample_margin * 2.0, -1)
	_expect(not player.has_active(), "The burst ends after 13 frames at 30 fps.")
	board.queue_free()


func _check_pacing() -> void:
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = arguments.find("--pacing-root")
	if index == -1: return
	var folders: PackedStringArray = arguments.slice(index + 1)
	for take: String in PACING_CASES:
		var base: Dictionary
		var current: Dictionary
		for directory: String in folders:
			var base_path: String = directory.path_join("base").path_join(take).path_join("take.json")
			var current_path: String = directory.path_join("after").path_join(take).path_join("take.json")
			if FileAccess.file_exists(base_path) and FileAccess.file_exists(current_path):
				base = JSON.parse_string(FileAccess.get_file_as_string(base_path))
				current = JSON.parse_string(FileAccess.get_file_as_string(current_path))
				break
		var old_frames: int = int(base.get("action_frames", -1))
		var new_frames: int = int(current.get("action_frames", -1))
		_expect(old_frames > 0 and old_frames == new_frames, take + " action length matches the base.")
		print("FX-17 PACING %s: base=%d, after=%d" % [take, old_frames, new_frames])
