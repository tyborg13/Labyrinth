# Hidden-material paint plan

Sorted by maximum sampled exposure, then hidden area. All five production clips
are sampled in each view; a zero means no exposed pixels in those sampled poses.
Exposure uses actual headless Skeleton2D transforms and nearest CPU masks.
It is a painting priority estimate; the native reel remains separate proof.

Magenta #FF00FF marks hidden material; green #00FF00 is background.
Neighbour names refer to the approved painted ownership, not new anatomy.
Covered counts measure the part currently hiding this request; border counts
measure its four-connected painted neighbours. Material descriptions come
from the approved pair and its supplied identity/material brief.

## 1. front / thigh_far

- Material: dark cloth trouser leg.
- Hidden area: 2075 px; peak sampled exposure: 1061 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[111, 113, 154, 188]`.
- Motions that expose it: walk: peak 1061 px at frame 47, 48/48 frames exposed; strike: peak 58 px at frame 12, 25/31 frames exposed; death: peak 35 px at frame 2, 31/32 frames exposed; hit: peak 34 px at frame 6, 17/24 frames exposed; idle: peak 11 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (549 px covered, 51 px border); `pelvis` — dark cloth at hips (74 px covered, 7 px border); `belt` — broad brown belt (333 px covered, 23 px border); `tabard` — red-brown tabard with its approved insignia (1103 px covered, 45 px border); `shin_far` — dark lower leg and boot cuff (13 px covered, 5 px border); `foot_far` — dull dark brown boot (3 px covered, 1 px border); `coat_far` — dark ash-grey ragged coat tail (7 px border).
- Request: [native](front_thigh_far.png) / [4× nearest](front_thigh_far_4x.png).

## 2. front / coat_near

- Material: dark ash-grey ragged coat tail.
- Hidden area: 729 px; peak sampled exposure: 709 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[165, 127, 190, 210]`.
- Motions that expose it: strike: peak 709 px at frame 22, 29/31 frames exposed; walk: peak 244 px at frame 35, 44/48 frames exposed; death: peak 76 px at frame 2, 28/32 frames exposed; hit: peak 73 px at frame 6, 17/24 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (8 px covered); `belt` — broad brown belt (2 px covered, 3 px border); `tabard` — red-brown tabard with its approved insignia (9 px covered, 1 px border); `upper_near` — dark cloth sleeve (90 px covered, 17 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (392 px covered, 22 px border); `hand_near` — dark brown leather glove (223 px covered, 21 px border); `foot_near` — dull dark brown boot (1 px covered); `shin_far` — dark lower leg and boot cuff (1 px covered); `foot_far` — dull dark brown boot (2 px covered, 3 px border); `chain` — chunky dark-iron chain (1 px covered); `shin_near` — dark lower leg and boot cuff (5 px border).
- Request: [native](front_coat_near.png) / [4× nearest](front_coat_near_4x.png).

## 3. front / thigh_near

- Material: dark cloth trouser leg.
- Hidden area: 1634 px; peak sampled exposure: 616 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[146, 126, 181, 203]`.
- Motions that expose it: walk: peak 616 px at frame 21, 48/48 frames exposed; strike: peak 340 px at frame 5, 28/31 frames exposed; death: peak 110 px at frame 13, 31/32 frames exposed; hit: peak 40 px at frame 6, 17/24 frames exposed; idle: peak 26 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (2 px covered); `torso` — dark ash-grey cowl and tunic (92 px covered, 16 px border); `pelvis` — dark cloth at hips (40 px covered, 8 px border); `belt` — broad brown belt (189 px covered, 12 px border); `tabard` — red-brown tabard with its approved insignia (4 px covered); `coat_near` — dark ash-grey ragged coat tail (202 px covered, 33 px border); `upper_near` — dark cloth sleeve (154 px covered, 24 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (426 px covered, 20 px border); `hand_near` — dark brown leather glove (431 px covered, 9 px border); `upper_far` — dark cloth sleeve (1 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (1 px covered); `shin_near` — dark lower leg and boot cuff (74 px covered, 12 px border); `foot_near` — dull dark brown boot (3 px covered); `shin_far` — dark lower leg and boot cuff (6 px covered); `foot_far` — dull dark brown boot (9 px covered); `coat_far` — dark ash-grey ragged coat tail (1 px border); `chain` — chunky dark-iron chain (1 px border).
- Request: [native](front_thigh_near.png) / [4× nearest](front_thigh_near_4x.png).

## 4. rear / shin_far

- Material: dark lower leg and boot cuff.
- Hidden area: 1054 px; peak sampled exposure: 559 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[118, 172, 146, 236]`.
- Motions that expose it: walk: peak 559 px at frame 29, 41/48 frames exposed; idle: peak 24 px at frame 6, 13/24 frames exposed; strike: peak 17 px at frame 21, 16/31 frames exposed; hit: peak 13 px at frame 1, 8/24 frames exposed; death: peak 3 px at frame 2, 2/32 frames exposed.
- Neighbouring materials: `coat_near` — dark ash-grey ragged coat tail (3 px covered); `coat_far` — dark ash-grey ragged coat tail (1046 px covered, 94 px border); `foot_far` — dull dark brown boot (5 px covered, 4 px border).
- Request: [native](rear_shin_far.png) / [4× nearest](rear_shin_far_4x.png).

## 5. rear / upper_near

- Material: dark cloth sleeve.
- Hidden area: 1110 px; peak sampled exposure: 541 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[70, 62, 102, 111]`.
- Motions that expose it: strike: peak 541 px at frame 7, 29/31 frames exposed; walk: peak 19 px at frame 5, 46/48 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (4 px covered, 4 px border); `torso` — dark ash-grey cowl and tunic (1100 px covered, 60 px border); `tabard` — red-brown tabard with its approved insignia (1 px covered); `coat_near` — dark ash-grey ragged coat tail (1 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (3 px covered); `foot_far` — dull dark brown boot (1 px covered).
- Request: [native](rear_upper_near.png) / [4× nearest](rear_upper_near_4x.png).

## 6. rear / thigh_far

- Material: dark cloth trouser leg.
- Hidden area: 2063 px; peak sampled exposure: 442 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[102, 130, 146, 200]`.
- Motions that expose it: walk: peak 442 px at frame 27, 38/48 frames exposed; strike: peak 11 px at frame 12, 16/31 frames exposed; death: peak 4 px at frame 9, 5/32 frames exposed; hit: peak 2 px at frame 16, 2/24 frames exposed; idle: peak 2 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (125 px covered, 27 px border); `pelvis` — dark cloth at hips (52 px covered, 13 px border); `belt` — broad brown belt (346 px covered, 19 px border); `coat_far` — dark ash-grey ragged coat tail (1540 px covered, 103 px border).
- Request: [native](rear_thigh_far.png) / [4× nearest](rear_thigh_far_4x.png).

## 7. front / torso

- Material: dark ash-grey cowl and tunic.
- Hidden area: 1954 px; peak sampled exposure: 396 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[117, 57, 186, 138]`.
- Motions that expose it: strike: peak 396 px at frame 13, 26/31 frames exposed; walk: peak 88 px at frame 12, 44/48 frames exposed; death: peak 40 px at frame 14, 31/32 frames exposed; hit: peak 9 px at frame 6, 17/24 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (845 px covered, 43 px border); `belt` — broad brown belt (38 px covered, 29 px border); `coat_near` — dark ash-grey ragged coat tail (13 px covered); `upper_near` — dark cloth sleeve (1046 px covered, 57 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (4 px covered, 4 px border); `upper_far` — dark cloth sleeve (1 px covered, 1 px border); `fore_far` — dark cloth sleeve with broad brown leather bands (7 px covered).
- Request: [native](front_torso.png) / [4× nearest](front_torso_4x.png).

## 8. rear / thigh_near

- Material: dark cloth trouser leg.
- Hidden area: 1293 px; peak sampled exposure: 339 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[75, 117, 110, 187]`.
- Motions that expose it: walk: peak 339 px at frame 7, 48/48 frames exposed; strike: peak 56 px at frame 12, 25/31 frames exposed; idle: peak 29 px at frame 6, 13/24 frames exposed; death: peak 28 px at frame 15, 31/32 frames exposed; hit: peak 19 px at frame 5, 18/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (366 px covered, 41 px border); `pelvis` — dark cloth at hips (362 px covered, 4 px border); `belt` — broad brown belt (413 px covered, 25 px border); `shin_near` — dark lower leg and boot cuff (136 px covered, 32 px border); `thigh_far` — dark cloth trouser leg (1 px covered, 2 px border); `shin_far` — dark lower leg and boot cuff (5 px covered); `foot_far` — dull dark brown boot (10 px covered, 3 px border); `coat_near` — dark ash-grey ragged coat tail (7 px border); `coat_far` — dark ash-grey ragged coat tail (6 px border).
- Request: [native](rear_thigh_near.png) / [4× nearest](rear_thigh_near_4x.png).

## 9. front / shin_far

- Material: dark lower leg and boot cuff.
- Hidden area: 926 px; peak sampled exposure: 336 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[110, 160, 138, 227]`.
- Motions that expose it: walk: peak 336 px at frame 46, 48/48 frames exposed; strike: peak 50 px at frame 13, 25/31 frames exposed; idle: peak 21 px at frame 6, 13/24 frames exposed; hit: peak 20 px at frame 3, 17/24 frames exposed; death: peak 19 px at frame 2, 30/32 frames exposed.
- Neighbouring materials: `tabard` — red-brown tabard with its approved insignia (780 px covered, 25 px border); `thigh_far` — dark cloth trouser leg (27 px covered, 12 px border); `foot_far` — dull dark brown boot (119 px covered, 17 px border); `coat_far` — dark ash-grey ragged coat tail (1 px border).
- Request: [native](front_shin_far.png) / [4× nearest](front_shin_far_4x.png).

## 10. front / upper_near

- Material: dark cloth sleeve.
- Hidden area: 430 px; peak sampled exposure: 255 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[154, 82, 188, 147]`.
- Motions that expose it: strike: peak 255 px at frame 6, 29/31 frames exposed; walk: peak 78 px at frame 10, 48/48 frames exposed; hit: peak 4 px at frame 9, 18/24 frames exposed; death: peak 3 px at frame 2, 7/32 frames exposed; idle: peak 2 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (238 px covered, 57 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (181 px covered, 30 px border); `upper_far` — dark cloth sleeve (1 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (7 px covered); `shin_far` — dark lower leg and boot cuff (1 px covered); `foot_far` — dull dark brown boot (2 px covered); `head` — rusted dark-iron bucket helm (1 px border); `belt` — broad brown belt (2 px border); `tabard` — red-brown tabard with its approved insignia (1 px border); `coat_near` — dark ash-grey ragged coat tail (4 px border).
- Request: [native](front_upper_near.png) / [4× nearest](front_upper_near_4x.png).

## 11. front / shin_near

- Material: dark lower leg and boot cuff.
- Hidden area: 752 px; peak sampled exposure: 199 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[154, 174, 188, 241]`.
- Motions that expose it: walk: peak 199 px at frame 23, 48/48 frames exposed; hit: peak 19 px at frame 3, 17/24 frames exposed; strike: peak 19 px at frame 5, 18/31 frames exposed; death: peak 18 px at frame 3, 31/32 frames exposed; idle: peak 12 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (2 px covered); `tabard` — red-brown tabard with its approved insignia (3 px covered, 1 px border); `coat_near` — dark ash-grey ragged coat tail (306 px covered, 30 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (1 px covered); `hand_near` — dark brown leather glove (28 px covered, 13 px border); `thigh_near` — dark cloth trouser leg (287 px covered, 5 px border); `foot_near` — dull dark brown boot (117 px covered, 22 px border); `foot_far` — dull dark brown boot (8 px covered, 2 px border).
- Request: [native](front_shin_near.png) / [4× nearest](front_shin_near_4x.png).

## 12. rear / coat_near

- Material: dark ash-grey ragged coat tail.
- Hidden area: 738 px; peak sampled exposure: 198 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[67, 109, 91, 168]`.
- Motions that expose it: walk: peak 198 px at frame 29, 40/48 frames exposed; death: peak 35 px at frame 2, 31/32 frames exposed; hit: peak 32 px at frame 9, 17/24 frames exposed; strike: peak 27 px at frame 5, 20/31 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (4 px covered, 1 px border); `torso` — dark ash-grey cowl and tunic (198 px covered, 34 px border); `pelvis` — dark cloth at hips (90 px covered, 12 px border); `belt` — broad brown belt (258 px covered, 11 px border); `coat_far` — dark ash-grey ragged coat tail (1 px covered); `thigh_near` — dark cloth trouser leg (178 px covered, 18 px border); `shin_far` — dark lower leg and boot cuff (1 px covered); `foot_far` — dull dark brown boot (8 px covered).
- Request: [native](rear_coat_near.png) / [4× nearest](rear_coat_near_4x.png).

## 13. front / belt

- Material: broad brown belt.
- Hidden area: 2072 px; peak sampled exposure: 184 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[114, 98, 191, 149]`.
- Motions that expose it: strike: peak 184 px at frame 12, 25/31 frames exposed; death: peak 79 px at frame 14, 31/32 frames exposed; walk: peak 66 px at frame 10, 48/48 frames exposed; hit: peak 21 px at frame 15, 16/24 frames exposed; idle: peak 2 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (1295 px covered, 47 px border); `coat_near` — dark ash-grey ragged coat tail (9 px covered, 6 px border); `upper_near` — dark cloth sleeve (640 px covered, 36 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (119 px covered, 20 px border); `upper_far` — dark cloth sleeve (1 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (3 px covered); `shin_far` — dark lower leg and boot cuff (1 px covered); `foot_far` — dull dark brown boot (4 px covered).
- Request: [native](front_belt.png) / [4× nearest](front_belt_4x.png).

## 14. rear / fore_near

- Material: dark cloth sleeve with broad brown leather bands.
- Hidden area: 901 px; peak sampled exposure: 73 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[70, 85, 98, 129]`.
- Motions that expose it: strike: peak 73 px at frame 6, 16/31 frames exposed; walk: peak 34 px at frame 10, 46/48 frames exposed; death: peak 3 px at frame 11, 27/32 frames exposed; hit: peak 1 px at frame 11, 1/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (875 px covered, 62 px border); `belt` — broad brown belt (20 px covered, 17 px border); `tabard` — red-brown tabard with its approved insignia (1 px covered); `upper_near` — dark cloth sleeve (4 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (1 px covered).
- Request: [native](rear_fore_near.png) / [4× nearest](rear_fore_near_4x.png).

## 15. front / coat_far

- Material: dark ash-grey ragged coat tail.
- Hidden area: 1919 px; peak sampled exposure: 64 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[109, 103, 148, 172]`.
- Motions that expose it: walk: peak 64 px at frame 18, 48/48 frames exposed; death: peak 9 px at frame 7, 31/32 frames exposed; strike: peak 9 px at frame 12, 22/31 frames exposed; hit: peak 7 px at frame 3, 16/24 frames exposed; idle: peak 2 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (676 px covered, 66 px border); `pelvis` — dark cloth at hips (76 px covered, 7 px border); `belt` — broad brown belt (351 px covered, 22 px border); `tabard` — red-brown tabard with its approved insignia (754 px covered, 23 px border); `coat_near` — dark ash-grey ragged coat tail (3 px covered); `thigh_far` — dark cloth trouser leg (51 px covered, 7 px border); `shin_far` — dark lower leg and boot cuff (5 px covered, 1 px border); `foot_far` — dull dark brown boot (3 px covered).
- Request: [native](front_coat_far.png) / [4× nearest](front_coat_far_4x.png).

## 16. front / fore_near

- Material: dark cloth sleeve with broad brown leather bands.
- Hidden area: 676 px; peak sampled exposure: 55 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[158, 121, 188, 175]`.
- Motions that expose it: strike: peak 55 px at frame 7, 27/31 frames exposed; walk: peak 15 px at frame 36, 48/48 frames exposed; death: peak 12 px at frame 4, 31/32 frames exposed; hit: peak 11 px at frame 5, 17/24 frames exposed; idle: peak 1 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `tabard` — red-brown tabard with its approved insignia (3 px covered); `upper_near` — dark cloth sleeve (354 px covered, 34 px border); `hand_near` — dark brown leather glove (316 px covered, 44 px border); `foot_near` — dull dark brown boot (1 px covered); `foot_far` — dull dark brown boot (2 px covered, 2 px border); `head` — rusted dark-iron bucket helm (1 px border); `torso` — dark ash-grey cowl and tunic (1 px border); `belt` — broad brown belt (1 px border); `coat_near` — dark ash-grey ragged coat tail (11 px border).
- Request: [native](front_fore_near.png) / [4× nearest](front_fore_near_4x.png).

## 17. rear / hand_near

- Material: dark brown leather glove.
- Hidden area: 594 px; peak sampled exposure: 45 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[74, 104, 101, 132]`.
- Motions that expose it: strike: peak 45 px at frame 7, 17/31 frames exposed; walk: peak 25 px at frame 9, 25/48 frames exposed; death: peak 17 px at frame 15, 26/32 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (509 px covered, 49 px border); `belt` — broad brown belt (85 px covered, 24 px border).
- Request: [native](rear_hand_near.png) / [4× nearest](rear_hand_near_4x.png).

## 18. front / upper_far

- Material: dark cloth sleeve.
- Hidden area: 936 px; peak sampled exposure: 44 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[79, 57, 137, 95]`.
- Motions that expose it: walk: peak 44 px at frame 34, 42/48 frames exposed; strike: peak 28 px at frame 11, 17/31 frames exposed; death: peak 2 px at frame 8, 29/32 frames exposed; hit: peak 1 px at frame 2, 15/24 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (376 px covered, 35 px border); `torso` — dark ash-grey cowl and tunic (372 px covered, 25 px border); `tabard` — red-brown tabard with its approved insignia (1 px covered); `coat_near` — dark ash-grey ragged coat tail (3 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (184 px covered, 23 px border).
- Request: [native](front_upper_far.png) / [4× nearest](front_upper_far_4x.png).

## 19. rear / foot_far

- Material: dull dark brown boot.
- Hidden area: 346 px; peak sampled exposure: 39 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[122, 222, 144, 244]`.
- Motions that expose it: walk: peak 39 px at frame 46, 30/48 frames exposed; death: peak 7 px at frame 14, 22/32 frames exposed.
- Neighbouring materials: `shin_far` — dark lower leg and boot cuff (346 px covered, 47 px border).
- Request: [native](rear_foot_far.png) / [4× nearest](rear_foot_far_4x.png).

## 20. rear / torso

- Material: dark ash-grey cowl and tunic.
- Hidden area: 1423 px; peak sampled exposure: 33 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[71, 53, 151, 140]`.
- Motions that expose it: death: peak 33 px at frame 2, 31/32 frames exposed; hit: peak 30 px at frame 6, 18/24 frames exposed; strike: peak 25 px at frame 12, 29/31 frames exposed; walk: peak 16 px at frame 15, 48/48 frames exposed; idle: peak 1 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `head` — rusted dark-iron bucket helm (471 px covered, 39 px border); `belt` — broad brown belt (146 px covered, 53 px border); `tabard` — red-brown tabard with its approved insignia (1 px covered); `coat_near` — dark ash-grey ragged coat tail (8 px covered, 1 px border); `upper_near` — dark cloth sleeve (14 px covered, 15 px border); `upper_far` — dark cloth sleeve (780 px covered, 34 px border); `fore_far` — dark cloth sleeve with broad brown leather bands (2 px covered); `foot_far` — dull dark brown boot (1 px covered).
- Request: [native](rear_torso.png) / [4× nearest](rear_torso_4x.png).

## 21. rear / fore_far

- Material: dark cloth sleeve with broad brown leather bands.
- Hidden area: 607 px; peak sampled exposure: 23 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[150, 92, 198, 134]`.
- Motions that expose it: walk: peak 23 px at frame 31, 42/48 frames exposed; strike: peak 12 px at frame 13, 13/31 frames exposed; death: peak 10 px at frame 9, 29/32 frames exposed; hit: peak 7 px at frame 9, 11/24 frames exposed.
- Neighbouring materials: `upper_far` — dark cloth sleeve (288 px covered, 47 px border); `hand_far` — dark brown leather glove (319 px covered, 13 px border); `chain` — chunky dark-iron chain (1 px border).
- Request: [native](rear_fore_far.png) / [4× nearest](rear_fore_far_4x.png).

## 22. rear / head

- Material: rusted dark-iron bucket helm.
- Hidden area: 479 px; peak sampled exposure: 21 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[94, 62, 139, 83]`.
- Motions that expose it: death: peak 21 px at frame 15, 30/32 frames exposed; hit: peak 8 px at frame 2, 17/24 frames exposed; walk: peak 8 px at frame 2, 42/48 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (471 px covered, 58 px border); `coat_near` — dark ash-grey ragged coat tail (8 px covered, 1 px border).
- Request: [native](rear_head.png) / [4× nearest](rear_head_4x.png).

## 23. front / hand_near

- Material: dark brown leather glove.
- Hidden area: 152 px; peak sampled exposure: 21 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[158, 150, 181, 178]`.
- Motions that expose it: strike: peak 21 px at frame 5, 25/31 frames exposed; walk: peak 8 px at frame 25, 48/48 frames exposed; death: peak 5 px at frame 1, 29/32 frames exposed; hit: peak 5 px at frame 6, 18/24 frames exposed; idle: peak 2 px at frame 6, 13/24 frames exposed.
- Neighbouring materials: `tabard` — red-brown tabard with its approved insignia (4 px covered); `fore_near` — dark cloth sleeve with broad brown leather bands (144 px covered, 24 px border); `foot_near` — dull dark brown boot (3 px covered); `chain` — chunky dark-iron chain (1 px covered); `head` — rusted dark-iron bucket helm (1 px border); `coat_near` — dark ash-grey ragged coat tail (9 px border); `thigh_near` — dark cloth trouser leg (5 px border); `shin_near` — dark lower leg and boot cuff (1 px border).
- Request: [native](front_hand_near.png) / [4× nearest](front_hand_near_4x.png).

## 24. front / head

- Material: rusted dark-iron bucket helm.
- Hidden area: 302 px; peak sampled exposure: 20 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[117, 67, 161, 90]`.
- Motions that expose it: death: peak 20 px at frame 7, 30/32 frames exposed; hit: peak 12 px at frame 2, 17/24 frames exposed; walk: peak 12 px at frame 2, 42/48 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (290 px covered, 59 px border); `coat_near` — dark ash-grey ragged coat tail (12 px covered, 1 px border).
- Request: [native](front_head.png) / [4× nearest](front_head_4x.png).

## 25. rear / coat_far

- Material: dark ash-grey ragged coat tail.
- Hidden area: 199 px; peak sampled exposure: 19 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[108, 134, 143, 219]`.
- Motions that expose it: walk: peak 19 px at frame 31, 48/48 frames exposed; hit: peak 3 px at frame 1, 11/24 frames exposed; idle: peak 3 px at frame 6, 13/24 frames exposed; strike: peak 3 px at frame 3, 20/31 frames exposed; death: peak 1 px at frame 2, 2/32 frames exposed.
- Neighbouring materials: `belt` — broad brown belt (193 px covered, 39 px border); `coat_near` — dark ash-grey ragged coat tail (3 px covered); `foot_far` — dull dark brown boot (3 px covered); `shin_far` — dark lower leg and boot cuff (12 px border).
- Request: [native](rear_coat_far.png) / [4× nearest](rear_coat_far_4x.png).

## 26. rear / foot_near

- Material: dull dark brown boot.
- Hidden area: 363 px; peak sampled exposure: 17 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[71, 208, 95, 229]`.
- Motions that expose it: walk: peak 17 px at frame 40, 25/48 frames exposed; death: peak 6 px at frame 13, 21/32 frames exposed.
- Neighbouring materials: `shin_near` — dark lower leg and boot cuff (363 px covered, 48 px border).
- Request: [native](rear_foot_near.png) / [4× nearest](rear_foot_near_4x.png).

## 27. rear / upper_far

- Material: dark cloth sleeve.
- Hidden area: 405 px; peak sampled exposure: 15 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[119, 81, 176, 132]`.
- Motions that expose it: strike: peak 15 px at frame 11, 15/31 frames exposed; walk: peak 13 px at frame 7, 27/48 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (141 px covered, 50 px border); `fore_far` — dark cloth sleeve with broad brown leather bands (264 px covered, 28 px border).
- Request: [native](rear_upper_far.png) / [4× nearest](rear_upper_far_4x.png).

## 28. rear / shin_near

- Material: dark lower leg and boot cuff.
- Hidden area: 493 px; peak sampled exposure: 13 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[77, 159, 105, 224]`.
- Motions that expose it: walk: peak 13 px at frame 47, 34/48 frames exposed; death: peak 7 px at frame 3, 30/32 frames exposed; hit: peak 5 px at frame 4, 12/24 frames exposed; strike: peak 3 px at frame 11, 15/31 frames exposed.
- Neighbouring materials: `thigh_near` — dark cloth trouser leg (483 px covered, 45 px border); `foot_near` — dull dark brown boot (2 px covered, 4 px border); `foot_far` — dull dark brown boot (8 px covered, 9 px border); `shin_far` — dark lower leg and boot cuff (1 px border).
- Request: [native](rear_shin_near.png) / [4× nearest](rear_shin_near_4x.png).

## 29. rear / belt

- Material: broad brown belt.
- Hidden area: 1307 px; peak sampled exposure: 12 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[76, 106, 142, 151]`.
- Motions that expose it: death: peak 12 px at frame 1, 30/32 frames exposed; hit: peak 12 px at frame 11, 17/24 frames exposed; walk: peak 1 px at frame 3, 11/48 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (1294 px covered, 65 px border); `coat_far` — dark ash-grey ragged coat tail (13 px covered, 15 px border); `tabard` — red-brown tabard with its approved insignia (1 px border).
- Request: [native](rear_belt.png) / [4× nearest](rear_belt_4x.png).

## 30. front / fore_far

- Material: dark cloth sleeve with broad brown leather bands.
- Hidden area: 689 px; peak sampled exposure: 12 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[56, 57, 105, 97]`.
- Motions that expose it: walk: peak 12 px at frame 2, 40/48 frames exposed; hit: peak 9 px at frame 3, 9/24 frames exposed; strike: peak 9 px at frame 11, 17/31 frames exposed; death: peak 8 px at frame 11, 26/32 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (1 px covered, 8 px border); `upper_far` — dark cloth sleeve (342 px covered, 31 px border); `hand_far` — dark brown leather glove (346 px covered, 22 px border); `chain` — chunky dark-iron chain (1 px border).
- Request: [native](front_fore_far.png) / [4× nearest](front_fore_far_4x.png).

## 31. rear / hand_far

- Material: dark brown leather glove.
- Hidden area: 56 px; peak sampled exposure: 12 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[177, 99, 189, 116]`.
- Motions that expose it: walk: peak 12 px at frame 2, 30/48 frames exposed; strike: peak 10 px at frame 23, 3/31 frames exposed; death: peak 9 px at frame 13, 24/32 frames exposed; hit: peak 5 px at frame 9, 4/24 frames exposed.
- Neighbouring materials: `fore_far` — dark cloth sleeve with broad brown leather bands (56 px covered, 22 px border).
- Request: [native](rear_hand_far.png) / [4× nearest](rear_hand_far_4x.png).

## 32. front / hand_far

- Material: dark brown leather glove.
- Hidden area: 67 px; peak sampled exposure: 11 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[67, 63, 79, 81]`.
- Motions that expose it: walk: peak 11 px at frame 26, 26/48 frames exposed; death: peak 9 px at frame 10, 24/32 frames exposed; strike: peak 9 px at frame 24, 14/31 frames exposed; hit: peak 8 px at frame 9, 4/24 frames exposed.
- Neighbouring materials: `fore_far` — dark cloth sleeve with broad brown leather bands (67 px covered, 23 px border).
- Request: [native](front_hand_far.png) / [4× nearest](front_hand_far_4x.png).

## 33. rear / pelvis

- Material: dark cloth at hips.
- Hidden area: 1727 px; peak sampled exposure: 10 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[77, 115, 135, 161]`.
- Motions that expose it: walk: peak 10 px at frame 39, 30/48 frames exposed; hit: peak 6 px at frame 16, 12/24 frames exposed; death: peak 3 px at frame 3, 8/32 frames exposed; idle: peak 3 px at frame 6, 13/24 frames exposed; strike: peak 3 px at frame 3, 18/31 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (796 px covered, 57 px border); `belt` — broad brown belt (661 px covered, 19 px border); `coat_far` — dark ash-grey ragged coat tail (267 px covered, 34 px border); `thigh_far` — dark cloth trouser leg (1 px covered, 1 px border); `shin_far` — dark lower leg and boot cuff (2 px covered, 1 px border); `thigh_near` — dark cloth trouser leg (12 px border).
- Request: [native](rear_pelvis.png) / [4× nearest](rear_pelvis_4x.png).

## 34. front / foot_far

- Material: dull dark brown boot.
- Hidden area: 168 px; peak sampled exposure: 10 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[113, 209, 134, 224]`.
- Motions that expose it: death: peak 10 px at frame 15, 26/32 frames exposed; walk: peak 3 px at frame 19, 9/48 frames exposed.
- Neighbouring materials: `shin_far` — dark lower leg and boot cuff (168 px covered, 31 px border).
- Request: [native](front_foot_far.png) / [4× nearest](front_foot_far_4x.png).

## 35. front / pelvis

- Material: dark cloth at hips.
- Hidden area: 1982 px; peak sampled exposure: 8 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[121, 111, 179, 157]`.
- Motions that expose it: walk: peak 8 px at frame 5, 28/48 frames exposed; death: peak 2 px at frame 9, 30/32 frames exposed; hit: peak 1 px at frame 1, 13/24 frames exposed; strike: peak 1 px at frame 12, 9/31 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (788 px covered, 44 px border); `belt` — broad brown belt (441 px covered, 10 px border); `tabard` — red-brown tabard with its approved insignia (134 px covered, 23 px border); `coat_far` — dark ash-grey ragged coat tail (1 px covered, 2 px border); `upper_near` — dark cloth sleeve (287 px covered, 26 px border); `fore_near` — dark cloth sleeve with broad brown leather bands (271 px covered, 22 px border); `hand_near` — dark brown leather glove (7 px covered, 7 px border); `upper_far` — dark cloth sleeve (1 px covered); `fore_far` — dark cloth sleeve with broad brown leather bands (2 px covered); `thigh_near` — dark cloth trouser leg (39 px covered, 9 px border); `shin_near` — dark lower leg and boot cuff (1 px covered, 1 px border); `shin_far` — dark lower leg and boot cuff (6 px covered); `foot_far` — dull dark brown boot (4 px covered); `thigh_far` — dark cloth trouser leg (2 px border).
- Request: [native](front_pelvis.png) / [4× nearest](front_pelvis_4x.png).

## 36. front / foot_near

- Material: dull dark brown boot.
- Hidden area: 168 px; peak sampled exposure: 6 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[163, 224, 185, 240]`.
- Motions that expose it: death: peak 6 px at frame 15, 26/32 frames exposed; walk: peak 4 px at frame 14, 31/48 frames exposed; strike: peak 3 px at frame 12, 10/31 frames exposed.
- Neighbouring materials: `shin_near` — dark lower leg and boot cuff (168 px covered, 33 px border).
- Request: [native](front_foot_near.png) / [4× nearest](front_foot_near_4x.png).

## 37. front / chain

- Material: chunky dark-iron chain.
- Hidden area: 95 px; peak sampled exposure: 5 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[57, 69, 72, 82]`.
- Motions that expose it: walk: peak 5 px at frame 21, 20/48 frames exposed; death: peak 1 px at frame 9, 23/32 frames exposed.
- Neighbouring materials: `fore_far` — dark cloth sleeve with broad brown leather bands (3 px covered, 7 px border); `hand_far` — dark brown leather glove (92 px covered, 36 px border).
- Request: [native](front_chain.png) / [4× nearest](front_chain_4x.png).

## 38. rear / tabard

- Material: red-brown tabard with its approved insignia.
- Hidden area: 1206 px; peak sampled exposure: 3 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[117, 113, 145, 177]`.
- Motions that expose it: walk: peak 3 px at frame 6, 13/48 frames exposed.
- Neighbouring materials: `torso` — dark ash-grey cowl and tunic (381 px covered, 49 px border); `belt` — broad brown belt (220 px covered, 15 px border); `coat_far` — dark ash-grey ragged coat tail (605 px covered, 65 px border).
- Request: [native](rear_tabard.png) / [4× nearest](rear_tabard_4x.png).

## 39. rear / chain

- Material: chunky dark-iron chain.
- Hidden area: 87 px; peak sampled exposure: 3 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[184, 105, 198, 116]`.
- Motions that expose it: walk: peak 3 px at frame 45, 14/48 frames exposed.
- Neighbouring materials: `hand_far` — dark brown leather glove (87 px covered, 36 px border); `fore_far` — dark cloth sleeve with broad brown leather bands (4 px border).
- Request: [native](rear_chain.png) / [4× nearest](rear_chain_4x.png).

## 40. front / tabard

- Material: red-brown tabard with its approved insignia.
- Hidden area: 2 px; peak sampled exposure: 2 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[133, 162, 137, 185]`.
- Motions that expose it: death: peak 2 px at frame 9, 25/32 frames exposed; idle: peak 2 px at frame 6, 13/24 frames exposed; strike: peak 2 px at frame 12, 19/31 frames exposed; walk: peak 2 px at frame 0, 40/48 frames exposed; hit: peak 1 px at frame 10, 6/24 frames exposed.
- Neighbouring materials: `foot_far` — dull dark brown boot (2 px covered); `thigh_far` — dark cloth trouser leg (1 px border); `shin_far` — dark lower leg and boot cuff (3 px border).
- Request: [native](front_tabard.png) / [4× nearest](front_tabard_4x.png).

## 41. rear / hook

- Material: barbed rusted-iron hook.
- Hidden area: 1 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `[214, 206, 215, 207]`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: `chain` — chunky dark-iron chain (1 px covered, 2 px border).
- Request: [native](rear_hook.png) / [4× nearest](rear_hook_4x.png).

## 42. front / hook

- Material: barbed rusted-iron hook.
- Hidden area: 0 px; peak sampled exposure: 0 px.
- Hidden bounds (left, top, right, bottom; exclusive): `None`.
- Motions that expose it: none in the sampled clips.
- Neighbouring materials: none; no hidden region.
- Request: [native](front_hook.png) / [4× nearest](front_hook_4x.png).
