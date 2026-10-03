"""Relic pool overhaul: the authored design record (reviewed 2026-10-02, implemented).

Every relic in the 100-relic pool, plus the 12 cuts. For new, reworked and
tweaked relics, `text` is the shipped rules text in plain words (data/relics.json
carries the same text with inline icons). Kept relics ship their earlier wording;
their `text` here is a paraphrase for review. Vocabulary follows
spec/card_keywords*.md and spec/forced_movement.md.

Fields
  status   keep | tweak | rework | new | cut
  source   offer (treasure rooms) | guardian | dragon
  shape    Transform | Convert | Bridge | Amplify | Setup | Engine
  packages card packages the relic pays off (see PACKAGES)
  I, E     intrinsic and extrinsic value, 0-3 each: what it does in any deck,
           and how much more it does in the deck it wants
  combos   "card:<id>" and "relic:<id>" references, validated by the builder
  impl     0 data or tuning on existing effects | 1 extends an existing hook
           | 2 needs a new engine rule or event
"""

PACKAGES = {
    "forced": "Push & Pull",
    "tempo": "Stagger & Time",
    "followup": "Follow-up & sequencing",
    "empower": "Empower",
    "block": "Block & Retaliate",
    "earth": "Stoneskin, Rubble & outcrops",
    "fire": "Fire",
    "ice": "Ice",
    "lightning": "Lightning",
    "radiance": "Light & Umbra",
    "illusion": "Illusions",
    "movement": "Move & Blink",
    "rites": "Rites & Exhaust",
    "blood": "Health costs",
    "status": "Statuses",
    "items": "Items",
    "gear": "Gear & elements",
}

SHAPES = {
    "Transform": "Changes how a rule works, so a package plays differently.",
    "Convert": "Turns one resource or event into another, so a package feeds a second one.",
    "Bridge": "Joins two packages: each makes the other better.",
    "Amplify": "Scales one package, with a condition you build toward.",
    "Setup": "Puts something on the board or in hand at the start, then gets out of the way.",
    "Engine": "Stores or spreads something over a combat; grows the more you lean in.",
}

RELICS = []


def relic(rid, name, rarity, status, shape, packages, I, E, text, intrinsic, extrinsic,
          combos=(), note="", impl=0, was=None, source="offer", replacement=None):
    RELICS.append({
        "id": rid, "name": name, "rarity": rarity, "status": status, "source": source,
        "shape": shape, "packages": list(packages), "I": I, "E": E, "text": text,
        "was": was, "intrinsic": intrinsic, "extrinsic": extrinsic,
        "combos": list(combos), "note": note, "impl": impl, "replacement": replacement,
    })


C, R, EP, L = "common", "rare", "epic", "legendary"

# ============================================================================ COMMON
# Mostly intrinsic: useful in nearly any deck, with a lean toward one package.

relic("pilgrim_boots", "Pilgrim Boots", C, "keep", "Setup", ["movement", "radiance"], 3, 1,
      "Gain 1 extra movement each turn. Your Move leaves radius-1 Light for 2 turns along its path; a Blink lights both ends.",
      "An extra tile of movement every turn.",
      "The Light trail feeds Beaconrunner Spurs, Sunlit Edge and Unclouded Sun.",
      ["relic:beaconrunner_spurs", "relic:sunlit_edge"],
      "Kept. A clean movement common that already reaches into Radiance.")
relic("briar_winch", "Quarry Winch", C, "keep", "Transform", ["forced", "earth"], 1, 2,
      "When you Push or Pull an enemy standing on Rubble, you may consume the Rubble to aim in any cardinal direction.",
      "Free redirection whenever a target stands on Rubble; broken terrain and Earth enemies leave plenty.",
      "Rubble becomes aiming fuel: point every shove at a wall, an outcrop or another enemy.",
      ["relic:millstone_fob", "card:updraft", "relic:masons_plumb"],
      "Kept. Its sideways and away pulls already travel their full line.")
relic("rimecatcher_vial", "Rimecatcher Vial", C, "keep", "Transform", ["ice"], 1, 2,
      "When your attack Freezes an enemy, you may move one of the Ice tiles it consumed to a tile next to the target.",
      "Keeps a little Ice on the board after a Freeze.",
      "An Ice deck can Freeze, then Freeze the neighbour.",
      ["card:shatter", "relic:frost_prism"],
      "Kept.")
relic("tailwind_fletching", "Tailwind Fletching", C, "keep", "Amplify", ["forced"], 1, 2,
      "Your Air Push and Pull deal 1 more damage and move targets 1 tile farther.",
      "Every Air shove is a little stronger.",
      "Under the collision rule, one more tile is 2 more damage whenever the line is blocked.",
      ["card:updraft", "card:vortex", "relic:siege_ram_totem"],
      "Kept. The collision rule quietly made it better.")
relic("reinforced_shield", "Reinforced Shield", C, "keep", "Bridge", ["block", "earth"], 2, 1,
      "While you have Stoneskin, your Block cards grant 3 more Block.",
      "Bigger Block in any deck that touches Stoneskin.",
      "Grave Dirt, Rubblewalker Greaves and Ashen Phylactery keep it switched on.",
      ["relic:grave_dirt", "relic:obsidian_heart"],
      "Kept.")
relic("static_soles", "Static Soles", C, "keep", "Setup", ["lightning", "movement"], 2, 1,
      "Your first Move or Blink each turn leaves Electrified on the tile you left and grants Vision 1 for 2 turns.",
      "A little Vision every turn.",
      "Walk a line of Electrified for conduction, Grounding Pin and Copper-Shod Staff.",
      ["relic:grounding_pin", "card:volt_surge"],
      "Kept. It is a once-per-turn trigger, but it builds the board instead of handing out cards.")
relic("hourglass_awl", "Hourglass Awl", C, "tweak", "Amplify", ["tempo"], 2, 1,
      "Attacks on cards that cost 6 or more Time gain Pierce.",
      "Heavy weapons and big spells ignore Block.",
      "Pairs with Hourglass Splinter and Leaden Pommel in slow, heavy decks.",
      ["card:overhead_smash", "card:tectonic_maul", "relic:hourglass_splinter"],
      "Threshold lowered from 7 to 6: 7+ covered 14 cards, 6+ covers 40.", impl=0,
      was="Attacks on cards with Time 7+ gain Pierce.")
relic("iron_buckler", "Iron Buckler", C, "rework", "Transform", ["block"], 3, 1,
      "At the start of your turn, keep up to 3 of your Block.",
      "Block stops being all-or-nothing between turns.",
      "Holds Block thresholds open for Anchor Chain, Briar Vambrace and Cold Mirror.",
      ["relic:anchor_chain", "relic:cold_mirror", "card:brace"],
      "Replaces a draw trigger with a rule. Big Block turns now carry a little forward. The dragon benchmark build uses this relic and needs re-running.",
      impl=1, was="The first card each turn with Block or Stoneskin and no attacks draws 1.")
relic("coffin_nails", "Coffin Nails", C, "rework", "Convert", ["block", "status"], 2, 1,
      "When your Block stops all of an enemy attack's damage, the attacker gains Bleed 1.",
      "Any Block deck punishes the enemies it walls off.",
      "Bleeding attackers feed Funeral Bell and lose health as they keep moving and swinging.",
      ["relic:funeral_bell", "relic:iron_buckler"],
      "The old version gave your attacks Bleed while you had Block. This one makes the Block itself the weapon.",
      impl=2, was="While you have Block, attacks on your cards inflict Bleed +1.")
