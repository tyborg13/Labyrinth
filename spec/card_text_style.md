# Card text style (director, 2026-11-07)

These are the rules for authored card text: each card's `description` in `data/cards.json`, which the Grimoire and plain-text tooltips show. They apply to panel and glossary text where those use the same words. In fights the card face uses icons and numbers; this style keeps the written text consistent with that.

These rules came from crd-01's audit, which found 62 phrasings for a basic melee hit, keywords capitalized inconsistently, verbs used for one card only, and rules defined inline on the card.

## Rules
1. **Keywords are capitalized wherever they appear as game terms,** using the glossary's name.
   - Statuses: Bleed, Immobilize, Expose, Sunder, Stagger, Shock, Chilled, Freeze/Frozen, Petrify.
   - Defences: Block, Stoneskin, Retaliate, Mantle.
   - Movement keywords: Push, Pull, Blink, Swap.
   - Ground: Fire, Ice, Rubble, Electrified, Light.
   - Other mechanics: Chain, Pierce, Quicken, Detonate, Expend, Vision, Truesight.
   - Card keywords and resources: Follow-up, Empower, Exhaust, Consume, Card Play, Time, Health.
2. **Basic verbs stay lowercase mid-sentence:** move, draw, heal, strike, deal, gain, leave, create, place, raise.
3. **One verb per kind of hit:**
   - Melee: "Strike for N" for an adjacent hit; "strike at reach R for N" beyond adjacent; "strike [shape] for N" for an area (for example "strike all adjacent tiles for 8").
   - Ranged: "Deal N at range R".
   - No flavour verbs: bash, kick, stomp, nick, sweep, clamp, mark, hook, snare, lash, or "reach" used as a verb.
4. **Riders follow the damage** (exception: a card whose push really happens before its hit keeps that order, e.g. Sleet Squall):
   - Push and Pull: "Deal 3 at range 4 and Push 2", not "Push 2 at range 4 for 3 damage".
   - Pierce is a rider sentence: "Strike for 6. Pierce."
5. **Element words:** name the element only where a rule depends on it: "Ice damage" (Chilled targets Freeze) and "Lightning damage" (Chain, Electrified). Fire, Earth and Air damage aren't named, because no rule reads them; leaving Fire or Rubble is named as ground.
6. **No inline definitions.** The panel and glossary define keywords:
   - "Quicken 2.", not "Quicken 2: your next card this turn costs 2 less Time.";
   - "Gain 3 Mantle.", not a Mantle definition.
   - Reminder clauses that state this card's own outcome stay, in plain words ("...each Chilled enemy you can see, Freezing them").
7. **Shapes use the face token's name:** "in a cross", "in a 3-tile line", "radius-2 diamond". No "cross pattern", "small blast" or "large pattern" unless that is the token's name.
8. **Numbers are digits,** including "3-tile line". Durations read "for N turns". Idioms keep words: "one of your illusions", "a one-tile enemy".
9. **Conducted Lightning:** "Hits spread by Electrified tiles also Shock." (it replaces "Electrified-assisted hits also Shock.").
10. Names of things a card creates stay capitalized as proper names (Worldspine). Common nouns (outcrop, crate, illusion as an object) stay lowercase.
11. **Standing conditions:** "if you stand on Fire" for your own tile, and "if the target stands on Fire" or "each enemy standing on Electrified" for others. Not "while standing on".
