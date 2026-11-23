# pla-08 implementation and balance evidence

Card scores are the standard heuristic totals from the pla-04r2 baseline and the pla-08 working tree. Relic and skill scores below are the affected contribution per stated outcome, using the same coefficients. The model does not estimate trigger frequencies or board-wide build synergy for those sources.

## Cards

| Card | Behavior | Face lines or icon rows | Score old → new |
|---|---|---|---:|
| Lantern Shot | Light 2 for 2 turns → lasting Light 2. Starter membership retained. | Ranged 3, Range 3, Light 2 / Draw 1 | 4.41 → 5.56 |
| Guiding Flare | Light 2 for 2 turns → lasting Light 2. Fire retained. | Ranged 3, Range 3 / Fire, Light 2 | 3.56 → 4.70 |
| Dawnstep | Sight +2 for 2 turns → Vision for 2 turns. | Move 3 / Vision, Time 2 | 3.60 → 4.20 |
| Prism Sight | Truesight for 2 turns → Vision for 2 turns. | Vision, Time 2 / Block 4 / Draw 1 | 4.40 → 4.40 |
| Storm Beacon | Light 2 for 2 turns → lasting Light 2 at the first hit. | Ranged 3, Chain 2, Range 3 / Electrified, Light 2 | 2.99 → 4.14 |
| Glowstone Ward | Existing lasting Light 2 now Exposes. Placement precedes Stoneskin 4. | Create {illuminate}Light~#2 and / gain {stoneskin}Stoneskin~#4. | 3.12 → 4.08 |
| Daybreak | Dispel 2 → lasting Light 4 on the hero’s tile. | {exhaust}Exhaust. / Create {illuminate}Light~#4 / where you stand. / {draw}Draw~#2, / {card_play}Card Play~#1. | 5.06 → 4.93 |
| Threaded Path | Light 1 for 2 turns → lasting Light 1 at the actual destination. | {move}Move~#3 / and create {illuminate}Light~#1 / where you arrive. / {draw}Draw~#1. | 3.99 → 4.66 |
| Trapdoor | Sight +2 for 2 turns → Vision for 2 turns. | Blink 4 / Block 5 / Vision, Time 2 | 4.92 → 5.52 |
| Lantern Rain | Light 2 for 2 turns → lasting Light 2 at the impact. | {ranged}#3 {pat:cross} / and create {illuminate}Light~#2. | 3.14 → 4.28 |
| Icebound Chains | Truesight for 2 turns → Vision for 2 turns. Ice behavior unchanged. | Ranged 5, Range 2, Immobilize / Vision, Time 2 | 5.60 → 5.60 |
| Spark Dart | Light 1 for 2 turns → lasting Light 1. Electrified retained. | Ranged 4, Range 3 / Electrified, Light 1 | 3.58 → 4.25 |
| Spark Focus | Sight +1 for 2 turns → Vision for 2 turns. | Leave {surface_electrified}Electrified. / {draw}Draw~#1 / and gain {vision}Vision / for #2~turns. | 3.51 → 4.86 |
| Beacon | Light 2 for 3 turns → lasting Light 2. | Create {illuminate}Light~#2 / and {draw}Draw~#1. | 3.77 → 4.73 |
| Blessed Salve | Light 2 for 2 turns → lasting Light 2. | {exhaust}Exhaust. {heal}Heal~#3 / and create {illuminate}Light~#2 / where you~stand. | 4.25 → 5.40 |
| Break the Veil | Dispel 1 → lasting Light 3 on the hero’s tile. | {exhaust}Exhaust. / Create {illuminate}Light~#3 / where you stand / and {draw}Draw~#1. | 3.03 → 4.14 |
| Censer Swing | Light 2 for 2 turns → lasting Light 2. | {melee}#5 {pat:neighbors}. / Create {illuminate}Light~#2 / where you~stand. | 2.54 → 3.69 |
| Incense Haze | Truesight for 2 turns → Vision for 2 turns. | Vision, Time 2 / Block 3 | 3.75 → 3.75 |
| Seeker's Mark | Truesight for 2 turns → Vision for 2 turns. | Vision, Time 2 / Draw 1 | 4.30 → 4.30 |
| Seer's Candle | Truesight and sight +2 for 2 turns → Vision for 3 turns. | Consume / Vision, Time 3 | 4.50 → 4.05 |
| Sun Flash | Light 2 for 2 turns → lasting Light 2. | Gain {block}Block~#5 / and create {illuminate}Light~#2 / where you~stand. | 3.35 → 4.50 |
| Vigil | Sight +1 for 2 turns → Vision for 2 turns. | Block 5 / Vision, Time 2 | 2.90 → 4.25 |
| Rite of Noon | Light 2 follows the hero and now Exposes. The attack bonus is removed. | {rite}Rite: {illuminate}Light~#2 / follows~you. | 2.19 → 1.80 |
| Flash Powder | Light 3 for 2 turns and instant Expose 2 → lasting Light 3 with turn-start Expose. | {consume}Consume. / Create {illuminate}Light~#3. | 4.04 → 3.79 |
| Seek the Light | Range 5 lit-only Blink → Blink 2 plus lit destinations through Range 5. | {blink}Blink~#2. / On {illuminate}Light: / also target tiles / within {range}Range~#5. | 2.34 → 2.60 |
| Sunpath Stride | Two-turn Light 1 trail → lasting Light 1 trail. | {move}Move~#4, leaving / {illuminate}Light~#1 on each tile / you~enter. | 3.15 → 4.21 |
| Shattered Reflection | Light 2 for 2 turns → lasting Light 2. The v5 target chip retains Range 6. | Create {illuminate}Light~#2. / On one of your / {illusion}illusions: / also {burst}Burst~#6 / the {illusion}illusion~first. | 4.81 → 5.95 |

