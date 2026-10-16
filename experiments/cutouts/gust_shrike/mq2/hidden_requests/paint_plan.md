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

## 1. rear / wing_near

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 1296 px; peak sampled exposure: 1048 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[115, 44, 158, 143]`.
- Motions that expose it: death: peak 1048 px at frame 27, 62/63 frames exposed; hover: peak 588 px at frame 7, 39/49 frames exposed; dive: peak 555 px at frame 39, 54/61 frames exposed; move: peak 505 px at frame 37, 46/49 frames exposed; talon_rake: peak 442 px at frame 22, 44/49 frames exposed; hit: peak 427 px at frame 7, 33/37 frames exposed; idle: peak 184 px at frame 72, 144/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (134 px covered, 26 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (1162 px covered, 73 px border).
- Request: [native](rear_wing_near.png) / [4× nearest](rear_wing_near_4x.png).

## 2. rear / body

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 2435 px; peak sampled exposure: 863 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[110, 87, 196, 189]`.
- Motions that expose it: hover: peak 863 px at frame 7, 40/49 frames exposed; dive: peak 719 px at frame 39, 54/61 frames exposed; move: peak 595 px at frame 38, 46/49 frames exposed; death: peak 516 px at frame 25, 62/63 frames exposed; talon_rake: peak 435 px at frame 22, 44/49 frames exposed; hit: peak 397 px at frame 6, 33/37 frames exposed; idle: peak 82 px at frame 0, 144/144 frames exposed.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (25 px covered, 9 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (2358 px covered, 53 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (52 px covered, 16 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (2 px border).
- Request: [native](rear_body.png) / [4× nearest](rear_body_4x.png).

## 3. front / body

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 1473 px; peak sampled exposure: 474 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[65, 153, 153, 214]`.
- Motions that expose it: hover: peak 474 px at frame 7, 25/49 frames exposed; dive: peak 410 px at frame 39, 54/61 frames exposed; move: peak 351 px at frame 38, 36/49 frames exposed; talon_rake: peak 284 px at frame 21, 35/49 frames exposed; hit: peak 253 px at frame 6, 32/37 frames exposed; death: peak 181 px at frame 8, 62/63 frames exposed; idle: peak 94 px at frame 45, 132/144 frames exposed.
- Neighbouring materials: `head` — dusky storm-grey, grey-tan and dark brown plumage (470 px covered, 40 px border); `mask` — bold dark mask band (53 px covered); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (944 px covered, 47 px border); `legs` — grey-brown scaled legs with big talons (6 px covered, 7 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (1 px border).
- Request: [native](front_body.png) / [4× nearest](front_body_4x.png).

## 4. rear / head

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 460 px; peak sampled exposure: 423 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[171, 62, 214, 98]`.
- Motions that expose it: death: peak 423 px at frame 28, 54/63 frames exposed; dive: peak 327 px at frame 14, 36/61 frames exposed; move: peak 308 px at frame 17, 16/49 frames exposed; hover: peak 307 px at frame 16, 19/49 frames exposed; talon_rake: peak 307 px at frame 11, 22/49 frames exposed; idle: peak 145 px at frame 100, 89/144 frames exposed; hit: peak 4 px at frame 4, 27/37 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (7 px covered, 5 px border); `beak` — heavy hooked iron-grey beak (1 px covered, 4 px border); `mask` — bold dark mask band (28 px covered, 1 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (424 px covered, 45 px border).
- Request: [native](rear_head.png) / [4× nearest](rear_head_4x.png).

## 5. front / wing_far

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 850 px; peak sampled exposure: 220 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[71, 117, 126, 167]`.
- Motions that expose it: idle: peak 220 px at frame 91, 135/144 frames exposed; dive: peak 159 px at frame 39, 54/61 frames exposed; hover: peak 152 px at frame 9, 39/49 frames exposed; move: peak 152 px at frame 38, 45/49 frames exposed; talon_rake: peak 140 px at frame 21, 44/49 frames exposed; hit: peak 128 px at frame 6, 32/37 frames exposed; death: peak 97 px at frame 7, 62/63 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (239 px covered, 17 px border); `head` — dusky storm-grey, grey-tan and dark brown plumage (353 px covered, 40 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (258 px covered, 61 px border).
- Request: [native](front_wing_far.png) / [4× nearest](front_wing_far_4x.png).

## 6. rear / legs

- Material: grey-brown scaled legs with big talons.
- Hidden area: 494 px; peak sampled exposure: 127 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[140, 146, 172, 185]`.
- Motions that expose it: death: peak 127 px at frame 26, 55/63 frames exposed; talon_rake: peak 115 px at frame 23, 31/49 frames exposed; move: peak 109 px at frame 38, 14/49 frames exposed; hit: peak 40 px at frame 5, 31/37 frames exposed; idle: peak 4 px at frame 32, 42/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (379 px covered, 96 px border); `wing_far` — dark brown plumage with pale storm grey-blue leading edge (115 px covered, 21 px border).
- Request: [native](rear_legs.png) / [4× nearest](rear_legs_4x.png).

## 7. rear / wing_far

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 119 px; peak sampled exposure: 119 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[151, 71, 190, 159]`.
- Motions that expose it: hit: peak 119 px at frame 3, 31/37 frames exposed; move: peak 119 px at frame 30, 46/49 frames exposed; dive: peak 118 px at frame 47, 53/61 frames exposed; hover: peak 118 px at frame 23, 39/49 frames exposed; death: peak 117 px at frame 7, 62/63 frames exposed; talon_rake: peak 116 px at frame 22, 44/49 frames exposed; idle: peak 102 px at frame 83, 144/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (115 px covered, 45 px border); `head` — dusky storm-grey, grey-tan and dark brown plumage (4 px covered, 8 px border).
- Request: [native](rear_wing_far.png) / [4× nearest](rear_wing_far_4x.png).

## 8. front / legs

- Material: grey-brown scaled legs with big talons.
- Hidden area: 208 px; peak sampled exposure: 105 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[91, 194, 120, 213]`.
- Motions that expose it: hit: peak 105 px at frame 5, 31/37 frames exposed; talon_rake: peak 26 px at frame 20, 19/49 frames exposed; death: peak 23 px at frame 22, 19/63 frames exposed; move: peak 23 px at frame 37, 31/49 frames exposed; idle: peak 11 px at frame 23, 66/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (208 px covered, 60 px border).
- Request: [native](front_legs.png) / [4× nearest](front_legs_4x.png).

## 9. front / tail

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 194 px; peak sampled exposure: 31 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[137, 176, 156, 194]`.
- Motions that expose it: move: peak 31 px at frame 36, 34/49 frames exposed; hover: peak 29 px at frame 6, 22/49 frames exposed; dive: peak 27 px at frame 39, 54/61 frames exposed; hit: peak 26 px at frame 5, 31/37 frames exposed; talon_rake: peak 26 px at frame 21, 25/49 frames exposed; death: peak 17 px at frame 8, 9/63 frames exposed; idle: peak 10 px at frame 29, 67/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (91 px covered, 21 px border); `wing_near` — dark brown plumage with pale storm grey-blue leading edge (103 px covered, 17 px border).
- Request: [native](front_tail.png) / [4× nearest](front_tail_4x.png).

## 10. front / wing_near

- Material: dark brown plumage with pale storm grey-blue leading edge.
- Hidden area: 16 px; peak sampled exposure: 19 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[125, 180, 156, 185]`.
- Motions that expose it: hover: peak 19 px at frame 9, 21/49 frames exposed; hit: peak 18 px at frame 10, 32/37 frames exposed; death: peak 17 px at frame 7, 25/63 frames exposed; dive: peak 17 px at frame 40, 25/61 frames exposed; move: peak 17 px at frame 6, 32/49 frames exposed; talon_rake: peak 17 px at frame 20, 26/49 frames exposed; idle: peak 16 px at frame 22, 58/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (15 px covered, 14 px border); `tail` — dusky storm-grey, grey-tan and dark brown plumage (1 px covered, 2 px border).
- Request: [native](front_wing_near.png) / [4× nearest](front_wing_near_4x.png).

## 11. front / head

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 107 px; peak sampled exposure: 14 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[52, 155, 92, 182]`.
- Motions that expose it: idle: peak 14 px at frame 78, 133/144 frames exposed; death: peak 12 px at frame 23, 61/63 frames exposed; hit: peak 12 px at frame 11, 25/37 frames exposed; dive: peak 7 px at frame 39, 37/61 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (15 px covered, 24 px border); `beak` — heavy hooked iron-grey beak (39 px covered, 8 px border); `mask` — bold dark mask band (53 px covered).
- Request: [native](front_head.png) / [4× nearest](front_head_4x.png).

## 12. rear / tail

- Material: dusky storm-grey, grey-tan and dark brown plumage.
- Hidden area: 89 px; peak sampled exposure: 9 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[110, 174, 125, 184]`.
- Motions that expose it: death: peak 9 px at frame 38, 54/63 frames exposed; move: peak 9 px at frame 43, 18/49 frames exposed; idle: peak 2 px at frame 63, 9/144 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (89 px covered, 21 px border).
- Request: [native](rear_tail.png) / [4× nearest](rear_tail_4x.png).

## 13. front / mask

- Material: bold dark mask band.
- Hidden area: 383 px; peak sampled exposure: 2 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[50, 151, 82, 170]`.
- Motions that expose it: death: peak 2 px at frame 10, 56/63 frames exposed; dive: peak 1 px at frame 10, 4/61 frames exposed; hit: peak 1 px at frame 2, 22/37 frames exposed; idle: peak 1 px at frame 12, 121/144 frames exposed; move: peak 1 px at frame 43, 2/49 frames exposed.
- Neighbouring materials: `body` — dusky storm-grey, grey-tan and dark brown plumage (1 px covered); `head` — dusky storm-grey, grey-tan and dark brown plumage (382 px covered, 58 px border).
- Request: [native](front_mask.png) / [4× nearest](front_mask_4x.png).

## 14. front / beak

- Material: heavy hooked iron-grey beak.
- Hidden area: 0 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `None`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: none; no hidden region.
- Request: [native](front_beak.png) / [4× nearest](front_beak_4x.png).

## 15. rear / beak

- Material: heavy hooked iron-grey beak.
- Hidden area: 0 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `None`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: none; no hidden region.
- Request: [native](rear_beak.png) / [4× nearest](rear_beak_4x.png).

## 16. rear / mask

- Material: bold dark mask band.
- Hidden area: 0 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `None`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: none; no hidden region.
- Request: [native](rear_mask.png) / [4× nearest](rear_mask_4x.png).
