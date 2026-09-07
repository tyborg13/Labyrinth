# Rules v5 verification

This is the September 7 feedback pass. Local receipts are under
`output/board-surface-refactor/feedback-pass/`; generated saves and rendered
media remain excluded from the game commit. The exact reviewed HEAD is bound
in the local handoff after verification and independent signoff.

| Check | Evidence |
| --- | --- |
| Integrated Godot regression | `full-suite-accepted.log`: TEST RESULT: PASS, process exit 0 |
| Core interactions | `surface-feedback-core-final.log`: 241 assertions pass; departure-Rubble movement regression also passes |
| Complete content | `data-check.log`: 26,710 checks; `content-smoke.log`: all 159 cards, 249 legal actions and 62 enemy intents pass ordinary/trace parity |
| Card and inventory UI | `ui/ui-native-05.json`: PASS10 at1920×1080/100%; actual220×308 and240×336 cards, parchment inset, one-pattern intents, paired Light rows and drag/drop/cancel inspected |
| Movement outcomes | `ui/movement-native-01.json`: PASS4; lethal pre-step Bleed commits and shows in-place damage; invalid/stale/hidden-collision and ordinary travel regressions pass |
| Playable inspection | `inspection-fixture.json`: separately generated and verified v5 save, with extra equipment/items/magic for inventory inspection; `inspection-native-final.json`: PASS5 at 1920×1080/100%, opening and conduction decision personally inspected |
| Presentation/analytics | `ui/presentation-focused-05.log`: current damage, delayed ground, targeting, replay, interruptions and v4/v5 event provenance/dedup pass |
| Save/tutorial | [SAVE_COMPATIBILITY_V5.md](SAVE_COMPATIBILITY_V5.md): v4 state and paid boundaries preserved; focused suites pass; native guided opening PASS22 |
| Surface materials | `art/material-02/`, material native PASS100; furnished PASS5; inspected texture and loop retain procedural authored silhouettes and motion |
| Renderer equivalence | All four retained-versus-direct normal/reduced pairs stay within2/255 everywhere; stable node count over12 lifecycle cycles |
| Performance | 24 tiles: median8.145/p9511.579ms, no interval over16.67ms. Stress72 tiles: median25.937/p9527.039ms; no added nodes/orphans. This is not a universal60fps claim |
| Balance/playtests | Full-pool score deltas retained in `balance/`; six seeded runs finish naturally with16 completed combats. Manual run completes3 encounters with26 paid cards. [PLAYTESTS_V5.md](PLAYTESTS_V5.md) records the limited greedy policy, Earth coverage gap and unbanked manual endpoint |
| Python/portability | Surface scorer6, progression context1, icon policy5 and fixture9 checks pass. Changed typed-array initializer audit and diff check pass |

The initial full run exposed stale copy/numeric assertions, which were updated
without weakening their semantic coverage. A later run still loaded an old
four-token-row assertion and expected the incorrect plural “1 card plays”; the
final receipt uses the corrected source. The initial Fire policy timeout exposed
an actual zero-step movement outcome being discarded; its final run reaches a
real defeat and emits one interrupted-movement event. These initial receipts
are retained rather than overwritten.

Gameplay/data/scorer source stayed stable during the final seeded matrix;
only RunScene presentation/analytics code changed concurrently. A subsequent
harness guard fix preserves actual decision counts when stopping a rejected
walk; no final run entered that guard. Current native UI and movement receipts
cover the final presentation changes separately.

Known base-suite renderer/ObjectDB shutdown warning categories remain, along
with the intentional ambiguous-legacy-save preservation warning. These checks
do not certify Windows runtime behavior or full human campaign balance.
