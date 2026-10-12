# Movement undo

A free movement `move` order (including a route covering several tiles) can be
undone during the current hero activation only when its generic deep comparison
has no differences outside `MovementUndoRules.IGNORED_FIELDS`. A new field,
removed field, type change or nested difference fails closed. Ghost Stride,
Illusion/cover commands and card approach paths are not free walks.

The pure `last_player_movement.undo_report` from `apply_player_movement` adds
`reversible`, `changed_fields` and actual traversed `tiles`. It does not change
movement, costs, surfaces, traps, damage, relics, cards, RNG or the turn clock.
Tile visibility is derived from position rather than saved: the report compares
Umbra tile visibility and visible enemy ids at the endpoint and every tile of the resolved route. This also
prevents information leaks on paths with an intermediate reveal. Damage/status,
traps, pickups, enemy reactions, clock/RNG changes, death/reward/event streams and
all other unlisted combat differences commit the walk and preceding history.
Ordinary Electrified currently has no arrival rider; contact that does cause a
status, damage or event is committed. Rubble that changes only movement cost is
reversible.

## Allowlist

The executable allowlist is in `scripts/movement_undo_rules.gd`, with a one-line
reason on every exact path. Its fields are:

- `player.pos`, `player.facing`: walked position and facing.
- `player_movement_remaining`: free movement expenditure.
- `last_player_movement.resolved`, `.action_type`, `.origin`, `.target`,
  `.destination`, `.spent`, `.light_refunds`, `.remaining_before`,
  `.remaining_after`, `.capacity`, `.undo_report`: request/path/report metadata.
  Actual light refund flags/events and actual capacity are still compared.
- `last_action_target`, `last_action_target_actor`: resolver target cursors.
- `log`: bounded presentation lines, including the ordinary moved-to line.
- `damage_context.actor_kind`, `.actor_id`, `.card_id`, `.action_type`,
  `.player_card`, `.source_kind`: current-request provenance.
- `turn_flags.first_move_bonus_used`, `turn_flags.tiles_moved`: movement counters.
  Snapshots restore their prior eligibility and distance-dependent previews too.

No wildcard ignores exist. In particular, neither all of `turn_flags` nor all of
`last_player_movement` is ignored. Arrays compare length, order and nested values.

## History and commit boundaries

The HUD helper owns a stack of deep pre-walk combat snapshots, never a saved-state
field. A reversible walk adds one snapshot. A non-reversible walk clears the stack
and marks the last walk committed. Card resolution starts and activation handoff
clear history synchronously, before animation awaits; Pass, automatic turn end and
enemy actions use the same handoff. Selecting, aiming and cancelling cards preserve
history. A strict expected-state guard also clears on unrelated combat mutations,
activation/actor changes and load/room changes. A newly loaded scene has no history.
Several undos step back one walk each; restoring the entire snapshot preserves
state equality, absent fields and RNG exactly.

Undo updates the run's combat state and the ordinary committed save boundary,
invalidates derived caches, and refreshes the board, Pass forecast and Turn Clock.
The hero returns instantly to the old tile, with its existing cutout canvas fading
back over 0.12 seconds. Reduced motion returns instantly. Presentation alpha is
outside combat state.

Fade progress uses elapsed wall time and refreshes the currently drawn cutout
before rendering. Completion, history/load interruption, reduced-motion changes
and scene exit explicitly restore both hero facings to exactly `1.0` alpha. A
synchronous capture can stall the main thread; the next rendered frame completes
an expired fade rather than retaining its last partial alpha.

The button is a `UiRoot` overlay outside layout containers. It reads the movement
chip's rect without writing either resource chip's size or position. Showing and
hiding the button leave the dock unchanged; the dock after undo matches the
settled dock after the walk.

