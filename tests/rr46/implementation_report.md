# rr-46 measurement and implementation evidence

Changes are uncommitted. No art, compiled motion, integration values, poses, gameplay outcomes, analytics, or saves were edited.

## Timing measurements

All triples below are seconds at **Normal / Fast / Fastest** (1× / 1.5× / 2×). The before table was captured before production edits by `tests/rr46/timing.gd --measure-only`; the after table executes the production path planner and death clock APIs. Microsecond frame rounding explains the last few digits.

Legacy movement comes from `CombatPacing.walk_frame_seconds`: `ENEMY_TILE_SECONDS=0.20` minus `FloatingCombatText.TARGET_FRAME_SECONDS=1/60`, divided by segment frame count. The path runner holds each scheduled frame, giving approximately 0.183333 s/tile, with one display frame reserved in the 0.20 s budget. `RunScene.MOVE_STEP_FRAMES=8` and `MOVE_FRAME_SECONDS=0.045` supply Ash Hound’s fallback before the clamp; Cinder Ooze has its own distance-dependent walk frame count at 60 Hz before the same clamp. Multi-tile segments and arrival cues retain the original chaining.

Legacy death is the procedural dissolve: 28 frames × 0.037 = 1.036 seconds. These existing Board constants now alias the shared playback clock; their values are unchanged. Its clip and fade overlap rather than adding a second clip. Rig deaths with a declared sequential fade scale the entire existing timeline uniformly, so the clip/fade boundary and chain-release/landing phases stay unchanged. Undeclared deaths keep their simultaneous dissolve.

`SettingsStore.combat_speed_scale` supplies 1/1.5/2. `CombatPacing` applies that to `Engine.time_scale` and its presentation clock. Enemy action windup/feedback additionally uses `ENEMY_ACTION_SPEED_SCALE=0.80`; thus attacks and hits/deaths occurring inside that scope divide by an additional 0.8. Caption lead/settle and hit-stop remain the existing shared behavior. Timings below start at clip/death-runner submission and exclude preceding caption/feedback waits and common hit-stop.

| Actor | Move before N/F/FF | Move after N/F/FF | Death before N/F/FF | Death after N/F/FF | Hit window N/F/FF |
|---|---|---|---|---|---|
| ash_hound | 0.183348 / 0.122232 / 0.091674 | 0.183348 / 0.122232 / 0.091674 | 1.036000 / 0.690667 / 0.518000 | 1.036000 / 0.690667 / 0.518000 | 0.360000 / 0.240000 / 0.180000 |
| ember_tick | 0.700014 / 0.466676 / 0.350007 | 0.700014 / 0.466676 / 0.350007 | 0.900000 / 0.600000 / 0.450000 | 0.900000 / 0.600000 / 0.450000 | 0.500000 / 0.333333 / 0.250000 |
| cinder_ooze | 0.183335 / 0.122223 / 0.091667 | 0.183335 / 0.122223 / 0.091667 | 1.036000 / 0.690667 / 0.518000 | 1.036000 / 0.690667 / 0.518000 | 0.360000 / 0.240000 / 0.180000 |
| hoarfrost_seer | 0.900018 / 0.600012 / 0.450009 | 0.183330 / 0.122220 / 0.091665 | 1.700000 / 1.133333 / 0.850000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| arc_thrall | 0.850017 / 0.566678 / 0.425009 | 0.183345 / 0.122230 / 0.091673 | 1.500000 / 1.000000 / 0.750000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| glacial_mirror | 0.900018 / 0.600012 / 0.450009 | 0.183330 / 0.122220 / 0.091665 | 1.500000 / 1.000000 / 0.750000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| briar_weaver | 0.900018 / 0.600012 / 0.450009 | 0.183330 / 0.122220 / 0.091665 | 2.536000 / 1.690667 / 1.268000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| hollow_mimic | 0.800016 / 0.533344 / 0.400008 | 0.183312 / 0.122208 / 0.091656 | 2.436000 / 1.624000 / 1.218000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| slag_mortar | 0.850017 / 0.566678 / 0.425009 | 0.183345 / 0.122230 / 0.091673 | 2.536000 / 1.690667 / 1.268000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| gale_herald | 0.900018 / 0.600012 / 0.450009 | 0.183330 / 0.122220 / 0.091665 | 2.536000 / 1.690667 / 1.268000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| gloam_stalker | 0.850017 / 0.566678 / 0.425009 | 0.183345 / 0.122230 / 0.091673 | 2.436000 / 1.624000 / 1.218000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| frostglass_lancer | 0.850017 / 0.566678 / 0.425009 | 0.183345 / 0.122230 / 0.091673 | 2.636000 / 1.757333 / 1.318000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |
| chainbound_gaoler | 0.850017 / 0.566678 / 0.425009 | 0.183345 / 0.122230 / 0.091673 | 2.636000 / 1.757333 / 1.318000 | 1.036000 / 0.690667 / 0.518000 | 0.500000 / 0.333333 / 0.250000 |

