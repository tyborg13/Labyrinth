extends "res://tests/sfx_sync_harness.gd"

func _program_frame_profiles() -> Array[String]:
	var profiles: Array[String]
	profiles.assign(super._program_frame_profiles().slice(4, 5))
	return profiles
