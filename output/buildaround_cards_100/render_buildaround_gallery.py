from __future__ import annotations

import hashlib
import json
import math
import random
from pathlib import Path
from typing import Any

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]

CARD_W = 320
CARD_H = 440
SHEET_COLS = 4
SHEET_ROWS = 5
CARDS_PER_SHEET = SHEET_COLS * SHEET_ROWS

FONT_REGULAR = "/System/Library/Fonts/Supplemental/Arial.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_NARROW = "/System/Library/Fonts/Supplemental/Arial Narrow.ttf"
FONT_NARROW_BOLD = "/System/Library/Fonts/Supplemental/Arial Narrow Bold.ttf"
FONT_TITLE = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"


ELEMENTS: dict[str, dict[str, str]] = {
    "neutral": {
        "label": "Neutral",
        "accent": "#8a6d49",
        "bg": "#efe4cf",
        "dark": "#51463f",
    },
    "fire": {
        "label": "Fire",
        "accent": "#d9623f",
        "bg": "#f5dfd2",
        "dark": "#5a3a30",
    },
    "ice": {
        "label": "Ice",
        "accent": "#5fa7d8",
        "bg": "#dcecf6",
        "dark": "#314758",
    },
    "lightning": {
        "label": "Lightning",
        "accent": "#cfb347",
        "bg": "#f4ebc8",
        "dark": "#584c2f",
    },
    "air": {
        "label": "Air",
        "accent": "#72bea5",
        "bg": "#dff4ee",
        "dark": "#315248",
    },
    "earth": {
        "label": "Earth",
        "accent": "#89a15b",
        "bg": "#e5edd7",
        "dark": "#445438",
    },
}

RARITIES: dict[str, dict[str, str]] = {
    "common": {"label": "Common", "color": "#8f8f86"},
    "uncommon": {"label": "Uncommon", "color": "#4f9d73"},
    "rare": {"label": "Rare", "color": "#9b6bd3"},
}


def c(
    card_id: str,
    name: str,
    element: str,
    rarity: str,
    time: int,
    exhaust: bool,
    health_cost: int,
    kind: str,
    text: str,
    hooks: str,
    art: str,
    icons: list[str],
) -> dict[str, Any]:
    return {
        "id": card_id,
        "name": name,
        "element": element,
        "rarity": rarity,
        "time": time,
        "burn": exhaust,
        "health_cost": health_cost,
        "kind": kind,
        "description": text,
        "hooks": hooks,
        "art_direction": art,
        "accent": ELEMENTS[element]["accent"],
        "proposed_art_path": f"res://assets/art/cards/{card_id}.png",
        "iconography": icons,
        "actions": [],
        "notes": "Text-rule build-around concept. Requires novel mechanic implementation before use.",
    }