Ash Hound has no articulated hit clip; 0.36 s is the legacy contextual reaction window, with the existing 0.140 s impact flash. Hit contact is t=0 relative to the damage trigger. Rig hit clips remain authored at 0.50 s; Cinder Ooze’s contextual hit window remains 0.36 s. Enemy-action hit windows divide these values by 0.8, just like other actors.

For deaths submitted inside enemy-action feedback, the legacy and all ten rig-v2 totals are **1.295000 / 0.863333 / 0.647500 s**. Their hit windows are **0.625000 / 0.416667 / 0.312500 s** for maquettes, **0.450000 / 0.300000 / 0.225000 s** for legacy reactions. The JSON records both death contexts explicitly; no additional action multiplier is applied to movement.

**Source discrepancies, preserved:** production Seer, Mirror, Weaver and Herald moves are 0.90 s rather than the brief’s 0.80–0.85 range. Ember Tick already uses a maquette adapter (0.70 s move, 0.90 s simultaneous death), so it is not on the old sprite clock in this checkout; its out-of-scope timing is unchanged. Ash Hound and Cinder Ooze establish the common legacy parity target.

| Rig | Move duration multiplier | Death duration multiplier | Scaled collapse | Scaled sequential fade |
|---|---:|---:|---:|---:|
| hoarfrost_seer | 0.203700000 | 0.609411765 | 1.036000 | 0.000000 |
| arc_thrall | 0.215700000 | 0.690666667 | 1.036000 | 0.000000 |
| glacial_mirror | 0.203700000 | 0.690666667 | 1.036000 | 0.000000 |
| briar_weaver | 0.203700000 | 0.408517350 | 0.612776 | 0.423224 |
| hollow_mimic | 0.229140000 | 0.425287356 | 0.595402 | 0.440598 |
| slag_mortar | 0.215700000 | 0.408517350 | 0.612776 | 0.423224 |
| gale_herald | 0.203700000 | 0.408517350 | 0.612776 | 0.423224 |
| gloam_stalker | 0.215700000 | 0.425287356 | 0.595402 | 0.440598 |
| frostglass_lancer | 0.215700000 | 0.393019727 | 0.628832 | 0.407168 |
| chainbound_gaoler | 0.215700000 | 0.393019727 | 0.628832 | 0.407168 |

Multipliers are playback duration/authored duration; playback rates are their reciprocals. Zero sequential fade means the dissolve still overlaps the clip, not that the unit disappears without a fade.

## Attack windup/contact measurements

The windup is the scheduled first-contact callback measured from the first t=0 frame submission; contact duration is an instant. Triples include the existing enemy-action 0.80 clock at each combat speed. No attack duration or contact mapping changed. `authored_contact_seconds` is retained separately in the JSON so pose-phase contact is not confused with gameplay callback time. Generic actions retain `AttackFxLibrary.feedback_start_progress`; case adapters retain their own endpoint/ceil mapping. Captions lead by the existing 0.25 s (first actor shares the 0.35 s banner lead) outside this clip clock.

