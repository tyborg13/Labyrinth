# rr-10 — exact protected rope mask

Front-only implementation on `codex/rr-10`; worker changes remain uncommitted.
No windowed run, peer review, fixture publication or production promotion.

## Acceptance

1. The director mask is imported byte for byte as
   `inputs/rope_mask_front.png`, bound to SHA256
   `26bc001a33b23ba21dada83c27e8c0e1d7fd21eb067e7b5ded4329509595444c`.
   It is validated as source-sized 255×255 RGBA, exactly 465 opaque white pixels
   and one connected component. Hashes are recorded in `inputs.json`, the layout
   override and build report, and included in the native proof input bindings.
2. All masked pixels belong to the rigid torso: 391 were already torso, 74
   transfer from the robe. Every unmasked pixel retains its previous owner and
   RGBA. The source partition gate independently reconstructs baseline ownership
   and applies the exact mask to detect regressions. Rest composition remains
   pixel-identical to the approved painting (0 px mismatch).
3. The former 74 robe-owned rope pixels become a required hidden cloth domain,
   stored in `ownership/front_rope_underlay.png`. The robe fills it using the
   existing rr-05 non-outline cloth continuation. Source gates verify actual
   coverage and the exact cloth field. Tests cover pixels exposed by the authored
   2 px idle drop. Removing hidden cloth or returning rope to the mesh fails
   even when the composed rest image remains unchanged.
4. The colour selector, its obsolete diagnostic and its placeholder are removed.
   `rope_masks.rear.file` is `inputs/rope_mask_rear.png`; its hash remains unset
   until the director supplies that protected mask with the rear repaint.
   The only active design placeholder is `TODO_DESIGN_mq6_rear_delivery_and_paint`.

No motion data, rig transforms, idle timing, weights or common runtime hooks were
changed. Board/pre-battle/portrait promotion remains deferred until the approved
rear exists and both views pass proof. No other creature's data or art changed.

## Implementation and proof

`tools/humanoid_cutout/ownership.py` owns protected-mask validation, exact
ownership overrides and source-partition validation. `rr10_build.py` wires the
mask, cloth domain and staged configuration. `gates.py` invokes the partition
check. `tests/test_rr10_rope.py` checks exact ownership/unmasked preservation,
cloth coverage, rear input configuration and three planted regressions.

Generated changes are limited to the Seer torso/robe materials and check masks,
their layout/seam/tuck metadata, staged front configuration and proof records.
The provided PNG is never rewritten. Historical native captures remain stale.

Observed tests and logs: [feedback2_verification.md](proof/feedback2_verification.md).
Complete changed-file list: [feedback2_changed_files.txt](proof/feedback2_changed_files.txt).

## Proof for the design owner

The worker stops here for real-renderer front review. Exact 1920×1080 / 100%
commands (through the mandatory visual runner) are:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh rest
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh native
cd /Users/borgerding/workspace/Labyrinth.worktrees/rr-10 && sh experiments/cutouts/hoarfrost_seer/rr10_proof.sh sheets
```

Run in that order. Outputs are `proof/native_rest/`, `proof/native/`,
`proof/native_gates.json`, failure crops under `proof/native_failures/`, and
`proof/contact_sheets/front_<clip>_3x.png`. None is claimed as fresh windowed
proof by the worker. The existing other proof commands remain available, but
the director requested this front review before any rear work.

## Chosen defaults / remaining work

No new defaults. Canvas size, mask count/connectivity, ownership and idle offset
come from the director's data and binding spec. Existing proof-only fixture and
timeout constants are unchanged.

Front native verification belongs to the director. Rear mask/maquette/painting,
two-view proof and production promotion remain deferred; no rear is fabricated.
