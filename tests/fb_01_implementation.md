# fb-01 implementation handoff

This feedback round is uncommitted in `codex/fb-01`. No peer review, publication,
inspection-fixture generation, or windowed run was performed by this worker.

## Director feedback 3 — current handoff

Read the director-provided review of `47e631059`, its edge reproduction log and
mutation report; inspected the accepted Frozen renderer capture before editing.
This round addresses only its three findings:

1. **Complete Immobilize movement.** `enemy_no_action_reason.gd` compares full
   unrestricted/restricted plans, including the Warband retreat path and the
   final landing of an embedded flight. Both comparisons retain the same Shock
   restriction, so flight already lost to Shock is not attributed to Immobilize.
   Constructed regressions resolve the existing screened captain arena at
   `(4,2) → (4,1)` and authored Gust Shrike Dive at `(2,4) → (3,4)`, both with and
   without commit steps. They check real unrestricted movement, blocked movement,
   resolver reason, one exact icon/text callout at turn start, input immutability,
   and the captain's retained attack.
2. **Complete HUD collision geometry.** `intent_callout_layout.gd` now consumes
   the renderer's `_fixed_hud_collision_rects` and `_enemy_hud_collision_rects`,
   including leader crests, status/defense badges and complete intent contours.
   It retains the shared typography input and the existing spacing/float rules.
   The Frozen capture fixture is now a marked captain at `(2,2)`; tests compare
   Frozen and Redirected rectangles directly against the actual crest in normal
   and reduced motion throughout the float, including the stationary start.
3. **Observable render guards.** The new test-only
   `tests/helpers/enemy_no_action_hud_observer.gd` records synchronous redraw
   requests during callout-only addition/expiry, before idle redraws can mask a
   wrong owner. `intent_callouts.gd` emits `intent_callout_drawn` after its actual
   native text submission. The observer checks that real submission's retained
   layer, compositing order, and same-frame order after actor HUDs and all badge
   overlays. `combat_board_view.gd` records callouts in their own render timing
   section, keeping the preceding HUD section boundary observable. Drawing and
   invalidation remain on the accepted HUD path.

Changed files this round: the four production scripts named above,
`tests/suites/enemy_no_action_suite.gd`, `tests/enemy_no_action_test.gd`, the new
HUD observer and its UID, and this handoff. Captions, reason strings, icons,
0.8-second real hold/0.3-second tail, privacy and analytics retain their accepted
contracts. No new art, colours, font sizes, dependencies or gameplay tuning.

Before/after and mutation evidence (assertion counts include wall-clock samples):

```text
New regression run before fixes:
ENEMY NO ACTION TEST RESULT: FAIL (1041 assertions; 27 failures)
Effects-layer invalidation reversion:
ENEMY NO ACTION TEST RESULT: FAIL (1041 assertions; 2 failures)
Draw callout below HUD reversion:
ENEMY NO ACTION TEST RESULT: FAIL (1041 assertions; 1 failures)
```

The initial run reproduced both missing reasons and crest intersections in both
motion modes; its observer also required the separate callout timing boundary.
The effects reversion fails `Callout-only addition requests exactly the HUD
redraw` and its expiry counterpart. The draw reversion fails `Actual callout text
is owned by the HUD layer above effects`. Every potential retained layer is
explicitly drawn for the ownership test after observing the isolated redraw
request, so a wrongly retained draw cannot escape observation. Both reversions
were restored before the final focused set; no mutation remains in the checkout.

Logs: `/private/tmp/labyrinth_codex/fb-01-feedback3-before.log`,
`fb-01-feedback3-mutant-effects-redraw.log`, and
`fb-01-feedback3-mutant-draw-below-hud.log`.

Final focused results after restoring both mutations:

```text
FB-01 FASTEST TIMING: reduced=false observed_wait=1.111s opaque_samples=115
FB-01 FASTEST TIMING: reduced=true observed_wait=1.110s opaque_samples=114
ENEMY NO ACTION TEST RESULT: PASS (1043 assertions; 0 failures)
THREATS AT REST TEST RESULT: PASS (612 assertions; includes compass suite)
ENEMY INTENT CONTINUITY TEST RESULT: PASS (1882 checks, 0 failures)
FLOATING COMBAT TEXT TEST RESULT: PASS
COMBAT FEEL TEST RESULT: PASS
UI identity lint: Ran 25 tests in 2.684s / OK
Godot sidecars: Ran 19 tests in 1.521s / OK
TEST REGISTRATION AUDIT: PASS (817 scripts; full suite=463, quarantined=29, windowed probe=325)
```

