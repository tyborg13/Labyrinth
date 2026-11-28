# fel-28 final fix round

## Round 2 review fixes

- The shared last-kill check now checks the settled combat state for card substeps, end-of-activation battlefield beats, and enemy-phase slices. Meteorfall's landing and the other presentation snapshots still drive the animation. A Cinder Ooze split with surviving droplets keeps the usual rail transition.
- Playback skips the player-activation rail step when the turn-start effects have already won combat. The engine and the analytics event steps remain at `fa0218bcb`.
- The board tracks whether a Crawler rig has reached the death overlay. It frees a presented rig when the overlay disappears and releases any waiting rigs as enemy pacing finishes.
- A sliced reward refresh uses the existing presentation-frame helper. Native keeps its draw signal. Headless falls back to a process frame, so the saved reward intro can finish without synthetic draw signals.

Production changes are in `scripts/run_scene.gd` and `scripts/combat_board_view.gd`. `tools/fel28/review_regressions.gd` and its UID add the four review probes. `tools/fel28/probe.gd` can use the archived census checkpoint after the fel-20 worktree was removed. The save and progression files in the archive matched the copies used in round 1 byte for byte. [Archived 00059 checkpoint](/private/tmp/labyrinth_codex/fel20-final.ts2LiA/checkpoints/00059)

### Review regression commands

```bash
out="$(mktemp -d /tmp/labyrinth_codex/fel28-review.XXXXXX)"
for case in ooze_split turn_start_final crawler_rigs continue_intro; do
    FEL28_REVIEW_CASE="$case" FEL28_OUTPUT="$out/$case" \
        python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path . --script tools/fel28/review_regressions.gd
done
bash tools/fel28/headless.sh ../release "$(mktemp -d /tmp/labyrinth_codex/fel28-headless.XXXXXX)"
```

The viewport sends Pass for both Meteorfall cases. The probe checks whether death playback submitted the Ooze removal and whether any rail transition removed the final Crawler before VICTORY. The rig probe checks the original node's lifetime during pacing. The Continue probe reloads a saved pending victory intro and disables synthetic draw signals. The Meteorfall fixture uses 50 damage and places the enemy 100 initiative time units ahead of the current clock. The Continue observation deadline is 6 s. These are proof-only defaults.

| Finding | `fa0218bcb` | Round 2 |
|---|---|---|
| Ooze split | `FEL28 OOZE_SPLIT rail_held=true FAIL` | `FEL28 OOZE_SPLIT rail_held=false PASS` |
| Final turn-start kill | `FEL28 TURN_START_FINAL rail_reflow=1 FAIL` | `FEL28 TURN_START_FINAL rail_reflow=0 PASS` |
| Crawler rig | `FEL28 CRAWLER_RIGS retained_after_dissolve FAIL` | `FEL28 CRAWLER_RIGS freed_after_dissolve PASS` |
| Headless Continue | `FEL28 CONTINUE_INTRO headless hangs FAIL` | `FEL28 CONTINUE_INTRO headless completes PASS` |

The unused rig check went from `FEL28 CRAWLER_RIGS unused_freed_at_scope_end=false FAIL` to `FEL28 CRAWLER_RIGS unused_freed_at_scope_end=true PASS`. [Baseline probe logs](/private/tmp/labyrinth_codex/fel28-r2-before.JAXTje) · [Baseline Ooze observer log](/private/tmp/labyrinth_codex/fel28-r2-before-ooze.61WiqQ/runner.log) · [Baseline locked Crawler rig log](/private/tmp/labyrinth_codex/fel28-r2-before-crawler.vTjzhW/runner.log) · [Fixed rail probe logs](/private/tmp/labyrinth_codex/fel28-r2-rail-final.tXOiv4) · [Fixed Crawler rig log](/private/tmp/labyrinth_codex/fel28-r2-crawler.zCYjky/runner.log) · [Fixed Continue log](/private/tmp/labyrinth_codex/fel28-r2-retry.fol1Bn/continue_intro/runner.log)

### Round 2 focused verification

The Godot commands in Focused verification below were run again for round 2. The deferred analytics fixture used its simulated draw option. Its result recorded 84 checks and an empty error array. [Round 2 focused Godot logs](/private/tmp/labyrinth_codex/fel28-r2-focused.hAueqM)

```text
RR46 MIXED DEATH CLOCKS: PASS (12 blocking/overlap cases; three speeds; 12 authored event crossings)
TURN ORDER STILL PORTRAITS: PASS (6 identities + Unknown Presence; rail + landing strip; 30 processed frames)
TURN ORDER LIFETIME TEST: PASS
ANIMATION STATE SUBMISSION TEST: PASS
SHARED TILE MOVEMENT TEST: PASS
DEATH TRANSITION TEST: PASS (6 cases)
TEST RESULT: PASS — committed save/resume boundary matrix
QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)
ENCOUNTER CALLER METADATA: PASS (UI/headless; combat, Guardian, boss; start/end/rewards)
ENCOUNTER ANALYTICS: PASS (0 failures)
Dragon rewards, gifts, wallet recovery and relic hooks passed.
Dragon reward feedback logic: PASS
GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS
TEST RESULT: PASS
FEL28 ENGINE AND PRESENTATION CLOCKS MATCH fa0218bcb
```