The initial room-to-combat dock shift predates undo. On base commit
`2c44a33e89e7f4f6a59d1faacdd9e19c68627aab`, `_sync_board_view_rect` tweens the
board's room offset to zero over 0.42 seconds. `_layout_combat_action_dock_content`
clamps the dock below the board's current rendered bottom. The probe's initial
hand/container settling does not await that separate board tween. The first walk
outlasts it, so the next dock layout moves up by the remaining board offset.
The director observed 59.90 px natively; the same 1920×1080 fixture with the base
RunScene and CombatEngine, with no undo button/report, reproduced a 24.14 px
shift headlessly (`y=802.2911` to `778.1534`, board `y=24.1376` to `0`). Its
hand bounds and resource sizes were unchanged. A second headless comparison
paused the existing tween at the director's remaining `59.896545` px offset,
then resumed it for the same walk: both base and current chips moved from
`y=838.0500` to `778.1534`, a matching `-59.89655` px. This is a debug timing
checkpoint, not a native renderer run. The sampled amount varies with elapsed
tween time. Undo preserves this existing framing behavior; proof compares
button visibility and undo against the settled post-walk rect, while retaining
the pre-walk rect as diagnostics.

## Inputs and feedback

Keyboard: `Z`, `Ctrl+Z`, `Cmd+Z`. Mouse: the compact `Undo move` button immediately
below the last movement chip, with the chip's width and a muted `Z` like Intents.
Its independent placement adds no reserved space or dock shift when hidden.
Controller: left trigger (`LT` on Xbox, `L2` on Steam Deck); combat previously had
no left-trigger binding (map trigger zoom remains modal). Held analog input is
latched so one press undoes one walk. The controller prompt is shown only while
undo is available. Guided tutorial hard gates, modals and committed animation/input
locks disable undo through every path.

Tooltip: “Take back your last move. Moves that revealed or triggered something
can't be undone.” An unavailable press after a non-reversible walk shows the
existing short floating text at the hero: “Can't undo — something changed.”
Other unavailable presses do nothing. Failed undo does not log analytics.

## Analytics

Successful undo appends `player_move_undone {tiles, activation_seq}` using the
existing combat context and analytics store. The existing ordinary `player_moved`
records remain in the append-only stream; undo never deletes historical events.
The ordinary movement record is the necessary exception to “no analytics event”:
otherwise the existing event emitted for every walk would prevent every undo.
Side-effect event streams in combat state remain part of the strict comparison.
See [analytics.md](analytics.md).

## Presentation values

The button is 34 px tall and sits 6 px below the movement chip, the chip's width. Undo plays the soft
menu-close cue (`RunSfxLibrary.MENU_CLOSE_ID`).

## Proof

The standalone suite runs rules, production movement/input/HUD/save/analytics
integration and commit-boundary checks. Retaliate currently reacts to attacks, not
walks; an enemy-reaction mutation is nevertheless a negative generic-diff witness.
The full Godot suite remains unchanged. All headless execution uses the task runner:

```sh
python3 tools/godot_task_runner.py --task-id itb-02 --stream -- godot --headless --path . --script tests/movement_undo_test.gd
python3 tools/godot_task_runner.py --task-id itb-02 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The design owner runs and inspects fresh real-renderer proof at 1920×1080, 100%
UI scale. The probe asserts button geometry, exact state restoration, blocked
notice, controller prompt/device glyph and reduced-motion behavior, and emits
named PNGs plus `semantic-proof.json` under `user://probes/movement_undo`.

The probe uses wall-clock checkpoints followed by a render boundary, rather than
timers that can consume an earlier part of a slow frame. Its printed/JSON
diagnostics include alpha, elapsed time, fade/coroutine activity, completion
reason, renderer/rig identities, and resource rects before showing and after
hiding undo, plus board rect/rendered bounds and board-centering activity. It
preserves the director's extra initial hand-layout settle, then compares the
shown and hidden overlay rects and the post-walk and post-undo dock rects. The
focused suite includes capture-stall, interruption and overlay-visibility
regressions. Run native proof with:

```sh
python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id itb-02 --expect-size 1920x1080 --proof-contract tests/movement_undo_probe_contract.json --result-manifest /private/tmp/labyrinth_codex/itb-02-proof/movement-undo-proof.json tests/movement_undo_probe.gd
```

The implementation engineer has no window-server access and does not run this
windowed proof. Fixture preparation, commit, peer review and publication belong
to the design owner under this unit's workflow split.
