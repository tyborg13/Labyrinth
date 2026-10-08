# Relic Trigger Feasibility

Current rules: relic pool overhaul, 2026-10-02. The board-surface constraints and
the nine transformations below are unchanged from the 2026-09-06 refactor; the
resource and state bridges table now covers the overhauled relics. The authored
pool is recorded in [the relic pool overhaul](relic_pool_overhaul/README.md).

## Live constraints and support

The player starts at 24 health with a five-card hand, two draws and two card
plays per turn; the hand cap is seven. Normal encounter targets are 3–5 enemies
and 3–5 player turns, with longer boss fights. These are tuning targets, not
measured guarantees for every seed. Fatigue begins at two damage and increases
on reshuffle. Relic draws stop before reshuffle. Only active player-action kills
of non-summoned enemies grant the ordinary extra play; passive start deaths do
not bank plays.

The support counts below are September 2026 figures, taken before the card pool
overhaul; regenerate them with the audit tool for current numbers. Counts include
nested conditional rewards and count cards, not actions; categories overlap.

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
| Worldroot Idol / `worldroot_idol` | Stand on a cardinal Rubble path, enable Worldroot and select a target. | The nearest connected legal origin is selected automatically (cardinal BFS order breaks ties). One melee/ranged attack measures from and consumes that origin; the player does not move. The route breaks as fuel is spent. Ordinary visibility and target legality still apply. |
| Basalt Kiln / `basalt_calendar` | Choose Rubble fuel for an existing Detonate action. | Consume selected Rubble, resolve the same shared blast union, then paint Fire on spent tiles. The new Fire has no placement damage and can be used by either side later. |
| Thunder Relay / `thunder_relay` | Chain through at least two enemies; choose endpoint exchange. | Exchange first and last native Chain targets only if both survive and both complete footprints fit. Resolve landing hazards. Conduction-only victims do not become endpoints. |

These effects do not all produce stats or draws. Each changes the set of legal
or useful tactical decisions. Shared danger and finite local fuel are deliberate
costs, including the Fire left by Basalt Kiln and routes available to enemy
Lightning under Stormcoal.

## Resource and state bridges

| Relic | Trigger / payoff | Repeat and scaling check |
| --- | --- | --- |
| Pocket Sundial | Using both base card plays brings your next turn 2 Time sooner. | 2 per full turn. |
| Borrowed Hourglass | End your turn with a card play unused: take another turn at once. | Once per combat; the extra turn's Time is added to the following turn. |
| Whirling Sash | One extra card play each turn; cards after the second cost 2 more Time. | The surcharge makes long turns delay the next one. |
| Crown of Surplus | Cards without Empower gain Empower (+3 Time): repeat the first action. | Excludes Rites, items, Flurry and cards with their own Empower. |
| Pendulum Weight | Stagger beyond the per-turn limit of 6 becomes damage. | Bounded by real Stagger supply; dragons halve Stagger before overflow. |
| Siege Ram Totem | Collision damage also Staggers the enemy by that much. | Within the normal per-turn Stagger limit. |
| Battering Yoke | An enemy pushed into another enemy knocks it 1 tile on. | Each enemy is knocked at most once per action. |
| The Breaking Wheel | A collision on a surface consumes it with a rider (Fire damage, Ice Freeze, Electrified Shock, Rubble Stagger). | The surface is spent; Freeze respects immunity. |
| Black Sun Dial | Consumed surfaces are stored and released on your next attack. | At most 3 stored; further consumptions are not stored. |
| Fivefold Knot | Each element played ties a knot for the combat: Pierce at 3, Chain 1 at 4, Block per card at 5. | Five knots in total; it never resets within a combat. |
| Mirror Triptych | Your first attack card each turn is echoed by up to three illusions at half damage. | Once per turn; each echo costs its illusion 1 health. |
| Storm Crown | A Chain bolt rebounds along its route for half damage. | The rebound does not conduct, add hops or apply riders. |
| Bloodmoon Chalice | Health lost on your turn adds 2 damage per health to your next attack. | At most 8; unused bonus ends with the turn. |
| Iron Lung | Health costs are paid with 2 Stoneskin per health. | Only while you hold at least 2 Stoneskin. |
| Briar Throne | Retaliate lasts the combat and grows by 1 per trigger. | Cards give you no Block. |
| Liturgy of Ash | Rites use no card play. | Their Time is still paid. |
| Pyre-Keeper's Urn | The most recently Exhausted card returns at turn start. | Once per turn; never a Rite or a healing card. |
| Quartermaster's Ledger | Items are no longer consumed. | Each item is usable once per combat; healing items are still consumed. |
| Beaconrunner Spurs | Entering your Light during a Move refunds movement. | At most 2 per turn. |
| Unclouded Sun | Your Light sources count as adjacent for your Move (relay points). | A jump between sources costs 1 movement; landing hazards apply as usual. |
| Ember Siphon | An enemy dying on Fire spreads Fire to the empty tiles around it. | Placement only, so no immediate contact. |
| Overflow Censer | Placing an elemental surface over a different one spreads it to the empty tiles around. | The spread does not chain. |
| Funeral Bell | An enemy dying with 2 or more statuses passes them to adjacent enemies. | Needs two different statuses on the dying enemy. |
| Static Soles | First actual Move/Blink leaves Electrified at its origin and grants Vision one for two turns. | Once per turn; a failed move does not spend the trigger. |
| Phoenix Ember | Adds one run Defiance charge. Trigger dispels two Umbra, paints Fire beneath enemies, draws three, and grants three plays. | Finite run survival resource; the shared Fire makes the board dangerous later. |
| Bloodglass Knife | At half health or lower with no Block/Stoneskin, attacks gain seven damage. | Deliberate direct-hit ceiling with an immediate survivability cost. |
| Thawing Charm | Excess healing becomes up to eight Stoneskin per turn; first conversion places local Light. | Supplies no healing itself. |
| Tailwind Fletching / Anchor Chain | Air or held-Block force modifiers improve damage and distance. | Paid Push/Pull with local collision constraints. |
| Storm Capacitor | Existing Lightning ranged Chain gains one hop reach. | No new target-budget semantics and no added damage per hop. |

Simple relics retain their clear action, defense, movement, Light, or illusion
roles. Not every relic needs to be a terrain transformation. Numerical values here are initial tuning;
[the heuristic](card_balance_heuristic.md) and seeded combat proof must be read
alongside them, not treated as a win-rate guarantee.

## Reproducible proof

`python3 tools/board_surface_content_audit.py` regenerates the full card role and
score receipt plus `relic-support-counts.json` under `output/board-surface-refactor/`. It validates all stable
inventories, retired rules removal, painter connectivity, and the nine required
transformation effects. Focused `relic_test.gd`, `surface_relic_test.gd`,
`board_surface_data_test.gd`, and `surface_parent_review_test.gd` cover execution
and negative source/continuation cases. Run Godot through the task runner.
