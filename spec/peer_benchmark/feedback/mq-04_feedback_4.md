# mq-04 feedback 4: Herald and Gloam fit, then curate for commit (director review of r3)

Review sheets: `proof/quality_r3/review/clay_comparison_lancer_r3.png` and `fit_overlay_contact_sheet.png`.

## Accepted
**Hoarfrost Seer** and **Arc Thrall** are accepted as clays: good 3/4 facing, readable volumes, fit passes. Freeze
them; don't touch them in this round.
- The Seer's dense staff-cuff wrinkles are acceptable: paint-over handles surface detail.
- I'm starting their paint-over myself.

## Round 4 scope: Gale Herald and Gloam Stalker only
### Gale Herald (rear 0.561, target ≥ 0.65; keep front ≥ 0.70)
1. **Hood:** the front clay shows rectangular holes and torn gaps in the hood or mask. Make it a solid, closed cowl
   whose pointed gold mask reads as one shape, like the source. No holes.
2. **Banners:**
   - Fit the length and drop to the source in both views. The rear banners currently run too low and too long,
     crossing the whole back diagonally.
   - Replace the fan-like regular pleats with soft cloth: 2–3 broad folds per banner and a ragged lower edge, as in
     the source.
   - The top attaches at the shoulder and back the way the source shows.
3. Horn, plates and legs stay as they are unless the fit needs them to move.

### Gloam Stalker (front 0.627, rear 0.632; targets ≥ 0.70 front, ≥ 0.65 rear)
1. **Back carapace (key identity feature, missing):**
   - The source has a dark, jagged, spiky mass rising behind the shoulders and hood, visible in both views; it's the
     brown spikes framing the figure.
   - Model it as its own rigid part (or 2–3 parts) attached to the upper torso, with the source's spike count and
     silhouette.
   - It needs its own part map, so the rig can use it.
2. **Legs and feet:** the clay legs are short and stubby. Fit the length, thigh mass and wide feet to the source.
3. **Claws:**
   - The crescent claws must attach clearly at the hands or forearms, with no floating gap.
   - Fit their curvature and length to the source.
   - Each claw is one part.
4. **Cloak:** fit the shoulder and lower cloak hem to the source's ragged outline.

Both: keep the 45° 3/4 facing, the collision, facing and ownership checks, and native determinism. Report the best
IoU per view with the overlays.

## Commit curation (all four figures; required before handoff)
The four figure trees hold about 1.7 GB, about 2,300 files; the Lancer's committed maquette is about 70 files and
under 1 MB.
- Write `spec/art_identity/maquettes/<figure>/COMMIT_MANIFEST.txt` listing what to track:
  - the builder inputs and spec;
  - the final native front and rear clays (1024);
  - part maps, joints and manifests;
  - the review sheets;
  - the provenance/hash JSON.
- Budget: ≤ 6 MB per figure, no `.blend`, no determinism or replay copies, no candidates, no superseded r1/r2 proof.
- Record SHA-256 hashes of anything you drop that proved something (determinism, cache replay) in a small JSON, then
  **delete** the bulky copies from the worktree (disk hygiene). Anything else must be regenerable from the committed
  builder plus spec. Show that by regenerating one figure's clay from a clean tree and matching its hash.
- If `spec_native.json` (about 39k lines) is generated output, don't track it unless the build needs it as input.
  Say which.

## Proof
- Fit table and overlays for Herald and Gloam.
- The updated four-figure + Lancer clay comparison.
- Disk usage per figure before and after curation.
- Focused, art identity and full Python suites.

The Blender bridge is up for this worktree; jobs start within 120 s.
