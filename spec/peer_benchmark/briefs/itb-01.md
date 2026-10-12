# itb-01 — Threats at rest: intent pills, order numerals, threat tiles, callouts

## Header
- Goal: like Into the Breach and Slay the Spire, the player sees every visible enemy's next attack WITHOUT hovering or
  toggling: a compact intent pill over each enemy (attack icon + damage, plus its order of action) and quiet crimson
  outlines on the tiles about to be hit. The existing full view stays available as "Details". When the player's plan
  cancels or redirects an enemy action, the board says so.
- Today: at rest the board shows NO intents (only the red base marks); everything sits behind the "Intents [I]" toggle,
  whose view is noisy (intent names, move-range wash, arcs). Evidence:
  `output/peer-benchmark-2026-10-12/clips/z_intents_on/off_on.png` (top = rest, bottom = toggle on).
- Mockup (approved look): `output/peer-benchmark-2026-10-12/mockups/threats_at_rest.png`.
- Base: `codex/peer-benchmark` (merge state after feel-01 lands; the director will tell you the base commit).
- Docs (sections): spec/actor_presentation.md, spec/ranged_intent_preview_rendering_notes.md, spec/turn_clock.md
  "Presentation", spec/forced_movement.md preview section, spec/visual_design_system.md tokens.
- Owned files: new `scripts/intent_badges.gd`, new `scripts/threat_tiles.gd`, new `scripts/intent_callouts.gd`, new
  `tests/suites/threats_at_rest_suite.gd` + `tests/threats_at_rest_test.gd`, new `tests/threats_at_rest_probe.gd`;
  modify `scripts/combat_board_view.gd` (draw calls + data plumbing only; put drawing in the new files),
  `scripts/run_scene.gd` (≤ 40 lines: toggle semantics, pass forecast data), `scripts/combat_hud_intents.gd` (label),
  `data/grimoire.json` (one entry update), `spec/threats_at_rest.md` (new), `spec/visual_design_system.md` (one bullet).
- Rules: presentation only (rules/state unchanged); Umbra rules unchanged (hidden enemies show nothing); reduced
  motion respected; Windows typed-array rule; `TODO_DESIGN_<name>` for anything undecided.
- Contract: risk tier standard. Acceptance: (1) pills and threat tiles visible at rest for every visible enemy, matching
  the mockup values; (2) order numerals match the turn-clock order of enemy actions before the hero's next turn;
  (3) hover isolates one enemy; Details toggle shows today's full view; (4) Cancelled / Redirected callouts fire in the
  right cases; (5) previews keep updating (a hovered push re-aims pills/tiles exactly like today's retarget preview).

## Change (numbered, testable)
1. **Intent pill** (per visible enemy with a known next intent), centred 8 px above the enemy's health bar:
   - Plate: rounded rect, radius 5 px, height 26 px, fill INK_0 `#0b0908` at 88% opacity, 1 px border in the intent
     family colour: attack/area = DANGER `#c7453b` (90%), defence/guard = STEEL `#8fb3d9` (90%), support/heal/summon =
     GOLD `#c9a25e` (90%), movement-only = TEXT_3 `#7f7262`.
   - Content: the action's primary icon at 20×20 (existing ActionIconLibrary icon for that action: melee, ranged, aoe,
     push, pull, block, heal…) then the primary number in the Crumble UI cut at 19 px, TEXT `#efe3c8` (damage; for
     multi-hit "4×2"; for block/guard the amount; no number for actions without one). A secondary status (Bleed,
     Chilled, Push distance) appears as a second 16 px icon + 15 px number, max one secondary.
   - Order disc: 22 px circle left of the plate (overlapping its left edge by 4 px), INK_0 fill, 1 px GOLD border,
     numeral in Crumble UI 14 px GOLD_BRIGHT `#f0cf8a`: the position of this enemy's next action among ENEMY actions
     scheduled before the hero's next turn if the hero ended the activation now (same projection as the Pass forecast).
     An enemy acting twice shows "1·3". Enemies that will not act before the hero's next turn show no disc and their
     plate at 55% opacity.
   - Pills never overlap each other: if two would, stack the later one 30 px higher (max 2 levels), keeping the order.
2. **Threat tiles** (at rest): every tile that will be struck by an enemy attack scheduled before the hero's next turn
   (same projection), excluding movement-range tiles: 2 px inner diamond outline DANGER at 75% + fill DANGER at 12%. The
   hero's tile when threatened: fill 24% with a slow pulse 18%→30% over 1.1 s (reduced motion: steady 24%). Overlapping
   threats on one tile do not stack fills (use the max). No arcs, no names, no movement wash at rest.
3. **Preview coupling.** While the player hovers/aims a card or a move, pills and threat tiles show the PREVIEWED
   intents (re-aimed by pushes, cancelled by kills/Shock/Freeze/Stagger past the hero's turn), using the existing
   preview data; a cancelled intent's pill shows the icon with a 2 px diagonal strike in TEXT_2 and its tiles disappear.
4. **Hover isolation.** Hovering/focusing an enemy keeps today's detailed single-enemy view and dims other enemies'
   threat tiles and pills to 40%.
5. **Details toggle.** The "Intents [I]" button becomes "Details [I]" (same key, same controller path) and shows
   today's full all-enemy view on top of the at-rest layer. Tooltip: "Show every enemy's full plan [I]" /
   "Hide full plans [I]". Default off.
6. **Callouts** during resolution (`intent_callouts.gd`), using the existing floating-text style at the enemy, Crumble
   UI 22 px, 0.9 s rise-and-fade, TEXT_2 colour: "Cancelled" when an enemy's turn comes and its announced attack does
   not happen because its target/line became invalid, it was Shocked/Frozen, or it was killed mid-turn before acting
   (only if it had a visible announced attack); "Redirected" when the announced attack resolves on a different target
   than announced because a unit or the hero was moved (it hits another enemy or empty ground). One callout per
   action; none for hidden enemies.
7. **Grimoire.** Update the intents/basics entry text: "Enemies show their next attack above them: its damage and the
   order they act in. Red tiles will be struck before your next turn. Press I for every enemy's full plan."
8. **Spec.** spec/threats_at_rest.md with the values above.

## Keep (must not break)
- The existing detailed hover view, retarget previews, lethal marks, Pass forecast, dragon pressure warnings, Umbra
  privacy (`tests/umbra_preview_privacy_probe.gd`), guided tutorial phase that teaches inspecting an enemy (update its
  copy only if it references the old toggle wording), controller navigation.

## Proof
- Suite: order numerals vs turn-clock projection (incl. double actions and non-acting enemies), threat tile set =
  attack tiles only, hidden enemies excluded, preview re-aim/cancel reflected, callout triggers (cancel by kill, by
  Shock, by moved target; redirect by push).
- Probe (windowed, director runs) at 1920×1080: rest view of the staged 4-enemy room (layout of
  `tools/trailer_director/shots/b_enemy_turn.gd`), hover isolation, a push preview re-aiming an intent, Details on,
  a Cancelled callout frame, an Umbra room with a hidden enemy.
- Keep green: enemy_intent_preview/compass suites, umbra privacy probe, full suite.

## Out of scope
- New icons/art, rules changes, rail redesign, sound.
