# area-01 feedback 2 — number-free floor, named activations

Presentation-only implementation on owner-committed r1 HEAD
`10f8e538e1759f21fa9f71248a13c636560dd5eb`. Feedback-2 changes remain
uncommitted. No windowed run, review, commit, publication or queue edit is part
of this worker handoff. Standard presentation risk: focused headless checks,
matched area truth audit and owner-run native inspection; no full suites or
new permanent test modules. No difficulty rerun or tuning change this round.

## Diagnosis and acceptance

- **R1:** the r1 `1·4` is the area attacker-order tag, supplied by
  `intent_badges.gd`, painted by `threat_tiles.gd` and retained/isolation slices.
  Threat descriptors no longer supply that badge order; the compatibility
  selector returns no tags and its painter draws nothing, including stale or
  explicitly supplied legacy tags. Health-frame discs, repeat chips and rail
  numbers are untouched. Both owning specifications now describe this rule.
- **R2:** the r1 Tharokh evidence has a six-cell, two-wide Bedrock Breath line;
  its `later_red_tiles.enemy_1` adds twelve cells from Faultline. The breath
  itself is not conical. The existing loss cursor now records each known
  red-producing activation's intent and unit snapshot, beside the existing
  later-red receipt. Summary/disc plumbing carries these presentation records
  to the board. Each activation gets its existing named move block, in order,
  with no deduplication of identical repeats. Its action numbers and shape rows
  come from that activation's snapshot. Later titles reuse the existing title
  font, underline, row sizing and clearance solver. Pointer and controller
  inspection share this builder. Single-activation layout remains unchanged.
  Records also invalidate stale rest views when names change without geometry.
- **R3:** `enemy_intent_activations.gd` supplies display-only action context from
  the unchanged r1 classifier. Every relative area gets `Moves with <Name>` in
  warning style and the exact owner-provided hover sentence. Display names use
  the text before the first comma. Combat and pre-battle rows share this context.
  Fixed moves retain Marked; ordinary aimed actions gain no new token.

The forecast performs no additional simulation, chooses no new move and mutates
no live combat state. Resolver, AI, held tiles, relative/fixed classification,
rule beats, saves, analytics, data, assets and authored tuning are unchanged.
Battlefield-rule sentences remain outside this pass.

## Changed files

- `scripts/threat_tiles.gd`, `intent_badges.gd`: remove floor order tags.
- `scripts/pass_forecast_red_tiles.gd`, `pass_forecast_discs.gd`: presentation
  activation receipts and rest-cache invalidation.
- New `scripts/enemy_intent_activations.gd` and UID: activation rows and relative
  action context. `combat_board_view.gd` reuses the existing title/row painter.
- `scripts/action_icon_library.gd`, `pre_battle_inspection_view.gd`: contextual
  warning token for all nineteen relative moves, including raw library rows.
- `spec/threats_at_rest.md`, `spec/visual_design_system.md`: current floor and
  multi-activation contract.
- Existing `tests/suites/threats_at_rest_suite.gd`, `tests/threats_at_rest_test.gd`
  and `tests/suites/en04_enemies_suite.gd`: changed floor-tag expectations;
  repeated names, exact relative wording, classification and stale-view checks.
  The initial area-rules run exposed the old Lob floor-tag assertion and an
  index into its now-empty tag array; those changed-requirement assertions were
  updated in place. No pre-existing unrelated failure assertion was changed.
- Existing area-01 `capture.gd`, `native_capture.sh`, `bootstrap_sidecars.gd`,
  plus `single_capture_contract.json`: native owner proof and unscaled crop.
- This handoff and `feedback2_results.json`: observed results and source hashes.

## Remaining legacy wording

The following are all remaining source occurrences of `Fixed direction` before
this handoff's own explanatory text (exact paths/lines are also in the JSON):

- `scripts/action_icon_library.gd`: one comparison removes the old label from
  relative rows; two original emitters remain for generic/unowned pattern rows.
  The only authored enemy using that fallback outside the r1 relative list is
  **Rime Spitter / Needle**, a pre-existing ordinary line attack. Its wording
  remains unchanged. Raw action/card/debug projections without enemy context
  retain their previous fallback; all nineteen relative combat/pre-battle
  projections are checked to replace it.
- `tests/suites/threats_at_rest_suite.gd`: the negative assertion checks that
  relative rows never contain the old label. It is not displayed to players.
- `spec/peer_benchmark/staged/text/inventory.csv`: lines 615, 621, 623, 624.
  `inventory.json` in the same directory: lines 15187, 15345, 15399, 15402,
  15412, 15425, 15428, 15438. These are historical extracted source/text records,
  not live glossary entries; left unchanged.
- `spec/peer_benchmark/deck_text_2026-11-07/inventory.csv:199`: historical token
  draw-source inventory (its text records the old fallback); left unchanged.

