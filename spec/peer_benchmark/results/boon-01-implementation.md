# boon-01 implementation and proof

**Current handoff: feedback 3.** The appended feedback-3 section supersedes
earlier persistence recovery and relic rules fitting. Feedback 2 supersedes
round-1 secondary layout and tooltip behavior.
The director inspected and approved the round-1 offer composition.

Design authority: `spec/peer_benchmark/briefs/boon-01.md` (2026-10-17), plus
**boon-01 feedback 1, 2 and 3** supplied in the implementation conversation. Feedback 1
resolves all five original design placeholders. No approved art, fonts, audio,
card/equipment definitions, task queue or Git history was changed. All changes
remain uncommitted on `codex/boon-01`. Risk: **high** (run state, progression,
run-end flow and modal input). The design owner owns commits, review, fixtures
and publication; this worker does not request sign-off or run peer review.

## Acceptance mapping

1. Eligibility is recorded at creation: awakening previously seen, run index
   greater than one, guided tutorial inactive. Deliberate talk opens the offer;
   no automatic heirloom. One take/decline transaction per run. Repeated talk
   and save/resume preserve the complete seeded offer.
2. Each column samples uniformly among eligible boons. All actual spells,
   equipment, elements and relics are saved before acceptance. Armory now uses
   **rare** gear, uniformly samples an eligible starter slot and then a piece
   in that slot, and removes the replaced starter and its cards. Stored
   heirlooms always occupy column one. All boon effects have focused coverage;
   Vitality now adds **6 max and 6 current HP**. Debt changes purchase/service
   prices only in the first visited Scavenger room, rounded upward.
3. Approved dialogue and names are unchanged. The actual Emaciated Man
   dialogue/portrait remains visible throughout both offer steps, without
   buttons or an advance hint. Taking/declining follows in the same box.
   Death/victory still ask for one equipped piece or Leave nothing before recap.
4. Progression stores one base equipment id. A new piece replaces the old;
   Leave nothing retains it. Taking consumes the stored item; no upgrades or
   grafts return. Terminal prompt/confirmation saves preserve wallet receipts.
   The main-menu label is **CHOOSING AN HEIRLOOM**, in `SAVED_RUN_MODE_LABELS`.
5. Granted spells join the deck directly; relics use normal pickup; Embers use
   the run wallet. Gold glossary tokens remain authoritative.
6. The offer uses three independent **300×400** choice surfaces at
   **(454,210), (810,210), (1166,210)**, with the reward hover/focus pose,
   16px reward-family column tags, bounded centred rules, 96px sockets and
   64px keyword glyphs. The shared SKIP & RECOVER factory supplies the iconless
   Take nothing/Back pills at **y650**. The room placard is hidden while the
   real dialogue is active; the input hint bar remains available.
   Secondary choices use full production card widgets, reward sizes/banner,
   58px gaps for three and 24px gaps for four–six, and the full keyword tooltip
   stack. Root Esc/B does nothing. Secondary Esc/B and **Back** return freely.
   Purge toggles distinct copies, holds both with a 20px lift/focus finish,
   submits that frame, then opens `magic_purge_confirmation` listing both.
   Cancel clears both; only confirmation removes spells.
7. The additive `run_start_boon_offered`, `run_start_boon_chosen` and
   `heirloom_left` JSONL events keep saved receipts and stable idempotency keys.
   Payload/recovery behavior is documented in `spec/analytics.md`.
8. The unchanged heuristic scores all granted-card pools. The updated Armory
   comparison samples slots the same way as production. No new cards or
   heuristic coefficients were added.

The five feedback decisions are implemented: rare Armory eligibility, Vitality
current HP, the resume label, Back, and replacement of every design placeholder
in `data/opening_boons.json`. No `TODO_DESIGN` fields remain in that data or the
boon runtime scripts.

## Files changed

