# Glacial Mirror — en-05

Director source: `spec/peer_benchmark/enemy_roster_v1.md` and protected
`spec/peer_benchmark/staged/enemies/wave_e2.json`. The production entry is
identical to that authored object; this unit performs no tuning.

Heavy Rime Hall protector: 20 HP, initiative 15, 13 Embers; authored weighted
activation cadence 20.5 before spawn stagger and legality filtering. Closest
comparisons are Warden's heavy support role and Frostglass Lancer's ice line.
It is a construct, so the existing wind classification anchors it.

1. Reflect is a permanent badge. pla-01 (director, 2026-11-20) made the rule
   match the owner's sentence, which is the tooltip and the whole Grimoire page:
   `Attacks from a non-adjacent tile bounce back to the attacker.` Every hit the
   Mirror would take from a board attack (aimed, area, Chain link, conducted,
   Push/Pull, melee reach) bounces when the attacker's origin tile is more than
   1 tile away; adjacent hits land. A bounced hit returns its damage before the
   Mirror's Block through the attacker's ordinary defense, once, and lands no
   damage, rider or movement on the Mirror, including movement shared by a
   group. Use the illusion's tile and halved damage for an echo, and the extra
   beam's own origin for player Refraction. The attack's other hits land. Chain
   continues past the bounced hit, and lightning can pass through a Mirror's
   conductive tile without hitting it.
   An attack is a hit the game shows with the melee (sword) or ranged (arrow)
   damage icon (director, pla-01 round 2); those all resolve through the board
   attack resolver, including derived attacks such as Shattered Reflection.
   Pure status and movement, selector strikes (Searing Light, Stoke, White
   Silence), Bursts, Meteorfall marks, battlefield rules, ground, traps,
   Collision and Retaliate land. Flashsteam's direct attack reflects from
   a non-adjacent tile and the follow-up Burst still hits the Mirror.
   Target-dependent card modifiers are resolved before reflection. Each bounce
   records a `reflect_bounced` surface event. The preview prefixes the hero's
   existing loss label with `↶ ` when a visible Mirror returns the hit to the
   hero, including Block or Defiance loss. The tooltip reads `Reflected: you
   take this damage.` A bounced Push/Pull omits the travel preview. A lone shot's
   projectile follows the existing arc, flashes white for 0.08 seconds and
   returns along that curve at 1.5 times its outbound speed; area, Chain and
   melee strikes keep their own animation.
2. Refraction selects the existing cardinal direction toward the hero and hits
   each passable tile in its four-tile line for 4 damage and Staggers targets on
   Ice by 6. When another Mirror reflects the beam, the damage and riders
   return to the caster. Forecast and resolution
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

Director feedback 2 keeps Refraction's existing `aoe` identity in the v2 feet
chip, alongside the health-frame order disc and area zone tag. Refraction,
Crystal Guard and Grind Forward intent/chip numbers share en-06's integer
formatting; the regression also covers Talon Rake, Hover, Dive and passives.
`tests/en05_enemies_probe.gd` now writes its eleven captures in the isolated
`user://probes/en05-enemies/<timestamp>/` namespace. No art changed in this
integration; art-02 remains the owner of re-art.
