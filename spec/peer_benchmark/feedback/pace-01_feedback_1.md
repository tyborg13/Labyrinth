# pace-01 feedback 1 — review fixes

The Codex review of 5631735f7 asked for changes (`spec/peer_benchmark/feedback/pace-01_review_5631735f7.md` on
integration). The director committed your round as 5631735f7, plus: the doc updates in `spec/combat_feel.md` and
`spec/visual_design_system.md`, and the registration of `combat_pacing_mutation_test` in
`tests/helpers/program_sub_suites.gd` and `tools/program_suite_runner.py`. Keep those.

Fix all four; the director's pacing values are unchanged.
1. **Ally support skips the lead (Medium).** `combat_pacing.gd` classifies the actor by `actor_key` only; ally heal and
   guard steps carry the caster in `source_actor_key`. Use the source actor for activation classification and caption
   ownership. Add ally-support coverage; removing `heal` from the action kinds must then fail a test.
2. **`status_damage` bypasses the settle (Medium).** Action-triggered bleed emits `status_damage`, which isn't in
   `ENEMY_ACTION_KINDS`; a bleed-death sequence produced no settle. Include it in settle handling and cover the early
   `continue` near `run_scene.gd` ~24660.
3. **Hidden attacks can settle twice (Medium).** The hidden-Umbra presentation (~`run_scene.gd` 24941) calls
   `after_step` for visible portions, and the outer branch (~24546) calls it again: two settles (0.304 s) for one attack.
   Give exactly one layer ownership of the pacing hook; add a clipped-Umbra regression asserting one settle.
4. **Unused constants (Low).** Remove `ROUND_CAPTURE_FPS` in `tests/combat_feel_probe.gd` and `Pacing` in
   `tests/combat_pacing_mutation_test.gd`.

Proof: the combat feel, pacing regression and mutation tests, and `python3 -m unittest discover -s tests -p
'test_p*.py'`. Report the three-speed times again. No full suites.