relic("duelist_whetstone", "Duelist Whetstone", C, "rework", "Amplify", ["movement"], 2, 1,
      "Attacks on cards that also Move or Blink deal 1 more damage for each tile you've traveled this turn (max 3 more).",
      "Lunges and charges hit harder.",
      "Counts independent movement too: walk first, then lunge. Feint Ribbon and Fencer's Gloves want the same turn.",
      ["card:bloody_lunge", "card:kestrel_dive", "relic:feint_ribbon"],
      "Uses the tiles-moved count the card overhaul added.", impl=1,
      was="Attacks on the first card each turn that also uses Move or Blink deal +2 damage.")
relic("flint_edge", "Flint Edge", C, "rework", "Convert", ["fire", "ice", "lightning"], 1, 2,
      "Your melee attacks consume the Fire, Ice or Electrified under their target to deal 3 more damage.",
      "Melee can cash in any ground an enemy stands on, including the enemy's own.",
      "Gives melee decks a stake in every element's surfaces.",
      ["card:rime_hack", "relic:pitch_gloves", "relic:breaking_wheel"],
      "Automatic, with no toggle: the hover forecast shows the tile being spent. Consumed Ice does not Freeze. It was +2 damage on Fire only.", impl=1,
      was="Your melee attacks deal +2 damage to enemies standing on Fire.")
relic("recoil_plates", "Recoil Plates", C, "new", "Convert", ["forced", "block"], 2, 1,
      "You take 1 Collision damage per lost tile instead of 2. Whenever you are part of a Collision, gain 3 Block.",
      "Blunts every enemy shove and Air trap.",
      "Lets you stand at the end of your own collision lanes.",
      ["relic:battering_yoke", "relic:hollow_puppet"],
      "Ash Hounds, Gallows Rocs, Stoneback Mites and Vaeloryx all push you into things now. This is the answer.", impl=1)
relic("millstone_fob", "Millstone Fob", C, "new", "Bridge", ["forced", "earth"], 1, 2,
      "When an enemy you Push or Pull collides, the tile it stopped on becomes Rubble.",
      "Rubble slows enemies walking back toward you.",
      "Collisions now feed every Rubble payoff: Quarry Signet, Quarry Winch, Basalt Kiln, Worldroot Idol.",
      ["relic:venom_signet", "relic:briar_winch", "card:crosswind"],
      "The seed of the Wrecking Yard build.", impl=1)
relic("tallow_candle", "Tallow Candle", C, "new", "Setup", ["radiance"], 3, 1,
      "At the start of each combat, create radius-2 Light on your tile for 3 turns.",
      "Starts every fight with sight and a lit tile, whatever the Umbra.",
      "Counts as a Light source for Captured Noon and a lit start for Sunlit Edge.",
      ["relic:tectonic_abacus", "relic:sunlit_edge"],
      "", impl=1)
relic("pocket_sundial", "Pocket Sundial", C, "new", "Convert", ["tempo"], 2, 1,
      "Each card play you leave unused at the end of your turn makes your next turn come 1 Time sooner (max 2).",
      "Playing one card is a real choice instead of a wasted play.",
      "Big single cards and Quicken turns; with Toll of the Late Bell, acting sooner means more enemies are late.",
      ["relic:toll_late_bell", "card:skybolt"],
      "Shown on the turn order rail as your next turn moving earlier.", impl=2)
relic("leaden_pommel", "Leaden Pommel", C, "new", "Amplify", ["tempo"], 2, 1,
      "Attacks on cards that cost 5 or more Time Stagger 1.",
      "Slow, heavy attacks also slow the enemy.",
      "Stacks with printed Stagger. Overflow past the limit feeds Pendulum Weight.",
      ["card:crushing_blow", "card:overhead_smash", "relic:pendulum_weight"],
      "", impl=0)
relic("pitch_gloves", "Pitch Gloves", C, "new", "Amplify", ["fire"], 1, 2,
      "Fire deals you 1 less damage. Fire you create deals enemies 1 more.",
      "Takes the sting out of enemy Fire and Fire traps.",
      "Fire decks can stand in their own fields and burn harder.",
      ["card:kindle", "relic:ember_siphon"],
      "", impl=1)
relic("hobnail_cleats", "Hobnail Cleats", C, "new", "Amplify", ["ice"], 1, 2,
      "Ice doesn't make you Chilled. While you stand on Ice, your Ice attacks deal 2 more damage.",
      "Ignore enemy Ice.",
      "Ice decks fight from their own field.",
      ["card:frost_lane", "relic:rimecatcher_vial"],
      "", impl=1)
relic("grounding_pin", "Grounding Pin", C, "new", "Bridge", ["lightning"], 1, 2,
      "Your single-target attacks against an enemy standing on Electrified gain Chain 1.",
      "Any attack can jump when the ground is charged, including enemy and trap Electrified.",
      "Lightning decks aim at the network instead of at the target.",
      ["relic:static_soles", "relic:copper_shod_staff", "card:static_ward"],
      "Replaces Ion Spool's draw trigger with an aiming rule.", impl=0)
relic("rubblewalker_greaves", "Rubblewalker Greaves", C, "new", "Amplify", ["earth", "movement"], 2, 1,
      "Rubble doesn't slow you. Start each turn standing on Rubble with 1 Stoneskin.",
      "Broken ground stops taxing your movement.",
      "Earth decks live on their own Rubble.",
      ["relic:millstone_fob", "card:quarry_step"],
      "", impl=1)
relic("grave_dirt", "Grave Dirt", C, "new", "Setup", ["earth"], 3, 1,
      "Start each combat with 4 Stoneskin.",
      "A safer first turn in any deck.",
      "Switches on Reinforced Shield, Faultline Brooch, Stonefist and Iron Lung from turn one.",
      ["relic:reinforced_shield", "relic:thornmail_brooch", "card:stonefist"],
      "Simple on purpose: a common that opens other relics.", impl=1)
relic("waxen_effigy", "Waxen Effigy", C, "new", "Setup", ["illusion"], 2, 2,
      "At the start of each combat, create a 2-health illusion on the empty tile next to you nearest an enemy.",
      "A free decoy to soak the first hit.",
      "Starts illusion payoffs on turn one: Widow Thread, Mirror Shard, Changeling's Rattle.",
      ["relic:widow_thread", "relic:mirror_shard", "relic:changelings_rattle"],
      "", impl=1)
relic("quick_draw_bandolier", "Quick-Draw Bandolier", C, "new", "Transform", ["items"], 2, 1,
      "Your items don't use a card play, but cost 1 more Time.",
      "Items become free actions on top of your two plays.",
      "Item-heavy loadouts turn every turn into three or four actions.",
      ["relic:alchemists_retort", "card:powder_keg", "card:throwing_net"],
      "", impl=2)
relic("briar_vambrace", "Briar Vambrace", C, "new", "Bridge", ["block"], 2, 1,
      "When a card gives you Block, also gain Retaliate 1 until your next turn.",
      "Every Block card has a few thorns.",
      "Retaliate decks stack it; Martyr's Gorget turns it back into Block.",
      ["relic:martyrs_gorget", "card:deflect"],
      "", impl=1)
relic("fencers_gloves", "Fencer's Gloves", C, "new", "Amplify", ["followup", "tempo"], 3, 1,
      "Your second card each turn costs 1 less Time.",
      "Every two-card turn is a little faster.",
      "Follow-up cards want to be second; so do heavy finishers.",
      ["card:quick_stab", "card:main_gauche", "relic:echoing_blade"],
      "", impl=1)

