# Player-facing text and tooltip audit

Inventory only: game text, data, UI, analytics and saves are unchanged.

## Method and coverage

6136 source/derived string records. Occurrences remain separate; generated per-card tooltip variants are counted separately from their definition templates. Code ids use file, owning scope, literal digest and duplicate ordinal, so moving a source line does not change its id. Changing copy intentionally changes a code id. Data ids use JSON pointers.

The lexical scanner visits every runtime GDScript, scene, project title and data file. It excludes comments, paths, identifiers, enum keys, colors and developer diagnostics. `coverage.json` retains every exclusion, source hash and dynamic display expression for review; this is an auditable static inventory, not a proof that all branches have been rendered. Exact literal fragments and complete format expressions/operands are preserved. Runtime export invokes production helpers for card token rows, tooltip overrides, relic redirects and formatted descriptions. Unbounded state/upgrade combinations remain parameterized, with the owning code cited.

Word counts ignore BBCode control tags; inline icon concepts, numeric values and format placeholders count as words. Thresholds: top 15 per surface, tooltips over 35 words, rules over 3 shaped lines. Counts are source occurrences/derived variants, not unique prose sentences.

## String counts by surface

| Surface | Source/derived records |
| --- | ---: |
| card name | 309 |
| card rules | 618 |
| card flavour | 0 |
| card tooltip | 1110 |
| keyword tooltip | 557 |
| relic name | 112 |
| relic description | 113 |
| relic tooltip | 168 |
| status/condition tooltip | 186 |
| intent label/tooltip | 194 |
| enemy name/tooltip | 109 |
| event title | 27 |
| event body | 125 |
| event choice | 146 |
| map node | 174 |
| reward screen | 32 |
| shop | 109 |
| chronicle | 67 |
| run-end recap | 108 |
| menus/settings | 109 |
| HUD labels | 836 |
| onboarding/tutorial | 217 |
| confirmation dialogs | 9 |
| error/empty states | 36 |
| equipment | 98 |
| skills | 184 |
| grimoire | 336 |
| dialogue | 43 |
| combat log | 4 |

## Owner's relic finding

Relic choice icons and inline symbols have no hover/focus definitions. Owned relic badges do have a name/description tooltip; icons inside that tooltip do not have independent concept definitions. These are distinct gaps. Legacy relic entries may redirect to another relic at runtime; both raw and resolved names/art are retained.

## Icons without complete tooltips by surface

| Surface | No tooltip | Partial pointer/focus coverage |
| --- | ---: | ---: |
| chronicle relics inline symbols | 50 | 0 |
| owned relic tooltip inline symbols | 50 | 0 |
| relic choice | 112 | 0 |
| relic choice inline symbols | 50 | 0 |
| HUD ability palette | 0 | 30 |
| HUD ability sigil preview | 30 | 0 |
| HUD defiance badge | 0 | 1 |
| HUD header | 0 | 3 |
| HUD labels | 0 | 6 |
| HUD minimap / board exit | 0 | 31 |
| HUD resource meter | 2 | 0 |
| action step tracker | 61 | 0 |
| board status/condition | 0 | 27 |
| card element crest | 0 | 5 |
| card inspection | 0 | 85 |
| card reward | 0 | 85 |
| card role emblem | 5 | 0 |
| card tooltip | 0 | 2 |
| character menu | 0 | 72 |
| character/menu stat chip | 2 | 0 |
| chronicle gear | 0 | 72 |
| chronicle spell list | 0 | 24 |
| controller prompts | 17 | 0 |
| enemy intent | 0 | 33 |
| equipment inspection | 0 | 72 |
| event body inline symbols | 0 | 10 |
| grimoire | 0 | 96 |
| grimoire entry | 0 | 72 |
| grimoire inline symbols | 50 | 0 |
| hand | 0 | 24 |
| map node | 0 | 1 |
| shop | 0 | 96 |
| shop currency / receipt | 1 | 0 |
| skill tree | 0 | 30 |
| skills | 0 | 1 |
| skills inline symbols | 0 | 24 |

Per-icon details, tooltip text/templates, source evidence, pointer/focus differences and inventory ids are in `inventory_icons.json`. Partial is never counted as yes.

## Cards exceeding three lines

Measured headlessly with Godot TextParagraph and the production text font/CardWidget width and font helpers at 100%. Live RunScene helpers supply hand (3 and 8 cards), three-choice reward and equipment-tooltip sizes at 1920×1080. The base card is included for comparison. Exact sizes, font sizes, widths and all counts are in `runtime.json`. This is font/layout proof, not renderer proof. Most cards draw action-token rows instead of prose; other rows are description-fit diagnostics, not visible overflow claims. Upgrades modify action rows and do not rewrite stored prose.

| Card | Base | Hand 3 | Hand 8 | Reward | Equipment tooltip | Prose on face | Inventory id |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
| Discharge | 8 | 8 | 7 | 9 | 7 | no — action rows | `resolved:card:discharge:rules` |
| Worldspine | 9 | 9 | 7 | 9 | 7 | no — action rows | `resolved:card:worldspine:rules` |
| Ball Lightning | 7 | 7 | 7 | 8 | 7 | no — action rows | `resolved:card:ball_lightning:rules` |
| Frost Circuit | 8 | 8 | 7 | 8 | 7 | no — action rows | `resolved:card:frost_circuit:rules` |
| Skybolt | 8 | 7 | 6 | 8 | 6 | no — action rows | `resolved:card:skybolt:rules` |
| Squall | 8 | 8 | 6 | 8 | 6 | no — action rows | `resolved:card:squall_shot:rules` |
| Cinder Bloom | 6 | 6 | 6 | 7 | 6 | no — action rows | `resolved:card:cinder_bloom:rules` |
| Cyclone Seal | 7 | 7 | 6 | 7 | 6 | no — action rows | `resolved:card:cyclone_seal:rules` |
| Flash Powder | 6 | 6 | 5 | 7 | 5 | no — action rows | `resolved:card:flash_powder:rules` |
| Immolation | 6 | 6 | 6 | 7 | 6 | no — action rows | `resolved:card:immolation:rules` |
| Shattered Reflection | 7 | 7 | 6 | 7 | 6 | no — action rows | `resolved:card:shattered_reflection:rules` |
| Storm Beacon | 6 | 6 | 6 | 7 | 6 | no — action rows | `resolved:card:storm_beacon:rules` |
| Tectonic Maul | 6 | 6 | 5 | 7 | 5 | no — action rows | `resolved:card:tectonic_maul:rules` |
| Thunderline | 6 | 6 | 5 | 7 | 5 | no — action rows | `resolved:card:thunderline:rules` |
| Wind Shear | 6 | 6 | 5 | 7 | 5 | no — action rows | `resolved:card:wind_shear:rules` |
| Crystal Mantle | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:crystal_mantle:rules` |
| Doppelganger | 5 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:doppelganger:rules` |
| Earthen Rampart | 6 | 6 | 6 | 6 | 6 | no — action rows | `resolved:card:earthen_rampart:rules` |
| Frost Heave | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:frost_heave:rules` |
| Grounding | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:grounding:rules` |
| Headlong | 6 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:headlong:rules` |
| Magma Vent | 5 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:magma_vent:rules` |
| Meteorfall | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:meteorfall:rules` |
| Mirror Image | 5 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:mirror_image:rules` |
| Plasma Arc | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:plasma_arc:rules` |
| Powder Keg | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:powder_keg:rules` |
| Reflected Threat | 5 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:reflected_threat:rules` |
| Rite of Tailwinds | 6 | 6 | 6 | 6 | 6 | yes | `resolved:card:rite_of_tailwinds:rules` |
| Rite of the Storm | 6 | 6 | 5 | 6 | 5 | yes | `resolved:card:rite_of_the_storm:rules` |
| Rockburst | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:rockburst:rules` |
| Salamander Heart | 6 | 6 | 5 | 6 | 5 | yes | `resolved:card:salamander_heart:rules` |
| Spark Dart | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:spark_dart:rules` |
| Spike Mantle | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:spike_mantle:rules` |
| Storm Jar | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:storm_jar:rules` |
| Thunderstone | 5 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:thunderstone:rules` |
| Worldbreak | 6 | 6 | 5 | 6 | 5 | no — action rows | `resolved:card:worldbreak:rules` |
| Worldroot Stride | 6 | 5 | 5 | 6 | 5 | no — action rows | `resolved:card:worldroot_stride:rules` |
| Basalt Guard | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:basalt_guard:rules` |
| Blood Price | 5 | 4 | 4 | 5 | 4 | no — action rows | `resolved:card:blood_price:rules` |
| Borrowed Spark | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:borrowed_spark:rules` |
| Caltrops | 4 | 4 | 3 | 5 | 3 | no — action rows | `resolved:card:caltrops:rules` |
| Censer Swing | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:censer_swing:rules` |
| Chain Bolt | 4 | 4 | 4 | 5 | 4 | no — action rows | `resolved:card:chain_bolt:rules` |
| Cinder Trail | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:cinder_trail:rules` |
| Lantern Rain | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:cinderburst:rules` |
| Dust Devil | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:dust_devil:rules` |
| Lantern Rain | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:ember_rain:rules` |
| Empty Husk | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:empty_husk:rules` |
| Eye of the Storm | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:eye_of_the_storm:rules` |
| Fan the Flames | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:fan_the_flames:rules` |
| Flashsteam | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:flashsteam:rules` |
| Frost Nova | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:frost_nova:rules` |
| Glacier Pin | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:glacier_pin:rules` |
| Hall of Mirrors | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:hall_of_mirrors:rules` |
| Ice Sculpture | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:ice_sculpture:rules` |
| Iron Wheel | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:iron_wheel:rules` |
| Lodestone Reversal | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:lodestone_reversal:rules` |
| Mirror Feint | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:mirror_feint:rules` |
| Petrify | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:petrify:rules` |
| Phoenix Cleave | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:phoenix_cleave:rules` |
| Rimeplate Lock | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:rimeplate_lock:rules` |
| Rite of Noon | 4 | 4 | 4 | 5 | 4 | yes | `resolved:card:rite_of_noon:rules` |
| Rooted Kick | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:rooted_kick:rules` |
| Royal Bramble | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:royal_bramble:rules` |
| Shatter | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:shatter:rules` |
| Shatter Swing | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:shatter_swing:rules` |
| Shatterline | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:shatterline:rules` |
| Smelling Salts | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:smelling_salts:rules` |
| Spark Focus | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:spark_focus:rules` |
| Static Mantle | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:static_mantle:rules` |
| Storm Relay | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:storm_relay:rules` |
| Storm Salvo | 4 | 4 | 4 | 5 | 4 | no — action rows | `resolved:card:storm_salvo:rules` |
| Stormstring Shot | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:stormstring_shot:rules` |
| Unpick | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:threadbare_guard:rules` |
| Threaded Path | 4 | 4 | 3 | 5 | 3 | no — action rows | `resolved:card:threaded_path:rules` |
| Thunderclap | 5 | 5 | 5 | 5 | 5 | no — action rows | `resolved:card:thunderclap:rules` |
| Tremor | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:tremor:rules` |
| Volt Surge | 5 | 5 | 4 | 5 | 4 | no — action rows | `resolved:card:volt_surge:rules` |
| Anchor Slam | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:anchor_slam:rules` |
| Beacon | 4 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:beacon:rules` |
| Blade Dance | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:blade_dance:rules` |
| Blessed Salve | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:blessed_salve:rules` |
| Blinding Bash | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:blinding_bash:rules` |
| Butcher Chop | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:butcher_chop:rules` |
| Capacitor | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:capacitor:rules` |
| Chain Lock | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:chain_lock:rules` |
| Changing Winds | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:changing_winds:rules` |
| Charged Orb | 4 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:charged_orb:rules` |
| Cinder Fusillade | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:cinder_fusillade:rules` |
| Cinder Patch | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:cinder_patch:rules` |
| Cinder Wall | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:cinder_wall:rules` |
| Cinderweave Guard | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:cinderweave_guard:rules` |
| Cloudstep Loop | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:cloudstep_loop:rules` |
| Couched Lance | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:couched_lance:rules` |
| Daybreak | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:daybreak:rules` |
| Ember Ward | 4 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:ember_ward:rules` |
| Fault Strike | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:fault_strike:rules` |
| Flame Jet | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:flame_jet:rules` |
| Forked Nock | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:forked_nock:rules` |
| Frost Snare | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:frost_snare:rules` |
| Frozen Bite | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:frozen_bite:rules` |
| Galvanize | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:galvanize:rules` |
| Grapple | 4 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:grapple:rules` |
| Grave Cleave | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:grave_cleave:rules` |
| Quarry Dust | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:grave_dust_satchel:rules` |
| Guiding Flare | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:guiding_flare:rules` |
| Low Sweep | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:hamstring_shot:rules` |
| Spur Trip | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:hamstring_slice:rules` |
| Headsman's Toll | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:headsmans_toll:rules` |
| Hotfoot | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:hotfoot:rules` |
| Hourglass Sand | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:hourglass_sand:rules` |
| Hurl Spear | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:hurl_spear:rules` |
| Hush of Winter | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:hush_of_winter:rules` |
| Icebound Chains | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:icebound_chains:rules` |
| Inferno Ritual | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:inferno_ritual:rules` |
| Kite Bash | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:kite_bash:rules` |
| Lantern Shot | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:lantern_shot:rules` |
| Main-Gauche | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:main_gauche:rules` |
| Molten Reach | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:molten_reach:rules` |
| Nail Parry | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:nail_parry:rules` |
| Overclock | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:overclock:rules` |
| Overhead Smash | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:overhead_smash:rules` |
| Palm Strike | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:palm_strike:rules` |
| Pitch Firebomb | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:pitch_firebomb:rules` |
| Pyroclasm | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:pyroclasm:rules` |
| Quarry Step | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:quarry_step:rules` |
| Raise Stone | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:raise_stone:rules` |
| Razor Gale | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:razor_gale:rules` |
| Refraction | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:refraction:rules` |
| Rime Hack | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:rime_hack:rules` |
| Rime Shard | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:rime_shard:rules` |
| Rimefang | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:rimefang:rules` |
| Rite of Hoarfrost | 4 | 4 | 3 | 4 | 3 | yes | `resolved:card:rite_of_hoarfrost:rules` |
| Rooted Stance | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:rooted_stance:rules` |
| Scorch | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:scorch:rules` |
| Shield Wall | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:shield_wall:rules` |
| Skate | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:skate:rules` |
| Sleet Squall | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:sleet_squall:rules` |
| Snake Eyes | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:snake_eyes:rules` |
| Spur Spark | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:spur_spark:rules` |
| Static Lash | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:static_lash:rules` |
| Static Pivot | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:static_pivot:rules` |
| Static Rush | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:static_rush:rules` |
| Static Ward | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:static_ward:rules` |
| Stolen Moment | 3 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:stolen_moment:rules` |
| Stone Ward | 4 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:stone_ward:rules` |
| Stonefist | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:stonefist:rules` |
| Sun Flash | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:sun_flash:rules` |
| Sunlance | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:sunlance:rules` |
| Sunpath Stride | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:sunpath_stride:rules` |
| Thorn Skewer | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:thorn_skewer:rules` |
| Throwing Net | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:throwing_net:rules` |
| Tombsplitter | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:tombsplitter:rules` |
| Voidsilk Molt | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:voidsilk_molt:rules` |
| Vortex | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:vortex:rules` |
| Whetstone | 4 | 3 | 3 | 4 | 3 | no — action rows | `resolved:card:whetstone:rules` |
| White Silence | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:white_silence:rules` |
| Wildfire Halo | 4 | 4 | 4 | 4 | 4 | no — action rows | `resolved:card:wildfire_halo:rules` |
| Windbreak | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:windbreak:rules` |
| Windlass Volley | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:windlass_volley:rules` |
| Witchglass Double | 4 | 4 | 3 | 4 | 3 | no — action rows | `resolved:card:witchglass_double:rules` |