Runtime integration: `scripts/run_engine.gd`, `scripts/dialogue_engine.gd`,
`scripts/progression_store.gd`, `scripts/run_scene.gd`, `scripts/main_menu.gd`.
New implementation: `data/opening_boons.json`, `scripts/opening_boon_rules.gd`,
`scripts/opening_boon_flow.gd`, `scripts/opening_boon_overlay.gd`,
`scripts/opening_boon_card.gd`. Documentation: `spec/analytics.md`, this report.
Coverage: `tests/suites/opening_boon_suite.gd`, `tests/opening_boon_test.gd`,
`tests/helpers/opening_boon_fixture.gd`, `tests/helpers/program_sub_suites.gd`.
The existing recap fixtures (`tests/run_end_recap_tests.gd`,
`tests/run_end_recap_probe.gd`) represent the state after Leave nothing;
existing assertions are retained. Proof: `tests/opening_boon_probe.gd`,
`tests/helpers/opening_boon_proof.gd`, `tests/opening_boon_probe_contract.json`.
Balance tooling: `tools/opening_boon_balance.py`.

## Rough power comparison

Units are intrinsic **health-saved-equivalent per card**. A deck sum represents
one pass through its cards, not total run value. Best-of-k assumes selection
of the highest scored visible card, using exact order statistics for distinct
uniform draws. The six starter spells sum to **11.7504** (Pale Spark 2.1101,
Dull Bolt 2.1034, Waning Pulse 1.6617, two copies each).

| Option | Heuristic result / explicit resource effect |
| --- | --- |
| Elemental Gift | Expected best of three **4.0019**; uniform pick **3.1975**, averaged over the five elements. |
| Armory | **24 rare items**, five eligible starter slots. Expected card-sum delta **−0.323648**. Item deltas **−2.2564 to +1.8921**. Equipment stat bonuses are outside the per-card scorer. |
| Heirloom | Item dependent; Duelist Rapier is **+1.2768** over Training Sword. Every base-item delta is listed by the tool. |
| Purge | Removing both Waning Pulses removes **3.3234** intrinsic card score. The benefit of deck thinning is not modelled. |
| Focus | Four common spells average **12.1773**, a card-sum delta of **+0.4269** after removing the six starters. |
| Vitality | **+6 max HP and +6 current HP**, leaving a fresh run full. |
| Trinket | One common relic; persistent relic effects are outside the per-card scorer. |
| Blood Price | Expected best of five **4.4892**, uniform pick **3.2816**, with **−5 max HP**. Crude card-minus-health budget: **−0.5108**. |
| Pawned Light | One rare relic; current HP becomes **ceil(max HP / 2)** after pickup bonuses. Relic power is outside this scorer. |
| Debt | **+120 Embers**, first Scavenger prices **ceil(price ×1.5)**. No invented Ember-to-health conversion. |

| Armory slot | Expected card-sum delta |
| --- | ---: |
| Armor | +0.580525 |
| Boots | −0.459000 |
| Offhand | −0.817800 |
| Trinket | −0.600100 |
| Weapon | −0.321867 |

Reproduce with `python3 tools/opening_boon_balance.py`; feedback report:
`/private/tmp/boon-01-feedback-balance.json`.

## Chosen defaults

Only proof/test values: `PROOF_SEED=2` (Gift/Purge/Debt),
`ALL_PREVIEWS_SEED=5` (Gift/Trinket/Debt), `BLOOD_PRICE_SEED=1`,
`PROOF_HEIRLOOM=duelist_rapier`, coverage seeds `1..32`,
`SCAVENGER_ONE=(1,0)`, `SCAVENGER_TWO=(2,0)`,
`PRICE_ROUNDING_BASE=175`, `FOCUS_CYCLES=2`,
`WALLET_RESUME_EMBERS=120`, `RULE_FIXTURE_SECTION_MAPS=false`.
Geometry tolerance is the director's **1px**, not an implementation default.
Existing fixture settle times, reward transition timing, skins and components
are reused. Five native 30px strips require a 2px reduction each to fit the
specified 140px zone; the resulting name font remains 14px. This is the
closest fit to both the existing strip and the director's fixed preview zone.

## Proof for the design owner

The updated contract requires **10 captures**, retaining all seven existing
names and adding `offer_all_previews.png`, `purge_two_selected.png`, and
`blood_price_five_cards.png`. The probe checks the live controls against its
node/geometry contract with **1px tolerances**, including the actual submitted
Purge pair before confirmation. Headless semantics do not establish appearance.