# ============================================================================ RARE
# Balanced: a modest effect anywhere, a real one in the right package.

relic("ember_lens", "Brightglass Lens", R, "keep", "Bridge", ["radiance", "lightning"], 1, 2,
      "Your ranged attacks against an enemy standing in Light gain Chain 1.",
      "Lit targets become Chain starts for any ranged deck.",
      "Radiance lights the board; Lightning uses it.",
      ["relic:tallow_candle", "card:forked_nock"],
      "Kept.")
relic("frost_prism", "Shatterglass Prism", R, "keep", "Bridge", ["ice", "earth"], 1, 2,
      "When your attack kills a Frozen enemy, Rubble appears under it and on each tile next to it.",
      "A Frozen kill leaves cover.",
      "Ice kills feed Earth's Rubble payoffs.",
      ["card:shatter", "relic:venom_signet"],
      "Kept.")
relic("anchor_chain", "Anchor Chain", R, "keep", "Bridge", ["block", "forced"], 1, 2,
      "While you have Block, your Push and Pull deal 2 more damage and move targets 1 tile farther.",
      "Defensive decks shove harder.",
      "One more tile is 2 more collision damage: Block decks hit like walls.",
      ["relic:iron_buckler", "card:shield_charge"],
      "Kept. The collision rule made its extra tile worth damage.")
relic("updraft_bottle", "Updraft Bottle", R, "keep", "Transform", ["forced", "fire", "ice", "lightning"], 1, 2,
      "When you Push or Pull an enemy off an elemental tile, you may carry that surface to where it lands.",
      "Move hazards instead of enemies.",
      "Drag a Fire tile into a Detonate cluster, or Ice to a wall.",
      ["card:vortex", "relic:breaking_wheel"],
      "Kept.")
relic("basalt_calendar", "Basalt Kiln", R, "keep", "Bridge", ["fire", "earth"], 1, 2,
      "Your Detonate may consume Rubble instead of Fire; the spent tiles become Fire.",
      "Rubble you already have becomes Detonate fuel.",
      "Earth fuels Fire, and leaves Fire for the next Detonate.",
      ["relic:millstone_fob", "card:magma_vent"],
      "Kept.")
relic("coalheart_crucible", "Stormcoal Crucible", R, "keep", "Bridge", ["fire", "lightning"], 0, 3,
      "Fire tiles also conduct Lightning. Attacks conducted through them consume them.",
      "Little without both schools.",
      "Fire fields become Lightning networks.",
      ["card:kindle", "card:spark_dart"],
      "Kept.")
relic("widow_thread", "Widow Thread", R, "keep", "Bridge", ["illusion", "status"], 1, 2,
      "While you have an illusion, your attacks Expose 1.",
      "Any deck with an illusion hits harder on the follow-up.",
      "Waxen Effigy turns it on from turn one.",
      ["relic:waxen_effigy", "card:straw_double"],
      "Kept.")
relic("thawing_charm", "Thawing Charm", R, "keep", "Convert", ["earth", "radiance"], 1, 2,
      "Healing beyond your maximum becomes Stoneskin (up to 8 each turn). The first conversion each turn creates radius-1 Light on you for 2 turns.",
      "Wasted healing is not wasted.",
      "Healing cards and items become armour.",
      ["card:patch_up", "card:crimson_draught"],
      "Kept.")
relic("storm_capacitor", "Storm Capacitor", R, "keep", "Amplify", ["lightning"], 1, 2,
      "Your Lightning ranged attacks with Chain gain Chain 1.",
      "Chain cards reach one more enemy.",
      "Pairs with Resonant Clapper and Storm Crown.",
      ["card:chain_bolt", "relic:storm_crown"],
      "Kept.")
relic("iron_lung", "Iron Lung", R, "rework", "Convert", ["blood", "empower", "earth"], 1, 2,
      "Every Health Cost, including an Empower cost, is paid from your Stoneskin first, at 2 Stoneskin per Health.",
      "A safety valve for any card that costs health.",
      "Blood and Empower decks can spend armour instead of life.",
      ["card:royal_bramble", "card:bloody_lunge", "relic:grave_dirt"],
      "Moved from common to rare. It was a once-per-turn Stoneskin trigger on health-cost cards.", impl=2,
      was="The first health-cost card you play each turn grants 3 Stoneskin.")
relic("hourglass_splinter", "Hourglass Splinter", R, "rework", "Convert", ["tempo"], 2, 1,
      "When you play a card that costs 6 or more Time, Quicken 2.",
      "A heavy card makes the next one cheap.",
      "Heavy opener, cheap Follow-up second card; stacks with Fencer's Gloves.",
      ["card:overhead_smash", "relic:fencers_gloves", "relic:hourglass_awl"],
      "", impl=1,
      was="The first card with Time 7+ each turn grants 1 card play and 4 Block.")
relic("chorus_mask", "Chorus Mask", R, "rework", "Amplify", ["gear"], 1, 2,
      "A card whose element differs from the last card you played this turn deals 2 more damage and grants 2 more Block.",
      "Mixed decks get a bonus on alternating turns.",
      "Two-school decks alternate on purpose.",
      ["relic:fivefold_knot", "relic:bonded_set"],
      "Keeps the variety idea and drops the extra card play.", impl=1,
      was="The first elemental card played after a different element each turn grants 1 card play and 3 Block.")
relic("gale_tabi", "Gale Tabi", R, "rework", "Convert", ["movement"], 1, 2,
      "After you Blink, your next attack this turn deals 1 more damage for each tile that Blink spanned (max 4 more).",
      "Blink becomes an attack setup.",
      "Long Blinks into big hits; pairs with Feint Ribbon.",
      ["card:kestrel_dive", "card:shadow_step", "relic:feint_ribbon"],
      "", impl=1,
      was="The first Blink of 3+ each turn draws 1 and grants 1 card play.")
relic("mirror_shard", "Mirror Shard", R, "rework", "Convert", ["illusion"], 1, 2,
      "When your Illusion is destroyed, it shatters, dealing 3 damage to each enemy next to it.",
      "A decoy that bites back.",
      "Hall of Mirrors becomes a minefield; Hollow Puppet throws the mines.",
      ["card:hall_of_mirrors", "relic:hollow_puppet", "relic:waxen_effigy"],
      "", impl=1,
      was="The first card that creates an illusion each turn grants 1 card play and Vision 1.")
relic("venom_signet", "Quarry Signet", R, "rework", "Amplify", ["earth", "forced"], 1, 2,
      "Enemies standing on Rubble take 1 more damage from everything: attacks, Collision, Fire and Retaliate.",
      "Broken ground favours you.",
      "Rubble-making decks multiply every hit.",
      ["relic:millstone_fob", "relic:siege_ram_totem", "card:fault_strike"],
      "Broader than the old +2 to attacks: collisions and passive damage count too.", impl=1,
      was="Your attacks deal +2 damage to enemies standing on Rubble.")
relic("ember_siphon", "Ember Siphon", R, "rework", "Engine", ["fire"], 1, 2,
      "When an enemy dies while standing on Fire, Fire spreads to each empty tile next to where it fell.",
      "Enemy and trap Fire becomes fuel too.",
      "Fire decks kill on their own fields, and every kill refuels the next Detonate.",
      ["card:wildfire_halo", "relic:ashen_brand"],
      "", impl=1,
      was="Once per combat, an enemy killed by your Fire or Detonate heals 3 and leaves Light.")