CARDS: list[dict[str, Any]] = [
    c("chrono_forge", "Chrono Forge", "neutral", "common", 6, True, 0, "LAW",
      "For this combat, the first card you play each turn costs -2 time. Cards with printed time 7+ also draw 1.",
      "high-time payoffs, draw, slow rares", "a brass forge hammering deck cards into clock gears", ["TIME", "DRAW", "LAW"]),
    c("turnstile_rite", "Turnstile Rite", "neutral", "common", 4, False, 0, "LAW",
      "Each turn: your first card costs 0 time, your second costs +3 time, your third costs -3 time.",
      "card-play sequencing, low-cost fillers", "a rotating dungeon turnstile with three glowing tally marks", ["TIME", "ORDER", "LAW"]),
    c("empty_hand_oath", "Empty Hand Oath", "neutral", "common", 3, False, 0, "ENGINE",
      "For this combat, if your hand is empty at end of turn, draw 2 and gain 1 card play next turn.",
      "cheap cards, card plays, hand dumps", "an open cinder-stained palm over a blank parchment deck", ["DRAW", "PLAY", "HAND"]),
    c("vow_of_one", "Vow of One", "neutral", "common", 5, True, 0, "PACT",
      "For this combat, you may play only one card each turn. That card costs -4 time and its numeric values are doubled.",
      "single-card turns, big attacks, big block", "a lone sword standing in a circle of extinguished candles", ["TIME", "X2", "PACT"]),
    c("common_cause", "Common Cause", "neutral", "common", 4, False, 0, "ENGINE",
      "For this combat, common cards gain +2 damage or +2 block. When a common card Exhausts, draw 1.",
      "common-heavy decks, Exhaust, starters", "a bundle of plain iron tools tied with a gold thread", ["COMMON", "DRAW", "EXH"]),
    c("black_archive", "Black Archive", "neutral", "uncommon", 7, True, 0, "ENGINE",
      "Return your Exhausted cards to the draw pile. For this combat, whenever a card Exhausts, deal 2 to all enemies.",
      "Exhaust loops, rare spikes, AOE chip", "a charred library shelf releasing glowing card-cinder pages", ["EXH", "AOE", "DRAW"]),
    c("mirror_doctrine", "Mirror Doctrine", "neutral", "uncommon", 5, True, 0, "LAW",
      "For this combat, your illusions copy the first status you apply each turn to the nearest enemy at 50% value.",
      "illusions, burn, poison, freeze, shock", "two hooded reflections in a cracked obsidian mirror", ["ILLUS", "STATUS", "COPY"]),
    c("debt_ledger", "Debt Ledger", "neutral", "uncommon", 4, False, 1, "PACT",
      "For this combat, whenever you pay health, draw that many cards and gain that much block. Healing cannot repay this debt.",
      "health costs, draw, block engines", "a blood-marked account book chained to a coin scale", ["HP", "DRAW", "BLOCK"]),
    c("last_bad_bargain", "Last Bad Bargain", "neutral", "rare", 9, True, 0, "PACT",
      "Set your health to 1. Gain 40 block. For this combat, your attacks gain +6 damage and pierce.",
      "glass-cannon decks, block, pierce", "a desperate pact sealed with one red candle and a cracked shield", ["HP", "BLOCK", "PIERCE"]),
    c("courier_law", "Courier Law", "neutral", "uncommon", 5, False, 0, "LAW",
      "For this combat, after you move 5+ tiles in a turn, your next ranged or AOE card ignores line of sight and gains +2 range.",
      "move, ranged, AOE, trap paths", "a masked runner carrying a sealed letter through broken doorways", ["MOVE", "RANGE", "LOS"]),
    c("reliquary_of_hands", "Reliquary of Hands", "neutral", "rare", 7, True, 0, "ENGINE",
      "For this combat, whenever you gain card plays, draw that many cards. Once each turn, drawing 3+ cards gives 1 card play.",
      "draw engines, card-play engines", "a reliquary filled with many small skeletal hands holding cards", ["DRAW", "PLAY", "ENGINE"]),
    c("tempo_thief", "Tempo Thief", "neutral", "uncommon", 5, True, 0, "BURST",
      "Delay all enemies by 3 time. For this combat, each 1-2 time card you play delays the nearest enemy by 1.",
      "fast cards, initiative control", "a cloaked thief stealing clock hands from enemy shadows", ["TIME", "FAST", "DELAY"]),
    c("maw_of_the_deck", "Maw of the Deck", "neutral", "uncommon", 6, False, 0, "ENGINE",
      "For this combat, each card drawn past 5 in hand is fed to the Maw. At 3 fed cards, deal 12 to all enemies and draw 1.",
      "big draw, overflow, AOE payoff", "a toothy wooden deck box swallowing glowing cards", ["DRAW", "AOE", "COUNT"]),
    c("parliament_of_echoes", "Parliament of Echoes", "neutral", "rare", 8, True, 0, "LAW",
      "For this combat, the first card you play each turn echoes: repeat its non-movement text at 50% values.",
      "big text cards, status payoffs", "a council of pale masks repeating one burning sentence", ["ECHO", "TEXT", "X2"]),
    c("undertakers_map", "Undertaker's Map", "neutral", "uncommon", 5, True, 0, "FIELD",
      "Mark all enemies. First time a Marked enemy dies, blink to its tile, draw 1, and move the Mark to the nearest enemy.",
      "kills, blink, target routing", "a burial map with pins joined by ghostly thread", ["MARK", "BLINK", "DRAW"]),
    c("rare_disease", "Rare Disease", "neutral", "rare", 6, True, 0, "PACT",
      "For this combat, rare cards cost -3 time and Exhaust. Whenever a rare card Exhausts, deal 5 to all enemies.",
      "rare-heavy decks, Exhaust, tempo", "a violet gem infecting ornate card frames with black veins", ["RARE", "TIME", "EXH"]),
    c("skeleton_key", "Skeleton Key", "neutral", "uncommon", 5, False, 0, "LAW",
      "For this combat, your cards have +2 range. Blink cards also create a 1-health illusion at your old tile.",
      "range, blink, illusions", "a bone key opening several impossible dungeon doors at once", ["RANGE", "BLINK", "ILLUS"]),
    c("blood_alphabet", "Blood Alphabet", "neutral", "rare", 6, True, 2, "ENGINE",
      "For this combat, losing health writes a Letter. At 3 Letters, clear them, draw 2, and your attacks gain +3 this turn.",
      "self-damage, draw, burst turns", "red runic letters crawling across a vellum card", ["HP", "DRAW", "DMG"]),
    c("oath_of_cinders", "Oath of Cinders", "neutral", "rare", 7, True, 0, "LAW",
      "For this combat, neutral cards count as your highest-intensity element and raise that element by 1 when played.",
      "neutral cards, elemental intensity", "a grey oath stone split by five colored embers", ["NEUT", "INT", "LAW"]),
    c("silent_majority", "Silent Majority", "neutral", "uncommon", 4, False, 0, "ENGINE",
      "For this combat, neutral cards cost -1 time. Each third neutral card you play creates a 2-health illusion.",
      "neutral decks, illusions, tempo", "a crowd of blank masks standing behind a single lit card", ["NEUT", "TIME", "ILLUS"]),

    c("ember_tax", "Ember Tax", "fire", "common", 5, False, 0, "LAW",
      "For this combat, burn ticks raise Fire intensity by 1 before decay. At Fire 4+, burn ticks twice.",
      "burn stacking, Fire intensity", "tax coins melting into a basin of red cinder", ["BURN", "INT", "LAW"]),
    c("furnace_choir", "Furnace Choir", "fire", "common", 7, True, 0, "BURST",
      "Apply 8 burn to all enemies. For this combat, when burn expires on an enemy, spread 4 burn to the nearest enemy.",
      "AOE burn, spread, crowd fights", "robed furnace mouths singing sparks into a dark hall", ["BURN", "AOE", "SPREAD"]),
    c("red_thread", "Red Thread", "fire", "common", 5, False, 0, "ENGINE",
      "For this combat, the first time you damage a burning enemy each turn, repeat that damage on every other burning enemy.",
      "burn setup, AOE conversion", "a glowing red thread stitching several burning targets together", ["BURN", "COPY", "AOE"]),
    c("cinder_bank", "Cinder Bank", "fire", "uncommon", 4, False, 0, "ENGINE",
      "For this combat, overkill from burn is banked. Your next attack spends the bank as bonus fire damage.",
      "burn kills, overkill, big hits", "a small iron vault packed with orange-hot cinders", ["BURN", "BANK", "DMG"]),
    c("bonfire_pact", "Bonfire Pact", "fire", "uncommon", 6, True, 0, "PACT",
      "Exhaust 2 cards from your hand. For this combat, your attacks apply burn equal to cards Exhausted this combat.",
      "Exhaust decks, attacks, burn", "two cards burning upright in a ritual bonfire", ["EXH", "BURN", "PACT"]),
    c("kindling_engine", "Kindling Engine", "fire", "uncommon", 5, True, 0, "ENGINE",
      "For this combat, whenever any card Exhausts, apply 3 burn to all enemies and raise Fire intensity by 1.",
      "Exhaust, Fire intensity, AOE burn", "a crank engine feeding torn cards into a furnace heart", ["EXH", "BURN", "INT"]),
    c("smoke_debt", "Smoke Debt", "fire", "uncommon", 5, False, 0, "LAW",
      "For this combat, burning enemies deal -1 damage per 5 burn on them. When their burn decays, gain that much block.",
      "defensive burn, block, attrition", "a shield made of debt notes dissolving into black smoke", ["BURN", "BLOCK", "LAW"]),
    c("wildfire_crown", "Wildfire Crown", "fire", "rare", 8, True, 0, "ENGINE",
      "For this combat, when burn kills an enemy, draw 2, gain 1 card play, and transfer its remaining burn to all enemies.",
      "burn kills, draw, card plays", "a crown of fire throwing sparks from one skull to many", ["BURN", "DRAW", "PLAY"]),
    c("molten_calendar", "Molten Calendar", "fire", "uncommon", 7, True, 0, "FIELD",
      "For this combat, after every third player turn, apply 18 burn to all enemies. Fire cards advance the calendar one step.",
      "long fights, Fire card density", "a lava calendar with three glowing dates cracked open", ["BURN", "COUNT", "FIELD"]),
    c("soot_mirror", "Soot Mirror", "fire", "rare", 6, True, 0, "PACT",
      "For this combat, burn on you also ticks on all enemies. At end of turn, move half your burn to the healthiest enemy.",
      "self-burn, enemy swarms, risk", "a smoky mirror reflecting the hero as a burning silhouette", ["BURN", "HP", "COPY"]),
    c("ignition_point", "Ignition Point", "fire", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, applying burn to an already burning enemy deals damage equal to the smaller burn value to it and adjacent enemies.",
      "stacking burn, adjacency, AOE", "two sparks colliding into a flower-shaped explosion", ["BURN", "AOE", "STACK"]),
    c("ember_tithe", "Ember Tithe", "fire", "rare", 5, True, 1, "PACT",
      "For this combat, the first attack damage you deal each turn costs 1 health and applies burn equal to half that damage.",
      "self-damage, big attacks, burn", "a red tithe bowl receiving blood and returning embers", ["HP", "DMG", "BURN"]),
    c("firebreak_clause", "Firebreak Clause", "fire", "uncommon", 4, False, 0, "LAW",
      "Convert all burn on you into block. For this combat, each 3 block you gain applies 1 burn to the nearest enemy.",
      "block engines, self-burn cleanup", "a legal scroll used as a shield against a wall of flame", ["BLOCK", "BURN", "LAW"]),
    c("sunken_kiln", "Sunken Kiln", "fire", "rare", 8, True, 0, "FIELD",
      "Set Fire intensity to 3. For this combat, Fire intensity cannot fall below 3, but non-Fire cards cost +1 time.",
      "mono-Fire decks, intensity scaling", "a submerged furnace glowing beneath black water", ["FIRE", "INT", "TIME"]),
    c("cinder_encore", "Cinder Encore", "fire", "rare", 7, True, 0, "ENGINE",
      "For this combat, the first Fire card that Exhausts each turn returns next turn as a 0-time copy, then vanishes.",
      "Fire Exhaust, burst repeats", "a singer made of cinder bowing as a card reignites", ["FIRE", "EXH", "ECHO"]),
    c("dragons_due", "Dragon's Due", "fire", "rare", 10, True, 0, "BURST",
      "Apply 40 burn to all enemies. Until an enemy dies, your cards cost +2 time.",
      "huge burn, kill race, tempo risk", "a dragon-shaped debt mark branded over a battlefield", ["BURN", "AOE", "TIME"]),

    c("absolute_zero", "Absolute Zero", "ice", "common", 8, True, 0, "BURST",
      "Freeze all enemies. For this combat, frozen enemies keep burn and poison from decaying.",
      "freeze, burn, poison", "a black-blue eclipse freezing a room in a single ring", ["FREEZE", "BURN", "POISON"]),
    c("glass_library", "Glass Library", "ice", "common", 5, False, 0, "ENGINE",
      "For this combat, whenever a frozen enemy takes damage, store half. When freeze ends, deal the stored damage again.",
      "freeze setup, delayed burst", "shelves of transparent books cracking with trapped impacts", ["FREEZE", "BANK", "DMG"]),
    c("hoarfrost_contract", "Hoarfrost Contract", "ice", "common", 4, False, 0, "LAW",
      "For this combat, the first time each enemy would act, if Ice is 2+, spend 1 Ice to freeze it instead.",
      "Ice intensity, turn denial", "a frost-covered contract signed by a claw of ice", ["ICE", "FREEZE", "LAW"]),
    c("shatter_bank", "Shatter Bank", "ice", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, overkill against frozen enemies becomes Shards. Your next attack spends Shards as bonus damage.",
      "freeze kills, overkill, burst", "a crystal bank filled with coin-like shards of frozen damage", ["FREEZE", "BANK", "DMG"]),
    c("crystal_prison", "Crystal Prison", "ice", "uncommon", 6, True, 0, "FIELD",
      "Create two 4-health ice illusions. For this combat, enemies that hit your illusions become frozen.",
      "illusions, freeze, enemy targeting", "two glass decoys inside a jagged crystal cage", ["ILLUS", "FREEZE", "FIELD"]),
    c("snowblind_map", "Snowblind Map", "ice", "uncommon", 5, False, 0, "LAW",
      "For this combat, enemies farther than 3 tiles treat you as invisible unless you damaged them this turn.",
      "kiting, range, movement", "a dungeon map erased by white wind except for three black tiles", ["RANGE", "MOVE", "LAW"]),
    c("slow_moon", "Slow Moon", "ice", "uncommon", 7, True, 0, "FIELD",
      "Delay all enemies by 4 time. For this combat, enemy delays are 50% stronger, but your first card each turn costs +1 time.",
      "initiative control, freeze, push time", "a pale moon hanging low over frozen clockwork", ["TIME", "DELAY", "FIELD"]),
    c("cold_read", "Cold Read", "ice", "uncommon", 4, False, 0, "ENGINE",
      "For this combat, before each enemy acts, draw 1. If that enemy is frozen or shocked, draw 2 instead.",
      "freeze/shock, draw, enemy pacing", "a blue candle illuminating enemy intent cards under ice", ["DRAW", "FREEZE", "SHOCK"]),
    c("silence_underfoot", "Silence Underfoot", "ice", "uncommon", 5, False, 0, "LAW",
      "For this combat, moving through traps prevents their trigger. Your next attack after moving freezes if Ice is 2+.",
      "movement, traps, Ice intensity", "soft snow covering a row of hidden spike traps", ["MOVE", "TRAP", "FREEZE"]),
    c("ice_nine", "Ice Nine", "ice", "rare", 8, True, 0, "LAW",
      "For this combat, burn and poison on frozen enemies do not decay. When freeze ends, those statuses tick once immediately.",
      "status stacking, freeze windows", "nine angular ice crystals trapping green and red fumes", ["FREEZE", "STATUS", "TICK"]),
    c("pale_refrain", "Pale Refrain", "ice", "rare", 6, True, 0, "ENGINE",
      "For this combat, the first card each turn that freezes an enemy returns to hand with +2 time.",
      "freeze density, replay, time tax", "a pale bell echoing a frozen card back into a hand", ["FREEZE", "ECHO", "TIME"]),
    c("glacier_debt", "Glacier Debt", "ice", "rare", 7, True, 0, "PACT",
      "Gain 12 stoneskin. For this combat, whenever stoneskin absorbs damage, freeze the attacker and lose 2 stoneskin.",
      "stoneskin, freeze, tank builds", "a towering ice debt-marker carved into a stone shield", ["STONE", "FREEZE", "PACT"]),
    c("frost_dividend", "Frost Dividend", "ice", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, whenever an enemy skips action from freeze or shock, draw 2 and gain 4 block.",
      "freeze, shock, defense draw", "frosted coins falling from a sleeping enemy silhouette", ["FREEZE", "SHOCK", "DRAW"]),
    c("white_trial", "White Trial", "ice", "rare", 8, True, 0, "FIELD",
      "Freeze the healthiest enemy. For this combat, damage dealt to it is mirrored at 50% to all frozen enemies.",
      "boss focus, freeze swarms", "a white tribunal mirror judging one large frozen foe", ["FREEZE", "COPY", "DMG"]),
    c("rime_escrow", "Rime Escrow", "ice", "rare", 6, True, 0, "ENGINE",
      "For this combat, the first 10 damage you would deal each turn is stored. At turn end, deal it to a frozen enemy and draw 1.",
      "damage timing, freeze targets", "a locked ice chest holding a red damage glyph", ["BANK", "FREEZE", "DRAW"]),
    c("frozen_minute", "Frozen Minute", "ice", "rare", 7, True, 0, "LAW",
      "For this combat, your first card each turn costs +2 time but plays twice if it targets a frozen enemy.",
      "freeze payoff, big first cards", "a minute hand trapped between two mirrored ice cards", ["TIME", "FREEZE", "X2"]),

    c("capacitor_heart", "Capacitor Heart", "lightning", "common", 4, False, 0, "ENGINE",
      "For this combat, unspent card plays at end of turn become Lightning intensity. At Lightning 4+, draw 1 at turn start.",
      "card plays, Lightning intensity", "a brass heart battery with card-play sparks inside", ["PLAY", "INT", "DRAW"]),
    c("chain_legislature", "Chain Legislature", "lightning", "common", 5, False, 0, "LAW",
      "For this combat, single-target ranged attacks gain chain 1. Chain jumps shock if Lightning is 3+.",
      "ranged decks, chain, shock", "a row of lightning-robed judges connected by bright arcs", ["RANGE", "CHAIN", "SHOCK"]),
    c("static_market", "Static Market", "lightning", "common", 5, False, 0, "ENGINE",
      "For this combat, your cards cost -1 time for each shocked enemy, to a minimum of 1.",
      "shock spread, fast turns", "a market stall trading clocks for crackling blue sparks", ["SHOCK", "TIME", "ENGINE"]),
    c("storm_battery", "Storm Battery", "lightning", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, whenever you draw 2+ cards at once, gain 1 Charge. At 3 Charges, shock all enemies and clear Charges.",
      "draw bursts, shock AOE", "a glass battery jar storing three jagged storm bolts", ["DRAW", "SHOCK", "COUNT"]),
    c("spark_double", "Spark Double", "lightning", "uncommon", 4, False, 0, "ENGINE",
      "For this combat, when an illusion is destroyed, shock the nearest enemy, deal 6, and draw 1.",
      "illusions, enemy targeting, shock", "a duplicate made of sparks collapsing into an enemy", ["ILLUS", "SHOCK", "DRAW"]),
    c("conductive_floor", "Conductive Floor", "lightning", "uncommon", 6, True, 0, "FIELD",
      "For this combat, enemies moved by push or pull leave a lightning trail. Chain jumps through trails deal +4.",
      "push/pull, chain routing", "dungeon floor tiles etched with glowing conductive grooves", ["MOVE", "CHAIN", "FIELD"]),
    c("dead_switch", "Dead Switch", "lightning", "uncommon", 4, True, 0, "PACT",
      "For this combat, whenever you take unblocked damage, shocked enemies take the same damage and lose shock.",
      "shock, self-risk, retaliation", "a cracked switch strapped to a heart with lightning wire", ["HP", "SHOCK", "COPY"]),
    c("voltaic_audit", "Voltaic Audit", "lightning", "uncommon", 6, False, 0, "ENGINE",
      "For this combat, every third card you play repeats its damage against the nearest shocked enemy.",
      "multi-card turns, shock payoff", "an electric ledger counting every third card with gold sparks", ["COUNT", "SHOCK", "DMG"]),
    c("crown_of_seconds", "Crown of Seconds", "lightning", "uncommon", 5, True, 0, "LAW",
      "For this combat, cards with time 6+ resolve as time 5, then their first attack gains +4 damage and chain 1.",
      "slow attacks, chain, tempo", "a crown of clock hands struck by yellow lightning", ["TIME", "CHAIN", "DMG"]),
    c("blackout_bloom", "Blackout Bloom", "lightning", "rare", 7, True, 0, "FIELD",
      "For this combat, shocked enemies cannot gain block or stoneskin and take +2 from every chain jump.",
      "shock control, chain damage", "a black flower opening in a burst of silent lightning", ["SHOCK", "CHAIN", "BLOCK"]),
    c("forked_fate", "Forked Fate", "lightning", "rare", 6, True, 0, "LAW",
      "Bind the two closest enemies. For this combat, status applied to one is copied at 50% value to the other.",
      "status decks, two-target fights", "two enemy shadows tied by a forked lightning thread", ["STATUS", "COPY", "PAIR"]),
    c("lightning_rod", "Lightning Rod", "lightning", "rare", 6, True, 0, "FIELD",
      "Create a 5-health rod illusion. For this combat, chain effects jump through it and shocked enemies prefer targeting it.",
      "illusions, chain routing, defense", "a metal decoy rod drawing all arcs into its raised hand", ["ILLUS", "CHAIN", "SHOCK"]),
    c("battery_acid", "Battery Acid", "lightning", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, when shock ends on an enemy, apply poison equal to twice your Lightning intensity.",
      "shock, poison, cross-element", "yellow acid dripping from a cracked storm battery", ["SHOCK", "POISON", "INT"]),
    c("relay_race", "Relay Race", "lightning", "rare", 6, False, 0, "ENGINE",
      "For this combat, every 3 tiles you move reduces next card time by 1 and gives its first attack chain 1.",
      "movement, chain, tempo", "runners passing a spark baton across dungeon tiles", ["MOVE", "TIME", "CHAIN"]),
    c("eye_of_zekarion", "Eye of Zekarion", "lightning", "rare", 8, True, 0, "LAW",
      "For this combat, shock-immune enemies take +6 from Lightning cards and count as shocked for your bonuses.",
      "boss tech, shock payoffs", "a golden storm eye staring from an armored mask", ["BOSS", "SHOCK", "DMG"]),
    c("thunder_mortgage", "Thunder Mortgage", "lightning", "rare", 3, True, 0, "PACT",
      "Gain 3 card plays now. For this combat, each card after the second each turn adds +2 time debt to your next turn.",
      "explosive turns, delayed penalty", "a contract nailed to a storm cloud with three bright seals", ["PLAY", "TIME", "PACT"]),

    c("wind_act", "Wind Act", "air", "common", 5, False, 0, "LAW",
      "For this combat, move and blink cards cost 0 time. Attacks played before you move each turn cost +2 time.",
      "movement-first decks, tempo", "a legal decree unfurling as a green wind spiral", ["MOVE", "BLINK", "TIME"]),
    c("empty_tile_gospel", "Empty Tile Gospel", "air", "common", 4, False, 0, "ENGINE",
      "For this combat, first time each turn you end movement on a tile you have not occupied, draw 1 and gain 1 block.",
      "pathing, draw, kiting", "a glowing footprint on an untouched slate tile", ["MOVE", "DRAW", "BLOCK"]),
    c("cyclone_court", "Cyclone Court", "air", "common", 6, True, 0, "FIELD",
      "For this combat, at end of your turn, push all enemies 1 away from you. If they hit walls, deal 4.",
      "positioning, wall damage", "a circular courtroom of wind hurling enemies outward", ["PUSH", "AOE", "FIELD"]),
    c("kite_doctrine", "Kite Doctrine", "air", "uncommon", 4, False, 0, "ENGINE",
      "For this combat, ranged attacks gain +1 damage for each tile you moved this turn, max +8.",
      "move, ranged, burst setup", "a paper war kite dragging a glowing arrow-tail", ["MOVE", "RANGE", "DMG"]),
    c("borrowed_door", "Borrowed Door", "air", "uncommon", 5, True, 0, "FIELD",
      "Blink 6. For this combat, your first blink each turn leaves a door; your next move may start from any door.",
      "blink, map control, escape routes", "a teal door floating sideways in an impossible corridor", ["BLINK", "MOVE", "FIELD"]),
    c("slipstream_engine", "Slipstream Engine", "air", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, whenever an enemy is pushed or pulled, gain 1 card play, once per card.",
      "push, pull, combo turns", "a compact turbine made of cards and green current", ["PUSH", "PULL", "PLAY"]),
    c("gale_receipts", "Gale Receipts", "air", "uncommon", 4, False, 0, "LAW",
      "For this combat, forced movement blocked by wall, unit, or pit deals 3 damage per blocked tile.",
      "push/pull, wall traps", "a pile of stamped receipts whipped against stone walls", ["PUSH", "PULL", "DMG"]),
    c("draft_market", "Draft Market", "air", "uncommon", 6, True, 0, "ENGINE",
      "Draw 3. For this combat, cards drawn after you move cost -2 time this turn.",
      "movement, draw, tempo bursts", "a wind market where cards flutter from hanging stalls", ["DRAW", "MOVE", "TIME"]),
    c("sky_tax", "Sky Tax", "air", "uncommon", 5, False, 0, "LAW",
      "For this combat, whenever an enemy moves voluntarily, it takes 2 damage per tile and loses 1 block.",
      "anti-melee, kiting, movement traps", "airborne coins cutting across an enemy's path", ["MOVE", "DMG", "BLOCK"]),
    c("feather_debt", "Feather Debt", "air", "rare", 3, True, 0, "PACT",
      "Gain 3 card plays. For this combat, every card after the third each turn Exhausts after resolving.",
      "big turns, Exhaust synergies", "three white feathers pinned to a debt slip", ["PLAY", "EXH", "PACT"]),
    c("echoing_step", "Echoing Step", "air", "rare", 5, True, 0, "ENGINE",
      "For this combat, your first move each turn repeats at turn end if the path is clear; otherwise gain 6 block.",
      "movement loops, positioning", "a translucent second footprint following the first through mist", ["MOVE", "ECHO", "BLOCK"]),
    c("airborne_archive", "Airborne Archive", "air", "rare", 6, True, 0, "FIELD",
      "For this combat, illusions drift with you after each move and pull adjacent enemies 1.",
      "illusions, movement, pull", "floating shelves of paper decoys drifting in a green gale", ["ILLUS", "MOVE", "PULL"]),
    c("crosswind_script", "Crosswind Script", "air", "uncommon", 4, False, 0, "LAW",
      "For this combat, after you push or pull an enemy, your next ranged or AOE card ignores line of sight.",
      "forced movement, ranged, AOE", "a teal script ribbon bending an arrow around a wall", ["PUSH", "RANGE", "LOS"]),
    c("eye_of_stillness", "Eye of Stillness", "air", "rare", 6, True, 0, "ENGINE",
      "For this combat, if you did not move last turn, your next move gains +6 range and draws 3.",
      "wait turns, explosive reposition", "a still teal eye at the center of a frozen wind ring", ["MOVE", "DRAW", "RANGE"]),
    c("vacuum_bloom", "Vacuum Bloom", "air", "rare", 7, True, 0, "FIELD",
      "For this combat, pull effects also apply poison 2 and burn 2 to enemies pulled adjacent to you.",
      "pull, poison, burn, close range", "a flower-shaped vacuum pulling green smoke and red sparks inward", ["PULL", "POISON", "BURN"]),
    c("sky_written_warrant", "Sky-Written Warrant", "air", "rare", 6, True, 0, "FIELD",
      "Mark the farthest enemy. For this combat, whenever it moves closer, draw 1; when it reaches you, push all enemies 3.",
      "kiting, mark, push payoff", "a glowing warrant written in clouds above a distant target", ["MARK", "DRAW", "PUSH"]),

    c("root_constitution", "Root Constitution", "earth", "common", 5, False, 0, "LAW",
      "For this combat, units cannot be pushed or pulled unless poisoned. Poisoned units take +3 forced-movement damage.",
      "poison, push/pull, control", "tree roots wrapped around an old stone law tablet", ["POISON", "PUSH", "PULL"]),
    c("garden_of_wounds", "Garden of Wounds", "earth", "common", 5, False, 0, "ENGINE",
      "For this combat, poison ticks heal you for 1 and grow 1 stoneskin, once per poisoned enemy each turn.",
      "poison, sustain, stoneskin", "green flowers growing from cracks in a bloodied shield", ["POISON", "HEAL", "STONE"]),
    c("stone_interest", "Stone Interest", "earth", "common", 4, False, 0, "ENGINE",
      "For this combat, when your stoneskin rises above 10, deal the excess as damage to all adjacent enemies.",
      "stoneskin stacking, melee range", "a stone banker weighing armor plates against enemy skulls", ["STONE", "AOE", "DMG"]),
    c("spore_ledger", "Spore Ledger", "earth", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, when a poisoned enemy dies, spread half its poison to all enemies.",
      "poison kills, AOE spread", "a mossy ledger releasing green spores from a torn page", ["POISON", "SPREAD", "AOE"]),
    c("iron_orchard", "Iron Orchard", "earth", "uncommon", 6, True, 0, "ENGINE",
      "At end of your turn, gain 1 stoneskin per card in discard, max 8. If you have 15+ stoneskin, draw 1.",
      "discard size, stoneskin, draw", "metal trees growing shields instead of fruit", ["STONE", "DISCARD", "DRAW"]),
    c("grave_treaty", "Grave Treaty", "earth", "uncommon", 5, False, 0, "FIELD",
      "For this combat, your illusions leave brambles when destroyed: adjacent enemies take poison 5 and immobilize.",
      "illusions, poison, immobilize", "a stone pact marker surrounded by thorny grave growth", ["ILLUS", "POISON", "IMMOB"]),
    c("deep_battery", "Deep Battery", "earth", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, first time each turn you gain stoneskin, reduce next card time by that amount, max -4.",
      "stoneskin, tempo, defense engines", "a buried green battery wired into a stone gauntlet", ["STONE", "TIME", "ENGINE"]),
    c("moss_that_remembers", "Moss That Remembers", "earth", "uncommon", 6, True, 0, "FIELD",
      "For this combat, tiles you leave become moss. Enemies entering moss take poison 2 and are delayed by 1 time.",
      "movement paths, poison terrain", "glowing moss preserving a trail of old footprints", ["MOVE", "POISON", "FIELD"]),
    c("buried_names", "Buried Names", "earth", "uncommon", 5, False, 0, "ENGINE",
      "For this combat, each Exhausted card becomes a Root. Your attacks apply poison equal to your Roots.",
      "Exhaust, poison scaling", "names carved into roots beneath a half-buried card", ["EXH", "POISON", "ROOT"]),
    c("mountain_clause", "Mountain Clause", "earth", "rare", 6, True, 0, "LAW",
      "For this combat, if you play no move or blink this turn, double block and stoneskin gained this turn.",
      "stationary defense, block, stoneskin", "a mountain-shaped clause stamped into a heavy shield", ["BLOCK", "STONE", "LAW"]),
    c("earthen_jury", "Earthen Jury", "earth", "rare", 7, True, 0, "LAW",
      "For this combat, poison added to any enemy also enters a shared poison pool. Pool ticks split across all enemies.",
      "poison scaling, swarm damage", "twelve stone faces judging a green poison basin", ["POISON", "POOL", "AOE"]),
    c("henge_engine", "Henge Engine", "earth", "rare", 6, False, 0, "ENGINE",
      "For this combat, every fourth card you play creates a 4-health stone illusion with 4 stoneskin.",
      "multi-card turns, illusions, defense", "a ring of standing stones assembling a small decoy", ["COUNT", "ILLUS", "STONE"]),
    c("fossil_clock", "Fossil Clock", "earth", "rare", 6, True, 0, "LAW",
      "For this combat, while you have 10+ stoneskin, your card time costs cannot exceed 5.",
      "stoneskin, high-time cards", "a clock fossil embedded in a mossy stone shield", ["STONE", "TIME", "LAW"]),
    c("widow_seeds", "Widow Seeds", "earth", "rare", 5, True, 0, "PACT",
      "For this combat, poison cannot kill enemies. Your attacks consume target poison as bonus damage.",
      "poison banking, finisher attacks", "black seeds sprouting green venom around a spear point", ["POISON", "DMG", "PACT"]),
    c("silt_cathedral", "Silt Cathedral", "earth", "rare", 7, True, 0, "FIELD",
      "For this combat, block you gain becomes stoneskin instead. Healing is halved.",
      "block cards, stoneskin, tank builds", "a cathedral of mud and stone rising around a shield altar", ["BLOCK", "STONE", "FIELD"]),
    c("tremor_writ", "Tremor Writ", "earth", "rare", 6, True, 0, "LAW",
      "For this combat, at end of each enemy turn, if it did not move, deal 8 damage and apply poison 3.",
      "immobilize, enemy control, poison", "a cracked legal writ causing the floor beneath an enemy to shake", ["IMMOB", "DMG", "POISON"]),
]


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def mix(a: tuple[int, int, int], b: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(a[0] * (1 - t) + b[0] * t),
        int(a[1] * (1 - t) + b[1] * t),
        int(a[2] * (1 - t) + b[2] * t),
    )


