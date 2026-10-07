extends RefCounted
class_name AssetLoader

const TEXTURE_EXTENSIONS: PackedStringArray = ["svg", "png", "webp", "jpg"]
const PNG_FIRST_TEXTURE_EXTENSIONS: PackedStringArray = ["png", "svg", "webp", "jpg"]
const AUDIO_EXTENSIONS: PackedStringArray = ["wav", "ogg"]
const DEFAULT_ALPHA_POLYGON_THRESHOLD: float = 0.08
const DEFAULT_ALPHA_POLYGON_SIMPLIFY_EPSILON: float = 3.0
const DEFAULT_ALPHA_POLYGON_MIN_AREA: float = 8.0
const CASTLE_CONTROL_ACCENT_HUE_MAX: float = 0.12
const CASTLE_CONTROL_ACCENT_HUE_WRAP_MIN: float = 0.92
const CASTLE_CONTROL_ACCENT_MIN_SATURATION: float = 0.40
const CASTLE_CONTROL_ACCENT_MIN_VALUE: float = 0.16
const CASTLE_CONTROL_ACCENT_MIN_RED_DOMINANCE: float = 0.10

static var _alpha_polygon_cache: Dictionary = {}
static var _castle_control_texture_cache: Dictionary = {}
static var _flipped_texture_cache: Dictionary = {}
static var _outline_clean_texture_cache: Dictionary = {}
static var _scaled_texture_cache: Dictionary = {}
static var _texture_used_rect_cache: Dictionary = {}
static var _audio_cache: Dictionary = {}
static var _looping_audio_cache: Dictionary = {}
static var _font_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}

# The worker owns only its newly decoded CPU Image. Texture creation, source
# tagging and the shared caches stay on the main thread. The drain joins the
# outstanding task on tree shutdown; cancellation never publishes into a freed
# scene and every pool task is reclaimed, including interrupted transitions.
class SourceImageResult extends RefCounted:
	var value: Variant
	var paths: PackedStringArray
	var images: Array[Image]
	var cancel_mutex := Mutex.new()
	var cancel_requested: bool = false

	func cancel() -> void:
		cancel_mutex.lock()
		cancel_requested = true
		cancel_mutex.unlock()

	func is_cancelled() -> bool:
		cancel_mutex.lock()
		var cancelled: bool = cancel_requested
		cancel_mutex.unlock()
		return cancelled

class SourceImageDrain extends Node:
	var task_id: int = -1
	var result: SourceImageResult

	func join() -> void:
		if task_id >= 0:
			WorkerThreadPool.wait_for_task_completion(task_id)
			task_id = -1

	func _exit_tree() -> void:
		if result != null: result.cancel()
		join()

static func prepare_textures_for(root: Node, manifest: Dictionary, present_frame: Callable, still_active: Callable = Callable()) -> void:
	var drain := SourceImageDrain.new()
	drain.name = "SourceImageDecodeDrain"
	drain.process_mode = Node.PROCESS_MODE_ALWAYS
	drain.result = SourceImageResult.new()
	root.add_child(drain)
	var source_paths: Dictionary = {}
	for path: String in manifest:
		if _texture_cache.has(path): continue
		var source_first: bool = bool(manifest[path])
		if FileAccess.file_exists(path) and (source_first or _should_prefer_source_file(path, TEXTURE_EXTENSIONS) or not ResourceLoader.exists(path)):
			source_paths[path] = drain.result.paths.size()
			drain.result.paths.append(path)
	if not drain.result.paths.is_empty():
		# One worker decodes the batch continuously instead of charging a whole
		# display interval per small asset. Inputs remain immutable; the result
		# array transfers to the main thread only after the pool task is joined.
		drain.task_id = WorkerThreadPool.add_task(_decode_owned_source_images.bind(drain.result), false, "Decode initial source images")
	var slice_started: int = Time.get_ticks_usec()
	for path: String in manifest:
		if still_active.is_valid() and not bool(still_active.call()):
			drain.result.cancel()
			break
		if _texture_cache.has(path) or source_paths.has(path): continue
		load_texture_source_first(path) if bool(manifest[path]) else load_texture(path)
		if Time.get_ticks_usec() - slice_started >= 4000:
			await present_frame.call()
			if not is_instance_valid(drain) or not drain.is_inside_tree(): return
			slice_started = Time.get_ticks_usec()
	if drain.task_id >= 0:
		while not WorkerThreadPool.is_task_completed(drain.task_id):
			await present_frame.call()
			if not is_instance_valid(drain) or not drain.is_inside_tree(): return
			if still_active.is_valid() and not bool(still_active.call()): drain.result.cancel()
		drain.join()
	if not drain.result.is_cancelled():
		slice_started = Time.get_ticks_usec()
		for path: String in source_paths:
			if still_active.is_valid() and not bool(still_active.call()): break
			# Keep an identity published by another main-thread consumer while
			# decoding, and use the existing fallback on a failed source decode.
			if not _texture_cache.has(path):
				var image: Image = drain.result.images[int(source_paths[path])]
				if image != null:
					_texture_cache[path] = _tag_texture_source(ImageTexture.create_from_image(image), path)
				else:
					load_texture_source_first(path) if bool(manifest[path]) else load_texture(path)
			if Time.get_ticks_usec() - slice_started >= 4000:
				await present_frame.call()
				if not is_instance_valid(drain) or not drain.is_inside_tree(): return
				slice_started = Time.get_ticks_usec()
	drain.queue_free()

