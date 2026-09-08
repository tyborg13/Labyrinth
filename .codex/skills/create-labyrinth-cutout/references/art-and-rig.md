# Art, registration and rig construction

## Start with a coherent character

Judge a source painting against the character's concept and the assembled rig against that painting. These are different comparisons. The approved protagonist was redrawn coherently; using it as the starting point does not mean every future edit needs another redraw.

The failed mixed-body pass had narrow, finely textured limbs on a broad head and torso. Connectivity checks still passed. Before rigging, compare head/body ratios, shoulder and hip widths, outline weight, highlight cluster size, leather/cloth/metal values and light direction at the same native scale. Avoid independently enlarging each part to fill a contact-sheet cell: it hides proportion errors.

Prefer manually splitting one coherent registered painting. Generate an individual missing component when necessary, then fit it to explicit dimensions and landmarks. Unconstrained generated multi-part atlases repeatedly changed dimensions and anatomy. Do not ask the image generator to decide the skeleton's dimensions or treat its output packing as registration.

Save the untouched generator output and the actual prompt/reference set, selected/rejected disposition, processing recipe and digest. A checkerboard painted into RGB/RGBA is not transparency. Inspect alpha explicitly; repair the background through the appropriate image tool. Registration and ownership tools copy existing pixels and do not supply hidden anatomy.

## Establish projection before splitting

Labyrinth uses a 2:1 board projection. Near and far shoulders, hips, knees and soles do not have to share horizontal image rows. Mark them separately on each view, and mark uncertain hidden positions honestly. A bounding box is crop metadata, not evidence of correct projected anatomy.

Register the whole source once on the game's 255×255 body canvas. Preserve those coordinates through crops, joints, meshes, replacement art and assembled rest. Individual fitting can be necessary for a generated component, but record both its source landmarks and target landmarks plus any deliberate width/length correction. Compare it assembled before accepting the fit.

For a new nonhumanoid enemy, define a graph appropriate to its anatomy. A crawler, wisp and humanoid do not need the same number or names of bones. `init` deliberately creates only a root and incomplete layouts; it is not an animation-ready creature.

## Semantic ownership and hidden material

`segment` reads ordered ownership polygons and exact pixel overrides. First owner wins on overlaps; overrides explicitly transfer a pixel. Unassigned visible pixels remain magenta in the ownership view and fail the command. It preserves source RGB/alpha and crop offsets; it never sweeps leftover pixels into the torso.

Inspect every part's boundaries and movement, not just the reported defect. Common mistakes were arm pixels assigned to a cloak, scarf/collar pixels left on the head, and waist pixels owned by the wrong moving surface. Exact rest reconstruction can still conceal all of these errors.

Art intended to articulate needs material hidden behind the rest pose: proximal sleeve caps, complete chest/back beneath removable garments, a pelvis under belt/flaps, overlapping knees and cuffs. Generate missing surfaces rather than stretching a visible strip over a hole. Test with the cloak/equipment hidden and with limbs at their maximum requested excursion.

For cloth across a shoulder, the concealed sleeve and visible cloth must move together at the overlap, then transition to their own bones. Keep cloth and arm ownership distinct. A detached seam is not fixed by painting arm pixels onto the cloak.

## Meshes, joints and terminal pieces

A rigid Sprite2D is appropriate for a stable drawing whose shape should stay intact. A long shin rectangle can visibly reorient as one piece and look broken. When this occurs, build finer mesh rows across the bend and use a shared weight field for all overlapping pieces, including knee covers. `skin` takes an explicit recipe with the same bands/axes for every part in the family.

The approved rear-leg recipe uses two-pixel columns and one-pixel rows. Its bands blend thigh to shin over 16 pixels around the knee, then into the foot over 12 pixels ending near the cuff. These values fit this character; select density and blend regions from the next creature's art and motion. They are not universal defaults for every body surface.

Mesh vertices use global registered source coordinates. UVs use crop-local coordinates. Bone bind positions use the same source coordinates. Parent meshes to the rig, with their Skeleton2D reference, rather than to an already moving bone; otherwise the transform is applied twice. Adjacent meshes need matching weights where they overlap.

Keep gloves, boots, weapon blades and other rigid terminal drawings rigid unless the requested art calls for deformation. Return the foot transform to a rigid basis after solving a projected leg. Preserve painted limb width; changing projected segment length may represent depth, whereas uniformly stretching the whole limb also stretches its width and boot.

More geometry does not repair wrong perspective, missing anatomy or poor paint. Inspect for folded/collapsed triangles, then judge the actual contour and material continuity. A pass on normalized weights or connected components cannot overrule an implausible knee.

## Equipment and garment variations

Fork a case before replacing art. Slots such as `head`, `neck`, `chest`, `legs`, `gloves`, `boots`, `cloak` and `weapon` are art-group metadata; they do not yet constitute live inventory swapping. Game equipment slots are a separate data/UI concern.

For a rigid piece, `replace-part` copies an RGBA image unchanged and updates its explicit source offset. It refuses skinned pieces, because replacing a skinned PNG without updating crop UVs/topology can silently corrupt it. Rebuild the relevant mesh recipe for deforming replacements.

Record the replacement's attachment and distal landmarks. For weapons, keep the gripping hand and weapon on separate transforms, with the grip registered in the fist; a compound hand/blade forced the wrist to fold in broad poses. Update `weapon_grip` landmarks when blade/grip geometry changes and remeasure the attack path.

A painted foot view cannot be corrected by rotating a front toe-cap toward its knee. Use the appropriate toe/heel perspective, then preserve that accepted direction with modest planted/swing angles. Show an occupied cuff: trousers should cover the boot opening. Match outline thickness, dark sole/underside, toe width and leather value to the mate. This was a separate problem from choosing the correct orientation.

For the approved rear cloak, the independent drape spans both shoulders while complete shoulder coverage remains underneath. Erasing the old shoulder piece alone would reveal a hole. Hide a competing visible seam with a coherent drape/overlap whose material belongs to the correct garment; check it through motion and with the garment removed.

Render fresh assembled rest images after art/registration changes. The case inspector bakes them once for its silhouette cache, and `render` saves `<facing>_rest.png`. When integrating, update the production static-rest path/digest as well as moving parts so HUD bounds and cached shadows use current art.

## Retained evidence

Read only the relevant evidence; do not rerun old builders to inspect it.

| Need | Repository reference |
| --- | --- |
| Every-part semantic audit | `experiments/protagonist_2d/segmentation_audit.md` and its labeled ownership images |
| Failed body/limb mismatch and anatomy lessons | `experiments/protagonist_2d/iteration_5.md`, `iteration_6.md` |
| Coherent registered masters and manual masks | `experiments/protagonist_2d/references/pass6/{front,rear}_master.png`, corresponding `_ownership.json`, assembly/parts reviews |
| Recorded individual component fitting | `experiments/protagonist_2d/registered_assets.py` and `references/pass6/components/` |
| Cuffs, knee overlap and garment assembly | `experiments/protagonist_2d/iteration_7.md`, `seam_assets.py`, `references/pass7/` |
| Final boot source/prompt and shoulder/leg fix | `experiments/protagonist_2d/references/pass9/`, `refine_pass9_meshes.py` |
| Approved production motion and final real gameplay | `spec/protagonist_cutout_runtime.md`, `experiments/protagonist_2d/renders/pass9/` |

Earlier hand-authored idle sheet comparisons remain in `references/authored_idle*`. They support the coordinated bob decision, not an exact pixel-for-pixel reconstruction claim.
