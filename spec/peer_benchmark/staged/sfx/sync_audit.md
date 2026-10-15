# SFX sync audit

Current measurement policy

Alignment uses the earliest local maximum within 2 dB of the strongest centered 5 ms RMS peak. Asset cuts measure instantaneous max-channel amplitude before fading and move to a point at least 20 dB below the selected RMS peak, retain at least 15 ms before it, and use a 3 ms linear fade. An already-short source head is kept whole rather than padded. The asset's complete tail is retained. The lossless parent recipe and its hash are recorded in the compact provenance.

Blink (including relay and swaps), cast.arcane, and animated roars plan each call at its actual selected pitch. The same per-call rule covers hit.blunt.heavy and illusion.spawn because their quiet asset cuts retain more pre-peak time than the contact window permits. Runtime head skips use the separate minimum-pre-peak and fade rule; the quiet-cut rule applies to lossless asset rebuilds. The actual submitted climax sets an absolute presentation-clock deadline; due calls dispatch in that process tick, without extrapolating frame intervals. Late dispatch skips the corresponding pitch-adjusted head, bounded by the 15 ms minimum pre-peak lead, with the 3 ms fade and whole tail preserved. Presentation deadlines freeze during pause or hit-stop. Aligned peaks must land at climax +15 ±1 ms; their onset cap is measured from scheduled playback. Other one-shots retain the 0–20 ms first-sample, ≤10 ms leading-silence, and 40/60 ms perceived-onset limits. All tunables live in data/sfx_cues.json rules.sync.

Every scenario runs at 1×, 1.5× and 2× with fixed 60 Hz, periodic 33 ms spikes, steady 30 fps, 144 Hz and seeded ±4 ms jitter. Coverage baselines requests, successful primaries and successful optional layers separately for each run. Primary priority drops always fail; cooldown drops require a preceding successful play within the authored cooldown. Optional-layer priority drops and intentionally empty ambient beds are recorded explicitly.

Gain restoration respects the original build's category/sample cap and −1 dBTP. Maximum BS.1770 loudness over 100 ms windows at 25 ms hops may change by −1.0…+0.5 LU. Same-frame contacts collapse only identical cues; distinct contacts remain audible. Additional contacts retain −6 dB layering.

Current results

`{"cue_call_site_rows": 136, "cues": 81, "loudness_exceptions": 2, "observations": 3950, "registry_cues": 81, "uncovered_call_sites": 0, "uncovered_cue_call_site_pairs": 0, "unmeasured": 0, "violations": 0}`

