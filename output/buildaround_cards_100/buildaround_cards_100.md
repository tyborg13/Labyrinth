# Labyrinth of Ash - 100 Text Build-Around Card Concepts

Staged design artifact. These cards are not implemented in `data/cards.json`, but each one now has proposed card data, a `text_rule` action contract, a processed `256x144` RGBA card-art asset, and a rendered selection preview.
They intentionally use text-rule mechanics that need bespoke combat, UI, heuristic, and analytics work before shipping.

Primary staged data file: `proposed_cards_game_ready.json`.
Design metadata file: `buildaround_cards_100_design.json`.

## Image Sheets

- `buildaround_card_sheet_01.png`
- `buildaround_card_sheet_02.png`
- `buildaround_card_sheet_03.png`
- `buildaround_card_sheet_04.png`
- `buildaround_card_sheet_05.png`

## Cards

## Neutral

### 001. Chrono Forge

- id: `chrono_forge`
- rarity: common
- element: Neutral
- cost: time 6, Exhaust
- kind: LAW
- text: For this combat, the first card you play each turn costs -2 time. Cards with printed time 7+ also draw 1.
- hooks: high-time payoffs, draw, slow rares
- iconography: TIME, DRAW, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/chrono_forge.png`
- art direction: a brass forge hammering deck cards into clock gears

### 002. Turnstile Rite

- id: `turnstile_rite`
- rarity: common
- element: Neutral
- cost: time 4
- kind: LAW
- text: Each turn: your first card costs 0 time, your second costs +3 time, your third costs -3 time.
- hooks: card-play sequencing, low-cost fillers
- iconography: TIME, ORDER, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/turnstile_rite.png`
- art direction: a rotating dungeon turnstile with three glowing tally marks

### 003. Empty Hand Oath

- id: `empty_hand_oath`
- rarity: common
- element: Neutral
- cost: time 3
- kind: ENGINE
- text: For this combat, if your hand is empty at end of turn, draw 2 and gain 1 card play next turn.
- hooks: cheap cards, card plays, hand dumps
- iconography: DRAW, PLAY, HAND
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/empty_hand_oath.png`
- art direction: an open ash-stained palm over a blank parchment deck

### 004. Vow of One

- id: `vow_of_one`
- rarity: common
- element: Neutral
- cost: time 5, Exhaust
- kind: PACT
- text: For this combat, you may play only one card each turn. That card costs -4 time and its numeric values are doubled.
- hooks: single-card turns, big attacks, big block
- iconography: TIME, X2, PACT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/vow_of_one.png`
- art direction: a lone sword standing in a circle of extinguished candles

### 005. Common Cause

- id: `common_cause`
- rarity: common
- element: Neutral
- cost: time 4
- kind: ENGINE
- text: For this combat, common cards gain +2 damage or +2 block. When a common card Exhausts, draw 1.
- hooks: common-heavy decks, Exhaust, starters
- iconography: COMMON, DRAW, EXH
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/common_cause.png`
- art direction: a bundle of plain iron tools tied with a gold thread

### 006. Black Archive

- id: `black_archive`
- rarity: uncommon
- element: Neutral
- cost: time 7, Exhaust
- kind: ENGINE
- text: Return your Exhausted cards to the draw pile. For this combat, whenever a card Exhausts, deal 2 to all enemies.
- hooks: Exhaust loops, rare spikes, AOE chip
- iconography: EXH, AOE, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/black_archive.png`
- art direction: a charred library shelf releasing glowing card-ash pages

### 007. Mirror Doctrine

- id: `mirror_doctrine`
- rarity: uncommon
- element: Neutral
- cost: time 5, Exhaust
- kind: LAW
- text: For this combat, your illusions copy the first status you apply each turn to the nearest enemy at 50% value.
- hooks: illusions, burn, poison, freeze, shock
- iconography: ILLUS, STATUS, COPY
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/mirror_doctrine.png`
- art direction: two hooded reflections in a cracked obsidian mirror

### 008. Debt Ledger

- id: `debt_ledger`
- rarity: uncommon
- element: Neutral
- cost: time 4, health cost 1
- kind: PACT
- text: For this combat, whenever you pay health, draw that many cards and gain that much block. Healing cannot repay this debt.
- hooks: health costs, draw, block engines
- iconography: HP, DRAW, BLOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/debt_ledger.png`
- art direction: a blood-marked account book chained to a coin scale

### 009. Last Bad Bargain

- id: `last_bad_bargain`
- rarity: rare
- element: Neutral
- cost: time 9, Exhaust
- kind: PACT
- text: Set your health to 1. Gain 40 block. For this combat, your attacks gain +6 damage and pierce.
- hooks: glass-cannon decks, block, pierce
- iconography: HP, BLOCK, PIERCE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/last_bad_bargain.png`
- art direction: a desperate pact sealed with one red candle and a cracked shield

### 010. Courier Law

- id: `courier_law`
- rarity: uncommon
- element: Neutral
- cost: time 5
- kind: LAW
- text: For this combat, after you move 5+ tiles in a turn, your next ranged or AOE card ignores line of sight and gains +2 range.
- hooks: move, ranged, AOE, trap paths
- iconography: MOVE, RANGE, LOS
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/courier_law.png`
- art direction: a masked runner carrying a sealed letter through broken doorways

### 011. Reliquary of Hands

