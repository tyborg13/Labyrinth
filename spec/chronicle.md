# Chronicle

Implementation contract: `meta-02`, standard risk (additive profile fields).
Authority: [unit brief](peer_benchmark/briefs/meta-02.md), approved Chronicle
mockup and its HTML. The brief's 1800×860 frame at (60, 110), detail title-row
score, and unnumbered FEATS label take precedence over the mockup.

## Records and persistence

`ChronicleRules` owns record construction, path bookkeeping, lifetime aggregation
and formatting. `ProgressionStore` owns durable profile fields:

- `chronicle_records`: newest first, at most 50 records.
- `chronicle_totals`: uncapped `runs`, `escapes`, `best_score`, `dragons_slain`;
  optional `deepest_depth` appears only after a run with `umbra_depth` metadata.
  Only victory can raise the deepest escaped depth.
- `chronicle_completed_ids`: uncapped run-result receipts, including dropped
  records, so terminal replay cannot increment totals after the history cap.

Every record contains the brief's run ID, outcome, local date, elapsed play time,
section and room position, optional Umbra Depth, score, feats, killer text,
entered path, section dragon IDs, final equipped gear, compiled deck counts in
first-occurrence deck order, and relic IDs. Two additive internal fields preserve
`section_names` for path labels and `dragons_slain` for lifetime aggregation.

New runs initialize `chronicle_path` at the threshold. Both room-entry transitions
append after mystery resolution. Events keep `event`; a mystery that reveals a
fight, merchant, relic room or Hearth records the revealed kind. Thresholds do
not become icons. Preparation/Begin do not append a second combat room. The
active path, section names and dragon IDs use the ordinary run-save dictionary.

Existing terminal adapters request `RunEngine.run_result_id(terminal)` before
passing their score-only metrics to `record_run_result`. That call stages a
bounded, process-local Chronicle snapshot under the unchanged result ID; the
store copies it into the same profile transaction as the result and score.
This also covers `RunEndRecapOverlay.embrace_state`. No save or analytics write
happens at staging. A resumed terminal state stages its snapshot again; durable
receipts decide whether it has already been recorded. Explicit run-state callers
of `record_run_result` can build the record directly.

Old profiles gain empty history and zero lifetime totals during ordinary
normalization. Stored pre-Chronicle results are never promoted to records.
Resumed pre-Chronicle runs lack the path marker and do not create partial records.
Malformed history rows are ignored. Profile currency, old result ledgers, scores,
analytics delivery and run saves retain their existing contracts.

## Presentation and input

The menu creates Chronicle between New Game and Settings with the existing
Obsidian slab style, 78 px height and 14 px gap (92 px pitch). Existing node names
remain intact. Opening hides the menu actions; closing restores Chronicle focus.

`chronicle_panel.gd` draws the shared major-dialog gilded frame and reuses the
Crumble fonts, palette, section-map icons, approved equipment/relic textures,
tooltip panels, equipment card preview widgets, controller prompts and menu
open/close/focus sounds. The list, empty state, result colours, detail score,
path medallions and build columns follow the brief. Long paths wrap after 16
icons; gear/relic icons wrap; the detail container keeps long builds accessible.
Every circular room slot clips its approved texture two pixels inside its ring,
including the 44 px dragon slot; square gear/relic slots keep their existing fit.
Spell entries wrap at their 17 px font width, retain ×N counts, and reserve the
eighth line for `+<k> more` when the complete deck exceeds eight lines.

Mouse wheel uses the native history scroller. Up/Down and D-pad select a row;
left-stick vertical threshold crossings select a row; LB/RB page by visible row
capacity. Native focus navigation reaches room, gear and relic icons, whose
tooltips also open on focus. Esc, B and the close button return to Chronicle on
the menu. Controller prompts read Select / Back.

Opening emits the single additive `chronicle_opened` analytics event described
in [analytics](analytics.md). Preview/probe opens may suppress that event.

## Acceptance and headless proof

1. Defeat, victory and embrace each produce one durable record. The suite exercises
   direct store calls and the unchanged production terminal adapters, repeat
   completion, profile reload and active path reload.
2. Lifetime runs, escapes, best score, dragons and optional deepest escaped depth
   remain correct through 58 completions and the 50-record cap; replay of a dropped
   result remains idempotent after profile reload.
3. The headless UI test checks panel geometry, menu pitch/order, empty copy,
   selection, scrolling width, equipment tooltip previews, keyboard/controller
   navigation, paging, focus restoration and the analytics emitter. Visual fidelity
   requires the fresh real-renderer proof below.
4. Old profiles, stored results without Chronicle records, resumed old runs and
   malformed rows are safe. Killer/subline/deck-overflow formatting is tested.

