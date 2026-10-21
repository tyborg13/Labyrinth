# spx-01 feedback 2 (Codex peer review of 5a9d5e278: CHANGES REQUESTED, regression coverage)

No gameplay regression was found. Fix these three, with the reviewer's mutations as proof:

1. **Medium:** the analytics regression doesn't catch lost caller metadata.
   - Blanking the helper's `room_type` or `guardian_id`, or removing the headless context merge
     (`headless_playtest.gd:1851`), all survive.
   - Assert independently expected room metadata through both callers (UI and headless) at combat start, combat end
     and reward. Cover a normal fight, a Guardian and a boss.
   - Keep the legacy-field oracle independent of the new helper.
2. **Low:** the save golden only round-trips an array.
   - Add a real run save and load through `ProgressionStore` in isolated storage, asserting successful persistence and
     complete state equality.
   - A corrupted save writer must fail it.
3. **Low:** remove the unused `Rooms` and `BIOMES` declarations in `encounter_sweep.gd`.

Focused tests only.