- id: `reliquary_of_hands`
- rarity: rare
- element: Neutral
- cost: time 7, Exhaust
- kind: ENGINE
- text: For this combat, whenever you gain card plays, draw that many cards. Once each turn, drawing 3+ cards gives 1 card play.
- hooks: draw engines, card-play engines
- iconography: DRAW, PLAY, ENGINE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/reliquary_of_hands.png`
- art direction: a reliquary filled with many small skeletal hands holding cards

### 012. Tempo Thief

- id: `tempo_thief`
- rarity: uncommon
- element: Neutral
- cost: time 5, Exhaust
- kind: BURST
- text: Delay all enemies by 3 time. For this combat, each 1-2 time card you play delays the nearest enemy by 1.
- hooks: fast cards, initiative control
- iconography: TIME, FAST, DELAY
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/tempo_thief.png`
- art direction: a cloaked thief stealing clock hands from enemy shadows

### 013. Maw of the Deck

- id: `maw_of_the_deck`
- rarity: uncommon
- element: Neutral
- cost: time 6
- kind: ENGINE
- text: For this combat, each card drawn past 5 in hand is fed to the Maw. At 3 fed cards, deal 12 to all enemies and draw 1.
- hooks: big draw, overflow, AOE payoff
- iconography: DRAW, AOE, COUNT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/maw_of_the_deck.png`
- art direction: a toothy wooden deck box swallowing glowing cards

### 014. Parliament of Echoes

- id: `parliament_of_echoes`
- rarity: rare
- element: Neutral
- cost: time 8, Exhaust
- kind: LAW
- text: For this combat, the first card you play each turn echoes: repeat its non-movement text at 50% values.
- hooks: big text cards, status payoffs
- iconography: ECHO, TEXT, X2
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/parliament_of_echoes.png`
- art direction: a council of pale masks repeating one burning sentence

### 015. Undertaker's Map

- id: `undertakers_map`
- rarity: uncommon
- element: Neutral
- cost: time 5, Exhaust
- kind: FIELD
- text: Mark all enemies. First time a Marked enemy dies, blink to its tile, draw 1, and move the Mark to the nearest enemy.
- hooks: kills, blink, target routing
- iconography: MARK, BLINK, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/undertakers_map.png`
- art direction: a burial map with pins joined by ghostly thread

### 016. Rare Disease

- id: `rare_disease`
- rarity: rare
- element: Neutral
- cost: time 6, Exhaust
- kind: PACT
- text: For this combat, rare cards cost -3 time and Exhaust. Whenever a rare card Exhausts, deal 5 to all enemies.
- hooks: rare-heavy decks, Exhaust, tempo
- iconography: RARE, TIME, EXH
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/rare_disease.png`
- art direction: a violet gem infecting ornate card frames with black veins

### 017. Skeleton Key

- id: `skeleton_key`
- rarity: uncommon
- element: Neutral
- cost: time 5
- kind: LAW
- text: For this combat, your cards have +2 range. Blink cards also create a 1-health illusion at your old tile.
- hooks: range, blink, illusions
- iconography: RANGE, BLINK, ILLUS
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/skeleton_key.png`
- art direction: a bone key opening several impossible dungeon doors at once

### 018. Blood Alphabet

- id: `blood_alphabet`
- rarity: rare
- element: Neutral
- cost: time 6, Exhaust, health cost 2
- kind: ENGINE
- text: For this combat, losing health writes a Letter. At 3 Letters, clear them, draw 2, and your attacks gain +3 this turn.
- hooks: self-damage, draw, burst turns
- iconography: HP, DRAW, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/blood_alphabet.png`
- art direction: red runic letters crawling across a vellum card

### 019. Oath of Ash

- id: `oath_of_ash`
- rarity: rare
- element: Neutral
- cost: time 7, Exhaust
- kind: LAW
- text: For this combat, neutral cards count as your highest-intensity element and raise that element by 1 when played.
- hooks: neutral cards, elemental intensity
- iconography: NEUT, INT, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/oath_of_ash.png`
- art direction: a grey oath stone split by five colored embers

### 020. Silent Majority

- id: `silent_majority`
- rarity: uncommon
- element: Neutral
- cost: time 4
- kind: ENGINE
- text: For this combat, neutral cards cost -1 time. Each third neutral card you play creates a 2-health illusion.
- hooks: neutral decks, illusions, tempo
- iconography: NEUT, TIME, ILLUS
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/silent_majority.png`
- art direction: a crowd of blank masks standing behind a single lit card

## Fire

### 021. Ash Tax

- id: `ash_tax`
- rarity: common
- element: Fire
- cost: time 5
- kind: LAW
- text: For this combat, burn ticks raise Fire intensity by 1 before decay. At Fire 4+, burn ticks twice.
- hooks: burn stacking, Fire intensity
- iconography: BURN, INT, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/ash_tax.png`
- art direction: tax coins melting into a basin of red ash

### 022. Furnace Choir

- id: `furnace_choir`
- rarity: common
- element: Fire
- cost: time 7, Exhaust
- kind: BURST
- text: Apply 8 burn to all enemies. For this combat, when burn expires on an enemy, spread 4 burn to the nearest enemy.
- hooks: AOE burn, spread, crowd fights
- iconography: BURN, AOE, SPREAD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/furnace_choir.png`
- art direction: robed furnace mouths singing sparks into a dark hall

### 023. Red Thread

