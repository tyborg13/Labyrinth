# Guardian inspection revision 3

This pass generalizes intent inspection, summon presentation, ground targeting and indirect elemental feedback through the shared combat/UI paths. Pacing changes target the Roc and Cantor cohorts; the turn-clock model itself stays intact.

## Interaction design

Surface: the combat board and its existing intent popups. The player needs to know an enemy’s declared movement, affected ground and unfamiliar effects. Clicking a visible enemy while no card or movement target is active keeps its intent visible. Existing target actions keep their normal click behavior. Clicking another enemy transfers focus; choosing a card, starting movement, clicking elsewhere or cancelling clears it. Pointer hover exposes exact token facts. Keyboard/controller inspection must reach the same information and dismiss without spending an action. The board, hand and normal turn controls remain the primary view; focus retains one contextual intent rather than opening a screen-covering menu. Native proof covers pointer focus/hover/dismissal, controller inspection/back/input handoff, overlapping patterns, summons and reduced motion at 1920×1080, 100% scale.

## Shared rules

Surface-producing attacks can target legal visible floor within their normal reach and sight rules without requiring a unit. An attack immediately followed by a previous-target Detonate can also aim at Fire ground; the Detonate keeps the same target and adds no click. Plain attacks retain their normal targets. Preview, card playability, actual resolution and analytics use the same rule.

Cragbound Gauntlet replaces Raise/Reclaim controls. Ranged Earth spells aimed at empty floor create one ordinary 3-HP outcrop at their chosen center after the spell resolves. The target must be empty when selected and still free when the outcrop is created. Existing enemy/terrain targets retain the spell’s ordinary result. Outcrops share Craghide art, Earth creation feedback, damage/destruction and Rubble residue. Spell placement is the only input; no independent Move or Stoneskin cost, extra targeting step or dedicated control is added.

Summon previews use green tile outlines and a summon icon; the compact intent row uses that icon plus the summoned name. Counts appear only for multiple spawns. Exact unfamiliar mechanics live in focused token tooltips, with factual wording and no tactical advice. Shared tile overlays deduplicate occupied cells and borders. Declared fixed attacks and actual resolution must agree, including interruptions, obstacles and appended summons.

Indirect elemental propagation and terrain creation animate at the actual effect boundary with their existing elemental visual and audio identity. They must not double-apply damage, repeat direct-hit sounds or mutate hand state. Outcrops emerge from the floor with irregular stone geometry, chipped fracture edges, fixed coarse/fine mineral texture, recessed fissures and darker ground contact; reduced motion preserves a readable static result and elemental cue.

## Proof and inspection

Use focused shared targeting/intent/input/feedback regressions, the full Godot suite, actual native captures and cadence observations. Update card/encounter scoring assumptions and additive analytics where affected. Preserve all existing Guardian inspection cases, replace the gauntlet study, and add ordinary-enemy focus, empty-floor surface/Detonate and indirect-conduction cases. Commit, obtain separate exact-HEAD peer review and verify the final saved fixtures before handoff. Publication remains pending user approval.

## Verified revision

The shared contract probe and full Godot suite pass. Icon identity checks (5 tests) and surface heuristic checks (6 tests) pass. Native Metal renders at 1920×1080 and 100% UI scale verify pointer hover opens the actual Bleed tooltip, a selected enemy retains its intent, controller inspection/cancel and selecting a different control clear focus correctly, single-click Earth placement, green summon markers, conduction impact/sound, and an intact hand afterward. The final normal/reduced outcrop sequence is recorded separately from the general interaction probe so its emergence is explicitly inspected with motion enabled.

Proof manifests: `output/guardian-revision-03/ui-v08.json` (28 images), `outcrop-v09.json` (6 images), and `playback-v10.json` (10 images). Curated screenshots and logs are retained with `output/guardian-revision-03/review.md`. Character rigs and their existing reviewed animation exports are unchanged in this pass.

`revision_03_evidence.json` records neutral card scores and two ordinary-loadout policy runs with their matching local analytics: Cantor won in seven activations at 21/24 HP, Roc in nine at 18/24 HP. These are functional cadence observations, not win-rate estimates. Unit contracts also cover the late-depth timing floor: minimum repeat delay 20 for these two leaders and 19 for their helpers, compared with 19 for a player turn containing two Time-5 cards. Very long turns can still yield extra enemy activations under the existing clock.

The 40-case inspection catalog adds empty Fire targeting without a trophy. Cragbound’s study has Root Snare attuned and Quarry Dust equipped as a consumable; both use ordinary card targeting. Ordinary Craghide encounter fixtures do not grant that epic consumable. All saves are regenerated and reload-verified against the reviewed commit before handoff. Native Windows testing remains unavailable; typed array assignments were reviewed and executed on macOS. Existing full-suite legacy-save and shutdown warnings remain unchanged.

Independent review reproduced and corrected four outcome-boundary cases: move/blink Fire loss now has one presentation group; deferred traps retain the primary sound/effect coverage; enemy trap handoffs keep indirect conduction feedback; and a forecast lethal Guardian approach suppresses backup markers. The real RunScene playback probe observes actual audio calls and rendered frames for Fire movement, Bleed-only movement, Frostbolt into a Fire trap, and Cantor conduction through a trapped conductor. The original candidate fails these regressions; the correction passes in normal and reduced motion. Both the focused contracts and full suite are rerun after these fixes.
