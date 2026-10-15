# rr-02 — round 4 (director motion review of the v03 reel)

Committed checkpoint: addd470bd. Proofs pass; motion review found three art defects and a missing reel scope.
Evidence: /private/tmp/claude-501/-Users-borgerding-workspace-Labyrinth/020b9ac4-7b92-4113-a7d2-bc6e802828dd/scratchpad/
`rr02_strips_front.png`, `rr02_strips_rear.png`, `rr02_zoom.png` (from /private/tmp/rr-02-mq3-render-v03).
Why a 4th round: these defects only appear in motion; earlier rounds were pipeline phases, not repeated failures.

## 1. Material-correct ownership (root cause of the red walk smear)
The painted tabard is wider than the maquette tabard, so tabard paint lands in the maquette labels of the parts behind
it. Front `thigh_far` visible pixels have median RGB (80,26,22) = tabard red (tabard median (83,28,24)); `pelvis`
(56,21,20) likewise; the hidden fills then diffuse that red (front/rear `thigh_far` fills are dark red in the fill sheet).
In the walk, a red streak runs down the far leg (front) and red flashes behind the far leg (rear).
Fix, as a deterministic recipe step before hidden fill, in both views:
- Materials (director data, add to the case recipe): `tabard_cloth` = the tabard part's core pixels (≥ 4 px inside its
  maquette label); `trousers` = `thigh_near` core pixels whose CIE Lab ΔE76 to the tabard median is > 20 (dark grey-brown,
  about (50,35,29)).
- For `pelvis`, `thigh_far`, `thigh_near` (front) and the rear thighs/pelvis: a pixel whose ΔE76 to `tabard_cloth` median
  is less than its ΔE76 to `trousers` median moves to the **tabard** part (front view) — it is tabard paint. In the rear
  view the tabard is front-only: such pixels stay in their part but are recoloured by nothing (report the count; expect ~0
  after the hidden-fill fix below).
- Hidden fills for thighs/pelvis sample **only** the `trousers` palette (plus the same part's own remaining visible
  pixels); never tabard or coat. Gate: each filled region's median within ΔE76 12 of the `trousers` median.
- Rest identity stays exact (0 differing pixels) in both views; check that reassigned pixels are drawn in the same
  order position at rest.

## 2. Stray specks
Several parts carry tiny detached islands (visible as dark specks near the feet and around the legs in walk/strike).
Rule, per part per view: an 8-connected component < 12 px not connected to the part's largest component moves to the
adjacent part it shares the most border with at rest; if it touches no other part, delete it only if rest identity
still holds (otherwise keep and report). Report counts per part.

## 3. Rear strike draw order
`sample_draw_order` draws `hand_fist` at 11 (in front) for rear `strike`/`manacle_pin`. In the rear view the punch goes
forward, away from the camera, so the fist arm (upper/fore/hand fist) must draw **behind the torso and head** for those
clips (frames 2–3 show a black blob over the far shoulder). Keep the front view as is.

## 4. Reel scope
The reel must include every clip production needs: `idle`, `walk`, `strike`, `hit`, `death`, **`chain_reel`**,
**`manacle_pin`**, both views. Add the two missing clips to the render and the motion samples.

## Proof
Focused tests, gate tests, full suites; validation ok; rest identity 0 pixels; zero magenta; updated fill sheet.
List the windowed render/verify/proof commands with a new capture path `/private/tmp/rr-02-mq3-render-v04`.
