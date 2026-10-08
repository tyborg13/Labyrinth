# Frozen calculation paths; typed local initializers adapted for Windows compatibility.
extends "res://scripts/combat_board_view.gd"

# Frozen before stage227: native checks and surface arrays are the oracle.

func _unit_shadow_draw_mesh(texture: Texture2D, draw_rect: Rect2, unit_type: String, shadow_geometry: Array, _shadow_geometry_validated: bool = false) -> ArrayMesh:
	var cache_key: String = _unit_shadow_draw_cache_key(texture, draw_rect, unit_type)
	if _unit_shadow_draw_mesh_cache.has(cache_key):
		_record_unit_shadow_cache_metric("mesh_hit", unit_type)
		return _unit_shadow_draw_mesh_cache.get(cache_key, null) as ArrayMesh
	_record_unit_shadow_cache_metric("mesh_miss", unit_type)
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for geometry_var: Variant in shadow_geometry:
		var geometry: Dictionary = geometry_var as Dictionary
		var triangulated: PackedInt32Array = geometry.get("triangulated", PackedInt32Array()) as PackedInt32Array
		_append_colored_polygon_to_mesh_arrays(
			geometry.get("soft", PackedVector2Array()) as PackedVector2Array,
			UNIT_SHADOW_SOFT_COLOR,
			vertices,
			colors,
			indices,
			triangulated
		)
		_append_colored_polygon_to_mesh_arrays(
			geometry.get("hard", PackedVector2Array()) as PackedVector2Array,
			UNIT_SHADOW_COLOR,
			vertices,
			colors,
			indices,
			triangulated
		)
	if vertices.is_empty() or indices.is_empty():
		_unit_shadow_draw_mesh_cache[cache_key] = null
		return null
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var shadow_mesh := ArrayMesh.new()
	shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_unit_shadow_draw_mesh_cache[cache_key] = shadow_mesh
	return shadow_mesh

func _append_colored_polygon_to_mesh_arrays(
	polygon: PackedVector2Array,
	color: Color,
	vertices: PackedVector3Array,
	colors: PackedColorArray,
	indices: PackedInt32Array,
	pretriangulated: PackedInt32Array = PackedInt32Array()
) -> void:
	if not _polygon_can_draw(polygon):
		return
	var triangulated: PackedInt32Array = pretriangulated
	if triangulated.is_empty():
		triangulated = Geometry2D.triangulate_polygon(polygon)
	if triangulated.is_empty():
		return
	var first_vertex: int = vertices.size()
	for point: Vector2 in polygon:
		vertices.append(Vector3(point.x, point.y, 0.0))
		colors.append(color)
	for index: int in triangulated:
		indices.append(first_vertex + index)

func _unit_shadow_draw_geometry(texture: Texture2D, draw_rect: Rect2, unit_type: String) -> Array:
	var cache_key: String = _unit_shadow_draw_cache_key(texture, draw_rect, unit_type)
	if _unit_shadow_draw_geometry_cache.has(cache_key):
		_record_unit_shadow_cache_metric("geometry_hit", unit_type)
		return _unit_shadow_draw_geometry_cache.get(cache_key, []) as Array
	_record_unit_shadow_cache_metric("geometry_miss", unit_type)
	var geometry: Array = []
	var shadow_data_was_missing: bool = not _unit_shadow_polygon_cache.has(texture.get_instance_id())
	var shadow_data_started_usec: int = Time.get_ticks_usec() if shadow_data_was_missing else 0
	var shadow_data: Dictionary = _unit_shadow_data_for_texture(texture)
	var shadow_polygons: Array[PackedVector2Array] = _packed_vector2_array_array(
		shadow_data.get("polygons", [])
	)
	var shadow_triangulations: Array[PackedInt32Array] = _packed_int32_array_array(
		shadow_data.get("triangulations", [])
	)
	var bounds: Rect2 = shadow_data.get("bounds", Rect2()) as Rect2
	if shadow_data_was_missing:
		var elapsed_usec: int = Time.get_ticks_usec() - shadow_data_started_usec
		_unit_shadow_sync_miss_metrics["count"] = int(_unit_shadow_sync_miss_metrics.get("count", 0)) + 1
		_unit_shadow_sync_miss_metrics["total_usec"] = int(_unit_shadow_sync_miss_metrics.get("total_usec", 0)) + elapsed_usec
		_unit_shadow_sync_miss_metrics["max_usec"] = maxi(int(_unit_shadow_sync_miss_metrics.get("max_usec", 0)), elapsed_usec)
		var by_type: Dictionary = _unit_shadow_sync_miss_metrics.get("by_type", {}) as Dictionary
		var type_metrics: Dictionary = by_type.get(unit_type, {}) as Dictionary
		type_metrics["count"] = int(type_metrics.get("count", 0)) + 1
		type_metrics["total_usec"] = int(type_metrics.get("total_usec", 0)) + elapsed_usec
		type_metrics["max_usec"] = maxi(int(type_metrics.get("max_usec", 0)), elapsed_usec)
		by_type[unit_type] = type_metrics
		_unit_shadow_sync_miss_metrics["by_type"] = by_type
	if shadow_polygons.is_empty() or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		_unit_shadow_draw_geometry_cache[cache_key] = geometry
		return geometry
	var shadow_size: Vector2 = _unit_shadow_draw_size(texture, draw_rect.size, bounds)
	for polygon_index: int in range(shadow_polygons.size()):
		var local_polygon: PackedVector2Array = shadow_polygons[polygon_index]
		var shadow_polygon: PackedVector2Array = _project_unit_shadow_polygon(local_polygon, shadow_size, Vector2.ZERO)
		if not _polygon_can_draw(shadow_polygon):
			continue
		var soft_polygon: PackedVector2Array = _scaled_polygon(shadow_polygon, UNIT_SHADOW_SOFT_SCALE)
		var triangulated := PackedInt32Array()
		if polygon_index < shadow_triangulations.size():
			triangulated = shadow_triangulations[polygon_index]
		geometry.append({
			"hard": shadow_polygon,
			"soft": soft_polygon if _polygon_can_draw(soft_polygon) else PackedVector2Array(),
			"triangulated": triangulated,
		})
	_unit_shadow_draw_geometry_cache[cache_key] = geometry
	return geometry

func _unit_shadow_data_from_opaque_polygons(opaque_polygons: Array[PackedVector2Array]) -> Dictionary:
	var local_polygons: Array[PackedVector2Array]
	var triangulations: Array[PackedInt32Array]
	var bounds: Rect2 = _polygon_bounds(opaque_polygons)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {"polygons": local_polygons, "triangulations": triangulations, "bounds": Rect2()}
	var bounds_center_x: float = bounds.position.x + bounds.size.x * 0.5
	var bounds_bottom_y: float = bounds.position.y + bounds.size.y
	for polygon: PackedVector2Array in opaque_polygons:
		var local_polygon := PackedVector2Array()
		for point: Vector2 in polygon:
			local_polygon.append(Vector2(
				(point.x - bounds_center_x) / bounds.size.x,
				(point.y - bounds_bottom_y) / bounds.size.y
			))
		if _polygon_can_draw(local_polygon):
			var triangulated: PackedInt32Array = Geometry2D.triangulate_polygon(local_polygon)
			if not triangulated.is_empty():
				local_polygons.append(local_polygon)
				triangulations.append(triangulated)
	var data: Dictionary = {
		"polygons": local_polygons,
		"triangulations": triangulations,
		"bounds": bounds,
	}
	return data