# Producers must create private CPU data only: no scene nodes, GPU objects or
# shared-cache mutation. The main-thread caller owns publication after the join.
static func prepare_cpu_value_for(root: Node, producer: Callable, present_frame: Callable, still_active: Callable) -> Variant:
	var drain := SourceImageDrain.new()
	drain.name = "OwnedCpuPreparationDrain"
	drain.result = SourceImageResult.new()
	root.add_child(drain)
	drain.task_id = WorkerThreadPool.add_task(_produce_owned_cpu_value.bind(producer, drain.result), false, "Prepare owned CPU asset")
	while not WorkerThreadPool.is_task_completed(drain.task_id):
		await present_frame.call()
		if not is_instance_valid(drain) or not drain.is_inside_tree(): return null
		if not bool(still_active.call()): drain.result.cancel()
	drain.join()
	var value: Variant = null if drain.result.is_cancelled() else drain.result.value
	drain.queue_free()
	return value

static func _produce_owned_cpu_value(producer: Callable, result: SourceImageResult) -> void:
	if not result.is_cancelled(): result.value = producer.call()

static func prepare_audio_for(root: Node, paths: PackedStringArray, present_frame: Callable, still_active: Callable, prepare_loop: bool = false) -> void:
	for path: String in paths:
		if _audio_cache.has(path) and (not prepare_loop or _looping_audio_cache.has(_audio_cache[path])): continue
		if _audio_cache.has(path):
			if prepare_loop: looping_audio_copy(_audio_cache[path] as AudioStream)
			continue
		# Imported resources remain on the main thread. Only the same raw-file
		# route used by load_audio_stream creates privately owned worker data.
		if not _should_prefer_source_file(path, AUDIO_EXTENSIONS) and ResourceLoader.exists(path):
			var imported: AudioStream = load_audio_stream(path)
			if prepare_loop: looping_audio_copy(imported)
			continue
		var result: Variant = await prepare_cpu_value_for(root, _prepare_owned_audio.bind(path, prepare_loop), present_frame, still_active)
		if not bool(still_active.call()) or not result is Dictionary: return
		var stream: AudioStream = result.get("stream") as AudioStream
		if stream != null and not _audio_cache.has(path): _audio_cache[path] = stream
		if prepare_loop and stream != null and _audio_cache.get(path) == stream:
			_looping_audio_cache[stream] = result.get("looped")

static func _prepare_owned_audio(path: String, prepare_loop: bool) -> Dictionary:
	var stream: AudioStream = _load_audio_stream_from_file(path)
	return {"stream": stream, "looped": _new_looping_audio_copy(stream) if prepare_loop and stream != null else null}

static func looping_audio_copy(resource: AudioStream) -> AudioStream:
	if resource == null: return null
	if not _looping_audio_cache.has(resource): _looping_audio_cache[resource] = _new_looping_audio_copy(resource)
	return _looping_audio_cache[resource] as AudioStream

static func _new_looping_audio_copy(resource: AudioStream) -> AudioStream:
	var looped: AudioStream = resource.duplicate() as AudioStream
	if looped is AudioStreamWAV:
		var wav: AudioStreamWAV = looped as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = maxi(1, int(round(wav.get_length() * float(wav.mix_rate))))
	return looped

static func _decode_owned_source_images(result: SourceImageResult) -> void:
	for path: String in result.paths:
		if result.is_cancelled(): return
		result.images.append(_load_source_image(path))

static func add_texture_constants(manifest: Dictionary, script: Script) -> void:
	# Constants are the owning loader's asset manifest. Do not walk preloaded
	# scripts: that would eagerly retain unrelated content and whole enemy rigs.
	_add_texture_paths(manifest, script.get_script_constant_map())

