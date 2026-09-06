# Relic Trigger Feasibility

Current rules and initial tuning: 2026-09-06 board-surface refactor. This replaces
the July 2026 intensity/Burn trigger table; those former estimates are historical,
not current balance assumptions. Use the full 60-ID supporting content audit and
[accepted surface rules](board_surface_refactor/DESIGN.md) for the complete pass.

## Live constraints and support

The player starts at 24 health with a five-card hand, two draws and two card
plays per turn; the hand cap is seven. Normal encounter targets are 3–5 enemies
and 3–5 player turns, with longer boss fights. These are tuning targets, not
measured guarantees for every seed. Fatigue begins at two damage and increases
on reshuffle. Relic draws stop before reshuffle. Only active player-action kills
of non-summoned enemies grant the ordinary extra play; passive start deaths do
not bank plays.

The current data contains 159 stable card IDs (158 playable plus retired Bone
Dart), 60 relics, 42 equipment pieces granting 88 distinct cards, and 29 active
abilities plus retired Layaway. Counts below include nested conditional rewards
and count cards, not actions; categories overlap.

| Support | Cards | Feasibility consequence |
| --- | ---: | --- |
| Fire placement | 11 | Widespread local setup for Detonate and conductive Fire |
| Ice placement | 8 | Requires contact before an Ice hit can Freeze |
| Electrified placement | 9 | Lines and areas support real cardinal networks |
| Rubble placement | 9 | Enables control, defense conversions, and remote origins |
| Detonate | 6 | A specialized payoff; needs fuel in its selected footprint |
| Printed Chain | 8 | Repeated hops are spatially constrained, not target-count capped |
| Damaging Ice hits | 12 | Can exploit active Chill; placement alone cannot skip setup |
| Shock riders or conditional bonuses | 4 | Retained specialized control rather than generic status saturation |
| Block | 46 | Broad defense-to-attack support |
| Stoneskin | 13 | Includes conditional rewards; costs remain meaningful |
| Move or Blink | 35 | Actual path/endpoint determines movement triggers |
| Push or Pull | 15 | Transports enemies through shared hazards |
| Draw / card-play actions | 33 / 7 | Common free-play refunds were deliberately reduced |
| Explicit Radiance identity | 15 | Light is independent of both terrain layers |

Prismatic Instinct adds one chosen tile once per combat. Confluence relocates one
existing layer once per combat. Neither supplies free repeated fuel, immediate
Chill, or ownership immunity. Enemy and trap terrain can be used by either side.

## Transformations

| Relic / stable ID | Enabling line | Cost, boundary, and strongest relevant interaction |
| --- | --- | --- |
| Stormcoal Crucible / `coalheart_crucible` | Connect Fire and Electrified into a Lightning route. | All Fire in the encounter is conductive for both sides. Electrical use consumes the Fire itself; no automatic Detonate. Ordinary conduction still needs cardinal continuity. |
| Updraft Bottle / `updraft_bottle` | Push or Pull an enemy off an elemental tile and choose to carry it. | Move existing ground only after displacement and landing hazards resolve; leave Rubble. Landing replacement is placement, so carried Ice does not immediately Chill. Blocked movement carries nothing. |
| Quarry Winch / `briar_winch` | Displace an enemy standing on Rubble. | Spend the supporting Rubble to choose another legal cardinal force direction. It does not add movement distance or bypass actor/wall collisions. |
| Faultline Brooch / `thornmail_brooch` | Hold four Stoneskin, then choose a non-Chain melee attack. | Spend four real Stoneskin to attack a cross and leave Rubble. This trades defense for reach and coverage; cancellation or invalid targeting spends nothing. |
| Shatterglass Prism / `frost_prism` | Paint Ice, establish Chill, Freeze with an Ice hit, then kill directly. | A direct player attack killing a Frozen enemy leaves footprint-plus-cardinal Rubble. Passive Fire or trap kills do not qualify. Large actors paint geometry once rather than multiplying damage. |
| Rimecatcher Vial / `rimecatcher_vial` | Freeze an Ice-supported enemy while choosing a spill direction. | One of the consumed Ice tiles becomes one legal adjacent tile. It does not preserve the enabling Ice, trigger immediate contact, or duplicate its entire footprint. |
| Worldroot Idol / `worldroot_idol` | Stand on a cardinal Rubble path and select a visible connected origin. | One melee/ranged attack measures from and consumes that remote origin; the player does not move. The route breaks as fuel is spent. Ordinary visibility and target legality still apply. |
| Basalt Kiln / `basalt_calendar` | Choose Rubble fuel for an existing Detonate action. | Consume selected Rubble, resolve the same shared blast union, then paint Fire on spent tiles. The new Fire has no placement damage and can be used by either side later. |
| Thunder Relay / `thunder_relay` | Chain through at least two enemies; choose endpoint exchange. | Exchange first and last native Chain targets only if both survive and both complete footprints fit. Resolve landing hazards. Conduction-only victims do not become endpoints. |

