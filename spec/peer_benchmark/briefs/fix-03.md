# fix-03 — Fatigue amplification bug + small presentation bugs found by the text audit

## Header
- **Owner decision (2026-10-15):** Fatigue damage must NOT be amplified by Expose, Chilled or Frozen ("No, definitely
  not"). Root cause (director): `scripts/combat_engine.gd:7773` calls
  `_lose_player_health(next_state, fatigue_damage, true, true, "fatigue", true)` — the 4th argument
  `apply_freeze_multiplier = true` routes Fatigue through `_damage_player`'s status multipliers.
- Base: `codex/peer-benchmark`. Owned files: `scripts/combat_engine.gd` (Fatigue call and, if needed, the multiplier
  gating in `_damage_player`), the HUD script(s) for Sunpath/Dawnbrand SPENT state, `text_token` call sites listed
  below, the Lightning Strikes count chip, new/updated tests. Analytics: Fatigue events keep their fields; if the
  damage value changes in any logged event, update `spec/analytics.md` only if it documents the old behaviour.
- Rules: no balance or rules changes beyond item 1; Windows typed-array rule; deterministic tests.

## Change
1. **Fatigue**: Fatigue health loss is never multiplied by Expose, Chilled, Frozen or any other incoming-damage
   multiplier (and still bypasses Block, as today). Fix at the call (and in `_damage_player` if the flag name hides more
   than freeze). Regression test: with each of Expose, Chilled, Frozen (and all three together) on the player, a
   reshuffle costs exactly the base Fatigue amount; it fails on the current code.
2. **Audit only, no change**: list every other non-attack player health-loss source (Bleed, Collision, traps, ground,
   costs, relic/skill self-damage, …) and whether each is currently amplified by those statuses (file:line). Report the
   table in the result; the owner decides later.
3. **Sunpath / Dawnbrand HUD SPENT** never shows because it reads the wrong flag — fix it to read the flag the rules set;
   regression test.
4. **`text_token` callers passing an icon key as the tone** render tokens without their icon — find every such call,
   fix it to pass the icon properly; test that each fixed token renders its icon.
5. **Lightning Strikes count chip** uses the Shock icon although no Shock is applied — use the icon of the concept it
   counts (if no dedicated icon exists, use the lightning element icon) and keep icon identity tests green
   (`python3 tests/test_icon_identity_policy.py`).

## Proof
New regression tests; combat engine suites; threats_at_rest; icon identity; full suite. Report the item-2 table.

## Out of scope
Changing any other damage source's amplification, text rewrites (ux-04), new icons.
