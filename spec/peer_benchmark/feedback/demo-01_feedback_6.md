# demo-01 — round 6 (director's windowed run 3)

1. I added a float tolerance to `comparison.py` (`FLOAT_TOLERANCE = 1e-4`, `_same()`): Meteorfall's per-frame
   `progress` values differed by ~2e-6 between native and headless clocks. Keep it; add a test (2e-6 passes, 1e-2 fails).
2. Meteorfall now passes the comparison but fails sync analysis: `status.bleed: Cue cannot be separated from recorded
   mix (correlation 0.487)` and `spell.fire: No unambiguous contact near the cue request` — many meteors and statuses
   sound at once. Ambiguity is a measurement limit, not a game failure. Policy:
   - Sync rows get a status: `measured` (offset/duration reported), `unmeasured` (with the reason: overlap, low
     correlation, ambiguous contact). Only a **measured** offset outside the sfx-04 tolerance, or a **measured**
     status/trap cue longer than 1.2 s, is a flag. Neither flags nor unmeasured rows stop recording or encoding;
     both are listed in manifest.json and printed in a summary table at the end of record and encode.
   - Recording/encoding refuse only when a clip's take is missing or fails fixture validation or the
     native-vs-headless comparison.
   - The trap clips (trap_enemy, trap_hero) must report a measured duration for the lightning trap cue; if it is
     unmeasured there, say why in the result.
3. `record` must continue through all 21 clips after a failing clip and report every failure at the end (it currently
   stops at the first), and must not need prior takes cleared to re-record (overwrite a clip's own outputs).
Focused demo tests only; do not commit; same windowed list.
