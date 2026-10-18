# rr-10 feedback 5 implementation handoff

Uncommitted work on `codex/rr-10`, based on `98c4e16df`. No merge, commit, peer review, publication, queue edit or windowed run was performed.

The front fills and both-view production routing are implemented. This is **not a complete native acceptance**: the director must render the changed meshes and rebake/record density rests. A separate rear-foot design placeholder remains below. The full Python suite honestly retains its density-rest failure.

## Numbered requirements

| Requirement | Implementation and observed proof |
| --- | --- |
| Feedback 5.1: shoulders/armpits | Torso continuation extends 4 source pixels under both sleeves/armpits. Each sleeve's existing inner tuck extends another 3 pixels under the torso. Original visible front ownership and protected motion are unchanged. |
| Feedback 5.1: smaller seams | Covered belt-side cloth and hem continuations use the spec's 3 px minimum. Foot continuations retain their transverse covered width. Where a garment continuation must sit under a boot or another lower layer, a covered mesh layer uses the **same garment weight field**, not a second independently moving garment. |
| Feedback 5.1: flags/negative space | The captured 50 flags were inspected by boundary owner: shoulder/chest, belt/robe, hem/foot, and the move-41 outline pair. None was staff-bounded negative space. Current source coverage and bone gates pass. The current GPU hole/stray result is unobserved pending the director's native run. |
| Feedback 5.2: rear inputs | Uses `mq6_rear` and the independently certified mq-06 delivery via `spec_for_view`; never the mirrored rr-07 rear. Painting digest and delivery manifest are verified. Front delivery PNGs and front joint values are checked against the frozen rr-07 registration. |
| Feedback 5.2: rope | Protected rear mask copied byte-for-byte, 242 pixels, one component; SHA-256 `2ded642ed2062d2b37c31c4aad01bb1fc717036ca6cd85b3994836b7c0b03348`. Exact ownership is torso, with cloth continuation under any transferred robe pixels. Front 465-pixel mask remains unchanged. |
| Feedback 5.2: rear construction | Same ten logical pieces, three garment fields, source grid/weights/cuff rules/tucks and runtime. Near/far hem weights follow the actual rear joint side. Staff is in front of the rear body, including the head; its grip remains above it. Both source rest assemblies differ from their approved paintings by **0 px**. The fully occluded rear near foot remains transparent under an explicit design placeholder. |
| Feedback 5.2: promotion | Board, live/reduced-motion renderer, pre-battle and portrait consumers use the production-owned v2 closure. Rear floor registration and hood height derive from the supplied rear root and painted head bounds. Actual resolver/callback tests preserve clip contacts and idle seed behavior. Standalone non-editor production PCK loads both views and every clip without authoring files. |
| Feedback 5.2: density/review | Both views' untouched paint is adopted and processed. New rests and retained historical rests are registered. **Native rest certification remains pending**, with a forced two-view rebake probe and exact commands below. Two-view rr-04 review composition is enabled. |
| Original §1 cut / §2 weights | Fused torso/collar/belt, fused crystal/staff, one robe field and two sleeve fields. Covered draw layers share their garment's field and bones. Two-pixel grid, four pelvis rows, linear vertical/smoothstep horizontal robe weights, elbow blend and rigid four-row cuffs are checked. |
| Original §3 fills / §4 runtime | Same-surface rr-05 donors, no outline in continuations, covered rest identity. Existing source-pixel IK/FK, inward, item-world-angle/release and world-step behavior are reused; 1,258 authored/presented bone samples pass for both views. No motion data or silhouette-gate thresholds changed. |
| Original §5 production / §6 gates | Production registration and callbacks are exercised. Idle rotation, split robe, 2 px tuck, 40° staff, moved ward hem, signed-key/midpoint, historical stray clusters, 3 px elbow opening, wrist/foot opening and new shoulder/belt regressions remain rejected. Full current native acceptance is deferred, not replaced by a CPU mesh raster oracle. |

## Files changed

The exhaustive list is [feedback5_files.txt](feedback5_files.txt). Principal files:

