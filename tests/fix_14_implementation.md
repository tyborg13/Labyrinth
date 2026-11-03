# fix-14 final-round implementation handoff

Feedback base: `3e3e11bbcb9d3295bc5f165bbc22b6d23910309d`.
Worktree `/Users/borgerding/workspace/Labyrinth.worktrees/fix-14`, branch
`codex/fix-14`. All changes remain uncommitted. No commits, pushes, branch or
queue changes, peer review, full project suite or windowed run were performed.

## Requirement 1 — one immediate capture rule

`ReactionPresentationTrace.capture_owner` is the one function that creates an
owner's board, realized per-unit losses and event boundary. Action, each
Retaliate/illusion retort, movement/arrival, charge and cascade paths call it.
The death flush seals the current owner before draining its pending deaths.
Nested death hooks/bursts seal their parent and resume from the child's final
cursor, so a parent cannot absorb or replay its child's losses.

Move/attack Bleed now enters that owner stack before damage is charged. Its
immediate payment is followed by its surface-death and burst entries, before
movement or attack resumes. Activation-start Fire and Warband retreat Bleed
use the same charge scope. Payment headers discard the legacy post-flush board,
loss, event and impact-victim payloads; the emitted fields come from their
immediate capture. Lethal charges/cascades stop the actor's later action.

The matrix exposed two missing Mimic integrations. Copied hits now invoke the
existing authored illusion-reaction hook, in the same order as other enemy
attacks. Their payload includes immediate collateral enemy losses. The shared
contact adapter holds and completes defeats for `en06_after` steps; its other
mechanics' paths are unchanged. Damage, reflection, burst, motion, popup and cue
values are reused from existing rules/assets. No copied keyword/surface rider
or new tuning was added.

## Requirement 2 — strict generated matrix

The required cross product contains 36 cases. Every cell below contains both
Tether and Mimic, with a static check through single-turn, committed single-turn
and full-phase APIs, plus production playback of each case.

| Owner | No death | Lethal owner + cascade | Cascade kills hero / ends combat |
| --- | --- | --- | --- |
| Arrival trap | both actors pass | both actors pass | both actors pass |
| Move Bleed | both actors pass | both actors pass | both actors pass |
| Attack Bleed | both actors pass | both actors pass | both actors pass |
| Beam / copied action | both actors pass | both actors pass | both actors pass |
| Retaliate | both actors pass | both actors pass | both actors pass |
| Reflection | both actors pass | both actors pass | both actors pass |

Seven separately named reviewer cases retain the supplied move-payment,
stationary attack-payment and leader-collapse reproductions, including the
Mimic's actual Tick ID 2. Six activation-Fire cases add the same three outcomes
for both actors. Two lethal Warband-retreat cases cover the other move payment.
Total: **51 fixtures, 153 distinct static API/mode combinations, 51 actual playbacks**.
No matrix case remains unsupported.

Each case checks whole-turn HP/Block/Stoneskin popup and analytics totals,
ordered immediate snapshots, no resurrection, a single defeat/fade on the
fixture's specified owner, and exact actual ring/cue starts without ID
deduplication. Charges additionally check that impact victims match only their
own loss arrays. Illusion fades are observed at the applied board boundary;
enemy/hero defeats are observed at the actual shared defeat playback boundary.

Generated full-phase fixtures give non-acting partners/Ticks a named test idle
intent, isolating the requested actor from unrelated ordinary-turn legacy
payloads. The seven supplied reproductions retain their original supported
geometry and action setup. A copied-action lethal fixture uses the existing
illusion-shatter relic to kill a Tick when the copied hit kills an illusion;
it does not add enemy friendly fire to Mimic's copied attack.

## Ordinary compatibility and previous acceptance

The original cascade, arrival, Bleed placement, intermediate reaction and
once-only continuation cases remain covered. The original hero-loss fixture
still presents `-4, -3`, with hero and Thrall defeats on their lethal bursts.

Ordinary Warden/Tick turns, both without and with Retaliate, compare exact
serialized resolution steps, surface events, action/status analytics, actual
popups, defeat owners, burst starts and displayed HP against the reviewer's
`23b4f251f` base output. The supplied values were copied without alteration;
serialized strings preserve the base's integer/float representation. The
existing analytics-only golden fixture is unchanged. The ordinary legacy
presentation gap remains intentionally unchanged and is not asserted correct.

## Files changed this round

- `scripts/reaction_presentation_trace.gd`: one owner capture, charge scope,
  owner sealing and pre-flush cursor behavior.
- `scripts/combat_engine.gd`: seal at flush entry; traced activation Fire and
  retreat payments; select the cascade's own status identity.