The UI identity lint reported `Ran 25 tests in 4.673s` and `OK`. Rules text reported `Ran 3 tests in 0.059s`, `OK` and `PASS: Rules text lint (16 existing hits)`. The Python default group selected 23 of 59 modules and reported `Ran 196 tests in 32.577s` and `OK`. The optional Python timing cache could not write under the read-only Git directory. [Lint logs](/private/tmp/labyrinth_codex/fel28-r2-lint.XZdh03) · [Python default-group log](/private/tmp/labyrinth_codex/fel28-r2-python.5QyWQJ/runner.log)

### Round 2 release comparison

The full eight-case headless comparison exited zero against `codex/release` at `e20cebc19`. All six quit saves matched after excluding the existing wall-clock play-time counter. The in-flight reward checkpoint also passed. The log includes the per-case gates and all headless intervals over 33 ms. It records wall timing under the dummy renderer. [Round 2 comparison log](/private/tmp/labyrinth_codex/fel28-r2-proof.wAZOmG/results.log)

```text
FEL28 roster unchanged_frames before=104 after=104 PASS
FEL28 shadow quit_death_save before=reward after=reward PASS
FEL28 shadow quit_victory_save before=reward after=reward PASS
FEL28 shadow quit_reveal_save before=reward after=reward PASS
FEL28 enemy_turn quit_death_save before=combat after=combat PASS
FEL28 enemy_turn quit_victory_save before=combat after=combat PASS
FEL28 enemy_turn quit_reveal_save before=reward after=reward PASS
FEL28 enemy_turn quit_in_flight before=reward after=reward PASS
FEL28 PASS cases=8
```

The director's native commands below still apply. If the archive moves, set `FEL28_CHECKPOINT` to the directory with the original 00059 save and progression files. The checkpoint storage failure from the review remains tracked separately.

## Changes

- Restored the release death wait, sample schedule, and burst code. The three clock scripts, combat pacing, and the blocking death runner match release byte for byte. The release settle remains part of each death beat.
- Kept the last-kill rail hold, immediate VICTORY handoff, and hidden reward preparation. The VICTORY and reward animation constants match release. The former 3.1 s target has been retracted.
- Reused the Crawler's existing rig between the lethal enemy status update and its first dissolve sample. The hidden rig resets to the same neutral front pose that release used when it created a replacement. The ordinary roster retires it after the enemy-round scope.
- Used the existing ordered disk worker at the enemy-round reward commit and at the reward header's skill outbox and acknowledgement. The held checkpoint is captured at the existing post-VICTORY commit point. The reveal and dependent appends wait for the preceding write. A departure during a write snapshots the held state and waits for the active drain before continuing. The Grimoire save keeps its position before the relic receipt reconciliation.

The production changes are in `scripts/combat_board_view.gd`, `scripts/prepared_victory_reward.gd`, `scripts/run_persistence.gd`, and `scripts/run_scene.gd`. The viewport fixtures, diagnostics, drive scripts, proof contract and report live in `tools/fel28/`.

## Director's native baseline

The director's [native run log](/private/tmp/labyrinth_codex/fel28-native.3zmYVw/native-results.log) predates this fix round.

| Take | Release ready (ms) | First-round branch ready (ms) | Release max frame (ms) | First-round branch max frame (ms) |
|---|---:|---:|---:|---:|
| Shadow | 3697 | 3689 | 64 | 38 |
| Humanoid | 4408 | 4368 | 59 | 37 |
| Multi | 3742 | 3714 | 60 | 36 |
| Enemy turn | 3293 | 3299 | 94 | 70 |

### Enemy-turn stall diagnosis

- **172.635 ms, 70.102 ms frame.** The original native report selected the preceding process frame's 4.23 ms rail layout span. The same JSON also records **35.254 ms** for animation overlay board submission on process frame 359, where the first death was drawn. The isolated [headless diagnostic](/private/tmp/labyrinth_codex/fel28-f1-trace.vDpJTV/take.json) attributed **36.796 ms** to `roster_crawler` in the corresponding submission and recorded the full front and rear Crawler rig loading again. The [revised trace](/private/tmp/labyrinth_codex/fel28-f1-acktrace.lxGQ9w/take.json) records a worst Crawler roster sync of **0.226 ms**. The headless trace confirms the rebuild was removed.
- **102.533 ms, 44.831 ms frame.** The recorded work includes the rail layout and a first hero-brush resource load. A separate instrumented headless take showed time in the interval between pre-draw and post-draw callbacks. The sandbox's `sample` attach failed with `sample cannot examine process ...`. The evidence attributes part of the frame to game code and leaves the remaining time unattributed.
- **2426.076 ms, 55.876 ms frame.** The native take records **17.778 ms** of blocking checkpoint storage. The first headless fix removed the enemy outcome write from the main-thread wait and exposed two additional skill receipt writes. The final trace records the remaining synchronous Grimoire checkpoint at **5.938 ms** and the worker submissions below 1 ms. Its first reveal frame was **17.369 ms**. Disk durability checks and the outbox append/ack sequence still run in the original order.

