# txt-36 truth audit

The table covers the two protected paragraphs on each of the 26 pages. A True verdict describes what the move or rule does when it resolves, with the target and timing conditions shown in the evidence. An absolute claim with a concrete counterexample is False. Damage and forced movement use the ordinary defenses, targeting and collision rules unless the action specifies an exception. Fictional descriptions are inventoried below.

## Claims

| Page | Concrete claim | Verdict | Evidence and observed behavior |
| --- | --- | --- | --- |
| Ember Tick | Every Tick death triggers Burst. | False | Ordinary deaths trigger it. A Hoarder catch suppresses queued brood death effects, including simultaneous actual deaths. `scripts/combat_engine.gd:12704`, `scripts/hoarder_room_rules.gd:149`, `tests/suites/hoarder_suite.gd:371` |
| Glacial Mirror | Whatever it reflects comes back stronger. | False | A damaging attack from a nonadjacent attacker can bounce, subject to exclusions. The return uses the resolved incoming damage amount and normal defenses. The bounce adds no damage of its own. `scripts/enemy_mechanics/reflect.gd:18`, `:40` |
| Arc Thrall | If “stopped feeling the shocks” implies Shock immunity, the Thrall is immune. | False | Arc Thrall has no Shock immunity in the catalog, and the ordinary Shock handler applies. The history or sensation itself is lore. `data/enemies.json:2877`, `scripts/combat_engine.gd:6724` |
| Gust Shrike | Dive strikes everything along the path, including other enemies. | False | The swept shape defines where it can strike. The enemy attack's unit targets are the hero team, so allies can stand in the marked area unharmed by Dive. `data/enemies.json:3510`, `scripts/guardian_combat_rules.gd:398`, `scripts/combat_engine.gd:12336` |
| Burrow Grub | The Grub always emerges on the exact Marked tile. | False | The strike retains the original Mark, but the Grub can surface on another legal tile if the Mark is blocked or its occupant cannot be displaced. If no landing exists, Erupt leaves it buried. `scripts/enemy_mechanics/burrow.gd:34`, `:74`, `:138` |
| Burrow Grub | Erupt leaves the hero Exposed. | False | Erupt damages the center occupant, displaces or Pushes where applicable and grants self-Expose. There is no hero Expose rider. Arrival on Rubble can have ordinary surface effects. `data/enemies.json:3026`, `scripts/enemy_mechanics/burrow.gd:74`, `:98` |
| Gloam Stalker | Fade always reappears behind the hero. | False | Fade prefers the tile opposite the hero's facing, then picks the closest legal cardinal neighbor within reach. It stays put if none is legal or movement is disabled. `scripts/enemy_mechanics/stalker.gd:22`, `:61` |
| Gloam Stalker | Fade always leads to an Ambush hit on the next turn. | False | The catalog schedules Ambush, but the engine selects Slash if the follow-up has no viable attack. A declared Ambush needs a living Stalker adjacent to the hero at resolution to strike. `data/enemies.json:2948`, `scripts/combat_engine.gd:9135`, `scripts/enemy_mechanics/stalker.gd:74` |
| Hollow Mimic | Echo makes the Mimic hit back at anything that strikes it up close. | False | The close-hit test accepts melee or a hit from an adjacent origin. The reaction requires a qualifying positive player attack and a surviving Mimic, and it targets the hero. Enemy friendly fire, battlefield damage and lethal hits do not all trigger a counter. `scripts/retaliate_rules.gd:139`, `:161` |
| Wick Shade | It puts braziers out as part of drifting toward the hero. | False | Its Snuff approaches a selected lit brazier, ends on or adjacent to that brazier and extinguishes it there. The hero-directed approach and Pull are separate actions. Wick Shade Snuff is only available where the hero can relight braziers by stepping on them, which excludes the Lamplighter arena. `data/enemies.json:2682`, `:2700`, `scripts/enemy_mechanics/snuff.gd:2`, `:129` |
| Ashen Reaver | Hooked Sweep strikes everything in front of it. | False | The move strikes within its authored sweep footprint. It targets the hero team, so allied enemies in front of the Reaver are unaffected by the hit. `data/enemies.json:1882`, `scripts/guardian_combat_rules.gd:398`, `scripts/combat_engine.gd:12336` |
| Gallows Roc | Gust moves every unit a full tile. | False | The dial is Push 1. The Roc itself is Anchored, as are some other units. Buried units are excluded and ordinary collision can prevent reaching the next tile. `data/enemies.json:2090`, `data/battlefield_rules.json:291`, `scripts/battlefield_rules/gust.gd:91`, `:126`, `scripts/combat_engine.gd:7453` |
| Gallows Roc | Gust recalculates the direction from the hero to the Roc as the turn ends. | False | The heading is calculated at announcement and held until the beat. Moving around the Roc during the hero turn can leave the announced heading pointing away from the Roc at execution. `scripts/battlefield_rules/gust.gd:231`, `:246`, `scripts/battlefield_rules/dispatcher.gd:223`, `:263` |
| Craghide | Each marked tile always becomes an Outcrop. | False | The Upheaval rule tries to raise each held site. Changed terrain or an occupant that cannot be displaced can keep an individual Mark from rising. `scripts/battlefield_rules/upheaval.gd:87`, `scripts/battlefield_rules/upheaval_rise.gd:23` |
| Craghide | Groundsplit breaks the Outcrops to deal damage. | False | It uses the owned Outcrops as centers for a damage area extending two tiles and excludes each source center from its own area. The action has no source-consumption step. `data/enemies.json:2195`, `scripts/guardian_combat_rules.gd:26`, `:391`, `:421` |
| Craghide | Groundsplit hurts whoever stands beside an Outcrop, including allies. | False | Groundsplit uses ordinary enemy attack targeting. The hero and illusions can be hit, but other enemies are excluded. `scripts/guardian_combat_rules.gd:398`, `scripts/combat_engine.gd:12081`, `:12336` |
| Last Lamplighter | Every brazier the Lamplighter puts out produces a Wick Shade. | False | The brazier is turned off before checking for a legal arrival tile and available summon capacity. With the initial Wick Shade still alive, the cap of 1 can block the summon while Snuff still puts the brazier out. `data/enemies.json:2244`, `scripts/guardian_combat_rules.gd:323`, `:370`, `tests/suites/guardian_rules_suite.gd:190` |
| Last Lamplighter | Each hidden Wick Shade always Blinks 1 tile closer after each player turn. | False | Shadowstep tries eligible hidden Shades. It can find no legal visible landing and skip a Shade. It picks the allowed tile closest to the hero without requiring it to be strictly closer than the Shade's old tile. `data/battlefield_rules.json:324`, `scripts/battlefield_rules/shadowstep.gd:13` |
| Storm Capacitor | It can never change tiles by any combat effect. | UNTESTED | It resists its own movement, Push and Pull. Burrow Grub's Erupt can forcibly place an occupant via a helper without the usual Anchored check. Whether a normal encounter or production sequence can put a Capacitor on that held tile was not witnessed. `scripts/combat_engine.gd:7427`, `:7453`, `:7521`, `scripts/enemy_mechanics/burrow.gd:91` |
| Ember Tick | Scuttle approaches the hero and bites at close range. | True | Move toward up to 3, then melee at Range 1. `data/enemies.json:3085` |
| Ember Tick | The ordinary death Burst hits the adjacent units. | True | The shared Burst hits all living eligible units touching the source cross once, including enemies and the hero, with four orthogonal neighbors. `scripts/enemy_mechanics/death_burst.gd:37`, `scripts/burst_rules.gd:23`, `:54` |
| Ember Tick | The death Burst leaves Fire. | True | The resolver places Fire on the source tile after damage. `scripts/enemy_mechanics/death_burst.gd:46` |
| Ember Tick | Kindle makes the death Burst stronger. | True | Kindle adds 2 to the stored bonus per use up to the cap of 4. Burst adds the bonus to base damage 4. `data/enemies.json:3076`, `:3103`, `scripts/enemy_mechanics/kindle.gd:3`, `scripts/enemy_mechanics/death_burst.gd:7` |
| Ember Hoarder | The Hoarder fights with a brood of Ember Ticks. | True | The encounter roster adds four Ticks. `data/special_encounters.json:293`, `:307`, `scripts/hoarder_room_rules.gd:31` |
| Ember Hoarder | It keeps its distance and scurries away. | True | Scurry retreats up to 2. Its special keep-distance logic can add a one-tile retreat when threatened. `data/enemies.json:3152`, `data/special_encounters.json:297`, `scripts/hoarder_room_rules.gd:93` |
| Ember Hoarder | The Hoarder Bursts on a kill. | True | It has the Tick's death Burst, including Fire on the source tile. The Hoarder catch keeps the Hoarder's own Burst. Slipping away is a dissolve without death effects. `data/enemies.json:3131`, `scripts/enemy_mechanics/death_burst.gd:22`, `scripts/hoarder_room_rules.gd:118`, `tests/suites/hoarder_suite.gd:365` |
| Ember Hoarder | Kindle strengthens its death Burst. | True | The Hoarder's Kindle adds 2 to the same capped bonus the shared death Burst reads. `data/enemies.json:3140`, `scripts/enemy_mechanics/kindle.gd:3`, `scripts/enemy_mechanics/death_burst.gd:7` |
| Ember Hoarder | It slips away with the hoard if the hero takes too long. | True | The deadline is after 5, 4 or 4 player turns by tier. The dissolve changes the objective and the hoard reward is unavailable. `data/special_encounters.json:269`, `:287`, `:301`, `scripts/hoarder_room_rules.gd:104`, `:199` |
| Slag Mortar | It can lob without seeing the landing area. | True | Lob ignores line of sight. Its primary center is aimed at the hero's tile. `data/enemies.json:3359`, `scripts/enemy_mechanics/marked_strike.gd:59`, `:104` |
| Slag Mortar | The lob Marks a cross centered on the hero. | True | The primary cross uses the hero's tile plus four orthogonal arms. The fire Warband captain can add a second cross. Edges can clip the pattern. `scripts/enemy_mechanics/marked_strike.gd:32`, `:100`, `data/special_encounters.json:94` |
| Slag Mortar | Slag lands on its next turn and leaves Fire. | True | The held Marks schedule Slag Lands and control damage and Fire placement. If the activation is skipped, the held follow-up survives the skip. `data/enemies.json:3359`, `scripts/combat_engine.gd:9135`, `scripts/enemy_mechanics/marked_strike.gd:233` |
| Slag Mortar | It braces behind Block. | True | Brace grants Block 6. `data/enemies.json:3390`, `scripts/combat_engine.gd:4983` |
| Slag Mortar | Scatter Shot knocks the hero back. | True | Its short-range ranged shot applies Push 1 to the hit target. `data/enemies.json:3404`, `tests/suites/en04_enemies_suite.gd:411` |
| Ash Hound | Ash Hounds fight with the Ashen Reaver. | True | The Reaver's starting roster contains two Ash Hounds. `scripts/guardian_library.gd:5`, `:25`, `scripts/room_generator.gd:688` |
| Ash Hound | It runs in to bite. | True | Bite approaches up to 3 before Range 1 melee. `data/enemies.json:2313` |
| Ash Hound | Flanking Bite pushes 1 tile. | True | Flanking Bite's melee rider is Push 1. Actual displacement still needs a legal tile. `data/enemies.json:2331`, `scripts/combat_engine.gd:7453` |
| Hoarfrost Seer | It Marks the hero's ground for Icefall. | True | Icefall centers its perpendicular three-tile line on the hero's tile within range. It filters out impassable or terrain-occupied tiles. `data/enemies.json:2743`, `scripts/enemy_mechanics/marked_strike.gd:32` |
| Hoarfrost Seer | Icefall lands on its next turn and leaves Ice. | True | Icefall Land is the held follow-up, retained through a skipped activation. It places Ice on the strike's tiles. `scripts/combat_engine.gd:9135`, `scripts/enemy_mechanics/marked_strike.gd:200`, `:228` |
| Hoarfrost Seer | Its bolts Stagger targets standing on Ice. | True | Rime Bolt has an on-target Ice Stagger 6 rider. The target must be hit. `data/enemies.json:2777`, `scripts/combat_engine.gd:6456` |
| Hoarfrost Seer | It falls back behind Block. | True | Withdraw retreats up to 2 and grants Block 4. `data/enemies.json:2798` |
| Glacial Mirror | It moves forward slowly. | True | Its approach-only Advance moves up to 2, and its base initiative is 15. These are the concrete values behind the qualitative description. `data/enemies.json:3423`, `:3480` |
| Glacial Mirror | It throws a line of refracted cold. | True | Refraction traces up to four tiles in a cardinal line and stops at impassable tiles. `data/enemies.json:3439`, `scripts/enemy_mechanics/reflect.gd:101` |
| Glacial Mirror | Refraction Pierces Block and Staggers hit targets on Ice. | True | The line uses Pierce and the on-target Ice Stagger 6 rider. `data/enemies.json:3439` |
| Glacial Mirror | It can guard itself with Block. | True | Crystal Guard gives Block 6 to a living adjacent other enemy with least Block if present and falls back to itself otherwise. `data/enemies.json:3462`, `scripts/enemy_mechanics/reflect.gd:92` |
| Rime Whelp | Whelps fight with Rimejaw. | True | A Whelp is an initial Rimejaw helper. `scripts/guardian_library.gd:6`, `scripts/room_generator.gd:688` |
| Rime Whelp | It closes in to bite. | True | The ordinary bite can approach 3 tiles before Range 1 melee. `data/enemies.json:2366` |
| Rime Whelp | Its snap Staggers targets standing on Ice. | True | Rime Snap has the Ice Stagger 6 rider. The first bite has no such rider. `data/enemies.json:2366`, `:2384` |
| Rime Spitter | Iskaldra keeps Rime Spitters to fight beside her. | True | Iskaldra starts with two. Rimejaw's roster also includes one. `data/enemies.json:1467`, `scripts/room_generator.gd:693`, `scripts/guardian_library.gd:6` |
| Rime Spitter | Its needle attacks down a line and leaves Ice at the far end. | True | Needle uses a Range 3 line. The resolver places Ice on the last tile of the resolved line if it is nonempty. `data/enemies.json:2426`, `scripts/guardian_combat_rules.gd:391`, `:406` |
| Rime Spitter | Frost spit Staggers hit targets standing on Ice. | True | The other ranged move, Frost Spit, carries the Ice Stagger 6 rider. `data/enemies.json:2445` |
| Arc Thrall | Arc Bolt leaves the ground Electrified. | True | The ranged bolt has an Electrified surface rider. `data/enemies.json:2892`, `scripts/combat_engine.gd:12054` |
| Arc Thrall | Its close-range jab Shocks the hero. | True | Arc Jab is Range 1 melee with Shock 1. `data/enemies.json:2911` |
| Storm Capacitor | It takes no movement actions and resists ordinary Push and Pull. | True | The immobility flag prevents voluntary movement and forced relocation through the normal Push/Pull mover. `data/enemies.json:3167`, `scripts/enemy_mechanics/capacitor.gd:12`, `scripts/combat_engine.gd:4929`, `:7521` |
| Storm Capacitor | It builds Charge and uses Arc Lash at 3 Charge. | True | Charge adds 1 to a cap of 3. At 3 the next assigned intent is Arc Lash, which discharges and resets the counter when resolved. `data/enemies.json:3182`, `scripts/enemy_mechanics/capacitor.gd:23`, `:116` |
| Storm Capacitor | Arc Lash leaps from unit to unit. | True | The chain starts at the closest eligible hero or other enemy within 4, then takes up to 3 orthogonal hops with no repeat victim. `scripts/enemy_mechanics/capacitor.gd:35`, `:74` |
| Storm Capacitor | Shock drains Charge. | True | Going from unshocked to Shocked removes 1 to a minimum of 0 and updates the announced intent. Adding Shock while already Shocked does not drain it again. `data/enemies.json:3182`, `scripts/enemy_mechanics/capacitor.gd:29`, `scripts/combat_engine.gd:6724` |
| Bell Tender | It fights with the Broken Choir. | True | The Cantor's initial roster includes a Bell Tender, which can also appear in the lightning Warband. `scripts/guardian_library.gd:7`, `data/special_encounters.json:143` |
| Bell Tender | It links tiles into Electrified ground the storm can strike. | True | Its connector lays Electrified ground. The lightning rule uses current Electrified tiles rather than checking which unit placed them. `data/enemies.json:2487`, `scripts/guardian_combat_rules.gd:149`, `:360`, `scripts/battlefield_rules/lightning_storm.gd:11` |
| Bell Tender | It fires staff bolts. | True | Staff Bolt is a lightning ranged attack. `data/enemies.json:2506` |
| Gale Herald | Its horn calls the wind. | True | Call the Wind installs the aimed wind effect. The horn is presentation. `data/enemies.json:2832`, `scripts/battlefield_rules/dispatcher.gd:177` |
| Gale Herald | Its bolts knock the hero back. | True | Gust Bolt applies Push 1 on hit. `data/enemies.json:2847` |
| Gale Herald | It gains Block by stilling the air. | True | Still Air grants Block 5. `data/enemies.json:2862` |
| Gust Shrike | Vaeloryx has a Gust Shrike fighting beside it. | True | Vaeloryx's authored opening roster includes one Gust Shrike. The wing origin is lore. `data/enemies.json:1319`, `scripts/room_generator.gd:693` |
| Gust Shrike | It dives in from a distance, striking along its path. | True | Dive approaches up to 4. Its swept area is the union of eligible impact tiles along the route. `data/enemies.json:3510`, `scripts/guardian_combat_rules.gd:137`, `scripts/committed_pattern_shapes.gd:90` |
| Gust Shrike | Dive knocks the hero back on a hit. | True | The swept attack has Push 1, subject to the forced movement resolver. `data/enemies.json:3510`, `scripts/combat_engine.gd:7453` |
| Gust Shrike | It rakes with its talons and retreats behind Block. | True | Talon Rake closes before melee. Hover retreats up to 2 and grants Block 3. `data/enemies.json:3529`, `:3547` |
| Roc Fledgling | Fledglings fight with Gallows Roc in the Hanging Roost. | True | Two are in the Roc's opening roster. The air Warband also carries two. `scripts/guardian_library.gd:8`, `data/special_encounters.json:111` |
| Roc Fledgling | It darts close and pecks. | True | Both moves approach before Range 1 melee. `data/enemies.json:2552`, `:2570` |
| Burrow Grub | Burrow Grubs fight with Tharokh. | True | Tharokh's opening roster contains two. The tunnels and physical roots are lore. `data/enemies.json:1055`, `scripts/room_generator.gd:693` |
| Burrow Grub | It burrows and Marks the hero's current tile. | True | Burrow sets the buried flag and stores the hero tile for Erupt. `data/enemies.json:3013`, `scripts/enemy_mechanics/burrow.gd:34` |
| Burrow Grub | On the next eligible turn it erupts and leaves Rubble. | True | The buried flag forces Erupt. On a successful landing the resolver places Rubble at the landing tile. `scripts/combat_engine.gd:9135`, `scripts/enemy_mechanics/burrow.gd:43`, `:98` |
| Burrow Grub | Erupt exposes the Grub. | True | The surviving Grub gains the move's self-Expose 2. `data/enemies.json:3026`, `scripts/enemy_mechanics/burrow.gd:107` |
| Burrow Grub | It gnaws above ground. | True | Gnaw is the move-then-melee option. The only intent available while buried is Erupt. `data/enemies.json:3042`, `scripts/enemy_mechanics/burrow.gd:27` |
| Briar Weaver | It Marks lines of ground that later rise as Outcrops. | True | Thornwall stores a held line using Upheaval geometry. A later Weaver turn raises it after the fuel timing gate permits, subject to legal placement. `data/enemies.json:3299`, `scripts/enemy_mechanics/bramble.gd:19`, `:60`, `:90` |
| Briar Weaver | It lashes from range. | True | Lash of Thorns is Range 3 ranged. `data/enemies.json:3313` |
| Briar Weaver | It heals the most wounded nearby ally. | True | Root Mend chooses a different living wounded enemy within 3, greatest missing Health first. It cannot target itself even if it is the most wounded. With no eligible ally, a held Root Mend becomes Lash of Thorns. `data/enemies.json:3327`, `scripts/enemy_mechanics/bramble.gd:26`, `scripts/combat_engine.gd:4608`, `:4651`, `tests/suites/en04_enemies_suite.gd:241` |
| Stoneback Mite | Stoneback Mites fight with the Craghide. | True | Two are in the starting roster. Two also follow the Briar Weaver in the earth Warband. `scripts/guardian_library.gd:9`, `data/special_encounters.json:78` |
| Stoneback Mite | It claws at the hero. | True | Claw and Driving Claw use Range 1 melee. `data/enemies.json:2607`, `:2625` |
| Stoneback Mite | Driving Claw shoves the hero while bracing behind a little Block. | True | Driving Claw grants Block 1 before melee with Push 1. `data/enemies.json:2625` |
| Gloam Stalker | Fade is a disappearance and reappearance. | True | Fade uses the Stalker's Blink resolver and reports a veil move for presentation. `data/enemies.json:2948`, `scripts/enemy_mechanics/stalker.gd:53`, `:84` |
| Gloam Stalker | Ambush is the authored next move after Fade. | True | Fade schedules Ambush. Slash replaces it if the attack cannot be set up. `data/enemies.json:2948`, `scripts/combat_engine.gd:9135` |
| Gloam Stalker | Otherwise it approaches and slashes. | True | Slash moves toward the hero before a shadow melee attack. `data/enemies.json:2977` |
| Hollow Mimic | It fires shadow bolts from range. | True | Echo and Shade Bolt have shadow ranged attacks at Range 4. `data/enemies.json:3237`, `:3255` |
| Hollow Mimic | Echo gives a reaction window until its next turn. | True | Echo grants Retaliate 3. Enemy turn start clears it, so multiple qualifying hits within the window can each trigger it. `data/enemies.json:3237`, `scripts/combat_engine.gd:4990`, `:7987`, `tests/suites/mim01_suite.gd:29` |
| Hollow Mimic | It falls back out of reach. | True | Recede moves away by up to 2 when space allows. `data/enemies.json:3269` |
| Wick Shade | The Last Lamplighter can call Wick Shades from braziers it snuffs. | True | The guardian's Snuff separately extinguishes a brazier and tries to spawn one Shade near it. The arena also starts with a Shade. `data/enemies.json:2244`, `scripts/guardian_library.gd:10`, `scripts/guardian_combat_rules.gd:335`, `:370` |
| Wick Shade | It drifts toward the hero and attacks up close. | True | Grasp and Drifting Grasp approach the target before melee. `data/enemies.json:2664`, `:2682` |
| Wick Shade | It can put out braziers. | True | Wick Shade Snuff can extinguish a relightable brazier in Last Light when the Shade reaches it. This is separate from the Lamplighter's Snuff. `data/enemies.json:2700`, `scripts/last_light_rules.gd:100`, `scripts/enemy_mechanics/snuff.gd:129` |
| Wick Shade | Its grasp drags the hero closer. | True | Drifting Grasp has Pull 1. Grasp itself has no Pull rider. `data/enemies.json:2664`, `:2682` |
| Ashen Reaver | It guards the Cinder Yard on the way to Vyraketh. | True | The Guardian catalog maps Vyraketh to the Reaver and the Cinder Yard, and room generation uses that catalog. `scripts/guardian_library.gd:5`, `scripts/room_generator.gd:269`, `:688` |
| Ashen Reaver | It rakes the ground with lines of Fire. | True | Raking Flame lays a broken-line Fire pattern. Executioner's Fall also has a line and Fire rider. `data/enemies.json:1863`, `:1903` |
| Ashen Reaver | It sweeps in front of itself. | True | Hooked Sweep hits its declared forward sweep area, with Fire and Push 1. `data/enemies.json:1882`, `scripts/guardian_combat_rules.gd:137` |
| Ashen Reaver | Its heaviest blow leaves it Exposed. | True | Executioner's Fall is its highest base hit at 8 and applies self-Expose 3 if the Reaver survives. `data/enemies.json:1903`, `scripts/guardian_combat_rules.gd:417` |
| Ashen Reaver | Wildfire spreads the flames toward the hero every other turn. | True | After every second player turn, Wildfire tries to spread each Fire tile by one step using the cardinal direction from the Reaver to the hero. `data/battlefield_rules.json:245`, `scripts/battlefield_rules/wildfire.gd:14`, `scripts/battlefield_rules/geometry.gd:6` |
| Rimejaw | It guards the Broken Rime on the way to Iskaldra. | True | The Guardian catalog maps Iskaldra to Rimejaw and the Broken Rime. `scripts/guardian_library.gd:6`, `scripts/room_generator.gd:688` |
| Rimejaw | It leaves Ice in its tracks. | True | Rime Trail places Ice along the approach path, excluding the final tile. `data/enemies.json:1941`, `scripts/combat_engine.gd:4974` |
| Rimejaw | It pounces from a distance. | True | Harrowing Pounce approaches up to 3 before its Range 1 attack. `data/enemies.json:1959` |
| Rimejaw | Its heavier bites Stagger targets standing on Ice. | True | Harrowing Pounce and the Frostbite move both have base damage 6 and the Ice Stagger rider. The lower damage Rime Trail bite does not. `data/enemies.json:1941`, `:1959`, `:1984` |
| Rimejaw | Frostbite Staggers units on Ice after each player turn. | True | The every-player-turn rule applies Stagger 6 on Ice with damage 0. Normal strike eligibility and Stagger rules still apply. `data/battlefield_rules.json:260`, `scripts/battlefield_rules/frostbite.gd:11`, `tests/suites/guardian_rules_suite.gd:72` |
| Storm Cantor | It leads the Broken Choir on the way to Zekarion. | True | The Guardian catalog maps Zekarion to the Cantor and Broken Choir. `scripts/guardian_library.gd:7`, `scripts/room_generator.gd:688` |
| Storm Cantor | It lays connected Electrified ground across the room. | True | Lay the Choir uses the connector with up to six legal new tiles. `data/enemies.json:2026`, `scripts/guardian_combat_rules.gd:149`, `tests/suites/guardian_rules_suite.gd:93` |
| Storm Cantor | Peal strikes units on Electrified ground. | True | Resolving Peal fires a damage-4 Lightning Storm on all eligible units touching current Electrified ground. Peal is skipped in selection if no Electrified surface exists. `data/battlefield_rules.json:276`, `scripts/battlefield_rules/lightning_storm.gd:11`, `scripts/guardian_combat_rules.gd:539` |
| Storm Cantor | It strikes hard with its staff up close. | True | Broken Rhythm approaches and deals base melee 11 at Range 2. `data/enemies.json:2058` |
| Storm Cantor | It calls Lightning Wisps to its side. | True | Call the Spark can spawn one Lightning Wisp per cast, with a Wisp cap of 2 and available-space checks. The starting roster also includes a Wisp. `data/enemies.json:2075`, `scripts/guardian_library.gd:7`, `scripts/guardian_combat_rules.gd:323`, `tests/suites/guardian_rules_suite.gd:172` |
| Gallows Roc | It occupies the Hanging Roost on the way to Vaeloryx. | True | The Guardian catalog maps Vaeloryx to the Roc and the Hanging Roost. `scripts/guardian_library.gd:8`, `scripts/room_generator.gd:688` |
| Gallows Roc | It hooks the hero from afar and pulls them closer. | True | Hookwind has a Range 4 line and Pull 2. `data/enemies.json:2107` |
| Gallows Roc | Its wing attack throws the hero back. | True | Razor Pinion is a sweep with Push 2. `data/enemies.json:2127` |
| Gallows Roc | It dives in to strike. | True | Grave Dive approaches up to 3 and deals Range 1 melee damage. `data/enemies.json:2147` |
| Gallows Roc | Gust fires after each player turn. | True | Authored after-player-turn cadence is 1, while the source is alive and combat continues. `data/battlefield_rules.json:291`, `scripts/battlefield_rules/dispatcher.gd:200` |
| Gallows Roc | The announced Gust direction is from the hero to the Roc. | True | Announcement locks the dominant cardinal direction toward the Roc from the hero at that moment. The beat uses this same heading for each eligible unit. `scripts/battlefield_rules/gust.gd:231`, `:246`, `:273` |
| Craghide | It occupies the Shattered Burrow on the way to Tharokh. | True | The Guardian catalog maps Tharokh to Craghide and the Shattered Burrow. `scripts/guardian_library.gd:9`, `scripts/room_generator.gd:688` |
| Craghide | Upheaval raises the Marked floor after every second Craghide turn. | True | The encounter's Craghide-sourced Upheaval rule marks the floor when installed, then plans new Marks after each beat. Its cadence counts every second source activation. Crag Heave itself only moves and neither it nor the Mites adds those Marks. `data/battlefield_rules.json:307`, `data/enemies.json:2183`, `scripts/guardian_library.gd:35`, `scripts/battlefield_rules/upheaval.gd:21`, `scripts/battlefield_rules/dispatcher.gd:263` |
| Craghide | Groundsplit damages units beside the Outcrops. | True | It uses its living owned Outcrops and hits eligible tiles within 2 of each, including adjacent tiles. `data/enemies.json:2195`, `scripts/guardian_combat_rules.gd:26`, `:421` |
| Craghide | It charges in for a crushing blow. | True | Crushing Rush approaches up to 3 before a base melee 8 hit. `data/enemies.json:2209` |
| Last Lamplighter | It keeps the Last Watch on the way to Noctyrax. | True | The Guardian catalog maps Noctyrax to the Lamplighter and the Last Watch, with two braziers in the arena. `scripts/guardian_library.gd:10`, `:65`, `scripts/room_generator.gd:688` |
| Last Lamplighter | Snuff extinguishes a brazier and can summon a Wick Shade. | True | The declaration selects a brazier. Resolution extinguishes it and tries to place one Shade near it. Last Procession later restores the braziers and removes outage-owned summons. `data/enemies.json:2244`, `scripts/guardian_combat_rules.gd:181`, `:323`, `:370`, `:40` |
| Last Lamplighter | Its lantern hook pulls the hero closer. | True | Mourning Hook uses a Range 4 line with Pull 1. `data/enemies.json:2259` |
| Last Lamplighter | Last Procession approaches the hero and strikes. | True | Last Procession approaches up to 3 and attacks with Range 1 melee. `data/enemies.json:2278` |
| Last Lamplighter | Its after-player-turn rule makes hidden Wick Shades attempt a one-tile Blink. | True | Shadowstep uses a one-tile search radius and restricts the eligible unit types to hidden Wick Shades. The Lamplighter itself does not Blink. `data/battlefield_rules.json:324`, `scripts/battlefield_rules/shadowstep.gd:13`, `tests/suites/guardian_rules_suite.gd:81` |