- id: `red_thread`
- rarity: common
- element: Fire
- cost: time 5
- kind: ENGINE
- text: For this combat, the first time you damage a burning enemy each turn, repeat that damage on every other burning enemy.
- hooks: burn setup, AOE conversion
- iconography: BURN, COPY, AOE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/red_thread.png`
- art direction: a glowing red thread stitching several burning targets together

### 024. Cinder Bank

- id: `cinder_bank`
- rarity: uncommon
- element: Fire
- cost: time 4
- kind: ENGINE
- text: For this combat, overkill from burn is banked. Your next attack spends the bank as bonus fire damage.
- hooks: burn kills, overkill, big hits
- iconography: BURN, BANK, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/cinder_bank.png`
- art direction: a small iron vault packed with orange-hot cinders

### 025. Bonfire Pact

- id: `bonfire_pact`
- rarity: uncommon
- element: Fire
- cost: time 6, Exhaust
- kind: PACT
- text: Exhaust 2 cards from your hand. For this combat, your attacks apply burn equal to cards Exhausted this combat.
- hooks: Exhaust decks, attacks, burn
- iconography: EXH, BURN, PACT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/bonfire_pact.png`
- art direction: two cards burning upright in a ritual bonfire

### 026. Kindling Engine

- id: `kindling_engine`
- rarity: uncommon
- element: Fire
- cost: time 5, Exhaust
- kind: ENGINE
- text: For this combat, whenever any card Exhausts, apply 3 burn to all enemies and raise Fire intensity by 1.
- hooks: Exhaust, Fire intensity, AOE burn
- iconography: EXH, BURN, INT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/kindling_engine.png`
- art direction: a crank engine feeding torn cards into a furnace heart

### 027. Smoke Debt

- id: `smoke_debt`
- rarity: uncommon
- element: Fire
- cost: time 5
- kind: LAW
- text: For this combat, burning enemies deal -1 damage per 5 burn on them. When their burn decays, gain that much block.
- hooks: defensive burn, block, attrition
- iconography: BURN, BLOCK, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/smoke_debt.png`
- art direction: a shield made of debt notes dissolving into black smoke

### 028. Wildfire Crown

- id: `wildfire_crown`
- rarity: rare
- element: Fire
- cost: time 8, Exhaust
- kind: ENGINE
- text: For this combat, when burn kills an enemy, draw 2, gain 1 card play, and transfer its remaining burn to all enemies.
- hooks: burn kills, draw, card plays
- iconography: BURN, DRAW, PLAY
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/wildfire_crown.png`
- art direction: a crown of fire throwing sparks from one skull to many

### 029. Molten Calendar

- id: `molten_calendar`
- rarity: uncommon
- element: Fire
- cost: time 7, Exhaust
- kind: FIELD
- text: For this combat, after every third player turn, apply 18 burn to all enemies. Fire cards advance the calendar one step.
- hooks: long fights, Fire card density
- iconography: BURN, COUNT, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/molten_calendar.png`
- art direction: a lava calendar with three glowing dates cracked open

### 030. Soot Mirror

- id: `soot_mirror`
- rarity: rare
- element: Fire
- cost: time 6, Exhaust
- kind: PACT
- text: For this combat, burn on you also ticks on all enemies. At end of turn, move half your burn to the healthiest enemy.
- hooks: self-burn, enemy swarms, risk
- iconography: BURN, HP, COPY
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/soot_mirror.png`
- art direction: a smoky mirror reflecting the hero as a burning silhouette

### 031. Ignition Point

- id: `ignition_point`
- rarity: uncommon
- element: Fire
- cost: time 5
- kind: ENGINE
- text: For this combat, applying burn to an already burning enemy deals damage equal to the smaller burn value to it and adjacent enemies.
- hooks: stacking burn, adjacency, AOE
- iconography: BURN, AOE, STACK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/ignition_point.png`
- art direction: two sparks colliding into a flower-shaped explosion

### 032. Ember Tithe

- id: `ember_tithe`
- rarity: rare
- element: Fire
- cost: time 5, Exhaust, health cost 1
- kind: PACT
- text: For this combat, the first attack damage you deal each turn costs 1 health and applies burn equal to half that damage.
- hooks: self-damage, big attacks, burn
- iconography: HP, DMG, BURN
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/ember_tithe.png`
- art direction: a red tithe bowl receiving blood and returning embers

### 033. Firebreak Clause

- id: `firebreak_clause`
- rarity: uncommon
- element: Fire
- cost: time 4
- kind: LAW
- text: Convert all burn on you into block. For this combat, each 3 block you gain applies 1 burn to the nearest enemy.
- hooks: block engines, self-burn cleanup
- iconography: BLOCK, BURN, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/firebreak_clause.png`
- art direction: a legal scroll used as a shield against a wall of flame

### 034. Sunken Kiln

- id: `sunken_kiln`
- rarity: rare
- element: Fire
- cost: time 8, Exhaust
- kind: FIELD
- text: Set Fire intensity to 3. For this combat, Fire intensity cannot fall below 3, but non-Fire cards cost +1 time.
- hooks: mono-Fire decks, intensity scaling
- iconography: FIRE, INT, TIME
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/sunken_kiln.png`
- art direction: a submerged furnace glowing beneath black water

### 035. Ashen Encore

- id: `ashen_encore`
- rarity: rare
- element: Fire
- cost: time 7, Exhaust
- kind: ENGINE
- text: For this combat, the first Fire card that Exhausts each turn returns next turn as a 0-time copy, then vanishes.
- hooks: Fire Exhaust, burst repeats
- iconography: FIRE, EXH, ECHO
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/ashen_encore.png`
- art direction: a singer made of ash bowing as a card reignites

### 036. Dragon's Due

- id: `dragons_due`
- rarity: rare
- element: Fire
- cost: time 10, Exhaust
- kind: BURST
- text: Apply 40 burn to all enemies. Until an enemy dies, your cards cost +2 time.
- hooks: huge burn, kill race, tempo risk
- iconography: BURN, AOE, TIME
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/dragons_due.png`
- art direction: a dragon-shaped debt mark branded over a battlefield

