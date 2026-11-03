# bos-01 implementation handoff

All changes are uncommitted on `codex/bos-01`. No encounter data, approved art, names, tuning, audio or protected
brief values were edited. The design owner retains commit, peer review, inspection and publication.

## Changed files

- `scripts/battlefield_rules/gust.gd`: saved toward-source/clockwise announcements and rotation, plus the existing
  resolved-damage boundary's bridge to the generic switch.
- `scripts/battlefield_rules/dispatcher.gd`: new dial preparation, switch validation, saved reinstall latch and
  additive fired-event flag.
- `scripts/battlefield_rules/half_health.gd`: threshold, partial replacements and one switch event.
- `scripts/battlefield_rules/switch_presentation.gd`: Continue baseline, committed-only banner and clock invalidation.
- `scripts/battlefield_rules/upheaval.gd`: cumulative line guard and resolution rechecks through the existing guards.
- `scripts/battlefield_rules/analytics.gd`: switch-event serialization and legacy fired-event fallback.
- `scripts/run_scene.gd`: five integration lines for the switch helper and additive analytics event.
- `spec/peer_benchmark/element_rules/design.md`, `spec/analytics.md`: documented dials, guard, latch, ownership and events.
- `tests/suites/bos01_rules_suite.gd`, `tests/bos01_rules_test.gd`: focused mechanics/Continue fixtures.
- `tests/bos01_rule_scene_test.gd`: production panel, clock, ghosts, banner, preview exclusion, Continue and JSONL.
- `tests/bos01_route_cases.gd`: existing Thornmother fixture comparison.
- `tests/fixtures/bos01_rule_fights.gd`, `tests/bos01_rules_probe.gd`,
  `tests/proof_contracts/bos01_rules.json`: three fixture fights and six production-camera/HUD captures.
- `tests/bos01_rule_mutations.py`: the five requested reversible mutations.
- `tests/suites/battlefield_rules_suite.gd`: the additive analytics payload now has nine fields.
- `tests/el04_rule_views_test.gd`: keep the source at its authored anchor while testing a follower's throw ghost;
  the original ghost assertion remains intact.
- `tests/headless_test_programs.json`, `tests/test_program_suite_runner.py`: append the four new headless programs
  after the preserved existing manifest. No assertion baseline was weakened.
- Eight engine-generated `.gd.uid` sidecars accompany the eight new GDScripts. This handoff is `tests/bos01_proof.md`.

## Numbered requirements and acceptance criteria

1. **Gust toward_source:** uses Wildfire's dominant-cardinal rule mirrored, held before the player moves.
   Forecast equals resolution across eight beats each with/without Anchored, and Continue preserves the announcement.
   The production scene shows the existing landing ghosts and panel arrow.
2. **Gust turn_clockwise:** source-to-hero initial cardinal, then UP → RIGHT → DOWN → LEFT → UP, rotated after each beat.
   Same eight-beat/Anchored/Continue coverage. The existing forced mover **moves** a free unanchored 2×2 source:
   `(4,4) → (4,3)` in the test; it is not universally refused.
3. **Half-Health:** triggers after resolved defense/Health, exactly once while the source survives. Tests cover exact
   and odd integer thresholds, raw lethal hits absorbed by Block or Stoneskin, all six rules, either optional
   replacement dictionary, carried counters, reinstall, changed-direction lock and undeclared/dead-source exclusions.
   Continue preserves the latch/counter/sentence/forecast. The actual panel, turn clock and TurnBanner update; hypothetical
   previews do not play a banner. UI and console serialize the additive event exactly once with retry deduplication.
   TurnBanner has no existing sound cue, so no sound was added.
4. **line_between guard:** Worldspine's connectivity/footprint check is reused; objectives with exits additionally
   use the existing Snare guard. Planning considers earlier accepted marks; resolution rechecks actual terrain and
   post-displacement positions. A three-high corridor skips exactly `(6,5)` and keeps `(6,3),(6,4)`.
   A 2×2 source's three-mark line keeps `(6,3)` and skips the two marks `(6,4),(6,5)` that close its second exit.
   Old saved held lines are guarded at resolution too. The rule applies to every line_between caller, including
   Thornmother and the ordinary Thornwall primitive.
5. **Frostbite 0:** existing code already Freezes Chilled hero, enemy and illusion and consumes their supporting Ice;
   the dedicated test proves all three and the existing suite proves Skate protection. No resolver change was needed.
