#!/usr/bin/env python3
"""Director's event catalog v2 (owner, playtest 18): no dice, more events, all open from the first section.
Writes the full catalog to the path given. Run from the repo root against the current data/events.json."""
import json, sys

d = json.load(open('data/events.json'))
ev = d['events']

def choice(id, label, effects, result, requires=None):
    c = {"id": id, "label": label, "effects": effects, "result": result}
    if requires: c["requires"] = requires
    return c

def hp(n): return {"type": "hp", "amount": n}
def embers(n): return {"type": "embers", "amount": n}
def omen(i): return {"type": "omen", "id": i}
def relic(r): return {"type": "relic", "rarity": r}
def gear(r, slot=None):
    e = {"type": "equipment", "rarity": r}
    if slot: e["slot"] = slot
    return e
def max_hp(n): return {"type": "max_hp", "amount": n}
def heal_pct(p): return {"type": "heal_percent", "percent": p}
def item(n=1): return {"type": "item", "count": n}
def need_hp(n): return [{"type": "hp_above", "amount": n}]
def need_max(n): return [{"type": "max_hp_above", "amount": n}]
def need_embers(n): return [{"type": "embers_at_least", "amount": n}]
LEAVE = lambda label="Leave": {"id": "leave", "label": label, "effects": []}

def replace(event, cid, new):
    choices = ev[event]["choices"]
    for i, c in enumerate(choices):
        if c["id"] == cid:
            choices[i] = new
            return
    raise KeyError((event, cid))

# ---- The eight dice events become fixed tradeoffs.
replace("bloodletters_basin", "reach", choice("reach", "Reach in", [hp(-2), relic("common")],
    "Something closes on your fingers, but not quite fast enough.", need_hp(2)))
ev["ossuary_gamblers"]["body"] = "Three skeletons crouch around an upturned shield, rattling knucklebones in a skull. The bones have no marks left on them. An empty place has been left in their circle, and they will play for whatever you put down."
replace("ossuary_gamblers", "wager_embers", choice("wager_embers", "Stake 50 Embers", [embers(-50), gear("rare")],
    "The bones always fall the same way. One of them slides a dented piece of kit across the shield and tucks your Embers into its ribcage.", need_embers(50)))
replace("ossuary_gamblers", "wager_blood", choice("wager_blood", "Stake a little of yourself", [max_hp(-2), relic("rare")],
    "You win something they had been keeping a long time. They clack approvingly at what you lost to get it.", need_max(6)))
replace("name_collector", "false", choice("false", "Give a false name", [embers(60), omen("hunted")],
    "It pays you anyway. A name is a name. Somewhere in the dark, something learns you lied."))
replace("mirror_of_skins", "shatter", choice("shatter", "Shatter the glass", [embers(70), omen("hunted")],
    "The silver backing is worth something to someone. The crash carries, and something answers it."))
replace("sealed_sarcophagus", "open", choice("open", "Push the lid open", [relic("rare"), omen("dread")],
    "The breathing stops. The treasure stays. Whatever was breathing has had a good look at you."))
replace("root_choked_vault", "squeeze", choice("squeeze", "Squeeze through the gap", [hp(-2), gear("common")],
    "You come out with something, and with most of your skin.", need_hp(2)))
replace("windcut_bridge", "run", choice("run", "Run across", [hp(-4), item(2), gear("common")],
    "You reach the pack before the wind reaches you. Most of you, anyway.", need_hp(4)))
replace("storm_obelisk", "grasp", choice("grasp", "Grasp it", [hp(-9), relic("epic")],
    "The storm passes through you and leaves something behind, along with the burn.", need_hp(9)))

# ---- Everything shared is legal from the first section.
for e in ev.values():
    if e["pool"] == "any":
        e["min_section"] = 0
        e["max_section"] = 5

def event(id, title, pool, body, choices, sections=(0, 5)):
    assert id not in ev, id
    assert len(body.split()) <= 70, id
    for c in choices:
        assert len(c["label"]) <= 28, c["label"]
    ev[id] = {"title": title, "pool": pool, "min_section": sections[0], "max_section": sections[1], "weight": 10, "body": body, "choices": choices}

# ---- New shared events.
event("toll_collector", "The Toll Collector", "any",
    "A hooded figure sits on a stool in the middle of the corridor, a lockbox between its knees. There is no bridge and no gate. It holds out one hand anyway.",
    [choice("pay", "Pay the toll", [embers(-40), omen("ember_ward")], "It stamps your wrist with something warm. The next few doors open easier.", need_embers(40)),
     choice("take", "Take the lockbox", [embers(90), omen("hunted")], "It doesn't stop you. It stands, folds the stool and follows at a distance.")])
event("drowned_chapel", "The Drowned Chapel", "any",
    "Black water fills the nave to your knees. At the altar, under the surface, a reliquary glows. The water is very cold and very still, and it remembers everyone who has stood in it.",
    [choice("wade", "Wade to the altar", [relic("rare"), omen("leaden_limbs")], "You come back with the reliquary. The cold comes back with you, and it stays in your legs."),
     choice("wash", "Wash your wounds", [heal_pct(30), omen("deepening_dark")], "The wounds close. The chapel is darker when you look up, and so is everywhere after it."),
     LEAVE()])
