# QA-131 release candidate 3 hunt

Candidate `2c6aff3f7` on `codex/qa-131`. Release control `92ed73479e58c97aa091300579eeef6f0039e59c`. This is a headless, report-only hunt. The audit and boss fixture drivers come from QA-129 at `3335b1852`. The release snapshot was copied from the clean local release checkout, with its warm import cache, into the evidence directory. Godot was limited to two concurrent processes for this task.

[Evidence directory](/private/tmp/labyrinth_codex/qa-131)

## Findings

### 1. Glacial Mirror submits a baked outbound head during its reflection animation

**Candidate regression in presentation state.** Seed **131011**, `reflect`, decision **2**. From `(4, 4)` aim Hurl Spear at the Glacial Mirror on `(6, 4)` and click. The Mirror commits one 6-damage return and plays the legacy outbound and return phases. While the legacy outbound phase is active, RC3 also enables a retained baked head. The retained head disappears before the legacy return. The old reflection draw path still runs before the new shot suppression check in `CombatBoardView`. Release plays the two legacy phases and has no retained submission. Forecast and committed Health agree on both revisions. The duplicate submission is verified headlessly, with native pixel impact pending.

- Candidate `baked_outbound=true`, `baked_returning=false`, `outbound=true`, `return=true`. The probe assertion is `Mirror playback does not also submit an independent retained head`. [Candidate log](/private/tmp/labyrinth_codex/qa-131/focused/live-complete.log:25)
- Release `baked_outbound=false`, `baked_returning=false`, `outbound=true`, `return=true`. [Release log](/private/tmp/labyrinth_codex/qa-131/release-controls/fx-complete.log:17)

### 2. Mid-animation quit persists the committed attack and omits `card_played`

**Pre-existing on release.** Seed **131011**, `save_shot` decision **2** and `save_area` decision **1**.

- **Shot.** Click Hurl Spear from `(4, 4)` to the Crawler at `(6, 4)`. Call the production quit preparation while its head is in flight. Disk and resumed state agree, with the Crawler at 8 Health and Hurl Spear removed. There are zero `card_played` rows on either revision.
- **Area.** Play Tremor with a 1-Health Crawler at `(4, 3)` and a powder keg at `(5, 4)`. Quit at contact. RC3 has 36 allocated stamps at departure. Disk and resumed state preserve the kill, 2 Health lost to the keg, and the card removal. Both revisions emit `actor_death` and `powder_keg_burst` and omit `card_played`. In the uninterrupted control both revisions emit one Tremor `card_played` with `kills_secured=1`.

