# Relic Trigger Feasibility

This table is the balance gate for the July 2026 second-pass relic rework. It
uses the live card, equipment, skill, combat, room, and run data rather than
assuming a conventional deckbuilder economy.

## Live Constraints

- Normal section encounters contain 3, 4, then 5 enemies. Most bosses are one
  enemy; the Lightning and Shadow bosses begin with two adds.
- Standard combats target 3–5 player turns and bosses 6–9.
- The player starts with 24 health, a 5-card hand, two draws and two card plays
  per turn. The hand cap is 7. Every non-summoned kill grants one play that
  turn.
- Fatigue begins at 2 damage and grows on each reshuffle. Relic draws therefore
  stop before a reshuffle unless a rules effect explicitly says otherwise.
- The live pool contains 159 card definitions. Of those, 56 appear in reward
  pools, 14 are referenced by starter decks, and 88 are provided by equipment;
  these provenance groups can overlap. Relevant support counts are:

| Support | Count | Notes |
| --- | ---: | --- |
| Shock application | 8 | 7 accessible reward/equipment sources; 1 legacy definition |
| Freeze application | 9 | 8 accessible reward/equipment sources; 1 legacy definition |
| Burn application | 13 | Broad Fire and equipment support |
| Bleed application | 8 | 6 equipment sources; 2 legacy definitions |
| Block cards | 41 | Available across neutral, elemental, and equipment packages |
| Stoneskin cards | 15 | Also enabled by Carry the Guard and Thawing Charm |
| Move or Blink cards | 38 | 21 also attack; 17 do not attack |
| Printed Move or Blink 4+ | 12 | Includes starter Shadow Step |
| Printed Blink 3+ | 8 | Enough for a dedicated Blink package |
| Push or Pull cards | 15 | Only 5 also print Block, motivating state bridges |
| Air Push or Pull actions | 3 | Bounds Tailwind Fletching's deck density |
| Ranged Chain attacks | 7 | 6 accessible sources; 1 legacy definition |
| Light/Vision/Truesight/Umbra-dispel cards | 7 | Includes starter Lantern Shot |
| Health-cost cards | 9 | Includes starter Bloody Lunge |
| Earth cards | 12 | Enough to reach both progressive commitment caps |
| Intensity-gain cards (F/I/L/A/E) | 11 / 8 / 11 / 5 / 8 | Raw intensity; Confluence does not satisfy multi-element relic storage |
| Draw / card-play cards | 36 / 19 | Draw is abundant; card plays are the binding resource |

No card or skill additions are required for the revised triggers. Existing
starter, reward, equipment, and permanent-skill support already makes every
new line constructible.

## Trigger And Scaling Table