- `scripts/board_attack_rules.gd`, `scripts/retaliate_rules.gd`,
  `scripts/illusion_card_rules.gd`: route owner snapshots/losses through the
  common capture function while preserving untraced event payloads.
- `scripts/enemy_mechanics/reaction_loss_ownership.gd`: ordered charge/cascade
  conversion, immediate charge fields and scoped intent detection.
- `scripts/enemy_mechanics/mimic.gd`: shared action capture, existing illusion
  reactions, and immediate collateral-loss payloads.
- `scripts/enemy_mechanics/traced_bleed_view.gd`, `scripts/run_scene.gd`:
  reuse the status adapter for traced charges, including activation Fire.
- `scripts/maquette_cutout_runtime/contact_actions.gd`: Mimic-only held defeat
  completion, retaining other mechanics' existing playback.
- `spec/analytics.md`: common pre-flush rule, charge ordering and activation Fire.
- `tests/suites/fix_14_owner_matrix_cases.gd`,
  `tests/suites/fix_14_owner_matrix.gd`, `tests/fix_14_matrix_test.gd`, and their
  UID sidecars: fixtures, strict matrix checks and playback selection.
- `tests/helpers/fix_14_legacy_compatibility.gd` and its UID,
  `tests/fixtures/fix_14_legacy_presentation.json`: supplied base resolution
  and playback byte comparisons. Golden values are protected expectations.
- `tests/helpers/fix_12_playback_scene.gd`: actual illusion fade ownership and
  explicit action/charge phases.
- `tests/suites/fix_14_suite.gd`, `tests/fix_14_test.gd`: matrix playback reuse,
  fixture-appropriate checks and both ordinary compatibility modes.
- `tests/fix_12_test.gd`, `tests/fix_12_probe.gd`,
  `tests/fix_12_proof.json`: payment-cascade capture and headless matrix contract.
- `tests/fix_12_mutations.py`, `tests/fix_14_mutations.py`: preserve adopted
  guards, add class/adapter mutations and the review's three extra guards.
- `tests/headless_test_programs.json`, `tests/test_program_suite_runner.py`:
  append the matrix program last, with matching `POST_SNARE_PROGRAMS` entry.
- `tests/fix_14_implementation.md`: this handoff.

## Verification and evidence

All Godot commands use `tools/godot_task_runner.py --task-id fix-14 --stream`.
No editor scan was used. Matrix playback was split by actor using test-only
arguments, with a 600-second runner cap for the known 25/26-case sequences.
Other focused programs use the normal runner cap. Logs live in
`/private/tmp/labyrinth_codex/`.

| Program/check | Exact observed result | Log |
| --- | --- | --- |
| `tests/fix_14_matrix_test.gd -- --check-only (restored)` | `FIX-14 MATRIX TEST RESULT: PASS (7237 checks, 0 failures)` | `fix-14-f3-matrix-restored.log` |
| `tests/fix_14_matrix_test.gd -- --actor=tether` | `FIX-14 MATRIX TEST RESULT: PASS (8098 checks, 0 failures)` | `fix-14-f3-matrix-tether-verified.log` |
| `tests/fix_14_matrix_test.gd -- --actor=mimic` | `FIX-14 MATRIX TEST RESULT: PASS (7947 checks, 0 failures)` | `fix-14-f3-matrix-mimic-verified.log` |
| `tests/fix_14_test.gd` | `FIX-14 TEST RESULT: PASS (2112 checks, 0 failures)` | `fix-14-f3-fix14-final.log` |
| `tests/fix_12_test.gd (restored)` | `FIX-12 TEST RESULT: PASS (1714 checks, 0 failures)` | `fix-14-f3-fix12-restored.log` |
| `tests/fix_12_probe.gd -- --check-only (restored)` | `FIX-12 PROBE CONTRACT: PASS (9844 checks; 1920x1080, UI scale 100%)` | `fix-14-f3-contract-restored.log` |
| `tests/fix_14_test.gd -- --legacy-only` | `FIX-14 TEST RESULT: PASS (7 checks, 0 failures)` | `fix-14-f3-legacy-bytes.log` |
| `tests/fix_11_test.gd` | `FIX-11 TEST RESULT: PASS (162 checks, 0 failures)` | `fix-14-f3-fix11.log` |
| `tests/en03_enemies_test.gd` | `EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)` | `fix-14-f3-en03.log` |
| `tests/en06_enemies_test.gd` | `EN06 ENEMIES TEST RESULT: PASS (178 checks, 0 failures)` | `fix-14-f3-en06.log` |
| `tests/enemy_no_action_test.gd` | `ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)` | `fix-14-f3-no-action.log` |
| `tests/en01_enemies_test.gd` | `EN01 ENEMIES TEST RESULT: PASS` | `fix-14-f3-en01.log` |
| `tests/ember_hearth_test.gd` | `TEST RESULT: PASS Ember Hearth lifecycle` | `fix-14-f3-ember-hearth.log` |
| `tests/ember_reward_feedback_test.gd` | `EMBER REWARD FEEDBACK TEST RESULT: PASS` | `fix-14-f3-ember-reward.log` |
| `tests/warband_test.gd` | `Warband suite: 0 failures` | `fix-14-f3-warband.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests in 2.723s` / `OK` | `fix-14-f3-ui-restored.log` |
| `python3 tests/test_godot_sidecars.py` | `Ran 19 tests in 1.501s` / `OK` | `fix-14-f3-sidecars-restored.log` |
| `python3 tests/test_program_suite_runner.py` | `Ran 28 tests in 19.638s` / `OK` | `fix-14-f3-program-runner.log` |
| `python3 tools/test_registration_audit.py` | `TEST REGISTRATION AUDIT: PASS (834 scripts; full suite=480, quarantined=29, windowed probe=325)` | `fix-14-f3-registration-restored.log` |
| `git diff --check` | exit 0 | terminal |