## Tooltips over 35 words

| Words | Surface | Id |
| ---: | --- | --- |
| 39 | relic tooltip | `resolved:relic:fivefold_knot` |
| 37 | relic description | `data:data/relics.json#/fivefold_knot/description` |

## Longest strings per surface

### card name

| Words | Id | Current text |
| ---: | --- | --- |
| 4 | `data:data/cards.json#/eye_of_the_storm/name` | Eye of the Storm |
| 4 | `data:data/cards.json#/rite_of_the_mountain/name` | Rite of the Mountain |
| 4 | `data:data/cards.json#/rite_of_the_pyre/name` | Rite of the Pyre |
| 4 | `data:data/cards.json#/rite_of_the_storm/name` | Rite of the Storm |
| 3 | `data:data/cards.json#/brace_the_spear/name` | Brace the Spear |
| 3 | `data:data/cards.json#/break_the_veil/name` | Break the Veil |
| 3 | `data:data/cards.json#/catch_the_wind/name` | Catch the Wind |
| 3 | `data:data/cards.json#/crack_the_whip/name` | Crack the Whip |
| 3 | `data:data/cards.json#/fan_of_knives/name` | Fan of Knives |
| 3 | `data:data/cards.json#/fan_the_flames/name` | Fan the Flames |
| 3 | `data:data/cards.json#/hall_of_mirrors/name` | Hall of Mirrors |
| 3 | `data:data/cards.json#/hook_and_hold/name` | Hook and Hold |
| 3 | `data:data/cards.json#/hush_of_winter/name` | Hush of Winter |
| 3 | `data:data/cards.json#/raise_the_anvil/name` | Raise the Anvil |
| 3 | `data:data/cards.json#/rite_of_hoarfrost/name` | Rite of Hoarfrost |

### card rules

| Words | Id | Current text |
| ---: | --- | --- |
| 32 | `data:data/cards.json#/worldspine/description` | Exhaust. Raise a 4-health Worldspine on each empty tile next to a tile within range 3. At the start of each of your turns, each enemy next to a Worldspine takes 3. |
| 32 | `resolved:card:worldspine:rules` | Exhaust. Raise a 4-health Worldspine on each empty tile next to a tile within range 3. At the start of each of your turns, each enemy next to a Worldspine takes 3. |
| 29 | `data:data/cards.json#/cyclone_seal/description` | Exhaust. Choose a tile within range 3. Pull every enemy within 3 of it up to 3 tiles toward it, then deal 6 to each enemy next to it. |
| 29 | `data:data/cards.json#/squall_shot/description` | Deal 2 in a cross at range 3 and push each enemy in it 1 away from the center. The enemy on the center is pushed away from you. |
| 29 | `resolved:card:cyclone_seal:rules` | Exhaust. Choose a tile within range 3. Pull every enemy within 3 of it up to 3 tiles toward it, then deal 6 to each enemy next to it. |
| 29 | `resolved:card:squall_shot:rules` | Deal 2 in a cross at range 3 and push each enemy in it 1 away from the center. The enemy on the center is pushed away from you. |
| 27 | `data:data/cards.json#/frost_circuit/description` | Turn an Ice tile within range 3 and all Ice connected to it into Electrified. Deal 2 Lightning damage to each enemy on them and Shock them. |
| 27 | `resolved:card:frost_circuit:rules` | Turn an Ice tile within range 3 and all Ice connected to it into Electrified. Deal 2 Lightning damage to each enemy on them and Shock them. |
| 25 | `data:data/cards.json#/discharge/description` | Choose an Electrified tile within range 4. Deal 5 Lightning damage to each enemy on or next to its connected network, then remove the network. |
| 25 | `data:data/cards.json#/shattered_reflection/description` | Destroy one of your illusions within range 6 to deal 6 to each enemy next to it and create radius-2 Light there for 2 turns. |
| 25 | `resolved:card:discharge:rules` | Choose an Electrified tile within range 4. Deal 5 Lightning damage to each enemy on or next to its connected network, then remove the network. |
| 25 | `resolved:card:shattered_reflection:rules` | Destroy one of your illusions within range 6 to deal 6 to each enemy next to it and create radius-2 Light there for 2 turns. |
| 24 | `data:data/cards.json#/immolation/description` | Detonate 8 on every Fire tile within 1 of you, including yours. You take no damage from it. Empower (2 HP): within 2 instead. |
| 24 | `data:data/cards.json#/rockburst/description` | Destroy an outcrop or crate within range 3 to deal 6 to each enemy next to it, then leave Rubble in a cross there. |
| 24 | `data:data/cards.json#/tectonic_maul/description` | Move 1, then strike for 11, or 15 against a target on Rubble. Leave a cross of Rubble at the impact and Stagger 3. |

### card flavour

| Words | Id | Current text |
| ---: | --- | --- |

### card tooltip