Commands (all from this worktree, all final focused runs exited 0):

```sh
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/enemy_no_action_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/threats_at_rest_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/enemy_intent_continuity_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/combat_feel_test.gd
python3 tests/test_ui_identity_lint.py
python3 tests/test_godot_sidecars.py
python3 tools/test_registration_audit.py
```

Final logs: `/private/tmp/labyrinth_codex/fb-01-feedback3-{focused,threats,continuity,pacing,ui,sidecars,registration}.log`.
The sandbox CA-certificate and dummy-renderer Veil diagnostics remain as
documented in feedback 2. The UI lint initially caught a new theme-font lookup;
reusing the supplied shared font resolved it without changing the lint baseline.
`git diff --check` and proof-contract JSON parsing pass. The new observer UID was
generated via `ResourceUID` in a temporary headless script through the task
runner, then that generator was removed. Full suites were not rerun, as directed.

The Git preflight recheck again encountered the protected parent repository's
`index.lock` error documented below. No Git metadata workaround, commit, review,
publication, inspection fixture or windowed execution was performed.

## Director feedback 2 — accepted history

The director accepted feedback 1 after a passing four-image windowed probe.
All four images were inspected before this revision, including the Frozen
capture with the stale `Tunnel Crawler: Advance` caption.

1. `intent_callouts.gd` selects the turn caption from the resolver's existing
   start-of-turn status tick, while preparing each activation's immutable
   presentation stream. Frozen, Petrified and Shocked use the same names as
   their callouts. Shock also names a move-only plan with no lost attack.
   Immobilized and other reasons retain the intent caption. Concealed status
   ticks never supply a caption, including an actor revealed later in the turn.
2. `combat_pacing.gd` uses that caption for the normal intent step. Frozen and
   Petrified have no intent step, so their start-of-turn callout establishes the
   caption immediately. The existing caption control, typography, placement,
   activation clock, lead waits and callout playback are unchanged.

Changed files this round: `scripts/intent_callouts.gd`,
`scripts/combat_pacing.gd`, `tests/suites/enemy_no_action_suite.gd`,
`tests/enemy_no_action_test.gd`, and this handoff. The probe inherits the updated
test and retains the existing four-image proof contract. Each capture now
asserts its live caption as well as callout text/opacity/geometry; Frozen must
show `Tunnel Crawler: Frozen` above its expanded intent badges. The constructed
intent's name comes from the approved Crawler data (`Skitter Strike`).

Focused caption checks cover all four statuses in real scene playback, Shock's
actual move, normal and commit-bearing streams, and hidden/revealed privacy.
The additional playback matrix runs headless; the windowed probe retains its
four capture states with caption assertions, avoiding unrelated playback time.
Full suites were not rerun, as directed. Windowed proof remains for the director;
the exact updated command and capture paths are below.

Observed focused results for the final feedback 2 revision:

```text
FB-01 FASTEST TIMING: reduced=false observed_wait=1.106s opaque_samples=114
FB-01 FASTEST TIMING: reduced=true observed_wait=1.108s opaque_samples=114
ENEMY NO ACTION TEST RESULT: PASS (1001 assertions; 0 failures)
THREATS AT REST TEST RESULT: PASS (612 assertions; includes compass suite)
FLOATING COMBAT TEXT TEST RESULT: PASS
COMBAT FEEL TEST RESULT: PASS
Ran 25 tests in 2.800s
OK
```

Commands run for this feedback round:

```sh
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/enemy_no_action_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/threats_at_rest_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/combat_feel_test.gd
python3 tests/test_ui_identity_lint.py
```

All four commands exited 0. Logs are
`/private/tmp/labyrinth_codex/fb-01-feedback2-{focused,threats,pacing,ui}.log`.
Godot also printed its sandbox macOS CA-certificate lookup diagnostic; the
combat-feel suite printed a dummy-renderer null-texture diagnostic in the
unchanged Veil asset alpha-polygon path. Both suites' result lines above passed;
no existing failure assertions were edited. `git diff --check` and proof-contract
JSON parsing pass. No new colours, font sizes, assets or dependencies were added.

The Git preflight recheck was blocked by this sandbox, while the director's
existing contract remains ready and the branch was clean before edits:

```text
error: git write-tree failed: fatal: Unable to create '/Users/borgerding/workspace/Labyrinth/.git/worktrees/fb-01/index.lock': Operation not permitted
```

No alternate Git metadata or index workaround was used. The director already
prepared this worktree and passed preflight under the unit's explicit workflow.

## Director feedback 1 — accepted history

The director's previous three-capture proof passed and established correct reasons
and timing; its images were inspected before this revision. This round changes
only callout rendering/geometry, its focused tests, and the proof contract.

- Intent callouts, including Redirected, now draw last on the retained board HUD,
  after health bars, time/order numerals, pips and intent badges. Their appearance
  and expiry invalidate that HUD owner.
- Text is centred on the acting enemy's actual health bar. Its outlined glyph
  bounds start 6px above the bar or any higher intent badges. If an adjacent
  actor's HUD intrudes, keep that horizontal centre and raise only enough to
  clear it with the same 6px gap. This necessary upward exception reconciles the
  requested acting-bar anchor with the explicit no-overlap requirement.
- Measurement uses native shaped glyph ink bounds, including bearings and
  ligatures. Status icons retain the previous cap-height size, are centred
  vertically on that cap height, and sit exactly 6px left of the outlined word.
  `TODO_DESIGN_STATUS_ICON_GAP` is resolved and removed.
- Float retains the existing vertical curve above that anchor; lateral drift
  and motion below the anchor are removed. Reduced motion, opacity/hold/fade,
  texts, resolver fields, analytics and privacy retain their contracts.
- The probe now requires four captures, adding Frozen with real expanded intent
  badges. That extra disclosure is proof-only; production disclosure preferences
  are unchanged. Tests cover adjacent hero/enemy bars, badges, Redirected, the
  complete float sweep, exact spacing/centring, HUD redraw/expiry and cache purity.

Feedback 1 observed focused results:

```text
FB-01 FASTEST TIMING: reduced=false observed_wait=1.105s opaque_samples=115
FB-01 FASTEST TIMING: reduced=true observed_wait=1.110s opaque_samples=114
ENEMY NO ACTION TEST RESULT: PASS (930 assertions; 0 failures)
THREATS AT REST TEST RESULT: PASS (612 assertions; includes compass suite)
UI identity lint: Ran 25 tests / OK
Icon identity policy: Ran 8 tests / OK
TEST REGISTRATION AUDIT: PASS (817 scripts; full suite=463, quarantined=29, windowed probe=325)
```

Logs are `/private/tmp/labyrinth_codex/fb-01-feedback1-{focused,threats,ui,icons,registration}.log`.
The commands are the same focused commands listed below; full suites were not
run for that feedback round. The director subsequently ran the four-image
windowed proof successfully and accepted its rendering; its captions prompted
feedback 2 above.

## Files changed

- `scripts/combat_engine.gd`, `scripts/enemy_no_action_reason.gd` and its UID:
  additive resolver explanations.
- `scripts/combat_board_view.gd`, `scripts/intent_callout_layout.gd` and its UID:
  topmost callout HUD ownership and collision-free text/icon placement.
- `scripts/intent_callouts.gd`, `scripts/run_scene.gd`: exact feedback, status
  icons, grouping, real-time playback and additive analytics payloads.
- `spec/analytics.md`: reason/event contract.
- `tests/suites/enemy_no_action_suite.gd`, `tests/enemy_no_action_test.gd`,
  `tests/enemy_no_action_probe.gd` and their UIDs,
  `tests/enemy_no_action_proof.json`: constructed states, live timing and proof.
- `tests/suites/threats_at_rest_suite.gd`, `tests/threats_at_rest_test.gd`,
  `tests/suites/enemy_intent_continuity_suite.gd`: intentional replacement of
  retired callout/timing/no-action analytics expectations.
- `tests/headless_test_programs.json`, `tests/windowed_test_allowlist.json`:
  registration; this document: implementation/proof handoff.

## Acceptance criteria

1. **Resolver reasons.** `enemy_no_action_reason.gd` supplies the seven specified
   reason values. Direct attack failures annotate the resolver context, which
   becomes an additive `no_action` step when no attack step resolved. Both turn
   and legacy phase resolution share this path. Existing start-of-turn status
   steps retain their fields and gain the restriction reason. Immobilize compares
   unrestricted/restricted plans; stationary plans get no Immobilized callout.
   A destroyed illusion followed by an unsuccessful second attack exercises
   `no_target` with a living hero. Gameplay rules and tuning are unchanged.