The remaining cards only lose the public category. Their mechanical faces stay in their existing form. The Light conditions stay on the source card.

| Card | Score old → new |
|---|---:|
| Mirror Charm | 3.66 → 3.66 |
| Blinding Bash | 1.72 → 1.72 |
| Dazzle | 1.99 → 1.99 |
| Hallowed Strike | 1.94 → 1.94 |
| Mirror Image | 3.58 → 3.58 |
| Sunlance | 2.95 → 2.95 |
| Doppelganger | 4.36 → 4.36 |
| Hall of Mirrors | 2.70 → 2.70 |
| Refraction | 3.10 → 3.10 |
| Revealing Glare | 2.57 → 2.57 |
| Searing Light | 2.55 → 2.55 |

Rite of Noon falls to **1.80**, in the weak or niche band. Blinding Bash (1.72), Dazzle (1.99), and Hallowed Strike (1.94) remain in that band. No affected card is above 7 or below 1.

## Relics and skills

An opening or tethered source uses the existing 3-activation model horizon. Multi-tile scores are quoted per placement, before overlapping coverage. Support values are per trigger and have no standalone-card band. The combat-only effects without changed tuning retain their existing per-trigger values.

| Relic or skill | Affected contribution | Score old → new |
|---|---|---:|
| Brightglass Lens | Chain bonus on a lit aimed hit remains | 0.45 → 0.45 |
| Pilgrim Boots | Lasting Light per path tile. The movement grant stays | 0.79 → 1.46 |
| Mirror Shard | Tag removal. Existing explosion scored per adjacent enemy | 1.35 → 1.35 |
| Static Soles | Sight +1 → global reveal for 2 turns. The conductor stays | 0.75 → 2.10 |
| Thawing Charm | Lasting Light on the first conversion. The Stoneskin conversion stays | 0.79 → 1.46 |
| Ember Siphon | Tag removal. Existing spread scored per new Fire tile | 0.42 → 0.42 |
| Phoenix Ember | Dispel 2 → lasting Light 3 on the hero’s tile when Defiance triggers | 3.30 → 2.76 (round 0: 0.00) |
| Cinderbrand Tongs | Lasting Light at the first new Fire card target | 0.79 → 1.46 |
| Stormglass Beacon | Lasting Light per enemy struck by the first Chain attack | 0.79 → 1.46 |
| Captured Noon | Same relief per reached stage. Lasting Lights support more threshold uptime | 1.65 → 1.65 |
| Open-Eyed Pin | One lasting Light per Vision card. Old estimate uses the usual 2-turn trigger | 0.79 → 1.46 |
| Moonless Compass | Same reward per matched pair. Light riders and trails count | 3.90 → 3.90 |
| Dawnbrand Filament | Lasting Light at the first direct attack target | 0.79 → 1.46 |
| Glowstone Matrix | Sight +1 → global reveal for 2 turns per Stoneskin card | 0.75 → 2.10 |
| Beaconrunner Spurs | Same refund per lit entered tile. Available more often with lasting Light | 0.25 → 0.25 |
| True North | Same Range +1 per ranged hit during Vision. Estimate per point of damage at Range 3 | 0.09 → 0.09 |
| Dawnstitch Cord | Same Block for the first Light or Vision card. Light riders and trails count | 1.00 → 1.00 |
| Starless Astrolabe | Lasting Light per qualifying status during Vision | 0.79 → 1.46 |
| Witchglass Lantern | Tethered radius bonus now Exposes. Estimate per active radius-2 aura | 1.39 → 2.35 |
| Sunlit Edge | Same Pierce per lit attack. Available more often with lasting Light | 0.75 → 0.75 |
| Unclouded Sun | Same links. Movement score for saving 1 tile via a link | 0.25 → 0.25 |
| Eclipse Mantle | Tethered Light 2 now Exposes. The 2 Health illusion stays | 1.39 → 2.35 |
| Tallow Candle | Opening Light 2 for 3 turns → lasting Light 2 | 1.39 → 2.35 |
| Long Dawn | Extends Vision by 1 turn. Old value uses a +1 radius Vision, or Truesight, or a timed Light | 0.38 / 1.05 / 0.19 → 1.05 |
| Sunpath | Lasting Light per path tile | 0.79 → 1.46 |
| Witchlight | Tethered Light now Exposes. Estimate per active radius-1 aura | 0.98 → 1.46 |
| Dawnbrand | First-hit Expose 1 remains. Score per successful proc | 0.32 → 0.32 |
| Afterglow | Lasting Light at the removed illusion’s tile | 0.79 → 1.46 |
| Open Sky | In-Light Truesight → in-Light Vision. Estimate per active turn | 1.05 → 1.05 |