relic("beaconrunner_spurs", "Beaconrunner Spurs", R, "rework", "Bridge", ["radiance", "movement"], 1, 2,
      "Each tile of your Light you enter during a Move refunds 1 movement (max 2 each turn).",
      "Longer walks in lit rooms.",
      "Radiance decks move farther than anyone.",
      ["relic:pilgrim_boots", "relic:unclouded_sun"],
      "", impl=2,
      was="The first Move or Blink each turn that ends in Light grants 1 card play and 3 Block.")
relic("feint_ribbon", "Feint Ribbon", R, "new", "Bridge", ["followup", "movement"], 1, 2,
      "If you've traveled 2 or more tiles this turn, your first card counts as a Follow-up.",
      "Rewards moving before you play.",
      "Follow-up cards fire on card one, so both of your plays carry a bonus.",
      ["card:quick_stab", "card:palm_strike", "relic:echoing_blade"],
      "", impl=1)
relic("battering_yoke", "Battering Yoke", R, "new", "Transform", ["forced"], 1, 2,
      "When an enemy you Push or Pull collides with another enemy, that enemy is knocked 1 tile in the same direction, colliding normally if it can't move.",
      "Crowds become chain reactions.",
      "One shove moves a whole cluster into the wall.",
      ["card:unsealed_gale", "relic:siege_ram_totem", "relic:galehook_talon"],
      "", impl=2)
relic("pendulum_weight", "Pendulum Weight", R, "new", "Convert", ["tempo"], 0, 3,
      "Stagger beyond an enemy's per-turn limit is dealt to it as damage instead.",
      "Nothing without Stagger.",
      "The Stagger cap stops being a ceiling.",
      ["card:tremor", "relic:leaden_pommel", "relic:siege_ram_totem"],
      "", impl=1)
relic("martyrs_gorget", "Martyr's Gorget", R, "new", "Convert", ["block"], 1, 2,
      "When your Retaliate damages an attacker, gain that much Block.",
      "Some armour back whenever thorns fire.",
      "Thorns refill your Block mid-enemy-turn; Briar Vambrace makes every Block card count.",
      ["relic:briar_vambrace", "card:riposte_lunge", "card:bristle"],
      "", impl=1)
relic("reliquary_box", "Reliquary Box", R, "new", "Amplify", ["rites"], 0, 3,
      "Your opening hand includes a Rite from your deck, if you have one. Each Rite costs 1 less Time.",
      "Nothing without Rites.",
      "Your Rite is down by turn one, every combat.",
      ["card:rite_of_the_pyre", "relic:liturgy_of_ash"],
      "", impl=1)
relic("changelings_rattle", "Changeling's Rattle", R, "new", "Bridge", ["illusion", "tempo"], 1, 2,
      "When an enemy destroys your Illusion, that enemy suffers Stagger 3 and Expose 2.",
      "Any decoy delays the enemy who breaks it.",
      "Illusion decks bait enemies down the turn clock.",
      ["card:mirror_feint", "relic:toll_late_bell"],
      "", impl=1)
relic("copper_shod_staff", "Copper-Shod Staff", R, "new", "Bridge", ["lightning", "earth", "illusion"], 0, 3,
      "Your outcrops and Illusion count as Electrified for your Lightning: they conduct and carry Chain, and take no damage from it.",
      "Nothing without Lightning.",
      "Walls and decoys become relays.",
      ["card:raise_stone", "card:straw_double", "card:chain_bolt"],
      "", impl=2)
relic("ashen_phylactery", "Ashen Phylactery", R, "new", "Convert", ["rites", "earth"], 1, 2,
      "When you Exhaust a card, gain Stoneskin equal to the Time you paid for it (max 5).",
      "Exhaust cards leave armour behind.",
      "Every Rite is also a Stoneskin card.",
      ["card:rite_of_the_mountain", "card:borrowed_spark", "relic:reinforced_shield"],
      "", impl=1)
relic("bonded_set", "Bonded Set", R, "new", "Amplify", ["gear"], 1, 2,
      "Cards from an equipment piece that shares its element with another equipped piece deal 1 more damage and grant 1 more Block.",
      "Rewards matching gear.",
      "A fire weapon and fire boots both improve.",
      ["relic:chorus_mask"],
      "", impl=1)
relic("overclock_coil", "Overclock Coil", R, "new", "Convert", ["empower", "tempo"], 0, 3,
      "When you Empower a card, Quicken 2.",
      "Nothing without Empower.",
      "Pays back Empower's Time; health and Exhaust Empowers become tempo.",
      ["card:overclock", "card:overhead_smash", "relic:crown_of_surplus"],
      "", impl=1)
relic("fetter_spikes", "Fetter Spikes", R, "new", "Bridge", ["status", "forced"], 0, 3,
      "Enemies with Immobilize take double Collision damage.",
      "Nothing without Immobilize.",
      "Pin it, then slam it.",
      ["card:snare_coil", "card:anchor_slam", "card:throwing_net"],
      "", impl=1)
relic("masons_plumb", "Mason's Plumb", R, "new", "Bridge", ["earth", "forced"], 0, 3,
      "Your outcrops have 2 more health. An enemy that collides with one of your outcrops takes 2 more damage, and the outcrop takes none.",
      "Nothing without outcrops.",
      "Build the wall, then shove enemies into it.",
      ["card:earthen_rampart", "card:geode", "relic:millstone_fob"],
      "", impl=1)

# ============================================================================ EPIC
# Mostly extrinsic: a turn-shaping effect once your deck supports it.

relic("bloodglass_knife", "Bloodglass Knife", EP, "keep", "Transform", ["blood"], 1, 2,
      "While at half health or less with no Block or Stoneskin, your attacks deal 7 more damage.",
      "A comeback edge at real risk.",
      "Health-cost decks live under the line on purpose.",
      ["relic:bloodmoon_chalice", "relic:iron_lung"],
      "Kept.")
relic("thunder_relay", "Thunder Relay", EP, "keep", "Transform", ["lightning", "forced"], 0, 3,
      "Your Chain attacks may swap their first and last enemy targets if both survive.",
      "Nothing without Chain.",
      "Chain becomes repositioning.",
      ["card:chain_bolt", "relic:storm_crown"],
      "Kept.")
relic("thornmail_brooch", "Faultline Brooch", EP, "keep", "Transform", ["earth"], 1, 2,
      "You may spend 4 Stoneskin to turn a single-target melee attack into a cross that leaves Rubble.",
      "Turns spare armour into reach.",
      "Stoneskin decks spend armour on area attacks.",
      ["relic:grave_dirt", "relic:ashen_phylactery"],
      "Kept.")
relic("obsidian_heart", "Obsidian Heart", EP, "keep", "Transform", ["block", "earth"], 2, 2,
      "Draw 1 fewer card in your opening hand. At the end of your turn, your remaining Block becomes Stoneskin.",
      "All Block persists, at a cost of one opening card.",
      "Block decks build a permanent wall.",
      ["relic:reinforced_shield", "card:shield_wall"],
      "Kept.")
relic("tectonic_abacus", "Captured Noon", EP, "keep", "Amplify", ["radiance"], 1, 2,
      "With 3 of your Light sources active, Umbra is 1 stage lower; with 6, it is 2 stages lower.",
      "Pushes back the dark.",
      "Light decks hold the room clear.",
      ["relic:tallow_candle", "relic:pilgrim_boots"],
      "Kept.")