This sandbox has no macOS window-server access. No windowed launch was retried.
The reward reference `output/peer-benchmark-2026-10-12/baseline/run_reward.png`
was inspected from the main checkout. The earlier `heirloom_prompt.png` path
in the director's manifest had expired; the existing component/skin and the
feedback's explicit **(323,842,1236,217)** dialogue bounds are used.

Run from the worktree (the expanded probe has more staged scenes, so its known
execution budget is 120 seconds):

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/boon-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/opening_boon_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/boon-01-feedback-visual.json tests/opening_boon_probe.gd --task-id boon-01
```

The runner prints absolute capture paths under its isolated
`user://opening_boon_probe/1920x1080/`: `offer_without_heirloom.png`,
`offer_with_heirloom.png`, `offer_spell_preview.png`,
`elemental_gift_choice.png`, `elemental_gift_taken.png`,
`heirloom_prompt.png`, `heirloom_prompt_reduced_motion.png`,
`offer_all_previews.png`, `purge_two_selected.png`,
`blood_price_five_cards.png`. `semantics.json` records the contract result.
No new `inspection_fixture.py` command was requested; the design owner retains
fixture preparation. The optional clip remains outside the protected
`tools/demo_clips/clips.json` contract; no director-authored clip values were
rewritten. The probe stages offer → Gift → chosen spell for inspection.

## Round-1 verification

Final feedback verification results follow. Both required full suites exited 0.

Final observed feedback checks:

```text
OPENING BOON RULES: deterministic rolls, eligibility, all effects, heirlooms, Debt and event receipts checked
OPENING BOON TEST RESULT: PASS
TEST RESULT: PASS
OPENING BOON PROBE RESULT: PASS
BOON HEADLESS SEMANTICS: PASS (1px geometry; 10 staged capture states; no renderer captures claimed)
BOON DESIGN PLACEHOLDERS: PASS (0 TODO_DESIGN keys)
BOON BALANCE REPORT: PASS (24 rare Armory items; expected card-score delta -0.323648; 5 elements)
```

- Focused engine command: `python3 tools/godot_task_runner.py --task-id boon-01 --timeout 120 --stream -- godot --headless --path . --script tests/opening_boon_test.gd`.
  Exit **0**, `/private/tmp/boon-01-feedback-focused-final-v3.log`.
- Semantic probe command: the same runner with
  `--script tests/opening_boon_probe.gd -- --verify-only`.
  Exit **0**, `/private/tmp/boon-01-feedback-probe-final-v3.log`.
  Its `passed: true`, `headless_semantics_only: true`, empty-capture report is
  copied to `/private/tmp/boon-01-feedback-headless-semantics.json`.
- UI identity lint: `python3 tests/test_ui_identity_lint.py`, exit **0**,
  `Ran 25 tests in 2.685s`, `OK`;
  `/private/tmp/boon-01-feedback-ui-lint-final.log`.
- `python3 tools/card_heuristic.py --json`, exit **0**;
  `/private/tmp/boon-01-feedback-card-scores.json`.
  `python3 tools/opening_boon_balance.py`, exit **0**;
  `/private/tmp/boon-01-feedback-balance.json`.
- `git diff --check`: exit **0**. No editor scan was used as a parser check.

Full Godot command:
`python3 tools/godot_task_runner.py --task-id boon-01 --timeout 900 --stream -- godot --headless --path . --script tests/run_tests.gd`.
Exit **0**, `/private/tmp/boon-01-feedback-full-godot.log`:

```text
OPENING BOON TEST RESULT: PASS
PROGRAM SUITE opening_boon_test: PASS
RUN END RECAP TEST RESULT: PASS
PROGRAM SUITE run_end_recap_tests: PASS
TEST RESULT: PASS — main menu resume safety
PROGRAM SUITE main_menu_resume_test: PASS
FULL SUITE RUNTIME: 884.525 seconds (budget 900 seconds)
TEST RESULT: PASS
```

The semantic probe intermittently prints these shutdown diagnostics after its
PASS result; verbose diagnosis identified a retained `GDScriptFunctionState`
and `scripts/run_scene.gd` resource. It still exits 0. Two-frame layout draining
was added to fixture cleanup, but the latest headless run retained the warning:

```text
WARNING: ObjectDB instances leaked at exit (run with --verbose for details).
ERROR: 1 resources still in use at exit (run with --verbose for details).
```

