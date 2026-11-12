# perf-110 result

Implementation is uncommitted on `codex/perf-110`. **Overall numeric acceptance is NOT MET.** All twelve valid takes reached the same 96-decision boundary. Semantic decisions and saved gameplay state match in all six pairs after explicitly documented runtime-identity/time normalization. Native pixel proof and native census are deferred to the design owner as requested.

| Seed | All six classes: redraw reduction (target ≥60%) | Polygon internal polygons/frame reduction (target ≥60%) | Summed slow-frame redraw estimate reduction (target ≥50%) | Five owned classes: redraw reduction, supplemental |
|---|---:|---:|---:|---:|
| 84 | 56.99% — FAIL | 72.42% — PASS | 64.65% — PASS | 69.12% |
| 85 | 38.78% — FAIL | 35.04% — FAIL | -18.67% — FAIL | 67.59% |

These are pooled per-seed figures; every individual take and pair is reproduced below. No pair meets every numeric threshold. The supplemental figure excludes only `builtin:Node2D`; it does not replace the all-six acceptance result. The dominant observed Node2D population is animated fire tongues outside this unit's owned files. Seed 85 also has much less of the targeted polygon workload: its baseline is about 48–52 internal polygons/frame versus about 3,143–3,389 on seed 84. Its remaining polygon and slow-frame targets were not achieved. No animation, interpolation, topology, art or tuning was changed to meet a number.

## 1. Trigger gate and source sites

The original-snapshot 96-decision gate passes conservatively: **55.8055% ordinary**, **56.0135% process->50ms** redraws have proven unchanged inputs or alpha-zero occlusion. There are 20,602 ordinary and 57 slow frames. Per-instance observations match the census executed counts exactly. Raw rows are `interleaved96/gate/draw-inputs.jsonl`; corrected summary is `interleaved96/gate/summary.json`.

The initial observer treated the empty tooltip script as having no draw inputs. Native Control also reads transform/clip/rect state. All legacy tooltip “unchanged” observations were therefore discounted; only proven occlusion remains in its qualifying count. The gate still passes. Observer version 2 records those native fields for future runs. This correction is a conservative lower bound, not a claim that every discounted redraw changes pixels.

| Class | Ordinary frames with redraw | Ordinary redraws | Proven unchanged/occluded | Slow frames with redraw | Slow redraws | Proven unchanged/occluded |
|---|---:|---:|---:|---:|---:|---:|
| builtin:Polygon2D | 2065 | 77736 | 54939 | 23 | 895 | 633 |
| res://scripts/segmented_health_bar.gd | 5024 | 33834 | 28010 | 39 | 178 | 77 |
| res://scripts/ui_tooltip_control.gd | 7142 | 10453 | 45 | 37 | 106 | 0 |
| res://scripts/board_surface_ice_layer.gd | 0 | 0 | 0 | 0 | 0 | 0 |
| builtin:Node2D | 1818 | 29804 | 865 | 12 | 300 | 119 |
| res://scripts/enemy_shadow_dissolve_effect.gd | 1213 | 2018 | 1995 | 1 | 1 | 0 |

Trigger sites below refer to original files under `baseline/scripts/` where applicable:

| Class | Trigger site and finding |
|---|---|
| Polygon2D | `maquette_cutout_runtime/rig.gd:61` restores bind paint before each production pose; `stable_paint.gd:22,63,66,71,87,99,100` writes bind/final polygon, skeleton, texture and UV fields. `humanoid_continuations.gd:38` repeats the selected texture; `strike_points.gd:80–84` restores texture and geometry. Native visibility changes also invalidate legacy meshes. The isolated Crawler probe showed changed bone poses alone produced no mesh redraws after initial setup. |
| segmented_health_bar.gd | `:18–25` connects every shared tracker change directly to redraw and always redraws on binding; `:45–63` redraws even on equal setter values. Shared notifications include other actors and stationary ghost holds. |
| ui_tooltip_control.gd | No script `_draw` or explicit queue. The native diagnostic observed 171 repeated draws: 164 had changed scale; position/size/pivot changes also occurred. Existing rail scale tweens are created in `run_scene.gd:13390,13477,13505`; direct frame sizing is `turn_order_slots.gd:77`. Native Control setters queue redraws on changed scale/rotation/pivot. Equal assignments already produced zero redraws in the isolated probe, so these motion/input writers were left unchanged. |
| board_surface_ice_layer.gd | `:15–32` already guards width/seed and phase; changing phase changes the shimmer alpha (`board_surface_presentation.gd:471`). No ice redraws occurred in the representative gate. Unchanged. |
| builtin:Node2D | Dominant paths are `.../SceneTile_2_6/SurfaceFire/@Node2D@...`, from `board_surface_fire_layer.gd:16–31`. Tongue phase changes visible flame geometry. These files are outside ownership. Unknown anonymous custom-draw classes are conservatively changed in the gate; only bare empty Node2D draws qualify as unchanged. |
| enemy_shadow_dissolve_effect.gd | `:64` always queues, although script `_draw` reads only `_draw_texture` and `size`; progress/UV/atlas changes are shader uniforms. |