| Relic | Live enabling line and expected timing | Repeat / worst-case scaling | Decision |
| --- | --- | --- | --- |
| Thunder Relay (Epic) | One of 7 accessible Shock sources while raw Lightning is 2+. Status-intensity relics resolve before status conditions, so Ion Spool can establish the required state regardless of acquisition order. | Once per turn. Deals 3 to each enemy: 9/12/15 total in 3/4/5-enemy rooms, or 18/24/30 if every target is already Frozen. | Feasible recurring discharge; replaces the unrealistic third-Shock threshold and intentionally bridges Shock into Freeze. |
| Cold Mirror (Epic) | Any of 41 Block cards followed by one of 8 accessible Freeze cards; a single card may also establish Block before its Freeze action. | Once per turn; converts at most 6 Block, never creates defense from nothing and never heals. | A two-package state bridge with persistent upside. |
| Vaulting Sigil (Epic) | A resolved Move path or Blink displacement of four tiles. Twelve cards print Move/Blink 4+, including starter Shadow Step; obstacles can still shorten Move paths. | Once per turn; +1 play and 4 Block. A later Move or Blink that turn cannot retrigger it. | Four is demanding but routinely achievable; six was not. |
| Moonless Compass (Epic) | One of 38 movement cards plus a different one of 7 Light/Vision/Truesight/Umbra-dispel cards in either order. Shadow Step + Lantern Shot enables it from the starter kit. | Once per combat; 6 Stoneskin and 2 plays, no draw. | Directly stated cross-card sequence; no invented card classes. |
| Bloodglass Knife (Epic) | Player must be at 12/24 health or less with zero Block and Stoneskin. Nine health-cost cards, Bloodmoon Chalice, Pain Remembers, and Phoenix Ember support the risk package. | +7 per target and per attack while exposed. A five-target AOE can add 35 raw damage (70 if all five targets are already Frozen), but leaves the player in lethal range with no defense. | Preserve +7. The health and defense opportunity cost justifies the exceptional ceiling. |
| Bloodmoon Chalice (Epic) | Finish a health-cost card at half health or less; 9 such cards exist, including a starter. | Once per combat: heal 5, draw 2, gain 1 play. Maximum healing is fixed at 5. | Preserved low-health bridge; paired play makes its draw usable without creating repeatable sustain. |
| Thawing Charm (Rare) | Requires healing at full or beyond missing health. Healing cards Exhaust and run healing is deliberately sparse. | Converts excess healing to at most 8 Stoneskin per turn; grants no health itself. | Preserved. It turns scarce healing overflow into defense without slowing the run clock. |
| Chorus Mask (Rare) | Play any elemental card, then a card of a different element. Element counts are Fire 17, Ice 15, Lightning 17, Air 11, Earth 12. | Once per turn; +1 play and 3 Block. The bonus play can continue the sequence, but the relic cannot trigger again that turn. | Feasible with the base two plays; direct condition replaces “pivot” jargon and draw. |
| Duelist Whetstone (Common) | First card each turn among 21 cards that both Move/Blink and attack. | Every attack on that first card gets +2: normally +2; a five-target AOE adds +10 (+20 if all are Frozen). Razor Gale can add +14 on a plausible seven-play Flurry turn (+28 into a Frozen target), but consumes all seven plays; more requires extraordinary stacked engines. | Offensive identity matches the rapier/whetstone theme and no longer overlaps Pilgrim Boots. |
| Pilgrim Boots (Common) | Any of 17 movement cards without attacks. | +1 range to each printed Move/Blink action; adds positioning, not damage or plays. | Distinct movement enabler with broad but bounded utility. |
| Ion Spool (Common) | First Shock each turn grants 1 Lightning; any later Lightning gain can also reach 4 and cash out the stored charge. From 0–1 starting Lightning, two coordinated Shock cards normally establish the first discharge. | Once per turn; 4 to all enemies = 12/16/20 total, or 24/32/40 if every target is Frozen. Consumption resets the next setup instead of allowing passive repetition. | Preserves the liked charge/consume engine with a visible electric payoff and an intentional Freeze bridge. |
| Cinderbrand Tongs (Common) | First Burn each turn grants 1 Fire; any later Fire gain can also reach 4 and cash out the stored charge. Thirteen Burn definitions make two-turn setup realistic. | Once per turn; immediate 2 to all plus Burn 1 = 6/8/10 immediate and 9/12/15 after the first Burn tick. If every target is Frozen, that ceiling becomes 15/20/25 after the tick. | Preserves the engine and replaces generic play economy with Fire pressure while allowing demanding Freeze setup to amplify the discharge. |
| Coffin Nails (Common) | Hold Block from any of 41 sources, then play an attack card. This also works with its six equipment-based Bleed cards but does not require owning one. | Adds Bleed 1 to every printed attack resolved while Block remains; base two plays usually permit one setup card and one payoff card. A five-target AOE can apply five Bleed. | Nail-appropriate Bleed bridge; no Burn-card mismatch. |
| Mossbound Wraps (Common) | Hold Block, then play any of 12 Earth cards. The Earth card may establish Block before its play trigger resolves. | Once per turn; 3 Stoneskin and zero healing. | Replaces repeatable sustain with a defense-state bridge. |
| Tailwind Fletching (Common) | Only 3 Air cards use Push/Pull actions. | +1 damage and +1 forced tile per qualifying action. At the base two plays its added damage is normally 1–2 total and remains single-target. | +1 avoids the prior repeated +2 damage scaling while keeping positional identity. |
| Anchor Chain (Rare) | Hold Block from any source, then use any of 15 Push/Pull cards. It no longer depends on the 5 cards that print both packages. | +2 single-target damage and +1 forced tile while Block remains. A setup card normally leaves one base play for one payoff; bonus plays can extend it. | Implements the requested stateful control bridge. |
| Basalt Calendar (Rare) | Play an Earth card, then count all Earth cards across the live combat deck zones, including the card just played. The 12-card Earth pool supports every step. | Once per combat after the first Earth card: 1 Stoneskin per Earth card, capped at 6, plus +1 Earth at 3–5 cards or +2 at 6+; intensity cap 2. It grants nothing at combat start, including in an Earth room. | Every Earth investment contributes defense; the delayed, capped intensity replaces the binary +3 breakpoint without pre-activating every current Earth threshold. |
| Worldroot Idol (Legendary) | Every Earth card contributes; any later Stoneskin gain activates the engine. Fifteen Stoneskin cards, Carry the Guard, and Thawing Charm supply cross-package support. | Starts with 2 Stoneskin per Earth card, capped at 16. First Stoneskin gain each turn adds only 1 Earth intensity. It grants no starting intensity. | Useful below mono-Earth, powerful at commitment, and cannot skip the elemental game. |
| Ember Siphon (Rare) | Kill any Burning enemy; 13 Burn definitions and 3–5 normal targets make one execute realistic. | Exactly once per combat: heal 3 and gain 1 Fire. Healing ceiling is 3 regardless of enemy count. | Preserves the substantial execute reward while protecting the health clock. |
| Gale Tabi (Rare) | Eight cards print Blink 3+. | Once per turn; draw 1 and gain 1 play. Safe draw cannot cause Fatigue, and the play makes the card usable. | Keeps Blink tempo without hand overfill. |
| Storm Capacitor (Rare) | Six accessible ranged Chain cards. | +1 Chain range only. It adds no per-hit damage and cannot exceed the encounter's 3–5 targets, though wider spacing can make additional existing-damage hops reachable. | Preserves Chain identity without multiplicative +2 damage. |
| Overflow Censer (Epic) | Three raw elements at 3. In an elemental room this needs about 8 intensity points (9 in a neutral room), normally 4–5 turns at base play rate; multi-gain cards and relics shorten it. | Once per combat: 12 Stoneskin, draw 2, gain 2 plays. Draw and plays are paired under the 7-card cap. | Difficult but reachable near the end of normal combat or in a boss fight; persistent defense distinguishes the payoff. |
| Black Sun Dial (Legendary) | All five raw elements at 2. This needs about 9 intensity points in an elemental room or 10 in neutral, versus 19–20 under the old threshold. A five-color deck reaches it in a long normal fight or boss. | Once per combat; consume 2 each, deal 12 to all (36–60 across 3–5 enemies, or 72–120 if every target is already Frozen), gain 12 Stoneskin, draw 3, gain 3 plays. Freezing the full room on top of five-color setup is intentionally allowed as a mythic cross-package ceiling. | Preserves the hard five-color build-around while making the swing turn both attainable and usable. |
| Phoenix Ember (Legendary) | Defiance requires a lethal hit; the player can expose themself or use health costs while retaining one run-scoped charge. | Once per added Defiance charge this run: Burn 6 to all (18–30 pending in normal rooms), draw 3, gain 3 plays, plus Defiance restores 25% max health. | Preserved as the rarity reference: dangerous, player-directed setup and a dramatic rescue turn. |
| Funeral Bell (Epic) | Three enemies must die with a status. Normal rooms have 3–5 targets and status access spans Burn, Bleed, Freeze, Shock, Poison, and Expose. | Once per combat; draw 3 and gain 2 plays. In a three-enemy room it resolves at victory; in four/five-enemy rooms or add fights it fuels the cleanup. | Kept because draw is paired with plays and the third marked death is a real board-state condition, not an inflated card count. |

## Terminology-Only Relics Audited

- Obsidian Heart now says “at turn end”; its 4-card opening hand is the cost for
  carrying all remaining Block into Stoneskin.
- Storm Crown now says “in one turn.” Its third Lightning card requires at least
  one of 19 card-play cards, a banked play from Measured Breath, a kill refund,
  or another relic engine; spending three cards creates room for draw 3 and its
  three added plays.
- Fivefold Knot now says “in one turn.” It requires three extra/banked/refunded
  plays beyond the base two. Because five cards were spent before draw 5 and
  five plays resolve, the large paired reward is usable under the hand cap.