static func _add_texture_paths(manifest: Dictionary, value: Variant) -> void:
	if value is String:
		var path: String = value
		if path.begins_with("res://") and TEXTURE_EXTENSIONS.has(path.get_extension().to_lower()) and not manifest.has(path):
			manifest[path] = false
	elif value is Dictionary:
		for entry: Variant in value.values(): _add_texture_paths(manifest, entry)
	elif value is Array or value is PackedStringArray:
		for entry: Variant in value: _add_texture_paths(manifest, entry)

static func load_texture(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _tag_texture_source(_texture_cache.get(path, null) as Texture2D, path)
	if _should_prefer_source_file(path, TEXTURE_EXTENSIONS):
		var source_texture: Texture2D = _load_texture_from_file(path)
		if source_texture != null:
			_tag_texture_source(source_texture, path)
			_texture_cache[path] = source_texture
			return source_texture
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is Texture2D:
			var loaded_texture: Texture2D = _tag_texture_source(loaded as Texture2D, path)
			_texture_cache[path] = loaded_texture
			return loaded_texture
	var texture: Texture2D = _load_texture_from_file(path)
	_tag_texture_source(texture, path)
	_texture_cache[path] = texture
	return texture

static func load_texture_source_first(path: String) -> Texture2D:
	# Source-first loading keeps direct repository launches working after a pull,
	# before Godot has rebuilt newly added entries under .godot/imported. Exported
	# builds fall back to ResourceLoader when the raw source is not packaged.
	if path.is_empty():
		return null
	if _texture_cache.has(path):
		return _tag_texture_source(_texture_cache.get(path, null) as Texture2D, path)
	var source_texture: Texture2D = _load_texture_from_file(path)
	if source_texture != null:
		_tag_texture_source(source_texture, path)
		_texture_cache[path] = source_texture
		return source_texture
	return load_texture(path)

static func _tag_texture_source(texture: Texture2D, path: String) -> Texture2D:
	# ImageTexture instances created from source files do not retain a resource_path.
	# Keep the logical asset identity on every load path so generated caches use the
	# same key in editor, headless, and exported builds.
	if texture != null and not path.is_empty():
		texture.set_meta("asset_source_path", path)
	return texture

static func load_audio_stream(path: String, loop: bool = false) -> AudioStream:
	if path.is_empty():
		return null
	if _audio_cache.has(path):
		return _configure_audio_loop(_audio_cache.get(path, null) as AudioStream, loop)
	if _should_prefer_source_file(path, AUDIO_EXTENSIONS):
		var source_stream: AudioStream = _load_audio_stream_from_file(path)
		if source_stream != null:
			_audio_cache[path] = source_stream
			return _configure_audio_loop(source_stream, loop)
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is AudioStream:
			_audio_cache[path] = loaded
			return _configure_audio_loop(loaded as AudioStream, loop)
	var stream: AudioStream = _load_audio_stream_from_file(path)
	_audio_cache[path] = stream
	return _configure_audio_loop(stream, loop)

static func _load_texture_from_file(path: String) -> Texture2D:
	var image: Image = _load_source_image(path)
	return ImageTexture.create_from_image(image) if image != null else null

static func _load_source_image(path: String) -> Image:
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var error: Error
	match path.get_extension().to_lower():
		"png":
			error = image.load_png_from_buffer(bytes)
		"jpg":
			error = image.load_jpg_from_buffer(bytes)
		"webp":
			error = image.load_webp_from_buffer(bytes)
		"svg":
			error = image.load_svg_from_buffer(bytes)
		_:
			error = ERR_FILE_UNRECOGNIZED
	if error != OK or image.is_empty():
		return null
	return image

static func _load_audio_stream_from_file(path: String) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"wav":
			return AudioStreamWAV.load_from_file(path)
		"ogg":
			return AudioStreamOggVorbis.load_from_file(path)
	return null

static func _configure_audio_loop(stream: AudioStream, loop: bool) -> AudioStream:
	if stream == null or not loop:
		return stream
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream

static func _should_prefer_source_file(path: String, extensions: PackedStringArray) -> bool:
	if not OS.has_feature("editor"):
		return false
	if not extensions.has(path.get_extension().to_lower()):
		return false
	return not _has_imported_resource(path)

static func _has_imported_resource(path: String) -> bool:
	var import_config := ConfigFile.new()
	if import_config.load("%s.import" % path) != OK:
		return false
	var remap_keys: PackedStringArray = import_config.get_section_keys("remap")
	for key: String in remap_keys:
		if key != "path" and not key.begins_with("path."):
			continue
		var imported_path: String = str(import_config.get_value("remap", key, ""))
		if not imported_path.is_empty() and FileAccess.file_exists(imported_path):
			return true
	return false

static func load_texture_region(path: String, region: Rect2i) -> Texture2D:
	var texture: Texture2D = load_texture(path)
	if texture == null:
		return null
	if region.size.x <= 0 or region.size.y <= 0:
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(region.position, region.size)
	return atlas

static func modulate_texture(texture: Texture2D, multiplier: Color) -> Texture2D:
	if texture == null:
		return null
	if is_equal_approx(multiplier.r, 1.0) and is_equal_approx(multiplier.g, 1.0) and is_equal_approx(multiplier.b, 1.0) and is_equal_approx(multiplier.a, 1.0):
		return texture
	var image: Image = _texture_to_image(texture)
	if image == null or image.is_empty():
		return texture
	var tinted_image: Image = image.duplicate()
	for y: int in range(tinted_image.get_height()):
		for x: int in range(tinted_image.get_width()):
			var pixel: Color = tinted_image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			tinted_image.set_pixel(x, y, Color(
				clampf(pixel.r * multiplier.r, 0.0, 1.0),
				clampf(pixel.g * multiplier.g, 0.0, 1.0),
				clampf(pixel.b * multiplier.b, 0.0, 1.0),
				clampf(pixel.a * multiplier.a, 0.0, 1.0)
			))
	return ImageTexture.create_from_image(tinted_image)

static func flip_texture_h(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var cache_key: String = "%s|flip_h" % _texture_processing_cache_key(texture)
	if _flipped_texture_cache.has(cache_key):
		return _flipped_texture_cache.get(cache_key, null)
	var image: Image = _texture_to_image(texture)
	if image == null or image.is_empty():
		_flipped_texture_cache[cache_key] = texture
		return texture
	var flipped_image: Image = image.duplicate()
	flipped_image.flip_x()
	var flipped_texture: Texture2D = ImageTexture.create_from_image(flipped_image)
	_flipped_texture_cache[cache_key] = flipped_texture
	return flipped_texture

static func scale_texture_nearest(texture: Texture2D, scale_factor: int) -> Texture2D:
	if texture == null or scale_factor <= 1:
		return texture
	var cache_key: String = "%s|scale_nearest|%d" % [_texture_processing_cache_key(texture), scale_factor]
	if _scaled_texture_cache.has(cache_key):
		return _scaled_texture_cache.get(cache_key, null)
	var image: Image = _texture_to_image(texture)
	if image == null or image.is_empty():
		_scaled_texture_cache[cache_key] = texture
		return texture
	var scaled_image: Image = image.duplicate()
	scaled_image.resize(
		maxi(1, image.get_width() * scale_factor),
		maxi(1, image.get_height() * scale_factor),
		Image.INTERPOLATE_NEAREST
	)
	var scaled_texture: Texture2D = ImageTexture.create_from_image(scaled_image)
	_scaled_texture_cache[cache_key] = scaled_texture
	return scaled_texture

static func strip_near_black_outline(texture: Texture2D, options: Dictionary = {}) -> Texture2D:
	if texture == null:
		return null
	var alpha_threshold: float = float(options.get("alpha_threshold", 0.08))
	var ring_depth: int = int(options.get("ring_depth", 1))
	var cache_key: String = "%s|strip_outline|%.3f|%d|%.3f|%.3f" % [
		_texture_processing_cache_key(texture),
		alpha_threshold,
		ring_depth,
		float(options.get("max_dark_channel", 0.34)),
		float(options.get("neighbor_min_channel", 0.12))
	]
	if _outline_clean_texture_cache.has(cache_key):
		return _outline_clean_texture_cache.get(cache_key, null)
	var source_image: Image = _texture_to_image(texture)
	if source_image == null or source_image.is_empty():
		_outline_clean_texture_cache[cache_key] = texture
		return texture
	var depth_map: Dictionary = {}
	var frontier: Array[Vector2i] = []
	for y: int in range(source_image.get_height()):
		for x: int in range(source_image.get_width()):
			var pixel: Color = source_image.get_pixel(x, y)
			if pixel.a <= alpha_threshold:
				continue
			if _pixel_touches_transparent(source_image, x, y, alpha_threshold):
				var point: Vector2i = Vector2i(x, y)
				depth_map[point] = 1
				frontier.append(point)
	while not frontier.is_empty():
		var current: Vector2i = frontier.pop_front()
		var current_depth: int = int(depth_map.get(current, 0))
		if current_depth >= ring_depth + 1:
			continue
		for offset_y: int in range(-1, 2):
			for offset_x: int in range(-1, 2):
				if offset_x == 0 and offset_y == 0:
					continue
				var next_point: Vector2i = current + Vector2i(offset_x, offset_y)
				if next_point.x < 0 or next_point.y < 0 or next_point.x >= source_image.get_width() or next_point.y >= source_image.get_height():
					continue
				if depth_map.has(next_point):
					continue
				var next_pixel: Color = source_image.get_pixel(next_point.x, next_point.y)
				if next_pixel.a <= alpha_threshold:
					continue
				depth_map[next_point] = current_depth + 1
				frontier.append(next_point)
	var cleaned_image: Image = source_image.duplicate()
	var changed_pixels: int = 0
	for point_variant: Variant in depth_map.keys():
		var point: Vector2i = point_variant
		var depth: int = int(depth_map.get(point, 0))
		if depth <= 0 or depth > ring_depth:
			continue
		var neighbor_color: Color = _average_inner_pixel_color(source_image, depth_map, point, alpha_threshold, ring_depth)
		if neighbor_color.a <= 0.0:
			continue
		cleaned_image.set_pixel(point.x, point.y, neighbor_color)
		changed_pixels += 1
	if changed_pixels == 0:
		_outline_clean_texture_cache[cache_key] = texture
		return texture
	var cleaned_texture: Texture2D = ImageTexture.create_from_image(cleaned_image)
	_outline_clean_texture_cache[cache_key] = cleaned_texture
	return cleaned_texture

static func load_texture_by_stem(path_stem: String, extensions: PackedStringArray = TEXTURE_EXTENSIONS) -> Texture2D:
	for ext: String in extensions:
		var full_path: String = "%s.%s" % [path_stem, ext]
		var texture: Texture2D = load_texture(full_path)
		if texture != null:
			return texture
	return null

static func load_terrain_texture(terrain_id: String) -> Texture2D:
	var extensions: PackedStringArray = TEXTURE_EXTENSIONS
	match terrain_id:
		"forest", "mountain", "castle", "ruins", "tower":
			extensions = PNG_FIRST_TEXTURE_EXTENSIONS
	return load_texture_by_stem("res://assets/placeholders/terrain_%s" % terrain_id, extensions)

static func load_presented_terrain_texture(terrain_id: String) -> Texture2D:
	var texture: Texture2D = load_terrain_texture(terrain_id)
	match terrain_id:
		"ruins", "tower":
			return trim_texture_to_used_rect(texture)
	return texture

static func trim_texture_to_used_rect(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		return texture
	var used_rect: Rect2i = image.get_used_rect()
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return texture
	if used_rect.position == Vector2i.ZERO and used_rect.size == image.get_size():
		return texture
	var atlas := AtlasTexture.new()
	atlas.atlas = texture
	atlas.region = Rect2(used_rect.position, used_rect.size)
	return atlas

static func build_castle_control_texture(texture: Texture2D, control_color: Color, options: Dictionary = {}) -> Texture2D:
	if texture == null:
		return null
	var saturation_floor: float = float(options.get("saturation_floor", 0.58))
	var value_multiplier: float = float(options.get("value_multiplier", 0.98))
	var blend_min: float = float(options.get("blend_min", 0.72))
	var blend_max: float = float(options.get("blend_max", 0.92))
	var blend_slope: float = float(options.get("blend_slope", 0.40))
	var cache_key: String = _castle_control_texture_cache_key(
		texture,
		control_color,
		saturation_floor,
		value_multiplier,
		blend_min,
		blend_max,
		blend_slope
	)
	if _castle_control_texture_cache.has(cache_key):
		return _castle_control_texture_cache.get(cache_key, null)
	var image: Image = texture.get_image()
	if image == null or image.is_empty():
		_castle_control_texture_cache[cache_key] = texture
		return texture
	var tinted_image: Image = image.duplicate()
	var control_hsv: Vector3 = _color_to_hsv(control_color)
	var changed_pixels: int = 0
	for y: int in range(tinted_image.get_height()):
		for x: int in range(tinted_image.get_width()):
			var pixel: Color = tinted_image.get_pixel(x, y)
			if not _is_castle_control_accent(pixel):
				continue
			var pixel_hsv: Vector3 = _color_to_hsv(pixel)
			var tinted_pixel: Color = Color.from_hsv(
				control_hsv.x,
				clampf(maxf(saturation_floor, pixel_hsv.y * 0.92 + control_hsv.y * 0.18), 0.0, 1.0),
				clampf(pixel_hsv.z * value_multiplier, 0.0, 1.0),
				pixel.a
			)
			var blend_weight: float = clampf(blend_min + (pixel_hsv.y - CASTLE_CONTROL_ACCENT_MIN_SATURATION) * blend_slope, blend_min, blend_max)
			tinted_image.set_pixel(x, y, pixel.lerp(tinted_pixel, blend_weight))
			changed_pixels += 1
	if changed_pixels == 0:
		_castle_control_texture_cache[cache_key] = texture
		return texture
	var tinted_texture: Texture2D = ImageTexture.create_from_image(tinted_image)
	_castle_control_texture_cache[cache_key] = tinted_texture
	return tinted_texture

static func build_sprite_sheet_frames(texture: Texture2D, frame_size: Vector2i, frame_indices: Array = []) -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if texture == null or frame_size.x <= 0 or frame_size.y <= 0:
		return frames
	var columns: int = int(texture.get_width() / frame_size.x)
	var rows: int = int(texture.get_height() / frame_size.y)
	if columns <= 0 or rows <= 0:
		return frames
	var total_frames: int = columns * rows
	var ordered_indices: Array = frame_indices if not frame_indices.is_empty() else range(total_frames)
	for index_var: Variant in ordered_indices:
		var frame_index: int = int(index_var)
		if frame_index < 0 or frame_index >= total_frames:
			continue
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			Vector2(float((frame_index % columns) * frame_size.x), float(int(frame_index / columns) * frame_size.y)),
			Vector2(float(frame_size.x), float(frame_size.y))
		)
		frames.append(atlas)
	return frames

static func texture_used_rect(texture: Texture2D) -> Rect2i:
	if texture == null:
		return Rect2i()
	# Retained combat-board layers share immutable textures but are separate
	# CanvasItems. Cache alpha bounds by stable texture/atlas identity here so
	# every layer does not read back and scan the same image independently.
	var cache_key: String = _texture_processing_cache_key(texture)
	if _texture_used_rect_cache.has(cache_key):
		var cached_rect: Rect2i = _texture_used_rect_cache.get(cache_key, Rect2i())
		return cached_rect
	var image: Image = _texture_to_image(texture)
	var used_rect := Rect2i()
	if image != null and not image.is_empty():
		used_rect = image.get_used_rect()
	_texture_used_rect_cache[cache_key] = used_rect
	return used_rect

static func cache_texture_used_rect(texture: Texture2D, used_rect: Rect2i) -> void:
	if texture == null:
		return
	_texture_used_rect_cache[_texture_processing_cache_key(texture)] = used_rect

static func texture_source_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	# Runtime gear bakes already own CPU pixels from their single viewport
	# readback. Silhouette consumers must not read the uploaded ImageTexture back.
	if texture.has_meta("gear_rest_image"):
		var gear_image: Variant = texture.get_meta("gear_rest_image")
		if gear_image is Image:
			return gear_image
	return texture.get_image()

static func build_alpha_polygons(
	texture: Texture2D,
	alpha_threshold: float = DEFAULT_ALPHA_POLYGON_THRESHOLD,
	simplify_epsilon: float = DEFAULT_ALPHA_POLYGON_SIMPLIFY_EPSILON,
	minimum_area: float = DEFAULT_ALPHA_POLYGON_MIN_AREA
) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if texture == null:
		return polygons
	var cache_key: String = _alpha_polygon_cache_key(texture, alpha_threshold, simplify_epsilon, minimum_area)
	if _alpha_polygon_cache.has(cache_key):
		return _alpha_polygon_cache.get(cache_key, [])
	var image: Image = texture_source_image(texture)
	if image == null or image.is_empty():
		_alpha_polygon_cache[cache_key] = polygons
		return polygons
	polygons = build_alpha_polygons_from_image(image, alpha_threshold, simplify_epsilon, minimum_area)
	_alpha_polygon_cache[cache_key] = polygons
	return polygons

static func build_alpha_polygons_from_image(
	image: Image,
	alpha_threshold: float = DEFAULT_ALPHA_POLYGON_THRESHOLD,
	simplify_epsilon: float = DEFAULT_ALPHA_POLYGON_SIMPLIFY_EPSILON,
	minimum_area: float = DEFAULT_ALPHA_POLYGON_MIN_AREA
) -> Array[PackedVector2Array]:
	var polygons: Array[PackedVector2Array] = []
	if image == null or image.is_empty():
		return polygons
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, alpha_threshold)
	var opaque_polygons: Array[PackedVector2Array] = bitmap.opaque_to_polygons(
		Rect2i(Vector2i.ZERO, image.get_size()),
		simplify_epsilon
	)
	for polygon: PackedVector2Array in opaque_polygons:
		if polygon.size() < 3:
			continue
		if absf(_polygon_signed_area(polygon)) < minimum_area:
			continue
		polygons.append(polygon)
	return polygons

static func _alpha_polygon_cache_key(texture: Texture2D, alpha_threshold: float, simplify_epsilon: float, minimum_area: float) -> String:
	if texture is AtlasTexture:
		var atlas_texture: AtlasTexture = texture
		return "atlas|%s|%s|%s|%.3f|%.3f|%.3f" % [
			_alpha_polygon_cache_key(atlas_texture.atlas, alpha_threshold, simplify_epsilon, minimum_area),
			str(atlas_texture.region.position),
			str(atlas_texture.region.size),
			alpha_threshold,
			simplify_epsilon,
			minimum_area
		]
	var resource_path: String = texture.resource_path
	if not resource_path.is_empty():
		return "path|%s|%d|%d|%.3f|%.3f|%.3f" % [
			resource_path,
			texture.get_width(),
			texture.get_height(),
			alpha_threshold,
			simplify_epsilon,
			minimum_area
		]
	return "instance|%d|%d|%d|%.3f|%.3f|%.3f" % [
		texture.get_instance_id(),
		texture.get_width(),
		texture.get_height(),
		alpha_threshold,
		simplify_epsilon,
		minimum_area
	]

static func _polygon_signed_area(points: PackedVector2Array) -> float:
	var area: float = 0.0
	if points.size() < 3:
		return area
	for idx: int in range(points.size()):
		var current: Vector2 = points[idx]
		var next: Vector2 = points[(idx + 1) % points.size()]
		area += current.x * next.y - next.x * current.y
	return area * 0.5

static func load_combat_marker_texture() -> Texture2D:
	return load_texture_by_stem("res://assets/art/icons/melee", PNG_FIRST_TEXTURE_EXTENSIONS)

static func load_font(path: String) -> FontFile:
	if path.is_empty():
		return null
	if _font_cache.has(path):
		return _font_cache.get(path, null)
	if ResourceLoader.exists(path):
		var loaded: Resource = load(path)
		if loaded is FontFile:
			_font_cache[path] = loaded
			return loaded
	if not FileAccess.file_exists(path):
		_font_cache[path] = null
		return null
	var font := FontFile.new()
	var err: Error = font.load_dynamic_font(path)
	if err != OK:
		_font_cache[path] = null
		return null
	_font_cache[path] = font
	return font

static func _castle_control_texture_cache_key(
	texture: Texture2D,
	control_color: Color,
	saturation_floor: float,
	value_multiplier: float,
	blend_min: float,
	blend_max: float,
	blend_slope: float
) -> String:
	var texture_id: String = texture.resource_path
	if texture_id.is_empty():
		texture_id = "instance|%d" % texture.get_instance_id()
	return "%s|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%.3f|%d|%d" % [
		texture_id,
		control_color.r,
		control_color.g,
		control_color.b,
		saturation_floor,
		value_multiplier,
		blend_min,
		blend_max,
		blend_slope,
		texture.get_width(),
		texture.get_height()
	]

static func _is_castle_control_accent(pixel: Color) -> bool:
	if pixel.a < 0.12:
		return false
	var hsv: Vector3 = _color_to_hsv(pixel)
	var hue: float = hsv.x
	if hue > CASTLE_CONTROL_ACCENT_HUE_MAX and hue < CASTLE_CONTROL_ACCENT_HUE_WRAP_MIN:
		return false
	if hsv.y < CASTLE_CONTROL_ACCENT_MIN_SATURATION or hsv.z < CASTLE_CONTROL_ACCENT_MIN_VALUE:
		return false
	if pixel.r - maxf(pixel.g, pixel.b) < CASTLE_CONTROL_ACCENT_MIN_RED_DOMINANCE:
		return false
	return true

static func _color_to_hsv(color: Color) -> Vector3:
	var max_channel: float = maxf(color.r, maxf(color.g, color.b))
	var min_channel: float = minf(color.r, minf(color.g, color.b))
	var chroma: float = max_channel - min_channel
	var hue: float = 0.0
	if chroma > 0.00001:
		if is_equal_approx(max_channel, color.r):
			hue = fmod((color.g - color.b) / chroma, 6.0) / 6.0
		elif is_equal_approx(max_channel, color.g):
			hue = (((color.b - color.r) / chroma) + 2.0) / 6.0
		else:
			hue = (((color.r - color.g) / chroma) + 4.0) / 6.0
		if hue < 0.0:
			hue += 1.0
	var saturation: float = 0.0 if max_channel <= 0.00001 else chroma / max_channel
	return Vector3(hue, saturation, max_channel)

static func _texture_processing_cache_key(texture: Texture2D) -> String:
	if texture is AtlasTexture:
		var atlas_texture: AtlasTexture = texture
		if atlas_texture.atlas == null:
			return "atlas|null"
		return "atlas|%s|%s|%s" % [
			_texture_processing_cache_key(atlas_texture.atlas),
			str(atlas_texture.region.position),
			str(atlas_texture.region.size)
		]
	var resource_path: String = texture.resource_path
	if not resource_path.is_empty():
		return "path|%s|%d|%d" % [
			resource_path,
			texture.get_width(),
			texture.get_height()
		]
	return "instance|%d|%d|%d" % [
		texture.get_instance_id(),
		texture.get_width(),
		texture.get_height()
	]

static func _texture_to_image(texture: Texture2D) -> Image:
	if texture == null:
		return null
	if texture is AtlasTexture:
		var atlas_texture: AtlasTexture = texture
		if atlas_texture.atlas == null:
			return null
		var atlas_image: Image = _texture_to_image(atlas_texture.atlas)
		if atlas_image == null or atlas_image.is_empty():
			return null
		var region := Rect2i(
			Vector2i(int(atlas_texture.region.position.x), int(atlas_texture.region.position.y)),
			Vector2i(int(atlas_texture.region.size.x), int(atlas_texture.region.size.y))
		)
		if region.size.x <= 0 or region.size.y <= 0:
			return atlas_image
		return atlas_image.get_region(region)
	return texture_source_image(texture)

static func _pixel_touches_transparent(image: Image, x: int, y: int, alpha_threshold: float) -> bool:
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x: int = x + offset_x
			var sample_y: int = y + offset_y
			if sample_x < 0 or sample_y < 0 or sample_x >= image.get_width() or sample_y >= image.get_height():
				return true
			if image.get_pixel(sample_x, sample_y).a <= alpha_threshold:
				return true
	return false

static func _average_inner_pixel_color(image: Image, depth_map: Dictionary, center: Vector2i, alpha_threshold: float, ring_depth: int) -> Color:
	var neighbor_rgb: Vector3 = Vector3.ZERO
	var neighbor_alpha_total: float = 0.0
	var neighbor_count: int = 0
	var current_depth: int = int(depth_map.get(center, 0))
	for offset_y: int in range(-1, 2):
		for offset_x: int in range(-1, 2):
			if offset_x == 0 and offset_y == 0:
				continue
			var sample_x: int = center.x + offset_x
			var sample_y: int = center.y + offset_y
			if sample_x < 0 or sample_y < 0 or sample_x >= image.get_width() or sample_y >= image.get_height():
				continue
			var sample_point: Vector2i = Vector2i(sample_x, sample_y)
			var sample_depth: int = int(depth_map.get(sample_point, 0))
			if sample_depth > 0 and sample_depth <= ring_depth:
				continue
			var neighbor: Color = image.get_pixel(sample_x, sample_y)
			if neighbor.a <= alpha_threshold:
				continue
			neighbor_rgb += Vector3(neighbor.r, neighbor.g, neighbor.b)
			neighbor_alpha_total += neighbor.a
			neighbor_count += 1
	if neighbor_count == 0:
		for offset_y: int in range(-1, 2):
			for offset_x: int in range(-1, 2):
				if offset_x == 0 and offset_y == 0:
					continue
				var sample_x: int = center.x + offset_x
				var sample_y: int = center.y + offset_y
				if sample_x < 0 or sample_y < 0 or sample_x >= image.get_width() or sample_y >= image.get_height():
					continue
				var sample_point: Vector2i = Vector2i(sample_x, sample_y)
				if int(depth_map.get(sample_point, 0)) <= current_depth:
					continue
				var neighbor: Color = image.get_pixel(sample_x, sample_y)
				if neighbor.a <= alpha_threshold:
					continue
				neighbor_rgb += Vector3(neighbor.r, neighbor.g, neighbor.b)
				neighbor_alpha_total += neighbor.a
				neighbor_count += 1
	if neighbor_count == 0:
		return Color(0.0, 0.0, 0.0, 0.0)
	return Color(
		neighbor_rgb.x / float(neighbor_count),
		neighbor_rgb.y / float(neighbor_count),
		neighbor_rgb.z / float(neighbor_count),
		neighbor_alpha_total / float(neighbor_count)
	)