## Ice

### 037. Absolute Zero

- id: `absolute_zero`
- rarity: common
- element: Ice
- cost: time 8, Exhaust
- kind: BURST
- text: Freeze all enemies. For this combat, frozen enemies keep burn and poison from decaying.
- hooks: freeze, burn, poison
- iconography: FREEZE, BURN, POISON
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/absolute_zero.png`
- art direction: a black-blue eclipse freezing a room in a single ring

### 038. Glass Library

- id: `glass_library`
- rarity: common
- element: Ice
- cost: time 5
- kind: ENGINE
- text: For this combat, whenever a frozen enemy takes damage, store half. When freeze ends, deal the stored damage again.
- hooks: freeze setup, delayed burst
- iconography: FREEZE, BANK, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/glass_library.png`
- art direction: shelves of transparent books cracking with trapped impacts

### 039. Hoarfrost Contract

- id: `hoarfrost_contract`
- rarity: common
- element: Ice
- cost: time 4
- kind: LAW
- text: For this combat, the first time each enemy would act, if Ice is 2+, spend 1 Ice to freeze it instead.
- hooks: Ice intensity, turn denial
- iconography: ICE, FREEZE, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/hoarfrost_contract.png`
- art direction: a frost-covered contract signed by a claw of ice

### 040. Shatter Bank

- id: `shatter_bank`
- rarity: uncommon
- element: Ice
- cost: time 5
- kind: ENGINE
- text: For this combat, overkill against frozen enemies becomes Shards. Your next attack spends Shards as bonus damage.
- hooks: freeze kills, overkill, burst
- iconography: FREEZE, BANK, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/shatter_bank.png`
- art direction: a crystal bank filled with coin-like shards of frozen damage

### 041. Crystal Prison

- id: `crystal_prison`
- rarity: uncommon
- element: Ice
- cost: time 6, Exhaust
- kind: FIELD
- text: Create two 4-health ice illusions. For this combat, enemies that hit your illusions become frozen.
- hooks: illusions, freeze, enemy targeting
- iconography: ILLUS, FREEZE, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/crystal_prison.png`
- art direction: two glass decoys inside a jagged crystal cage

### 042. Snowblind Map

- id: `snowblind_map`
- rarity: uncommon
- element: Ice
- cost: time 5
- kind: LAW
- text: For this combat, enemies farther than 3 tiles treat you as invisible unless you damaged them this turn.
- hooks: kiting, range, movement
- iconography: RANGE, MOVE, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/snowblind_map.png`
- art direction: a dungeon map erased by white wind except for three black tiles

### 043. Slow Moon

- id: `slow_moon`
- rarity: uncommon
- element: Ice
- cost: time 7, Exhaust
- kind: FIELD
- text: Delay all enemies by 4 time. For this combat, enemy delays are 50% stronger, but your first card each turn costs +1 time.
- hooks: initiative control, freeze, push time
- iconography: TIME, DELAY, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/slow_moon.png`
- art direction: a pale moon hanging low over frozen clockwork

### 044. Cold Read

- id: `cold_read`
- rarity: uncommon
- element: Ice
- cost: time 4
- kind: ENGINE
- text: For this combat, before each enemy acts, draw 1. If that enemy is frozen or shocked, draw 2 instead.
- hooks: freeze/shock, draw, enemy pacing
- iconography: DRAW, FREEZE, SHOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/cold_read.png`
- art direction: a blue candle illuminating enemy intent cards under ice

### 045. Silence Underfoot

- id: `silence_underfoot`
- rarity: uncommon
- element: Ice
- cost: time 5
- kind: LAW
- text: For this combat, moving through traps prevents their trigger. Your next attack after moving freezes if Ice is 2+.
- hooks: movement, traps, Ice intensity
- iconography: MOVE, TRAP, FREEZE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/silence_underfoot.png`
- art direction: soft snow covering a row of hidden spike traps

### 046. Ice Nine

- id: `ice_nine`
- rarity: rare
- element: Ice
- cost: time 8, Exhaust
- kind: LAW
- text: For this combat, burn and poison on frozen enemies do not decay. When freeze ends, those statuses tick once immediately.
- hooks: status stacking, freeze windows
- iconography: FREEZE, STATUS, TICK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/ice_nine.png`
- art direction: nine angular ice crystals trapping green and red fumes

### 047. Pale Refrain

- id: `pale_refrain`
- rarity: rare
- element: Ice
- cost: time 6, Exhaust
- kind: ENGINE
- text: For this combat, the first card each turn that freezes an enemy returns to hand with +2 time.
- hooks: freeze density, replay, time tax
- iconography: FREEZE, ECHO, TIME
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/pale_refrain.png`
- art direction: a pale bell echoing a frozen card back into a hand

### 048. Glacier Debt

- id: `glacier_debt`
- rarity: rare
- element: Ice
- cost: time 7, Exhaust
- kind: PACT
- text: Gain 12 stoneskin. For this combat, whenever stoneskin absorbs damage, freeze the attacker and lose 2 stoneskin.
- hooks: stoneskin, freeze, tank builds
- iconography: STONE, FREEZE, PACT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/glacier_debt.png`
- art direction: a towering ice debt-marker carved into a stone shield

### 049. Frost Dividend