| Actor / clip | Complete clip N/F/FF | Windup to contact N/F/FF | Route |
|---|---|---|---|
| ash_hound / bite | 0.300000 / 0.200000 / 0.150000 | 0.100000 / 0.066667 / 0.050000 | RunScene/AttackFxLibrary |
| ash_hound / circle | 0.300000 / 0.200000 / 0.150000 | 0.100000 / 0.066667 / 0.050000 | RunScene/AttackFxLibrary |
| ember_tick / bite | 0.750000 / 0.500000 / 0.375000 | 0.312500 / 0.208333 / 0.156250 | RunScene/AttackFxLibrary |
| ember_tick / kindle | 1.125000 / 0.750000 / 0.562500 | 0.541667 / 0.361111 / 0.270833 | RunScene/AttackFxLibrary |
| cinder_ooze / cinder_bloom | 1.000000 / 0.666667 / 0.500000 | 0.375000 / 0.250000 / 0.187500 | RunScene/AttackFxLibrary |
| cinder_ooze / smolder_slide | 0.875000 / 0.583333 / 0.437500 | 0.354167 / 0.236111 / 0.177083 | RunScene/AttackFxLibrary |
| hoarfrost_seer / bolt | 1.062500 / 0.708333 / 0.531250 | 0.333333 / 0.222222 / 0.166667 | RunScene/AttackFxLibrary |
| hoarfrost_seer / land | 1.000000 / 0.666667 / 0.500000 | 0.479167 / 0.319444 / 0.239583 | RunScene/AttackFxLibrary |
| hoarfrost_seer / mark | 1.625000 / 1.083333 / 0.812500 | 0.791667 / 0.527778 / 0.395833 | RunScene/AttackFxLibrary |
| hoarfrost_seer / ward | 1.125000 / 0.750000 / 0.562500 | 0.541667 / 0.361111 / 0.270833 | RunScene/AttackFxLibrary |
| arc_thrall / jab | 0.875000 / 0.583333 / 0.437500 | 0.354167 / 0.236111 / 0.177083 | RunScene/AttackFxLibrary |
| arc_thrall / tether | 1.500000 / 1.000000 / 0.750000 | 0.729167 / 0.486111 / 0.364583 | assets/units/hoarfrost_seer_cutout/actions.gd |
| glacial_mirror / guard | 1.125000 / 0.750000 / 0.562500 | 0.500000 / 0.333333 / 0.250000 | assets/units/glacial_mirror_cutout/actions.gd |
| glacial_mirror / refraction | 1.375000 / 0.916667 / 0.687500 | 0.687500 / 0.458333 / 0.343750 | assets/units/glacial_mirror_cutout/actions.gd |
| briar_weaver / lash | 0.937500 / 0.625000 / 0.468750 | 0.333333 / 0.222222 / 0.166667 | RunScene/AttackFxLibrary |
| briar_weaver / mend | 1.250000 / 0.833333 / 0.625000 | 0.687500 / 0.458333 / 0.343750 | assets/units/briar_weaver_cutout/actions.gd |
| briar_weaver / thornwall | 1.375000 / 0.916667 / 0.687500 | 0.750000 / 0.500000 / 0.375000 | assets/units/briar_weaver_cutout/actions.gd |
| hollow_mimic / block | 1.000000 / 0.666667 / 0.500000 | 0.395833 / 0.263889 / 0.197917 | scripts/maquette_cutout_runtime/contact_actions.gd |
| hollow_mimic / bolt | 1.000000 / 0.666667 / 0.500000 | 0.458333 / 0.305556 / 0.229167 | scripts/maquette_cutout_runtime/contact_actions.gd |
| hollow_mimic / mirror | 1.125000 / 0.750000 / 0.562500 | 0.562500 / 0.375000 / 0.281250 | scripts/maquette_cutout_runtime/contact_actions.gd |
| slag_mortar / brace | 1.125000 / 0.750000 / 0.562500 | 0.458333 / 0.305556 / 0.229167 | assets/units/slag_mortar_cutout/actions.gd |
| slag_mortar / land | 0.750000 / 0.500000 / 0.375000 | 0.229167 / 0.152778 / 0.114583 | assets/units/slag_mortar_cutout/actions.gd |
| slag_mortar / lob | 1.500000 / 1.000000 / 0.750000 | 0.895833 / 0.597222 / 0.447917 | assets/units/slag_mortar_cutout/actions.gd |
| slag_mortar / scatter | 1.000000 / 0.666667 / 0.500000 | 0.229167 / 0.152778 / 0.114583 | RunScene/AttackFxLibrary |
| gale_herald / call_the_wind | 1.500000 / 1.000000 / 0.750000 | 0.895833 / 0.597222 / 0.447917 | scripts/maquette_cutout_runtime/contact_actions.gd |
| gale_herald / gust_bolt | 1.000000 / 0.666667 / 0.500000 | 0.458333 / 0.305556 / 0.229167 | scripts/maquette_cutout_runtime/contact_actions.gd |
| gale_herald / still_air | 1.125000 / 0.750000 / 0.562500 | 0.562500 / 0.375000 / 0.281250 | scripts/maquette_cutout_runtime/contact_actions.gd |
| gloam_stalker / ambush | 0.875000 / 0.583333 / 0.437500 | 0.354167 / 0.236111 / 0.177083 | scripts/maquette_cutout_runtime/contact_actions.gd |
| gloam_stalker / fade | 1.000000 / 0.666667 / 0.500000 | 0.500000 / 0.333333 / 0.250000 | assets/units/gloam_stalker_cutout/actions.gd |
| gloam_stalker / slash | 1.000000 / 0.666667 / 0.500000 | 0.479167 / 0.319444 / 0.239583 | scripts/maquette_cutout_runtime/contact_actions.gd |
| frostglass_lancer / cast | 1.187500 / 0.791667 / 0.593750 | 0.645833 / 0.430556 / 0.322917 | scripts/maquette_cutout_runtime/contact_actions.gd |
| frostglass_lancer / guard | 1.125000 / 0.750000 / 0.562500 | 0.333333 / 0.222222 / 0.166667 | scripts/maquette_cutout_runtime/contact_actions.gd |
| frostglass_lancer / jab | 0.750000 / 0.500000 / 0.375000 | 0.333333 / 0.222222 / 0.166667 | scripts/maquette_cutout_runtime/contact_actions.gd |
| frostglass_lancer / lunge | 1.375000 / 0.916667 / 0.687500 | 0.666667 / 0.444444 / 0.333333 | scripts/maquette_cutout_runtime/contact_actions.gd |
| frostglass_lancer / pin | 1.500000 / 1.000000 / 0.750000 | 0.979167 / 0.652778 / 0.489583 | scripts/maquette_cutout_runtime/contact_actions.gd |
| chainbound_gaoler / guard | 1.125000 / 0.750000 / 0.562500 | 0.333333 / 0.222222 / 0.166667 | scripts/maquette_cutout_runtime/contact_actions.gd |
| chainbound_gaoler / pin | 1.000000 / 0.666667 / 0.500000 | 0.500000 / 0.333333 / 0.250000 | scripts/maquette_cutout_runtime/contact_actions.gd |
| chainbound_gaoler / press | 1.062500 / 0.708333 / 0.531250 | 0.520833 / 0.347222 / 0.260417 | scripts/maquette_cutout_runtime/contact_actions.gd |
| chainbound_gaoler / reel | 1.375000 / 0.916667 / 0.687500 | 0.687500 / 0.458333 / 0.343750 | scripts/maquette_cutout_runtime/contact_actions.gd |

