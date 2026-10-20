# rr-30 feedback 2 (director: Codex review of a098da6b1, and the rear chroma)

The rigid limbs fixed the stretching: 0% on all 80 pieces, and 862 coverage frames pass. Four items remain. The director
merged integration into your branch.

1. **High: rear identity chroma 0.2004 is over the 0.2 limit.**
   - Director decision: the rear raw's new flap is desaturated 15% toward its grey (`staged/mq11/paint/README.md`,
     commit a9bf0b7e5). Nothing else changed.
   - Re-process the rear job from the updated raw. Re-cut the rear and keep a 0 px rest.
   - **Strict certification must pass:** `python3 tests/test_art_identity_gate.py` passes 111 of 111.
   - `rr30_identity.py` must not write an unconditional `PASS`. Record the director's verdict only when certification
     passes, and fail loudly otherwise.
2. **Medium: declared scale is ignored for skinned pieces** (`stretch.py:133`).
   - Apply the validated per-piece declared scale to the skinned measurement too.
   - Add normalized boundary tests through `report()`.
3. **Medium: required behaviour can disappear without failing a test.**
   - Check freshly sampled runtime flap motion in both views. Disabling the Godot sway must fail.
   - Add `report()` fixtures that must fail for rigid strain and for skinned strain. Disabling either rejection branch
     must fail.
4. **High: native acceptance.** The director runs the windowed density, rest, native, sheets, walk, idle, production
   and review captures after this round. Don't attempt them. Keep the bindings refreshable.
5. Focused tests only.
