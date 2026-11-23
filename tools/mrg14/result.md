# mrg-14 candidate 4 integration

The working tree on `codex/mrg-14` contains the composition of the seven approved tips over candidate 3, `90d5574ff`. HEAD still points to that base. The working rules reserve merge commits and Git writes for the design owner. Each composition step used the commit graph's merge base for the approved tip and the preceding virtual merge parents. The [integration inventory](/private/tmp/labyrinth_codex/mrg-14/changes.txt) has 268 paths. The [per-tip conflict files and resolutions](/private/tmp/labyrinth_codex/mrg-14/) include the three source versions for each conflict. The source ancestry check found zero excluded commit subjects.

## Acceptance

1. The seven tips were applied to the working tree in the specified order. The table records the commits and conflict resolutions. The seven merge commits remain pending.
2. Skybreak, Cinder Breath, Blink and the common reward pickup ran through production playback with their default behavior. Separate probes checked the title Grimoire, Controls rebinding and persistence, gfix-32 dismissal, and the Fire and Electrified fight under the pixel ground default. Only ground required enabling a default-off feature. The release pack and template were verified headless. Native stills remain pending.
3. A scratch probe saved a settings file with candidate 3's actual `SettingsStore`, then loaded it with candidate 4. The previous setting values and file bytes were identical. The six defaults match candidate 3's P, Space, E, Z, I and M keys. A second Godot process read the edited bindings in the ux-19 restart probe.
4. `data/ground_surface_style.json` sets `default_mode` to `pixel` and `director_note` to “Owner approved 2026-11-23 (ground-fx-motion-2). LABYRINTH_GROUND_FX=off or LABYRINTH_GROUND_FX=pixel overrides the data default.” `tools/grd03/verify_geometry.gd` pins the default and checks both overrides. `tools/grd11/ground_comparison.gd` sets `off` explicitly for the legacy control and accepts `--default` for the unset-environment comparison. Each sliced route exercised 11 cases, including previews, feedback and conduction.

## Composition and conflict resolutions

| Order | Tip | Resolution |
| --- | --- | --- |
| 1 | `8b5494403` gfix-32 | Clean. Settings owns Back and backdrop dismissal while the reset confirmation is open. |
| 2 | `b08fb9c5b` ux-18 | Clean. Carries the shared Grimoire, title entry and authored menu-test updates. |
| 3 | `72834ccd8` ux-19 | `card_empower_controller.gd` keeps candidate 3's rule and two-line return plus ux-19's charged, controller and rebound instructions. The overlap in `run_scene.gd` routes both modality and binding updates through the shared Grimoire panel's wording refresh. |
| 4 | `d09633dc1` fnd-01 | The burst provenance keeps the tile, self and acquisition entries. The asset inventory adds the nine acquisition sheets, retaining the candidate 3 tile and self pins. |
| 5 | `90a7ea5d8` fx-18, with fx-15 | The export filters and asset inventory add strike data and all seven strike sheets. `run_scene.gd` keeps both the acquisition and dragon-spell preloads. |
| 6 | `df946b04e` fx-19 | Clean on the shared fx-15 ancestry. |
| 7 | `44302e421` grd-11 | The board keeps burst resize and placement alongside ground resize and contact sync at both geometry entry points, plus shot submission and ground contacts/focus depth at combat-state submission. Both renderers retain their process and draw paths. The filters add both ground data files. The asset inventory, board registry and ground provenance retain all additions from the approved ground line. |

The six export include filters retain every inherited pattern and explicitly include `data/tile_bursts.json`, `data/self_bursts.json`, `data/shots.json`, `data/strikes.json`, `data/acquisition_bursts.json`, `data/ground_surface_style.json` and `data/ground_fx_atlas.json`. The inventory check matched all 56 incoming asset paths and retained every candidate 3 pin, registry entry and introduced entry. The older ground ancestry's exclusion for the retired `defense_heal_casts.png` follows candidate 3's existing removal of that asset. [Integrity log](/private/tmp/labyrinth_codex/mrg-14/integrity.log).

### Integration fixes

