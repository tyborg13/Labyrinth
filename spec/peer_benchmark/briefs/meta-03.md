# meta-03 — Umbra Depths: a 20-step difficulty ladder (rules, unlocks, New Descent picker)

## Header
- Goal: Slay the Spire's Ascension spine for Escape the Umbra. Escaping at Depth N unlocks Depth N+1. Each depth adds
  one plainly worded difficulty that touches a different system, and adds +5% score.
- Base: `codex/peer-benchmark` at 6f4bbacfb (map v4, ev-01 events/omens and meta-01 run score/run-end are merged).
  meta-02 (Chronicle) runs in parallel and also edits `main_menu.gd` and `progression_store.gd`: keep your edits there
  small and local (the director merges).
- Data provided (director-authored, committed before launch, protected): `data/depths.json` — 20 levels with the
  exact player-facing text and a modifier per level.
- Mockup (approved): `output/peer-benchmark-2026-10-12/mockups/depth_picker.png` (source `depth_picker.html`).
- Owned files: new `scripts/depth_rules.gd`, new `scripts/new_descent_panel.gd`, new
  `tests/suites/depth_rules_suite.gd` + `tests/depth_rules_test.gd`, new `tests/new_descent_probe.gd`; modify only
  where each modifier hooks in (minimal, call `DepthRules`): `scripts/section_map_graph.gd` (Guardian weight),
  `scripts/combat_engine.gd` / `scripts/room_generator.gd` (enemy damage/HP by class, initiative, fatigue base,
  Guardian helper count, Noctyrax enrage), `scripts/run_engine.gd` (start HP, max HP, start omen, Hearth heal, dragon
  Embers, card reward weights, shop prices, event costs via EventRules), `scripts/event_rules.gd` (cost scaling only),
  `scripts/progression_store.gd` (unlocked depth, best per depth), `scripts/main_menu.gd` (New Game → picker),
  `scripts/run_end_recap_overlay.gd` + `scripts/run_score_rules.gd` (depth line + score bonus row; meta-01 has landed),
  `tests/run_tests.gd` (suite registration only),
  `scripts/run_scene.gd` (≤ 15 lines: depth tag in the header), `spec/depths.md` (new), `spec/analytics.md` (additive
  `depth` on run start/end events).
- Rules: Depth 0 = today's game exactly (byte-identical state hashes for all existing suites); a run stores its
  `umbra_depth` and never changes it; old saves load as depth 0; Windows typed-array rule.
- Contract: risk tier high (rules across systems, saves, progression). Acceptance: (1) every modifier applies exactly
  as specified and only at depth ≥ its level; (2) depth 0 unchanged; (3) unlock on escape at the current max depth;
  (4) picker per mockup with mouse/keyboard/controller; (5) header tag + run-end line; (6) analytics.

## Modifier semantics (exact)
- `map_guardian_weight{multiplier}`: multiply the revision-4 Guardian type weight (10) by the multiplier before
  rolling; route constraints unchanged.
- `enemy_damage_bonus{class, amount}`: + amount to every damaging action of that class (regular = non-guardian,
  non-dragon, non-summon enemies; guardian = guardian leaders AND their helpers; dragon = the six dragons).
