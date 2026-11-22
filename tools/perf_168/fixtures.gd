extends RefCounted

const Run = preload("res://scripts/run_engine.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Store = preload("res://scripts/progression_store.gd")
const Boons = preload("res://scripts/opening_boon_rules.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")

const CASES: Array[String] = ["combat", "elite", "guardian", "campfire", "event", "scavenger", "treasure", "graftwright"]
const SEED: int = 83
const WALLET: int = 720
const PAINTING_EVENT: String = "starving_pilgrim"
const STOCK: Array[String] = [
	"grave_mortar", "icicle_lance", "dawnstep", "boiled_leather", "dust_tabi",
	"duelist_rapier", "crimson_draught", "nail_bomb", "jaw_trap",
]

static func make(kind: String, index: int) -> Dictionary:
	var engine := Run.new()
	var profile: Dictionary = Store.set_embers(Store.default_data(), WALLET)
	profile["guided_combat_tutorial"] = {"version": 2, "status": "dismissed", "completed_steps": []}
	var state: Dictionary = engine.create_new_run(SEED, profile)
	if Boons.pending(state): state = Boons.choose(engine, state, "")
	state["run_index"] = index * CASES.size() + CASES.find(kind) + 1
	var moves: Array[Vector2i] = engine.available_moves(state)
	if moves.is_empty(): return {}
	var target: Vector2i = moves.front()
	var room: Dictionary = Graph.room(state, target)
	room.merge({"type": "special" if kind == "elite" else kind, "cleared": false,
		"merchant_kind": "", "npcs": [], "element": "none"}, true)
	var boss: String = str(Graph.section(state, 0)["boss_id"])
	var element: String = Bosses.element_for_boss(boss)
	match kind:
		"combat":
			room["element"] = "fire"
		"elite":
			room.merge({"element": element, "special_type": "warband", "special_variant": element}, true)
		"guardian":
			var guardian: Dictionary = Guardians.for_boss(boss)
			room.merge({"element": guardian["element"], "boss_id": boss,
				"guardian_id": guardian["id"], "guardian_relic": guardian["relic"]}, true)
		"event":
			room["event_id"] = PAINTING_EVENT
		"scavenger":
			room["merchant_kind"] = kind
			room["npcs"] = [{"id": kind, "pos": Vector2i(3, 4)}]
			room[Run.MERCHANT_STOCK_KEY] = STOCK.duplicate()
	var expected: Dictionary = engine.move_to_pre_battle(state, target)
	return {"state": state, "target": target, "expected": expected}

static func expected_mode(kind: String) -> String:
	match kind:
		"combat", "elite", "guardian": return "pre_battle"
		"scavenger": return "room"
		_: return kind
