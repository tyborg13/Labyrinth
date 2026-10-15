# art-07 — round 1 (peer review of b40c9fd70: CHANGES REQUESTED)

Work on top of b40c9fd70. Do not commit. Replay compatibility and the art-06 leftovers are fine.

1. **HIGH — the hue protection swallows real bodies.** On real rears it excludes 64–93% of the body from the transfer
   (gaoler rear 92.5%, lancer rear 64.5%, wisp rear 79–83.5%, bloomer stand-ins 90–93%): brown/rust bodies share the hue
   of rust/amber/copper accents, every accent pixel adds its own ±25° window, and near-grey pixels (noise hue) are caught.
   Fix (director rule):
   - Hue protection applies only to rear pixels whose Lab chroma ≥ max(the rear's own p90 Lab chroma, 30).
   - Reference hues come from the **dominant** accent hue bins (15° bins holding ≥ 5% of the reference's accent pixels),
     not every accent pixel.
   - L* ≥ 80 protection stays, but never for green-dominant pixels (see 3).
   - Guard: if more than 25% of either image's body would be protected, or a body is empty, `process` fails with a clear
     message unless `--allow-protected-share` is passed (recorded in the sidecar). Never silently return the rear unchanged.
   - Proof: report the protected body share for the gaoler, lancer, wisp and bloomer rears (target 2–10%) and keep the
     lancer/wisp bright cores unchanged; add a body-coverage assertion to the proof test.
2. **MEDIUM — re-processing silently changes approved pixels.** `process` on an existing kit with a recorded legacy
   `palette_match` step must default to the **recorded** parameters; new parameters only with
   `--palette-parameters current` (and `legacy` explicit). Fix the metadata-migration recipe in
   `spec/visual_identity_gate.md` (~line 319) accordingly; test that re-processing every recorded rear reproduces its
   approved pixel digest.
3. **MEDIUM — bright green key residue survives**: pixels like (90,250,90) (L* 87.6) are protected and skip the green
   cleanup. Exclude green-dominant pixels from protection; test it (mutant M6 must be caught).
4. **LOW — filter validation**: validate `min_chroma`, `min_lum`, `max_lum` like the new limits (finite, 0..1, no bools),
   and reject min > max for each pair.

Proof: gate tests, registry check PASS, replay of all raw_steps kits byte-identical, the protected-share table.
