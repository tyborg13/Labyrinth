# rd-08 feedback 1: remove enemy hover tooltips

The Sealbinder information gap recorded in this historical round is resolved by
[the owner’s feedback 2 decision](FEEDBACK2.md): its existing countdown chips now
use the exact rules text through the shared fixed-status tooltip path. The code
placeholder is removed.

Changes remain uncommitted. No native/windowed run, peer review or full suite
was performed. Existing certified saves and approved assets are unchanged.

## Requirements and implementation

1. Removed rd-04's enemy summary builders and pointer/controller dispatch. Body,
   footprint and compact-disc hover no longer append an enemy name/Health/intent
   panel. Enemy rail rows return empty tooltip text, including controller rail
   details. The Marked leader popup registrations and specialized Sealbinder
   hover popup are removed. This applies under both health-bar settings.
2. All hover ownership and rendering remain in place: plate, disc unfurl, focused
   title, rail highlight, isolation, move preview and outlines. Enemy rail controls
   remain controller-navigable independently of whether they have tooltip text.
   The integration proof checks these alongside tooltip absence.
3. Canonical floor/terrain/prop and fixed-status tooltips retain their paths,
   including rd-03's choosing gate. An enemy can overlap one of those legitimate
   inspectors; the proof validates every returned ground-stack entry against the
   canonical floor/prop data rather than forbidding those preserved panels.
   Hero rail tooltips, card tooltips, Grimoire, Details and briefing code remain
   unchanged. Details continues to show full plans and status-token explanations.
4. The leader cue already exists elsewhere: the combat objective HUD uses the
   objective title and live named leader/Health (`combat_objective_hud.gd`,
   `set_combat_state` and `_live_detail`); its objective tooltip states
   `Defeat the marked leader. The rest flee.` The pre-fight objective repeats that
   same rule through the `pre_battle_view.gd` objective header; each leader card keeps
   its `PreBattleLeaderLabel` reading `LEADER`. Warband objectives explicitly say
   that killing the captain makes the rest flee. The board's existing leader
   crest and floor beacon remain visible. No `TODO_DESIGN_leader_cue` is needed.
   A separate uncovered case is recorded below for Sealbinders.
5. Updated rd-04's dragon proof and rd-08's integration proof to check no enemy
   tooltip, retained floor details, plate and unfurled disc for every dragon
   footprint tile under both settings. rd-08 also checks body/disc/rail/controller
   paths and retained controller rail navigation.

Removing the old tooltip queries exposed an rd-04 hit-test bug: `enemy_at_point`
called `reverse()` on the board's shared retained unit array. It now reverses an
explicitly typed copy. This prevents a read-only query from changing actor order;
the integration proof asserts that the shared roster remains identical. The
original rd-07 status-coverage assertion passes unchanged with this correction.

## Observed proof

Logs: `/private/tmp/labyrinth_codex/rd-08/feedback1/`.

| Check | Exact result | Log |
|---|---|---|
| Integration | `RD08 INTEGRATION: PASS (5199 checks, 0 failures)` | `integration-final.log` |
| rd-04 overlap | `RD04 THREAT ISOLATION: PASS (2147 checks, 0 failures)` | `rd04-overlap-final.log` |
| rd-04 Zekarion | `RD04 THREAT ISOLATION: PASS (1852 checks, 0 failures)` | `rd04-zekarion-final.log` |
| rd-04 Vyraketh | `RD04 THREAT ISOLATION: PASS (1868 checks, 0 failures)` | `rd04-vyraketh-final.log` |
| rd-07 board UI | `RD07 BOARD UI: PASS (153 checks, 0 failures)` | `board-ui-final.log` |
| Board tile tooltips | `BOARD TILE TOOLTIPS: PASS checks=217 failures=0` | `board-tooltips.log` |
| Hover | `RD08 HOVER: PASS (52316 checks, 0 failures)` | `hover-final.log` |
| Python default group | `Ran 189 tests in 28.116s`; `OK` | `python-default.log`; 20 modules |
| UI identity lint | `Ran 25 tests`; `OK` | `ui-lint.log` |
| Godot sidecars | `Ran 19 tests in 2.430s`; `OK` | `sidecar-tests.log` |
| Python resource audit | `ISOLATION AUDIT: 56 modules` | `python-audit.log` |
| Owner launch tools / contracts | `RD08 OWNER TOOLS: PASS (syntax, contracts, profile seeds once; Steam source unchanged)` | `tools-check.log` |
| Enemy still setup | `RD08 CAPTURE SETUP: PASS (overlap, 1 samples, headless; no images)` | `capture-enemy-final.log` |
| Zekarion still setup | `RD08 CAPTURE SETUP: PASS (zekarion, 1 samples, headless; no images)` | `capture-zekarion-final.log` |

The initial integration proof incorrectly rejected allowed neighboring trap/prop
panels. Its final assertion validates canonical ground entries and exact status
text while rejecting enemy summaries. The original failed logs are retained.
The Python suite reports the expected optional timing-cache write permission
failure under read-only Git metadata, after its successful test result.
No assertion for a pre-existing master failure was changed.

## Proof for the design owner: two stills only

These commands were not run windowed. Both use the real certified cases, approved
cel assets, Metal/mobile, 1920x1080, 100% UI scale and a 300-second probe timeout.
The launcher rejects logs containing `Cel look variant unavailable`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all sh tools/rd08/proof_for_owner.sh hover-enemy
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all sh tools/rd08/proof_for_owner.sh hover-zekarion
```

Expanded commands:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/rd08/capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd08/enemy_hover_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-08/feedback1/native-overlap.json -- --case overlap --hover-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rd-08 && LABYRINTH_CEL_LOOK=all python3 tools/visual_probe_runner.py tools/rd08/capture.gd --task-id rd-08 --godot "$PWD/tools/rd08/native_capture.sh" --no-headless --display-driver macos --audio-driver Dummy --rendering-driver metal --rendering-method mobile --fallback-rendering-driver metal --timeout 300 --expect-size 1920x1080 --proof-contract tools/rd08/zekarion_hover_contract.json --result-manifest /private/tmp/labyrinth_codex/rd-08/feedback1/native-zekarion.json -- --case zekarion --hover-only
```

Expected files:

- `/private/tmp/labyrinth_codex/rd-08/feedback1/stills/overlap/03_enemy_hover.png`
- `/private/tmp/labyrinth_codex/rd-08/feedback1/stills/zekarion/11_zekarion_hover.png`

Each directory also contains `semantics.json`, including tooltip-at-pointer,
plate opacity, intent layouts, isolation and x-ray state. Current headless
metadata certifies setup only; no new PNG or pixel inspection is claimed.
The previous release app predates this feedback; the source play command in
README uses the updated code.

## TODO_DESIGN / chosen defaults / open issues

`TODO_DESIGN_sealbinder_cue` records a separate unique-information gap. A
Sealbinder's removed popup was the only display of its exact rules: killing it
keeps its door open and open doors pay Embers when escaping. Its countdown chips
remain, but do not explain those rules. A named placeholder in
`board_threat_isolation.gd` records the owner decision; no replacement cue or
new wording was invented. The existing `SnareRules.seal_tooltip` data formatter
is retained so the owner can place the exact text on an approved surface.

No player-visible defaults were chosen. The new still mode reuses the existing
certified scenes, pointer targets, settling frames, 0.25-second plate settlement
and 0.8-second tooltip wait. New files are tooling/proof files only; no art,
icons, fonts, audio, gameplay, save or analytics values changed. Native inspection
and the Sealbinder cue destination remain owner work.
