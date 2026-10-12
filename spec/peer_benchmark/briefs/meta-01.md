# meta-01 — Run score, feats and the run-end screen

## Header
- Goal: every run ends with a reason to start another: a banner and a dry line, what killed you, then a line-by-line
  score with feats (Slay the Spire's death screen grammar) and a NEW BEST tag; the score is saved per run for the
  Chronicle (meta-02).
- Base: `codex/peer-benchmark` (director gives the commit; after map-01 merges, since "unknown rooms" come from it).
- Mockup (approved): `output/peer-benchmark-2026-10-12/mockups/run_end.png` (source `run_end.html`). Ignore the faded
  old stats in its backdrop (mockup artefact); the left side is the live board as today.
- Owned files: new `scripts/run_score_rules.gd`, new `data/run_end_text.json` (director-authored, protected),
  new `tests/suites/run_score_suite.gd` + `tests/run_score_test.gd`; modify `scripts/run_end_recap_overlay.gd`
  (rebuild the layout), `scripts/run_engine.gd` + `scripts/combat_engine.gd` (stat counters only, additive fields in
  `run_stats`), `scripts/progression_store.gd` (store score/feats/killer in the stored run results; best score),
  `tests/run_end_recap_probe.gd` (update), `spec/run_end.md` (new), `spec/analytics.md` (additive `run_scored`).
- Rules: rules unchanged except counters; Windows typed-array rule; saves: old stored results without scores load fine
  (score null → shown as "—" later); `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier standard. Acceptance: (1) counters tracked and saved mid-run; (2) score + feats computed exactly
  per table; (3) run-end screen per mockup for defeat, victory and Ember Hearth embrace; (4) NEW BEST; (5) analytics.

## Data provided
`data/run_end_text.json`:
```json
{
  "titles": {"defeat": ["SLAIN", "FALLEN"], "victory": ["ESCAPED"], "embrace": ["WITHDRAWN"]},
  "quips": {
    "defeat": ["The labyrinth keeps what it kills.", "Somewhere, a cartographer adds your name.", "The Umbra is patient.",
      "Your Embers cool where you fell.", "The dark was never empty.", "Another light goes out below.",
      "The dragons did not notice.", "The stone remembers the way down.", "Even the Emaciated Man looks away.",
      "The halls fold shut behind you.", "Not today. Perhaps not ever.", "The Scavenger will find your boots.",
      "Darkness, at last, is quiet.", "You will wake at the Threshold again."],
    "victory": ["The light finds you first.", "Behind you, the labyrinth forgets your name.",
      "The Umbra loosens its grip. For now.", "Six dragons. One door.",
      "You step into a morning you had stopped believing in.", "The dark will need a new story."],
    "embrace": ["Wisdom is knowing which door to leave by.", "The Embers come with you. The dark stays.",
      "You live to descend again."]
  }
}
```
The director commits this file before launch. Title and quip pick: seeded by the run id (stable on re-render).

## Change (numbered, testable)
1. **Counters** (additive `run_stats` fields, saved): rooms_explored (rooms entered, any type, excluding the Threshold),
   enemies_slain (all enemy deaths credited to the run, excluding summons), guardians_slain + guardians_unscathed
   (guardian fights won with no HP lost), dragons_slain (ordered ids) + dragons_flawless (ids), max_single_hit (largest
   damage from one player hit), max_kills_one_card (most enemies killed by one card resolution), mystery_rooms_entered,
   events_resolved, max_held_embers, defiance_spent, run_seconds (play time, paused time excluded), killer
   `{enemy_type, intent_id, damage}` (or `{"cause": "fatigue"|"surface"|"trap", ...}`).
2. **Score** (`RunScoreRules.score(run_state, outcome) -> {lines, feats, total}`), exactly:
   - "Rooms explored" N × 5 · "Enemies slain" N × 2 · "Guardians slain" N × 25 ·
     "Dragons slain" cumulative 50/100/150/200/250/300 by count (e.g. 2 dragons → 150), listing their names ·
     Victory only: "Escaped the Umbra" +250.
   - Feats (gold rows, each with its detail line): "Unscathed" +25 per guardian won without losing Health
     ("<Guardian> without losing Health"); "Flawless" +50 per dragon likewise; "Overkill" +25 once if max_single_hit
     ≥ 20 ("<N> damage in one hit"); "Chain Reaction" +25 once if max_kills_one_card ≥ 3 ("<N> foes slain by one
     card"); "Seeker" +25 if mystery_rooms_entered ≥ 10 ("<N> unknown rooms"); "Bargainer" +25 if events_resolved ≥ 8
     ("<N> events"); "Ember Hoard" +25 at max_held_embers ≥ 600, +50 instead at ≥ 1,200 ("<N> Embers held at once");
     victory only: "Last Light" +25 if defiance_spent ≥ 1 ("Escaped after Defiance saved you"), "Swift" +25 if
     run_seconds < 3,600 / +50 instead if < 2,700 ("Escaped in <m> minutes"), "Ascetic" +50 if relics ≤ 3
     ("Escaped with <N> relics").
   - Rows with 0 points are omitted. Order: base rows, then feats in the order above.
3. **Run-end screen** (`run_end_recap_overlay.gd`), right column at x = 1010, width 780 on 1920×1080 (mockup values):
   - Eyebrow (eyebrow font 15 px, letter-spacing 5, UMBRA `#9a7cf0` for defeat, GOLD for victory/embrace):
     "Section <roman> · <biome name> · Room <step> of <S>" (biome name from data/biomes.json if present, else the
     section title).
   - Title: Display font 112 px, `#ddd3c4`, umbra shadow (defeat) / ember shadow (victory).
   - Quip: Text italic 24 px TEXT_2.
   - Cause (defeat): 44 px round portrait of the killer (existing portrait art) + "Felled by a <Enemy>'s <Intent>,
     <N> damage." / "Fatigue took your last breath." / "<Surface> took your last breath." / "A <element> trap took
     your last breath." Victory: "Noctyrax falls. The way out is open." Embrace: "You leave by the Ember Hearth,
     carrying <N> Embers."
   - Gilded rule, then score rows (width 560): label UI 20 px TEXT_2 with a Text 16 px TEXT_3 detail; value UI 22 px
     tabular; feats in GOLD_BRIGHT with a gold diamond marker; 1 px hairline between rows.
   - Total: "SCORE" eyebrow + Display 52 px GOLD_BRIGHT; "NEW BEST" tag (UI 13 px, letter-spacing 3, ink on EMBER) when
     the total beats the stored best.
   - Embers line as today's information, reworded: defeat "Embers lost <N>. They wait where you fell, in Section
     <roman> of your next run." (or today's no-marker text when 0); victory/embrace "Embers carried <N>."
   - Buttons: keep today's slab buttons; labels "Rise Again" (primary, = New Run), "Chronicle" (disabled with tooltip
     "Coming soon" until meta-02 lands), "Main Menu".
4. **Motion.** Title fades in 0.3 s; quip and cause 0.25 s later; rows reveal one by one every 0.11 s with the existing
   soft UI tick; total counts up over 0.8 s (ease-out) then the NEW BEST tag pops (1.25→1.0, 0.25 s). Any input skips
   to the end state. Reduced motion: everything appears at once.
5. **Persistence.** Stored run results gain `score`, `feats`, `killer`, `section`, `biome`; `best_score` in
   progression. Analytics `run_scored {total, lines, feats}` additive.
6. **Spec.** spec/run_end.md.

## Keep
- Death/escape flow, Ember recovery staging, defiance, existing stored results, Steam stats, controller focus
  (primary button first).

## Proof
- Suite: each counter, score/feat table cases (incl. boundaries 599/600/1,199/1,200, 2,699/2,700/3,599/3,600 s),
  omission of zero rows, seeded title/quip stability, old results load.
- Probe (windowed, director runs): defeat mid-run with 2 dragons/2 feats (mockup state), victory with 6 dragons, embrace,
  reduced-motion end state, NEW BEST.
- Keep green: run_end_recap probe (updated), full suite.

## Out of scope
- The Chronicle screen (meta-02), unlocks, achievements.
