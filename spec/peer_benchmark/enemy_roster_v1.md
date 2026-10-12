# Section enemy roster v1 (director design, 2026-10-12)

Owner direction (2026-10-12): sections have distinct biomes, so each needs its own enemies with mechanics that make
it *play* differently, not just look different. Today every section draws from the same neutral regulars; lightning
and shadow have no element regular.

Design rules (from the StS/ITB research):
- Each section has a one-line tactical theme. Its two signature regulars both express it; together with the biome
  they make the section's fights feel different within one turn.
- Every new enemy has exactly one headline rule a player can state after one encounter, and it is telegraphed on the
  board before it resolves (ITB honesty: the player always sees what will be hit).
- Every headline rule has a positional counterplay that uses the hero's existing verbs (move, push/pull, kill order,
  block, Shock/Freeze), and most can be turned against the enemies (friendly fire is how ITB makes puzzles).
- Numbers sit in the enemy skill's bands (light 6–10 HP / init 7–10; standard 10–16 / 9–13; heavy 18–26 / 13–17).
- No stun. Stun was removed.

Section fights after this wave: ~60% of compositions include at least one section signature enemy; neutrals stay as
the connective tissue; the room-element regular still appears (it drives rewards). Section tables live in
`data/encounters.json` (enc-01).

## I · Worldspine Roots (earth) — "the ground moves"

### Burrow Grub `burrow_grub` — standard, 12 HP, initiative 10, 10 Embers
Silhouette: a pale segmented grub the size of a hound, ringed with ochre chitin plates, a round lamprey mouth of
stone teeth; dirt clinging to its underside. Accent: ochre.
- **Burrow** (time 5, weight 3): sinks into the floor (Burrowed: cannot be targeted except by area effects and
  surfaces; its tile shows a churned mound) and marks the **hero's current tile** as its eruption tile (cracked-earth
  ring, DANGER).
- **Erupt** (time 5, only while Burrowed; always its next intent): surfaces at the marked tile: 6 damage to whatever
  unit stands there (hero or enemy), pushes each adjacent unit 1 tile outward, leaves Rubble on the tile, and the grub
  gains Expose 2. If the tile is blocked by terrain, it surfaces on the nearest free tile and only pushes.
- **Gnaw** (time 4, weight 2): move toward + melee 3.
Counterplay: step off the mark; push an enemy onto it; punish the exposed grub.

### Briar Weaver `briar_weaver` — controller, 14 HP, initiative 12, 11 Embers
Silhouette: a stooped, bark-skinned figure woven from roots, long finger-thorns, a hood of dead leaves, an amber eye
glow. Accent: moss green.
- **Thornwall** (time 6, weight 3): grows Bramble on a telegraphed line of 3 tiles adjacent to the hero (the line
  perpendicular to the weaver→hero direction, centred on the tile in front of the hero). Bramble: impassable terrain
  for 3 rounds; a unit pushed into Bramble takes 2 damage and Bleed 1 (enemies too).
- **Lash of Thorns** (time 5, weight 2): ranged 3 + Bleed 1, range 3.
- **Root Mend** (time 5, weight 1): heal the most wounded ally within 3 for 4.
Counterplay: walk around before it closes; use the Bramble as a weapon (push enemies into it).

## II · Cinder Crown (fire) — "everything burns and blows up"

### Ember Tick `ember_tick` — light, 6 HP, initiative 8, 6 Embers (appears in pairs or threes)
Silhouette: a small obsidian-shelled tick whose swollen abdomen glows molten through cracks. Accent: molten orange.
- **Scuttle** (time 4, weight 3): move toward 3 + melee 2.
- **Kindle** (time 4, weight 1): its Burst damage +2 until it dies (abdomen glows brighter).
- **Burst** (passive, on death, always shown as a badge and a dashed ring on hover): 4 damage to every adjacent unit
  (hero and enemies) and Fire surface on its own tile.
Counterplay: kill it at range, or push it beside its friends and pop it — chain reactions.

