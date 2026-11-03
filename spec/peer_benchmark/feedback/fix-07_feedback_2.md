# fix-07 feedback 2 (from the Codex review of 3ff9b0325) — LAUNCH ONLY WHEN THE OWNER IS NOT PLAYING

Finding 2 of the review (deleted feedback/ledger lines) is a comparison artifact: the integration branch advanced after
this unit branched. Ignore it; don't touch those files.

1. **Medium: Funeral Bell doubles Petrify Block.** Casting Petrify on B, then killing an adjacent Petrified + Exposed
   enemy with Funeral Bell gives B 10 Block. Rule: Petrify grants its 5 Block only when it newly petrifies an enemy that
   isn't already Petrified (from any source). Regressions: card → relic spread onto the same enemy (stays 5); relic
   spread twice in one turn (stays 5); an enemy with existing unrelated Block gets +5 (adds, never overwrites; this
   also catches the surviving overwrite mutant).
2. **Low: update `spec/card_mechanics_maneuver.md`** (~138, ~148) to the fixed keyword Block, the shared helper, source
   attribution and the two-token card face.
3. **Low: one Petrify wording everywhere.** The enemy status badge (`scripts/combat_board_view.gd` ~16950) and the
   turn-order tooltip (`scripts/run_scene.gd` ~13052, a one-line text change only; nothing else in run_scene.gd) use
   shared wording from one place. Badge text: `Petrified: skips its next turn (still paying its Time) and has 5 Block
   through your next turn. Dragons are immune.` Turn-order line stays specific to the queued turn:
   `Petrified: skips this turn (still costs its Time)`. Test both consumers.

Re-run only maneuver, relic_u7, glossary, card_keywords and the badge/turn-order checks. No full suites.