The resumed hero and surviving enemies all resolve body textures, all three effect atlases are bound, and RC3 retains zero stale shot heads, shot hits or burst stamps. Playback is transient. The discrepancy is the durable gameplay effect without a matching play receipt. [Candidate shot](/private/tmp/labyrinth_codex/qa-131/live-complete/save_shot/analytics) · [Candidate area](/private/tmp/labyrinth_codex/qa-131/live-complete/save_area/analytics) · [Uninterrupted candidate](/private/tmp/labyrinth_codex/qa-131/live-complete/area/analytics) · [Release comparison](/private/tmp/labyrinth_codex/qa-131/release-controls/fx-complete.log:18) · [Analytics contract](../../spec/analytics.md#L464)

### 3. Interrupted playback retains objects at process exit

**Pre-existing ObjectDB signature.** Seed **131011**. Run the live matrix through `save_area` decision **1**, including the quit/resume sequence in finding 2. The candidate and release both log `WARNING: ObjectDB instances leaked at exit (run with --verbose for details).` The earliest playback interruption in both matrices is `save_shot` decision **2**. An isolated verbose replay of `save_shot` retained four GDScript function states on each revision. [Verbose candidate](/private/tmp/labyrinth_codex/qa-131/release-controls/isolated-save-candidate.log) · [Verbose release](/private/tmp/labyrinth_codex/qa-131/release-controls/isolated-save-release.log) [Candidate exit](/private/tmp/labyrinth_codex/qa-131/focused/live-complete.log:41) · [Release exit](/private/tmp/labyrinth_codex/qa-131/release-controls/fx-complete.log:27)

### 4. Cold worktree import cache omits two baked atlases

**Test-host setup.** Seed **131000**, decision **0** onward. Open the run with this worktree's original warm-but-incomplete `.godot` cache and enter combat. It has tracked `.import` sidecars for `tile_burst_44.png` and `self_burst_44.png` with no matching `.ctex`. The two loader stacks produce `Unable to open file`, two `Failed loading resource` messages and `Error loading resource` per read. Both atlas paths emit their four-message group 51 times each, for 408 error lines tied to decisions 0–481. The source PNGs and sidecars matched the candidate merge tree byte-for-byte. Restoring 42 generated import/cache files for the approved sheets removed the missing-file condition. The actual export and packed release smoke both load the catalogue sheets. Release predates both families. [First occurrence](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131000/godot.log:14) · [Packed release smoke](/private/tmp/labyrinth_codex/qa-131/export/smoke/launch.log:13)

### 5. Headless macOS certificate lookup error

**Pre-existing host error.** Seed **131000** at startup, decision **0**, and startup in other headless processes on both revisions. Minimal repro is to start either build through the headless runner. The loader logs `ERROR: Condition "ret != noErr" is true. Returning: ""` from `get_system_ca_certificates` at `platform/macos/os_macos.mm:1014`. The engine proceeds to execute the probe. Export and the native release template also emit the marker before their first decision. [Candidate startup](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131000/godot.log:11) · [Release startup](/private/tmp/labyrinth_codex/qa-131/release-controls/fx-complete.log:11) · [Packed release startup](/private/tmp/labyrinth_codex/qa-131/export/smoke/launch.log:1)

### 6. Treasure glossary logs a geometry overflow

**Pre-existing geometry condition.** Seed **131000**, decision **587**. Select map room `(6, 2)` from the Section II Scavenger. The next treasure frame logs `Relic glossary above-row overflow: RelicChoice_venom_signet` with a **1920×1920** viewport and a choice row top of **1964**. The minimal `--overflow-geometry` replay hovers Venom Signet at these same dimensions, fixture decision **1**. Both revisions emit the warning. The candidate reports block height 130 and top 1822, matching the campaign geometry. Release reports height 109 and top 1843. The release route prefix reached decision 588 in a different combat room and did not emit the warning. The isolated hover at the intended **1920×1080** returned `overflow=false` on both revisions. [Campaign warning](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131000/godot.log:5662) · [Matched candidate](/private/tmp/labyrinth_codex/qa-131/release-controls/relic-matched-candidate.log:14) · [Matched release](/private/tmp/labyrinth_codex/qa-131/release-controls/relic-matched-release.log:14)

Seed **131001**, decision **2110**, logs the same category for `RelicChoice_tallow_candle` after treasure entry at `(18, -10)` in V. Hovering Tallow Candle at the same forced geometry reproduces the warning on both revisions. [Campaign warning](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131001/godot.log:2220) · [Candidate](/private/tmp/labyrinth_codex/qa-131/release-controls/tallow-matched-candidate.log:14) · [Release](/private/tmp/labyrinth_codex/qa-131/release-controls/tallow-matched-release.log:14)

### 7. FX-14 resize verification is sensitive to frame pacing

**Fixed-FPS test assertion.** FX-14 fixture seed **97131**, scripted resize after the shot geometry and depth checks. Running the existing verifier with `--headless --fixed-fps 60` logged `Resize installs the staged sheet once the thread completes` at `tools/fx14/verify.gd:222`. The verifier samples up to 120 process frames while a background thread decodes the replacement atlas. Repeating under the wall clock with `--headless --max-fps 60` returned `FX-14 VERIFY: PASS (1809 checks, 0 failures)`. The affected suites pass in both runs. The release has no baked shot controller or resize assertion. [Fixed FPS](/private/tmp/labyrinth_codex/qa-131/focused/tools-fx14-verify.gd.log:14) · [Wall clock](/private/tmp/labyrinth_codex/qa-131/focused/fx14-wall-clock.log:16)

### 8. Section-entry detector flags a higher node count

**Pre-existing census pattern.** Seed **131000**, decision **2399**, entering VI. The QA-129 threshold flags `tree_nodes grew more than 25% from section 0 to section 5 (1718 -> 2590)`. The section table shows reversals and stable effect counts. Pinned release controls sampled 1726 nodes at a fresh I start and 2403 at a fresh VI Noctyrax fixture, both with zero orphans. Different room presentations can therefore exceed the threshold on release. The release control is an endpoint comparison. [Candidate threshold](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131000/godot.log:7560) · [Release I](/private/tmp/labyrinth_codex/qa-131/release-controls/census-early/trace.jsonl) · [Release VI](/private/tmp/labyrinth_codex/qa-131/release-controls/census-late/trace.jsonl)

## Coverage

### 1. Whole runs and encounter matrix

Two fresh profiles reached all six sections and won with reduced motion enabled throughout. Both Godot runners exited 0. The cache omissions in finding 4 affect early area and self-burst playback for 131000. Seed 131001 had the warm cache from startup. The optional third seed 131002 was deliberately interrupted at decision 57 after the required coverage completed. The runner's 130 status records that interruption. [Stop receipt](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131002/intentional-stop.json)

| Seed | Reached | Result | Decisions | Room entries | Runner output |
| --- | --- | --- | ---: | ---: | --- |
| 131000 | I–VI | Victory | 2870 | 72 | [`RUN HUNT SEED 131000: outcome=victory decisions=2870 findings=411`](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131000/evidence.json) |
| 131001 | I–VI | Victory | 3130 | 72 | [`RUN HUNT SEED 131001: outcome=victory decisions=3130 findings=3`](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131001/evidence.json) |

Across these 6,000 decisions, the observer compared 979 held card outcomes and 203 fully disclosed Pass forecasts. It sampled 2,876 settled initiative rails with Light. The campaign audit found zero preview/resolution mismatches and zero contradictions in its checked append-only fields over 70 combat starts, 1,774 card plays and 5,412 surface events. The separately interrupted save fixtures exposed the missing-play contradiction in finding 2. No completed whole or targeted run logged a product `SCRIPT ERROR`, freed-object access, softlock or crash. The per-occurrence index includes runtime messages, decisions, room data and analytics for every hunt run. [Index](/private/tmp/labyrinth_codex/qa-131/index.json)

All six dragons and all six Guardians separately completed the pinned QA-129 targeted route, with normal motion. These are staged production encounters and are counted separately from the fresh whole runs. The target launcher exited 0. The encounter audit reports 0 preview/analytics contradictions across 274 held comparisons and 34 fully disclosed Pass forecasts. The raw targeted analytics contain 401 card plays.

| Encounter | Resolved seed | Decisions | Result |
| --- | ---: | ---: | --- |
| Vyraketh | 131022 | 47 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/dragon-vyraketh/godot.log) |
| Iskaldra | 131020 | 56 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/dragon-iskaldra/godot.log) |
| Zekarion | 131037 | 86 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/dragon-zekarion/godot.log) |
| Vaeloryx | 131023 | 62 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/dragon-vaeloryx/godot.log) |
| Tharokh | 131021 | 71 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/dragon-tharokh/godot.log) |
| Noctyrax | 131020 | 132 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/dragon-noctyrax/godot.log) |
| Ashen Reaver | 131020 | 71 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/guardian-ashen_reaver/godot.log) |
| Rimejaw | 131020 | 63 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/guardian-rimejaw/godot.log) |
| Storm Cantor | 131020 | 159 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/guardian-storm_cantor/godot.log) |
| Gallows Roc | 131020 | 93 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/guardian-gallows_roc/godot.log) |
| Craghide | 131020 | 162 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/guardian-craghide/godot.log) |
| Last Lamplighter | 131020 | 115 | [`target_completed`](/private/tmp/labyrinth_codex/qa-131/targets/guardian-last_lamplighter/godot.log) |