- `scripts/board_ground_fx_sheet.gd` and `scripts/board_pixel_surface_depth.gd` place ground stamps behind any effect overlays that share the same canvas. The actor-relative front and back slots keep their depth, including casts over occupied ground.
- `scripts/input_wording.gd` binds the current candidate 3 sentences for enemy intents, Undo and Empower. The bound case changes only the key. The unbound case uses the exact ux-19 text. `tools/ux19/probe.gd` pins all three current sentences and keeps the binding and unbinding checks.
- `tools/gfix32/verify.gd` checks geometry for the ux-19 Restore default keys button as well as the existing framed rows. The same geometry, modality, dismissal and focus assertions run.
- `tools/ux18/proof.gd` searches for “drawing from an empty” in the Fatigue article. That phrase exists in both data revisions. Candidate 3 removed “reshuffle”. The search and focus assertions still exercise the result.

## Verification

Godot commands ran through `tools/godot_task_runner.py --task-id mrg-14 --stream`. Detailed logs are in [focused](/private/tmp/labyrinth_codex/mrg-14/focused) and [parse](/private/tmp/labyrinth_codex/mrg-14/parse).

| Check | Observed result |
| --- | --- |
| fx-12 tile bursts | `FX-12 VERIFY: 120 checks, 0 failures` · `TEST RESULT: PASS` |
| fx-13 self bursts | `FX-13 VERIFY: 96 checks, 0 failures` · `TEST RESULT: PASS` |
| fx-13 affected suites | `FX-13 FOCUSED: 3727 checks, 0 failures` · `TEST RESULT: PASS` |
| fx-14 shots and affected suites | `FX-14 AFFECTED SUITES: PASS (1112 checks, 0 failures)` · `FX-14 VERIFY: PASS (1809 checks, 0 failures)`. Normal frame pacing let the threaded resize finish within its unchanged 120-frame budget. The forced-rate dry runs failed that assertion. |
| fx-15 sky strikes | `FX-15 VERIFY PASS (0 failures)` for the standalone check and the six affected suites. |
| fx-18 dragon spells | `FX-18 VERIFY PASS (0 failures)` · `FX-18 FOCUSED PASS (0 failures)`. The matched control used the candidate composition with just fx-18's presentation changes reversed in scratch files. The original three scripts predate other merged board APIs and cannot serve as stand-ins for the integrated board. |
| fx-19 Blink | Sixteen `FX-19 VERIFY PASS` lines and exits 0, covering eight cases in full and reduced motion against the approved base receipts. `FX-19 FOCUSED PASS (2332 checks, 0 failures)`. |
| grd-11 surfaces | `GRD-11 IMPORTED ATLASES: PASS (7 L8 sheets preloaded, no mipmaps, 10920960 index bytes matched)` · `GRD-11 ROWS AND DEPTH: PASS (visibility, flight, 2×2 footprint, illusions, props, frame-boundary switch, reduced motion, closer painters and HUD)`. All six surface suites passed. |
| Ground default and overrides | `GRD-06 GROUND DEFAULT: PASS (pixel ships by default, off data flip, pixel and off environment overrides)` · `GRD-11 SLICE DRAW PATHS: PASS (11 cases, pixel mode submits zero legacy ground, previews, feedback and conduction submitted)` · `GRD-11 SLICE DRAW PATHS: PASS (11 cases, off override retains legacy ground, previews, feedback and conduction submitted)`. |
| Shared ground and effect depth | `MRG-14 GROUND DRAW ORDER: PASS (occupied ground and burst share the front slot, ground paints first)`. [Scratch probe log](/private/tmp/labyrinth_codex/mrg-14/focused/ground-order.log). |
| fnd-01 acquisition | `FND-01 VERIFY: 111 checks, 0 failures` · `TEST RESULT: PASS` · `DECK ELEMENT REWARDS: 0 failures` · `TEST RESULT: PASS (84 checks)` for combat texture preparation. |
| gfix-32 | `GFIX-32 AFTER HEADLESS: 0 failures`, exit 0. |
| ux-18 focused | `UX18 HEADLESS RESULT: PASS` · `UX18 DEMO RESULT: PASS` · `TEST RESULT: PASS — main menu input and startup transitions` · `CHRONICLE TEST RESULT: PASS` · `GRIMOIRE PERFORMANCE RESULT: PASS` · `GRIMOIRE SEARCH PROBE RESULT: PASS` for focus return. The older search probe and comparison are listed below. |
| ux-19 focused | `UX19 HEADLESS RESULT: 116 passed, 0 failed` · `UX19 RESTART RESULT: 1 passed, 0 failed` · `Settings QoL checks: 74 passed, 0 failed` · `COMBAT HUD BUTTONS TEST: PASS` · `ENEMY HURRY TEST RESULT: PASS` · `MOVEMENT UNDO RESULT: 0 failures`. The Settings modal suite is listed below. |
| Candidate 3 settings | `MRG-14 LEGACY SETTINGS: PASS (candidate 3 bytes and values preserved; P, Space, E, Z, I, M)`. [Receipt](/private/tmp/labyrinth_codex/mrg-14/legacy-settings.log). |
| Python default | `ISOLATION AUDIT: 59 modules` · `SELECTED MODULES: 23 of 59` · `Ran 196 tests in 47.312s` · `OK`. [Log](/private/tmp/labyrinth_codex/mrg-14/python-default.log). The separate audit also recorded 59 modules. |
| UI and rules lint | `Ran 25 tests in 12.756s` · `OK` for UI identity. `PASS: Rules text lint (16 existing hits)`. |
| Parser, launcher and contracts | Task-runner `--check-only` exited 0 for all 86 changed or added GDScripts. `MRG-14 NATIVE CONTRACTS: PASS (7 probes, 8 planned 1920x1080 stills)`. `git diff --check` and `sh -n` exited 0. |

