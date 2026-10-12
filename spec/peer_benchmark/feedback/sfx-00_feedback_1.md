# sfx-00 feedback 1 — decisions for every TODO_DESIGN (implement, rename constants without the prefix, rerun tests)

- SHORT_PEAK_TARGETS (takes < 0.4 s use peak instead of LUFS), dBFS: impact −3, body −4, vocal −6, ui −12, card −10,
  spell −4, movement −14, status −8, pickup −8, stinger −3; ambience is never short (always LUFS).
- STEREO_SIDE_RATIO: keep stereo when side/mid RMS ratio ≥ 0.25; otherwise downmix to mono (mean of L/R). Ambience and
  stinger keep stereo when the source is stereo regardless.
- MULTICHANNEL_DOWNMIX (> 2 channels): L = channel 0, R = channel 1 (front pair); ignore the others. Apply in both
  audition and build.
- LOWPASS: 2nd-order Butterworth (scipy `butter(..., output="sos")` + `sosfilt`), applied before loudness normalisation.
- FADE_CURVE: equal-power (quarter-sine) fade-out; also a 3 ms linear fade-in on every take to avoid clicks.
- LOOP_CROSSFADE_CURVE: equal-power. NON_AMBIENCE_LOOP: allowed for any category with `"loop": true`, same treatment.
- PITCH_MODE: resample (tape-style; pitch and duration change together).
- Audition page: title "Escape the Umbra — Sound Audition"; play button "Play"; shortcuts: Space = play/stop the
  focused candidate, 1–4 = play candidate A–D of the focused cue, J/K = next/previous cue, P = toggle the pick radio
  of the last played candidate. CSS: dark warm ink page (background #0c0a08, text #efe3c8, secondary #b5a58a, accent
  gold #c9a25e, pick highlight ember #e8893a), system serif for headings, readable 16 px body, one cue per section with
  its note, candidates as rows (label, play button, waveform envelope drawn from the 64-point envelope as a small SVG
  sparkline, key features, source path in muted small text, licence).
- The two broad-suite issues (missing PIL/fontTools/mido in the system Python, and the pre-existing fixture depth
  failure) are out of scope; note them only.
