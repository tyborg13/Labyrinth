extends RefCounted

# Definition provenance belongs to the owning production builder, not to the
# fact that its eventual CardWidget can accept an arbitrary test override.
static func contract(id: String) -> Dictionary:
	if id.begins_with("hand_"):
		return _source("both", "scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides")
	if id.begins_with("scavenger_"):
		return _source("both", "scripts/scavenger_shop_view.gd: _build_native_scaled_card -> card.configure(...); CardDisplay.bind(card, _run_state)")
	if id.begins_with("card_fx_staged") or id == "card_drag_proxy":
		return _source("both", "scripts/run_scene.gd: _animate_card_play_fx / _spawn_card_proxy -> widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display -> widget.set_display_overrides")
	match id:
		"boon_spells":
			return _source("both", "scripts/opening_boon_overlay.gd: _spell_choice -> widget.configure(...); CardDisplay.bind(widget, _state)")
		"deck_view", "campfire", "purge_picker":
			return _source("both", "scripts/magic_purge_overlay.gd: configure -> PileView.card_cell(host, id, count, select_card); scripts/pile_dialog_view.gd: card_cell -> cell.widget.configure(card_id); CardDisplay.bind(cell.widget, host._card_display_state())")
		"purge_confirmation":
			return _source("both", "scripts/magic_purge_confirmation.gd: present -> card.configure(card_id, false, false, true, false, false); CardDisplay.bind(card, host._card_display_state())")
		"graftwright":
			return _source("both", "scripts/graftwright_view.gd: _card -> card.configure(id, false, false, true, false, false); CardDisplay.bind(card, state)")
		"graftwright_inspection":
			return _source("both", "scripts/graftwright_view.gd: _open_inspection -> Tooltip.make_lines(_card_name(id), [CardDisplay.rules_text(id, face.definition, face.display_summary_rows())])")
		"reward_offers":
			return _source("both", "scripts/run_scene.gd: _add_reward_choice_card -> widget.configure(..., _card_def(card_id) if definition.is_empty() else definition)")
		"grimoire", "grimoire_equipment":
			return _source("both", "scripts/run_scene.gd: _populate_grimoire_card_detail / _populate_grimoire_equipment_detail -> _build_card_preview_widget -> _item_preview_builder().card_preview; definition_resolver = _card_def -> GameData.card_def_for_progression")
		"card_tooltip", "equipment_tooltip":
			return _source("both", "scripts/run_scene.gd: _build_card_tooltip_panel / _build_equipment_tooltip_panel -> _item_preview_builder; scripts/item_preview_builders.gd: card_preview -> widget.configure(..., card_definition(id)); definition_resolver = RunScene._card_def")
		"chronicle_card", "chronicle_equipment":
			return _source("both", "scripts/chronicle_panel.gd: _build_detail -> _tooltip_host.definitions[id] = Rules.card_definition(id, record.deck_card_definitions); scripts/item_preview_builders.gd: card_preview -> widget.configure(..., card_definition(id))")
		"pile_dialog":
			return _source("both", "scripts/run_scene.gd: _append_pile_dialog_card_pool_entry / _open_pile_view -> widget.configure(..., _card_def(card_id, _combat_state))")
		"upgrade_preview":
			return _source("both", "scripts/run_scene.gd: _upgrade_refresh_options / _build_upgrade_option_row -> widget.configure(..., GameData.card_def_for_progression(...) / GameData.preview_card_with_mod(...))")
	# Unknown contexts cannot silently inherit the broadest sampling policy.
	return _source("", "")

static func _source(kind: String, builder: String) -> Dictionary:
	return {"definition_source": kind, "production_builder_call": builder}

static func entries_for(context: Dictionary, entries: Array) -> Array:
	match str(context.get("definition_source", "")):
		"base": return entries.filter(func(entry: Dictionary) -> bool: return entry["variant"] == "base")
		"modified": return entries.filter(func(entry: Dictionary) -> bool: return entry["variant"] != "base")
		"both": return entries
	return []

static func counts(entries: Array) -> Dictionary:
	var base: int = entries.filter(func(entry: Dictionary) -> bool: return entry["variant"] == "base").size()
	return {"base": base, "modified": entries.size() - base}

static func write_result(path: String, entries: Array, minimums: Array, sample_count: int) -> void:
	var inventory: Dictionary = counts(entries)
	var lines := PackedStringArray([
		"# pt13-08 observed card-legibility results", "",
		"1920×1080; 100% UI scale; 14 px rules and 16 px icon floors; seven existing exemptions. Measurements use native production screen hierarchies after three stable frames, with a three-second settling cap.", "",
		"%d distinct definitions (%d base, %d modified); %d contexts; %d measurements." % [entries.size(), inventory["base"], inventory["modified"], minimums.size(), sample_count], "",
		"Each context samples base and modified definitions through its production builder. Run-scoped ID builders share CardDisplay with the hand; Chronicle retains its recorded definitions. Strict rules-body content identity is unchanged.", "",
		"| Context | Definition source | Base definitions | Modified definitions | Samples | Production builder call |",
		"|---|---|---:|---:|---:|---|",
	])
	for row: Dictionary in minimums:
		lines.append("| %s | %s | %d | %d | %d | `%s` |" % [row["context"], row["definition_source"], row["definition_counts"]["base"], row["definition_counts"]["modified"], row["samples"], row["production_builder_call"]])
	lines.append_array(PackedStringArray(["", "| Context | Rules px | Token px | Footer px | Icon px | Sample failures | Overflow cases | Exemption |", "|---|---:|---:|---:|---:|---:|---:|---|"]))
	for row: Dictionary in minimums:
		lines.append("| %s | %s | %s | %s | %s | %d | %d | %s |" % [row["context"], _number(row["text_px"]["rules"]), _number(row["text_px"]["token_number"]), _number(row["text_px"]["footer"]), _number(row["icon_px"]), row["sample_failure_count"], row["overflow_count"], row["exemption"]])
	lines.append_array(PackedStringArray(["", "Per-definition measurements, expected rules text, match counts, native ancestor transforms, variant aliases, overflow and equipment bounds are recorded in `audit.json`. `README.md` and the earlier verification reports retain the card-fitter rationale and historical evidence; the before evidence was recorded at 591da4132.", ""]))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))

static func _number(value: Variant) -> String:
	return "—" if value == null else "%.3f" % float(value)