## Draw-order evidence

The headless check covers six biomes × three tiers × map revisions 6 and 7: 36 Warband boards, all ten rigs, eight travel directions (including both camera diagonals), every source frame phase, stationary deaths, and 30 resolver-generated keep-distance routes. It checks occupied floor ownership against resolved tile-space paths independently of production’s world-to-floor inverse. An additional 481 actual retained-cache submissions cover every rig/direction and the Seer's displayed root reaching a tile ahead of linear t. Native pixel occlusion still requires the native probe; the headless result is not a claim about painted pixels.

The defect is destination-tile ownership for the entire travel segment. During a retreat toward the rear, that submits the body before its current floor/foreground tile; toward the camera it can submit in front of nearer props too early. The fix uses the current displayed ground root (all protected move roots have forward travel only), inverts the board lattice (nearest Euclidean centre is incorrect for diagonals), invalidates retained grouping when geometry changes, and re-sorts occupants when a rig moves. Death and unchanged static actors retain their original depth.

Observed result: `RR46 DEPTH ORDER: PASS (36 boards; 173718 frames; 74248 old-routing failures; 30 retreat routes; native pixels=false)`. Each grouped finding lists board, actor, clip, representative frame, all failing frame numbers, source/destination, old/expected tile and planned crop filename in `/private/tmp/labyrinth_codex/rr46/depth-final.json`. These are depth-routing findings, not inspected renderer defects.