### Slag Mortar `slag_mortar` — heavy artillery, 18 HP, initiative 14, 13 Embers
Silhouette: a squat brute carrying a soot-black clay kiln on its back like a mortar barrel, molten slag in the bowl,
thick leather apron. Accent: molten orange.
- **Lob Slag** (time 6, weight 3): marks a plus-shaped target centred on the hero's tile (range 3–6, ignores line of
  sight; glowing ember marks). On its next activation the slag lands: 5 damage centre, 3 on the four arms, Fire surface
  on all five tiles. (Reuse the cinder-mark/detonate mechanic.)
- **Brace** (time 5, weight 1): Block 6 and move away 2.
- **Scatter Shot** (time 5, weight 2, only when the hero is within 2): ranged 3, push 1.
Counterplay: leave the cross; push enemies into it; dive the mortar.

## III · Rime Hall (ice) — "control and patience"

### Hoarfrost Seer `hoarfrost_seer` — controller, 12 HP, initiative 12, 11 Embers
Silhouette: a gaunt blind seer in frost-stiff robes, icicles hanging from the hood's rim, a staff topped with a
hanging ice shard. Accent: pale ice blue.
- **Icefall** (time 6, weight 3): marks the hero's tile and the two tiles beside it along the axis perpendicular to
  the seer→hero direction (falling-icicle shadows). On its next activation icicles fall: 5 damage on each marked tile,
  and each leaves an **Ice Pillar** (impassable for 3 rounds; a unit pushed into a pillar shatters it and takes 2).
- **Rime Bolt** (time 4, weight 2): ranged 3 + Chilled, range 4.
- **Withdraw** (time 4, weight 1): move away 2 + Block 4.
Counterplay: step out of the line; the pillars it leaves block enemies too.

### Glacial Mirror `glacial_mirror` — heavy protector, 20 HP, initiative 15, 13 Embers
Silhouette: a hulking crystal construct, a cracked mirror-flat ice slab for a chest, frost-rimed stone limbs.
Accent: pale ice blue.
- **Reflect** (passive, badge): single-target ranged attacks and projectiles aimed at it are reflected back at the
  attacker for full damage. Melee, area and surface damage hit it normally.
- **Refraction** (time 6, weight 3): a piercing beam in a straight line toward the hero, range 4: 4 damage + Chilled
  to every unit on the line.
- **Crystal Guard** (time 5, weight 2): grant Block 6 to the adjacent ally with the least Block (itself if none).
Counterplay: walk up and hit it; never shoot it.

## IV · Hollow Gale (air) — "you don't control where you stand"

### Gale Herald `gale_herald` — controller, 14 HP, initiative 13, 11 Embers
Silhouette: a tall masked herald in ragged grey-blue banners that stream sideways, a long brass horn. Accent:
storm grey-blue.
- **Call the Wind** (time 6, weight 3): sets a wind direction for 2 rounds (shown as drifting arrows across the
  board). The direction pushes the hero toward the nearest hazard, enemy or wall if one is within 3 tiles in that
  direction (tie: toward the herald). At the end of each enemy turn while the wind blows, every non-anchored unit
  (hero and enemies; not bosses, constructs or rooted units) is pushed 1 tile with the wind, in order of distance
  downwind first. Collisions deal normal push damage. Killing the herald stops the wind.
- **Gust Bolt** (time 4, weight 2): ranged 3 + push 1.
- **Still Air** (time 5, weight 1): Block 5.
Counterplay: plan your end position one tile upwind; let the wind throw enemies into walls and each other.

### Gust Shrike `gust_shrike` — light skirmisher, 9 HP, initiative 9, 8 Embers, flying
Silhouette: a lean storm-grey raptor with tattered wing membranes and a hooked iron-grey beak. Accent: storm
grey-blue.
- **Dive** (time 5, weight 3): marks a straight line of up to 4 tiles ending at the hero; flies along it, pushing
  every unit it passes 1 tile sideways (away from the line), and strikes the hero for 4; ends adjacent.
