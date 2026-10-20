# Encounter redesign (proposal stage, 2026-10-20)

Owner request (2026-10-20): make every encounter "strategically interesting and fun and ask difficult questions":
the dragons, the Guardians, Defeat the Leader and Reach the Exit. Propose first, iterate in the Review Inbox, then
build with Codex as its own workstream. Nothing here is built yet.

- Proposal page: https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX ("Umbra Encounter Redesign").
- Inbox items: `enc-warband`, `enc-breakout`, `enc-clarity`, `enc-dragons`, `enc-guardians`. Owner verdicts there
  are binding; record them in `../feedback.md` and here.
- Sources: `body.html` (copy), `boards.py` (board diagram specs), `board.js` (top-down renderer), `gen.py`
  (`python3 boards.py > boards.json && python3 gen.py <dir>` builds `encounter_redesign.html`, inlining the
  Crumble fonts). `mockups/` builds the real-capture mockups with headless Chrome. `iso.py` holds the board tile
  geometry; `calib.py` draws a calibration grid. Captures, rendered mockups and the page are in the primary checkout
  under `output/encounter-redesign-2026-10-20/`.
- Evidence behind the proposal: local analytics (Aug–Sep), with Reach Exit 13/13 won at a median of 0 HP lost and
  Leader fights ending after a median of 1.5 kills. Code survey: leader = highest max HP
  (`room_generator.gd:601-622`); exits at fixed midpoints 6 tiles from the entry (`combat_objective_rules.gd:117-139`);
  Guardian helpers re-summoned on every Guardian activation (`guardian_combat_rules.gd:489-505`); Cantor and Roc at
  initiative 20; no HP-threshold phases anywhere.
- Planned units after approval:
  1. enc-01: measurement. A seed sweep plus a boss bot harness, and a fix for analytics context fields dropped by the
     `AnalyticsStore` whitelist.
  2. enc-02: Warband.
  3. enc-03: Breakout.
  4. enc-04: clarity layer.
  5. enc-05: dragon framework, with Tharokh as the pilot.
  6. enc-06: Guardian framework, with Rimejaw as the pilot.
