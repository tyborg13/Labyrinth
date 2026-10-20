# mq-11 paint-overs (director-approved)

Final raws (these are what the rig units cut from):
- `hollow_mimic_front_mq11_raw.png`: round 2 (`mq11b`). The hair is brought forward around the face, per the owner's
  2026-10-20 note "situated too far back".
  - Prompt: `../../paintovers/hollow_mimic_front_mq11b.md`.
  - References: `refs_hollow_mimic_front_mq11b/`. Reference 03 is the round-1 raw.
- `hollow_mimic_rear_mq11_raw.png`: round 1 r2 (shaggy dome).
  - Prompts: `hollow_mimic_rear_mq11.md`, then `hollow_mimic_rear_mq11_r2.md`.
  - References: `refs_hollow_mimic_rear/`.
- `slag_mortar_front_mq11_raw.png`: round 1. The repaint is composited below y 560 into the approved mq9 front.
  - Prompt: `slag_mortar_front_mq11.md`.
  - References: `refs_slag_mortar_front/`.
- `slag_mortar_rear_mq11_raw.png`: round 2 (`mq11b`). A wide back flap replaces the narrow sash, per the owner's note
  "rear is like a thong". The repaint is composited below y 560 into the round-1 rear.
  - Prompt: `slag_mortar_rear_mq11b.md`.
  - References: `refs_slag_mortar_rear_mq11b/`.
`refs_hollow_mimic_front/` and `refs_slag_mortar_rear/` hold the round-1 references, kept for history.

Director tone step (2026-10-20, rr-30): the round-2 rear's new flap pushed the rear identity chroma to 0.2004, over the
0.2 limit. The flap's pixels (those changed from the round-1 rear, below y 560) were desaturated toward their grey by
15%, which is `g + (c - g) * 0.85`. That is the same kind of deterministic tone-down as the Gaoler's tabard. Nothing
else changed.