## Numbered requirements and acceptance

1. **Measure first:** the immutable before table, after table, per-rig factors and attack/contact table above cover all thirteen actors at all three settings. `timing_baseline.json` retains the pre-edit measurement; the timing probe executes the production path planner.
2. **Movement parity:** the ten humanoid move clocks now use the existing enemy tile budget. Two-tile production schedules match within one 60 Hz frame at every setting; dropping the scaling fails. Source phases, gait gates and segment chaining are preserved. Seer's protected four-shuffle exception is recorded below.
3. **Death parity:** shared playback scales the whole authored clip/fade timeline to the legacy 1.036-second budget. The factors above preserve release, landing and clip/fade boundary phases. Dropping the scaling fails.
4. **Combat settings:** the existing Engine/presentation-clock scope applies all three settings and the existing enemy-action multiplier. The clock regression verifies the installed scope rather than a new standalone speed implementation; attacks and hits retain their existing schedules.
5. **Feet/floor ordering:** the headless sweep reproduces the old destination-depth mismatch and checks the fixed current-ground ownership, retained caches, all directions, resolver retreats and stationary deaths on every Warband board. Native crop inspection and proof of every painted piece against walls/props remain pending for the design owner. Exact native commands and expected outputs are in `proof_for_design_owner.md`.

Authored poses/reference assets remain byte-identical (2,558 protected files). The rr-40 fresh/prepared geometry oracle passes headlessly; its renderer-pixel branch is included in the owner's native commands. The full suites and historical compatibility migrations are reported below.

## Design placeholder and proof limits

`TODO_DESIGN_SEER_SIX_STEP_GAIT`: protected Seer data authors four shuffles under the robe and has no six-step gait declaration. Its existing poses are preserved. The other nine rigs pass the independent planted-stance/apex-knee gates on unchanged authored phase samples mapped to all three accelerated clocks. At display rates, some dense authored phases naturally fall between output frames.

Native floor/wall/prop pixel sweeps, crops, rr-40 pixel geometry and fight footage remain for the design owner because this sandbox has no window-server access. No windowed run was attempted. Commands and output locations are in `proof_for_design_owner.md`.

## Chosen defaults

All-rig Python checks use a temporary project with current code and approved assets archived from the pinned Git base. Ten per-family live byte checks keep the existing Python resource groups separate. The audit estimates a longest shard of 1479 seconds (previous broad reader would have forced 3239 seconds).

Only proof/numerical defaults were chosen: 1920×1080 at UI scale 1.0 (required); two settled renderer frames; seed 83 and revisions 6/7 from the existing Warband fixture; eight direction vectors; depth-fixture player HP/max HP 40 and actor HP/max HP 10; comparison origins (2,3)/(2,4), two tiles; proof player HP/max HP 1000; three recorded real rounds, three staged retreat repetitions and a 30 FPS recording cap; test/engine timeouts 300/360 seconds, native comparison timeout 120 seconds and all-findings batch timeout 3600 seconds; cache probes at phases 0, 0.25, 0.49, 0.51, 0.75 and 1; a 100000-usec synthetic clock sample; 1800-second full Godot budget for the full program manifest and the large asset-import pass; numerical floor-boundary epsilon 0.000001. Crop framing uses the actual padded unit rectangle. All are plain named constants/fields or explicit proof-runner arguments, and none changes production tuning.

