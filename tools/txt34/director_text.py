"""txt-34 director text: creature lore and plain rules lines for the Grimoire.

Owner feedback 2026-11-24 (grimoire-truth-txt32, NEEDS CHANGES): a creature page should
say what the creature is and how it fights in broad terms, like any bestiary, with
the moves in a table below. The table is built from data by the game, so the prose
never lists moves. Run once from the worktree root: python3 tools/txt34/director_text.py
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PATH = ROOT / "data" / "grimoire.json"

# Each creature: [what it is, how it fights]. Paragraph 1 hints at the owner's lore direction
# (2026-11-24): the Labyrinth is Noctyrax's prison, its sibling dragons rule the world above as gods,
# and every creature here is its making. Hints only, never the whole story. Prose, not rules text: the move table
# below it carries the exact rules.
LORE = {
    "enemy:crawler": [
        "A hairless, milk-eyed thing bred in the dark beneath the Labyrinth. It hunts by the tremor of footsteps on stone.",
        "It scuttles straight at you and rakes with its claws, or curls up behind its thick hide.",
    ],
    "enemy:acolyte": [
        "A robed skeleton still keeping the rites of an order that once knelt to the dragons. The orb in its hand is packed with the dust of the dead.",
        "It prefers to fight from a distance, hurling bolts of grave dust, warding itself with Block and mending its own bones.",
    ],
    "enemy:harrier": [
        "The bones of a hunter who came into the Labyrinth and never left. The dark stood it back up, spear and all.",
        "It harries you with its spear from range, and its hardest throws punch through Block. It skips back out of reach, or rushes in to stab.",
    ],
    "enemy:warden": [
        "A dead knight raised to guard these halls. It no longer remembers whose watch it keeps, only that no one may leave.",
        "It marches in behind its shield and swings a spiked mace, or stamps down to hit everything beside it. It can also give Block to each other enemy.",
    ],
    "enemy:cinder_ooze": [
        "Slag that crawls the Labyrinth's furnace halls, shaped in the likeness of a fire it has never seen. A cracked crust holds in a core that never cools.",
        "It oozes after you and leaves Fire wherever it strikes, and it soaks up nearby flames to harden its crust. When it dies, it can split into two Cinder Droplets.",
    ],
    "enemy:cinder_droplet": [
        "A burning gobbet of slag, thrown off when a Cinder Ooze dies. It is small, quick and just as hot.",
        "It darts in to spatter you and leaves Fire on your tile, then hisses back behind a thin crust of Block.",
    ],
    "enemy:bile_bloomer": [
        "A flower of living stone, grown where no light has ever reached. Its petals are slate, and its seeds are shards.",
        "It bursts in a spray of flying stone that leaves Rubble around it, and flicks shards that make the next hit on you land harder. It grows Stoneskin, and Rubble beside it makes that skin thicker.",
    ],
    "enemy:chainbound_gaoler": [
        "The Labyrinth's jailer, still walking the rounds of cells no one has left in centuries. It carries a hook on a length of chain for new prisoners.",
        "It hooks you with its chain and drags you in, shackles you in place and batters you up close. It also hides behind Block.",
    ],
    "enemy:grave_surgeon": [
        "A plague doctor's coat with something patient inside it. It stitches up the Labyrinth's dead and sends them back to fight.",
        "It hangs back to heal the other enemies and brace them with Block, and the bracing clears Fire, Ice or Electrified from under them. Up close, it cuts at you with a serrated saw.",
    ],
    "enemy:frostglass_lancer": [
        "Ice given the shape of a knight and set to stand watch in the Rime Hall. Its spear is a single shard of glacier ice.",
        "It drives its spear through a line of tiles and leaves Ice behind, or throws it from range, and its hardest strikes Stagger anyone standing on Ice. It also falls back behind a guard of Block.",
    ],
    "enemy:lightning_wisp": [
        "A scrap of thundercloud given a will of its own. Zekarion calls Wisps down to fight for it.",
        "It zips in to sting, charges the ground beneath it with Electrified, and fires arcs that leap along Electrified ground and Shock whoever they reach there.",
    ],
    "enemy:veilbound_acolyte": [
        "An acolyte who walked into the Umbra and came back wearing it. It serves Noctyrax at the heart of the dark.",
        "It pricks you with needles of shadow from a short distance, then slips away again.",
    ],
    "enemy:zekarion": [
        "The storm dragon of the Tempest Spire. Lightning crawls over its scales, and the air around it never settles. In the world outside, people pray to it for rain and curse it for the floods.",
        "Zekarion scatters lightning across the floor and leaves that ground Electrified, then uses Overload to strike everyone standing on it. Between storms, it lashes you with lightning and calls Lightning Wisps to its side.",
    ],
    "enemy:tharokh": [
        "An earth dragon so old that the Worldspine Roots grew around it. Its scales are slabs of bedrock. Outside these walls, kings are crowned on stones said to be its shed scales.",
        "Tharokh sends lines of breaking stone across the room, breathes a wave of Rubble and rakes anything in reach of its claws. Upheaval raises Outcrops from the ground it Marks, and Burrow Grubs fight at its side.",
    ],
    "enemy:vyraketh": [
        "The fire dragon that rules the Cinder Crown. Its scales glow like banked coals. Every hearth in the world above is lit in its name.",
        "Vyraketh rains cinders that Mark the floor and set it burning, breathes flame and bites hard up close. Wildfire spreads its fires to the tiles around them, Crownfire sets off its Marked fires at once, and Cinder Droplets fight at its side.",
    ],
    "enemy:vaeloryx": [
        "The wind dragon of the Hollow Gale, pale as cloud. Its wings never stop moving. Sailors far from here still pour out wine to it before they leave port.",
        "Vaeloryx hooks you from afar and drags you in, dives through anything in its path, and whips up wind that throws back everyone near it. Its Gust shoves units downwind after each of its turns, and Gust Shrikes fly at its side.",
    ],
    "enemy:iskaldra": [
        "The ice dragon of the Rime Hall, armored in crystal that grows back as fast as it breaks. The north keeps its winters long in Iskaldra's honor.",
        "Iskaldra wraps itself in layers of Crystal Mantle, lances the floor with Ice and claws at close range. Each layer widens Shatterstorm, Frostbite hurts each unit standing on Ice, and Rime Spitters fight at its side.",
    ],
    "enemy:noctyrax": [
        "The dragon at the heart of the Umbra. Its kin wear crowns in the world above. These walls, and everything that walks between them, are its making.",
        "Noctyrax drags you closer with coils of night that snuff out braziers, rakes with its claws and breathes darkness that ignores Block. Its Last Eclipse strikes Marked ground and then swallows the room in dark, and Veilbound Acolytes rise to fight beside it.",
    ],
}

# Rules articles: plain wording, no one-off details (the previews and the creature
# pages carry those). Each value replaces that entry's whole body.
BODIES = {
    "basic:map": [
        "Revealed exits show where you can travel next. Rooms you leave are sealed behind you.",
        None,  # keep this paragraph
    ],
    "combat:defiance": [
        "Each Defiance charge saves you from 1 lethal hit and leaves you at 25% of your maximum Health, rounded up.",
        None,  # keep this paragraph
    ],
    "combat:targeting": [
        "Attacks need a visible target within Range. Ranged attacks also need line of sight. A card that ignores Range or line of sight says so.",
        None,  # keep this paragraph
    ],
    "combat:fatigue": [
        None,  # keep this paragraph
        "Each Fatigue in a combat costs 1 more Health than the last. Fatigue bypasses Block. Draw and Pass previews show the Health that Fatigue costs.",
    ],
    "keyword:card_play": [
        None,  # keep this paragraph
        "Each enemy summon gives you 1 more Card Play next turn. Killing a summoned enemy gives none.",
    ],
    "combat:cinder_marks": [
        None,  # keep this paragraph
        "Crownfire Bursts each of Vyraketh's Marked Fire tiles, then Vyraketh moves toward you and attacks. The Meteorfall card Marks tiles. At the start of your next turn, each unit on a Marked tile takes damage, and each Marked tile becomes Fire.",
    ],
    "combat:crystal_armor": [
        None,  # keep this paragraph
        "Each layer extends Iskaldra's Shatterstorm by 1 tile, and Shatterstorm breaks the remaining layers. Crystal Mantle cards give you layers that last until broken or combat ends.",
    ],
    "combat:boss_eclipse": [
        None,  # keep this paragraph
        "Night Coil puts out the nearest brazier. Walk or Blink onto a dark brazier's tile to relight that brazier. Light blocks Eclipse's darkness.",
    ],
}

def main() -> None:
    data = json.loads(PATH.read_text(encoding="utf-8"))
    seen = set()
    for entry in data["entries"]:
        entry_id = entry["id"]
        if entry_id in LORE:
            entry.pop("body", None)
            entry["lore"] = LORE[entry_id]
            seen.add(entry_id)
        if entry_id in BODIES:
            body = entry["body"]
            for index, text in enumerate(BODIES[entry_id]):
                if text is not None:
                    body[index] = text
            seen.add(entry_id)
    missing = (set(LORE) | set(BODIES)) - seen
    if missing:
        raise SystemExit(f"missing entries: {sorted(missing)}")
    PATH.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
