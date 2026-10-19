# pace-02 — Enemy actions play at 80% speed (owner note)

## Header
- **Owner, enemy-pacing verdict (2026-10-19):** "This is better but still a bit fast. Are the attack animations and
  number pop ups still sped up? It may be worth slowing those down a little rather than keeping them sped up and just
  holding after."
- **Facts (director):** at Normal, enemy actions already play at their authored speed (`Engine.time_scale` 1.0);
  feel-01 shortened the gaps between enemies, not the actions. pace-01 (merged 4e874c34f) added the 0.25 s caption lead
  and the full feedback plus a 0.15 s settle.
- **Base:** `codex/peer-benchmark`. **Owned:** `scripts/combat_pacing.gd` and its enemy-phase hooks, the combat feel
  probe and suites, the pacing regression and mutation tests, the SFX sync harness's scale coverage
  (`tests/sfx_sync_*.gd`, coverage only; never lower a baseline), the capture helper `tests/capture_pace_round.py`, and
  the docs `spec/combat_feel.md` and `spec/visual_design_system.md` (pacing lines).

## Change (director values)
1. **Enemy action presentation scale:** from each enemy action's wind-up through the end of its hit reaction and damage
   numbers, presentation runs at **0.80 ×** the combat-speed scale: Normal 0.80, Fast 1.20, Fastest 1.60. Use the
   existing presentation clock (`Engine.time_scale` through `CombatPacing`). This covers attacks, casts, push/pull, AoE,
   lightning, ally support, status damage and the mechanic views (en02/en04/en05/en06, the Seer and other maquette
   actions). Constant: `ENEMY_ACTION_SPEED_SCALE = 0.80`.
2. **Unchanged:**
   - enemy movement (0.20 s per tile at Normal, scaled by combat speed only);
   - the 0.25 s caption lead and the 0.15 s settle (normal combat-speed scale, not the 0.8);
   - the hero's own cards;
   - hit-stop (real milliseconds);
   - audio pitch;
   - reduced motion.
3. **SFX sync:** cues still start on their action frames. Extend the harness so the effective enemy-action scales (0.8,
   1.2, 1.6) are covered alongside the existing 1.0/1.5/2.0. Every presentation plays once with its full authored
   duration. No baseline count is lowered.
4. **Budget:** the staged Normal round stays ≤ 9.0 s. Report the before/after `pass_to_hero_banner` times at all three
   speeds.

## Proof
- Headless: the combat feel probe at three speeds, the pacing regression, mutation and action-pacing suites, all three
  `suites/sfx_sync_*_program` (`tools/program_suite_runner.py --suite …`), and `tests.test_test_registration_audit`.
  Mutations: scale 1.0 restored; movement wrongly slowed; lead or settle wrongly stretched.
- Windowed, run by the director: the before/after round capture (`tests/capture_pace_round.py`), as in pace-01.
- No full suites; the director runs them at merge.

## Out of scope
Animation content, hit-stop and shake values, movement speed, the turn-order HUD.