These effects do not all produce stats or draws. Each changes the set of legal
or useful tactical decisions. Shared danger and finite local fuel are deliberate
costs, including the Fire left by Basalt Kiln and routes available to enemy
Lightning under Stormcoal.

## Resource and state bridges

| Relic | Current trigger / payoff | Repeat and scaling check |
| --- | --- | --- |
| Cinderbrand Tongs | The first actually new Fire created by your card each turn adds radius-1 Light for two turns at the primary tile. | Once per turn; idempotent repaint cannot farm Light. No Fire strength or global discharge. |
| Ion Spool | A Lightning attack consumes at least two conductive tiles to draw one. | Once per turn, counts used Electrified and hybrid Fire, not repaint or unconsumed network size. |
| Static Soles | First actual Move/Blink leaves Electrified at its origin and grants Vision one for two turns. | Once per turn; a failed move does not spend the trigger. The tile is usable immediately. |
| Cold Mirror | First actual Freeze while holding Block converts up to six Block to Stoneskin. | Once per turn; requires activated Chill and a later Ice hit. Freeze immunity cannot trigger it and it creates no defense from nothing. |
| Ember Siphon | Your Fire or Detonate kills an enemy: heal three and place local Light. | Once per combat. Keep causal ownership separate from card-play credit, including enemy-start Fire kills. |
| Overflow Censer | Three ground types coexist on visible tiles: six Stoneskin and draw two. | Once per combat, not a recurring tile-count scaler. Rubble is one type; Light is not a fifth terrain type. |
| Black Sun Dial | Consume elemental ground over Rubble: a local shared cross pulse of six, then six Stoneskin. | Once per combat. Each actor takes the secondary pulse once; it cannot recursively claim another consumption reward or masquerade as a direct attack. |
| Storm Crown | One native Chain attack hits three different enemies: draw two and gain one play. | Once per turn. Ordinary conduction victims and a reused enemy ID do not satisfy native route count. |
| Funeral Bell | Player actions kill a third statused enemy: draw three and gain two plays. | Once per combat. In three-enemy rooms it may occur at victory; passive start deaths and summons cannot build an unlimited engine. |
| Phoenix Ember | Adds one run Defiance charge. Trigger dispels two Umbra, paints Fire beneath enemies, draws three, and grants three plays. | Finite run survival resource. Placement does not instantly harm or Chill occupants; shared Fire makes the rescue board dangerous later. |
| Vaulting Sigil | Actual Move/Blink of four or more tiles: one play and four Block. | Once per turn; Rubble taxes path budget, so printed range alone does not prove trigger reach. |
| Gale Tabi | Actual Blink of at least three tiles: draw one and gain one play. | Once per turn; safe draw cannot force Fatigue. Landing hazards still resolve. |
| Moonless Compass | Separate movement and Radiance cards in one turn: six Stoneskin and two plays. | Once per combat; one card containing both packages does not satisfy both halves. |
| Chorus Mask | Play a different element after an elemental card: one play and three Block. | Once per turn. The extra play can continue a turn but does not repeat the refund. |
| Bloodglass Knife | At half health or lower with no Block/Stoneskin, attacks gain seven damage. | Deliberate exceptional direct-hit ceiling with immediate survivability cost; passive hazards do not inherit it. |
| Bloodmoon Chalice | Finish a health-cost card at half health or lower: heal five, draw two, gain one play. | Once per combat; fixed sustain ceiling. |
| Thawing Charm | Excess healing becomes up to eight Stoneskin per turn; first conversion places local Light. | Supplies no healing itself; retains the scarce healing cost. |
| Coffin Nails / Mossbound Wraps | Block enables attack Bleed / first Earth-card Stoneskin three. | Separate defense and attack cards can assemble the condition. No Poison or damaging Burn path remains. |
| Tailwind Fletching / Anchor Chain | Air or held-Block force modifiers improve damage and distance. | Existing paid Push/Pull, local collision constraints, shared path hazards; do not skip force geometry. |
| Storm Capacitor | Existing Lightning ranged Chain gains one hop reach. | No new target-budget semantics and no added damage per hop. |
| Fivefold Knot | Play all five elements in one turn: draw five and gain five plays. | Once per combat; requires three extra/banked/kill-refunded plays beyond the base two. This retained rare sequence does not use terrain counts or intensity. |

Simple relics retain their clear action, defense, movement, Light, or illusion
roles. The complete audit covers all sixty IDs rather than requiring every relic
to become a terrain transformation. Numerical values here are initial tuning;
[the heuristic](card_balance_heuristic.md) and seeded combat proof must be read
alongside them, not treated as a win-rate guarantee.

## Reproducible proof

`python3 tools/board_surface_content_audit.py` regenerates the full card role and
score receipt plus `relic-support-counts.json` under `output/board-surface-refactor/`. It validates all stable
inventories, retired rules removal, painter connectivity, and the nine required
transformation effects. Focused `relic_test.gd`, `surface_relic_test.gd`,
`board_surface_data_test.gd`, and `surface_parent_review_test.gd` cover execution
and negative source/continuation cases. Run Godot through the task runner.