No live glossary definition quotes that label. No glossary wording was changed.

## Proof for the design owner

No windowed command was attempted. Run from the current worktree:

```sh
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/feedback1/truth/tharokh-1301/repro/1301-10 tharokh bedrock_breath
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/feedback1/truth/zekarion-1301/repro/1301-1 zekarion skybreak
cd /Users/borgerding/workspace/Labyrinth.worktrees/area-01 && sh tools/atk13/area01/native_capture.sh /private/tmp/labyrinth_codex/area-01/feedback1/truth/ashen_reaver-1301/repro/1301-1 ashen_reaver raking_flame true
```

The existing visual runner/native Metal launcher uses `LABYRINTH_CEL_LOOK=all`,
1920×1080, 100% UI scale and one attempt. Outputs are under
`/private/tmp/labyrinth_codex/area-01/feedback2/captures/`:

1. `tharokh-bedrock_breath_rest.png`: controller inspection open, Bedrock Breath
   then Faultline; same content verified with pointer inspection; no floor tags.
2. `tharokh-bedrock_breath_aimed.png`: real Updraft aimed at Tharokh; relative
   breath slides, later Faultline follows the existing forecast's frozen marks.
3. `tharokh-bedrock_breath_strike.png`: real push/attack playback at contact.
4. `zekarion-skybreak_rest.png`: existing Marked medallions, no order tags.
   Its aimed/strike frames are retained as additional proof.
5. `ashen_reaver-raking_flame_rest.png` and
   `crops/ashen_reaver-raking_flame_tooltip.png`: real once-acting relative move
   with its movement warning. The crop is taken directly from the native image
   at the production tooltip's measured bounds, without rescaling or repainting.

Each case also writes semantic JSON and a visual-runner manifest. The r1 PNGs
exist, but their visual-runner manifests reported no discoverable images: the
old script did not print its external output directory. This script now prints
that directory, including its crop subdirectory, for the existing collector.
No inspection-fixture installation is required; audited saves are copied into
isolated runner HOME directories. Fixture preparation remains with the owner.

## Chosen defaults and TODO_DESIGN

No player-facing defaults or TODO_DESIGN placeholders were needed. No art,
icons, colours or fonts were created or downloaded.

Proof-only Health is derived from `RunEngine.BASE_MAX_HP` and the existing
`DepthRules.start_max_hp` for the saved run: these three cases use **24/24**,
including refreshed cached hero-target Health. The live card and attack
playback checks survival every frame. The audit's inherited 9999-Health walk is
only a headless coverage witness; it is not used in owner screenshots.

New proof-only fields: `PROOF_CROP_PADDING=8` pixels (includes the title's
existing shadow), `PROOF_ATTEMPTS=1`; `--single=true` selects the once-acting
crop case. Existing boot/layout/playback limits, pointer parking, Updraft debug
hand insertion, contact timing, seeds and audit walk defaults remain as in r1.
No timing or value seen during normal gameplay changed.

## Observed verification

Final result lines, per-move/per-kind counts, logs, source hashes and remaining
limits are recorded in `feedback2_results.json`. Native pixels and an independent
visual judgement remain owner work. The previously disclosed r1 hidden-ground
forecast limit is not changed by this presentation pass; geometry and fixed-area
comparisons must remain zero. No difficulty or full-suite results are relabelled
as feedback-2 proof.

## Final observed results

Both natural-fight audit drivers exited 0: `AREA01 TRUTH AUDIT PASS`.

27 moves, two seeds each; 535 continued area executions and 5619 PASS/movement alternatives. All tile, independent stamp, at-rest/no-shift, red-omission and fixed-area forecast mismatches are **0**. The 9 disclosed relative end-to-end differences from r1 remain (zero undisclosed); no targeting rule was changed.

| Kind | Moves | Walked | Alternative strikes | Push/pull branches | Force strike checks | Geometry errors | Forecast differences (undisclosed) |
|---|---:|---:|---:|---:|---:|---:|---|
| fixed | 8 | 139 | 980 | 171 | 167 | 0 | 0 (0) |
| relative | 19 | 396 | 3197 | 509 | 508 | 0 | 9 (0) |

