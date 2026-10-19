# pace-02 feedback 1 — review fixes

The Codex review of f33b29da6 asked for two fixes. The director's values are unchanged.

1. **Ambush blink slowed (Medium).** `combat_pacing.gd` ~319 enables 0.80 before the Gloam Stalker's embedded blink,
   and `scripts/enemy_mechanics/veil_view.gd` ~78 has no movement guards. Identical (6,4)→(3,4) blinks run at 1.0 for
   Fade but 0.8 for Ambush. Bracket the blink with `begin_movement`/`end_movement` so it plays at the movement scale,
   then resume 0.80 for the strike. Add a regression for both Fade and Ambush, with Reduced Motion on and off.
2. **Approach-walk guard coverage (Medium).** Removing both movement hooks from `_animate_actor_along_path` survives the
   new suite, because the Shrike fixture is already aligned. Add an unaligned Dive fixture; assert the approach scale
   (1.0) and the following attack scale (0.80) independently; register this mutation so it must fail.

Proof: the combat feel, pacing, action-clock suites and mutations, the three SFX sync programs, the registration audit.
No full suites.
