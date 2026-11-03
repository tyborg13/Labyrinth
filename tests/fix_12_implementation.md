# fix-12 implementation handoff — feedback 3

Worktree `/Users/borgerding/workspace/Labyrinth.worktrees/fix-12`, branch
`codex/fix-12`, starting HEAD `92caabc2009fb486a17f40b92d21bd54ce715108`.
All feedback-3 changes remain uncommitted. The owner handles commits, separate
review, renderer inspection, fixtures, full suites at merge, and publication.
No peer review, windowed run, full suite, or Git mutation ran in this round.
A retry of `python3 tools/parallel_task.py preflight` could not create the shared
Git directory's `index.lock` (`Operation not permitted`); the task was already
prepared and preflighted by the design owner.

## Files changed this round

- `scripts/reaction_presentation_trace.gd` and its UID: opt-in transient board
  snapshots and realized actor/enemy/terrain losses at reaction boundaries.
- `scripts/battlefield_rules/hit.gd`, `scripts/board_attack_rules.gd`: pass the
  optional trace through the shared resolver and capture the action boundary
  before Retaliate and each illusion retort, in resolution order.
- `scripts/retaliate_rules.gd`, `scripts/illusion_card_rules.gd`: capture each
  reaction's intermediate board and all of its realized victims. Surface events
  gain additive loss arrays; snapshots are never serialized into those events.
- `scripts/enemy_mechanics/tether.gd`, `scripts/enemy_mechanics/mimic.gd`: use
  the captured action board instead of reconstructing it from final actor HP.
- `scripts/enemy_mechanics/reaction_loss_ownership.gd`: subtract exact reaction
  enemy losses while preserving attack-owned damage on the same unit; attach
  intermediate reaction boards and complete per-victim payloads to the existing
  status steps. Untraced mechanics retain their existing presentation payloads.
- `scripts/combat_engine.gd`: use that focused helper at both enemy action
  presentation entry points.
- `scripts/run_scene.gd`: apply `reaction_after`, present its complete loss
  arrays with existing popup helpers, and add loss arrays to status analytics.
- `spec/analytics.md`: document transient boards and additive reaction losses.
- `tests/suites/fix_12_reactions_suite.gd`: the four new review fixtures,
  intermediate HP/owner assertions, both commit modes, and collateral analytics.
- `tests/helpers/fix_12_playback_scene.gd`: observe applied HP transitions and
  the phase owning each defeat at production presentation boundaries.
- `tests/fix_12_test.gd`: named mutation-check argument; normal runs retain all
  17 production playback cases.
- `tests/fix_12_mutations.py`: all 13 adopted mutations, with byte-exact source
  restoration and explicit expected assertion failures.
- This handoff. Existing probe and proof-contract files remain valid.

## Numbered acceptance criteria

1. **Feedback 3: intermediate snapshots.** Arrival is still presented by the
   ordinary move. The action applies its actual pre-reaction board, then each
   reaction applies its own captured board, sorted by surface-event sequence.
   The HP-6 review fixture shows `6 -> 5` on arrival, `5 -> 3` on Retaliate,
   and `3 -> 0` on reflection. Static checks cover both commit modes. Production
   playback checks both transitions and observes exactly one defeat, owned by
   `illusion_retort`.
2. **Feedback 3: Mimic collateral.** Stationary and approaching Quick Stab
   fixtures reproduce Retaliate Push into a crawler. Both present its actual
   `10 -> 8` injury as one `-2` popup on Retaliate, alongside the attacker's
   own damage. Surface-event and status-tick analytics contain the crawler's
   realized loss. The shared popup-total helper checks HP, Block and Stoneskin
   for every unit in every fix-12 playback case.
3. **Feedback 3: mixed ownership on one reacting unit.** The reviewed Air-trap
   fixture retains arrival 1, beam-owned collision 2, and Retaliate 2 on the
   Thrall. The beam's loss payload must retain its 2 even though that same
   unit also reacts. Deleting all attack-owned losses on reacting units is
   included in the mutation set.
4. **Original brief / feedback 1–2 preserved.** Tether and Mimic use post-move
   action boundaries; cancelled actions have empty losses. Tether cancellation
   still reads its pre-reaction `beam_resolved` marker, so lethal Retaliate or
   reflection cannot erase a real hit. Movement analytics precede the attack
   and retain actor identity. Friendly fire stays on the beam. The focused
   tests retain all earlier regression and popup-total checks.