Lantern Sight (omen) uses its authored 3 turns. Its reveal contribution is **2.25 → 3.15**.

## Face copy differences from v5

- Spark Focus replaces “3 tiles” in the chip and sentence with the Tile chip and a 3-tile diagram. The sentence reads “Leave Electrified. Draw 1 and gain Vision for 2 turns.”
- Seek the Light uses the required additive condition form. It reads “Blink 2. On Light: also target tiles within Range 5.”
- Shattered Reflection uses the approved v5 Range 6 chip. The ledger commentary suggests Range 4, while the authored v5 row and the pla-04r2 implementation both give 6.

The corresponding Grimoire descriptions preserve the target and area information in plain text.

- **Glowstone Ward** — Create Light 2 at range 3 and gain Stoneskin 4.
- **Lantern Rain** — Deal 3 at range 3 and create Light 2.
- **Spark Focus** — Leave Electrified on 3 tiles at range 3. Draw 1 and gain Vision for 2 turns.
- **Beacon** — Create Light 2 at range 4 and draw 1.
- **Censer Swing** — Strike all adjacent tiles for 5. Create Light 2 where you stand.
- **Flash Powder** — Consume. Create Light 3 at range 3.
- **Shattered Reflection** — Create Light 2 on a tile within range 6. On one of your illusions: also Burst 6 the illusion first.

## Enemy and encounter sources

The Last Lamplighter relights the arena braziers after Last Procession.
Noctyrax can restore braziers through the legacy saved Night Coil path.
The Wick Shade snuffs braziers. Enemies starting a turn within lit brazier
coverage receive Expose 2. Coverage ends on Snuff and returns on relight.

The Rite of Noon aura follows the hero. Illusion auras follow living
illusions and apply the same turn-start Expose rule. Afterglow places a
separate lasting Light source when an illusion is removed.

## Feedback 1 copy changes

Repeated tooltip bodies are listed once. Inline token markup is shown as stored. The HUD row omits the shared heading and Vision line.