The two actor runs contain 26 Tether and 25 Mimic production cases. The coverage
inventory verifies all 36 required combinations and all 15 extra/named cases:
`/private/tmp/labyrinth_codex/fix-14-f3-matrix-coverage.json`.
After the frozen-source mutation matrix restored all files, fix-12 playback,
the static matrix and the headless proof contract passed again.

Exact matrix playback commands:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-14 && python3 tools/godot_task_runner.py --task-id fix-14 --timeout 600 --stream -- godot --headless --path . --script tests/fix_14_matrix_test.gd -- --actor=tether
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-14 && python3 tools/godot_task_runner.py --task-id fix-14 --timeout 600 --stream -- godot --headless --path . --script tests/fix_14_matrix_test.gd -- --actor=mimic
```

Representative actual payment-cascade observations:

```text
FIX-14 MATRIX PLAYBACK: review_payment_move_tether_terminal; expected defeats={ "enemy_3": "surface_death", "enemy_1": "bleed_move", "player": "death_burst" } actual=[{ "key": "enemy_1", "phase": "bleed_move" }, { "key": "enemy_3", "phase": "surface_death" }, { "key": "player", "phase": "death_burst" }]; rings=[3] cues=[3]
FIX-14 MATRIX PLAYBACK: review_payment_move_mimic_terminal; expected defeats={ "enemy_1": "bleed_move", "player": "death_burst", "enemy_2": "surface_death" } actual=[{ "key": "enemy_1", "phase": "bleed_move" }, { "key": "enemy_2", "phase": "surface_death" }, { "key": "player", "phase": "death_burst" }]; rings=[2] cues=[2]
```


Development runs exposed the missing reflection and contact-defeat integrations;
those strict assertions were retained and the integrations were completed.
Fixture setup errors (Rite cache identities and required Warband fields), a
misapplied old fixture-specific Bleed helper, and golden-number serialization
were corrected without weakening the matrix's expected owners or totals.
Final passing runs contain no script errors. Existing certificate,
dummy-renderer texture and shutdown RID/ObjectDB diagnostics remain visible;
no real-renderer appearance result is claimed.

## Requirement 3 — mutation table

The matrix must reject capturing an owner after deaths flush. The mutation
flushes with capture disabled before the shared function records that owner.
The previous 26 guards remain, plus the required class mutation and two guards
for the Mimic integrations. Caught requires exit 1, the specific expected
assertion, a failure summary, no script error and byte-exact source restoration.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-14 && PYTHONPYCACHEPREFIX=/private/tmp/labyrinth_codex/fix-14-f3-pycache python3 tests/fix_14_mutations.py --include-fix-12 --output-dir /private/tmp/labyrinth_codex/fix-14-f3-mutations-final
```

```text
FIX-14 MUTATION RESULT: 29/29 caught; all source files restored
```

