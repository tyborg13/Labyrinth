# sfx-05 feedback 1 (director)

Good build and wiring. Two open items, both decided here. Focused tests only.

1. **`TODO_DESIGN_sync_policy` is resolved by a recipe trim, not a policy exception.**
   - The flame take's first 90 ms is a −29 to −11 dB pre-roll, which put the perceived onset at 110 ms and 130 ms.
   - The director edited `spec/peer_benchmark/staged/sfx/recipes_empower.json` in your worktree (uncommitted):
     - `empower.charge` A: flame `trim` [0.09, 0.45], `fade_in_ms` 6, crackle `offset_ms` 0.
     - `empower.uncharge` A: flame `trim` [0.10, 0.42], `fade_in_ms` 6.
   - The director's renders measure:
     - charge: perceived onset 20.1 ms, first peak 24.9 ms;
     - un-charge: perceived onset 12.1 ms, first peak 17.5 ms, designed sha256 `dd180dd9…`.
   - Rebuild both cues from this recipe through the same design → index → slice → features → build chain. Keep the
     −24/−30 LUFS targets and refresh the manifest, provenance and hash-bound fixtures.
   - **The sync audit must PASS with zero violations.** Don't use head alignment, an exception or a cap change.
   - Remove `TODO_DESIGN_sync_policy` from both registry entries.
   - The `onset_note` fields are director notes. Keep them; the design tool already accepts them.
2. **Blocked-health attempts: minimal routing edits are authorized.**
   - Edit `scripts/run_scene.gd` and `scripts/card_widget.gd`, only where they currently swallow the attempt.
   - When charging is blocked by health, a charge attempt by seal click, E or RS plays `card.invalid` once. Respect
     its existing 200 ms cooldown.
   - The attempt doesn't change the charge state and plays no Empower cue.
   - Leave any existing blocked-state visual or tooltip as it is.
   - Add this to the routed test: one blocked attempt per input path gives exactly `["card.invalid"]`.
3. Re-run the focused checks from your handoff, plus the sync audit with `--check`.
