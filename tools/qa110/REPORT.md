# QA-110 settled UI state hunt

Release production code at `ef75a9a66` with the director's QA-101 and QA-103
drivers at `aa8a8779a`. Godot 4.6.1. Master comparison uses `047c5848f`.
This is a report-only hunt. [Commands and native proof](README.md)

## Findings

| Severity | Reproduction and visible state | Root cause | Fix size | Master |
|---|---|---|---|---|
| S1 | `tharokh-mouse-pass_with_loop`, seed 7262026. Hover Haft Shove until its loop opens, then click Pass. At the settled turn 2 start, Tharokh's warning includes `(6, 3)`, `(6, 4)`, `(6, 5)` and `(3, 4)`. The present-board calculation includes `(2, 5)`, `(5, 3)` and `(5, 4)` instead. The receipt attributes all four extra tiles to the Pass correction. The same correction stage can erase a living foe's current warning. In seed 101003, decision 102, confirm Whirlwind Slash then Walk to `(2, 5)`. That tile loses its red warning because Pass predicts enemy 1 will die before acting. [Focused release replay](out/release-targeted/godot.log) [Headless still](out/findings/red-tile_set.svg) [Scene receipt](out/release-targeted/3-tharokh-mouse-pass_with_loop-red-tile_set.still.json) [Campaign trace](out/default-final/seed-101003/trace.jsonl) [Missing warning receipt](out/default-final/seed-101003/102-run-red-tile_set.still.json) | At-rest stage paint applies the Pass forecast's announced-area adjustments to the single-board threat result. The adjustment replaces the original stamp with the sequentially resolved tiles and drops some threats from foes forecast to die first. [Stage](../../scripts/stage_hover_refresh.gd#L47) [Stamp replacement](../../scripts/pass_forecast_red_tiles.gd#L107) | Small to medium. Decouple the staged tile footprint from the Pass forecast's repeat and loss receipts. | Yes. The matching headless probe reproduced at `047c5848f`. [Master shifted tiles](out/master-targeted-final/godot.log) [Master missing warning](out/master-red-repro/trace.jsonl) |
| S2 | `normal-mouse-focus_loss_drag`, seed 7262026. Press Haft Shove, drag onto the board, and deliver the window-focus-loss notification before releasing. The held card proxy remains visible and drag slot 0 is still active after settling. The simulated path reproduces in all five room types. [Focused release replay](out/release-targeted/godot.log) [Headless still](out/findings/targeting-drag_survived_focus_loss.svg) | The RunScene window notification handler handles mouse exit, application suspend/resume and close. The held card exits through release or input cancellation. The window focus-out branch has no drag retirement. [Window notifications](../../scripts/run_scene.gd#L3874) [Held card input](../../scripts/run_scene.gd#L2443) | Small. Route window focus-out through the existing drag cleanup and verify reentry. | Yes. The matching headless probe reproduced at `047c5848f`. [Master replay](out/master-targeted-final/godot.log) |

## Coverage method

The whole-run driver inherits the QA-101 route policy. Every counted decision
ended at the next sample after two quiet process frames with the animation
lock released, no running scene-tree Tween, the rail out of transition and
the hand fan out of its slide. The last decision before a terminal screen
also receives a boundary. The initial state is sampled as decision zero.
The latest driver waits for the authored Pass tooltip fade and records a
watchdog miss without counting it as a settled check. Each invariant counts
only at an applicable boundary.

- Tooltips, previews and callouts use live GUI ownership, board presentation
  and the retained controls. Production's foe inspection can show its own
  intent path or ghost while the foe is inspected. The check scores retired
  player aiming and foe intent owners.
- Hover uses the actual pointer hit test or controller board candidate and
  compares it with the visible targeting border and retained floor paint.
- Alpha checks visible board/HUD CanvasItems independently for `modulate`
  and `self_modulate`. Authored translucent values have scoped source entries
  below.
- Turn order compares the visible actor key sequence and the overflow
  disclosure against a fresh engine projection for the current HUD
  state. Engine-authored card timing projections, battlefield beat entries
  and hidden Umbra identity are preserved.
- Hand checks the fan's cards in child order against the live deck and
  compares the card/slot positions within 2 px.
- Red reads the board's retained tile inputs and compares them with a fresh
  single-board intent calculation. Pass totals use a separate fresh
  activation forecast and compare the button label, enabled state, tooltip
  and any visible row values.
- Lifetime reads the global Tween census and live AnimationPlayers. Godot
  exposes processed tweens without a bound-owner accessor, so any running
  tween prevents a counted boundary. Room counts compare adjacent observed
  boundaries and retain their modes, room identities and scene instance IDs.

## Authored translucency

| Nodes | Resting value | Authoring site |
|---|---|---|
| Card art shadows | 0.42 self-modulate | [Card shadow](../../scripts/card_widget.gd#L1303) |
| Hand CardWidgets | 0.56 unusable, 0.72 dimmed, 0.90 printed action unavailable | [Card interaction state](../../scripts/card_widget.gd#L986) |
| Initiative brush and portraits | Brush 0.95 active, 0.90 queued, 0.648 projected. Portrait 0.94 queued, 0.74 projected and 0.98 for card projection. Overflow compounds the portrait tint. | [Brush](../../scripts/turn_order_ink.gd#L18) [Portrait](../../scripts/run_scene.gd#L12817) [Overflow](../../scripts/turn_order_slots.gd#L366) |
| Pass art | 0.92 disabled | [Art state](../../scripts/run_scene.gd#L14889) |
| Empty pile icons | 0.42 | [Pile visual](../../scripts/pile_visual_refresh.gd#L28) |
| Movement and Card Play meters | 0.42 disabled or empty | [Movement](../../scripts/run_scene.gd#L13604) [Card Play](../../scripts/run_scene.gd#L13566) |
| Guided prompt Skip | 0.78 | [Skip](../../scripts/contextual_combat_prompt.gd#L478) |
| Retained foe hover and card aim canvases | 0.30 for isolated-out hover paint, 0.50 for the affected aim HUD and its tab | [Hover dim](../../scripts/board_threat_isolation.gd#L94) [Aim HUD](../../scripts/board_aim_focus.gd#L204) [Tab](../../scripts/intent_badges.gd#L742) |
| Bodies occluding the focused diamond | 0.30 while the board focus owns that occlusion | [Occlusion reveal](../../scripts/board_occlusion_reveal.gd#L3) [Canvas alpha](../../scripts/board_aim_focus.gd#L76) |
| Active targeting border | Pulse 0.85–1.00, and 0.70 invalid tile tint multiplier | [Border update](../../scripts/targeted_tile_highlight.gd#L48) |
| Boss status forecast cells | Active preview pulse 0.52–0.74 times base alpha. Reduced motion holds at 0.641. | [Boss HUD binding](../../scripts/combat_hud_forecast.gd#L190) [Pulse](../../scripts/combat_preview_pulse.gd#L8) |

## Coverage and verdicts

All ten scored runs reached a natural endpoint and returned runner exit 0. Every logged decision has a settled receipt. The 8,387 campaign samples include the ten initial states. The matrix contributes 95 more settled samples. [Census](out/analysis/coverage.json) [Default campaign](out/default-final/report.md) [No-Embrace campaign](out/no-embrace-final/report.md)

| Lane | Terminal outcomes | Decisions | Settled samples | Room visits |
|---|---|---:|---:|---:|
| Default · 101001–101008 | 8 embrace | 2,350 | 2,358 | 85 |
| No Embrace · 101013–101014 | 2 victory | 6,027 | 6,029 | 144 |

| Invariant | Applicable settled checks | Raw flagged boundaries | Verdict |
|---|---:|---:|---|
| Tooltips, keyword pop-ups and hover callouts | 6,836 | 0 | Clean in the scored samples. |
| Targeting, aim and destination ownership | 6,836 | 5 | Not clean. Five pointer drags survived simulated focus loss. |
| Hover ring and raised tile border | 6,836 | 0 | Clean in the scored samples. |
| Partial CanvasItem alpha | 6,836 | 881 | No stuck fade confirmed. The recorded exceptions are authored tint or transitional motion. |
| Turn-order HUD | 6,436 | 41 | Clean in the calibrated projection checks. The early comparison yielded card-selection flags. |
| Hand order, IDs and slot geometry | 6,836 | 4 | Clean after accounting for the authored selected-card lift. |
| Present-board red tiles | 6,169 | 248 | Not clean. Matched release and master replays show shifted and omitted warnings. |
| Pass label, lock state and forecast totals | 6,836 | 0 | Clean in the scored samples. |
| Tween and AnimationPlayer retirement | 8,482 | 0 | Clean at the observed boundaries. Room counts vary below. |

Raw flags retain calibration history. Seed 101013 ran before the audit included card timing in its rail oracle, recognized all authored translucency, and waited for the Pass fade. Its 41 rail flags occurred on card selections. The four remaining hand flags in the merged interruption log are the authored −5 px selected CardWidget lift, which is about 4.16 screen px at the observed scale. [Card pose](../../scripts/card_widget.gd#L2434) [Pass fade](../../scripts/pass_forecast_focus_tooltip.gd#L13)

The red flags include 143 authored Umbral Snare pressure cells from runs before the audit added that decorator. Thirty-six campaign receipts directly link a mismatch to the Pass correction or predicted early death. Seven further differences occurred while aiming in earlier captures and lack a matched reproduction. [Snare pressure paint](../../scripts/snare_pressure_view.gd#L15) [Red campaign receipt](out/analysis/red-tile_set.svg)

## Room node census

Only one of 209 same-scene room boundaries returned to the identical live-tree count. These are differences from a room’s first settled sample to the next room’s first settled sample or the run terminal screen. The recorded modes and board rosters vary, so the growth comparison does not establish a retained-node leak. [Room receipts](out/analysis/coverage.json)

| Departing room type | Boundaries | Live-tree node delta | Orphan-node delta |
|---|---:|---:|---:|
| boss | 11 | -790 to +586 | 0 to +26 |
| campfire | 32 | -101 to +1,154 | 0 |
| combat | 64 | -707 to +880 | -8 to +19 |
| ember_hoarder | 2 | -1,393 to -1,058 | 0 |
| event | 28 | -356 to +548 | 0 |
| graftwright | 4 | +57 to +1,516 | -19 to 0 |
| guardian | 7 | -645 to +255 | 0 |
| last_light | 6 | -401 to +426 | 0 |
| scavenger | 13 | -261 to +242 | 0 |
| start | 22 | +266 to +1,126 | 0 |
| treasure | 17 | -85 to +563 | 0 |
| umbral_snare | 2 | -89 to +489 | 0 |
| warband | 1 | -217 | 0 |

The inherited section-growth diagnostic also fired. Startup logs retain the sandbox CA certificate message. The early observer emitted a duplicate mouse-entry notification, which was removed after calibration. The matched master retained its known right-column anchor warning. [QA-103 baseline notes](../qa103/REPORT.md)

## Interruption witnesses

| Path | Attempts | Observed boundary |
|---|---:|---|
| Right-click, Esc, controller B during aim | 5 each | All 15 entered targeting and cancelled. |
| Card → foe → tile | 10 | All 10 transferred ownership at one-frame intervals. Mouse hit testing uses the actual event position. Controller navigation uses the shipped virtual-cursor candidates. |
| Grimoire, Settings, Deck during animation | 10 each | All 30 requests met the lock. All 30 opened and closed in the unlocked positive control. The production entry handlers reject the locked requests. |
| Pass with keyword loop open | 10 | All 10 entered Pass with one loop visible. Each loop retired after the turn. |
| Foe dies during its own move | 10 | All 10 resolved lethal Fire on an actual movement entry. The fixture used a grounded crawler where the original roster could not reach the trigger. |
| Summon while hero card is hovered | 10 | All 10 summons arrived. In the five mouse cases the pointer still covered the card at arrival. The hand's logical hover had been cleared in all 10 cases. The live controller hover/arrival overlap was not reached. |
| Window focus loss during drag or aim | 10 | Five mouse drags and five controller aims received the simulated focus event. The five pointer drags survived. Controller aim is the available controller equivalent, and physical focus loss remains a native check. |

The lock rejects Grimoire and the menu through their main buttons, and the
deck rejects pile activation while inert. The hand ignores hover starts while
animated, so a pointer being over a card and the card owning logical hover
are different observations during Pass. [Grimoire and menu](../../scripts/run_scene.gd#L28795)
[Pile input](../../scripts/run_scene.gd#L29412) [Hand hover](../../scripts/run_scene.gd#L21645)

[Initial matrix](out/interruptions/godot.log)
[Pointer and mechanic recheck](out/interruption-recheck/godot.log)
[Tharokh and Umbra death recheck](out/death-recheck/godot.log)
[Focused release](out/release-targeted/godot.log)
[Matched master](out/master-targeted-final/godot.log)

## Verification and proof

```text
QA110 COVERAGE whole_runs=10/10 decisions=8377 settled=8387 interruption_triggers=85/95
RUN HUNT RESULT: started=8 finished=8 finding_groups=2
RUN HUNT RESULT: started=2 finished=2 finding_groups=5
QA110 INTERRUPTIONS cases=95 headless=true
QA110 INTERRUPTIONS cases=50 headless=true
QA110 INTERRUPTIONS cases=4 headless=true
QA110 INTERRUPTIONS cases=3 headless=true
QA103 RESULT interruptions.gd: PASS (0 failures)
THREATS AT REST TEST RESULT: PASS (16324 assertions; includes compass suite)
RUN HUNT: seed=101003 outcome=replay_point decisions=102
QA110 native replay parser exit=0
ISOLATION AUDIT: 56 modules
```

The three-case receipt passed on both builds. The Python isolation command
ran in audit-only mode. The existing focused Godot test ran through the
task runner. The first master probe exposed a tool compatibility issue
because the release-only static forecast source helper was missing. The
repeat used the common RunScene source entry point and exited 0.

The headless stills record scene state at 1920×1080. Native viewport images and
the physical window focus event remain [owner proof](README.md#proof-for-the-design-owner).
The default campaign inherits QA-101's headless window setup, which reports a
1920×1920 logical viewport in the new telemetry. The focused interruption and
master replays report 1920×1080. That difference matters for geometry and
prevents treating campaign state receipts as desktop pixel proof.

## Chosen defaults

The driver uses QA-101's deterministic seeds and route policy, including its
9,999 starting Health stress fixture, fastest combat, 120 FPS cap and ×8 scene
clock. The interruption lane uses QA-103's encounter fixtures, 60 FPS and ×4
headless scene time. Its debug hand uses the shipped Haft Shove and Stone Plate.
The forced own-move death fixture starts a foe at 1 internal Health unit and
places shipped Fire on its actual path. The forced arrival fixture uses the
shipped Zekarion summon intent. The work uses a 20-second campaign settle
watchdog, 300 interruption boot frames, 600 settle frames, four input-layout
frames and a one-second hover dwell. Native focus proof waits up to 20 seconds
for a physical focus event.

No `TODO_DESIGN_*` placeholders or production changes.
