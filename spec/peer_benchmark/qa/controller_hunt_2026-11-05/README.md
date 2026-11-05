# qa-51 controller-only run hunt

Six whole runs reached a normal end: five by Embrace and seed 10 by victory over
Noctyrax. Eight acceptance seeds (4–11) produced **12,267 decisions** and
**39,412 recorded controller input steps**. Seed 4 also reached Noctyrax and
exposed the shadow-targeting parity gap below; seed 6 stopped on the inherited
fight budget. All eight engine runners exited 0. Five small local bugs are fixed.
All changes are uncommitted; the design owner retains review and publication.

| Seed | Outcome | Decisions | Sections reached |
|---|---|---:|---|
| 4 | Targeting parity stall (raw outcome: softlock) | 2,423 | 0–5; Noctyrax entered at decision 2,339 |
| 5 | Embrace | 855 | 0–1 |
| 6 | Fight exploration limit | 759 | 0–1 |
| 7 | Embrace | 1,787 | 0–2 |
| 8 | Embrace | 2,680 | 0–5 |
| 9 | Embrace | 660 | 0 |
| 10 | Victory | 2,903 | 0–5; Noctyrax defeated |
| 11 | Embrace, including card-reward selection | 200 | 0 |

Extra seeds 12 and 13 were stopped after the acceptance criteria were met and
are excluded from these totals. Earlier development campaigns were canceled
when the movement mapping was corrected and are also excluded. A recorded button
step represents its press/release pair; each axis sample is one step.

## Acceptance criteria

1. **Driver and screen coverage met.** Six completed controller-only runs, two
   final-dragon entries and one final-dragon victory. Map, pre-battle, card modes,
   targeting, Pass, Details, Draw/Discard, turn order, card/relic/treasure rewards,
   shop purchase and purge, events, campfire, Camp/Pause, Grimoire and mocked
   search, Character's three tabs, all eight Settings rows, run end and Chronicle
   were exercised. Gear rewards occurred through seed 8's event results
   (`pilgrim_vestments`, `thornmail` and `patched_cloak`) and seed 10's `monks_wraps`;
   the gear inventory was also navigated. Production analytics record five buys,
   nine completed purges, four committed card rewards and six Chronicle opens.
2. **Detection met.** The oracle checks focus ownership/visibility/enabled state,
   active modal containment, reachable focus/cursor paths and bounded lack of
   progress. Input/result mismatches include the fixed Details action and the
   reported keyboard-only Details controller-tooltip copy. Headless checks establish input/state
   behavior; native visual evidence remains owner work.
3. **Report and reproductions met.** Findings below include screen, seed, input
   sequence and cause. `campaign.json` retains contexts and input tails linked to
   complete task-local streams; the portable dragon fixture and probe reproduce
   the late parity issue. `verification.json` records exact result lines.
4. **Small fixes and regressions met.** Five local fixes (two, two, two, one and
   three code lines respectively) have regressions in the existing controller
   sweep. The Python default group and UI identity gate pass. No full suites,
   peer review, commits, publication or windowed runs were performed.

The driver inherits qa-45's production hunt and its read-only decision policy.
It replaces dispatch with physical `InputEventJoypadButton` and
`InputEventJoypadMotion` events through `Input.parse_input_event`. It never
calls a gameplay handler, emits an action signal, grabs focus, advances a cursor
by calling a production process method, or installs a room fixture during a run.
The inherited initial Health override (9,999) remains diagnostic. Run creation,
profile/storage isolation and this override are setup, not controller input.
Only the explicitly requested Steam keyboard mock inserts text into the focused
Grimoire `LineEdit`; it delivers `fatigue` and the normal `text_changed` signal.
Steam+X belongs to Steam's compositor; real Deck keyboard delivery remains a
hardware inspection item.

The driver searches native focus links and the production board candidate graph,
then sends the required D-pad edges and A. Free-cursor room entry and candidates
outside that graph use closed-loop left-stick events. Cards use X/R1/A, their
printed mode, the wanted board target, and the preview player's tile for final
confirmation. Pass uses Y; menu uses Start; map uses View; back uses B. The
existing policy chooses room, combat, reward, shop and event actions. No layout,
wording, tuning, artwork, analytics schema or save format changes are made.

## Reproduce