event("patient_surgeon", "The Patient Surgeon", "any",
    "A surgeon in a beaked mask has laid out his tools on a clean cloth. \"You look unwell,\" he says, \"and I am short of blood. I expect we can help each other.\" There is a chair. It has straps.",
    [choice("stitches", "Pay for stitches", [embers(-35), heal_pct(50)], "He is very good. You try not to think about where he practised.", need_embers(35)),
     choice("sell", "Sell him a pint", [hp(-5), embers(70)], "He counts out the Embers with wet fingers and thanks you for your patience.", need_hp(5)),
     LEAVE()])
event("twin_doors", "The Twin Doors", "any",
    "Two doors stand side by side in a wall that should not have any. One is warm to the touch. One is not. A note nailed between them reads ONE OF THESE IS A MISTAKE, in your own handwriting.",
    [choice("warm", "The warm door", [gear("rare"), omen("kindled")], "Behind it, a smithy on fire and a piece of gear left on the anvil. The heat follows you out."),
     choice("cold", "The cold door", [{"type": "card_choice", "count": 3, "element": "section", "min_rarity": "rare"}, omen("dread")], "Behind it, a study, frost on the pages, and a chair turned to face the door. You read quickly.")])
event("tinkers_cart", "The Tinker's Cart", "any",
    "A tinker's cart stands in the passage with no tinker anywhere near it. A painted sign says TAKE ONE, LEAVE ONE. The shelves hold other people's gear, some of it still warm.",
    [choice("trade", "Leave something, take one", [{"type": "lose_item"}, gear("rare")], "You put yours on the shelf and take the better one. It seems fair, and that worries you.", [{"type": "has_item"}]),
     choice("steal", "Just take one", [gear("common"), omen("hunted")], "You walk away quickly. Behind you, a wheel begins to turn."),
     LEAVE()])
event("candle_auction", "The Candle Auction", "any",
    "Hooded bidders sit in rows. An auctioneer holds up a lot you cannot quite see while a candle burns down on the lectern. You find a numbered paddle in your hand, and you do not remember taking it.",
    [choice("high", "Bid high", [embers(-90), relic("epic")], "Nobody bids against you. Nobody looks at you either, as you carry it out.", need_embers(90)),
     choice("low", "Bid low", [embers(-40), relic("common")], "The candle gutters out just in time. The room sighs, and you are handed a small parcel.", need_embers(40)),
     choice("sell", "Sell your paddle", [embers(25)], "The bidder beside you pays without turning its head. You did not see it take the paddle.")])
event("the_sleeper", "The Sleeper", "any",
    "Something the size of a house sleeps across the passage, ribs rising and falling like slow bellows. The way around will take hours. Its purse lies open on the floor, close enough to reach.",
    [choice("rob", "Cut its purse", [embers(80), omen("dread")], "It doesn't wake. One eye opens anyway, and it follows you all the way out."),
     choice("around", "Take the long way", [{"type": "reveal", "hops": 3}], "It takes hours. You learn a great deal about these halls, and nothing at all about what it was.")])
event("ash_confessional", "The Ash Confessional", "any",
    "A booth of charred wood stands alone in the dark. From behind the screen, a voice says, \"Tell me what you have done, and I will take it from you.\" It sounds as if it means it.",
    [choice("some", "Confess a little", [{"type": "transform_magic", "count": 1, "rarity_step": 0}, {"type": "heal", "amount": 8}], "You feel lighter. One of your spells no longer works quite the way you remember.", [{"type": "has_attuned_magic"}]),
     choice("all", "Confess everything", [{"type": "transform_magic", "count": 3, "rarity_step": 1}, max_hp(-4)], "It takes a long time. It takes a good deal more than you offered.", [{"type": "has_attuned_magic"}] + need_max(8)),
     LEAVE("Say nothing")])
event("last_expedition", "The Last Expedition", "any",
    "Another like you sits slumped against the wall, breathing wet and shallow. Their gear is better than yours. They look at it, then at you, and say nothing at all.",
    [choice("take", "Take their gear", [gear("rare"), omen("dread")], "They watch you do it. They are still watching when you look back from the end of the hall."),
     choice("stay", "Sit with them", [omen("quickened_blood")], "You stay until it is over. You leave with nothing in your hands, and you walk faster than you came.")])
event("hungry_door", "The Hungry Door", "any",
    "The door has a mouth where the lock should be. It is small and patient, and it has waited a long while. From beyond it comes the sound of coins settling.",
    [choice("item", "Feed it something", [{"type": "lose_item"}, relic("common"), embers(40)], "It swallows, considers and opens. You take what you can carry.", [{"type": "has_item"}]),
     choice("blood", "Feed it your blood", [hp(-6), embers(110)], "It drinks and drinks, then lets you in. The coins are warm.", need_hp(6)),
     LEAVE()])
