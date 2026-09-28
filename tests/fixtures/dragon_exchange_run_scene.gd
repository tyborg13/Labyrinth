extends "res://scripts/run_scene.gd"
var heard_cues: Array[String]
var fail_next_ack: bool = false
var blocked_ack_observed: bool = false

func _play_sfx(entry: Dictionary) -> float:
	heard_cues.append(str(entry.get("id","")))
	return super._play_sfx(entry)

func _reconcile_progression_analytics_outbox() -> bool:
	if not fail_next_ack: return super._reconcile_progression_analytics_outbox()
	fail_next_ack = false
	# Fail only the acknowledgment after the durable purchase and JSONL append.
	var blocked: String = ProjectSettings.globalize_path(ProgressionStore._storage_path+".tmp")
	assert(DirAccess.make_dir_absolute(blocked)==OK)
	var result: bool = super._reconcile_progression_analytics_outbox()
	blocked_ack_observed = not result
	assert(DirAccess.remove_absolute(blocked)==OK)
	return result
