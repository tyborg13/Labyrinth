# Run score and run-end recap (meta-01)

Design authority: `spec/peer_benchmark/briefs/meta-01.md` and the approved
`output/peer-benchmark-2026-10-12/mockups/run_end.png` / `run_end.html`.
The brief takes precedence over the mockup's feat order and CSS buttons.
The director's `spec/peer_benchmark/feedback/meta-01_feedback_1.md` supplies
minute formatting, silent reveals, aggregate feats, overflow and legacy copy.
Director feedback 2 specifies oblique, title glow, rule visibility, single-feat
copy, bounded details, full-viewport placement and the withdrawal backdrop.
`data/run_end_text.json` is director-authored and protected. No asset, font,
mechanic, currency rule, Steam metric or achievement is introduced by this unit.

## Counters and save contract

`RunScoreRules.normalized_stats` preserves additive fields and initializes old
snapshots. `CombatEngine` retains the existing `enemies_killed`, `damage_dealt`
and `damage_received` semantics. The new fields are:

| Field | Source |
| --- | --- |
| `rooms_explored` | First committed entry into any room except the Threshold; both ordinary and pre-battle entry paths |
| `enemies_slain` | Alive-to-dead enemy transition, excluding summons and objective-only follower removal |
| `guardians_slain` | Won guardian encounters, guarded by the room's cleared receipt |
| `guardians_unscathed` | Ordered guardian ids won without any cumulative Health loss during that encounter |
| `dragons_slain`, `dragons_flawless` | Ordered dragon ids, each awarded once; flawless uses the same Health-loss receipt |
| `max_single_hit` | Largest resolved direct player hit, after amplification, before defense and Health clamping; absorbed Crystal Mantle hits are excluded |
| `max_kills_one_card` | Largest count of enemy deaths during one card resolution, including its triggered effects and summons |
| `mystery_rooms_entered` | First entry counted before the mystery becomes its resolved room type |
| `events_resolved` | Successful choice-page to result-page transition; repeats and Continue do not increment |
| `max_held_embers` | High-water wallet value, including starting, recovered and HUD-visible pending combat Embers; spending does not decrease it |
| `defiance_spent` | Actual Defiance trigger, independent of capacity increases |
| `run_seconds` | Scene-owned active monotonic elapsed time, copied into the run snapshot only at existing commit/save and run-end boundaries; menu/settings pause, tree pause, hidden run scene and terminal time excluded |
| `killer` | Final lethal enemy type, intent id and resolved incoming damage, or fatigue/surface/trap attribution |

Guardian ids rather than a bare unscathed count retain the names required by the
feat detail. The encounter's starting cumulative Health loss lives in
`combat_state.score_health_loss_at_start`; `combat_state.score_wallet_base` accounts for the carried wallet plus pending room rewards/recovery without double counting. Healing cannot erase loss. Mid-card
`card_resolution_kills` and `card_resolution_active` remain in `run_stats` so
checkpoints/resume retain the resolution boundary. A new encounter resets only
those temporary card fields. Defiance, Last Door and Fatigue survival clear
lethal attribution when the player survives.

RunScene owns a `RunScoreRules` clock instance, sampled from its existing physics
callback independently of dialogue processing and animation time scale. Samples
change only that instance. The recap's legacy physics clock adapter is disabled
when installed in RunScene. Menu transitions, tree-pause and visibility
notifications sample the transition boundary; the clock counts the preceding
active interval and excludes the subsequent inactive interval. Physics catch-up
and dropped steps cannot inflate or discard elapsed play time. No wall timestamp
or pending clock field is saved.

Existing committed-boundary saves copy the cumulative clock into
`run_state.run_stats.run_seconds`, including room exits, combat checkpoints and
explicit saves. Terminal scoring and Embrace commit the clock before building
their result. Loading a run resets the scene clock to the saved total, including
when the same run id is reloaded. Combat stats omit `run_seconds`: encounter
creation, combat adoption, wallet synchronization and save repair all preserve
this separation. Run adoption retains the run snapshot's saved time rather than
reading a stale combat value. Swift and the Chronicle's run-time source continue
to use the committed run field.

## Scoring

`RunScoreRules.score(run_state, outcome)` is pure and returns
`{lines: Array[Dictionary], feats: Array[Dictionary], total: int}`. Each row has
`id`, `label`, `detail`, `points`, `subject`, and `feat`. Zero-point rows are
omitted. Base rows and feat rows are separate ordered lists; the recap appends
feats after base rows.

| Base row | Points |
| --- | --- |
| Rooms explored | N × 5 |
| Enemies slain | N × 2 |
| Guardians slain | N × 25 |
| Dragons slain | Cumulative 50/100/150/200/250/300 per dragon: 1 → 50, 2 → 150, 6 → 1,050; names in slain order |
| Escaped the Umbra | Victory only, 250 |