## Lore

| Page | Lore |
| --- | --- |
| Ember Tick | Furnace feeding, swollen shell and visible cracks. |
| Ember Hoarder | Having gorged on Embers, barely running and physically sitting on its hoard. |
| Slag Mortar | Squat build, furnace bowl and origin as an artillery creature for the Cinder Crown. |
| Ash Hound | Scorched, smouldering hide and breeding history. |
| Hoarfrost Seer | Hood, the journey north, staying in the Rime Hall and reading frost like stars. |
| Glacial Mirror | Glacier body and crystal chest pane. |
| Rime Whelp | Age, relation to Rimejaw, growing spines and hunting history. |
| Rime Spitter | Toad appearance, frosty throat and the hound-keeper comparison. |
| Arc Thrall | Tempest Spire servitude, collar, rod, size and the subjective sensation of shocks. |
| Storm Capacitor | Iron jar, something trying to escape and its place in the floor of the Spire. |
| Bell Tender | Hood, brass mask and carrying the choir's song. |
| Gale Herald | Wind-torn banners and sounding Vaeloryx's call. |
| Gust Shrike | Small hawk appearance and the wing-spark origin. |
| Roc Fledgling | Age and still growing into its wings. |
| Burrow Grub | Blindness, size and the tunnels it chews through Tharokh's roots. |
| Briar Weaver | Root-and-thorn body, origin and tending stone like a gardener. |
| Stoneback Mite | Stone shell and living among the Craghide's plates. |
| Gloam Stalker | Hood, sickles, deepest Umbra and the description of how rarely the hero sees it first. |
| Hollow Mimic | Copying the hero's shape, hair and armor, and how the dark learns. |
| Wick Shade | Lost traveller, hooded shape and a light in place of a face. |
| Ashen Reaver | Executioner history, blackened plate and the unlit forge behind the glowing falchion. |
| Rimejaw | Pale body, skull face, Ice spines and how it hunts. |
| Storm Cantor | Gilding, hymns and people still singing them above the Labyrinth. |
| Gallows Roc | Carthorse-scale size, feathers, charms, ropes and nesting history. |
| Craghide | Bear body, stone plates, centuries of sleep and dislike of being woken. |
| Last Lamplighter | Last keeper, making the rounds and the worldbuilding around shades and extinguished flames. |

The focused Godot checks and their outcomes are in [result.md](result.md).