### 2. Effects stress

| Case | Seed and decision | Observed |
| --- | --- | --- |
| Wide area, two areas in one step and kill | 131011, `area`, 1 | Tremor submits 13 tiles and reaches 13 simultaneously visible tiles. Earth and keg-impact stamp birth frames are identical. The target dies and still receives a visible hit stamp. The larger case settles in about 0.9 seconds. |
| Eclipse Umbra and explicit fog mask | 131011, `umbra`, 1. 131010, board decisions 2–3 | Live Tremor creates stamps on 5 of its 13 tiles. The two-area board submission creates 32 stamps clear, 14 under the engine's Eclipse visibility mask, and 10 under the explicit fog mask. Every submitted stamp is on a visible tile. |
| Eight directions | 131010, board decisions 4–11 | The spear uses eight distinct directional atlas columns, `0, 2, 8, 14, 16, 18, 24, 30` in the 32-column projected atlas. |
| Empty target and cancellation | 131010, board decisions 4–11. 131011, `cancel`, 2 | Board-only empty ground travel creates ground contact on arrival. Withdrawing a travel submission clears the head without impact. Cancelling an aimed Hurl Spear in RunScene leaves the card in hand and creates no head or hit. |
| Stacked gains | 131011, `gains`, 1–2 | Brace and Crystal Mantle both resolve on turn 1. Block is 6 after Brace. Block remains 6 and Mantle is 3 after the second card, with distinct self-burst front rows. |
| Reflect | 131011, `reflect`, 2 | One 6-damage return, with matching forecast and committed Health. See finding 1 for the duplicate outbound submission. |