| Mutation | Result | Exact child assertion summary |
| --- | --- | --- |
| `before_to_after_losses` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 49 failures)` |
| `mimic_before_to_after_losses` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 35 failures)` |
| `tether_remove_cancel_guard` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 1 failures)` |
| `mimic_remove_footprint_guard` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 1 failures)` |
| `analytics_drop_movement` | CAUGHT | `FIX-12 TEST RESULT: FAIL (882 checks, 52 failures)` |
| `analytics_drop_identity` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 10 failures)` |
| `analytics_reverse_order` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 30 failures)` |
| `tether_drop_friendly_fire_losses` | CAUGHT | `FIX-12 TEST RESULT: FAIL (943 checks, 17 failures)` |
| `tether_restore_final_hp_cancellation` | CAUGHT | `FIX-12 TEST RESULT: FAIL (938 checks, 28 failures)` |
| `tether_do_not_subtract_reactions` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 48 failures)` |
| `tether_do_not_defer_reaction_snapshot` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 30 failures)` |
| `mimic_do_not_defer_reaction_snapshot` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 20 failures)` |
| `tether_drop_all_reacting_unit_losses` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 4 failures)` |
| `drop_cascade_step` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1432 checks, 56 failures)` |
| `bundle_tail_into_beam` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1456 checks, 38 failures)` |
| `late_arrival_capture` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1322 checks, 82 failures)` |
| `untraced_status_fields` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1662 checks, 2 failures)` |
| `restart_burst_continuation` | CAUGHT | `FIX-14 TEST RESULT: FAIL (2112 checks, 2 failures)` |
| `final_reaction_snapshot` | CAUGHT | `FIX-12 TEST RESULT: FAIL (948 checks, 12 failures)` |
| `drop_mimic_reaction_collateral` | CAUGHT | `FIX-12 TEST RESULT: FAIL (944 checks, 16 failures)` |
| `disable_burst_coalescing` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1746 checks, 4 failures)` |
| `overwrite_inherited_trace` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1436 checks, 37 failures)` |
| `hoist_attack_bleed_before_arrival` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1662 checks, 63 failures)` |
| `omit_attack_bleed_baseline` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1662 checks, 9 failures)` |
| `tether_omit_lethal_bleed_action_guard` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1716 checks, 6 failures)` |
| `mimic_omit_lethal_bleed_action_guard` | CAUGHT | `FIX-14 TEST RESULT: FAIL (1683 checks, 3 failures)` |
| `capture_owner_after_flush` | CAUGHT | `FIX-14 MATRIX TEST RESULT: FAIL (5857 checks, 318 failures)` |
| `omit_mimic_reflection_hook` | CAUGHT | `FIX-14 MATRIX TEST RESULT: FAIL (7039 checks, 30 failures)` |
| `omit_mimic_contact_defeat` | CAUGHT | `FIX-14 MATRIX TEST RESULT: FAIL (7275 checks, 2 failures)` |

Machine-readable evidence: `/private/tmp/labyrinth_codex/fix-14-f3-mutations-final/mutation-results.json`.
The final class mutation fails **318 matrix assertions**. Driver log:
`/private/tmp/labyrinth_codex/fix-14-f3-mutations-final.log`; individual child logs
are beside the JSON. Each original source byte sequence was restored before
the next mutation. Restored-source matrix/probe checks were run again afterward.


## Proof for the design owner

This sandbox has no macOS window-server access. No windowed run or retry was
attempted. The probe now requires eight 1920×1080 captures at 100% UI scale,
including a live hero popup and Tick ring after lethal Bleed and its death reward.

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/fix-14 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --task-id fix-14 --timeout 60 --expect-size 1920x1080 --proof-contract tests/fix_12_proof.json --result-manifest /private/tmp/labyrinth_codex/fix-14-feedback3-visual-manifest.json tests/fix_12_probe.gd
```

Expected directory: `user://probes/fix-12/` in the runner's isolated home.
New capture: `payment_cascade_burst_1920x1080.png`. Existing required captures:
`cancelled_arrival_1920x1080.png`, `firing_arrival_1920x1080.png`,
`firing_beam_1920x1080.png`, `mimic_attack_1920x1080.png`,
`cascade_burst_1920x1080.png`, `arrival_cascade_burst_1920x1080.png`, and
`bleed_attack_1920x1080.png`. No PNG or visual manifest was produced here.
The design owner owns the inspection fixture; this brief requests no new
`inspection_fixture.py` command.

## TODO_DESIGN placeholders

None. No new player-facing art, wording, icons, audio or tuning was chosen.

## Chosen defaults

Only test/debug choices: named fixture coordinates/IDs, healthy HP 30, charge 2,
reward/shatter damage 1, expected existing burst 4, idle test intents, and a
single-captain Warband with command radius/bonus 0 and retreat trigger/step 1.
Its debug break line is `RETREAT_BREAK_LINE`; the captain name comes from data.
The copied test card is existing `whirlwind_slash`. Matrix case timeout is the
named 20-second constant; runner cap is 600 seconds for the actor playback
shards. Test-only actor/case filters and proof prefix `payment_cascade` select
repeatable evidence. All production motion, timing, effects and cues reuse
existing behavior.

## Open issues

- Owner real-renderer proof and inspection remain unrun here.
- The ordinary Warden/Tick legacy presentation gap is unchanged and out of scope.
- Native Windows was not available; new typed-array assignments use typed
  helpers/temporaries. No full project suite was run, as requested.
