extends "res://tools/hitch_census/driver.gd"
## CPU-only attribution adapter; inherits the census policy and whole-run loop.
## The base validation path supplies synthetic post-draw signals headlessly.

func _initialize() -> void:
	super._initialize()
	validate_only = true
	headless_smoke = true

func _validate() -> void:
	if DisplayServer.get_name() != "headless" or driver_name != "whole" or stop_after <= 0:
		push_error("PERF109: headless whole requires a fixed --stop-after decision count")
		quit(2)
		return
	print("PERF109: CPU-only whole run; synthetic draw signals, no renderer proof")
	await _whole()