The authoritative input streams and execution logs are in
`/private/tmp/labyrinth_codex/qa-51/evidence/campaign-acceptance/<seed>/`.
`command.json` records the exact launch; `inputs.jsonl` records every physical
button or axis sample, with the pre-input focus and run context. Policy trace
rows can contain an unused mouse-event argument from qa-45's offer descriptions;
the adapter never injects it. The physical stream is the input evidence. The tool and fixes evolved during
execution: seeds 4–7 used the earlier purge-offer inventory, seeds 8–10 used the
active confirmation scope, and seed 11 added activated CardWidget offers. The
archived current driver therefore need not repeat historical choices exactly.
The captured dragon fixture is the portable reproduction for the late finding.

Restore task-local tools if needed (the `.txt` copies are outside Godot's script
inventory):

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 - <<'PY_RESTORE'
from pathlib import Path
import shutil
source = Path('spec/peer_benchmark/qa/controller_hunt_2026-11-05/proof-sources')
destination = Path('/private/tmp/labyrinth_codex/qa-51/tools')
destination.mkdir(parents=True, exist_ok=True)
for item in source.glob('*.txt'):
    shutil.copyfile(item, destination / item.name.removesuffix('.txt'))
PY_RESTORE
```

Use fresh output paths; the original evidence must remain intact. For a focused
physical replay through the first reward:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/godot_task_runner.py --task-id qa-51 --timeout 900 --stream -- godot --headless --path . --script /private/tmp/labyrinth_codex/qa-51/tools/controller_hunt.gd -- --seed 4 --no-embrace true --stop-after 40 --output-dir /private/tmp/labyrinth_codex/qa-51/replays/seed-4-reward-1
```

For another whole campaign, import `run_acceptance.py`, set its `EVIDENCE` to a
fresh absolute directory, and map its `run` function over `SEEDS` using its
`PROCESS_LIMIT` (4). `run(10)` supplies the replacement for seed 6's bounded
exploration stop; `run(11)` adds the repaired CardWidget offer inventory. The
archived collector documents the counted acceptance seeds. Use fresh evidence
paths for every replay.

## Findings fixed here

1. **Tutorial Skip was absent from controller candidates.** Seed 4, first fight,
   tutorial's first forced action: the mouse could press **Skip Tutorial**, while
   controller candidate enumeration returned the permitted tile and Menu only.
   The original controller replay stalled on that available mouse action. The
   two-line fix includes the visible prompt's existing focusable controls before
   the guided header filter in `scripts/run_scene.gd:3143`. Regression:
   `tests/controller_screen_sweep.gd` with `--tutorial-navigation-only` navigates
   to the existing Skip control, presses A, and checks the tutorial ends.
2. **Pile modal leaked focus to its HUD opener.** Seed 4, first fight after Skip:
   move to Draw, A; focus remains on `PilesBar/DrawPile` behind `PileScrim`.
   Discard does the same. Both the fresh and cache-hit branches of
   `_open_pile_view` omitted the modal refresh. Two added calls reuse the existing
   modal recovery at `scripts/run_scene.gd:29119` and `:29171`. The existing combat
   sweep opens each pile twice and checks focus belongs to the modal.
3. **A could not toggle Details.** Seed 4, first fight after Skip: move to DETAILS,
   A; `_show_all_enemy_intents` stays false. Custom controller activation emitted
   only `pressed`, while Details listens to `toggled` (`run_scene.gd:12243`).
   The two-line activation fix at `run_scene.gd:3308` updates toggle state first,
   preserving ButtonGroup unpress rules. The existing combat sweep checks A
   enables Details and A restores its prior state.
4. **Reward reveal ended without controller focus.** Seed 4, first fight's reward
   (decision 34 in the retained audit): `intro_pending`, reveal and animation
   locks are all clear, Skip & Recover is enabled, and no control has focus.
   `_finish_reward_intro` restored interaction but omitted focus recovery. The
   one-line fix at `run_scene.gd:15585` schedules the existing controller modal
   refresh. `--reward-focus-only` checks focus appears after completion without
   another navigation event. The physical-input replay through decision 40
   retains only the separate menu finding after this fix.


