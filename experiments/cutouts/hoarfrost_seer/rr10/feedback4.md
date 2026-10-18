# rr-10 feedback 4 — deeper joint continuations

The requested source/rig corrections are implemented. The approved painting,
protected motion, rope mask, source ownership, idle keys and calibrated native
gates are byte-identical to `477e6d24a`. Only derived hidden continuations,
mesh cuff weights and their dependent data changed. No existing runtime hook,
production selector, other creature, threshold, audio or VFX changed. Changes
remain uncommitted; no windowed command or peer review was run.

## Acceptance

1. **Wrists:** both hidden wrist continuations retain the old transverse
   coverage and extend from 3 to 5 px along the forearm axis. The continuation
   remains behind inherited higher rest layers, including the staff: clipping
   it to the sleeve alone would cut away the lower wrist corner hidden by the
   staff at rest. The last 4 px of cuff vertex rows, projected along the
   forearm and ending at the wrist, are entirely `fore_<side>` weighted.
   Captured mark 30, bolt 27 and death 30 body masks have no joint-seam holes
   after adding the current rigid tucks through the existing rr-05 path.
2. **Feet:** both feet carry 4 px of upward hidden top continuation. The new
   rigid foot tucks close the captured move 9 opening. Restoring the old near
   foot tuck reopens the seam and fails the unchanged calibrated hole gate.
3. **Robe:** the existing hidden cloth surface, including rr-05 seed coverage,
   is extended by the 3-to-5 px difference across its top and both belt sides,
   behind higher rest layers. Extending visible ownership alone misses some
   side coverage. The resulting source is still one robe mesh. Cloth comes
   from the exact rr-05 non-outline donor field. The source rest composite has
   **0 changed pixels**. The front robe's covered bounds now begin at source
   y=133 (previously 135), so its source grid, UVs and dependent weight/proof
   templates were regenerated using the unchanged 2 px / top-4-row policy.
4. **Gates and mutations (partial proof):** all 629 real sampled poses pass
   cuff/hand and hem/foot attachment checks. The calibrated hole gate passes
   four captured native body fixtures with current rigid tucks (mark 30,
   death 30, move 9, bolt 27). Reinstating the old wrist tucks fails mark/death;
   reinstating the old foot tuck fails move 9. The existing 3 px far-elbow
   mutation still fails. **No all-pose current mesh pixel verdict is claimed.**
   That check needs fresh renderer captures: the sandbox has no window server,
   and the binding spec explicitly forbids a CPU mesh raster oracle. The
   headless fixture tests preserve captured GPU mesh/body masks and rasterize
   only rigid tucks through the already permitted rr-05 path. They establish
   these regressions, not acceptance of all newly rendered mesh pixels.

An exploratory CPU alpha raster was discarded because its sampling flags
were not native evidence and it would substitute for the forbidden mesh
oracle. It is absent from the implementation and acceptance path. Native
freshness checks and `sheets` refusal remain intact; stale captures were not
rebound or certified. The all-pose native hole gate remains for the director.

The source idle audit preserves all original texels and the authored rigid
translations. Added continuation produces up to four additional source pixels
in 36 of 50 idle frames (132 total appearances); stripping those authorized
new tuck texels restores the old source frames exactly. This is exposed cloth
coverage, permitted by feedback 1, rather than a new motion channel.

The all-old-body/current-rigid-tuck diagnostic still flags 71 of 467 retained
body frames. Those are not current mesh render results: it deliberately leaves
the old cuff and robe rendering untouched. Fresh native proof is still needed
for the data changes to those meshes.

## Files

Implementation:

- `tools/humanoid_cutout/tucks.py`: per-piece depths, forearm/upward extrusion,
  retained transverse coverage, existing-cloth extension and rest occlusion.
- `tools/humanoid_cutout/mesh.py`: specified four-row forearm cuff override.
- `experiments/cutouts/hoarfrost_seer/rr10_build.py`: wires the tuck policies,
  foot masks, source continuations and regenerated mesh/proof data.
- `tools/humanoid_cutout/seam_proof.py`: existing rigid raster plus hash-bound
  captured body masks; it never skins or rasterizes a mesh.
- `experiments/cutouts/hoarfrost_seer/rr10_idle_identity.py`: rigid-group source
  idle audit against the director's base; no mesh rasterization.
- `experiments/cutouts/hoarfrost_seer/rr10_tuck_diagnostic.py`: all retained old
  GPU body frames plus current rigid tucks, clearly separate from acceptance.
- `experiments/cutouts/hoarfrost_seer/rr10_seam_fixtures.py`: reproducible
  extraction from the director's retained native capture, without a GUI run.

Derived data:

- Case `pieces/front/hidden_hand_{near,far}.png`,
  `hidden_foot_{near,far}.png`, `robe.png`, and matching `checks/front/` files.
- Case `tucks/front_hand_{near,far}.png`, `front_robe.png`, new
  `front_foot_{near,far}.png` and their keep-import metadata.
- Case `layouts/front.json`, `seams/front_{robe,sleeve_far}.png`,
  `seams/{robe,sleeve_far}_mesh.json`, `holes/robe_mesh.json`.
- `assets/units/hoarfrost_seer_cutout/humanoid_v2/front.json`.

Tests/proof:

- `tests/test_rr10_tucks.py`: six source, attachment, captured seam and mutation
  tests. Existing tests and their assertions were preserved.
- `tests/rr10/feedback4/captures.json` plus fifteen native body/seam/reference
  mask PNGs. This data is explicitly labelled historical captured body proof.
- Case `proof/build.json`, `proof/samples.json`, `README.md`, this handoff and
  `proof/feedback4_verification.md` (full exact result lines).

## TODO_DESIGN and chosen defaults

No new TODO_DESIGN or player-facing default. The existing
`TODO_DESIGN_mq6_rear_delivery_and_paint` stop remains. The depths (5/4/5),
forearm cuff rows (4) and retained base tuck (3) are director-supplied values.
The test timeout is the existing named 180-second headless proof timeout.
Fixture frames are the director's reported mark 30, death 30, move 9 and bolt
27. Proof geometry uses the existing 512 px canvas / 128 px source origin.

## Proof for the design owner

From this worktree, at 1920×1080 and 100% UI scale through the existing visual
runner and proof contracts:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
```

`native` refreshes samples, captures every real presented frame and runs the
unchanged pixel gates. Outputs: `proof/native/frames.json`,
`proof/native/front_<clip>/pose_<frame>.png`, `proof/native_gates.json`.
Accepted sheets: `proof/contact_sheets/front_<clip>_3x.png`. The rear is still
pending the director's approved mq6 delivery and repaint.
