# rr-04 implementation and design-owner proof

The implementation is uncommitted on `codex/rr-04`. No peer review, signoff,
fixture publication, commit, push, merge, rebase, stash or branch change was run.
The design owner retains native inspection, review, committing and publication.

## Acceptance criteria

1. **Semantic compiler:** `tools/maquette_motion/compiler.py` preserves every
   protected authored key, smoothstep/hold interpolation, duration, intent,
   contact, loop and terminal flag. Per-view raise signs derive from projected
   joint-to-material rays and up; lean signs derive from up and forward.
   `body` targets root. Squash compensates width by `1/squash`; uniform scale
   and inherited body/part opacity apply to actual Bone2Ds. Fractional forward
   travel multiplies the resolved board-step distance. An explicit joint recipe
   also supports other maquettes; rr-04's geometry adapters are separate from
   the channel compilation. Unknown semantics fail with `TODO_DESIGN_*`.
2. **Rigs:** the Shale r9 and Wisp r4 cached exports, approved raw paintings,
   processing records and labels are retained alongside each case. Registered
   ownership partitions reconstruct all four approved processed paintings with
   **0 differing pixels**. Additional pivots derive from capsule starts and
   petal base edges; existing root/base/crown/core/tail joints remain authoritative.
   Hidden requests and deterministic fills use approved same-material paint.
   Exposure estimates use actual Bone2D samples, with 34 Shale and 10 Wisp
   requests. No hidden-material TODOs remain. Wisp crown/arc labels bind to core.
   This is CPU partition proof; native rest equality remains a separate gate.
3. **Production:** board pools load the shared maquette renderer for
   `bile_bloomer` and `lightning_wisp`. Authored intent/action selectors route
   each verb separately. The resolved board step anchors the rig once, avoiding
   double travel. Existing feedback boundaries remap to authored contact for
   sound/VFX; authored durations control playback. Hit recovery can finish after
   the popup; utility status feedback does not replay its clip. Death holds its
   preceding facing. Pre-battle, inspection and turn portraits use the same
   renderer through an atlas of its logical source region. Existing frames,
   input handlers, text, outcomes, saves and analytics are preserved. Density
   sources, registrations, derived paint and the shadow cache are updated.
   The four new native rest records intentionally remain pending.
4. **Real-time review:** `tools/maquette_cutout_review.py` composes the native
   capture at 60 fps, with front left/rear right, exact 2x nearest scaling,
   #1E1E24 background and clip name above. Idle/move repeat three times; other
   actions twice; death once with a one-second terminal hold. `--render` first
   invokes the required visual runner. No MP4 has been rendered by this worker.
5. **Gates:** a separate director/geometry oracle derives expectations without
   invoking the compiler. Actual local/global Bone2D matrices and opacity are checked at
   authored keys and midpoints in both views. Production recording uses real
   resolver steps and RunScene callbacks, with a fixed presentation clock;
   six changing bone poses and six changing native frames per clip, contact,
   non-restarting actions and hit retirement are required. Native and production
   manifests bind source, compiled data, layouts, runtime and production paint.
   Raise-sign, missing-key and frozen-idle mutations fail; frozen idle is also
   caught by the actual production recorder. A compiler sign bug is also rejected
   after recompiling and sampling while that broken compiler remains installed.

## Files

- `tools/maquette_cutout_{build,exposure,gates,review}.py` and
  `tools/maquette_motion/{compiler,contract,exposure,gates}.py`.
- `scripts/maquette_cutout_runtime/`: motion, rig, renderer, action, presentation,
  portrait adapters and thin creature registration scripts.
- `assets/units/{shale_bloomer,lightning_wisp}_cutout/` and both corresponding
  `experiments/cutouts/` cases, retained inputs and maquette exports.
- Focused integration hooks in `combat_board_view.gd`, `run_scene.gd`,
  `cutout_context.gd`, `actor_presentation.gd`, pre-battle views/layout and the
  turn-order landing strip.
- Identity/density rest ledgers, density outputs/sources and
  `assets/generated/unit_shadow_cache.res`. The legacy identity rows bind derived
  rest snapshots to the supplied approved paintings; no worker judge verdict was
  added. Unrelated identity entries are unchanged. Final rest ledgers are refreshed
  by `seal-density` after the design owner's native rebake.
- `tests/maquette_cutout/`, `tests/maquette_cutout_test.gd`,
  `tests/test_semantic_maquette_motion.py` and the affected existing suites and
  strike/pre-battle fixtures. Superseded idle/meshed-rig assertions were replaced
  with the new maquette contract; unrelated assertions remain.

## Retained headless proof

`proof/verification_results.json` records exact final result lines, log paths,
full-suite outcomes and remaining native requirements. `proof/motion_samples.json`
contains actual Godot matrices; `proof/motion_gates.json` is their source-bound
verification. `proof/production_logic_frames.json` and
`proof/production_logic_gate.json` retain real callback progression without a
native-pixel claim. `proof/input_contact_sheet.png` contains the inspected inputs;
`proof/{front,rear}_ownership_3x.png` shows ownership. Hidden request/fill records
are in `hidden_requests/` and `hidden_fills/`.

## TODO_DESIGN placeholders

None added to either delivered case. Compiler design dictionaries and hidden-fill
pending-design lists are empty. Wisp's explicit authored `body.lift_px` idle track
is retained alongside its independent core and tail motion.

## Chosen defaults

All choices here are test/proof or numerical implementation settings:

- Existing 255px source, 512px action canvas and (128,128) source offset.
- Diagnostic movement step 96px at source pixel scale 1; test hit HP 30;
  eight settling frames; inherited proof presentation-clock step 6000us.