6. **Ownership:** existing Fire and Outcrop resolvers already tag their source. Tests inspect
   `elemental_source.actor_id` for Fire/Ice and `owner_kind/owner_id` for Outcrops. None of the six approved beats
   creates Ice; its test exercises the exact shared ground-placement primitive under a beat source context.
   No unapproved Ice-creating dial was introduced.

All three task-contract acceptance criteria are covered by the above focused tests. Pixel inspection is pending
with the design owner because this worker has no macOS window-server access.

## Existing behavior cases

The existing focused rule, Warband, Snare, element retrofit and enemy suites pass. The allowed route-guard exception:

```text
BOS01 THORNMOTHER: seed=83 tier=1 source=(3, 2) hero=(4, 7) skipped=[]
BOS01 THORNMOTHER: seed=83 tier=2 source=(3, 1) hero=(4, 7) skipped=[]
BOS01 THORNMOTHER RELOCATED SOURCE: source=(1, 6) skipped_held=[(1, 6)]
BOS01 THORNMOTHER: seed=83 tier=3 source=(7, 3) hero=(4, 7) skipped=[]
```

The relocated-source case is the former el04 throw-ghost fixture. Its newly refused source mark prompted the fixture
change to a follower, preserving the ghost assertion. Other boards can skip marks under the same approved guard;
this report does not claim an exhaustive enumeration of all possible board states.

## Verification observed

Every Godot command used `python3 tools/godot_task_runner.py --task-id bos-01 --stream -- godot --headless --path . --script <script>`.
A scene diagnostic run used `--verbose` for audio teardown diagnosis; the final normal run has no teardown warning.
Exact final result lines:

| Script/check | Observed result |
|---|---|
| `tests/bos01_rules_test.gd` (mutation controls) | `BOS01 RULES TEST RESULT: PASS (247 checks, 0 failures)` |
| `tests/bos01_rule_scene_test.gd` | `BOS01 RULE SCENE RESULT: PASS (13 checks, 0 failures)` |
| `tests/bos01_rules_probe.gd -- --check-only` | `BOS01 PROBE CONTRACT: PASS (3 fixture fights, 6 captures, 1920x1080, UI scale 100%)` |
| `tests/bos01_route_cases.gd` | `BOS01 ROUTE CASE REPORT: PASS (3 existing Thornmother fixtures and relocated-source held line)` |
| `tests/battlefield_rules_test.gd` | `BATTLEFIELD RULES TEST RESULT: PASS (591 checks, 0 failures)` |
| `tests/warband_test.gd` | `Warband suite: 0 failures` |
| `tests/warband_orders_test.gd` | `WARBAND ORDERS TEST RESULT: PASS (287 checks, 0 failures)` |
| `tests/warband_wind_lock_test.gd` | `SPX07 WIND LOCK RESULT: PASS (114 checks, 0 failures)` |
| `tests/snare_test.gd` | `Snare suite: 0 failures` |
| `tests/element_retrofit_test.gd` | `ELEMENT RETROFIT TEST RESULT: PASS (939 checks, 0 failures)` |
| `tests/el04_rule_views_test.gd` | `EL04 RULE VIEWS RESULT: PASS (0 failures)` |
| `tests/en04_enemies_test.gd` | `EN04 ENEMIES TEST RESULT: PASS (353 checks, 0 failures)` |
| `python3 tests/bos01_rule_mutations.py` | `BOS01 MUTATION RESULT: PASS (5/5 killed; controls pass; exact sources restored)` |
| `python3 tests/test_ui_identity_lint.py` | `Ran 25 tests` / `OK` |
| `python3 tests/test_element_rule_contract.py` | `Ran 2 tests` / `OK` |
| `python3 tests/test_program_suite_runner.py` | `Ran 28 tests` / `OK` |
| `python3 tools/run_python_suite.py --shards 4 --audit-only --output-dir /private/tmp/labyrinth_codex/bos-01/python-audit` | `ISOLATION AUDIT: 227 modules; /private/tmp/labyrinth_codex/bos-01/python-audit/isolation-audit.md` |
| `python3 tools/test_registration_audit.py --json /private/tmp/labyrinth_codex/bos-01/registration.json --markdown /private/tmp/labyrinth_codex/bos-01/registration.md` | `TEST REGISTRATION AUDIT: PASS (875 scripts; full suite=514, quarantined=29, windowed probe=332)` |
| Sidecar guard including untracked files | `BOS01 SIDECAR CHECK: PASS (8 new UID sidecars, no collisions, repository sidecar contract)` |
| `git diff --check` | exit 0, no output |

