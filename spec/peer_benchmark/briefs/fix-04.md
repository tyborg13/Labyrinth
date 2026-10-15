# fix-04 — Briar Weaver loses its turn and intent after Thornwall (owner playtest 8)

## Header
- Owner (playtest 8, frozen build 3782ea5d0): "the Briar Weaver guy is bugged. He used the Thornwall thing and then he
  didn't get another turn. He was showing no intent, either mousing over him or showing a threat on the board."
- No script error in the session log (`/private/tmp/labyrinth-godot-home/playtest-8-inspection/godot.log`).
- Briar Weaver intents (data/enemies.json): thornwall (time 6, weight 3, `grow_bramble` line3 perpendicular in front of
  the hero, 3 rounds), lash_of_thorns (time 5, ranged), root_mend (time 5, heal_ally most_wounded).
- Base: `codex/peer-benchmark`. Owned: whatever the root cause needs (enemy intent selection / turn clock / en-04
  mechanics), plus tests. Follow AGENTS.md (combat/analytics rules: update instrumentation if outcomes change).

## Change
1. Reproduce headlessly: a combat with a Briar Weaver that casts Thornwall (also with the fixture's crawler + harrier,
   and alone), then advance the turn clock several rounds. Record whether it gets later turns and whether an intent is
   selected and shown (unit tooltip and board threat).
2. Find and state the **root cause** (e.g. intent selection returning nothing while bramble exists, turn-clock
   scheduling after a time-6 intent, root_mend with no wounded ally, lash with no line of sight). Fix it at the cause.
   Every enemy must always have a valid next intent or an explicit, visible fallback (never a silent no-intent state).
3. Regression test that fails before the fix and passes after; plus a general invariant test over all enemies: after
   each of their intents resolves, the enemy has a scheduled turn and a non-empty displayed intent.

## Proof
The regression test (before/after), the invariant suite, full suite. State the root cause in the result.