The native 50 ms cap needs a fresh renderer run. The native report prints both the draw frame and preceding process frame's CPU spans for intervals above 33 ms. This keeps a long draw from obscuring the corresponding submission work.

### Prior native frames over 33 ms

The spans below are the attribution captured on the director’s first-round run. The enemy-turn diagnosis above uses the current draw frame as well as the preceding process frame.

| Take | Build | Time after input (ms) | Frame (ms) | Recorded work |
|---|---|---:|---:|---|
| shadow | release | 358.961 | 34.022 | `action frame; no attributed CPU span, previous readback/spool=13.62ms` |
| shadow | release | 2826.824 | 64.308 | `refresh_ui_large_map=5.08ms, combat_checkpoint_persist_storage=4.40ms, refresh_ui_grimoire_sync=4.00ms, previous readback/spool=4.59ms` |
| shadow | branch | 34.445 | 34.445 | `combat_checkpoint_persist_storage=5.50ms, stage_board_submission=2.57ms, deferred_layout_turn_order_anchor=1.02ms` |
| shadow | branch | 1862.699 | 35.590 | `victory frame; no attributed CPU span, previous readback/spool=5.59ms` |
| shadow | branch | 2747.810 | 38.124 | `combat_checkpoint_persist_storage=4.40ms, refresh_ui_grimoire_sync=3.72ms, stage_board_submission=2.96ms, previous readback/spool=7.63ms` |
| shadow | branch | 2785.608 | 37.798 | `combat_checkpoint_persist_storage=4.40ms, refresh_ui_grimoire_sync=3.72ms, stage_board_submission=2.96ms, previous readback/spool=9.13ms` |
| humanoid | release | 3537.845 | 59.090 | `refresh_ui_large_map=4.98ms, combat_checkpoint_persist_storage=4.20ms, refresh_ui_grimoire_sync=3.88ms, previous readback/spool=4.96ms` |
| humanoid | branch | 3449.898 | 34.472 | `combat_checkpoint_persist_storage=3.99ms, refresh_ui_grimoire_sync=3.71ms, stage_board_submission=3.06ms, previous readback/spool=5.46ms` |
| humanoid | branch | 3487.160 | 37.262 | `combat_checkpoint_persist_storage=3.99ms, refresh_ui_grimoire_sync=3.71ms, stage_board_submission=3.06ms, previous readback/spool=11.89ms` |
| multi | release | 2867.109 | 60.167 | `refresh_ui_large_map=5.04ms, combat_checkpoint_persist_storage=4.09ms, refresh_ui_grimoire_sync=3.86ms, previous readback/spool=8.00ms` |
| multi | branch | 2814.717 | 36.256 | `combat_checkpoint_persist_storage=4.32ms, refresh_ui_grimoire_sync=3.78ms, stage_board_submission=2.85ms, previous readback/spool=9.18ms` |
| enemy_turn | release | 91.951 | 42.253 | `deferred_layout_turn_order_anchor=4.68ms, engine_current_turn_order_context=0.21ms, engine_current_turn_order_visibility=0.18ms, previous readback/spool=6.30ms` |
| enemy_turn | release | 153.057 | 61.106 | `deferred_layout_turn_order_anchor=4.68ms, engine_current_turn_order_context=0.21ms, engine_current_turn_order_visibility=0.18ms, previous readback/spool=2.49ms` |
| enemy_turn | release | 1497.475 | 39.941 | `enemy_round_final_checkpoint_total=3.59ms, animation_overlay_board_submission=2.27ms, combat_checkpoint_base_duplicate=0.01ms, previous readback/spool=7.69ms` |
| enemy_turn | release | 2422.249 | 94.344 | `combat_checkpoint_persist_storage=23.80ms, refresh_ui_large_map=5.52ms, refresh_ui_grimoire_sync=4.22ms, previous readback/spool=6.26ms` |
| enemy_turn | branch | 102.533 | 44.831 | `deferred_layout_turn_order_anchor=4.23ms, engine_current_turn_order_context=0.21ms, engine_current_turn_order_visibility=0.21ms, previous readback/spool=5.85ms` |
| enemy_turn | branch | 172.635 | 70.102 | `deferred_layout_turn_order_anchor=4.23ms, engine_current_turn_order_context=0.21ms, engine_current_turn_order_visibility=0.21ms, previous readback/spool=3.24ms` |
| enemy_turn | branch | 206.914 | 34.279 | `animation_overlay_board_submission=35.25ms, deferred_checkpoint_write=0.86ms, previous readback/spool=7.34ms` |
| enemy_turn | branch | 1523.209 | 41.569 | `enemy_round_final_checkpoint_total=4.19ms, animation_overlay_board_submission=2.41ms, combat_checkpoint_base_duplicate=0.01ms, previous readback/spool=8.55ms` |
| enemy_turn | branch | 2426.076 | 55.876 | `combat_checkpoint_persist_storage=17.78ms, refresh_ui_grimoire_sync=4.13ms, stage_board_submission=3.12ms, previous readback/spool=4.33ms` |
| enemy_turn | branch | 2460.596 | 34.520 | `combat_checkpoint_persist_storage=17.78ms, refresh_ui_grimoire_sync=4.13ms, stage_board_submission=3.12ms, previous readback/spool=7.83ms` |

