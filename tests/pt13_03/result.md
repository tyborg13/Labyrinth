# pt13-08 observed card-legibility results

1920×1080; 100% UI scale; 14 px rules and 16 px icon floors; seven existing exemptions. Measurements use native production screen hierarchies after three stable frames, with a three-second settling cap.

2334 distinct definitions (309 base, 2025 modified); 32 contexts; 52413 measurements.

Each context samples only definitions accepted by its production builder. ID-only builders use base definitions. Builders that accept definitions or resolve progression / Chronicle snapshots retain base and modified coverage. Strict rules-body content identity is unchanged.

| Context | Definition source | Base definitions | Modified definitions | Samples | Production builder call |
|---|---|---:|---:|---:|---|
| hand_1_rest | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_1_focused | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_1_hovered | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_1_targeting | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_7_rest | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_7_focused | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_7_hovered | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_7_targeting | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| hand_controller_focused | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: hand widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display_for_index -> widget.set_display_overrides` |
| reward_offers | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _add_reward_choice_card -> widget.configure(..., _card_def(card_id) if definition.is_empty() else definition)` |
| boon_spells | base | 309 | 0 | 309 | `scripts/opening_boon_overlay.gd: _spell_choice -> widget.configure(..., Data.card_def(id))` |
| scavenger_offer | base | 309 | 0 | 309 | `scripts/scavenger_shop_view.gd: _build_native_scaled_card -> card.configure(..., GameData.card_def(item_id))` |
| scavenger_sell | base | 309 | 0 | 309 | `scripts/scavenger_shop_view.gd: _build_native_scaled_card -> card.configure(..., GameData.card_def(item_id))` |
| scavenger_receipt | base | 309 | 0 | 309 | `scripts/scavenger_shop_view.gd: _build_native_scaled_card -> card.configure(..., GameData.card_def(item_id))` |
| scavenger_detail | base | 309 | 0 | 309 | `scripts/scavenger_shop_view.gd: _build_native_scaled_card -> card.configure(..., GameData.card_def(item_id))` |
| deck_view | base | 309 | 0 | 309 | `scripts/magic_purge_overlay.gd: configure -> PileView.card_cell(host, id, count, select_card); scripts/pile_dialog_view.gd: card_cell -> cell.widget.configure(card_id) -> GameData.card_def(card_id)` |
| grimoire | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _populate_grimoire_card_detail / _populate_grimoire_equipment_detail -> _build_card_preview_widget -> _item_preview_builder().card_preview; definition_resolver = _card_def -> GameData.card_def_for_progression` |
| grimoire_equipment | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _populate_grimoire_card_detail / _populate_grimoire_equipment_detail -> _build_card_preview_widget -> _item_preview_builder().card_preview; definition_resolver = _card_def -> GameData.card_def_for_progression` |
| card_tooltip | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _build_card_tooltip_panel / _build_equipment_tooltip_panel -> _item_preview_builder; scripts/item_preview_builders.gd: card_preview -> widget.configure(..., card_definition(id)); definition_resolver = RunScene._card_def` |
| chronicle_card | both | 309 | 2025 | 2334 | `scripts/chronicle_panel.gd: _build_detail -> _tooltip_host.definitions[id] = Rules.card_definition(id, record.deck_card_definitions); scripts/item_preview_builders.gd: card_preview -> widget.configure(..., card_definition(id))` |
| equipment_tooltip | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _build_card_tooltip_panel / _build_equipment_tooltip_panel -> _item_preview_builder; scripts/item_preview_builders.gd: card_preview -> widget.configure(..., card_definition(id)); definition_resolver = RunScene._card_def` |
| chronicle_equipment | both | 309 | 2025 | 2334 | `scripts/chronicle_panel.gd: _build_detail -> _tooltip_host.definitions[id] = Rules.card_definition(id, record.deck_card_definitions); scripts/item_preview_builders.gd: card_preview -> widget.configure(..., card_definition(id))` |
| graftwright | base | 309 | 0 | 309 | `scripts/graftwright_view.gd: _card -> card.configure(id, false, false, true, false, false) -> GameData.card_def(id)` |
| graftwright_inspection | base | 309 | 0 | 309 | `scripts/graftwright_view.gd: _open_inspection -> Tooltip.make_lines(_card_name(id), [ActionIcons.card_rules_text(Data.card_def(id))])` |
| campfire | base | 309 | 0 | 309 | `scripts/magic_purge_overlay.gd: configure -> PileView.card_cell(host, id, count, select_card); scripts/pile_dialog_view.gd: card_cell -> cell.widget.configure(card_id) -> GameData.card_def(card_id)` |
| purge_picker | base | 309 | 0 | 309 | `scripts/magic_purge_overlay.gd: configure -> PileView.card_cell(host, id, count, select_card); scripts/pile_dialog_view.gd: card_cell -> cell.widget.configure(card_id) -> GameData.card_def(card_id)` |
| pile_dialog | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _append_pile_dialog_card_pool_entry / _open_pile_view -> widget.configure(..., _card_def(card_id, _combat_state))` |
| purge_confirmation | base | 309 | 0 | 309 | `scripts/magic_purge_confirmation.gd: present -> card.configure(card_id, false, false, true, false, false) -> GameData.card_def(card_id)` |
| upgrade_preview | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _upgrade_refresh_options / _build_upgrade_option_row -> widget.configure(..., GameData.card_def_for_progression(...) / GameData.preview_card_with_mod(...))` |
| card_drag_proxy | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _animate_card_play_fx / _spawn_card_proxy -> widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display -> widget.set_display_overrides` |
| card_fx_staged | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _animate_card_play_fx / _spawn_card_proxy -> widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display -> widget.set_display_overrides` |
| card_fx_staged_reduced_motion | both | 309 | 2025 | 2334 | `scripts/run_scene.gd: _animate_card_play_fx / _spawn_card_proxy -> widget.configure(..., _card_def(card_id, _combat_state)); _card_widget_display -> widget.set_display_overrides` |

