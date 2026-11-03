# mq-25 — accepted delivery, final gate corrections

The native delivery is **accepted (`accepted: true`)**. Both proof verifies
pass. Feedback 3 closes the two review gaps from `167b89f7e`; all geometry,
paint, camera, pose, labels, capture pixels and existing sidecars are unchanged.
There are no pending design decisions.

## Final requirements

1. **Required columns survive occlusion.** The complete projected lower
   `grip_ring`, `held_chain` and `lantern_cap_ring` regions in the unoccluded
   native lantern solo define the required columns. Depth-tested part-map
   visibility supplies the visible pixels separately. Every required column
   must show assembly pixels below that column's lowest native hand pixel.
   All **30/30 columns pass in both views**. Wholly hiding front column
   **722**, or **722–724**, now fails while retaining all 30 required columns.
   Existing solo captures suffice; no ID pass or recapture was needed.
2. **Far palm faces backward.** The oracle recovers the native palm normal
   from oval topology. It projects the established body-backward direction
   (-X) perpendicular to the live elbow–wrist axis, without importing hand
   constructor axes or reading authored palm metadata. The existing 0.1°
   angle tolerance applies. Native error is **0.000143327211°**. Rotating the
   complete far hand **180° about the elbow–wrist axis** now fails.
3. **Current entry points describe acceptance.** This README and
   `verification_results.json` are current. Prior entry points, native
   reports, bindings and regeneration receipts are retained under
   `history/mq25_feedback2/`; older round reports remain historical.

The director's 8 px top-bar allowance remains: the present **6 px passes**,
while **12 px fails**. Hiding the chain and cap ring behind the fist fails.
The ratified penetration limit remains 0.005 H (native 0.004565567813 H), and
fingertip-to-palm limit remains 0.014 H (maximum 0.013247505803 H). Wire
clearance **0** and signed crossings **[0, 0, 0, 0]** remain diagnostics.
The 12° fan, thumb, mantle, labels and all eight segment lengths still pass.

## Verification and preservation

The two new regression methods were run against the unchanged `167b89f7e`
gates before the fixes: `Ran 2 tests in 5.113s`; `FAILED (failures=3)`.
Those failures expose the two column cases and reversed hand being wrongly
accepted. Both methods now pass within the complete mq24 focused suite.
See `feedback3_validation/regressions.json` and the pinned-baseline log.

Observed final results:

| Check | Exact result lines |
|---|---|
| mq24 | `Ran 53 tests in 31.261s`; `OK` |
| mq20 | `Ran 35 tests in 31.041s`; `OK` |
| Delivery and sidecars | `Ran 30 tests in 6.372s`; `OK` |
| Art identity | `Ran 111 tests in 67.838s`; `OK` |
| Python resource audit | `ISOLATION AUDIT: 236 modules`; exit 0 |
| mq24 verify | `MQ24_HASH_BOUND_DELIVERY: PASS; regeneration verified` |
| mq20 verify | `MQ20_HASH_BOUND_DELIVERY: PASS` |
| Gate revalidation | `MQ24_GATE_REVALIDATION: PASS; captures_byte_identical=true; native_meshes=57` |

This is **229 focused tests**, with no full suite run. Exact commands, logs,
acceptance criteria and outcomes are in `verification_results.json`.

`proof revalidate` only admits changes to the two gates and their proof
entry/helper. It refuses geometry, renderer and other input changes. It
compiles a fresh copied input project, builds fresh native geometry through
the approved bridge, and opens it for the current geometry audit. Its mesh
hashes must exactly match the accepted build. It then remeasures the original
accepted captures and refreshes their proof bindings. The original clean
regeneration receipts remain archived; the updated receipt explicitly records
that capture bytes were reused unchanged. No render is represented as new.

All **57/57 source pieces**, **57/57 native mesh hashes**, **247/247 protected
input files**, and **308 checked capture/sidecar files** match their baselines.
The full hash list is `ratification_validation/geometry_sha256.md`; current
readback is `feedback3_validation/geometry_preservation.json`. Combined native
mesh SHA-256:

`943a4519b9f457746fc3d53609c2a26e533e8b253cf1ac7668a45df1d50e05bd`

The fresh opened-native audit catches **6/6** required mutations, with **0**
survivors. Its mutation and segment tables are in `feedback3_validation/`.
Director prompt inventory and reviewed-commit history pins remain unchanged.
Paint-job trees and mq20 were not edited; sidecars remain in place.

## Files changed and chosen defaults

- Gates: `capture_gate.py`, `rule_measure.py`.
- Proof integration: `proof.py`, new focused helper `revalidation.py`.
- Regressions and revalidation guards: `tests/test_mq24_maquette.py`.
- Accepted delivery: geometry/image audit reports, bindings and clean-source
  regeneration receipts; capture and sidecar bytes unchanged.
- Current documentation/evidence: `README.md`, `verification_results.json`,
  `feedback3_validation/`, and historical report copies under `history/`.

No player-visible defaults were chosen. The backward axis is the existing
coordinate convention; alpha 128 and angle tolerance 0.1° are inherited.
New test fixture fields name the director's exact columns and 180° rotation.
The operational gate-only input allowlist is named `GATE_ONLY_FILES` in
`revalidation.py`; proof output uses `proof/mq25-feedback3-revalidation/`.
`TODO_DESIGN` placeholders: **none pending**. Open implementation issues: none.

## Proof for the design owner

Accepted captures: `delivery/contact_sheet.webp`, the front/rear clay and
part maps, and all four `delivery/*_hand_*_3x.png` crops. The original native
pixels remain in place. The fresh audit model is
`proof/mq25-feedback3-revalidation/native/maquette.blend`.

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq24.proof verify --capture spec/art_identity/maquettes/last_lamplighter/mq24/delivery --regeneration spec/art_identity/maquettes/last_lamplighter/mq24/delivery/validation/regeneration
cd /Users/borgerding/workspace/Labyrinth.worktrees/mq-25 && python3 -B -m spec.art_identity.maquettes.last_lamplighter.mq20.proof verify
```

Windowed commands and `inspection_fixture.py`: **not applicable** to this
offline native maquette; there is no Godot UI scene or playable save. No local
windowed run was attempted. No new asset or sidecar generation was needed.

All changes remain uncommitted. The director owns preflight, contract,
commit, review, fixture and merge/full-suite work; none was run here.
