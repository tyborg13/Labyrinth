# qa-23 feedback 1

| Finding | Seed | Root cause | Fix | Regression |
|---|---|---|---|---|
| No-effect Gloam Ambush reaches Contact without `actor_key` | 5, decision 2475 | The resolver adds `enemy_after` to an otherwise empty strike. The Gloam adapter treated that snapshot as a contact action. | Forward strikes with `kind` and `actor_key` to Contact; send snapshot-only strikes through the existing scene dispatch. | Existing `tests/suites/en03_enemies_suite.gd`: no-effect playback with/without Blink, normal/reduced motion; real-hit controls. |

This chooses the **legacy scene-dispatch fallback**, matching `stalker_view.gd` before the contact route. Supplying an actor key would introduce a swing. No-effect frame submissions, timing, pacing, state and silent feedback match the legacy reference; real effects retain the authored Ambush contact clip. No animation difference appeared in these traces. No art, rig data, timings, tuning or audio declarations changed.

All seven integration `actions.gd` adapters were inspected at `7f3f1e5f59e81042122bcc1829f38a2c2e31b3b7`: Briar Weaver, Burrow Grub, Glacial Mirror, Gloam Stalker, Hoarfrost Seer, Slag Mortar and Storm Capacitor. Gloam is the only nested Contact forwarder. The audit also covers all 11 `humanoid_v2` integration declarations. No additional affected adapter was found.

Proof:

- Base adapter: `QA23 AMBUSH PLAYBACK: FAIL (33 checks, 4 failures)`; four missing-`actor_key` script errors.
- Fixed adapter: `QA23 AMBUSH PLAYBACK: PASS (33 checks, 0 failures)`; zero script errors.
- Final focused program: `EN03 ENEMIES TEST RESULT: PASS (499 checks, 0 failures)`, exit 0, no retries.
- Seed 5: `replay_point`, decision **2476**, exit 0, **zero `SCRIPT ERROR:` markers**; 67 rooms, sections 0–5. All 2476 inputs match the original campaign after normalizing generated UI node IDs.
- Final Python default: `Ran 178 tests in 27.655s`, `OK` (19 modules); isolation audit 54 modules. No full suites.

Logs, exact commands, source hashes and replay evidence: `/private/tmp/labyrinth_codex/qa-23/feedback-1/` (`proof-summary.json`, `adapter-audit.json`, `regression-{before,after}.log`, `en03-final.json`, `python-final/`, `seed5-replay/`). Native captures: none; this sandbox has no window server. The prior polygon proof command remains in `result.md`.

Files changed this feedback: `assets/units/gloam_stalker_cutout/actions.gd`, `tests/suites/en03_enemies_suite.gd`, this report and `feedback-1-proof.json`. Prior accepted changes remain intact. Everything is uncommitted.

Chosen defaults (test-only): `AMBUSH_START=(2,2)`, `AMBUSH_BLINK_END=(3,2)`, `AMBUSH_DISTANT_HERO=(6,6)`, `AMBUSH_HIT_START=(5,4)`, `AmbushPacing.resume_action=false`, `AmbushPlaybackScene.reduced=false` (both motion modes exercised). Frame counts and durations come from production data.

TODO_DESIGN placeholders: none. New product issues or balance surprises: none. The known macOS certificate diagnostic and accepted tree-growth note remain in replay evidence; Python passed despite the sandbox denying its optional Git timing-cache update. This resolves the Gloam open issue in the original report; tree growth and Snare remain notes.
