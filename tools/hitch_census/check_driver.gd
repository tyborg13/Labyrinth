extends "res://tools/hitch_census/driver.gd"
## Bounded headless integration, using the identical driver and observer paths.
## Always pass --validate; the trace header remains native=false.
func _validate() -> void:
	if driver_name == "whole":
		await _whole()
	elif driver_name == "demo":
		var session := DemoSession.new()
		session.host = self
		root.add_child(session)
		session.run()
	else:
		await super._validate()