| Cue | Call site | Onset ms | Perceived ms | Peak − climax ms | Result |
|---|---|---:|---:|---:|---|
| hit.blade.light | scripts/sfx_cue_router.gd::hit | 0.965 | 11.513 | 25.675…28.377 | loudness exception |
| hit.blade.light | scripts/sfx_cue_router.gd::hit | 0.965 | 11.513 | 25.675…28.377 | loudness exception |
| hurt.hero | scripts/sfx_cue_router.gd::hit | 0.217 | 1.736 | 14.704…15.929 | loudness exception |
| hurt.hero | scripts/sfx_cue_router.gd::presentation | 0.217 | 1.736 | 14.704…15.929 | loudness exception |
| status.shatter | scripts/sfx_cue_router.gd::hit | unmeasured | unmeasured | unmeasured…unmeasured | dropped |
| ambience.iskaldra | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| ambience.noctyrax | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| ambience.stone | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| ambience.tharokh | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| ambience.vaeloryx | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| ambience.vyraketh | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| ambience.zekarion | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.000 | 11034.376 | unmeasured…unmeasured | pass |
| block.break | scripts/sfx_cue_router.gd::hit | 0.152 | 7.834 | 14.463…15.668 | pass |
| block.gain | scripts/sfx_cue_router.gd::presentation | 0.911 | 16.602 | 19.411…21.029 | pass |
| card.exhaust | scripts/run_scene.gd::_consume_pending_card_draw_sfx | 0.217 | 2.756 | 14.623…15.842 | pass |
| card.exhaust | scripts/sfx_cue_router.gd::card_exhaust | 0.217 | 2.756 | 14.623…15.842 | pass |
| card.hover | scripts/run_scene.gd::_on_card_hover_started | 1.574 | 4.765 | 4.363…4.920 | pass |
| card.hover | scripts/sfx_cue_router.gd::card_hover | 1.574 | 4.765 | 4.363…4.920 | pass |
| card.invalid | scripts/run_scene.gd::_on_card_pressed | 3.699 | 26.063 | 27.471…28.593 | pass |
| card.invalid | scripts/run_scene.gd::_on_card_pressed | 3.699 | 26.063 | 27.471…28.593 | pass |
| card.invalid | scripts/run_scene.gd::_on_card_drag_started | 3.699 | 26.063 | 27.471…28.593 | pass |
| card.invalid | scripts/run_scene.gd::_on_board_tile_clicked | 3.699 | 26.063 | 27.471…28.593 | pass |
| card.invalid | scripts/sfx_cue_router.gd::card_invalid | 3.699 | 26.063 | 27.471…28.593 | pass |
| card.select | scripts/run_scene.gd::_on_card_drag_started | 0.760 | 0.586 | 3.726…4.036 | pass |
| card.select | scripts/run_scene.gd::_begin_card_preview | 0.760 | 0.586 | 3.726…4.036 | pass |
| card.select | scripts/sfx_cue_router.gd::card_select | 0.760 | 0.586 | 3.726…4.036 | pass |
| cast.arcane | scripts/sfx_cue_router.gd::release | 66.861 | 1.494 | 15.003…15.010 | pass |
| crate.break | scripts/sfx_cue_router.gd::crate | 9.386 | 10.132 | 12.341…13.640 | pass |
| crate.hit | scripts/sfx_cue_router.gd::crate | 0.133 | 15.559 | 19.163…21.609 | pass |
| death.avian | scripts/sfx_cue_router.gd::death | 0.373 | 6.711 | 14.385…16.140 | pass |
| death.beast | scripts/sfx_cue_router.gd::death | 0.263 | 12.697 | 20.516…22.675 | pass |
| death.bone | scripts/sfx_cue_router.gd::death | 0.285 | 25.592 | 24.841…27.456 | pass |
| death.dragon | scripts/sfx_cue_router.gd::death | 0.167 | 4.812 | 22.958…22.958 | pass |
| death.hero | scripts/sfx_cue_router.gd::death | 0.146 | 5.396 | 16.979…16.979 | pass |
| death.humanoid | scripts/sfx_cue_router.gd::death | 2.127 | 16.710 | 18.930…20.508 | pass |
| death.ooze | scripts/sfx_cue_router.gd::death | 2.926 | 13.918 | 14.013…15.802 | pass |
| death.spirit | scripts/sfx_cue_router.gd::death | 0.351 | 11.404 | 26.230…28.991 | pass |
| death.stone | scripts/sfx_cue_router.gd::death | 0.260 | 26.063 | 27.123…29.384 | pass |
| deck.shuffle | scripts/run_scene.gd::_consume_pending_card_draw_sfx | 0.301 | 13.660 | 25.384…26.954 | pass |
| deck.shuffle | scripts/sfx_cue_router.gd::deck_shuffle | 0.301 | 13.660 | 25.384…26.954 | pass |
| defiance | scripts/run_scene.gd::_refresh_relic_bar | 0.333 | 4.208 | 19.125…19.125 | pass |
| defiance | scripts/sfx_cue_router.gd::defiance | 0.333 | 4.208 | 19.125…19.125 | pass |
| dragon.roar | scripts/sfx_cue_router.gd::begin_action | 0.623 | 57.925 | unmeasured…unmeasured | pass |
| dragon.roar | scripts/sfx_cue_router.gd::presentation | 600.340 | 2.708 | 15.006…15.020 | pass |
| dragon.wings | scripts/run_scene.gd::_animate_actor_along_path | 2.300 | 59.896 | unmeasured…unmeasured | pass |
| dragon.wings | scripts/sfx_cue_router.gd::walk_start | 2.300 | 59.896 | unmeasured…unmeasured | pass |
| event.choose | scripts/run_scene.gd::_on_section_map_event | 1.181 | 7.023 | 24.717…26.246 | pass |
| event.choose | scripts/sfx_cue_router.gd::event_choose | 1.181 | 7.023 | 24.717…26.246 | pass |
| fatigue | scripts/run_scene.gd::_fatigue_damage_presentation_for_elapsed | 0.765 | 2.105 | 15.033…15.646 | pass |
| fatigue | scripts/sfx_cue_router.gd::fatigue | 0.765 | 2.105 | 15.033…15.646 | pass |
| heal | scripts/sfx_cue_router.gd::heal | 0.456 | 2.995 | 17.368…22.895 | pass |
| hit.arcane | scripts/sfx_cue_router.gd::hit | 0.066 | 3.640 | 14.544…16.075 | pass |
| hit.arcane | scripts/sfx_cue_router.gd::hit | 0.066 | 3.640 | 14.544…16.075 | pass |
| hit.blade.heavy | scripts/sfx_cue_router.gd::hit | 0.174 | 3.581 | 14.704…15.929 | pass |
| hit.blade.heavy | scripts/sfx_cue_router.gd::hit | 0.174 | 3.581 | 14.704…15.929 | pass |
| hit.blocked | scripts/sfx_cue_router.gd::hit | 0.855 | 19.846 | 27.143…30.000 | pass |
| hit.blocked | scripts/sfx_cue_router.gd::hit | 0.855 | 19.846 | 27.143…30.000 | pass |
| hit.blunt.heavy | scripts/sfx_cue_router.gd::hit | 0.296 | 8.094 | 15.006…15.006 | pass |
| hit.blunt.heavy | scripts/sfx_cue_router.gd::hit | 1.013 | 11.188 | 15.002…15.003 | pass |
| hit.blunt.light | scripts/sfx_cue_router.gd::hit | 1.053 | 10.110 | 14.306…15.811 | pass |
| hit.blunt.light | scripts/sfx_cue_router.gd::hit | 1.053 | 10.110 | 14.306…15.811 | pass |
| hit.claw | scripts/sfx_cue_router.gd::hit | 0.199 | 9.486 | 14.760…16.645 | pass |
| hit.claw | scripts/sfx_cue_router.gd::hit | 0.199 | 9.486 | 14.760…16.645 | pass |
| hit.pierce | scripts/sfx_cue_router.gd::hit | 0.132 | 2.127 | 14.940…16.513 | pass |
| hit.pierce | scripts/sfx_cue_router.gd::hit | 0.132 | 2.127 | 14.940…16.513 | pass |
| illusion.break | scripts/sfx_cue_router.gd::illusion_break | 0.307 | 1.886 | 15.952…17.632 | pass |
| illusion.spawn | scripts/sfx_cue_router.gd::illusion_spawn | 0.336 | 2.937 | 15.019…15.019 | pass |
| map.hover | scripts/sfx_cue_router.gd::map_hover | 0.621 | 14.561 | 14.230…16.046 | pass |
| map.select | scripts/run_scene.gd::_on_map_view_room_selected | 2.363 | 19.652 | 21.561…22.895 | pass |
| map.select | scripts/sfx_cue_router.gd::map_select | 2.363 | 19.652 | 21.561…22.895 | pass |
| move.blink | scripts/run_scene.gd::_animate_player_action_step | 0.139 | 5.348 | 15.002…15.002 | pass |
| move.blink | scripts/sfx_cue_router.gd::blink | 266.996 | 5.886 | 15.002…15.020 | pass |
| omen.bane | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.167 | 3.854 | 16.958…16.958 | pass |
| omen.bane | scripts/sfx_cue_router.gd::omen | 0.167 | 3.854 | 16.958…16.958 | pass |
| omen.blessing | scripts/run_scene.gd::_update_ambient_sfx_for_context | 0.188 | 1.938 | 15.958…15.958 | pass |
| omen.blessing | scripts/sfx_cue_router.gd::omen | 0.188 | 1.938 | 15.958…15.958 | pass |
| pickup.gear | scripts/run_scene.gd::_animate_board_pickup_acquisitions | 0.473 | 7.775 | 24.980…26.525 | pass |
| pickup.gear | scripts/sfx_cue_router.gd::pickup | 0.473 | 7.775 | 24.980…26.525 | pass |
| pickup.item | scripts/run_scene.gd::_animate_board_pickup_acquisitions | 0.499 | 3.190 | 6.751…7.313 | pass |
| pickup.item | scripts/sfx_cue_router.gd::pickup | 0.499 | 3.190 | 6.751…7.313 | pass |
| push.collision | scripts/sfx_cue_router.gd::hit | 0.369 | 18.446 | 27.604…29.905 | pass |
| push.collision | scripts/sfx_cue_router.gd::hit | 0.369 | 18.446 | 27.604…29.905 | pass |
| push.slide | scripts/run_scene.gd::_animate_player_action_step | 6.893 | 33.112 | unmeasured…unmeasured | pass |
| push.slide | scripts/run_scene.gd::_animate_enemy_phase_steps | 6.893 | 33.112 | unmeasured…unmeasured | pass |
| push.slide | scripts/sfx_cue_router.gd::push | 6.893 | 33.112 | unmeasured…unmeasured | pass |
| radiance.light | scripts/run_scene.gd::_animate_player_action_step | 0.174 | 1.671 | 15.725…17.036 | pass |
| radiance.light | scripts/run_scene.gd::_animate_player_action_step | 0.174 | 1.671 | 15.725…17.036 | pass |
| radiance.light | scripts/sfx_cue_router.gd::light | 0.174 | 1.671 | 15.725…17.036 | pass |
| relic.trigger | scripts/sfx_cue_router.gd::relic_trigger | 0.195 | 16.645 | 19.010…20.595 | pass |
| shop.buy | scripts/run_scene.gd::_on_merchant_buy_pressed | 0.109 | 3.060 | 14.904…16.146 | pass |
| shop.buy | scripts/sfx_cue_router.gd::shop_buy | 0.109 | 3.060 | 14.904…16.146 | pass |
| shop.sell | scripts/run_scene.gd::_on_merchant_sell_pressed | 0.239 | 7.617 | 15.064…27.951 | pass |
| shop.sell | scripts/sfx_cue_router.gd::shop_sell | 0.239 | 7.617 | 15.064…27.951 | pass |
| shot.bow | scripts/sfx_cue_router.gd::release | 1.096 | 21.732 | 23.532…26.009 | pass |
| shot.crossbow | scripts/sfx_cue_router.gd::release | 1.179 | 23.376 | 25.824…27.976 | pass |
| spell.air | scripts/sfx_cue_router.gd::hit | 0.065 | 13.390 | 16.587…17.969 | pass |
| spell.air | scripts/sfx_cue_router.gd::hit | 0.065 | 13.390 | 16.587…17.969 | pass |
| spell.earth | scripts/sfx_cue_router.gd::hit | 0.326 | 25.456 | 26.162…28.342 | pass |
| spell.earth | scripts/sfx_cue_router.gd::hit | 0.326 | 25.456 | 26.162…28.342 | pass |
| spell.earth | scripts/sfx_cue_router.gd::presentation | 0.326 | 25.456 | 26.162…28.342 | pass |
| spell.fire | scripts/sfx_cue_router.gd::hit | 0.087 | 1.367 | 5.849…6.337 | pass |
| spell.fire | scripts/sfx_cue_router.gd::hit | 0.087 | 1.367 | 5.849…6.337 | pass |
| spell.fire | scripts/sfx_cue_router.gd::presentation | 0.087 | 1.367 | 5.849…6.337 | pass |
| spell.ice | scripts/sfx_cue_router.gd::hit | 0.087 | 2.951 | 21.735…23.546 | pass |
| spell.ice | scripts/sfx_cue_router.gd::hit | 0.087 | 2.951 | 21.735…23.546 | pass |
| spell.lightning | scripts/sfx_cue_router.gd::hit | 0.087 | 1.259 | 15.264…16.536 | pass |
| spell.lightning | scripts/sfx_cue_router.gd::hit | 0.087 | 1.259 | 15.264…16.536 | pass |
| spell.lightning | scripts/sfx_cue_router.gd::presentation | 0.087 | 1.259 | 15.264…16.536 | pass |
| spell.shadow | scripts/sfx_cue_router.gd::begin_action | 0.022 | 2.496 | 15.585…16.884 | pass |
| spell.shadow | scripts/sfx_cue_router.gd::hit | 0.022 | 2.496 | 15.585…16.884 | pass |
| spell.shadow | scripts/sfx_cue_router.gd::hit | 0.022 | 2.496 | 15.585…16.884 | pass |
| status.bleed | scripts/sfx_cue_router.gd::status | 0.482 | 0.000 | 3.333…3.684 | pass |
| status.freeze | scripts/sfx_cue_router.gd::status | 1.933 | 6.680 | 7.484…7.947 | pass |
| status.shatter | scripts/sfx_cue_router.gd::hit | 9.407 | 11.319 | 12.702…13.488 | pass |
| status.shock | scripts/sfx_cue_router.gd::status | 0.307 | 0.658 | 18.214…20.132 | pass |
| status.stagger | scripts/sfx_cue_router.gd::status | 0.088 | 1.579 | 14.325…15.833 | pass |
| step.enemy.heavy | scripts/run_scene.gd::_animate_actor_along_path | 0.658 | 7.368 | 14.286…15.789 | pass |
| step.enemy.heavy | scripts/sfx_cue_router.gd::walk_tile | 0.658 | 7.368 | 14.286…15.789 | pass |
| step.enemy.light | scripts/run_scene.gd::_animate_actor_along_path | 6.810 | 9.050 | 15.284…17.585 | pass |
| step.enemy.light | scripts/sfx_cue_router.gd::walk_tile | 6.810 | 9.050 | 15.284…17.585 | pass |
| step.hero | scripts/run_scene.gd::_animate_actor_along_path | 7.580 | 7.048 | 6.053…11.436 | pass |
| step.hero | scripts/sfx_cue_router.gd::walk_tile | 7.580 | 7.048 | 6.053…11.436 | pass |
| stoneskin.gain | scripts/sfx_cue_router.gd::presentation | 1.072 | 19.531 | 22.837…24.740 | pass |
| surface.electric | scripts/run_scene.gd::_play_outcome_sounds | 0.351 | 3.860 | 14.306…15.811 | pass |
| surface.electric | scripts/sfx_cue_router.gd::surface | 0.351 | 3.860 | 14.306…15.811 | pass |
| surface.fire | scripts/run_scene.gd::_play_outcome_sounds | 0.263 | 11.316 | 14.762…16.316 | pass |
| surface.fire | scripts/sfx_cue_router.gd::surface | 0.263 | 11.316 | 14.762…16.316 | pass |
| surface.ice | scripts/run_scene.gd::_play_outcome_sounds | 1.096 | 25.592 | 26.825…29.649 | pass |
| surface.ice | scripts/sfx_cue_router.gd::surface | 1.096 | 25.592 | 26.825…29.649 | pass |
| surface.rubble | scripts/run_scene.gd::_play_outcome_sounds | 0.154 | 25.746 | 26.111…28.860 | pass |
| surface.rubble | scripts/sfx_cue_router.gd::surface | 0.154 | 25.746 | 26.111…28.860 | pass |
| swing.heavy | scripts/sfx_cue_router.gd::wind_up | 0.285 | 48.860 | unmeasured…unmeasured | pass |
| swing.light | scripts/sfx_cue_router.gd::wind_up | 6.361 | 56.272 | unmeasured…unmeasured | pass |
| trap.trigger | scripts/run_scene.gd::_play_trap_sfx | 0.543 | 4.036 | 7.933…8.594 | pass |
| trap.trigger | scripts/sfx_cue_router.gd::trap | 0.543 | 4.036 | 7.933…8.594 | pass |
| vocal.beast | scripts/sfx_cue_router.gd::begin_action | 0.739 | 42.428 | unmeasured…unmeasured | pass |