| Words | Id | Current text |
| ---: | --- | --- |
| 30 | `resolved:card:frost_circuit:tooltip:surface_electrified:1` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Turns a Ice tile and every Ice tile connected to it into Electrified. |
| 29 | `resolved:card:powder_keg:tooltip:detonate:3` | When the keg is destroyed by anything, it deals 6 to its tile and each tile next to it: you, illusions, enemies and terrain. Kegs set each other off. |
| 29 | `resolved:card:reflected_threat:tooltip:retaliate:2` | Retaliate<br>Until your next turn, an enemy that hits you in melee takes this much damage (Block and Stoneskin absorb it) and any listed riders. Several Retaliates add up. |
| 28 | `resolved:card:meteorfall:tooltip:cinder_marks:0` | Meteorfall<br>Marks the shown tiles. At the start of your next turn, before you draw, each marked tile takes the damage (anyone there, including you) and becomes Fire. |
| 28 | `resolved:card:searing_light:tooltip:all_enemies:1` | Sweeping Strike<br>Hits every enemy you can see that meets the shown condition. There is no target to choose, and enemies hidden by the Umbra are never hit. |
| 28 | `resolved:card:static_ward:tooltip:surface_electrified:1` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface under each adjacent enemy and on your tile. |
| 28 | `resolved:card:stoke:tooltip:all_enemies:1` | Sweeping Strike<br>Hits every enemy you can see that meets the shown condition. There is no target to choose, and enemies hidden by the Umbra are never hit. |
| 28 | `resolved:card:white_silence:tooltip:all_enemies:1` | Sweeping Strike<br>Hits every enemy you can see that meets the shown condition. There is no target to choose, and enemies hidden by the Umbra are never hit. |
| 24 | `resolved:card:ball_lightning:tooltip:surface_electrified:4` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface in the affected area. |
| 24 | `resolved:card:lodestone_reversal:tooltip:surface_electrified:3` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface in the affected area. |
| 24 | `resolved:card:petrify:tooltip:petrify:0` | Petrify<br>The enemy skips its next turn (it still costs its Time) and gains Block, which lasts through your next turn. Dragons are immune. |
| 24 | `resolved:card:spark_dart:tooltip:surface_electrified:2` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface in the affected area. |
| 24 | `resolved:card:spur_spark:tooltip:surface_electrified:1` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface in the affected area. |
| 24 | `resolved:card:static_pivot:tooltip:surface_electrified:1` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface in the affected area. |
| 24 | `resolved:card:storm_beacon:tooltip:surface_electrified:3` | Electrified<br>Lightning spreads through connected Electrified tiles. Chain can jump through these tiles to reach other targets.<br>Leaves this surface in the affected area. |

### keyword tooltip

| Words | Id | Current text |
| ---: | --- | --- |
| 30 | `code:scripts/action_icon_library.gd:KEYWORDS:325253fc0b2e:1` | The enemy skips its next turn (the skipped turn still costs its Time) and gains Block that lasts through your next turn. Not Freeze: no extra damage. Dragons are immune. |
| 29 | `code:scripts/action_icon_library.gd:tokens_for_action:44c8257bc713:1` | When the keg is destroyed by anything, it deals %d to its tile and each tile next to it: you, illusions, enemies and terrain. Kegs set each other off. |
| 28 | `code:scripts/action_icon_library.gd:KEYWORDS:3c5d58f22377:1` | A stopped Push or Pull deals 2 damage per tile not moved to the target and to whatever stopped it. Walls take nothing. Block and Stoneskin absorb it. |
| 28 | `code:scripts/action_icon_library.gd:KEYWORDS:e138e6dcab53:1` | Until your next turn, an enemy that hits you in melee takes this much damage (Block and Stoneskin absorb it) and any listed riders. Several Retaliates add up. |
| 27 | `code:scripts/action_icon_library.gd:KEYWORDS:9ea2c8ed7ca8:1` | Turns the chosen surface tile, and every tile of it connected to it when shown, into another surface. Each enemy on a converted tile takes the damage. |
| 26 | `code:scripts/action_icon_library.gd:KEYWORDS:3d99e37db0fd:1` | Hits every enemy you can see that meets the shown condition. There is no target to choose, and enemies hidden by the Umbra are never hit. |
| 26 | `code:scripts/action_icon_library.gd:tokens_for_action:7492011b4d94:1` | Meteorfall<br>Marks the shown tiles. At the start of your next turn, before you draw, each marked tile takes the damage (anyone there, including you)%s. |
| 25 | `code:scripts/action_icon_library.gd:KEYWORDS:ef3fe0570a56:1` | Swap places with a visible one-tile enemy or one of your illusions. Both of you arrive normally; nothing collides, and Anchored does not stop it. |
| 25 | `code:scripts/action_icon_library.gd:tokens_for_guardian_rule:7374ba88a0dd:1` | Hits the shown approach path and every tile within this distance of the dragon's swept body, including where it started. The approach direction stays fixed. |
| 24 | `code:scripts/action_icon_library.gd:KEYWORDS:00f23b115431:1` | Your next attack on a later card this turn gains the shown bonus, then the bonus is spent. Unused bonuses end with your turn. |
| 24 | `code:scripts/action_icon_library.gd:_append_maneuver_tokens:c64e62079ef0:1` | Petrify<br>The enemy skips its next turn (it still costs its Time) and gains Block, which lasts through your next turn. Dragons are immune. |
| 24 | `code:scripts/action_icon_library.gd:tokens_for_action:978a0a222942:1` | Raises a Worldspine with this much health on each empty tile around the target. Spires block movement, not sight, and leave Rubble when destroyed. |
| 23 | `code:scripts/action_icon_library.gd:_append_maneuver_tokens:9cb811428709:1` | Crystal Mantle<br>Each direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and health costs bypass it. |
| 22 | `code:scripts/action_icon_library.gd:KEYWORDS:dcf6fc72df15:1` | Your next card this turn costs this much less Time (minimum 1). Several Quickens add up; unused Quicken ends with your turn. |
| 22 | `code:scripts/action_icon_library.gd:KEYWORDS:dd4eae0ec6d9:1` | You and one of your illusions trade tiles. Both of you trigger the ground and traps where you land. Immobilize prevents it. |

### relic name

| Words | Id | Current text |
| ---: | --- | --- |
| 5 | `data:data/relics.json#/toll_late_bell/name` | Toll of the Late Bell |
| 3 | `data:data/relics.json#/black_sun_dial/name` | Black Sun Dial |
| 3 | `data:data/relics.json#/breaking_wheel/name` | The Breaking Wheel |
| 3 | `data:data/relics.json#/crown_of_surplus/name` | Crown of Surplus |
| 3 | `data:data/relics.json#/liturgy_of_ash/name` | Liturgy of Ash |
| 3 | `data:data/relics.json#/rosary_of_vows/name` | Rosary of Vows |
| 3 | `data:data/relics.json#/siege_ram_totem/name` | Siege Ram Totem |
| 2 | `data:data/relics.json#/alchemists_retort/name` | Alchemist's Retort |
| 2 | `data:data/relics.json#/anchor_chain/name` | Anchor Chain |
| 2 | `data:data/relics.json#/ashen_brand/name` | Ashen Brand |
| 2 | `data:data/relics.json#/ashen_phylactery/name` | Ashen Phylactery |
| 2 | `data:data/relics.json#/basalt_calendar/name` | Basalt Kiln |
| 2 | `data:data/relics.json#/battering_yoke/name` | Battering Yoke |
| 2 | `data:data/relics.json#/beaconrunner_spurs/name` | Beaconrunner Spurs |
| 2 | `data:data/relics.json#/bloodglass_knife/name` | Bloodglass Knife |

### relic description

| Words | Id | Current text |
| ---: | --- | --- |
| 37 | `data:data/relics.json#/fivefold_knot/description` | Each element you play ties its knot for this combat. With 3 of the 5 knots, your attacks @icon(pierce); with 4, they also gain @icon(chain) 1; with all 5, every card you play also grants 3 @icon(block). |
| 31 | `data:data/relics.json#/black_sun_dial/description` | Consuming a surface stores it (max 3). Your next attack deals 2 more damage per stored surface, and its target gets each one's effect: @icon(surface_fire) beneath it, @icon(chilled), @icon(shock), @icon(stagger) 2. |
| 31 | `data:data/relics.json#/cold_mirror/description` | When you @icon(freeze) an enemy while you have 4 or more @icon(block), your @icon(block) hardens: lose all your @icon(block) and gain 1 @icon(frost_armor) layer for every 4 lost (max 2). |
| 31 | `data:data/relics.json#/winters_hour/description` | Your first @icon(element_ice) card each turn stores @icon(time) 3 (maximum 3). Non-@icon(element_ice) cards spend stored @icon(time) to reduce their cost, to a minimum of @icon(time) 1. Stored @icon(time) lasts this combat. |
| 30 | `data:data/relics.json#/hollow_puppet/description` | Your @icon(push) and @icon(pull) can target your @icon(illusion) without damaging it. An @icon(illusion) that collides with an enemy shatters, dealing its remaining @icon(health) to that enemy instead of @icon(collision) damage. |
| 30 | `data:data/relics.json#/mirror_triptych/description` | Your first attack card each turn is echoed by up to 3 @icon(illusion) at half damage (rounded down). Each hits the nearest enemy it can reach and loses 1 @icon(health). |
| 28 | `data:data/relics.json#/borrowed_hourglass/description` | Once per combat, when you end your turn with a @icon(card_play) unused, take another turn at once. Everything it costs is added to your next turn's @icon(time). |
| 28 | `data:data/relics.json#/breaking_wheel/description` | An enemy colliding on a surface breaks it: @icon(surface_fire) deals 3 more damage, @icon(surface_ice) gives @icon(freeze), @icon(surface_electrified) gives @icon(shock) to it and its blocker, @icon(surface_rubble) gives @icon(stagger) 3. |
| 27 | `data:data/relics.json#/battering_yoke/description` | When an enemy you @icon(push) or @icon(pull) collides with another enemy, that enemy is knocked 1 tile in the same direction, colliding normally if it can't @icon(move). |
| 26 | `data:data/relics.json#/crowncoal_heart/description` | Each turn, your first single-target hit on ground without an elemental surface adds @icon(surface_fire). Your first @icon(detonate) consuming 2+ @icon(surface_fire) grants @icon(stoneskin) 6 after the blast. |
| 26 | `data:data/relics.json#/overflow_censer/description` | When you place @icon(surface_fire), @icon(surface_ice) or @icon(surface_electrified) on a tile holding a different one of them, it also spreads to each empty tile next to it. |
| 26 | `data:data/relics.json#/worldheart/description` | At turn end, convert up to 2 remaining @icon(block) into @icon(stoneskin). Whenever you gain @icon(stoneskin), deal half that amount, rounded down, to adjacent enemies (maximum 4). |
| 25 | `data:data/relics.json#/pyre_keepers_urn/description` | At the start of your turn, the last card you sent to @icon(exhaust) returns to your hand, unless it is a @icon(rite) or has @icon(heal). |
| 25 | `data:data/relics.json#/unbound_pinion/description` | The first card action each turn that sends an enemy 2 or more tiles, or makes it collide, refills your movement and you @icon(draw) 1. |
| 24 | `data:data/relics.json#/masons_plumb/description` | Your outcrops have 2 more @icon(health). An enemy that collides with one of your outcrops takes 2 more damage, and the outcrop takes none. |

### relic tooltip