relic("sunlit_edge", "Sunlit Edge", EP, "keep", "Bridge", ["radiance"], 1, 2,
      "While you stand in Light, your attacks Pierce.",
      "Fight from a lit tile and ignore Block.",
      "Radiance decks keep a lit tile under you.",
      ["relic:pilgrim_boots", "relic:tallow_candle"],
      "Kept.")
relic("witchglass_carapace", "Witchglass Carapace", EP, "keep", "Amplify", ["illusion"], 0, 3,
      "Enemy ranged attacks deal at most 1 damage to your illusions.",
      "Nothing without illusions.",
      "Decoys survive ranged enemies.",
      ["card:doppelganger", "relic:mirror_triptych"],
      "Kept.")
relic("cold_mirror", "Cold Mirror", EP, "rework", "Convert", ["ice", "block"], 0, 3,
      "When you Freeze an enemy while you have 4 or more Block, your Block hardens: lose all your Block and gain 1 Crystal Mantle layer for every 4 lost (max 2).",
      "Nothing without Freeze.",
      "Each Mantle layer cancels a whole hit: a Freeze turn becomes a shield.",
      ["card:shatter", "relic:iron_buckler", "card:crystal_mantle"],
      "Uses the Mantle mechanic from the card overhaul.", impl=1,
      was="Once per turn, inflicting Freeze while you have Block converts up to 6 Block into Stoneskin.")
relic("vaulting_sigil", "Vaulting Sigil", EP, "rework", "Transform", ["movement", "tempo"], 1, 2,
      "Your Move can pass through enemies (you can't stop on one). Each enemy you pass through suffers Stagger 2.",
      "Enemies stop boxing you in.",
      "Run through the line, delaying each enemy you pass.",
      ["card:headlong", "relic:toll_late_bell", "relic:duelist_whetstone"],
      "", impl=2,
      was="The first Move or Blink of 4+ each turn grants 1 card play and 4 Block.")
relic("overflow_censer", "Overflow Censer", EP, "rework", "Engine", ["fire", "ice", "lightning", "earth"], 0, 3,
      "When you place Fire, Ice or Electrified on a tile holding a different one of them, it also spreads to each empty tile next to it.",
      "Nothing without two schools of ground.",
      "Mixed boards grow every time you overwrite.",
      ["relic:black_sun_dial", "relic:coalheart_crucible"],
      "", impl=2,
      was="Once per combat, having 3 different surface types in view grants 6 Stoneskin and draw 2.")
relic("funeral_bell", "Funeral Bell", EP, "rework", "Engine", ["status"], 1, 2,
      "When an enemy dies with 2 or more different statuses, such as Bleed and Expose, each enemy next to it gains them.",
      "Chill from Ice ground and Bleed from Coffin Nails count; mixed decks trigger it by accident.",
      "Bleed, Expose, Sunder and Shock spread through crowds.",
      ["relic:coffin_nails", "relic:widow_thread", "card:hamstring_slice"],
      "", impl=1,
      was="When your actions kill the third enemy with a status effect this combat, draw 3 and gain 2 card plays.")
relic("bloodmoon_chalice", "Bloodmoon Chalice", EP, "rework", "Convert", ["blood"], 1, 2,
      "When you lose health during your turn, your next attack this turn deals 2 more damage per health lost (max 8 more).",
      "Fire, collisions and Bleed on your own turn pay you back.",
      "Health costs and Empower (health) become damage.",
      ["card:royal_bramble", "relic:bloodglass_knife", "card:phoenix_cleave"],
      "", impl=1,
      was="The first health-cost card finished at half health or less each combat heals 5, draws 2 and grants 1 card play.")
relic("glassway_compass", "Glassway Compass", EP, "rework", "Transform", ["illusion", "movement"], 0, 3,
      "Your Move and Blink can end on your Illusion: you trade places with it instantly, skipping the tiles between.",
      "Nothing without illusions.",
      "Every illusion is a door.",
      ["card:hall_of_mirrors", "relic:waxen_effigy", "relic:mirror_triptych"],
      "Uses the normal Move and Blink destination click; no new action. Moved from legendary to epic: its old effect is half of Eclipse Mantle, which keeps it. Owner review 2026-10-03: a Move trade is a teleport that spends the route's movement but enters only the landing tile.", impl=2,
      was="The first Blink each turn creates a 2-health illusion on the tile you left.")
relic("breaking_wheel", "The Breaking Wheel", EP, "new", "Bridge", ["forced", "fire", "ice", "lightning", "earth"], 0, 3,
      "An enemy colliding on a surface breaks it: Fire deals 3 more damage, Ice gives Freeze, Electrified gives Shock to it and its blocker, Rubble gives Stagger 3.",
      "Nothing without forced movement.",
      "Every school's ground becomes a collision finisher.",
      ["relic:updraft_bottle", "relic:millstone_fob", "card:sleet_squall"],
      "The consumed surface is removed. Freeze through collision is strong; it needs Ice at the exact contact tile.", impl=2)
relic("hollow_puppet", "Hollow Puppet", EP, "new", "Transform", ["illusion", "forced"], 0, 3,
      "Your Push and Pull can target your Illusion without damaging it. An Illusion that collides with an enemy shatters, dealing its remaining Health to that enemy instead of Collision damage.",
      "Nothing without both.",
      "Decoys become thrown weapons.",
      ["card:hall_of_mirrors", "relic:mirror_shard", "card:yank"],
      "Breaks the no-illusion-displacement rule on purpose, for your own Push and Pull only.", impl=2)
relic("toll_late_bell", "Toll of the Late Bell", EP, "new", "Amplify", ["tempo"], 1, 2,
      "Enemies set to act after your next turn on the Turn Clock are late: your attacks deal them 3 more damage.",
      "Slow enemies are already late in many fights.",
      "Stagger them, Quicken yourself, and they are all late.",
      ["relic:pocket_sundial", "relic:siege_ram_totem", "card:crushing_blow"],
      "Shown on the turn order rail: a late enemy's portrait carries the bell.", impl=1)
relic("rosary_of_vows", "Rosary of Vows", EP, "new", "Engine", ["rites", "block"], 0, 3,
      "At the start of your turn, gain 2 Block for each active Rite you have.",
      "Nothing without Rites.",
      "Every Rite also becomes a Block engine.",
      ["relic:reliquary_box", "relic:liturgy_of_ash"],
      "", impl=1)
relic("siege_ram_totem", "Siege Ram Totem", EP, "new", "Bridge", ["forced", "tempo"], 1, 2,
      "Any enemy that takes Collision damage suffers that much Stagger (within the normal limit).",
      "Enemies that shove you into their allies delay those allies.",
      "Every slam knocks the target back down the turn clock.",
      ["relic:pendulum_weight", "relic:toll_late_bell", "card:updraft"],
      "", impl=1)
relic("echoing_blade", "Echoing Blade", EP, "new", "Engine", ["followup"], 0, 3,
      "When a Follow-up bonus applies, your next card this turn costs 1 less Time and deals 2 more damage.",
      "Nothing without Follow-up.",
      "Follow-ups chain: three-card turns gain the most.",
      ["relic:feint_ribbon", "relic:whirling_sash", "card:main_gauche"],
      "", impl=1)
relic("alchemists_retort", "Alchemist's Retort", EP, "new", "Amplify", ["items"], 1, 2,
      "Your items' damage, Block, Heal and Stoneskin are increased by half, rounded up.",
      "Every item you find is better.",
      "Item builds turn consumables into centrepieces.",
      ["relic:quick_draw_bandolier", "card:powder_keg", "card:crimson_draught"],
      "", impl=1)

# ============================================================================ LEGENDARY
# Strongly extrinsic: a rule that defines the run once the deck is built for it.

