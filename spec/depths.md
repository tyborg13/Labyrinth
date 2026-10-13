# Umbra Depths (meta-03)

Design authority: protected `data/depths.json` and the unit brief. The approved
picker reference is `output/peer-benchmark-2026-10-12/mockups/depth_picker.png`
(and its HTML source; both are present in the design owner's parent checkout).
No assets are generated or replaced by this unit.

## Run and profile contract

`DepthRules.depth(state)` resolves the immutable `umbra_depth`, clamped to 0–20.
Nonzero runs persist the field in the run, generated encounters and combat state.
Depth zero uses the existing sparse representation: a missing field means zero.
This keeps complete Variant state bytes identical to the task base, including
RNG, map, combat, queue and progression. Old saves never derive their run depth
from a newer profile's remembered selection. Load repair clamps an explicitly
edited run field to its embedded unlocked maximum; ordinary progression updates
and changing the picker selection do not change an active run's difficulty.

The profile uses:

- `umbra_depth_unlocked`: zero when absent, capped at 20.
- `umbra_depth_selected`: the last choice, clamped to the unlocked maximum.
- `umbra_depth_best_scores`: a map of string depth ids to monotonic best scores.
- `umbra_depth_twenty_escaped`: distinguishes an escape at Depth 20 from merely
  unlocking it, for the picker’s deepest-escape line.

The existing completed-result ledger owns unlock and per-depth best updates.
A recorded victory with Noctyrax among the slain dragons at the current unlocked
maximum advances it by one, capped at 20. Defeat, Hearth withdrawal, debug boss
victories, lower-depth escapes and replay of a recorded result cannot advance it.
Legacy unscored results remain nullable. Completed nonzero results additionally
retain `umbra_depth` independently of the existing room-depth metric.

## Modifier ownership

Every modifier is cumulative and gated by its authored level; its text and
numbers are read from the protected JSON, without rewriting that data.

| Levels | Runtime boundary |
| --- | --- |
| 1 | Revision-4 map Guardian weight before weighted rolls; route constraints unchanged |
| 2–4 | Fresh enemy intent actions, after existing encounter damage scaling |
| 5 | Hearth linger healing and its existing preview chip, floor one |
| 6, 14 | Run-start max HP first, then wounded-start HP rounded up |
| 7–9 | Generated and subsequently spawned enemy HP after existing encounter scaling |
| 10 | Starting Hunted through OmenRules, retaining the omen’s default fights |
| 11 | Effective personal sight from section index 1 onward, including vision bonuses; clear and Eclipse unchanged, floor one |
| 12 | Combat reward rarity rolls, including their rerolls; event and shop pools unchanged |
| 13 | Dragon death Embers and boss victory bonus combined, rounded half up once |
| 15 | EventRules negative HP/max HP/Ember amounts, previews and matching requirements; benefits unchanged |
| 16 | Scavenger purchase charges and every UI buy-price read through DepthRules, rounded up to a multiple of five; sell base unchanged |
| 17 | Regular enemy base initiative and queue projection, floor three |
| 18 | New-combat reshuffle fatigue base |
| 19 | Extra Guardian helper after authored arena placement, on legal unoccupied floor |
| 20 | Noctyrax HP and damaging intent actions, cumulative with dragon class rules |

Guardian leaders and helpers share the Guardian class, including summoned
replacements. Ordinary summons receive no regular-enemy modifier. Only the six
authored dragons receive dragon modifiers. Loaded committed intents and already
scaled HP are retained; modifiers are never reapplied by load repair.

Dragon death rewards retain immediate presentation; the victory bonus pays the
remaining rounded amount so the combined reward rounds once, even when opposing
Ember omens coexist.

The score bonus is round-half-up of the complete pre-bonus total (base rows plus
feats) × depth × 5%. Its row is the last base row, before feats, with label
`Umbra Depth N`, detail `+N×5%` resolved numerically, and the added points as value.
Depth zero adds neither row nor recap eyebrow text. Nonzero recaps append
` · Umbra Depth N`; combat headers add an Umbra-violet eyebrow after the room
subtitle. Existing node names, analytics ids, saves and input paths remain intact.

## Picker and director decisions (feedback 1)

New Game opens the picker only after the first unlock. Existing saved-run
replacement confirmation remains before it. Back retains that save. Begin attempts to save
the chosen depth before the existing loading/new-run transaction starts, and
proceeds at that choice when only profile preference persistence fails.
The panel is 860×780, centered in the 1920×1080 reference viewport. It uses the
approved fonts, shared gilded material, 54 px round arrows, 64 px title, exact
protected modifier text, 21 px single-column text and 19 px two-column text.
Above ten, levels 1–10 are left and 11–20 right, at 30 px row pitch with a
40 px gap between columns. Numbers remain UI 15 px TEXT_3. The unlock hint
is Text 17 px TEXT_3, beneath the complete list. Only the newest row is primary
text with the ember NEW tag. Modifier number text follows the brief's TEXT_3 rule
where the mockup differs. Mouse buttons, Left/Right, LB/RB, Enter/A and Esc/B
are supported. Existing CursorFeedback click/confirmation cues are reused.

The director resolved every placeholder:

- Depth 19 adds `rime_whelp` for Rimejaw and `bell_tender` for Storm Cantor.
  Other Guardians use the first listed helper type, including mixed rosters.
- Dense rows, columns and hint type use the values specified above. A wrapped
  newest row retains its full text; its column has no subsequent row.
- Failed preference persistence keeps the choice in process memory across menu
  instances, logs one error per continuous failure episode, and adds no player
  message. Starting a descent carries that session choice into the embedded
  progression snapshot and permits a failed profile write after this specific
  preference failure. The new run save remains mandatory before replacement;
  other profile failures retain the existing start guard.
- `scavenger_shop_view.gd` is authorized by feedback 1. All six price read sites
  share a helper that calls DepthRules for buy prices; sell prices remain at the
  original base. Tags, tooltips, affordability, details and receipts agree with
  purchase charges.

The protected ladder places the Scavenger increase at Depth 16, while Depth 13
reduces dragon Embers. Feedback 1's Depth 13 price-equality regression is covered
at its authored base prices; increased-price coverage is also tested at Depth 16.
No protected data values are rewritten.

## Proof contract

Risk tier: high. `tests/depth_rules_test.gd` runs the extracted full-suite module.
It checks all twenty level gates, twelve pre-change SHA-256 state hashes, class
and spawn scaling, costs/previews/requirements, reward rounding, score, unlock
idempotency, per-depth bests, save/load, old saves, picker input, and JSONL depth. Feedback checks cover all six extra Guardian
helpers, session persistence failure through production run startup, and all
217 buyable items at Depths 0, 13 and 16 against actual purchase charges.
The existing section-map v2, event, dragon and Guardian suites remain regression
coverage. `tests/run_tests.gd` changes only suite registration.

`tests/new_descent_probe.gd -- --validate-only` checks the live menu route,
remembered choice, input ownership, text bounds, combat header and live shop
price equality headlessly.
Its windowed mode captures Depth 0, 3, 12, locked arrow, 20 and combat header at
1920×1080 and 100% UI scale, plus Scavenger views at Depths 13 and 16. It emits
eight PNGs beneath
`user://meta-03-depth-proof`; the visual runner prints their absolute paths.
`--write-proof-contract <path>` writes the corresponding semantic image contract
without launching any windows. The implementation sandbox cannot provide fresh
real-renderer inspection; the design owner must run and inspect the captures.

Proof-only defaults are plain named constants: seeds 307/8821/90429 for base
hashes, seed 307 for the capture fixture, six settle frames, one post-draw frame,
and a 240-frame teardown budget. Encounter fixtures use regular/Guardian room
depth 6, dragon room depth 8, entry direction (1,0), spawn tile (1,1), spawn
id 99, lethal proof damage 100000, base HP 13 and 200 reward rolls. The header
probe includes the existing iron_lung relic to check strip clearance below the
depth tag. The shop proof uses a 10000-Ember fixture budget. These do not alter
player-facing timing.
The full suite uses a 900-second runner timeout because the baseline was still
executing at the default 300-second limit.