5. **Third-mechanic scan.** No third arrival double count was found.
   `scripts/enemy_mechanics/dive.gd:143` aggregates approach and attack losses,
   but `dive_view.gd:153` applies the approach without an ordinary move-loss
   popup, and `dive_view.gd:164` presents the combined payload once. Veil uses
   `blink_state` at `veil.gd:127`; Burrow and Wind do not present a second
   ordinary move-loss popup. Evidence:
   `/private/tmp/labyrinth_codex/fix-12-feedback3-mechanics-scan.log`.

## Verification

The mutation runner exited 0. Each child exited 1 due to its expected
assertion failures, with no `SCRIPT ERROR:`; each edited source was restored
byte-for-byte. All resolver, analytics and intermediate-boundary checks run for
each mutation, together with the original five production arrival playbacks.
The full restored-source run additionally plays every reaction fixture.

```text
FIX-12 MUTATION RESULT: 13/13 caught; all source files restored
FIX-12 MUTATION EVIDENCE: PASS (13 assertion failures; 13 byte-exact restorations; no script errors)
```

| Mutation | Outcome | Exact child result |
| --- | --- | --- |
| `before_to_after_losses` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 33 failures)` |
| `mimic_before_to_after_losses` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 36 failures)` |
| `tether_remove_cancel_guard` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 1 failures)` |
| `mimic_remove_footprint_guard` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 1 failures)` |
| `analytics_drop_movement` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (439 checks, 10 failures)` |
| `analytics_drop_identity` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 10 failures)` |
| `analytics_reverse_order` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 30 failures)` |
| `tether_drop_friendly_fire_losses` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 10 failures)` |
| `tether_restore_final_hp_cancellation` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 18 failures)` |
| `tether_do_not_subtract_reactions` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 14 failures)` |
| `tether_do_not_defer_reaction_snapshot` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 30 failures)` |
| `mimic_do_not_defer_reaction_snapshot` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 20 failures)` |
| `tether_drop_all_reacting_unit_losses` | **CAUGHT** | `FIX-12 TEST RESULT: FAIL (489 checks, 2 failures)` |

Logs and machine-readable results:
`/private/tmp/labyrinth_codex/fix-12-feedback3-mutations.log` and
`/private/tmp/labyrinth_codex/fix-12-feedback3-mutations/mutation-results.json`.

All commands below exited 0. Exact observed summaries:

| Program/check | Result lines | Log in `/private/tmp/labyrinth_codex/` |
| --- | --- | --- |
| `tests/fix_12_test.gd` restored source | `FIX-12 TEST RESULT: PASS (722 checks, 0 failures)` | `fix-12-feedback3-restored.log` |
| `tests/fix_12_probe.gd -- --check-only` | `FIX-12 PROBE CONTRACT: PASS (402 checks; 1920x1080, UI scale 100%)` | `fix-12-feedback3-restored-contract.log` |
| `tests/fix_11_test.gd` | `FIX-11 TEST RESULT: PASS (162 checks, 0 failures)` | `fix-12-feedback3-fix11.log` |
| `tests/en03_enemies_test.gd` | `EN03 ENEMIES TEST RESULT: PASS (211 checks, 0 failures)` | `fix-12-feedback3-en03.log` |
| `tests/en06_enemies_test.gd` | `EN06 ENEMIES TEST RESULT: PASS (178 checks, 0 failures)` | `fix-12-feedback3-en06.log` |
| `tests/enemy_no_action_test.gd` | `ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)` | `fix-12-feedback3-no-action.log` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` | `fix-12-feedback3-ui-lint.log` |
| `python3 tests/test_godot_sidecars.py` | `Ran 19 tests` / `OK` | `fix-12-feedback3-sidecars.log` |
| `python3 tools/test_registration_audit.py` | `TEST REGISTRATION AUDIT: PASS (829 scripts; full suite=475, quarantined=29, windowed probe=325)` | `fix-12-feedback3-registration.log` |
| `python3 tests/test_program_suite_runner.py ProgramSuiteRunnerTests.test_manifest_preserves_all_existing_children_and_order` | `Ran 1 test` / `OK` | `fix-12-feedback3-registration-guard.log` |

The reaction-trace UID was generated through the task runner, without an editor
scan: `FIX-12 FEEDBACK 3 UID SETUP: PASS (1 sidecar)` in
`fix-12-feedback3-uids.log`. The temporary setup script was removed. The initial
production playback run passed 714 checks; the final 722 includes the eight
added collateral-analytics assertions. `git diff --check` exits 0. The
headless-only deferred-cascade diagnostic also exited 0, but reports the known
unfixed follow-up described below; it is not counted as a passing regression.

Focused tests only, as explicitly requested. All Godot commands use
`python3 tools/godot_task_runner.py --task-id fix-12 --stream -- godot --headless
--path . --script <program>`.

## Proof for the design owner

No windowed run was attempted; no PNG was generated in this sandbox. Run the
existing four-sequence production probe at 1920x1080 and 100% UI scale:

```sh
python3 tools/visual_probe_runner.py --timeout 60 --no-headless --display-driver macos --audio-driver Dummy tests/fix_12_probe.gd --task-id fix-12 --expect-size 1920x1080 --proof-contract tests/fix_12_proof.json --result-manifest /private/tmp/labyrinth_codex/fix-12-visual-proof.json
```

Run from this worktree. The runner prints the isolated absolute path for
`user://probes/fix-12/`, containing `cancelled_arrival_1920x1080.png`,
`firing_arrival_1920x1080.png`, `firing_beam_1920x1080.png`, and
`mimic_attack_1920x1080.png`. The unchanged proof contract requires all four
native-size images and nonblank board regions. The reaction fixtures run only
in the headless test, preserving the four windowed sequences and the owner's
60-second timeout. No inspection-fixture command was requested by the brief;
fixture preparation is assigned to the owner.