relic("phoenix_ember", "Phoenix Ember", L, "keep", "Engine", ["blood", "fire"], 2, 2,
      "Gain 1 Defiance this run. When it triggers, Dispel 2 Umbra, place Fire beneath all enemies, draw 3 and gain 3 card plays.",
      "A second life.",
      "Fire decks turn the rescue into a counterattack.",
      ["relic:ashen_brand", "relic:ember_siphon"],
      "Kept.")
relic("worldroot_idol", "Worldroot Idol", L, "keep", "Transform", ["earth", "movement"], 0, 3,
      "While you stand on Rubble, you may launch a single-target melee or ranged attack from another connected Rubble tile, consuming it.",
      "Nothing without Rubble.",
      "Rubble networks become a battlefield you attack from anywhere.",
      ["relic:millstone_fob", "relic:rubblewalker_greaves"],
      "Kept.")
relic("storm_crown", "Storm Crown", L, "rework", "Transform", ["lightning"], 0, 3,
      "Your Chain attacks rebound: after the last hop, the bolt travels back along its route, hitting each enemy again for half damage (rounded down).",
      "Nothing without Chain.",
      "Every Chain hits each target twice.",
      ["relic:storm_capacitor", "relic:resonant_clapper", "card:chain_bolt"],
      "The rebound doesn't conduct and doesn't count as new hops for Resonant Clapper.", impl=2,
      was="The first Chain attack each turn that hits 3+ different enemies draws 2 and grants 1 card play.")
relic("black_sun_dial", "Black Sun Dial", L, "rework", "Engine", ["fire", "ice", "lightning", "earth"], 0, 3,
      "Consuming a surface stores it (max 3). Your next attack deals 2 more damage per stored surface, and its target gets each one's effect: Fire beneath it, Chilled, Shock, Stagger 2.",
      "Nothing without surfaces to spend.",
      "Spend three schools' ground, then unload it in one hit.",
      ["relic:flint_edge", "relic:overflow_censer", "card:magma_vent"],
      "Shown on the badge as up to three stored elements.", impl=2,
      was="Once per combat, your first elemental consume on Rubble deals 6 to everyone in a cross and grants 6 Stoneskin.")
relic("fivefold_knot", "Fivefold Knot", L, "rework", "Engine", ["gear"], 0, 3,
      "Each element you play ties its knot for this combat. With 3 of the 5 knots, your attacks Pierce; with 4, they also gain Chain 1; with all 5, every card you play also grants 3 Block.",
      "Nothing in a one-school deck.",
      "Five-school decks unlock a new rule every knot.",
      ["relic:chorus_mask", "relic:bonded_set"],
      "Thresholds instead of a once-per-combat jackpot.", impl=2,
      was="Once per combat, after you play all 5 elements in one turn, draw 5 and gain 5 card plays.")
relic("borrowed_hourglass", "Borrowed Hourglass", L, "rework", "Transform", ["tempo"], 1, 2,
      "Once per combat, when you end your turn with a card play unused, take another turn at once. Everything it costs is added to your next turn's Time.",
      "One extra turn per fight.",
      "Spend one play to buy a whole turn ahead of the enemies; Quicken and cheap cards keep the Time debt small.",
      ["relic:pocket_sundial", "relic:toll_late_bell", "card:stolen_moment"],
      "", impl=2,
      was="The first banked card play spent on a Time 7+ card each combat draws 4 and grants 3 card plays.")
relic("unclouded_sun", "Unclouded Sun", L, "rework", "Transform", ["radiance", "movement"], 0, 3,
      "Your Light sources are relay points: when you Move, each of them counts as next to every other.",
      "Nothing without Light.",
      "Every Light source is a relay.",
      ["relic:pilgrim_boots", "relic:beaconrunner_spurs", "card:daybreak"],
      "Owner review 2026-10-03: only Light sources link, so a jump runs relay to relay and the hero walks to and from them; the jump plays as a Blink.", impl=2,
      was="Once per combat, when a room that began in Umbra first becomes Clear, gain 12 Stoneskin, draw 3 and gain 3 card plays.")
relic("crown_of_surplus", "Crown of Surplus", L, "new", "Transform", ["empower", "tempo"], 2, 2,
      "Cards without their own Empower gain one: Empower (+3 Time): repeat the card's first action. Rite cards, items and Flurry cards are excluded.",
      "Any card can double up.",
      "Overclock Coil and Quicken pay the Time back.",
      ["relic:overclock_coil", "relic:fencers_gloves"],
      "The Time cost is the brake. Enemies act more often against a deck that doubles everything.", impl=2)
relic("mirror_triptych", "Mirror Triptych", L, "new", "Engine", ["illusion"], 0, 3,
      "Your first attack card each turn is echoed by up to 3 Illusion at half damage (rounded down). Each hits the nearest enemy it can reach and loses 1 Health.",
      "Nothing without illusions.",
      "A hall of mirrors becomes a firing line.",
      ["card:hall_of_mirrors", "relic:witchglass_carapace", "relic:glassway_compass"],
      "Capped at three echoes; echoes wear the illusions down.", impl=2)
relic("liturgy_of_ash", "Liturgy of Ash", L, "new", "Transform", ["rites"], 0, 3,
      "Rite cards don't use a Card Play.",
      "Nothing without Rites.",
      "Every Rite is free tempo; a Rite deck plays two attacks and its Rites each turn.",
      ["relic:reliquary_box", "relic:rosary_of_vows", "relic:ashen_phylactery"],
      "", impl=1)
relic("pyre_keepers_urn", "Pyre-Keeper's Urn", L, "new", "Engine", ["rites"], 0, 3,
      "At the start of your turn, the last card you sent to Exhaust returns to your hand, unless it is a Rite or has Heal.",
      "Nothing without Exhaust.",
      "One-shot cards become every-turn cards.",
      ["card:phoenix_cleave", "card:borrowed_spark", "relic:ashen_phylactery"],
      "", impl=2)
relic("briar_throne", "Briar Throne", L, "new", "Transform", ["block"], 0, 3,
      "Your Retaliate no longer expires, and grows by 1 each time it triggers. Cards can't give you Block.",
      "A trap without Retaliate cards.",
      "Thorns become your whole defence and keep growing all combat.",
      ["card:barbed_mail", "card:bristle", "relic:martyrs_gorget"],
      "A real trade: no Block from cards. Block from relics, such as Martyr's Gorget and Recoil Plates, still works.", impl=2)
relic("whirling_sash", "Whirling Sash", L, "new", "Transform", ["followup", "tempo"], 2, 2,
      "Gain 1 extra card play each turn. Each card after your second each turn costs 2 more Time.",
      "A third card every turn.",
      "Follow-up, Quicken and cheap cards make the third card nearly free; Flurry repeats once more.",
      ["relic:echoing_blade", "relic:fencers_gloves", "card:razor_gale"],
      "", impl=1)
relic("quartermasters_ledger", "Quartermaster's Ledger", L, "new", "Transform", ["items"], 0, 3,
      "Your items lose Consume, except items that Heal. Each item can be used once per combat.",
      "Nothing until you carry items.",
      "Your item loadout becomes a permanent second deck.",
      ["relic:quick_draw_bandolier", "relic:alchemists_retort", "card:powder_keg"],
      "Healing stays scarce: draughts and elixirs are still Consumed. The Scavenger's item prices may need a look.", impl=2)

# ============================================================================ TROPHIES
# Guardian and dragon rewards: never offered at random. Kept unless noted.