- `rr10_build.py`, `rr10_density.py`, `rr10_pack.sh`, `rr10_gates.py`, `rr10_proof.sh`; case inputs, source partition, parts, meshes, checks, seams, tucks and protected rear-mask import.
- Production `assets/units/hoarfrost_seer_cutout/` layouts, renderer, rig, integration record and `humanoid_v2/` paint/motion closure.
- New reusable helpers: `tools/humanoid_cutout/source_view.py`, `skin_layers.py`, `promotion.py`, `integration.py`, `production_gates.py`; existing mesh/tuck/depth/seam/gate helpers extended.
- Minimal shared maquette hooks this round: **`presentation.gd`** selects the v2 asset directory for Seer; **`action.gd`** reads motion from that directory; **`portrait.gd`** reads the same rest registration. Other identities resolve the same paths as before. Existing `motion.gd`, `rig.gd` and `renderer.gd` v2 hooks were reused unchanged.
- Seer-only board/rest-path and rear floor/HUD registration in `combat_board_view.gd` and `actor_presentation.gd`; Seer-only art/density registry records and untouched density sources.
- `tests/rr10/` native/production/binding/runtime/pack/density probes, retained GPU seam fixtures and focused Python tests. Only the Seer branch of legacy rr-07 tests changes to the v2 contract; Thrall's existing hierarchy/pixel assertions remain.

No Bloomer, Wisp, Thrall, Lancer, Herald, Gloam or Shrike creature assets/data were edited.

## Observed headless results

| Command/probe | Exact result / log |
| --- | --- |
| `python3 experiments/cutouts/hoarfrost_seer/rr10_build.py` | `RR10 FRONT BUILD: PASS (rest mismatch: 0 px; 3 joint_meshes; protected tracks byte-identical)`; same rear line; `RR10 TUCK COVERAGE: 0 missing source pixels (both views; see proof/build.json)`. The three are the logical garment fields; covered draw layers are additional polygons sharing those fields. `/private/tmp/rr10-feedback5-build.log` |
| `samples.gd` through rr-10 runner | `RR10 BONE SAMPLES: PASS (1258 poses; headless transforms only)` — `/private/tmp/rr10-feedback5-samples.log` |
| `python3 -B experiments/cutouts/hoarfrost_seer/rr10_gates.py` | `RR10 BONE/CUT GATES: PASS (0 errors)` — `/private/tmp/rr10-feedback5-gates.log` |
| Focused `test_rr10*.py` | `Ran 45 tests in 42.021s` / `OK` — `/private/tmp/rr10-feedback5-focused-final.log` |
| Legacy production compatibility | `Ran 5 tests in 71.411s` / `OK` — `/private/tmp/rr10-feedback5-legacy-production.log` |
| Updated runtime | `RR07 RUNTIME: PASS (73057 checks, 0 failures; headless logic only)` — `/private/tmp/rr10-feedback5-runtime.log` |
| Native probe `--validate-only` | `RR10 NATIVE PROBE LOAD: PASS` — `/private/tmp/rr10-feedback5-native-load-final.log`; load/mask validation only, no renderer claim. |
| Standalone release package | `RR10 PRODUCTION PACK: PASS (2 views; source-only PNG loading; editor=false)` — `/private/tmp/rr10-feedback5-pack-final.log`; package `proof/production_pack/rr10.pck`. Reproduce with `sh experiments/cutouts/hoarfrost_seer/rr10_pack.sh`. |
| Art / icon / UI identity suites | `Ran 111 tests in 46.436s` / `OK`; `Ran 7 tests in 0.036s` / `OK`; `Ran 25 tests in 2.498s` / `OK`. Logs `/private/tmp/rr10-feedback5-{art,icon,ui}-identity.log`. |
| Full Godot suite | `TEST REGISTRATION AUDIT: PASS (744 scripts; full suite=400, quarantined=29, windowed probe=315)`; `MAIN BODY ASSERTIONS: 378906`; `FULL SUITE RUNTIME: 401.469 seconds (budget 900 seconds)`; `TEST RESULT: PASS` — `/private/tmp/rr10-feedback5-godot-full-final.log`. |
| Full Python suite | `Ran 921 tests in 873.585s` / **`FAILED (failures=1, skipped=63)`** — `/private/tmp/rr10-feedback5-python-full-final.log`. Sole failure: `test_shipped_derivations_and_manifest_are_current`, requiring native density rest records. Other density coverage/derivation tests pass. |

Full-suite commands:

```sh
python3 tools/godot_task_runner.py --task-id rr-10 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd
python3 -m unittest discover -s tests -p 'test_*.py' -v
```

