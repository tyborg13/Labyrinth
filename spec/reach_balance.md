# Short attack reach and purposeful approach

Content revision: `short_reach_v1`, September 10, 2026. This is the first playable
candidate of the approved reach proposal. It changes reach and enemy positioning,
with human inspection still required before publication.

## Contract

Ordinary enemy direct threat is normally 2–3 tiles, with a ceiling of 4 for
specified approaches and lane attacks. Count movement before an attack plus its
Manhattan range and pattern extent. Retreat is not approach. Boss mechanics,
electrical networks, Chain relays, and Fire-powered Detonate retain their authored
extensions; there is no global runtime range clamp.

Most mobile enemies have a move-3 approach carrying only weak neutral melee 1.
Ooze, Bloomer and Gaoler are slower anchors with move-2 repositioning. Warden
retains its slow movement and global group guard. Surgeon retains move-1 support
and move-2 melee. HP, base initiative, existing intent Time, room generation,
objectives, rewards, fatigue and player damage/Time are unchanged.

The player retains two independent movement tiles without a card or Time cost.
Ordinary pokes and rich utility attacks use range 2, dedicated shots use range 3,
and Stormstring Shot/Hush of Winter retain explicit range-4 identities. Targeted
AOE centers use range 2–3; preserve pattern shapes and inspect the affected union.
Offensive movement is 1–2, except Iron Wheel's move-3 charge. Pure movement is 2–3;
Trapdoor and exhausting Voidsilk Molt retain premium blink 4. Illusion and surface
placement stays within 2–3. True North adds one ranged range during Truesight.
Sunpath/Gale Tabi's 3+ movement triggers remain attainable.

Light radii, vision bonuses, visibility, hidden identities, Umbra progression and
all warning behavior are unchanged. Hidden attacks and emerge-then-hit remain
possible. Meta progression that attaches Light, vision, partial hints or warnings
to existing actions is a separate future design, not part of this revision.

## Enemy intent decisions

| Enemy | Signature / short actions | Approach / positioning |
| --- | --- | --- |
| Crawler | Skitter 2 + melee 1, damage 4 + Bleed 1 | Lunge 3 + melee 1, damage 3 without Bleed; Coil unchanged |
| Acolyte | Dust Bolt stationary range 3; Siphon 1 + range 2 and existing heal | Dust Advance 3 + melee 1, damage 2, Time 4; Ward move 1 |
| Harrier | Pelt range 3 with Pierce/Bleed; Darting Pelt 1 + range 2 | Rush 3 + melee 1, damage 3; retreat 2 unchanged |
| Warden | March 1 + melee 1; Crushing Step 2 + adjacent cross | Existing slow protector; global Bulwark retained |
| Ooze | Slide 1 + melee 1; adjacent Fire cross | New attackless Ooze Advance 2, Time 5; Slag Shell/fuel untouched |
| Bloomer | Burst 1 + radius-2 pattern; stationary Shard Mark range 3 | New attackless Shale Advance 2, Time 5; shell/fuel untouched |
| Gaoler | Reel range 3, pull 2; Pin range 3; Cudgel 1 + melee 1 | Iron Guard moves 2, retaining its block |
| Surgeon | Jab 2 + melee 1; support radius 3 | Moves 1 toward an injured ally outside range; holds a legal heal; healthy last Surgeon pursues |
| Lancer | Glass Lunge 1 + three-tile ray; both shots range 3 | Spear Advance 3 + melee 1, neutral damage 2, Time 4; retreat 1 |
| Wisp | Static Lash 1 + range 2; Capacitor Arc retreat 1 + range 2 | Spark Dart 3 + melee 1, neutral damage 2: no conduction |
| Droplet | Existing 2 + melee 1 | Unchanged |
| Veilbound Acolyte | Needle range 2; existing 2 + melee 1 | Existing retreat 2; preferred range 2 |

Approaches are marked `purpose: approach`. When a useful signature attack can
connect, tactical selection excludes approaches. Otherwise a useful approach
gets decisive priority, including when its optional melee cannot reach yet.
This chooses only the next revealed intent; it never substitutes a signature
attack after an approach moves. Attackless advance plans to the role's preferred
range and a legal firing lane rather than always seeking melee adjacency.

Support approach evaluates actual navigable healing anchors, preferring safe,
short routes. It never moves toward the player merely because an ally is distant.
When no ally remains, a healthy Surgeon uses frontliner selection so cleanup
cannot become endless self-guard. Injured support retains its healing priorities.

The tactical threat-distance constant stays 5: the player still has movement 2
plus a specialist shot 3. The close-distance constant stays 2 for adjacent pressure
and retreat choice. Neither constant defines enemy attack legality.

## Cards, scoring and compatibility

The full source-aware field and score audit is
[card-audit.json](proofs/reach-rebalance/card-audit.json). It includes starting,
reward, equipment and item membership, old/new fields and old/new complete scores.
All printed descriptions were updated with the numeric data. Existing action
icons and cards render values from live definitions; the card frame/role texture
cache does not bake these numbers and requires no regeneration. No new icon
identity or art was introduced.

[The heuristic](card_balance_heuristic.md) and Python scorer now distinguish ranges
1/2/3/4 rather than assigning them one factor. The committed legal-action sample
covers 48 rooms, six elements, depths 1/3/9/19, and separate Clear/Deep/Heart
cohorts. These are structural availability anchors, not empirical hit rates.
Melee factors remain a conservative commitment/routing discount; no automatic
damage or Time compensation was added.

Saved visible intents and paid checkpoints remain verbatim until the next normal
selection; current cards load immediately. The transition is explicitly marked
and reported in analytics. See [save compatibility](save_persistence.md) and
[analytics](analytics.md). This preserves previews, commitment, paid surface
bonuses and the exact saved action boundary without resetting a fight.

## Evidence and inspection

[Verification and playtests](proofs/reach-rebalance/verification.md) records the
actual commands, paired outcomes, pursuit limits and real-renderer proof. Do not
interpret one greedy policy's survival as a human win rate. Perfect move/pass
kiting can avoid isolated mobile enemies on an empty board; clutter changes that,
and the mixed mobile squad defeats that policy. The two-tile player pool remains
the approved reference rather than being reduced to compensate.

Remaining human balance questions include melee exposure, expensive-card cadence,
AOE clustering, support attrition, late Umbra and progression-equipped boss fights.
The candidate is intended for the user's playable worktree inspection.