| Words | Id | Current text |
| ---: | --- | --- |
| 39 | `resolved:relic:fivefold_knot` | Fivefold Knot<br>Each element you play ties its knot for this combat. With 3 of the 5 knots, your attacks @icon(pierce); with 4, they also gain @icon(chain) 1; with all 5, every card you play also grants 3 @icon(block). |
| 34 | `resolved:relic:black_sun_dial` | Black Sun Dial<br>Consuming a surface stores it (max 3). Your next attack deals 2 more damage per stored surface, and its target gets each one's effect: @icon(surface_fire) beneath it, @icon(chilled), @icon(shock), @icon(stagger) 2. |
| 33 | `resolved:relic:cold_mirror` | Cold Mirror<br>When you @icon(freeze) an enemy while you have 4 or more @icon(block), your @icon(block) hardens: lose all your @icon(block) and gain 1 @icon(frost_armor) layer for every 4 lost (max 2). |
| 33 | `resolved:relic:winters_hour` | Winter's Hourglass<br>Your first @icon(element_ice) card each turn stores @icon(time) 3 (maximum 3). Non-@icon(element_ice) cards spend stored @icon(time) to reduce their cost, to a minimum of @icon(time) 1. Stored @icon(time) lasts this combat. |
| 32 | `resolved:relic:hollow_puppet` | Hollow Puppet<br>Your @icon(push) and @icon(pull) can target your @icon(illusion) without damaging it. An @icon(illusion) that collides with an enemy shatters, dealing its remaining @icon(health) to that enemy instead of @icon(collision) damage. |
| 32 | `resolved:relic:mirror_triptych` | Mirror Triptych<br>Your first attack card each turn is echoed by up to 3 @icon(illusion) at half damage (rounded down). Each hits the nearest enemy it can reach and loses 1 @icon(health). |
| 32 | `resolved:relic:witchglass_lantern` | Hollow Puppet<br>Your @icon(push) and @icon(pull) can target your @icon(illusion) without damaging it. An @icon(illusion) that collides with an enemy shatters, dealing its remaining @icon(health) to that enemy instead of @icon(collision) damage. |
| 31 | `resolved:relic:breaking_wheel` | The Breaking Wheel<br>An enemy colliding on a surface breaks it: @icon(surface_fire) deals 3 more damage, @icon(surface_ice) gives @icon(freeze), @icon(surface_electrified) gives @icon(shock) to it and its blocker, @icon(surface_rubble) gives @icon(stagger) 3. |
| 30 | `resolved:relic:borrowed_hourglass` | Borrowed Hourglass<br>Once per combat, when you end your turn with a @icon(card_play) unused, take another turn at once. Everything it costs is added to your next turn's @icon(time). |
| 29 | `resolved:relic:battering_yoke` | Battering Yoke<br>When an enemy you @icon(push) or @icon(pull) collides with another enemy, that enemy is knocked 1 tile in the same direction, colliding normally if it can't @icon(move). |
| 28 | `resolved:relic:crowncoal_heart` | Crowncoal Heart<br>Each turn, your first single-target hit on ground without an elemental surface adds @icon(surface_fire). Your first @icon(detonate) consuming 2+ @icon(surface_fire) grants @icon(stoneskin) 6 after the blast. |
| 28 | `resolved:relic:overflow_censer` | Overflow Censer<br>When you place @icon(surface_fire), @icon(surface_ice) or @icon(surface_electrified) on a tile holding a different one of them, it also spreads to each empty tile next to it. |
| 27 | `resolved:relic:pyre_keepers_urn` | Pyre-Keeper's Urn<br>At the start of your turn, the last card you sent to @icon(exhaust) returns to your hand, unless it is a @icon(rite) or has @icon(heal). |
| 27 | `resolved:relic:unbound_pinion` | Unbound Pinion<br>The first card action each turn that sends an enemy 2 or more tiles, or makes it collide, refills your movement and you @icon(draw) 1. |
| 27 | `resolved:relic:worldheart` | Worldheart<br>At turn end, convert up to 2 remaining @icon(block) into @icon(stoneskin). Whenever you gain @icon(stoneskin), deal half that amount, rounded down, to adjacent enemies (maximum 4). |

### status/condition tooltip

| Words | Id | Current text |
| ---: | --- | --- |
| 28 | `code:scripts/enemy_mechanics/burrow_view.gd:badges:3dade5fa313e:1` | Burrowed<br>Cannot be targeted by single-target attacks; area effects and surfaces on its old tile still hit it. Does not block movement and cannot be pushed or pulled. |
| 22 | `code:scripts/enemy_mechanics/icefall_view.gd:pillar_tooltip:96f9a286d584:1` | Ice Pillar: blocks movement and sight for %d more round(s). A unit pushed into it shatters it and takes 2 damage. |
| 20 | `code:scripts/combat_board_view.gd:_unit_status_badges:bf53edfd58d0:1` | Petrified<br>Skips its next turn; the skipped turn still costs its Time. Its Petrify Block lasts through your next turn. |
| 20 | `code:scripts/combat_board_view.gd:_unit_status_badges:c3a41b8485ed:1` | Crystal Mantle<br>Each direct damaging hit breaks one layer and prevents its damage. Ground and damage over time bypass it. |
| 20 | `code:scripts/run_scene.gd:_refresh_boss_status_row:609d5fa5bece:1` | Crystal Mantle: each direct damaging hit breaks one layer and prevents its damage. Ground and damage over time bypass it. |
| 18 | `code:scripts/action_icon_library.gd:STATE_CONDITION_COPY:991eaa6f699b:1` | If Target at Half Health<br>Applies if the target is at or below half health before the hit. |
| 18 | `code:scripts/enemy_mechanics/bramble_view.gd:tooltip:bcadea398773:1` | Bramble: blocks movement for %d more round(s). A unit pushed into it takes 2 damage and Bleeds. |
| 16 | `code:scripts/enemy_mechanics/lob_view.gd:mark_tooltip:28e60f2d1e6e:1` | Lob Slag<br>On Slag Mortar's next turn this tile takes %d damage, and becomes Fire.%s |
| 15 | `code:scripts/combat_board_view.gd:_draw_meteor_mark_badges:5fe0c655b7d8:1` | Meteorfall<br>At the start of your next turn this tile takes %d damage%s.%s |
| 15 | `code:scripts/enemy_mechanics/burrow_view.gd:draw_badges:ba95ed52e74e:1` | Erupt<br>On Burrow Grub's next turn this tile takes %d damage, and becomes Rubble.%s |
| 13 | `code:scripts/combat_board_view.gd:_terrain_tooltip_text:2e5deb6edfc7:1` | <br>When destroyed, deals %d to its tile and each tile next to it. |
| 13 | `code:scripts/combat_board_view.gd:_terrain_tooltip_text:8a6b91792978:1` | <br>At the start of your turn, each enemy next to it takes %d. |
| 13 | `code:scripts/enemy_mechanics/death_burst_view.gd:badges:441ce6fd6940:1` | Bursts: when this dies, it deals %d damage to everything next to it. |
| 13 | `code:scripts/retaliate_rules.gd:player_badges:ab7e3f084e98:1` | Rite thorns last for this combat; card Retaliate lasts until your next turn. |
| 13 | `code:scripts/tempo_rules.gd:player_badges:0def24d6bdb2:1` | Quicken %d<br>Your next card this turn costs %d less Time (minimum 1). |

### intent label/tooltip

| Words | Id | Current text |
| ---: | --- | --- |
| 18 | `code:scripts/enemy_mechanics/bramble.gd:collision:bcadea398773:1` | Bramble: blocks movement for %d more round(s). A unit pushed into it takes 2 damage and Bleeds. |
| 18 | `code:scripts/enemy_mechanics/reflect.gd:TOOLTIP:519991782dcd:1` | Reflect: ranged attacks against it bounce back to the attacker. Hit it up close or with area effects. |
| 16 | `code:scripts/enemy_mechanics/burrow_view.gd:rows:320af1d40f2a:1` | Surfaces at the mark, displaces its occupant, pushes adjacent units, leaves Rubble and gains Expose 2. |
| 15 | `code:scripts/enemy_mechanics/wind_view.gd:refresh_chip:4b0f8320b8d8:1` | At the end of each enemy turn, everything not anchored is pushed 1 tile %s. |
| 13 | `code:scripts/combat_board_view.gd:_intent_rows_for_unit:04138b3b5f50:1` | Both fixed Light refuges return after this intent resolves, including a skipped turn. |
| 13 | `code:scripts/enemy_mechanics/icefall.gd:collision:e77a4868c5d4:1` | a unit pushed into a pillar takes 2 and the pillar shatters (removed). |
| 11 | `code:scripts/enemy_mechanics/mimic_view.gd:rows:6c41e6a0add0:1` | Mirror: it copies the last attack you played — %s: %d damage. |
| 10 | `code:scripts/enemy_mechanics/burrow_view.gd:rows:475391cb33f7:1` | Burrowed; marks your current tile. Erupt is its next intent. |
| 9 | `code:scripts/enemy_mechanics/kindle_view.gd:rows:53bc84a35ac0:1` | Burst damage increases until death; stacks to max +4. |
| 6 | `code:scripts/enemy_mechanics/veil.gd:TARGETING_REASON:2ba1ed6a90b7:1` | Veiled — attack from an adjacent tile. |
| 6 | `code:scripts/run_scene.gd:_refresh_enemy_intent_toggle:a3c893397fd8:1` | Show every enemy's full plan [I] |
| 5 | `code:scripts/combat_engine.gd:_resolve_enemy_intent:c7c100631065:1` | Something stirs in the Umbra. |
| 5 | `code:scripts/enemy_mechanics/reflect.gd:PREVIEW_TOOLTIP:ab3db0bc3d37:1` | Reflected: you take this damage. |
| 4 | `code:scripts/enemy_mechanics/death_burst_view.gd:pre_battle_summary:2aa21e2585c8:1` | Bursts 4 / Kindle / Melee |
| 4 | `code:scripts/enemy_mechanics/wind_view.gd:DIRECTION_NAMES:487269f24b73:1` | toward the lower left |

### enemy name/tooltip

| Words | Id | Current text |
| ---: | --- | --- |
| 14 | `code:scripts/guardian_library.gd:inspection_summary:169433b5d4ec:1` | Replaces one missing helper on its next declared turn. Up to two helpers alive. |
| 14 | `code:scripts/guardian_library.gd:inspection_summary:db285113ba92:1` | Replaces its fallen companion. Snuff adds a temporary Shade, up to two Shades total. |
| 11 | `code:scripts/guardian_library.gd:inspection_summary:de4e874b5e4a:1` | The Cantor replaces it after defeat. One Wisp at a time. |
| 9 | `code:scripts/guardian_library.gd:intent_notes:aad1853f163f:1` | Relights braziers and dismisses Snuff’s Shades, even when skipped. |
| 8 | `code:scripts/guardian_library.gd:intent_notes:c1545e57bbe2:1` | Extends the existing electrical network toward its target. |
| 7 | `code:scripts/guardian_library.gd:inspection_summary:1f2f6c20e335:1` | Replaced after defeat. Stays through Last Procession. |
| 7 | `code:scripts/guardian_library.gd:intent_notes:77e70b026345:1` | Up to two outcrops; each fuels Groundsplit. |
| 7 | `code:scripts/guardian_library.gd:intent_notes:a43987c6c317:1` | %s remains even if the strike misses. |
| 6 | `code:scripts/guardian_library.gd:inspection_summary:2381e0e4fe57:1` | The Guardian replaces it after defeat. |
| 5 | `code:scripts/guardian_library.gd:intent_notes:68d957c3a94a:1` | The second row stays clear. |
| 5 | `code:scripts/guardian_library.gd:intent_notes:6f7f4b67a666:1` | Braziers relight after Last Procession. |
| 4 | `code:scripts/guardian_library.gd:inspection_summary:ecab884866ca:1` | Disappears after Last Procession. |
| 4 | `code:scripts/guardian_library.gd:intent_notes:4bd7324ad6ef:1` | Overlapping bursts hit once. |
| 4 | `data:data/enemies.json#/iskaldra/name` | Iskaldra, the Rime Tyrant |
| 4 | `data:data/enemies.json#/noctyrax/name` | Noctyrax, the Last Eclipse |