The worktree import timed out after 300 seconds. The headless proofs used 48 existing texture imports matched to the approved PNGs and import sidecars. The independent staged release export generated its own import cache. The Python default group passed despite the optional timing-cache write being denied under shared Git metadata.

## Release export

- The production macOS release kept `scenes/startup.tscn` and was built with `tools/export_game.py --task-id mrg-14 --preset 'Steam macOS'` using the existing release staging exclusions. `CEL_PACK_TEST paths=3089 failures=0`. [Export log](/private/tmp/labyrinth_codex/mrg-14/export-staged-release.log), [release application](</private/tmp/labyrinth_codex/mrg-14/Candidate 4/Escape the Umbra.app>).
- `pck_check.py` reported `MRG-14 PCK: PASS (8/8 data files, 48/48 sheets)`. It matched the seven required data files and Controls byte-for-byte, matched the indexed pixels of 44 baked sheets, and loaded all four ground decals at their source dimensions. The acquisition-specific verifier reported `FND-01 PACK: 9 of 9 baked sheets match in the exported pack` and `TEST RESULT: PASS`. [PCK inventory](/private/tmp/labyrinth_codex/mrg-14/pck-check.log), [acquisition pack verifier](/private/tmp/labyrinth_codex/mrg-14/fnd01-pack.log).
- The existing smoke staging launched the release template through the task runner and reported `EXPORT_SMOKE_LOADED scripts=798 scenes=9` and `EXPORT_SMOKE RESULT: PASS (227.36 seconds)`. It loaded ShotFx, the tile burst class shared by tile, self and strike players, AcquisitionBurst, the ground surface and ground sheet classes, and the combat board and RunScene. [Smoke result](/private/tmp/labyrinth_codex/mrg-14/export-smoke.log), [template log](/private/tmp/labyrinth_codex/mrg-14/export-smoke/launch.log).

## Proof for the design owner