This is an open headless cleanup issue, not a renderer-proof success. The full
suite also emitted ObjectDB shutdown warnings. No existing assertion was
relaxed to obtain a pass.

Full Python discovery:
`python3 -m unittest discover -s tests -p 'test_*.py' -v`.
Exit **0**, `/private/tmp/boon-01-feedback-full-python.log`:

```text
Ran 617 tests in 531.757s
OK (skipped=61)
```

The verbose log records all 61 optional-dependency skips and their reasons.
Remaining proof is the design owner's fresh windowed ten-image run. No new
renderer capture, clip, identity judge pass or inspection fixture is claimed.


## Feedback 2 — implementation and proof

The director's 12 supplied images in `output/boon-01/director_r1/` were all
inspected, including the full-size Blood Price, Elemental Gift and Purge
captures, crop and contact sheet. Those provided files remain untouched.

1. Trinket uses the existing relic description verbatim. Pawned Light uses the
   same description followed by `Start at half @kw(health|HP).`. Keyword markup
   is preserved. Item names/sockets and Armory/Heirloom wording are unchanged.
   The complete effect can require five lines, superseding the original
   four-line name sentence. The 252×120 rules zone, font and offer geometry are
   unchanged. A focused fit check covers every current common/rare relic;
   observed maximum content height: **90px of 120px**.
2. A boon-owned subclass of the shared tooltip stack clamps its top below the
   rules box plus **8px**. Automatic focus is silent, including a card appearing
   under a stationary pointer. A genuine pointer motion or a keyboard/controller
   navigation focus change enables inspection. The normal full keyword stack is
   retained. Shared reward/global tooltip behavior is untouched.
   The existing Purge confirmation temporarily owns inspection input, so moving
   the pointer over its buttons cannot expose cards behind it.
3. Layout includes the painted watch crown and the worst reward hover pose.
   Its top is at least **y245** and **16px below the rules box**, including
   hover/focus and Purge selection. Back remains centred at **y650**.
   Three 292×411 reward cards cannot satisfy both fixed vertical bounds. The
   implementation therefore derives the largest uniform card scale that fits,
   preserving aspect ratio and the authored gaps. Observed headless geometry:

   | Step | Card size | Row top |
   | --- | --- | ---: |
   | Elemental Gift | 244.318×344 | 306 |
   | Blood Price | 214×301.312 | 299 |
   | Purge | 214×301.312 | 299 |

   Only the three-card size changes; the five/six-card reward sizes fit. These
   dimensions are calculated from the bounds and existing watch/hover geometry,
   rather than additional chosen visual defaults.
4. Purge retains the **20px** selected lift. Its existing ownership pill becomes
   **REMOVE** with `UiPalette.DANGER`, the shared destructive/warning token.
   Deselecting restores **OWNED** and its original muted finish. Confirmation
   and cancel semantics are unchanged.
5. The proof contract now requires **11 images**, preserving the original ten
   and adding **secondary_open_no_tooltip.png** immediately after Blood Price
   opens, with no intervening inspection input. Semantic checks retain **1px
   tolerances** and verify the painted medallion, rules/banner exclusion, Back
   position, navigation/pointer inspection and selected tag colour.
6. New full-pool text fitting and interaction/geometry checks live in the
   standalone boon probe; none is registered in the full Godot suite. The
   existing full-suite boon runner has the same waits and scenarios, with its
   existing hover assertion updated to the boon-owned stack. The 900-second
   full-suite budget is unchanged.

Feedback-2 files: `data/opening_boons.json`, `scripts/opening_boon_rules.gd`,
`scripts/opening_boon_overlay.gd`, new `scripts/opening_boon_inspection.gd`,
`scripts/opening_boon_secondary_layout.gd`,
`scripts/opening_boon_tooltip_stack.gd`, `tests/opening_boon_test.gd`,
`tests/opening_boon_probe.gd`, `tests/helpers/opening_boon_proof.gd`,
`tests/opening_boon_probe_contract.json`, and this report.

No new TODO_DESIGN placeholder, dependency, art, icon, font, audio or balance
value was introduced. No new test seed or timeout was chosen; existing proof
seeds and the established 120-second focused/probe budget are reused.

### Feedback-2 checks

