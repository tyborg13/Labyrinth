# Creature move claim audit

44 creature pages. 137 move rows and 1100 claims. 100 False, 1 UNTESTED, 999 True.

The production Grimoire supplied each rendered line. The same builder supplied the token and tooltip inventory. A generated token tooltip is listed even when an authored summary replaces it or the ordinary combat panel suppresses the default damage tooltip. Figures are catalog base values. Engine evidence describes ordinary eligible targets, default rules and unmodified base damage unless a claim explicitly promises more. The live Erupt panel uses its dedicated emergence sentence. Headless combat receipts cover the changed moves and three comparison moves.

[Wording inventory](#wording-inventory) · [Evidence key](#evidence-key)

## False rows (47)

### arc_thrall / Arc Bolt

`Move 2 · Ranged 3 · Range 3 · Electrified` · Time 5

Catalog `arc_bolt`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L2877)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).
- Token `Electrified` — **True** [ground](#evidence-ground).
- Tooltip `A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles.` — **True** [electrified](#evidence-electrified).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### arc_thrall / Arc Jab

`Move 2 · Melee 3 · Shock 1` · Time 4

Catalog `arc_jab`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2877)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Shock 1` — **True** [shock](#evidence-shock).
- Tooltip `Shocked units can only Move or Blink on their next turn.` — **False** [shock_effect](#evidence-shock-effect).

### ashen_reaver / Executioner's Fall

`Move 1 · Ranged 8 · Range 4 · Fire · Area · Self: Expose 3` · Time 7

Catalog `executioners_fall`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L1846)

- Time `Time 7` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged 8` — **True** [attack](#evidence-attack).
- Tooltip `Deal 8 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_guardian](#evidence-ranged-guardian).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Area` — **True** [area_committed](#evidence-area-committed).
- Token `Self:` — **True** [self_reaver](#evidence-self-reaver).
- Token `Expose 3` — **True** [self_reaver](#evidence-self-reaver).
- Tooltip `The next hit that damages an Exposed unit deals 3 more damage.` — **True** [expose_effect](#evidence-expose-effect).

### ashen_reaver / Hooked Sweep

`Move 2 · Melee 6 · Range 2 · Push 1 · Fire · Area` · Time 5

Catalog `hooked_sweep`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L1846)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Range 2` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **False** [force_direction](#evidence-force-direction).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### ashen_reaver / Raking Flame

`Move 1 · Ranged · Fire · Range 4 · Area` · Time 4

Catalog `raking_flame`. Actions in order: `move_toward, surface`. [Enemy data](../../data/enemies.json#L1846)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged` — **False** [placement](#evidence-placement).
- Token `Fire` — **True** [layout_ground](#evidence-layout-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### bell_tender / Join the Choir

`Move 2 · Ranged · Electrified · Range 4 · 2 linked tiles` · Time 4

Catalog `connector`. Actions in order: `move_toward, surface`. [Enemy data](../../data/enemies.json#L2470)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged` — **False** [placement](#evidence-placement).
- Token `Electrified` — **True** [layout_ground](#evidence-layout-ground).
- Tooltip `A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles.` — **True** [electrified](#evidence-electrified).
- Token `Range 4` — **True** [connector_range](#evidence-connector-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [connector_range](#evidence-connector-range).
- Token `2 linked tiles` — **False** [connector_count](#evidence-connector-count).
- Tooltip `Extends existing Electrified toward its target.` — **False** [connector_existing](#evidence-connector-existing).

### bell_tender / Staff Bolt

`Move 2 · Ranged 3 · Range 3` · Time 4

Catalog `staff_bolt`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L2470)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).

### bile_bloomer / Shale Burst

`Move 1 · Melee 3 · Area · Rubble` · Time 5

Catalog `bile_burst`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L505)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Area` — **True** [area](#evidence-area).
- Token `Rubble` — **True** [ground](#evidence-ground).
- Tooltip `Leaving Rubble costs 2 Movement.` — **True** [rubble](#evidence-rubble).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### briar_weaver / Thornwall

`Marked · Upheaval 3` · Time 6

Catalog `thornwall`. Actions in order: `upheaval_mark`. [Enemy data](../../data/enemies.json#L3284)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [upheaval](#evidence-upheaval).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **False** [mark_bramble](#evidence-mark-bramble).
- Token `Upheaval 3` — **True** [upheaval](#evidence-upheaval).
- Tooltip `On each Upheaval beat, Marked tiles become Outcrops and move units to free adjacent tiles.` — **True** [upheaval](#evidence-upheaval).

### burrow_grub / Burrow

`Burrow` · Time 5

Catalog `burrow`. Actions in order: `burrow`. [Enemy data](../../data/enemies.json#L2998)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Burrow` — **True** [burrow](#evidence-burrow).
- Tooltip `This enemy Burrows and Marks your tile.` — **True** [burrow](#evidence-burrow).
- Tooltip `Burrowed enemies cannot be targeted.` — **False** [burrow_target](#evidence-burrow-target).

### burrow_grub / Erupt

`Erupt 6 · Push 1 · Rubble · Self: Expose 2` · Time 5

Catalog `erupt`. Actions in order: `erupt`. [Enemy data](../../data/enemies.json#L2998)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Erupt 6` — **True** [erupt_damage](#evidence-erupt-damage).
- Tooltip `This enemy emerges on the Marked tile or the nearest open tile.` — **True** [erupt](#evidence-erupt).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **False** [force_erupt](#evidence-force-erupt).
- Token `Rubble` — **True** [erupt_rubble](#evidence-erupt-rubble).
- Tooltip `Leaving Rubble costs 2 Movement.` — **True** [rubble](#evidence-rubble).
- Token `Self:` — **True** [self_grub](#evidence-self-grub).
- Token `Expose 2` — **True** [self_grub](#evidence-self-grub).
- Tooltip `The next hit that damages an Exposed unit deals 2 more damage.` — **True** [expose_effect](#evidence-expose-effect).

### cinder_ooze / Cinder Bloom

`Melee 4 · Area · Fire` · Time 6

Catalog `cinder_bloom`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L332)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Area` — **True** [area](#evidence-area).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### craghide / Groundsplit

`Marked · Melee 7 · Each Outcrop · within 2` · Time 6

Catalog `groundsplit`. Actions in order: `terrain_burst`. [Enemy data](../../data/enemies.json#L2166)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **False** [mark_crag](#evidence-mark-crag).
- Token `Melee 7` — **True** [attack](#evidence-attack).
- Tooltip `Deal 7 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_crag](#evidence-melee-crag).
- Token `Each Outcrop · within 2` — **False** [crag_area](#evidence-crag-area).
- Tooltip `This enemy hits each floor tile within the shown distance of a surviving Outcrop.` — **False** [crag_area](#evidence-crag-area).

### frostglass_lancer / Glass Lunge

`Move 1 · Melee 6 · Area · Ice · On Ice: also Stagger 6` · Time 5

Catalog `glass_lunge`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L805)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Area` — **True** [area](#evidence-area).
- Token `Ice` — **True** [ground](#evidence-ground).
- Tooltip `entering Ice` — **True** [ice](#evidence-ice).
- Tooltip `starting a turn on Ice gains Expose 2` — **True** [ice](#evidence-ice).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### gale_herald / Call the Wind

`Gust 2 · Push 1` · Time 6

Catalog `call_the_wind`. Actions in order: `call_wind`. [Enemy data](../../data/enemies.json#L2816)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Gust 2` — **True** [gust_count](#evidence-gust-count).
- Tooltip `On each Gust beat, each unit is Pushed downwind.` — **False** [gust_each](#evidence-gust-each).
- Token `Push 1` — **True** [gust_count](#evidence-gust-count).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **False** [force_gust](#evidence-force-gust).

### gallows_roc / Hookwind

`Move 1 · Ranged 3 · Range 4 · Pull 2 · Area` · Time 4

Catalog `hookwind`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L2090)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_guardian](#evidence-ranged-guardian).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Pull 2` — **True** [force](#evidence-force).
- Tooltip `Move the target 2 tiles straight toward the source, causing a Collision if blocked.` — **False** [force_direction](#evidence-force-direction).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### gallows_roc / Razor Pinion

`Move 2 · Melee 6 · Range 2 · Push 2 · Area` · Time 5

Catalog `razor_pinion`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L2090)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Range 2` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Push 2` — **True** [force](#evidence-force).
- Tooltip `Move the target 2 tiles straight away from the source, causing a Collision if blocked.` — **False** [force_direction](#evidence-force-direction).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### glacial_mirror / Refraction

`Melee 4 · Area · Pierce · On Ice: also Stagger 6` · Time 6

Catalog `refraction`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L3423)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_mirror](#evidence-melee-mirror).
- Token `Area` — **UNTESTED** [area_mirror](#evidence-area-mirror).
- Token `Pierce` — **True** [pierce](#evidence-pierce).
- Tooltip `ignores Block` — **True** [pierce](#evidence-pierce).
- Tooltip `and Stoneskin` — **True** [pierce](#evidence-pierce).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### gloam_stalker / Fade

`Blink 4` · Time 5

Catalog `fade`. Actions in order: `veil_blink`. [Enemy data](../../data/enemies.json#L2933)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Blink 4` — **True** [fade](#evidence-fade).
- Tooltip `Blinks behind you, or to another adjacent tile` — **False** [fade_absolute](#evidence-fade-absolute).
- Tooltip `then Ambushes on this enemy’s next turn` — **True** [ambush](#evidence-ambush).

### grave_surgeon / Field Brace

`Move 1 · Block 3 · Expend` · Time 4

Catalog `field_brace`. Actions in order: `move_toward, guard_ally`. [Enemy data](../../data/enemies.json#L731)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Block 3` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).
- Token `Expend` — **True** [block](#evidence-block).
- Tooltip `Remove Shape Ground from your tile.` — **False** [expend_ally](#evidence-expend-ally).

### gust_shrike / Dive

`Move 4 · Melee 4 · Push 1 · Within 1 of its path` · Time 5

Catalog `dive`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L3494)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 4` — **True** [move](#evidence-move).
- Tooltip `Walk up to 4 tiles.` — **True** [move](#evidence-move).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_dive](#evidence-melee-dive).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **True** [force](#evidence-force).
- Token `Within 1 of its path` — **True** [dive](#evidence-dive).
- Tooltip `Hits every tile within 1 tiles of its path.` — **False** [dive_every](#evidence-dive-every).

### hollow_mimic / Echo

`Ranged 3 · Range 4 · Retaliate 3` · Time 6

Catalog `echo`. Actions in order: `ranged, retaliate`. [Enemy data](../../data/enemies.json#L3222)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Retaliate 3` — **True** [retaliate](#evidence-retaliate).
- Tooltip `Until your next turn` — **True** [retaliate](#evidence-retaliate).
- Tooltip `each enemy that hits you in melee takes 3 damage` — **False** [retaliate_victim](#evidence-retaliate-victim).

### iskaldra / Shatterstorm

`Move 1 · Melee 7 · @pattern(ring_1:1) · Range 1, +1 per Crystal Mantle · removes all Crystal Mantle` · Time 6

Catalog `shatterstorm`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L1323)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Melee 7` — **True** [attack](#evidence-attack).
- Tooltip `Deal 7 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Range 1` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_ring_tip](#evidence-range-ring-tip).
- Token `@pattern(ring_1:1)` — **True** [area_ring](#evidence-area-ring).
- Token `Mantle fuels range` — **True** [mantle_range](#evidence-mantle-range).
- Tooltip `Each remaining layer adds 1 range, up to 4.` — **True** [mantle_range](#evidence-mantle-range).
- Tooltip `Break layers to shrink the warning` — **False** [mantle_warning](#evidence-mantle-warning).
- Tooltip `Shatterstorm spends the rest` — **True** [mantle_range](#evidence-mantle-range).
- Summary `Range 1, +1 per Crystal Mantle` — **True** [mantle_range](#evidence-mantle-range).
- Summary `removes all Crystal Mantle` — **True** [mantle_range](#evidence-mantle-range).

### iskaldra / Whiteout Lance

`Melee 6 · Range 3 · Ice · @pattern(body_cross:3) · On Ice: also Stagger 6` · Time 5

Catalog `whiteout_lance`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L1323)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Range 3` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Ice` — **True** [ground](#evidence-ground).
- Tooltip `entering Ice` — **True** [ice](#evidence-ice).
- Tooltip `starting a turn on Ice gains Expose 2` — **True** [ice](#evidence-ice).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `@pattern(body_cross:3)` — **True** [area_committed](#evidence-area-committed).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### last_lamplighter / Mourning Hook

`Move 2 · Ranged 3 · Range 4 · Pull 1 · Area` · Time 5

Catalog `mourning_hook`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L2227)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_guardian](#evidence-ranged-guardian).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Pull 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight toward the source, causing a Collision if blocked.` — **False** [force_direction](#evidence-force-direction).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### lightning_wisp / Capacitor Arc

`Retreat 1 · Ranged 4 · Range 2 · On Electrified: also Shock +1` · Time 4

Catalog `blinding_arc`. Actions in order: `move_away, ranged`. [Enemy data](../../data/enemies.json#L1756)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 1` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 1 tile away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).
- Token `if Electrified used:` — **True** [conducted](#evidence-conducted).
- Tooltip `if Electrified used:` — **True** [conducted](#evidence-conducted).
- Token `Shock +1` — **True** [shock](#evidence-shock).
- Tooltip `Shocked units can only Move or Blink on their next turn.` — **False** [shock_effect](#evidence-shock-effect).

### lightning_wisp / Static Lash

`Move 1 · Ranged 3 · Range 2 · Electrified` · Time 4

Catalog `static_lash`. Actions in order: `move_toward, ranged, surface`. [Enemy data](../../data/enemies.json#L1756)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).
- Token `Electrified` — **True** [layout_ground](#evidence-layout-ground).
- Tooltip `A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles.` — **True** [electrified](#evidence-electrified).

### noctyrax / Last Eclipse

`Marked: Ranged 8 · Eclipse 2, then Summon Veilbound Acolyte` · Time 6

Catalog `last_eclipse`. Actions in order: `umbra_eclipse, summon_minions`. [Enemy data](../../data/enemies.json#L1472)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [marked](#evidence-marked).
- Token `Ranged 8` — **True** [attack](#evidence-attack).
- Tooltip `Deal 8 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Eclipse 2` — **True** [eclipse_duration](#evidence-eclipse-duration).
- Tooltip `hits you and your illusions on Marked tiles` — **True** [eclipse_damage](#evidence-eclipse-damage).
- Tooltip `then starts Eclipse for 2 turns` — **False** [eclipse_order](#evidence-eclipse-order).
- Token `Summon` — **True** [summon](#evidence-summon).
- Tooltip `This enemy adds Veilbound Acolyte to combat.` — **True** [summon](#evidence-summon).
- Token `Veilbound Acolyte` — **True** [summon](#evidence-summon).
- Summary `Marked: Ranged 8` — **True** [eclipse_damage](#evidence-eclipse-damage).
- Summary `Eclipse 2` — **True** [eclipse_duration](#evidence-eclipse-duration).
- Summary `then Summon Veilbound Acolyte` — **True** [summon](#evidence-summon).

### noctyrax / Night Coil

`Ranged 6 · Range 3 · Pull 1 · Area · puts out the nearest brazier` · Time 6

Catalog `night_coil`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L1472)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Ranged 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Range 3` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Pull 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight toward the source, causing a Collision if blocked.` — **False** [force_direction](#evidence-force-direction).
- Token `Area` — **True** [area_committed](#evidence-area-committed).
- Token `Snuff brazier` — **True** [snuff_coil](#evidence-snuff-coil).
- Tooltip `Night Coil puts out the Marked brazier.` — **True** [snuff_coil](#evidence-snuff-coil).
- Tooltip `Enter that brazier's tile to relight the brazier before Eclipse.` — **True** [brazier_relight](#evidence-brazier-relight).
- Summary `puts out the nearest brazier` — **True** [snuff_coil](#evidence-snuff-coil).

### noctyrax / Starless Breath

`Ranged 8 · Range 4 · Pierce · Area` · Time 6

Catalog `starless_breath`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L1472)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Ranged 8` — **True** [attack](#evidence-attack).
- Tooltip `Deal 8 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Pierce` — **True** [pierce](#evidence-pierce).
- Tooltip `ignores Block` — **True** [pierce](#evidence-pierce).
- Tooltip `and Stoneskin` — **True** [pierce](#evidence-pierce).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### rime_spitter / Rime Needle

`Move 2 · Ranged 2 · Range 3 · Area · Ice · At lane end` · Time 6

Catalog `needle`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L2409)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_guardian](#evidence-ranged-guardian).
- Token `Range 3` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Area` — **True** [area_committed](#evidence-area-committed).
- Token `Ice` — **True** [lane_end](#evidence-lane-end).
- Tooltip `entering Ice` — **True** [ice](#evidence-ice).
- Tooltip `starting a turn on Ice gains Expose 2` — **True** [ice](#evidence-ice).
- Token `At lane end` — **True** [lane_end](#evidence-lane-end).

### storm_cantor / Lay the Choir

`Move 2 · Ranged · Electrified · Range 5 · 6 linked tiles` · Time 4

Catalog `lay_the_choir`. Actions in order: `move_toward, surface`. [Enemy data](../../data/enemies.json#L2009)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged` — **False** [placement](#evidence-placement).
- Token `Electrified` — **True** [layout_ground](#evidence-layout-ground).
- Tooltip `A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles.` — **True** [electrified](#evidence-electrified).
- Token `Range 5` — **True** [connector_range](#evidence-connector-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [connector_range](#evidence-connector-range).
- Token `6 linked tiles` — **False** [connector_count](#evidence-connector-count).
- Tooltip `Extends existing Electrified toward its target.` — **False** [connector_existing](#evidence-connector-existing).

### tharokh / Bedrock Breath

`Ranged 10 · Range 4 · Rubble · Area` · Time 5

Catalog `bedrock_breath`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L939)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 10` — **True** [attack](#evidence-attack).
- Tooltip `Deal 10 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Rubble` — **True** [ground](#evidence-ground).
- Tooltip `Leaving Rubble costs 2 Movement.` — **True** [rubble](#evidence-rubble).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### tharokh / Stonewake

`Ranged 6 · Range 4 · Area` · Time 4

Catalog `stonewake`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L939)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Ranged 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Range 4` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### tharokh / Worldspine Claw

`Move 2 · Melee 15 · Range 1 · Area` · Time 5

Catalog `worldspine_claw`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L939)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 15` — **True** [attack](#evidence-attack).
- Tooltip `Deal 15 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Range 1` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### vaeloryx / Eye of the Storm

`Retreat 3 · Melee 8 · Range 5 · @pattern(ring_2:5), then Melee 4` · Time 6

Catalog `eye_of_storm`. Actions in order: `move_away, aoe, melee`. [Enemy data](../../data/enemies.json#L1190)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Retreat 3` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 3 tiles away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Melee 8` — **True** [attack](#evidence-attack).
- Tooltip `Deal 8 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Range 5` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_ring_tip](#evidence-range-ring-tip).
- Token `@pattern(ring_2:5)` — **True** [area_ring](#evidence-area-ring).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Summary `Retreat 3 · Melee 8 · Range 5 · [diagram]` — **True** [area_ring](#evidence-area-ring).
- Summary `then Melee 4` — **True** [attack](#evidence-attack).

### vaeloryx / Hollow Gale

`Melee 6 · Range 2 · Push 1 · @pattern(ring_1:2)` · Time 6

Catalog `hollow_gale`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L1190)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Melee` — **True** [area_ring](#evidence-area-ring).
- Token `Hollow Gale 6` — **True** [area_damage](#evidence-area-damage).
- Tooltip `damages each unit within 2 tiles` — **False** [gale_unit](#evidence-gale-unit).
- Tooltip `Pushes each unit hit 1 tile` — **True** [gale_push](#evidence-gale-push).
- Token `Range 2` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_ring_tip](#evidence-range-ring-tip).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **True** [force](#evidence-force).
- Token `@pattern(ring_1:2)` — **True** [area_ring](#evidence-area-ring).
- Summary `Melee 6 · Range 2 · Push 1 · [diagram]` — **True** [area_ring](#evidence-area-ring).

### vaeloryx / Razor Dive

`Move 3 · Melee 7 · Range 1 of the dive trail behind this enemy` · Time 5

Catalog `razor_dive`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L1190)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 7` — **True** [attack](#evidence-attack).
- Tooltip `Deal 7 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_dive](#evidence-melee-dive).
- Token `Range 1` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [razor](#evidence-razor).
- Token `Along approach +1` — **False** [razor](#evidence-razor).
- Tooltip `Hits every tile within this distance of its path.` — **False** [razor](#evidence-razor).
- Summary `Range 1 of the dive trail behind this enemy` — **False** [razor](#evidence-razor).

### vyraketh / Cinder Maw

`Move 2 · Melee 8, then Cinder Marks 7: Ranged 3 · Fire` · Time 5

Catalog `cinder_maw`. Actions in order: `move_toward, melee, cinder_marks`. [Enemy data](../../data/enemies.json#L1060)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 8` — **True** [attack](#evidence-attack).
- Tooltip `Deal 8 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [marked](#evidence-marked).
- Token `Cinder Marks 7` — **False** [cinder_size](#evidence-cinder-size).
- Tooltip `This enemy leaves Fire on each Marked tile.` — **True** [cinder_hit](#evidence-cinder-hit).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Summary `Move 2 · Melee 8, then Cinder Marks` — **True** [cinder_hit](#evidence-cinder-hit).
- Summary `Cinder Marks 7` — **False** [cinder_size](#evidence-cinder-size).
- Summary `Ranged 3 · Fire` — **True** [cinder_hit](#evidence-cinder-hit).

### vyraketh / Cinder Breath

`Ranged 6 · Range 3 · Area` · Time 5

Catalog `cinderfall`. Actions in order: `aoe`. [Enemy data](../../data/enemies.json#L1060)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Range 3` — **True** [range_shape](#evidence-range-shape).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [range_shape_tip](#evidence-range-shape-tip).
- Token `Area` — **True** [area_committed](#evidence-area-committed).

### vyraketh / Crownfire

`Each Cinder Mark: Burst 8, then Move 2 · Melee 6` · Time 5

Catalog `crownfire`. Actions in order: `detonate_cinders, move_toward, melee`. [Enemy data](../../data/enemies.json#L1060)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [marked](#evidence-marked).
- Token `Crownfire 8` — **True** [cinder_burst](#evidence-cinder-burst).
- Tooltip `This enemy Bursts the Fire on each tile from this enemy's last Cinder Marks.` — **True** [cinder_burst](#evidence-cinder-burst).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Summary `Each Cinder Mark: Burst 8` — **False** [cinder_fuel](#evidence-cinder-fuel).
- Summary `then Move 2 · Melee 6` — **True** [cinder_burst](#evidence-cinder-burst).

### vyraketh / Meteorfall

`Cinder Marks 7: Ranged 4 · Fire, then Ranged 4 · Range 4` · Time 5

Catalog `kindle_ground`. Actions in order: `cinder_marks, ranged`. [Enemy data](../../data/enemies.json#L1060)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [marked](#evidence-marked).
- Token `Cinder Marks 7` — **False** [cinder_size](#evidence-cinder-size).
- Tooltip `This enemy leaves Fire on each Marked tile.` — **True** [cinder_hit](#evidence-cinder-hit).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Summary `Cinder Marks 7` — **False** [cinder_size](#evidence-cinder-size).
- Summary `Ranged 4 · Fire, then Ranged 4 · Range 4` — **True** [cinder_hit](#evidence-cinder-hit).

### warden / Crushing Step

`Move 2 · Melee 6 · Area` · Time 6

Catalog `crushing_step`. Actions in order: `move_toward, aoe`. [Enemy data](../../data/enemies.json#L247)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **False** [melee_area](#evidence-melee-area).
- Token `Area` — **True** [area](#evidence-area).

### zekarion / Call Wisps

`Ranged 4 · Range 4 · Summon Lightning Wisp` · Time 6

Catalog `call_wisps`. Actions in order: `ranged, summon_minions`. [Enemy data](../../data/enemies.json#L1589)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).
- Token `Summon` — **True** [summon](#evidence-summon).
- Tooltip `This enemy adds Lightning Wisp to combat.` — **True** [summon](#evidence-summon).
- Token `Lightning Wisp` — **True** [summon](#evidence-summon).

### zekarion / Skybreak

`Lightning Strikes 9: Ranged 5 · Electrified` · Time 6

Catalog `skybreak`. Actions in order: `lightning_strikes`. [Enemy data](../../data/enemies.json#L1589)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [marked](#evidence-marked).
- Token `Ranged 5` — **True** [attack](#evidence-attack).
- Tooltip `Deal 5 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [ranged_committed](#evidence-ranged-committed).
- Token `Lightning Strikes 9` — **False** [sky_count](#evidence-sky-count).
- Tooltip `This enemy hits random tiles.` — **False** [sky_random](#evidence-sky-random).
- Token `Electrified` — **True** [ground](#evidence-ground).
- Tooltip `A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles.` — **True** [electrified](#evidence-electrified).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Summary `Lightning Strikes 9` — **False** [sky_count](#evidence-sky-count).
- Summary `Ranged 5 · Electrified` — **True** [sky_hit](#evidence-sky-hit).

### zekarion / Storm Lash

`Move 1 · Ranged 4 · Range 3 · Electrified` · Time 5

Catalog `storm_claw`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L1589)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).
- Token `Electrified` — **True** [ground](#evidence-ground).
- Tooltip `A Lightning card's hit on an Electrified tile also hits each enemy on connected Electrified tiles.` — **True** [electrified](#evidence-electrified).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### zekarion / Overload

`Ranged 3 · Range 4` · Time 5

Catalog `tempest_breath`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L1589)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **False** [relay](#evidence-relay).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **False** [relay](#evidence-relay).

## UNTESTED rows (0)

## True rows (90)

### acolyte / Dust Advance

`Move 3 · Melee 2` · Time 4

Catalog `dust_advance`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L72)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### acolyte / Dust Bolt

`Ranged 5 · Range 3` · Time 4

Catalog `dust_bolt`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L72)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Ranged 5` — **True** [attack](#evidence-attack).
- Tooltip `Deal 5 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### acolyte / Siphon

`Move 1 · Ranged 4 · Range 2 · Heal 2` · Time 5

Catalog `siphon`. Actions in order: `move_toward, ranged, heal_self`. [Enemy data](../../data/enemies.json#L72)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Heal 2` — **True** [heal](#evidence-heal).
- Tooltip `Restore 2 Health.` — **True** [heal](#evidence-heal).

### acolyte / Ward Chant

`Move 1 · Block 4` · Time 4

Catalog `ward_chant`. Actions in order: `move_toward, block`. [Enemy data](../../data/enemies.json#L72)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Block 4` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### ash_hound / Bite

`Move 3 · Melee 3` · Time 4

Catalog `bite`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2297)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### ash_hound / Flanking Bite

`Move 3 · Melee 2 · Push 1` · Time 4

Catalog `circle`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2297)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### bile_bloomer / Shale Shell

`Stoneskin 2` · Time 6

Catalog `pustule_shell`. Actions in order: `stoneskin`. [Enemy data](../../data/enemies.json#L505)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Stoneskin 2` — **True** [stoneskin](#evidence-stoneskin).
- Tooltip `Stoneskin absorbs damage after Block and stays until used up.` — **True** [stoneskin](#evidence-stoneskin).

### bile_bloomer / Shale Advance

`Move 2` · Time 5

Catalog `shale_advance`. Actions in order: `move_toward`. [Enemy data](../../data/enemies.json#L505)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).

### bile_bloomer / Shard Mark

`Ranged 3 · Range 3 · Expose 2 · Rubble` · Time 5

Catalog `spore_mark`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L505)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Expose 2` — **True** [expose](#evidence-expose).
- Tooltip `The next hit that damages an Exposed unit deals 2 more damage.` — **True** [expose_effect](#evidence-expose-effect).
- Token `Rubble` — **True** [ground](#evidence-ground).
- Tooltip `Leaving Rubble costs 2 Movement.` — **True** [rubble](#evidence-rubble).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### briar_weaver / Lash of Thorns

`Ranged 4 · Range 3` · Time 5

Catalog `lash_of_thorns`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L3284)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### briar_weaver / Root Mend

`Heal 4` · Time 5

Catalog `root_mend`. Actions in order: `heal_ally`. [Enemy data](../../data/enemies.json#L3284)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Heal 4` — **True** [heal](#evidence-heal).
- Tooltip `Restore 4 Health.` — **True** [heal](#evidence-heal).

### burrow_grub / Gnaw

`Move 2 · Melee 3` · Time 4

Catalog `gnaw`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2998)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### chainbound_gaoler / Chain Reel

`Melee 4 · Range 3 · Pull 2` · Time 6

Catalog `chain_reel`. Actions in order: `pull`. [Enemy data](../../data/enemies.json#L648)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Pull 2` — **True** [force](#evidence-force).
- Tooltip `Move the target 2 tiles straight toward the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### chainbound_gaoler / Cudgel Press

`Move 1 · Melee 6` · Time 5

Catalog `cudgel_press`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L648)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### chainbound_gaoler / Iron Guard

`Move 2 · Block 5` · Time 4

Catalog `iron_guard`. Actions in order: `move_toward, block`. [Enemy data](../../data/enemies.json#L648)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Block 5` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### chainbound_gaoler / Manacle Pin

`Ranged 1 · Range 3 · Immobilize` · Time 5

Catalog `manacle_pin`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L648)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 1` — **True** [attack](#evidence-attack).
- Tooltip `Deal 1 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Immobilize` — **True** [immobilize](#evidence-immobilize).
- Tooltip `Immobilized units can't Move, Blink or Swap on their next turn.` — **True** [immobilize](#evidence-immobilize).

### cinder_droplet / Hiss Back

`Retreat 1 · Block 2` · Time 4

Catalog `hiss_back`. Actions in order: `move_away, block`. [Enemy data](../../data/enemies.json#L449)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 1` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 1 tile away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Block 2` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### cinder_droplet / Spatter

`Move 2 · Melee 3 · Fire` · Time 4

Catalog `spatter`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L449)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### cinder_ooze / Ooze Advance

`Move 2` · Time 5

Catalog `ooze_advance`. Actions in order: `move_toward`. [Enemy data](../../data/enemies.json#L332)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).

### cinder_ooze / Slag Shell

`Block 3` · Time 4

Catalog `slag_shell`. Actions in order: `block`. [Enemy data](../../data/enemies.json#L332)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Block 3` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### cinder_ooze / Smolder Slide

`Move 1 · Melee 5 · Fire` · Time 5

Catalog `smolder_slide`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L332)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Melee 5` — **True** [attack](#evidence-attack).
- Tooltip `Deal 5 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Fire` — **True** [ground](#evidence-ground).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).

### craghide / Crushing Rush

`Move 3 · Melee 8` · Time 6

Catalog `crushing_rush`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2166)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 8` — **True** [attack](#evidence-attack).
- Tooltip `Deal 8 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### craghide / Crag Heave

`Move 2` · Time 4

Catalog `upheaval`. Actions in order: `move_toward`. [Enemy data](../../data/enemies.json#L2166)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).

### crawler / Coil

`Move 2 · Block 4` · Time 4

Catalog `coil`. Actions in order: `move_toward, block`. [Enemy data](../../data/enemies.json#L2)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Block 4` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### crawler / Lunge

`Move 3 · Melee 3` · Time 6

Catalog `lunge`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### crawler / Skitter Strike

`Move 2 · Melee 5` · Time 5

Catalog `skitter_strike`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 5` — **True** [attack](#evidence-attack).
- Tooltip `Deal 5 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### ember_hoarder / Kindle

`Burst +2` · Time 4

Catalog `kindle`. Actions in order: `kindle`. [Enemy data](../../data/enemies.json#L3118)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Burst +2` — **True** [kindle](#evidence-kindle).
- Tooltip `Its Burst deals 2 more.` — **True** [kindle](#evidence-kindle).

### ember_hoarder / Scurry

`Retreat 2` · Time 4

Catalog `scurry`. Actions in order: `move_away`. [Enemy data](../../data/enemies.json#L3118)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 2` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 2 tiles away from its target.` — **True** [retreat](#evidence-retreat).

### ember_tick / Kindle

`Burst +2` · Time 4

Catalog `kindle`. Actions in order: `kindle`. [Enemy data](../../data/enemies.json#L3063)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Burst +2` — **True** [kindle](#evidence-kindle).
- Tooltip `Its Burst deals 2 more.` — **True** [kindle](#evidence-kindle).

### ember_tick / Scuttle

`Move 3 · Melee 2` · Time 4

Catalog `scuttle`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L3063)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### frostglass_lancer / Frost Pin

`Ranged 5 · Range 3 · On Ice: also Stagger 6` · Time 6

Catalog `frost_pin`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L805)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Ranged 5` — **True** [attack](#evidence-attack).
- Tooltip `Deal 5 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### frostglass_lancer / Refract Guard

`Retreat 1 · Block 4 · Expend` · Time 5

Catalog `refract_guard`. Actions in order: `move_away, block`. [Enemy data](../../data/enemies.json#L805)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Retreat 1` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 1 tile away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Block 4` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).
- Token `Expend` — **True** [expend_self](#evidence-expend-self).
- Tooltip `Remove Ice from your tile.` — **True** [expend_self](#evidence-expend-self).

### frostglass_lancer / Spear Advance

`Move 3 · Melee 2` · Time 4

Catalog `spear_advance`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L805)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### frostglass_lancer / Spear Cast

`Ranged 4 · Range 3` · Time 4

Catalog `spear_cast`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L805)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### gale_herald / Gust Bolt

`Ranged 3 · Range 4 · Push 1` · Time 4

Catalog `gust_bolt`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L2816)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### gale_herald / Still Air

`Block 5` · Time 5

Catalog `still_air`. Actions in order: `block`. [Enemy data](../../data/enemies.json#L2816)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Block 5` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### gallows_roc / Grave Dive

`Move 3 · Melee 9` · Time 7

Catalog `grave_dive`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2090)

- Time `Time 7` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 9` — **True** [attack](#evidence-attack).
- Tooltip `Deal 9 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### glacial_mirror / Grind Forward

`Move 2` · Time 5

Catalog `advance`. Actions in order: `move_toward`. [Enemy data](../../data/enemies.json#L3423)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).

### glacial_mirror / Crystal Guard

`Block 6` · Time 5

Catalog `crystal_guard`. Actions in order: `guard_ally`. [Enemy data](../../data/enemies.json#L3423)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Block 6` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### gloam_stalker / Ambush

`Melee 7` · Time 5

Catalog `ambush`. Actions in order: `melee`. [Enemy data](../../data/enemies.json#L2933)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Melee 7` — **True** [attack](#evidence-attack).
- Tooltip `Deal 7 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### gloam_stalker / Slash

`Move 2 · Melee 4` · Time 4

Catalog `slash`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2933)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### grave_surgeon / Saw Jab

`Move 2 · Melee 3` · Time 4

Catalog `saw_jab`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L731)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### grave_surgeon / Triage Suture

`Move 1 · Heal 2` · Time 4

Catalog `triage_suture`. Actions in order: `move_toward, heal_ally`. [Enemy data](../../data/enemies.json#L731)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Heal 2` — **True** [heal](#evidence-heal).
- Tooltip `Restore 2 Health.` — **True** [heal](#evidence-heal).

### gust_shrike / Hover

`Retreat 2 · Block 3` · Time 4

Catalog `hover`. Actions in order: `move_away, block`. [Enemy data](../../data/enemies.json#L3494)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 2` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 2 tiles away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Block 3` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### gust_shrike / Talon Rake

`Move 2 · Melee 4` · Time 4

Catalog `talon_rake`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L3494)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### harrier / Darting Pelt

`Move 1 · Ranged 4 · Range 2` · Time 5

Catalog `darting_pelt`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L163)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### harrier / Pelt

`Pierce 5 · Range 3` · Time 4

Catalog `pelt`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L163)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Pierce 5` — **True** [pierce](#evidence-pierce).
- Tooltip `ignores Block` — **True** [pierce](#evidence-pierce).
- Tooltip `and Stoneskin` — **True** [pierce](#evidence-pierce).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### harrier / Retreat Step

`Retreat 2 · Block 3` · Time 4

Catalog `retreat_step`. Actions in order: `move_away, block`. [Enemy data](../../data/enemies.json#L163)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 2` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 2 tiles away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Block 3` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### harrier / Rush

`Move 3 · Melee 3` · Time 5

Catalog `rush`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L163)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### hoarfrost_seer / Icefall

`@pattern(icefall:hero) · Icefall 5 · Range 5` · Time 6

Catalog `icefall`. Actions in order: `icefall_mark`. [Enemy data](../../data/enemies.json#L2726)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `@pattern(icefall:hero)` — **True** [area_icefall](#evidence-area-icefall).
- Token `Icefall 5` — **True** [icefall](#evidence-icefall).
- Tooltip `@pattern(icefall:hero) This enemy hits each Marked tile on this enemy’s next turn, then leaves Ice.` — **True** [icefall](#evidence-icefall).
- Token `Range 5` — **True** [icefall_range](#evidence-icefall-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [icefall_range](#evidence-icefall-range).

### hoarfrost_seer / Icefall

`Icefall 5 · Ice · On Ice: also Stagger 6` · Time 4

Catalog `icefall_land`. Actions in order: `icefall_land`. [Enemy data](../../data/enemies.json#L2726)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Icefall 5` — **True** [icefall](#evidence-icefall).
- Tooltip `Marked tiles take the hit and turn to Ice.` — **True** [icefall](#evidence-icefall).
- Token `Ice` — **True** [icefall](#evidence-icefall).
- Tooltip `entering Ice` — **True** [ice](#evidence-ice).
- Tooltip `starting a turn on Ice gains Expose 2` — **True** [ice](#evidence-ice).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Target on Ice:` — **True** [icefall_condition](#evidence-icefall-condition).
- Tooltip `Target on Ice:` — **True** [icefall_condition](#evidence-icefall-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### hoarfrost_seer / Rime Bolt

`Ranged 3 · Range 4 · On Ice: also Stagger 6` · Time 4

Catalog `rime_bolt`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L2726)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### hoarfrost_seer / Withdraw

`Retreat 2 · Block 4` · Time 4

Catalog `withdraw`. Actions in order: `move_away, block`. [Enemy data](../../data/enemies.json#L2726)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 2` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 2 tiles away from its target.` — **True** [retreat](#evidence-retreat).
- Token `Block 4` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### hollow_mimic / Recede

`Retreat 2` · Time 4

Catalog `recede`. Actions in order: `move_away`. [Enemy data](../../data/enemies.json#L3222)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Retreat 2` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 2 tiles away from its target.` — **True** [retreat](#evidence-retreat).

### hollow_mimic / Shade Bolt

`Ranged 4 · Range 4` · Time 4

Catalog `shade_bolt`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L3222)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### iskaldra / Crystal Mantle

`Crystal Mantle 2 · Ranged 4 · Range 4 · On Ice: also Stagger 6` · Time 4

Catalog `crystal_mantle`. Actions in order: `frost_armor, ranged`. [Enemy data](../../data/enemies.json#L1323)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Crystal Mantle 2` — **True** [mantle_gain](#evidence-mantle-gain).
- Tooltip `Forms Crystal Mantle.` — **True** [mantle_gain](#evidence-mantle-gain).
- Tooltip `Each direct damaging hit breaks one layer and prevents its damage` — **True** [mantle_hit](#evidence-mantle-hit).
- Tooltip `ground and damage over time bypass it` — **True** [mantle_bypass](#evidence-mantle-bypass).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### iskaldra / Rime Talon

`Move 3 · Melee 10 · On Ice: also Stagger 6` · Time 5

Catalog `rime_talon`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1323)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 10` — **True** [attack](#evidence-attack).
- Tooltip `Deal 10 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### last_lamplighter / Last Procession

`Move 3 · Melee 6` · Time 7

Catalog `last_procession`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2227)

- Time `Time 7` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### last_lamplighter / Snuff

`Summon Wick Shade · Snuff brazier` · Time 4

Catalog `snuff`. Actions in order: `summon_minions`. [Enemy data](../../data/enemies.json#L2227)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Summon` — **True** [summon_guardian](#evidence-summon-guardian).
- Tooltip `This enemy adds Wick Shade to combat.` — **True** [summon_guardian](#evidence-summon-guardian).
- Token `Wick Shade` — **True** [summon](#evidence-summon).
- Token `Snuff brazier` — **True** [snuff_guardian](#evidence-snuff-guardian).
- Tooltip `Lasts until Last Procession, including a skipped turn.` — **True** [snuff_guardian](#evidence-snuff-guardian).
- Summary `You gain +1 Card Play next turn. (live combat tooltip)` — **True** [summon_reward](#evidence-summon-reward).

### lightning_wisp / Spark Dart

`Move 3 · Melee 2` · Time 4

Catalog `spark_dart`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1756)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### noctyrax / Void Claw

`Move 2 · Melee 10 · Expose 1` · Time 5

Catalog `void_claw`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1472)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 10` — **True** [attack](#evidence-attack).
- Tooltip `Deal 10 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Expose 1` — **True** [expose](#evidence-expose).
- Tooltip `The next hit that damages an Exposed unit deals 1 more damage.` — **True** [expose_effect](#evidence-expose-effect).

### rime_spitter / Frost Spit

`Move 2 · Ranged 2 · Range 3 · On Ice: also Stagger 6` · Time 4

Catalog `recover`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L2409)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 3` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### rime_whelp / Bite

`Move 3 · Melee 3` · Time 4

Catalog `bite`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2350)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### rime_whelp / Rime Snap

`Move 2 · Melee 2 · On Ice: also Stagger 6` · Time 4

Catalog `circle`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2350)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### rimejaw / Rime Bite

`Move 2 · Melee 6 · On Ice: also Stagger 6` · Time 5

Catalog `frostbite`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1924)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### rimejaw / Harrowing Pounce

`Move 3 · Melee 6 · Ice · On Ice: also Stagger 6` · Time 6

Catalog `harrowing_pounce`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1924)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 6` — **True** [attack](#evidence-attack).
- Tooltip `Deal 6 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Ice` — **True** [ground](#evidence-ground).
- Tooltip `entering Ice` — **True** [ice](#evidence-ice).
- Tooltip `starting a turn on Ice gains Expose 2` — **True** [ice](#evidence-ice).
- Tooltip `Leaves this ground in the affected area.` — **True** [ground](#evidence-ground).
- Token `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Tooltip `Target on Ice:` — **True** [ice_condition](#evidence-ice-condition).
- Token `Stagger 6` — **True** [stagger](#evidence-stagger).
- Tooltip `Delay the target's next turn by 6 Time.` — **True** [stagger](#evidence-stagger).

### rimejaw / Rime Trail

`Move 2 · Ice · Trail · Melee 3` · Time 4

Catalog `rime_trail`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1924)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ice` — **True** [move_trail](#evidence-move-trail).
- Tooltip `entering Ice` — **True** [ice](#evidence-ice).
- Tooltip `starting a turn on Ice gains Expose 2` — **True** [ice](#evidence-ice).
- Token `Trail` — **True** [move_trail](#evidence-move-trail).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### roc_fledgling / Darting Peck

`Move 3 · Melee 2` · Time 4

Catalog `circle`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2535)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### roc_fledgling / Hooked Peck

`Move 2 · Melee 3` · Time 4

Catalog `peck`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2535)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### slag_mortar / Brace

`Block 6` · Time 5

Catalog `brace`. Actions in order: `block`. [Enemy data](../../data/enemies.json#L3344)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Block 6` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### slag_mortar / Lob Slag

`@pattern(cross:hero) This enemy Marks tiles on your tile. On this enemy's next turn, this enemy will deal 5 damage on the central tile and 3 damage on each adjacent tile, then leave Fire.` · Time 6

Catalog `lob_slag`. Actions in order: `lob_mark`. [Enemy data](../../data/enemies.json#L3344)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `@pattern(cross:hero)` — **True** [area_lob](#evidence-area-lob).
- Token `Marked` — **True** [mark_next](#evidence-mark-next).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [mark_next](#evidence-mark-next).
- Token `Aoe 5` — **True** [lob_hit](#evidence-lob-hit).
- Tooltip `5 damage on the central tile` — **True** [lob_hit](#evidence-lob-hit).
- Tooltip `3 damage on each adjacent tile` — **True** [lob_hit](#evidence-lob-hit).
- Token `Fire` — **True** [lob_fire](#evidence-lob-fire).
- Tooltip `entering Fire takes 2 damage` — **True** [fire](#evidence-fire).
- Tooltip `starting on Fire takes 3` — **True** [fire](#evidence-fire).
- Summary `Marks tiles on your tile` — **True** [lob_mark](#evidence-lob-mark).
- Summary `On this enemy's next turn` — **True** [mark_next](#evidence-mark-next).
- Summary `5 damage on the central tile` — **True** [lob_hit](#evidence-lob-hit).
- Summary `3 damage on each adjacent tile` — **True** [lob_hit](#evidence-lob-hit).
- Summary `then leave Fire` — **True** [lob_fire](#evidence-lob-fire).

### slag_mortar / Scatter Shot

`Ranged 3 · Range 2 · Push 1` · Time 5

Catalog `scatter_shot`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L3344)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Ranged 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### slag_mortar / Lob Slag

`@pattern(cross) Deal 5 damage on the central tile and 3 damage on each adjacent tile, then leave Fire.` · Time 4

Catalog `slag_lands`. Actions in order: `lob_land`. [Enemy data](../../data/enemies.json#L3344)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `@pattern(cross)` — **True** [area_lob](#evidence-area-lob).
- Token `Lob Slag · 5 / 3` — **True** [lob_hit](#evidence-lob-hit).
- Tooltip `5 damage on the central tile` — **True** [lob_hit](#evidence-lob-hit).
- Tooltip `3 damage on each adjacent tile` — **True** [lob_hit](#evidence-lob-hit).
- Tooltip `then leave Fire` — **True** [lob_fire](#evidence-lob-fire).
- Summary `5 damage on the central tile` — **True** [lob_hit](#evidence-lob-hit).
- Summary `3 damage on each adjacent tile` — **True** [lob_hit](#evidence-lob-hit).
- Summary `then leave Fire` — **True** [lob_fire](#evidence-lob-fire).

### stoneback_mite / Claw

`Move 2 · Melee 3` · Time 4

Catalog `bite`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2590)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 3` — **True** [attack](#evidence-attack).
- Tooltip `Deal 3 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### stoneback_mite / Driving Claw

`Move 2 · Block 1 · Melee 2 · Push 1` · Time 4

Catalog `brace`. Actions in order: `move_toward, block, melee`. [Enemy data](../../data/enemies.json#L2590)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Block 1` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Push 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight away from the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### storm_cantor / Broken Rhythm

`Move 2 · Melee 11 · Range 2` · Time 5

Catalog `broken_rhythm`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2009)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 11` — **True** [attack](#evidence-attack).
- Tooltip `Deal 11 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### storm_cantor / Call the Spark

`Summon Lightning Wisp` · Time 6

Catalog `call_the_spark`. Actions in order: `summon_minions`. [Enemy data](../../data/enemies.json#L2009)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Summon` — **True** [summon_guardian](#evidence-summon-guardian).
- Tooltip `This enemy adds Lightning Wisp to combat.` — **True** [summon_guardian](#evidence-summon-guardian).
- Token `Lightning Wisp` — **True** [summon](#evidence-summon).

### storm_cantor / Peal

`Move 1` · Time 6

Catalog `peal`. Actions in order: `move_toward`. [Enemy data](../../data/enemies.json#L2009)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).

### storm_capacitor / Charge

`Charge +1` · Time 4

Catalog `charge`. Actions in order: `gain_charge`. [Enemy data](../../data/enemies.json#L3167)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Charge +1` — **True** [cap_gain](#evidence-cap-gain).
- Tooltip `At 3 Charge, this enemy's next attack is Arc Lash.` — **True** [cap_threshold](#evidence-cap-threshold).
- Tooltip `Shock removes 1 Charge.` — **True** [cap_shock](#evidence-cap-shock).

### storm_capacitor / Arc Lash

`Arc 6, Range 4, 3 extra hits` · Time 5

Catalog `discharge`. Actions in order: `chain_discharge, reset_charge`. [Enemy data](../../data/enemies.json#L3167)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Arc 6, Range 4, 3 extra hits` — **True** [cap_lash](#evidence-cap-lash).
- Tooltip `hits the nearest target within 4 tiles for 6 damage` — **True** [cap_lash](#evidence-cap-lash).
- Tooltip `hits up to 3 more, each adjacent to the prior target and taking 1 less damage` — **True** [cap_lash](#evidence-cap-lash).

### tharokh / Faultline

`Each Worldspine: Burst 8, then Ranged 4 · Range 4` · Time 6

Catalog `faultline`. Actions in order: `terrain_burst, ranged`. [Enemy data](../../data/enemies.json#L939)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Marked` — **True** [marked](#evidence-marked).
- Tooltip `Marked tiles show where this enemy acts on its next turn.` — **True** [marked](#evidence-marked).
- Token `Burst 8` — **True** [worldspine](#evidence-worldspine).
- Tooltip `Destroy the target, then deal 8 damage on that tile and each adjacent tile.` — **True** [burst_definition](#evidence-burst-definition).
- Token `each Worldspine` — **True** [worldspine](#evidence-worldspine).
- Tooltip `This enemy Bursts each surviving Worldspine.` — **True** [worldspine](#evidence-worldspine).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Summary `Each Worldspine: Burst 8, then Ranged 4 · Range 4` — **True** [worldspine](#evidence-worldspine).

### vaeloryx / Skyhook

`Move 2 · Ranged 4 · Range 4 · Pull 2` · Time 5

Catalog `skyhook`. Actions in order: `move_toward, ranged`. [Enemy data](../../data/enemies.json#L1190)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Ranged 4` — **True** [attack](#evidence-attack).
- Tooltip `Deal 4 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 4` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).
- Token `Pull 2` — **True** [force](#evidence-force).
- Tooltip `Move the target 2 tiles straight toward the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### veilbound_acolyte / Closing Shade

`Move 2 · Melee 1` · Time 7

Catalog `closing_shade`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L1691)

- Time `Time 7` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 1` — **True** [attack](#evidence-attack).
- Tooltip `Deal 1 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### veilbound_acolyte / Shroudstep

`Retreat 2` · Time 6

Catalog `shroudstep`. Actions in order: `move_away`. [Enemy data](../../data/enemies.json#L1691)

- Time `Time 6` — **True** [clock](#evidence-clock).
- Token `Retreat 2` — **True** [retreat](#evidence-retreat).
- Tooltip `This enemy moves up to 2 tiles away from its target.` — **True** [retreat](#evidence-retreat).

### veilbound_acolyte / Veil Needle

`Ranged 1 · Range 2` · Time 7

Catalog `veil_needle`. Actions in order: `ranged`. [Enemy data](../../data/enemies.json#L1691)

- Time `Time 7` — **True** [clock](#evidence-clock).
- Token `Ranged 1` — **True** [attack](#evidence-attack).
- Tooltip `Deal 1 damage` — **True** [attack](#evidence-attack).
- Tooltip `to a target within Range and line of sight.` — **True** [ranged](#evidence-ranged).
- Token `Range 2` — **True** [range](#evidence-range).
- Tooltip `Maximum distance to the target in tiles, counted without diagonals.` — **True** [range](#evidence-range).

### warden / Bulwark

`Block 6` · Time 5

Catalog `bulwark`. Actions in order: `guard_ally`. [Enemy data](../../data/enemies.json#L247)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Block 6` — **True** [block](#evidence-block).
- Tooltip `Block absorbs damage` — **True** [block_damage](#evidence-block-damage).
- Tooltip `until the start of the holder's next turn` — **True** [block_end](#evidence-block-end).

### warden / Marching Blow

`Move 1 · Melee 9` · Time 5

Catalog `marching_blow`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L247)

- Time `Time 5` — **True** [clock](#evidence-clock).
- Token `Move 1` — **True** [move](#evidence-move).
- Tooltip `Walk up to 1 tile.` — **True** [move](#evidence-move).
- Token `Melee 9` — **True** [attack](#evidence-attack).
- Tooltip `Deal 9 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### wick_shade / Hooking Grasp

`Move 2 · Melee 2 · Pull 1` · Time 4

Catalog `drift`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2648)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).
- Token `Pull 1` — **True** [force](#evidence-force).
- Tooltip `Move the target 1 tile straight toward the source, causing a Collision if blocked.` — **True** [force](#evidence-force).

### wick_shade / Grasp

`Move 3 · Melee 2` · Time 4

Catalog `grasp`. Actions in order: `move_toward, melee`. [Enemy data](../../data/enemies.json#L2648)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 3` — **True** [move](#evidence-move).
- Tooltip `Walk up to 3 tiles.` — **True** [move](#evidence-move).
- Token `Melee 2` — **True** [attack](#evidence-attack).
- Tooltip `Deal 2 damage` — **True** [attack](#evidence-attack).
- Tooltip `to an adjacent target or a target within the card's Range.` — **True** [melee](#evidence-melee).

### wick_shade / Snuff

`Move 2 · Snuff brazier` · Time 4

Catalog `snuff`. Actions in order: `move_toward`. [Enemy data](../../data/enemies.json#L2648)

- Time `Time 4` — **True** [clock](#evidence-clock).
- Token `Move 2` — **True** [move](#evidence-move).
- Tooltip `Walk up to 2 tiles.` — **True** [move](#evidence-move).
- Token `Snuff brazier` — **True** [snuff_wick](#evidence-snuff-wick).
- Tooltip `@pattern(diamond:2) Enter the brazier's tile to relight the brazier and restore Light on these tiles.` — **True** [brazier_relight](#evidence-brazier-relight).

## Wording inventory

Current rows

- Razor Dive uses `Range 1 of the dive trail behind this enemy` and the generated `Along approach +1`. Both describe a translated footprint with invented path language.
- Shatterstorm has `Mantle fuels range` in the generated token. Its diagram uses `Ring` internally. The Grimoire displays the authored range wording.
- Whiteout Lance has `Cross 3` as the generated diagram label. Hollow Gale and Eye of the Storm have generated `Ring 1–2` and `Ring 2–5` diagram labels. The Grimoire displays diagrams.
- Groundsplit uses `Each Outcrop · within 2`, with no unit after `2`. Rime Needle uses `At lane end`. Rime Trail uses `Trail`.
- Join the Choir and Lay the Choir use `linked tiles` and `Extends existing Electrified toward its target`. Field Brace has `Shape Ground`. Arc Lash uses `extra hits` as a compact label for its jumps.
- Other wording outside the style table includes `card’s Range` on enemy Melee, `each enemy that hits you` on enemy Retaliate, and the titleless `Its Burst deals 2 more` in Kindle.
- The three specified word changes remove `Along approach +1` from Gust Shrike and `Snuff refuge` from the brazier chip. `Dive wake`, `Shadow sweep`, `Spire pulse`, `Connected network` and `Marked tiles · Expended` remain in formatter branches with no matching current catalog row. They were not exercised as saved intents.

## Evidence key

### Evidence ambush

**True.** The next intent is the authored Ambush. It can Blink to adjacency before the strike. [Engine path](../../scripts/enemy_mechanics/stalker.gd#L61)

### Evidence area

**True.** The move has multiple authored impact tiles. The nominal Area chip denotes that footprint. [Engine path](../../scripts/combat_engine.gd#L4760)

### Evidence area-committed

**True.** The offsets represent the geometry on open ground. The live calculation clips blocked lanes or shifts the committed area as applicable. [Engine path](../../scripts/committed_pattern_shapes.gd#L48)

### Evidence area-damage

**True.** The committed or scripted area applies its base damage through the board hit dispatcher. [Engine path](../../scripts/guardian_combat_rules.gd#L352)

### Evidence area-icefall

**True.** Icefall's authored three-tile move marks a line across the hero. The diagram represents the open-board area before filtering. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L32)

### Evidence area-lob

**True.** The Lob diagram uses the center and its four side-adjacent tiles for the ordinary variant. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L32)

### Evidence area-mirror

**UNTESTED.** The generic Area token has no explicit offsets. The special resolver uses a four-tile line, but the exact generic chip geometry was not verified in the native plate. [Engine path](../../scripts/enemy_mechanics/reflect.gd#L104)

### Evidence area-ring

**True.** The drawn offsets represent the radial area measured from the boss body and honor the authored minimum and maximum reach. [Engine path](../../scripts/committed_pattern_shapes.gd#L75)

### Evidence attack

**True.** The action passes its base damage to the attack resolver. The token uses the raw catalog value. [Engine path](../../scripts/combat_engine.gd#L6793)

### Evidence block

**True.** The block or guard action adds the authored amount to the eligible recipient. [Engine path](../../scripts/combat_engine.gd#L866)

### Evidence block-damage

**True.** Block absorbs ordinary damage before Health. [Engine path](../../scripts/combat_engine.gd#L5176)

### Evidence block-end

**True.** Enemy activation start clears Block for its holder. [Engine path](../../scripts/combat_engine.gd#L8014)

### Evidence brazier-relight

**True.** The hero's arrival on the brazier restores Light in Last Light and Noctyrax encounters. [Engine path](../../scripts/dragon_combat_rules.gd#L221)

### Evidence burrow

**True.** Burrow marks the hero's current tile and sets the Grub’s burrowed flag. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L34)

### Evidence burrow-target

**False.** Direct attacks and movement keywords are denied. Quake and several area paths can still reach a burrowed unit. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L15)

### Evidence burst-definition

**True.** The Burst spends the surviving Worldspine on its center and reaches adjacent tiles under the action’s radius 1. [Engine path](../../scripts/combat_engine.gd#L6984)

### Evidence cap-gain

**True.** Charge advances by one, capped at three. [Engine path](../../scripts/enemy_mechanics/capacitor.gd#L116)

### Evidence cap-lash

**True.** The first hit chooses the nearest eligible target within four tiles for six base damage. Up to three adjacent jumps follow, with one less base damage per jump. [Engine path](../../scripts/enemy_mechanics/capacitor.gd#L74)

### Evidence cap-shock

**True.** A new Shock application removes two Charge, capped at zero. [Engine path](../../scripts/enemy_mechanics/capacitor.gd#L29)

### Evidence cap-threshold

**True.** At three Charge the next selected attack is Arc Lash, provided grounding has not reduced Charge first. [Engine path](../../scripts/enemy_mechanics/capacitor.gd#L23)

### Evidence cinder-burst

**True.** Crownfire Bursts only the surviving Fire from this dragon's last Cinder Marks. Its later Move and Melee resolve separately. [Engine path](../../scripts/combat_engine.gd#L7091)

### Evidence cinder-fuel

**False.** A Mark with replaced or removed Fire no longer Bursts. Crownfire resolves the surviving committed Fire fuel. [Engine path](../../scripts/boss_area_rules.gd#L182)

### Evidence cinder-hit

**True.** The move hits on the committed Cinder Marks and leaves Fire. The other catalog actions keep their own order. [Engine path](../../scripts/combat_engine.gd#L7067)

### Evidence cinder-size

**False.** Seven is the permitted footprint budget. Tile restrictions and required safe footprints can yield fewer marks. [Engine path](../../scripts/dragon_pressure_fields.gd#L14)

### Evidence clock

**True.** The scheduler reads the move’s authored Time and spends it across the intent. [Engine path](../../scripts/combat_engine.gd#L6334)

### Evidence conducted

**True.** The route, including a relay or chain hop, must count as Electrified-assisted for Shock +1. [Engine path](../../scripts/board_attack_rules.gd#L134)

### Evidence connector-count

**False.** The number is an upper limit. The connector can start from its own tile and can lay fewer tiles when floor, reach or line of sight run out. [Engine path](../../scripts/guardian_combat_rules.gd#L698)

### Evidence connector-existing

**False.** With no valid existing Electrified seed the placement falls back to its own origin. Existing Electrified is optional. [Engine path](../../scripts/guardian_combat_rules.gd#L698)

### Evidence connector-range

**True.** New conductor tiles are bounded by the placement action’s range and line of sight. [Engine path](../../scripts/guardian_combat_rules.gd#L698)

### Evidence crag-area

**False.** The engine spreads around surviving owned Outcrops and explicitly excludes their center tiles. The tooltip says each floor tile within reach. [Engine path](../../scripts/guardian_combat_rules.gd#L33)

### Evidence dive

**True.** The open-board path witness measured five route tiles and eleven tiles at orthogonal distance one. Shape, forecast and impact matched. [Engine path](../../scripts/committed_pattern_shapes.gd#L90)

### Evidence dive-every

**False.** On obstructed boards radial_shape filters to passable tiles with line of sight. 'Every tile' overstates the measured reach. [Engine path](../../scripts/committed_pattern_shapes.gd#L75)

### Evidence eclipse-damage

**True.** The Eclipse strike hits the hero and illusions that occupy the held Marked area. [Engine path](../../scripts/combat_engine.gd#L7188)

### Evidence eclipse-duration

**True.** The resolver installs the authored duration in the hero-activation counter. [Engine path](../../scripts/combat_engine.gd#L7188)

### Evidence eclipse-order

**False.** Eclipse is started in state before its damage resolves. The counter lasts two hero activations. [Engine path](../../scripts/combat_engine.gd#L7188)

### Evidence electrified

**True.** The Lightning-card glossary condition expands through the connected Electrified component. [Engine path](../../scripts/combat_engine.gd#L1411)

### Evidence erupt

**True.** Erupt searches from the mark for a legal emergence tile when the mark cannot be occupied. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L138)

### Evidence erupt-damage

**True.** The authored damage is dealt to occupants of the marked tile. The separate adjacent Push uses the actual landing tile. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L34)

### Evidence erupt-rubble

**True.** Erupt places Rubble at the actual emergence tile after resolving its displacement. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L107)

### Evidence expend-ally

**False.** Field Brace removes the elemental ground from the guarded ally’s footprint. 'Your tile' names the wrong recipient and 'Shape Ground' is not a ground kind. [Engine path](../../scripts/combat_engine.gd#L1805)

### Evidence expend-self

**True.** The regular Block action clears Ice from the source’s footprint. [Engine path](../../scripts/combat_engine.gd#L5086)

### Evidence expose

**True.** The hit adds the specified Expose to the target under the status rules. [Engine path](../../scripts/combat_engine.gd#L4899)

### Evidence expose-effect

**True.** The next damaging hit spends Expose and adds the recorded amount. [Engine path](../../scripts/combat_engine.gd#L5279)

### Evidence fade

**True.** The destination prefers the tile behind the hero, then checks the other adjacent tiles within the authored reach. [Engine path](../../scripts/enemy_mechanics/stalker.gd#L22)

### Evidence fade-absolute

**False.** Fade can remain at its starting tile if all adjacent destinations are blocked, out of range or movement is disabled. [Engine path](../../scripts/enemy_mechanics/stalker.gd#L61)

### Evidence fire

**True.** Default Fire uses 2 entry damage and 3 start damage on affected units. [Engine path](../../scripts/combat_engine.gd#L12114)

### Evidence force

**True.** The rider passes its direction and tile allowance to shared force. A qualifying obstruction can cause Collision. [Engine path](../../scripts/combat_engine.gd#L7453)

### Evidence force-direction

**False.** The committed action sets a fixed forward or reverse force direction, so an off-axis victim does not necessarily move straight toward or away from the source. [Engine path](../../scripts/guardian_combat_rules.gd#L179)

### Evidence force-erupt

**False.** The central victim uses the first legal adjacent relocation and bypasses the shared Collision path. Only neighbors use the normal Push resolver. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L34)

### Evidence force-gust

**False.** Call the Wind installs a rule that moves eligible units downwind on a beat. It does not Push a single target away from the source on the action. [Engine path](../../scripts/battlefield_rules/gust.gd#L126)

### Evidence gale-push

**True.** Hollow Gale supplies the Push 1 rider for each eligible hit from the committed attack. [Engine path](../../scripts/guardian_combat_rules.gd#L352)

### Evidence gale-unit

**False.** Hollow Gale affects tiles in a ring around a two-tile body. The attack does not damage each unit within two tiles, including the source or allied enemies. [Engine path](../../scripts/committed_pattern_shapes.gd#L75)

### Evidence ground

**True.** The authored ground field is passed to ground placement on the move's affected tiles, subject to placement legality. [Engine path](../../scripts/board_attack_rules.gd#L19)

### Evidence gust-count

**True.** The ordinary Call installs the authored number of Gust beats and push distance. [Engine path](../../scripts/battlefield_rules/dispatcher.gd#L177)

### Evidence gust-each

**False.** The rule filters Anchored, buried and dead units, then calls shared force for the eligible roster. [Engine path](../../scripts/battlefield_rules/gust.gd#L105)

### Evidence heal

**True.** The heal adds the authored amount to the eligible recipient, capped by missing Health. [Engine path](../../scripts/combat_engine.gd#L4097)

### Evidence ice

**True.** Default Ice gives Expose 2 on entry or turn start. [Engine path](../../scripts/combat_engine.gd#L12114)

### Evidence ice-condition

**True.** The target’s Ice at hit time is sampled for the rider. Ice placed by the action happens later. [Engine path](../../scripts/board_attack_rules.gd#L133)

### Evidence icefall

**True.** Icefall hits its recorded tiles on the landing turn for the follow-up damage and then places Ice. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L200)

### Evidence icefall-condition

**True.** The landing samples existing Ice for Stagger before placing new Ice. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L200)

### Evidence icefall-range

**True.** Availability checks the authored distance before marking. The mark explicitly ignores line of sight. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L59)

### Evidence immobilize

**True.** Manacle Pin supplies the immobilize rider and the player action gate blocks Move, Blink and Swap. [Engine path](../../scripts/combat_engine.gd#L1174)

### Evidence kindle

**True.** Kindle adds the catalog value to death_burst_bonus. Death Burst adds it to the base damage. [Engine path](../../scripts/enemy_mechanics/kindle.gd#L5)

### Evidence lane-end

**True.** Needle uses the last surviving lane tile for terminal Ice. [Engine path](../../scripts/guardian_combat_rules.gd#L406)

### Evidence layout-ground

**True.** The placement action writes the indicated ground on its declared tiles. [Engine path](../../scripts/guardian_combat_rules.gd#L352)

### Evidence lob-fire

**True.** Each placeable impacted tile becomes Fire after the held damage resolves. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L233)

### Evidence lob-hit

**True.** The held center takes 5 base damage and its adjacent tiles take 3 at landing. Fire placement follows the hit loop. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L233)

### Evidence lob-mark

**True.** The ordinary Lob mark is centered on the hero’s tile and schedules the held landing. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L104)

### Evidence mantle-bypass

**True.** Ordinary ground and damage over time go through non-direct damage handling. [Engine path](../../scripts/combat_engine.gd#L12096)

### Evidence mantle-gain

**True.** The action adds two Mantle layers subject to the cap of three. [Engine path](../../scripts/combat_engine.gd#L7119)

### Evidence mantle-hit

**True.** On an ordinary direct hit, Mantle spends a layer and absorbs the damage. [Engine path](../../scripts/combat_engine.gd#L5176)

### Evidence mantle-range

**True.** At declaration, Shatterstorm uses base range 1 plus each existing layer, capped at 4. Resolution clears remaining Mantle. [Engine path](../../scripts/guardian_combat_rules.gd#L547)

### Evidence mantle-warning

**False.** Removing Mantle after declaration does not shrink the committed warning. The held stamp is reused on resolution. [Engine path](../../scripts/boss_area_rules.gd#L97)

### Evidence mark-bramble

**False.** Thornwall can keep a pending mark beyond the next source turn when the Upheaval fuel boundary has not cleared. [Engine path](../../scripts/enemy_mechanics/bramble.gd#L70)

### Evidence mark-crag

**False.** Groundsplit recomputes the footprint from surviving owned Outcrops. Removing an Outcrop can remove its warned coverage before impact. [Engine path](../../scripts/guardian_combat_rules.gd#L421)

### Evidence mark-next

**True.** The mark records the tiles for the following landing action. [Engine path](../../scripts/enemy_mechanics/marked_strike.gd#L82)

### Evidence marked

**True.** The displayed marks are committed, then the corresponding resolver acts on the held tiles. [Engine path](../../scripts/boss_area_rules.gd#L97)

### Evidence melee

**True.** An ordinary attack checks the target from the attacker's footprint against its melee reach. [Engine path](../../scripts/combat_engine.gd#L4721)

### Evidence melee-area

**False.** This is area damage. The resolver can hit several occupants at once and uses the area footprint instead of a card's melee reach. [Engine path](../../scripts/combat_engine.gd#L4760)

### Evidence melee-crag

**False.** Groundsplit hits the surviving owned Outcrops' areas, independently of distance to Craghide or any selected target. [Engine path](../../scripts/guardian_combat_rules.gd#L33)

### Evidence melee-dive

**False.** The swept footprint hits off-route tiles based on every route anchor, even outside ordinary melee reach of the final enemy tile. [Engine path](../../scripts/committed_pattern_shapes.gd#L90)

### Evidence melee-mirror

**False.** Refraction strikes a four-tile lane and takes its base and stored reflected damage from its special resolver. [Engine path](../../scripts/enemy_mechanics/reflect.gd#L157)

### Evidence move

**True.** The action’s range is a movement allowance. The route spends it moving toward a target or setting up the follow-up. [Engine path](../../scripts/combat_engine.gd#L5091)

### Evidence move-trail

**True.** Rime Trail writes Ice along the actual movement path, stopping before the endpoint. [Engine path](../../scripts/combat_engine.gd#L4966)

### Evidence pierce

**True.** The action bypasses Block and Stoneskin through the Pierce check. [Engine path](../../scripts/combat_engine.gd#L6446)

### Evidence placement

**False.** The action places ground and resolves no ranged damage or attack on a target. [Engine path](../../scripts/guardian_combat_rules.gd#L352)

### Evidence range

**True.** Ordinary target reach is orthogonal grid distance from the source footprint. [Engine path](../../scripts/combat_engine.gd#L4721)

### Evidence range-ring-tip

**False.** This number is the outer extent from the body for an area around the enemy. The move does not select a target at that distance. [Engine path](../../scripts/committed_pattern_shapes.gd#L75)

### Evidence range-shape

**True.** The chip's number is the authored default reach of the displayed area. [Engine path](../../scripts/guardian_combat_rules.gd#L553)

### Evidence range-shape-tip

**False.** This number controls forward extent or area geometry. It is not a maximum orthogonal distance to a selected target. [Engine path](../../scripts/committed_pattern_shapes.gd#L48)

### Evidence ranged

**True.** Ordinary ranged targeting checks range and line of sight. [Engine path](../../scripts/combat_engine.gd#L4721)

### Evidence ranged-committed

**False.** The hit uses an area or Marked footprint, which can hit several occupants. It does not select a single target at impact or necessarily recheck line of sight. [Engine path](../../scripts/boss_area_rules.gd#L97)

### Evidence ranged-guardian

**False.** This hits a lane at its resolved origin. Multiple occupants can be hit on the same action. [Engine path](../../scripts/guardian_combat_rules.gd#L421)

### Evidence razor

**False.** Razor Dive's held footprint follows the planned route and translates to the actual endpoint when interrupted. It can hit away from the traveled route. [Engine path](../../tests/dragon_committed_patterns_test.gd#L209)

### Evidence relay

**False.** Lightning has an Electrified relay path. The resolver can strike without a direct in-range line to that target. [Engine path](../../scripts/combat_engine.gd#L6793)

### Evidence retaliate

**True.** Echo adds the authored retaliation amount. The enemy clears it on activation start. [Engine path](../../scripts/combat_engine.gd#L8014)

### Evidence retaliate-victim

**False.** The target is the hero when the hero hits the Mimic. An adjacent ranged hit can also trigger the reaction. [Engine path](../../scripts/retaliate_rules.gd#L140)

### Evidence retreat

**True.** The move-away action plans and spends the stated retreat allowance. [Engine path](../../scripts/combat_engine.gd#L10907)

### Evidence rubble

**True.** Leaving Rubble costs 2 Movement under the base rules. Flying and movement overrides are separate rules. [Engine path](../../scripts/board_surface_rules.gd#L170)

### Evidence self-grub

**True.** Erupt applies self_expose to the surviving Grub. The hero hit and displacement have no Expose rider. [Engine path](../../scripts/enemy_mechanics/burrow.gd#L109)

### Evidence self-reaver

**True.** The committed attack applies self_expose to the source, once, through the guardian resolver. [Engine path](../../scripts/guardian_combat_rules.gd#L417)

### Evidence shock

**True.** The hit applies the printed Shock duration. Capacitor Arc adds 1 when its route uses an Electrified conductor. [Engine path](../../scripts/board_attack_rules.gd#L134)

### Evidence shock-effect

**False.** Enemy Shock cancels attacks while ordinary support can resolve. Hero Shock also permits explicit maneuver actions alongside Move and Blink. [Engine path](../../scripts/combat_engine.gd#L1172)

### Evidence sky-count

**False.** Nine is the maximum. The selector can return fewer eligible tiles to preserve a safe route. [Engine path](../../scripts/dragon_scatter_pattern.gd#L8)

### Evidence sky-hit

**True.** The resolver uses the committed scatter tiles for 5 base damage and places Electrified. [Engine path](../../scripts/combat_engine.gd#L6886)

### Evidence sky-random

**False.** The hero tile is prioritized and the rest use a deterministic seed-and-cycle hash with safety constraints, not independent random hits. [Engine path](../../scripts/dragon_scatter_pattern.gd#L8)

### Evidence snuff-coil

**True.** Night Coil picks the brazier nearest the hero, records its id and extinguishes it. Entering its tile before Eclipse restores Light. [Engine path](../../scripts/dragon_combat_rules.gd#L101)

### Evidence snuff-guardian

**True.** Snuff extinguishes the recorded Guardian brazier. Last Procession cleanup relights it and removes outage helpers, including on a skipped turn. [Engine path](../../scripts/guardian_combat_rules.gd#L40)

### Evidence snuff-wick

**True.** The move targets a lit relightable brazier and puts it out if the Shade reaches it. Entering its tile restores the brazier’s Light through the room relight rule. [Engine path](../../scripts/enemy_mechanics/snuff.gd#L129)

### Evidence stagger

**True.** The rider requests the printed Time delay, subject to the game's normal per-turn Stagger bounds. [Engine path](../../scripts/card_keyword_rules.gd#L247)

### Evidence stoneskin

**True.** The action adds Stoneskin. Damage spends Block before Stoneskin, and activation does not clear Stoneskin. [Engine path](../../scripts/combat_engine.gd#L5176)

### Evidence summon

**True.** The authored minion is the type spawned on the legal summon tiles. The live count is bounded by slots and cap. [Engine path](../../scripts/combat_engine.gd#L6892)

### Evidence summon-guardian

**True.** Guardian summons spawn the named helper if the declared tile is legal and its cap permits. [Engine path](../../scripts/guardian_combat_rules.gd#L323)

### Evidence summon-reward

**True.** Eligible successful summons bank one Card Play for the hero's next turn. [Engine path](../../scripts/summon_card_play_rules.gd#L15)

### Evidence upheaval

**True.** Thornwall stores a three-Health Outcrop raise. Eligible occupants move to legal adjacent floor and blocked placements can fail. [Engine path](../../scripts/enemy_mechanics/bramble.gd#L90)

### Evidence worldspine

**True.** The Burst uses the remaining committed Worldspines, destroys them and applies Burst 8 before the separate Range 4 strike. [Engine path](../../scripts/combat_engine.gd#L6984)