### Death sweep

The tool reports `FEL28 DEATH <type>/<mode> wait_ms=N visible_end_ms=N PASS|FAIL`. The check is release wait minus measured visible end between zero and **100 ms plus one 60 fps frame**. Paired clean crops bracket each submitted frame to account for background drift. Tail strips retain the final 300 ms of the authored wait. The prior capture recorded waits 40–188 ms after the measured endpoints. The reduced-motion Cinder Droplet, Bell Tender, Stoneback Mite, Wick Shade and Gloam Stalker exceeded the new predicate and their clean references shifted. The rerun will establish the new measurements. [Prior death sweep data and strips](/private/tmp/labyrinth_codex/fel28-native-deaths.ilfkcE/deaths.json)

`TODO_DESIGN_DEATH_VISIBILITY_CALIBRATION` retains the release clocks for every row. Production adds no per-subject timing values.

### Death table

Values are milliseconds. The wait columns come from the release clock and its settle. The visible-end columns are prior director measurements from the sampled renderer crops. Fresh pixel measurements remain a native check.

| Subject | Release and final wait (normal) | Prior visible end (normal) | Release and final wait (reduced) | Prior visible end (reduced) |
|---|---:|---:|---:|---:|
| `acolyte` | 1076 | 999 | 1076 | 999 |
| `arc_thrall` | 1740 | 1700 | 1076 | 1036 |
| `ash_hound` | 1076 | 962 | 1076 | 999 |
| `ashen_reaver` | 1800 | 1743 | 1076 | 1036 |
| `bell_tender` | 1076 | 1036 | 1076 | 888 |
| `bile_bloomer` | 1340 | 1300 | 1340 | 1283 |
| `bramble` | 1080 | 1040 | 1080 | 1040 |
| `briar_weaver` | 1740 | 1700 | 1076 | 1036 |
| `burrow_grub` | 1340 | 1283 | 1340 | 1283 |
| `chainbound_gaoler` | 1800 | 1760 | 1076 | 1020 |
| `cinder_droplet` | 1076 | 999 | 1076 | 925 |
| `cinder_ooze` | 1076 | 999 | 1076 | 999 |
| `crag_outcrop` | 1080 | 1040 | 1080 | 1040 |
| `craghide` | 1076 | 999 | 1076 | 962 |
| `crawler` | 1076 | 962 | 1076 | 999 |
| `dragon_spire` | 1080 | 1040 | 1080 | 975 |
| `ember_hoarder` | 940 | 900 | 940 | 900 |
| `ember_tick` | 940 | 883 | 940 | 883 |
| `frostglass_lancer` | 1800 | 1760 | 1076 | 1036 |
| `gale_herald` | 1740 | 1700 | 1076 | 1036 |
| `gallows_roc` | 1076 | 1036 | 1076 | 1036 |
| `glacial_mirror` | 1740 | 1683 | 1076 | 1036 |
| `gloam_stalker` | 1680 | 1640 | 1076 | 888 |
| `grave_surgeon` | 1076 | 1036 | 1076 | 1036 |
| `gust_shrike` | 1076 | 1036 | 1076 | 1036 |
| `harrier` | 1076 | 999 | 1076 | 999 |
| `hoarfrost_seer` | 1860 | 1803 | 1076 | 1020 |
| `hollow_mimic` | 1680 | 1640 | 1076 | 1036 |
| `ice_pillar` | 1080 | 975 | 1080 | 1040 |
| `iskaldra` | 1076 | 1036 | 1076 | 999 |
| `last_lamplighter` | 1800 | 1760 | 1076 | 1020 |
| `lightning_wisp` | 1240 | 1183 | 1240 | 1200 |
| `noctyrax` | 1076 | 1036 | 1076 | 1036 |
| `powder_keg` | 1080 | 1040 | 1080 | 975 |
| `raised_cover` | 1080 | 1040 | 1080 | 1040 |
| `rime_spitter` | 1076 | 1036 | 1076 | 962 |
| `rime_whelp` | 1076 | 962 | 1076 | 999 |
| `rimejaw` | 1076 | 999 | 1076 | 962 |
| `roc_fledgling` | 1076 | 999 | 1076 | 999 |
| `slag_mortar` | 1740 | 1683 | 1076 | 1036 |
| `stoneback_mite` | 1076 | 999 | 1076 | 925 |
| `storm_cantor` | 1920 | 1880 | 1076 | 1020 |
| `storm_capacitor` | 2476 | 2436 | 2476 | 2436 |
| `tharokh` | 1076 | 1036 | 1076 | 999 |
| `vaeloryx` | 1076 | 1036 | 1076 | 1036 |
| `veilbound_acolyte` | 1076 | 1036 | 1076 | 1036 |
| `vyraketh` | 1076 | 1036 | 1076 | 1036 |
| `warden` | 1076 | 1036 | 1076 | 1036 |
| `wick_shade` | 1076 | 1036 | 1076 | 888 |
| `wooden_box` | 1080 | 1040 | 1080 | 975 |
| `wooden_crate` | 1080 | 1040 | 1080 | 975 |
| `zekarion` | 1076 | 1036 | 1076 | 1036 |

