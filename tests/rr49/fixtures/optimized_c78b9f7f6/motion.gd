extends RefCounted

static func point(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))
