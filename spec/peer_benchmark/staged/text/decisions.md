# Text rewrite — director decisions (2026-10-15)

Inputs: `glossary_rewrite.{json,md}`, `relic_rewrite.{json,md}` (Claude drafts), `spec/text_style_guide.md`.

## Glossary
- **Accept** all accuracy fixes, the conventions ("next to" = 4 orthogonal tiles; "attack" = direct hit; "ground" is the
  one noun for Fire/Ice/Electrified/Rubble; durations in words; keywords referenced, never re-explained).
- **Renames accepted:** Thornwall → Bramble (the intent keeps "Thornwall"); Consume Ground/Surface → **Expend** (item
  keyword Consume unchanged); Illuminate → **Light**; Summon Minions → **Summon**; Kindle Ground → **Cinder Marks**;
  The Last Eclipse → **Last Eclipse**; Character and Loadout → **Character**. Spelling unifications accepted: Rooted →
  Immobilize, Truesight, Card Play, Embers, Moltshard, "ground", Stoneskin (fix the "Guard" mislabel).
- Q1 **Expend** (not Spend — Spend stays for points/currency).
- Q2 Fire and Ice keep the shared element/ground names; icons disambiguate where both matter.
- Q3 **Wait**: new keyword, text-only (its HUD chip already reads "WAIT +N"). **Turns**: new text-only entry for duration
  chips that today borrow the Time icon — the chip's tooltip panel uses the Turns entry ("Turns left: how many more of the
  bearer's turns this lasts." — drafter to finalize per code), so no card shows two different "Time" panels. A dedicated
  Turns icon is a later art task.
- Q4 Keep **Swap Illusion** separate (own icon); define it by reference to Swap.
- Q5 **Sure-Footed**: drop the Air-push clause (match the code).
- Q6 **Hollow Gale**: wire Vaeloryx's live Hollow Gale intent to the `gale_force` icon and define it from the live action.
- Q7 Delete `raise_cover`, `reclaim_cover`. Q8 Delete `skill_layaway`.
- Q9 Add **Ice Pillar** (text-only entry, defined from the Icefall code).
- Q10 Rename the Storm Capacitor enemy's "Discharge" intent to **Arc Burst** (Discharge stays the card keyword).
- Add entries: **Movement** (the per-turn movement resource, distinct from the Move keyword) and **Item**.
- **Outcrop** definition states that Worldspines and Powder Kegs count as Outcrops (so relic text can just say Outcrops).

## Relics
- Adopt the token convention: `@term(key)` = icon + glossary name (first mention of resources, statuses, grounds, Light,
  Illusion); `@kw(key)` = keyword style, no icon; `|Form` inflection. Names flow from the glossary.
- Accept all accuracy fixes and rewrites, aligned to the glossary names above (Light, Expend, Bramble, Cinder Marks …).
- **Storm Capacitor relic → rename** (collides with the enemy). Drafter proposes 3 names that fit its effect; director
  picks.
- **Black Sun Dial**: find a ≤ 25-word wording (hard limit).
- **Pocket Sundial**: use the Wait keyword.
- Copper-Shod Staff / Mason's Plumb: say "Outcrops" (the glossary covers Worldspines and Powder Kegs).
- "+1 Chain" is the form for additive bonuses.
- Winter's Spur apostrophe fix accepted.

## Code issues found (separate fix unit, not text)
Sunpath/Dawnbrand HUD never shows SPENT (wrong flag); `text_token` callers passing an icon key as the tone (icon
missing); Lightning Strikes count chip uses the Shock icon; enemy-view copies of definitions pinned by tests (move to the
glossary). Fatigue amplified by Expose/Chilled/Frozen (`combat_engine.gd:7773`) is a rules question for the owner — no
change without approval.

## Follow-up (2026-10-15)
- **Outcrop / Worldbreak**: no rules change. Worldbreak's text names its real targets ("an Outcrop or Worldspine you
  raised" — not Powder Kegs); the Outcrop glossary entry stays as drafted.
- Glossary draft is final (`glossary_rewrite.json`, `"final": true`, 145 live entries).