- id: `frost_dividend`
- rarity: uncommon
- element: Ice
- cost: time 5
- kind: ENGINE
- text: For this combat, whenever an enemy skips action from freeze or shock, draw 2 and gain 4 block.
- hooks: freeze, shock, defense draw
- iconography: FREEZE, SHOCK, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/frost_dividend.png`
- art direction: frosted coins falling from a sleeping enemy silhouette

### 050. White Trial

- id: `white_trial`
- rarity: rare
- element: Ice
- cost: time 8, Exhaust
- kind: FIELD
- text: Freeze the healthiest enemy. For this combat, damage dealt to it is mirrored at 50% to all frozen enemies.
- hooks: boss focus, freeze swarms
- iconography: FREEZE, COPY, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/white_trial.png`
- art direction: a white tribunal mirror judging one large frozen foe

### 051. Rime Escrow

- id: `rime_escrow`
- rarity: rare
- element: Ice
- cost: time 6, Exhaust
- kind: ENGINE
- text: For this combat, the first 10 damage you would deal each turn is stored. At turn end, deal it to a frozen enemy and draw 1.
- hooks: damage timing, freeze targets
- iconography: BANK, FREEZE, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/rime_escrow.png`
- art direction: a locked ice chest holding a red damage glyph

### 052. Frozen Minute

- id: `frozen_minute`
- rarity: rare
- element: Ice
- cost: time 7, Exhaust
- kind: LAW
- text: For this combat, your first card each turn costs +2 time but plays twice if it targets a frozen enemy.
- hooks: freeze payoff, big first cards
- iconography: TIME, FREEZE, X2
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/frozen_minute.png`
- art direction: a minute hand trapped between two mirrored ice cards

## Lightning

### 053. Capacitor Heart

- id: `capacitor_heart`
- rarity: common
- element: Lightning
- cost: time 4
- kind: ENGINE
- text: For this combat, unspent card plays at end of turn become Lightning intensity. At Lightning 4+, draw 1 at turn start.
- hooks: card plays, Lightning intensity
- iconography: PLAY, INT, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/capacitor_heart.png`
- art direction: a brass heart battery with card-play sparks inside

### 054. Chain Legislature

- id: `chain_legislature`
- rarity: common
- element: Lightning
- cost: time 5
- kind: LAW
- text: For this combat, single-target ranged attacks gain chain 1. Chain jumps shock if Lightning is 3+.
- hooks: ranged decks, chain, shock
- iconography: RANGE, CHAIN, SHOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/chain_legislature.png`
- art direction: a row of lightning-robed judges connected by bright arcs

### 055. Static Market

- id: `static_market`
- rarity: common
- element: Lightning
- cost: time 5
- kind: ENGINE
- text: For this combat, your cards cost -1 time for each shocked enemy, to a minimum of 1.
- hooks: shock spread, fast turns
- iconography: SHOCK, TIME, ENGINE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/static_market.png`
- art direction: a market stall trading clocks for crackling blue sparks

### 056. Storm Battery

- id: `storm_battery`
- rarity: uncommon
- element: Lightning
- cost: time 5
- kind: ENGINE
- text: For this combat, whenever you draw 2+ cards at once, gain 1 Charge. At 3 Charges, shock all enemies and clear Charges.
- hooks: draw bursts, shock AOE
- iconography: DRAW, SHOCK, COUNT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/storm_battery.png`
- art direction: a glass battery jar storing three jagged storm bolts

### 057. Spark Double

- id: `spark_double`
- rarity: uncommon
- element: Lightning
- cost: time 4
- kind: ENGINE
- text: For this combat, when an illusion is destroyed, shock the nearest enemy, deal 6, and draw 1.
- hooks: illusions, enemy targeting, shock
- iconography: ILLUS, SHOCK, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/spark_double.png`
- art direction: a duplicate made of sparks collapsing into an enemy

### 058. Conductive Floor

- id: `conductive_floor`
- rarity: uncommon
- element: Lightning
- cost: time 6, Exhaust
- kind: FIELD
- text: For this combat, enemies moved by push or pull leave a lightning trail. Chain jumps through trails deal +4.
- hooks: push/pull, chain routing
- iconography: MOVE, CHAIN, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/conductive_floor.png`
- art direction: dungeon floor tiles etched with glowing conductive grooves

### 059. Dead Switch

- id: `dead_switch`
- rarity: uncommon
- element: Lightning
- cost: time 4, Exhaust
- kind: PACT
- text: For this combat, whenever you take unblocked damage, shocked enemies take the same damage and lose shock.
- hooks: shock, self-risk, retaliation
- iconography: HP, SHOCK, COPY
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/dead_switch.png`
- art direction: a cracked switch strapped to a heart with lightning wire

### 060. Voltaic Audit

- id: `voltaic_audit`
- rarity: uncommon
- element: Lightning
- cost: time 6
- kind: ENGINE
- text: For this combat, every third card you play repeats its damage against the nearest shocked enemy.
- hooks: multi-card turns, shock payoff
- iconography: COUNT, SHOCK, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/voltaic_audit.png`
- art direction: an electric ledger counting every third card with gold sparks

### 061. Crown of Seconds

- id: `crown_of_seconds`
- rarity: uncommon
- element: Lightning
- cost: time 5, Exhaust
- kind: LAW
- text: For this combat, cards with time 6+ resolve as time 5, then their first attack gains +4 damage and chain 1.
- hooks: slow attacks, chain, tempo
- iconography: TIME, CHAIN, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/crown_of_seconds.png`
- art direction: a crown of clock hands struck by yellow lightning

### 062. Blackout Bloom

- id: `blackout_bloom`
- rarity: rare
- element: Lightning
- cost: time 7, Exhaust
- kind: FIELD
- text: For this combat, shocked enemies cannot gain block or stoneskin and take +2 from every chain jump.
- hooks: shock control, chain damage
- iconography: SHOCK, CHAIN, BLOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/blackout_bloom.png`
- art direction: a black flower opening in a burst of silent lightning

