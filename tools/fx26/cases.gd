extends RefCounted

const Fixtures23 = preload("res://tools/fx23/cases.gd")
const AIM := Fixtures23.TARGET
const SECOND := Fixtures23.CHAIN_TARGET
const THIRD := Vector2i(7, 2)
const PARKED := Vector2i(7, 6)
const RELAY := Vector2i(6, 2)
const CRAG_FUEL := Vector2i(4, 3)
const CRAG_FUEL_HP: int = 3
const TERRAIN_CASE: String = "craghide_groundsplit"
const FLOOR_STAGE: String = "eclipse"
const CHAIN_CARD: String = "chain_bolt"
const REEL: String = "recording"
const AREAS: Dictionary = {
	"ice": ["rime_shard", "lance"],
	"air": ["squall_shot", "blade"],
	"earth": ["grave_dust_satchel", "rock"],
	"shadow": ["rime_shard", "shade"], # Resolver fixture only. Live Shadow areas are dragons.
	"fire": ["cinder_bloom", "ember"],
	"lightning": ["volt_surge", "spark"],
	"none": ["nail_bomb", "pale"],
}
const CHAIN_CASES: Array[String] = ["chain", "chain_hidden", "chain_reduced", "chain_relay"]
const NATIVE_CASES: Array[String] = ["ice_hit", "air_hit", "earth_hit", "shadow_hit", "chain"]

static func hide_last(state: Dictionary) -> void:
	var umbra: Dictionary = state["umbra"]
	umbra["stage"] = FLOOR_STAGE
	umbra["stage_reduction"] = 0
	var lights: Array[Dictionary] = [
		{"id": "fx26-first", "pos": AIM, "radius": 0, "remaining_activations": -1},
		{"id": "fx26-second", "pos": SECOND, "radius": 0, "remaining_activations": -1},
	]
	umbra["light_sources"] = lights
