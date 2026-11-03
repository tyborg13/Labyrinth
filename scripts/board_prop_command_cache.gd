extends RefCounted

# Each retained scene canvas owns these slots. Keep the original commands in
# their original order (no batching, shader or extra CanvasItem). Animated parts,
# terrain bars, tooltips, and bodies remain live at their existing paint positions.
const Art = preload("res://scripts/combat_art_treatment.gd")
var _slots: Dictionary = {}
var _used_slots: Dictionary = {}
var recording: bool = false
var commands: Array = []
var builds: int = 0
var hits: int = 0
var enabled: bool = true

func begin_draw() -> void:
	_used_slots.clear()

func end_draw() -> void:
	for slot: String in _slots.keys():
		if not _used_slots.has(slot): _slots.erase(slot)

func paint(board: Control, slot: String, inputs: Array, build: Callable) -> void:
	_used_slots[slot] = true
	var entry: Dictionary = _slots.get(slot, {})
	var snapshot: Array = _snapshot(inputs)
	if enabled and not entry.is_empty() and entry["inputs"] == snapshot:
		hits += 1
	else:
		commands = []
		recording = true
		build.call()
		recording = false
		entry = {"inputs": snapshot, "commands": commands}
		_slots[slot] = entry
		builds += 1
	for command: Array in entry["commands"]: board._submit_prop_command(command)

# Resources are mutable references even inside duplicate(true). Capture the
# geometry used by world(), including nested atlas sources, as immutable values.
func _snapshot(value: Variant) -> Variant:
	if value is Texture2D:
		var texture: Texture2D = value
		var geometry: Array = [texture.get_instance_id(), texture.get_rid(), texture.get_size()]
		if texture is AtlasTexture:
			geometry.append_array([texture.region, texture.margin, texture.filter_clip, _snapshot(texture.atlas)])
		return geometry
	if value is Array:
		var result: Array = []
		for entry: Variant in value: result.append(_snapshot(entry))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[key] = _snapshot(value[key])
		return result
	return value

func polygon(points: PackedVector2Array, colors: PackedColorArray, uvs: PackedVector2Array, texture: Texture2D, profile: int) -> void:
	var tagged: PackedVector2Array = uvs.duplicate()
	for index: int in range(tagged.size()): tagged[index].x += Art.UV_LANE * float(profile)
	commands.append(["polygon", points, colors, tagged, texture])

# Exact CombatArtTreatment.draw_rect construction. The equivalence test compares
# the emitted primitive arguments against the original implementation, cold/warm.
func world(texture: Texture2D, rect: Rect2, tint: Color, profile: int, source: Rect2, art_enabled: bool) -> void:
	if not art_enabled or profile == 0:
		commands.append(["texture", texture, rect, tint] if source.size == Vector2.ZERO else ["region", texture, rect, source, tint])
		return
	if texture == null or rect.size.x <= 0.0 or rect.size.y <= 0.0: return
	var sampled: Texture2D = texture
	var source_rect: Rect2 = source if source.size != Vector2.ZERO else Rect2(Vector2.ZERO, texture.get_size())
	if texture is AtlasTexture:
		var atlas: AtlasTexture = texture as AtlasTexture
		if atlas.atlas == null: return
		sampled = atlas.atlas
		var clipped: Rect2 = source_rect.intersection(Rect2(atlas.margin.position, atlas.region.size))
		if not clipped.has_area(): return
		rect = Rect2(rect.position + (clipped.position - source_rect.position) / source_rect.size * rect.size, clipped.size / source_rect.size * rect.size)
		source_rect = Rect2(atlas.region.position + clipped.position - atlas.margin.position, clipped.size)
	var uv := Rect2(source_rect.position / sampled.get_size(), source_rect.size / sampled.get_size())
	polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([tint]), PackedVector2Array([uv.position, Vector2(uv.end.x, uv.position.y), uv.end, Vector2(uv.position.x, uv.end.y)]), sampled, profile)