relic("ashen_brand", "Ashen Brand", L, "keep", "Transform", ["fire"], 0, 3,
      "Detonate consumes the whole connected Fire cluster. Each extra overlapping blast adds 25% of base damage.",
      "", "Fire decks shape one huge Detonate.", ["relic:ember_siphon"], "Kept. Rewarded by the Ashen Reaver.", source="guardian")
relic("winters_spur", "Winter’s Spur", L, "keep", "Transform", ["ice", "movement"], 0, 3,
      "A straight stretch of Ice costs 1 base movement per Move. Turning starts a new stretch.",
      "", "Ice roads become highways.", ["relic:hobnail_cleats"], "Kept. Rewarded by Rimejaw.", source="guardian")
relic("resonant_clapper", "Resonant Clapper", L, "keep", "Amplify", ["lightning"], 0, 3,
      "Chain gains 25% of base damage for each successive enemy hop.",
      "", "Long Chains end on big hits.", ["relic:storm_crown"], "Kept. Rewarded by the Storm Cantor.", source="guardian")
relic("galehook_talon", "Galehook Talon", L, "keep", "Transform", ["forced"], 0, 3,
      "Push and Pull move the target's whole contiguous line of enemies together; the group stops at an obstruction.",
      "", "Lines of enemies slam as one.", ["relic:battering_yoke"], "Kept. Rewarded by the Gallows Roc.", source="guardian")
relic("cragbound_gauntlet", "Cragbound Gauntlet", L, "keep", "Transform", ["earth"], 0, 3,
      "Your ranged Earth spells raise a 3-health outcrop at an empty ground target.",
      "", "Every Earth shot builds cover.", ["relic:masons_plumb"], "Kept. Rewarded by Craghide.", source="guardian")
relic("procession_lantern", "Procession Lantern", L, "keep", "Transform", ["illusion", "movement"], 0, 3,
      "Your illusions can use your independent movement.",
      "", "Decoys walk.", ["relic:glassway_compass"], "Kept. Rewarded by the Last Lamplighter.", source="guardian")
relic("crowncoal_heart", "Crowncoal Heart", L, "keep", "Engine", ["fire", "earth"], 0, 3,
      "Each turn, your first single-target hit on ground without an elemental surface leaves Fire. Your first Detonate each turn that consumes 2+ Fire grants 6 Stoneskin.",
      "", "Attacks lay the fuel.", ["relic:ashen_brand"], "Kept. Vyraketh's trophy.", source="dragon")
relic("worldheart", "Worldheart", L, "keep", "Engine", ["block", "earth"], 0, 3,
      "At the end of your turn, up to 2 remaining Block becomes Stoneskin. Whenever you gain Stoneskin, deal half that amount (rounded down, max 4) to each adjacent enemy.",
      "", "Armour becomes thorns.", ["relic:ashen_phylactery"], "Kept. Tharokh's trophy.", source="dragon")
relic("unbound_pinion", "Unbound Pinion", L, "tweak", "Convert", ["forced", "movement"], 0, 3,
      "The first card action each turn that sends an enemy 2 or more tiles, or makes it collide, refills your movement and you Draw 1.",
      "", "A slam refills your legs.", ["relic:millstone_fob"],
      "Collisions now count, so a fully blocked push still triggers it. Vaeloryx's trophy.", impl=1, source="dragon",
      was="The first card action each turn that pushes or pulls an enemy at least 2 tiles refills your movement and draws 1.")
relic("winters_hour", "Winter's Hourglass", L, "keep", "Convert", ["ice", "tempo"], 0, 3,
      "Your first Ice card each turn stores 3 Time (max 3). Non-Ice cards spend stored Time to cost less, to a minimum of 1. Stored Time lasts the combat.",
      "", "Ice pays for everything else.", ["relic:hourglass_splinter"], "Kept. Iskaldra's trophy.", source="dragon")
relic("stormroad_coil", "Stormroad Coil", L, "keep", "Transform", ["lightning"], 0, 3,
      "Single-target ranged attacks can relay once through Electrified, with normal range on each leg.",
      "", "Shoot around corners.", ["relic:static_soles"], "Kept. Zekarion's trophy.", source="dragon")
relic("eclipse_mantle", "Eclipse Mantle", L, "keep", "Engine", ["illusion", "radiance", "movement"], 0, 3,
      "Your first Blink each turn leaves a 2-health illusion at its origin. Your illusions radiate radius-2 Light while they last.",
      "", "Every Blink leaves a lantern.", ["relic:mirror_triptych"], "Kept. Noctyrax's trophy, for the next run.", source="dragon")

# ============================================================================ CUTS
# Retired. Saves that hold one receive the listed replacement.

relic("true_north", "True North", R, "cut", "Amplify", ["radiance"], 0, 1,
      "", "", "", [], "+1 range while you have Truesight rarely changes a decision, and Truesight is rare.",
      was="While you have Truesight, ranged actions gain +1 range.", replacement="bonded_set")
relic("dawnstitch_cord", "Dawnstitch Cord", R, "cut", "Amplify", ["radiance"], 0, 1,
      "", "", "", [], "A once-per-turn Block tip for Radiance cards. Radiance already has more relics than any other school.",
      was="The first card each turn that creates Light, grants Vision or Truesight, or Dispels Umbra grants 4 Block.", replacement="martyrs_gorget")
relic("starless_astrolabe", "Starless Astrolabe", R, "cut", "Amplify", ["radiance"], 0, 1,
      "", "", "", [], "Truesight plus Freeze or Shock to make a little Light: three narrow conditions for a small effect.",
      was="While you have Truesight, applying Freeze or Shock creates Light beneath that enemy.", replacement="changelings_rattle")
relic("voltaic_tuning_fork", "Stormglass Beacon", R, "cut", "Amplify", ["lightning", "radiance"], 0, 1,
      "", "", "", [], "Light under Chain targets overlaps Brightglass Lens and pays off nothing Lightning wants.",
      was="The first Chain attack each turn creates Light beneath every enemy it hits.", replacement="copper_shod_staff")
relic("moonless_compass", "Moonless Compass", EP, "cut", "Amplify", ["radiance", "movement"], 0, 1,
      "", "", "", [], "Once per combat, two card types in one turn: a checklist, not a build.",
      was="Once per combat, playing separate movement and Light cards in one turn grants 6 Stoneskin and 2 card plays.", replacement="echoing_blade")
relic("witchglass_lantern", "Witchglass Lantern", EP, "cut", "Amplify", ["illusion", "radiance"], 0, 1,
      "", "", "", [], "Duplicates the Witchlight skill and Eclipse Mantle's Light aura.",
      was="Your illusions have +2 Light radius while they last.", replacement="hollow_puppet")
relic("glowstone_matrix", "Glowstone Matrix", C, "cut", "Amplify", ["earth", "radiance"], 0, 1,
      "", "", "", [], "Vision on Stoneskin cards joins two unrelated packages for no reason.",
      was="Cards that grant Stoneskin also grant Vision 1 for 2 turns.", replacement="grave_dirt")
relic("hollow_die", "Open-Eyed Pin", C, "cut", "Amplify", ["radiance"], 0, 1,
      "", "", "", [], "Light when you gain Vision; Vision cards already light the board.",
      was="When a card grants Vision or Truesight, create radius-1 Light at you for its duration.", replacement="tallow_candle")
relic("dawnbrand_filament", "Dawnbrand Filament", C, "cut", "Amplify", ["radiance"], 0, 1,
      "", "", "", [], "Repeats the Dawnbrand skill.",
      was="The first direct attack each turn creates radius-1 Light at its target for 2 turns.", replacement="fencers_gloves")
