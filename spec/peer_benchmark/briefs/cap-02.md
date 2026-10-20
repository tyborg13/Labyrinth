# cap-02 — Production crop plan covers the whole run (cap-01 follow-up)

## Header
- Base: integration HEAD (green, includes cap-01).
- **Defect.** cap-01's production writer fixes one crop rect per run up front. The director's rr-28 windowed run hit
  "Production action canvas escaped the fixed run crop", then "Assertion failed: Incomplete production crop plan", at
  `tests/maquette_cutout/capture_storage.gd:193` in two places:
  - the Mimic, `tests/rr20/production_capture.gd:150`: its first scenario (`front/hurl_spear`) passed with 1,315
    frames, and a later scenario failed;
  - the Capacitor, `tests/rr17/production_capture.gd:146`.
  - Logs: `/private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/rr28_mimic_production.log`
    and `rr28_capacitor.log`.
  - The Seer and Mortar runs (cap-01's equivalence cases) didn't trigger it.
  - Likely cause: the actor's action canvas moves on screen within a run (board movement, a scenario at another tile, a
    copied action), so a rect planned from the starting canvas doesn't cover it. Confirm the actual cause first.
- Owned: `tests/maquette_cutout/capture_storage.gd`, the production capture writers that plan crops, and their tests.

## Change
1. **Plan the crop from the whole run.**
   - Plan it from every frame's actor action-canvas screen rect across every scenario and clip of the run, before
     writing any frame. For example, a logic pre-pass (production already has a `logic` mode) records the rects, and
     their union plus the 16 px margin becomes the run's fixed crop.
   - The rect stays constant per run, so frames stay aligned.
   - If a frame still escapes, it's a bug. Fail with the scenario, clip and frame named.
2. **Regression.**
   - A synthetic run whose actor moves across the board after the first frame must produce a covering crop.
   - Without the change, it reproduces today's error.
3. **Equivalence.**
   - The Seer's and Mortar's planned rects must contain the rects cap-01 recorded for them. If they're unchanged, say
     so.
   - List the director's windowed commands for the Mimic (`experiments/cutouts/hollow_mimic/proof.sh production`) and
     the Capacitor (`experiments/cutouts/storm_capacitor/rr17_proof.sh`).
4. Focused tests only.

## Keep
- The encoder (lossless WebP), the manifest format (`crop`, `size`), gates and pixel semantics.
- Windows typed-array rule.
