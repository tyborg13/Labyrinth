# Gloam Stalker (`gloam_stalker`)

sta-01 supersedes the Veiled portions of en-03 (owner approved
`enemy-mechanics-audit`, 2026-10-30). HP 11, initiative 10, reward 10 Embers,
Fade/Slash weights and all Time values are unchanged.

1. Fade Blinks up to 4 to the free adjacent tile behind the hero's last
   voluntary movement direction this round. Without a recorded direction it
   uses the opposite of the hero-to-stalker start direction. The nearest free
   adjacent alternative uses existing stable cardinal ordering. With no legal
   destination in range, it stays. Immobilize still blocks the Blink.
2. `next_intent` forces Ambush for 7 with its existing telegraph, melee, re-Blink
   when needed, and impossible-strike fallback to Slash. Slash remains Move 2
   and melee 4. Shock and Freeze retain existing activation restrictions.
3. Fade grants no status. During the wind-up the Stalker is targetable normally,
   draws normally, and has no Veiled badge, rim, wisps, or faded body. Ordinary
   attacks can kill it. Tooltip: “Fade: Blinks behind you. Next turn it Ambushes.”
4. Legacy saves discard `veiled` and convert `ends_veil` to the retained Ambush
   positioning marker, preserving held intent identity, Time and damage.
   Hero movement direction still persists and restores with Undo.

Umbra concealment and the shadow Warband's Prior order remain independent:
`scripts/enemy_mechanics/veil.gd` retains only their visibility helpers.
Positioning and Blink presentation live in `stalker.gd` and `stalker_view.gd`.
The Veil glossary, Grimoire keyword and icon registry identity are retired.

Authored repeat comparison remains Fade 15, Ambush 15, Slash 14, or 14.75 per
activation including forced follow-ups. Counterplay uses normal movement,
blocking and attacks. Intrinsic player-card coefficients do not change.

Existing approved art, portraits and production cutout bytes are unchanged:
`assets/art/enemies/gloam_stalker.png` and
`assets/art/portraits/gloam_stalker.png`. No new assets or encounter changes.
Focused proof: `tests/sta01_mechanics_test.gd`, the retained en-03 suite and
`tests/sta01_enemies_probe.gd` (1920×1080, 100% UI scale).