### event title

| Words | Id | Current text |
| ---: | --- | --- |
| 5 | `data:data/events.json#/events/bell_of_the_gale/title` | The Bell of the Gale |
| 5 | `data:data/events.json#/events/mirror_of_skins/title` | The Mirror of Second Skins |
| 5 | `data:data/events.json#/events/shrine_last_door/title` | Shrine of the Last Door |
| 4 | `data:data/events.json#/events/name_collector/title` | The Collector of Names |
| 3 | `data:data/events.json#/events/abandoned_forge/title` | The Abandoned Forge |
| 3 | `data:data/events.json#/events/bloodletters_basin/title` | The Bloodletter's Basin |
| 3 | `data:data/events.json#/events/cinder_supplicant/title` | The Cinder Supplicant |
| 3 | `data:data/events.json#/events/ember_font/title` | The Ember Font |
| 3 | `data:data/events.json#/events/ember_usurer/title` | The Ember Usurer |
| 3 | `data:data/events.json#/events/fallen_lantern_bearer/title` | The Fallen Lantern-Bearer |
| 3 | `data:data/events.json#/events/frozen_champion/title` | The Frozen Champion |
| 3 | `data:data/events.json#/events/hanged_knight/title` | The Hanged Knight |
| 3 | `data:data/events.json#/events/hoarfrost_spring/title` | The Hoarfrost Spring |
| 3 | `data:data/events.json#/events/lost_cartographer/title` | The Lost Cartographer |
| 3 | `data:data/events.json#/events/moth_library/title` | The Moth-Eaten Library |

### event body

| Words | Id | Current text |
| ---: | --- | --- |
| 35 | `data:data/events.json#/events/lost_cartographer/body` | A mapmaker sits against the wall, quill still in hand, dead a week or a century. His charts are pinned beneath a purse heavy with Embers. The ink on the top sheet is still wet. |
| 34 | `data:data/events.json#/events/name_collector/body` | A tall figure in a coat of stitched parchment bows to you. Every scrap of the coat bears a name. "Give me yours," it says, "and I will keep it safe from the dark." |
| 33 | `data:data/events.json#/events/bloodletters_basin/body` | A basin of black stone stands in an alcove, its lip worn smooth by kneeling. Dried runnels stain the floor beneath it. Something glints at the bottom, and something deeper still is thirsty. |
| 32 | `data:data/events.json#/events/root_choked_vault/body` | Roots as thick as a man's waist have split a vault door from its hinges. Through the gap you can see gear stacked in the dark, and the roots are still growing. |
| 31 | `data:data/events.json#/events/starving_pilgrim/body` | A pilgrim kneels in the dust, too weak to stand. His hands are cupped as if in prayer, but they are only begging. An offering bowl sits untouched at his knees. |
| 31 | `data:data/events.json#/events/umbral_bargain/body` | The dark in this room is thicker than elsewhere, and it is listening. When you speak, it answers in your own voice. "You want to leave," it says. "I can help." |
| 31 | `data:data/events.json#/events/whispering_well/body` | Voices rise from a dry well, your own among them, saying things you have not said yet. A bucket hangs ready on its rope. Far below, black water lies very still. |
| 28 | `data:data/events.json#/events/abandoned_forge/body` | The forge is cold, but the anvil is not. Someone was working here very recently and left in a hurry. Their tools are laid out in perfect order. |
| 28 | `data:data/events.json#/events/cinder_supplicant/body` | A robed figure kneels before a brazier, feeding it with its own fingers. It has very few left. "The Crown hungers," it says. "Feed it, and it teaches." |
| 28 | `data:data/events.json#/events/mirror_of_skins/body` | Your reflection in the tall mirror moves half a step late, and it wears your spells differently than you do. It lays one palm flat against the glass. |
| 28 | `data:data/events.json#/events/shrine_last_door/body` | A door stands alone in the middle of the hall, framed by nothing. Candles burn along its threshold. Those who pass through it, the pilgrims say, come back. |
| 28 | `data:data/events.json#/events/windcut_bridge/body` | A rope bridge spans a chasm, the wind pulling at it like a hand at a loose thread. On the far side, a corpse has left its pack. |
| 28 | `data:data/events.json#/events/your_own_body/body` | A body lies face-down in the dust, wearing your clothes and carrying your gear, one hand outstretched toward the way you came. You do not turn it over. |
| 27 | `data:data/events.json#/events/ember_font/body` | A pool of molten ember seethes in a ring of black glass. Weapons have been plunged into it and abandoned, their hilts blackened, their blades gone strange. |
| 27 | `data:data/events.json#/events/hanged_knight/body` | A knight in good armour turns slowly on a chain above a pit. The chain groans with every turn, loud enough to carry far down the halls. |

### event choice

| Words | Id | Current text |
| ---: | --- | --- |
| 22 | `data:data/events.json#/events/abandoned_forge/choices/0/result` | The anvil remembers the work. Your weapon comes out of the quench better than it went in. Your hands come out burnt. |
| 22 | `data:data/events.json#/events/mirror_of_skins/choices/0/result` | For a moment you stand on the wrong side of the glass. When you step back, one of your spells has changed. |
| 21 | `data:data/events.json#/events/hanged_knight/choices/0/result` | He comes down with a crash that echoes for a long time. His gear is yours. So is everything that heard. |
| 21 | `data:data/events.json#/events/starving_pilgrim/choices/0/result` | He eats with shaking hands, then presses his palm to your chest and whispers a blessing. It settles in your bones. |
| 19 | `data:data/events.json#/events/lost_cartographer/choices/1/result` | The routes ahead unfold in his careful hand. One of them, you notice, ends at a drawing of you. |
| 19 | `data:data/events.json#/events/petrified_pilgrims/choices/1/result` | The stone creeps a little way up your fingers and stays. It does not hurt. It does not leave. |
| 18 | `data:data/events.json#/events/frozen_champion/choices/1/result` | She lives for three breaths, long enough to press her hand to your chest and pass something on. |
| 17 | `data:data/events.json#/events/bell_of_the_gale/choices/0/result` | The note goes through you and keeps going. Your blood runs faster. So does everything that heard. |
| 17 | `data:data/events.json#/events/name_collector/choices/0/result` | It writes your name on its sleeve with a careful hand. You feel lighter, and somewhat less. |
| 17 | `data:data/events.json#/events/weeping_statue/choices/0/result` | The gem comes free. The light goes with it, and the dark leans closer for a while. |
| 17 | `data:data/events.json#/events/whispering_well/choices/1/result` | The Ember falls a long way. Something at the bottom whispers a spell back up to you. |
| 17 | `data:data/events.json#/events/your_own_body/choices/1/result` | It takes a long time with bare hands. When you are done, you feel harder to kill. |
| 16 | `data:data/events.json#/events/abandoned_forge/choices/1/result` | You beat out the dents and fold in something new. It fits better than it did. |
| 16 | `data:data/events.json#/events/bell_of_the_gale/choices/1/result` | You pry away what you can carry. The bell falls silent, and the wind with it. |
| 16 | `data:data/events.json#/events/frozen_champion/choices/0/result` | The ice breaks like a shout. She falls into a thousand pieces. Her sword does not. |

### map node

| Words | Id | Current text |
| ---: | --- | --- |
| 10 | `code:scripts/run_scene.gd:_on_mini_map_overlay_gui_input:187de3a51b50:1` | The map can wait until the guided action is complete. |
| 10 | `code:scripts/run_scene.gd:_refresh_large_map_navigation_hint:493bf8111f03:1` | DRAG / TWO-FINGER PAN  •  SCROLL / PINCH TO ZOOM  •  M TO CLOSE |
| 8 | `code:scripts/section_map_panel.gd:_refresh:0b40c3c31352:1` | SECTION %s / VI  ·  %d / %d ROOMS EXPLORED%s |
| 7 | `code:scripts/start_room_map_flow.gd:PATH_HINT:2bdf8c166e6d:1` | Choose your path on the map [M] |
| 6 | `data:data/depths.json#/levels/11/text` | Rare spells are offered less often. |
| 5 | `code:scripts/section_map_panel.gd:_refresh_actions:1c9941c67541:1` | No unknown rooms in sight. |
| 5 | `code:scripts/section_map_panel.gd:_refresh_actions:7c2ab2d84c26:1` | Resolve the current room first. |
| 5 | `data:data/depths.json#/levels/0/text` | Guardians stand on more routes. |
| 5 | `data:data/depths.json#/levels/4/text` | The Ember Hearth restores less. |
| 5 | `data:data/depths.json#/levels/5/text` | You begin each run wounded. |
| 5 | `data:data/depths.json#/levels/9/text` | You begin each run Hunted. |
| 4 | `code:scripts/dragon_boss_library.gd:BOSS_ROOM_NAMES:726caa880630:1` | The Rime Tyrant's Court |
| 4 | `code:scripts/section_map_panel.gd:_build:c949bcbf09a8:1` | Choose an unknown room |
| 4 | `code:scripts/section_map_panel.gd:_refresh_actions:e4862e6ce9f5:1` | Reveal an unknown room. |
| 4 | `code:scripts/section_map_panel.gd:room_description:5d02f44b6b7d:1` | Inherit an equipment card ·  |

### reward screen

