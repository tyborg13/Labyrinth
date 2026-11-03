extends RefCounted

## Geometry/catalog only; enumeration is grid/data order, never painter order.
const BOUNDS_PADDING_TILES: float = 0.5
const TIE_RANK := {"floor":0,"scene_prop":1,"grid_prop":2,"terrain":3}

static func catalog(board: Control) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var grid: Array = board.combat_state["grid"]
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var tile := Vector2i(x,y)
			if str(grid[y][x])=="void" or not board._should_render_tile(board._display_tile_id(str(grid[y][x]),tile),tile,grid): continue
			var floor_bounds: Rect2 = Rect2(board.world_position_for_tile(tile)-Vector2(board._tile_width(),board._tile_height())*0.5,Vector2(board._tile_width(),board._tile_height()*2))
			_add(result,board,"floor","floor",tile,"floor_%d_%d"%[x,y],floor_bounds,{})
			var tile_id: String = str(grid[y][x])
			if tile_id in ["wall","pillar","door"]:
				var wall: bool = tile_id=="wall" and board._is_outer_boundary_tile(grid,tile)
				var bounds: Rect2 = board._prop_rect_for_tile(tile)
				if wall:
					for segment: Dictionary in board._boundary_prop_segments("wall",grid,tile): bounds = bounds.merge(segment.get("draw_rect",Rect2()))
				_add(result,board,"wall" if wall else "prop","grid_prop",tile,"grid_%d_%d"%[x,y],bounds,{})
	for index: int in range(board.combat_state.get("terrain",[]).size()):
		var terrain: Dictionary = board.combat_state["terrain"][index]
		if not board.BoardSurfaceRules.terrain_is_live(terrain): continue
		var tile: Vector2i = terrain["pos"]
		var texture: Texture2D = board._terrain_textures.get(board._terrain_art_kind(str(terrain.get("kind",""))),null)
		var bounds: Rect2 = board._terrain_rect_for_tile(tile,texture,str(terrain.get("kind",""))) if texture!=null else board._prop_rect_for_tile(tile)
		_add(result,board,"prop","terrain",tile,"terrain_%d"%index,bounds,terrain)
	for index: int in range(board.presentation.get("scene_props",[]).size()):
		var prop: Dictionary = board.presentation["scene_props"][index]
		var tile: Vector2i = prop["tile"]
		var texture: Texture2D = board._texture_for_scene_prop(prop)
		var bounds: Rect2 = board._scene_prop_rect(texture,prop) if texture!=null else board._prop_rect_for_tile(tile)
		_add(result,board,"prop","scene_prop",tile,"scene_%d"%index,bounds,prop)
	return result

static func _add(result: Array[Dictionary], board: Control, kind: String, renderer: String, tile: Vector2i, id: String, bounds: Rect2, data: Dictionary) -> void:
	# Static occupants sort at the tile centre; sprite bounds include front
	# corners and padding and must never become a prop's ground anchor.
	var ground: Vector2 = board.world_position_for_tile(tile)
	result.append({"id":id,"kind":kind,"renderer":renderer,"plane":0 if renderer=="floor" else 1,"tie_rank":TIE_RANK[renderer],"tile":tile,"ground_x":ground.x,"ground_y":ground.y,"bounds":bounds.grow(board._tile_width()*BOUNDS_PADDING_TILES),"data":data})