| Move | Kind | Walked | Alternative strikes | Updraft / Yank | Geometry errors |
|---|---|---:|---:|---|---:|
| ashen_reaver/executioners_fall | relative | 8 | 73 | 6 / 6 | 0 |
| ashen_reaver/hooked_sweep | relative | 8 | 89 | 6 / 6 | 0 |
| ashen_reaver/raking_flame | relative | 9 | 85 | 4 / 4 | 0 |
| bell_tender/connector | relative | 8 | 63 | 1 / 0 | 0 |
| briar_weaver/thornwall | fixed | 13 | 83 | 6 / 6 | 0 |
| craghide/groundsplit | fixed | 30 | 125 | 15 / 15 | 0 |
| gallows_roc/hookwind | relative | 40 | 340 | 28 / 28 | 0 |
| gallows_roc/razor_pinion | relative | 38 | 355 | 22 / 22 | 0 |
| iskaldra/shatterstorm | relative | 22 | 188 | 11 / 11 | 0 |
| iskaldra/whiteout_lance | relative | 22 | 172 | 14 / 14 | 0 |
| last_lamplighter/mourning_hook | relative | 38 | 288 | 19 / 19 | 0 |
| noctyrax/last_eclipse | fixed | 22 | 174 | 21 / 21 | 0 |
| noctyrax/night_coil | relative | 22 | 154 | 16 / 16 | 0 |
| noctyrax/starless_breath | relative | 20 | 122 | 16 / 16 | 0 |
| storm_cantor/lay_the_choir | relative | 27 | 237 | 18 / 18 | 0 |
| tharokh/bedrock_breath | relative | 19 | 93 | 13 / 13 | 0 |
| tharokh/faultline | fixed | 18 | 102 | 12 / 12 | 0 |
| tharokh/stonewake | relative | 20 | 108 | 13 / 13 | 0 |
| tharokh/worldspine_claw | relative | 19 | 101 | 12 / 12 | 0 |
| vaeloryx/eye_of_storm | relative | 22 | 216 | 14 / 14 | 0 |
| vaeloryx/hollow_gale | relative | 22 | 212 | 23 / 23 | 0 |
| vaeloryx/razor_dive | relative | 24 | 231 | 14 / 14 | 0 |
| vyraketh/cinder_maw | fixed | 7 | 67 | 5 / 5 | 0 |
| vyraketh/cinderfall | relative | 8 | 70 | 5 / 5 | 0 |
| vyraketh/crownfire | fixed | 8 | 78 | 8 / 8 | 0 |
| vyraketh/kindle_ground | fixed | 9 | 77 | 8 / 9 | 0 |
| zekarion/skybreak | fixed | 32 | 274 | 10 / 10 | 0 |

All five separate live-follow-up matrices retain zero disagreements. Raw records: `/private/tmp/labyrinth_codex/area-01/feedback2/{truth,helpers}/`.

- `AREA01 RULES RESULT: PASS (1879 checks, 0 failures)` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tools-atk13-area01-rules_tests.log`.
- `AREA01 EXISTING SUITES RESULT: PASS (1921 checks, 0 failures)` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tools-atk13-area01-focused_suites.log`.
- `Dragon committed patterns passed.` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-dragon_committed_patterns_test.log`.
- `Dragon feedback mechanics passed.` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-dragon_feedback_mechanics_test.log`.
- `Dragon rewards, gifts, wallet recovery and relic hooks passed.` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-dragon_rewards_test.log`.
- `Dragon reward feedback logic: PASS` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-dragon_reward_feedback_test.log`.
- `DRAGON TROPHY FEEDBACK: PASS` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-dragon_trophy_feedback_test.log`.
- `DRAGON WALLET ACK TEST: PASS (108 checks)` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-dragon_wallet_ack_test.log`.
- `GUARDIAN RULES TEST RESULT: PASS (667 checks, 0 failures)` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tests-guardian_rules_test.log`.
- `THREATS AT REST TEST RESULT: PASS (17040 assertions; includes compass suite)` — `/private/tmp/labyrinth_codex/area-01/feedback2/threats-final.log`.
- `ATK03 FOCUSED RESULT: PASS (1778 assertions, 0 failures)` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tools-atk03-focused_tests.log`.
- `ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)` — `/private/tmp/labyrinth_codex/area-01/feedback2/checks/tools-atk04-focused_tests.log`.
- `SHORT CARD TOOLTIPS TEST RESULT: PASS (767 checks, 0 failures)` — `/private/tmp/labyrinth_codex/area-01/feedback2/short-tooltips.log`.

- UI identity lint: `Ran 25 tests` / `OK` — `feedback2/ui-lint.log`.
- `AREA01 CAPTURE COMPONENTS PASS (2 cases; headless semantics only)` — `feedback2/capture-final.log`.
- Single Reaver: `AREA01 CAPTURE PASS semantic=true` — `feedback2/capture-single-final.log`.
- All three capture cases have zero unnamed foe-red tiles, matching pointer/controller rows and 24/24 Health; measured crop bounds are in the JSON. Each playback checks survival every frame.
- Headless Dummy renderer resource/texture cleanup warnings remain in capture logs; they are not native image proof.
- `AREA01 SIDECARS PASS`; shell syntax and `git diff --check` passed. No full suites, difficulty reruns or windowed attempts.

Open issues: owner-run native inspection remains outstanding. The accepted r1 hidden-ground forecast limitation remains disclosed. No other headless check is failing. Passive/death/split trait rows remain printed once per foe, while move rows repeat per activation.