[Board probe](/private/tmp/labyrinth_codex/qa-131/focused/tools-qa131-board_effects.gd.log) · [Live probe](/private/tmp/labyrinth_codex/qa-131/focused/live-complete.log)

### 3. Save and resume

Shot and area checkpoints were both exercised while playback was active. The saved and resumed state agreed. All expected actor textures and effect atlases resolved. The shot and area presentation samples are transient. See findings 2 and 3 for analytics and teardown. [Departure and resume receipts](/private/tmp/labyrinth_codex/qa-131/focused/live-complete.log:26)

### 4. Section-start growth

Seed **131000**, first quiescent room entry per section. The engine node counter and recursive scene-tree count agree at each sample.

| Section | Decision | Nodes | Orphans | Texture bytes | Area stamps | Self stamps | Shot slots |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| I | 0 | 1718 | 0 | 0 | 0 | 0 | 6 |
| II | 380 | 2467 | 0 | 0 | 0 | 0 | 6 |
| III | 909 | 3075 | 0 | 0 | 0 | 0 | 6 |
| IV | 1317 | 2705 | 14 | 0 | 0 | 0 | 6 |
| V | 1718 | 2765 | 0 | 0 | 0 | 0 | 6 |
| VI | 2399 | 2590 | 0 | 0 | 0 | 0 | 6 |

The historical 25% detector fires at decision **2399**, with live nodes up **50.8%** from I to VI. Counts fall in IV and VI, so the series has no monotonic node growth. The 14 orphans at entry to IV clear before V and stay at zero through VI. The two burst collectors hold transient stamps and the shot controller preallocates its six slots. Neither grows at these samples. The dummy renderer returns zero texture bytes throughout, so this run cannot establish GPU memory stability. The warm-cache census also records bound atlas texels. [Section trace](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131000/trace.jsonl)

The warm-cache seed **131001** samples **1716, 2557, 2535, 2557, 2832, 3027** live nodes at section entry. Each entry has zero orphans and the same area/self/shot counts of **0 / 0 / 6**. At VI entry (decision **2370**), the historical threshold reports `1716 -> 3027` (**76.4%** higher). The count dips between II and III. The first-combat samples also vary by room. All 12 warm-cache samples bind the same atlas sizes (**1,601,600** tile, **788,480** self and **2,971,136** shot texels). These are bound atlas dimensions. The headless renderer's GPU allocation values remain unavailable. [Warm section trace](/private/tmp/labyrinth_codex/qa-131/campaign/seed-131001/trace.jsonl)

### 5. Export

`python3 tools/export_game.py --task-id qa-131 --preset 'Steam macOS' --output '/private/tmp/labyrinth_codex/qa-131/export/Escape the Umbra.app'` exited **0**. It logged `CEL_PACK_TEST paths=3089 failures=0`, and the export listing contains all three `res://data/` JSON files. The signed macOS bundle is retained.

