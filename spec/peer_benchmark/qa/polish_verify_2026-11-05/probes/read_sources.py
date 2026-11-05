"""Snapshot exact-release source evidence; no product writes."""
from pathlib import Path
import hashlib
import json
import re
import subprocess

BASE = Path(__file__).resolve().parents[1]
GROUPS = {
'hover': {'scripts/run_scene.gd': [r'^func _cancel_card_selection', r'^func _resolve_hand_pointer', r'^func _on_hand_slide_finished', r'^func _fit_current_hand_layout_to_visible_width', r'^func _complete_hand_layout_pending', r'^func _wait_for_hand_hover_rest', r'^func _flush_hand_hover_emphasis', r'^func _on_card_hover_started'], 'tests/card_draw_hand_flow_test.gd': [r'^func _run_resting_pointer_regression']},
'item_rows': {'scripts/run_scene.gd': [r'^func _build_item_card_tile_body', r'CardDisplay.resolved_rules_text'], 'tests/card_display_overrides_test.gd': [r'Pack row uses Long Dawn']},
'deck_strips': {'scripts/ui_card_strip.gd': [r'const LIST_WIDTH',r'^func _fit_name'], 'scripts/character_card_strip.gd': [r'^func _fit_name'], 'scripts/character_menu_view.gd': [r'^static func deck_list']},
'pack_focus': {'scripts/character_menu_view.gd': [r'^static func sync_tile',r'^static func row_body'], 'scripts/run_scene.gd': [r'^func _apply_controller_loadout_focus_style']},
'boon': {'scripts/opening_boon_card.gd': [r'276',r'Strip',r'custom_minimum_size']},
'shop': {'scripts/run_engine.gd': [r'^func merchant_sellable_ids',r'^func _repair_magic_state_in_place'], 'scripts/scavenger_shop_view.gd': [r'Two framed tabs',r'func .*filter',r'func .*page'], 'scripts/magic_purge_overlay.gd': [r'SCAVENGER_SERVICE_GAP',r'ScavengerPurge',r'^func select_card']},
'caption': {'scripts/run_scene.gd': [r'ACTION_BANNER_MIN_WIDTH',r'ACTION_BANNER_HEIGHT',r'^func _layout_action_banner',r'^func _boss_move_caption']},
'run_end': {'scripts/combat_objective_hud.gd': [r'^func _live_detail'], 'scripts/run_score_rules.gd': [r'DEFAULT_TITLES',r'All six',r'^static func.*title'], 'scripts/run_end_recap_overlay.gd': [r'_total_value.position.x',r'large action',r'func .*victory',r'NewBestTag',r'func .*chronicle'], 'scripts/chronicle_rules.gd': [r'^static func result_word']},
'keyword_body': {'scripts/ui_tooltip_panel.gd': [r'ICON_BODY_WIDTH',r'^static func _make_text_box'], 'scripts/card_focus_tooltip_stack.gd': [r'func .*keyword',r'func .*rest']},
'copy': {'scripts/run_scene.gd': [r'stats_label.text = "LV',r'_play_meter_count.text',r'_movement_meter_count.text'], 'scripts/settings_panel.gd': [r'Fullscreen or windowed',r'Reduced motion',r'Reset every setting',r'confirm.text =',r'restore.text =']},
'doors': {'scripts/combat_board_view.gd': [r'_draw_door_icon\(icon_texture',r'^func _draw_door_icon',r'^func _draw_death_health_bars']},
'map': {'scripts/section_map_graph.gd': [r'node\["npcs"\]',r'"npcs":.*scavenger'], 'scripts/run_scene.gd': [r'func _open_large_map',r'_large_map_scrim.color',r'const ROOM_KIND_TITLES',r'^func _room_title_text'], 'scripts/section_map_panel.gd': [r'^func room_description',r'^func can_activate_room',r'func .*tooltip'], 'scripts/section_map_node.gd': [r'^func _draw_face',r'lantern_marker']},
'dragon': {'scripts/dragon_arrival.gd': [r'^const HOLD_SECONDS',r'^static func opening_motion',r'^static func play'], **{'scripts/'+id+'_cutout/motion.gd': [r'clip == "roar"'] for id in ['tharokh','vyraketh','vaeloryx','iskaldra','zekarion','noctyrax']}, 'scripts/run_scene.gd': [r'^func _present_opening_hand_after_combat_entry']},
'area_copy': {'scripts/action_icon_library.gd': [r'aim tile needs range/LOS',r'^static func card_role_emblem_key'], 'data/glossary.json': [r'Damage a target in Range and line of sight'], 'data/card_panel_text.json': [r'area',r'even']},
'event': {'scripts/event_health_strip.gd': [r'NUMBER_GAP',r'^func _spawn_number'], 'scripts/event_view_choice.gd': [r'mouse_entered.connect',r'focus_entered.connect'], 'scripts/event_rules.gd': [r'"skip_label": "Skip"'], 'scripts/event_view.gd': [r'^func _play',r'^func present']},
'popup': {'scripts/run_scene.gd': [r'^func _animate_player_action_step',r'^func _floating_texts_for_step',r'^func _status_damage_floating_texts',r'^func _decorate_bleed_damage_float'], 'scripts/floating_combat_text.gd': [r'^static func damage_hit_scale',r'Reserve peak glyph bounds']},
'reward': {'scripts/run_scene.gd': [r'^func _on_reward_card_pressed',r'^func _animate_magic_reward_acquisition_flair',r'^func _animate_loadout_acquisition_ray',r'^func _open_skill_choice_dialog',r'^func _skill_choice_panel_style',r'^func _reward_secondary_button',r'^func _build_reward_choice_stack',r'LOADOUT_ACQUISITION_RAY_SECONDS'], 'scripts/run_engine.gd': [r'MISSED_EQUIPMENT_NOTICE if',r'^func finish_combat'], 'scripts/card_area_presentation.gd': [r'^static func attack_type']},
'purge': {'scripts/magic_purge_confirmation.gd': [r'^func play_exhaust',r'^func _layout'], 'scripts/magic_purge_overlay.gd': [r'^func _layout',r'^func select_card'], 'scripts/run_scene.gd': [r'^func _confirm_magic_purge']},
'audio': {'scripts/run_scene.gd': [r'^const CARD_PLAY_SFX_ENTRY',r'^func _show_turn_banner',r'^func _animate_card_play_reward',r'^func _music_context_is_transient'], 'scripts/sfx_cue_router.gd': [r'^func presentation',r'arrival_animation',r'^func ground_fire_burns',r'GROUND_BURN_KINDS',r'^func hit',r'^func baseline'], 'scripts/settings_store.gd': [r'"master_volume": 0.80',r'SFX_HEADROOM_DB']},
'chronicle': {'scripts/chronicle_panel.gd': [r'^func open',r'No descents yet',r'Your first descent'], 'scripts/main_menu.gd': [r'^func _on_settings_button_pressed',r'^func _on_chronicle_button_pressed']},
'pre_battle': {'scripts/pre_battle_view.gd': [r'^static func _equipped_weapon_icon',r'PreBattleEquipButton']},
'notice': {'scripts/run_scene.gd': [r'^func _board_notice_text',r'var grimoire_notice:',r'layout.get\("npcs"'], 'scripts/grimoire_library.gd': [r'Added %d entries'], 'scripts/room_generator.gd': [r'room_type == "graftwright"']},
'line_aim': {'scripts/line_opening_aim.gd': [r'^static func direction'], 'scripts/enemy_mechanics/reaction_loss_ownership.gd': [r'^static func arrival_steps', r'^static func _cascade_step']},
'projection': {'scripts/turn_order_landing_strip.gd': [r'^static func placement',r'font_size',r'cost',r'projected_card']},
'settings': {'scripts/settings_panel.gd': [r'^func _add_volume_row',r'^func _show_restore_confirmation'], 'scripts/main_menu.gd': [r'^func _on_settings_button_pressed',r'^func _on_start_button_pressed']},
}
rows=[]; manifest={}
for group, files in GROUPS.items():
 for name, patterns in files.items():
  p=Path(name)
  if not p.is_file():
   rows.append({'group':group,'path':name,'missing':True}); continue
  text=p.read_text(); lines=text.splitlines()
  manifest[name]=hashlib.sha256(p.read_bytes()).hexdigest()
  for pattern in patterns:
   matches=[i for i,line in enumerate(lines) if re.search(pattern,line)]
   for i in matches[:3]:
    # Functions include enough context to distinguish old from current paths.
    n=30 if lines[i].startswith(('func ','static func ')) else 7
    rows.append({'group':group,'path':name,'line':i+1,'pattern':pattern,'excerpt':'\n'.join(f'{j+1}: {lines[j]}' for j in range(max(0,i-2),min(len(lines),i+n)))})
(BASE/'evidence/sources.json').write_text(json.dumps(rows,indent=2)+'\n')
(BASE/'evidence/source_manifest.json').write_text(json.dumps({'head':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'files':manifest},indent=2)+'\n')
print('QA52 SOURCE SNAPSHOT COMPLETE excerpts=%d files=%d missing_files=%d' % (len(rows),len(manifest),sum(bool(r.get('missing')) for r in rows)))
