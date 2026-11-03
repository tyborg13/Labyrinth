# fix-15 feedback 3 implementation handoff

Worktree: `/Users/borgerding/workspace/Labyrinth.worktrees/fix-15`.
Branch: `codex/fix-15`; unchanged HEAD: `bb42290fcb0cc10da8ce7865791d729fd8b382db`.
Risk tier: standard. Changes remain uncommitted. No Git writes, queue edits,
peer review, publication or windowed runs were performed.

## Acceptance criteria

1. Record an independent ordered journal at actual resolver operations, with
   each owner event's post-event type-preserving serialized state.
2. Compare owning playback steps one to one, in that execution order, with
   presented equal to resolved after every event. Keep the existing deliberate
   deferrals and an exception-free final comparison.
3. Reject reversed Fire/skip steps for Tether and Mimic, Freeze and Petrify;
   also reject an action swapped with its Retaliate reaction for both actors.
   Exercise the actual production animation, not just static payload arrays.
4. Preserve the 71-case matrix, earlier fixes, ordinary bytes and mutation guards;
   run focused proof only and report residual risks.

## Implementation

The resolver exposes an opt-in `_resolver_journal` observer. Calls surround the
real Fire contact, counter consumption, hit, Retaliate, illusion retort, Bleed,
movement, newborn arrival, surface-death and burst operations. The observer reads
no presentation trace or returned step list. A test-only recorder copies raw
post-event state and appends monotonically sequenced owner records. Preparation
is observed before the intent step is built; completion observes the resolver's
returned state. Warband retreat payments are observed outside the normal action
wrapper as well. Preview copies are excluded by live-state identity. Whether
Bleed stopped an action is computed from resolver inputs and resulting state,
without consulting the presentation context's stop flag.

The journal retains every raw changed interval. A normalized event sequence
coalesces only adjacent intervals of the same owner across no-op children, and
an uninterrupted unpaid walk into its single embedded move. Interrupted or
Bleed-paid walks retain each arrival interval. No presented snapshot, returned
step index, trace field or candidate state membership selects journal events.
Each observed owning step is compared directly to the same ordinal in the
independent journal: owner kind/actor, exact post-event state and total count.
Missing, extra, duplicate or reordered owning steps fail. The previous unordered
membership checks, end-owner collector and presentation-derived index correlation
were removed. Original snapshot-content guards remain as additional checks.

The full matrix remains **71 cases x three APIs = 213 resolutions**. Actual
production playback covers **38 Tether + 33 Mimic = 71 cases**. Observer metadata
and journals remain outside combat state, saved data and analytics. Default
engines have no observer and preserve their presentation payloads.

## Explicit intermediate allow-list

Unchanged. No actor roster, position, HP, status, charge or other gameplay board
field is excluded. The final comparison excludes nothing.

| Field | Reason |
| --- | --- |
| `damage_context` | The enclosing hit/death scope restores its caller's cause after owner capture. |
| `_surface_damage_batch` | The enclosing compound hit closes its synchronous damage batch after owner capture. |
| `_surface_pending_deaths` | The death flush drains this private queue after the causing hit is captured. |
| `_death_burst_queue` | The enclosing FIFO drains queued bursts after owner capture. |
| `_death_burst_running` | The enclosing FIFO clears its reentrancy guard after owner capture. |
| `death_burst_events` | The legacy burst journal is applied after explicit traced burst feedback to prevent replay. |
| `enemies[].death_burst_resolved` | The FIFO's per-enemy reentrancy guard is published after burst resolution, at turn cleanup. |



## Verification and changed files


- `scripts/board_attack_rules.gd`
- `scripts/combat_engine.gd`
- `scripts/enemy_mechanics/death_burst.gd`
- `scripts/enemy_mechanics/mimic.gd`
- `scripts/illusion_card_rules.gd`
- `scripts/retaliate_rules.gd`
- `spec/analytics.md`
- `tests/fix_14_matrix_test.gd`
- `tests/fix_15_implementation.md`
- `tests/fix_15_mutations.py`
- `tests/helpers/fix_15_ordered_journal.gd`
- `tests/helpers/fix_15_ordered_journal.gd.uid`
- `tests/helpers/fix_15_resolver_recorder.gd`
- `tests/helpers/fix_15_state_invariant.gd`
- `tests/suites/fix_14_suite.gd`

All runtime additions are optional resolver observation calls; the journal and
comparison live in small test helpers. Existing supplied fixtures and golden
values were not changed. No gameplay rule, tuning, save format, analytics
payload, node identity, input path, art, font, audio or UI text was changed.

## Focused verification

All normal Godot invocations used `python3 tools/godot_task_runner.py --task-id
fix-15 --stream -- godot --headless --path . --script <program>`. Matrix playback
shards used the existing known-workload `--timeout 600`, with `--actor=tether` or
`--actor=mimic`. The static matrix used `--check-only`; the headless contract used
`tests/fix_12_probe.gd -- --check-only`. All final normal runs exited zero with no
script errors. Logs below are in `/private/tmp/labyrinth_codex/`.