Re-trimmed files

| File | Previous removed samples | Current removed samples | Loudness Δ LU |
|---|---:|---:|---:|
| block.break/block.break_01.ogg | 2139 | 2107 | -0.042 |
| card.exhaust/card.exhaust_01.ogg | 13903 | 6623 | -0.897 |
| cast.arcane/cast.arcane_01.ogg | 11583 | 9083 | -0.011 |
| crate.hit/crate.hit_01.ogg | 2962 | 849 | -0.509 |
| death.avian/death.avian_01.ogg | 16663 | 12882 | -0.222 |
| death.avian/death.avian_02.ogg | 19357 | 15310 | 0.065 |
| death.avian/death.avian_03.ogg | 17234 | 10065 | -0.099 |
| death.bone/death.bone_01.ogg | 1295 | 1292 | -0.044 |
| death.dragon/death.dragon_01.ogg | 4538 | 4876 | -0.181 |
| death.hero/death.hero_01.ogg | 16 | 642 | -0.475 |
| deck.shuffle/deck.shuffle_01.ogg | 7364 | 7363 | -0.961 |
| defiance/defiance_01.ogg | 50074 | 2499 | 0.005 |
| dragon.roar/dragon.roar_01.ogg | 1539 | 1536 | -0.011 |
| fatigue/fatigue_01.ogg | 10932 | 6464 | 0.082 |
| heal/heal_01.ogg | 18394 | 10385 | -0.044 |
| heal/heal_02.ogg | 33397 | 26297 | 0.022 |
| heal/heal_03.ogg | 24858 | 18602 | -0.044 |
| hit.arcane/hit.arcane_01.ogg | 7011 | 5315 | -0.154 |
| hit.blade.heavy/hit.blade.heavy_01.ogg | 1289 | 844 | -0.877 |
| hit.blunt.heavy/hit.blunt.heavy_01.ogg | 5749 | 1914 | 0.087 |
| hit.blunt.heavy/hit.blunt.heavy_02.ogg | 7499 | 5584 | -0.801 |
| hit.blunt.light/hit.blunt.light_01.ogg | 452 | 291 | -0.220 |
| hit.claw/hit.claw_01.ogg | 7022 | 6159 | -0.576 |
| hit.pierce/hit.pierce_01.ogg | 5923 | 3957 | -0.036 |
| hurt.hero/hurt.hero_01.ogg | 2818 | 2715 | -1.255 |
| illusion.break/illusion.break_01.ogg | 15688 | 13969 | -0.113 |
| illusion.spawn/illusion.spawn_01.ogg | 26067 | 18989 | -0.010 |
| map.hover/map.hover_01.ogg | 3441 | 3423 | -0.093 |
| move.blink/move.blink_01.ogg | 34198 | 34121 | 0.085 |
| omen.bane/omen.bane_01.ogg | 37275 | 5046 | 0.065 |
| omen.blessing/omen.blessing_01.ogg | 15971 | 1885 | 0.050 |
| pickup.gear/pickup.gear_01.ogg | 1677 | 1665 | 0.225 |
| radiance.light/radiance.light_01.ogg | 41951 | 33770 | 0.026 |
| relic.trigger/relic.trigger_01.ogg | 637 | 1070 | -0.940 |
| shop.buy/shop.buy_01.ogg | 1079 | 916 | -0.286 |
| shop.sell/shop.sell_01.ogg | 6699 | 6205 | -0.121 |
| shop.sell/shop.sell_02.ogg | 8708 | 8704 | 0.269 |
| spell.air/spell.air_01.ogg | 20119 | 16912 | 0.020 |
| spell.earth/spell.earth_01.ogg | 407 | 391 | 0.198 |
| spell.fire/spell.fire_01.ogg | 8332 | 0 | -0.000 |
| spell.ice/spell.ice_01.ogg | 45603 | 43262 | -0.238 |
| spell.lightning/spell.lightning_01.ogg | 6893 | 3912 | -0.018 |
| spell.shadow/spell.shadow_01.ogg | 9831 | 7641 | -0.289 |
| status.shock/status.shock_01.ogg | 56040 | 54830 | 0.050 |
| status.stagger/status.stagger_01.ogg | 2396 | 1656 | -0.089 |
| step.enemy.heavy/step.enemy.heavy_01.ogg | 846 | 1490 | -0.022 |
| surface.electric/surface.electric_01.ogg | 57570 | 4714 | 0.111 |
| surface.fire/surface.fire_01.ogg | 10018 | 4770 | 0.042 |
| swing.heavy/swing.heavy_01.ogg | 3480 | 3476 | 0.000 |

