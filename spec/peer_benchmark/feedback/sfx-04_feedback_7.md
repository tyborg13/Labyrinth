# sfx-04 — round 7 (owner playtest 8: cue length) — send after round 6

Owner: the lightning-trap electricity sound is "multiple seconds long ... outrageously long". Measured:
`surface.electric_01.ogg` 9.12 s, `status.shock_01.ogg` 3.59 s, `spell.lightning_01.ogg` 2.87 s.
Director rule (one-shot cue length caps, tail ends in a 150 ms fade-out, nothing else changes):
- status, surface, impact, hit, UI and trap cues: ≤ 1.2 s total;
- spell / cast cues: ≤ 1.8 s;
- roar, death and other signature cues: ≤ 2.5 s;
- only cues the registry marks as loops/ambience may be longer.
Audit every cue variant against these caps; trim the over-long ones deterministically in the sound lab (keep the head
alignment from rounds 4–6, keep peak caps, loudness within the existing window), regenerate provenance, and list every
file trimmed with old → new length. Add a test that fails for any non-loop cue over its cap.