### 063. Forked Fate

- id: `forked_fate`
- rarity: rare
- element: Lightning
- cost: time 6, Exhaust
- kind: LAW
- text: Bind the two closest enemies. For this combat, status applied to one is copied at 50% value to the other.
- hooks: status decks, two-target fights
- iconography: STATUS, COPY, PAIR
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/forked_fate.png`
- art direction: two enemy shadows tied by a forked lightning thread

### 064. Lightning Rod

- id: `lightning_rod`
- rarity: rare
- element: Lightning
- cost: time 6, Exhaust
- kind: FIELD
- text: Create a 5-health rod illusion. For this combat, chain effects jump through it and shocked enemies prefer targeting it.
- hooks: illusions, chain routing, defense
- iconography: ILLUS, CHAIN, SHOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/lightning_rod.png`
- art direction: a metal decoy rod drawing all arcs into its raised hand

### 065. Battery Acid

- id: `battery_acid`
- rarity: uncommon
- element: Lightning
- cost: time 5
- kind: ENGINE
- text: For this combat, when shock ends on an enemy, apply poison equal to twice your Lightning intensity.
- hooks: shock, poison, cross-element
- iconography: SHOCK, POISON, INT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/battery_acid.png`
- art direction: yellow acid dripping from a cracked storm battery

### 066. Relay Race

- id: `relay_race`
- rarity: rare
- element: Lightning
- cost: time 6
- kind: ENGINE
- text: For this combat, every 3 tiles you move reduces next card time by 1 and gives its first attack chain 1.
- hooks: movement, chain, tempo
- iconography: MOVE, TIME, CHAIN
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/relay_race.png`
- art direction: runners passing a spark baton across dungeon tiles

### 067. Eye of Zekarion

- id: `eye_of_zekarion`
- rarity: rare
- element: Lightning
- cost: time 8, Exhaust
- kind: LAW
- text: For this combat, shock-immune enemies take +6 from Lightning cards and count as shocked for your bonuses.
- hooks: boss tech, shock payoffs
- iconography: BOSS, SHOCK, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/eye_of_zekarion.png`
- art direction: a golden storm eye staring from an armored mask

### 068. Thunder Mortgage

- id: `thunder_mortgage`
- rarity: rare
- element: Lightning
- cost: time 3, Exhaust
- kind: PACT
- text: Gain 3 card plays now. For this combat, each card after the second each turn adds +2 time debt to your next turn.
- hooks: explosive turns, delayed penalty
- iconography: PLAY, TIME, PACT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/thunder_mortgage.png`
- art direction: a contract nailed to a storm cloud with three bright seals

## Air

### 069. Wind Act

- id: `wind_act`
- rarity: common
- element: Air
- cost: time 5
- kind: LAW
- text: For this combat, move and blink cards cost 0 time. Attacks played before you move each turn cost +2 time.
- hooks: movement-first decks, tempo
- iconography: MOVE, BLINK, TIME
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/wind_act.png`
- art direction: a legal decree unfurling as a green wind spiral

### 070. Empty Tile Gospel

- id: `empty_tile_gospel`
- rarity: common
- element: Air
- cost: time 4
- kind: ENGINE
- text: For this combat, first time each turn you end movement on a tile you have not occupied, draw 1 and gain 1 block.
- hooks: pathing, draw, kiting
- iconography: MOVE, DRAW, BLOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/empty_tile_gospel.png`
- art direction: a glowing footprint on an untouched slate tile

### 071. Cyclone Court

- id: `cyclone_court`
- rarity: common
- element: Air
- cost: time 6, Exhaust
- kind: FIELD
- text: For this combat, at end of your turn, push all enemies 1 away from you. If they hit walls, deal 4.
- hooks: positioning, wall damage
- iconography: PUSH, AOE, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/cyclone_court.png`
- art direction: a circular courtroom of wind hurling enemies outward

### 072. Kite Doctrine

- id: `kite_doctrine`
- rarity: uncommon
- element: Air
- cost: time 4
- kind: ENGINE
- text: For this combat, ranged attacks gain +1 damage for each tile you moved this turn, max +8.
- hooks: move, ranged, burst setup
- iconography: MOVE, RANGE, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/kite_doctrine.png`
- art direction: a paper war kite dragging a glowing arrow-tail

### 073. Borrowed Door

- id: `borrowed_door`
- rarity: uncommon
- element: Air
- cost: time 5, Exhaust
- kind: FIELD
- text: Blink 6. For this combat, your first blink each turn leaves a door; your next move may start from any door.
- hooks: blink, map control, escape routes
- iconography: BLINK, MOVE, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/borrowed_door.png`
- art direction: a teal door floating sideways in an impossible corridor

### 074. Slipstream Engine

- id: `slipstream_engine`
- rarity: uncommon
- element: Air
- cost: time 5
- kind: ENGINE
- text: For this combat, whenever an enemy is pushed or pulled, gain 1 card play, once per card.
- hooks: push, pull, combo turns
- iconography: PUSH, PULL, PLAY
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/slipstream_engine.png`
- art direction: a compact turbine made of cards and green current

### 075. Gale Receipts