- Focused boon tests: exit **0**, `/private/tmp/boon-01-r2-focused-final.log`:
  `OPENING BOON TEST RESULT: PASS`, `TEST RESULT: PASS`.
- Final focused semantic probe: exit **0**,
  `/private/tmp/boon-01-r2-probe-final-guard.log`:
  `OPENING BOON PROBE RESULT: PASS`. Its explicitly headless, empty-capture
  report is copied to `/private/tmp/boon-01-r2-headless-semantics.json`.
- UI identity lint: `/private/tmp/boon-01-r2-ui-lint.log`:
  `Ran 25 tests in 3.410s`, `OK`.
- `git diff --check`: exit **0**. Earlier focused proof rejected the old
  four-line name-sentence limit after the approved relic effect was added;
  the updated contract requires complete, unclipped effect text in the same
  geometry. No pre-existing master assertion was rewritten.

- Python discovery: exit **0**, `/private/tmp/boon-01-r2-full-python.log`:
  `Ran 617 tests in 488.837s`, `OK (skipped=61)`.
- Final full Godot suite: exit **0**,
  `/private/tmp/boon-01-r2-full-godot-final.log`:
  `PROGRAM SUITE opening_boon_test: PASS`,
  `PROGRAM SUITE run_end_recap_tests: PASS`,
  `PROGRAM SUITE main_menu_resume_test: PASS`,
  `FULL SUITE RUNTIME: 844.070 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`. This is **40.455 seconds below** the director's previous
  884.525-second run. The first feedback-2 full run also passed in 853.074
  seconds before the Purge confirmation inspection guard was added; the final
  run includes that guard. Neither run increases the 900-second budget.

Godot logs include macOS CA-certificate startup diagnostics and some isolated
program suites' ObjectDB cleanup warnings, also present in the first passing
run. The final focused boon test/probe do not emit ObjectDB cleanup warnings.
No assertion has been weakened or reclassified to hide those diagnostics.

### Feedback-2 proof for the design owner

This sandbox still has no macOS window-server access. New windowed captures
cannot be produced here, and none is claimed. Run:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/boon-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/opening_boon_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/boon-01-r2-visual.json tests/opening_boon_probe.gd --task-id boon-01
```

The runner prints exact capture paths beneath its isolated
`user://opening_boon_probe/1920x1080/`, including the new
`secondary_open_no_tooltip.png`. All ten prior names remain in the contract.
No inspection-fixture change or command is required by this feedback. The
owner retains renderer review, fixture preparation, commits and publication.

## Feedback 3 — peer findings and director text fit

Read the complete review from the integration branch using
`git show codex/peer-benchmark:spec/peer_benchmark/feedback/boon-01_review_1382b6916.md`.
Inspected the supplied `director_r2/offer_with_heirloom.png`, `zoom3.png` and
`sheet3.png`. No director captures or approved card/equipment/relic assets or
definitions changed.

1. **Replacement recovery:** `opening_boon_recovery.gd` acknowledges a saved
   run's strictly newer embedded progression before `_start_run` can replace
   it. Failed acknowledgment retains the original save. Equal revisions keep
   the profile's fields, including a committed recovery marker; embedded
   outbox entries are merged additively. Run-first terminal boon transactions
   stamp settlement once; ordinary profile-first checkpoints retain their
   existing revision behavior. Terminal fallback replacement uses the normal
   accounting/result receipts, recovering already-settled fallback wallets or
   settling raw terminal wallets before deletion. It preserves acknowledged
   profile wallets. Active abandonment still loses held Embers. The focused
   regression takes Duelist Rapier with profile writes failing, verifies the
   run-only consumption, blocks replacement while acknowledgment cannot save,
   then restores writes and verifies no Rapier in the next offer. Settled
   wallet recovery and equal-revision recovery-marker retention are covered,
   plus profile-write failures before/after victory/death presentation.
2. **Outstanding receipts:** Save & Quit, abandonment and replacement either
   deliver boon receipts or transfer them durably to the existing profile
   analytics outbox before clearing/overwriting the save. Keys and original
   run context are retained. A failed transfer leaves the save intact. Tests
   force appends to fail, choose Leave nothing, fail and restore the profile
   transfer, quit, replace, restore appends and replay both copies. A separate
   path replaces directly without quitting. Each of the three events is
   observed exactly once after recovery. JSONL remains local and append-only.
