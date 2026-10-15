# vfx-01 round 5 — fade and destruction regression coverage

Uncommitted test-only changes on `54454a73d`. Read the peer review at `/private/tmp/labyrinth_codex/review/vfx-01-54454a73d.md` and its two reproduction logs. The production renderer, shader and protected style data are unchanged. The director retains commit, review, inspection and publication.

## Changes and acceptance

1. **Draw-time core fade.** A test-only `StrokeDrawing` subclass intercepts the native `_stroke` boundary while executing the production `_draw()` logic. Its core straddles the data's `alpha_floor` while the halo stays at alpha 0.5. The test first verifies that the visible halo keeps the stroke past the early filter, then requires one halo draw and zero core draws below the floor. Equal/above-floor controls require an opaque core. This checks the draw-time guard independently of early stroke filtering.

   The real-renderer probe repeats the mixed-alpha fixture. It requires an empty GPU core mask, a nonempty halo mask, and nonempty normal Bayer output. It saves `line_mixed_alpha.png` at 1920×1080; the contract now requires 26 unique captures. The existing transparent-halo width/fade fixture remains intact. This worker has no window-server access: headless parsing does not establish GPU correctness.

2. **Destruction, not only detachment.** The lifecycle test saves the instance IDs of the line viewport, drawing and composite before each transition. After deferred deletion it requires every saved ID to be invalid. Eight line→non-line and eight line→empty transitions check 48 retired target IDs. Existing owner-field and child-count assertions remain as secondary checks. A missing target also fails before deletion, so a broken fixture cannot pass vacuously.

## Changed files

- `tests/pixel_fx_test.gd`: production draw-boundary recorder, mixed-alpha cutoff tests, repeated destruction checks.
- `tests/pixel_fx_render_probe.gd`: mixed-alpha GPU core/halo/normal assertions and capture.
- `tests/pixel_fx_render_probe_contract.json`: require the added 1920×1080 capture.
- `tests/pixel_fx_proof.md`: this handoff.

## Observed proof

- Initial focused run: `PIXEL FX TEST RESULT: PASS (11797 checks, 0 failures)`; runner exit 0.
- **Core-cutoff mutant caught:** temporarily replace `if core.a >= lines.alpha_floor:` with `if core.a > 0.0:`. Result: `PIXEL FX TEST RESULT: FAIL (11798 checks, 1 failures)`; runner exit 1. Failure: `Draw-time core coverage is empty below alpha_floor even with a visible halo`.
- **Viewport-destruction mutant caught:** temporarily remove `viewport.queue_free()` from `_release()`. Result: `PIXEL FX TEST RESULT: FAIL (11797 checks, 16 failures)`; runner exit 1. The eight line→non-line cycles each detect both the surviving viewport and its drawing.
- Both mutations were applied separately, run through the task runner, and restored in `finally` blocks. `PRODUCTION SOURCE RESTORED: PASS`; the production file has no diff against HEAD.
- Restored focused run: `PIXEL FX TEST RESULT: PASS (11797 checks, 0 failures)`; runner exit 0.
- Render probe headless `--check-only`: runner exit 0. `RENDER CONTRACT: PASS (26 unique 1920x1080 captures)`.
- `PRODUCTION AND STYLE UNCHANGED: PASS` against HEAD.
- Full Godot suite: `FULL SUITE RUNTIME: 857.323 seconds (budget 900 seconds)` / `TEST RESULT: PASS`; runner exit 0.

Logs:

- `/private/tmp/vfx-01-round5-pixel-initial.log`
- `/private/tmp/vfx-01-round5-mutant-core_cutoff.log`
- `/private/tmp/vfx-01-round5-mutant-target_free.log`
- `/private/tmp/vfx-01-round5-pixel.log`
- `/private/tmp/vfx-01-round5-render-parse.log`
- `/private/tmp/vfx-01-round5-full-godot.log`

No performance rerun is needed for these test-only changes. The peer review records passing unique-progress CPU budgets on the unchanged production HEAD; those are prior evidence, not new measurements by this worker.

## Proof for the design owner

Fresh mixed-alpha GPU proof remains pending this windowed command. It was not run here.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/vfx-01 && python3 tools/visual_probe_runner.py --task-id vfx-01 --no-headless --display-driver macos --audio-driver Dummy --rendering-method mobile --rendering-driver vulkan --timeout 240 --startup-timeout 45 --proof-contract tests/pixel_fx_render_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/vfx-01-round5-render.json tests/pixel_fx_render_probe.gd
```

Required result: `PIXEL FX RENDER PROBE: PASS`. Captures are under `user://probes/pixel_fx_render/`; the runner prints the isolated absolute directory. The new `line_mixed_alpha.png` must show the dithered halo without an opaque core. The probe asserts this separation using actual GPU masks before saving normal output.

Headless reproduction:

```sh
python3 tools/godot_task_runner.py --task-id vfx-01 --stream -- godot --headless --path . --script tests/pixel_fx_test.gd
python3 tools/godot_task_runner.py --task-id vfx-01 --stream -- godot --headless --path . --script tests/pixel_fx_render_probe.gd --check-only
python3 tools/godot_task_runner.py --task-id vfx-01 --timeout 960 --stream -- godot --headless --path . --script tests/run_tests.gd
```

## Chosen defaults and open proof

No `TODO_DESIGN` placeholders, production values or assets. Test-only choices: eight repetitions per cleanup path; the recorder's points (10,20)→(100,20) and 200×100 configuration. Halo alpha 0.5 comes from the peer reproduction; ±0.0001 floor offsets and GPU fixture positions are unchanged. Existing runner timeouts are unchanged.

Both requested mutants now fail explicit assertions, and the restored focused tests and full suite pass. Fresh mixed-alpha GPU output remains pending the owner command above. All changes remain uncommitted.
