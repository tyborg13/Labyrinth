extends RefCounted
## One strip owns its slots. Reuse only the same portrait source/visibility;
## content and the fresh portrait clock are reapplied by the original factory.
var _available: Array[Control]

func begin(strip: Control) -> void:
	_available.clear()
	for child: Node in strip.get_children():
		if child is Control and child.has_meta("landing_strip_portrait_source"):
			# Free the final names before actors exchange positions in the strip.
			child.name = "RetainedLandingStripSlot_%d" % _available.size()
			_available.append(child as Control)
		else:
			strip.remove_child(child)
			child.queue_free()

func take(source: Array) -> Control:
	for slot: Control in _available:
		if slot.get_meta("landing_strip_portrait_source") == source:
			_available.erase(slot)
			# Reproduce factory child order, including overlapping brush strokes.
			slot.get_parent().move_child(slot, slot.get_parent().get_child_count() - 1)
			return slot
	return null

func finish(strip: Control) -> void:
	for slot: Control in _available:
		strip.remove_child(slot)
		slot.queue_free()
	_available.clear()