| Words | Id | Current text |
| ---: | --- | --- |
| 15 | `code:scripts/run_scene.gd:_reward_recover_button:be7e8faba04f:1` | Recover %d HP, then choose whether one offered card follows you to the next reward. |
| 12 | `code:scripts/run_scene.gd:_add_dragon_reward_stack:70a483fa1a2a:1` | Begin your next run with this relic. It lasts for that run. |
| 12 | `code:scripts/run_scene.gd:_on_skip_reward_pressed:fc74939168fc:1` | Choose whether one offered card should follow you to the next reward. |
| 11 | `code:scripts/run_scene.gd:_on_skip_reward_pressed:361d1c6111e0:1` | This card will replace one choice in your next combat reward. |
| 10 | `code:scripts/run_scene.gd:_on_skip_reward_pressed:ac255881674c:1` | Take the healing reward and leave every offered card behind. |
| 9 | `code:scripts/run_engine.gd:reroll_card_reward:01fdaeb635ac:1` | The reward shifts into a new set of choices. |
| 9 | `code:scripts/run_scene.gd:_on_reward_reroll_pressed:5eaaa137acae:1` | Choose a reward before rerolling on the guided run. |
| 9 | `code:scripts/run_scene.gd:_reward_recover_button:51be9fe33fdb:1` | Leave every offered card behind. Health is already full. |
| 9 | `code:scripts/run_scene.gd:_reward_recover_button:b0aedc0b4e10:1` | Leave every offered card behind and recover %d HP. |
| 7 | `code:scripts/run_engine.gd:reroll_card_reward:7e76840b4ec6:1` | Discerning Eye replaces the offered card reward. |
| 7 | `code:scripts/run_engine.gd:skip_reward_for_heal:3e214d132d69:1` | Saved a card for the next reward. |
| 7 | `code:scripts/run_scene.gd:_add_dragon_reward_stack:e65a9c19662f:1` | +1 Moltshard · First dragon defeated this run |
| 6 | `code:scripts/run_scene.gd:_add_dragon_reward_stack:8ed1d378e5c3:1` | First-dragon Moltshard already earned this run |
| 6 | `code:scripts/run_scene.gd:_reward_recover_button:028339bfefad:1` | SKIP & RECOVER  +%d HP   %d → %d |
| 5 | `code:scripts/run_engine.gd:claim_card_reward:3adedcebc342:1` | Added %s to reserve magic. |

### shop

| Words | Id | Current text |
| ---: | --- | --- |
| 32 | `code:scripts/graftwright_view.gd:_build_intro:0a7188b49c33:1` | My needle needs two pieces of the same kind. Bring me something to spare, and I'll unpick it to stitch one of its cards into another piece, replacing a card you choose. |
| 29 | `code:scripts/graftwright_view.gd:_build_intro:7474aa123e4c:1` | Lay down two pieces of the same kind. I'll unpick one to stitch a card into the other, replacing a card you choose. The offering won't survive my needle. |
| 9 | `code:scripts/scavenger_shop_view.gd:_build_static_scene:0a69d5eb0c86:1` | Close the shop and return to the room's doors. |
| 8 | `code:scripts/scavenger_shop_view.gd:_build_detail_content:54374fe22f64:1` | Show the previous card granted by this gear. |
| 8 | `code:scripts/scavenger_shop_view.gd:_build_detail_content:d3cc0c4791c2:1` | Show the next card granted by this gear. |
| 7 | `code:scripts/graftwright_view.gd:_build_picker_context:d68f68ec6c8f:1` | Sacrifice must match the equipment to improve:  |
| 7 | `code:scripts/run_engine.gd:reserve_merchant_offer:ec579030e0a1:1` | %s is held for the next visit. |
| 7 | `code:scripts/run_engine.gd:reserve_merchant_offer:ff6a52a2174c:1` | Layaway holds %s for the next visit. |
| 7 | `code:scripts/scavenger_shop_view.gd:_offer_tooltip:84d1373f02cf:1` | %s<br>Price: %d embers — need %d more |
| 6 | `code:scripts/graftwright_view.gd:_build_picker_context:19cfac92b364:1` | Choosing another type clears the sacrifice. |
| 5 | `code:scripts/run_scene.gd:_add_merchant_return_to_shop_button:1dabbaf80aac:1` | Open the merchant's stock again. |
| 5 | `code:scripts/scavenger_shop_view.gd:_offer_tooltip:41c9a421d744:1` | %s<br>Sell value: %d embers |
| 5 | `code:scripts/scavenger_shop_view.gd:_populate_sell_page:a0b02b63033e:1` | No spare wares to sell. |
| 5 | `code:scripts/scavenger_shop_view.gd:_sync_detail:36fb278f4275:1` | Sell the selected owned ware. |
| 5 | `code:scripts/scavenger_shop_view.gd:_sync_detail:e0a4a513cb3c:1` | You cannot afford this ware. |

### chronicle

| Words | Id | Current text |
| ---: | --- | --- |
| 7 | `code:scripts/chronicle_panel.gd:open:78913b5dbe88:1` | Your first descent will be written here. |
| 7 | `code:scripts/chronicle_rules.gd:subline:589d8893bede:1` | %s, room %d of %d · %d min |
| 6 | `code:scripts/chronicle_rules.gd:killer_text:61de4f15b2f7:1` | Felled by a %s's %s |
| 5 | `code:scripts/chronicle_rules.gd:killer_text:27a7b5c47bb0:1` | Withdrew at the Ember Hearth |
| 4 | `code:scripts/chronicle_panel.gd:_build_detail:cb4986d53065:1` | No feats this time. |
| 4 | `code:scripts/chronicle_rules.gd:killer_text:62def4adcbd4:1` | Worn down by fatigue |
| 3 | `code:scripts/chronicle_panel.gd:_add_row:75bb83c59877:1` | %s · %d min |
| 3 | `code:scripts/chronicle_panel.gd:_build_path:d320e6018e67:1` | %s · Guardian combat |
| 3 | `code:scripts/chronicle_panel.gd:open:88de7786e7e7:1` | No descents yet. |
| 3 | `code:scripts/chronicle_rules.gd:killer_text:00f09eedbcd4:1` | Slain by %s |
| 3 | `code:scripts/chronicle_rules.gd:killer_text:00f09eedbcd4:2` | Slain by %s |
| 3 | `code:scripts/chronicle_rules.gd:section_text:07e177238750:1` | Section %s · %s |
| 3 | `code:scripts/chronicle_rules.gd:subline:eabc908661c2:1` |  · Umbra Depth %d |
| 2 | `code:scripts/chronicle_panel.gd:_add_row:28d77732c296:1` | DEPTH %d |
| 2 | `code:scripts/chronicle_panel.gd:_build_detail:0b8795746854:1` |  · %d min |

### run-end recap

| Words | Id | Current text |
| ---: | --- | --- |
| 15 | `code:scripts/run_end_recap_overlay.gd:build_model:adbdf3e783b7:1` | Embers lost %s. They wait where you fell, in Section %s of your next run. |
| 10 | `data:data/run_end_text.json#/quips/victory/4` | You step into a morning you had stopped believing in. |
| 9 | `code:scripts/run_score_rules.gd:cause_text:46de62d77d5f:1` | You leave by the Ember Hearth, carrying %s Embers. |
| 8 | `code:scripts/run_end_recap_overlay.gd:build_model:3ec9df9acd64:1` | The ascent is complete. Carried embers are secure. |
| 8 | `code:scripts/run_score_rules.gd:cause_text:ed7cb98fbc44:1` | Felled by a %s's %s, %d damage. |
| 8 | `data:data/run_end_text.json#/quips/embrace/0` | Wisdom is knowing which door to leave by. |
| 8 | `data:data/run_end_text.json#/quips/embrace/1` | The Embers come with you. The dark stays. |
| 7 | `code:scripts/run_end_recap_overlay.gd:build_model:74461b140ab4:1` | Section %s%s · Room %d of %d |
| 7 | `code:scripts/run_end_recap_overlay.gd:build_model:e30bbbef7633:1` | Recovery marker %s · Depth %d · %d embers |
| 7 | `code:scripts/run_score_rules.gd:cause_text:3cd5ffd8414b:1` | The ground itself took your last breath. |
| 7 | `code:scripts/run_score_rules.gd:cause_text:47c2d50871a9:1` | Noctyrax falls. The way out is open. |
| 7 | `code:scripts/run_score_rules.gd:cause_text:7329ea2181f6:1` | A %s trap took your last breath. |
| 7 | `data:data/run_end_text.json#/quips/defeat/13` | You will wake at the Threshold again. |
| 7 | `data:data/run_end_text.json#/quips/victory/1` | Behind you, the labyrinth forgets your name. |
| 7 | `data:data/run_end_text.json#/quips/victory/2` | The Umbra loosens its grip. For now. |

### menus/settings

| Words | Id | Current text |
| ---: | --- | --- |
| 9 | `code:scripts/main_menu.gd:_on_run_loading_failed:757257dc1994:1` | The Labyrinth could not be loaded.<br>Please try again. |
| 9 | `code:scripts/settings_panel.gd:COMBAT_SPEED_DETAIL:169e34906a46:1` | How quickly enemy turns and card effects play out. |
| 8 | `code:scripts/new_descent_panel.gd:_refresh:76ab7fd82d19:1` | Escape at Depth %d to unlock Depth %d. |
| 7 | `code:scripts/main_menu.gd:_reload_progression:e00b71ee953f:1` | LV %d  \|  EMBERS %d  \|  SKILLS %d/%d |
| 7 | `code:scripts/new_descent_panel.gd:_refresh:f3120ed395ea:1` | The Umbra as you first knew it. |
| 7 | `code:scripts/settings_panel.gd:_build_audio_section:67ed47db766a:1` | Mix each layer without muting the world. |
| 6 | `code:scenes/main_menu.tscn:top_level:2d8c4427aa6c:1` | HP 185 / 260  ·  HELD 74 EMBERS |
| 6 | `code:scenes/main_menu.tscn:top_level:2d8c4427aa6c:2` | HP 185 / 260  ·  HELD 74 EMBERS |
| 6 | `code:scenes/main_menu.tscn:top_level:f401feff99f8:1` | LV 1  \|  EMBERS 0  \|  BOUND 0 |
| 6 | `code:scripts/main_menu.gd:_build_saved_run_preview:9339373f924f:1` | HP %d / %d  ·  HELD %d EMBERS |
| 6 | `code:scripts/settings_panel.gd:_build_accessibility_section:683633098647:1` | Instant reveals each line at once |
| 6 | `code:scripts/settings_panel.gd:_build_accessibility_section:6bfe26358f1d:1` | Skips supported entrance and travel flourishes |
| 6 | `code:scripts/settings_panel.gd:_build_accessibility_section:e6b9aec6b843:1` | Tune pacing without changing the rules. |
| 6 | `code:scripts/settings_panel.gd:_build_display_section:59c043187e16:1` | Safe choices for the current screen. |
| 6 | `code:scripts/settings_panel.gd:_build_display_section:767783228d9e:1` | Window changes stay bounded and centered |

### HUD labels