3. **Surviving mutations:** the repeat test now retries a different piece that
   is still equipped; the Purge test requests two Pale Sparks with only one
   remaining; injected authoritative run-write failures assert unchanged live
   gameplay/progression, durable run/profile, terminal flags and analytics.
   Boon terminal choices save the run before the profile so failed run writes
   cannot commit an otherwise rolled-back heirloom. All three temporary guard
   removals were rejected: **3 caught, 0 survived; source restored**. Summary:
   `/private/tmp/boon-01-r3-mutations.json`.
4. **Data authority:** `Rules.purge_count()` reads the one data count used by
   validation, selection capacity, confirmation readiness and rules text.
   The text template resolves to the unchanged approved sentence. Removed
   unused `focus.remove_count`; Focus still swaps the actual starter spells.
   The balance report also slices the actual starter-copy scores using this
   data count, rather than assuming two removals. Its observed Purge score is
   still **3.3234**, and rare Armory's expected delta is **−0.3236483333**.
5. **Text layout:** every boon keeps a 252px rules zone with 24px side padding.
   More than four lines at `SIZE_BODY` (16px) uses the existing `SIZE_SMALL`
   (15px), retaining the body font. The probe instantiates production boon
   cards for every eligible common/rare relic in **both** presentations:
   **54 relics × 2 = 108 cards**. Observed maximum **5 lines / 85px**, with
   **12** cards using the smaller size. Each card is checked after layout/draw
   opportunities for both pads, width, role-specific line limits, complete
   effect/keyword text and vertical fit. The 11 capture names and 1px tolerances
   remain intact; the contract now records the typography limits too.

Feedback-3 files: `data/opening_boons.json`; `scripts/opening_boon_card.gd`,
`opening_boon_flow.gd`, `opening_boon_overlay.gd`, `opening_boon_rules.gd`, new
`opening_boon_recovery.gd`, and the small integration hooks in `run_scene.gd`;
`tests/suites/opening_boon_suite.gd`, new `tests/opening_boon_recovery_test.gd`,
new `tests/helpers/opening_boon_relic_proof.gd`,
`tests/helpers/opening_boon_proof.gd`, `tests/opening_boon_probe.gd`,
`tests/opening_boon_probe_contract.json`, `spec/analytics.md`, and this report.
`tools/opening_boon_balance.py` now derives its removal count from boon data.

All expensive new fault-injection and complete-pool presentation checks stay
in standalone focused runners/probes. Only the two cheap guard assertions
changed in the existing full-suite model coverage. No full-suite scene startup,
wait, dependency, art, icon, font asset, balance coefficient or timeout added.

### Feedback-3 chosen defaults and open issues

No TODO_DESIGN placeholders or new player-facing decisions. New test-only
fields name the isolated profile/run/analytics paths and a file used as a
write-blocking parent: `PROFILE_PATH=user://pre_battle_probe_progression.json`,
`RUN_PATH=user://pre_battle_probe_run.save`,
`ANALYTICS_PATH=user://opening_boon_recovery_analytics`,
`WRITE_BLOCKER=user://opening_boon_write_blocker` and derived
`FAILED_WRITE_PATH=WRITE_BLOCKER/unwritable`.
`SETTLED_WALLET=120` reuses the existing wallet fixture;
`RECOVERY_COORD=(2,0)` reuses the existing recovery/Scavenger coordinate. Existing seeds,
viewport/scale and 120-second focused budgets are reused. Full Godot remains
budgeted at 900 seconds. Revision/idempotency mechanics reuse existing named
fields, not gameplay tuning. All changes remain uncommitted.

The first recap check caught an equal-revision marker regression introduced by
the initial recovery implementation. Its existing assertion was preserved,
the tie behavior was fixed, and the focused recap rerun passed.

### Feedback-3 verification

- Focused boon tests: exit **0**, `/private/tmp/boon-01-r3-focused-final.log`:
  `OPENING BOON TEST RESULT: PASS`, `TEST RESULT: PASS`.
