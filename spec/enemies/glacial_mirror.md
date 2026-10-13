# Glacial Mirror — en-05

Director source: `spec/peer_benchmark/enemy_roster_v1.md` and protected
`spec/peer_benchmark/staged/enemies/wave_e2.json`. The production entry is
identical to that authored object; this unit performs no tuning.

Heavy Rime Hall protector: 20 HP, initiative 15, 13 Embers; authored weighted
activation cadence 20.5 before spawn stagger and legality filtering. Closest
comparisons are Warden's heavy support role and Frostglass Lancer's ice line.
It is a construct, so the existing wind classification anchors it.

1. Reflect is a permanent badge. Non-adjacent, single-target ranged attacks
   return the damage before the Mirror's Block through the attacker's ordinary
   defense. Adjacent/melee, area, surfaces, Chain and forced damage do not reflect.
   Target-dependent card modifiers are resolved before reflection. The preview
   uses the real simulated result and places its number/return marker on the hero,
   with the exact line `Reflected: you take this damage.` The Mirror tooltip is
   `Reflect: ranged attacks against it bounce back to the attacker. Hit it up close or with area effects.`
   The projectile follows the existing arc, flashes white for 0.08 seconds and
   returns along that curve at 1.5 times its outbound speed.
2. Refraction selects the existing cardinal direction toward the hero and hits
   each passable tile in its four-tile line. Damage is 4 ice with the authored
   Pierce flag; both teams receive persistent Chilled. Forecast and resolution
   share the same geometry. The beam is #9cc8e6, 6-pixel core, 14-pixel glow at
   30% opacity for 0.3 seconds. Friendly-fire death rewards remain the existing
   rules, without a player-card bonus.
3. Crystal Guard grants Block 6 to the adjacent living ally with least Block;
   self is the fallback only without adjacent allies. Existing id order breaks
   an equal-Block tie. Grind Forward retains Move 2.

Mechanics: `scripts/enemy_mechanics/reflect.gd`; presentation:
`reflect_view.gd`. Static art: `assets/art/enemies/glacial_mirror.png`,
255 square, 248-pixel silhouette (115% of the 216-pixel hero after integer
rounding), baseline y=251 matching Chainbound Gaoler. Portrait:
`assets/art/portraits/glacial_mirror.png`, native 128 square, top padding 8,
centred on the head crevice and upper ice chest. Reflect icon:
`assets/art/icons/reflect.png`; Refraction retains AoE/Pierce identities.
There is no idle sheet or cutout. Art scale/offsets retain existing defaults;
no artwork, fonts or audio were generated or downloaded.

The director owns the post-merge `ice_mirror` encounter group. `biome_groups`
is already present, but this unit intentionally does not modify the pools.
No new analytics event is required; the ordinary enemy action and damage/death
instrumentation is retained. Comparison assumptions are recorded together in
`spec/card_balance_heuristic.md` and `tools/card_heuristic.py`.

Proof belongs to `tests/en05_enemies_test.gd`,
`tests/en05_live_integration_test.gd`, `tests/test_en05_assets.py`,
`tests/en05_enemies_probe.gd` and its eleven-image contract. Headless checks prove
logic only. The design owner must run and inspect the windowed captures at
1920x1080, 100% scale before accepting presentation.