Run focused checks and the full suite through the task runner:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/godot_task_runner.py --task-id meta-02 --stream -- godot --headless --path . --script tests/chronicle_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/godot_task_runner.py --task-id meta-02 --stream -- godot --headless --path . --script tests/run_score_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/godot_task_runner.py --task-id meta-02 --stream -- godot --headless --path . --script tests/run_end_recap_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/godot_task_runner.py --task-id meta-02 --stream -- godot --headless --path . --script tests/main_menu_input_test.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/godot_task_runner.py --task-id meta-02 --timeout 1800 --stream -- godot --headless --path . --script tests/run_tests.gd
```

The original full suite remains owner-maintained. Registering the new extracted
suite in `tests/run_tests.gd` is a follow-up outside this unit's owned files:
preload `tests/suites/chronicle_suite.gd`, then call `ChronicleSuite.run(_assert)`.
The focused entry point already runs that entire suite.

Observed headless result lines (12 Oct 2026):

| Check | Result |
| --- | --- |
| Chronicle suite and UI/input integration | `CHRONICLE TEST RESULT: PASS` |
| Run score | `RUN SCORE TEST RESULT: PASS` |
| Full Godot suite, final runtime implementation | `TEST RESULT: PASS` |
| Chronicle probe parser, `--check-only` | Exit 0; no capture |
| Icon identity policy | `Ran 6 tests` / `OK` |
| Run-end recap | `RUN END RECAP TEST RESULT: FAIL (7 failure(s))` |
| Menu resume safety | `TEST RESULT: FAIL — 4 main menu resume safety failure(s)` |
| Menu first-click input and startup transitions | `TEST RESULT: PASS — main menu input and startup transitions` |

The seven run-end and four resume failures reproduce against unchanged HEAD
copies of the three modified runtime scripts. Their assertions were preserved.
An earlier run-end attempt also intermittently failed recovery-marker placement;
the final run matches the seven baseline failures. Run-end assertions still
expect the older recap layout/copy/font and death-frame count. Resume assertions
expect immediate replacement/reset while the existing transition stages the
replacement asynchronously. Director feedback explicitly adds the menu-input
fixture to this unit's scope: it now traverses Continue, New Game, Chronicle,
Settings, Quit. Its original focus, pointer, Settings and transition assertions
remain intact; the added Chronicle step also checks focus and molten selection.

No windowed probe was attempted. The initial full-suite run hit the default
300-second runner timeout during existing animation checks; subsequent 1800-second
runs completed with PASS. `git diff --check` and proof-contract JSON validation
also passed. Existing engine certificate/resource-cleanup messages still appear
in headless logs.

## Proof for the design owner

No windowed process can run in the implementation sandbox. Run these commands on
a machine with window-server access, inspect every image at native resolution,
and retain the emitted manifest. The probe renders into a 1920×1080 SubViewport
with UPDATE_ALWAYS, captures that texture independently of native Retina window
resolution, and asserts 100% UI scale. It captures the menu, seven-record Chronicle, empty state,
victory, 30-spell overflow and controller focus. It checks semantic selection,
score, overflow and focus restoration before reporting its result.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/visual_probe_runner.py --task-id meta-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/chronicle_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/meta-02-chronicle-feedback-1.json tests/chronicle_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/visual_probe_runner.py --task-id meta-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/main_menu_branding_probe_contract.json tests/main_menu_branding_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/visual_probe_runner.py --task-id meta-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tests/main_menu_umbra_button_probe_contract.json tests/main_menu_umbra_button_probe.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/meta-02 && python3 tools/visual_probe_runner.py --task-id meta-02 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/main_menu_resume_probe.gd
```

Chronicle image paths are `user://probes/chronicle/1920x1080/{main_menu,chronicle,
empty,victory,spells_overflow,controller_focus}.png`; the runner's manifest records
their absolute task-isolated locations. No capture has been generated by the
implementation engineer. Inspection-fixture preparation and publication belong
to the design owner; this unit brief does not request a fixture-helper command.
The director inspected the initial captures and accepted the presentation, then
requested the fixed-size capture target and circular texture clipping. Fresh
captures of those corrections remain director-owned proof.

## Open design fields and chosen test defaults

The fallback constants `TODO_DESIGN_UNKNOWN_KILLER`,
`TODO_DESIGN_UNKNOWN_INTENT`, `TODO_DESIGN_TRAP_NAME`,
`TODO_DESIGN_SURFACE_NAME`, and `TODO_DESIGN_SECTION_NAME` remain explicit when
the underlying run metadata supplies no approved name. Normal named enemy,
fatigue, elemental trap, surface, victory and embrace records use approved copy.

Debug-only defaults: fixture seed 8821; isolated named test/probe storage paths;
55 additional completions for cap/replay proof, 15 rows for scrolling proof,
and an 80 px formatting-test width to exercise spell overflow deterministically;
four settle frames before each capture and one hover-settle frame before native
pointer press/release; a 1800-second full-suite timeout after
observing the suite exceed the default 300 seconds. Probe build icons use current
production starter gear and the seven named production relic IDs in the probe.
The circular clip's named `CIRCLE_SEGMENTS` reuses the existing ring's 64-segment
tessellation; its two-pixel inset comes directly from director feedback.
The mockup's illustrative Cinderburst, Frost Lance and Glacier Step entries are
debug fixture IDs, displayed by their approved mockup names; production records
always use their actual compiled deck IDs. Remaining fixture paths/outcomes are
named fields in the probe, with the seven dates/scores/depths from the mockup.
