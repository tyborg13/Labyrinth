extends "res://tests/sfx_sync_harness.gd"

func _program_frame_profiles() -> Array[String]:
	var profiles: Array[String]
	profiles.assign(super._program_frame_profiles().slice(2, 4))
	return profiles

func _verify_program_lengths() -> void:
	# The final profile child verifies the unchanged complete sample set once.
	pass
