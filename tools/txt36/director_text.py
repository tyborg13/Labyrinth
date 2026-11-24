"""txt-36 director text: Grimoire pages for the 26 creatures that had none.

The owner approved grimoire-bestiary on 2026-11-24 with no notes; that approval covered writing the missing pages.
Same form as txt-34: [what it is, how it fights], prose rather than rules text, with no move lists. The game builds
the move table, traits and battlefield rule under the prose from data. Lore direction (owner 2026-11-24): the
Labyrinth is Noctyrax's prison, its sibling dragons are worshipped as gods in the world above, and every creature
here is its making. Use hints only, never the whole story.

Run once from the worktree root: python3 tools/txt36/director_text.py
It appends one entry per creature to data/grimoire.json in the order below, and refuses to run if any entry
already exists.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "data" / "grimoire.json"
ENEMIES = ROOT / "data" / "enemies.json"

# Order: commons by element (fire, ice, lightning, air, earth, shadow), then the six Guardians.
LORE = {
    # Fire
    "ember_tick": [
        "A tick swollen on the heat of the furnace halls. Fire shows through the cracks in its shell.",
        "It scuttles in to bite. When it dies it Bursts, hurting every unit beside it and leaving Fire, and Kindle makes that Burst stronger.",
    ],
    "ember_hoarder": [
        "An Ember Tick that has gorged on the Labyrinth's Embers until it can barely run. It sits on its hoard with a brood of Ember Ticks around it.",
        "It keeps its distance and scurries away from you, and Kindle makes the Burst it leaves when it dies stronger. If you don't catch it in time, it slips away with its hoard.",
    ],
    "slag_mortar": [
        "A squat brute with a furnace bowl strapped to its back, made to shell the halls of the Cinder Crown. It throws its slag without looking where it lands.",
        "It lobs slag that Marks a cross of tiles on you, then lands on its next turn and leaves Fire. It also braces behind Block and fires scattered slag that knocks you back.",
    ],
    "ash_hound": [
        "A lean, scorched hound bred to run with the Ashen Reaver. Its hide still smoulders.",
        "Ash Hounds run fast and bite, and their Flanking Bite knocks you back a tile.",
    ],
    # Ice
    "hoarfrost_seer": [
        "A hooded hermit who came north looking for Iskaldra's winter and never left the Rime Hall. It reads the frost the way others read the stars.",
        "It marks the ground at your feet for Icefall, which lands on its next turn and leaves Ice, and its bolts Stagger anyone standing on Ice. It also falls back behind Block.",
    ],
    "glacial_mirror": [
        "A walking slab of glacier ice with a pane of clear crystal set in its chest. You can see yourself in it, a little colder than you are.",
        "Its Reflect sends attacks made from a distance back at you. It grinds forward slowly, throws a line of refracted cold that Pierces Block and Staggers anyone on Ice, and shields the ally beside it, or itself, with Block.",
    ],
    "rime_whelp": [
        "A young Rimejaw that has not grown its full spines. Whelps follow the Rimejaw on its hunts.",
        "It closes fast to bite, and its snapping jaws Stagger anyone standing on Ice.",
    ],
    "rime_spitter": [
        "A squat, pale toad with a throat full of frost. Iskaldra keeps them the way a lord keeps hounds.",
        "It spits a needle of ice down a line that leaves Ice at the far end, and its frost spit Staggers anyone standing on Ice.",
    ],
    # Lightning
    "arc_thrall": [
        "A hulking servant of the Tempest Spire, with an iron collar at its throat and a rod full of lightning in its fist. It has worn that collar so long it has forgotten it is there.",
        "It hurls bolts from its rod that leave the ground Electrified, and up close its jab Shocks you.",
    ],
    "storm_capacitor": [
        "A jar of storm bound in iron and set into the floor of the Tempest Spire. Something inside it keeps trying to get out.",
        "It never moves. It builds Charge, and at 3 Charge it unleashes Arc Lash, which leaps from unit to unit. Shock drains its Charge.",
    ],
    "bell_tender": [
        "A hooded bell-ringer of the Broken Choir, masked in brass. It carries the choir's song out across the floor.",
        "It links tiles into Electrified ground for the storm to strike, and fires bolts from its staff.",
    ],
    # Air
    "gale_herald": [
        "A herald wrapped in wind-torn banners, still sounding Vaeloryx's call through the Hollow Gale.",
        "It blows its horn to call the wind, fires bolts of wind that knock you back, and stills the air around itself for Block.",
    ],
    "gust_shrike": [
        "A small, quick hawk of the Hollow Gale. Vaeloryx's wings throw them off like sparks.",
        "It dives in from far off and hits you anywhere along its path, knocking you back. It also rakes with its talons and hovers out of reach behind Block.",
    ],
    "roc_fledgling": [
        "A young Gallows Roc, not yet grown into its wings. It follows the Roc out of the Hanging Roost to fight.",
        "It darts in close and pecks at you.",
    ],
    # Earth
    "burrow_grub": [
        "A blind grub as thick as a man, chewing tunnels through the Worldspine Roots. Tharokh's roots are full of them.",
        "It burrows under the floor and marks the tile under you, then erupts there on its next turn, throwing up Rubble and leaving itself Exposed. Above ground, it gnaws.",
    ],
    "briar_weaver": [
        "A hunched knot of living roots and thorns, grown out of the Worldspine Roots. It tends the Labyrinth's stone the way a gardener tends a hedge.",
        "It Marks lines of floor that later heave up into Outcrops, lashes you with thorns from range and heals its most wounded ally nearby.",
    ],
    "stoneback_mite": [
        "A stone-shelled mite that lives among the Craghide's plates and follows it out to fight.",
        "It claws at you, and its Driving Claw shoves you back while it braces behind a little Block.",
    ],
    # Shadow
    "gloam_stalker": [
        "A hooded thing with sickles for hands that lives in the Umbra's deepest dark. You rarely see it before it is behind you.",
        "It Fades into the dark and reappears behind you, then strikes from Ambush on its next turn. Otherwise it closes in and slashes.",
    ],
    "hollow_mimic": [
        "A shadow that has taken on your shape, down to the hair and the armor. The dark down here learns from everyone who walks in it.",
        "It fires bolts of shadow from range. After its Echo, it hits back whenever you strike it up close, until its next turn. It also falls back out of reach.",
    ],
    "wick_shade": [
        "What is left of someone who lost their way in the dark: a hooded shape with one cold light where a face should be. The Last Lamplighter calls them out of the flames it snuffs.",
        "It drifts toward you and grasps at you to drag you closer. In Last Light, it puts out the braziers you keep lit.",
    ],
    # Guardians
    "ashen_reaver": [
        "An executioner in blackened plate, made to hold the Cinder Yard on the road to Vyraketh. Its falchion still glows from a forge no one has lit in an age.",
        "The Reaver rakes the ground with lines of Fire and sweeps its falchion across the tiles in front of it, and its heaviest blow leaves it Exposed. Wildfire spreads its flames toward you every other turn.",
    ],
    "rimejaw": [
        "A long, pale beast with a bare skull for a face and spines of ice down its back. It hunts the Broken Rime on the road to Iskaldra.",
        "It leaves Ice in its tracks and pounces from a distance, and its heavier bites Stagger anyone standing on Ice. Frostbite Staggers each unit on Ice after each of your turns.",
    ],
    "storm_cantor": [
        "A gilded figure that leads the Broken Choir on the road to Zekarion. It sings the hymns people above still sing to the storm, and down here the storm answers.",
        "The Cantor lays chains of Electrified ground across the room, then its Peal strikes everyone standing on that ground. Up close it brings its staff down hard, and it calls Lightning Wisps to its side.",
    ],
    "gallows_roc": [
        "A vulture the size of a cart, with charms and gallows rope tangled in its feathers. It nests in the Hanging Roost on the road to Vaeloryx.",
        "It hooks you from afar and drags you closer, beats its razor wings to throw you back, and dives on you from above. After each of your turns, its Gust blows across the room.",
    ],
    "craghide": [
        "A bear grown over with plates of rock, sleeping off the centuries in the Shattered Burrow on the road to Tharokh. It does not like to be woken.",
        "Every other turn, it heaves Marked floor up into Outcrops. It cracks the ground around that stone to hurt you if you stand near it, and charges in for a crushing blow.",
    ],
    "last_lamplighter": [
        "The last keeper of the Labyrinth's braziers, still making its rounds at the Last Watch on the road to Noctyrax. Every flame it snuffs leaves the dark a little deeper.",
        "It snuffs braziers and calls up a Wick Shade when none is left, hooks you closer with its lantern chain and walks its Last Procession in to strike. After each of your turns, hidden Wick Shades step toward you through the dark.",
    ],
}


def main() -> None:
    data = json.loads(PATH.read_text())
    enemies = json.loads(ENEMIES.read_text())
    existing = {str(entry.get("id", "")) for entry in data["entries"]}
    for enemy_id in LORE:
        if enemy_id not in enemies:
            raise SystemExit(f"unknown enemy id {enemy_id}")
        if "enemy:" + enemy_id in existing:
            raise SystemExit(f"enemy:{enemy_id} already has a page")
    for enemy_id, lore in LORE.items():
        data["entries"].append({
            "id": "enemy:" + enemy_id,
            "section": "creatures",
            "enemy_id": enemy_id,
            "title": str(enemies[enemy_id]["name"]),
            "lore": lore,
        })
    PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"added {len(LORE)} creature pages")


if __name__ == "__main__":
    main()