Feats follow the brief's order: Unscathed (25 per guardian), Flawless (50 per
dragon), Overkill (25 at hit ≥20), Chain Reaction (25 at kills ≥3), Seeker
(25 at mysteries ≥10), Bargainer (25 at events ≥8), Ember Hoard (25 at ≥600,
50 instead at ≥1,200), Last Light (victory, 25 after Defiance), Swift (victory,
50 below 2,700 seconds or 25 below 3,600), Ascetic (victory, 50 with ≤3 relics).
No victory-only row is awarded for defeat or Embrace.

Unscathed and Flawless each occupy one row with summed points. One award uses
`Unscathed` / `Flawless` and `<Name> without losing Health`; two or more use
`Unscathed ×<n>` / `Flawless ×<n>` with names joined by `, `. More than three
names show the first three followed by ` +<k>`. Swift detail uses
`floor(run_seconds / 60)` and `Escaped in <m> minutes`, with `1 minute` singular.

## Persistence and analytics

The completed result ledger retains its existing bound and result-id replay
policy. Results add nullable `score`, `lines`, `feats`, `killer`, `section`,
`biome`, `outcome`, and `new_best_score`. Legacy records retain `score: null`
for Chronicle's later “—” presentation. The profile adds `best_score`, initially
zero. Only a strict improvement earns NEW BEST, and replay retains the original
score and badge decision.

`RunEndRecapOverlay.result_stats` retains the six legacy metric ids and includes
an internal `_score_result` bridge only for terminal states. The existing
RunScene terminal recorder therefore persists defeat/victory scores. The bridge
is filtered out of legacy metric maps. `ProgressionStore.record_run_result` also accepts an explicit run
state/outcome for pure callers.

Each first score stages `run_scored {total, lines, feats}` in the existing
progression analytics outbox under `<result_id>:run_scored`. The original
analytics run id and progression context are retained. Existing outbox delivery
appends local JSONL and acknowledges idempotently; a repeated terminal commit
does not create another event. Delivery may occur at the next existing outbox
reconciliation (including the next boot).

## Presentation and input

At 1920×1080 / 100% scale, the column starts at (1010, 82), is 780 px wide, and
uses a 560 px score ledger. It uses the approved Crumble UI/Text/Display assets
and shared palette, seeded titles and quips, current biome names (or section
title), existing turn-order portrait registry (including aliases and guardian paths), clipped to a 44 px circle, gilding, gold feat
diamonds, a Display 52 px total, NEW BEST, the approved Ember copy, and current
slab button treatments. The proportional UI font's existing digit glyphs are
centered in equal advances to provide tabular score values without another font.
`LastLightRecap`, `OutcomeKicker`, `OutcomeTitle`, `NewRunButton`, and
`MainMenuButton` ids remain. The Chronicle button is disabled with “Coming soon”.
Rise Again keeps primary focus and left/right navigation skips disabled Chronicle.

The recap attaches to `UiLayer/UiRoot`, which covers the full viewport, rather
than the inset StageRoot. The original coordinate assertion reads the correct
`OutcomeRecap` node and remains intact; layout is fixed to (1010,82), width 780.
Victory and withdrawal share the same full-viewport shade. Both hide the top-right
HUD using the existing terminal visibility flag.

Quip oblique uses the approved Text FontVariation with skew 0.2, at 24 px TEXT_2.
Titles retain their 0,3 drop shadow and add an 18 px glyph glow: violet #9a7cf0
for defeat, ember #e8893a otherwise, with 25% inner alpha. Nested glyph outlines
provide its soft falloff without another font or art asset. The gilded rule is a
9 px rotated gold square and a 1 px GOLD_DIM-to-transparent line over 560 px,
drawn in the column above the death shroud so defeat cannot darken it away.

The title fades over 0.3 s; copy appears 0.25 s after that fade; rows reveal every
0.11 s. The total eases out over 0.8 s, followed by the 1.25→1.0 NEW BEST pop over
0.25 s. Any pressed input, pointer movement, drag or deliberate stick movement
completes the presentation without also activating an action. Reduced motion
sets the whole screen and existing death shroud to their final state immediately.
Repeated identical models do not restart the reveal.

Row reveals and NEW BEST are silent; existing music and outcome stingers remain.
There is no row-reveal audio signal.

At nine or fewer rows the ledger is a single 560 px column. More than nine rows
use the full 780 px width: 380 px base column, 20 px gap, 380 px feat column.
Rows keep their UI 20 px label, Text 16 px detail and UI 22 px value. Details
truncate with an ellipsis and expose their full text in a tooltip. Detail width
is column width minus the label extent, value width and 12 px combined gaps.
Font minimum-size invalidation completes before the final detail bounds are
reapplied; rows also clip their contents. Values reserve their actual tabular
digit width. Headless checks and the probe verify the resulting rectangles in
both layouts to prevent overlap. No scrolling
is used; all ten possible feat rows fit at the approved row spacing.

Legacy fallbacks are director-approved: unknown killer uses “The Umbra took your
last breath.”; an enemy missing an intent uses “Felled by a <Enemy>, <N> damage.”;
an unnamed surface uses “The ground itself took your last breath.”; a trap
missing its element uses “A trap took your last breath.” An unnamed section omits
the biome segment; absent section data uses “Depth <global depth>”. Missing title
lists use SLAIN, ESCAPED or WITHDRAWN, the first approved title for that outcome;
a missing quip hides that line. Legacy recovery preserves the existing EMBERS
LOST amount and unchanged recovery-marker copy when section data is absent.
No design placeholders remain.

