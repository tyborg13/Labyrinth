# Roster upgrade (owner-approved 2026-10-13: phased, regulars first)

Source: legacy audit `staged/legacy_audit/` (15 High, 14 Medium, 2 Low vs the 11 approved art-02 enemies).

## Waves
- **1a — no new rigs**: crawler recolour (rr-01, Lab L×0.76 ab×0.85). [running]
- **1b — rigged regulars, maquette pipeline** (pilot: chainbound gaoler, rr-02): acolyte (+ a distinct veilbound
  variant), frostglass lancer, bile bloomer, harrier, lightning wisp (needs a core mass), warden (front only), cinder
  ooze (front only). cinder_droplet and grave_surgeon stay.
- **2 — guardians** (13 rigs). First: roc fledgling and gallows roc rebuilt from perched bird maquettes (owner: birds with
  broken rear wings), then the rest.
- **3 — dragons** via quadruped/wing maquettes.

## Maquette → rig pipeline (rr-02 pilot)
1. `spec/art_identity/maquettes/humanoid.py` + `<enemy>/spec.json`: a posed 3D proxy with the rig's part list (labels),
   rendered from the board camera front (yaw 0) and rear (yaw 180): part-label maps, clay, per-part solo renders for
   hidden material, and projected joint positions (`joints_px.json`).
2. Paint over the maquette (image generation; identity from the current painting, hand from canon) — front and rear.
3. Process with the identity gate (K, palette match, outline); judge; owner.
4. Ownership from the label maps (same placement as the painting) → `cutout_workflow.py segment` inputs; hidden
   material painted over the solo renders; joints from the projected maquette joints → a new case reusing the existing
   joint graph and motion sampler where the topology matches.
5. Render/validate/integrate with the existing cutout pipeline; portraits; registry.

## Lessons (rr-02 pilot, judge 2026-10-13)
- Generate the rear only after the front is approved, with the approved front as its identity reference (the kit's
  rule): parallel front/rear generation from the old art produced two material schemes (chain, hook, sleeves, helm).
- State materials explicitly (no chainmail checker; "every patch ≥ 3 blocks"); keep the original coat colour so the
  accent stays the accent.
- Size class follows drawn height (art_scale × canvas): the gaoler is "medium" at art_scale 0.9.
- Every edited raw gets its own job folder (`mq_front_v2`, `mq_front_v3`, …) and is processed before anything depends
  on it; before a judge runs, check that the sheet's "front pixels" digest is the newest front job's `pixel_sha256`
  and that the rear's `palette_match.reference_pixel_sha256` is the same digest. (Round 2 judged the unedited front
  because the edit was copied to raw/ but never processed; the rear was generated from the edit and matched to the
  old front.)
- `rear_consistency` is global statistics: it passes local material swaps (copper vs iron helm, cloth vs mail). The
  judge's per-part colour table is the real consistency check.
- Paint at the drawn size: kit K=4 with target ≤ 225 and art_scale 1.0 beats painting at 241 and drawing at 0.9.
- One hot accent: a second saturated mass at the accent's hue (the gaoler's tabard at chroma 0.52 beside the rust
  hook) is toned down deterministically (`maquettes/chainbound_gaoler/tone_tabard.py`, oxblood) rather than
  re-prompted.