5. **Unaffordable multi-card gear could not enter its card navigator.** Seed 4,
   section 0 Scavenger, decision 292: select Witchglass Aegis while Buy is
   disabled, then try its previous-card arrow. A stayed on the shelf; traversing
   other offers changed the selection and hid the navigator. The three-line
   change in `scripts/scavenger_shop_view.gd:1204` keeps the existing affordable
   trade action and enters the existing previous-card control when Buy is
   disabled. The existing shop sweep uses zero Embers, presses A on that gear,
   and checks A can turn its granted card without changing wares.

Before/after cases live under `/private/tmp/labyrinth_codex/qa-51/evidence/`:
`smoke2`, `tutorial-fix`, `aux-final`, `aux-after-fixes`, `reward-audit`,
`reward-after`, `combat-fixes`, and `reward-fix`. Each hunt has `inputs.jsonl`,
`trace.jsonl`, `controller.json` and `summary.json`. Input indices in findings
bind the short reproduction tail to the complete physical sequence.

## Needs a unit


**Noctyrax shadow targeting differs between pointer and controller.** Seed 4,
section 5, room `(24, 0)`: the final dragon was entered at decision 2,339. Later
select Hamstring Shot, choose its printed action, and try to target `(4, 2)`.
The tile is a legal pending target but absent from controller candidates; the
hunt eventually records 50 unchanged decisions (2,423 total). The preserved save
reproduction starts at player `(3, 3)`. A real stick moves to the target and A
leaves the player and held card unchanged. A real mouse click hits `(4, 2)`, consumes
Hamstring Shot and commits movement to `(3, 2)` under Umbra's movement rules.
`CombatBoardView.controller_navigable_tiles` excludes tiles outside
`umbra_visible_tiles` (`scripts/combat_board_view.gd:4316`), whereas its pointer
hit test (`:16576`) accepts the rendered polygon; RunScene accepts that legal
pending target (`scripts/run_scene.gd:21701`). This needs a separate unit to
restore targeting parity while preserving the Umbra information boundary; simply
removing the visibility gate risks exposing hidden content. It is outside the
small local focus repairs and touches protected renderer/navigation policy.
This is a capability gap and policy stall, not proof that every controller
strategy is blocked: seed 10 defeated Noctyrax. The separate mouse counterfactual
is excluded from whole-run input evidence. Fixture: `dragon-target.variant`;
probe and native command are below.


**Camp/Pause opens without focus.** Seed 4, after the opening dialogue, close the
map with B and press Start. MenuScrim has enabled Character, Grimoire, Settings
and Close actions but no focus. One D-pad event establishes focus; this is not a
run blocker. `scripts/modal_menu_focus.gd:58` restores a remembered page only and
`handle_input` seeds a fresh page on its next input. This behavior is expressly
asserted in `tests/utility_ui_layout_probe.gd:334` (first A focuses without
activation). A separate owner-directed unit should reconcile the desired initial
controller focus with that existing first-press contract and cover Camp, Pause,
Settings and return focus together. This unit preserves that assertion.

**Existing portrait rebuild regression fails.** The baseline controller screen
sweep reports `Y preserves the focused unit's replacement portrait` and a missing
`turn_order_actor_key` metadata error. Its fixture takes `.back()` from
`TurnOrderSlots.controller_controls`, which appends the Details button after
portraits (`scripts/turn_order_slots.gd:18`); it therefore asks Details for an actor
key. The separate unit should select a real actor-bearing portrait in the
fixture, reproduce any remaining post-Pass focus loss, and repair that behavior
with its own proof. The existing assertion and fixture are preserved here.


**Details controller tooltip retains a keyboard shortcut.** Seed 4, first
fight: focus Details with the controller. The actual button correctly hides its
I glyph (`scripts/combat_hud_intents.gd`, `_refresh_key`); its native Button text
is transparent. Its tooltip still says `Show every enemy's full plan [I]`
(`scripts/run_scene.gd:21888–21890`). Controller focus forwards that text through
`controller_focus_candidates.gd` to the analog cursor's rendered detail panel
(`controller_analog_cursor.gd:112`). The dragon fixture records the glyph hidden
and this controller-tooltip string together. A follow-up copy unit should use
owner-approved controller shortcut wording and preserve the keyboard tooltip.
Text changes are outside this unit; the `combat_details` native command supplies
owner proof. This finding concerns the tooltip, not the already-correct button.