The five mutations remove clockwise rotation, aim toward_source at resolution, permit a second switch, reset the
carried counter, and remove the line route guard. Each produced its intended assertion failure without parser or
script errors in the final mutation run. Logs: `/private/tmp/labyrinth_codex/bos-01/mutations/` (including both controls).
Scene log: `/private/tmp/labyrinth_codex/bos-01/scene-final.log`.

No full Python or Godot suite was run, per the unit's standard-risk proof split. No new `tests/test*.py` module was
created; the opt-in mutation driver is not a discovery module. The resource isolation audit passed.

## Proof for the design owner

No windowed command was attempted or retried. Run this exact command for all six captures, using the game's own
camera, HUD and 100% UI scale at 1920×1080:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tools/visual_probe_runner.py --task-id bos-01 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/proof_contracts/bos01_rules.json --result-manifest /private/tmp/labyrinth_codex/bos-01/visual-result.json tests/bos01_rules_probe.gd
```

The probe prints each absolute capture path; the isolated user directory contains:

```text
user://probes/bos01/toward_source_before.png
user://probes/bos01/toward_source_after.png
user://probes/bos01/turn_clockwise_before.png
user://probes/bos01/turn_clockwise_after.png
user://probes/bos01/half_health_before.png
user://probes/bos01/half_health_after.png
```

The half-Health after capture includes the live banner. The capture contract validates six named full-size images;
inspect the sentence/clock, arrow/ghosts, and banner against the binding brief. Captures do not exist yet.

Interactive fixture fights (normal game inputs, no capture camera changes):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tools/godot_task_runner.py --task-id bos-01 --timeout 0 --stream -- godot --path . --script tests/bos01_rules_probe.gd -- --interactive --case toward_source
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tools/godot_task_runner.py --task-id bos-01 --timeout 0 --stream -- godot --path . --script tests/bos01_rules_probe.gd -- --interactive --case turn_clockwise
cd /Users/borgerding/workspace/Labyrinth.worktrees/bos-01 && python3 tools/godot_task_runner.py --task-id bos-01 --timeout 0 --stream -- godot --path . --script tests/bos01_rules_probe.gd -- --interactive --case half_health
```

The interactive half-Health fixture starts one Health above half, so a normal card hit crosses it. Inspection fixture
certification and peer review remain with the design owner under the requested workflow split.

## TODO_DESIGN placeholders

the fixture half-Health sentence (director, 2026-10-27): "After each of its turns, its wind Pushes everyone 2 tiles, then turns a quarter clockwise." (`HALF_HEALTH_SENTENCE`).
The brief supplies Vaeloryx's 1→2 tile change but no exact replacement panel sentence. The placeholder is confined
to debug fixtures/tests. The production engine always consumes the instance's authored `at_half_health.sentence`.

## Chosen defaults

Only test/proof values were chosen, stored in named fields/constants:

- Shared fight proof: source `(4,3)`, hero `(6,6)`, room `(1,0)`, room depth `2`, wait-intent Time `4`;
  the existing enemy-suite seed/board/player loadout is reused. Interactive half-Health margin: `1`.
- Reuse the existing engine fixture's 50-Health hero/source; crossing cases use explicit Health/Block/Stoneskin
  fields (26→25, 40 with 70 defense taking a raw 100 hit, and the odd 51-max threshold).
- Corridor/source-footprint test positions are named `source`, `player`, `grid` and `marks` fields; synthetic clock
  turns use Time `10,20,30`. These are debug fixtures, not encounter tuning.
- Private save path `user://bos01-continue.save`, analytics directory `user://bos01-analytics`, synthetic combat ids,
  and mutation output `/private/tmp/labyrinth_codex/bos-01/mutations`.
- Default interactive case `toward_source`; normal interactive runner timeout is disabled (`--timeout 0`).
- Scene audio teardown settle: `AUDIO_TEARDOWN_SETTLE_SECONDS = 0.1`; existing TurnBanner fade-in is reused for capture.
- Presentation's internal invalidation token: `<battlefield-rule-switched>`. UIDs were generated by Godot.

## Open issues

The design-owner sentence and windowed pixel inspection remain outstanding. macOS headless runs emitted the existing
`get_system_ca_certificates (platform/macos/os_macos.mm:1014)` diagnostic; runner/test exits are reported above.