## Focused verification

```bash
for check in rr46/death_clocks death_transition_test save_resume_boundary_test application_shutdown_test encounter_analytics_test dragon_rewards_test dragon_reward_feedback_test guided_combat_tutorial_integration_test; do
    python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path . --script "tests/$check.gd"
done
python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path . --script tests/deferred_skill_analytics_test.gd -- --simulate-draw
python3 tests/test_ui_identity_lint.py
python3 tools/run_python_suite.py --shards 4 --output-dir /tmp/labyrinth_codex/fel28-f1-python.3BKi7q
```

```text
RR46 MIXED DEATH CLOCKS: PASS (12 blocking/overlap cases; three speeds; 12 authored event crossings)
TURN ORDER STILL PORTRAITS: PASS (6 identities + Unknown Presence; rail + landing strip; 30 processed frames)
TURN ORDER LIFETIME TEST: PASS
ANIMATION STATE SUBMISSION TEST: PASS
SHARED TILE MOVEMENT TEST: PASS
DEATH TRANSITION TEST: PASS (6 cases)
TEST RESULT: PASS — committed save/resume boundary matrix
QA84 APPLICATION SHUTDOWN TEST RESULT: PASS (18 assertions; 0 failures)
ENCOUNTER CALLER METADATA: PASS (UI/headless; combat, Guardian, boss; start/end/rewards)
ENCOUNTER ANALYTICS: PASS (0 failures)
Dragon rewards, gifts, wallet recovery and relic hooks passed.
Dragon reward feedback logic: PASS
GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS
TEST RESULT: PASS
Ran 25 tests in 6.668s
OK
Ran 196 tests in 42.784s
OK
INPUT GROUP TIME default: 23 modules; 108.578 module-seconds; 42.568s maximum attributed shard work
```

The deferred skill analytics result covers 84 checks with its `--simulate-draw` option. The initial invocation without this option timed out waiting for native draw callbacks. The Python runner could not update its timing cache inside the read-only Git directory after completing the default group. [Focused test logs](/private/tmp/labyrinth_codex/fel28-f1-focused.aHp5Uk) · [Final save and shutdown test logs](/private/tmp/labyrinth_codex/fel28-f1-save-rerun.XyzgHU) · [Deferred analytics log](/private/tmp/labyrinth_codex/fel28-f1-skill.DGSR0t/results.log) · [Python default-group log](/private/tmp/labyrinth_codex/fel28-f1-python.3BKi7q/runner.log)

## Headless comparison

```bash
bash tools/fel28/headless.sh ../release /tmp/labyrinth_codex/fel28-f1-proof.3zZWZm
out=/tmp/labyrinth_codex/fel28-f1-proof.3zZWZm
for boundary in death victory reveal checkpoint; do
    FEL28_TOOLS="$PWD/tools" FEL28_CASE=enemy_turn FEL28_QUIT_AT="$boundary" FEL28_OUTPUT="$out/branch/quit-enemy-$boundary" \
        python3 tools/godot_task_runner.py --task-id fel-28 --stream -- godot --headless --path "$PWD" --script "$PWD/tools/fel28/probe.gd"
done
python3 tools/fel28/report.py headless "$out"
```

The original menu fixture timed out before the branch enemy-turn departure takes. Those takes resumed through the menu's normal checkpoint-loading contract directly under the dummy renderer. Their combat input still entered through the viewport. The native fixture continues through the menu. An isolated repeat of the reduced-motion take also showed headless wall-time scheduling stalls. Process-frame ordering and wall times are both recorded. [Full comparison log and per-take artifacts](/private/tmp/labyrinth_codex/fel28-f1-proof.3zZWZm/results.log) · [Isolated reduced-motion trace](/private/tmp/labyrinth_codex/fel28-f1-reduced.1tD5K7/take.json)

The first reduced-motion take recorded a 423.977 ms headless interval at the end of VICTORY. Its preparation completed after the overlay closed. The isolated retry observed preparation while VICTORY was still visible. Both sets of timings are retained. [Initial comparison](/private/tmp/labyrinth_codex/fel28-f1-proof.3zZWZm/results-initial.log)

The matching saves omit only the active play-time counter. The separate in-flight quit completed the reward write with the pending intro preserved.