Run the native launcher from a macOS desktop session. It runs only the still captures via the visual probe runner at 1920×1080 and 100% UI scale. It sets `LABYRINTH_CEL_LOOK=all` and unsets `LABYRINTH_GROUND_FX`. Frame-clock scratch movies are removed and no video is delivered. [Launcher](native.sh).

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mrg-14 && /private/tmp/labyrinth_codex/mrg-14/native.sh
```

The launcher writes the planned captures under [native](/private/tmp/labyrinth_codex/mrg-14/native).

| Feature | File |
| --- | --- |
| Ground under units | `ground/combat-ground.png` |
| Sky strike | `sky/sky-strike.png` |
| Dragon spell | `dragon/dragon-spell.png` |
| Blink | `blink/blink.png` |
| Reward acquisition | `reward/reward-acquisition.png` |
| Title and open Grimoire | `grimoire/title_pointer.png`, `grimoire/title_sections.png` |
| Controls | `controls/settings-controls.png` |

Each case writes a `manifest.json`. Headless plans observed Skybreak contact at frame 35, Cinder Breath's final ring at contact, the two visible Blink endpoints with four rows, and reward proxy release at frame 22 with the burst ending at frame 32. The ground, Grimoire and Controls dry runs each printed their `MRG-14 … STILL: PASS` line. [Capture plans](/private/tmp/labyrinth_codex/mrg-14/native-plan).

## Files changed

The [composition inventory](/private/tmp/labyrinth_codex/mrg-14/changes.txt) lists each incoming file. The [final status](/private/tmp/labyrinth_codex/mrg-14/final-status.txt) lists all 292 worktree paths. Integration-specific edits are the conflict resolutions above, the ground default and its two proof scripts, the two ground depth helpers, the Grimoire word-binding compatibility and proof changes, and the gfix-32 verifier adjustment. `tools/mrg14/` contains this report, the pack checker, the native launcher, seven still adapters with their UID sidecars, and the corresponding capture contracts.

## TODO_DESIGN placeholders

None added. ux-19's committed wording already provides the approved unbound strings.

## Chosen defaults

- Captures reuse the approved Skybreak, Cinder Breath, hero Blink, common reward, ground fight, title profile and Controls fixtures. The ground still uses frame 12 from grd-11. The reward still uses the existing +133 ms sample so the burst is visible behind the selected card.
- Each capture has a 120-second runner limit and an exact-size image contract with luma range 12 and standard deviation 3 as minimums. Ground and title evidence uses the current fixture framing. The legacy settings probe uses a 0.37 volume, reduced motion, and a 1280×800 window at (12, 34) on a 1920×1080 primary screen to detect preference loss. Pack validation mounts the release in a disposable empty project.
- The fx-18 comparison variant reverses only that branch's three presentation source changes and retains the candidate's other integrated systems.

## Open issues

- Git merge commits and native framebuffer validation remain pending. The user-assigned workflow forbids worker Git writes and the sandbox has no macOS window-server access.
- `tests/settings_modal_input_test.gd` reported `TEST RESULT: FAIL — 7 Settings modal input failure(s)`. Its confirmation route expects the backdrop click to leave the confirmation and its focus active. The approved gfix-32 behavior dismisses that confirmation on click. Later assertions in that route then act on the parent Settings screen. The gfix-32 verifier passed the approved outcomes.
- `tests/grimoire_search_probe.gd` reported `GRIMOIRE SEARCH PROBE RESULT: FAIL (7 failures)` on both candidate 3 and candidate 4 with the same assertion messages. It pins “reshuffle”, Truesight and the older Upheaval wording. The final ux-18 control-state comparison reported `FAIL: run control state differs for controller_entry` against the old release because candidate 3 rewrote the Fatigue body. The snapshots also measure 364 versus 374 discovered entries on the played fixture. Both headless snapshots completed their state checks. [Candidate 3 search](/private/tmp/labyrinth_codex/mrg-14/focused/grimoire_search_candidate3.log), [comparison log](/private/tmp/labyrinth_codex/mrg-14/ux18-comparison/compare.log).
- The Windows scanner reported `TYPED ARRAY SCAN: 86 scripts; 29 new; 8 pre-existing` against candidate 3. The 29 reports are in inherited branch lines. They include typed declarations in proof fixtures and the untyped button-list concat in the title code. The scanner output is recorded without claiming a Windows runtime result. [Scan](/private/tmp/labyrinth_codex/mrg-14/typed-array.log).