`python3 tools/qa131/export_smoke.py --output-dir /private/tmp/labyrinth_codex/qa-131/export/smoke` ran the repository smoke with the QA-131 metadata probe compiled into the disposable release bootstrap. The native release-template log has no metadata-load errors.

```text
QA131 EXPORT FX tile_bursts.json loaded=7/7
QA131 EXPORT FX self_bursts.json loaded=7/7
QA131 EXPORT FX shots.json loaded=7/7
EXPORT_SMOKE_LOADED scripts=783 scenes=9
EXPORT_SMOKE RESULT: PASS (103.77 seconds)
```

Both export imports report the duplicate UID between `player_reaver_idle.png` and `player_reaver_anime_idle.png`. This is an import warning at decision 0, before a seed is started. The two pinned release sidecars also share `uid://dhbcy5jpnld0c`. [Bundle](</private/tmp/labyrinth_codex/qa-131/export/Escape the Umbra.app>) · [Game export](/private/tmp/labyrinth_codex/qa-131/export/game.log) · [Smoke import](/private/tmp/labyrinth_codex/qa-131/export/smoke/export.log) · [Smoke launch](/private/tmp/labyrinth_codex/qa-131/export/smoke/launch.log)

## Focused checks

| Check | Exact result |
| --- | --- |
| Board effects | `QA131 BOARD EFFECTS: 97 checks, 0 failures` |
| Live candidate | `QA131 LIVE EFFECTS: 75 checks, 1 failures` (Mirror assertion) |
| Live release control | `QA131 LIVE EFFECTS: 39 checks, 0 failures` |
| FX-12 | `FX-12 VERIFY: 120 checks, 0 failures` and `TEST RESULT: PASS` |
| FX-13 | `FX-13 VERIFY: 96 checks, 0 failures` and `TEST RESULT: PASS` |
| FX-14 under fixed FPS | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` and `FX-14 VERIFY: FAIL (1809 checks, 1 failures)` |
| FX-14 on the wall clock | `FX-14 VERIFY: PASS (1809 checks, 0 failures)` |
| Enemy no-action | `ENEMY NO ACTION TEST RESULT: PASS (2369 assertions; 0 failures)` |
| Rules text lint | `Ran 3 tests`, `OK`, `PASS: Rules text lint (16 existing hits)` |
| Hunt tooling | `Ran 7 tests` and `OK` |
| Windowed census driver, headless bootstrap | `RUN HUNT: seed=131001 outcome=replay_point decisions=1` |
| Pinned QA-129 release controls | Both revisions log `QA129 CONTROL: Iron Cleaver family = blade` and `QA129 CONTROL: engine remains after dropping owner with route heap = false` |

[Focused logs](/private/tmp/labyrinth_codex/qa-131/focused) · [Release logs](/private/tmp/labyrinth_codex/qa-131/release-controls)

The first draft of the private board probe used a fully visible Heart footprint and checked dictionary keys with mixed numeric types. Its setup assertions at decisions 1–3 cleared after correcting the test inputs. The first private live probe attempted to register a child of a SubViewport as the SceneTree's current scene, which logged `p_scene && p_scene->get_parent() != root`. That iteration also produced one dummy texture RID and two retained script resources at exit. A subsequent early frame-bound teardown retained one resource. The final probes remove that invalid scene assignment and wait on a real-time guard. The clear area then settles in about 0.9 seconds. The isolated live exit still retains the four pre-existing function states reported above. The private probe's intermediate parse error and an overly strict relic-reveal setup assertion were corrected in the QA scripts. Release comparison is inapplicable to the earlier local probe versions. The FX-12 unit probe's seven raw-PNG warnings come from explicitly decoding its seven source bake images. The release predates that verifier, and the packed smoke resolves each atlas as an imported Texture2D. [Initial board](/private/tmp/labyrinth_codex/qa-131/focused/board-initial.log) · [Initial live](/private/tmp/labyrinth_codex/qa-131/focused/live-initial.log) · [Private parse failure](/private/tmp/labyrinth_codex/qa-131/focused/live.log) · [FX-12](/private/tmp/labyrinth_codex/qa-131/focused/tools-fx12-verify.gd.log)

## Replays

Use a fresh evidence subdirectory for each replay. The first command replays the two completed seeds.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-131 && python3 tools/qa131/setup_harness.py && python3 tools/run_hunt.py --task-id qa-131 --seed 131000 --runs 2 --processes 1 --fixed-fps 30 --no-embrace --script /private/tmp/labyrinth_codex/qa-131/harness/campaign.gd --output-dir /private/tmp/labyrinth_codex/qa-131/replay-campaign
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-131 && LABYRINTH_QA131_LIVE_OUT=/private/tmp/labyrinth_codex/qa-131/replay-live python3 tools/godot_task_runner.py --task-id qa-131 --stream -- godot --headless --fixed-fps 60 --path . --script tools/qa131/live_effects.gd -- reflect save_shot save_area
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-131 && LABYRINTH_QA131_RELEASE=1 LABYRINTH_QA131_LIVE_OUT=/private/tmp/labyrinth_codex/qa-131/replay-release python3 tools/godot_task_runner.py --project /private/tmp/labyrinth_codex/qa-131/release-92ed73479 --task-id qa-131 --stream -- godot --headless --fixed-fps 60 --path /private/tmp/labyrinth_codex/qa-131/release-92ed73479 --script "$PWD/tools/qa131/live_effects.gd" -- reflect save_shot save_area
```