## Focused validation results

- `focused-final.log`: `Ran 16 tests in 82.549s` / `OK`. Current-code temporary projects use immutable approved asset inputs; per-family checks verify all 2,558 live protected files.
- `final-clocks.log`: `RR46 TIMING: PASS (39 actor/speed rows; production path schedule)` and `RR46 SCALING MUTATIONS: PASS (move and death rejected by production schedule checks)`.
- `depth-final.log`: `RR46 DEPTH ORDER: PASS (36 boards; 173718 frames; 74248 old-routing failures; 30 retreat routes; native pixels=false)`; JSON additionally records 481 retained-cache cases and zero errors.
- rr-40 fresh/prepared: `RR46 RR40 GEOMETRY: PASS (fresh and prepared; native pixels=false)`.
- Gait: `RR46 SCALED GAIT GATES: PASS (9 six-step rigs x 2 views; planted stances and apex knees; three playback clocks; Seer retains protected four-shuffle clip)`.
- `rr17-final.log`: `RR17 RUNTIME: PASS (58 checks, 0 failures; headless logic only)`. Its shared opt-in fixture now uses non-humanoid Ember Tick so all original cross-identity clock/seed assertions remain intact; humanoid scaling is covered separately.
- `fight-final-validation.log`: `REAL FIGHT CAPTURE VALIDATION: PASS`, persisted fixture/Continue only. An attempted extended headless fight playback reached its 300-second limit; native action playback remains pending.
- Native depth and comparison scripts pass Godot `--check-only`; comparison additionally reports `RR46 COMPARISON: PASS (two tiles; Slag Mortar beside Ash Hound; native=false)`.
- Initial `--import` reached its 300-second limit while importing the large existing asset tree. The complete cache pass with the known-workload 1800-second budget exited 0. Import was for resource caches/UIDs, never parser proof.
- The first full Godot attempt was interrupted after finding the Seer displayed-root edge case. The next full run completed with `TEST RESULT: FAIL (3 failure(s))`: the rr-17 fixture addressed above, missing imported emblem textures addressed by completing import, and a status-plate movement-plan timing cap (`7305 us` vs `4000 us`) during concurrent import. Assertions were not relaxed. A clean final full run follows.

## Files changed

- `scripts/combat_board_view.gd`
- `scripts/maquette_cutout_runtime/board_depth.gd`
- `scripts/maquette_cutout_runtime/board_depth.gd.uid`
- `scripts/maquette_cutout_runtime/death.gd`
- `scripts/maquette_cutout_runtime/death_sequence.gd`
- `scripts/maquette_cutout_runtime/playback_timing.gd`
- `scripts/maquette_cutout_runtime/playback_timing.gd.uid`
- `scripts/run_scene.gd`
- `tests/fix18/rest_provenance.py`
- `tests/headless_test_programs.json`
- `tests/rr17/feedback_samples.gd`
- `tests/rr17/runtime_test.gd`
- `tests/rr19/overlap_samples.gd`
- `tests/rr22/runtime_checks.gd`
- `tests/rr30/runtime_checks.gd`
- `tests/rr46/attack_timings.gd`
- `tests/rr46/attack_timings.gd.uid`
- `tests/rr46/clock_scene.gd`
- `tests/rr46/clock_scene.gd.uid`
- `tests/rr46/comparison_probe.gd`
- `tests/rr46/comparison_probe.gd.uid`
- `tests/rr46/comparison_proof_contract.json`
- `tests/rr46/depth_check.gd`
- `tests/rr46/depth_check.gd.uid`
- `tests/rr46/depth_probe.gd`
- `tests/rr46/depth_probe.gd.uid`
- `tests/rr46/depth_proof_contract.json`
- `tests/rr46/depth_sweep.gd`
- `tests/rr46/depth_sweep.gd.uid`
- `tests/rr46/fight_probe.gd`
- `tests/rr46/fight_probe.gd.uid`
- `tests/rr46/fight_proof_contract.json`
- `tests/rr46/gait_samples.gd`
- `tests/rr46/gait_samples.gd.uid`
- `tests/rr46/implementation_report.md`
- `tests/rr46/preservation.py`
- `tests/rr46/proof_for_design_owner.md`
- `tests/rr46/rest_binding_changes.json`
- `tests/rr46/rest_provenance.py`
- `tests/rr46/runtime_preservation.py`
- `tests/rr46/sprite_geometry.gd`
- `tests/rr46/sprite_geometry.gd.uid`
- `tests/rr46/timing.gd`
- `tests/rr46/timing.gd.uid`
- `tests/rr46/timing_baseline.json`
- `tests/test_fix18_draw_origin.py`
- `tests/test_program_suite_runner.py`
- `tests/test_pt14_04_coverage.py`
- `tests/test_rr17_integration.py`
- `tests/test_rr19_overlap.py`
- `tests/test_rr46_playback.py`
- `tests/test_rr46_preserve_arc_thrall.py`
- `tests/test_rr46_preserve_briar_weaver.py`
- `tests/test_rr46_preserve_chainbound_gaoler.py`
- `tests/test_rr46_preserve_frostglass_lancer.py`
- `tests/test_rr46_preserve_gale_herald.py`
- `tests/test_rr46_preserve_glacial_mirror.py`
- `tests/test_rr46_preserve_gloam_stalker.py`
- `tests/test_rr46_preserve_hoarfrost_seer.py`
- `tests/test_rr46_preserve_hollow_mimic.py`
- `tests/test_rr46_preserve_slag_mortar.py`
- `tests/windowed_test_allowlist.json`
- `tools/python_suite_resources.json`

