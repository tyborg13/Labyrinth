extends Container

const FoeLayout = preload("res://scripts/pre_battle_foe_layout.gd")

func _get_minimum_size() -> Vector2:
	return Vector2.ZERO

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or size.x <= 0.0 or size.y <= 0.0:
		return
	var cells: Array[Rect2] = _cells()
	var reserves: Array[float]
	reserves.resize(2)
	reserves.fill(0.0)
	for index: int in range(cells.size()):
		var card := get_child(index) as Control
		fit_child_in_rect(card, cells[index])
		var caption := card.get_node("PreBattleFoeCaption") as Control
		var row: int = int(card.get_meta("lineup_row", 0))
		reserves[row] = maxf(reserves[row], float(caption.call("measure", card.size.x)))
	var lineup_scale: float = 0.8
	for index: int in range(cells.size()):
		var card := get_child(index) as Control
		lineup_scale = minf(lineup_scale, FoeLayout.fit_scale(card, reserves[int(card.get_meta("lineup_row", 0))]))
	if get_child_count() <= 3:
		var above: float = 0.0
		var below: float = 0.0
		for card: Control in get_children():
			var data: Dictionary = FoeLayout.metrics(str((card.get("enemy") as Dictionary).get("type", "")))
			var drawn_scale: float = lineup_scale * float(data["art_scale"])
			above = maxf(above, float(data["above"]) * drawn_scale)
			below = maxf(below, float(data["below"]) * drawn_scale)
		# Centre the visible group after fitting k, with one shared ground line.
		var group_height: float = above + below + reserves[0]
		var ground_y: float = (size.y - group_height) * 0.5 + above
		for card: Control in get_children():
			FoeLayout.apply(card, lineup_scale, reserves[0], ground_y + below, ground_y)
		return
	for card: Control in get_children():
		FoeLayout.apply(card, lineup_scale, reserves[int(card.get_meta("lineup_row", 0))])

func _cells() -> Array[Rect2]:
	var result: Array[Rect2]
	result.resize(get_child_count())
	var small: Array[int]
	var large: Array[int]
	for index: int in range(get_child_count()):
		var card := get_child(index) as Control
		var data: Dictionary = FoeLayout.metrics(str((card.get("enemy") as Dictionary).get("type", "")))
		if bool(data["large"]):
			large.append(index)
		else:
			small.append(index)
	var rows: int = 1 if get_child_count() <= 3 else 2
	var columns: Array = []
	if rows == 1:
		for index: int in range(get_child_count()):
			columns.append({"weight": 2 if large.has(index) else 1, "members": [index]})
	else:
		var small_columns: int = ceili(small.size() / 2.0)
		var left_columns: int = ceili(small_columns / 2.0)
		for column: int in range(left_columns):
			columns.append({"weight": 1, "members": small.slice(column * 2, column * 2 + 2)})
		for index: int in large:
			columns.append({"weight": 2, "members": [index]})
		for column: int in range(left_columns, small_columns):
			columns.append({"weight": 1, "members": small.slice(column * 2, column * 2 + 2)})
	var total_weight: int = small.size() + large.size() * 2 if rows == 1 else ceili(small.size() / 2.0) + large.size() * 2
	var left: float = 0.0
	for column_index: int in range(columns.size()):
		var column: Dictionary = columns[column_index]
		var width: float = size.x * int(column["weight"]) / maxi(1, total_weight)
		var members: Array = column["members"]
		for row: int in range(members.size()):
			var index: int = int(members[row])
			var spanning: bool = rows == 2 and large.has(index)
			var card := get_child(index) as Control
			card.set_meta("lineup_row", 1 if spanning else row)
			result[index] = Rect2(left, 0.0 if spanning else row * size.y / rows, width, size.y if spanning else size.y / rows)
		left += width
	return result