| Check | Exact result line(s) | Log |
| --- | --- | --- |
| Full static matrix | `FIX-14 MATRIX TEST RESULT: PASS (20854 checks, 0 failures)` | `fix-15-f3-matrix-static.log` |
| 38 Tether production playbacks | `FIX-14 MATRIX TEST RESULT: PASS (23021 checks, 0 failures)` | `fix-15-f3-matrix-tether.log` |
| 33 Mimic production playbacks | `FIX-14 MATRIX TEST RESULT: PASS (22538 checks, 0 failures)` | `fix-15-f3-matrix-mimic.log` |
| fix-12 | `FIX-12 TEST RESULT: PASS (2134 checks, 0 failures)` | `fix-15-f3-fix12.log` |
| fix-14, including ordinary byte goldens | `FIX-14 TEST RESULT: PASS (2539 checks, 0 failures)` | `fix-15-f3-fix14.log` |
| Headless probe contract | `FIX-12 PROBE CONTRACT: PASS (24025 checks; 1920x1080, UI scale 100%)` | `fix-15-f3-probe-contract.log` |
| EN01 | `EN01 ENEMIES TEST RESULT: PASS` | `fix-15-f3-en01.log` |
| EN03 | `EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)` | `fix-15-f3-en03.log` |
| EN06 | `EN06 ENEMIES TEST RESULT: PASS (178 checks, 0 failures)` | `fix-15-f3-en06.log` |
| Godot sidecars | `Ran 19 tests in 1.864s`<br>`OK` | `fix-15-f3-sidecars.log` |
| Registration audit | `TEST REGISTRATION AUDIT: PASS (834 scripts; full suite=480, quarantined=29, windowed probe=325)` | `fix-15-f3-registration.log` |

Candidate sidecars were also checked with both tracked and untracked files:
`CANDIDATE GODOT SIDECARS: PASS (tracked and untracked candidate files)`.
`git diff --check` passed. No editor scan or temporary global-class cache was
used. Existing macOS certificate, EN03 dummy-texture and shutdown-resource
messages remain visible in logs. The initial journal missed retreat Bleed
outside the normal action wrapper; its first state-only run failed 22 checks.
The recorder was corrected, and the complete final runs above pass. Earlier
preliminary playback logs were retained separately and are not counted above.

## Mutation proof

```bash
python3 tests/fix_15_mutations.py --output-dir /private/tmp/labyrinth_codex/fix-15-f3-mutations
python3 tests/fix_14_mutations.py --include-fix-12 --task-id fix-15 --output-dir /private/tmp/labyrinth_codex/fix-15-f3-legacy-mutations
```

`FIX-15 MUTATION RESULT: 24/24 caught; all source files restored`

`FIX-14 MUTATION RESULT: 29/29 caught; all source files restored`

**`FIX-15 FEEDBACK 3 MUTATION RESULT: 53/53 caught; all source files restored`**

Combined machine-readable table:
`/private/tmp/labyrinth_codex/fix-15-f3-mutation-results.json`.
All 51 prior caught guards, the Fire/skip survivor and the second order mutation
are caught. Each requires its expected assertion, exit 1, no script errors and
byte-exact source restoration. Order guards additionally require actual
production playback to reject the reorder for both actors; Fire/skip covers
both Freeze and Petrify (four playbacks), and action/reaction covers two.
The matrix selector accepts a comma-separated case list to run those groups.
The mutation runner's optional `--only` can select guards; the default runs all
24 current guards, with the two order challenges first.