relic("mossbound_wraps", "Mossbound Wraps", C, "cut", "Amplify", ["earth"], 0, 1,
      "", "", "", [], "A first-Earth-card trigger for 3 Stoneskin. Grave Dirt and Rubblewalker Greaves do the job without the checklist.",
      was="The first Earth card you play while you have Block each turn grants 3 Stoneskin.", replacement="rubblewalker_greaves")
relic("ion_spool", "Ion Spool", C, "cut", "Amplify", ["lightning"], 0, 1,
      "", "", "", [], "Draw 1 on a conduction count. Grounding Pin changes how you aim instead.",
      was="The first Lightning attack each turn that conducts through 2+ tiles draws 1.", replacement="grounding_pin")
relic("cinderbrand_tongs", "Cinderbrand Tongs", C, "cut", "Amplify", ["fire", "radiance"], 0, 1,
      "", "", "", [], "Light from new Fire. Fire decks want fuel and payoffs, not Light.",
      was="Your first card each turn to create new Fire also creates radius-1 Light at its target.", replacement="pitch_gloves")

# ============================================================================ BUILDS
# How relics combine with card packages. Every reference is validated.

BUILDS = [
    {"name": "Wrecking Yard", "packages": ["forced", "earth"],
     "pitch": "Raise outcrops, shove enemies into them, and make every collision leave Rubble that makes the next one hurt more.",
     "cards": ["updraft", "crosswind", "unsealed_gale", "shield_charge", "earthen_rampart", "geode"],
     "relics": ["millstone_fob", "masons_plumb", "venom_signet", "battering_yoke", "siege_ram_totem", "breaking_wheel", "galehook_talon"],
     "line": "Earthen Rampart walls the lane. Updraft drives an Ash Hound straight into it: 4 collision damage, 6 with Mason's Plumb, and the wall takes none. Siege Ram Totem Staggers it 6. Millstone Fob leaves Rubble under it, so Quarry Signet adds 1 to everything that hits it next."},
    {"name": "The Late Bell", "packages": ["tempo"],
     "pitch": "Push enemies down the turn clock, act twice before they do, and punish everyone left waiting.",
     "cards": ["crushing_blow", "overhead_smash", "tremor", "clockwork_mark", "static_rush", "stolen_moment"],
     "relics": ["leaden_pommel", "pendulum_weight", "toll_late_bell", "pocket_sundial", "hourglass_splinter", "borrowed_hourglass"],
     "line": "Overhead Smash (7 Time) Staggers 1 through Leaden Pommel and Quickens 2 through Hourglass Splinter. Crushing Blow then costs 3 instead of 5 and Staggers 4. Both targets now act after your next turn, so Toll of the Late Bell adds 3 to every hit on them."},
    {"name": "Hall of Glass", "packages": ["illusion"],
     "pitch": "Fill the room with decoys that bite, explode, swap with you and shoot back.",
     "cards": ["hall_of_mirrors", "mirror_feint", "straw_double", "doppelganger", "reflected_threat", "empty_husk"],
     "relics": ["waxen_effigy", "mirror_shard", "changelings_rattle", "widow_thread", "hollow_puppet", "glassway_compass", "mirror_triptych"],
     "line": "Hall of Mirrors rings you in glass. Each illusion an enemy breaks shatters for 3 and Staggers its killer. Hollow Puppet throws the survivors, and Mirror Triptych echoes your first attack from three of them."},
    {"name": "Vigil of Ash", "packages": ["rites"],
     "pitch": "Open with a Rite every combat, play them for free, and let every Exhaust leave armour.",
     "cards": ["rite_of_the_pyre", "rite_of_the_mountain", "rite_of_hoarfrost", "salamander_heart", "phoenix_cleave", "borrowed_spark"],
     "relics": ["reliquary_box", "ashen_phylactery", "rosary_of_vows", "liturgy_of_ash", "pyre_keepers_urn"],
     "line": "Reliquary Box puts Rite of the Mountain in the opening hand; it costs no play under Liturgy of Ash. Ashen Phylactery turns it into 4 Stoneskin. Each turn after, Rosary of Vows adds 2 Block per Rite."},
    {"name": "Thornwall", "packages": ["block"],
     "pitch": "Hold Block between turns and turn every enemy swing into damage and more Block.",
     "cards": ["deflect", "riposte_lunge", "bristle", "undertaker_stand", "brace", "shield_wall"],
     "relics": ["iron_buckler", "coffin_nails", "briar_vambrace", "martyrs_gorget", "reinforced_shield", "obsidian_heart", "briar_throne"],
     "line": "Shield Wall plus Briar Vambrace: 9 Block and Retaliate 1. Iron Buckler keeps 3 of it. A Crawler bites into the wall: it Bleeds from Coffin Nails, takes the thorns, and Martyr's Gorget hands the damage back as Block."},
    {"name": "Bloodprice", "packages": ["blood", "empower"],
     "pitch": "Pay health and Empower on purpose, and cash every point in for damage.",
     "cards": ["bloody_lunge", "royal_bramble", "reprise", "glassbone_guard", "phoenix_cleave", "overclock"],
     "relics": ["iron_lung", "bloodmoon_chalice", "bloodglass_knife", "overclock_coil", "crown_of_surplus", "phoenix_ember"],
     "line": "Royal Bramble Empowered for 1 health: Bloodmoon Chalice adds 2 to the next attack and Overclock Coil Quickens 2. When health runs low, Iron Lung pays the next cost in Stoneskin instead."},
    {"name": "Duelist's Step", "packages": ["movement", "followup"],
     "pitch": "Move first, then let both of your cards hit as Follow-ups.",
     "cards": ["quick_stab", "main_gauche", "palm_strike", "flowing_step", "kestrel_dive", "headlong"],
     "relics": ["duelist_whetstone", "fencers_gloves", "feint_ribbon", "gale_tabi", "vaulting_sigil", "echoing_blade", "whirling_sash"],
     "line": "Walk 2 tiles, and Feint Ribbon makes Quick Stab a Follow-up on card one. Echoing Blade makes Main-Gauche cheaper and 2 stronger. Whirling Sash adds a third card."},
    {"name": "Prism", "packages": ["gear", "fire", "ice", "lightning", "earth"],
     "pitch": "Mix schools on purpose: alternate elements, overwrite surfaces, and store them for one big release.",
     "cards": ["kindle", "frost_lane", "spark_dart", "quarry_step", "magma_vent", "rime_hack"],
     "relics": ["chorus_mask", "bonded_set", "flint_edge", "overflow_censer", "black_sun_dial", "fivefold_knot", "coalheart_crucible"],
     "line": "Frost Lane laid over Kindle's Fire overflows Ice onto the neighbours. Flint Edge spends Fire under one target and Ice under another; Black Sun Dial stores both and releases 4 damage plus Fire and Chill on the next hit."},
    {"name": "Quartermaster", "packages": ["items"],
     "pitch": "Carry a full belt of items and use them as free, oversized, permanent actions.",
     "cards": ["powder_keg", "throwing_net", "lamp_oil", "caltrops", "crimson_draught", "thunderstone"],
     "relics": ["quick_draw_bandolier", "alchemists_retort", "quartermasters_ledger"],
     "line": "Quick-Draw Bandolier makes Throwing Net a free action. Alchemist's Retort makes Powder Keg's blast 9. Quartermaster's Ledger means they're back next fight."},
]