```text
FEL28 DEATH CLOCKS rows=104
FEL28 roster unchanged_frames before=104 after=104 PASS
FEL28 shadow fixture before=1 after=1 PASS
FEL28 shadow rail_reflow before=1 after=0 PASS
FEL28 shadow death_to_victory_frames before=7 after=4 PASS
FEL28 HEADLESS HANDOFF shadow release_ms=113.179 branch_ms=68.029
FEL28 shadow prepared_during_victory before=1 after=1 PASS
FEL28 shadow input_to_ready_ms before=3714.595 after=3700.800 PASS
FEL28 HEADLESS TIMING shadow release max_frame_ms=82.260 reveal_start_frame_ms=82.260
FEL28 HITCH shadow release t_ms=35.208 frame_ms=35.208 action frame; no attributed CPU span
FEL28 HITCH shadow release t_ms=2856.072 frame_ms=82.260 preceding process frame refresh_ui_large_map=7.79ms, refresh_ui_grimoire_sync=6.49ms, combat_checkpoint_persist_storage=6.21ms
FEL28 HEADLESS TIMING shadow branch max_frame_ms=31.784 reveal_start_frame_ms=20.630
FEL28 humanoid fixture before=1 after=1 PASS
FEL28 humanoid rail_reflow before=1 after=0 PASS
FEL28 humanoid death_to_victory_frames before=7 after=4 PASS
FEL28 HEADLESS HANDOFF humanoid release_ms=118.196 branch_ms=64.317
FEL28 humanoid prepared_during_victory before=1 after=1 PASS
FEL28 humanoid input_to_ready_ms before=4363.989 after=4329.248 PASS
FEL28 HEADLESS TIMING humanoid release max_frame_ms=81.169 reveal_start_frame_ms=81.169
FEL28 HITCH humanoid release t_ms=45.612 frame_ms=45.612 action frame; no attributed CPU span
FEL28 HITCH humanoid release t_ms=3531.108 frame_ms=81.169 draw frame grimoire_row_preparation=0.48ms, recap_glyph_shaping_preparation=0.37ms, deferred_analytics_batch=0.28ms | preceding process frame refresh_ui_large_map=8.37ms, refresh_ui_grimoire_sync=8.07ms, combat_checkpoint_persist_storage=6.76ms
FEL28 HEADLESS TIMING humanoid branch max_frame_ms=32.172 reveal_start_frame_ms=17.906
FEL28 multi fixture before=1 after=1 PASS
FEL28 multi rail_reflow before=1 after=0 PASS
FEL28 multi death_to_victory_frames before=7 after=4 PASS
FEL28 HEADLESS HANDOFF multi release_ms=120.221 branch_ms=65.814
FEL28 multi prepared_during_victory before=1 after=1 PASS
FEL28 multi input_to_ready_ms before=3724.385 after=3694.410 PASS
FEL28 HEADLESS TIMING multi release max_frame_ms=72.219 reveal_start_frame_ms=72.219
FEL28 HITCH multi release t_ms=37.171 frame_ms=37.171 action frame; no attributed CPU span
FEL28 HITCH multi release t_ms=2862.607 frame_ms=72.219 preceding process frame combat_checkpoint_persist_storage=6.73ms, refresh_ui_large_map=6.45ms, refresh_ui_grimoire_sync=6.24ms
FEL28 HEADLESS TIMING multi branch max_frame_ms=29.209 reveal_start_frame_ms=17.729
FEL28 burst fixture before=1 after=1 PASS
FEL28 burst rail_reflow before=1 after=0 PASS
FEL28 burst death_to_victory_frames before=7 after=4 PASS
FEL28 HEADLESS HANDOFF burst release_ms=115.736 branch_ms=59.692
FEL28 burst prepared_during_victory before=1 after=1 PASS
FEL28 burst input_to_ready_ms before=3771.052 after=3752.530 PASS
FEL28 HEADLESS TIMING burst release max_frame_ms=67.929 reveal_start_frame_ms=67.929
FEL28 HITCH burst release t_ms=42.730 frame_ms=42.730 action frame; no attributed CPU span
FEL28 HITCH burst release t_ms=2909.319 frame_ms=67.929 preceding process frame refresh_ui_grimoire_sync=6.88ms, combat_checkpoint_persist_storage=6.79ms, refresh_ui_large_map=6.68ms
FEL28 HEADLESS TIMING burst branch max_frame_ms=37.464 reveal_start_frame_ms=16.185
FEL28 HITCH burst branch t_ms=831.935 frame_ms=33.181 death frame; no attributed CPU span
FEL28 HITCH burst branch t_ms=1362.755 frame_ms=37.464 death frame; no attributed CPU span
FEL28 HITCH burst branch t_ms=1396.594 frame_ms=33.839 death frame; no attributed CPU span
FEL28 terrain fixture before=1 after=1 PASS
FEL28 terrain rail_reflow before=1 after=0 PASS
FEL28 terrain death_to_victory_frames before=7 after=4 PASS
FEL28 HEADLESS HANDOFF terrain release_ms=116.091 branch_ms=64.988
FEL28 terrain prepared_during_victory before=1 after=1 PASS
FEL28 terrain input_to_ready_ms before=3700.368 after=3699.183 PASS
FEL28 HEADLESS TIMING terrain release max_frame_ms=67.480 reveal_start_frame_ms=67.480
FEL28 HITCH terrain release t_ms=35.864 frame_ms=35.864 action frame; no attributed CPU span
FEL28 HITCH terrain release t_ms=273.796 frame_ms=33.494 draw frame character_dialog_preparation=6.01ms, character_portrait=0.85ms, character_item_slots=0.22ms
FEL28 HITCH terrain release t_ms=2840.000 frame_ms=67.480 preceding process frame refresh_ui_large_map=8.03ms, combat_checkpoint_persist_storage=6.65ms, refresh_ui_grimoire_sync=6.51ms
FEL28 HEADLESS TIMING terrain branch max_frame_ms=27.692 reveal_start_frame_ms=20.730
FEL28 enemy_turn fixture before=1 after=1 PASS
FEL28 enemy_turn rail_reflow before=1 after=0 PASS
FEL28 enemy_turn death_to_victory_frames before=1 after=1 PASS
FEL28 HEADLESS HANDOFF enemy_turn release_ms=28.620 branch_ms=23.958
FEL28 enemy_turn prepared_during_victory before=1 after=1 PASS
FEL28 enemy_turn input_to_ready_ms before=3305.120 after=3362.781 PASS
FEL28 HEADLESS TIMING enemy_turn release max_frame_ms=85.454 reveal_start_frame_ms=85.454
FEL28 HITCH enemy_turn release t_ms=123.498 frame_ms=65.004 draw frame deferred_layout_turn_order_anchor=7.76ms, engine_current_turn_order_visibility=0.35ms, engine_current_turn_order_context=0.28ms
FEL28 HITCH enemy_turn release t_ms=210.232 frame_ms=64.972 draw frame animation_overlay_board_submission=3.96ms | preceding process frame animation_overlay_board_submission=48.44ms, deferred_checkpoint_write=1.30ms
FEL28 HITCH enemy_turn release t_ms=2460.459 frame_ms=85.454 preceding process frame combat_checkpoint_persist_storage=22.80ms, refresh_ui_large_map=5.96ms, refresh_ui_grimoire_sync=5.50ms
FEL28 HEADLESS TIMING enemy_turn branch max_frame_ms=53.087 reveal_start_frame_ms=23.334
FEL28 HITCH enemy_turn branch t_ms=112.223 frame_ms=53.087 draw frame deferred_layout_turn_order_anchor=3.52ms, engine_current_turn_order_visibility=0.17ms, engine_current_turn_order_context=0.17ms
FEL28 midfight fixture before=1 after=1 PASS
FEL28 midfight rail_reflow before=1 after=1 PASS
FEL28 midfight input_to_ready_ms before=1925.050 after=1945.841 PASS
FEL28 HEADLESS TIMING midfight release max_frame_ms=36.496 reveal_start_frame_ms=-1.000
FEL28 HITCH midfight release t_ms=36.496 frame_ms=36.496 draw frame deferred_checkpoint_write=1.10ms, committed_hand_query_normalize=0.08ms
FEL28 HEADLESS TIMING midfight branch max_frame_ms=27.794 reveal_start_frame_ms=-1.000
FEL28 reduced fixture before=1 after=1 PASS
FEL28 reduced rail_reflow before=1 after=0 PASS
FEL28 reduced death_to_victory_frames before=7 after=2 PASS
FEL28 HEADLESS HANDOFF reduced release_ms=118.261 branch_ms=238.125
FEL28 reduced prepared_during_victory before=1 after=1 PASS
FEL28 reduced input_to_ready_ms before=2221.206 after=2970.080 PASS
FEL28 HEADLESS TIMING reduced release max_frame_ms=89.119 reveal_start_frame_ms=89.119
FEL28 HITCH reduced release t_ms=36.792 frame_ms=36.792 draw frame deferred_analytics_batch=0.22ms
FEL28 HITCH reduced release t_ms=2195.896 frame_ms=89.119 draw frame combat_checkpoint_persist_storage=6.38ms, stage_board_submission=3.17ms, grimoire_row_preparation=0.53ms | preceding process frame refresh_ui_large_map=11.43ms, stage_board_submission=5.69ms, refresh_ui_grimoire_sync=5.39ms
FEL28 HEADLESS TIMING reduced branch max_frame_ms=219.572 reveal_start_frame_ms=17.166
FEL28 HITCH reduced branch t_ms=148.493 frame_ms=148.493 draw frame deferred_analytics_batch=0.35ms
FEL28 HITCH reduced branch t_ms=328.368 frame_ms=169.523 action frame; no attributed CPU span
FEL28 HITCH reduced branch t_ms=517.086 frame_ms=183.432 draw frame engine_board_attack_plan_total=0.41ms, engine_board_attack_hits_total=0.24ms, engine_player_action_duplicate=0.14ms
FEL28 HITCH reduced branch t_ms=550.139 frame_ms=33.053 preceding process frame engine_board_attack_plan_total=0.41ms, engine_board_attack_hits_total=0.24ms, engine_player_action_duplicate=0.14ms
FEL28 HITCH reduced branch t_ms=729.932 frame_ms=175.906 death frame; no attributed CPU span
FEL28 HITCH reduced branch t_ms=932.718 frame_ms=196.778 preceding process frame animation_overlay_board_submission=3.02ms
FEL28 HITCH reduced branch t_ms=1157.149 frame_ms=209.212 preceding process frame animation_overlay_board_submission=2.51ms
FEL28 HITCH reduced branch t_ms=1393.456 frame_ms=219.572 draw frame deferred_layout_combat_objective_hud=0.04ms, deferred_layout_combat_action_dock=0.03ms, deferred_sync_hand_side_widths=0.02ms
FEL28 HITCH reduced branch t_ms=1623.984 frame_ms=219.327 draw frame deferred_layout_turn_order_anchor=0.09ms, deferred_layout_boss_health_overlay=0.04ms, deferred_layout_combat_objective_hud=0.04ms | preceding process frame deferred_layout_turn_order_anchor=0.60ms, deferred_layout_combat_action_dock=0.12ms, deferred_layout_combat_objective_hud=0.10ms
FEL28 HITCH reduced branch t_ms=1861.304 frame_ms=196.967 death frame; no attributed CPU span
FEL28 HITCH reduced branch t_ms=2074.995 frame_ms=184.921 death frame; no attributed CPU span
FEL28 HITCH reduced branch t_ms=2218.097 frame_ms=136.342 death frame; no attributed CPU span
FEL28 HITCH reduced branch t_ms=2439.094 frame_ms=206.024 draw frame engine_current_turn_order_visibility=1.38ms, engine_current_turn_order_project_active=0.10ms, engine_current_turn_order_context=0.08ms
FEL28 HITCH reduced branch t_ms=2636.227 frame_ms=152.757 draw frame victory_reward_preparation=14.57ms | preceding process frame victory_reward_preparation=8.14ms
FEL28 HITCH reduced branch t_ms=2794.652 frame_ms=122.307 draw frame refresh_ui_choice_bar_total=7.45ms, refresh_ui_objective=1.15ms, recap_glyph_shaping_preparation=0.67ms | preceding process frame refresh_ui_grimoire_sync=50.98ms, combat_checkpoint_persist_storage=16.37ms, card_finish_played_analytics=2.62ms
FEL28 HITCH reduced branch t_ms=2848.020 frame_ms=36.202 draw frame recap_glyph_shaping_preparation=1.12ms, refresh_ui_visibility_total=0.95ms, refresh_ui_telemetry_context=0.80ms | preceding process frame refresh_ui_hand_total=6.95ms, stage_board_submission=5.86ms, stage_visibility=0.31ms
FEL28 HITCH reduced branch t_ms=2884.146 frame_ms=36.126 draw frame combat_checkpoint_persist_storage=19.24ms, room_map_analytics_flush=0.13ms, recap_glyph_raster_preparation=0.03ms | preceding process frame recap_glyph_shaping_preparation=1.12ms, refresh_ui_visibility_total=0.95ms, refresh_ui_telemetry_context=0.80ms
FEL28 HITCH reduced branch t_ms=2970.080 frame_ms=85.934 draw frame recap_glyph_shaping_preparation=1.27ms | preceding process frame combat_checkpoint_persist_storage=19.24ms, room_map_analytics_flush=0.13ms, recap_glyph_raster_preparation=0.03ms
FEL28 shadow quit_death_save before=reward after=reward PASS
FEL28 shadow quit_victory_save before=reward after=reward PASS
FEL28 shadow quit_reveal_save before=reward after=reward PASS
FEL28 enemy_turn quit_death_save before=combat after=combat PASS
FEL28 enemy_turn quit_victory_save before=combat after=combat PASS
FEL28 enemy_turn quit_reveal_save before=reward after=reward PASS
FEL28 enemy_turn quit_in_flight before=reward after=reward PASS
FEL28 PASS cases=8
```