## Final full Godot suite

Command: `python3 tools/godot_task_runner.py --task-id rr-46 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd`.

The final tree run, `full-godot-final-tree.log`, reports:

```text
MAIN BODY ASSERTIONS: 495687
FULL SUITE RUNTIME: 765.096 seconds (budget 900 seconds)
TEST RESULT: PASS
```

All 234 program results passed, exit 0. The existing ObjectDB leak-at-exit warning remains in the log; it did not fail the runner. The earlier `full-godot-verified.log` also passed (674.072 seconds), before the final historical test/reporting corrections.

Gloam Fade measurement retains the resolver's compound Veil selector. Its contact is the visual blink start; the existing 0.24-second presentation-clock blink transit (divided by the same combat/action speed) precedes the resolved blink commit. This reporting correction does not change production playback.

## Historical test migrations and first Python run

The first complete sharded Python run reported `Ran 2127 tests in 2370.232s` and `FAILED (failures=11, errors=1, skipped=66)`. Its failures were the Slag authored/playback-duration assumption; the two new program entries missing from the strict manifest suffix; the historical whole-runtime byte pin; two retimed humanoid snapshot comparisons; two legacy-group fixtures still containing a now-retimed humanoid; four obsolete paired-Capacitor clock comparisons; and the rest-source provenance seal. No production data, protected fixture JSON or authored-pose report was rewritten.

The fixes preserve exact legacy clocks on non-humanoid fixtures, require retimed humanoids to keep their solo phases and legacy total, retain every Capacitor frame, and compare the complete historical runtime bytes after reversing only rr-46's exact literal deltas. The rest seal normalizes only four explicitly pinned new/changed playback source bindings before recovering the original complete pose-byte digest; new mutation checks reject changed poses, unknown/missing inputs and forged hashes.

Focused results after these migrations:

- `death-migrations-final.log`: `Ran 20 tests in 37.820s` / `OK`; `RR19 SHARED CLOCK MUTATION: CAUGHT (Tick frame 20 instead of 53 at 0.900 s)`.
- `rr30-final.log`: `RR30 RUNTIME: PASS (320 checks; headless logic only)`.
- `runner-manifest-final.log`: `Ran 2 tests in 0.203s` / `OK`, including removal mutation coverage.
- `runtime-pin-final.log`: `Ran 2 tests in 1.490s` / `OK`, including unrelated-edit and missing-anchor rejection.
- `rest-reseal-final.log`: `RR41 REST/DENSITY RESEAL: PASS (fresh poses byte-identical after pinned fix-18 source bindings; density evidence unchanged)`.
- `rest-provenance-mutations-final.log`: `Ran 2 tests in 0.094s` / `OK`.