- id: `gale_receipts`
- rarity: uncommon
- element: Air
- cost: time 4
- kind: LAW
- text: For this combat, forced movement blocked by wall, unit, or pit deals 3 damage per blocked tile.
- hooks: push/pull, wall traps
- iconography: PUSH, PULL, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/gale_receipts.png`
- art direction: a pile of stamped receipts whipped against stone walls

### 076. Draft Market

- id: `draft_market`
- rarity: uncommon
- element: Air
- cost: time 6, Exhaust
- kind: ENGINE
- text: Draw 3. For this combat, cards drawn after you move cost -2 time this turn.
- hooks: movement, draw, tempo bursts
- iconography: DRAW, MOVE, TIME
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/draft_market.png`
- art direction: a wind market where cards flutter from hanging stalls

### 077. Sky Tax

- id: `sky_tax`
- rarity: uncommon
- element: Air
- cost: time 5
- kind: LAW
- text: For this combat, whenever an enemy moves voluntarily, it takes 2 damage per tile and loses 1 block.
- hooks: anti-melee, kiting, movement traps
- iconography: MOVE, DMG, BLOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/sky_tax.png`
- art direction: airborne coins cutting across an enemy's path

### 078. Feather Debt

- id: `feather_debt`
- rarity: rare
- element: Air
- cost: time 3, Exhaust
- kind: PACT
- text: Gain 3 card plays. For this combat, every card after the third each turn Exhausts after resolving.
- hooks: big turns, Exhaust synergies
- iconography: PLAY, EXH, PACT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/feather_debt.png`
- art direction: three white feathers pinned to a debt slip

### 079. Echoing Step

- id: `echoing_step`
- rarity: rare
- element: Air
- cost: time 5, Exhaust
- kind: ENGINE
- text: For this combat, your first move each turn repeats at turn end if the path is clear; otherwise gain 6 block.
- hooks: movement loops, positioning
- iconography: MOVE, ECHO, BLOCK
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/echoing_step.png`
- art direction: a translucent second footprint following the first through mist

### 080. Airborne Archive

- id: `airborne_archive`
- rarity: rare
- element: Air
- cost: time 6, Exhaust
- kind: FIELD
- text: For this combat, illusions drift with you after each move and pull adjacent enemies 1.
- hooks: illusions, movement, pull
- iconography: ILLUS, MOVE, PULL
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/airborne_archive.png`
- art direction: floating shelves of paper decoys drifting in a green gale

### 081. Crosswind Script

- id: `crosswind_script`
- rarity: uncommon
- element: Air
- cost: time 4
- kind: LAW
- text: For this combat, after you push or pull an enemy, your next ranged or AOE card ignores line of sight.
- hooks: forced movement, ranged, AOE
- iconography: PUSH, RANGE, LOS
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/crosswind_script.png`
- art direction: a teal script ribbon bending an arrow around a wall

### 082. Eye of Stillness

- id: `eye_of_stillness`
- rarity: rare
- element: Air
- cost: time 6, Exhaust
- kind: ENGINE
- text: For this combat, if you did not move last turn, your next move gains +6 range and draws 3.
- hooks: wait turns, explosive reposition
- iconography: MOVE, DRAW, RANGE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/eye_of_stillness.png`
- art direction: a still teal eye at the center of a frozen wind ring

### 083. Vacuum Bloom

- id: `vacuum_bloom`
- rarity: rare
- element: Air
- cost: time 7, Exhaust
- kind: FIELD
- text: For this combat, pull effects also apply poison 2 and burn 2 to enemies pulled adjacent to you.
- hooks: pull, poison, burn, close range
- iconography: PULL, POISON, BURN
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/vacuum_bloom.png`
- art direction: a flower-shaped vacuum pulling green smoke and red sparks inward

### 084. Sky-Written Warrant

- id: `sky_written_warrant`
- rarity: rare
- element: Air
- cost: time 6, Exhaust
- kind: FIELD
- text: Mark the farthest enemy. For this combat, whenever it moves closer, draw 1; when it reaches you, push all enemies 3.
- hooks: kiting, mark, push payoff
- iconography: MARK, DRAW, PUSH
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/sky_written_warrant.png`
- art direction: a glowing warrant written in clouds above a distant target

## Earth

### 085. Root Constitution

- id: `root_constitution`
- rarity: common
- element: Earth
- cost: time 5
- kind: LAW
- text: For this combat, units cannot be pushed or pulled unless poisoned. Poisoned units take +3 forced-movement damage.
- hooks: poison, push/pull, control
- iconography: POISON, PUSH, PULL
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/root_constitution.png`
- art direction: tree roots wrapped around an old stone law tablet

### 086. Garden of Wounds

- id: `garden_of_wounds`
- rarity: common
- element: Earth
- cost: time 5
- kind: ENGINE
- text: For this combat, poison ticks heal you for 1 and grow 1 stoneskin, once per poisoned enemy each turn.
- hooks: poison, sustain, stoneskin
- iconography: POISON, HEAL, STONE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/garden_of_wounds.png`
- art direction: green flowers growing from cracks in a bloodied shield

### 087. Stone Interest

- id: `stone_interest`
- rarity: common
- element: Earth
- cost: time 4
- kind: ENGINE
- text: For this combat, when your stoneskin rises above 10, deal the excess as damage to all adjacent enemies.
- hooks: stoneskin stacking, melee range
- iconography: STONE, AOE, DMG
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/stone_interest.png`
- art direction: a stone banker weighing armor plates against enemy skulls

### 088. Spore Ledger

- id: `spore_ledger`
- rarity: uncommon
- element: Earth
- cost: time 5
- kind: ENGINE
- text: For this combat, when a poisoned enemy dies, spread half its poison to all enemies.
- hooks: poison kills, AOE spread
- iconography: POISON, SPREAD, AOE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/spore_ledger.png`
- art direction: a mossy ledger releasing green spores from a torn page

