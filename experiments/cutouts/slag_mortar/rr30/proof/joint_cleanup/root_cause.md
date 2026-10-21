# rr-30 round 3: attribution before construction changes

The director evidence was inspected before editing construction. Original
source layers, layout and actual Godot Sprite2D matrices for lob0000, lob0016
and lob0032 were saved before the edits. The before images and pixel maps
replay that immutable state with those captured matrices, including the
original action-only head continuation recipes.
`attribution.json.gz` records every pixel in the five flagged-region windows for
lob0016 and lob0032: destination coordinate, topmost piece, RGBA, exact sampled
piece UV, painting coordinate and original painting RGBA (12,014 pixels total).
`attribution.json` summarizes those windows. The full unmodified layer inventory
and layout were retained separately for a construction-disabled mutation fixture.

| Defect | Producing pieces and cause |
| --- | --- |
| Near upper/forearm dark slash | `hidden_torso` shows through the separating cut. Example lob0016 source-space destination [177,142] samples [178,140]: cover RGBA [20,10,6,255], painting RGBA [90,50,31,255]. [180,143] samples [181,141]: same dark torso donor, while the painting is [112,65,40,255]. The own-torso nearest donor rule is the wrong material for exposed arm skin. |
| Far upper arm below shoulder | `upper_far` original outer-outline texels, e.g. [74,109] RGBA [9,6,3,255], become surrounded by protruding `hidden_torso` material. The source edge was an exterior contour at rest. In motion that contour becomes an apparent internal slash. |
| Far elbow / above bracer | `hidden_upper_far` and `hidden_fore_far` expose dark edge donors, together with the moved `upper_far` original edge. The per-pixel tables distinguish visible original paint from hidden continuation paint. |
| Shoulder and wrist fragments | `hidden_torso`, `hidden_pelvis`, `hidden_upper_near`, `hidden_fore_near`, `hidden_bracer_near`, `hidden_hand_near`, and corresponding far-side covers have visible cells outside their local contacts. The broad projected solos, accumulated pose sweeps and raster guards were combined without a final joint-local bound. |
| Knees and inner thighs | `hidden_thigh_near`, `hidden_thigh_far`, `hidden_shin_near`, `hidden_shin_far` extend beyond the knee contacts. These are connected extensions, so detached-component counting returns zero. |
| Warm bit beside hem | `hidden_thigh_near`, not the approved flap: lob0016 destination [146,213] samples [161,212], copying skin RGBA [200,115,67,255] over a source location whose painting is [136,54,22,255]. The thigh continuation reaches below the knee and emerges beside the rigid flap. |

The error is construction: excessive hidden domains and unrestricted nearest
own-piece colour donors. No painting, director track, joint pivot or timing was
changed when this record was made. A rest-only comparison cannot see these
exposures because the visible source pieces conceal them at rest.

Subsequent source measurements found two construction issues affecting the
replacement covers: the front near-elbow native hinge [194.67,147] is about
eleven pixels from the painted contact endpoint centroid
[187.27272727272728,139.27272727272728], and the rear near-foot ownership puts
the intervening sole in the shin instead of joining its heel and toe. The
derived rig registers that elbow to the measured contact and transfers 174
existing sole texels inside the rear heel/toe hull to the rigid foot. Protected
maquette joints and paintings are unchanged; both rest assemblies remain exact.
