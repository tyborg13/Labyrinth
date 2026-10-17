# rr-05 feedback 9 — finalize: seam metrics become reports; the director judges the native clip

Your certificates show that the tear and protrusion constraints, as I wrote them, can't both hold for some poses
(e.g. Bloomer `front_move/0019`). I'm changing the acceptance, not asking you to keep searching.
`output/rr-05/feedback8/cpu-evidence/contact_sheet.png` looks intact at board scale.

## Acceptance (final)
- **Blocking, unchanged:**
  - 0 detached components;
  - feature integrity (single node, exact pixels, owner bone);
  - 0 held/boundary shimmer;
  - rest identity 0 px;
  - CPU/native model agreement.
- **Report-only:** interior tears, negative space and underlay protrusion stay measured, with per-clip maxima in the
  result and the proof report. They no longer block derive, the proof script or promotion.
- **Final gate:** I watch the native MP4 for both creatures and judge any visible seam.

## Seam underlays: keep them, with these decisions on your TODO_DESIGN items
1. **Sibling seams** (two parts with the same parent): the underlay belongs to whichever of the two is drawn lower,
   and is painted from that part.
2. **Disconnected bands** (`front/seam_trunk_root_tip_c`, `rear/seam_trunk_core`): split each into connected
   components. Each component is its own underlay node with the same owner. Drop components smaller than 3 px.
3. **Band width:** that joint's derived maximum separation + 1 px, capped at 4 px per side.
4. **Interior reference:** measure tears in the root bone's moving frame (trunk/core), as you did.

## Then
Make `proof_for_design_owner.sh --from-native --creature shale_bloomer` (and the same for the Wisp) run end to end
under these gates. Keep the focused suites green, run the Python suite, and run the full Godot suite through the
parallel runner (qa-07 is merged on integration; merge it in if your base lacks it). Hand back the commands; I'll run
the native proof and the MP4s.

## Repo hygiene
I committed your work so far (9b108eac1) and merged integration (it includes qa-07's parallel runner). The commit
carries about 30 MB of per-round JSON evidence under `experiments/cutouts/shale_bloomer/rr05/proof/feedback*/`
(`*-evidence.json`, `constraint_certificates.json`, `*-TODO_DESIGN.json`, continuity and sha listings).
- Keep in the repo: the final round's summary markdown and small result JSONs (each under 200 KB), plus whatever the
  derive/gates need to reproduce.
- Move bulky diagnostic evidence from earlier rounds to `output/rr-05/archive/` (untracked), and delete it from the
  tree in your final diff.
- Report the repo size delta.