## Proof for the design owner

Run the normal native comparison and branch sweep from this worktree.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-28 && bash tools/fel28/native.sh /Users/borgerding/workspace/Labyrinth.worktrees/release "$(mktemp -d /tmp/labyrinth_codex/fel28-native.XXXXXX)"
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-28 && bash tools/fel28/native_deaths.sh "$(mktemp -d /tmp/labyrinth_codex/fel28-native-deaths.XXXXXX)"
cd /Users/borgerding/workspace/Labyrinth.worktrees/fel-28 && FEL28_PROJECT=../release bash tools/fel28/native_deaths.sh "$(mktemp -d /tmp/labyrinth_codex/fel28-native-deaths-release.XXXXXX)"
```

Native outputs include audio MP4s, 20 fps comparison strips, renderer PNGs and the per-take JSON. The optional `LABYRINTH_HITCH_TRACE=1` records per-frame load and board submission breakdowns. `FEL28_SAMPLE=1` requests a one-second macOS stack sample at input. Use a separate trace run for diagnostics. The sandbox ran headless checks.

## Chosen proof defaults

- 60 fps, 1920×1080, 100% UI scale, a 45 s cold Continue deadline, and a 15 s observation deadline. The native take timeout is 90 s and the death sweep timeout is 1,800 s.
- Synthetic combat seed 94301 with 24 hero Health and 1 Health per victim. The last enemy in the enemy-turn case starts on Fire. The shadow and reduced-motion cases use the existing 00060 checkpoint.
- Injected disk delay of 120 ms in the in-flight departure check. The matching release/branch departure comparisons omit only the existing active play-time counter.
- Headless timing reports both process-frame ordering and wall intervals. The four-frame VICTORY observation bound at 60 fps includes the release's 40 ms settle and one draw-sampling frame. The native driver checks the 50 ms wall-time cap.