## Scene integration

`embrace_state(run_state, banked_progression)` prepares a scored WITHDRAWN
snapshot while preserving banked currency and recovery state. The scene adopts
it only after the existing profile save succeeds, then clears the resumable run,
finishes any existing Hearth feedback, releases the choice animation lock and
shows the recap. Withdrawal is included in terminal visibility and refresh
routing. Its legacy defeat flag `game_over` remains false, and the displayed
amount comes from held Embers. Rise Again and Main Menu retain their existing
signal/action paths; Chronicle is disabled. The scene change is within the
approved 20-line budget (19 changed lines). The score suite is registered in the
full suite, and the authorized Hearth assertion now checks WITHDRAWN while
retaining its banking, save-clearing and departure-cue checks.
No peer review, commit, publication or inspection fixture is performed here.

## Proof and chosen non-player defaults

For fix-02, `run_score_suite.gd` covers commit-only samples, combat save/resume,
paused/offline time, legacy combat-clock repair, terminal exclusions and Swift
against the cumulative saved total. `combat_feel_suite.gd` retains its complete
resolver-state/RNG equality assertion and also calls the score suite's live
clock checks against production physics, menus/settings, tree pause, visibility,
explicit save, resume and run end. This state-plumbing fix needs headless proof;
it changes no layout, assets, motion or input flow and needs no renderer capture
or inspection fixture.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-02 && python3 tools/godot_task_runner.py --task-id fix-02 --stream -- godot --headless --path . --script tests/combat_feel_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-02 && python3 tools/godot_task_runner.py --task-id fix-02 --stream -- godot --headless --path . --script tests/run_score_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-02 && python3 tools/godot_task_runner.py --task-id fix-02 --timeout 600 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The synthetic clock proof uses `CLOCK_START_USEC=1000000`,
`CLOCK_SAVED_SECONDS=120.5`, `CLOCK_ACTIVE_SECONDS=10.5`,
`CLOCK_PAUSED_SECONDS=90.0`, `CLOCK_RESUMED_SECONDS=7.25` and
`CLOCK_USEC_PER_SECOND=1000000`, with the existing persistence seed `512`.
`LIVE_CLOCK_PROOF_FRAMES=3` bounds each production-clock observation and
`LIVE_CLOCK_POOL_WARM_FRAME_BUDGET=120` bounds fixture teardown. These
values affect only tests; production scoring thresholds remain unchanged.

Focused headless suite:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-01 && python3 tools/godot_task_runner.py --task-id meta-01 --stream -- godot --headless --path . --script tests/run_score_test.gd
```

It covers counters, actual event choices, flawless Health-loss receipts,
summons, card boundaries, all six dragon totals, every feat and threshold,
599/600/1,199/1,200 Embers, 2,699/2,700/3,599/3,600 seconds, zero omission,
seeded copy, legacy records, replay, strict bests, JSONL retries, terminal bridge,
live pause clock, skip and reduced motion.

Full suite (600 s budget because the existing full suite's extensive cutout
checks exceeded the runner's 300 s default after successful startup):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-01 && python3 tools/godot_task_runner.py --task-id meta-01 --timeout 600 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The existing `tests/run_end_recap_tests.gd` remains outside the extended ownership
and is run unchanged. Its six obsolete UI expectations and two baseline
expectation failures are reported. Both baseline failures reproduce on
`codex/peer-benchmark` HEAD `21ed3604f`: the player uses the current protagonist
cutout rather than 16 death sprites, and section-map recovery stages 41 Embers at
(2, -1), mapped from the legacy coordinate (2, 0). The owned recap probe checks
the current cutout death clip/phase and mapped recovery room instead.

Windowed proof for the design owner (not run in this sandbox):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/run_end_recap_probe.gd --task-id meta-01 --expect-size 1920x1080 --proof-contract tests/run_end_recap_probe_contract.json --result-manifest output/meta-01/run_end_recap_proof.json
```

The runner reports its isolated `user://run_end_recap_probe_v9/1920x1080/`
capture directory. Thirteen captures include the existing death transition,
defeat stages/focus, reduced motion, the approved 567-point three-feat mockup,
a separate two-feat defeat, six-dragon victory, all-feat two-column overflow,
and WITHDRAWN via the production Embrace action. No PNG
is claimed as captured or visually verified here.

Non-player choices are named test seeds `COUNTER_RUN_SEED=6101`,
`EVENT_RUN_SEED=6111`, `PERSISTENCE_RUN_SEED=512`, the actual Hearth-board fixture's `EMBER_HEARTH_PROOF_SEED=8821`, the live-clock proof's
`CLOCK_PROOF_FRAMES=3`, `RECOVERY_PROOF_SEED=8822`,
`POOL_WARM_PROOF_FRAME_BUDGET=120` for fixture teardown, and the runner's 600 s
full-suite budget. Production
text, tuning and assets remain the design owner's values.
