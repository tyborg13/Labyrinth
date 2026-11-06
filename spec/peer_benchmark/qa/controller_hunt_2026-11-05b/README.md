# qa-57: release controller-only hunt

**6 completed whole runs; 2 final-dragon entries.**
The campaign recorded **12,143 decisions** and
**38,687 physical controller input steps** across the seeds below.
All work is uncommitted. One new local focus bug is fixed with two production
lines and a regression in the existing controller sweep. Production scenes,
data, artwork, analytics and save formats are unchanged.

Actual release HEAD: `f0af5a0be69316eea5e3ebb644b98f39dee17fea`
(`Merge qa-58: full suite green (render gate teardown, no arrival cue for opening enemies, restored test helpers)`).
Branch: `codex/qa-57`. Risk tier: **standard**.
No Git writes, peer review, fixture publication or windowed
runs were performed. The director owns those later phases.

| Seed | Outcome | Decisions | Controller steps | Sections |
|---|---|---:|---:|---|
| 14 | victory | 2,923 | 8,750 | 0, 1, 2, 3, 4, 5 |
| 15 | victory | 2,878 | 9,391 | 0, 1, 2, 3, 4, 5 |
| 16 | embrace | 2,331 | 7,435 | 0, 1, 2, 3, 4 |
| 17 | embrace | 488 | 1,756 | 0 |
| 18 | embrace | 1,309 | 4,292 | 0, 1 |
| 19 | embrace | 2,214 | 7,063 | 0, 1, 2, 3, 4 |

## Numbered acceptance criteria

