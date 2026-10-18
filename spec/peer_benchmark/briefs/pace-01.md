# pace-01 — Readable enemy actions (playtest 10)

## Header
- **Owner, playtest 10 (2026-10-18):** "the enemies moving quickly is nice, I like that, but non movement actions may be
  too sped up, sometimes all the enemies turns play and I can't really keep up with what they are all doing."
- **Root cause (director):** `scripts/combat_pacing.gd` `feedback_duration()` caps each enemy action's post-hit
  feedback at `ENEMY_FEEDBACK_ADVANCE_SECONDS` (0.20 s), but the damage number alone is authored at 0.48 s
  (`FloatingCombatText.ANIMATION_DURATION_SECONDS`, plus stagger). The next enemy starts while the last hit is still
  playing, so actions overlap. Only the first enemy gets a lead-in (the 0.35 s banner lead).
- **Base:** `codex/peer-benchmark`. **Owned:** `scripts/combat_pacing.gd`, `tests/combat_feel_probe.gd`,
  `tests/suites/combat_feel_suite.gd`, `tests/suites/combat_pacing_regression_suite.gd`, and new tests or capture
  helpers. Touch `scripts/run_scene.gd` only where a pacing hook is missing; list each change.

## Change (director values; all in `combat_pacing.gd` constants)
1. **Movement unchanged:** `ENEMY_TILE_SECONDS` stays 0.20 s per tile (owner approved).
2. **Full feedback for enemy actions:** after an enemy attack, cast, push, pull, AoE or lightning strike, the hit
   reaction and damage numbers play their full authored duration; then hold `ENEMY_ACTION_SETTLE_SECONDS` = 0.15 s before
   the next enemy's turn begins. Remove the 0.20 s cap for these steps. Move-only turns keep today's hand-off.
3. **Lead-in for each acting enemy:** before an enemy's wind-up, hold `ENEMY_ACTION_LEAD_SECONDS` = 0.25 s with its
   caption ("Name: Intent") showing. The first enemy of the phase keeps the 0.35 s banner lead instead (no double wait).
   Move-only turns get no lead-in.
4. **Combat speed setting still applies:** Fast (1.5×) and Fastest (2×) scale every wait above through the existing
   presentation clock. Hit-stop and reduced motion keep working.
5. **Budget:** the staged round's budget changes from ≤ 6.0 s to ≤ 9.0 s at Normal. Report the before/after
   `pass_to_hero_banner` times at Normal, Fast and Fastest.

## Proof
- **Repair the feel probe first:** `tests/combat_feel_probe.gd --timeline-only` fails today with "Approved round has
  a valid placement" (stale fixture). Fix the fixture so the staged round again has 4 acting enemies, at least one
  move-only turn, and at least one melee and one ranged/cast action.
- Headless: the probe timeline at all three speeds (no overlap: each enemy's wind-up starts after the previous enemy's
  feedback plus the settle), the pacing regression suite, and the combat feel suite. Mutations: restore the 0.20 s cap;
  drop the lead-in; make a move-only turn wait.
- Windowed, run by the director: give the exact command for a 1920x1080, 60 fps capture of the staged round at Normal,
  before and after, with game audio, as an MP4 for the owner.
- Don't run the full Godot or Python suites; the director runs them at merge.

## Out of scope
Player-side pacing, animation content, hit-stop and shake values, the turn-order HUD.
