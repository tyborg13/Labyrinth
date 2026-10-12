# meta-02 — Chronicle: run history and lifetime stats

## Header
- Goal: Slay the Spire's run history/compendium habit — every descent is remembered: how it ended, the path through
  the sections, the build, the score and its feats. Lifetime totals give long-term goals.
- Base: `codex/peer-benchmark` at 6f4bbacfb (meta-01 merged: score, feats, killer, run_seconds in stored results). meta-01 provides score, feats, killer
  and the counters in stored run results; meta-03 (Umbra Depths) may run in parallel and adds `umbra_depth` — read it
  when present, show nothing when absent.
- Mockup (approved with the changes listed below): `output/peer-benchmark-2026-10-12/mockups/chronicle.png`
  (source `chronicle.html`).
- Owned files: new `scripts/chronicle_rules.gd` (builds the record, lifetime totals, formatting), new
  `scripts/chronicle_panel.gd` (+ scene if you prefer), new `tests/suites/chronicle_suite.gd` + `tests/chronicle_test.gd`,
  new `tests/chronicle_probe.gd`; modify `scripts/progression_store.gd` (store records + totals), `scripts/run_engine.gd`
  (record the path as rooms are entered; minimal), `scripts/main_menu.gd` (Chronicle button), `spec/chronicle.md`
  (new), `spec/analytics.md` (additive `chronicle_opened` event only).
- Rules: presentation + profile data; game rules unchanged; Windows typed-array rule; old profiles load (no records →
  empty state; old stored results without a chronicle record are not listed); `TODO_DESIGN_<name>` for anything open.
- Contract: risk tier standard (profile save format). Acceptance: (1) a record is written once per finished run
  (defeat, victory, Ember Hearth embrace) and survives restart; (2) lifetime totals; (3) UI per mockup + changes with
  mouse, keyboard and controller; (4) old profiles and runs without records are safe.

## Record (one per finished run; newest first; keep the newest 50, drop the oldest)
`{run_id, outcome ("defeat"|"victory"|"embrace"), ended_at (local date "12 Oct"), run_seconds, section_index,
section_name, room_index (1-based rooms entered in that section), room_total (rooms on that section's route as the map
counts them), umbra_depth (if present), score_total, feats [{title, detail}], killer_text, path [[room_kind, ...] per
section entered], dragon_ids (by section), gear [item ids equipped at the end], deck [[card_id, count] in deck order],
relics [relic ids]}`.
- `room_kind` uses the section map's node kinds (combat, guardian, event/mystery, scavenger, hearth, graftwright,
  relic/treasure, dragon, boss, threshold excluded). Record the kind the room turned out to be (a mystery that became a
  fight records "event" if it was an event, else its revealed kind).
- `killer_text`: "Felled by a <Enemy name>'s <Intent name>"; fatigue → "Worn down by fatigue"; surface/trap → "Slain
  by <surface/trap name>"; victory → "Noctyrax falls"; embrace → "Withdrew at the Ember Hearth".
- Lifetime totals (kept forever, not capped): runs, escapes, best score, dragons slain, deepest Umbra Depth escaped
  (only when meta-03 data exists; otherwise the chip is hidden).

## Screen (per mockup, with these changes)
1. Entry: main menu button "Chronicle" between "New Game" and "Settings", same button style and 92 px spacing (Quit
   moves down one slot). Opens the Chronicle; Esc / B / the close button returns to the menu with focus on Chronicle.
2. Panel: 1800×860 centred (x 60, y 110), the major-dialog frame from the mockup (gold corner brackets, inner keyline).
   Eyebrow "CHRONICLE" (UI 15 px, letter-spacing 5, GOLD_DIM), title "Your Descents" (UI 44 px, GOLD_BRIGHT).
   Stat chips top-right as in the mockup: "<N> runs", "<N> escapes", "<N> best score", "<N> dragons slain",
   "<N> deepest depth" (last chip only with meta-03 data). Numbers use thousands separators.
3. List (left, 520 px wide, from y 130 inside the panel): rows as in the mockup — result word (UI 15 px, letter-spacing
   3; SLAIN `#d07a6c`, ESCAPED GOLD_BRIGHT, WITHDRAWN TEXT_2), where line (Text 18 px TEXT: "Section III · Rime Hall";
   victory "Noctyrax falls") with date · minutes below (15 px TEXT_3), score right (UI 22 px) with "DEPTH N" below in
   UMBRA violet `#9a7cf0` when depth ≥ 1. Selected row: 1 px GOLD border, 7% gold fill, soft ember glow. Scrolls when
   more rows than fit; mouse wheel, Up/Down, D-pad, LB/RB page.
4. Detail (right): title = result word in Display 56 px `#ddd3c4` with the violet drop shadow; **score at the right
   end of the title row**: number in UI 44 px GOLD_BRIGHT with eyebrow "SCORE" above it (UI 14 px, letter-spacing 4,
   GOLD_DIM). Subline (Text 21 px TEXT_2, bold parts TEXT): "<where>, room <i> of <n> · <m> min · Umbra Depth <d> ·
   <killer_text>" (omit the depth part at depth 0/absent). Gilded rule.
5. "THE PATH": one row per section entered: section label (Text 16 px TEXT_2, roman numeral + name) then 34 px round
   room icons (the section map's node icons, 1 px `#5a4630` ring, `#0f0c09` fill, 6 px gap); the dragon room 44 px with
   a GOLD ring; the room where the run ended in a defeat shows a 34 px DANGER ring with a ✕ instead; an embrace ends with
   the Hearth icon in a GOLD ring. More than 16 icons in a row: wrap.
6. Three columns under the path: "GEAR" (52 px item icons, 8 px gap, wrap), "SPELLS" (card names in deck order, "×N"
   suffix for duplicates, separated by " · ", Text 17 px, line-height 1.6; more than 8 lines → end with
   "+<k> more"), "FEATS" (no number in the label; each feat "◆ <Title> — <detail>" Text 17 px GOLD_BRIGHT, diamond GOLD;
   none → "No feats this time." TEXT_3). Then "RELICS" (52 px icons) below. Hover/focus on any icon shows the
   existing item/relic/room tooltip.
7. Empty state: list shows "No descents yet." (Text 18 px TEXT_3, centred in the list); detail shows "Your first
   descent will be written here." (Text 21 px TEXT_2), chips show zeros.
8. Input: mouse; keyboard Up/Down select, Esc back; controller D-pad/stick select, LB/RB page, B back; the controller
   prompt bar shows "Select" / "Back". Opening/selection use the existing UI sounds.

## Proof
- Suite: a record is written once per outcome type (defeat with killer, victory, embrace), restart persistence, 50-run
  cap with totals still counting, path kinds in order incl. revealed mysteries, old profile without records, formatting
  of killer/subline/spells overflow.
- Probe (windowed, director runs): Chronicle with 7 seeded records matching the mockup data, the empty state, a
  victory record selected, a 30-spell deck (overflow), controller focus.
- Keep green: full suite, run_end/run_score suites, main menu probes.

## Out of scope
- Daily runs, achievements, sharing/export, deleting history.