### 089. Iron Orchard

- id: `iron_orchard`
- rarity: uncommon
- element: Earth
- cost: time 6, Exhaust
- kind: ENGINE
- text: At end of your turn, gain 1 stoneskin per card in discard, max 8. If you have 15+ stoneskin, draw 1.
- hooks: discard size, stoneskin, draw
- iconography: STONE, DISCARD, DRAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/iron_orchard.png`
- art direction: metal trees growing shields instead of fruit

### 090. Grave Treaty

- id: `grave_treaty`
- rarity: uncommon
- element: Earth
- cost: time 5
- kind: FIELD
- text: For this combat, your illusions leave brambles when destroyed: adjacent enemies take poison 5 and immobilize.
- hooks: illusions, poison, immobilize
- iconography: ILLUS, POISON, IMMOB
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/grave_treaty.png`
- art direction: a stone pact marker surrounded by thorny grave growth

### 091. Deep Battery

- id: `deep_battery`
- rarity: uncommon
- element: Earth
- cost: time 5
- kind: ENGINE
- text: For this combat, first time each turn you gain stoneskin, reduce next card time by that amount, max -4.
- hooks: stoneskin, tempo, defense engines
- iconography: STONE, TIME, ENGINE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/deep_battery.png`
- art direction: a buried green battery wired into a stone gauntlet

### 092. Moss That Remembers

- id: `moss_that_remembers`
- rarity: uncommon
- element: Earth
- cost: time 6, Exhaust
- kind: FIELD
- text: For this combat, tiles you leave become moss. Enemies entering moss take poison 2 and are delayed by 1 time.
- hooks: movement paths, poison terrain
- iconography: MOVE, POISON, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/moss_that_remembers.png`
- art direction: glowing moss preserving a trail of old footprints

### 093. Buried Names

- id: `buried_names`
- rarity: uncommon
- element: Earth
- cost: time 5
- kind: ENGINE
- text: For this combat, each Exhausted card becomes a Root. Your attacks apply poison equal to your Roots.
- hooks: Exhaust, poison scaling
- iconography: EXH, POISON, ROOT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/buried_names.png`
- art direction: names carved into roots beneath a half-buried card

### 094. Mountain Clause

- id: `mountain_clause`
- rarity: rare
- element: Earth
- cost: time 6, Exhaust
- kind: LAW
- text: For this combat, if you play no move or blink this turn, double block and stoneskin gained this turn.
- hooks: stationary defense, block, stoneskin
- iconography: BLOCK, STONE, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/mountain_clause.png`
- art direction: a mountain-shaped clause stamped into a heavy shield

### 095. Earthen Jury

- id: `earthen_jury`
- rarity: rare
- element: Earth
- cost: time 7, Exhaust
- kind: LAW
- text: For this combat, poison added to any enemy also enters a shared poison pool. Pool ticks split across all enemies.
- hooks: poison scaling, swarm damage
- iconography: POISON, POOL, AOE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/earthen_jury.png`
- art direction: twelve stone faces judging a green poison basin

### 096. Henge Engine

- id: `henge_engine`
- rarity: rare
- element: Earth
- cost: time 6
- kind: ENGINE
- text: For this combat, every fourth card you play creates a 4-health stone illusion with 4 stoneskin.
- hooks: multi-card turns, illusions, defense
- iconography: COUNT, ILLUS, STONE
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/henge_engine.png`
- art direction: a ring of standing stones assembling a small decoy

### 097. Fossil Clock

- id: `fossil_clock`
- rarity: rare
- element: Earth
- cost: time 6, Exhaust
- kind: LAW
- text: For this combat, while you have 10+ stoneskin, your card time costs cannot exceed 5.
- hooks: stoneskin, high-time cards
- iconography: STONE, TIME, LAW
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/fossil_clock.png`
- art direction: a clock fossil embedded in a mossy stone shield

### 098. Widow Seeds

- id: `widow_seeds`
- rarity: rare
- element: Earth
- cost: time 5, Exhaust
- kind: PACT
- text: For this combat, poison cannot kill enemies. Your attacks consume target poison as bonus damage.
- hooks: poison banking, finisher attacks
- iconography: POISON, DMG, PACT
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/widow_seeds.png`
- art direction: black seeds sprouting green venom around a spear point

### 099. Silt Cathedral

- id: `silt_cathedral`
- rarity: rare
- element: Earth
- cost: time 7, Exhaust
- kind: FIELD
- text: For this combat, block you gain becomes stoneskin instead. Healing is halved.
- hooks: block cards, stoneskin, tank builds
- iconography: BLOCK, STONE, FIELD
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/silt_cathedral.png`
- art direction: a cathedral of mud and stone rising around a shield altar

### 100. Tremor Writ

- id: `tremor_writ`
- rarity: rare
- element: Earth
- cost: time 6, Exhaust
- kind: LAW
- text: For this combat, at end of each enemy turn, if it did not move, deal 8 damage and apply poison 3.
- hooks: immobilize, enemy control, poison
- iconography: IMMOB, DMG, POISON
- proposed art path: `res://output/buildaround_cards_100/assets/art/cards/tremor_writ.png`
- art direction: a cracked legal writ causing the floor beneath an enemy to shake