- **Talon Rake** (time 4, weight 2): melee 3 + Bleed 1.
- **Hover** (time 4, weight 1): move away 2 + Block 3.
- **Flying** (passive): ignores surfaces, traps, Bramble and Ice Pillars while moving.
Counterplay: stand where the dive line crosses its allies; block the line.

## V · Tempest Spire (lightning) — "spacing matters"

### Arc Thrall `arc_thrall` — standard, 10 HP, initiative 11, 9 Embers (always spawned in pairs)
Silhouette: a hunched thrall in a corroded copper collar and harness, a crackling iron rod fused to one arm.
Accent: electric violet.
- **Tether** (time 5, weight 3): if another thrall shares a row or column with a clear line within 6 tiles, a beam
  between them is telegraphed; when it resolves, every tile between them takes 4 + Shock (any unit). If no partner is
  aligned, it moves to the nearest tile that aligns with its partner with the hero between them, then telegraphs.
- **Arc Jab** (time 4, weight 2): melee 3 + Shock.
Counterplay: push one thrall out of line; push enemies into the beam.

### Storm Capacitor `storm_capacitor` — heavy construct, 22 HP, initiative 16, 13 Embers, immobile
Silhouette: a hulking iron-and-glass coil column on a stone base, violet lightning trapped inside, chained to the
floor. Accent: electric violet.
- **Charge** (time 4): +1 Charge (shown as three pips; Charge carries over).
- **Discharge** (time 5, chosen when Charge is 3): chain lightning: 6 damage to the nearest unit within 4 (hero or
  enemy), then jumps to a unit adjacent to the last one struck, up to 3 jumps, −1 damage per jump; Charge resets.
- **Grounded** (passive): whenever it becomes Shocked, it loses 1 Charge.
Counterplay: kill it before 3 pips, Shock it, or keep units apart when it fires.

## VI · Noctyrax's domain (shadow) — "what you can't see"

### Gloam Stalker `gloam_stalker` — skirmisher, 11 HP, initiative 10, 10 Embers
Silhouette: a thin, long-limbed shade wrapped in torn black veils, a pale masklike face, two long bone blades.
Accent: umbra violet.
- **Fade** (time 5, weight 3): becomes Veiled (only adjacent attacks and area effects can hit it; drawn as a faint
  silhouette) and blinks to the free tile behind the hero (opposite the hero's last move direction; else the farthest
  free tile adjacent to the hero) within 4.
- **Ambush** (time 5; its next intent after Fade, while Veiled and adjacent): melee 7; Veil ends.
- **Slash** (time 4, weight 2): melee 4.
Counterplay: its strike tile is always shown — step away or put your back to a wall; area effects find it.

### Hollow Mimic `hollow_mimic` — standard, 14 HP, initiative 12, 11 Embers
Silhouette: a faceless figure of black glass in a hero-like stance, a cracked mirror where the face should be.
Accent: umbra violet.
- **Mirror** (time 6, weight 3): copies the last attack card the hero played this round: its next intent uses that
  card's base damage and shape aimed at the hero, named "Mirror: <card>". With no attack played this round, it uses
  Shade Bolt instead.
- **Shade Bolt** (time 4, weight 2): ranged 4, range 4.
- **Recede** (time 4, weight 1): move away 2 + Block 4.
Counterplay: kill it first, or feed it a small card before your big one.

## Waves
- **E1** (one per section, clearest rules): burrow_grub, ember_tick, hoarfrost_seer, gale_herald, arc_thrall,
  gloam_stalker.
- **E2**: briar_weaver, slag_mortar, glacial_mirror, gust_shrike, storm_capacitor, hollow_mimic.
Per enemy: concept painting (image run, director-approved) → cutout case (rig, idle/walk/attack/hit/collapse) →
mechanics + data + previews + portrait + encounter tables + tests → windowed proof and an inspection fixture.