## TODO_DESIGN placeholders

None. The implementation uses existing effect labels, popup styles, timing,
assets and flow. No player-facing values were chosen or authored assets changed.

## Chosen defaults

New fields are test/proof only. `MUTATION_CHECK_ARGUMENT="--mutation-check"`
runs every resolver/analytics/intermediate-boundary check and the original five
production arrival/action playbacks for each mutation. The restored normal run
also plays all 12 reaction fixtures. Existing settle frames (8), playback timeout
(8 seconds), viewport (1920x1080), UI scale (1.0), isolated storage paths, mutation
engine timeout (180 seconds) and wrapper cleanup (10 seconds) are unchanged.

The added fixture values come directly from the review: `SECOND_REACTION_HP=6`,
`COLLISION_LOSS=2`, `COLLATERAL_HP=10`, `MOVING_MIMIC_START=(4,2)`,
`COLLATERAL_TILE=(3,4)`, `MIMIC_ROUTE_WALLS=[(5,2),(5,3)]`,
`RETALIATE_PUSH=1`, and `BEAM_COLLISION_WALL=(1,3)`. Arrival damage, copied-card
identity/damage, hero and illusion positions, reaction amounts, IDs and other
fixture state reuse the earlier named fixture fields and approved game data.

## Open issues and residual risks

- Owner must run and inspect the real-renderer proof. Full suites remain with
  the director at merge; this worker ran focused tests only.
- **Confirmed follow-up: deferred Ember Tick death cascades.** These resolve
  after the capture points in `board_attack_rules.gd:239`, via
  `CombatEngine._flush_surface_deaths` at `combat_engine.gd:12115`. A temporary
  headless diagnostic used the reviewer's `tether_reaction_kills_hero` fixture:
  hazard-free firing state, Thrall `(2,3)`, hero `(3,3)` at HP 7, Retaliate 2
  with Push 1, and two HP-1 Ember Ticks at `(1,3)` and `(2,4)` (IDs 3/4).
  The new snapshots miss the later death-burst tail: resolved hero/Thrall HP
  `0/0`, presented `3/6`; hero payload loss 4 versus real loss 7. The prior
  implementation incorrectly bundled that tail into the beam. Per the final
  round instruction this extra finding is left for a follow-up unit, rather
  than reported as fixed. Evidence:
  `/private/tmp/labyrinth_codex/fix-12-feedback3-residual.log`:
  `FIX-12 DEFERRED CASCADE DIAGNOSTIC: hero resolved=0 presented=3 payload_loss=4 real_loss=7; attacker resolved=0 presented=6`.
  The diagnostic script was removed after use; no failing project assertion
  was rewritten or hidden. The exact fixture also remains in the supplied
  `/private/tmp/fix-12-rereview/followups.gd`.
- Other enemy mechanics keep their legacy reaction presentation payloads. The
  opt-in trace is used by Tether and Mimic only.
- The sandbox emits the existing macOS certificate-store diagnostic. EN03 can
  also emit dummy-texture diagnostics, and scene tests can emit an ObjectDB leak
  warning at shutdown. No existing failing assertions were rewritten.
