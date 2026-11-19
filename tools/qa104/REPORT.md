# qa-104 · RD08 hover and PTF07 Pass forecast

Verified on `codex/qa-104` at release base `e5a6d3f53` with the test changes in this worktree. All seven failing assertion labels are stale. Together they accounted for 801 assertion failures across the two checks. Both focused checks now pass.

## First-parent bisect

Ran the original checks against historical source snapshots inside the task worktree, using its existing Godot import cache and the task runner. The first bad commit in each range was verified against its immediate first parent. Logs are under `.godot/qa-104/` as `<revision>-rd08.log` and `<revision>-ptf07.log`.

| Check | Other first-parent probes, in release order | Last good, exact result | First bad, exact result |
| --- | --- | --- | --- |
| RD08 hover | `b23826c3a` pass, `7007270c0` fail, `e5a6d3f53` fail | `648a58e4d` — `RD08 HOVER: PASS (52317 checks, 0 failures)` | `41974101d` (perf-135, branch commit `54b05c508`) — `RD08 HOVER: FAIL (52317 checks, 799 failures)` |
| PTF07 | `68b1a0b30`, `371edd331`, `9b58e2f89`, `c70495782`, `b8de863ef`, and `e5a6d3f53` all fail with the same two assertion labels | `479fe7cf1` — `PTF07 RESULT: PASS (335 checks, 0 failures)` | `191c95e8b` (ship-02, Frostbite change `e0f3fa6e1`) — `PTF07 RESULT: FAIL (329 checks, 2 failures)` |

## RD08 hover

| Original assertion | Failures | First bad | Classification |
| --- | ---: | --- | --- |
| Exact retained binding presentation: air/expanded | 160 | `41974101d` | Stale |
| Exact retained binding presentation: air/preview | 160 | `41974101d` | Stale |
| Exact retained binding presentation: air/clear | 160 | `41974101d` | Stale |
| Exact retained binding presentation: air/obstacle | 160 | `41974101d` | Stale |
| Exact retained binding _hud_layout_entries_cache: air/controller | 159 | `41974101d` | Stale |

- **Presentation.** The assertions already used content equality. The diagnostic found one differing key in all four mutations. The candidate omitted `collision_markers` and the reference stored `[]`. Perf-135 separates the owner's submission from the retained presentation and refreshes the shared retained dictionary from the current submission (`scripts/combat_board_view.gd:2427`). Wind paint can materialize the empty key when it restores its input after drawing (`scripts/enemy_mechanics/wind_view.gd:449`). The direct and wind collision painters both read absence as an empty list (`scripts/combat_board_view.gd:10498`, `scripts/enemy_mechanics/wind_view.gd:437`). The check now compares that effective marker list and retains exact equality for every other key. It also compares the ordered wind collision paint receipts from the actual retained effects layers.
- **Controller focus.** The HUD canvas and owner already had equal layout entries. The 159 mismatches came from non-HUD retained canvases holding the previous HUD-only entries. Perf-135 tracks base-layer and slice-list invalidation separately, and a slice-list change alone no longer triggers full state binding replay (`scripts/combat_board_view.gd:2112`, `:2414`). The hover refresh publishes layout entries to the HUD and rebuilds its paint plan (`:4795`). The check retains exact entries on the board and HUD canvases, retains health rectangles and all other field checks, and compares ordered HUD paint entries from the retained HUDs (`:9919`). The lower check count reflects the removed HUD-cache comparisons on non-HUD layers and the added paint receipt comparisons.

The same headless matrix ran 39 board/mutation pairs across the ordinary, air, and lightning fixtures. The air sequence moves from mouse hover to controller focus on the first foe, expands intents, submits and clears an enemy-move preview, and adds the fixture's HUD obstacle. The receipt comparisons and the existing retained draw comparisons passed.

## PTF07 Pass forecast

| Original assertion | First bad | Classification |
| --- | --- | --- |
| activation_end: projected Health equals live resolution | `191c95e8b` | Stale |
| activation_end: DEFEAT equals live resolution | `191c95e8b` | Stale |

Repro with `tools/ptf07/forecast_cases.gd`'s `activation_end` fixture. Start the hero at 24/24 Health, 0 Block and 0 Defiance, Chilled on Ice at (2, 4), with the Crawler at (3, 4) announcing a 5-damage Claw. Frostbite deals 2 damage at each player activation end. Pass without playing a card. Immediately before ship-02, the forecast and the original one-round live oracle both ended at 17 Health. Ship-02 made Frostbite apply live Freeze (`scripts/battlefield_rules/frostbite.gd:9`, `scripts/combat_engine.gd:11995`). At the first return to the hero, committed combat leaves 5 Health and a Frozen restriction. The old oracle stopped there with DEFEAT false. Pass the Frozen turn without playing a card and committed combat ends at 0 Health with DEFEAT true, matching the forecast's 0 Health and DEFEAT true for the full span. The lethal fixture starts at 2 Health and agrees at 0 Health and DEFEAT true before any Frozen turn is passed.

The repaired check uses the production forecast scheduler and independently drives the committed activation path through each Frozen turn, as qa-93 did for PTF08. The existing Health, DEFEAT, and Defiance truth checks remain intact. The new receipts verify the number of skipped turns and show that the first boundary and full span differ for the nonlethal Frostbite fixture.

## Verification

From the task worktree:

```sh
python3 tools/godot_task_runner.py --task-id qa-104 --stream -- godot --headless --path . --script tools/rd08/hover_checks.gd
python3 tools/godot_task_runner.py --task-id qa-104 --stream -- godot --headless --path . --script tools/ptf07/forecast_cases.gd
python3 tools/godot_task_runner.py --task-id qa-104 --stream -- godot --headless --path . --script tests/perf/hover_equivalence_probe.gd -- --setup-only
```

- `PERF04 HOVER EQUIVALENCE: 39 complete HUD/badge/retained-state comparisons; submission and catalog mutations detected`
- `RD08 HOVER: PASS (46207 checks, 0 failures)`
- `ACTIVATION END activation_end: first_hp=5 skipped_turns=1 forecast_defeat=true actual_outcome=defeat`
- `CASE activation_end: forecast_hp=0 actual_hp=0 loss=24 uncertain=false`
- `ACTIVATION END activation_end_lethal: first_hp=0 skipped_turns=0 forecast_defeat=true actual_outcome=defeat`
- `PTF07 RESULT: PASS (333 checks, 0 failures)`
- `PERF04 NATIVE SETUP RESULT: PASS (0 failures); pixels not checked`

The final logs are `.godot/qa-104/hover-after.log`, `.godot/qa-104/forecast-after.log`, and `.godot/qa-104/native-setup.log`. Godot emitted the existing macOS CA certificate diagnostic, `Condition "ret != noErr" is true. Returning: ""`, and all three checks exited successfully. The full suites are left to the design owner's merge workflow.

### Proof for the design owner

The headless paint receipt comparison satisfies the hover proof requirement. The existing optional pixel oracle exercises isolated HUD, overlay, and foreground rendering at 1920×1080 and 100% UI scale. This sandbox has no window server. The command emits candidate/reference captures under `output/perf-04/native/`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-104 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 tests/perf/hover_equivalence_probe.gd --task-id qa-104
```

### Chosen defaults

- `LIVE_SKIPPED_TURN_LIMIT = 100` bounds the test-only committed loop and fails explicitly if exceeded. It follows the qa-93 PTF08 precedent.

No `TODO_DESIGN_*` placeholders or remaining failures. The scope is the two existing checks and this report. A playable inspection fixture is unnecessary for this test-only change.