- `enemy_hp_percent{class, amount}`: max HP × amount/100 rounded up, applied after existing depth scaling.
- `hearth_heal_delta{amount}`: Ember Hearth linger heal + amount (never below 1).
- `start_hp_percent{amount}`: the run starts at ceil(max HP × amount/100).
- `start_omen{omen}`: the run starts with that omen at its default fights.
- `umbra_sight_delta{amount, from_section}`: sight radius + amount for sections ≥ from_section (0-based; never below
  1; Eclipse unchanged; section I's "clear" stage unchanged).
- `card_reward_rarity_weights{weights}`: replace the card-reward rarity weights for combat rewards.
- `dragon_ember_percent{amount}`: Embers from dragon kills (enemy reward + the boss victory bonus) × amount/100,
  rounded half up.
- `max_hp_delta{amount}`: base max HP + amount at run start.
- `event_costs{hp_delta, max_hp_delta, ember_cost_percent}`: event HP costs (negative `hp`) are 1 larger, negative
  `max_hp` costs 1 larger, Ember payments × 125% rounded up to a multiple of 5; the preview lines show the scaled
  numbers; requirements scale with them.
- `shop_price_percent{amount}`: Scavenger buy prices × amount/100 rounded up to a multiple of 5 (sell unchanged).
- `enemy_initiative_delta{class, amount}`: regular enemies' base initiative + amount (−1 = they act sooner; floor 3).
- `fatigue_base_delta{amount}`: reshuffle fatigue base + amount.
- `guardian_extra_helper{amount}`: each Guardian fight adds amount extra helpers of that Guardian's helper type at
  legal tiles.
- `boss_enrage{boss, hp_percent, damage_bonus}`: that boss's max HP × hp_percent/100 and + damage_bonus to its damaging
  actions.

## Unlocks and score
- Profile stores `umbra_depth_unlocked` (0 initially) and best score per depth. Escaping (Noctyrax defeated) at depth
  d where d == unlocked raises unlocked to min(20, d+1). The picker cannot go above unlocked.
- Score: the run's final score total × (1 + 0.05 × depth), shown as its own run-end row "Umbra Depth N" "+N×5%".

## New Descent picker (main menu → New Game when unlocked ≥ 1; at 0, New Game starts as today)
- Modal per mockup: panel 860×780 centred on 1920×1080, major-dialog material; eyebrow "NEW DESCENT" (UMBRA violet);
  title "Umbra Depth N" (Display 64 px, GOLD_BRIGHT) flanked by 54 px round arrow buttons (disabled at 0 / at the
  unlocked max); subline "Score +X% · Deepest escape: Depth M" (or "No escapes yet"); gilded rule; the cumulative list
  of modifier texts 1..N (Text 21 px, number in UI 15 px TEXT_3; the newest row in TEXT with an ember "NEW" tag);
  when N > 10, two columns of 10 rows at 19 px. Depth 0 shows a single line: "The Umbra as you first knew it."
  Footer buttons: "Back", "Begin Descent" (primary). Under the list, when N == unlocked < 20, a TEXT_3 line: "Escape at
  Depth N to unlock Depth N+1."
- Input: Left/Right (and LB/RB) change depth; Enter/A begins; Esc/B backs out. Remember the last chosen depth.
- Header tag in runs at depth ≥ 1: after the room subtitle, "Umbra Depth N" in the eyebrow style (UMBRA violet).

## Proof
- Suite: each modifier at its level and not below (20 cases), depth-0 equality with existing state hashes, unlock
  progression, score multiplier, save/load of `umbra_depth`, old saves → 0.
- Probe (windowed, director runs): picker at depth 0, 3 (mockup), 12 (two columns), locked arrow; a combat header with
  the depth tag.
- Keep green: full suite, section_map v2, event_rules, dragon_boss, guardian suites.

## Out of scope
- New enemy movesets, a double final boss, achievements, daily runs.

## Decided details (brief checklist)
- Run-end: the score bonus row is the last base row: label "Umbra Depth <N>", detail "+<N×5>%", value = the added
  points (round half up), before feats; the eyebrow gains " · Umbra Depth <N>" at depth ≥ 1. Depth 0: no row, no text.
- Picker sounds: existing UI cues only (arrow buttons = the existing UI click; Begin Descent = the existing confirm);
  no new audio.
- Fallbacks: a profile without `umbra_depth_unlocked` = 0 (New Game starts as today, no picker); a stored depth above
  the unlocked value (edited saves) clamps to unlocked; a run save without `umbra_depth` = 0.
- Overflow: at N > 10 the list uses two columns of up to 10 rows at 19 px (as specified); N = 20 is the maximum, so no
  further overflow.
