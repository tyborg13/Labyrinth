extends RefCounted
## Optional per-NPC crop in the shared 255px sprite coordinate system.
## Kept separate so DialogueBoxView can use the same data after dlg-01 lands.
static func region(definition: Dictionary, source: Vector2) -> Rect2:
	var authored: Variant = definition.get("portrait_region", null)
	if authored is Array and authored.size() == 4:
		var scale: Vector2 = source / 255.0
		return Rect2(Vector2(float(authored[0]), float(authored[1])) * scale, Vector2(float(authored[2]), float(authored[3])) * scale)
	var crop: float = source.x * 0.56
	return Rect2(Vector2((source.x - crop) * 0.5, source.y * 0.04), Vector2(crop, crop))