| Mutation | Outcome | Exact mutant result (expected FAIL) |
| --- | --- | --- |
| `reverse_fire_and_skip` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6986 checks, 64 failures)` |
| `swap_reaction_with_action` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6932 checks, 192 failures)` |
| `drop_history` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (15582 checks, 927 failures)` |
| `drop_revision` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (15588 checks, 1083 failures)` |
| `drop_history_and_revision` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (15588 checks, 1216 failures)` |
| `drop_board_player` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1577 checks, 653 failures)` |
| `drop_board_enemies` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1553 checks, 671 failures)` |
| `drop_board_illusions` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1571 checks, 635 failures)` |
| `drop_board_surfaces` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1571 checks, 635 failures)` |
| `drop_board_traps` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1571 checks, 635 failures)` |
| `drop_board_terrain` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1571 checks, 635 failures)` |
| `drop_board_loot` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1571 checks, 635 failures)` |
| `drop_spawn_only_state` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6210 checks, 442 failures)` |
| `stale_freeze_counter` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1586 checks, 641 failures)` |
| `serialize_position_type_collision` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1784 checks, 639 failures)` |
| `intermediate_position_type_collision` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (1784 checks, 639 failures)` |
| `terminal_position_type_collision` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6614 checks, 428 failures)` |
| `drop_consumed_skip_snapshot` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6741 checks, 36 failures)` |
| `drop_terminal_completion` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (5762 checks, 426 failures)` |
| `late_newborn_arrival_capture` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6771 checks, 36 failures)` |
| `drop_newborn_arrival_losses` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6831 checks, 12 failures)` |
| `legacy_snapshot_add_illusions` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1999 checks, 1 failures)` |
| `reverse_presented_roster` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (2052 checks, 585 failures)` |
| `drop_nested_illusion_link` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (6756 checks, 9 failures)` |
| `before_to_after_losses` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 49 failures)` |
| `mimic_before_to_after_losses` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 35 failures)` |
| `tether_remove_cancel_guard` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 1 failures)` |
| `mimic_remove_footprint_guard` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 1 failures)` |
| `analytics_drop_movement` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1110 checks, 52 failures)` |
| `analytics_drop_identity` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 10 failures)` |
| `analytics_reverse_order` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 30 failures)` |
| `tether_drop_friendly_fire_losses` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1171 checks, 17 failures)` |
| `tether_restore_final_hp_cancellation` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1166 checks, 28 failures)` |
| `tether_do_not_subtract_reactions` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 48 failures)` |
| `tether_do_not_defer_reaction_snapshot` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1168 checks, 30 failures)` |
| `mimic_do_not_defer_reaction_snapshot` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 20 failures)` |
| `tether_drop_all_reacting_unit_losses` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 4 failures)` |
| `drop_cascade_step` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1739 checks, 56 failures)` |
| `bundle_tail_into_beam` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1763 checks, 38 failures)` |
| `late_arrival_capture` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1563 checks, 82 failures)` |
| `untraced_status_fields` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1999 checks, 2 failures)` |
| `restart_burst_continuation` | Caught; restored | `FIX-14 TEST RESULT: FAIL (2539 checks, 2 failures)` |
| `final_reaction_snapshot` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1176 checks, 12 failures)` |
| `drop_mimic_reaction_collateral` | Caught; restored | `FIX-12 TEST RESULT: FAIL (1172 checks, 16 failures)` |
| `disable_burst_coalescing` | Caught; restored | `FIX-14 TEST RESULT: FAIL (2167 checks, 13 failures)` |
| `overwrite_inherited_trace` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1647 checks, 37 failures)` |
| `hoist_attack_bleed_before_arrival` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1999 checks, 63 failures)` |
| `omit_attack_bleed_baseline` | Caught; restored | `FIX-14 TEST RESULT: FAIL (1999 checks, 9 failures)` |
| `tether_omit_lethal_bleed_action_guard` | Caught; restored | `FIX-14 TEST RESULT: FAIL (2053 checks, 6 failures)` |
| `mimic_omit_lethal_bleed_action_guard` | Caught; restored | `FIX-14 TEST RESULT: FAIL (2020 checks, 3 failures)` |
| `capture_owner_after_flush` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (14941 checks, 1067 failures)` |
| `omit_mimic_reflection_hook` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (20392 checks, 30 failures)` |
| `omit_mimic_contact_defeat` | Caught; restored | `FIX-14 MATRIX TEST RESULT: FAIL (20912 checks, 2 failures)` |

## Proof for the design owner

No windowed run was attempted: this worker has no window-server access. The
existing 1920x1080, 100% UI scale native capture command is:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-15 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id fix-15 --timeout 180 --expect-size 1920x1080 --proof-contract tests/fix_12_proof.json --result-manifest /private/tmp/labyrinth_codex/fix-15-f3-visual-proof.json tests/fix_12_probe.gd
```

Expected PNGs: `user://probes/fix-12/` inside the runner's isolated home, with
names listed in `tests/fix_12_proof.json`. No PNGs or native visual manifest were
produced here. The headless contract proves semantics, not pixel appearance.
The design owner retains inspection-fixture preparation, commit, peer review,
joint full-suite execution and publication.

## TODO_DESIGN and chosen defaults

- `TODO_DESIGN`: none. No perceivable values or presentation design were chosen.
- Chosen defaults: monotonic journal sequence/token integers, live-state identity
  filtering and named test-only owner kinds identify raw resolver events. No
  gameplay values were chosen. Existing test-only 20-second playback deadlines
  remain unchanged; comma-separated case selection is a test harness option.

## Residual risks

- The proof covers the 71-case traced matrix and the six corrupted-order
  playbacks, not all possible gameplay states. Future owner operations must add
  raw resolver boundaries and fixtures; missing instrumentation in an untested
  mechanic remains a risk. No arbitrary snapshot membership or trace-derived
  ordering is used as evidence.
- The only state exceptions remain the seven explicitly documented intermediate
  scope/history fields above. Final equality has no exceptions.
- Windowed appearance and native Windows execution were not verified here. The
  director's joint full suite remains outstanding, per the focused-only request.
- Default-off observer-call overhead was not profiled. Ordinary payload bytes
  and focused semantics pass; this handoff makes no performance claim.
- No known unmutated functional or assertion failure remains in the final checks.
  All changes remain uncommitted at the original branch and HEAD.