The native tooltip evidence is `tooltip-native-diagnostic/tooltip-triggers.jsonl`, including changed fields and signal call stacks. Six resize signals point to `turn_order_slots.gd:77`; native scale setters account for most repeated draws without those signals. [Godot 4.6.1 Control source](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/gui/control.cpp#L1450) explains the setter invalidations and native draw inputs. [Polygon2D source](https://github.com/godotengine/godot/blob/4.6.1-stable/scene/2d/polygon_2d.cpp#L301) shows per-internal-polygon triangulation and unconditional polygon/UV/texture setter invalidation. No topology precomputation or replacement was used.

A fresh version-2 baseline smoke also passed: `PERF110 GATE: PASS`, ordinary frames=1054, redraws=2263, redundant fraction=0.7945205479452054; count coverage matched. Files: `gate-native-inputs/summary.json` and `gate-native-inputs.log`. This validates the corrected native Control key without replacing the conservative 96-decision gate.

## 2. Changed files/functions and invisibility

| File / function | Why the change is invisible |
|---|---|
| `scripts/maquette_cutout_runtime/rig.gd::apply_pose/apply_authored_pose` | Retains virtual case-owned hooks; skips only the intermediate bind-paint restore immediately before stable-paint submission. Standalone authored/oracle calls retain their restore. |
| `scripts/maquette_cutout_runtime/stable_paint.gd::restore/apply` | Exact packed-array/reference comparisons skip equal polygon/UV/texture/skeleton writes; changed poses use the original calculations in the original frame. |
| `scripts/maquette_cutout_runtime/humanoid_continuations.gd::apply` | Retains the original texture selection and texels, skipping assignment of the same texture reference. |
| `scripts/maquette_cutout_runtime/strike_points.gd::restore_nodes` | Restores changed texture/geometry as before; skips only equal texture/polygon/UV/skeleton writes. |
| `scripts/segmented_health_bar.gd::_draw_key/_request_redraw`, setters and binding/ghost callback | Compares every drawn field and the current ghost sample. Any changed input queues immediately, including silent max-HP and reduced-motion changes. Unchanged holds/other-actor notifications retain existing commands. |
| `scripts/enemy_shadow_dissolve_effect.gd::configure` | Updates every shader uniform on every call; resubmits commands only when the texture rectangle or draw texture changes. |

`tools/perf110/` contains the focused checks, trigger observers, byte oracle, deterministic capture fixture/contract, guarded serial A/B collector, saved-state reader, report utilities and eight Godot-generated UID sidecars. No new Python test modules were added. No scenes, provided data/art, combat_board_view.gd, forecast code, census code, analytics instrumentation or save format was edited. No commits, peer review, publication or cleanup were performed; those remain with the design owner.

## 3. Before/after numbers per take


All runs: headless census, seed 84 or 85, 96 decisions; startup excluded. 
Ordinary/slow use measured `process_wall_ms <=50 / >50`; 
`redraw_ms_estimate` is a signal-gap estimate, not exclusive redraw CPU. Headless `process_wall_ms` ends at the last-priority Node process callback, before later deferred redraw work; it is not the native process/GPU bucket.

| Pair | Seed | Variant | Ordinary frames | Target redraws/frame | Polygon internal polygons/frame | Slow frames | Slow summed redraw ms estimate |
|---|---|---|---:|---:|---:|---:|---:|
| 1 | 84 | A | 17018 | 8.117523 | 3389.084381 | 138 | 3985.658 |
| 1 | 84 | B | 20454 | 3.290310 | 896.219908 | 113 | 1010.825 |
| 2 | 85 | A | 20560 | 3.584971 | 48.479280 | 54 | 375.265 |
| 2 | 85 | B | 20553 | 2.156911 | 32.080961 | 61 | 416.030 |
| 3 | 84 | B | 21145 | 3.318846 | 879.562450 | 60 | 373.876 |
| 3 | 84 | A | 20941 | 7.546440 | 3142.597297 | 51 | 543.593 |
| 4 | 85 | B | 20189 | 2.187132 | 31.875576 | 69 | 576.952 |
| 4 | 85 | A | 20194 | 3.524809 | 51.927800 | 67 | 628.860 |
| 5 | 84 | A | 20607 | 7.507303 | 3153.280827 | 75 | 707.215 |
| 5 | 84 | B | 21183 | 3.324600 | 887.196714 | 60 | 466.341 |
| 6 | 85 | A | 20364 | 3.569387 | 48.524651 | 74 | 472.478 |
| 6 | 85 | B | 20118 | 2.194154 | 32.774630 | 83 | 759.323 |

| Pair | Redraw reduction ≥60% | Polygon reduction ≥60% | Slow estimate reduction ≥50% | Choices / normalized saved state |
|---|---:|---:|---:|---|
| 1 | 59.47% (FAIL) | 73.56% (PASS) | 74.64% (PASS) | identical |
| 2 | 39.83% (FAIL) | 33.83% (FAIL) | -10.86% (FAIL) | identical |
| 3 | 56.02% (FAIL) | 72.01% (PASS) | 31.22% (FAIL) | identical |
| 4 | 37.95% (FAIL) | 38.62% (FAIL) | 8.25% (FAIL) | identical |
| 5 | 55.72% (FAIL) | 71.86% (PASS) | 34.06% (FAIL) | identical |
| 6 | 38.53% (FAIL) | 32.46% (FAIL) | -60.71% (FAIL) | identical |

Pooled per-seed comparison (sum counts / sum ordinary frames across the three takes; sum slow estimates):

| Seed | All six: redraw reduction ≥60% | Polygon reduction ≥60% | Slow estimate reduction ≥50% | Five owned classes: redraw reduction (supplemental) |
|---|---:|---:|---:|---:|
| 84 | 56.99% | 72.42% | 64.65% | 69.12% |
| 85 | 38.78% | 35.04% | -18.67% | 67.59% |

Acceptance: NOT MET.

Acceptance includes builtin:Node2D. The supplemental five-class figure excludes only that aggregate bucket, whose dominant observed population is fire tongues outside the owned scripts; it does not replace the acceptance figure. 
Decision comparison removes frame timing and normalizes only anonymous Godot node numeric suffixes in UI paths. Named selectors (such as Choice1), actions, arguments, text and signals remain exact. Raw logs and their equality flag are retained. 
Replay outcomes and complete coverage dictionaries are compared exactly. 
Saved Variant state is compared directly after excluding wall-clock run duration and normalizing analytics run identity plus its combat-id prefix; the combat ordinal and all other fields remain exact. Raw identity differences and both durations are retained in state_comparison.json. 
These are partial-run outcomes at the fixed decision boundary, not terminal run victories.

Only complete fixed-decision takes under `measured-ab/` are included. `sources.json` and `source/{A,B}/` retain the exact six owned source files; `restored.json` verifies the candidate was restored. Two earlier collections represent superseded source and are excluded. One final-source B attempt stopped at 90 decisions at the original 240-second cap; it is also excluded. Unchanged gameplay phases slowed in that sample. The headless cap was raised to 360 seconds / 420 seconds runner, and `--resume` retained only hash-matched completed takes, using a fresh B retry directory. Both A and B finish at 96 decisions, never at their safety cap. Native collection retains 240 seconds.

## 4. Validation actually observed

| Check | Exact result / evidence |
|---|---|
| Focused redraw regressions | `PERF110 FOCUSED: checks=11 failures=0 PASS`; `regressions-health-key.log`. Includes equal inputs, other actor notifications, hold/drain/heal, rebinding, hidden→visible, silent max-HP and silent reduced-motion changes, plus retained dissolve uniforms/changed rectangles. |
| Existing affected suites plus new checks | `PERF110 FOCUSED: checks=1841 failures=2 FAIL`; `focused-health-key.log`. Both failures are the pre-existing `lightning_wisp: deferred portrait defeat retains the live atlas` and `bile_bloomer: deferred portrait defeat retains the live atlas`. |
| Untouched original, same existing suites | `PERF110 FOCUSED: checks=1830 failures=2 FAIL`; `focused-baseline.log`, with exactly those same two assertions. Assertions were not rewritten. Health ghost unit/integration, tooltip consistency, cutout gate, maquette runtime/movement suites were exercised. |
| Python default group | `Ran 189 tests in 26.905s` / `OK`, exit 0; `python-health-key.log` and `python-health-key/summary.json`. Optional timing-cache writes into read-only shared Git metadata were denied; tests passed. No full suites ran. |
| Python resource audit | Exit 0, `ISOLATION AUDIT: 56 modules`; `python-audit/isolation-audit.md`. No new tests/test*.py modules requiring resource entries. |
| Exact submitted byte oracle | `PERF110 BYTE ORACLE: {'samples': 592, 'equal': True, 'unavailable_textures': 0}`; `pose-byte-comparison.json`, `pose-bytes-{A,B}.json/.log`. Actual node polygon/UV/topology/color buffers, transforms, tints and texture bytes are hashed across five production humanoid adapters, both facings and all declared clips/repeated phases. This is submitted-data proof, not native pixel proof. |
| Saved-state outcomes | `PERF110 STATE OUTCOMES: pairs=6 differences=0`; `state-normalized.log`, `measured-ab/state_comparison.json`. All gameplay fields compare directly as decoded Variants. |
| Capture setup, headless only | `PERF110 CAPTURE HEADLESS SETUP: samples=4 failures=0`; `capture-final-verified.log`, `capture-final-verified/samples.json`. No PNGs were produced. |
| UID/sidecar preparation | `PERF110 TOOL UIDS: created=8; existing sidecars preserved`; `tool-uids.log`. Prospective tracked+new inventory: `PERF110 PROSPECTIVE SIDECARS: PASS`. Existing UID sidecars were not overwritten. |
| Source restoration / whitespace | `PERF110 FINAL SOURCE HASHES: match measured B`; `git diff --check` exit 0. Only six owned runtime files and new tools/perf110 files changed. |

Saved-state normalization is deliberately narrow: wall-clock `run_stats.run_seconds`, randomized `analytics.run_id`, and only the matching run-id prefix of `combat_state.analytics.combat_id`. The combat ordinal remains exact. Before identity normalization, the only remaining leaf differences in every pair were those two analytics identifiers; all raw differences and durations are retained. Run IDs are randomized by unchanged `run_scene.gd:32391`; combat identity appends the logical ordinal at `:33007`. Decision comparison removes frame timing and normalizes anonymous Godot node numeric suffixes only in UI paths; named choices, arguments, text and signals remain exact. Raw files are not byte-identical and are retained unchanged.

Diagnostics: equal native assignments to eleven tooltip-host properties each reported `same_assignment_draws=0`. The isolated Crawler reported initial `draws=8 bone_setups=1`, then `draws=0 bone_setups=0` for repeated and changed idle phases. An initial absent script-class cache prevented scene load; a permitted headless import created the cache but hit its 300-second cap (exit 124). Subsequent listed scene loads/checks succeeded. Early observer/tool errors were corrected and excluded. No editor scan was used as a parser check.

## 5. Proof for the design owner

The implementation engineer ran no windowed or native jobs. Run these from this worktree before changing the candidate. They snapshot the current candidate, verify baseline hashes, temporarily install only the owned original/candidate source files, record hashes, then restore the candidate in `finally`. Preserve `baseline/` with these artifacts.

Pixel A/B, 1920×1080, 100% scale:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-110 && python3 tools/perf110/run_ab.py --baseline /private/tmp/labyrinth_codex/perf-110/baseline --output /private/tmp/labyrinth_codex/perf-110/native-pixels --capture
```

This uses tools/visual_probe_runner.py with `--no-headless --display-driver macos --audio-driver Dummy --expect-size 1920x1080 --proof-contract tools/perf110/proof_contract.json`. Expected future paths under `native-pixels/{A,B}/`: `crawler_idle.png`, `crawler_attack.png`, `hoarfrost_seer_idle.png`, `hoarfrost_seer_attack.png`. Manifests: `native-pixels/{A,B}-manifest.json`. Each board has the production hero plus one enemy at fixed idle/attack phase 0.5 and a production segmented health widget mid-drain at 0.75 s. Processing/clocks are frozen and proof pointer input is ignored. Compare corresponding A/B pixels; equality is not claimed without this native run.

Native census A/B, both seeds:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-110 && python3 tools/perf110/run_ab.py --baseline /private/tmp/labyrinth_codex/perf-110/baseline --output /private/tmp/labyrinth_codex/perf-110/native-census --native-census
```

The unchanged collector freezes A/B copies and uses `--drivers whole --seed 84 --seeds 2 --cache warm --profiles normal --seconds 240 --stop-after 96 --tag perf110-A|B --disk-cap-gb 10`. It retains its historical perf-109 runner label. The owner prepares the inspection fixture/peer review/publication under the explicit workflow split; this unit did not request an inspection_fixture.py command.

Representative headless reproduction:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-110 && python3 tools/perf110/run_ab.py --baseline /private/tmp/labyrinth_codex/perf-110/baseline --output /private/tmp/labyrinth_codex/perf-110/replay-repro
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-110 && PERF110_AB_DIR=/private/tmp/labyrinth_codex/perf-110/replay-repro python3 tools/godot_task_runner.py --task-id perf-110 --stream -- godot --headless --path . --script tools/perf110/compare_states.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/perf-110 && python3 tools/perf110/summarize_ab.py /private/tmp/labyrinth_codex/perf-110/replay-repro
```

## TODO_DESIGN and Chosen defaults

No TODO_DESIGN placeholders were introduced. No player-facing value was chosen.

All selected values are proof-only named constants/fields: final count 96 decisions; diagnostic prefixes 12/32; 360-second headless driver and 420-second runner caps; native cap 240 seconds; pair order 84 AB, 85 AB, 84 BA, 85 BA, 84 AB, 85 AB; pooled per-seed counts/frames with all pairs also reported; tooltip fixture 100×80 and 3 settle frames; health fixture 160×16, HP 24, damage 6 and 3 settle frames; oracle types Hoarfrost Seer, Arc Thrall, Glacial Mirror, Frostglass Lancer, Chainbound Gaoler, phases 0/.1/.25/.5/.75/1/.5/.5; capture Crawler/Hoarfrost Seer, phase .5, ambient .5 s, ghost .75 s, damage 6, health position (64,64), health size (320,20), 8 settle frames and pointer filter IGNORE; normalized proof run identity `<run>`. The 1920×1080 and 100% UI scale are brief requirements. New tool UIDs were assigned by Godot. Production colors, assets, clip names and timing come from existing definitions.

## Open issues / acceptance not achieved

1. All-six-class ordinary redraw reduction is below 60% on both seeds. The owned five-class reductions exceed 60%, but do not satisfy the broader table criterion.
2. Seed 85 misses the polygon and slow-estimate targets; its estimated slow redraw sum increases 18.67%. Individual-pair results expose additional variability, including seed-84 pairs below the 50% slow-estimate target. No claim of complete performance acceptance is made.
3. Two portrait-atlas assertions fail identically on the original source. They remain unchanged.
4. Native pixel equality and native hitch measurements remain for the design owner. The 592 submitted-data samples cannot substitute for a renderer pixel diff.