2. **Callouts.** Exact brief text, existing callout typography/outline/colour,
   and existing `shock`, `freeze`, `petrify`, `immobilize` glossary textures.
   Icons use the font's H glyph cap height. Reason classification consumes
   resolver fields; position comparisons remain only for the existing Redirected
   behavior. Movement completes before deferred reasons; Immobilized appears at
   turn start even if an attack follows. Hidden actors get no callout.
3. **Timing.** Wall-clock ticks drive the opaque 0.8-second hold and shared fade
   curve over the final 0.3 seconds. Sequential playback waits for the entire
   1.1-second callout before the next actor. Reduced motion removes float while
   retaining the same hold/fade. Redirected retains its original 0.9 seconds.
4. **Analytics.** `enemy_action_resolved` gains `no_action_reason`, empty on
   ordinary resolved actions. Failed attempts/restrictions use the same event
   with no fabricated losses. Existing status tick events remain. The additive
   behavior is documented in `spec/analytics.md`.

## Initial implementation verification (before feedback 1)

Initial focused results (wall-clock sample counts can vary by run):

```text
FB-01 FASTEST TIMING: reduced=false observed_wait=1.106s opaque_samples=114
FB-01 FASTEST TIMING: reduced=true observed_wait=1.102s opaque_samples=114
ENEMY NO ACTION TEST RESULT: PASS (691 assertions; 0 failures)
THREATS AT REST TEST RESULT: PASS (612 assertions; includes compass suite)
ENEMY INTENT CONTINUITY TEST RESULT: PASS (1882 checks, 0 failures)
UI identity lint: Ran 25 tests / OK
Icon identity policy: Ran 8 tests / OK
TEST REGISTRATION AUDIT: PASS (817 scripts; full suite=463, quarantined=29, windowed probe=325)
FB-01 CAP HEIGHT: (19.0, 18.0)
```

Commands, all from this worktree:

```sh
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/enemy_no_action_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/threats_at_rest_test.gd
python3 tools/godot_task_runner.py --task-id fb-01 --stream -- godot --headless --path . --script tests/enemy_intent_continuity_test.gd
python3 tests/test_ui_identity_lint.py
python3 tests/test_icon_identity_policy.py
python3 tools/test_registration_audit.py
python3 tools/godot_task_runner.py --task-id fb-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The 900-second outer timeout accommodates the documented full-suite main body
and isolated program scheduler. The observed full Godot run reported:

```text
MAIN BODY ASSERTIONS: 495455
ENEMY NO ACTION TEST RESULT: PASS (690 assertions; 0 failures)
FULL SUITE RUNTIME: 686.545 seconds (budget 900 seconds)
TEST RESULT: FAIL (5 failure(s))
```

Four failures were the previous continuity suite's expectation that unreachable
Lash emits no action event. That expectation was updated to require exactly one
reason event with empty hit-loss data, then the focused continuity run above
passed. The full suite predates the final focused fixes; the focused results
above cover the final implementation. The fifth
failure was the unchanged `special_encounter_test` program, whose two assertions
cannot load approved/director-staged emblem `.ctex` imports in this fresh
worktree. No assertion or asset in that program was changed. All other 206 child
programs passed.

The extra repository-wide Python discovery was interrupted during the unrelated
RR30 exhaustive per-frame art coverage test, after 1,517 test starts. It ended
with `KeyboardInterrupt` / exit `130`; it has no final pass/fail result. The
required focused Python checks above completed successfully. No Python production
code changed in this unit.

Logs: `/private/tmp/labyrinth_codex/fb-01-focused.log`, `fb-01-threats.log`,
`fb-01-full-godot.log`, `fb-01-full-python.log`, `fb-01-ui-lint.log`,
`fb-01-icons.log`, `fb-01-continuity.log`. `git diff --check` and proof-contract JSON parsing pass.
New script sidecars were generated with Godot's `ResourceUID` through the task
runner; the temporary generator was removed. A temporary headless metric check
also confirmed the production font's cap-height query is nonzero (18 pixels);
its script was removed, with output in `fb-01-cap-height.log` beside the logs above.

## Proof for the design owner

Window-server access is unavailable in this worker sandbox. This worker has not
attempted or produced fresh renderer captures. Run this command on the director's
windowed machine:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fb-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy tests/enemy_no_action_probe.gd --task-id fb-01 --expect-size 1920x1080 --proof-contract tests/enemy_no_action_proof.json --result-manifest /private/tmp/labyrinth_codex/fb-01-feedback3-visual-proof.json
```