| Words | Id | Current text |
| ---: | --- | --- |
| 33 | `code:scripts/run_scene.gd:_refresh_umbra_subtitle:f612b10697e1:1` | %s Umbra<br>Personal vision: %s.<br>Tiles outside your vision or a light source are obscured. Hidden enemies cannot be targeted and conceal their intents.<br>Radiance can reveal them or drive the Umbra back. |
| 22 | `code:scripts/maneuver_rules.gd:FLAG_INFO:659622dffef4:1` | Until your next turn, you can't be pushed or pulled. Push and Pull against you move you 0 tiles and never collide. |
| 22 | `code:scripts/run_scene.gd:_pass_preview_risk_tooltip:621a1db734ba:1` | A revealed lethal hit will spend %d Defiance and restore %d HP. You return with %d/%d HP (%s) and %d Defiance. |
| 18 | `code:scripts/combat_board_view.gd:_noctyrax_brazier_markers:86d7a5c49bf6:1` | This brazier relights after Night Coil resolves, including a skipped turn. Step onto it to restore Light sooner. |
| 18 | `code:scripts/combat_objective_rules.gd:DEFINITIONS:6cdc92195258:1` | Reach a marked threshold to escape through that door. Enemies and terrain are positioned to bar your path. |
| 17 | `code:scripts/combat_board_view.gd:_trap_tooltip_text:6aaf817936eb:1` | %s Trap<br>%d damage only to its center occupant.<br>%s<br>New ground has no immediate occupant effect. |
| 17 | `code:scripts/run_scene.gd:_pass_preview_risk_tooltip:99bae49e8dc2:1` | One or more hidden presences act before your next turn. Their intents and possible damage are unknown. |
| 16 | `code:scripts/run_scene.gd:_empower_command_tooltip:1c8b0f48ddf3:1` | Empower (%s): %s.<br>The cost is paid when the card finishes. Press E (controller: right stick). |
| 15 | `code:scripts/combat_board_view.gd:_noctyrax_brazier_markers:8262949dbad8:1` | Light radius 2 blocks Eclipse darkness. The marked ground and other attacks can still hit. |
| 14 | `code:scripts/movement_undo_button.gd:_init:cfadb6698452:1` | Take back your last move. Moves that revealed or triggered something can't be undone. |
| 14 | `code:scripts/run_scene.gd:_exchange_moltshard_at_entrance:d3ac8ae5aa1d:1` | Bring me a Moltshard from a dragon, and I can trade it for Embers. |
| 14 | `code:scripts/run_scene.gd:_open_level_up_overlay:b59f385daea3:1` | Skill point gained. Defiance +%d. Spend the point now or save it for later. |
| 13 | `code:scripts/combat_board_view.gd:_noctyrax_brazier_markers:21ac7ad887c7:1` | Step onto this brazier's tile to relight it and restore Light radius 2. |
| 13 | `code:scripts/maneuver_rules.gd:FLAG_INFO:9635e49e516a:1` | This turn, moving onto Ice costs no movement and Ice doesn't Chill you. |
| 13 | `code:scripts/run_scene.gd:_build_defiance_badge:6f2735008b9f:1` | DEFIANCE %d / %d<br>Lethal health loss spends 1 to restore 25%% max health.<br> |

### onboarding/tutorial

| Words | Id | Current text |
| ---: | --- | --- |
| 19 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:887a3708212f:1` | Card Time places your next turn. An unused play still takes 5, so faster cards bring you back sooner. |
| 19 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:887a3708212f:2` | Card Time places your next turn. An unused play still takes 5, so faster cards bring you back sooner. |
| 19 | `code:scripts/contextual_combat_tutorial.gd:PHASES:887a3708212f:1` | Card Time places your next turn. An unused play still takes 5, so faster cards bring you back sooner. |
| 19 | `code:scripts/contextual_combat_tutorial.gd:PHASES:887a3708212f:2` | Card Time places your next turn. An unused play still takes 5, so faster cards bring you back sooner. |
| 18 | `code:scripts/contextual_combat_tutorial.gd:PHASES:4a92ca2c356c:1` | Pass ends your turn. Each unused play still takes 5 Time. The preview shows what enemies do next. |
| 18 | `code:scripts/contextual_combat_tutorial.gd:PHASES:4a92ca2c356c:2` | Pass ends your turn. Each unused play still takes 5 Time. The preview shows what enemies do next. |
| 17 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:d951e3a7dcc2:1` | The crawler's 4-damage attack used 4 Block, so you lost no Health. Defeat it on your own. |
| 17 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:d951e3a7dcc2:2` | The crawler's 4-damage attack used 4 Block, so you lost no Health. Defeat it on your own. |
| 15 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:41fc1235bd46:1` | You begin each turn with 2 movement. Use 1 to move onto the glowing tile. |
| 15 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:41fc1235bd46:2` | You begin each turn with 2 movement. Use 1 to move onto the glowing tile. |
| 15 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:9cb65668857e:1` | Select the glowing crawler. Follow-up adds 3 after Pale Spark, so Quick Stab deals 9. |
| 15 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:abf1f06cfda4:1` | Click the glowing crawler. Follow-up adds 3 after Pale Spark, so Quick Stab deals 9. |
| 14 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:29178427cf2f:1` | Pale Spark spent 1 card play. The counter has fallen from 2 to 1. |
| 14 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:29178427cf2f:2` | Pale Spark spent 1 card play. The counter has fallen from 2 to 1. |
| 13 | `code:scripts/contextual_combat_tutorial.gd:AUTHORED_PHASES:2366f40d1b3e:1` | This crawler will move up to 3 tiles, then attack for 4 damage. |

### confirmation dialogs

| Words | Id | Current text |
| ---: | --- | --- |
| 23 | `code:scripts/run_scene.gd:_open_skill_reset_confirmation:4c84f4e0d6ab:1` | Are you sure you want to clear all %d learned skills?<br>All %d earned skill points will be restored. This costs 1 Moltshard. |
| 14 | `code:scripts/run_scene.gd:_confirm_skill_reset:2e966cb54afb:1` | Skills could not be reset because the profile changed or no Moltshard is available. |
| 12 | `code:scripts/run_scene.gd:_confirm_skill_reset:879f6ed4bf20:1` | Skills could not be reset. Nothing changed and no Moltshard was spent. |
| 8 | `code:scripts/run_scene.gd:_on_abandon_run_pressed:ecb776ead251:1` | Could not save the completed run. Try again. |
| 2 | `code:scripts/run_scene.gd:_open_skill_reset_confirmation:0f8278eae83e:1` | Reset Skills |
| 2 | `code:scripts/run_scene.gd:_open_skill_reset_confirmation:2ca650268f1e:1` | Reset Skills? |
| 2 | `code:scripts/settings_panel.gd:_confirm_restore_defaults:0a4a35c29cf4:1` | Defaults restored |
| 2 | `code:scripts/settings_panel.gd:_show_restore_confirmation:5529118b0637:1` | Confirmation required |
| 1 | `code:scripts/run_scene.gd:_open_skill_reset_confirmation:19766ed6ccb2:1` | Cancel |

### error/empty states

| Words | Id | Current text |
| ---: | --- | --- |
| 11 | `code:scripts/run_scene.gd:_commit_dragon_reward_continue:ca61030bc34f:1` | Could not save. Your rewards are still here; try Continue again. |
| 10 | `code:scripts/run_scene.gd:_skill_reset_unavailable_reason:828711acf154:1` | Defeat the first boss of a run to earn one. |
| 10 | `code:scripts/run_scene.gd:_start_run:804f828e253c:1` | Could not save the previous run's relic gift. Try again. |
| 8 | `code:scripts/run_scene.gd:_skill_reset_unavailable_reason:99799288b548:1` | Finish the current action before resetting your skills. |
| 7 | `code:scripts/graftwright_rules.gd:room_error:ae0de26b405e:1` | Visit the Graftwright to inherit a card. |
| 7 | `code:scripts/graftwright_rules.gd:room_error:ae0de26b405e:2` | Visit the Graftwright to inherit a card. |
| 7 | `code:scripts/graftwright_view.gd:_build_empty:00b1a266c05f:1` | Bring two pieces of the same type. |
| 7 | `code:scripts/run_scene.gd:_on_back_to_menu_pressed:3506c4ccc4ec:1` | Could not save. Try again before leaving. |
| 7 | `code:scripts/run_scene.gd:_on_graft_requested:a0f67642c3a1:1` | Could not save. Your equipment is unchanged. |
| 7 | `code:scripts/run_scene.gd:_skill_reset_unavailable_reason:114f6ed05080:1` | Reset is unavailable after the run ends. |
| 7 | `code:scripts/run_scene.gd:_skill_reset_unavailable_reason:45462c776efc:1` | Start a run before resetting your skills. |
| 7 | `code:scripts/run_scene.gd:_skill_reset_unavailable_reason:9ba68d5f43f9:1` | Learn a skill before resetting the tree. |
| 6 | `code:scripts/event_rules.gd:choice_block_reason:714f68a391de:1` | Requires more than %d max Health. |
| 6 | `code:scripts/graftwright_rules.gd:pair_error:5c48930c6cf4:1` | Equipment must be the same type. |
| 6 | `code:scripts/graftwright_rules.gd:pair_error:e096d7fe2041:1` | Choose a different item to sacrifice. |

### equipment

| Words | Id | Current text |
| ---: | --- | --- |
| 8 | `code:scripts/run_engine.gd:equip_equipment:e3bffe922e55:1` | Open Arsenal equips %s in the trinket slot. |
| 8 | `code:scripts/run_scene.gd:_on_loadout_button_pressed:7c70c733cd56:1` | Finish the guided action before changing your loadout. |
| 6 | `code:scripts/run_engine.gd:ESCAPE_MISSED_EQUIPMENT_NOTICE:05007f16c8e0:1` | Unclaimed gear will be left behind. |
| 5 | `code:scripts/run_engine.gd:MISSED_EQUIPMENT_NOTICE:51b23342f8f4:1` | Unclaimed gear crumbles into dust. |
| 3 | `code:scripts/run_scene.gd:_animate_missed_equipment_resolution:b77f8cf9329a:1` | Salvager recovers %s. |
| 3 | `code:scripts/run_scene.gd:_build_equipment_tooltip_panel:8d441442fa40:1` | Locked in combat |
| 3 | `code:scripts/run_scene.gd:_equipment_tooltip:8d441442fa40:1` | Locked in combat |
| 3 | `data:data/equipment.json#/buckler_of_nails/name` | Buckler of Nails |
| 3 | `data:data/equipment.json#/crown_of_thorns/name` | Crown of Thorns |
| 2 | `code:scripts/combat_board_view.gd:_equipment_loot_fallback_tooltip:8b7f0b1a41ad:1` | %s<br>%s |
| 2 | `code:scripts/run_engine.gd:_apply_collected_equipment_to_owned_state:d2fd45662ac3:1` | Found %s. |
| 2 | `code:scripts/run_engine.gd:equip_equipment:43966dfd8745:1` | Equipped %s. |
| 2 | `code:scripts/run_scene.gd:_build_equipment_tooltip_panel:442c6bbe5d10:1` | %s \| %s |
| 2 | `code:scripts/run_scene.gd:_controller_equipment_pickup_detail:8b6f09f93119:1` | Adds %s |
| 2 | `code:scripts/run_scene.gd:_controller_equipment_pickup_detail:ffad84272d6b:1` | %s · %s |

