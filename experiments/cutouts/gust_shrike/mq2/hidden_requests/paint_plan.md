# Hidden-material paint plan

Sorted by maximum sampled exposure, then hidden area. All seven production clips
are sampled in each view; a zero means no exposed pixels in those sampled poses.
Exposure uses actual headless Skeleton2D transforms and nearest CPU masks.
It is a painting priority estimate; the native reel remains separate proof.

Magenta #FF00FF marks hidden material; green #00FF00 is background.
Neighbour names refer to the approved painted ownership, not new anatomy.
Covered counts measure the part currently hiding this request; border counts
measure its four-connected painted neighbours. Material descriptions come
from the approved pair and its supplied identity/material brief.

## 1. rear / body

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 2455 px; peak sampled exposure: 873 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[110, 87, 196, 189]`.
- Motions that expose it: hover: peak 873 px at frame 7, 46/49 frames exposed; dive: peak 715 px at frame 39, 54/61 frames exposed; move: peak 608 px at frame 38, 47/49 frames exposed; talon_rake: peak 434 px at frame 22, 45/49 frames exposed; death: peak 267 px at frame 9, 62/63 frames exposed; hit: peak 267 px at frame 8, 32/37 frames exposed; idle: peak 36 px at frame 0, 144/144 frames exposed.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (24 px covered, 11 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (2 px covered, 1 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (2355 px covered, 53 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (73 px covered, 17 px border); `legs` — grey-brown scaled legs with big talons (1 px covered, 6 px border).
- Request: [native](rear_body.png) / [4× nearest](rear_body_4x.png).

## 2. rear / wing_near

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 1312 px; peak sampled exposure: 605 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[115, 44, 158, 143]`.
- Motions that expose it: hover: peak 605 px at frame 26, 46/49 frames exposed; dive: peak 568 px at frame 39, 54/61 frames exposed; move: peak 518 px at frame 37, 46/49 frames exposed; talon_rake: peak 451 px at frame 22, 45/49 frames exposed; hit: peak 370 px at frame 6, 32/37 frames exposed; death: peak 205 px at frame 14, 62/63 frames exposed; idle: peak 106 px at frame 62, 144/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (133 px covered, 26 px border); `head` — dusky storm-grey, grey-tan and dark brown plumage (10 px covered); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (1161 px covered, 73 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (8 px covered).
- Request: [native](rear_wing_near.png) / [4× nearest](rear_wing_near_4x.png).

## 3. front / body

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 1490 px; peak sampled exposure: 477 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[65, 153, 153, 214]`.
- Motions that expose it: hover: peak 477 px at frame 7, 45/49 frames exposed; dive: peak 414 px at frame 39, 54/61 frames exposed; move: peak 354 px at frame 38, 36/49 frames exposed; talon_rake: peak 284 px at frame 21, 35/49 frames exposed; hit: peak 190 px at frame 4, 31/37 frames exposed; idle: peak 38 px at frame 34, 106/144 frames exposed; death: peak 14 px at frame 20, 60/63 frames exposed.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (464 px covered, 39 px border); `mask` — bold dark mask band (53 px covered); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (964 px covered, 46 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (3 px covered, 2 px border); `legs` — grey-brown scaled legs with big talons (6 px covered, 8 px border).
- Request: [native](front_body.png) / [4× nearest](front_body_4x.png).

## 4. rear / head

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 466 px; peak sampled exposure: 356 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[171, 62, 214, 98]`.
- Motions that expose it: death: peak 356 px at frame 18, 62/63 frames exposed; dive: peak 328 px at frame 14, 54/61 frames exposed; move: peak 315 px at frame 17, 47/49 frames exposed; hover: peak 311 px at frame 16, 46/49 frames exposed; talon_rake: peak 310 px at frame 11, 44/49 frames exposed; idle: peak 30 px at frame 0, 131/144 frames exposed; hit: peak 7 px at frame 5, 32/37 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (5 px covered, 5 px border); `mask` — bold dark mask band (27 px covered, 1 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (5 px covered); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (424 px covered, 45 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (1 px covered); `legs` — grey-brown scaled legs with big talons (4 px covered); `beak` — heavy hooked iron-grey beak (4 px border).
- Request: [native](rear_head.png) / [4× nearest](rear_head_4x.png).

## 5. front / wing_far

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 850 px; peak sampled exposure: 164 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[71, 117, 126, 167]`.
- Motions that expose it: dive: peak 164 px at frame 39, 54/61 frames exposed; move: peak 157 px at frame 38, 46/49 frames exposed; hover: peak 155 px at frame 9, 46/49 frames exposed; talon_rake: peak 145 px at frame 21, 45/49 frames exposed; hit: peak 107 px at frame 6, 32/37 frames exposed; idle: peak 96 px at frame 107, 140/144 frames exposed; death: peak 48 px at frame 4, 61/63 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (237 px covered, 16 px border); `head` — dusky storm-grey, grey-tan and dark brown plumage (355 px covered, 40 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (247 px covered, 62 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (5 px covered); `legs` — grey-brown scaled legs with big talons (6 px covered).
- Request: [native](front_wing_far.png) / [4× nearest](front_wing_far_4x.png).

## 6. rear / wing_far

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 119 px; peak sampled exposure: 119 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[151, 71, 190, 159]`.
- Motions that expose it: hit: peak 119 px at frame 6, 31/37 frames exposed; dive: peak 118 px at frame 47, 53/61 frames exposed; move: peak 118 px at frame 30, 47/49 frames exposed; hover: peak 117 px at frame 23, 46/49 frames exposed; talon_rake: peak 116 px at frame 27, 45/49 frames exposed; idle: peak 70 px at frame 60, 144/144 frames exposed; death: peak 27 px at frame 11, 61/63 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (106 px covered, 45 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (9 px covered); `legs` — grey-brown scaled legs with big talons (4 px covered); `head` — dusky storm-grey, grey-tan and dark brown plumage (8 px border).
- Request: [native](rear_wing_far.png) / [4× nearest](rear_wing_far_4x.png).

## 7. rear / legs

- Material: grey-brown scaled legs with big talons.
- Hidden area: 494 px; peak sampled exposure: 115 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[140, 146, 172, 185]`.
- Motions that expose it: talon_rake: peak 115 px at frame 23, 31/49 frames exposed; move: peak 109 px at frame 38, 14/49 frames exposed; hit: peak 33 px at frame 4, 29/37 frames exposed; death: peak 16 px at frame 10, 13/63 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (374 px covered, 95 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (115 px covered, 21 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (5 px covered, 1 px border).
- Request: [native](rear_legs.png) / [4× nearest](rear_legs_4x.png).

## 8. front / legs

- Material: grey-brown scaled legs with big talons.
- Hidden area: 208 px; peak sampled exposure: 63 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[91, 194, 120, 213]`.
- Motions that expose it: hit: peak 63 px at frame 5, 29/37 frames exposed; talon_rake: peak 26 px at frame 20, 19/49 frames exposed; move: peak 23 px at frame 37, 31/49 frames exposed; death: peak 10 px at frame 32, 43/63 frames exposed; idle: peak 8 px at frame 29, 38/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (205 px covered, 60 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (3 px covered).
- Request: [native](front_legs.png) / [4× nearest](front_legs_4x.png).

## 9. front / tail

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 194 px; peak sampled exposure: 31 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[137, 176, 156, 194]`.
- Motions that expose it: move: peak 31 px at frame 36, 34/49 frames exposed; hover: peak 29 px at frame 6, 22/49 frames exposed; dive: peak 27 px at frame 39, 54/61 frames exposed; talon_rake: peak 26 px at frame 21, 25/49 frames exposed; hit: peak 19 px at frame 7, 30/37 frames exposed; idle: peak 5 px at frame 28, 59/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (91 px covered, 21 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (103 px covered, 17 px border).
- Request: [native](front_tail.png) / [4× nearest](front_tail_4x.png).

## 10. front / wing_near

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 21 px; peak sampled exposure: 21 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[113, 123, 156, 185]`.
- Motions that expose it: hit: peak 21 px at frame 30, 31/37 frames exposed; hover: peak 20 px at frame 5, 38/49 frames exposed; move: peak 20 px at frame 5, 43/49 frames exposed; dive: peak 19 px at frame 7, 54/61 frames exposed; idle: peak 19 px at frame 57, 96/144 frames exposed; talon_rake: peak 19 px at frame 23, 43/49 frames exposed; death: peak 4 px at frame 2, 58/63 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (15 px covered, 14 px border); `head` — dusky storm-grey, grey-tan and dark brown plumage (5 px covered); `tail` — dusky storm-grey, grey-tan and dark brown plumage (1 px covered, 2 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (10 px border).
- Request: [native](front_wing_near.png) / [4× nearest](front_wing_near_4x.png).

## 11. front / head

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 114 px; peak sampled exposure: 16 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[52, 152, 92, 182]`.
- Motions that expose it: move: peak 16 px at frame 38, 46/49 frames exposed; dive: peak 15 px at frame 2, 54/61 frames exposed; hover: peak 15 px at frame 3, 39/49 frames exposed; idle: peak 15 px at frame 85, 80/144 frames exposed; talon_rake: peak 15 px at frame 2, 44/49 frames exposed; death: peak 14 px at frame 2, 61/63 frames exposed; hit: peak 13 px at frame 4, 29/37 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (1 px covered, 24 px border); `beak` — heavy hooked iron-grey beak (39 px covered, 8 px border); `mask` — bold dark mask band (53 px covered); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (21 px covered, 1 px border).
- Request: [native](front_head.png) / [4× nearest](front_head_4x.png).

## 12. front / mask

- Material: bold dark mask band.
- Hidden area: 383 px; peak sampled exposure: 12 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[50, 151, 82, 170]`.
- Motions that expose it: death: peak 12 px at frame 19, 62/63 frames exposed; dive: peak 10 px at frame 11, 54/61 frames exposed; hit: peak 9 px at frame 3, 30/37 frames exposed; idle: peak 9 px at frame 87, 98/144 frames exposed; move: peak 8 px at frame 39, 47/49 frames exposed; hover: peak 7 px at frame 2, 39/49 frames exposed; talon_rake: peak 7 px at frame 1, 45/49 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (2 px covered); `head` — dusky storm-grey, grey-tan and dark brown plumage (374 px covered, 57 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (7 px covered, 1 px border).
- Request: [native](front_mask.png) / [4× nearest](front_mask_4x.png).

## 13. rear / tail

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 89 px; peak sampled exposure: 9 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[110, 174, 125, 184]`.
- Motions that expose it: move: peak 9 px at frame 43, 18/49 frames exposed; death: peak 7 px at frame 30, 50/63 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (89 px covered, 21 px border).
- Request: [native](rear_tail.png) / [4× nearest](rear_tail_4x.png).

## 14. rear / mask

- Material: bold dark mask band.
- Hidden area: 414 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[181, 63, 213, 82]`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (397 px covered, 54 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (3 px covered); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (12 px covered, 11 px border); `legs` — grey-brown scaled legs with big talons (2 px covered); `beak` — heavy hooked iron-grey beak (1 px border).
- Request: [native](rear_mask.png) / [4× nearest](rear_mask_4x.png).

## 15. rear / beak

- Material: heavy hooked iron-grey beak.
- Hidden area: 225 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[195, 68, 214, 85]`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (205 px covered, 42 px border); `mask` — bold dark mask band (17 px covered, 6 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (2 px covered); `tail` — dusky storm-grey, grey-tan and dark brown plumage (1 px covered).
- Request: [native](rear_beak.png) / [4× nearest](rear_beak_4x.png).

## 16. front / beak

- Material: heavy hooked iron-grey beak.
- Hidden area: 152 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[53, 161, 69, 177]`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (152 px covered, 34 px border).
- Request: [native](front_beak.png) / [4× nearest](front_beak_4x.png).