The probe captures production playback at 0.4 seconds into the opaque hold,
after any movement. It asserts exact text, opacity, native resolution and 100%
UI scale, plus the live turn caption. Frozen must show `Tunnel Crawler: Frozen`.
Expected files under the runner's isolated `user://probes/fb-01/`:

- `out_of_range_1920x1080.png`
- `no_line_of_sight_1920x1080.png`
- `shocked_1920x1080.png`
- `frozen_1920x1080.png` (captain at `(2,2)`, with crest and expanded intent badges)

The runner prints the absolute capture directory and validates all four images
against `tests/enemy_no_action_proof.json`. The director owns visual judgment,
peer review, the playable inspection fixture, committing and publication.

## TODO_DESIGN placeholders

None remaining. The director approved the 6px gap in feedback 1.

## Chosen defaults

These values occur only in constructed tests/proof or runner bounds:

| Named fields/constants | Values |
| --- | --- |
| `FIXTURE_SEED`, `GRID_SIDE` | `126065`, `9` |
| `HERO_TILE`, `ENEMY_TILE` | `(4,4)`, `(2,4)` |
| `FIXTURE_HP`, `FIXTURE_DAMAGE`, `FIXTURE_RANGED_RANGE` | `24`, `4`, `6` |
| Fixture layout fields | coord `(1,0)`, depth `2`, clear Umbra, one `brace` in a one-card hand; empty terrain/traps/loot |
| Fixture intent fields | id `fb_01_test`, name read from the approved Crawler's first intent, explicitly constructed actions/statuses |
| Fixture positions | skipped-turn enemy `(3,4)`; move-then-range enemy `(1,4)`; LOS wall `(3,4)`; decoy `(2,3)` with id `1` and HP `4` |
| `SECOND_ACTOR_ID`, `SECOND_ACTOR_TILE` | `2`, `(6,4)` (also the legacy grouping fixture) |
| `HIDDEN_ACTOR_TILE` | `(7,1)`, beyond the hero's Heart sight radius in caption privacy tests |
| `CAPTAIN_TILE` | `(2,2)`, the director's crest regression position |
| Movement regression fixture fields | Existing Warband `arena()` and its `Hold` intent (`time=4`, `damage=3`, `range=6`); approved Gust Shrike `Dive`; director-specified endpoints `(4,1)` and `(3,4)` |
| HUD observer fixture | Existing `SETTLE_FRAMES`, viewport and Frozen state; expanded intent rows; synchronous request capture followed by one explicit redraw of all retained layers |
| `SETTLE_FRAMES`, `MID_HOLD_SECONDS` | `8`, `0.4` |
| `HOLD_SAMPLE_END_SECONDS`, `PLAYBACK_TIMEOUT_SECONDS`, `AUDIO_DRAIN_SECONDS` | `0.78`, `6.0`, `0.1` seconds |
| Full-suite runner timeout | `900` seconds (initial implementation only) |
| `GEOMETRY_SAMPLE_SECONDS` | `0.0`, `0.4`, `0.8`, `1.0` seconds |
| `ISOLATED_HEALTH_RECT`, `UPPER_INTENT_RECT` | `(500,400,120,18)`, `(500,350,120,24)` |
| Frozen capture disclosure | `show_all_enemy_intents = true` in the proof-only board submission |

The brief supplies production timing, text, icons and style. No gameplay defaults
or tuning were selected.

## Open issues / other no-action paths

- Director re-capture/judgment of Frozen on a captain remains open; earlier rendering/captions are accepted.
- The initial full Godot run recorded missing imported emblem caches described
  above. The observed failing assertions are `Approved emblem imports load
  through Godot’s real resource loader` and `Director-staged emblem sidecars
  load through Godot’s real resource loader`.
- Tether's partner/alignment cancellation still has its separate `Cancelled`
  label in `scripts/enemy_mechanics/tether.gd`; this was found and left untouched
  under the brief's instruction to report other no-action paths.
- Death during Fire/Bleed, unmet surface requirements, special/held attacks with
  empty footprints or an unusable held aim, and non-attack no-ops retain their
  existing behavior. These do not receive an invented reason from presentation.
- Guardian `Interrupted` labels are unchanged, as required.