| Context | Rules px | Token px | Footer px | Icon px | Sample failures | Overflow cases | Exemption |
|---|---:|---:|---:|---:|---:|---:|---|
| hand_1_rest | 13.312 | 13.312 | — | 16.640 | 0 | 4 | hand at rest; hover/focus shows it at 17 px |
| hand_1_focused | 17.039 | 17.039 | — | 21.299 | 0 | 4 |  |
| hand_1_hovered | 17.039 | 17.039 | — | 21.299 | 0 | 4 |  |
| hand_1_targeting | 14.790 | 14.790 | — | 18.487 | 0 | 4 |  |
| hand_7_rest | 13.312 | 13.312 | — | 16.640 | 0 | 4 | hand at rest; hover/focus shows it at 17 px |
| hand_7_focused | 17.039 | 17.039 | — | 21.299 | 0 | 4 |  |
| hand_7_hovered | 17.039 | 17.039 | — | 21.299 | 0 | 4 |  |
| hand_7_targeting | 14.790 | 14.790 | — | 18.487 | 0 | 4 |  |
| hand_controller_focused | 19.497 | 19.497 | — | 24.371 | 0 | 4 |  |
| reward_offers | 18.688 | 18.688 | — | 23.360 | 0 | 4 |  |
| boon_spells | 15.636 | 15.636 | — | 19.545 | 0 | 1 |  |
| scavenger_offer | 11.273 | 11.273 | — | 14.091 | 0 | 1 | shop shelf; hover/focus shows scavenger_detail at 16 px |
| scavenger_sell | 6.364 | 6.364 | — | 7.955 | 0 | 1 | thumbnail; scavenger_detail shows it at 16 px |
| scavenger_receipt | 4.409 | 4.409 | — | 5.511 | 0 | 1 | thumbnail; scavenger_detail shows it at 16 px |
| scavenger_detail | 16.000 | 16.000 | — | 20.000 | 0 | 1 |  |
| deck_view | 14.016 | 14.016 | — | 17.520 | 0 | 1 |  |
| grimoire | 15.360 | 15.360 | — | 19.200 | 0 | 4 |  |
| grimoire_equipment | 14.016 | 14.016 | — | 17.520 | 0 | 4 |  |
| card_tooltip | 14.336 | 14.336 | — | 17.920 | 0 | 4 |  |
| chronicle_card | 14.336 | 14.336 | — | 17.920 | 0 | 4 |  |
| equipment_tooltip | 14.336 | 14.336 | — | 17.920 | 0 | 4 |  |
| chronicle_equipment | 14.336 | 14.336 | — | 17.920 | 0 | 4 |  |
| graftwright | 14.016 | 14.016 | — | 17.520 | 0 | 1 |  |
| graftwright_inspection | 16.000 | — | — | — | 0 | 0 |  |
| campfire | 14.016 | 14.016 | — | 17.520 | 0 | 1 |  |
| purge_picker | 14.016 | 14.016 | — | 17.520 | 0 | 1 |  |
| pile_dialog | 14.016 | 14.016 | — | 17.520 | 0 | 4 |  |
| purge_confirmation | 16.000 | 16.000 | — | 20.000 | 0 | 1 |  |
| upgrade_preview | 14.016 | 14.016 | — | 17.520 | 0 | 4 |  |
| card_drag_proxy | 11.182 | 11.182 | — | 13.978 | 0 | 4 | transient while dragging |
| card_fx_staged | 14.377 | 14.377 | — | 17.971 | 0 | 4 |  |
| card_fx_staged_reduced_motion | 13.578 | 13.578 | — | 16.973 | 0 | 4 | transient play effect |

Per-definition measurements, expected rules text, match counts, native ancestor transforms, variant aliases, overflow and equipment bounds are recorded in `audit.json`. `README.md` and the earlier verification reports retain the card-fitter rationale and historical evidence; the before evidence was recorded at 591da4132.