def draw_centered(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], text: str,
                  fnt: ImageFont.FreeTypeFont, fill: str) -> None:
    bbox = draw.textbbox((0, 0), text, font=fnt)
    x = box[0] + (box[2] - box[0] - (bbox[2] - bbox[0])) / 2
    y = box[1] + (box[3] - box[1] - (bbox[3] - bbox[1])) / 2 - 1
    draw.text((x, y), text, font=fnt, fill=fill)


def wrap_text(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont, width: int) -> list[str]:
    lines: list[str] = []
    for paragraph in text.split("\n"):
        words = paragraph.split()
        current = ""
        for word in words:
            trial = word if not current else f"{current} {word}"
            if draw.textbbox((0, 0), trial, font=fnt)[2] <= width:
                current = trial
            else:
                if current:
                    lines.append(current)
                current = word
        if current:
            lines.append(current)
    return lines


def text_block(draw: ImageDraw.ImageDraw, xy: tuple[int, int], width: int, height: int,
               text: str, size: int, fill: str, bold: bool = False) -> int:
    font_path = FONT_NARROW_BOLD if bold else FONT_NARROW
    for candidate in range(size, 9, -1):
        fnt = font(font_path, candidate)
        line_h = int(candidate * 1.18) + 2
        lines = wrap_text(draw, text, fnt, width)
        if len(lines) * line_h <= height:
            y = xy[1]
            for line in lines:
                draw.text((xy[0], y), line, font=fnt, fill=fill)
                y += line_h
            return y
    fnt = font(font_path, 9)
    line_h = 13
    lines = wrap_text(draw, text, fnt, width)
    max_lines = max(1, height // line_h)
    for index, line in enumerate(lines[:max_lines]):
        if index == max_lines - 1 and len(lines) > max_lines:
            while draw.textbbox((0, 0), f"{line}...", font=fnt)[2] > width and line:
                line = line[:-1]
            line = f"{line}..."
        draw.text((xy[0], xy[1] + index * line_h), line, font=fnt, fill=fill)
    return xy[1] + min(len(lines), max_lines) * line_h


def draw_badge(draw: ImageDraw.ImageDraw, x: int, y: int, text: str, fill: str,
               text_fill: str = "#f8efe0") -> int:
    fnt = font(FONT_NARROW_BOLD, 12)
    w = max(34, draw.textbbox((0, 0), text, font=fnt)[2] + 16)
    draw.rounded_rectangle((x, y, x + w, y + 20), radius=5, fill=fill, outline="#2a211c", width=1)
    draw_centered(draw, (x, y, x + w, y + 20), text, fnt, text_fill)
    return w


def draw_pixel_art(card: dict[str, Any], size: tuple[int, int]) -> Image.Image:
    seed = int(hashlib.sha256(card["id"].encode("utf-8")).hexdigest()[:16], 16)
    rng = random.Random(seed)
    w, h = 160, 58
    element = ELEMENTS[card["element"]]
    accent = hex_to_rgb(element["accent"])
    dark = hex_to_rgb(element["dark"])
    img = Image.new("RGBA", (w, h), dark + (255,))
    px = img.load()
    for y in range(h):
        t = y / max(1, h - 1)
        base = mix(dark, accent, 0.12 + 0.18 * t)
        for x in range(w):
            n = rng.randint(-12, 10)
            vignette = abs(x - w / 2) / (w / 2)
            shade = -int(vignette * 22)
            px[x, y] = (
                max(0, min(255, base[0] + n + shade)),
                max(0, min(255, base[1] + n + shade)),
                max(0, min(255, base[2] + n + shade)),
                255,
            )
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(24):
        x0 = rng.randint(-20, w)
        y0 = rng.randint(0, h)
        x1 = x0 + rng.randint(18, 60)
        y1 = y0 + rng.randint(-18, 18)
        color = accent + (rng.randint(35, 95),)
        d.line((x0, y0, x1, y1), fill=color, width=rng.choice([1, 1, 2]))

    cx = w // 2 + rng.randint(-8, 8)
    cy = h // 2 + rng.randint(-4, 4)
    glow = accent + (120,)
    bright = mix(accent, (255, 236, 194), 0.45)
    shadow = (23, 18, 16, 210)
    kind = card["kind"]
    name = card["name"].lower()

    d.ellipse((cx - 30, cy - 22, cx + 30, cy + 22), fill=accent + (42,), outline=bright + (180,), width=1)
    if kind == "LAW":
        d.rectangle((cx - 4, cy - 24, cx + 4, cy + 24), fill=bright + (230,))
        d.polygon([(cx - 30, cy - 15), (cx - 8, cy - 15), (cx - 18, cy + 4)], outline=bright + (230,), fill=glow)
        d.polygon([(cx + 30, cy - 15), (cx + 8, cy - 15), (cx + 18, cy + 4)], outline=bright + (230,), fill=glow)
    elif kind == "ENGINE":
        for i in range(12):
            ang = math.tau * i / 12
            x = cx + int(math.cos(ang) * 24)
            y = cy + int(math.sin(ang) * 19)
            d.rectangle((x - 2, y - 2, x + 2, y + 2), fill=bright + (220,))
        d.ellipse((cx - 18, cy - 18, cx + 18, cy + 18), outline=bright + (230,), width=4)
        d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=shadow)
    elif kind == "PACT":
        d.polygon([(cx, cy - 25), (cx + 25, cy + 18), (cx - 25, cy + 18)], fill=glow, outline=bright + (230,))
        d.line((cx - 26, cy + 18, cx + 26, cy + 18), fill=(90, 20, 24, 230), width=3)
        d.ellipse((cx - 5, cy - 5, cx + 5, cy + 5), fill=(180, 28, 32, 230))
    elif kind == "BURST":
        points = []
        for i in range(18):
            radius = 30 if i % 2 == 0 else 12
            ang = math.tau * i / 18 - math.pi / 2
            points.append((cx + int(math.cos(ang) * radius), cy + int(math.sin(ang) * radius)))
        d.polygon(points, fill=glow, outline=bright + (230,))
    elif kind == "FIELD":
        for gx in range(cx - 42, cx + 43, 14):
            d.line((gx, cy - 24, gx, cy + 24), fill=accent + (100,), width=1)
        for gy in range(cy - 21, cy + 22, 14):
            d.line((cx - 45, gy, cx + 45, gy), fill=accent + (100,), width=1)
        d.rounded_rectangle((cx - 26, cy - 18, cx + 26, cy + 18), radius=7, outline=bright + (230,), width=3)
    else:
        d.ellipse((cx - 24, cy - 20, cx + 24, cy + 20), outline=bright + (230,), width=3)

    if "mirror" in name or "echo" in name:
        d.arc((cx - 36, cy - 24, cx + 36, cy + 24), 210, 330, fill=(250, 250, 255, 220), width=3)
    if "blood" in name or card["health_cost"] > 0:
        d.ellipse((cx + 27, cy + 8, cx + 36, cy + 18), fill=(180, 24, 32, 210))
    if card["burn"]:
        d.polygon([(w - 18, 9), (w - 10, 26), (w - 22, 23), (w - 14, 43)], fill=(255, 102, 56, 210))

    mask = Image.new("L", (w, h), 0)
    md = ImageDraw.Draw(mask)
    poly = [(5, 4), (w - 7, 2), (w - 2, 12), (w - 5, h - 6), (w - 22, h - 2), (7, h - 5), (2, h - 16)]
    md.polygon(poly, fill=255)
    md.filter = None
    img.putalpha(mask.filter(ImageFilter.GaussianBlur(0.4)))
    return img.resize(size, Image.Resampling.NEAREST)


