extends RefCounted

static func entries(id: String, historical: Dictionary) -> Array:
	var expected: Array = (historical[id] as Array).duplicate(true)
	if id == "immolation":
		# CBT-01 (5e20c1099) added adjacent damage before the existing Detonate.
		# Retain the pre-glossary capture; compose the new damage/pattern prefix
		# from independent historical entries instead of the formatter under test.
		var pattern: Dictionary = expected.pop_at(2)
		expected.insert(1, (historical["quick_stab"][1] as Dictionary).duplicate(true))
		expected.insert(2, pattern)
	return expected
