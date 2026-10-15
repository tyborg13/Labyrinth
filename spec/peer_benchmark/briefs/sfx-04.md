# sfx-04 — Audio/visual sync audit and fixes

## Header
- Owner, playtest 7 (2026-10-15): "the blink animation, the visual animation plays, and then the sound doesn't seem to
  really trigger until after that happens, and there's a couple other animations that ... the timing's not quite right
  ... do an audit of that and make sure that the timing is syncing up with the visual and that it doesn't get delayed by
  sequencing with other sounds."
- Base: `codex/peer-benchmark` (this worktree). Owned files: `scripts/sfx_bank.gd`, `scripts/sfx_cue_router.gd`,
  `scripts/attack_sfx_library.gd`, `scripts/run_sfx_library.gd`, the SFX trigger call sites in `scripts/*.gd` (only the
  lines that schedule/play cues and the minimum plumbing to pass a visual anchor time), `data/sfx_cues.json` only for
  timing fields if the router needs them, the SFX build tooling under `tools/sfx_lab/` and rebuilt audio files under
  `assets/audio/sfx/` only for item 3, new `tools/sfx_sync_audit.py` / `tests/sfx_sync_*`, and new
  `spec/peer_benchmark/staged/sfx/sync_audit.{json,md}`.
- Rules: no gameplay, balance, analytics or rules changes; no new sounds and no gain/EQ changes (sfx-03's levels stay);
  Windows typed-array rule; deterministic tests (no wall-clock sleeps).

## Sync rules (director decisions)
Perceived audio onset = the frame the cue is played + the sample's own leading silence. For every cue:
- **Impacts, hits, blocks, status applications, deaths:** onset 0–20 ms after the visual's impact frame (the frame the
  hit flash / damage number / status icon first appears). Never before it, never later than 20 ms.
- **Movement, teleports and dashes (`move.blink` and any other blink/dash/teleport):** the departure sound's onset is on
  the first frame the vanish/departure visual is drawn (0–20 ms). If a separate arrival visual exists and the cue set
  has an arrival cue, it plays on the arrival frame.
- **Casts, wind-ups, card plays, UI clicks:** onset 0–20 ms after the first frame of the visual or input response.
- **Ambient/loop cues:** start with their visual state change; out of scope for the 20 ms bound but must not be delayed
  by other cues.
- **No cue waits for another cue.** A cue is never queued behind, awaited after, or serialized with another cue or with
  an unrelated tween/sequence. If a polyphony/voice limit is reached, the router drops (or steals) by an explicit
  priority; it never delays. Cues that intentionally layer (e.g. a hit with a status) start together at their own
  anchors.

## Change
1. **Audit** (`tools/sfx_sync_audit.py` + a headless Godot harness): for every cue in `data/sfx_cues.json`, find each
   call site; record the visual anchor it accompanies (file:line of the visual event), the scheduled delay between the
   anchor frame and `play()` (measured in a deterministic harness that drives each action through the real
   presentation code with a fixed frame clock), the sample's leading silence (first sample above −45 dBFS), any queueing
   or sequencing cause, and the verdict against the rules above. Write
   `spec/peer_benchmark/staged/sfx/sync_audit.json` and a readable `sync_audit.md` (one row per cue × call site;
   violations first). Run it before and after the fixes; keep both tables (`before` / `after` sections).
2. **Fix every violation** at its cause: move the play call to the anchor frame, pass the anchor through instead of
   awaiting a sequence, remove serialization between cues, replace delay-on-limit with priority drop. Keep each cue's
   sound and level.
3. **Leading silence:** any cue whose leading silence exceeds 10 ms is rebuilt through the existing `tools/sfx_lab`
   build with the leading silence trimmed to ≤ 5 ms and a 2 ms fade-in; every other build parameter unchanged; record it
   in the build's provenance as sfx-04.
4. **Regression tests:** the harness asserts the onset window for every cue × call site (so a new delayed cue fails),
   plus a test that two cues triggered on the same frame both start on that frame.

## Proof
- The before/after audit tables; `tests/sfx_bank_test.gd`; the sound-lab tests under
  `~/.cache/umbra-sfx/venv/bin/python tests/test_sfx_lab.py`; the new sync tests; threats_at_rest; full suite (report the
  runtime).
- List, for the director, every cue whose timing changed (cue, call site, before ms → after ms, cause) so it can be
  checked by ear in a playtest. No windowed captures needed.

## Out of scope
New sounds, mixing levels, music, adding cues to silent visuals (list such visuals in the audit as "no cue" instead).