## Proof for the design owner

These capture probes are ready for a machine with window-server access. Expected image size is 1920×1080 at 100% UI scale. Native captures were deferred. The result manifests record paths and image validation. The windowed census records real texture-memory samples after each section-entry frame and preserves its decision trace. The board proof includes the clear area, two visibility masks, eight flight directions and empty ground contact. Live proof includes both Mirror legs, area contacts, both gains and both resumed fights.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-131 && mkdir -p /private/tmp/labyrinth_codex/qa-131/native/board && LABYRINTH_QA131_CAPTURE_DIR=/private/tmp/labyrinth_codex/qa-131/native/board python3 tools/visual_probe_runner.py tools/qa131/board_effects.gd --task-id qa-131 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 120 --proof-contract tools/qa131/board_proof.json --result-manifest /private/tmp/labyrinth_codex/qa-131/native/board/images.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-131 && mkdir -p /private/tmp/labyrinth_codex/qa-131/native/live && LABYRINTH_QA131_LIVE_OUT=/private/tmp/labyrinth_codex/qa-131/native/live python3 tools/visual_probe_runner.py tools/qa131/live_effects.gd --task-id qa-131 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 120 --proof-contract tools/qa131/live_proof.json --result-manifest /private/tmp/labyrinth_codex/qa-131/native/live/images.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/qa-131 && python3 tools/qa131/setup_harness.py --windowed-census && python3 tools/visual_probe_runner.py /private/tmp/labyrinth_codex/qa-131/native-harness/campaign.gd --task-id qa-131 --no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --timeout 3600 --proof-contract tools/qa131/census_proof.json --result-manifest /private/tmp/labyrinth_codex/qa-131/native/census/images.json -- --seed 131001 --output-dir /private/tmp/labyrinth_codex/qa-131/native/census --no-embrace true
```

## Open issues

The Mirror's outbound double submission needs native capture to establish its pixel impact. Real texture-memory trends and shader output need renderer execution. The pre-existing interrupted-quit analytics and ObjectDB findings remain reproducible on the pinned release.

## Chosen defaults

QA fixtures use seeds 131010 and 131011, a 9×9 test board, 30 starting Health in RunScene, a one-Health target and powder keg, and a two-damage test keg. The outline of the board, fixture placement and event timing are private to the probes. Whole runs use the existing hunt policy, fixed 30 FPS, 8× scene time, fastest combat, 9,999 starting Health, source art and no voluntary Embrace. Seeds below 131002 keep reduced motion enabled across resumes. Live observations use a 12-second real-time guard. The isolated relic control uses the warning’s reported geometry. Native proof uses the specified resolution and a central board region. These settings affect QA only.

No `TODO_DESIGN_*` fields were needed.
