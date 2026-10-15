# anim-01 — Idle life for static directional enemies (pixel-true, data-driven)

## Header
- Owner, playtest 7 (2026-10-15), about an Earth enemy: "it didn't look like he had an idle animation ... if he was
  moving, it was so subtle that I couldn't even really tell." The 12 art-02/art-04 enemies are static directional
  paintings (front/rear + mirrors, `scripts/static_enemy_facing.gd`) with no idle motion. Cutout rigs come later via the
  maquette pipeline (rr-02); this unit gives every static enemy a flavour-matched idle now.
- Base: `codex/peer-benchmark`. Owned files: new `data/static_enemy_idle.json` (director data below — copy it exactly),
  new `scripts/static_enemy_idle.gd` (+ a canvas shader if used, e.g. `shaders/static_enemy_idle.gdshader`), the static
  enemy draw path in `scripts/combat_board_view.gd` (plumbing only), `scripts/static_enemy_facing.gd` only if needed,
  new `tests/static_enemy_idle_*` and a frame-strip probe `tests/static_enemy_idle_probe.gd` + contract.
- Rules: presentation only (no gameplay/timing/analytics changes); Windows typed-array rule; deterministic given a
  seed and a time value (no wall clock in tests).

## Technique (director decisions)
- **Pixel-true deformation only.** Every displacement is a whole number of the sprite's own art pixels (one art pixel =
  one texel of the 255-px sprite as drawn, so it scales with `art_scale` and the board). No smooth scaling, rotation or
  sub-pixel offsets of the painting — they shimmer and blur pixel art.
- **breathe**: rows above the pivot line (pivot = fraction of drawn height from the sprite's bottom edge) shift up by
  `round(amp_px × w(y) × s(t))`, `w` rising linearly from 0 at the pivot to 1 at the top, `s(t) = (1 − cos(2πt/period))/2`.
  Rows below the pivot (feet) never move. Gaps opened by the shift are filled by repeating the row above (stretch), never
  transparent.
- **sway**: rows above the pivot shift horizontally by `round(amp_px × w(y) × sin(2πt/period + φ))`.
- **bob** (flyers): the whole sprite moves vertically by `round(amp_px × sin(2πt/period))`; its ground shadow keeps its
  place and shrinks to 94% width at the top of the bob.
- **glow**: accent pixels (chroma above the sprite's own 90th percentile + 15 in RGB max−min, the gate's accent rule)
  get brightness × `1 + amp × n(t)` with `n` a smooth value noise at `rate_hz` (deterministic per unit); hue unchanged.
- Each unit gets a phase offset from its id so a group never moves in sync. Mirrored facings mirror the motion.
- Idle runs only while the unit is idle: moves, attacks, hurt and death presentation take over and the idle resumes
  from rest. **Reduced motion** (existing setting): no breathe/sway/bob; glow amplitude halved.
- Logical rects, health bars, intents and tooltips never move with the idle.

## Director data — `data/static_enemy_idle.json`
```json
{
 "doc": "Idle profiles for static directional enemies (anim-01). amp_px are whole art pixels; period in seconds; pivot = fraction of drawn height from the bottom.",
 "default": {"breathe": {"amp_px": 1, "period": 3.2, "pivot": 0.3}},
 "enemies": {
  "burrow_grub":     {"breathe": {"amp_px": 2, "period": 2.6, "pivot": 0.15}},
  "ember_tick":      {"breathe": {"amp_px": 1, "period": 0.9, "pivot": 0.2}, "glow": {"amp": 0.2, "rate_hz": 6.0}},
  "briar_weaver":    {"sway": {"amp_px": 2, "period": 3.4, "pivot": 0.3}, "breathe": {"amp_px": 1, "period": 3.4, "pivot": 0.3}},
  "slag_mortar":     {"breathe": {"amp_px": 2, "period": 3.0, "pivot": 0.35}, "glow": {"amp": 0.15, "rate_hz": 0.7}},
  "hoarfrost_seer":  {"sway": {"amp_px": 1, "period": 4.0, "pivot": 0.35}, "breathe": {"amp_px": 1, "period": 4.0, "pivot": 0.35}},
  "glacial_mirror":  {"breathe": {"amp_px": 1, "period": 3.6, "pivot": 0.3}, "glow": {"amp": 0.12, "rate_hz": 0.4}},
  "gale_herald":     {"sway": {"amp_px": 2, "period": 2.4, "pivot": 0.4}, "breathe": {"amp_px": 1, "period": 2.4, "pivot": 0.35}},
  "arc_thrall":      {"breathe": {"amp_px": 1, "period": 2.0, "pivot": 0.3}, "glow": {"amp": 0.25, "rate_hz": 8.0}},
  "storm_capacitor": {"glow": {"amp": 0.3, "rate_hz": 10.0}},
  "gloam_stalker":   {"breathe": {"amp_px": 1, "period": 2.2, "pivot": 0.3}, "sway": {"amp_px": 1, "period": 2.2, "pivot": 0.4}},
  "hollow_mimic":    {"breathe": {"amp_px": 1, "period": 3.8, "pivot": 0.3}},
  "gust_shrike":     {"bob": {"amp_px": 3, "period": 1.1}, "breathe": {"amp_px": 1, "period": 1.1, "pivot": 0.3}}
 }
}
```
Any other enemy using static directional art falls back to `default`; objects with no rear (storm_capacitor) use only
the profile given. The director tunes these numbers by editing the data file; no code changes for tuning.

## Proof
- Tests: integer-only displacement (no fractional offsets in any sampled frame), feet rows unchanged by breathe/sway,
  phase decorrelation between two units of the same type, reduced-motion behaviour, idle suspended during an action,
  data validation (unknown keys/enemies fail), full suite.
- Windowed (list the command; the director runs it): `tests/static_enemy_idle_probe.gd` writing, for each of the 12
  enemies, an 8-frame strip over one period at 2× nearest (front facing, board background) plus one strip for a mirrored
  rear and one for reduced motion, and a contact sheet of all strips.

## Out of scope
Cutout rigs, attack/move animation changes, new art.