### skills

| Words | Id | Current text |
| ---: | --- | --- |
| 31 | `data:data/skills.json#/living_shadow/description` | Once between your turns, when @icon(illusion) is destroyed or dispelled, return your most recently discarded non-item card to hand—or put it atop your draw pile if your hand is full. |
| 24 | `data:data/skills.json#/sunpath/description` | The first @icon(move) or @icon(blink) 3+ each turn leaves @icon(illuminate) 1 @icon(time) 2 on every tile entered. @icon(blink) also covers its origin and destination. |
| 22 | `data:data/skills.json#/confluence/description` | Once per combat, @icon(surface_relocate) one surface up to @icon(range) 4. Both tiles must be visible and within @icon(range) 4 of you. |
| 20 | `data:data/skills.json#/layaway/description` | Once between bosses, hold one ware for the next Scavenger visit. A pending hold blocks future uses until it returns. |
| 20 | `data:data/skills.json#/pain_remembers/description` | After you first lose @icon(health) each combat, the next non-item card discarded while your hand has room returns to it. |
| 18 | `data:data/skills.json#/carry_the_guard/description` | Once per combat, activate while you have @icon(block) to convert your remaining @icon(block) into @icon(stoneskin) at turn end. |
| 18 | `data:data/skills.json#/encore/description` | Once per combat, return a non-item card from discard to your hand. Costs no @icon(card_play) or @icon(time). |
| 18 | `data:data/skills.json#/prismatic_instinct/description` | Once per combat, place @icon(surface_fire), @icon(surface_ice), @icon(surface_electrified) or @icon(surface_rubble) within @icon(range) 4. Costs no @icon(card_play) or @icon(time). |
| 17 | `data:data/skills.json#/deferred_choice/description` | Skip a card reward to save one offered card. It replaces one card in your next reward. |
| 16 | `data:data/skills.json#/afterglow/description` | When @icon(illusion) is removed during combat, it leaves @icon(illuminate) 1 @icon(time) 2 at its final tile. |
| 16 | `data:data/skills.json#/quick_wits/description` | Once per combat, discard a card to gain @icon(draw) 1. Costs no @icon(card_play) or @icon(time). |
| 15 | `data:data/skills.json#/borrowed_time/description` | The first card paid for with a banked @icon(card_play) each combat adds no @icon(time). |
| 15 | `data:data/skills.json#/last_door/description` | Once between bosses, a non-boss defeat returns you to the previous room at @icon(health) 1. |
| 14 | `data:data/skills.json#/dawnbrand/description` | The first direct attack each turn against an enemy in @icon(illuminate) inflicts @icon(expose) 1. |
| 14 | `data:data/skills.json#/makeshift_tool/description` | Once per combat, activate to discard your next item after use instead of @icon(consume). |

### grimoire

| Words | Id | Current text |
| ---: | --- | --- |
| 58 | `data:data/grimoire.json#/entries/92/body/0` | Consume: an attack that consumes a surface deals its bonus to each enemy it hits that stands on that surface, then removes the surface beneath it. An area consumes the surface on every tile of its pattern. Some attacks can only target an enemy standing on the surface. Any surface the attack leaves is placed after the consumption. |
| 57 | `data:data/grimoire.json#/entries/13/body/2` | Powder kegs and Worldspines are raised the same way. A keg blocks movement but not sight; when anything destroys it, it deals its damage to its tile and each tile next to it, setting off other kegs. Your Worldspines pulse at the start of each of your turns, hitting each enemy next to one of them once. |
| 52 | `data:data/grimoire.json#/entries/70/body/0` | An area force pushes or pulls every enemy within its radius of a center: you, or a tile you choose. Each enemy moves along its own straight line away from (Push) or toward (Pull) the center, using the normal Push and Pull rules. An enemy standing on a Pull's center stays put. |
| 50 | `data:data/grimoire.json#/entries/31/body/1` | Some illusions carry an effect while they live: enemies that damage a charged illusion take damage back (once per enemy attack), and a Doppelganger lets your ranged attacks fire from its tile. Mirror Feint places its illusion beside an enemy; Hall of Mirrors fills every empty tile next to you. |
| 44 | `data:data/grimoire.json#/entries/13/body/1` | A tile is legal only when the raise keeps every floor tile connected, so an outcrop can never seal the hero, an enemy, a pickup or an exit away. A Worldspine cage is the one exception: it may seal the single tile it surrounds. |
| 42 | `data:data/grimoire.json#/entries/31/body/2` | Empty Husk swaps you with one of your illusions and moves your Block onto it as extra health. Shattered Reflection destroys one of your illusions to blast each enemy next to it. Both count as normal arrivals and destruction for illusion effects. |
| 41 | `data:data/grimoire.json#/entries/68/body/2` | The Meteorfall card marks a line of tiles the same way. The marks stay through enemy turns; at the start of your next turn, before you draw, each marked tile takes the damage (anyone standing there, including you) and becomes Fire. |
| 38 | `data:data/grimoire.json#/entries/28/body/0` | Gains its listed bonus if you already played another card this turn. The bonus is decided when the card starts, so every Flurry repeat shares it, and the card's numbers update in your hand while it is active. |
| 38 | `data:data/grimoire.json#/entries/75/body/3` | Crystal Mantle cards give you the same layers: each direct hit against you breaks one layer instead of dealing damage. Fire, Bleed, collisions, traps and health costs bypass it. Your layers last until broken or the combat ends. |
| 38 | `data:data/grimoire.json#/entries/93/body/0` | Some cards strike every enemy you can see that meets a condition: standing on Fire or Electrified ground, Chilled, or in Light. There is no target to choose, and an enemy hidden by the Umbra is never hit. |
| 36 | `data:data/grimoire.json#/entries/71/body/1` | Both of you arrive normally: surfaces and traps trigger for each, and you collect loot on your new tile. A swap is not a Push or Pull, so nothing collides and Anchored does not stop it. |
| 35 | `data:data/grimoire.json#/entries/73/body/0` | Cleanse removes the listed statuses from you at once: Bleed, Immobilize, Chilled or Shock. Removing Immobilize or Shock frees you for the rest of this turn, and a Shock cleanse can be played while Shocked. |
| 34 | `data:data/grimoire.json#/entries/34/body/1` | Melee means a melee attack or any attack made from a tile next to you. Retaliate triggers once per enemy attack. Several Retaliates add their damage and Bleed; Shock and Push use the largest. |
| 33 | `data:data/grimoire.json#/entries/48/body/0` | When forced movement is stopped by a wall, crate, outcrop, character or illusion, the target takes 2 damage for each tile it didn't move, and so does whatever it hit. Walls take nothing. |
| 32 | `data:data/grimoire.json#/entries/34/body/0` | Until the start of your next turn, an enemy whose melee attack hits you takes the Retaliate amount. Block and Stoneskin absorb it; Chill, Freeze and Expose do not add to it. |

### dialogue

| Words | Id | Current text |
| ---: | --- | --- |
| 24 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:f6f7ee1f2563:1` | When you are ready, ask me to awaken your power. I can trade your Moltshards for Embers, then use those Embers to strengthen you. |
| 22 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:2c23692d5563:1` | That cast-off scale remembers the fire that made it. Let me wake it, and its power will kindle Embers of your own. |
| 19 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:05a30c7e2035:1` | After all this time, I can but provide this small measure of safety. The rest is up to you... |
| 17 | `code:scripts/scavenger_shop_view.gd:_sync_dialogue:d59dd5f482ef:1` | “Cards, steel, little miracles in bottles. Spend your embers, or show me what you've brought to sell.” |
| 16 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:0c518dbea150:1` | You reached his shadow. It will only get stronger the further you stray from this place. |
| 16 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:518dcb47a56a:1` | You reached [i]his[/i] shadow. It will only get stronger the further you stray from this place. |
| 15 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:8913103b1ed0:1` | A dragon has fallen. I felt it... and so did the Shard you carried away. |
| 14 | `data:data/npcs.json#/scavenger/default_dialogue/0` | Nothing down here is useless. Some things are just waiting for the right hand. |
| 12 | `code:scripts/dialogue_engine.gd:emaciated_service_dialogue:057f0a0d322a:1` | You need 1 Moltshard. The first dragon defeated each run grants one. |
| 12 | `data:data/npcs.json#/scavenger/default_dialogue/1` | Cards, steel, little miracles in bottles. I find what the dark forgets. |
| 11 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:98769cceb379:1` | Once, long ago, I was nearly a match for his power. |
| 11 | `code:scripts/dialogue_engine.gd:_emaciated_man_dialogue:bacaef96f2a9:1` | Once, long ago, I was nearly a match for [i]his[/i] power. |
| 11 | `code:scripts/dialogue_engine.gd:emaciated_service_dialogue:bdbfaaf47c67:1` | Spend %d Embers to gain a level and a skill point. |
| 10 | `data:data/npcs.json#/scavenger/default_dialogue/2` | Buy it, use it, lose it. That's the honest bargain. |
| 9 | `code:scripts/dialogue_engine.gd:_default_npc_dialogue:8d334a75da1b:1` | There is business to settle before the path continues. |

### combat log

| Words | Id | Current text |
| ---: | --- | --- |
| 5 | `code:scripts/combat_engine.gd:_anonymize_hidden_enemy_action_logs:cf34509abf0e:1` | Something shifts in the Umbra. |
| 5 | `code:scripts/combat_engine.gd:_trap_trigger_log:7d338ee8c178:1` | %s trap: %d center damage. |
| 4 | `code:scripts/combat_engine.gd:_anonymize_hidden_enemy_action_logs:6993ae7775f3:1` | A hidden presence attacks. |
| 2 | `code:scripts/run_scene.gd:_log_text:8b7f0b1a41ad:1` | %s<br>%s |

## Glossary findings

`glossary_seed.json` retains verbatim source-linked definitions, aliases and naming candidates. Confirmed rules discrepancies: Time's ‘each unused play’ omits the base-play cap; the Grimoire's Chilled definition requires Ice although relic Chilled persists off Ice. No text has been corrected.

## Proof and limitations

Run `python3 tools/text_audit.py --check` to re-export production data and compare every generated artifact without writing. Run `--self-test` for scanner/source tests. Headless fixture validation and exact windowed command are documented in `captures.md`. Renderer capture and independent visual inspection remain with the design owner.

No TODO_DESIGN placeholders: this audit introduces no player-visible decisions. Chosen defaults are tool-only: export timeout 180 s, 12-character source digests, probe seed 321; shop fixture seed 73491/720 Embers and existing stock; 2 Bleed stacks; the named production hand/relic fixtures; measurement hands of 3/8 cards; disabled-event Embers 0; 600 readiness frames; 5 settling frames; 1.2 s presentation wait; 0.6 s native-tooltip wait; 0.025 s treasure polling; manual tooltip anchor (1200,350), 24 px margin and z-order 4095. No production values change.
