extends SceneTree

const Fixture = preload("res://tests/helpers/deck_element_reward_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Elements = preload("res://scripts/element_data.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Sequence = preload("res://scripts/post_combat_reward_sequence.gd")

const RESOLUTION := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/deck_element_reward"
const FIRE_ROOM_SEED: int = 7320
const FOCUS_SETTLE_SECONDS: float = 0.18
const GEOMETRY_TOLERANCE: float = 1.0
const PREPARATION_DRAIN_MSEC: int = 5000
const MIN_CAPTION_PADDING: float = 10.0
const CAPTION_ICON_HEIGHT: float = 20.0
const MIN_FRAME_GAP: float = 6.0
const MAX_FRAME_GAP: float = 8.0

var viewport: SubViewport
var scene: Node
var failures: int = 0
var capture_images: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	capture_images = DisplayServer.get_name() != "headless"
	if not capture_images:
		print("HEADLESS SEMANTICS ONLY: no renderer captures")
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = RESOLUTION
	root.size = RESOLUTION
	viewport = SubViewport.new()
	viewport.size = RESOLUTION
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var air_reward: Dictionary = _reward_state(Elements.AIR, true, Fixture.SEED)
	if air_reward.is_empty() or not Progression.save_run_state(air_reward):
		_check(false, "The initial proof reward must be resumable")
		quit(1)
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(scene)
	if capture_images:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
		root.warp_mouse(Vector2(2.0, 2.0))
	await _capture_case("fire_deck_air_room", true, 1)
	scene.call("_load_run_state", _reward_state(Elements.FIRE, true, FIRE_ROOM_SEED))
	await _capture_case("fire_deck_fire_room", true, 2)
	scene.call("_load_run_state", _reward_state(Elements.AIR, false, Fixture.SEED))
	await _capture_case("neutral_deck", false, 0)
	await _drain_preparation()
	viewport.queue_free()
	await process_frame
	await process_frame
	print("DECK ELEMENT REWARD UI: %d failures" % failures)
	print("TEST RESULT: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)

func _reward_state(room_element: String, with_fire: bool, seed_value: int) -> Dictionary:
	var engine := Run.new()
	var combat: Dictionary = Fixture.combat(engine, room_element, with_fire, seed_value)
	var state: Dictionary = engine.finish_combat(combat, Fixture.victory(combat))
	if state.get("mode", "") != "reward": return {}
	state["pending_reward"]["intro_pending"] = false
	return state

func _capture_case(name: String, with_fire: bool, expected_count: int) -> void:
	await process_frame
	await process_frame
	await process_frame
	var row: HBoxContainer = scene.find_child("RewardCardRow", true, false)
	_check(row != null and row.is_visible_in_tree() and row.get_child_count() == 3, name + " presents three reward slots")
	if row == null or row.get_child_count() != 3: return
	var cards: Array[Control]
	var marked_card: Control
	var count: int = 0
	for slot: Control in row.get_children():
		var card: Control = slot.find_child("CardWidget", true, false)
		var marker: PanelContainer = slot.find_child("RewardDeckCaption", true, false)
		var card_id: String = slot.get_meta("reward_card_id")
		var should_mark: bool = with_fire and Data.card_element(card_id) == Elements.FIRE
		_check((marker != null) == should_mark, "%s marks only matching cards (%s)" % [name, card_id])
		_check(card != null and card.focus_mode == Control.FOCUS_ALL, "%s keeps the card focusable (%s)" % [name, card_id])
		if card == null: continue
		cards.append(card)
		if marker == null: continue
		count += 1
		var icon: TextureRect = marker.find_child("ElementIcon", true, false)
		var caption: Label = marker.find_child("Caption", true, false)
		var painted_icon: AtlasTexture = icon.texture as AtlasTexture
		var source_icon: Texture2D = Assets.load_texture(Elements.icon_path(Elements.FIRE))
		_check(painted_icon != null and painted_icon.atlas == source_icon and painted_icon.region == Rect2(Assets.texture_used_rect(source_icon)), name + " sizes the approved Fire icon to its painted area")
		var badge: Label = card.get_node("RewardOwnershipBadge").get_child(0)
		_check(caption.text == "Your deck" and caption.get_theme_font_size("font_size") == badge.get_theme_font_size("font_size") and caption.get_theme_font("font") == badge.get_theme_font("font"), name + " matches the NEW tag typography")
		_check(absf(icon.get_global_rect().size.y - CAPTION_ICON_HEIGHT) <= GEOMETRY_TOLERANCE, name + " draws the icon at 20 px at rest")
		_check(marker.focus_mode == Control.FOCUS_NONE and marker.mouse_filter == Control.MOUSE_FILTER_IGNORE, name + " keeps the caption out of input navigation")
		_check(_caption_fits(marker, card, slot), name + " puts the visible caption centered above the card")
		var shape: Rect2 = marker.get_global_rect()
		var left_padding: float = icon.get_global_rect().position.x - shape.position.x
		var right_padding: float = shape.end.x - caption.get_global_rect().end.x
		print("DECK CAPTION %s %s: padding %.1f / %.1f, icon %.1f, frame gap %.1f px" % [name, card_id, left_padding, right_padding, icon.get_global_rect().size.y, card.get_global_rect().position.y - shape.end.y])
		marked_card = card
	_check(count == expected_count, "%s has %d marked cards (expected %d)" % [name, count, expected_count])
	_check_focus(cards, name)
	if capture_images: await _save_capture(name)
	if marked_card != null: await _check_focused_caption(marked_card, name)
	print("DECK ELEMENT REWARD UI %s: %d marked" % [name, count])

func _check_focus(cards: Array[Control], name: String) -> void:
	var recover: Control = scene.find_child("RewardRecoverButton", true, false)
	for index: int in range(cards.size()):
		var card: Control = cards[index]
		_check(card.get_node_or_null(card.focus_neighbor_left) == cards[posmod(index - 1, cards.size())], name + " retains the leftward focus path")
		_check(card.get_node_or_null(card.focus_neighbor_right) == cards[(index + 1) % cards.size()], name + " retains the rightward focus path")
		_check(recover != null and card.get_node_or_null(card.focus_neighbor_bottom) == recover, name + " retains focus navigation to Recover")

func _check_focused_caption(card: Control, name: String) -> void:
	var slot: Control = card.get_parent().get_parent()
	var marker: Control = slot.find_child("RewardDeckCaption", true, false)
	card.grab_focus()
	await create_timer(FOCUS_SETTLE_SECONDS).timeout
	_check(card.has_focus() and card.z_index == 20, name + " retains the normal focus lift")
	_check(_caption_fits(marker, card, slot), name + " caption clears the focused card")
	if capture_images and name == "fire_deck_air_room": await _save_capture(name + "_focused")
	card.release_focus()
	var tooltips: Control = scene.get("_card_focus_tooltip_stack")
	card.mouse_entered.emit()
	_check(tooltips.is_visible_in_tree() and tooltips.get("_follow_target") == card, name + " opens the existing card hover tooltip")
	await create_timer(FOCUS_SETTLE_SECONDS).timeout
	_check(_caption_fits(marker, card, slot), name + " caption follows the hover lift")
	card.mouse_exited.emit()
	_check(not tooltips.is_visible_in_tree(), name + " closes the card hover tooltip on exit")
	Sequence.prepare_card_slot(slot, scene.CARD_BACK_TEXTURE_PATH)
	_check(not marker.is_visible_in_tree(), name + " hides the caption on the unrevealed card back")
	Sequence.reveal_card_face(slot, true)
	_check(marker.is_visible_in_tree() and card.focus_mode == Control.FOCUS_ALL, name + " reveals the caption with the face and restores card focus")

func _caption_fits(marker: Control, card: Control, slot: Control) -> bool:
	var caption_rect: Rect2 = marker.get_global_rect()
	var card_rect: Rect2 = card.get_global_rect()
	var icon: Rect2 = (marker.find_child("ElementIcon", true, false) as Control).get_global_rect()
	var label: Rect2 = (marker.find_child("Caption", true, false) as Control).get_global_rect()
	var dial: Rect2 = (card.get_node("TimeCostBadge") as Control).get_global_rect()
	var slot_rect: Rect2 = slot.get_global_rect()
	var gap: float = card_rect.position.y - caption_rect.end.y
	return (
		marker.is_visible_in_tree() and viewport.get_visible_rect().encloses(caption_rect)
		and caption_rect.position.x >= slot_rect.position.x and caption_rect.end.x <= slot_rect.end.x
		and gap >= MIN_FRAME_GAP and gap <= MAX_FRAME_GAP
		and absf(caption_rect.get_center().x - card_rect.get_center().x) <= GEOMETRY_TOLERANCE
		and absf(icon.get_center().y - label.get_center().y) <= GEOMETRY_TOLERANCE
		and icon.position.x - caption_rect.position.x >= MIN_CAPTION_PADDING
		and caption_rect.end.x - label.end.x >= MIN_CAPTION_PADDING
		and not dial.intersects(caption_rect)
	)

func _save_capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = "%s/%s.png" % [OUTPUT_DIR, name]
	var image: Image = viewport.get_texture().get_image()
	_check(image != null and image.get_size() == RESOLUTION, name + " renderer returns the exact proof size")
	if image == null or image.get_size() != RESOLUTION: return
	_check(image.save_png(path) == OK, name + " writes a PNG")
	print("CAPTURE: " + ProjectSettings.globalize_path(path))

func _drain_preparation() -> void:
	var deadline: int = Time.get_ticks_msec() + PREPARATION_DRAIN_MSEC
	while Time.get_ticks_msec() < deadline:
		if scene.get("_character_row_preparation_running_revision") == -1 and scene.get("_grimoire_row_preparation_running_revision") == -1:
			return
		await process_frame

func _check(condition: bool, message: String) -> void:
	if condition: return
	failures += 1
	push_error(message)