def render_card(card: dict[str, Any], number: int) -> Image.Image:
    frame_path = REPO / "assets" / "art" / "ui" / f"card_frame_rarity_{card['rarity']}.png"
    if frame_path.exists():
        base = Image.open(frame_path).convert("RGBA").resize((CARD_W, CARD_H), Image.Resampling.LANCZOS)
    else:
        base = Image.new("RGBA", (CARD_W, CARD_H), "#ead9bd")
    draw = ImageDraw.Draw(base, "RGBA")

    element = ELEMENTS[card["element"]]
    accent = element["accent"]
    rarity_color = RARITIES[card["rarity"]]["color"]
    draw.rounded_rectangle((24, 24, CARD_W - 24, CARD_H - 24), radius=16,
                           fill=hex_to_rgb(element["bg"]) + (85,))
    draw.rounded_rectangle((20, 20, CARD_W - 20, CARD_H - 20), radius=18,
                           outline=hex_to_rgb(accent) + (180,), width=3)

    title_limit = CARD_W - 68 - 73
    title_font = font(FONT_TITLE, 19)
    title_y = 26
    for size in range(19, 12, -1):
        candidate = font(FONT_TITLE, size)
        if draw.textbbox((0, 0), card["name"], font=candidate)[2] <= title_limit:
            title_font = candidate
            title_y = 27 + max(0, (19 - size) // 2)
            break
    else:
        for size in range(19, 11, -1):
            candidate = font(FONT_NARROW_BOLD, size)
            if draw.textbbox((0, 0), card["name"], font=candidate)[2] <= title_limit:
                title_font = candidate
                title_y = 27 + max(0, (19 - size) // 2)
                break
    draw.text((30, 29), f"{number:03d}", font=font(FONT_NARROW_BOLD, 13), fill="#4b382a")
    draw.text((68, title_y), card["name"], font=title_font, fill="#201915")

    draw.ellipse((CARD_W - 59, 20, CARD_W - 21, 58), fill="#2b241e", outline="#c8a95d", width=3)
    draw_centered(draw, (CARD_W - 59, 20, CARD_W - 21, 58), str(card["time"]), font(FONT_BOLD, 17), "#f8ecd0")

    meta_y = 57
    x = 30
    x += draw_badge(draw, x, meta_y, element["label"].upper()[:8], accent) + 5
    x += draw_badge(draw, x, meta_y, card["rarity"].upper()[:6], rarity_color) + 5
    if card["burn"]:
        x += draw_badge(draw, x, meta_y, "EXH", "#5d4037") + 5
    if int(card["health_cost"]) > 0:
        draw_badge(draw, x, meta_y, f"HP {card['health_cost']}", "#8f2d2d")

    art_box = (31, 86, CARD_W - 31, 184)
    draw.rounded_rectangle((art_box[0] - 2, art_box[1] - 2, art_box[2] + 2, art_box[3] + 2),
                           radius=10, fill="#211916", outline="#6b4b32", width=2)
    base.alpha_composite(draw_pixel_art(card, (art_box[2] - art_box[0], art_box[3] - art_box[1])), (art_box[0], art_box[1]))
    draw.rounded_rectangle(art_box, radius=8, outline=hex_to_rgb(accent) + (185,), width=2)

    chip_y = 191
    chip_x = 31
    for icon in card["iconography"][:3]:
        chip_x += draw_badge(draw, chip_x, chip_y, icon, "#3d322a", "#f1ddbd") + 5

    draw.text((31, 220), card["kind"], font=font(FONT_NARROW_BOLD, 12), fill=accent)
    text_block(draw, (31, 237), CARD_W - 62, 101, card["description"], 18, "#251d18", bold=False)

    hook_y = 346
    draw.rounded_rectangle((29, hook_y - 5, CARD_W - 29, CARD_H - 43), radius=7,
                           fill=(255, 248, 224, 138), outline=hex_to_rgb(accent) + (95,), width=1)
    draw.text((37, hook_y), "HOOKS", font=font(FONT_NARROW_BOLD, 11), fill="#5a4638")
    text_block(draw, (37, hook_y + 16), CARD_W - 74, 39, card["hooks"], 13, "#3e3028", bold=True)

    draw.text((31, CARD_H - 36), card["id"], font=font(FONT_NARROW, 11), fill="#5c4a3d")
    draw.rectangle((CARD_W - 86, CARD_H - 39, CARD_W - 32, CARD_H - 30), fill=hex_to_rgb(accent) + (190,))
    return base.convert("RGB")


def render_sheets(cards: list[dict[str, Any]]) -> list[Path]:
    sheet_paths: list[Path] = []
    gap = 24
    margin = 34
    header_h = 82
    sheet_w = margin * 2 + SHEET_COLS * CARD_W + (SHEET_COLS - 1) * gap
    sheet_h = header_h + margin + SHEET_ROWS * CARD_H + (SHEET_ROWS - 1) * gap + 40
    sheet_count = math.ceil(len(cards) / CARDS_PER_SHEET)

    for sheet_index in range(sheet_count):
        start = sheet_index * CARDS_PER_SHEET
        subset = cards[start:start + CARDS_PER_SHEET]
        sheet = Image.new("RGB", (sheet_w, sheet_h), "#1e1917")
        draw = ImageDraw.Draw(sheet)
        for y in range(sheet_h):
            t = y / max(1, sheet_h - 1)
            color = mix((29, 24, 22), (55, 42, 34), t)
            draw.line((0, y, sheet_w, y), fill=color)
        draw.text((margin, 26), "Escape the Umbra - 100 Text Build-Around Card Concepts",
                  font=font(FONT_TITLE, 25), fill="#f2dec0")
        draw.text((margin, 56), f"Sheet {sheet_index + 1} of {sheet_count}  |  Cards {start + 1:03d}-{start + len(subset):03d}",
                  font=font(FONT_NARROW, 18), fill="#cdb894")
        for local_index, card in enumerate(subset):
            row = local_index // SHEET_COLS
            col = local_index % SHEET_COLS
            x = margin + col * (CARD_W + gap)
            y = header_h + row * (CARD_H + gap)
            sheet.paste(render_card(card, start + local_index + 1), (x, y))
        path = ROOT / f"buildaround_card_sheet_{sheet_index + 1:02d}.png"
        sheet.save(path, optimize=True)
        sheet_paths.append(path)
    return sheet_paths


def write_catalog(cards: list[dict[str, Any]], sheet_paths: list[Path]) -> None:
    json_cards = []
    for number, card in enumerate(cards, 1):
        out = dict(card)
        out["number"] = number
        if out["element"] == "neutral":
            out["element"] = None
        json_cards.append(out)
    (ROOT / "buildaround_cards_100.json").write_text(json.dumps(json_cards, indent=2) + "\n", encoding="utf-8")

    lines = [
        "# Escape the Umbra - 100 Text Build-Around Card Concepts",
        "",
        "Design-only artifact. These cards are not implemented in `data/cards.json`.",
        "They intentionally use text-rule mechanics that need bespoke combat, UI, heuristic, and analytics work before shipping.",
        "",
        "## Image Sheets",
        "",
    ]
    for path in sheet_paths:
        lines.append(f"- `{path.name}`")
    lines.extend(["", "## Cards", ""])
    current_element = ""
    for number, card in enumerate(cards, 1):
        if card["element"] != current_element:
            current_element = card["element"]
            lines.append(f"## {ELEMENTS[current_element]['label']}")
            lines.append("")
        cost_bits = [f"time {card['time']}"]
        if card["burn"]:
            cost_bits.append("Exhaust")
        if card["health_cost"]:
            cost_bits.append(f"health cost {card['health_cost']}")
        lines.extend([
            f"### {number:03d}. {card['name']}",
            "",
            f"- id: `{card['id']}`",
            f"- rarity: {card['rarity']}",
            f"- element: {ELEMENTS[card['element']]['label']}",
            f"- cost: {', '.join(cost_bits)}",
            f"- kind: {card['kind']}",
            f"- text: {card['description']}",
            f"- hooks: {card['hooks']}",
            f"- iconography: {', '.join(card['iconography'])}",
            f"- proposed art path: `{card['proposed_art_path']}`",
            f"- art direction: {card['art_direction']}",
            "",
        ])
    (ROOT / "buildaround_cards_100.md").write_text("\n".join(lines), encoding="utf-8")


def validate(cards: list[dict[str, Any]]) -> None:
    ids = [card["id"] for card in cards]
    if len(cards) != 100:
        raise SystemExit(f"Expected 100 cards, found {len(cards)}")
    if len(set(ids)) != len(ids):
        raise SystemExit("Duplicate card ids found")
    for card in cards:
        if card["element"] not in ELEMENTS:
            raise SystemExit(f"Bad element on {card['id']}: {card['element']}")
        if card["rarity"] not in RARITIES:
            raise SystemExit(f"Bad rarity on {card['id']}: {card['rarity']}")
        if not 1 <= int(card["time"]) <= 10:
            raise SystemExit(f"Bad time on {card['id']}: {card['time']}")
        if not card["description"] or not card["art_direction"]:
            raise SystemExit(f"Missing kit text on {card['id']}")


def main() -> None:
    validate(CARDS)
    sheet_paths = render_sheets(CARDS)
    write_catalog(CARDS, sheet_paths)
    print(f"Rendered {len(sheet_paths)} sheets and {len(CARDS)} cards into {ROOT}")


if __name__ == "__main__":
    main()
