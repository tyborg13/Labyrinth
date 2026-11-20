extends RefCounted
## Restore client coordinates inside the current monitor's usable area.

const DEFAULT_WINDOWED_SIZE := Vector2i(1600, 900)
const MINIMUM_WINDOWED_SIZE := Vector2i(960, 540)
const WINDOW_SCREEN_MARGIN := Vector2i(64, 64)
const WINDOWS_TITLE_FALLBACK_PX: int = 40

static func safe_windowed_size(requested: Vector2i, usable_screen_size: Vector2i) -> Vector2i:
	var bounded_usable := Vector2i(maxi(1, usable_screen_size.x), maxi(1, usable_screen_size.y))
	var margin := Vector2i(
		mini(WINDOW_SCREEN_MARGIN.x, maxi(0, bounded_usable.x - 640)),
		mini(WINDOW_SCREEN_MARGIN.y, maxi(0, bounded_usable.y - 360))
	)
	var maximum: Vector2i = bounded_usable - margin
	var minimum: Vector2i = MINIMUM_WINDOWED_SIZE.min(maximum)
	var candidate: Vector2i = requested if requested.x > 0 and requested.y > 0 else DEFAULT_WINDOWED_SIZE
	return candidate.clamp(minimum, maximum)

static func screen_rect(display: Object, screen: int) -> Rect2i:
	return Rect2i(display.screen_get_position(screen), display.screen_get_size(screen))

static func screen_rects(display: Object) -> Array[Rect2i]:
	var screens: Array[Rect2i]
	for index: int in display.get_screen_count():
		screens.append(screen_rect(display, index))
	return screens

static func screen_neighbors(screens: Array[Rect2i], screen: int) -> Array:
	var neighbors: Array = []
	var origin: Vector2i = screens[screen].position
	for index: int in screens.size():
		if index == screen or not screens[index].has_area():
			continue
		var rect: Rect2i = screens[index]
		var offset: Vector2i = rect.position - origin
		neighbors.append([offset.x, offset.y, rect.size.x, rect.size.y])
	return neighbors

static func restore_native_window(settings: Dictionary, display: Object) -> bool:
	var screens: Array[Rect2i] = screen_rects(display)
	var usable_rects: Array[Rect2i]
	for index: int in screens.size():
		usable_rects.append(display.screen_get_usable_rect(index))
	var rect: Rect2i = restore_rect(settings, screens, usable_rects, display.get_primary_screen(), _decoration_insets(display))
	if not rect.has_area():
		return false
	if display.window_get_size() != rect.size:
		display.window_set_size(rect.size)
	if display.window_get_position() != rect.position:
		display.window_set_position(rect.position)
	return true

static func restore_rect(
	settings: Dictionary, screens: Array[Rect2i], usable_rects: Array[Rect2i], primary_screen: int,
	insets: Vector4i = Vector4i.ZERO
) -> Rect2i:
	if screens.is_empty():
		return Rect2i()
	var saved_screen: int = _find_saved_screen(settings, screens)
	if saved_screen >= 0:
		var bounds: Rect2i = _client_bounds(usable_rects[saved_screen], insets)
		var saved_size: Array = settings["window_size"]
		var requested := Vector2i(saved_size[0], saved_size[1])
		if bounds.has_area():
			var size: Vector2i = requested.min(bounds.size)
			var saved_position: Array = settings["window_position"]
			var position: Vector2i = screens[saved_screen].position + Vector2i(saved_position[0], saved_position[1])
			return Rect2i(position.clamp(bounds.position, bounds.end - size), size)
		return Rect2i()
	var fallback: Rect2i = _client_bounds(usable_rects[clampi(primary_screen, 0, screens.size() - 1)], insets)
	if not fallback.has_area():
		return Rect2i()
	var size: Vector2i = safe_windowed_size(DEFAULT_WINDOWED_SIZE, fallback.size)
	return Rect2i(fallback.position + (fallback.size - size) / 2, size)

static func _find_saved_screen(settings: Dictionary, screens: Array[Rect2i]) -> int:
	if not settings.has("window_screen_size"):
		return -1
	var dimensions: Array = settings["window_screen_size"]
	var saved_size := Vector2i(dimensions[0], dimensions[1])
	var saved_index: int = settings["window_screen"]
	var saved_neighbors: Array = settings.get("window_screen_neighbors", [])
	var best_screen: int = -1
	var best_matches: int = -1
	for candidate: int in screens.size():
		if screens[candidate].size != saved_size:
			continue
		var matches: int = 0
		for neighbor: Array in screen_neighbors(screens, candidate):
			if saved_neighbors.has(neighbor):
				matches += 1
		if matches > best_matches or (matches == best_matches and candidate == saved_index):
			best_screen = candidate
			best_matches = matches
	return best_screen

static func _decoration_insets(display: Object) -> Vector4i:
	var client_position: Vector2i = display.window_get_position()
	var client_size: Vector2i = display.window_get_size()
	var outer_position: Vector2i = display.window_get_position_with_decorations()
	var outer_size: Vector2i = display.window_get_size_with_decorations()
	var leading := Vector2i.ZERO
	var trailing := Vector2i.ZERO
	var client := Rect2i(client_position, client_size)
	var outer := Rect2i(outer_position, outer_size)
	if client.has_area() and outer.encloses(client):
		leading = client.position - outer.position
		trailing = outer.end - client.end
	if leading.y == 0 and display.get_name() == "Windows":
		leading.y = WINDOWS_TITLE_FALLBACK_PX
	return Vector4i(leading.x, leading.y, trailing.x, trailing.y)

static func _client_bounds(usable: Rect2i, insets: Vector4i) -> Rect2i:
	var leading := Vector2i(insets.x, insets.y)
	var trailing := Vector2i(insets.z, insets.w)
	return Rect2i(usable.position + leading, (usable.size - leading - trailing).max(Vector2i.ZERO))
