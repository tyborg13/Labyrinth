# mq-02 worker validation (2026-10-16)

All source edits remain uncommitted on `codex/mq-02`. No peer review, commit,
push, branch change, queue mutation, Blender launch or windowed run was made.

| Command | Observed result |
|---|---|
| `python3 -m unittest discover -s tests -p 'test_*.py' -v` | `Ran 563 tests in 395.215s` / `OK (skipped=61)` |
| `python3 -m unittest discover -s tests -p 'test_maquette_geometry.py' -v` (final focused run) | `Ran 21 tests in 8.968s` / `OK` |
| `python3 tests/test_art_identity_gate.py` | `Ran 111 tests in 44.377s` / `OK` |
| `python3 tools/output_gdignore.py --check` | `OUTPUT GDIGNORE: PASS (12 folders; 2 referenced roots)` |
| `git diff --check` | Exit 0, no output |
| `python3 -m py_compile` for all changed/new Python sources, with task-local `PYTHONPYCACHEPREFIX` | Exit 0 |
| NumPy-only geometry import/build with all `PIL` imports explicitly blocked | `NUMPY_ONLY_MESH_BUILD: PASS` |
| `python3 spec/art_identity/maquettes/director_proof.py --print-only` | Exit 0; 21 director capture/comparison commands printed; no Blender process started |
| Lancer r2 raster preview | `MAQUETTE_RASTER: PASS` |
| Lancer r2 `measure --require-gate` | Exit 1; `MAQUETTE_FIT: FAIL; IoU=0.622604; median band error=0.119198; max band error=7.047354; conflicting bands=[0, 22, 23]` |
| Lancer r2 `fit` | Exit 2; `MAQUETTE_FIT_ERROR: Fit requires resolved design annotations: ...`; no spec_fit.json written |
| Committed-render `compat --require-gate` | Exit 1: gaoler/shrike solo masks pass; lancer/wisp/bloomer visible-label comparisons fail and need director solo proof |

The broad Python run began before the last focused additions. The final focused
run covers the final geometry/raster/fitter implementation and adds old/new
render-proof validation plus a test that band fitting improves a wider source.
The 61 full-suite skips report optional music/audio environments; their exact
reasons remain in the verbose log. No test assertion inherited from the base
branch was changed.

Logs are in `/private/tmp/labyrinth_codex/mq-02/`:
`python-full.log`, `geometry-tests-final.log`, `art-identity-tests.log`,
`compat-gate.log`, `lancer-gate.log`, `lancer-fit.log`, `lancer-raster.log`,
and `director-commands.txt`.

The first explicit compile check hit the environment's default external cache:
`PermissionError: [Errno 1] Operation not permitted:
'/Users/borgerding/Library/Caches/com.apple.python/Users/borgerding/workspace/Labyrinth.worktrees/mq-02'`.
It passed after setting `PYTHONPYCACHEPREFIX` to the permitted task-local temp
directory. No permission escalation was requested.

## Evidence

- [Per-spec IoU table](compatibility_summary.md),
  [every part and baseline path](compatibility_report.json).
- [Lancer r2 diagnostic report](../frostglass_lancer/proof_r2/fit_report.json),
  [overlay](../frostglass_lancer/proof_r2/fit_overlay.png),
  [front parts](../frostglass_lancer/proof_r2/front_parts.png),
  [rear parts](../frostglass_lancer/proof_r2/rear_parts.png), plus solo alpha
  previews and projected joints in the same folder. Overlay and front parts
  were visually inspected by the worker.
- [Hash manifest](proof_manifest.json) binds the worker's source and numerical
  artifacts; it is not a renderer signoff or publication approval.
- [Director capture commands and full acceptance contract](../FITTING.md).

## Unmet acceptance and design placeholders

1. Whole-roster per-part silhouette >=0.98 is **not established**. The committed
   gaoler and shrike solos pass; the other three creatures need the supplied
   old/new Blender proof. Whole silhouettes are above 0.994 for all five specs,
   but that does not replace the per-part requirement.
2. Joint projection meets the available committed gaoler/shrike proof to
   0.01 px. Other committed joint files are unavailable.
3. Sculpted primitives and voxel union are implemented and headless-tested.
   Their actual Blender captures remain director-owned.
4. Measure/fit tooling is implemented, including failure gates and derived-only
   output. It deliberately refuses to fit unresolved design placeholders.
5. Lancer r2 is **incomplete**. The brief contains intent without approved
   numeric r2 geometry or source annotations. `TODO_DESIGN_r2_sculpted_geometry`
   lists hood/slit, shoulder, torso, legs/knee guards, cloak and spear data.
   `TODO_DESIGN_torso_sections`, `TODO_DESIGN_radius_profile` and
   `TODO_DESIGN_shell_cut` mark retained r1 fallback shapes. Source annotations
   are `TODO_DESIGN_source_head_top_px`, `TODO_DESIGN_source_sole_bottom_px`,
   `TODO_DESIGN_source_ground_centroid_px` and
   `TODO_DESIGN_{shoulder,waist,hip,knee,ankle}_source_y_fraction`.

The reported lancer bands are provisional fallback conflicts, not evidence
that the approved proportion intents are incompatible: the unannotated source
frame includes the spear tip. No unapproved body dimensions, cap cuts, folds,
rag seed, pose, face slit or knee-guard geometry were selected.
