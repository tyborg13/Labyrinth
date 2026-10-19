extends "res://tests/rr10/samples.gd"

## Preserve the normal presented record and also sample its continuous pose.
## This keeps pixel rounding from turning a small positive key into zero travel.
const PixelClock = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")

func record(rig: Node2D, view: String, clip: String, phase: float, frame: int, kind: String) -> Dictionary:
	var row: Dictionary = super.record(rig, view, clip, phase, frame, kind)
	var sample_phase: float = phase
	if kind == "presented":
		var data: Dictionary = Motion.data_for(rig.layout)
		sample_phase = PixelClock.phase_for(data, clip, phase)
		rig.apply_authored_pose(clip, sample_phase)
		row["direction_bones"] = super.record(rig, view, clip, sample_phase, frame, kind)["bones"]
		rig.apply_pose(clip, phase)
	else:
		row["direction_bones"] = row["bones"].duplicate(true)
	row["direction_phase"] = sample_phase
	return row

func proof_geometry(data: Dictionary) -> Dictionary:
	if data["clips"].get("move", {}).has("gait"):
		return await preload("res://tests/gait01/board_geometry.gd").measure(self, str(data["creature"]))
	return await super.proof_geometry(data)
