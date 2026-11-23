# fx-38 Kindle sprite glow

Round 1 is uncommitted on `codex/fx-38`. The before project is candidate 4, `codex/mrg-15` at `76aac505bcc3f1f915344a5e7b14e8e20e1e1fae`.

## Live shader and loading order

The title Continue action now drives the proof through the normal loading cover. The observer records the frame when the cover submits its textured-board sample and verifies that the warmed material is registered before the combat board enters. It also checks that the board receives the exact same shader object.

```text
FX-38 ROUND 0 LOADING_COVER prewarm before board=yes sample_frame=3 board_frame=1395 shared_shader=yes board shader contains kindle_crack=no
FX-38 ROUND 1 LOADING_COVER prewarm before board=yes sample_frame=3 board_frame=1743 shared_shader=yes board shader contains kindle_crack=yes
```

The round 0 line ran against its original files before the change and is recorded in `/private/tmp/labyrinth_codex/fx-38/round1/round0-order.log`. The round 1 line is in `/private/tmp/labyrinth_codex/fx-38/round1/dry-run.log`.

- `assets/shaders/combat_art_treatment.gdshader:4` includes the effect. Lines 15–16 decode the Kindle levels and restore the original lighting profile. Lines 22–23 preserve the sampled texel for masking. Line 39 applies the alpha-gated boost before the original output assignment.
- `assets/shaders/kindle_cracks.gdshaderinc` and its UID contain the existing thresholds, halo taps, strength selection, and RGB boost. The standalone `kindle_cracks.gdshader`, its UID, and `KindleView.CRACK_SHADER` were removed.
- `scripts/combat_board_view.gd:1995` uses `impact_flash_shader(CombatArtTreatment.SHADER)`, the source used by the loading-cover recipes. Line 1997 configures the board's material before assignment at line 1999. Line 2173 shares that material with retained draw layers. The headless probe verifies the gain and orange uniforms on the shared material and checks the actor canvases that reference it.
- Floor baking uses the ordinary profile and its own material. Profiles 0–11 have zero Kindle gain and keep their original lighting and output. The white flash code, loading-cover recipes, and prewarm behavior retain their original implementations.

Round 0's ellipse removal, Ember Tick and Ember Hoarder support, pulse and reduced-motion behavior remain in place. The badge pop and `Burst +N` functions retain their original bodies. The current headless probe still records the 33-vertex base polygon at both strengths and reports zero legacy glow nodes after the change.

## Pixel checks

The approved front and rear plates were run through the CPU reference in both cel modes. Every case reported `outside_changed=0`, `outside_core_and_halo_max=0/255`, and `core_darker=0`.

| Plate | Cel | Halo pixels changed | Max delta outside core | Core pixels brighter at +4 than +2 | Mean core luma gain |
| --- | --- | ---: | ---: | ---: | ---: |
| Front | Off | 930 | 70/255 | 695/695 | 20.805/255 |
| Front | All | 867 | 70/255 | 661/661 | 20.283/255 |
| Rear | Off | 878 | 70/255 | 789/789 | 20.140/255 |
| Rear | All | 878 | 70/255 | 789/789 | 20.140/255 |

The accepted 3(b) check uses the combined crack and halo area. The 70/255 value is inside the halo.

For check (d), the headless plan loads the exact candidate 4 shader and compares it to the live shader's inactive path. It reported the following.

```text
FX-38 BASE SOURCE PASS (profiles 0-11: same sampling, grading and output, zero Kindle gain)
```

The native check uses the same frozen textures, light inputs, and local draw coordinates to compare the hero and the zero-bonus Tick against candidate 4. It also reads back the real floor cache with each shader on the same bake canvas. It prints differing pixel counts and maximum per-channel deltas for each case, and requires exact RGBA equality. The GPU pixel readings for (a)–(d) require the window-server run.

## Capture proof

Both takes load the saved Fire fight from the actual title Continue action. The loading cover hands off the live root viewport, so capture reads that viewport at a fixed 1920×1080 and 100% UI scale. The launcher verifies PNG dimensions and prints each full-frame and 3× crop path on its own line.

```text
FX-38 BEFORE PLAN PASS (1 captures) /private/tmp/labyrinth_codex/fx-38/round1/plan.TzSOTl/before/take.json
FX-38 AFTER Fire fight: Tick +2, Tick +4, Hoarder +2; legacy glow nodes=0
FX-38 PROFILES PASS (three actors, death, bonus reset)
FX-38 PULSE 73 frames at 60 fps, stride 6 (planned)
FX-38 HIT FLASH frame=17 opacity=0.6597
FX-38 DISSOLVE frame=54 phase=0.1111
FX-38 DISSOLVE frame=73 phase=0.4631
FX-38 DISSOLVE frame=91 phase=0.7966
FX-38 AFTER PLAN PASS (18 captures) /private/tmp/labyrinth_codex/fx-38/round1/plan.TzSOTl/after/take.json
FX-38 AFTER PLAN PASS (18 captures) /private/tmp/labyrinth_codex/fx-38/round1/plan-off/take.json
```

### Proof for the design owner

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/fx-38 && /private/tmp/labyrinth_codex/fx-38/native.sh
```

The launcher writes under `/private/tmp/labyrinth_codex/fx-38/native.*/{before,after}/`. Both takes contain `kindled_full.png` and the three `kindled_*_3x.png` crops. The after take adds the pulse frames and `pulse_strip.png`, the hit flash, and three dissolve frames with crops. Each directory includes a `take.json` and a native runner `manifest.json`. Add `--dry-run` for the headless plan.

## Focused checks

Godot checks ran through the fx-38 task runner. Logs are under `/private/tmp/labyrinth_codex/fx-38/round1/`.

| Check | Exact result line |
| --- | --- |
| `tests/en01_enemies_test.gd` | `EN01 ENEMIES TEST RESULT: PASS` |
| `tests/hoarder_test.gd` | `Hoarder suite: 0 failures` |
| `tests/board_status_plates_test.gd` | `BOARD STATUS PLATES TEST RESULT: PASS (29408 assertions; 0 failures)` |
| `tests/static_facing_test.gd` | `STATIC FACING TEST RESULT: PASS (149 checks, 0 failures)` |
| `tests/death_transition_test.gd` | `DEATH TRANSITION TEST: PASS (6 cases)` |
| `tests/test_rules_text_lint.py` | `PASS: Rules text lint (16 existing hits)` |
| `tools/perf165/lifecycle.gd` | `PERF165 LIFECYCLE: PASS (0 failures; 34 warmed recipes)` |

The macOS system-certificate diagnostic and EN01's dummy-renderer Burrow texture diagnostic also occur on candidate 4. No assertions were changed and no permanent tests were added.

## Chosen defaults

- Kept the seed-83, tier-2 Fire Hoarder fixture, original proof placements, Quick Stab, 180×180 source crops, 60 fps, and dissolve thresholds of 0.10, 0.45, and 0.78.
- The cover has a 30-second wait limit. Fixed-FPS headless playback yields 2 ms per frame during loading to give the normal threaded loader CPU time. Native takes retain a 180-second runner timeout.
- Sampled actor comparisons use the same solid `#22252a` background and 1:1 nearest filtering in both variants. Floor comparison reads the live bake canvas. The root viewport uses a fixed 1920×1080 render size and the ordinary Continue handoff.

## TODO_DESIGN and open proof

No design placeholders. Windowed captures and GPU pixel equality remain pending because the sandbox cannot run windowed Godot.