1. **Driver / screen coverage met.** At least six normal run endings on seeds
   outside qa-51's 4–11, including the final dragon. Section map, pre-battle,
   cards, targeting, Pass, Details, Draw/Discard, turn order, card and relic
   rewards, treasure, gear rewards, shop Buy and Purge, events, campfire,
   Camp/Pause, Grimoire and Steam keyboard search mock, Character's three tabs,
   all nine Settings rows, run end and Chronicle were visited. Analytics record
   10 purchases, 3 Scavenger purges, 84 committed card rewards and
   6 Chronicle opens.
   Natural event gear rewards are itemized in `campaign.json` (including seed
   15's `tourney_lance`). The 35-screen fixture inventory separately reached
   330/330 controls. See the coverage dictionary and per-seed traces for the
   distinction between whole-run evidence and supplemental fixtures.
2. **Detection met within the headless scope.** The driver checks missing,
   hidden, disabled and stale focus; containment in the active modal (including
   Settings confirmation and Chronicle); native focus/candidate reachability;
   bounded unchanged state; and the known Details prompt/action mismatch.
   The new disabled-Learn focus failure was found and fixed. No new
   controller-only soft lock was found.
   Pixel appearance, crossfade appearance and real Deck keyboard delivery remain
   native/hardware inspection work; no renderer proof is claimed.
3. **Report / reproductions met.** Findings below give screen, seed or fixture,
   physical reproduction, and file:line cause. `campaign.json` retains finding
   context and the last 40 inputs linked to the complete input stream.
   `verification.json` retains exact observed result lines and runner exits.
   `input-audit.json` checks all six physical input streams are ordered and their
   lengths match the reported input counts.
4. **Small fixes / regression checks met.** Two lines in
   `scripts/skill_tree_view.gd` return focus to the selected skill when Learn
   becomes disabled. The regression added to the existing controller sweep
   fails before the fix and passes after it. No pre-existing assertion was
   changed. Qa-51's five repairs hold:
   the focused Tutorial Skip and reward-reveal checks pass; the broad sweep's
   fresh/cache-hit piles, Details A toggle and unaffordable gear card navigation
   assertions pass. HUD replacement and analog regressions also pass. The broad
   sweep's four existing mixed-input assertions remain failures and are reported
   below. No full Godot or full Python suite was run; Python's default pass group
   is the required bounded run.

## Driver and evidence

The driver starts from qa-51's archived adapter and the current production
`tools/run_hunt.gd` / `tools/run_hunt_policy.gd`. Policy choices enter through
`InputEventJoypadButton` or `InputEventJoypadMotion` and
`Input.parse_input_event`: D-pad/native focus links or closed-loop left-stick
navigation, then A; X/R1/A for cards, Y for Pass, Start for the menu, View for the
map and B for back. It never grabs focus, calls a gameplay handler, emits an
activation signal or installs a room fixture during a counted run.
Run creation and the inherited diagnostic initial 9,999 Health are setup.
A button step counts its press/release pair; each axis sample is one step.

Settings rows are master, music and SFX volume, display mode, UI scale, edge
smoothing, dialogue speed, combat speed and reduced motion. Each is reached;
sliders receive right/left, options open and cancel their native popup, and
reduced motion toggles twice. Camp is audited immediately after Start.

The search mock now exercises sd-07's real
`GrimoireSearchKeyboard -> SteamService -> showFloatingGamepadTextInput` path.
Only Steam's API endpoint and delivered text are mocked; navigation and A remain
physical joypad events. Focus requests a single-line keyboard, A does not reopen
an already-open keyboard, `fatigue` filters the live search, and leaving dismisses
it. The mock inserts text and emits the field's normal `text_changed`; this is
the explicit keyboard-mock exception to the physical-event-only rule. The real
Steam client and compositor are not initialized by this mock.

For qa-54's known hidden pending targets, the read-only adapter records absent
candidate offers and chooses from the remaining offers with the inherited random
policy, or uses B to cancel if none remain. These exclusions are logged, never
counted as successful target activations. No new gameplay strategy or targeting
rule is implemented. Seeds 14 and 15 decline Embrace; other seeds retain the
inherited terminal-choice policy.

Every counted run has `command.json`, `execution.json`, `execution.log`,
`trace.jsonl`, `inputs.jsonl`, `controller.json`, `summary.json` and isolated
analytics under `/private/tmp/labyrinth_codex/qa-57/evidence/campaign-acceptance/<seed>/`.
Seeds 14–18 loaded the release scripts before the local fix; seed 19 loads the
fix. Their exact skill-tree source and driver SHA-256 values are recorded in
`campaign.json`. Seed 19 uses the initial equivalent focus repair in the action
refresh; the final two-line repair lives solely in the activation handler to
avoid touching the protected refresh path. The final focused test validates it.
The first adapter included covered Character controls in Reset
confirmation offers; seed 19 uses the corrected active scope.
The physical input stream is authoritative; inherited policy descriptions can
retain unused mouse-event arguments, which the adapter never injects.
Tool snapshots are archived as `.txt` under `proof-sources/` to avoid Godot script
inventory/UID noise. `provenance.json` binds the scripts and release HEAD.

Restore the tools, then replay with a fresh output directory:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 - <<'RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/controller_hunt_2026-11-05b/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-57/tools')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
RESTORE
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/godot_task_runner.py --task-id qa-57 --timeout 3600 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-57/tools/controller_hunt.gd -- --seed 14 --no-embrace true --output-dir /private/tmp/labyrinth_codex/qa-57/replays/seed-14-fresh
```

The final adapter and focus repair can change later policy choices after an
affected modal. Historical matching uses each run's recorded physical stream
and source hashes; the standalone Learn regression and captured dragon/treasure
fixtures are the portable reproductions for their findings.
Use `--stop-after <decision>` for a bounded reproduction, or replay another
seed with its saved `command.json` and a new output path. Campaign coordination
is `run_acceptance.py`; the count and all attempts are retained in `campaign.json`.

## Fixed here: learning a skill leaves focus on disabled Learn

Screen: Character / Skills. Seed 16, section 2, campfire room `(11, 7)`, decision
1284, input 4050; also seed 18, section 1, pre-battle `(6, -6)`, decision 992,
input 3387. In Skills, navigate to Long Dawn, right to Learn, then A. The skill
is persisted and Learn changes to its disabled Learned state, but GUI focus
remains on `SkillDetailAction`. The last inputs for seed 16 are right, right, A
(from Ghost Stride through Long Dawn to Learn); seed 18 selects Long Dawn with
A, then right, A. Full paths and input tails remain in `campaign.json`.

Cause: `scripts/skill_tree_view.gd:1290` refreshes the action's availability after
learning without recovering its now-unusable focus. Two added lines in `_on_detail_action_pressed` at `:1436`
check, after the learn callback, that this still-live disabled action owns focus,
then reuse the
existing `grab_tree_focus()` helper to return to its selected node. The guard
preserves another control's focus. No rules, text, geometry, animation or tuning
changes. It was recoverable with a direction, so this is an invalid focus finding,
not a whole-run soft lock.

Regression: `tests/controller_screen_sweep.gd --skill-learn-focus-only` uses
actual controller navigation and A to learn, checks persistence, disabled Learn,
immediate focus on the selected node, further enabled navigation and no second
point spent. Before: `REGRESSION SKILL_LEARN_FOCUS: FAIL` /
`CONTROLLER SCREEN SWEEP: FAIL (1 findings)` (the selected-node focus assertion).
After: `REGRESSION SKILL_LEARN_FOCUS: PASS` /
`CONTROLLER SCREEN SWEEP: PASS (0 findings)`. An earlier development fixture
expected the starting graph node to remain selected while navigating across
other graph nodes; that fixture-only expectation was corrected before the
one-failure baseline and is retained as `skill-learn-before.log`.

## Rejected oracle findings: covered Reset controls

Seed 18, section 1, pre-battle `(6, -6)`, decision 994: A on Reset Skills opens its
confirmation. At decisions 995–996 the old adapter offered Living Shadow and
Carry the Guard behind it; it correctly could not focus either from
`CancelSkillReset`. The recorded active scope is `SkillResetConfirmationScrim`.
This is correct modal containment. Cause: `tools/run_hunt_policy.gd:35` enumerates
the whole Character scrim, while the adapter initially only overrode the Purge
confirmation inventory. The task-local adapter now enumerates the existing Reset
`focus_scope` equivalent (the confirmation scrim) first. Seed 19 uses this
oracle correction. The existing Reset containment sweep passes; no product fix
or new unit is needed for these reports. Seed 16 also produced the same covered
Reset offers at decisions 1796–1797 before the oracle correction.

## Transient oracle finding: asynchronous Purge close handoff

Seed 19, section 4, Scavenger `(19, -13)`, decision 2155, input 6870: confirm
Cinderline Tempo's purge while in Sell mode. The immediate post-action audit
records no focus after the overlay closes. Cause: `_close_magic_purge` at
`scripts/run_scene.gd:34434` schedules the existing modal recovery;
`_refresh_controller_modal_after_layout` at `:3457` waits two process frames.
The oracle sampled during that handoff, before its normal settled decision.

A focused physical-input countercheck, `purge_return_probe.gd`, samples 16 frames
at the same diagnostic ×8 / 240 FPS settings. Frames 0–1 have no focus; frame 2
and every later sample focus the enabled `PackFilter_all`. In the actual run,
the next input, 6871, also starts on `PackFilter_all`; no extra input was needed
to recover and the run progressed. The Scavenger sweep prints
`CONTROLLER SCREEN SWEEP: PASS (0 findings)`. State samples are retained at
`/private/tmp/labyrinth_codex/qa-57/evidence/purge-return/purge_return_frames.json`.
This is an existing two-frame presentation/focus handoff, not a persistent
controller dead-end. No production timing or focus-recovery policy was changed.
If an immediate close-frame focus guarantee is desired, it needs an explicit
owner-directed timing contract rather than changing the shared refresh path here.

## Needs a unit / already owned by qa-54

### 1. Details tooltip still advertises the keyboard shortcut

Screen: first combat, Details. Seed 14, decision 8, input 271 (also seen on every
other campaign seed). After skipping the tutorial, focus Draw, A, B; focus
Discard, A, B; navigate to Details and press A. A correctly toggles full plans,
but the controller cursor tooltip still includes `[I]`. The input tail in
`campaign.json` gives the exact D-pad sequence; the full stream is
`campaign-acceptance/14/inputs.jsonl`.

Cause: `scripts/run_scene.gd:21903–21906` supplies the keyboard suffix in the
button's tooltip; `scripts/controller_focus_candidates.gd:27` forwards that
text to the analog cursor. `scripts/combat_hud_intents.gd:86–88` correctly hides
the separate I glyph for controller use. This is the already-assigned qa-54 copy
and tooltip-shortcut work; changing wording is outside qa-57. Preserve keyboard
copy and use the owner's approved controller wording there. The native Details
capture command below supplies a picture if needed.

### 2. Hidden legal targets still differ between mouse and controller

Screen: final dragon and Tharokh combat. The portable qa-51 fixture is seed 4, section 5,
room `(24, 0)`, and was independently replayed on today's HEAD. Physical sequence:
X, R1 until Hamstring Shot, A, right until its printed Play mode, A, left stick
toward `(4, 2)`, A. The card remains held and the committed player does not move.
The separate mouse counterfactual hits `(4, 2)`, consumes the card and commits
movement to `(3, 2)`. This counterfactual is excluded from whole-run input counts.

Observed line: `DRAGON TARGET PARITY: target=(4, 2) controller=false visible=false controller_card_retained=true mouse_hit=(4, 2) committed_player=(3, 2)`.
Cause: `scripts/combat_board_view.gd:4318` filters controller navigation by Umbra
visibility, while `:16471` pointer hit testing accepts the target polygon and
`scripts/run_scene.gd:21652` accepts the pending legal action. This is qa-54's
existing visibility-policy unit; removing its visibility filter here would
change gameplay/information policy and touch protected board submission work.
Use its approved targeting design. The same visibility filter also excludes
some Tharokh targets: seed 14's Dull Bolt at decision 2002 and seed 16's Pale
Spark at decision 1801. A separate existing-boss fixture with Pale Spark confirms
`(5, 3)` is legal, rendered stone and pointer-hittable, but `visible=false` and
absent from controller tiles. Thus these earlier labels are also visibility gaps,
not wall/floor exclusions. `target-filter-final.log` records the read-only
countercheck, excluded from whole-run counts. Its first two development attempts
never reached a pending target (one toggled out of the already-active hand) and
are excluded; the corrected probe asserts a nonempty target set.
Seed 15 also physically attempted missing Noctyrax cursor targets `(4, 2)`,
`(1, 3)`, `(2, 4)` and `(5, 1)` at decisions 2805, 2807, 2821 and 2834; each
records `cursor_unreachable` with its physical input tail. It later won, as did
seed 14. The parity gap therefore does not block every controller strategy.
Whole-run observations/exclusions:

- Seed 14, section 3, room (16, 0), decision 2002, input 6045: qa-54: legal pending target absent from controller candidates: (5, 4).
- Seed 14, section 5, room (24, 0), decision 2830, input 8488: qa-54: legal pending target absent from controller candidates: (5, 3).
- Seed 14, section 5, room (24, 0), decision 2830, input 8488: qa-54: legal pending target absent from controller candidates: (4, 4).
- Seed 15, section 4, room (20, 0), decision 2277, input 7389: qa-54: legal pending target absent from controller candidates: (5, 3).
- Seed 15, section 4, room (20, 0), decision 2277, input 7389: qa-54: legal pending target absent from controller candidates: (4, 4).
- Seed 15, section 4, room (20, 0), decision 2277, input 7389: qa-54: legal pending target absent from controller candidates: (5, 4).
- Seed 15, section 5, room (21, -19), decision 2357, input 7649: qa-54: legal pending target absent from controller candidates: (4, 1).
- Seed 15, section 5, room (21, -19), decision 2357, input 7649: qa-54: legal pending target absent from controller candidates: (4, 3).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (3, 4).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (2, 5).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (6, 5).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (1, 6).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (7, 6).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (2, 7).
- Seed 15, section 5, room (22, -14), decision 2564, input 8311: qa-54: legal pending target absent from controller candidates: (6, 7).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (3, 1).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (2, 2).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (4, 2).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (5, 5).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (2, 6).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (4, 6).
- Seed 15, section 5, room (23, -8), decision 2736, input 8926: qa-54: legal pending target absent from controller candidates: (3, 7).
- Seed 15, section 5, room (24, 0), decision 2860, input 9315: qa-54: legal pending target absent from controller candidates: (1, 3).
- Seed 15, section 5, room (24, 0), decision 2860, input 9315: qa-54: legal pending target absent from controller candidates: (6, 3).
- Seed 15, section 5, room (24, 0), decision 2860, input 9315: qa-54: legal pending target absent from controller candidates: (1, 4).
- Seed 15, section 5, room (24, 0), decision 2860, input 9315: qa-54: legal pending target absent from controller candidates: (2, 4).
- Seed 15, section 5, room (24, 0), decision 2860, input 9315: qa-54: legal pending target absent from controller candidates: (3, 5).
- Seed 16, section 3, room (16, 0), decision 1801, input 5561: qa-54: legal pending target absent from controller candidates: (4, 3).
- Seed 16, section 3, room (16, 0), decision 1801, input 5561: qa-54: legal pending target absent from controller candidates: (5, 3).
- Seed 16, section 3, room (16, 0), decision 1801, input 5561: qa-54: legal pending target absent from controller candidates: (5, 4).

### 3. Existing broad sweep has a mixed-input Settings expectation mismatch

Screen: title Settings / Restore confirmation; seed not applicable (title
fixture, followed by the existing depth-3/selected-1 debug profile).
Command: the broad navigation sweep below. It uses controller Restore, B, then
forces pointer mode, saves the old focus, directly opens confirmation and sends
a neutral left-X sample. It expects the earlier focus to remain. That expectation
already fails at this release HEAD. No assertion was rewritten.

Cause: `scripts/settings_panel.gd:528–545` immediately focuses confirmation when
it opens, before that neutral input. After the fixture cancels in pointer mode,
focus is empty. `scripts/main_menu.gd:227–230` consumes the next controller B to
seed focus, leaving Settings open. `:1152–1154` then returns focus from the
fixture's directly opened New Run panel to Settings, causing the two later
New Run assertions. This needs an owner-directed test/interaction reconciliation:
confirm the intended pointer confirmation seeding and switch-to-controller Back
contract, then repair the fixture or local behavior with focused coverage.
The initial mismatch and all cascading assertions are preserved below, rather
than counted as four new controller-only blockers.

Exact baseline result: `CONTROLLER SCREEN SWEEP: FAIL (4 findings)`:

- `Neutral joypad noise preserves pointer confirmation focus`
- `Settings B returns to title`
- `New-run setup initially focuses Begin Descent`
- `New-run immediate A/Enter begins the chosen depth`

Counterchecks: the existing isolated `--new-run-setup-only` run prints
`CONTROLLER SCREEN SWEEP: PASS (0 findings)`. The separate physical-only
`title_controller.gd` opens title Settings with A, opens Restore with A, uses B
twice, navigates to New Run and presses A twice; it prints
`TITLE CONTROLLER: PASS (0 findings)`. Thus the whole controller path does not
reproduce the mixed-input cascade. Its first development run used a fresh profile
and incorrectly expected an unlocked-depth picker; that diagnostic failed once,
was corrected to the existing depth fixture and is excluded from acceptance.
Its failed log remains retained as `evidence/title-controller.log`.

## Verification

- **new-run-isolated** (exit 0): `CONTROLLER SCREEN SWEEP: PASS (0 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/new-run-isolated.log`.
- **title-controller-depth** (exit 0): `TITLE CONTROLLER: PASS (0 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/title-controller-depth.log`.
- **tutorial** (exit 0): `CONTROLLER SCREEN SWEEP: PASS (0 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/tutorial.log`.
- **reward** (exit 0): `CONTROLLER SCREEN SWEEP: PASS (0 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/reward.log`.
- **dragon-parity** (exit 0): `DRAGON TARGET PARITY: target=(4, 2) controller=false visible=false controller_card_retained=true mouse_hit=(4, 2) committed_player=(3, 2)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/dragon-parity.log`.
- **skill-learn-before-focused** (exit 1): `REGRESSION SKILL_LEARN_FOCUS: FAIL` / `SWEEP FINDING: Learning returns focus from the disabled action to its selected skill` / `CONTROLLER SCREEN SWEEP: FAIL (1 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/skill-learn-before-focused.log`.
- **skill-learn-final** (exit 0): `REGRESSION SKILL_LEARN_FOCUS: PASS` / `CONTROLLER SCREEN SWEEP: PASS (0 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/skill-learn-final.log`.
- **python-default-handler** (exit 0): `ISOLATION AUDIT: 55 modules; /private/tmp/labyrinth_codex/qa-57/evidence/python-default-handler/isolation-audit.md` / `SELECTED MODULES: 19 of 55` / `Ran 183 tests in 32.122s` / `OK` / `PYTHON SUITE WALL: 32.122s; results: /private/tmp/labyrinth_codex/qa-57/evidence/python-default-handler`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/python-default-handler.log`.
- **ui-identity-final** (exit 0): `Ran 25 tests in 6.743s` / `OK`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/ui-identity-final.log`.
- **treasure-replay** (exit 0): `CONTROLLER HUNT: seed=14 outcome=replay_point inputs=1681 findings=1` / `RUN HUNT: seed=14 outcome=replay_point decisions=452`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/treasure-replay.log`.
- **treasure-reveal-probe** (exit 0): `TREASURE REVEAL BOUNDS: 180 samples, 0 overflow samples, native=false`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/treasure-reveal-probe.log`.
- **target-filter-final** (exit 0): `FILTER SELECTED: region=board selected=0 pending=[(4, 3), (5, 3), (4, 4), (5, 4), (2, 3)]` / `TARGET FILTER GAP: {"display":"stone","grid":"stone","mouse_hit":"(5, 3)","rendered":true,"tile":"(5, 3)","visible":false}` / `TARGET FILTER PROBE: 1 missing legal targets`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/target-filter-final.log`.
- **sweep-final** (exit 1): `REGRESSION SKILL_LEARN_FOCUS: PASS` / `REGRESSION HUD_REBUILD: PASS` / `REGRESSION ANALOG_VOLUME: PASS` / `REGRESSION ANALOG_SELECTION: PASS` / `SWEEP FINDING: Neutral joypad noise preserves pointer confirmation focus` / `SWEEP FINDING: Settings B returns to title` / `SWEEP FINDING: New-run setup initially focuses Begin Descent` / `SWEEP FINDING: New-run immediate A/Enter begins the chosen depth` / `CONTROLLER SCREEN SWEEP: FAIL (4 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/sweep-final.log`.
- **purge-return** (exit 0): `CONTROLLER SCREEN SWEEP: PASS (0 findings)`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/purge-return.log`.
- **python-audit** (exit 0): `ISOLATION AUDIT: 55 modules` / `SELECTED MODULES: 19 of 55`. Log: `/private/tmp/labyrinth_codex/qa-57/evidence/python-audit/isolation-audit.md`.

Both the pre-change and final broad sweeps reached **330/330 controls across
35 screens** and report the same four existing assertions. The final sweep also
prints `REGRESSION SKILL_LEARN_FOCUS: PASS`; HUD replacement, analog volume and
analog selection are all `PASS`. Logs:
`/private/tmp/labyrinth_codex/qa-57/evidence/sweep-baseline.log` and
`/private/tmp/labyrinth_codex/qa-57/evidence/sweep-final.log`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/godot_task_runner.py --task-id qa-57 --timeout 900 --stream -- godot --headless --path . --script tests/controller_screen_sweep.gd -- --navigation-only --output-dir /private/tmp/labyrinth_codex/qa-57/replays/sweep-fresh
```

The cold import exited 0 and retained the baseline macOS CA-certificate error
and duplicate placeholder UID warning. Campaign runtime diagnostics, including
transient rejected focus attempts during map/reward locks, are retained with
log file and line in `campaign.json`; these are not persistent focus failures.
The dragon fixture retains the existing anchor-size warning while loading.
Python could not update its optional learned timing cache in read-only Git
metadata; its observed test result is still `OK`. The UI identity static lint passes; its fresh native capture and independent
visual inspection remain director work under the explicit worker restriction.
No full suite, independent review, commit, publish, push or cleanup was attempted.

## Native inspection candidate: transient treasure glossary bounds

Seed 14, section 1, treasure room `(7, 1)`, after decision 452 (select the mystery
room from the section map). During entrance, the log reports
`Relic glossary above-row overflow: RelicChoice_venom_signet, viewport=(1920.0, 1080.0), block=(1260.0, 109.0), top=1003.0, row_top=1124.0`.
Cause: `scripts/card_focus_tooltip_stack.gd:298–325` calculates the above-row
fallback while the treasure row is still below the viewport; the backtrace
comes from `scripts/run_scene.gd:27770` during `_play_treasure_room_reveal`.
It happened once; later input and choices progressed. This is a diagnostic
candidate, not a visually confirmed persistent defect or controller parity gap.
No layout/timing value was changed. A separate owner-directed visual unit is
needed only if the native frame sequence confirms player-visible clipping.

A bounded seed-14 replay through decision 452 captures the actual pending offers;
`treasure_reveal_probe.gd` reloads that fixture, samples the live production
entrance and captures frames 1, 32, 180 at a diagnostic 60 FPS cap, plus the first observed overflow frame.
This supplemental fixture is excluded from whole-run totals. The captured
state reload completed 180 headless samples with zero overflow samples; this
does not reproduce the exact original entry timing or establish visual absence. The captured fixture is archived as `treasure-reveal.variant`; the
native command is in `treasure-proof-for-owner.sh`. Its 180 sample frames
and capture indices are diagnostic fields; no player-visible value is chosen.

The optional Python bytecode syntax check could not write to the ambient macOS
cache (`/Users/borgerding/Library/Caches/com.apple.python/private/tmp/labyrinth_codex`,
`PermissionError: [Errno 1] Operation not permitted`). The read-only AST check
passed for the four helpers; no cache permission or dependency was changed.

## Proof for the design owner

No windowed run was attempted: this worker has no macOS window-server access.
The updated focus probe, existing parity probe and proof contracts are ready at 1920×1080,
100% UI scale. Run these exact commands (also in `proof-for-owner.sh`):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/visual_probe_runner.py --task-id qa-57 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05b/combat_details-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-57/native/combat_details-manifest.json tests/controller_screen_sweep.gd -- --combat-only --capture-screen combat_details --output-dir /private/tmp/labyrinth_codex/qa-57/native/combat_details
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/visual_probe_runner.py --task-id qa-57 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05b/dragon-target-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-57/native/dragon-target-manifest.json /private/tmp/labyrinth_codex/qa-57/tools/dragon_target_parity.gd -- --fixture res://spec/peer_benchmark/qa/controller_hunt_2026-11-05/dragon-target.variant --output-dir /private/tmp/labyrinth_codex/qa-57/native/dragon_target
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/visual_probe_runner.py --task-id qa-57 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05b/skill_learn_focus-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-57/native/skill_learn_focus-manifest.json tests/controller_screen_sweep.gd -- --skill-learn-focus-only --capture-screen skill_learn_focus --output-dir /private/tmp/labyrinth_codex/qa-57/native/skill_learn_focus
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-57 && python3 tools/visual_probe_runner.py --task-id qa-57 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05b/treasure_reveal-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-57/native/treasure_reveal-manifest.json /private/tmp/labyrinth_codex/qa-57/tools/treasure_reveal_probe.gd -- --fixture res://spec/peer_benchmark/qa/controller_hunt_2026-11-05b/treasure-reveal.variant --output-dir /private/tmp/labyrinth_codex/qa-57/native/treasure_reveal
```

Expected, **not yet generated**, captures:

- `/private/tmp/labyrinth_codex/qa-57/native/skill_learn_focus/native_skill_learn_focus/skill_learn_focus_focus.png`
- `/private/tmp/labyrinth_codex/qa-57/native/combat_details/native_combat_details/combat_details_focus.png`
- `/private/tmp/labyrinth_codex/qa-57/native/dragon_target/dragon_target_controller.png`
- `/private/tmp/labyrinth_codex/qa-57/native/dragon_target/dragon_target_pointer.png`
- `/private/tmp/labyrinth_codex/qa-57/native/treasure_reveal/treasure_reveal_0001.png`, `treasure_reveal_0032.png`, `treasure_reveal_0180.png` (plus an overflow frame if seen)

Inspect the learned skill's restored node focus, the Details shortcut and the controller/mouse target
counterfactual. The contracts validate presence, size and nonblank content;
inspection remains necessary. No `inspection_fixture.py` command was requested;
fixture preparation remains director-owned.

## Chosen defaults and open issues

All choices are diagnostic fields; no player-facing design value was chosen.
The inherited hunt fields are Health 9,999, time scale ×8, eight settling frames,
400 decisions per fight, 50 unchanged fight decisions, 120 decisions per other
screen, 20 scene seconds without a decision, and random policy seed equal to
run seed. The physical adapter retains max FPS 240, three input-settling frames,
160 navigation steps, 640 analog samples, analog strengths 0.4–0.9, approach
distance 160, analog time scale 1, 2,400 animation-wait frames, a 40-step input
tail, 20 hand-cycle steps, six card-mode steps, four Chronicle scan steps, and
search mock text `fatigue`. Campaign fields are four processes, 3,600 seconds per
run and seeds 14–19 (plus any explicitly listed replacement attempts above).

The title countercheck uses named diagnostic fields: 1920×1080 proof size,
three settling frames, 160 navigation steps, unlocked depth 3 and selected depth
1 from the existing fixture. The inherited dragon diagnostic uses its captured
Hamstring Shot/target, eight settling frames, 120 mouse-settling frames, six mode
steps, 240 stick samples at 0.5 strength, six-pixel tolerance and an eight-pixel
mouse handoff offset. The Learn regression reuses seed 73491 and the existing
level-3 profile with Measured Breath, one Moltshard and Ghost Stride as its
initial navigation target; the currently inspected node is the learning target.
The treasure diagnostic uses a 60 FPS cap, 180 samples and capture frames
1, 32 and 180, plus its first observed overflow frame.
The target-filter diagnostic uses the existing boss-probe fixture at depth
16, Pale Spark, eight settling frames, a 240-frame readiness bound, six mode
steps and a 240 FPS diagnostic cap. The Purge handoff countercheck samples 16 frames after close, with a 2,400-frame
commit wait bound, reusing the hunt's 240 FPS / ×8 diagnostics and existing shop
fixture. Native command caps remain 600 seconds / 60 seconds startup.

**TODO_DESIGN placeholders: none.** Open issues are qa-54's targeting/tooltip
work, the broad mixed-input assertion mismatch, and native/hardware inspection (including the transient glossary candidate).
The sole new production finding is fixed here. Remaining known work is qa-54
and the mixed-input test reconciliation; native inspection may confirm or clear
the transient treasure candidate.
