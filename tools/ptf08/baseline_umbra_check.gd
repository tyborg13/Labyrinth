extends SceneTree

# Read-only HEAD snapshots supplied by the commands documented in result.md.
const BASELINE_DIR: String = "/private/tmp/labyrinth_codex/ptf-08"
const EXPECTED_PATH: String = "res://assets/art/icons/umbra_presence.png"

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var baseline: Script = load(BASELINE_DIR.path_join("baseline_run_scene.gd"))
	var slots: Script = load(BASELINE_DIR.path_join("baseline_turn_order_slots.gd"))
	var scene: Node = baseline.new()
	var entry: Dictionary = {"kind": "enemy", "type": "crawler", "actor_key": "baseline_umbra", "hidden_by_umbra": true}
	var slot: Control = slots.update(scene, entry, 0)
	var parts: Dictionary = slot.get_meta("perf03_retained_parts")
	var texture: Texture2D = (parts["portrait"] as TextureRect).texture
	var existing_mismatch: bool = texture != null and texture.resource_path != EXPECTED_PATH and str(texture.get_meta("asset_source_path", "")) == EXPECTED_PATH
	print("PTF08 HEAD BASELINE UMBRA: %s (source=%s; resource_path=%s)" % ["EXISTING ASSERTION MISMATCH" if existing_mismatch else "NOT REPRODUCED", str(texture.get_meta("asset_source_path", "")), texture.resource_path])
	slot.free()
	scene.free()
	quit(0 if existing_mismatch else 1)