- Final headless probe: exit **0**, `/private/tmp/boon-01-r3-probe-final.log`:
  `BOON RELIC RULES PROOF: {"cards":108,"maximum_height":85,"maximum_lines":5,"smaller_body_cards":12}`,
  `OPENING BOON PROBE RESULT: PASS`. Its report is copied to
  `/private/tmp/boon-01-r3-headless-semantics.json`; captures are explicitly
  empty. This final run emitted an intermittent shutdown diagnostic retaining
  one `run_scene.gd` function-state/resource (identified in the verbose focused
  run), also observed intermittently in prior rounds. It is not a failed
  semantic assertion or renderer proof and is not claimed fixed here.
- Recovery/fault injection: exit **0**, `/private/tmp/boon-01-r3-recovery-final.log`:
  `OPENING BOON RECOVERY TEST RESULT: PASS`, `TEST RESULT: PASS`.
  The Rapier reproduction blocks profile writes while keeping its live file
  readable. Forced failure cases intentionally print persistence errors; their
  rollback/durability assertions all pass. This standalone runner is not added
  to the full-suite program list.
- Focused recap: exit **0**, `/private/tmp/boon-01-r3-recap-final.log`:
  `RUN END RECAP TEST RESULT: PASS`.
- Focused menu resume: exit **0**, `/private/tmp/boon-01-r3-menu-final.log`:
  `TEST RESULT: PASS — main menu resume safety`.
- Final UI identity lint: exit **0**, `/private/tmp/boon-01-r3-ui-lint-final.log`:
  `Ran 25 tests in 3.272s`, `OK`.
- Balance report: exit **0**, `python3 tools/opening_boon_balance.py`:
  `/private/tmp/boon-01-r3-balance.json` (Purge count **2**, card score removed
  **3.3234**; Armory expected card-sum delta **−0.32364833333333326**).
- Both existing derived analytics hosts pass task-runner `--check-only`:
  `/private/tmp/boon-01-r3-deferred-skill-parse.log` and
  `/private/tmp/boon-01-r3-deferred-run-skill-parse.log`. The three-argument
  persistence method signature remains compatible; no derived tests changed.
- Targeted guard removals: `/private/tmp/boon-01-r3-mutations.json`:
  `BOON MUTATIONS: 3 caught, 0 survived; source restored`. Each failed on its
  intended regression assertion, with no parser error.

- Python discovery: exit **0**, `/private/tmp/boon-01-r3-full-python.log`:
  `Ran 617 tests in 481.224s`, `OK (skipped=61)`.

- Final full Godot retry: exit **0**,
  `/private/tmp/boon-01-r3-full-godot-retry.log`:
  `PROGRAM SUITE opening_boon_test: PASS`,
  `PROGRAM SUITE run_end_recap_tests: PASS`,
  `PROGRAM SUITE main_menu_resume_test: PASS`,
  `FULL SUITE RUNTIME: 835.208 seconds (budget 900 seconds)`,
  `TEST RESULT: PASS`. No full-suite budget was raised. Runtime code was frozen
  for this successful run. All expensive new tests remain focused-only.

The first feedback-3 full Godot attempt (`/private/tmp/boon-01-r3-full-godot.log`)
exited **124** with `error: command timed out after 900 seconds.` EN03 had just
reported `PASS (210 checks, 0 failures)`; the boon/recap/menu tail did not finish.
No assertion failure was reported. This attempt is **not a PASS**. The budget
was not raised. Python discovery ran before the same-budget retry, so the
two broad suites did not compete for CPU. No new heavy tests had run in this
full attempt; those remain focused-only.

Final `git diff --check`: exit **0**. No commits, branch changes, review agents,
publication actions, task-queue edits or director capture edits were performed.

### Feedback-3 proof for the design owner

Windowed proof remains owner-run: this worker has no WindowServer access and
has not retried a windowed launch. Run from this worktree:

```bash
cd /Users/borgerding/workspace/Labyrinth.worktrees/boon-01 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 120 --expect-size 1920x1080 --proof-contract tests/opening_boon_probe_contract.json --result-manifest /private/tmp/labyrinth-inspection-manifests/boon-01-r3-visual.json tests/opening_boon_probe.gd --task-id boon-01
```

The runner prints exact PNG paths beneath isolated
`user://opening_boon_probe/1920x1080/`. It retains all 11 captures, including
`offer_with_heirloom.png` and `secondary_open_no_tooltip.png`. Headless metrics
are not renderer proof. No inspection-fixture command is required by feedback 3.
