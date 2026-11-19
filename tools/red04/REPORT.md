# Red-04 and the truth-batch handoff

Red-04 keeps each first stamp on the displayed board and unions it with the existing atk-11 hero-tile contacts. It preserves the release inputs to reverse hover, intent expansion, the rail, and the targeting outline. The floor and marker build their own tile lookups when their threat rows change. A floor tile has one entry per owner and keeps the maximum alpha and any rule-outline flag.

Release removed later-attack floor paint in area-04. The Spark Dart → Static Lash and Dust Bolt → Dust Advance checkpoints still count both activations and their losses in Pass. The later attacks add no floor rows in red-04.

## Focused proof

- Tharokh's seed 7262026 Pass-with-loop replay kept `(2,5)`, `(5,3)`, and `(5,4)` in the first stamp. The native checkpoint uses real Health.
- At seed 101003, decision 102, the forecast expects the enemy to die first. The floor still paints its warning at `(2,5)` and the raised outline uses release coverage. The native checkpoint has 9,999 maximum Health because the normal-Health route ends at decision 23.
- The Windows checkpoints counted 11 Health from Pass at decision 226 and 2 Health plus 3 Block at decision 463. Both had zero later-attack rows. The contact checks covered a Gust collision, Fire from a living or dead foe, and a push onto Fire whose contact belongs to the landing tile.
- The overlap fixture keeps one owner entry per tile, maximum alpha, the public visibility allowance, and the rule-outline flag. The marker fixture verified that an identical stage submission retains its lookup.

```text
THREATS AT REST TEST RESULT: PASS (16324 assertions; includes compass suite)
ATK04 FOCUSED RESULT: PASS (892 assertions, 0 failures)
EL04 RULE VIEWS RESULT: PASS (0 failures)
PTF09 HIGHLIGHT: PASS (3655 checks, 0 failures)
QA103 RESULT approved_cases.gd: PASS (0 failures)
```

## Ten-run campaign

Eight runs ended in Embrace and two in victory. Of 8,376 settled samples, 6,743 were scored for red. The before and after comparison uses the same board in each sample and excludes Snare pressure decoration.

```text
RED04 CAMPAIGN: runs=10/10 settled=8376 scored_red=6743 changed=88 first_stamp_mismatches=95->0 at_rest=62->0
RED04 PASS ISSUES: 0
RED04 LATER-ATTACK ROWS: 0
```

Of the 88 changed boards, 58 were at rest. There were 33 restored warnings for living enemies, 25 restored present-board anchors, 21 foe-surface contacts, and 9 rule contacts. The seven corresponding archived aim samples cleared their red flags. Receipts are under `tools/qa110/out/red04/feedback2/`.

In the paired headless assembly benchmark, the largest p95 increase was 7.12 microseconds per warmed submission. Each case used 31 paired samples of 2,000 submissions. The campaign used 60 fixed FPS.

## Notes for truth-batch-1

The first five findings in the re-review of `0bd1a2b76` apply when red-03 restores later-move paint in `codex/mrg-05`.

1. Begin repeat geometry on the committed board. Advance only the acting foe's own earlier moves. A Gale Herald moving the hero between those moves and a hovered Walk destination are checks for keeping repeat geometry anchored. Pass and existing markers still use the hovered forecast.
2. Classify each effective action independently. Vyraketh's Meteorfall can cause immediate damage with its Cinder Marks and also fires a ranged shot. Include both damaging footprints.
3. Run the activation-start gates on the foe's projected state before collecting footprints. A Storm Capacitor starting with 4 Health and 2 Charge on persistent Fire can survive to Charge and then die to the next Fire tick before Arc Burst.
4. Admit deterministic follow-ups behind hidden or new actors. Storm Capacitor's 3-Charge Arc Burst can be known even when a hidden actor makes the Pass random stream uncertain. Keep that uncertainty in Pass.
5. Stop collecting repeat tiles at the first player turn entry. A Freeze skip can extend Pass's damage forecast past that entry without extending repeat paint.

## Native retry

The previous Walk command exited before launching Godot because the visual runner protects an existing `result.json`. The wrapper creates a unique `run.*` directory for each invocation under `tools/qa110/out/red04/native/<case>-<phase>/` and prints the path. Each run retains its own PNG, receipt, and manifest.
