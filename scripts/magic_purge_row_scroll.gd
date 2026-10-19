extends ScrollContainer

# All native scrollbar writes (including dragging) use the same row lattice.
# Focus remains on the card buttons; only off-page artwork is hidden so its
# badge/crown cannot peek into the adjacent page's overhang or headroom.
const VISIBLE_ROWS: int = 2
var _grid: Control
var _columns: int = 1
var _row_pitch: int = 1
var _row_count: int = 0
var _updating: bool = false

func configure(grid: Control, columns: int, row_pitch: int) -> void:
	_grid = grid
	_columns = columns
	_row_pitch = row_pitch
	_row_count = ceili(float(grid.get_child_count()) / columns)
	follow_focus = false
	scroll_vertical_custom_step = row_pitch
	var bar := get_v_scroll_bar()
	bar.changed.connect(_sync_range)
	bar.value_changed.connect(_scrolled)
	resized.connect(_sync_range)
	for index: int in range(grid.get_child_count()):
		var cell: Control = grid.get_child(index)
		cell.focus_entered.connect(_reveal_row.bind(index / columns))
	_sync_range()
	call_deferred("_sync_range")

func _sync_range() -> void:
	if _updating or _grid == null: return
	_updating = true
	var bar := get_v_scroll_bar()
	var panel: StyleBox = get_theme_stylebox("panel")
	var page_height: float = maxf(0.0, size.y - panel.get_minimum_size().y)
	bar.step = _row_pitch
	bar.max_value = page_height + maxi(0, _row_count - VISIBLE_ROWS) * _row_pitch
	bar.page = page_height
	bar.value = clampi(roundi(bar.value / _row_pitch), 0, maxi(0, _row_count - VISIBLE_ROWS)) * _row_pitch
	_updating = false
	_refresh_page()

func _scrolled(_value: float) -> void:
	_sync_range()

func _refresh_page() -> void:
	var first_row: int = scroll_vertical / _row_pitch
	for index: int in range(_grid.get_child_count()):
		var row: int = index / _columns
		var on_page: bool = row >= first_row and row < first_row + VISIBLE_ROWS
		var cell: Control = _grid.get_child(index)
		# Keep keyboard/controller focus targets, without pointer hits on the
		# empty sliver of an off-page button inside the badge overflow room.
		cell.mouse_filter = Control.MOUSE_FILTER_STOP if on_page else Control.MOUSE_FILTER_IGNORE
		for artwork: CanvasItem in cell.get_children():
			artwork.visible = on_page

func _reveal_row(row: int) -> void:
	var first_row: int = scroll_vertical / _row_pitch
	if row < first_row: scroll_vertical = row * _row_pitch
	elif row >= first_row + VISIBLE_ROWS: scroll_vertical = (row - VISIBLE_ROWS + 1) * _row_pitch
	_refresh_page()

func _gui_input(event: InputEvent) -> void:
	var direction: int = 0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: direction = 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP: direction = -1
	elif event is InputEventPanGesture:
		direction = int(signf(event.delta.y))
	if direction != 0:
		scroll_vertical += direction * _row_pitch
		accept_event()