An additional manual run of the historical rr-22 runtime probe encounters its existing missing `apron_tip` joint (log `rr22-final.log`); it was stopped after that error. Its old authored-duration check now names the authored API, and its unrelated assertions remain unchanged. It is not one of the registered current runtime programs.

The Python runner could not update its untracked timing-history cache in the shared Git directory: `Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmp5fjlthpj'`. Test outputs remain in the authorized task-local output directory; no permission escalation or workaround was attempted.

## Final Python isolation audit

Command: `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/rr46/final-tree-audit`.

Result: `ISOLATION AUDIT: 238 modules; /private/tmp/labyrinth_codex/rr46/final-tree-audit/isolation-audit.md`, exit 0. Every new Python module has an audited resource entry. New all-rig checks write only per-test temporary projects; the ten live family checks retain their separate shared-resource groups.

## Final full Python suite

Command: `python3 tools/run_python_suite.py --shards 4 --output-dir /private/tmp/labyrinth_codex/rr46/full-python-final`.

`full-python-final.log` reports, exit 1:

```text
Ran 2130 tests in 1693.365s
FAILED (failures=1, skipped=66)
PYTHON SUITE WALL: 1693.365s; results: /private/tmp/labyrinth_codex/rr46/full-python-final
```

Shard totals: 932/204/511/483 tests; zero errors. Shards 1, 2 and 3 passed. The only failure is the unchanged `test_sb02_movement.Movement.test_incremental_submission` performance assertion during concurrent execution. Its payload reported `Movement plan exceeds 4000 us: 13442` and `mixed cold/warm plan exceeds 4000 us: 5253/766/486`. The final Godot suite passed this same movement probe. The absolute cap and its assertions were not changed.

After all shards stopped, the same failing payload was run once through the required task runner:

```sh
python3 tools/godot_task_runner.py --task-id rr-46 --stream -- godot --headless --path . --script tests/status_plates_performance_probe.gd -- --movement-only
```

`sb02-idle.log` reports `STATUS MOVEMENT PROBE RESULT: PASS`, exit 0, with `plan_max_us=1414` against `cap_us=4000`; mixed cold best/warm median were 2068/272 µs. This is consistent with concurrent-load sensitivity. It does not turn the failed full Python invocation into a pass; no assertion or production code was changed after that invocation.

All 17 rr-46 Python tests passed in the full run, including the seven playback/negative controls and ten independent family-preservation checks. The protected-file count remains 2,558. Relevant result lines include:

```text
RR46 SCALING MUTATIONS: PASS (move and death rejected by production schedule checks)
RR46 AUTHORED PRESERVATION: PASS (480 byte-identical protected files vs e3034e24fd81)
RR46 TIMING: PASS (39 actor/speed rows; production path schedule)
RR46 RR40 GEOMETRY: PASS (fresh and prepared; native pixels=false)
RR46 SCALED GAIT GATES: PASS (9 six-step rigs x 2 views; planted stances and apex knees; three playback clocks; Seer retains protected four-shuffle clip)
RR46 DEPTH ORDER: PASS (36 boards; 173718 frames; 74248 old-routing failures; 30 retreat routes; native pixels=false)
RR41 REST/DENSITY RESEAL: PASS (fresh poses byte-identical after pinned fix-18 source bindings; density evidence unchanged)
```

The final Python run also reported the shared-Git cache denial: `Cannot update untracked timing cache /Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/python-suite.json: [Errno 1] Operation not permitted: '/Users/borgerding/workspace/Labyrinth/.git/labyrinth-test-timings/tmpsnj5tzd0'`. This cache-write failure is separate from the test assertion; task-local logs/results were written successfully.

Final `git diff --check` passed. The branch remains `codex/rr-46` at `e3034e24fd8193daf717c691ba8939094927ac51`, with all implementation changes uncommitted and no protected asset changes in the final status.