Listening checklist

Audition every revised file, with special attention to first-transient shape, clicks at the cut, and the intact tail. The checklist includes every rebuilt file, covering both peer-flagged sets (17 + 15) conservatively. Reconstructed flags are annotated; exact membership of the peer lists was not supplied.

- [ ] `block.break/block.break_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `block.gain/block.gain_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `card.exhaust/card.exhaust_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `card.hover/card.hover_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `card.invalid/card.invalid_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `card.select/card.select_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `cast.arcane/cast.arcane_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `crate.break/crate.break_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `crate.hit/crate.hit_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.avian/death.avian_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.avian/death.avian_02.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.avian/death.avian_03.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.beast/death.beast_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.bone/death.bone_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.dragon/death.dragon_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.hero/death.hero_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `death.humanoid/death.humanoid_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `death.ooze/death.ooze_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `death.spirit/death.spirit_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `death.stone/death.stone_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `deck.shuffle/deck.shuffle_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `defiance/defiance_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `dragon.roar/dragon.roar_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `dragon.wings/dragon.wings_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `event.choose/event.choose_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `fatigue/fatigue_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `heal/heal_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `heal/heal_02.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `heal/heal_03.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.arcane/hit.arcane_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.blade.heavy/hit.blade.heavy_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.blade.light/hit.blade.light_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `hit.blocked/hit.blocked_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `hit.blunt.heavy/hit.blunt.heavy_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.blunt.heavy/hit.blunt.heavy_02.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.blunt.light/hit.blunt.light_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.claw/hit.claw_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hit.pierce/hit.pierce_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `hurt.hero/hurt.hero_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `illusion.break/illusion.break_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `illusion.spawn/illusion.spawn_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `map.hover/map.hover_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `map.select/map.select_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `move.blink/move.blink_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `omen.bane/omen.bane_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `omen.blessing/omen.blessing_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `pickup.gear/pickup.gear_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `pickup.item/pickup.item_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `push.collision/push.collision_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `push.slide/push.slide_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `radiance.light/radiance.light_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `relic.trigger/relic.trigger_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `shop.buy/shop.buy_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `shop.sell/shop.sell_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `shop.sell/shop.sell_02.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `shot.bow/shot.bow_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `spell.air/spell.air_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `spell.earth/spell.earth_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `spell.fire/spell.fire_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `spell.ice/spell.ice_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `spell.lightning/spell.lightning_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient; peer explicitly flagged lightning transient
- [ ] `spell.shadow/spell.shadow_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `status.bleed/status.bleed_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `status.freeze/status.freeze_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `status.shatter/status.shatter_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `status.shock/status.shock_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `status.stagger/status.stagger_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `step.enemy.heavy/step.enemy.heavy_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `step.enemy.light/step.enemy.light_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `step.hero/step.hero_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `step.hero/step.hero_02.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `step.hero/step.hero_03.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `surface.electric/surface.electric_01.ogg`: old cut removed content within 1 dB of strongest envelope; old cut above −20 dB on RMS envelope; audition first transient
- [ ] `surface.fire/surface.fire_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `surface.ice/surface.ice_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `surface.rubble/surface.rubble_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `swing.heavy/swing.heavy_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient
- [ ] `swing.light/swing.light_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `swing.light/swing.light_02.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `swing.light/swing.light_03.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `trap.trigger/trap.trigger_01.ogg`: verify first transient, quiet cut, loudness and tail
- [ ] `vocal.beast/vocal.beast_01.ogg`: old cut above −20 dB on RMS envelope; audition first transient

Follow-ups

- hit.blade.light/hit.blade.light_01.ogg: capped loudness outside window (-2.131 LU)
- hurt.hero/hurt.hero_01.ogg: capped loudness outside window (-1.255 LU)

Reproduce from the task worktree with the sound-lab Python environment activated:

```sh
python tools/sfx_lab/sync.py
python tools/sfx_sync_audit.py --report output/sfx/sync_audit.json --check
python3 tools/godot_task_runner.py --task-id sfx-04 --stream -- godot --headless --path . --script tests/sfx_sync_bank_test.gd
```

The first command is idempotent. A changed source requires the approved local sound library in .godot/sfx_lab; use --features and --sources to relocate it. Full traces, PCM copies, and reports stay under gitignored output/sfx/. Use --refresh-baseline only after inspecting the current measurements and coverage. The harness exercises every scenario at 1×, 1.5×, and 2× with fixed 60 Hz, periodic 33 ms spikes, steady 30 fps, 144 Hz and seeded ±4 ms jitter. Composite walk/relay cases observe the first post-rift destination submission independently of logical player state. It observes production presentation submissions with deterministic clocks; it does not claim audio-device or speaker latency measurements.

Verification

- Round 6: uncommitted changes on df41875b4. Audio assets, provenance and sync rules are unchanged; the two inherited cap-limited loudness exceptions remain listed above.
- Fresh production harness and independent PCM audit: PASS, 3,950 observations, 315 aligned calls, 81/81 cues and 136 cue × call-site rows; no timing, playback, coverage, PCM or decoded-length failures. Log: output/sfx/round6-final-audit.log.
- Every scenario ran at 1×, 1.5× and 2× with fixed 60 Hz, periodic 33 ms spikes, steady 30 fps, 144 Hz and seeded ±4 ms jitter. All 315 aligned peaks were +15.002303…+15.019923 ms after the independently observed presentation climax.
- Walk → blink, blink → walk and walk → blink → walk each played exactly one blink in all 15 combinations: 45 composite relay peaks at +15.005132…+15.013382 ms. Arrival is observed from the destination state or first post-rift position submission, in submission order even when two submissions share a timestamp.
- Strict check of the fresh current-source trace: PASS; independently decoded PCM and the complete measured report matched the refreshed audit exactly. --check left the tracked baseline and Markdown hashes unchanged. Logs: output/sfx/round6-check.log and output/sfx/round6-before-check.sha256.
- Baseline changes only add the three composite scenarios and their request/primary-play counts. Existing counts, call-site identities, sample measurements and allowed-drop counts are preserved.
- Sync bank: PASS, 0 failures, including already-due cues queued during pause/hit-stop and played exactly once after resume; 83 Godot stream lengths match decoded PCM. Log: output/sfx/round6-bank.log.
- Dispatch-guard mutation: removing only the presentation-active guard causes the four expected pause/hit-stop failures. Production source is unchanged by the mutation. Evidence: output/sfx/round6-freeze-mutant/result.json and result.log.
- Relay-trigger mutation: restoring logical-position-only behavior fails the final fixtures with two missing blink sounds, one +531.682 ms late peak, two missing-request count failures and two missing-primary-play count failures. Log: output/sfx/round6-relay-mutant.log.
- Focused sync Python: 13 tests, PASS (2.370 seconds). Full Python discovery: 397 tests, PASS (61 optional skips), 331.552 seconds. Logs: output/sfx/round6-sync-python.log and output/sfx/round6-full-python.log.
- Full Godot suite: PASS, 852.702 seconds within the unchanged 900-second budget. Includes the sync bank and all 15 timing/coverage assertion combinations (3,950 observations, 0 failures). Log: output/sfx/round6-full-godot.log.
- Runtime, test and tool source hashes stayed unchanged through the full Godot run. Input hashes: output/sfx/round6-tested-inputs.json. No commit, push, external reviewer or windowed capture was performed in this revision.