The initial full Godot attempt timed out on obsolete rr-07 Seer hierarchy assertions; the final run above passes after replacing that Seer branch with v2 checks. No pre-existing unrelated failing assertion was rewritten.

Current pixel-proof limits: the four retained shoulder/belt GPU-body fixtures close with the new rigid fills and reopen with the old fill mutation. Historical body comparison closed 45/50 flags before the additional mesh continuations; those older captures cannot certify the changed meshes. Conservative rigid opaque-texel bounds fit the 512px proof canvas with 0 violations (`proof/feedback5/rigid_canvas_bounds.json`). No CPU mesh raster oracle was introduced, no stale native proof was rebound, and no fresh native hole/stray PASS is claimed.

## Proof for the design owner

Run from `/Users/borgerding/workspace/Labyrinth.worktrees/rr-10`, in this order. Density must precede captures because native rest changes invalidate the production input binding.

```sh
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh density
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh rest
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh idle
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh production
sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh review
```

`density` expands to these exact native/recording commands:

```sh
python3 tools/visual_probe_runner.py --task-id rr-10 --no-headless --display-driver macos --audio-driver Dummy --timeout 180 tests/rr10/density_rebake.gd -- --only hoarfrost_seer_cutout
python3 tools/process_board_density.py --record-rests --only hoarfrost_seer_cutout
python3 tools/godot_task_runner.py --task-id rr-10 --stream -- godot --headless --path . --script tools/generate_unit_shadow_cache.gd
python3 tools/process_board_density.py --check --only hoarfrost_seer_cutout
python3 experiments/cutouts/hoarfrost_seer/rr10_density.py seal
```

The rebake always renders both promoted views, even when cleanup changes no texels. Recording includes two active v2 rests and two retained historical rests. Native density records were not fabricated: the [cutout skill](../../../../.codex/skills/create-labyrinth-cutout/SKILL.md) requires “process → native rest-rebake → `process_board_density.py --record-rests` → shadow cache”, and this worker has no window-server access.

Expected outputs under `experiments/cutouts/hoarfrost_seer/rr10/proof/`:

- `native_rest/rest_pair.png`, `native/frames.json`, `native_gates.json` (required 0 errors).
- `contact_sheets/front_<clip>_3x.png` and `rear_<clip>_3x.png`, every presented frame.
- `seer_protagonist_idle.mp4`: board scale, 2× nearest, #1E1E24, five loops.
- `production_native/frames.json` and real-progression captures at 1920×1080 / 100% UI scale.
- `hoarfrost_seer_review.mp4`: front left/rear right, 2× nearest, #1E1E24, centered clip label, idle ×3 / move ×3 / other actions ×2 / death once plus 1 s hold.

All windowed commands remain unrun here. The design owner owns the inspection fixture and review/publication steps; this feedback requested no worker fixture command or sign-off.

## TODO_DESIGN placeholders

`TODO_DESIGN_rear_foot_near_hidden_paint` in `inputs.json` / `cutout.json`: the rear near-foot solo is fully occluded in the categorical map (0 visible label pixels), so its painting partition has no near-foot paint to donate. The registered rigid piece remains transparent. A director decision is pending on the hidden donor; no boot paint was invented or borrowed without that decision. Evidence: `proof/feedback5/rear_near_foot_source.png` (approved paint, registered part map, solo; 4× diagnostic).

No rope-colour or rear-delivery TODO remains.

## Chosen defaults

Only proof/implementation values: diagnostic crop margin **3 px**, zoom **4×**, label height **18 px**, stored as `DEBUG_CROP_MARGIN_PX`, `DEBUG_CROP_ZOOM`, `DEBUG_LABEL_HEIGHT_PX` in `proof/feedback5/crop_defaults.json`; package executable mode `EXPORT_EXECUTABLE_MODE = 0o755`. The package smoke reuses the existing `PROOF_PHASE = 0.3`. No new player-facing tuning, motion, colour, font or camera value was chosen.

## Open issues

1. Resolve the fully occluded rear near-foot hidden paint choice.
2. Run native density rebake/recording, then rerun the Python suite to clear its sole failure.
3. Run fresh native/rest/sheets/idle/production/review. Current mesh seam closure, stray pixels and visual weight behavior remain director-renderer acceptance, not an observed worker PASS.
