extends "res://scripts/merchant_acquisition_effect.gd"

const Signage = preload("res://scripts/scavenger_signage.gd")

var banner_parchment: Rect2
var banner_gap: float = 10.0

func _update_pose() -> void:
	super._update_pose()
	if reduced_motion or proxy == null:
		return
	var ware: Rect2 = get_global_transform().affine_inverse() * Signage.ware_rect(proxy)
	if banner_parchment.position.x < ware.end.x and banner_parchment.end.x > ware.position.x:
		proxy.position.y += maxf(0.0, banner_parchment.end.y + banner_gap - ware.position.y)