| Surface | Round 0 | Feedback 1 |
|---|---|---|
| Light glossary, Grimoire and tooltips | Lasts the battle. Enemies that start their turn in its light are Exposed 2. | Placed Light lasts the battle. Enemies starting a turn in Light are Exposed 2. |
| Target, trail, and landing Light diagrams | @pattern(diamond:{r}) Lasts the battle. Enemies that start their turn in its light are Exposed 2. | @pattern(diamond:{r}) Placed Light lasts the battle. Enemies starting a turn in Light are Exposed 2. |
| Self Light diagram | @pattern(diamond:{r}:hero) Lasts the battle. Enemies that start their turn in its light are Exposed 2. | @pattern(diamond:{r}:hero) Placed Light lasts the battle. Enemies starting a turn in Light are Exposed 2. |
| Vision glossary, Grimoire and tooltips | Shows every hidden enemy while it lasts. | Vision reveals every hidden enemy while active. |
| Afterglow skill and glossary | When an @icon(illusion) is removed, leave @icon(illuminate) 1 on its tile. | When an @icon(illusion) is removed, leave @icon(illuminate) 1 on the illusion's tile. |
| Light Grimoire | Reveals tiles within its radius through the Umbra. | Reveals tiles within the Light radius through the Umbra. |
| Umbra Grimoire | The Umbra hides board tiles beyond your sight. Enemies concealed within it cannot be directly targeted, and their identities, intents, and threat previews remain hidden. | The Umbra hides board tiles beyond your sight. Concealed enemies cannot be directly targeted. The Umbra hides the identities, intents, and threat previews of concealed enemies. |
| Umbra Grimoire, Light radius | Umbra stages grow more severe deeper in the labyrinth. Light reveals tiles within its radius. Vision shows hidden enemies. | Umbra stages grow more severe deeper in the labyrinth. Light reveals tiles within the Light radius. Vision shows hidden enemies. |
| Umbra HUD tooltip | Tiles outside your sight or a Light source are obscured. Hidden enemies cannot be targeted and conceal their intents. | Tiles outside your sight or a Light source are obscured. Hidden enemies cannot be targeted and show no intents. |
| Last Eclipse Grimoire, Acolytes | Noctyrax replaces defeated Acolytes, up to two alive. They hide in Umbra; Light and Vision reveal them. | Noctyrax replaces defeated Acolytes, up to two alive. Acolytes hide in the Umbra. Light and Vision reveal Acolytes. |
| Veilbound Acolyte Grimoire | Light and Vision reveal its position before its ranged needles and closing strikes resolve. | Light and Vision reveal the Acolyte before ranged needles and closing strikes resolve. |
| Static Soles | Your first @kw(move) or @kw(blink) each turn leaves @term(surface_electrified) at its origin and grants @term(vision) for 2 turns. | Your first @kw(move) or @kw(blink) each turn leaves @term(surface_electrified) on the starting tile and grants @term(vision) for 2 turns. |
| Thawing Charm | Excess healing becomes @term(stoneskin), up to 8 each turn. It also creates radius-1 @term(illuminate) on you, once per turn. | Excess healing becomes @term(stoneskin), up to 8 each turn. The first conversion each turn creates radius-1 @term(illuminate) on you. |
| Cinderbrand Tongs | Your first card each turn to create new @icon(surface_fire) also creates @icon(illuminate) 1 at its target. | Your first card each turn to create new @icon(surface_fire) also creates @icon(illuminate) 1 at the card's target. |
| Stormglass Beacon | The first @icon(chain) attack each turn creates @icon(illuminate) {radius} beneath every enemy it hits. | The first @icon(chain) attack each turn creates @icon(illuminate) {radius} beneath each enemy hit. |
| Dawnbrand Filament | The first direct attack each turn creates @icon(illuminate) {radius} at its target. | The first direct attack each turn creates @icon(illuminate) {radius} at the attack's target. |
| Phoenix Ember, reward ruling | Gain 1 @term(defiance). When @kw(defiance) saves you, place @term(surface_fire) under every enemy, @kw(draw) 3 and gain 3 @term(card_play\|Card Plays). | Gain 1 @term(defiance). When @kw(defiance) saves you, create @term(illuminate) 3 on your tile, place @term(surface_fire) under every enemy, @kw(draw) 3 and gain 3 @term(card_play\|Card Plays). |
