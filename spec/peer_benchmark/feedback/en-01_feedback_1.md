# en-01 feedback 1 (director)

Mechanics look right in the native captures (erupt displaces/damages the hero, chain bursts propagate). Fix the
following, then re-run everything. Proof copies of your captures: `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/proof/en-01/`.

## Ownership
1. **Apply your shared integration patch** (`spec/enemies/en01_shared_integration.patch`) — you now own those files
   (action_icon_library, enemy_intent_compass, enemy_strike_points, icon identity policy spec/test,
   contextual_cutout_suite, test_board_pixel_density) for EN01-specific additions only. Keep the generic static melee
   fallback for strike points (drop the `TODO_DESIGN_MELEE_STRIKE` fields; static enemies use the generic fallback).

## Icons (approved; your launch prompt was missing this section — my mistake)
2. Approved raw icon paintings (flat green background, outside git):
   `/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art/icons/{burrow,erupt,burst}.png`.
   Process them exactly like the existing 64×64 icons in `assets/art/icons/` (key green, trim, same padding as
   `cinder_marks.png` / `blink.png`), register them in `ActionIconLibrary` and the icon identity registry, and replace
   the temporary aliases. One icon per concept: Burrow intent + Burrowed status = `burrow`; Erupt mark = `erupt`;
   Bursts badge + Kindle intent + Kindled = `burst`. Run `python3 tests/test_icon_identity_policy.py`.

## Decisions (replace the TODO_DESIGN fields)
3. **Burrowed state must hide the body.** Capture 01 shows the grub's full body at its old tile with the eruption mark
   — after Burrow resolves the body must not be drawn; only the mound + health bar + intent remain. Add a capture
   `01b_grub_burrowed.png` after Burrow resolves (mound visible, body hidden, mark on the hero tile).
4. **Mound**: base ellipse `#4a3520`, 1 px rim highlight `#7a5a34` on the upper-left arc, 7 specks (4 × `#2e2116`,
   3 × `#b98b45`, 2–3 px each, deterministic per unit id), 60% of tile width × 32% of tile height, breathing scale
   ±3% over 1.5 s (reduced motion: static).
5. **Dust burst** on Erupt: 0.35 s radial puff of 10 particles `#b98b45` fading from 70% alpha to 0, travelling out to
   0.6 tile widths, plus the existing Rubble surface creation visual.
6. **Erupt with no free adjacent tile** for the unit on the mark: the grub surfaces on the nearest free tile to the mark
   instead; the unit on the mark still takes the 6 damage and is not moved; adjacent pushes are computed from the
   grub's actual surfacing tile.
7. **Kindle glow**: additive ellipse under the sprite centred on the abdomen, 70% of tile width × 40% of tile height,
   `#ff8a3a`, alpha 35% at +2 / 55% at +4, pulsing ±10% alpha over 1.2 s (reduced motion: steady).
8. **Bursts badge**: icon + number only, in the existing status badge row like other statuses — no "Bursts" word on
   the board. Tooltip: "Bursts: when this dies, it deals <N> damage to everything next to it."
9. **Burst ring**: keep your dashed ring: 2 px `#e8722c` at 85%, dash 8 px, gap 6 px.
10. **Chain timing**: each subsequent burst in a chain starts 0.18 s after the previous one starts.
11. **Size**: burrow grub silhouette height = 75% of the hero's standing height (it currently reads as tall as the
    hero); ember tick height = 45% of the hero's height. Feet/base on the tile anchor as now.
12. **Portraits**: centre the 128×128 crop on the head (grub: the mouth ring; tick: the front head shell) with the head
    filling ~70% of the portrait width; same background treatment as existing portraits.

## Encounters
13. enc-01 is landing in parallel; leave `data/encounters.json` alone — the director adds your `biome_groups` entries.

## Proof
- Focused suite, icon audit, density checks and the full suite all green.
- Probe captures regenerated incl. `01b_grub_burrowed.png`; list the windowed command again.