event("ember_shaft", "The Ember Shaft", "any",
    "A shaft drops away into the dark with warm air rising from it. Far below, a bed of Embers pulses like something breathing. A frayed rope hangs down. It looks long enough.",
    [choice("climb", "Climb down", [hp(-5), embers(90)], "The rope holds until you are nearly back up. Your pockets are full, and you stop bleeding eventually.", need_hp(5)),
     choice("offer", "Throw one in", [embers(-20), omen("ember_tithe")], "It falls for a long time. Below, the bed brightens, and the dark seems to owe you something.", need_embers(20)),
     LEAVE()])
event("blind_scribe", "The Blind Scribe", "any",
    "An old scribe writes without ink in a book that is almost full. He turns his head as you come near. \"Yours is a short chapter,\" he says. \"I could make it longer, or I could make it better.\"",
    [choice("longer", "Make it longer", [max_hp(4), omen("deepening_dark")], "His pen scratches on. You feel sturdier, and the halls feel longer and darker for it."),
     choice("better", "Make it better", [{"type": "card_choice", "count": 3, "element": "any", "min_rarity": "rare"}, max_hp(-2)], "He crosses out a line and writes a finer one. You miss whatever was on it.", need_max(6))])

# ---- New element events.
event("quarry_mouth", "The Quarry's Mouth", "earth",
    "A quarry has been cut into the living rock, its tools abandoned mid-stroke. The stone at the face is warm and soft as bread. It closes slowly over anything left touching it.",
    [choice("dig", "Dig out the seam", [hp(-4), gear("rare", "armor")], "The stone grips your arms to the elbow before it gives up what it was keeping.", need_hp(4)),
     choice("press", "Press your skin to it", [omen("stone_vow"), max_hp(-2)], "It takes a thin layer of you, and leaves a thin layer of itself.", need_max(6)),
     LEAVE()], (0, 4))
event("kiln_of_names", "The Kiln of Names", "fire",
    "A kiln the height of a chapel burns with nobody tending it. Clay figures line its shelves, each with a face you nearly know. One of them is shaped like you, and it has not been fired.",
    [choice("fire", "Fire it", [max_hp(4), omen("kindled")], "You slide yourself into the heat and feel it set. You are harder now, and you run hot."),
     choice("smash", "Smash it", [hp(-3), {"type": "card_choice", "count": 3, "element": "fire", "min_rarity": "rare"}], "Something inside you cracks with it. Between the shards, the kiln has left you a choice.", need_hp(3)),
     LEAVE()], (0, 4))
event("howling_gallery", "The Howling Gallery", "air",
    "A long gallery of slit windows sings as the wind crosses it, every window a different note. Stop your ears and you can cross in peace. Listen, and the song tells you things you may not want.",
    [choice("listen", "Listen", [{"type": "card_choice", "count": 3, "element": "air", "min_rarity": "rare"}, omen("dread")], "By the far end you know the song, and it knows you."),
     choice("stop", "Stop your ears", [{"type": "reveal", "hops": 3}], "You cross in silence, counting the windows, and you see the routes beyond them plainly.")], (0, 4))
event("glass_lake", "The Glass Lake", "ice",
    "Beneath the ice a procession walks the lake bed, lanterns lit, faces upturned. One of them carries gear you would like very much. The ice is thin above it, and the procession has noticed you.",
    [choice("break", "Break the ice", [gear("rare"), omen("leaden_limbs")], "An arm comes up and hands it to you. The cold takes your legs for its trouble."),
     choice("bow", "Bow to them", [omen("lantern_sight")], "They bow back and raise their lanterns, and for a while you can see further than you should."),
     LEAVE()], (0, 4))
event("copper_saint", "The Copper Saint", "lightning",
    "A copper saint stands in a flooded crypt, arms raised, struck so many times that the metal has run like wax. Sparks walk the water toward your boots. Its halo looks loose.",
    [choice("halo", "Take the halo", [hp(-6), relic("rare")], "It comes away in your hand. So does most of the feeling in that hand, for a while.", need_hp(6)),
     choice("stand", "Stand in the water", [hp(-4), omen("quickened_blood")], "It finds you. When the ringing stops, your heart is going twice as fast.", need_hp(4)),
     LEAVE()], (0, 4))
event("last_hearth", "The Last Hearth", "shadow",
    "A hearth burns in the dark with nobody beside it, and for the first time in a long while you are warm. You could stay. Everyone here stayed, you realise, looking at the shapes around the fire.",
    [choice("warm", "Warm your hands", [heal_pct(50), omen("deepening_dark")], "It is the best you have felt in days. It is much darker when you finally stand."),
     choice("coal", "Take a coal", [{"type": "defiance", "amount": 1}, max_hp(-4)], "It burns through everything you wrap it in. You carry it anyway.", need_max(8)),
     LEAVE("Walk on")], (5, 5))

for k, e in ev.items():
    for c in e["choices"]:
        assert all(x["type"] != "random" for x in c.get("effects", [])), k
d["version"] = 2
out = sys.argv[1] if len(sys.argv) > 1 else "spec/peer_benchmark/staged/ev-03/events.json"
json.dump(d, open(out, "w"), indent=1, ensure_ascii=False)
open(out, "a").write("\n")
print("events", len(ev), "any", sum(1 for e in ev.values() if e["pool"] == "any"))