- Matrix gate tolerance 0.00003; phase comparison epsilon 0.000001; oracle
  angular degeneracy epsilon 1e-12.
- Native proof label y=60, height=60, vertical figure offset=40; Godot's default
  proof font/theme. Input contact thumbnails are at most 256px, four columns.
- Prototype encoding settings: H.264 CRF 16, medium preset, two encoder threads.
- Synthetic math fixture: root alpha .5, core alpha .4, squash .8 and uniform
  scale 1.1. These values are never installed into production motion data.

The 60fps clock, review layout/background/repeats, action timing, amplitudes,
contacts and intent strings are director values. Density values follow the
existing rule and art scales; floor anchors derive from registered maquette roots.

## Proof for the design owner

The complete sequence is also executable as `bash proof/design_owner_proof.sh`
from this case directory. Run from this worktree. No windowed command below was attempted by the worker.
The long native timeout covers sustained PNG capture; startup watchdogs and
single-attempt behavior remain enabled. Use fresh result-manifest paths on reruns.
The generic screenshot runner validates representative opaque scene composites;
the semantic native gate checks every bound raw frame, including Wisp's authored
fully transparent death endpoint.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && mkdir -p output/rr-04
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/output_gdignore.py

# Native rest identity against the approved, untreated case paint.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/native_contract.json --result-manifest output/rr-04/shale-rest-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/shale_bloomer/mq3 --output res://output/rr-04/shale-rest --rest-only
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/native_contract.json --result-manifest output/rr-04/wisp-rest-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/lightning_wisp/mq4 --output res://output/rr-04/wisp-rest --rest-only

# Native clip rendering, each authored clip sampled at 60fps in both views.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_render_contract.json --result-manifest output/rr-04/shale-render-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/shale_bloomer/mq3 --output res://output/rr-04/shale-native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_render_contract.json --result-manifest output/rr-04/wisp-render-result.json tests/maquette_cutout/native_capture.gd -- --case res://experiments/cutouts/lightning_wisp/mq4 --output res://output/rr-04/wisp-native

# Verify all captured files/rests and signed bone motion.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --native output/rr-04/shale-native --output output/rr-04/shale-native-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --native output/rr-04/wisp-native --output output/rr-04/wisp-native-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --stream -- godot --headless --path . --script tests/maquette_cutout/samples.gd -- --case res://experiments/cutouts/shale_bloomer/mq3 --output res://output/rr-04/shale-samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --stream -- godot --headless --path . --script tests/maquette_cutout/samples.gd -- --case res://experiments/cutouts/lightning_wisp/mq4 --output res://output/rr-04/wisp-samples.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --samples output/rr-04/shale-samples.json --output output/rr-04/shale-motion-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --samples output/rr-04/wisp-samples.json --output output/rr-04/wisp-motion-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tests/test_semantic_maquette_motion.py -v

# Finish density rests using the real renderer, then record and seal them.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only shale_bloomer_cutout
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tools/rebake_cutout_rests.gd -- --only lightning_wisp
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/process_board_density.py --only shale_bloomer_cutout --record-rests
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/process_board_density.py --only lightning_wisp --record-rests
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_build.py seal-density --creature shale_bloomer
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_build.py seal-density --creature lightning_wisp
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/process_board_density.py --check

# Real production callback capture at 1920x1080, 100% UI scale.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/shale_bloomer_production_contract.json --result-manifest output/rr-04/shale-production-result.json tests/maquette_cutout/production_capture.gd -- --type bile_bloomer --output res://output/rr-04/shale-production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/visual_probe_runner.py --task-id rr-04 --no-headless --display-driver macos --audio-driver Dummy --timeout 900 --expect-size 1920x1080 --proof-contract tests/maquette_cutout/lightning_wisp_production_contract.json --result-manifest output/rr-04/wisp-production-result.json tests/maquette_cutout/production_capture.gd -- --type lightning_wisp --output res://output/rr-04/wisp-production
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/shale_bloomer/mq3 --production output/rr-04/shale-production/frames.json --output output/rr-04/shale-production-gates.json
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_gates.py --case experiments/cutouts/lightning_wisp/mq4 --production output/rr-04/wisp-production/frames.json --output output/rr-04/wisp-production-gates.json

# The two real-time MP4s, without retiming or interpolated frames.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_review.py --case experiments/cutouts/shale_bloomer/mq3 --capture output/rr-04/shale-native --output output/rr-04/shale_bloomer_review.mp4
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/maquette_cutout_review.py --case experiments/cutouts/lightning_wisp/mq4 --capture output/rr-04/wisp-native --output output/rr-04/lightning_wisp_review.mp4

# Owner-owned playable inspection fixture and launch.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/inspection_fixture.py --task-id rr-04 --scenario combat --enemy-types bile_bloomer,lightning_wisp --enemy-intents bile_burst,spark_dart --summary 'rr-04 Shale Bloomer and Lightning Wisp maquette rigs' --manifest /private/tmp/labyrinth-inspection-manifests/rr-04.json --launch

# Full final suites after native rest completion.
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 tools/godot_task_runner.py --task-id rr-04 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-04 && python3 -m unittest discover -s tests -p 'test_*.py' -v
```

Expected native capture locations are the `output/rr-04/{shale,wisp}-{rest,native,production}`
directories above. The fixture command is provided for the design owner and has
not been generated or verified by this worker. UI/art judge inspection is also
owner-owned, consistent with the explicit no-review worker instruction.