Early card-movement choices were routed through ordinary movement rather than
the policy target. Those campaigns were canceled and excluded from acceptance;
the corrected campaign maps both card movement and selected ordinary movement
directly to their offered target. The initial driver also recorded unreachable piles while the forced tutorial
was active, and D-pad-only free-room initialization failures. These are driver
limitations, not player access bugs: the tutorial intentionally blocks pile use,
and free-room entry requires stick movement. Corrected driver revisions defer
combat inventory until Skip and use left-stick events to initialize free space.
Purge offers initially included list controls behind the confirmation; focus
correctly stayed in the confirmation. The adapter now enumerates only its active
`focus_scope()`, preserving the inherited browse budget. Those unreachable
covered targets are oracle artifacts, not leaked focus. The inherited policy also omitted `CardWidget.activated` actions because its
BaseButton branch returned first (`tools/run_hunt_policy.gd:166`). The adapter
repairs that offer inventory; seed 11 took four card rewards through controller
input. The unmodified base policy and the adapter difference are archived. The first Settings diagnostic raised a driver-only Dictionary-to-Control type
error; its coordinator was canceled (exit 130), corrected, and rerun. Raw logs
are retained instead of treating these attempts as completed runs.

## Proof for the design owner

No windowed command was attempted: the worker has no macOS window-server access.
The following captures use the existing fixed 1920×1080 SubViewport, 100% UI scale
and approved assets. Inspect the focused Skip button, the pile modal's focus,
Details with full plans enabled, focus after reward reveal, and the unaffordable
gear card navigator. Contracts check
image presence, dimensions and nonblank content; they do not replace inspection.
No inspection-fixture command was requested; fixture preparation is owner-owned.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/visual_probe_runner.py --task-id qa-51 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05/tutorial_skip-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-51/native/tutorial_skip-manifest.json tests/controller_screen_sweep.gd -- --tutorial-navigation-only --capture-screen tutorial_skip --output-dir /private/tmp/labyrinth_codex/qa-51/native/tutorial_skip
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/visual_probe_runner.py --task-id qa-51 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05/pile_focus-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-51/native/pile_focus-manifest.json tests/controller_screen_sweep.gd -- --combat-only --capture-screen pile_focus --output-dir /private/tmp/labyrinth_codex/qa-51/native/pile_focus
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/visual_probe_runner.py --task-id qa-51 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05/combat_details-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-51/native/combat_details-manifest.json tests/controller_screen_sweep.gd -- --combat-only --capture-screen combat_details --output-dir /private/tmp/labyrinth_codex/qa-51/native/combat_details
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/visual_probe_runner.py --task-id qa-51 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05/reward_focus-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-51/native/reward_focus-manifest.json tests/controller_screen_sweep.gd -- --reward-focus-only --capture-screen reward_focus --output-dir /private/tmp/labyrinth_codex/qa-51/native/reward_focus
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/visual_probe_runner.py --task-id qa-51 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05/shop_unaffordable-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-51/native/shop_unaffordable-manifest.json tests/controller_screen_sweep.gd -- --scavenger-links-only --capture-screen shop_unaffordable --output-dir /private/tmp/labyrinth_codex/qa-51/native/shop_unaffordable
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-51 && python3 tools/visual_probe_runner.py --task-id qa-51 --no-headless --display-driver macos --audio-driver Dummy --timeout 600 --startup-timeout 60 --expect-size 1920x1080 --proof-contract spec/peer_benchmark/qa/controller_hunt_2026-11-05/dragon-target-proof-contract.json --result-manifest /private/tmp/labyrinth_codex/qa-51/native/dragon-target-manifest.json /private/tmp/labyrinth_codex/qa-51/tools/dragon_target_parity.gd -- --fixture res://spec/peer_benchmark/qa/controller_hunt_2026-11-05/dragon-target.variant --output-dir /private/tmp/labyrinth_codex/qa-51/native/dragon_target
```

Expected PNGs:

- `/private/tmp/labyrinth_codex/qa-51/native/tutorial_skip/native_tutorial_skip/tutorial_skip_focus.png`
- `/private/tmp/labyrinth_codex/qa-51/native/pile_focus/native_pile_focus/pile_focus_focus.png`
- `/private/tmp/labyrinth_codex/qa-51/native/combat_details/native_combat_details/combat_details_focus.png`
- `/private/tmp/labyrinth_codex/qa-51/native/reward_focus/native_reward_focus/reward_focus_focus.png`
- `/private/tmp/labyrinth_codex/qa-51/native/shop_unaffordable/native_shop_unaffordable/shop_unaffordable_focus.png`

The dragon command captures controller targeting first and then runs its
separate mouse counterfactual. Expected files are
`/private/tmp/labyrinth_codex/qa-51/native/dragon_target/dragon_target_controller.png`
and `dragon_target_pointer.png` in the same directory.

## Verification and retained diagnostics

- Tutorial, combat/pile/Details, reward-focus and shop focused runs each print
  `CONTROLLER SCREEN SWEEP: PASS (0 findings)`.
- `GUIDED COMBAT TUTORIAL INTEGRATION TEST: PASS`.
- Python default group: `Ran 182 tests in 37.483s` / `OK` (19 modules).
- UI identity: `Ran 25 tests in 5.976s` / `OK`.
- Isolation audit: `ISOLATION AUDIT: 55 modules`. No new Python test module.
- The pre-change broad sweep reached 330/330 controls across 35 fixture screens
  and printed `CONTROLLER SCREEN SWEEP: FAIL (1 findings)` for the existing
  portrait fixture issue described above. Its assertion was not rewritten.
- Portable dragon reproduction: `DRAGON TARGET PARITY: target=(4, 2)
  controller=false visible=false controller_card_retained=true mouse_hit=(4, 2) committed_player=(3, 2)`.

The cold import exited 0 and retained the baseline macOS CA-certificate error and
duplicate placeholder UID warning. Counted runs contain no GDScript errors.
They retain rejected focus attempts during reward/section-map input locks:
`section_map_panel.gd:1100`, `run_scene.gd:3529`, and the recursive map focus lock
in `section_transition.gd:364`. Every subsequent map handoff progressed; these
warnings are not counted as persistent lost-focus findings. Seed 6's bounded
shutdown retained an ObjectDB warning (`core/object/object.cpp:2641`); ownership
was not resolved in this focus unit. The dragon fixture emits an existing anchor
sizing warning while loading (`run_scene.gd:5063`), with no script error.
Python could not update the optional timing cache in read-only Git metadata;
its test result is still the observed `OK`. Raw markers and locations remain in
`campaign.json` and task-local logs.

## Chosen defaults

All choices below are test/diagnostic fields; no player-visible design value was
chosen. The initial Health 9,999, scene time ×8, fight bound 400 decisions,
unchanged-state bound 50 decisions, screen bound 120 decisions and eight-frame
inherited settling are qa-45 defaults. New physical-input settling is 3 frames;
D-pad path bound is 160, analog bound 640 samples, analog navigation uses time
scale 1, and animation/presentation waiting is bounded at 2,400 frames. The acceptance
driver uses a 240 FPS diagnostic cap (early discarded diagnostics used 120 FPS).
Whole-run processes have a 3,600-second cap; each counted run finished inside it. The acceptance campaign uses four workers: seed 4 declines Embrace and seeds
5–11 retain the existing default terminal-choice policy. Earlier diagnostic
campaigns are retained separately and excluded from acceptance totals. Search mock text is `fatigue`.
Native proof allows 600 seconds total and 60 seconds startup per case. Named
bounds also retain 40 input steps, allow 20 hand-cycle and 6 card-mode steps,
and inspect Chronicle with 4 directional steps. Analog steering uses maximum
strength 0.9, minimum 0.4 and an approach distance of 160 screen units. The
separate dragon diagnostic settles 120 frames after its mouse counterfactual
and uses an 8-pixel relative motion sample only to establish pointer modality.
Its controller attempt allows 240 stick samples at strength 0.5 with a 6-pixel
arrival tolerance; these are named diagnostic fields.

The added shop regression uses `UNAFFORDABLE_SHOP_EMBERS = 0` and existing
`witchglass_aegis`, `boiled_leather`, and `crimson_draught` stock as debug-only
fixture data. There are no new TODO_DESIGN placeholders or assets. Existing narration
placeholders in other units are untouched. The director owns commits, review,
inspection and publication; none were attempted by this worker.
