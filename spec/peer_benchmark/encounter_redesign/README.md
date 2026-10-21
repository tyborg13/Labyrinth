# Encounter redesign (proposal stage, 2026-10-20)

Owner request (2026-10-20): make every encounter "strategically interesting and fun and ask difficult questions":
the dragons, the Guardians, Defeat the Leader and Reach the Exit. Propose first, iterate in the Review Inbox, then
build with Codex as its own workstream. Nothing here is built yet.

- Proposal page: https://claude.ai/artifact/D6P63LRV4ccFizPGmMqzRX ("Umbra Encounter Redesign").
- Inbox items: `enc-specials`, `enc-clarity`, `enc-dragons`, `enc-guardians` (`enc-warband` and `enc-breakout` were
  closed when the owner redirected them, 2026-10-20). Owner verdicts there are binding; record them in `../feedback.md`
  and here.
- Revision 2 (2026-10-20, owner's redirect): standard fights are always Defeat All. Defeat the Leader and Reach the
  Exit became authored, map-visible special encounters, alongside two new ones: the Warband (a fixed captain per
  section), Umbral Snare (sealing doors, Sealbinders, hunters, the Umbral Gaoler), Ember Hoarder (a new creature that
  flees with embers) and Last Light (the parked Survive objective around a brazier). Each type pays in its own
  currency (gear, embers, embers, healing), on top of 4 card choices (at least one Rare or better) and 1.5× embers.
  2–3 per section, never the same type twice; per-section variant tables are in `body.html`.
- APPROVED 2026-10-21 (enc-specials), with the director decisions recorded in `../feedback.md`: the Hoarder reuses an
  Ember Tick, the Cinder Crown gang drops its Ticks, and captains are not scaled.
- Concept emblems (proposal only, not shippable identity art): prompts in `emblems/prompt_*.txt`, image jobs
  `enc-emblem-{warband,umbral-snare,ember-hoarder,last-light}` with refs fight/relic/scavenger/campfire/lantern from
  `assets/art/icons/map/`. Outputs, by sha256, in `output/encounter-redesign-2026-10-20/emblems/`:
  warband 975d3d01…4361, umbral_snare 91acb822…15ca2, ember_hoarder a4807c1d…5caf, last_light abc6ba13…2ff6.
  `mockups/mock_special_map.py <emblem dir> <out dir>` composites them into the ux-01 Hollow Gale capture and
  rebuilds the legend (present types only, 12 px gaps).
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
  2. enc-02: special-encounter framework (Defeat All standard fights, map placement, emblems, legend, tooltips,
     rewards) with the Warband as the pilot.
  3. enc-03 / enc-04: Umbral Snare and Last Light, in parallel.
  4. enc-05: Ember Hoarder, after its creature art passes the visual identity gate.
  5. enc-06: clarity layer.
  6. enc-07: dragon framework, with Tharokh as the pilot.
  7. enc-08: Guardian framework, with Rimejaw as the pilot.
