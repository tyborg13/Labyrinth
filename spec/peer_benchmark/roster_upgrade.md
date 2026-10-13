# Roster upgrade (owner-approved 2026-10-13: phased, regulars first)

Source: legacy audit `staged/legacy_audit/` (15 High, 14 Medium, 2 Low vs the 11 approved art-02 enemies).

## Waves
- **1a — no new rigs**: crawler recolour (rr-01, Lab L×0.76 ab×0.85). [running]
- **1b — rigged regulars, maquette pipeline** (pilot: chainbound gaoler, rr-02): acolyte (+ a distinct veilbound
  variant), frostglass lancer, bile bloomer, harrier, lightning wisp (needs a core mass), warden (front only), cinder
  ooze (front only). cinder_droplet and grave_surgeon stay.
- **2 — guardians** (13 rigs; rocs via bird maquettes).
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
