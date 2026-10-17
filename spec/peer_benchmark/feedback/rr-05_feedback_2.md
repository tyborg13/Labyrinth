# rr-05 feedback 2 — the windowed proof fails native verification (director run)

I ran `proof_for_design_owner.sh` under the director lock, minus the final inspection launch. The two derives passed.
The first native review step stopped the script (`set -e`), so nothing after it ran: no Wisp MP4, promote, adoption or
rebake.

- Log: `output/rr-05/director_windowed_run1.log`
- Report: `output/rr-05/shale-native/pixel_gates.json`
- Captures: `output/rr-05/shale-native/**`, including `pixel_frames.json` and `pixel_samples.json`

`ValueError: Pixel/feature verification failed` reports 118 errors, all "native part does not match its source
transform". The most frequent are front/root_stem_r ×14, rear/root_stem_l ×14, front/feature_amber_right ×12,
front/hidden_root_tip_r ×8 and rear/root_tip_l ×8. Petals, tendrils and the other amber features also appear.

1. **Find the root cause from the saved captures.** Candidates are GPU sampling at the 1.5° rotation steps, pivot or
   offset rounding that differs between the CPU model and the native transform, the order of whole-pixel snapping
   versus rotation, or a hidden-fill node drawn with a different transform.
   - State the cause with evidence: one failing part, its frame, the expected vs captured bounds, and the pixel diff.
   - Add a headless regression that fails before the fix and passes after, if one is possible. If it isn't, explain
     why.
2. **Fix the runtime or the model.** Native output must match the CPU source transform within the existing
   tolerances. Never loosen a tolerance. Features (amber nodules, crown gem, eye) must stay single nodes with
   unchanged pixels.
3. Keep `proof_for_design_owner.sh` in run order and resumable. Add a flag or split it so I can re-run from the native
   review step without repeating the derives. Remove the inspection launch from the script, because I run that
   separately.
4. Delete the stale `output/rr-05/shale-native` captures once your diagnosis is recorded, so the next run starts
   clean (disk hygiene).
